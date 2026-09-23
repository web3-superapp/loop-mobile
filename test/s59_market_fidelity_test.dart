import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_mining_hooks.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// A rules answer that publishes a weight for the market fixture's asset.
FakeMiningGateway _weightedRules() => FakeMiningGateway(
  rules: S7Answer<MiningRules>(
    value: s7MiningRules(approved: s7BaselineFormulaVersion()),
  ),
);

/// Every `LoopFolioPrimary` a page mounted, in mount order.
List<LoopFolioPrimary> _folios(WidgetTester tester) =>
    tester.widgetList<LoopFolioPrimary>(find.byType(LoopFolioPrimary)).toList();

void main() {
  loopWatchGround();

  group('market · the row is the community\'s price face', () {
    testWidgets('the page opens on the list, not on a hero', (tester) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
      );

      // S78b / approved design: 行情 is a price list. A Lime hero stated one
      // row's change in 27pt and pushed the other seven below the fold.
      expect(find.byType(LoopFolioPrimary), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('market-search-field')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('market-tabs')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('market-stats')),
        findsOneWidget,
      );
      expect(find.text('自选 1 · '), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('market-column-header')),
        findsOneWidget,
      );
    });

    testWidgets('a change nothing reported is counted nowhere', (tester) async {
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
                    change: const LoopFact.unavailable(
                      'MARKET_FACT_NOT_REPORTED',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // A row whose change was not read is in neither count and is not
      // announced: 「1 项涨跌读不到」 was USDT, which has no move to report
      // (walkthrough 2026-09-23, d01). The row itself carries the block.
      final stats = tester.widget<MarketStatsLine>(
        find.byKey(const ValueKey<String>('market-stats')),
      );
      expect(stats.total, 1);
      expect(stats.up, 0);
      expect(stats.down, 0);
      expect(stats.flat, 0);
      expect(find.textContaining('读不到'), findsWidgets);
    });

    testWidgets('每行画 1H 走势线，并把出处收进整块的落款', (tester) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
      );

      // `.market-spark`: the shape the audit found missing on every row.
      expect(find.byType(LoopSparkline), findsWidgets);
      // The row's second line is no longer its provenance; the block's own
      // footer names the source once for the rows it just listed.
      expect(
        find.byKey(const ValueKey<String>('market-list-provenance')),
        findsOneWidget,
      );
      expect(find.textContaining('来源 DexScreener'), findsWidgets);
    });

    testWidgets('a published weight becomes the row\'s second line', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
        mining: _weightedRules(),
      );

      // S78b: a development baseline publishes 1× for everything it lists, so
      // a column of 「权重 1× · 开发基线」 in the accent colour said the same
      // internal thing about every row and nothing about any of them
      // (walkthrough 2026-09-23, d01). The row keeps the asset's own name.
      final row = tester.widget<MarketAssetTile>(
        find.byKey(const ValueKey<String>('market-asset-$s5WbnbAssetId')).first,
      );
      expect(row.miningWeight, isNotNull);
      expect(
        marketAssetSubtitle(row.row, weight: row.miningWeight),
        isNot(contains(miningBaselineLabel)),
      );
      expect(
        marketAssetSubtitle(row.row, weight: row.miningWeight),
        isNot(contains('权重')),
      );
      // A weight an approved, non-baseline version published is still shown.
      expect(
        marketAssetSubtitle(
          row.row,
          weight: const MarketMiningWeight(weight: '1.5', baseline: false),
        ),
        contains('权重 1.5×'),
      );
    });

    testWidgets('a weight nothing published is left off, never shown as 1×', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
      );

      final row = tester.widget<MarketAssetTile>(
        find.byKey(const ValueKey<String>('market-asset-$s5WbnbAssetId')).first,
      );
      expect(row.miningWeight, isNull);
      expect(
        marketAssetSubtitle(row.row, weight: row.miningWeight),
        isNot(contains('权重')),
      );
    });

    testWidgets('the four lists are tabs, and switching keeps the page', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
      );

      final tabs = tester.widget<MarketTabBar>(
        find.byKey(const ValueKey<String>('market-tabs')),
      );
      expect(tabs.labels, <String>['自选', '热门', '涨幅榜', '新币']);
      expect(tabs.selectedIndex, 0);

      await tester.tap(find.byKey(const ValueKey<String>('market-tab-热门')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<MarketTabBar>(
              find.byKey(const ValueKey<String>('market-tabs')),
            )
            .selectedIndex,
        1,
      );
      // The page is still the same page: the bar did not go away and no
      // skeleton replaced the list.
      expect(
        find.byKey(const ValueKey<String>('market-screen')),
        findsOneWidget,
      );
      expect(find.byType(MarketAssetTile), findsWidgets);
    });
  });

  group('token · the page opens on the quote', () {
    testWidgets('no hero, no card — the price is the first thing on it', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      expect(find.byType(LoopFolioPrimary), findsNothing);
      expect(find.byKey(const ValueKey<String>('token-card')), findsNothing);
      expect(find.byKey(const ValueKey<String>('token-quote')), findsOneWidget);
      expect(find.text('TOKEN FACTS'), findsNothing);
      // `ETH / USD` over `Ethereum · BSC · 0x…`: the bar states the pair and
      // what it is written against.
      expect(find.text('WBNB / USD'), findsOneWidget);
      expect(find.textContaining('Wrapped BNB · '), findsOneWidget);
    });

    testWidgets('买入 与 卖出 are pinned to the foot, shut, and say why once', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      // S82a: the pair moved into the pinned bar at the foot of the page, so
      // it is reachable from wherever in the page the reader is. Same one
      // gate, same two labels, and still no reason on the buttons themselves.
      expect(
        find.byKey(const ValueKey<String>('token-trade-bar')),
        findsOneWidget,
      );
      final buy = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('token-buy-action')),
      );
      final sell = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('token-sell-action')),
      );
      expect(buy.onPressed, isNull);
      expect(sell.onPressed, isNull);
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-swap-unavailable')),
      );
      expect(
        find.textContaining(loopReasonCodeText('BSC_WRITES_DISABLED')),
        findsOneWidget,
      );
    });

    testWidgets('an open gate opens the two controls in the same bar', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(
            value: s5Detail(
              capability: const LoopAssetCapability(
                viewable: true,
                swappable: true,
                value: LoopAssetCapabilityValue.swappable,
                reasonCode: null,
              ),
            ),
          ),
        ),
      );

      final buy = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('token-buy-action')),
      );
      final sell = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('token-sell-action')),
      );
      expect(buy.onPressed, isNotNull);
      expect(sell.onPressed, isNotNull);
    });

    testWidgets('a published weight replaces the module-wide refusal', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        mining: _weightedRules(),
      );

      // S78b: the weight is stated once, by the 挖矿数据 row, which is also
      // the one place that opens 挖矿. 「Mining Weight 1× · 开发基线」 was on
      // the first screen twice (walkthrough 2026-09-23, e01).
      expect(find.textContaining('Mining Weight'), findsNothing);
      expect(find.textContaining(miningBaselineLabel), findsNothing);
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-mining-weight')),
      );
      expect(
        find.byKey(const ValueKey<String>('token-mining-unavailable')),
        findsNothing,
      );
      expect(find.textContaining('挖矿权重'), findsOneWidget);
    });

    testWidgets('no weight keeps the module-wide refusal, never a 1×', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-mining-unavailable')),
      );
      expect(
        find.byKey(const ValueKey<String>('token-mining-weight')),
        findsNothing,
      );
    });

    testWidgets('a row that can read a value states it, not what it is for', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      // S82a: the entry lives under the 持有人 tab of the page's lower half.
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-section-tabs')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('token-tab-持有人')));
      await tester.pumpAndSettle();
      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('token-holders-entry')),
      );
      expect(row.subtitle, startsWith('8,019,338 持有人'));
    });

    testWidgets('a page still reading states that, and prints no figure', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          asset: S5Answer<MarketAssetDetail>(pending: true),
        ),
        settle: false,
      );

      expect(find.byType(LoopFolioPrimary), findsNothing);
      expect(find.byKey(const ValueKey<String>('token-quote')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('token-state-loading')),
        findsOneWidget,
      );
    });
  });

  group('chart-full · one hue and the prototype\'s two control rows', () {
    testWidgets('the bar states the quote, not the page\'s own name', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      expect(find.text('全屏 K 线'), findsNothing);
      expect(find.text('WBNB'), findsWidgets);
      expect(find.text('\$747.39 +0.27%'), findsOneWidget);
    });

    testWidgets('MA 与 VOL 可切换，EMA / MACD / RSI 不出现', (tester) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      final bar = tester.widget<MarketSegmentBar>(
        find.byKey(const ValueKey<String>('chart-full-indicators')),
      );
      // Nothing draws EMA, MACD or RSI and nothing is going to in this
      // build, so they are not rendered at all: a greyed chip reads as a
      // control that is temporarily broken (S77a).
      expect(bar.labels, <String>['MA', 'VOL']);
      expect(bar.enabled, <bool>[true, true]);
      expect(bar.selectedIndices, <int>{0, 1});
      expect(find.text('EMA'), findsNothing);
      expect(find.text('MACD'), findsNothing);
      expect(find.text('RSI'), findsNothing);

      final chart = tester.widget<LoopCandleChart>(
        find.byType(LoopCandleChart),
      );
      expect(chart.movingAveragePeriods, <int>[7, 25]);
      expect(chart.showVolume, isTrue);

      // The plot takes the height the page has, so the tool row can sit
      // below the fold on a short test surface.
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('market-seg-MA')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('market-seg-MA')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LoopCandleChart>(find.byType(LoopCandleChart))
            .movingAveragePeriods,
        isEmpty,
      );
    });

    testWidgets('an average is the mean of the closes already on screen', (
      tester,
    ) async {
      final candles = <LoopCandle>[
        for (var hour = 1; hour <= 4; hour += 1)
          LoopCandle(
            openTime: DateTime.utc(2026, 9, 8, hour),
            closeTime: DateTime.utc(2026, 9, 8, hour + 1),
            open: Decimal.fromInt(hour),
            high: Decimal.fromInt(hour),
            low: Decimal.fromInt(hour),
            close: Decimal.fromInt(hour),
            volume: Decimal.one,
            swapCount: 1,
            isOpen: false,
          ),
      ];

      // Clamped at the start of the series, so the line begins where the
      // data begins instead of being padded with a value nothing reported.
      expect(
        loopCandleMovingAverage(candles, 2).map((v) => v.toString()).toList(),
        <String>['1', '1.5', '2.5', '3.5'],
      );
      expect(loopCandleMovingAverage(const <LoopCandle>[], 2), isEmpty);
      expect(loopCandleMovingAverageLabel(candles, 2), 'MA2 3.5');
      expect(loopCandleMovingAverageLabel(const <LoopCandle>[], 2), isNull);
    });
  });

  group('chalk · the five pages the prototype opens on a white hero', () {
    Future<void> expectChalk(WidgetTester tester, Widget page) async {
      final folio = _folios(tester).first;
      expect(folio.variant, LoopFolioVariant.chalk);
      // `.folio-primary.folio-state::after` is the only selector that draws
      // the corner ring; a Chalk hero has none.
      expect(folio.ring, isFalse);
    }

    testWidgets('token-holders', (tester) async {
      await pumpS5Page(
        tester,
        const HolderDistributionScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );
      await expectChalk(tester, const SizedBox.shrink());
      // `.stat-grid`: the prototype's two cells, with the half that has no
      // source saying so in the figure's place.
      expect(
        find.byKey(const ValueKey<String>('token-holders-stats')),
        findsOneWidget,
      );
    });

    testWidgets('token-trades', (tester) async {
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
      await expectChalk(tester, const SizedBox.shrink());
      // `.row-ico` with the direction arrow on every row.
      expect(find.byType(MarketDirectionAvatar), findsWidgets);
    });

    testWidgets('new-pairs', (tester) async {
      await pumpS5Page(
        tester,
        const NewPairsScreen(),
        market: FakeMarketReadGateway(),
      );
      await expectChalk(tester, const SizedBox.shrink());
      expect(_folios(tester).first.stamp, marketNewPairsStamp);
      expect(_folios(tester).first.kicker, marketNewPairsKicker);
    });

    testWidgets('smart-money keeps the prototype\'s two groups', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const SmartMoneyScreen(),
        market: FakeMarketReadGateway(),
      );
      await expectChalk(tester, const SizedBox.shrink());
      expect(find.text('关注地址'), findsOneWidget);
      expect(find.text('最近动向'), findsOneWidget);
      expect(_folios(tester).first.kicker, marketSmartMoneyKicker);
    });

    testWidgets('alerts', (tester) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(),
      );
      await expectChalk(tester, const SizedBox.shrink());
      final seg = tester.widget<LoopSeg>(
        find.byKey(const ValueKey<String>('alerts-create-action')),
      );
      expect(seg.label, '新建');
    });

    testWidgets('watchlist-edit puts the list above the groups', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(),
      );
      await expectChalk(tester, const SizedBox.shrink());
      final done = tester.widget<LoopSeg>(
        find.byKey(const ValueKey<String>('watchlist-save-action')),
      );
      expect(done.label, '完成');
      // The prototype's order: the list the page exists to edit comes first.
      final hint = tester.getTopLeft(find.text('拖动排序 · 左滑删除')).dy;
      final groups = tester.getTopLeft(find.text('分组')).dy;
      expect(hint, lessThan(groups));
      // `.badge.badge-down`: a word, not a bin glyph.
      expect(find.text('删除'), findsWidgets);
    });
  });
}
