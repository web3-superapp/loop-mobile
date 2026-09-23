import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_card_chart.dart';
import 'package:loop_mobile/features/market/token_screen.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// The Token Card's small line, and the two states it has.
///
/// The line is not decoration: it is the last 24 closes of
/// `GET /v2/market/assets/{assetId}/candles?interval=1h`, normalised the same
/// way [LoopCandleChart] normalises its own OHLC. When the series is
/// unavailable, empty or unread, the card draws **nothing** and states the
/// server's reason instead — a shape with no data behind it would be a fact the
/// server never stated.
void main() {
  group('normalisation', () {
    test('keeps only the last 24 closes, newest last', () {
      final candles = <LoopCandle>[
        for (var hour = 0; hour < 30; hour++)
          s5ModelCandle(hour: hour % 24, close: '${700 + hour}'),
      ];

      final closes = loopSparklineCloses(candles);
      expect(closes, hasLength(loopSparklineWindow));
      expect(closes.first, Decimal.parse('706'));
      expect(closes.last, Decimal.parse('729'));
      // A shorter series is a shorter line; nothing is padded.
      expect(loopSparklineCloses(candles.take(5).toList()), hasLength(5));
      expect(loopSparklineCloses(const <LoopCandle>[]), isEmpty);
    });

    test(
      'maps the lowest close to the floor and the highest to the ceiling',
      () {
        const size = Size(100, 40);
        final closes = <Decimal>[
          Decimal.parse('10'),
          Decimal.parse('20'),
          Decimal.parse('30'),
        ];
        final points = LoopSparklinePainter.points(closes, size);
        final plot = LoopSparklinePainter.plotRect(size)!;

        expect(points, hasLength(3));
        expect(points.first.dy, closeTo(plot.bottom, 1e-9));
        expect(points.last.dy, closeTo(plot.top, 1e-9));
        expect(points[1].dy, closeTo(plot.center.dy, 1e-9));
        // The x steps are even across the plot.
        expect(points.first.dx, closeTo(plot.left, 1e-9));
        expect(points.last.dx, closeTo(plot.right, 1e-9));
      },
    );

    test('an unchanged price is a flat line, not a divide by zero', () {
      const size = Size(100, 40);
      final flat = <Decimal>[
        Decimal.parse('747.482453211647133359'),
        Decimal.parse('747.482453211647133359'),
      ];
      final plot = LoopSparklinePainter.plotRect(size)!;

      for (final point in LoopSparklinePainter.points(flat, size)) {
        expect(point.dy, closeTo(plot.center.dy, 1e-9));
      }
      // Precision a `double` would lose still separates two closes.
      final precise = <Decimal>[
        Decimal.parse('747.482453211647133359'),
        Decimal.parse('747.482453211647133360'),
      ];
      final points = LoopSparklinePainter.points(precise, size);
      expect(points.first.dy, closeTo(plot.bottom, 1e-9));
      expect(points.last.dy, closeTo(plot.top, 1e-9));
    });

    test('nothing is drawn without a plot or a close', () {
      expect(LoopSparklinePainter.plotRect(Size.zero), isNull);
      expect(
        LoopSparklinePainter.points(<Decimal>[Decimal.one], Size.zero),
        isEmpty,
      );
      expect(
        LoopSparklinePainter.points(const <Decimal>[], const Size(100, 40)),
        isEmpty,
      );
    });
  });

  group('token · the page opens on the quote, not on a card', () {
    testWidgets(
      'the quote, the four cells and the two actions, in that order',
      (tester) async {
        await pumpS5Page(
          tester,
          const TokenDetailScreen(assetId: s5WbnbAssetId),
          market: FakeMarketReadGateway(),
        );

        // S78b: the approved design opens on the price itself. The signature
        // card spent a third of the first screen on its own border and pushed
        // the chart off it, and its small 1H line said the same thing the K
        // line under it says at eight times the size.
        expect(find.byKey(const ValueKey<String>('token-card')), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('token-quote')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('token-quote-cells')),
          findsOneWidget,
        );
        // S82a: the two actions moved into the pinned bar at the foot of the
        // page, so they are reachable from wherever in the page the reader is.
        expect(
          find.byKey(const ValueKey<String>('token-trade-bar')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('token-buy-action')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('token-sell-action')),
          findsOneWidget,
        );
        // The chart on this page is the K line, and there is exactly one of it.
        expect(
          find.byKey(const ValueKey<String>('token-card-chart-line')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('token-candle-chart')),
          findsOneWidget,
        );
      },
    );

    testWidgets('an unavailable series is stated once, by the K line', (
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
              candles: MarketCandlesUnavailable('MARKET_POOL_NOT_INDEXED'),
            ),
          ),
        ),
      );

      // No line at all — never a flat or a placeholder shape.
      expect(find.byType(LoopSparkline), findsNothing);
      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('candles-unavailable')),
      );
      expect(
        find.byKey(const ValueKey<String>('candles-unavailable')),
        findsOneWidget,
      );
      // The reason appears exactly once on the page.
      expect(
        find.textContaining(loopReasonCodeText('MARKET_POOL_NOT_INDEXED')),
        findsOneWidget,
      );
    });
  });

  group('the widget is reusable outside the token page', () {
    testWidgets('community-profile drives the same line from the same port', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const Scaffold(
          body: SizedBox(
            height: 80,
            child: TokenCardSparkline(
              assetId: s5WbnbAssetId,
              keyPrefix: 'community-bound-asset-chart',
            ),
          ),
        ),
        market: FakeMarketReadGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('community-bound-asset-chart-line')),
        findsOneWidget,
      );
    });
  });
}
