import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/widgets/loop_dock_bar.dart';

/// Decision 0096 · the five-tab bar magnifies under a sliding finger.
void main() {
  group('LoopDockBar.scaleAt', () {
    test('peak under the finger, 1.15 one cell away, rest from two', () {
      expect(LoopDockBar.scaleAt(0), LoopMotion.dockPeakScale);
      expect(
        LoopDockBar.scaleAt(1),
        moreOrLessEquals(LoopMotion.dockNeighbourScale),
      );
      expect(
        LoopDockBar.scaleAt(-1),
        moreOrLessEquals(LoopMotion.dockNeighbourScale),
      );
      expect(LoopDockBar.scaleAt(2), 1);
      expect(LoopDockBar.scaleAt(3.5), 1);
      // Monotonic between the three anchors: no bump in the decay.
      var previous = LoopDockBar.scaleAt(0);
      for (var d = 0.1; d < 2; d += 0.1) {
        final scale = LoopDockBar.scaleAt(d);
        expect(scale, lessThanOrEqualTo(previous));
        previous = scale;
      }
    });

    test('glyphs make room by weight; the row keeps its width', () {
      const width = 350.0;
      final cells = LoopDockBar.layout(
        count: 5,
        width: width,
        fingerX: width / 2,
        strength: 1,
      );
      expect(cells[2].scale, LoopMotion.dockPeakScale);
      expect(cells[2].shift, moreOrLessEquals(0));
      // The neighbours move outward, symmetrically.
      expect(cells[1].shift, lessThan(0));
      expect(cells[3].shift, greaterThan(0));
      expect(cells[1].shift, moreOrLessEquals(-cells[3].shift));
      // Visual widths still add up to the row: the first cell's left edge and
      // the last one's right edge do not move.
      final total = cells.fold<double>(0, (sum, cell) => sum + cell.scale);
      final firstVisual = width * cells.first.scale / total;
      expect(
        width / 10 + cells.first.shift - firstVisual / 2,
        moreOrLessEquals(0),
      );
      final lastVisual = width * cells.last.scale / total;
      expect(
        width * 9 / 10 + cells.last.shift + lastVisual / 2,
        moreOrLessEquals(width),
      );
    });

    test('no finger or no strength is the resting row', () {
      for (final cells in <List<LoopDockCell>>[
        LoopDockBar.layout(count: 5, width: 300, fingerX: null, strength: 1),
        LoopDockBar.layout(count: 5, width: 300, fingerX: 120, strength: 0),
      ]) {
        expect(cells.every((cell) => cell.atRest), isTrue);
      }
    });
  });

  group('LoopTabBar · dock', () {
    Future<List<int>> pumpBar(
      WidgetTester tester, {
      bool reduceMotion = false,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selections = <int>[];
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              bottomNavigationBar: LoopTabBar(
                selectedIndex: selected,
                onSelect: (index) {
                  selections.add(index);
                  setState(() => selected = index);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return selections;
    }

    const slugs = <String>['chat', 'square', 'meme', 'intel', 'wallet'];

    Finder cell(String slug) => find.byKey(ValueKey<String>('loop-tab-$slug'));

    List<LoopTabItem> items(WidgetTester tester) =>
        tester.widgetList<LoopTabItem>(find.byType(LoopTabItem)).toList();

    List<Size> cellSizes(WidgetTester tester) => <Size>[
      for (final slug in slugs) tester.getSize(cell(slug)),
    ];

    List<Rect> cellRects(WidgetTester tester) => <Rect>[
      for (final slug in slugs) tester.getRect(cell(slug)),
    ];

    testWidgets('a tap switches exactly as before and nothing magnifies', (
      tester,
    ) async {
      final selections = await pumpBar(tester);
      final gesture = await tester.startGesture(tester.getCenter(cell('meme')));
      // Held, not moved, short of a long press: still just a tap.
      await tester.pump(const Duration(milliseconds: 120));
      expect(items(tester).every((item) => item.dock.atRest), isTrue);
      await gesture.up();
      await tester.pump();
      expect(selections, <int>[2]);
      await tester.pumpAndSettle();
      expect(items(tester).every((item) => item.dock.atRest), isTrue);
      expect(
        find.byKey(const ValueKey<String>('loop-tab-dock-meme')),
        findsNothing,
      );
    });

    testWidgets('a slide magnifies by distance, neighbours make room, the '
        'cells keep their size, and lifting selects', (tester) async {
      final selections = await pumpBar(tester);
      final before = cellRects(tester);
      final start = tester.getCenter(cell('square'));
      final gesture = await tester.startGesture(start);
      await tester.pump();
      // Two steps past the touch slop, ending on the Launch cell's centre.
      final target = tester.getCenter(cell('meme'));
      await gesture.moveTo(Offset((start.dx + target.dx) / 2, start.dy));
      await tester.pump();
      await gesture.moveTo(Offset(target.dx, start.dy));
      await tester.pump();
      // Pump the engage through to its end frame by frame.
      for (var i = 0; i < 8; i += 1) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      final docked = items(tester).map((item) => item.dock).toList();
      expect(docked[2].scale, moreOrLessEquals(LoopMotion.dockPeakScale));
      expect(
        docked[1].scale,
        moreOrLessEquals(LoopMotion.dockNeighbourScale, epsilon: 0.01),
      );
      expect(
        docked[3].scale,
        moreOrLessEquals(LoopMotion.dockNeighbourScale, epsilon: 0.01),
      );
      expect(docked[0].scale, lessThan(docked[1].scale));
      // Neighbours give way outward.
      expect(docked[1].shift, lessThan(0));
      expect(docked[3].shift, greaterThan(0));
      expect(
        find.byKey(const ValueKey<String>('loop-tab-dock-meme')),
        findsOneWidget,
      );
      // The hit areas are the laid-out cells, untouched by the magnification.
      expect(cellRects(tester), before);
      // Nothing has been selected while the finger is still down.
      expect(selections, isEmpty);

      await gesture.up();
      await tester.pump();
      expect(selections, <int>[2]);
      await tester.pumpAndSettle();
      expect(items(tester).every((item) => item.dock.atRest), isTrue);
      expect(cellSizes(tester), before.map((rect) => rect.size).toList());
    });

    testWidgets('a slide that ends on the selected tab selects nothing', (
      tester,
    ) async {
      final selections = await pumpBar(tester);
      final start = tester.getCenter(cell('chat'));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveTo(start);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
    });

    testWidgets('a held press becomes a slide too', (tester) async {
      final selections = await pumpBar(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(cell('intel')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      for (var i = 0; i < 8; i += 1) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(
        items(tester)[3].dock.scale,
        moreOrLessEquals(LoopMotion.dockPeakScale),
      );
      await gesture.moveTo(tester.getCenter(cell('wallet')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selections, <int>[4]);
      expect(items(tester).every((item) => item.dock.atRest), isTrue);
    });

    testWidgets('reduced motion keeps the selection and drops the magnifier', (
      tester,
    ) async {
      final selections = await pumpBar(tester, reduceMotion: true);
      final start = tester.getCenter(cell('chat'));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(cell('intel')));
      await tester.pump();
      expect(items(tester).every((item) => item.dock.atRest), isTrue);
      await gesture.up();
      await tester.pump();
      expect(selections, <int>[3]);
    });
  });
}
