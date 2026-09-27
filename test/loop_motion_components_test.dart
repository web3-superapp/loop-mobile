import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_avatar_stack.dart';
import 'package:loop_mobile/widgets/loop_progress_fill.dart';
import 'package:loop_mobile/widgets/loop_tray_disclosure.dart';

import 'support/loop_ground_probe.dart';

/// Decision 0092 · the three motion primitives.
///
/// The ground probe watches every frame these tests paint, including every
/// transition frame, so a colour that only goes missing half way through a
/// fade fails here rather than on the device.
void main() {
  loopWatchGround();

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            disableAnimations: reduceMotion,
          ),
          child: Scaffold(
            body: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );
  }

  group('LoopMotion', () {
    test('keeps the parameter table of decision 0092', () {
      expect(LoopMotion.avatarSpread, const Duration(milliseconds: 280));
      expect(LoopMotion.avatarStagger, const Duration(milliseconds: 35));
      expect(LoopMotion.avatarStackStep, closeTo(2 / 3, 1e-9));
      expect(LoopMotion.progressFill, const Duration(milliseconds: 260));
      expect(LoopMotion.progressCurve, Curves.easeOutCubic);
      expect(LoopMotion.progressComplete, const Duration(milliseconds: 600));
      expect(LoopMotion.progressCompletePeak, 0.12);
      expect(LoopMotion.trayExpand, const Duration(milliseconds: 280));
    });
  });

  group('LoopAvatarStack', () {
    const entries = <LoopAvatarStackEntry>[
      LoopAvatarStackEntry(label: 'pepe_founder'),
      LoopAvatarStackEntry(label: 'NightOwl'),
      LoopAvatarStackEntry(label: '匿名成员'),
    ];

    double faceLeft(WidgetTester tester, int index) => tester
        .getTopLeft(
          find.byKey(ValueKey<String>('loop-avatar-stack-face-$index')),
        )
        .dx;

    testWidgets('stacks with a third covered and a +N disc', (tester) async {
      await mount(
        tester,
        const LoopAvatarStack(entries: entries, total: 12, size: 30),
      );
      final origin = faceLeft(tester, 0);
      expect(faceLeft(tester, 1) - origin, closeTo(20, 0.01));
      expect(faceLeft(tester, 2) - origin, closeTo(40, 0.01));
      expect(faceLeft(tester, 3) - origin, closeTo(60, 0.01));
      expect(find.text('+9'), findsOneWidget);
      // Stacked, the names are not built: nothing reads them off screen.
      expect(find.text('pepe_founder'), findsNothing);
    });

    testWidgets('spreads one after another, names under, and gathers back', (
      tester,
    ) async {
      await mount(
        tester,
        const LoopAvatarStack(entries: entries, total: 12, size: 30),
      );
      final origin = faceLeft(tester, 0);
      final stacked = <double>[
        for (var i = 0; i < 4; i += 1) faceLeft(tester, i) - origin,
      ];

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-avatar-stack-toggle')),
      );
      await tester.pump();
      // Mid-flight: the first face has started, the last has not yet.
      await tester.pump(const Duration(milliseconds: 60));
      final firstCellShift = (60 - 30) / 2;
      final one = faceLeft(tester, 1) - origin;
      final three = faceLeft(tester, 3) - origin;
      expect(one, greaterThan(stacked[1]));
      expect(one, lessThan(68 + firstCellShift));
      expect(three, lessThan(stacked[3] + 1));

      await tester.pumpAndSettle();
      // Spread: 60-wide cells, 8 apart, face centred in its cell.
      final spreadOrigin = faceLeft(tester, 0) - firstCellShift;
      expect(faceLeft(tester, 1) - spreadOrigin, closeTo(68 + 15, 0.01));
      expect(faceLeft(tester, 2) - spreadOrigin, closeTo(136 + 15, 0.01));
      expect(find.text('pepe_founder'), findsOneWidget);
      expect(find.text('匿名成员'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-avatar-stack-toggle')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(faceLeft(tester, 2) - origin, greaterThan(stacked[2]));
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i += 1) {
        expect(faceLeft(tester, i) - origin, closeTo(stacked[i], 0.01));
      }
    });

    testWidgets('switches at once when motion is reduced', (tester) async {
      await mount(
        tester,
        const LoopAvatarStack(entries: entries, total: 3, size: 30),
        reduceMotion: true,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-avatar-stack-more')),
        findsNothing,
      );
      final origin = faceLeft(tester, 0);
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-avatar-stack-toggle')),
      );
      await tester.pump();
      // The very next frame is the end state; nothing is left to travel.
      expect(faceLeft(tester, 1) - origin, closeTo(68 + 15, 0.01));
      expect(find.text('NightOwl'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 16));
      expect(faceLeft(tester, 1) - origin, closeTo(68 + 15, 0.01));
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-avatar-stack-toggle')),
      );
      await tester.pump();
      expect(faceLeft(tester, 1) - origin, closeTo(20, 0.01));
    });

    testWidgets('keeps a 44pt target and states the names to a reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await mount(
        tester,
        const LoopAvatarStack(
          entries: entries,
          total: 5,
          semanticLabel: '成员预览',
        ),
      );
      final box = tester.getSize(
        find.byKey(const ValueKey<String>('loop-avatar-stack-toggle')),
      );
      expect(box.height, greaterThanOrEqualTo(LoopTouch.minimum));
      expect(
        find.bySemanticsLabel('成员预览，pepe_founder、NightOwl、匿名成员，另外 2 人'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('LoopProgressFill', () {
    double fillWidth(WidgetTester tester) => tester
        .getSize(find.byKey(const ValueKey<String>('loop-progress-fill-bar')))
        .width;

    Widget fill(double progress, {double? from}) => SizedBox(
      width: 200,
      child: LoopProgressFill(
        progress: progress,
        from: from,
        height: 4,
        fillColor: LoopColors.lime,
        trackColor: LoopColors.line2,
      ),
    );

    testWidgets('stands at its value when nothing moves', (tester) async {
      await mount(tester, fill(0.4));
      expect(fillWidth(tester), closeTo(80, 0.01));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('advances smoothly to a new value', (tester) async {
      await mount(tester, fill(0.2));
      await mount(tester, fill(0.6));
      await tester.pump(const Duration(milliseconds: 130));
      final mid = fillWidth(tester);
      expect(mid, greaterThan(40));
      expect(mid, lessThan(120));
      await tester.pumpAndSettle();
      expect(fillWidth(tester), closeTo(120, 0.01));
      expect(
        find.byKey(const ValueKey<String>('loop-progress-fill-flash')),
        findsNothing,
      );
    });

    testWidgets('carries the previous step forward on appearance', (
      tester,
    ) async {
      await mount(tester, fill(0.6, from: 0.4));
      await tester.pump();
      expect(fillWidth(tester), lessThan(120));
      await tester.pumpAndSettle();
      expect(fillWidth(tester), closeTo(120, 0.01));
    });

    testWidgets('brightens once on reaching the whole width', (tester) async {
      await mount(tester, fill(0.8));
      await mount(tester, fill(1));
      await tester.pump(LoopMotion.progressFill);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      final flash = find.byKey(
        const ValueKey<String>('loop-progress-fill-flash'),
      );
      expect(flash, findsOneWidget);
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: flash, matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, greaterThan(0.1));
      expect(fade.opacity.value, lessThanOrEqualTo(0.12));
      await tester.pumpAndSettle();
      expect(flash, findsNothing);
      expect(fillWidth(tester), closeTo(200, 0.01));
    });

    testWidgets('switches at once and never flashes when motion is reduced', (
      tester,
    ) async {
      await mount(tester, fill(0.2), reduceMotion: true);
      await mount(tester, fill(1), reduceMotion: true);
      await tester.pump();
      expect(fillWidth(tester), closeTo(200, 0.01));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byKey(const ValueKey<String>('loop-progress-fill-flash')),
        findsNothing,
      );
    });

    testWidgets('derives its default fill from the ground', (tester) async {
      await mount(
        tester,
        const SizedBox(
          width: 200,
          child: LoopProgressFill(progress: 0.5, child: SizedBox(height: 40)),
        ),
      );
      final box = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('loop-progress-fill-bar')),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(box.color, LoopColors.card2);
    });
  });

  group('LoopTrayDisclosure', () {
    Widget tray({bool tapCard = false, VoidCallback? onCard}) =>
        LoopTrayDisclosure(
          card: GestureDetector(
            key: const ValueKey<String>('main-card'),
            onTap: onCard,
            child: Container(
              height: 80,
              decoration: const BoxDecoration(
                color: LoopColors.elevated,
                borderRadius: LoopRadius.card,
              ),
            ),
          ),
          summary: const Text('可动用 1.2 · 算力 40'),
          detail: const Column(
            key: ValueKey<String>('detail-lines'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(height: 20, child: Text('可动用 1.2')),
              SizedBox(height: 20, child: Text('算力 40')),
              SizedBox(height: 20, child: Text('手续费保留 0.01')),
            ],
          ),
        );

    Rect cardRect(WidgetTester tester) =>
        tester.getRect(find.byKey(const ValueKey<String>('main-card')));
    Rect trayRect(WidgetTester tester) =>
        tester.getRect(find.byKey(const ValueKey<String>('loop-tray')));

    testWidgets('tucks a narrower tray under the card showing one line', (
      tester,
    ) async {
      await mount(tester, Align(alignment: Alignment.topCenter, child: tray()));
      final card = cardRect(tester);
      final under = trayRect(tester);
      expect(under.left - card.left, LoopTrayDisclosure.defaultTrayInset);
      expect(card.right - under.right, LoopTrayDisclosure.defaultTrayInset);
      expect(under.top, card.bottom - LoopTrayDisclosure.defaultOverlap);
      expect(under.bottom, greaterThan(card.bottom));
      expect(find.text('可动用 1.2 · 算力 40'), findsOneWidget);
      // Closed: the detail is not built, so nothing reads it off screen.
      expect(
        find.byKey(const ValueKey<String>('loop-tray-detail')),
        findsNothing,
      );
      expect(find.text('手续费保留 0.01'), findsNothing);
    });

    testWidgets('opens downward without moving the card, and closes', (
      tester,
    ) async {
      await mount(tester, Align(alignment: Alignment.topCenter, child: tray()));
      final card = cardRect(tester);
      final closed = trayRect(tester);

      await tester.tap(find.byKey(const ValueKey<String>('loop-tray-toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 140));
      final mid = trayRect(tester);
      expect(mid.top, closed.top);
      expect(mid.height, greaterThan(closed.height));
      expect(cardRect(tester), card);

      await tester.pumpAndSettle();
      final open = trayRect(tester);
      expect(open.height, greaterThan(mid.height));
      expect(cardRect(tester), card);
      expect(find.text('手续费保留 0.01'), findsOneWidget);
      final fade = tester.widget<FadeTransition>(
        find.byKey(const ValueKey<String>('loop-tray-detail')),
      );
      expect(fade.opacity.value, 1);

      await tester.tap(find.byKey(const ValueKey<String>('loop-tray-toggle')));
      await tester.pumpAndSettle();
      expect(trayRect(tester), closed);
      expect(cardRect(tester), card);
    });

    testWidgets('keeps the card tap separate from the tray tap', (
      tester,
    ) async {
      var cardTaps = 0;
      await mount(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: tray(onCard: () => cardTaps += 1),
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('main-card')));
      await tester.pumpAndSettle();
      expect(cardTaps, 1);
      final closed = trayRect(tester);
      await tester.tap(find.byKey(const ValueKey<String>('loop-tray-toggle')));
      await tester.pumpAndSettle();
      expect(cardTaps, 1);
      expect(trayRect(tester).height, greaterThan(closed.height));
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('loop-tray'))).height -
            LoopTrayDisclosure.defaultOverlap,
        greaterThanOrEqualTo(LoopTouch.minimum),
      );
    });

    testWidgets('switches at once when motion is reduced', (tester) async {
      await mount(
        tester,
        Align(alignment: Alignment.topCenter, child: tray()),
        reduceMotion: true,
      );
      final closed = trayRect(tester);
      await tester.tap(find.byKey(const ValueKey<String>('loop-tray-toggle')));
      await tester.pump();
      expect(trayRect(tester).height, greaterThan(closed.height + 60));
      final fade = tester.widget<FadeTransition>(
        find.byKey(const ValueKey<String>('loop-tray-detail')),
      );
      expect(fade.opacity.value, 1);
      await tester.tap(find.byKey(const ValueKey<String>('loop-tray-toggle')));
      await tester.pump();
      expect(trayRect(tester), closed);
    });
  });
}
