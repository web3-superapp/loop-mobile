import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';

void main() {
  final now = DateTime.utc(2026, 9, 22, 12);
  const authenticated = LoopNotificationSessionContext.authenticated();
  const wbnb = 'eip155:56:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c';

  LoopNotificationRouter router({
    int capacity = 128,
    DateTime Function()? clock,
  }) {
    return LoopNotificationRouter(
      clock: clock ?? () => now,
      openedPointerCapacity: capacity,
    );
  }

  group('只认这四个键', () {
    test('一条合规的推送解析成一个指针，而不是一个结果', () {
      final decision = router().route(
        data: _payload(type: LoopPushNotificationType.priceAlertTriggered),
        ingress: LoopNotificationIngress.interaction,
        session: authenticated,
      );

      expect(decision.disposition, LoopNotificationDisposition.pointerReady);
      expect(
        decision.pointer?.type,
        LoopPushNotificationType.priceAlertTriggered,
      );
      expect(decision.pointer?.entityRef, 'priceAlert:$_uuid');
    });

    test('多一个键就整条作废，不是可以只读一半的推送', () {
      for (final extra in <Map<String, Object?>>[
        <String, Object?>{'contextParams': 'assetId=$wbnb'},
        <String, Object?>{'assetId': wbnb},
        <String, Object?>{'body': '余额 747.39'},
        <String, Object?>{'deep_link': '/wallet/send'},
      ]) {
        final decision = router().route(
          data: _payload(
            type: LoopPushNotificationType.priceAlertTriggered,
            extra: extra,
          ),
          ingress: LoopNotificationIngress.interaction,
          session: authenticated,
        );

        expect(
          decision.disposition,
          LoopNotificationDisposition.malformed,
          reason: extra.keys.first,
        );
        expect(decision.pointer, isNull, reason: extra.keys.first);
      }
    });

    test('少一个键、值不是字符串、版本不对，都是无效载荷', () {
      final missing = _payload(type: LoopPushNotificationType.securityEvent)
        ..remove('contextRoute');
      final nonString = _payload(type: LoopPushNotificationType.securityEvent)
        ..['eventVersion'] = 1;
      final wrongVersion = _payload(
        type: LoopPushNotificationType.securityEvent,
      )..['eventVersion'] = '2';

      for (final data in <Map<String, Object?>>[
        missing,
        nonString,
        wrongVersion,
      ]) {
        expect(
          router()
              .route(
                data: data,
                ingress: LoopNotificationIngress.interaction,
                session: authenticated,
              )
              .disposition,
          LoopNotificationDisposition.malformed,
        );
      }
    });

    test('Stream 自己的聊天推送在这里失败关闭，而不是被半懂', () {
      // Stream 的 data 带 sender / cid / message_id 等键，与 LOOP 的信封不是
      // 同一件东西；半懂它就等于让另一个发送方决定去哪一页。
      final decision = router().route(
        data: const <String, Object?>{
          'sender': 'stream.chat',
          'type': 'message.new',
          'version': 'v2',
          'id': 'message-id',
        },
        ingress: LoopNotificationIngress.interaction,
        session: authenticated,
      );

      expect(decision.disposition, LoopNotificationDisposition.malformed);
    });

    test('type 与 contextRoute 配不上时，不用其中一半去解释另一半', () {
      final data = _payload(type: LoopPushNotificationType.securityEvent)
        ..['contextRoute'] = 'token';

      expect(
        router()
            .route(
              data: data,
              ingress: LoopNotificationIngress.interaction,
              session: authenticated,
            )
            .disposition,
        LoopNotificationDisposition.malformed,
      );
    });

    test('entityRef 的前缀属于身份的一部分，不是标签', () {
      for (final entityRef in <String>[
        'voiceRoom:$_uuid',
        'priceAlert:not-a-uuid',
        'priceAlert:',
        ' priceAlert:$_uuid',
        // A zero-width space, written as its code point: pasted into source
        // it would be an invisible difference nobody could review.
        'priceAlert:$_uuid${String.fromCharCode(0x200b)}',
      ]) {
        final data = _payload(
          type: LoopPushNotificationType.priceAlertTriggered,
        )..['entityRef'] = entityRef;

        expect(
          router()
              .route(
                data: data,
                ingress: LoopNotificationIngress.interaction,
                session: authenticated,
              )
              .disposition,
          LoopNotificationDisposition.malformed,
          reason: entityRef,
        );
      }
    });
  });

  group('送达上下文与会话', () {
    test('前台与后台只是「看到了」，从不导航', () {
      for (final ingress in <LoopNotificationIngress>[
        LoopNotificationIngress.foreground,
        LoopNotificationIngress.background,
      ]) {
        final decision = router().route(
          data: _payload(type: LoopPushNotificationType.securityEvent),
          ingress: ingress,
          session: authenticated,
        );

        expect(decision.pointer, isNull, reason: ingress.name);
        expect(
          decision.disposition,
          ingress == LoopNotificationIngress.foreground
              ? LoopNotificationDisposition.foregroundObserved
              : LoopNotificationDisposition.backgroundDeferred,
        );
      }
    });

    test('未登录被拒绝，正在恢复的会话只是被推迟', () {
      expect(
        router()
            .route(
              data: _payload(type: LoopPushNotificationType.securityEvent),
              ingress: LoopNotificationIngress.interaction,
              session: const LoopNotificationSessionContext.ineligible(),
            )
            .disposition,
        LoopNotificationDisposition.sessionRejected,
      );
      expect(
        router()
            .route(
              data: _payload(type: LoopPushNotificationType.securityEvent),
              ingress: LoopNotificationIngress.interaction,
              session: const LoopNotificationSessionContext.restoring(),
            )
            .disposition,
        LoopNotificationDisposition.sessionDeferred,
      );
    });

    test('同一个指针在一分钟内只开一次，过了窗口再触发就是新的一件事', () {
      var clock = now;
      final single = router(clock: () => clock);
      final data = _payload(type: LoopPushNotificationType.priceAlertTriggered);

      expect(
        single
            .route(
              data: data,
              ingress: LoopNotificationIngress.interaction,
              session: authenticated,
            )
            .disposition,
        LoopNotificationDisposition.pointerReady,
      );
      expect(
        single
            .route(
              data: data,
              ingress: LoopNotificationIngress.interaction,
              session: authenticated,
            )
            .disposition,
        LoopNotificationDisposition.duplicateInteraction,
      );

      clock = now.add(const Duration(minutes: 2));
      expect(
        single
            .route(
              data: data,
              ingress: LoopNotificationIngress.interaction,
              session: authenticated,
            )
            .disposition,
        LoopNotificationDisposition.pointerReady,
        reason: '两分钟后同一个提醒再次触发，是一件新的事',
      );
    });

    test('去重表有上界，最旧的一条先让位', () {
      final small = router(capacity: 1);
      final first = _payload(
        type: LoopPushNotificationType.priceAlertTriggered,
      );
      final second = _payload(
        type: LoopPushNotificationType.priceAlertTriggered,
        entity: '00000000-0000-4000-8000-00000000000b',
      );

      for (final data in <Map<String, Object?>>[first, second, first]) {
        expect(
          small
              .route(
                data: data,
                ingress: LoopNotificationIngress.interaction,
                session: authenticated,
              )
              .disposition,
          LoopNotificationDisposition.pointerReady,
        );
      }
    });

    test('容量必须在界内', () {
      expect(() => router(capacity: 0), throwsArgumentError);
      expect(() => router(capacity: 2048), throwsArgumentError);
      expect(
        () => LoopNotificationRouter(duplicateWindow: Duration.zero),
        throwsArgumentError,
      );
    });
  });

  group('目的地来自 feed 的记录', () {
    LoopNotificationPointer pointer(LoopPushNotificationType type) {
      return router()
          .route(
            data: _payload(type: type),
            ingress: LoopNotificationIngress.interaction,
            session: authenticated,
          )
          .pointer!;
    }

    test('feed 确认了资产，才打开那一个 Token 页', () {
      final intent = LoopNotificationRouter.resolve(
        pointer(LoopPushNotificationType.priceAlertTriggered),
        context: const LoopNotificationContext(
          contextRoute: 'token',
          assetId: wbnb,
        ),
      );

      expect(intent, isA<LoopPriceAlertNotificationIntent>());
      expect(
        intent.location,
        '/market/token?assetId=${Uri.encodeQueryComponent(wbnb)}',
      );
    });

    test('feed 没确认资产就退到价格提醒页，不猜一个 Token', () {
      for (final context in <LoopNotificationContext?>[
        null,
        const LoopNotificationContext(contextRoute: 'token'),
        const LoopNotificationContext(contextRoute: 'token', assetId: 'PEPE'),
        const LoopNotificationContext(contextRoute: 'devices', assetId: wbnb),
      ]) {
        final intent = LoopNotificationRouter.resolve(
          pointer(LoopPushNotificationType.priceAlertTriggered),
          context: context,
        );

        expect(intent, isA<LoopPriceAlertListNotificationIntent>());
        expect(intent.location, '/market/alerts');
      }
    });

    test('安全事件与语音房的目的地不带任何来自 payload 的参数', () {
      expect(
        LoopNotificationRouter.resolve(
          pointer(LoopPushNotificationType.securityEvent),
        ).location,
        '/profile/devices',
      );
      expect(
        LoopNotificationRouter.resolve(
          pointer(LoopPushNotificationType.communityVoiceRoomStarted),
        ).location,
        '/chat/voice',
      );
    });
  });
}

const _uuid = '00000000-0000-4000-8000-00000000000a';

Map<String, Object?> _payload({
  required LoopPushNotificationType type,
  String entity = _uuid,
  Map<String, Object?> extra = const <String, Object?>{},
}) {
  return <String, Object?>{
    'type': type.wireName,
    'entityRef': '${type.entityPrefix}:$entity',
    'contextRoute': type.contextRoute.wireName,
    'eventVersion': LoopNotificationRouter.eventVersion,
    ...extra,
  };
}
