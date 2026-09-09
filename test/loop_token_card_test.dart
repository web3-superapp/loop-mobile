import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

const _pepe = LoopTokenCardModel(
  symbol: 'PEPE',
  identifier: '0x6982…1933',
  price: r'$0.000013',
  change: '+4.8%',
  changeUp: true,
  metrics: <LoopTokenMetric>[
    LoopTokenMetric('市值', r'$5.4B'),
    LoopTokenMetric('流动性', r'$42.8M'),
    LoopTokenMetric('持有人', '418K'),
  ],
  communityLine: 'LOOP 社区 128K 成员 · 0.35×',
  chartRangeLabel: '1H · 固定演示',
  chart: SizedBox.expand(),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390, 1200);
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
  testWidgets('normal: identity, quote, chart, metrics, community, actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var bought = 0;
    await _pump(
      tester,
      LoopTokenCard(
        state: LoopTokenCardState.normal,
        model: _pepe,
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction('买入', buy: true, onTap: () => bought += 1),
          LoopTokenCardAction('卖出', onTap: () {}),
          LoopTokenCardAction('图表', onTap: () {}),
          LoopTokenCardAction('社区', onTap: () {}),
        ],
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('loop-token-card-normal')),
      findsOneWidget,
    );
    expect(find.text('PEPE'), findsOneWidget);
    expect(find.text(r'$0.000013'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('+4.8%')).style?.color,
      LoopColors.lime,
    );
    expect(
      tester.widget<Text>(find.text(r'$0.000013')).style?.fontFamily,
      LoopFonts.mono,
    );
    expect(find.text('1H · 固定演示'), findsOneWidget);
    expect(find.text('市值'), findsOneWidget);
    expect(find.text(r'$42.8M'), findsOneWidget);
    expect(find.text('LOOP 社区 128K 成员 · 0.35×'), findsOneWidget);
    expect(tester.widget<Text>(find.text('买入')).style?.color, LoopColors.lime);
    expect(find.bySemanticsLabel('PEPE Token Card · 正常'), findsOneWidget);
    expect(
      tester.getSize(find.bySemanticsLabel('买入')).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.text('买入'));
    expect(bought, 1);
    semantics.dispose();
  });

  testWidgets('loading disables actions and shows placeholders only', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await _pump(
      tester,
      LoopTokenCard(
        state: LoopTokenCardState.loading,
        model: const LoopTokenCardModel(
          symbol: 'PEPE',
          identifier: '0x6982...1933',
          metrics: <LoopTokenMetric>[
            LoopTokenMetric('市值', '等待数据'),
            LoopTokenMetric('流动性', '等待数据'),
            LoopTokenMetric('持有人', '等待数据'),
          ],
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction('买入', buy: true, onTap: () => taps += 1),
          LoopTokenCardAction('图表', onTap: () => taps += 1),
        ],
      ),
    );
    expect(find.text('识别中…'), findsOneWidget);
    expect(find.text('识别中'), findsOneWidget);
    expect(find.text('PEPE'), findsNothing);
    expect(find.text('等待数据'), findsNWidgets(3));
    expect(
      tester.getSemantics(find.bySemanticsLabel('买入')),
      matchesSemantics(
        label: '买入',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    await tester.tap(find.text('买入'), warnIfMissed: false);
    expect(taps, 0);
    semantics.dispose();
  });

  testWidgets('the graduated state carries no ecosystem tax label', (
    tester,
  ) async {
    await _pump(
      tester,
      LoopTokenCard(
        state: LoopTokenCardState.graduated,
        model: const LoopTokenCardModel(
          symbol: 'BONEZ',
          identifier: '0x9c4b...7f82',
          badge: 'GRADUATED',
          metrics: <LoopTokenMetric>[
            LoopTokenMetric('市值', r'$2.4M'),
            LoopTokenMetric('持有人', '4,120'),
          ],
        ),
      ),
    );

    // No tax rate exists until the Launch contract baseline is delivered.
    expect(find.textContaining('生态税'), findsNothing);
    expect(find.text('1%'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('loop-token-card-graduated')),
      findsOneWidget,
    );
  });

  testWidgets('graduated, partial and risk states keep their exact facts', (
    tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: <Widget>[
          LoopTokenCard(
            state: LoopTokenCardState.graduated,
            model: const LoopTokenCardModel(
              symbol: 'BONEZ',
              identifier: '...9B2ELOOP',
              price: r'$0.0024',
              change: '+712%',
              changeUp: true,
              badge: 'GRADUATED',
              metrics: <LoopTokenMetric>[
                LoopTokenMetric('市值', r'$2.4M'),
                LoopTokenMetric('流动性', r'$412K', accent: true),
                LoopTokenMetric('持有人', '4,120'),
              ],
              communityIcon: 'graduate',
              communityLine: '08-22 毕业 · 外盘流动性已建立',
            ),
            actions: <LoopTokenCardAction>[
              LoopTokenCardAction('毕业详情', onTap: () {}),
            ],
          ),
          // The graduated state carries no ecosystem-tax metric: there is no
          // proven tax rate while the Launch contract baseline is pending.
          LoopTokenCard(
            state: LoopTokenCardState.partial,
            model: const LoopTokenCardModel(
              symbol: 'UNKNOWN',
              identifier: '0x9c4b...7f82',
              price: r'$0.000004',
              metrics: <LoopTokenMetric>[
                LoopTokenMetric('市值', '数据不可得'),
                LoopTokenMetric('流动性', '数据不可得'),
                LoopTokenMetric('持有人', '数据不可得'),
              ],
              communityIcon: 'info',
              communityLine: '该代币未加入 LOOP 社区，无 Mining Weight',
            ),
            actions: <LoopTokenCardAction>[
              LoopTokenCardAction('查看合约', onTap: () {}),
              const LoopTokenCardAction('交易不可用'),
            ],
          ),
          LoopTokenCard(
            state: LoopTokenCardState.risk,
            model: const LoopTokenCardModel(
              symbol: 'PEPE',
              identifier: '0x3f8a...2b91',
              price: r'$0.0000079',
              change: '+842%',
              changeUp: true,
              riskFacts: <LoopTokenRiskFact>[
                LoopTokenRiskFact(
                  fact: '该合约含 mint 函数，发行方可增发',
                  source: 'GoPlus',
                  observedLabel: '2 分钟前',
                ),
                LoopTokenRiskFact(
                  fact: '合约地址与 PEPE 官方不一致',
                  source: '链上比对',
                  observedLabel: '2 分钟前',
                ),
              ],
              metrics: <LoopTokenMetric>[
                LoopTokenMetric('市值', r'$142K'),
                LoopTokenMetric('流动性', r'$8,200'),
                LoopTokenMetric('持有人', '84'),
              ],
            ),
            actions: <LoopTokenCardAction>[
              LoopTokenCardAction('确认事实后买入', buy: true, onTap: () {}),
              LoopTokenCardAction('查看全部事实', onTap: () {}),
            ],
          ),
        ],
      ),
    );
    final graduated = tester.widget<Container>(
      find.byKey(const ValueKey<String>('loop-token-card-graduated')),
    );
    expect(
      (graduated.decoration! as BoxDecoration).border!.top.color,
      LoopColors.lime.withValues(alpha: 0.32),
    );
    expect(find.text('GRADUATED'), findsOneWidget);
    // The accent metric is a liquidity figure the owner can prove, not a tax.
    expect(
      tester.widget<Text>(find.text(r'$412K')).style?.color,
      LoopColors.lime,
    );

    expect(find.text('无 24H 数据'), findsOneWidget);
    expect(find.text('数据不可得'), findsNWidgets(3));
    expect(
      tester.widget<Text>(find.text('数据不可得').first).style?.color,
      LoopColors.text3,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('交易不可用')),
      matchesSemantics(
        label: '交易不可用',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('loop-token-card-risk-facts')),
      findsOneWidget,
    );
    expect(find.textContaining('来源 GoPlus，观察于 2 分钟前'), findsOneWidget);
    expect(find.textContaining('来源 链上比对'), findsOneWidget);
    expect(find.textContaining('危险'), findsNothing);
    expect(find.textContaining('不安全'), findsNothing);
  });

  testWidgets('every state stays legible at 390pt and 2x text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final state in LoopTokenCardState.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: LoopTokenCard(
                state: state,
                model: _pepe,
                actions: <LoopTokenCardAction>[
                  LoopTokenCardAction('买入', buy: true, onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: state.name);
      expect(find.byType(LoopTokenCard), findsOneWidget, reason: state.name);
    }
  });
}
