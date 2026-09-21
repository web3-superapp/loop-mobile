import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

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
    testWidgets('the hero states a reading, not the page\'s own name', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
      );

      final folio = _folios(tester).first;
      // `.folio-heading` carries a conclusion — the prototype's
      // 「PEPE 领涨 +12.4%」 — and never the title in the bar above it.
      expect(folio.heading, isNot('行情信号'));
      expect(folio.heading, 'WBNB 领涨 +0.27%');
      // `.folio-stamp` is a settled figure, not the module's name.
      expect(folio.stamp, '1 WATCHED');
      expect(folio.caption, contains('1 个自选'));
      expect(folio.caption, contains('1 涨 0 跌'));
    });

    testWidgets('a hero with no readable change never claims a leader', (
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

      final folio = _folios(tester).first;
      expect(folio.heading, '1 个自选 · 涨跌读不到');
      expect(folio.caption, contains('1 项涨跌读不到'));
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
        find.byKey(const ValueKey<String>('market-watchlist-provenance')),
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

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('market-asset-$s5WbnbAssetId')).first,
      );
      expect(row.subtitle, contains('权重 1×'));
      // A development baseline labels every figure it produced.
      expect(row.subtitle, contains(miningBaselineLabel));
      // `.row-s .mining-accent`: the weight has its own voice inside the line.
      expect(row.subtitleSpans, isNotNull);
    });

    testWidgets('a weight nothing published is left off, never shown as 1×', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
      );

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('market-asset-$s5WbnbAssetId')).first,
      );
      expect(row.subtitle, isNot(contains('权重')));
      expect(row.subtitleSpans, isNull);
    });

    testWidgets('自选 is a text pill in the bar, not a bare glyph', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
      );

      final seg = tester.widget<LoopSeg>(
        find.byKey(const ValueKey<String>('market-watchlist-action')),
      );
      expect(seg.label, '自选');
      expect(seg.onSelected, isNotNull);
    });
  });

  group('token · the card is the page\'s first block', () {
    testWidgets('原型没有 hero 的页不再多压一张', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      // No `page-primary` folio at all: the signature card is the primary
      // region, exactly as `#scr-token` declares it.
      expect(find.byType(LoopFolioPrimary), findsNothing);
      expect(find.byKey(const ValueKey<String>('token-card')), findsOneWidget);
      expect(find.text('TOKEN FACTS'), findsNothing);
    });

    testWidgets('买入 与 卖出 留在卡上，关着，理由只说一次', (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      final card = tester.widget<LoopTokenCard>(
        find.byKey(const ValueKey<String>('token-card')),
      );
      expect(card.actions.map((action) => action.label).toList(), <String>[
        '买入',
        '卖出',
        '图表',
      ]);
      expect(card.actions.first.buy, isTrue);
      // Shut, not hidden: the segment takes no tap while the gate is closed.
      expect(card.actions.first.onTap, isNull);
      expect(card.actions[1].onTap, isNull);
      expect(card.actions[2].onTap, isNotNull);
      // The card points at the one card that carries the whole sentence.
      expect(card.model.footnotes, contains('买入与卖出当前不可用，原因见本页底部。'));
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-swap-unavailable')),
      );
      expect(
        find.textContaining(loopReasonCodeText('BSC_WRITES_DISABLED')),
        findsOneWidget,
      );
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

      final card = tester.widget<LoopTokenCard>(
        find.byKey(const ValueKey<String>('token-card')),
      );
      // `.tcard-community` is the mining strip, not a provenance note.
      expect(card.model.communityLine, contains('Mining Weight 1×'));
      expect(card.model.communityIcon, 'mine');
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-mining-weight')),
      );
      expect(
        find.byKey(const ValueKey<String>('token-mining-unavailable')),
        findsNothing,
      );
    });

    testWidgets('no weight keeps the module-wide refusal, never a 1×', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      final card = tester.widget<LoopTokenCard>(
        find.byKey(const ValueKey<String>('token-card')),
      );
      expect(card.model.communityLine, isNot(contains('Mining Weight')));
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

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('token-holders-entry')),
      );
      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('token-holders-entry')),
      );
      expect(row.subtitle, startsWith('8,019,338 持有人'));
    });

    testWidgets('a page that could not read the asset still opens as a card', (
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
      expect(
        find.byKey(const ValueKey<String>('token-card-loading')),
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

    testWidgets('MA 与 VOL 可切换，EMA / MACD / RSI 关着', (tester) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      final bar = tester.widget<MarketSegmentBar>(
        find.byKey(const ValueKey<String>('chart-full-indicators')),
      );
      expect(bar.labels, <String>['MA', 'EMA', 'MACD', 'RSI', 'VOL']);
      expect(bar.enabled, <bool>[true, false, false, false, true]);
      expect(bar.selectedIndices, <int>{0, 4});

      final chart = tester.widget<LoopCandleChart>(
        find.byType(LoopCandleChart),
      );
      expect(chart.movingAveragePeriods, <int>[7, 25]);
      expect(chart.showVolume, isTrue);

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
      expect(_folios(tester).first.stamp, 'HIGH RISK');
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
      expect(_folios(tester).first.kicker, 'PUBLIC WALLET WATCH');
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
