import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';

import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// The "BSC 测试网" badge and its one-time explanation appear on exactly the
/// surfaces the Launch chain slot reaches, and nowhere else (decision 0038).
/// A build whose Launch slot equals the primary chain must look exactly as it
/// did before S9: no badge, no notice, no extra row.
void main() {
  final testnetBadge = find.byKey(const ValueKey<String>('loop-testnet-badge'));
  final testnetNotice = find.byKey(
    const ValueKey<String>('loop-testnet-notice'),
  );

  group('launch surfaces', () {
    testWidgets(
      'the catalogue is unchanged while Launch is on the main chain',
      (tester) async {
        await pumpS7Page(
          tester,
          const LaunchScreen(),
          launch: FakeLaunchGateway(
            overview: S7Answer<LaunchOverview>(value: s7Overview()),
          ),
        );

        expect(testnetBadge, findsNothing);
        expect(testnetNotice, findsNothing);
        expect(
          find.byKey(const ValueKey<String>('launch-chain-block')),
          findsNothing,
        );
      },
    );

    testWidgets('a published testnet slot states the chain once', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(
            value: s7Overview(
              live: <LaunchSummary>[s7LaunchSummary(chainId: 'eip155:97')],
            ),
          ),
        ),
        meta: s7MetaSnapshot(launchChainId: 'eip155:97'),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-chain-row')),
        findsOneWidget,
      );
      expect(testnetNotice, findsOneWidget);
      expect(find.text(loopTestnetNoticeTitle), findsOneWidget);
      // The row keeps its on-chain state badge as well as the chain badge.
      expect(find.text('链上待确认'), findsWidgets);
    });

    testWidgets('the row badge follows the launch, not the capability', (
      tester,
    ) async {
      // A primary-chain launch inside a testnet-configured backend carries no
      // badge of its own: the chain is the record's, never the deployment's.
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(
            value: s7Overview(live: <LaunchSummary>[s7LaunchSummary()]),
          ),
        ),
        meta: s7MetaSnapshot(launchChainId: 'eip155:97'),
      );

      // The surface block is present (the capability says testnet) but the
      // row itself carries only its on-chain state badge.
      expect(
        find.byKey(const ValueKey<String>('launch-chain-row')),
        findsOneWidget,
      );
      expect(testnetBadge, findsOneWidget);
    });

    testWidgets('the explanation can be closed and stays closed', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(value: s7Overview()),
        ),
        meta: s7MetaSnapshot(launchChainId: 'eip155:97'),
      );

      expect(testnetNotice, findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-testnet-notice-dismiss')),
      );
      await tester.pumpAndSettle();

      expect(testnetNotice, findsNothing);
      // Closing the explanation never removes the chain statement itself.
      expect(
        find.byKey(const ValueKey<String>('launch-chain-row')),
        findsOneWidget,
      );
    });

    testWidgets('the record pages state the launch record\'s own chain', (
      tester,
    ) async {
      for (final page in <Widget>[
        const LaunchDetailScreen(launchId: s7LaunchId),
        const LaunchRoundsScreen(launchId: s7LaunchId),
        const LaunchTradeScreen(launchId: s7LaunchId),
      ]) {
        await pumpS7Page(
          tester,
          page,
          launch: FakeLaunchGateway(
            detail: S7Answer<LaunchDetail>(
              value: s7Detail(chainId: 'eip155:97'),
            ),
          ),
          wallet: FakeWalletReadGateway(),
          meta: s7MetaSnapshot(launchChainId: 'eip155:97'),
        );

        expect(
          find.byKey(const ValueKey<String>('launch-chain-row')),
          findsOneWidget,
          reason: '${page.runtimeType} must state the launch chain',
        );
      }
    });

    testWidgets('loop-stake reads the chain from the capability', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LoopStakeScreen(),
        launch: FakeLaunchGateway(),
        meta: s7MetaSnapshot(launchChainId: 'eip155:97'),
      );

      expect(
        find.byKey(const ValueKey<String>('launch-chain-row')),
        findsOneWidget,
      );
      expect(testnetBadge, findsOneWidget);
    });
  });

  group('wallet surfaces', () {
    testWidgets('no Launch block while the slot equals the primary chain', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('wallet-launch-chain')),
        findsNothing,
      );
      expect(testnetBadge, findsNothing);
    });

    testWidgets('a published slot shows the tBNB balance and its badge', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(launchChain: _launchChainBalance()),
          ),
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-launch-chain-row')),
      );

      expect(find.text('tBNB'), findsOneWidget);
      expect(find.text('2.5'), findsOneWidget);
      expect(find.textContaining('可动用 2.495'), findsOneWidget);
      expect(testnetBadge, findsOneWidget);
    });

    testWidgets('an unavailable slot states the reason and never a zero', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              launchChain: const LoopLaunchChainBalance(
                chainId: 'eip155:97',
                available: false,
                reasonCode: 'LAUNCH_CHAIN_RPC_NOT_CONFIGURED',
                nativeBalance: null,
              ),
            ),
          ),
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-launch-chain-unavailable')),
      );

      expect(
        find.textContaining(
          loopReasonCodeText('LAUNCH_CHAIN_RPC_NOT_CONFIGURED'),
        ),
        findsOneWidget,
      );
      expect(find.text('0'), findsNothing);
      // The main-chain rows are untouched by the testnet failure.
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('networks shows no Launch row while the slot is shared', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('networks-launch-chain-row')),
        findsNothing,
      );
    });

    testWidgets('networks lists the Launch slot once it is published', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(
          status: S5Answer<LoopChainStatus>(
            value: s5Status(
              launchChain: _launchChainStatus(
                head: LoopChainHead(
                  blockNumber: BigInt.from(52000000),
                  blockHash: s5BlockHash,
                  observedAt: DateTime.utc(2026, 9, 9, 10, 45, 5),
                ),
              ),
            ),
          ),
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('networks-launch-chain-row')),
      );

      expect(find.text('BSC 测试网（Launch）'), findsOneWidget);
      expect(find.textContaining('eip155:97'), findsOneWidget);
    });

    testWidgets('an unconfigured Launch RPC is unavailable, not abnormal', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(
          status: S5Answer<LoopChainStatus>(
            value: s5Status(
              launchChain: _launchChainStatus(
                verification: LoopChainVerification.unknown,
                head: null,
                reasonCode: 'LAUNCH_CHAIN_RPC_NOT_CONFIGURED',
              ),
            ),
          ),
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('networks-launch-chain-unavailable')),
      );

      // A slot that was never wired up has no height and no health to report,
      // so it never reads as a chain that is misbehaving.
      expect(
        find.byKey(const ValueKey<String>('networks-launch-chain-row')),
        findsNothing,
      );
      expect(find.text('异常'), findsNothing);
      expect(
        find.textContaining(
          loopReasonCodeText('LAUNCH_CHAIN_RPC_NOT_CONFIGURED'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a pending verification is 待校验, never 异常', (tester) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(
          status: S5Answer<LoopChainStatus>(
            value: s5Status(
              launchChain: _launchChainStatus(
                verification: LoopChainVerification.unknown,
                head: null,
                reasonCode: 'LAUNCH_CHAIN_VERIFICATION_PENDING',
              ),
            ),
          ),
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('networks-launch-chain-row')),
      );

      // "Not proven yet" is neither a fault nor a proof.
      expect(find.text('待校验'), findsOneWidget);
      expect(find.text('异常'), findsNothing);
      // The primary chain row and its endpoint are untouched by the Launch
      // slot's pending verification.
      expect(find.text('正常'), findsNWidgets(2));
    });

    testWidgets('an unreachable or mismatched slot stays 异常', (tester) async {
      for (final (verification, reasonCode)
          in const <(LoopChainVerification, String)>[
            (LoopChainVerification.unreachable, 'LAUNCH_CHAIN_RPC_UNREACHABLE'),
            (LoopChainVerification.mismatched, 'LAUNCH_CHAIN_ID_MISMATCH'),
          ]) {
        await pumpS5Page(
          tester,
          const NetworksScreen(),
          chain: FakeChainGateway(
            status: S5Answer<LoopChainStatus>(
              value: s5Status(
                launchChain: _launchChainStatus(
                  verification: verification,
                  head: null,
                  reasonCode: reasonCode,
                ),
              ),
            ),
          ),
        );

        await scrollToS5Section(
          tester,
          find.byKey(const ValueKey<String>('networks-launch-chain-row')),
        );

        expect(find.text('异常'), findsOneWidget, reason: reasonCode);
        expect(find.text('待校验'), findsNothing, reason: reasonCode);
      }
    });
  });

  group('sign sheet', () {
    Future<void> pumpSheet(WidgetTester tester, {String? networkBadge}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: LoopSignSheet(
              state: LoopSignSheetState.pending,
              networkBadge: networkBadge,
              facts: const <LoopSignFact>[LoopSignFact('资产', 'tBNB')],
              onConfirm: () {},
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a money action names no chain of its own', (tester) async {
      await pumpSheet(tester);

      expect(
        find.byKey(const ValueKey<String>('loop-sign-sheet-network-badge')),
        findsNothing,
      );
    });

    testWidgets('a testnet signature is named, never blocked', (tester) async {
      await pumpSheet(tester, networkBadge: loopTestnetBadgeLabel);

      expect(
        find.byKey(const ValueKey<String>('loop-sign-sheet-network-badge')),
        findsOneWidget,
      );
      expect(find.text(loopTestnetBadgeLabel), findsOneWidget);
      // The badge is a statement of fact: the confirmation stays enabled.
      final sheet = tester.widget<LoopSignSheet>(find.byType(LoopSignSheet));
      expect(sheet.confirmEnabled, isTrue);
    });
  });

  group('primary-chain surfaces never mention the testnet', () {
    testWidgets('the market destination carries no chain badge', (
      tester,
    ) async {
      await pumpS5Page(tester, const MarketScreen());

      expect(testnetBadge, findsNothing);
      expect(testnetNotice, findsNothing);
      expect(find.textContaining('eip155:97'), findsNothing);
    });

    testWidgets('the watchlist carries no chain badge', (tester) async {
      await pumpS5Page(tester, const WatchlistEditorScreen());

      expect(testnetBadge, findsNothing);
      expect(find.textContaining('eip155:97'), findsNothing);
    });
  });
}

LoopLaunchChainBalance _launchChainBalance() => LoopLaunchChainBalance(
  chainId: 'eip155:97',
  available: true,
  reasonCode: null,
  nativeBalance: LoopLaunchChainNativeBalance(
    assetId: 'eip155:97:native',
    symbol: 'tBNB',
    decimals: 18,
    rawValue: '2500000000000000000',
    displayBalance: Decimal.parse('2.5'),
    availableBalance: Decimal.parse('2.5'),
    spendableBalance: Decimal.parse('2.495'),
    gasReserve: Decimal.parse('0.005'),
    snapshot: LoopBalanceSnapshot(
      blockNumber: BigInt.from(52000000),
      blockHash: s5BlockHash,
      observedAt: DateTime.utc(2026, 9, 9, 10, 45, 5),
      confirmations: 5,
    ),
  ),
);

LoopLaunchChainStatus _launchChainStatus({
  LoopChainVerification verification = LoopChainVerification.verified,
  LoopChainHead? head,
  String? reasonCode,
}) => LoopLaunchChainStatus(
  chainId: 'eip155:97',
  chainReference: 97,
  verification: verification,
  confirmations: 5,
  reorgDepthBlocks: 15,
  head: head,
  reasonCode: reasonCode,
);
