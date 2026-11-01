// S331 · decision 0261: the tab bar's glass pill is visible, stretches across
// from the old cell to the new one and settles there; a press swells the
// whole bar by 2 %. Reduced motion jumps and does not swell.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

final Finder _indicator = _key('loop-tab-indicator');

Finder _cell(String label) => find.widgetWithText(LoopTabItem, label);

const List<String> _labels = <String>['聊天', '广场', 'MEME', '情报', '钱包'];

Future<void> _pumpBar(
  WidgetTester tester, {
  int initial = 0,
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  var selected = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          bottomNavigationBar: LoopTabBar(
            selectedIndex: selected,
            onSelect: (index) => setState(() => selected = index),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The cell's slot in the row: the item box itself.
Rect _cellRect(WidgetTester tester, String label) =>
    tester.getRect(_cell(label));

void _expectRestingOn(WidgetTester tester, String label) {
  final pill = tester.getRect(_indicator);
  final cell = _cellRect(tester, label);
  expect(pill.width, moreOrLessEquals(cell.width - 8, epsilon: 0.01));
  expect(pill.left, moreOrLessEquals(cell.left + 4, epsilon: 0.01));
  expect(pill.right, moreOrLessEquals(cell.right - 4, epsilon: 0.01));
  for (final other in _labels.where((l) => l != label)) {
    expect(
      pill.contains(_cellRect(tester, other).center),
      isFalse,
      reason: 'pill must not cover $other at rest',
    );
  }
}

void main() {
  testWidgets('at rest the glass pill sits inside the selected cell', (
    tester,
  ) async {
    await _pumpBar(tester, initial: 3);
    expect(_indicator, findsOneWidget);
    final box = tester.widget<DecoratedBox>(_indicator);
    final shape = box.decoration as ShapeDecoration;
    expect(shape.color, const Color(0x1AFFFFFF));
    expect((shape.shape as StadiumBorder).side.color, const Color(0x14FFFFFF));
    _expectRestingOn(tester, '情报');
    final row = tester.getRect(_key('loop-tab-bar-float'));
    final pill = tester.getRect(_indicator);
    // Inside the bar, never spilling under it.
    expect(pill.top, greaterThan(row.top));
    expect(pill.bottom, lessThan(row.bottom));
  });

  testWidgets('switching to a neighbour stretches across both, then settles', (
    tester,
  ) async {
    await _pumpBar(tester, initial: 1);
    _expectRestingOn(tester, '广场');
    final from = _cellRect(tester, '广场');
    await tester.tap(_cell('MEME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final to = _cellRect(tester, 'MEME');
    final mid = tester.getRect(_indicator);
    expect(mid.contains(from.center), isTrue);
    expect(mid.contains(to.center), isTrue);
    await tester.pumpAndSettle();
    _expectRestingOn(tester, 'MEME');
  });

  testWidgets('a three-cell jump stretches and settles the same way', (
    tester,
  ) async {
    await _pumpBar(tester, initial: 4);
    final from = _cellRect(tester, '钱包');
    await tester.tap(_cell('广场'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final mid = tester.getRect(_indicator);
    final to = _cellRect(tester, '广场');
    // The leading edge runs out over 0.62 of the slide, so across three
    // cells it has passed the cells in between — the pill is one long bar
    // from the old cell's centre more than two cells towards the new one —
    // while the trailing edge has not left yet.
    expect(mid.contains(from.center), isTrue);
    expect(mid.contains(_cellRect(tester, '情报').center), isTrue);
    expect(mid.contains(_cellRect(tester, 'MEME').center), isTrue);
    expect(mid.width, greaterThan(2.5 * from.width));
    expect(mid.left, lessThan(to.right));
    // The trailing edge springs, but only a little past its rest.
    var narrowest = double.infinity;
    for (var i = 0; i < 30; i += 1) {
      await tester.pump(const Duration(milliseconds: 10));
      final rect = tester.getRect(_indicator);
      if (rect.width < narrowest) narrowest = rect.width;
    }
    expect(narrowest, greaterThan(to.width - 8 - to.width * 0.07));
    await tester.pumpAndSettle();
    _expectRestingOn(tester, '广场');
  });

  testWidgets('a second tap mid-flight carries on from where the pill is', (
    tester,
  ) async {
    await _pumpBar(tester);
    await tester.tap(_cell('情报'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final before = tester.getRect(_indicator);
    await tester.tap(_cell('钱包'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final after = tester.getRect(_indicator);
    // No jump back to the first cell.
    expect(after.left, greaterThanOrEqualTo(before.left - 1));
    await tester.pumpAndSettle();
    _expectRestingOn(tester, '钱包');
  });

  testWidgets('reduced motion lands in one frame and does not swell', (
    tester,
  ) async {
    await _pumpBar(tester, reduceMotion: true);
    _expectRestingOn(tester, '聊天');
    final rest = tester.getRect(_key('loop-tab-bar-float'));
    final gesture = await tester.startGesture(tester.getCenter(_cell('钱包')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      tester.getRect(_key('loop-tab-bar-float')).width,
      moreOrLessEquals(rest.width),
    );
    await gesture.up();
    await tester.pump();
    _expectRestingOn(tester, '钱包');
  });

  testWidgets('a press swells the whole bar to 1.02 and lifting restores it', (
    tester,
  ) async {
    await _pumpBar(tester);
    final rest = tester.getRect(_key('loop-tab-bar-float'));
    final gesture = await tester.startGesture(tester.getCenter(_cell('MEME')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final pressed = tester.getRect(_key('loop-tab-bar-float'));
    expect(pressed.width / rest.width, moreOrLessEquals(1.02, epsilon: 1e-6));
    expect(pressed.height / rest.height, moreOrLessEquals(1.02, epsilon: 1e-6));
    expect(pressed.center.dx, moreOrLessEquals(rest.center.dx));
    expect(pressed.center.dy, moreOrLessEquals(rest.center.dy));
    await gesture.up();
    await tester.pumpAndSettle();
    final released = tester.getRect(_key('loop-tab-bar-float'));
    expect(released.width, moreOrLessEquals(rest.width));
    _expectRestingOn(tester, 'MEME');
  });

  test('the bounded back curve overshoots by what it is asked', () {
    for (final overshoot in <double>[0.015, 0.06, 0.1]) {
      final curve = LoopBoundedBackCurve(overshoot: overshoot);
      var peak = 0.0;
      for (var i = 0; i <= 1000; i += 1) {
        final v = curve.transform(i / 1000);
        if (v > peak) peak = v;
      }
      expect(peak - 1, moreOrLessEquals(overshoot, epsilon: 1e-3));
      expect(curve.transform(1), 1);
    }
  });

  Matrix4 glyph(WidgetTester tester, String slug) =>
      tester.widget<Transform>(_key('loop-tab-glyph-motion-$slug')).transform;

  testWidgets('the compass turns the moment 广场 becomes selected', (
    tester,
  ) async {
    await _pumpBar(tester);
    for (final slug in <String>['chat', 'square', 'meme', 'intel', 'wallet']) {
      expect(glyph(tester, slug), Matrix4.identity());
    }
    await tester.tap(_cell('广场'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(glyph(tester, 'square'), isNot(Matrix4.identity()));
    // The cell that lost the selection plays nothing.
    expect(glyph(tester, 'chat'), Matrix4.identity());
    await tester.pumpAndSettle();
    expect(glyph(tester, 'square'), Matrix4.identity());
  });

  testWidgets('every glyph moves on selection and rests after', (tester) async {
    await _pumpBar(tester, initial: 1);
    const slugs = <String>['chat', 'square', 'meme', 'intel', 'wallet'];
    for (var i = 0; i < _labels.length; i += 1) {
      if (i == 1) continue;
      await tester.tap(_cell(_labels[i]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(glyph(tester, slugs[i]), isNot(Matrix4.identity()));
      await tester.pumpAndSettle();
      expect(glyph(tester, slugs[i]), Matrix4.identity());
    }
  });

  testWidgets('tapping the selected tab again does not move its glyph', (
    tester,
  ) async {
    await _pumpBar(tester, initial: 1);
    await tester.tap(_cell('广场'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(glyph(tester, 'square'), Matrix4.identity());
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion keeps every glyph still', (tester) async {
    await _pumpBar(tester, reduceMotion: true);
    await tester.tap(_cell('广场'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(glyph(tester, 'square'), Matrix4.identity());
    await tester.tap(_cell('钱包'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(glyph(tester, 'wallet'), Matrix4.identity());
  });
}
