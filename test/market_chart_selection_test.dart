import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

void main() {
  for (final width in <double>[360, 390]) {
    for (final fullScreen in <bool>[false, true]) {
      testWidgets(
        'unboxed chart keeps data and plot visible at $width full=$fullScreen',
        (tester) async {
          await pumpS5Page(
            tester,
            fullScreen
                ? const FullChartScreen(assetId: s5WbnbAssetId)
                : const TokenDetailScreen(assetId: s5WbnbAssetId),
            market: FakeMarketReadGateway(),
            size: Size(width, 844),
          );
          final canvas = find.byKey(
            const ValueKey<String>('loop-candle-chart-canvas'),
          );
          final rect = tester.getRect(canvas);
          expect(rect.width, greaterThanOrEqualTo(width - 16));
          expect(rect.height, greaterThanOrEqualTo(330));
          expect(rect.bottom, lessThan(844));
          expect(
            find.ancestor(of: canvas, matching: find.byType(LoopSurfaceCard)),
            findsNothing,
          );
          final details = find.byKey(
            const ValueKey<String>('candle-data-details'),
          );
          expect(tester.getRect(details).bottom, lessThanOrEqualTo(844));
          expect(
            find.descendant(of: details, matching: find.textContaining('USDT')),
            findsWidgets,
          );
          final chart = tester.widget<LoopCandleChart>(
            find.byType(LoopCandleChart),
          );
          expect(
            find.text('O ${loopFormatCandlePrice(chart.candles.last.open)}'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('candles-moving-averages')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('chart keeps the quote unit visible and expands source details', (
    tester,
  ) async {
    await pumpS5Page(
      tester,
      const TokenDetailScreen(assetId: s5WbnbAssetId),
      market: FakeMarketReadGateway(),
      size: const Size(390, 1800),
    );
    final details = find.byKey(const ValueKey<String>('candle-data-details'));
    final source = find.descendant(
      of: details,
      matching: find.textContaining('观察于'),
    );
    final unit = find.descendant(
      of: details,
      matching: find.textContaining('USDT'),
    );
    expect(unit, findsWidgets);
    expect(source, findsNothing);
    await tester.ensureVisible(details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(source, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected chart candle updates exact OHLC and resets on deselection',
    (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(
          candles: S5Answer<MarketCandleSeries>(
            value: s5Series(
              items: List.generate(
                40,
                (i) => s5ModelCandle(hour: i, close: '${700 + i}'),
              ),
            ),
          ),
        ),
        size: const Size(390, 1800),
      );
      final chart = tester.widget<LoopCandleChart>(
        find.byType(LoopCandleChart),
      );
      expect(chart.candles.length, greaterThan(1));
      final canvas = find.byKey(
        const ValueKey<String>('loop-candle-chart-canvas'),
      );
      final initialRect = tester.getRect(canvas);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(
        location: initialRect.topLeft - const Offset(0, 10),
      );
      await mouse.moveTo(initialRect.topLeft + const Offset(7, 2));
      await tester.pumpAndSettle();
      expect(tester.getRect(canvas), initialRect);
      // Another hover at the original top edge must retain selection, not exit
      // because an inserted timestamp shifted the chart beneath the pointer.
      await mouse.moveTo(initialRect.topLeft + const Offset(8, 2));
      await tester.pumpAndSettle();
      expect(tester.getRect(canvas), initialRect);
      expect(
        find.text(
          loopCandleMovingAverageLabel(chart.candles.take(1).toList(), 7)!,
        ),
        findsOneWidget,
      );
      expect(
        find.text(loopCandleMovingAverageLabel(chart.candles, 7)!),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('candle-selection')),
        findsOneWidget,
      );
      expect(
        find.text('O ${loopFormatCandlePrice(chart.candles.first.open)}'),
        findsOneWidget,
      );
      await mouse.moveTo(initialRect.topLeft - const Offset(0, 10));
      await tester.pumpAndSettle();
      expect(tester.getRect(canvas), initialRect);
      expect(
        find.byKey(const ValueKey<String>('candle-selection')),
        findsNothing,
      );
      expect(
        find.text('O ${loopFormatCandlePrice(chart.candles.last.open)}'),
        findsOneWidget,
      );
      await mouse.moveTo(initialRect.topLeft + const Offset(7, 2));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('token-interval-4h')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('candle-selection')),
        findsNothing,
      );
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );
}
