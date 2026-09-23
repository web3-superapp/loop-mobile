import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/notifications/loop_push_registration_diagnostics.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
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

    testWidgets('a hero over a partial list counts what it loaded', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(
          page: S5Answer<LoopAlertPage>(
            value: LoopAlertPage(
              items: <LoopPriceAlert>[s5Alert()],
              nextCursor: 'next',
            ),
          ),
        ),
        notifications: FakeNotificationsGateway(),
      );

      // One page of an unknown number: the hero may not call its armed rows
      // the alerts that are listening, and it never prints 「N ACTIVE」.
      expect(find.text('已载入 1 条提醒'), findsOneWidget);
      expect(find.textContaining('个提醒正在监听'), findsNothing);
      expect(find.textContaining('ACTIVE'), findsNothing);
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
      // 删除 asks before it deletes: the editor's own control opens a
      // confirmation rather than sitting beside 保存 and removing the alert
      // on one tap (S77a).
      await tester.tap(
        find.byKey(const ValueKey<String>('alert-delete-confirm-yes')),
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
      // A provider LOOP names elsewhere is named the same way here.
      expect(find.textContaining('来源 DexScreener'), findsOneWidget);
      expect(find.textContaining('来源 dexscreener'), findsNothing);
      // The alert id addresses the row this entry highlights; it is not copy.
      expect(find.textContaining('提醒 $s5AlertId'), findsNothing);
      expect(find.textContaining(s5AlertId), findsNothing);
      expect(find.text('未读'), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey<String>('alerts-feed-$s5NotificationId')),
      );
      await tester.pumpAndSettle();
      expect(notifications.read, <String>[s5NotificationId]);
      expect(find.text('未读'), findsNothing);
    });

    testWidgets('an internal source identifier never reaches the row', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(
          feed: S5Answer<LoopNotificationFeed>(
            value: s5Feed(
              items: <LoopNotificationEntry>[
                s5Notification(source: 'mock_seed'),
              ],
            ),
          ),
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(ValueKey<String>('alerts-feed-$s5NotificationId')),
      );
      // The contract leaves `source` an open identifier, so a pipeline name
      // arrives here as readily as a provider. A source a reader cannot check
      // is not provenance; the observation time still is.
      expect(find.textContaining('mock_seed'), findsNothing);
      expect(find.textContaining('来源'), findsNothing);
      expect(find.textContaining('观察于'), findsWidgets);
    });

    testWidgets('the token page drops the same internal source identifier', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        notifications: FakeNotificationsGateway(
          feed: S5Answer<LoopNotificationFeed>(
            value: s5Feed(
              items: <LoopNotificationEntry>[
                s5Notification(source: 'mock_seed'),
              ],
            ),
          ),
        ),
      );

      // S82a: 简介 carries the contract facts and this asset's notifications.
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-section-tabs')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('token-tab-简介')));
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey<String>('token-feed-$s5NotificationId'));
      await scrollToS5Section(tester, row);
      // Same rule as the trigger history: a source a reader cannot check is
      // not provenance, and the two pages state it the same way. The page's
      // own provider labels, which name providers, are untouched.
      final subtitle = tester.widget<LoopRecordRow>(row).subtitle;
      expect(subtitle, isNot(contains('mock_seed')));
      expect(subtitle, isNot(contains('来源')));
      expect(subtitle, contains('观察于'));
    });

    testWidgets('the trigger history pages to the end and says so', (
      tester,
    ) async {
      const secondId = '5f1c3c7e-6c9a-4b9e-9a4f-2c5d8e7b1a33';
      final notifications =
          FakeNotificationsGateway(
              feed: S5Answer<LoopNotificationFeed>(
                value: s5Feed(nextCursor: 'cursor-2'),
              ),
            )
            ..feedPages = <String, LoopNotificationFeed>{
              'cursor-2': s5Feed(
                items: <LoopNotificationEntry>[
                  s5Notification(notificationId: secondId, symbol: 'USDT'),
                ],
                unreadCount: 2,
              ),
            };
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: notifications,
      );

      final loadMore = find.byKey(
        const ValueKey<String>('alerts-feed-load-more'),
      );
      await scrollToS5Section(tester, loadMore);
      expect(
        find.byKey(const ValueKey<String>('alerts-feed-end')),
        findsNothing,
      );

      await tester.tap(loadMore);
      await tester.pumpAndSettle();

      // The first read carries no cursor, the second carries the server's and
      // never a limit beside it.
      expect(notifications.feedCursors, <String?>[null, 'cursor-2']);
      // Both pages are on the page, in the order the server gave them.
      expect(
        find.byKey(ValueKey<String>('alerts-feed-$s5NotificationId')),
        findsOneWidget,
      );
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('alerts-feed-$secondId')),
      );
      // The end of the list states that it is the end instead of just stopping.
      expect(loadMore, findsNothing);
      expect(find.text('没有更多触发记录'), findsOneWidget);
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
      // Once per screen: the feed footer printed the same sentence two lines
      // above the notice that owns it.
      expect(find.textContaining('推送还没有开放'), findsOneWidget);
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
      // The locked row says so on its own line, carries the 已开启 pill and
      // offers no control. The prototype has no slider anywhere, so neither
      // does this page (audit 2026-09-21 §D+ #12).
      expect(find.byType(Switch), findsNothing);
      final lockedRow = find.byKey(
        const ValueKey<String>('notification-category-security.event'),
      );
      expect(
        find.descendant(of: lockedRow, matching: find.textContaining('无法关闭')),
        findsOneWidget,
      );
      expect(tester.widget<LoopRecordRow>(lockedRow).onTap, isNull);
    });

    testWidgets('the summary counts what is delivered, not what is stored', (
      tester,
    ) async {
      // Nine of the ten switches are on in this fixture; only price alerts
      // are emitted, so 「9 项开启」 promised eight kinds of notification that
      // never arrive.
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
      );

      expect(find.text('1 项开启并生效'), findsOneWidget);
      expect(find.text('9 项开启'), findsNothing);

      // Every switch that stores an intent without producing anything says so
      // on its own row; the one that works carries no such mark. It is said
      // in the row's own second line, because a second pill beside the state
      // pill put two status controls on one row.
      for (final category in LoopNotificationCategory.values) {
        final row = find.byKey(
          ValueKey<String>('notification-category-${category.wireName}'),
        );
        await scrollToS5Section(tester, row);
        expect(
          find.descendant(of: row, matching: find.textContaining('暂不生效')),
          category == LoopNotificationCategory.tradePriceAlert
              ? findsNothing
              : findsOneWidget,
          reason: category.wireName,
        );
      }
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
        find.byKey(
          const ValueKey<String>('notification-category-community.all'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('notification-category-community.all'),
        ),
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
        find.byKey(
          const ValueKey<String>('notification-category-community.all'),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey<String>('notification-category-community.all'),
        ),
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

    // S73: the capability document answers for LOOP, and this page used to
    // let that one sentence stand for the device too. A device that never got
    // as far as the permission prompt said exactly what a registered device
    // that had received nothing said.
    testWidgets('the page says this device was never asked for permission', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
        pushDiagnostics: _pushDiagnostics(LoopPushRegistrationGate.noPrincipal),
      );

      expect(find.text('还没有向这台设备请求通知权限'), findsOneWidget);
    });

    // Decision 0076: the prompt waits for Community, and the page
    // says which moment it is waiting for rather than only that it is.
    testWidgets('a prompt that waits for Community says so', (tester) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
        pushDiagnostics: _pushDiagnostics(
          LoopPushRegistrationGate.awaitingCommunity,
        ),
      );

      expect(find.text('还没有向这台设备请求通知权限'), findsOneWidget);
      expect(find.text('进入社区后会请求一次。'), findsOneWidget);
    });

    testWidgets('a refused permission names the one step that changes it', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
        pushDiagnostics: _pushDiagnostics(
          LoopPushRegistrationGate.permissionDenied,
        ),
      );

      expect(find.text('通知权限已拒绝，这台设备收不到推送'), findsOneWidget);
      expect(find.text('可以在系统设置里为 LOOP 重新打开通知。'), findsOneWidget);
    });

    testWidgets('a registered device still does not claim a delivery', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
        pushDiagnostics: _pushDiagnostics(LoopPushRegistrationGate.registered),
      );

      expect(find.text('这台设备已登记接收推送'), findsOneWidget);
      expect(find.text('这不代表已经能送达。'), findsOneWidget);
    });

    // The server's own statement is not repeated in this device's words: one
    // screen would then read as two different problems.
    testWidgets('LOOP having no push runtime is said once, not twice', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
        pushDiagnostics: _pushDiagnostics(
          LoopPushRegistrationGate.capabilityUnavailable,
        ),
      );

      expect(find.text('推送尚不可用'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('notification-preferences-push-device'),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'the sentence follows the registration while the page is open',
      (tester) async {
        final recorder = LoopPushRegistrationDiagnosticsRecorder();
        addTearDown(recorder.dispose);
        recorder.record(LoopPushRegistrationGate.noPrincipal);

        await pumpS5Page(
          tester,
          const NotificationPreferencesScreen(),
          notifications: FakeNotificationsGateway(),
          pushDiagnostics: recorder,
        );
        expect(find.text('还没有向这台设备请求通知权限'), findsOneWidget);

        recorder.record(LoopPushRegistrationGate.registered);
        await tester.pumpAndSettle();

        expect(find.text('还没有向这台设备请求通知权限'), findsNothing);
        expect(find.text('这台设备已登记接收推送'), findsOneWidget);
      },
    );

    testWidgets('推送开通之后，那句「尚不可用」就不再出现', (tester) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(
          preferences: S5Answer<LoopNotificationPreferences>(
            value: s5Preferences(push: null),
          ),
        ),
        meta: s5MetaSnapshot(
          pushNotifications: LoopV2CapabilityAvailability.available,
        ),
      );

      expect(find.text('推送尚不可用'), findsNothing);
      // 通道有了，不等于这台设备收到过；页面只说后面这件事。
      expect(find.text('推送还没有在真机上确认过'), findsOneWidget);
    });

    testWidgets('真机确认过之后，这一行也收起来', (tester) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(
          preferences: S5Answer<LoopNotificationPreferences>(
            value: s5Preferences(push: null),
          ),
        ),
        meta: s5MetaSnapshot(
          pushNotifications: LoopV2CapabilityAvailability.available,
          pushEvidencePending: false,
        ),
      );

      expect(find.text('推送尚不可用'), findsNothing);
      expect(find.text('推送还没有在真机上确认过'), findsNothing);
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

  group('priceAlertTriggered 推送', () {
    Map<String, Object?> payload({
      String entity = '0b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e',
      String contextRoute = 'token',
    }) => <String, Object?>{
      'type': LoopPushNotificationType.priceAlertTriggered.wireName,
      'entityRef': 'priceAlert:$entity',
      'contextRoute': contextRoute,
      'eventVersion': LoopNotificationRouter.eventVersion,
    };

    LoopNotificationDecision route(Map<String, Object?> data) {
      final router = LoopNotificationRouter(
        clock: () => DateTime.utc(2026, 9, 8, 8),
      );
      return router.route(
        data: data,
        ingress: LoopNotificationIngress.interaction,
        session: const LoopNotificationSessionContext.authenticated(),
      );
    }

    test('推送只带一个 alert 指针，不带资产', () {
      final decision = route(payload());

      expect(decision.disposition, LoopNotificationDisposition.pointerReady);
      expect(
        decision.pointer?.entityRef,
        'priceAlert:0b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e',
      );
    });

    test('资产由 feed 的那条记录决定，才打开对应 Token 页', () {
      final intent = LoopNotificationRouter.resolve(
        route(payload()).pointer!,
        context: const LoopNotificationContext(
          contextRoute: 'token',
          assetId: s5WbnbAssetId,
        ),
      );

      expect(
        intent.location,
        '/market/token?assetId=${Uri.encodeQueryComponent(s5WbnbAssetId)}',
      );
    });

    test('feed 给不出规范资产时退回价格提醒页', () {
      final intent = LoopNotificationRouter.resolve(
        route(payload()).pointer!,
        context: const LoopNotificationContext(
          contextRoute: 'token',
          assetId: 'PEPE',
        ),
      );

      expect(intent.location, '/market/alerts');
    });

    test('contextRoute 与类型对不上时不解析成指针', () {
      expect(
        route(payload(contextRoute: 'devices')).disposition,
        LoopNotificationDisposition.malformed,
      );
    });
  });
}

/// A recorder already stopped at one step.
LoopPushRegistrationDiagnosticsRecorder _pushDiagnostics(
  LoopPushRegistrationGate gate,
) {
  final recorder = LoopPushRegistrationDiagnosticsRecorder()..record(gate);
  addTearDown(recorder.dispose);
  return recorder;
}
