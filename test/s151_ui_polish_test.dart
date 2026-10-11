// Decision 0149 (S151-mobile): UI acceptance polish. Each test pins one
// fixed problem seen on the emulator so the shape cannot quietly come back.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_trade_panel.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_screen.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(412, 892);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('sign sheet: values form one start-aligned column with room '
      'for a sentence (S142 obs. 3, 「先授权 …」)', (tester) async {
    const approval = '2,000 \$S13776DF 给官方池路由';
    await _pump(
      tester,
      const LoopSignSheet(
        state: LoopSignSheetState.pending,
        title: '确认外盘卖出',
        facts: <LoopSignFact>[
          LoopSignFact('卖出', '2,000 \$S13776DF'),
          LoopSignFact('先授权', approval),
          LoopSignFact('路由', '0xcb02…8f5d'),
        ],
      ),
    );
    final values = <Finder>[
      find.text('2,000 \$S13776DF'),
      find.text(approval),
      find.text('0xcb02…8f5d'),
    ];
    final starts = values.map((f) => tester.getTopLeft(f).dx).toSet();
    expect(starts, hasLength(1), reason: 'every value starts on one edge');
    expect(tester.widget<Text>(values[1]).textAlign, TextAlign.start);
    // The label column is the smaller share: 2 : 3.
    final label = tester.getTopLeft(find.text('先授权')).dx;
    final rowWidth = tester.getSize(find.byType(LoopKeyValue).first).width;
    expect(starts.single - label, lessThan(rowWidth / 2));
  });

  testWidgets('LoopKeyValue keeps its old halves and right alignment by '
      'default', (tester) async {
    await _pump(tester, const LoopKeyValue(label: '毕业价', value: '\$0.0006667'));
    expect(
      tester.widget<Text>(find.text('\$0.0006667')).textAlign,
      TextAlign.right,
    );
  });

  testWidgets('price-row skeleton: no hairline, two right lines and the '
      '96 × 44 pill of the loaded row', (tester) async {
    await _pump(
      tester,
      const LoopSkeleton(
        type: LoopSkeletonType.priceRow,
        rows: 3,
        rowHeight: 72,
        leadingSize: 36,
      ),
    );
    final rows = find.byKey(const ValueKey<String>('loop-skeleton-price-row'));
    expect(rows, findsOneWidget);
    final bordered = find.descendant(
      of: rows,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).border != null,
      ),
    );
    expect(bordered, findsNothing);
    final pills = find.byWidgetPredicate(
      (w) => w is LoopSkeletonBlock && w.width == 96 && w.height == 44,
    );
    expect(pills, findsNWidgets(3));
    expect(loopSkeletonPillSize, const Size(96, 44));
  });

  testWidgets('LoopSegBar inside a padded block can drop its own gutter', (
    tester,
  ) async {
    await _pump(
      tester,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LoopSegBar(
          labels: const <String>['买入', '卖出'],
          selectedIndex: 0,
          padding: EdgeInsets.zero,
          onSelected: (_) {},
        ),
      ),
    );
    expect(tester.getTopLeft(find.byType(LoopSeg).first).dx, 16);
  });

  testWidgets('power hint: sentence over figures, chevron only when it '
      'opens a page', (tester) async {
    await _pump(
      tester,
      Column(
        children: <Widget>[
          LoopPowerHint(
            key: const ValueKey<String>('tappable'),
            text: '钱包持仓正在产生算力',
            figure: '0 算力 · 今日预估 — LOOP · 当前算力公式',
            onTap: () {},
          ),
          const LoopPowerHint(
            key: ValueKey<String>('still'),
            text: '这个资产的挖矿贡献',
            figure: '算力 —',
          ),
        ],
      ),
    );
    final sentence = tester.getTopLeft(find.text('钱包持仓正在产生算力'));
    final figure = tester.getTopLeft(find.text('0 算力 · 今日预估 — LOOP · 当前算力公式'));
    expect(figure.dy, greaterThan(sentence.dy));
    expect(figure.dx, sentence.dx);
    LoopIcon? chevronIn(String key) {
      final icons = tester.widgetList<LoopIcon>(
        find.descendant(
          of: find.byKey(ValueKey<String>(key)),
          matching: find.byType(LoopIcon),
        ),
      );
      return icons.where((i) => i.name == 'chevron').firstOrNull;
    }

    expect(chevronIn('tappable'), isNotNull);
    expect(chevronIn('still'), isNull);
  });

  testWidgets('v2 swap link sits on the gutter, caption size, 44 tall', (
    tester,
  ) async {
    var opened = 0;
    await _pump(tester, Launch2PoolSwapLink(onOpen: () => opened += 1));
    final link = find.byKey(const ValueKey<String>('launch2-go-swap'));
    expect(tester.getTopLeft(link).dx, 16);
    expect(tester.getSize(link).height, greaterThanOrEqualTo(44));
    await tester.tap(link);
    expect(opened, 1);
    expect(find.byType(TextButton), findsNothing);
  });

  test('project page sections share one heading size', () {
    expect(launch2PanelHeadingStyle.fontSize, 20);
    expect(launch2PanelHeadingStyle.fontWeight, FontWeight.w700);
    expect(launch2PanelTopGap, greaterThanOrEqualTo(24));
  });

  test('rewards awaiting title names the account state for its own hours', () {
    expect(miningAwaitingTitle('MINING_NOTHING_SETTLED'), '你有算力的小时还没有结算');
    expect(miningAwaitingTitle(null), '首个小时结算后开始展示奖励');
    expect(
      miningDisplayReasonText('MINING_NOTHING_SETTLED'),
      isNot(contains('首个有算力的小时结算后开始展示')),
    );
    expect(
      miningClaimUnavailableText('MINING_NOTHING_SETTLED'),
      '有算力的小时结算后可领取',
    );
  });

  testWidgets('two-step strip says which step 确认签名 starts', (tester) async {
    Color colourOf(String text) =>
        tester.widget<Text>(find.text(text)).style!.color!;
    await _pump(
      tester,
      const Launch2SignStepStrip(
        noun: '卖出',
        approval: Launch2StepStatus.waiting,
        main: Launch2StepStatus.waiting,
      ),
    );
    expect(colourOf('授权'), LoopColors.chalk);
    expect(colourOf('卖出'), LoopColors.text2);
    expect(find.text('下一步，待签名'), findsOneWidget);
    expect(find.text('待签名'), findsOneWidget);
    await _pump(
      tester,
      const Launch2SignStepStrip(
        noun: '卖出',
        approval: Launch2StepStatus.done,
        main: Launch2StepStatus.waiting,
      ),
    );
    expect(colourOf('卖出'), LoopColors.chalk);
  });
}
