// S131 / decision 0135: the inline token chart pans and pinches inside a
// scrolling page (audit 2026-10-09 m6), its crosshair ticks as it steps, and
// the docked unread pill's two buttons are 44 pt touch targets with a press
// state and a light touch.
import 'package:decimal/decimal.dart';
import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/loop_chart_gestures.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/integrations/communication/stream_unread_pill_band.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

List<LoopCandle> _candles(int count) => <LoopCandle>[
  for (var index = 0; index < count; index += 1)
    LoopCandle(
      openTime: DateTime.utc(2026, 10, 1).add(Duration(hours: index)),
      closeTime: DateTime.utc(2026, 10, 1).add(Duration(hours: index + 1)),
      open: Decimal.parse('${100 + index % 7}'),
      high: Decimal.parse('${110 + index % 7}'),
      low: Decimal.parse('${95 + index % 7}'),
      close: Decimal.parse('${101 + (index * 3) % 11}'),
      volume: Decimal.parse('${10 + index % 5}'),
      swapCount: 3,
      isOpen: index == count - 1,
    ),
];

/// The chart where the token page puts it: one block in a vertical list,
/// with content above and below it.
Future<ScrollController> _pumpInlineChart(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 800);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(
        backgroundColor: LoopColors.ink,
        body: ListView(
          controller: controller,
          children: <Widget>[
            const SizedBox(height: 200),
            LoopMarketChart(
              candles: _candles(300),
              interval: LoopCandleInterval.oneHour,
              semanticLabel: 'chart',
            ),
            const SizedBox(height: 1600),
          ],
        ),
      ),
    ),
  );
  return controller;
}

LoopMarketChartState _chart(WidgetTester tester) =>
    tester.state<LoopMarketChartState>(find.byType(LoopMarketChart));

/// A point on the chart's plot, clear of the left edge guard.
const Offset _onChart = Offset(200, 330);

void main() {
  late List<LoopHaptic> played;
  setUp(() => played = LoopHaptics.debugRecord());
  tearDown(() => LoopHaptics.debugPlayer = null);

  group('inline chart gestures (m6)', () {
    testWidgets('a sideways drag pans the window and leaves the page still', (
      tester,
    ) async {
      final page = await _pumpInlineChart(tester);
      // A real thumb drifts and reports in small steps: 35 degrees off the
      // horizontal, 4 pt sideways and 2.8 pt down per event. The page's
      // vertical drag would take this at 18 pt down, before a plain scale
      // recognizer's 36 pt of travel; the chart claims it at 18 pt sideways.
      final gesture = await tester.startGesture(_onChart);
      for (var step = 0; step < 30; step += 1) {
        await gesture.moveBy(const Offset(4, 2.8));
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_chart(tester).viewport.endOffset, greaterThan(0));
      expect(page.offset, 0);

      final moved = _chart(tester).viewport.endOffset;
      await tester.dragFrom(_onChart, const Offset(-120, -30));
      await tester.pumpAndSettle();
      expect(_chart(tester).viewport.endOffset, lessThan(moved));
      expect(page.offset, 0);
    });

    testWidgets('an upward drag on the chart scrolls the page', (tester) async {
      final page = await _pumpInlineChart(tester);
      final before = _chart(tester).viewport;
      await tester.dragFrom(_onChart, const Offset(30, -200));
      await tester.pumpAndSettle();
      expect(page.offset, greaterThan(100));
      expect(_chart(tester).viewport, before);
    });

    testWidgets('a pinch inside the page narrows the window', (tester) async {
      final page = await _pumpInlineChart(tester);
      expect(_chart(tester).viewport.visible, LoopChartViewport.defaultVisible);
      final left = await tester.startGesture(_onChart - const Offset(20, 10));
      final right = await tester.startGesture(_onChart + const Offset(20, 10));
      await tester.pump();
      for (var step = 1; step <= 6; step += 1) {
        final spread = 20.0 + 100 * step / 6;
        await left.moveTo(_onChart - Offset(spread, spread / 2));
        await right.moveTo(_onChart + Offset(spread, spread / 2));
        await tester.pump();
      }
      await left.up();
      await right.up();
      await tester.pumpAndSettle();
      expect(
        _chart(tester).viewport.visible,
        lessThan(LoopChartViewport.defaultVisible),
      );
      expect(page.offset, 0);
    });

    testWidgets('a touch that stops a coasting page does not pan the chart', (
      tester,
    ) async {
      final page = await _pumpInlineChart(tester);
      await tester.flingFrom(
        const Offset(200, 700),
        const Offset(0, -300),
        3000,
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      final position = page.position;
      expect(position.isScrollingNotifier.value, isTrue);
      // The chart has moved up with the page; touch it where it is now.
      final chart = tester.getRect(find.byType(LoopMarketChart));
      expect(chart.bottom, greaterThan(100));
      final at = Offset(200, chart.bottom - 60);
      await tester.dragFrom(at, const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(_chart(tester).viewport.endOffset, 0);
    });

    testWidgets('the chart uses the shared arbitration recognizers', (
      tester,
    ) async {
      await _pumpInlineChart(tester);
      final detector = tester.widget<RawGestureDetector>(
        find.byKey(const ValueKey<String>('loop-market-chart-gestures')),
      );
      expect(
        detector.gestures.keys,
        containsAll(<Type>[
          LoopChartScaleGestureRecognizer,
          LongPressGestureRecognizer,
        ]),
      );
    });

    testWidgets('the crosshair picks up once and ticks per bucket', (
      tester,
    ) async {
      await _pumpInlineChart(tester);
      final gesture = await tester.startGesture(_onChart);
      await tester.pump(const Duration(milliseconds: 700));
      expect(_chart(tester).crosshairIndex, isNotNull);
      expect(played, <LoopHaptic>[LoopHaptic.medium]);

      final first = _chart(tester).crosshairIndex;
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(_chart(tester).crosshairIndex, isNot(first));
      expect(played.first, LoopHaptic.medium);
      expect(played.skip(1), isNotEmpty);
      expect(played.skip(1), everyElement(LoopHaptic.selection));

      // Holding still on the same bucket plays nothing more.
      final count = played.length;
      await gesture.moveBy(const Offset(0.1, 0));
      await tester.pump();
      expect(played.length, count);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(_chart(tester).crosshairIndex, isNull);
    });
  });

  group('unread pill touch targets', () {
    Widget host(Widget child) => MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('both buttons are at least 44 pt and the face is unchanged', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LoopUnreadJumpPill(
                label: '4 条未读',
                onJump: () {},
                onDismiss: () {},
              ),
              StreamJumpToUnreadButton(
                label: '4 条未读',
                onJumpPressed: () {},
                onDismissPressed: () {},
              ),
            ],
          ),
        ),
      );
      final jump = tester.getSize(
        find.byKey(const ValueKey<String>('loop-unread-pill-jump')),
      );
      final dismiss = tester.getSize(
        find.byKey(const ValueKey<String>('loop-unread-pill-dismiss')),
      );
      expect(jump.height, greaterThanOrEqualTo(LoopTouch.minimum));
      expect(jump.width, greaterThanOrEqualTo(LoopTouch.minimum));
      expect(dismiss.height, greaterThanOrEqualTo(LoopTouch.minimum));
      expect(dismiss.width, greaterThanOrEqualTo(LoopTouch.minimum));

      // The visible pill is the size Stream's own pill is.
      final face = tester.getSize(
        find.byKey(const ValueKey<String>('loop-unread-pill-face')),
      );
      final stream = tester.getSize(find.byType(StreamJumpToUnreadButton));
      expect(face.width, moreOrLessEquals(stream.width, epsilon: 0.5));
      expect(face.height, moreOrLessEquals(stream.height, epsilon: 0.5));

      // A hit just outside the face, inside the 44 pt area, still lands.
      final faceRect = tester.getRect(
        find.byKey(const ValueKey<String>('loop-unread-pill-face')),
      );
      final dismissRect = tester.getRect(
        find.byKey(const ValueKey<String>('loop-unread-pill-dismiss')),
      );
      expect(dismissRect.right, greaterThan(faceRect.right));
      expect(dismissRect.top, lessThan(faceRect.top));
      handle.dispose();
    });

    testWidgets('a tap dims the pressed part and plays a light touch', (
      tester,
    ) async {
      var jumps = 0;
      var dismissals = 0;
      await tester.pumpWidget(
        host(
          LoopUnreadJumpPill(
            label: '4 条未读',
            onJump: () => jumps += 1,
            onDismiss: () => dismissals += 1,
          ),
        ),
      );
      final dismissKey = find.byKey(
        const ValueKey<String>('loop-unread-pill-dismiss'),
      );
      final dismissRect = tester.getRect(dismissKey);
      // Press at the area's outer corner, outside the drawn face.
      final gesture = await tester.startGesture(
        dismissRect.topRight + const Offset(-1, 1),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(of: dismissKey, matching: find.byType(AnimatedOpacity)),
      );
      expect(opacity.opacity, LoopMotion.pressOpacity);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(dismissals, 1);
      expect(played, <LoopHaptic>[LoopHaptic.light]);

      await tester.tap(find.text('4 条未读'));
      await tester.pumpAndSettle();
      expect(jumps, 1);
      expect(played, <LoopHaptic>[LoopHaptic.light, LoopHaptic.light]);
    });
  });
}
