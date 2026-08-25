import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';

void main() {
  final now = DateTime.utc(2026, 8, 25, 12);
  const authenticated = LoopNotificationSessionContext.authenticated(
    'loop_7a7448be64e24f9fa9f1891f1beec7fd',
  );

  LoopNotificationRouter router({int capacity = 128}) {
    return LoopNotificationRouter(
      clock: () => now,
      openedEventCapacity: capacity,
    );
  }

  test('interaction resolves only the strict Chat CID route', () {
    final decision = router().route(
      data: _payload(
        kind: LoopNotificationRouter.chatMessageKind,
        cid: 'messaging:loop-room-42',
      ),
      ingress: LoopNotificationIngress.interaction,
      session: authenticated,
    );

    expect(decision.disposition, LoopNotificationDisposition.navigationReady);
    expect(decision.intent, isA<LoopChatNotificationIntent>());
    expect(
      decision.intent?.location,
      '/chat/channel/${Uri.encodeComponent('messaging:loop-room-42')}',
    );
  });

  test('Audio Room and system events resolve only fixed safe destinations', () {
    final instance = router();
    final audio = instance.route(
      data: _payload(
        kind: LoopNotificationRouter.audioRoomActivityKind,
        eventId: '123e4567-e89b-42d3-a456-426614174001',
      ),
      ingress: LoopNotificationIngress.interaction,
      session: authenticated,
    );
    final system = instance.route(
      data: _payload(
        kind: LoopNotificationRouter.systemNoticeKind,
        eventId: '123e4567-e89b-42d3-a456-426614174002',
      ),
      ingress: LoopNotificationIngress.interaction,
      session: authenticated,
    );

    expect(audio.intent, isA<LoopAudioRoomNotificationIntent>());
    expect(audio.intent?.location, '/chat/voice');
    expect(system.intent, isA<LoopNotificationCenterIntent>());
    expect(system.intent?.location, '/notifications');
  });

  test('delivery never navigates and does not consume a later interaction', () {
    final instance = router();
    final data = _payload(kind: LoopNotificationRouter.chatMessageKind);

    final foreground = instance.route(
      data: data,
      ingress: LoopNotificationIngress.foreground,
      session: authenticated,
    );
    final background = instance.route(
      data: data,
      ingress: LoopNotificationIngress.background,
      session: authenticated,
    );
    final interaction = instance.route(
      data: data,
      ingress: LoopNotificationIngress.interaction,
      session: authenticated,
    );

    expect(
      foreground.disposition,
      LoopNotificationDisposition.foregroundObserved,
    );
    expect(foreground.intent, isNull);
    expect(
      background.disposition,
      LoopNotificationDisposition.backgroundDeferred,
    );
    expect(background.intent, isNull);
    expect(
      interaction.disposition,
      LoopNotificationDisposition.navigationReady,
    );
  });

  test('one process claims the same interaction only once', () {
    final instance = router();
    final data = _payload(kind: LoopNotificationRouter.systemNoticeKind);

    final first = instance.route(
      data: data,
      ingress: LoopNotificationIngress.interaction,
      session: authenticated,
    );
    final duplicate = instance.route(
      data: data,
      ingress: LoopNotificationIngress.interaction,
      session: authenticated,
    );

    expect(first.disposition, LoopNotificationDisposition.navigationReady);
    expect(
      duplicate.disposition,
      LoopNotificationDisposition.duplicateInteraction,
    );
    expect(duplicate.intent, isNull);
  });

  test('session and server-derived recipient gates fail closed', () {
    final instance = router();
    final data = _payload(kind: LoopNotificationRouter.chatMessageKind);

    expect(
      instance
          .route(
            data: data,
            ingress: LoopNotificationIngress.interaction,
            session: const LoopNotificationSessionContext.restoring(),
          )
          .disposition,
      LoopNotificationDisposition.sessionDeferred,
    );
    expect(
      instance
          .route(
            data: data,
            ingress: LoopNotificationIngress.interaction,
            session: const LoopNotificationSessionContext.ineligible(),
          )
          .disposition,
      LoopNotificationDisposition.sessionRejected,
    );
    expect(
      instance
          .route(
            data: data,
            ingress: LoopNotificationIngress.interaction,
            session: const LoopNotificationSessionContext.authenticated(
              'loop_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            ),
          )
          .disposition,
      LoopNotificationDisposition.recipientMismatch,
    );
  });

  test('unknown provider-like and expanded payloads are malformed', () {
    final instance = router();
    final cases = <Map<String, Object?>>[
      <String, Object?>{
        'type': 'message.new',
        'cid': 'messaging:loop-room-42',
        'message_id': 'provider-message',
      },
      <String, Object?>{
        'sender': 'stream.video',
        'type': 'call.ring',
        'call_cid': 'audio_room:untrusted-room',
      },
      _payload(kind: LoopNotificationRouter.audioRoomActivityKind)
        ..['room_id'] = 'untrusted-room',
      _payload(kind: LoopNotificationRouter.chatMessageKind)
        ..['title'] = 'untrusted body marker',
      _payload(kind: LoopNotificationRouter.chatMessageKind)
        ..['loop_schema'] = 'notification.v2',
      _payload(kind: 'chat.unknown'),
      _payload(kind: LoopNotificationRouter.chatMessageKind)
        ..['cid'] = 'livestream:loop-room-42',
      _payload(kind: LoopNotificationRouter.chatMessageKind)
        ..['cid'] = 'messaging:bad\u0000room',
      _payload(kind: LoopNotificationRouter.chatMessageKind)
        ..['event_id'] = 'not-a-canonical-uuid',
      _payload(kind: LoopNotificationRouter.chatMessageKind)
        ..['expires_at'] = 42,
    ];

    for (final data in cases) {
      final decision = instance.route(
        data: data,
        ingress: LoopNotificationIngress.interaction,
        session: authenticated,
      );
      expect(
        decision.disposition,
        LoopNotificationDisposition.malformed,
        reason: '$data',
      );
      expect(decision.intent, isNull);
    }
  });

  test('canonical lifetime, future skew, and expiry are enforced', () {
    final instance = router();
    final invalidFormat = _payload(
      kind: LoopNotificationRouter.systemNoticeKind,
    )..['occurred_at'] = '2026-08-25T11:59:00Z';
    final future = _payload(kind: LoopNotificationRouter.systemNoticeKind)
      ..['occurred_at'] = '2026-08-25T12:05:00.001Z';
    final excessiveLifetime =
        _payload(kind: LoopNotificationRouter.systemNoticeKind)
          ..['occurred_at'] = '2026-08-25T12:00:00.000Z'
          ..['expires_at'] = '2026-09-01T12:00:00.001Z';
    final expired = _payload(kind: LoopNotificationRouter.systemNoticeKind)
      ..['occurred_at'] = '2026-08-25T11:00:00.000Z'
      ..['expires_at'] = '2026-08-25T12:00:00.000Z';

    for (final data in <Map<String, Object?>>[
      invalidFormat,
      future,
      excessiveLifetime,
    ]) {
      expect(
        instance
            .route(
              data: data,
              ingress: LoopNotificationIngress.interaction,
              session: authenticated,
            )
            .disposition,
        LoopNotificationDisposition.invalidTime,
      );
    }
    expect(
      instance
          .route(
            data: expired,
            ingress: LoopNotificationIngress.interaction,
            session: authenticated,
          )
          .disposition,
      LoopNotificationDisposition.expired,
    );
  });

  test(
    'interaction receipt memory is bounded and does not claim payload data',
    () {
      final instance = router(capacity: 1);
      final first = _payload(
        kind: LoopNotificationRouter.systemNoticeKind,
        eventId: '123e4567-e89b-42d3-a456-426614174001',
      );
      final second = _payload(
        kind: LoopNotificationRouter.systemNoticeKind,
        eventId: '123e4567-e89b-42d3-a456-426614174002',
      );

      for (final data in <Map<String, Object?>>[first, second, first]) {
        expect(
          instance
              .route(
                data: data,
                ingress: LoopNotificationIngress.interaction,
                session: authenticated,
              )
              .disposition,
          LoopNotificationDisposition.navigationReady,
        );
      }

      const marker = 'secret-notification-body-marker';
      final malformed = _payload(kind: LoopNotificationRouter.systemNoticeKind)
        ..['body'] = marker;
      final decision = instance.route(
        data: malformed,
        ingress: LoopNotificationIngress.interaction,
        session: authenticated,
      );
      expect(decision.toString(), isNot(contains(marker)));
    },
  );

  test('invalid process receipt capacity is rejected', () {
    expect(
      () => LoopNotificationRouter(openedEventCapacity: 0),
      throwsArgumentError,
    );
    expect(
      () => LoopNotificationRouter(openedEventCapacity: 1025),
      throwsArgumentError,
    );
  });
}

Map<String, Object?> _payload({
  required String kind,
  String eventId = '123e4567-e89b-42d3-a456-426614174000',
  String cid = 'messaging:loop-room-42',
}) {
  return <String, Object?>{
    'loop_schema': LoopNotificationRouter.schema,
    'event_id': eventId,
    'recipient_stream_user_id': 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
    'kind': kind,
    'occurred_at': '2026-08-25T11:59:00.000Z',
    'expires_at': '2026-08-25T12:10:00.000Z',
    if (kind == LoopNotificationRouter.chatMessageKind) 'cid': cid,
  };
}
