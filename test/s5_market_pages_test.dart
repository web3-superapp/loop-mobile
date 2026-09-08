import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

void main() {
  group('market · the行情 tab', () {
    testWidgets('loading shows a skeleton and no figure', (tester) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(pending: true),
        ),
        settle: false,
      );

      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(find.textContaining('个自选资产'), findsNothing);
    });

    testWidgets('ready renders each fact with its source and time', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
      );

      expect(find.text('1 个自选资产'), findsOneWidget);
      expect(find.text('\$747.39'), findsWidgets);
      expect(find.textContaining('来源 DexScreener'), findsWidgets);
      expect(find.textContaining('观察于'), findsWidgets);
    });

    testWidgets('a stale price is shown with a marker, not silently', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(
            value: s5Overview(
              watchlist: MarketWatchlistAvailable(
                version: 1,
                items: <MarketAssetRow>[
                  s5MarketRow(price: s5StaleFact('747.39')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('数据可能过期'), findsWidgets);
      expect(find.text('\$747.39'), findsWidgets);
    });

    testWidgets('an unavailable price renders its reason, never zero', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(
            value: s5Overview(
              watchlist: MarketWatchlistAvailable(
                version: 1,
                items: <MarketAssetRow>[
                  s5MarketRow(
                    price: const LoopFact.unavailable('MARKET_PAIR_NOT_FOUND'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('没有以该资产为 base 的交易对'), findsWidgets);
      expect(find.text('\$0'), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('the trending block always states its ordering rule', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
      );

      expect(find.textContaining('按 DexScreener 24h 成交量排序'), findsOneWidget);
    });

    testWidgets('an empty watchlist offers the editor, not a zero', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(
            value: s5Overview(
              watchlist: MarketWatchlistAvailable(
                version: 1,
                items: const <MarketAssetRow>[],
              ),
            ),
          ),
        ),
      );

      expect(find.text('还没有自选资产'), findsOneWidget);
      expect(find.text('管理自选'), findsWidgets);
    });

    testWidgets('offline pauses the page instead of blanking it', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
      );

      expect(find.byType(LoopOfflineState), findsOneWidget);
    });

    testWidgets('an unparsable payload is an error, not a blank list', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(
            failure: LoopChainFailureKind.invalidData,
          ),
        ),
      );

      expect(find.byType(LoopErrorState), findsOneWidget);
      expect(find.textContaining('没有采纳任何内容'), findsOneWidget);
    });

    testWidgets('an unavailable capability stops the page before any read', (
      tester,
    ) async {
      final market = FakeMarketReadGateway();
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: market,
        meta: s5MetaSnapshot(
          marketRead: LoopV2CapabilityAvailability.unavailable,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('market-capability-block')),
        findsOneWidget,
      );
      expect(find.textContaining('服务端依赖尚未配齐'), findsOneWidget);
    });
  });

  group('token', () {
    testWidgets('a malformed route identity fails closed', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: 'PEPE'),
        market: FakeMarketReadGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('token-invalid-identity')),
        findsOneWidget,
      );
    });

    testWidgets('the Swap entry point is absent while swappable is false', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('token-swap-entry')),
        findsNothing,
      );
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-swap-unavailable')),
      );
      expect(find.textContaining('Swap 尚未交付'), findsOneWidget);
    });

    testWidgets(
      'a derived candle series is labelled and marks the open bucket',
      (tester) async {
        await pumpS5Page(
          tester,
          const TokenDetailScreen(assetId: s5WbnbAssetId),
          market: FakeMarketReadGateway(),
        );

        expect(find.byType(LoopCandleChart), findsOneWidget);
        expect(find.text('链上成交聚合'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('candles-open-marker')),
          findsOneWidget,
        );
        // The price unit is the pool's other token, never USD.
        expect(find.text('USDT per WBNB'), findsOneWidget);
      },
    );

    testWidgets('an unavailable candle block states its reason', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          candles: S5Answer<MarketCandleSeries>(
            value: const MarketCandleSeries(
              assetId: s5WbnbAssetId,
              interval: LoopCandleInterval.oneHour,
              candles: MarketCandlesUnavailable('MARKET_POOL_NOT_REGISTERED'),
            ),
          ),
        ),
      );

      expect(find.textContaining('没有已登记的 PancakeSwap V3 池'), findsOneWidget);
    });

    testWidgets('security facts render with their own source and time', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-security-facts')),
      );
      expect(find.textContaining('合约已验证开源 —— 来源 GoPlus，观察于'), findsOneWidget);
      expect(find.textContaining('不输出评级、评分或综合结论'), findsOneWidget);
    });

    testWidgets('a blocked asset hides every fact', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            value: s5Detail(
              capability: const LoopAssetCapability(
                viewable: false,
                swappable: false,
                value: LoopAssetCapabilityValue.blocked,
                reasonCode: 'ASSET_BLOCKED',
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('token-asset-blocked')),
        findsOneWidget,
      );
      expect(find.text('\$747.39'), findsNothing);
    });

    testWidgets('a not-found asset is an error state, not an empty page', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            failure: LoopChainFailureKind.notFound,
          ),
        ),
      );

      expect(find.byType(LoopErrorState), findsWidgets);
      expect(find.textContaining('目标不存在、未登记'), findsWidgets);
    });
  });

  group('chart-full', () {
    testWidgets('the intervals map one to one onto the contract', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      for (final interval in LoopCandleInterval.values) {
        expect(
          find.byKey(ValueKey<String>('candle-interval-${interval.wireName}')),
          findsOneWidget,
        );
      }
      // The prototype's 1m segment has no backend and is absent.
      expect(find.text('1m'), findsNothing);
    });

    testWidgets('the indicator tools are unavailable, not inert controls', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('chart-full-indicators-unavailable')),
      );
      expect(find.textContaining('指标与画线工具'), findsWidgets);
    });

    testWidgets('changing the interval requests that exact interval', (
      tester,
    ) async {
      final market = FakeMarketReadGateway();
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: market,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('candle-interval-1d')),
      );
      await tester.pumpAndSettle();

      expect(market.intervals, contains(LoopCandleInterval.oneDay));
    });
  });

  group('token-holders', () {
    testWidgets('only the count is shown; the distribution is unavailable', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const HolderDistributionScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      expect(find.textContaining('8,019,338 持有人'), findsOneWidget);
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-holders-distribution')),
      );
      expect(find.textContaining('持有人分布需要全量历史'), findsOneWidget);
      // No invented concentration percentages.
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('token-trades', () {
    testWidgets('an unavailable tape is not an empty list', (tester) async {
      await pumpS5Page(
        tester,
        const TradingActivityScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          trades: S5Answer<MarketTradesPage>(
            value: const MarketTradesPage(
              assetId: s5WbnbAssetId,
              trades: MarketTradesUnavailable('BSC_POOL_INDEXER_NOT_STARTED'),
            ),
          ),
        ),
      );

      expect(find.textContaining('池事件索引尚未运行'), findsOneWidget);
    });

    testWidgets('a row marks ownership and confirmation, not an address', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TradingActivityScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          trades: S5Answer<MarketTradesPage>(
            value: MarketTradesPage(
              assetId: s5WbnbAssetId,
              trades: MarketTradesAvailable(
                source: LoopFactSource.loopIndexer,
                items: <MarketTrade>[
                  MarketTrade(
                    transactionHash: s5TxHash,
                    logIndex: 12,
                    blockNumber: BigInt.from(120640705),
                    blockHash: s5BlockHash,
                    blockTimestamp: DateTime.utc(2026, 9, 8, 7, 30),
                    confirmations: 101,
                    status: LoopConfirmationStatus.confirmed,
                    direction: MarketTradeDirection.buy,
                    amountAsset: Decimal.parse('1.25'),
                    amountQuote: Decimal.parse('934.35'),
                    quoteAssetId: s5UsdtAssetId,
                    quoteSymbol: 'USDT',
                    priceAfter: Decimal.parse('747.48'),
                    poolAddress: s5PoolAddress,
                    isOwn: true,
                  ),
                ],
                nextCursor: null,
                freshness: LoopIndexerFreshness(
                  indexerBlockNumber: BigInt.from(120640710),
                  headBlockNumber: BigInt.from(120640743),
                  lagBlocks: 33,
                  observedAt: DateTime.utc(2026, 9, 8, 7, 31),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('买入 934.35 USDT'), findsOneWidget);
      expect(find.textContaining('我 · 已确认 · 101 确认'), findsOneWidget);
      expect(find.textContaining('不下发对手方地址'), findsOneWidget);
    });

    testWidgets('the smart-money segment is disabled and explains itself', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TradingActivityScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('market-seg-聪明钱')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('market-seg-聪明钱')));
      await tester.pumpAndSettle();
      // The disabled segment cannot become the selection.
      expect(
        find.byKey(const ValueKey<String>('token-trades-smart-money')),
        findsNothing,
      );
    });
  });

  group('new-pairs and smart-money', () {
    testWidgets('new-pairs is a whole-page unavailable with the reason', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const NewPairsScreen(),
        market: FakeMarketReadGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('new-pairs-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('GeckoTerminal 未启用'), findsWidgets);
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('new-pairs-risk-screening')),
      );
      expect(find.textContaining('预筛不等于结论'), findsOneWidget);
    });

    testWidgets('smart-money never lists an address or a win rate', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const SmartMoneyScreen(),
        market: FakeMarketReadGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('smart-money-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('聪明钱追踪尚未交付'), findsOneWidget);
      expect(find.textContaining('胜率'), findsWidgets);
      expect(find.textContaining('0x'), findsNothing);
    });
  });

  group('asset route round trip', () {
    testWidgets('go_router hands the page back the exact CAIP identity', (
      tester,
    ) async {
      // The canonical location percent-encodes the CAIP colons. If go_router
      // normalised them differently the page would fail closed on its own
      // link, so the round trip is guarded rather than assumed.
      String? parsed;
      final router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(path: '/', builder: (context, state) => const SizedBox()),
          GoRoute(
            path: MarketAssetRoute.tokenPath,
            builder: (context, state) {
              parsed = MarketAssetRoute.parse(
                state.uri,
                MarketAssetRoute.tokenPath,
              );
              return const SizedBox();
            },
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      router.go(MarketAssetRoute.token(s5WbnbAssetId));
      await tester.pumpAndSettle();

      expect(parsed, s5WbnbAssetId);
    });
  });
}
