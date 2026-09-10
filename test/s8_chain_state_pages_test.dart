import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// Loading / Empty / Error / Offline for the thirteen S5 pages that render
/// their reads through `LoopChainStateBlock`.
///
/// **The `-state-empty` key is dead on every one of these pages.** A page only
/// reaches the shared block's `empty` phase when `loopChainPhaseForFailure`
/// is handed a `null` kind, and the only producer of a failed phase —
/// `LoopChainResourceState.failed(kind)` — takes a non-nullable kind. So the
/// `empty` branch is unreachable from a read. Emptiness on these pages is
/// therefore a property of a **successful** read whose collection happens to
/// have no rows, and each page renders its OWN keyed empty widget for it.
/// Every empty case below pumps the successful read, asserts that page-local
/// key, and additionally asserts `<prefix>-state-empty` findsNothing so the
/// dead branch stays dead.
///
/// Offline is asserted only where nothing else pins it. `token`,
/// `token-trades`, `watchlist-edit` and `alerts` are pinned in
/// `test/s8_offline_permission_states_test.dart`; `wallet`, `networth`,
/// `asset`, `receive`, `wallets`, `tx-history` and `networks` in
/// `test/s5_offline_permission_states_test.dart`. This file adds the three
/// that had none: `new-pairs`, `smart-money` and the nested
/// `wallet-asset-registry` block.
///
/// Every expectation names one page's own key prefix. The shared block being
/// reachable from somewhere is never the evidence.

// ---------------------------------------------------------------------------
// The uniform states: Loading, Error and (where unpinned) Offline.
// ---------------------------------------------------------------------------

/// Mounts one page with exactly one port answering [failure] or never
/// answering at all. It is never called for a successful read, so the answers
/// below deliberately carry no value.
typedef _StatePump = Future<void> Function(
  WidgetTester tester, {
  LoopChainFailureKind? failure,
  bool pending,
});

final class _Case {
  _Case({
    required this.slug,
    required this.prefix,
    required this.pump,
    required this.absentWhileLoading,
    required this.absentWhileLoadingLabel,
    this.offlineUnpinned = false,
  });

  /// The manifest slug, used in the test name.
  final String slug;

  /// The page's own `LoopChainStateBlock` key prefix.
  final String prefix;
  final _StatePump pump;

  /// A concrete figure or identity that only exists once the read landed. A
  /// skeleton that is accompanied by it would be showing something the page
  /// has not been told yet.
  final Finder absentWhileLoading;
  final String absentWhileLoadingLabel;

  /// `true` when no other test pins this prefix's offline state.
  final bool offlineUnpinned;
}

final List<_Case> _cases = <_Case>[
  // -- market ---------------------------------------------------------------
  _Case(
    slug: 'token',
    prefix: 'token',
    absentWhileLoading: find.textContaining('747.39'),
    absentWhileLoadingLabel: 'the price fact',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const TokenDetailScreen(assetId: s5WbnbAssetId),
      market: FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(failure: failure, pending: pending),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'token-trades',
    prefix: 'token-trades',
    absentWhileLoading: find.textContaining('笔链上成交'),
    absentWhileLoadingLabel: 'the trade count',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const TradingActivityScreen(assetId: s5WbnbAssetId),
      market: FakeMarketReadGateway(
        trades: S5Answer<MarketTradesPage>(failure: failure, pending: pending),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'alerts',
    prefix: 'alerts',
    absentWhileLoading: find.textContaining('个提醒正在监听'),
    absentWhileLoadingLabel: 'the armed-alert count',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const PriceAlertsScreen(),
      alerts: FakeAlertsGateway(
        page: S5Answer<LoopAlertPage>(failure: failure, pending: pending),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'watchlist-edit',
    prefix: 'watchlist',
    absentWhileLoading: find.textContaining('个自选资产'),
    absentWhileLoadingLabel: 'the watched-asset count',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const WatchlistEditorScreen(),
      watchlist: FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(
          failure: failure,
          pending: pending,
        ),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'new-pairs',
    prefix: 'new-pairs',
    absentWhileLoading: find.textContaining('个新对'),
    absentWhileLoadingLabel: 'the new-pair count',
    offlineUnpinned: true,
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const NewPairsScreen(),
      market: FakeMarketReadGateway(
        newPairs: S5Answer<MarketNewPairsPage>(
          failure: failure,
          pending: pending,
        ),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'smart-money',
    prefix: 'smart-money',
    absentWhileLoading: find.byKey(
      const ValueKey<String>('smart-money-unavailable'),
    ),
    absentWhileLoadingLabel: "the server's own unavailable reason",
    offlineUnpinned: true,
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const SmartMoneyScreen(),
      market: FakeMarketReadGateway(
        smartMoney: S5Answer<LoopUnavailable>(
          failure: failure,
          pending: pending,
        ),
      ),
      settle: !pending,
    ),
  ),

  // -- wallet read ----------------------------------------------------------
  // `wallet` composes two blocks: the directory decides which wallet is read,
  // and only then are that wallet's balances read. Each one owns a prefix, so
  // both are pinned separately.
  _Case(
    slug: 'wallet',
    prefix: 'wallet-directory',
    absentWhileLoading: find.textContaining(r'$'),
    absentWhileLoadingLabel: 'a net-worth figure',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const WalletScreen(),
      wallet: FakeWalletReadGateway(
        directory: S5Answer<LoopWalletDirectory>(
          failure: failure,
          pending: pending,
        ),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'wallet',
    prefix: 'wallet-balances',
    absentWhileLoading: find.textContaining(r'$'),
    absentWhileLoadingLabel: 'a net-worth figure',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const WalletScreen(),
      wallet: FakeWalletReadGateway(
        balances: S5Answer<LoopWalletBalances>(
          failure: failure,
          pending: pending,
        ),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'networth',
    prefix: 'networth',
    absentWhileLoading: find.textContaining('6,352'),
    absentWhileLoadingLabel: 'the net-worth total',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const NetWorthScreen(),
      wallet: FakeWalletReadGateway(
        balances: S5Answer<LoopWalletBalances>(
          failure: failure,
          pending: pending,
        ),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'asset',
    prefix: 'wallet-asset',
    absentWhileLoading: find.text('7'),
    absentWhileLoadingLabel: 'the balance',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const WalletAssetScreen(assetId: s5NativeAssetId),
      wallet: FakeWalletReadGateway(
        balances: S5Answer<LoopWalletBalances>(
          failure: failure,
          pending: pending,
        ),
      ),
      chain: FakeChainGateway(),
      settle: !pending,
    ),
  ),
  // The registry facts are a second read behind the balance row. It has its
  // own prefix because a registry that failed must not blank a balance that
  // loaded — and nothing else pins its offline state.
  _Case(
    slug: 'asset',
    prefix: 'wallet-asset-registry',
    absentWhileLoading: find.byKey(
      const ValueKey<String>('wallet-asset-registry'),
    ),
    absentWhileLoadingLabel: 'the registry facts card',
    offlineUnpinned: true,
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const WalletAssetScreen(assetId: s5NativeAssetId),
      wallet: FakeWalletReadGateway(),
      chain: FakeChainGateway(
        asset: S5Answer<LoopChainAssetView>(failure: failure, pending: pending),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'receive',
    prefix: 'receive',
    absentWhileLoading: find.byKey(const ValueKey<String>('receive-qr')),
    absentWhileLoadingLabel: 'the receive QR code',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const ReceiveScreen(walletId: s5WalletId),
      wallet: FakeWalletReadGateway(
        receive: S5Answer<LoopWalletReceive>(
          failure: failure,
          pending: pending,
        ),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'tx-history',
    prefix: 'tx-history',
    absentWhileLoading: find.text('1 笔'),
    absentWhileLoadingLabel: 'the transfer count',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const TransactionHistoryScreen(walletId: s5WalletId),
      wallet: FakeWalletReadGateway(
        activity: S5Answer<LoopWalletActivityPage>(
          failure: failure,
          pending: pending,
        ),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'wallets',
    prefix: 'wallets',
    // The notice copy also contains 「钱包」, so the tally is matched exactly.
    absentWhileLoading: find.text('2 个钱包'),
    absentWhileLoadingLabel: 'the wallet count',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const WalletManagerScreen(),
      wallet: FakeWalletReadGateway(
        directory: S5Answer<LoopWalletDirectory>(
          failure: failure,
          pending: pending,
        ),
      ),
      settle: !pending,
    ),
  ),
  _Case(
    slug: 'networks',
    prefix: 'networks',
    absentWhileLoading: find.textContaining('正常'),
    absentWhileLoadingLabel: 'the healthy-endpoint tally',
    pump: (tester, {failure, pending = false}) => pumpS5Page(
      tester,
      const NetworksScreen(),
      chain: FakeChainGateway(
        status: S5Answer<LoopChainStatus>(failure: failure, pending: pending),
      ),
      settle: !pending,
    ),
  ),
];

/// A never-completing read leaves the skeleton animating, so the frame cannot
/// be settled. Two extra frames let the reads that *did* answer land.
Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// A `LoopChainStatus` whose RPC health carries no endpoint at all.
LoopChainStatus _statusWithoutEndpoints() {
  final base = s5Status();
  return LoopChainStatus(
    chain: base.chain,
    rpc: const LoopRpcHealth(
      available: false,
      reasonCode: 'BSC_RPC_NOT_CONFIGURED',
      verification: LoopChainVerification.verified,
      head: null,
      endpoints: <LoopRpcEndpointHealth>[],
    ),
    indexer: base.indexer,
    registry: base.registry,
  );
}

void main() {
  // -------------------------------------------------------------------------
  // Loading / Error / Offline — one table, every page.
  // -------------------------------------------------------------------------
  for (final testCase in _cases) {
    group('${testCase.slug} · ${testCase.prefix}', () {
      testWidgets('${testCase.prefix} shows a skeleton and none of '
          '${testCase.absentWhileLoadingLabel} while the read is in flight', (
        tester,
      ) async {
        await testCase.pump(tester, pending: true);
        await _pumpFrames(tester);

        expect(
          find.byKey(ValueKey<String>('${testCase.prefix}-state-loading')),
          findsOneWidget,
        );
        expect(
          testCase.absentWhileLoading,
          findsNothing,
          reason:
              'a skeleton must not be accompanied by '
              '${testCase.absentWhileLoadingLabel}, which the page has not '
              'been told yet',
        );
      });

      testWidgets(
        '${testCase.prefix} reports an unreadable answer as an error',
        (tester) async {
          await testCase.pump(failure: LoopChainFailureKind.unexpected, tester);

          expect(
            find.byKey(ValueKey<String>('${testCase.prefix}-state-error')),
            findsOneWidget,
          );
          // A server that answered badly is not a network that never answered.
          expect(
            find.byKey(ValueKey<String>('${testCase.prefix}-state-offline')),
            findsNothing,
          );
        },
      );

      if (testCase.offlineUnpinned) {
        testWidgets('${testCase.prefix} pauses offline instead of erroring', (
          tester,
        ) async {
          await testCase.pump(failure: LoopChainFailureKind.offline, tester);

          expect(
            find.byKey(ValueKey<String>('${testCase.prefix}-state-offline')),
            findsOneWidget,
          );
          expect(
            find.byKey(ValueKey<String>('${testCase.prefix}-state-error')),
            findsNothing,
            reason: 'a request that reached nobody is not a server error',
          );
          expect(
            find.byKey(ValueKey<String>('${testCase.prefix}-state-empty')),
            findsNothing,
            reason: 'a paused read is never "there is nothing"',
          );
        });
      }
    });
  }

  // -------------------------------------------------------------------------
  // Empty — one bespoke case per page, because every page owns its own key.
  // -------------------------------------------------------------------------

  group('token · empty', () {
    testWidgets('token has no empty state: a detail is facts, not a list', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      // `MarketAssetDetail` is a record of facts — price, liquidity, FDV, the
      // primary pair — not a collection. A read either returns that record or
      // fails, and a fact the source did not report renders its own reason
      // line. So there is no "read succeeded but there is nothing" for token.
      expect(
        find.byKey(const ValueKey<String>('token-state-empty')),
        findsNothing,
        reason: 'token can never publish the shared block\'s empty phase',
      );
      expect(
        find.byKey(const ValueKey<String>('token-state-error')),
        findsNothing,
      );
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-facts-notice')),
      );
      expect(
        find.byKey(const ValueKey<String>('token-facts-notice')),
        findsOneWidget,
      );
    });
  });

  group('token-trades · empty', () {
    testWidgets('token-trades states an empty tape with its own key', (
      tester,
    ) async {
      // The default fake answers with a readable tape carrying zero swaps.
      await pumpS5Page(
        tester,
        const TradingActivityScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('token-trades-empty')),
        findsOneWidget,
      );
      expect(find.text('这一页没有成交'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('token-trades-state-empty')),
        findsNothing,
        reason: 'the shared block is only reached by a failed read',
      );
    });
  });

  group('alerts · empty', () {
    testWidgets('alerts states an empty list with its own key', (tester) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(
          page: S5Answer<LoopAlertPage>(
            value: LoopAlertPage(
              items: const <LoopPriceAlert>[],
              nextCursor: null,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('alerts-empty')),
        findsOneWidget,
      );
      // The empty state offers the one action that resolves it.
      expect(
        find.byKey(const ValueKey<String>('alerts-empty-create')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('alerts-state-empty')),
        findsNothing,
      );
    });
  });

  group('watchlist-edit · empty', () {
    testWidgets(
      'watchlist-edit states a groupless watchlist with its own key',
      (tester) async {
        await pumpS5Page(
          tester,
          const WatchlistEditorScreen(),
          watchlist: FakeWatchlistGateway(
            snapshot: S5Answer<WatchlistSnapshot>(
              value: WatchlistSnapshot(
                version: 1,
                updatedAt: DateTime.utc(2026, 9, 8, 5, 12),
                groups: const <WatchlistGroup>[],
              ),
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('watchlist-no-groups')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('watchlist-state-empty')),
          findsNothing,
        );
      },
    );

    testWidgets('watchlist-edit states an empty group with its own key', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(
            value: WatchlistSnapshot(
              version: 1,
              updatedAt: DateTime.utc(2026, 9, 8, 5, 12),
              groups: <WatchlistGroup>[
                WatchlistGroup(
                  key: 'mining',
                  name: 'Mining',
                  items: const <WatchlistItem>[],
                ),
              ],
            ),
          ),
        ),
      );

      // A group that exists and holds nothing is not a groupless watchlist:
      // the two say different things and carry different keys.
      expect(
        find.byKey(const ValueKey<String>('watchlist-group-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('watchlist-no-groups')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('watchlist-state-empty')),
        findsNothing,
      );
    });
  });

  group('new-pairs · empty', () {
    testWidgets('new-pairs distinguishes "no pool reported" from "no source"', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NewPairsScreen(),
        market: FakeMarketReadGateway(
          newPairs: S5Answer<MarketNewPairsPage>(
            value: MarketNewPairsPage(
              newPairs: MarketNewPairsAvailable(
                source: LoopFactSource.geckoterminal,
                fetchedAt: DateTime.utc(2026, 9, 8, 7, 31),
                ttlSeconds: 60,
                quality: LoopFactQuality.fresh,
                reasonCode: null,
                items: const <MarketNewPair>[],
              ),
              riskScreening: const LoopUnavailable(
                'MARKET_PROVIDER_GOPLUS_NOT_CONFIGURED',
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('new-pairs-empty')),
        findsOneWidget,
      );
      expect(find.text('来源当前没有报告新的池'), findsOneWidget);
      // A source that reported nothing is not a missing source.
      expect(
        find.byKey(const ValueKey<String>('new-pairs-unavailable')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('new-pairs-state-empty')),
        findsNothing,
      );
    });
  });

  group('smart-money · empty', () {
    testWidgets('smart-money has no empty state: the port carries no list', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const SmartMoneyScreen(),
        market: FakeMarketReadGateway(),
      );

      // The port's return type is `Future<LoopUnavailable>` — a stated reason
      // with no collection behind it. There is no list that could come back
      // with zero rows, so "empty" is not a state this page has.
      expect(
        find.byKey(const ValueKey<String>('smart-money-state-empty')),
        findsNothing,
        reason: 'a LoopUnavailable carries no rows to be empty of',
      );
      expect(
        find.byKey(const ValueKey<String>('smart-money-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('smart-money-state-error')),
        findsNothing,
      );
    });
  });

  group('wallet · empty', () {
    testWidgets('wallet states a registry with no readable row', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(rows: const <LoopAssetBalanceRow>[]),
          ),
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-balances-empty')),
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-balances-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-balances-state-empty')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-directory-state-empty')),
        findsNothing,
      );
    });
  });

  group('networth · empty', () {
    testWidgets(
      'networth labels a zero-row breakdown instead of showing none',
      (tester) async {
        await pumpS5Page(
          tester,
          const NetWorthScreen(),
          wallet: FakeWalletReadGateway(
            balances: S5Answer<LoopWalletBalances>(
              value: s5Balances(rows: const <LoopAssetBalanceRow>[]),
            ),
          ),
        );

        await scrollToS5Section(
          tester,
          find.byKey(const ValueKey<String>('networth-empty')),
        );
        expect(
          find.byKey(const ValueKey<String>('networth-empty')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('networth-state-empty')),
          findsNothing,
        );
      },
    );
  });

  group('asset · empty', () {
    testWidgets('asset says the asset is not in the readable list', (
      tester,
    ) async {
      // The balances answer holds only the native row, so USDT has no row.
      await pumpS5Page(
        tester,
        const WalletAssetScreen(assetId: s5UsdtAssetId),
        wallet: FakeWalletReadGateway(),
        chain: FakeChainGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('wallet-asset-missing-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-asset-state-empty')),
        findsNothing,
      );
      // Absent from the registry is not a zero balance.
      expect(find.text('0'), findsNothing);
    });
  });

  group('receive · empty', () {
    testWidgets('receive says no network was offered rather than showing one', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const ReceiveScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          receive: S5Answer<LoopWalletReceive>(
            value: LoopWalletReceive(
              walletId: s5WalletId,
              networks: const <LoopReceiveNetwork>[],
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('receive-no-network')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('receive-state-empty')),
        findsNothing,
      );
      // No address may be rendered when the server named no network.
      expect(find.byKey(const ValueKey<String>('receive-qr')), findsNothing);
      expect(find.text(s5Address), findsNothing);
    });
  });

  group('tx-history · empty', () {
    testWidgets('tx-history states an empty segment with its own key', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(
            value: s5Activity(items: const <LoopWalletActivityEntry>[]),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('tx-history-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tx-history-state-empty')),
        findsNothing,
      );
      // The indexer's own freshness still shows: it read the range, it just
      // found nothing belonging to this wallet.
      expect(
        find.byKey(const ValueKey<String>('tx-history-freshness')),
        findsOneWidget,
      );
    });
  });

  group('wallets · empty', () {
    testWidgets('wallets names each empty wallet class separately', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletManagerScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(
            value: LoopWalletDirectory(
              wallets: <LoopWalletAccount>[
                LoopWalletAccount(
                  walletId: s5WalletId,
                  address: s5Address,
                  kind: LoopWalletKind.embedded,
                  status: LoopWalletStatus.active,
                  isActive: false,
                  firstSeenAt: DateTime.utc(2026, 9, 8),
                  lastSeenAt: DateTime.utc(2026, 9, 8),
                ),
              ],
              activeWalletId: null,
              observedAt: DateTime.utc(2026, 9, 8, 5, 12),
            ),
          ),
        ),
      );

      // `_WalletList` is rendered twice, so "no connected external wallet" is
      // its own statement rather than a blank below the embedded list.
      expect(
        find.byKey(const ValueKey<String>('wallets-empty-没有已连接的外部钱包')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('wallets-empty-没有嵌入式钱包')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('wallets-state-empty')),
        findsNothing,
      );
      expect(find.text('使用中'), findsNothing);
    });

    testWidgets('a directory with no wallet at all is the creation state', (
      tester,
    ) async {
      // Decision 0063: "the account owns no wallet" is a read result with one
      // action, not two per-class blanks and not a failed read.
      await pumpS5Page(
        tester,
        const WalletManagerScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(
            value: LoopWalletDirectory(
              wallets: const <LoopWalletAccount>[],
              activeWalletId: null,
              observedAt: DateTime.utc(2026, 9, 8, 5, 12),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('wallets-no-wallet')),
        findsOneWidget,
      );
      expect(find.text('这个账号还没有钱包'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('wallets-state-empty')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('wallets-empty-没有嵌入式钱包')),
        findsNothing,
      );
    });
  });

  group('networks · empty', () {
    testWidgets('networks expresses "no endpoint" as unavailable, by design', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NetworksScreen(),
        chain: FakeChainGateway(
          status: S5Answer<LoopChainStatus>(value: _statusWithoutEndpoints()),
        ),
      );

      // An RPC list with no entry is not "there is nothing to show": it means
      // the deployment configured no endpoint, which is a stated reason code.
      // So the page renders an unavailable card rather than an empty one.
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('networks-no-endpoints')),
      );
      expect(
        find.byKey(const ValueKey<String>('networks-no-endpoints')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('networks-state-empty')),
        findsNothing,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Write paths — an action that never reached the server changed nothing, so
  // the page pauses instead of reporting a failed write.
  // -------------------------------------------------------------------------

  group('wallets · offline switch', () {
    testWidgets(
      'wallets pauses an offline switch instead of reporting it failed',
      (tester) async {
        final wallet = FakeWalletReadGateway(
          switchFailure: LoopChainFailureKind.offline,
        );
        await pumpS5Page(tester, const WalletManagerScreen(), wallet: wallet);

        await tester.tap(
          find.byKey(const ValueKey<String>('wallet-row-$s5OtherWalletId')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('wallets-activate-confirm')),
        );
        await tester.pumpAndSettle();

        expect(wallet.switched, <String>[s5OtherWalletId]);
        expect(
          find.byKey(const ValueKey<String>('wallets-switch-offline')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('wallets-switch-error')),
          findsNothing,
          reason:
              'a switch that reached nobody is a pause, not a failed switch',
        );
        expect(find.text('已切换活跃钱包'), findsNothing);
        // The active wallet below is still the server's own answer.
        expect(find.text('使用中'), findsOneWidget);
      },
    );
  });

  group('tx-history · offline paging', () {
    testWidgets(
      'tx-history pauses the next page and keeps the rows it showed',
      (tester) async {
        final wallet = FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(
            value: s5Activity(nextCursor: s5Cursor),
          ),
          activityMoreFailure: LoopChainFailureKind.offline,
        );
        await pumpS5Page(
          tester,
          const TransactionHistoryScreen(walletId: s5WalletId),
          wallet: wallet,
        );

        await scrollToS5Section(
          tester,
          find.byKey(const ValueKey<String>('tx-history-load-more')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('tx-history-load-more')),
        );
        await tester.pumpAndSettle();

        expect(wallet.activityCursors, <String?>[null, s5Cursor]);
        expect(
          find.byKey(const ValueKey<String>('tx-history-page-offline')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('tx-history-page-error')),
          findsNothing,
          reason: 'a page that reached nobody did not fail, it did not happen',
        );
        // The rows the first page already showed stay on screen.
        await scrollToS5Section(
          tester,
          find.byKey(const ValueKey<String>('tx-entry-$s5TxHash:3')),
        );
        expect(
          find.byKey(const ValueKey<String>('tx-entry-$s5TxHash:3')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('tx-history-empty')),
          findsNothing,
        );
      },
    );
  });

  group('watchlist-edit · offline save', () {
    testWidgets('watchlist-edit pauses an offline save and keeps the draft', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway(
        replaceFailure: LoopChainFailureKind.offline,
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
        find.byKey(const ValueKey<String>('watchlist-save-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('watchlist-save-error')),
        findsNothing,
        reason: 'a save that reached nobody overwrote nothing on either side',
      );
      expect(find.text('自选已保存'), findsNothing);
      // The draft that was typed is still exactly what is on screen.
      expect(find.text('2 个自选资产'), findsOneWidget);
    });
  });

  group('alerts · offline command', () {
    testWidgets(
      'alerts pauses an offline delete instead of reporting it failed',
      (tester) async {
        final alerts = FakeAlertsGateway(
          commandFailure: LoopChainFailureKind.offline,
        );
        await pumpS5Page(tester, const PriceAlertsScreen(), alerts: alerts);

        await scrollToS5Section(
          tester,
          find.byKey(const ValueKey<String>('alert-$s5AlertId')),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('alert-$s5AlertId')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('alert-editor-delete')),
        );
        await tester.pumpAndSettle();

        expect(alerts.deleted, <String>[s5AlertId]);
        expect(
          find.byKey(const ValueKey<String>('alerts-command-offline')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('alerts-command-error')),
          findsNothing,
          reason: 'a command that reached nobody deleted nothing',
        );
        expect(find.text('提醒已删除'), findsNothing);
        // The list below is still the server's own answer.
        expect(
          find.byKey(const ValueKey<String>('alert-$s5AlertId')),
          findsOneWidget,
        );
      },
    );
  });

  // A refused command is the Permission state of an already-loaded page: the
  // server answered, so the page keeps what it read and offers no retry.
  group('watchlist-edit · refused save', () {
    testWidgets('a refused save is a permission state and keeps the draft', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway(
        replaceFailure: LoopChainFailureKind.permissionDenied,
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
        find.byKey(const ValueKey<String>('watchlist-save-permission')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('watchlist-save-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('watchlist-save-offline')),
        findsNothing,
      );
      expect(find.text('自选已保存'), findsNothing);
      expect(find.text('2 个自选资产'), findsOneWidget);
    });
  });

  group('alerts · refused command', () {
    testWidgets('a refused delete keeps the alert and states the refusal', (
      tester,
    ) async {
      final alerts = FakeAlertsGateway(
        commandFailure: LoopChainFailureKind.permissionDenied,
      );
      await pumpS5Page(tester, const PriceAlertsScreen(), alerts: alerts);

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('alert-$s5AlertId')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('alert-$s5AlertId')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('alert-editor-delete')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('alerts-command-permission')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('alerts-command-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('alerts-command-offline')),
        findsNothing,
      );
      expect(find.text('提醒已删除'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('alert-$s5AlertId')),
        findsOneWidget,
      );
    });
  });
}
