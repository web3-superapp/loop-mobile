import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';

import 'support/loop_ground_probe.dart';

List<LoopCandle> candles({int count = 60, String? flat}) =>
    List.generate(count, (i) {
      final price = Decimal.parse(flat ?? '${100 + i}');
      return LoopCandle(
        openTime: DateTime.utc(
          2026,
          1,
          1,
        ).add(Duration(hours: i < 30 ? i : i + 10)),
        closeTime: DateTime.utc(
          2026,
          1,
          1,
        ).add(Duration(hours: (i < 30 ? i : i + 10) + 1)),
        open: price,
        high: price,
        low: price,
        close: price,
        volume: Decimal.one,
        swapCount: 1,
        isOpen: false,
      );
    });
Future<void> pumpChart(
  WidgetTester tester,
  List<LoopCandle> data, {
  double width = 360,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: LoopCandleChart(
            candles: data,
            semanticLabel: '价格历史',
            height: 300,
            movingAveragePeriods: const [7],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String range(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('candle-visible-range')))
    .data!;
void main() {
  loopWatchGround();
  test('historical moving average outside a gap viewport leaves the plot rather than flattening', () {
    final data = [
      ...candles(count: 15, flat: '1'),
      ...candles(count: 45, flat: '1000'),
    ];
    final firstVisibleAverage = loopCandleMovingAverage(data, 7)[15];
    expect(firstVisibleAverage, lessThan(Decimal.fromInt(990)));
    final y = loopCandlePriceY(
      firstVisibleAverage,
      lowest: Decimal.fromInt(990),
      highest: Decimal.fromInt(1010),
      top: 8,
      bottom: 180,
    );
    expect(y, greaterThan(180));
    expect(
      loopCandlePriceY(
        Decimal.fromInt(1000),
        lowest: Decimal.fromInt(990),
        highest: Decimal.fromInt(1010),
        top: 8,
        bottom: 180,
      ),
      94,
    );
  });
  for (final width in [360.0, 390.0]) {
    testWidgets('pan zoom and latest reset at $width', (tester) async {
      await pumpChart(tester, candles(), width: width);
      final initial = range(tester);
      expect(initial, contains('16–60'));
      await tester.drag(
        find.byKey(const ValueKey('loop-candle-chart-canvas')),
        const Offset(130, 0),
      );
      await tester.pumpAndSettle();
      expect(range(tester), isNot(initial));
      await tester.tap(find.byKey(const ValueKey('candle-zoom-in')));
      await tester.pumpAndSettle();
      expect(range(tester), contains('/60'));
      await tester.tap(find.byKey(const ValueKey('candle-reset')));
      await tester.pumpAndSettle();
      expect(range(tester), initial);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'selection uses an existing timestamp and clears when data empties',
    (tester) async {
      final data = candles();
      await pumpChart(tester, data);
      await tester.tapAt(
        tester.getTopLeft(
              find.byKey(const ValueKey('loop-candle-chart-canvas')),
            ) +
            const Offset(120, 70),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('candle-selection')), findsOneWidget);
      await pumpChart(tester, []);
      expect(find.byKey(const ValueKey('candle-selection')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('flat tiny prices and one bucket have a usable chart', (
    tester,
  ) async {
    await pumpChart(tester, candles(flat: '0.00000000000001234'));
    expect(range(tester), contains('16–60'));
    await pumpChart(tester, candles(count: 1, flat: '0'));
    expect(range(tester), contains('1–1'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'wheel zoom and pan preserve full-history averages and latest quote',
    (tester) async {
      final data = candles();
      await pumpChart(tester, data);
      final canvas = find.byKey(const ValueKey('loop-candle-chart-canvas'));
      final initial = range(tester);
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getTopLeft(canvas) + const Offset(120, 90),
          scrollDelta: const Offset(0, -180),
        ),
      );
      await tester.pumpAndSettle();
      expect(range(tester), isNot(initial));
      await tester.drag(canvas, const Offset(100, 0));
      await tester.pumpAndSettle();
      final dynamic painter = tester.widget<CustomPaint>(canvas).painter;
      // Inspect the private painter's immutable inputs without exporting a test-only API.
      // ignore: avoid_dynamic_calls
      final List<LoopCandle> visible = painter.candles as List<LoopCandle>;
      final first = data.indexOf(visible.first);
      final List<List<Decimal>> averages =
          // ignore: avoid_dynamic_calls
          painter.averages as List<List<Decimal>>;
      expect(averages.first.first, loopCandleMovingAverage(data, 7)[first]);
      // ignore: avoid_dynamic_calls
      expect(painter.latest, same(data.last));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getTopLeft(canvas) + const Offset(120, 90),
          scrollDelta: const Offset(0, 2000),
        ),
      );
      await tester.pumpAndSettle();
      expect(range(tester), contains('1–60/60'));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: tester.getTopLeft(canvas) + const Offset(120, 90),
          scrollDelta: const Offset(0, -2000),
        ),
      );
      await tester.pumpAndSettle();
      final bounds = range(tester)
          .split('/')
          .first
          .split('–')
          .map(int.parse)
          .toList();
      expect(bounds.last - bounds.first + 1, 8);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pinch zoom and selection callback use real candles across gaps',
    (tester) async {
      final data = candles();
      LoopCandle? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: LoopCandleChart(
                candles: data,
                semanticLabel: '价格历史',
                height: 300,
                onCandleSelected: (value) => selected = value,
              ),
            ),
          ),
        ),
      );
      final canvas = find.byKey(const ValueKey('loop-candle-chart-canvas'));
      final origin = tester.getTopLeft(canvas);
      final dynamic initialPainter = tester.widget<CustomPaint>(canvas).painter;
      // ignore: avoid_dynamic_calls
      final width = 360 - (initialPainter.axisWidth as double) - 12;
      // 34:00 is inside the missing 30..39 interval, nearest the real 29:00 bucket.
      await tester.tapAt(
        origin + Offset(6 + (34 - 15) / (69 - 15) * width, 80),
      );
      await tester.pumpAndSettle();
      expect(selected, same(data[29]));
      final before = range(tester);
      final first = await tester.startGesture(
        origin + const Offset(80, 100),
        pointer: 1,
      );
      final second = await tester.startGesture(
        origin + const Offset(160, 100),
        pointer: 2,
      );
      await tester.pump();
      await first.moveTo(origin + const Offset(40, 100));
      await second.moveTo(origin + const Offset(210, 100));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(range(tester), isNot(before));
      expect(selected, isNull);
      await tester.tapAt(origin + const Offset(120, 80));
      await tester.pumpAndSettle();
      expect(data.contains(selected), isTrue);
      expect(selected!.openTime.hour, isNotNull);
      await tester.tap(find.byKey(const ValueKey('candle-reset')));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    },
  );
}
