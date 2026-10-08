import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
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

/// Opens 关于 under the token chart (decision 0118).
Future<void> _openAbout(WidgetTester tester) async {
  await scrollToS5Section(
    tester,
    find.byKey(const ValueKey<String>('token-section-tabs')),
  );
  await tester.tap(find.byKey(const ValueKey<String>('token-tab-关于')));
  await tester.pumpAndSettle();
}

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
      // Decision 0118: no statistics line and no sortable header; the server
      // orders each list and says so on the source line.
      expect(find.byKey(const ValueKey<String>('market-stats')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('market-column-header')),
        findsNothing,
      );
    });

    testWidgets('每行画 1H 走势线，并把出处收进整块的落款', (tester) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
      );

      // Decision 0118: the Fomo row carries no line; the block's own source
      // line names the source once for the rows it just listed.
      expect(
        find.byKey(const ValueKey<String>('market-list-provenance')),
        findsOneWidget,
      );
      expect(find.textContaining('来源 DexScreener'), findsWidgets);
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
      // Decision 0118: the bar states the ticker; the line under it names the
      // asset and its contract.
      expect(find.text('WBNB'), findsWidgets);
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
      await _openAbout(tester);
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
      await _openAbout(tester);
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

      await _openAbout(tester);
      // Decision 0118: no weight is simply no line — never a 1×.
      expect(
        find.byKey(const ValueKey<String>('token-mining-weight')),
        findsNothing,
      );
      expect(find.textContaining('1×'), findsNothing);
    });

    testWidgets('a row that can read a value states it, not what it is for', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      // Decision 0118: 持有者 is the first tab and states the count itself.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('token-holders-count')),
          matching: find.text('8,019,338'),
        ),
        findsOneWidget,
      );
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
      expect(find.text('\$747.39 ▲ 0.27%'), findsOneWidget);
    });

    testWidgets('MA 与 VOL 可切换，EMA / MACD / RSI 不出现', (tester) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      // Nothing draws EMA, MACD or RSI and nothing is going to in this
      // build, so they are not rendered at all (S77a).
      expect(find.text('EMA'), findsNothing);
      expect(find.text('MACD'), findsNothing);
      expect(find.text('RSI'), findsNothing);

      // Decision 0118: MA off and VOL on by default, both switchable.
      var chart = tester.widget<LoopMarketChart>(find.byType(LoopMarketChart));
      expect(chart.showMovingAverages, isFalse);
      expect(chart.showVolume, isTrue);
      expect(LoopMarketChart.averagePeriods, <int>[7, 25]);

      await tester.tap(find.byKey(const ValueKey<String>('token-chart-ma')));
      await tester.pumpAndSettle();
      chart = tester.widget<LoopMarketChart>(find.byType(LoopMarketChart));
      expect(chart.showMovingAverages, isTrue);
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
      // Decision 0087: the word moved into the glyph's name.
      final create = tester.widget<LoopIconButton>(
        find.byKey(const ValueKey<String>('alerts-create-action')),
      );
      expect(create.label, '新建');
      expect(create.icon, 'plus');
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
      final done = tester.widget<LoopIconButton>(
        find.byKey(const ValueKey<String>('watchlist-save-action')),
      );
      expect(done.label, '完成');
      expect(done.icon, 'check');
      // The prototype's order: the list the page exists to edit comes first.
      final hint = tester.getTopLeft(find.text('拖动排序 · 左滑删除')).dy;
      final groups = tester.getTopLeft(find.text('分组')).dy;
      expect(hint, lessThan(groups));
      // `.badge.badge-down`: a word, not a bin glyph.
      expect(find.text('删除'), findsWidgets);
    });
  });
}
