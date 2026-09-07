import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production toast-states route shows samples and no feedback', (
    tester,
  ) async {
    final router = await pumpProductionApp(tester);
    router.go('/preview/toast');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('feedback-source-unavailable')),
      findsOneWidget,
    );
    expect(find.byType(LoopGlobalNotice), findsNothing);
    expect(find.text('当前反馈'), findsNothing);

    await scrollPageTo(
      tester,
      find.byKey(const ValueKey<String>('toast-trigger-ok')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('toast-trigger-ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(LoopToastHost), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LoopToastHost),
        matching: find.byKey(const ValueKey<String>('loop-toast-ok')),
      ),
      findsWidgets,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Static comparison rows are visibly samples.
    await scrollPageTo(tester, find.text('示例 · 交易失败：gas 不足').last);
    expect(find.textContaining('示例 · '), findsWidgets);

    await tester.tap(find.byKey(const ValueKey<String>('loop-topbar-back')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/community');
  });

  testWidgets('feedback fails closed for blank messages and labels', (
    tester,
  ) async {
    for (final message in <String>['', '   ']) {
      await pumpSystemSurface(
        tester,
        SystemSurfaceScreen.fromId(
          'toast',
          globalFeedback: LoopGlobalFeedback(
            kind: LoopNoticeKind.success,
            message: message,
            actionLabel: '查看',
          ),
          onFeedbackAction: () {},
        ),
      );
      expect(find.byType(LoopGlobalNotice), findsNothing);
      expect(find.text('查看'), findsNothing);
    }
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'toast',
        globalFeedback: const LoopGlobalFeedback(
          kind: LoopNoticeKind.warning,
          message: '确切的警告观测。',
          actionLabel: '  ',
        ),
        onFeedbackAction: () {},
      ),
    );
    expect(find.text('确切的警告观测。'), findsOneWidget);
    expect(find.byType(LoopGlobalNotice), findsOneWidget);
    expect(find.text('关闭'), findsNothing);
  });

  testWidgets('explicit feedback renders its kind with exact actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var actions = 0;
    var dismissed = 0;
    for (final (kind, key, prefix) in <(LoopNoticeKind, String, String)>[
      (LoopNoticeKind.success, 'loop-toast-ok', '成功'),
      (LoopNoticeKind.warning, 'loop-toast-warn', '警告'),
      (LoopNoticeKind.error, 'loop-toast-err', '错误'),
    ]) {
      await pumpSystemSurface(
        tester,
        SystemSurfaceScreen.fromId(
          'toast',
          globalFeedback: LoopGlobalFeedback(
            kind: kind,
            message: '来自功能的 ${kind.name} 结果',
            actionLabel: '查看',
          ),
          onFeedbackAction: () => actions += 1,
          onFeedbackDismiss: () => dismissed += 1,
          onSecondaryAction: () {},
        ),
      );
      expect(find.text('当前反馈'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(LoopGlobalNotice),
          matching: find.byKey(ValueKey<String>(key)),
        ),
        findsOneWidget,
        reason: key,
      );
      expect(
        find.bySemanticsLabel('$prefix：来自功能的 ${kind.name} 结果'),
        findsOneWidget,
      );
      expect(find.text('返回 LOOP'), findsNothing);
      await tester.tap(find.text('查看'));
      await tester.tap(find.text('关闭'));
    }
    expect((actions, dismissed), (3, 3));
    semantics.dispose();
  });

  testWidgets('toast page remains usable at 2x text', (tester) async {
    await pumpSystemSurface(
      tester,
      const SystemSurfaceScreen.fromId('toast'),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await scrollPageTo(
      tester,
      find.byKey(const ValueKey<String>('toast-trigger-err')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('toast-trigger-err')));
    await tester.pump();
    expect(find.byType(LoopToastView), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });
}
