import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

const _facts = <LoopSignFact>[
  LoopSignFact('操作', 'Swap'),
  LoopSignFact('资产', '0.5 ETH → USDC'),
  LoopSignFact('网络', 'BSC'),
  LoopSignFact('费用', '0.0012 BNB'),
];

Future<void> _pump(WidgetTester tester, LoopSignSheet sheet) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: Scaffold(body: SingleChildScrollView(child: sheet)),
    ),
  );
  await tester.pump();
}

SemanticsNode _button(WidgetTester tester, String label) =>
    tester.getSemantics(find.bySemanticsLabel(label));

void main() {
  testWidgets(
    'pending: facts visible, confirm enabled and bound to the owner',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var confirmed = 0;
      var cancelled = 0;
      await _pump(
        tester,
        LoopSignSheet(
          state: LoopSignSheetState.pending,
          facts: _facts,
          onConfirm: () => confirmed += 1,
          onCancel: () => cancelled += 1,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('loop-sign-sheet-pending')),
        findsOneWidget,
      );
      for (final fact in _facts) {
        expect(find.text(fact.label), findsOneWidget);
        expect(find.text(fact.value), findsOneWidget);
      }
      expect(find.text('待确认'), findsOneWidget);
      expect(
        _button(tester, '确认'),
        matchesSemantics(
          label: '确认',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.text('确认'));
      await tester.tap(find.text('取消'));
      expect(confirmed, 1);
      expect(cancelled, 1);
      semantics.dispose();
    },
  );

  testWidgets('simulation failure and policy rejection disable confirm', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var confirmed = 0;
    var adjusted = 0;
    await _pump(
      tester,
      LoopSignSheet(
        state: LoopSignSheetState.simulationFailed,
        facts: const <LoopSignFact>[
          LoopSignFact('操作', 'Swap'),
          LoopSignFact('模拟结果', '失败 · 无法预演', down: true),
        ],
        reason: '模拟服务未返回可验证结果。当前不能确认；可重试模拟或取消操作。',
        onConfirm: () => confirmed += 1,
        onCancel: () {},
      ),
    );
    expect(find.text('模拟失败'), findsOneWidget);
    expect(find.text('失败 · 无法预演'), findsOneWidget);
    expect(
      _button(tester, '确认'),
      matchesSemantics(
        label: '确认',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    await tester.tap(find.text('确认'), warnIfMissed: false);
    expect(confirmed, 0);

    await _pump(
      tester,
      LoopSignSheet(
        state: LoopSignSheetState.policyRejected,
        facts: const <LoopSignFact>[
          LoopSignFact('操作', '转账 5,000 USDC'),
          LoopSignFact('结果', '被拒绝', down: true),
        ],
        reason: '超过你设置的单笔转账上限。这是你自己配置的钱包策略 —— 可在安全中心调整。',
        onConfirm: () => confirmed += 1,
        onCancel: () {},
        onAdjustPolicy: () => adjusted += 1,
      ),
    );
    expect(find.text('被策略拒绝'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(
      _button(tester, '确认'),
      matchesSemantics(
        label: '确认',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    await tester.tap(find.text('调整策略'));
    expect(adjusted, 1);
    expect(confirmed, 0);
    semantics.dispose();
  });

  testWidgets('signing disables everything; complete offers only close', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      LoopSignSheet(
        state: LoopSignSheetState.signing,
        facts: _facts,
        onConfirm: () {},
        onCancel: () {},
      ),
    );
    expect(find.text('正在签名并广播'), findsOneWidget);
    expect(find.text('请勿关闭 App'), findsOneWidget);
    expect(
      _button(tester, '取消'),
      matchesSemantics(
        label: '取消',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    expect(
      _button(tester, '签名中'),
      matchesSemantics(
        label: '签名中',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );

    var closed = 0;
    await _pump(
      tester,
      LoopSignSheet(
        state: LoopSignSheetState.complete,
        facts: const <LoopSignFact>[LoopSignFact('结果', '已广播 · 等待链上确认')],
        reason: '成功提示不代表链上已完成；请在交易结果页查看确认。',
        onCancel: () => closed += 1,
      ),
    );
    expect(find.text('已完成'), findsOneWidget);
    expect(find.bySemanticsLabel('确认'), findsNothing);
    await tester.tap(find.text('关闭'));
    expect(closed, 1);
    semantics.dispose();
  });

  testWidgets('LoopSignSheet.show opens inside the veil-backed sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => LoopSignSheet.show(
                context,
                sheet: LoopSignSheet(
                  state: LoopSignSheetState.pending,
                  facts: _facts,
                  onConfirm: () {},
                  onCancel: () => Navigator.of(context).pop(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('loop-sheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('loop-sign-sheet-pending')),
      findsOneWidget,
    );
    expect(
      tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color,
      LoopColors.veil,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('loop-sheet')), findsNothing);
  });
}
