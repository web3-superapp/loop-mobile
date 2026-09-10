import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/notifications/loop_notification_router.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

void main() {
  group('watchlist-edit', () {
    testWidgets('loading shows a skeleton and no count', (tester) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(pending: true),
        ),
        settle: false,
      );

      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(find.textContaining('个自选资产'), findsNothing);
    });

    testWidgets('a row that is no longer readable is still listed', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(),
      );

      expect(find.text('3 个自选资产'), findsOneWidget);
      expect(find.text('不可读'), findsOneWidget);
      expect(find.textContaining('这个资产已经读不到'), findsOneWidget);
      // No price is rendered: the Watchlist is not a market fact.
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('removing asks for a second confirmation first', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway();
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: watchlist,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('watchlist-remove-$s5WbnbAssetId')),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 个自选资产'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-remove-confirm')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 个自选资产'), findsOneWidget);
      // Nothing is committed until the explicit save.
      expect(watchlist.written, isEmpty);
    });

    testWidgets('saving sends the CAS version and the new order', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway();
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: watchlist,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('watchlist-remove-$s5UsdtAssetId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-remove-confirm')),
      );
      await tester.pumpAndSettle();

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('watchlist-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('watchlist-save')));
      await tester.pumpAndSettle();

      expect(watchlist.expectedVersions, <int>[1]);
      expect(
        watchlist.written.single.single.items.map((item) => item.assetId),
        <String>[s5WbnbAssetId, s5NativeAssetId],
      );
      expect(find.text('自选已保存'), findsOneWidget);
    });

    testWidgets('a version conflict keeps the draft and blocks re-apply', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway(
        replaceFailure: LoopChainFailureKind.versionConflict,
      );
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: watchlist,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('watchlist-remove-$s5UsdtAssetId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-remove-confirm')),
      );
      await tester.pumpAndSettle();
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('watchlist-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('watchlist-save')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('watchlist-conflict')),
        findsOneWidget,
      );
      expect(find.textContaining('没有覆盖任何内容'), findsOneWidget);
      // The local draft survives the conflict.
      expect(find.text('2 个自选资产'), findsOneWidget);
      expect(find.text('自选已保存'), findsNothing);
    });

    testWidgets('a conflict names what a reload would discard', (tester) async {
      final watchlist = FakeWatchlistGateway(
        replaceFailure: LoopChainFailureKind.versionConflict,
      );
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: watchlist,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('watchlist-remove-$s5UsdtAssetId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-remove-confirm')),
      );
      await tester.pumpAndSettle();
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('watchlist-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('watchlist-save')));
      await tester.pumpAndSettle();

      // A reload is destructive, so it is offered only beside a list of
      // exactly what it discards.
      expect(
        find.byKey(const ValueKey<String>('watchlist-conflict-diff')),
        findsOneWidget,
      );
      expect(find.textContaining('Mining：移除 1 项'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('watchlist-conflict-reload')),
        findsOneWidget,
      );
    });

    testWidgets('the draft can be copied before a reload discards it', (
      tester,
    ) async {
      final writes = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') writes.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(
          replaceFailure: LoopChainFailureKind.versionConflict,
        ),
      );

      await tester.tap(
        find.byKey(ValueKey<String>('watchlist-remove-$s5UsdtAssetId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-remove-confirm')),
      );
      await tester.pumpAndSettle();
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('watchlist-save')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('watchlist-save')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('watchlist-conflict-copy-draft')),
      );
      await tester.pumpAndSettle();

      final copied =
          (writes.single.arguments as Map<Object?, Object?>)['text']! as String;
      expect(copied, contains(s5WbnbAssetId));
      expect(copied, contains(s5NativeAssetId));
      // The removed row is not in the copy: the draft is what would be lost.
      expect(copied, isNot(contains(s5UsdtAssetId)));
      expect(find.text('草稿已复制'), findsOneWidget);
    });

    testWidgets('an unavailable capability stops the editor', (tester) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(),
        meta: s5MetaSnapshot(
          watchlist: LoopV2CapabilityAvailability.unavailable,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('watchlist-capability-block')),
        findsOneWidget,
      );
    });
  });

  group('alerts', () {
    testWidgets('an alert row states its state and evaluation time', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(),
      );

      expect(find.text('1 个提醒正在监听'), findsOneWidget);
      expect(find.text('WBNB 涨到 800.5'), findsOneWidget);
      expect(find.textContaining('评估于'), findsOneWidget);
    });

    testWidgets('an alert never evaluated says so instead of guessing', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(
          page: S5Answer<LoopAlertPage>(
            value: LoopAlertPage(
              items: <LoopPriceAlert>[
                LoopPriceAlert(
                  alertId: s5AlertId,
                  assetId: s5WbnbAssetId,
                  asset: s5Summary(),
                  condition: LoopAlertCondition.below,
                  threshold: s5Decimal('600'),
                  thresholdText: '600',
                  expiresAt: null,
                  state: LoopAlertState.active,
                  triggeredAt: null,
                  lastEvaluatedAt: null,
                  delivery: const LoopUnavailable('PUSH_RUNTIME_DEFERRED'),
                  version: 1,
                  createdAt: DateTime.utc(2026, 9, 8),
                  updatedAt: DateTime.utc(2026, 9, 8),
                ),
              ],
              nextCursor: null,
            ),
          ),
        ),
        notifications: FakeNotificationsGateway(),
      );

      expect(find.textContaining('评估器还没有看过这条'), findsOneWidget);
    });

    testWidgets('a malformed threshold never leaves the editor', (
      tester,
    ) async {
      final alerts = FakeAlertsGateway();
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(assetId: s5WbnbAssetId),
        alerts: alerts,
        notifications: FakeNotificationsGateway(),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('alerts-create-action')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('alert-threshold-field')),
        '0',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('alert-editor-submit')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('alert-editor-error')),
        findsOneWidget,
      );
      expect(alerts.created, isEmpty);
    });

    testWidgets('creating sends the exact threshold string', (tester) async {
      final alerts = FakeAlertsGateway();
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(assetId: s5WbnbAssetId),
        alerts: alerts,
        notifications: FakeNotificationsGateway(),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('alerts-create-action')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('alert-threshold-field')),
        '800.500',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('alert-editor-submit')),
      );
      await tester.pumpAndSettle();

      expect(alerts.created.single.threshold, '800.500');
      expect(alerts.created.single.assetId, s5WbnbAssetId);
      expect(find.text('提醒已保存'), findsOneWidget);
    });

    testWidgets('editing sends the alert version as the CAS input', (
      tester,
    ) async {
      final alerts = FakeAlertsGateway(
        page: S5Answer<LoopAlertPage>(
          value: LoopAlertPage(
            items: <LoopPriceAlert>[s5Alert(version: 4)],
            nextCursor: null,
          ),
        ),
      );
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: alerts,
        notifications: FakeNotificationsGateway(),
      );

      await tester.tap(find.byKey(ValueKey<String>('alert-$s5AlertId')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('alert-editor-submit')),
      );
      await tester.pumpAndSettle();

      expect(alerts.expectedVersions, <int>[4]);
      expect(alerts.updated.single.threshold, '800.5');
    });

    testWidgets('deleting a triggered alert sends its version', (tester) async {
      final alerts = FakeAlertsGateway(
        page: S5Answer<LoopAlertPage>(
          value: LoopAlertPage(
            items: <LoopPriceAlert>[
              s5Alert(state: LoopAlertState.triggered, version: 2),
            ],
            nextCursor: null,
          ),
        ),
      );
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: alerts,
        notifications: FakeNotificationsGateway(),
      );

      await tester.tap(find.byKey(ValueKey<String>('alert-$s5AlertId')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('alert-editor-delete')),
      );
      await tester.pumpAndSettle();

      expect(alerts.deleted, <String>[s5AlertId]);
      expect(alerts.expectedVersions, <int>[2]);
      expect(find.text('提醒已删除'), findsOneWidget);
    });

    testWidgets('the trigger history is the price-alert feed', (tester) async {
      final notifications = FakeNotificationsGateway();
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: notifications,
      );

      await scrollToS5Section(
        tester,
        find.byKey(ValueKey<String>('alerts-feed-$s5NotificationId')),
      );
      expect(find.textContaining('WBNB 触发 700（观察值 747.39）'), findsOneWidget);
      expect(find.textContaining('来源 dexscreener'), findsOneWidget);
      expect(find.text('未读'), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey<String>('alerts-feed-$s5NotificationId')),
      );
      await tester.pumpAndSettle();
      expect(notifications.read, <String>[s5NotificationId]);
      expect(find.text('未读'), findsNothing);
    });

    testWidgets('a feed entry highlights exactly the alert it references', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(
          page: S5Answer<LoopAlertPage>(
            value: LoopAlertPage(
              items: <LoopPriceAlert>[
                s5Alert(),
                LoopPriceAlert(
                  alertId: s5OtherWalletId,
                  assetId: s5UsdtAssetId,
                  asset: s5Summary(symbol: 'USDT'),
                  condition: LoopAlertCondition.below,
                  threshold: s5Decimal('1'),
                  thresholdText: '1',
                  expiresAt: null,
                  state: LoopAlertState.active,
                  triggeredAt: null,
                  lastEvaluatedAt: DateTime.utc(2026, 9, 8, 7),
                  delivery: const LoopUnavailable('PUSH_RUNTIME_DEFERRED'),
                  version: 1,
                  createdAt: DateTime.utc(2026, 9, 8),
                  updatedAt: DateTime.utc(2026, 9, 8),
                ),
              ],
              nextCursor: null,
            ),
          ),
        ),
        notifications: FakeNotificationsGateway(),
      );

      // The feed's `entityRef` is `priceAlert:<alertId>`, so exactly the row it
      // names is highlighted; the other alert is untouched even though both
      // are active.
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('alert-$s5AlertId')),
          matching: find.text('本次触发'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('alert-$s5OtherWalletId')),
          matching: find.text('本次触发'),
        ),
        findsNothing,
      );
      expect(find.textContaining('通知已记录这次触发'), findsOneWidget);
    });

    testWidgets('no feed entry means no alert row is highlighted', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(
          feed: S5Answer<LoopNotificationFeed>(
            value: LoopNotificationFeed(
              items: const <LoopNotificationEntry>[],
              nextCursor: null,
              unreadCount: 0,
              push: const LoopUnavailable('PUSH_RUNTIME_DEFERRED'),
            ),
          ),
        ),
      );

      expect(find.byKey(ValueKey<String>('alert-$s5AlertId')), findsOneWidget);
      expect(find.text('本次触发'), findsNothing);
    });

    testWidgets('push is stated as unavailable, never as pending permission', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(),
      );

      expect(find.text('推送尚不可用'), findsOneWidget);
      expect(find.textContaining('需要系统通知权限'), findsNothing);
    });
  });

  group('notif-settings', () {
    testWidgets('renders the ten categories with security locked on', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
      );

      for (final category in LoopNotificationCategory.values) {
        await scrollToS5Section(
          tester,
          find.byKey(
            ValueKey<String>('notification-category-${category.wireName}'),
          ),
        );
      }
      // The detail line and the locked badge both say it; the switch is absent.
      expect(find.text('无法关闭'), findsNWidgets(2));
      expect(
        find.byKey(
          const ValueKey<String>('notification-switch-security.event'),
        ),
        findsNothing,
      );
    });

    testWidgets('a toggle commits under the CAS version with all ten keys', (
      tester,
    ) async {
      final notifications = FakeNotificationsGateway();
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: notifications,
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('notification-switch-community.all')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('notification-switch-community.all')),
      );
      await tester.pumpAndSettle();

      expect(notifications.expectedVersions, <int>[0]);
      final written = notifications.written.single;
      expect(written.length, LoopNotificationCategory.values.length);
      expect(written[LoopNotificationCategory.communityAll], isTrue);
      // The locked category is always submitted as true.
      expect(written[LoopNotificationCategory.securityEvent], isTrue);
      expect(find.text('通知设置已保存'), findsOneWidget);
    });

    testWidgets('a conflict keeps the page and asks for a reload', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(
          writeFailure: LoopChainFailureKind.versionConflict,
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('notification-switch-community.all')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('notification-switch-community.all')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('notification-preferences-conflict')),
        findsOneWidget,
      );
      expect(find.text('通知设置已保存'), findsNothing);
    });

    testWidgets('delivery is unavailable regardless of the saved intents', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
      );

      expect(find.text('推送尚不可用'), findsOneWidget);
      expect(find.textContaining('推送还没有开放'), findsWidgets);
    });

    testWidgets('an unavailable capability stops the page', (tester) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
        meta: s5MetaSnapshot(
          notificationsFeed: LoopV2CapabilityAvailability.unavailable,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('notification-capability-block')),
        findsOneWidget,
      );
    });
  });

  group('priceAlertTriggered intent', () {
    Map<String, Object?> envelope({
      String assetId = s5WbnbAssetId,
      String kind = LoopNotificationRouter.priceAlertTriggeredKind,
    }) => <String, Object?>{
      'loop_schema': LoopNotificationRouter.schema,
      'event_id': '7d9b0a1c-2e3f-4a5b-8c6d-7e8f9a0b1c2d',
      'recipient_stream_user_id': 'loop_abcdefgh12',
      'kind': kind,
      'occurred_at': '2026-09-08T07:31:00.000Z',
      'expires_at': '2026-09-08T09:31:00.000Z',
      'asset_id': assetId,
    };

    LoopNotificationDecision route(Map<String, Object?> data) {
      final router = LoopNotificationRouter(
        clock: () => DateTime.utc(2026, 9, 8, 8),
      );
      return router.route(
        data: data,
        ingress: LoopNotificationIngress.interaction,
        session: const LoopNotificationSessionContext.authenticated(
          'loop_abcdefgh12',
        ),
      );
    }

    test('an interaction opens the token page for that exact asset', () {
      final decision = route(envelope());

      expect(decision.disposition, LoopNotificationDisposition.navigationReady);
      expect(decision.intent, isA<LoopPriceAlertNotificationIntent>());
      expect(
        decision.intent!.location,
        '/market/token?assetId=${Uri.encodeQueryComponent(s5WbnbAssetId)}',
      );
    });

    test('a non-canonical assetId fails closed', () {
      final decision = route(envelope(assetId: 'PEPE'));

      expect(decision.disposition, LoopNotificationDisposition.malformed);
      expect(decision.intent, isNull);
    });

    test('a price-alert envelope without an assetId is malformed', () {
      final data = envelope()..remove('asset_id');

      expect(route(data).disposition, LoopNotificationDisposition.malformed);
    });

    test('an asset id on a chat envelope is an unknown key', () {
      final data = envelope(kind: LoopNotificationRouter.chatMessageKind);

      expect(route(data).disposition, LoopNotificationDisposition.malformed);
    });
  });
}
