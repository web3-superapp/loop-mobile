import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/widgets/loop_accordion_strip.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s83c_fixtures.dart';

/// Decision 0100 · the 发射轨道 accordion reworked: the row is as tall as the
/// open strip's content (at least 160), narrow strips carry their phase and
/// raised bar, and the surface follows the phase.
void main() {
  loopWatchGround();
  final now = DateTime.utc(2026, 9, 22, 12);

  LaunchChainRound round(
    int index,
    DateTime start,
    DateTime end, {
    String raised = '10000000000000000000000',
  }) => LaunchChainRound(
    roundId: '$s7RoundId-$index',
    roundIndex: index,
    startAt: start,
    endAt: end,
    priceUsd1PerToken: '10000000000000000',
    roundCapUsd1: '40000000000000000000000',
    walletRoundCapUsd1: '500000000000000000000',
    allowlistRoot: LaunchChainRound.zeroRoot,
    raisedUsd1: raised,
  );

  // R1 over (full), R2 in progress (a quarter), R3 not yet open.
  final rounds = <LaunchChainRound>[
    round(
      1,
      DateTime.utc(2026, 9, 20),
      DateTime.utc(2026, 9, 21),
      raised: '40000000000000000000000',
    ),
    round(2, DateTime.utc(2026, 9, 22), DateTime.utc(2026, 9, 23)),
    round(3, DateTime.utc(2026, 9, 24), DateTime.utc(2026, 9, 25), raised: '0'),
  ];

  Finder key(String value) => find.byKey(ValueKey<String>(value));

  Future<void> pumpDetail(
    WidgetTester tester, {
    List<LaunchChainRound>? chainRounds,
    bool reduceMotion = false,
  }) async {
    await pumpS7Page(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reduceMotion),
          child: LaunchDetailScreen(
            launchId: s7LaunchId,
            clock: () => now,
            onOpenGraduation: () {},
          ),
        ),
      ),
      size: const Size(390, 2600),
      launch: FakeLaunchGateway(
        detail: S7Answer<LaunchDetail>(
          value: s83cDetail(rounds: chainRounds ?? rounds),
        ),
      ),
    );
    await tester.ensureVisible(key('launch-track'));
    await tester.pumpAndSettle();
  }

  BoxDecoration surfaceOf(WidgetTester tester, String id) =>
      tester
              .widget<Ink>(
                find
                    .descendant(
                      of: key('launch-track-strip-$id'),
                      matching: find.byType(Ink),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  Color edgeOf(WidgetTester tester, String id) =>
      (surfaceOf(tester, id).border! as Border).top.color;

  testWidgets('the row is as tall as the open strip, no more', (tester) async {
    await pumpDetail(tester);
    final row = tester.getRect(key('launch-track'));
    final strip = tester.getRect(key('launch-track-strip-2'));
    expect(row.height, strip.height);
    expect(row.height, greaterThanOrEqualTo(160));
    // The old fixed 224 is gone; the content decides.
    expect(row.height, isNot(224));
    // The footer is the last thing in the strip and sits on its bottom
    // padding: no band of empty ground under it.
    final footer = tester.getRect(
      find.descendant(
        of: key('launch-track-strip-2'),
        matching: find.text('钱包上限 500 USD1'),
      ),
    );
    expect(strip.bottom - footer.bottom, lessThanOrEqualTo(11 + 4));
    // The detail's own last line (the bar) sits right above the footer.
    expect(tester.takeException(), isNull);
  });

  testWidgets('END open: the row shrinks to END and ends on its footer', (
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
    final strip = tester.getRect(key('launch-track-strip-end'));
    final footer = tester.getRect(
      find.descendant(
        of: key('launch-track-strip-end'),
        matching: find.text('读自区块 45,000,000'),
      ),
    );
    expect(strip.bottom - footer.bottom, lessThanOrEqualTo(11 + 4));
    final button = tester.getRect(key('launch-track-open-graduation'));
    // Between the button and the footer: the footer's own rule and gap.
    expect(footer.top - button.bottom, lessThanOrEqualTo(24));
    expect(strip.height, lessThan(224));
  });

  testWidgets('switching strips moves the height with the widths', (
    tester,
  ) async {
    await pumpDetail(tester);
    final roundHeight = tester.getSize(key('launch-track')).height;
    await tester.tap(key('launch-track-strip-end'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final mid = tester.getSize(key('launch-track')).height;
    await tester.pumpAndSettle();
    final endHeight = tester.getSize(key('launch-track')).height;
    expect(endHeight, isNot(roundHeight));
    expect(
      mid,
      inExclusiveRange(
        endHeight < roundHeight ? endHeight : roundHeight,
        endHeight < roundHeight ? roundHeight : endHeight,
      ),
    );
    // Closing every strip settles on the floor.
    await tester.tap(key('launch-track-strip-end'));
    await tester.pumpAndSettle();
    expect(tester.getSize(key('launch-track')).height, 160);
  });

  testWidgets('reduced motion: the height changes in one frame', (
    tester,
  ) async {
    await pumpDetail(tester, reduceMotion: true);
    await tester.tap(key('launch-track-strip-end'));
    await tester.pump();
    final first = tester.getSize(key('launch-track')).height;
    await tester.pumpAndSettle();
    expect(tester.getSize(key('launch-track')).height, first);
  });

  testWidgets('narrow strips read their phase along the long edge', (
    tester,
  ) async {
    await pumpDetail(tester);
    final words = <String, String>{'1': '已结束', '3': '未开始', 'end': '毕业'};
    words.forEach((id, word) {
      final text = find.descendant(
        of: key('launch-track-strip-$id'),
        matching: find.text(word),
      );
      expect(text, findsOneWidget, reason: id);
      expect(
        find.ancestor(of: text, matching: find.byType(RotatedBox)),
        findsOneWidget,
        reason: id,
      );
    });
    // The open strip draws its detail, not its word.
    expect(key('loop-accordion-word-2'), findsNothing);
    // The raised bar fills from the bottom: R1 is full, R3 is empty, END
    // has none.
    final bar1 = find.descendant(
      of: key('loop-accordion-bar-1'),
      matching: find.byType(ColoredBox),
    );
    expect(
      tester.getSize(bar1.last).height,
      moreOrLessEquals(LoopAccordionStrip.barHeight),
    );
    final bar3 = find.descendant(
      of: key('loop-accordion-bar-3'),
      matching: find.byType(ColoredBox),
    );
    expect(tester.getSize(bar3.last).height, 0);
    expect(key('loop-accordion-bar-end'), findsNothing);
    // The word is the screen reader's too, through the strip's own label.
    expect(
      tester.getSemantics(key('launch-track-strip-1')).label,
      contains('已结束'),
    );
  });

  testWidgets('the round in progress wears Lime; the others do not', (
    tester,
  ) async {
    await pumpDetail(tester);
    expect(edgeOf(tester, '2'), LoopColors.lime);
    expect(surfaceOf(tester, '2').color, LoopColors.limeSoft);
    // Over: greyscale edge and ground.
    expect(edgeOf(tester, '1'), isNot(LoopColors.lime));
    expect(edgeOf(tester, '1'), LoopColors.line);
    // Not yet: an outline on no ground of its own.
    expect(surfaceOf(tester, '3').color!.a, 0);
    expect(edgeOf(tester, '3').a, greaterThan(0));
    // The badge on the open strip's title line is the sale's own word.
    expect(
      find.descendant(
        of: key('launch-track-strip-2'),
        matching: find.text('销售进行中'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the measuring copies are not on screen for finders or '
      'readers', (tester) async {
    await pumpDetail(tester);
    expect(find.text('Round 2 · 公开轮'), findsOneWidget);
    expect(find.text('毕业与迁移'), findsNothing);
    expect(
      find.descendant(
        of: key('launch-track'),
        matching: find.byType(LoopButton),
      ),
      findsNothing,
    );
    expect(find.bySemanticsLabel('查看毕业流程'), findsNothing);
  });

  testWidgets('a short detail keeps the 160 floor', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: LoopAccordionStrip(
            minHeight: 160,
            initialIndex: 0,
            keyPrefix: 'probe',
            margin: const EdgeInsets.symmetric(horizontal: 16),
            fallback: const SizedBox.shrink(),
            items: const <LoopAccordionItem>[
              LoopAccordionItem(
                id: 'a',
                shortTitle: 'A',
                semanticLabel: 'a',
                detail: Text('一行'),
              ),
              LoopAccordionItem(
                id: 'b',
                shortTitle: 'B',
                semanticLabel: 'b',
                detail: SizedBox(height: 300),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(key('probe-row')).height, 160);
    await tester.tap(key('probe-strip-b'));
    await tester.pumpAndSettle();
    // 300 of detail, the title line and its gap, and the padding.
    expect(
      tester.getSize(key('probe-row')).height,
      moreOrLessEquals(300 + LoopAccordionStrip.titleHeight + 8 + 22),
    );
    expect(LoopMotion.accordionExpand, const Duration(milliseconds: 280));
  });
}
