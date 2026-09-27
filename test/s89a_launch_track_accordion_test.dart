import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/widgets/loop_accordion_strip.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s83c_fixtures.dart';

/// Decision 0096 · `launch-detail`'s 发射轨道 as a horizontal accordion.
void main() {
  loopWatchGround();
  final now = DateTime.utc(2026, 9, 22, 12);

  LaunchChainRound round(int index, DateTime start, DateTime end) =>
      LaunchChainRound(
        roundId: index == 3 ? null : '$s7RoundId-$index',
        roundIndex: index,
        startAt: start,
        endAt: end,
        priceUsd1PerToken: '10000000000000000',
        roundCapUsd1: '40000000000000000000000',
        walletRoundCapUsd1: '500000000000000000000',
        allowlistRoot: index == 1 ? s83cRoot : LaunchChainRound.zeroRoot,
        raisedUsd1: '10000000000000000000000',
      );

  // R1 over, R2 in progress, R3 not yet open.
  final rounds = <LaunchChainRound>[
    round(1, DateTime.utc(2026, 9, 20), DateTime.utc(2026, 9, 21)),
    round(2, DateTime.utc(2026, 9, 22), DateTime.utc(2026, 9, 23)),
    round(3, DateTime.utc(2026, 9, 24), DateTime.utc(2026, 9, 25)),
  ];

  Finder key(String value) => find.byKey(ValueKey<String>(value));

  Future<void> pumpDetail(
    WidgetTester tester, {
    List<LaunchChainRound>? chainRounds,
    Size size = const Size(390, 2600),
    double textScale = 1,
    bool reduceMotion = false,
    VoidCallback? onOpenGraduation,
  }) async {
    await pumpS7Page(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: LaunchDetailScreen(
            launchId: s7LaunchId,
            clock: () => now,
            onOpenGraduation: onOpenGraduation,
          ),
        ),
      ),
      size: size,
      launch: FakeLaunchGateway(
        detail: S7Answer<LaunchDetail>(
          value: s83cDetail(rounds: chainRounds ?? rounds),
        ),
      ),
    );
  }

  double widthOf(WidgetTester tester, String id) =>
      tester.getSize(key('launch-track-strip-$id')).width;

  /// Pumps [LoopMotion.accordionExpand] frame by frame, so every transition
  /// frame passes the ground probe before the end state is asserted.
  Future<void> runMotion(WidgetTester tester) async {
    const frame = Duration(milliseconds: 16);
    var elapsed = Duration.zero;
    while (elapsed < LoopMotion.accordionExpand) {
      await tester.pump(frame);
      elapsed += frame;
    }
    await tester.pumpAndSettle();
  }

  testWidgets('the round in progress opens on arrival; the rest are narrow', (
    tester,
  ) async {
    await pumpDetail(tester);

    expect(key('launch-track'), findsOneWidget);
    expect(find.byType(LoopAccordionStrip), findsOneWidget);
    for (final id in <String>['1', '2', '3', 'end']) {
      expect(key('launch-track-strip-$id'), findsOneWidget, reason: id);
    }
    // Weight 3 against 1: the open strip is three times a narrow one.
    expect(
      widthOf(tester, '2'),
      moreOrLessEquals(widthOf(tester, '1') * 3, epsilon: 0.5),
    );
    expect(widthOf(tester, '1'), moreOrLessEquals(widthOf(tester, 'end')));
    // Only the open strip builds its detail.
    expect(key('launch-track-detail-2'), findsOneWidget);
    expect(key('launch-track-detail-1'), findsNothing);
    expect(key('launch-track-detail-end'), findsNothing);
    final detail = key('launch-track-detail-2');
    // Decision 0100: two small cards (window; price and round cap, the unit
    // in the label), raised over the bar, and the wallet cap as the footer.
    for (final text in <String>[
      'Round 2 · 公开轮',
      '09-22 00:00',
      '09-23 00:00',
      '0.01',
      '40,000',
      '10,000 USD1',
    ]) {
      expect(
        find.descendant(of: detail, matching: find.text(text)),
        findsOneWidget,
        reason: text,
      );
    }
    expect(
      find.descendant(
        of: key('launch-track-strip-2'),
        matching: find.text('钱包上限 500 USD1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: detail, matching: find.byType(LoopProgressBar)),
      findsOneWidget,
    );
    // The vertical list is not built alongside.
    expect(key('launch-track-1'), findsNothing);
  });

  testWidgets('a tap widens that strip, its detail after 40 %, and a second '
      'tap returns the row to equal widths', (tester) async {
    await pumpDetail(tester);
    await tester.ensureVisible(key('launch-track'));
    await tester.pumpAndSettle();

    await tester.tap(key('launch-track-strip-1'));
    await tester.pump();
    // Early in the motion the new detail has not started to fade in, and the
    // closing one is still on its way out.
    await tester.pump(const Duration(milliseconds: 48));
    expect(key('launch-track-detail-1'), findsNothing);
    await runMotion(tester);
    expect(key('launch-track-detail-1'), findsOneWidget);
    expect(key('launch-track-detail-2'), findsNothing);
    expect(
      widthOf(tester, '1'),
      moreOrLessEquals(widthOf(tester, '2') * 3, epsilon: 0.5),
    );
    // Round 1 is the allowlist round.
    expect(
      find.descendant(
        of: key('launch-track-detail-1'),
        matching: find.text('Round 1 · 名单轮'),
      ),
      findsOneWidget,
    );

    await tester.tap(key('launch-track-strip-1'));
    await runMotion(tester);
    expect(key('launch-track-detail-1'), findsNothing);
    final widths = <double>[
      for (final id in <String>['1', '2', '3', 'end']) widthOf(tester, id),
    ];
    for (final width in widths) {
      expect(width, moreOrLessEquals(widths.first));
    }
  });

  testWidgets('between rounds the next round to open is open on arrival '
      '(decision 0097)', (tester) async {
    await pumpDetail(
      tester,
      chainRounds: <LaunchChainRound>[rounds.first, rounds.last],
    );
    expect(key('launch-track-detail-1'), findsNothing);
    expect(key('launch-track-detail-3'), findsOneWidget);
    expect(
      widthOf(tester, '3'),
      moreOrLessEquals(widthOf(tester, '1') * 3, epsilon: 0.5),
    );
  });

  testWidgets('a sale whose rounds have all ended opens on END', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      chainRounds: <LaunchChainRound>[
        round(1, DateTime.utc(2026, 9, 18), DateTime.utc(2026, 9, 19)),
        round(2, DateTime.utc(2026, 9, 20), DateTime.utc(2026, 9, 21)),
      ],
    );
    expect(key('launch-track-detail-end'), findsOneWidget);
    expect(key('launch-track-detail-1'), findsNothing);
    expect(
      widthOf(tester, 'end'),
      moreOrLessEquals(widthOf(tester, '1') * 3, epsilon: 0.5),
    );
  });

  testWidgets("the open detail is exactly the strip's content width and "
      'its right-aligned figures stay inside (decision 0097)', (tester) async {
    await pumpDetail(tester);
    expect(tester.takeException(), isNull);
    final strip = tester.getRect(key('launch-track-strip-2'));
    final detail = tester.getRect(key('launch-track-detail-2'));
    // 10 dp of padding and the 1 dp edge on each side.
    const inset = 11.0;
    expect(detail.width, moreOrLessEquals(strip.width - inset * 2));
    expect(detail.left, moreOrLessEquals(strip.left + inset));
    expect(detail.right, moreOrLessEquals(strip.right - inset));
    for (final text in <String>[
      '09-22 00:00',
      '09-23 00:00',
      '0.01',
      '40,000',
      '10,000 USD1',
      '钱包上限 500 USD1',
    ]) {
      final figure = tester.getRect(
        find.descendant(
          of: key('launch-track-strip-2'),
          matching: find.text(text),
        ),
      );
      expect(
        figure.right,
        lessThanOrEqualTo(strip.right - inset + 0.01),
        reason: text,
      );
    }
  });

  group('launchTrackInitialIndex (decision 0097)', () {
    test('a round in progress is the current step', () {
      expect(launchTrackInitialIndex(rounds, now), 1);
    });
    test('every round over: END, after the last round', () {
      expect(
        launchTrackInitialIndex(rounds, DateTime.utc(2026, 9, 25)),
        rounds.length,
      );
      expect(
        launchTrackInitialIndex(rounds, DateTime.utc(2026, 10)),
        rounds.length,
      );
    });
    test('not started: the first round', () {
      expect(launchTrackInitialIndex(rounds, DateTime.utc(2026, 9, 1)), 0);
    });
    test('between two rounds: the next one to open', () {
      expect(launchTrackInitialIndex(rounds, DateTime.utc(2026, 9, 23, 12)), 2);
    });
    test('no rounds: nothing open', () {
      expect(launchTrackInitialIndex(const <LaunchChainRound>[], now), isNull);
    });
  });

  testWidgets('a round LOOP has no record of says so in its strip', (
    tester,
  ) async {
    await pumpDetail(tester);
    await tester.ensureVisible(key('launch-track'));
    await tester.tap(key('launch-track-strip-3'));
    await runMotion(tester);
    expect(
      find.descendant(
        of: key('launch-track-detail-3'),
        matching: find.text('LOOP 没有这一轮的记录，不能在这里认购'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('END opens to the graduation step and leads to its page', (
    tester,
  ) async {
    var opened = 0;
    await pumpDetail(tester, onOpenGraduation: () => opened += 1);
    await tester.ensureVisible(key('launch-track'));
    await tester.tap(key('launch-track-strip-end'));
    await runMotion(tester);
    final detail = key('launch-track-detail-end');
    expect(
      find.descendant(of: detail, matching: find.text('毕业与迁移')),
      findsOneWidget,
    );
    // Decision 0100: the projection is the open strip's badge, on its title
    // line, rather than a line of the detail.
    expect(
      find.descendant(
        of: key('launch-track-strip-end'),
        matching: find.byType(LoopBadge),
      ),
      findsOneWidget,
    );
    await tester.tap(key('launch-track-open-graduation'));
    await tester.pumpAndSettle();
    expect(opened, 1);
    // The button is the step's own; the strip stays open.
    expect(detail, findsOneWidget);
  });

  testWidgets('reduced motion switches in one frame', (tester) async {
    await pumpDetail(tester, reduceMotion: true);
    await tester.ensureVisible(key('launch-track'));
    await tester.pumpAndSettle();
    await tester.tap(key('launch-track-strip-3'));
    await tester.pump();
    expect(key('launch-track-detail-3'), findsOneWidget);
    expect(key('launch-track-detail-2'), findsNothing);
    expect(
      widthOf(tester, '3'),
      moreOrLessEquals(widthOf(tester, '2') * 3, epsilon: 0.5),
    );
  });

  testWidgets('large type falls back to the vertical list', (tester) async {
    await pumpDetail(tester, textScale: LoopAccordionStrip.maxTextScale);
    expect(find.byType(LoopAccordionStrip), findsOneWidget);
    expect(key('launch-track-strip-1'), findsNothing);
    expect(key('launch-track'), findsOneWidget);
    expect(tester.widget(key('launch-track')), isA<LoopRecordGroup>());
    for (final index in <int>[1, 2, 3]) {
      expect(key('launch-track-$index'), findsOneWidget);
    }
    expect(key('launch-track-graduation'), findsOneWidget);
  });

  testWidgets('a narrow screen falls back to the vertical list', (
    tester,
  ) async {
    await pumpDetail(tester, size: const Size(340, 2600));
    expect(key('launch-track-strip-1'), findsNothing);
    expect(tester.widget(key('launch-track')), isA<LoopRecordGroup>());
    expect(key('launch-track-2'), findsOneWidget);
  });

  testWidgets('more rounds than the row can hold fall back as well', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      chainRounds: <LaunchChainRound>[
        for (var index = 1; index <= 7; index += 1)
          round(
            index,
            DateTime.utc(2026, 9, index),
            DateTime.utc(2026, 9, index + 1),
          ),
      ],
    );
    expect(key('launch-track-strip-1'), findsNothing);
    expect(key('launch-track-7'), findsOneWidget);
  });

  test('the fit rule', () {
    // 390 − 32 margin with four strips leaves the open one well over the
    // floor; seven strips do not.
    expect(
      LoopAccordionStrip.openWidthFor(358, 4),
      greaterThan(LoopAccordionStrip.minOpenWidth),
    );
    expect(
      LoopAccordionStrip.openWidthFor(358, 8),
      lessThan(LoopAccordionStrip.minOpenWidth),
    );
  });

  testWidgets('LoopAccordionStrip lays its detail out at the content width '
      'the edge and the padding leave', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    Widget detail(String id) => Row(
      children: <Widget>[
        const Text('剩余'),
        const Spacer(),
        Text('04:36', key: ValueKey<String>('figure-$id')),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: LoopAccordionStrip(
            minHeight: 120,
            initialIndex: 0,
            keyPrefix: 'probe',
            margin: const EdgeInsets.symmetric(horizontal: 16),
            fallback: const SizedBox.shrink(),
            items: <LoopAccordionItem>[
              for (final id in <String>['a', 'b', 'c'])
                LoopAccordionItem(
                  id: id,
                  shortTitle: id.toUpperCase(),
                  semanticLabel: id,
                  detail: detail(id),
                ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final strip = tester.getRect(key('probe-strip-a'));
    final openWidth = LoopAccordionStrip.openWidthFor(390 - 32, 3);
    expect(strip.width, moreOrLessEquals(openWidth));
    final box = tester.renderObject<RenderBox>(key('probe-detail-a'));
    // Padding 10 and the 1 dp edge on each side.
    expect(box.size.width, moreOrLessEquals(openWidth - 22));
    expect(
      tester.getRect(key('probe-detail-a')).right,
      moreOrLessEquals(strip.right - 11),
    );
    // The last character ends on the content edge, not 2 dp past it.
    expect(
      tester.getRect(key('figure-a')).right,
      moreOrLessEquals(strip.right - 11),
    );
  });
}
