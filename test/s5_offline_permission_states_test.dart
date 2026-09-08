import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// The offline and permission halves of the five reviewed states.
///
/// Offline must pause the page and name what it paused, rather than blanking
/// it or claiming an empty result; a refused account must read as a permission
/// state, never as a service outage.
void main() {
  /// Every page's offline block names the same four paused actions, so the
  /// user is told what stopped rather than only that something did.
  const pausedActions = <String>['刷新', '切换钱包', '保存自选', '价格提醒'];

  Future<void> expectOffline(WidgetTester tester, String keyPrefix) async {
    final offline = find.byKey(ValueKey<String>('$keyPrefix-state-offline'));
    expect(offline, findsOneWidget, reason: keyPrefix);
    expect(find.byType(LoopOfflineState), findsWidgets, reason: keyPrefix);
    for (final action in pausedActions) {
      expect(
        find.descendant(of: offline, matching: find.textContaining(action)),
        findsWidgets,
        reason: '$keyPrefix must name the paused action $action',
      );
    }
  }

  Future<void> expectPermission(WidgetTester tester, String keyPrefix) async {
    expect(
      find.byKey(ValueKey<String>('$keyPrefix-state-permission')),
      findsOneWidget,
      reason: keyPrefix,
    );
    expect(find.byType(LoopPermissionState), findsWidgets, reason: keyPrefix);
    // A refused account is not an outage: the copy must not offer a retry.
    expect(find.byType(LoopOfflineState), findsNothing, reason: keyPrefix);
  }

  group('wallet · offline', () {
    testWidgets('wallet pauses on the directory read', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      await expectOffline(tester, 'wallet-directory');
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('wallet pauses on the balance read', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      await expectOffline(tester, 'wallet-balances');
    });

    testWidgets('networth pauses without inventing a total', (tester) async {
      await pumpS5Page(
        tester,
        const NetWorthScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      await expectOffline(tester, 'networth');
      expect(find.text('净值不可用'), findsNothing);
      expect(find.textContaining('6,352'), findsNothing);
    });

    testWidgets('asset pauses without a balance', (tester) async {
      await pumpS5Page(
        tester,
        const WalletAssetScreen(assetId: s5NativeAssetId),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
        chain: FakeChainGateway(),
      );

      await expectOffline(tester, 'wallet-asset');
      expect(find.text('7'), findsNothing);
    });

    testWidgets('receive pauses without an address', (tester) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          receive: S5Answer<LoopWalletReceive>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      await expectOffline(tester, 'receive');
      expect(find.byKey(const ValueKey<String>('receive-qr')), findsNothing);
      expect(find.text(s5Address), findsNothing);
    });

    testWidgets('wallets pauses without listing a wallet', (tester) async {
      await pumpS5Page(
        tester,
        const WalletManagerScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      await expectOffline(tester, 'wallets');
      expect(find.text('使用中'), findsNothing);
    });

    testWidgets('tx-history pauses without claiming an empty tape', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      await expectOffline(tester, 'tx-history');
      expect(find.text('这一段没有记录'), findsNothing);
    });

    testWidgets('networks pauses without an endpoint', (tester) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(
          status: S5Answer<LoopChainStatus>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      await expectOffline(tester, 'networks');
      expect(find.text('rpc-2bd52ca6d267'), findsNothing);
    });
  });

  group('wallet · permission', () {
    testWidgets('wallet reads a refused account as a permission state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(
            failure: LoopChainFailureKind.permissionDenied,
          ),
        ),
      );

      await expectPermission(tester, 'wallet-directory');
      expect(find.textContaining('无权执行此操作'), findsOneWidget);
    });

    testWidgets('networth reads a refused account as a permission state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetWorthScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            failure: LoopChainFailureKind.permissionDenied,
          ),
        ),
      );

      await expectPermission(tester, 'networth');
    });

    testWidgets('asset reads a refused account as a permission state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletAssetScreen(assetId: s5NativeAssetId),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            failure: LoopChainFailureKind.permissionDenied,
          ),
        ),
        chain: FakeChainGateway(),
      );

      await expectPermission(tester, 'wallet-asset');
    });

    testWidgets('receive reads a refused account as a permission state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          receive: S5Answer<LoopWalletReceive>(
            failure: LoopChainFailureKind.permissionDenied,
          ),
        ),
      );

      await expectPermission(tester, 'receive');
      expect(find.byKey(const ValueKey<String>('receive-qr')), findsNothing);
    });

    testWidgets('wallets reads a refused account as a permission state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletManagerScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(
            failure: LoopChainFailureKind.permissionDenied,
          ),
        ),
      );

      await expectPermission(tester, 'wallets');
    });

    testWidgets('tx-history reads a refused account as a permission state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(
            failure: LoopChainFailureKind.permissionDenied,
          ),
        ),
      );

      await expectPermission(tester, 'tx-history');
    });

    testWidgets('networks reads a refused account as a permission state', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(
          status: S5Answer<LoopChainStatus>(
            failure: LoopChainFailureKind.permissionDenied,
          ),
        ),
      );

      await expectPermission(tester, 'networks');
    });
  });

  group('watchlist, alerts and notif-settings · offline', () {
    testWidgets('watchlist-edit pauses without an empty list', (tester) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      await expectOffline(tester, 'watchlist');
      expect(find.text('还没有自选资产'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('watchlist-save')),
        findsNothing,
      );
    });

    testWidgets('alerts pauses without claiming zero alerts', (tester) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(
          page: S5Answer<LoopAlertPage>(failure: LoopChainFailureKind.offline),
        ),
        notifications: FakeNotificationsGateway(),
      );

      await expectOffline(tester, 'alerts');
      expect(find.text('还没有价格提醒'), findsNothing);
      expect(find.textContaining('个提醒正在监听'), findsNothing);
    });

    testWidgets('the alerts trigger history pauses on its own', (tester) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(
          feed: S5Answer<LoopNotificationFeed>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      // The alert list still rendered: one block failing does not blank a
      // block that loaded.
      expect(find.text('WBNB 涨到 800.5'), findsOneWidget);
      await expectOffline(tester, 'alerts-feed');
      expect(find.text('还没有触发记录'), findsNothing);
    });

    testWidgets('notif-settings pauses without showing a default', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(
          preferences: S5Answer<LoopNotificationPreferences>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      await expectOffline(tester, 'notification-preferences');
      expect(find.byType(Switch), findsNothing);
      expect(find.textContaining('项开启'), findsNothing);
    });
  });
}
