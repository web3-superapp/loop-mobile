import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/wallet_creation_facts.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_widgets.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/features/shell/loop_pending_surface.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

/// Decision 0192 (S197-4, docs/37 §2): the mining, account, security, system
/// and launch-creation pages draw each word in its one ladder step.

Future<void> _pump(WidgetTester tester, Widget child) {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

/// The style [text] is painted in — a whole paragraph or one span inside it.
TextStyle _painted(WidgetTester tester, String text) {
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    TextStyle? found;
    void visit(InlineSpan span, TextStyle? inherited) {
      if (found != null) return;
      final merged = inherited?.merge(span.style) ?? span.style;
      if (span is TextSpan) {
        if (span.text == text) {
          found = merged;
          return;
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          visit(child, merged);
        }
      }
    }

    visit(paragraph.text, null);
    if (found != null) return found!;
  }
  fail('no painted text "$text"');
}

void _expectStep(
  WidgetTester tester,
  String text,
  TextStyle step, {
  FontWeight? weight,
}) {
  final painted = _painted(tester, text);
  expect(painted.fontSize, step.fontSize, reason: '$text · size');
  expect(
    painted.fontWeight,
    weight ?? step.fontWeight,
    reason: '$text · weight',
  );
}

void main() {
  loopWatchGround();

  testWidgets('M33 / M34 · the mining hero kickers, metrics and figure', (
    tester,
  ) async {
    await _pump(
      tester,
      const MiningSummaryHero(
        heading: '1,234',
        unit: 'MP',
        rank: '12',
        caption: '上一小时',
        metrics: <MiningHeroMetric>[
          MiningHeroMetric(slug: 'a', label: '持仓', value: '10', spoken: '10'),
          MiningHeroMetric(slug: 'b', label: '邀请', value: '20', spoken: '20'),
          MiningHeroMetric(slug: 'c', label: '社区', value: '30', spoken: '30'),
        ],
      ),
    );

    _expectStep(tester, 'MINING POWER', LoopType.kicker);
    _expectStep(tester, 'RANK ', LoopType.kicker);
    _expectStep(tester, '持仓', LoopType.kicker);
    _expectStep(tester, '10', LoopType.figure);
    _expectStep(tester, '1,234', LoopType.statFigure);
    _expectStep(tester, ' MP', LoopType.figureMd);
  });

  testWidgets('M37 · a mining metric row: kicker label, figureLg value', (
    tester,
  ) async {
    await _pump(
      tester,
      MiningMetricRow(
        slug: 'power',
        label: '本小时算力',
        figure: const MiningFigureValue('4200'),
        baseline: false,
      ),
    );

    _expectStep(tester, '本小时算力', LoopType.kicker);
    _expectStep(tester, '4,200', LoopType.figureLg);
  });

  testWidgets('a mining detail row reads at figureLg unless told otherwise', (
    tester,
  ) async {
    await _pump(
      tester,
      const Column(
        children: <Widget>[
          MiningDetailRow(label: '可领取', value: '12.5'),
          MiningDetailRow(
            label: '已领取',
            value: '3',
            trailingLabel: '待结算',
            trailingValue: '4',
          ),
        ],
      ),
    );

    _expectStep(tester, '可领取', LoopType.captionSm);
    _expectStep(tester, '12.5', LoopType.figureLg);
    _expectStep(tester, '3', LoopType.figure);
  });

  testWidgets('M36 / M7 / M17 · referral levels and the explain sheet', (
    tester,
  ) async {
    await pumpS7Page(
      tester,
      const ReferralScreen(),
      referral: FakeReferralGateway(),
    );

    final level = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere((text) => (text.data ?? '').startsWith('L1 · '));
    _expectStep(tester, level.data!, LoopType.kicker);

    await tester.tap(
      find.byKey(const ValueKey<String>('referral-explain-action')),
    );
    await tester.pumpAndSettle();
    _expectStep(tester, 'Referral 说明', LoopType.heading);
    final support = _painted(
      tester,
      '每个账号只有一个邀请码。被邀请人激活 LOOP ID 并绑定钱包后，关系进入下一个验证阶段；'
      '「有效」需要挖矿公式版本被批准，因此当前不会出现有效关系。'
      '加成只计入 Mining Power，不是收入、佣金或返佣。',
    );
    expect(support.fontSize, LoopType.bodySm.fontSize);
    expect(support.color, LoopColors.text2);
  });

  testWidgets('M44 · a pending surface states its title at titleLg', (
    tester,
  ) async {
    final entry = LoopRouteManifest.entries.first;
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: LoopPendingSurface(entry: entry),
      ),
    );

    final titles = tester
        .widgetList<Text>(find.text(entry.title))
        .map((text) => text.style?.fontSize)
        .toSet();
    expect(titles, <double?>{LoopType.titleLg.fontSize});
  });

  testWidgets('L7 · wallet creation headline heading, detail caption', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: WalletCreateScreen(
          facts: const LoopWalletCreationFacts(
            phase: LoopWalletCreationPhase.working,
          ),
          onContinue: () {},
        ),
      ),
    );

    final headline = tester.widget<Text>(
      find.byKey(const ValueKey<String>('wallet-create-progress')),
    );
    expect(headline.style?.fontSize, LoopType.heading.fontSize);
    expect(headline.style?.fontWeight, LoopType.heading.fontWeight);
  });
}
