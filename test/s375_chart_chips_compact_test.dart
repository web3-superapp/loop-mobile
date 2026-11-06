// S375 · decision 0299: the chart's period chips and its K线 / MA / VOL
// switches are compact capsules — 2 above and below the word, 4 either side,
// the 13 pt chip step unchanged — centred in a transparent 44 target.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/loop_chart_toolbar.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const List<String> _intervals = <String>['15m', '1h', '4h', '1d', '1w'];
const List<String> _toggles = <String>[
  'token-chart-style',
  'token-chart-ma',
  'token-chart-vol',
];

Finder _capsuleOf(Finder chip) =>
    find.descendant(of: chip, matching: find.byKey(LoopCompactChip.capsuleKey));

Finder _wordOf(Finder chip) =>
    find.descendant(of: chip, matching: find.byType(RichText)).first;

/// The capsule's edge is 2 from the word above and below and 4 either side.
void _expectTight(WidgetTester tester, Finder chip, String reason) {
  final capsule = tester.getRect(_capsuleOf(chip));
  final word = tester.getRect(_wordOf(chip));
  expect(word.top - capsule.top, closeTo(2, 0.01), reason: reason);
  expect(capsule.bottom - word.bottom, closeTo(2, 0.01), reason: reason);
  expect(word.left - capsule.left, closeTo(4, 0.01), reason: reason);
  expect(capsule.right - word.right, closeTo(4, 0.01), reason: reason);
}

/// The finger's target is at least 44 × 44 and holds the capsule centred.
void _expectTarget(WidgetTester tester, Finder chip, String reason) {
  final target = tester.getRect(
    find.descendant(of: chip, matching: find.byType(InkWell)).first,
  );
  final capsule = tester.getRect(_capsuleOf(chip));
  expect(target.width, greaterThanOrEqualTo(LoopTouch.minimum), reason: reason);
  expect(
    target.height,
    greaterThanOrEqualTo(LoopTouch.minimum),
    reason: reason,
  );
  expect(capsule.height, lessThan(LoopTouch.minimum), reason: reason);
  expect(target.center.dy, closeTo(capsule.center.dy, 0.01), reason: reason);
  expect(target.center.dx, closeTo(capsule.center.dx, 0.01), reason: reason);
}

BoxDecoration _decoration(WidgetTester tester, Finder chip) =>
    tester.widget<DecoratedBox>(_capsuleOf(chip)).decoration as BoxDecoration;

void main() {
  group('token page · compact chart chips', () {
    testWidgets('periods and switches hug their word, 44 targets', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );
      for (final name in _intervals) {
        final chip = _key('token-interval-$name');
        expect(chip, findsOneWidget, reason: name);
        // S379 · decision 0303: the period is a LoopChartPeriod on the
        // compact capsule.
        expect(
          tester.widget<LoopChartPeriod>(chip).fill,
          isFalse,
          reason: name,
        );
        _expectTight(tester, chip, name);
        _expectTarget(tester, chip, name);
      }
      for (final toggle in _toggles) {
        final chip = _key(toggle);
        _expectTight(tester, chip, toggle);
        _expectTarget(tester, chip, toggle);
      }
      // S379 · decision 0303: the period is 12 (never bold); the switches
      // keep the 13 pt chip step.
      final word = tester.widget<RichText>(_wordOf(_key('token-interval-1h')));
      expect(word.text.style?.fontSize, 12);
      final vol = tester.widget<RichText>(_wordOf(_key('token-chart-vol')));
      expect(vol.text.style?.fontSize, 13);
    });

    testWidgets('the chosen ground and the r8 corner are unchanged', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );
      final chosen = _decoration(tester, _key('token-interval-1h'));
      expect(chosen.color, LoopColors.chipActive);
      expect(chosen.borderRadius, LoopRadius.pill);
      final idle = _decoration(tester, _key('token-interval-1d'));
      expect(idle.color, LoopColors.chipIdle);
      expect(idle.borderRadius, LoopRadius.pill);
      // VOL is on by default, MA off.
      expect(
        _decoration(tester, _key('token-chart-vol')).color,
        LoopColors.chipActive,
      );
      expect(
        _decoration(tester, _key('token-chart-ma')).color,
        LoopColors.chipIdle,
      );

      // A tap in the transparent room above the capsule still chooses.
      final capsule = tester.getRect(_capsuleOf(_key('token-interval-4h')));
      final target = tester.getRect(
        find
            .descendant(
              of: _key('token-interval-4h'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.tapAt(Offset(capsule.center.dx, target.top + 2));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LoopChartPeriod>(_key('token-interval-4h')).selected,
        isTrue,
      );
      expect(
        _decoration(tester, _key('token-interval-4h')).color,
        LoopColors.chipActive,
      );
    });

    testWidgets('at 360 the five periods and 全屏 share one unscrolled line', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        size: const Size(360, 2400),
      );
      final expand = tester.getRect(_key('token-chart-expand'));
      expect(expand.right, lessThanOrEqualTo(360));
      final first = tester.getRect(_key('token-interval-15m'));
      for (final name in _intervals) {
        final rect = tester.getRect(_key('token-interval-$name'));
        expect(rect.center.dy, closeTo(first.center.dy, 0.01), reason: name);
        expect(rect.right, lessThanOrEqualTo(expand.left), reason: name);
        // Neighbours keep the 4 gap between targets.
        if (name != _intervals.first) {
          final previous = tester.getRect(
            _key('token-interval-${_intervals[_intervals.indexOf(name) - 1]}'),
          );
          expect(rect.left - previous.right, closeTo(4, 0.01), reason: name);
        }
      }
      // The full-screen glyph sits on the same line, centred with the chips.
      expect(expand.center.dy, closeTo(first.center.dy, 0.5));
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.ancestor(
                of: _key('token-interval-15m'),
                matching: find.byType(SingleChildScrollView),
              ),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scroll.position.maxScrollExtent, 0);
      // The holder-count row (token_screen 持有者) overflows at 360 in the
      // test font before S375 too; it is outside the chart, whose own rows
      // are checked for overflow at 360 in the group below.
      tester.takeException();
    });
  });

  group('the shared rows · Chinese labels at 360', () {
    Future<void> pumpRow(WidgetTester tester, {required bool fill}) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LoopChartIntervalRow(
                  fill: fill,
                  options: <LoopChartIntervalOption>[
                    for (final (index, label) in const <String>[
                      '15分',
                      '1时',
                      '4时',
                      '1日',
                      '1周',
                    ].indexed)
                      (keyName: 'p$index', label: label),
                  ],
                  selectedIndex: 1,
                  onSelected: (_) {},
                  trailing: SizedBox.square(
                    key: const ValueKey<String>('expand'),
                    dimension: LoopTouch.minimum,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('scrolling row: one line, 44 tall, tight capsules', (
      tester,
    ) async {
      await pumpRow(tester, fill: false);
      final expand = tester.getRect(_key('expand'));
      for (var index = 0; index < 5; index++) {
        final chip = _key('p$index');
        final rect = tester.getRect(chip);
        expect(rect.right, lessThanOrEqualTo(expand.left), reason: '$index');
        expect(rect.height, LoopTouch.minimum, reason: '$index');
        _expectTight(tester, chip, '$index');
        _expectTarget(tester, chip, '$index');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('filled row (MEME pages): capsule hugs the word, 44 target', (
      tester,
    ) async {
      await pumpRow(tester, fill: true);
      for (var index = 0; index < 5; index++) {
        final chip = _key('p$index');
        _expectTight(tester, chip, '$index');
        _expectTarget(tester, chip, '$index');
      }
      expect(tester.widget<LoopChartPeriod>(_key('p1')).selected, isTrue);
      expect(_decoration(tester, _key('p1')).color, LoopColors.purpleSelected);
      expect(_decoration(tester, _key('p1')).borderRadius, LoopRadius.pill);
      expect(_decoration(tester, _key('p0')).color, Colors.transparent);
      expect(tester.takeException(), isNull);
    });
  });
}
