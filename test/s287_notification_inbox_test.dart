// S287 · decision 0241: the notification centre under 聊天 (需求方
// 2026-10-22 第 10 条) — codec, router, page, bell.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/notifications/notification_bell.dart';
import 'package:loop_mobile/features/notifications/notification_inbox.dart';
import 'package:loop_mobile/features/notifications/notification_inbox_screen.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/notifications/notifications_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/notifications/loop_v2_notifications_api.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s287_notifications.dart';

const _token = 'privy-access-token';
Map<String, Object?> _row({
  required String id,
  required String type,
  String entityRef = 'launch2Instance:$s287InstanceId',
  String contextRoute = 'launch2-instance',
  Map<String, Object?> contextParams = const <String, Object?>{
    'instanceId': s287InstanceId,
  },
  Map<String, Object?> payload = const <String, Object?>{},
  Object? readAt,
  bool withReadAt = true,
}) => <String, Object?>{
  'notificationId': id,
  'type': type,
  'entityRef': entityRef,
  'contextRoute': contextRoute,
  'contextParams': contextParams,
  'payload': payload,
  'source': null,
  'observedAt': null,
  if (withReadAt) 'readAt': readAt,
  'createdAt': '2026-10-22T06:00:00.000Z',
};

Map<String, Object?> _feed(List<Map<String, Object?>> items) =>
    <String, Object?>{
      'items': items,
      'nextCursor': null,
      'unreadCount': 1,
      'push': s5Unavailable('PUSH_RUNTIME_DEFERRED'),
      'contractVersion': '2.0',
    };

Finder _key(String value) => find.byKey(ValueKey<String>(value));

void main() {
  loopWatchGround();

  group('codec', () {
    Future<LoopNotificationFeed> decode(List<Map<String, Object?>> rows) {
      final api = DioLoopV2NotificationsApi(
        s5Dio((options, handler) {
          handler.resolve(s5Response(options, _feed(rows)));
        }),
      );
      return api.getFeed(accessToken: _token, clientVersion: s5ClientVersion);
    }

    test('the four new types decode with their kind and category', () async {
      final feed = await decode(<Map<String, Object?>>[
        _row(id: s287Id(1), type: 'launch.graduated'),
        _row(id: s287Id(2), type: 'launch.badge_minted'),
        _row(
          id: s287Id(3),
          type: 'social.friend_request',
          entityRef: 'friendRequest:$s287RequestId',
          contextRoute: 'dm-requests',
          contextParams: const <String, Object?>{},
        ),
        _row(
          id: s287Id(4),
          type: 'social.friend_accepted',
          entityRef: 'friendRequest:$s287RequestId',
          contextRoute: 'user-profile',
          contextParams: const <String, Object?>{
            'publicProfileId': s287ProfileId,
          },
        ),
      ]);

      expect(feed.items.map((entry) => entry.kind), <LoopNotificationKind>[
        LoopNotificationKind.launchGraduated,
        LoopNotificationKind.launchBadgeMinted,
        LoopNotificationKind.friendRequest,
        LoopNotificationKind.friendAccepted,
      ]);
      // None of them is a preference category by name, so no category
      // reader (alerts, token page, 我) picks them up.
      expect(feed.items.every((entry) => entry.type == null), isTrue);
      expect(feed.priceAlerts, isEmpty);
      expect(
        feed.items.first.category,
        LoopNotificationCategory.launchGraduation,
      );
    });

    test('an unknown type is kept and drawn plainly, not refused', () async {
      final feed = await decode(<Map<String, Object?>>[
        s5NotificationBody(),
        _row(
          id: s287Id(9),
          type: 'mining.something_new',
          contextRoute: 'mining-new',
          payload: const <String, Object?>{'title': '新事件', 'body': '正文'},
        ),
      ]);

      expect(feed.items, hasLength(2));
      final unknown = feed.items.last;
      expect(unknown.type, isNull);
      expect(unknown.kind, isNull);
      expect(unknown.rawType, 'mining.something_new');
      final view = loopNotificationPresentation(unknown);
      expect(view.icon, 'bell');
      expect(view.title, '新事件');
      expect(view.body, '正文');
      // The price alert next to it is untouched.
      expect(feed.priceAlerts, hasLength(1));
    });

    test(
      'readAt: null is unread, a time is read, a missing key is read',
      () async {
        final feed = await decode(<Map<String, Object?>>[
          _row(id: s287Id(1), type: 'launch.graduated'),
          _row(
            id: s287Id(2),
            type: 'launch.graduated',
            readAt: '2026-10-22T07:00:00.000Z',
          ),
          _row(id: s287Id(3), type: 'launch.graduated', withReadAt: false),
        ]);

        expect(feed.items.map((entry) => entry.isUnread), <bool>[
          true,
          false,
          false,
        ]);
        expect(feed.items.last.readStateKnown, isFalse);
      },
    );

    test('a fifth unknown key is still an invalid row', () async {
      await expectLater(
        decode(<Map<String, Object?>>[
          <String, Object?>{
            ..._row(id: s287Id(1), type: 'launch.graduated'),
            'extra': 'x',
          },
        ]),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('unread-count decodes with or without the contract stamp', () async {
      for (final body in <Map<String, Object?>>[
        <String, Object?>{'unread': 5, 'observedAt': '2026-10-22T07:00:00Z'},
        <String, Object?>{
          'unread': 120,
          'observedAt': '2026-10-22T07:00:00Z',
          'contractVersion': '2.0',
        },
      ]) {
        RequestOptions? captured;
        final api = DioLoopV2NotificationsApi(
          s5Dio((options, handler) {
            captured = options;
            handler.resolve(s5Response(options, body));
          }),
        );
        final count = await api.getUnreadCount(
          accessToken: _token,
          clientVersion: s5ClientVersion,
        );
        expect(count?.unread, body['unread']);
        expect(captured!.path, '/v2/notifications/unread-count');
        expect(captured!.headers.containsKey('idempotency-key'), isFalse);
      }
    });

    test('a 404 from either new endpoint is an absent endpoint', () async {
      final api = DioLoopV2NotificationsApi(
        s5Dio(
          (options, handler) => handler.reject(
            s5ErrorResponse(options, statusCode: 404, code: 'NOT_FOUND'),
          ),
        ),
      );

      expect(
        await api.getUnreadCount(
          accessToken: _token,
          clientVersion: s5ClientVersion,
        ),
        isNull,
      );
      expect(
        await api.markAllRead(
          accessToken: _token,
          clientVersion: s5ClientVersion,
          idempotencyKey: s5OtherWalletId,
        ),
        isNull,
      );
    });

    test('another failure is still a failure', () async {
      final api = DioLoopV2NotificationsApi(
        s5Dio(
          (options, handler) => handler.reject(
            s5ErrorResponse(options, statusCode: 500, code: 'INTERNAL_ERROR'),
          ),
        ),
      );

      await expectLater(
        api.getUnreadCount(accessToken: _token, clientVersion: s5ClientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('read-all carries an idempotency key and answers the count', () async {
      RequestOptions? captured;
      final api = DioLoopV2NotificationsApi(
        s5Dio((options, handler) {
          captured = options;
          handler.resolve(
            s5Response(options, <String, Object?>{
              'marked': 7,
              'contractVersion': '2.0',
            }),
          );
        }),
      );

      final marked = await api.markAllRead(
        accessToken: _token,
        clientVersion: s5ClientVersion,
        idempotencyKey: s5OtherWalletId,
      );

      expect(marked, 7);
      expect(captured!.method, 'POST');
      expect(captured!.path, '/v2/notifications/read-all');
      expect(captured!.headers['idempotency-key'], s5OtherWalletId);
    });

    test('a malformed count is an invalid payload', () async {
      final api = DioLoopV2NotificationsApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, <String, Object?>{
              'unread': -1,
              'observedAt': '2026-10-22T07:00:00Z',
            }),
          ),
        ),
      );

      await expectLater(
        api.getUnreadCount(accessToken: _token, clientVersion: s5ClientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('router', () {
    final router = LoopNotificationRouter(
      clock: () => DateTime.utc(2026, 10, 22, 12),
    );
    const authenticated = LoopNotificationSessionContext.authenticated();

    LoopNotificationDecision route(
      String type,
      String entityRef,
      String contextRoute,
    ) => router.route(
      data: <String, Object?>{
        'type': type,
        'entityRef': entityRef,
        'contextRoute': contextRoute,
        'eventVersion': '1',
      },
      ingress: LoopNotificationIngress.interaction,
      session: authenticated,
    );

    final cases =
        <
          (
            LoopPushNotificationType,
            String,
            String,
            LoopNotificationContext,
            String,
            String,
          )
        >[
          (
            LoopPushNotificationType.launchGraduated,
            'launch2Instance:$s287InstanceId',
            'launch2-instance',
            const LoopNotificationContext(
              contextRoute: 'launch2-instance',
              instanceId: s287InstanceId,
            ),
            '/launch2/instance?id=$s287InstanceId',
            'dm-requests',
          ),
          (
            LoopPushNotificationType.launchBadgeMinted,
            'launch2Instance:7a1b2c3d-4e5f-4a6b-8c7d-000000000001',
            'launch2-instance',
            const LoopNotificationContext(
              contextRoute: 'launch2-instance',
              instanceId: s287InstanceId,
            ),
            '/launch2/instance?id=$s287InstanceId',
            'token',
          ),
          (
            LoopPushNotificationType.friendRequest,
            'friendRequest:$s287RequestId',
            'dm-requests',
            const LoopNotificationContext(contextRoute: 'dm-requests'),
            '/chat/requests',
            'user-profile',
          ),
          (
            LoopPushNotificationType.friendAccepted,
            'friendRequest:0f1e2d3c-4b5a-4968-8776-000000000002',
            'user-profile',
            const LoopNotificationContext(
              contextRoute: 'user-profile',
              publicProfileId: s287ProfileId,
            ),
            '/profile/user?id=$s287ProfileId',
            'launch2-instance',
          ),
        ];

    for (final (type, entityRef, contextRoute, context, location, wrong)
        in cases) {
      test('${type.wireName} opens what the feed confirmed', () {
        final decision = route(type.wireName, entityRef, contextRoute);
        expect(decision.disposition, LoopNotificationDisposition.pointerReady);
        expect(decision.pointer?.type, type);
        expect(
          LoopNotificationRouter.resolve(
            decision.pointer!,
            context: context,
          ).location,
          location,
        );
      });

      test('${type.wireName} paired with $wrong is refused', () {
        final decision = route(type.wireName, entityRef, wrong);
        expect(decision.disposition, LoopNotificationDisposition.malformed);
        expect(decision.pointer, isNull);
      });
    }

    test('an unconfirmed graduation or acceptance names nothing', () {
      final graduated = route(
        'launch.graduated',
        'launch2Instance:7a1b2c3d-4e5f-4a6b-8c7d-0000000000aa',
        'launch2-instance',
      );
      expect(
        LoopNotificationRouter.resolve(graduated.pointer!).location,
        '/meme',
      );
      final accepted = route(
        'social.friend_accepted',
        'friendRequest:0f1e2d3c-4b5a-4968-8776-0000000000bb',
        'user-profile',
      );
      expect(
        LoopNotificationRouter.resolve(accepted.pointer!).location,
        '/chat',
      );
    });

    test('a wrong entity kind or an unknown type still fails closed', () {
      expect(
        route(
          'launch.graduated',
          'friendRequest:$s287RequestId',
          'launch2-instance',
        ).disposition,
        LoopNotificationDisposition.malformed,
      );
      expect(
        route(
          'launch.something_else',
          'launch2Instance:$s287InstanceId',
          'launch2-instance',
        ).disposition,
        LoopNotificationDisposition.malformed,
      );
    });

    test('a feed record resolves through the same validation', () {
      String? record(String route, [Map<String, String> params = const {}]) =>
          LoopNotificationRouter.resolveRecord(
            LoopNotificationContext(
              contextRoute: route,
              assetId: params['assetId'],
              communityId: params['communityId'],
              instanceId: params['instanceId'],
              publicProfileId: params['publicProfileId'],
            ),
          )?.location;

      expect(
        record('launch2-instance', <String, String>{
          'instanceId': s287InstanceId,
        }),
        '/launch2/instance?id=$s287InstanceId',
      );
      expect(
        record('launch2-instance', <String, String>{'instanceId': 'nope'}),
        '/meme',
      );
      expect(record('dm-requests'), '/chat/requests');
      expect(
        record('user-profile', <String, String>{
          'publicProfileId': s287ProfileId,
        }),
        '/profile/user?id=$s287ProfileId',
      );
      expect(record('devices'), '/profile/devices');
      expect(record('token'), '/market/alerts');
      expect(record('somewhere-new'), isNull);
    });
  });

  group('notification centre', () {
    testWidgets('groups 今天 / 更早 with an unread dot and a bold title', (
      tester,
    ) async {
      await pumpS287Inbox(
        tester,
        S287NotificationsGateway(items: s287MixedRows()),
      );

      expect(_key('notification-inbox-day-today'), findsOneWidget);
      expect(_key('notification-inbox-day-earlier'), findsOneWidget);
      final todayY = tester.getTopLeft(_key('notification-inbox-day-today')).dy;
      final earlierY = tester
          .getTopLeft(_key('notification-inbox-day-earlier'))
          .dy;
      expect(
        tester.getTopLeft(_key('notification-row-${s287Id(2)}')).dy,
        allOf(greaterThan(todayY), lessThan(earlierY)),
      );
      expect(
        tester.getTopLeft(_key('notification-row-${s287Id(3)}')).dy,
        greaterThan(earlierY),
      );

      // Unread: the dot and a bold title. Read: neither.
      expect(_key('notification-unread-${s287Id(1)}'), findsOneWidget);
      expect(_key('notification-unread-${s287Id(2)}'), findsNothing);
      FontWeight? weight(String id) =>
          tester.widget<Text>(_key('notification-title-$id')).style?.fontWeight;
      expect(weight(s287Id(1)), FontWeight.w700);
      expect(weight(s287Id(2)), FontWeight.w400);

      // Each kind has its glyph and its own sentence.
      expect(_key('notification-icon-${s287Id(1)}-graduate'), findsOneWidget);
      expect(_key('notification-icon-${s287Id(2)}-user'), findsOneWidget);
      expect(_key('notification-icon-${s287Id(3)}-crown'), findsOneWidget);
      expect(_key('notification-icon-${s287Id(4)}-users'), findsOneWidget);
      expect(_key('notification-icon-${s287Id(5)}-bell'), findsOneWidget);
      expect(find.text('FROG 已毕业'), findsOneWidget);
      expect(find.text('Nightowl 想加你为好友'), findsOneWidget);
      expect(find.text('FROG · #12'), findsOneWidget);
      expect(find.text('一条新通知'), findsOneWidget);
      expect(find.text('未读 3 条'), findsOneWidget);
    });

    testWidgets('a tap marks the row read, then opens its destination', (
      tester,
    ) async {
      final gateway = S287NotificationsGateway(items: s287MixedRows());
      final opened = await pumpS287Inbox(tester, gateway);

      await tester.tap(_key('notification-row-${s287Id(1)}'));
      await tester.pumpAndSettle();

      expect(gateway.read, <String>[s287Id(1)]);
      expect(opened, <String>['/launch2/instance?id=$s287InstanceId']);
      expect(_key('notification-unread-${s287Id(1)}'), findsNothing);
      expect(
        tester
            .widget<Text>(_key('notification-title-${s287Id(1)}'))
            .style
            ?.fontWeight,
        FontWeight.w400,
      );

      // A read row is not written again; it still opens.
      await tester.tap(_key('notification-row-${s287Id(4)}'));
      await tester.pumpAndSettle();
      expect(gateway.read, <String>[s287Id(1)]);
      expect(opened.last, '/profile/user?id=$s287ProfileId');
    });

    testWidgets('a row with an unknown destination is only marked read', (
      tester,
    ) async {
      final gateway = S287NotificationsGateway(items: s287MixedRows());
      final opened = await pumpS287Inbox(tester, gateway);

      await tester.tap(_key('notification-row-${s287Id(5)}'));
      await tester.pumpAndSettle();

      expect(gateway.read, <String>[s287Id(5)]);
      expect(opened, isEmpty);
    });

    testWidgets('全部已读 uses read-all when the server has it', (tester) async {
      final gateway = S287NotificationsGateway(items: s287MixedRows())
        ..readAllAnswer = 3;
      await pumpS287Inbox(tester, gateway);

      await tester.tap(_key('notification-inbox-read-all'));
      await tester.pumpAndSettle();

      expect(gateway.readAllCalls, 1);
      expect(gateway.read, isEmpty);
      for (final n in <int>[1, 3, 5]) {
        expect(_key('notification-unread-${s287Id(n)}'), findsNothing);
      }
      expect(_key('notification-inbox-read-all'), findsNothing);
      expect(find.text('已全部标为已读'), findsOneWidget);
      await tester.pump(LoopToast.defaultDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('全部已读 falls back to row by row on a 404', (tester) async {
      final gateway = S287NotificationsGateway(items: s287MixedRows());
      await pumpS287Inbox(tester, gateway);

      await tester.tap(_key('notification-inbox-read-all'));
      await tester.pumpAndSettle();

      expect(gateway.readAllCalls, 1);
      expect(gateway.read, <String>[s287Id(1), s287Id(3), s287Id(5)]);
      expect(_key('notification-unread-${s287Id(3)}'), findsNothing);
      await tester.pump(LoopToast.defaultDuration);
      await tester.pumpAndSettle();
    });

    testWidgets('the settings entry opens notif-settings', (tester) async {
      final settings = <String>[];
      await pumpS287Inbox(
        tester,
        S287NotificationsGateway(items: s287MixedRows()),
        settingsOpened: settings,
      );

      await tester.tap(_key('notification-inbox-settings'));
      await tester.pumpAndSettle();
      expect(settings, <String>['notif-settings']);
    });

    testWidgets('empty: 还没有通知, and no read-all', (tester) async {
      await pumpS287Inbox(tester, S287NotificationsGateway());

      expect(_key('notification-inbox-empty'), findsOneWidget);
      expect(find.text('还没有通知'), findsOneWidget);
      expect(_key('notification-inbox-read-all'), findsNothing);
      expect(_key('notification-inbox-settings'), findsOneWidget);
    });

    testWidgets('error: a retry that reads again', (tester) async {
      final gateway = S287NotificationsGateway(
        items: s287MixedRows(),
        feedFailure: LoopChainFailureKind.readFailed,
      );
      await pumpS287Inbox(tester, gateway);

      expect(_key('notification-inbox-state-error'), findsOneWidget);
      gateway.feedFailure = null;
      await tester.tap(
        find.descendant(
          of: _key('notification-inbox-state-error'),
          matching: find.text('重试'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('notification-inbox-state-error'), findsNothing);
      expect(_key('notification-row-${s287Id(1)}'), findsOneWidget);
    });

    for (final (name, gateway, key)
        in <(String, S287NotificationsGateway Function(), String)>[
          (
            'offline',
            () => S287NotificationsGateway(
              feedFailure: LoopChainFailureKind.offline,
            ),
            'notification-inbox-state-offline',
          ),
          (
            'permission',
            () => S287NotificationsGateway(
              feedFailure: LoopChainFailureKind.permissionDenied,
            ),
            'notification-inbox-state-permission',
          ),
          (
            'unavailable',
            () => S287NotificationsGateway(
              mode: LoopChainGatewayMode.unavailable,
            ),
            'notification-inbox-state-unavailable',
          ),
        ]) {
      testWidgets('$name says so', (tester) async {
        await pumpS287Inbox(tester, gateway());
        expect(_key(key), findsOneWidget);
        expect(_key('notification-inbox-read-all'), findsNothing);
      });
    }

    testWidgets('loading draws the skeleton', (tester) async {
      final pending = Completer<void>();
      addTearDown(() {
        if (!pending.isCompleted) pending.complete();
      });
      await pumpS5Page(
        tester,
        const NotificationInboxScreen(),
        notifications: FakeNotificationsGateway(
          feed: S5Answer<LoopNotificationFeed>(pending: true),
        ),
        settle: false,
      );
      expect(_key('notification-inbox-state-loading'), findsOneWidget);
    });

    testWidgets('a Preview build says 演示数据', (tester) async {
      await pumpS287Inbox(
        tester,
        S287NotificationsGateway(
          items: s287MixedRows(),
          mode: LoopChainGatewayMode.preview,
        ),
      );
      expect(_key('chain-preview-notice'), findsOneWidget);
      expect(find.text('演示数据'), findsOneWidget);
    });

    testWidgets('the next page follows the feed cursor', (tester) async {
      final gateway = S287NotificationsGateway(
        items: s287MixedRows(),
        nextCursor: 'cursor-2',
      );
      gateway.pages['cursor-2'] = LoopNotificationFeed(
        items: <LoopNotificationEntry>[
          s287Entry(
            id: s287Id(6),
            rawType: 'launch.graduated',
            payload: const <String, String?>{'symbol': 'MOON'},
            createdAt: DateTime(2026, 10, 10, 9),
          ),
        ],
        nextCursor: null,
        unreadCount: 4,
        push: null,
      );
      await pumpS287Inbox(tester, gateway, size: const Size(390, 2400));

      expect(gateway.cursors, <String?>[null, 'cursor-2']);
      expect(_key('notification-row-${s287Id(6)}'), findsOneWidget);
      expect(find.text('MOON 已毕业'), findsOneWidget);
    });
  });

  group('grouping', () {
    test('a row from earlier today is 今天, yesterday is 更早', () {
      expect(
        loopNotificationDayOf(
          DateTime(2026, 10, 22, 0, 5).toUtc(),
          now: s287Now,
        ),
        LoopNotificationDay.today,
      );
      expect(
        loopNotificationDayOf(
          DateTime(2026, 10, 21, 23, 55).toUtc(),
          now: s287Now,
        ),
        LoopNotificationDay.earlier,
      );
      expect(
        loopNotificationGroups(const <LoopNotificationEntry>[], now: s287Now),
        isEmpty,
      );
    });
  });

  group('bell', () {
    Future<S287NotificationsGateway> pumpChat(
      WidgetTester tester, {
      int? unread,
      List<String>? opened,
    }) async {
      final gateway = S287NotificationsGateway()
        ..unread = unread == null
            ? null
            : LoopNotificationUnreadCount(
                unread: unread,
                observedAt: DateTime.utc(2026, 10, 22, 7),
              );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsGatewayProvider.overrideWithValue(gateway),
            streamChatAuthorizationProvider.overrideWith(
              (ref) => Future<StreamSessionAuthorization>.error(
                StateError('no chat in this test'),
              ),
            ),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: StreamChatInboxPage(
              onOpenNotifications: () => opened?.add('notifications'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return gateway;
    }

    testWidgets('0 unread draws a bare bell', (tester) async {
      final gateway = await pumpChat(tester, unread: 0);
      expect(_key('chat-notification-bell'), findsOneWidget);
      expect(_key('chat-notification-badge'), findsNothing);
      expect(gateway.unreadReads, 1);
    });

    testWidgets('5 unread prints 5', (tester) async {
      await pumpChat(tester, unread: 5);
      expect(
        find.descendant(
          of: _key('chat-notification-badge'),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('120 unread prints 99+', (tester) async {
      await pumpChat(tester, unread: 120);
      expect(
        find.descendant(
          of: _key('chat-notification-badge'),
          matching: find.text('99+'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a server without the endpoint draws no badge', (tester) async {
      await pumpChat(tester);
      expect(_key('chat-notification-bell'), findsOneWidget);
      expect(_key('chat-notification-badge'), findsNothing);
    });

    testWidgets('the bell opens the notification centre', (tester) async {
      final opened = <String>[];
      await pumpChat(tester, unread: 2, opened: opened);
      await tester.tap(_key('chat-notification-bell'));
      await tester.pumpAndSettle();
      expect(opened, <String>['notifications']);
    });

    testWidgets('a foreground return reads at most once a minute', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 10, 22, 7);
      final gateway = S287NotificationsGateway()
        ..unread = LoopNotificationUnreadCount(
          unread: 1,
          observedAt: DateTime.utc(2026, 10, 22, 7),
        );
      final container = ProviderContainer(
        overrides: [
          notificationsGatewayProvider.overrideWithValue(gateway),
          loopReadClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        notificationUnreadCountProvider.notifier,
      );

      await controller.refresh();
      await controller.refresh();
      expect(gateway.unreadReads, 1);
      expect(container.read(notificationUnreadCountProvider), 1);

      now = now.add(const Duration(seconds: 61));
      await controller.refresh();
      expect(gateway.unreadReads, 2);

      // A notification arriving, or a read in the centre, forces one.
      await controller.refresh(force: true);
      expect(gateway.unreadReads, 3);
    });

    testWidgets('a Preview build never asks', (tester) async {
      final gateway =
          S287NotificationsGateway(mode: LoopChainGatewayMode.preview)
            ..unread = LoopNotificationUnreadCount(
              unread: 4,
              observedAt: DateTime.utc(2026, 10, 22, 7),
            );
      final container = ProviderContainer(
        overrides: [notificationsGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      await container
          .read(notificationUnreadCountProvider.notifier)
          .refresh(force: true);
      expect(gateway.unreadReads, 0);
      expect(container.read(notificationUnreadCountProvider), isNull);
    });

    test('the bell widget is exported for the chat head', () {
      expect(const NotificationBellButton(onPressed: null), isA<Widget>());
    });
  });
}
