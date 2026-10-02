import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/token_screen.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

void main() {
  testWidgets(
    'selected chart candle updates exact OHLC and resets on deselection',
    (tester) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        size: const Size(390, 1800),
      );
      final chart = tester.widget<LoopCandleChart>(
        find.byType(LoopCandleChart),
      );
      expect(chart.candles.length, greaterThan(1));
      chart.onCandleSelected!(chart.candles.first);
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('candle-selection-time')),
        findsOneWidget,
      );
      expect(
        find.text('O ${loopFormatCandlePrice(chart.candles.first.open)}'),
        findsOneWidget,
      );
      chart.onCandleSelected!(null);
      await tester.pump();
      expect(
        find.text('O ${loopFormatCandlePrice(chart.candles.last.open)}'),
        findsOneWidget,
      );
      chart.onCandleSelected!(chart.candles.first);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('token-interval-4h')));
      await tester.pumpAndSettle();
      final label = tester.widget<Text>(
        find.byKey(const ValueKey<String>('candle-selection-time')),
      );
      expect(label.data, startsWith('最新'));
      expect(tester.takeException(), isNull);
    },
  );
}
