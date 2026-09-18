import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';

void main() {
  testWidgets(
    'LoopSheet uses the veil barrier, top radius and restores focus',
    (tester) async {
      final opener = FocusNode(debugLabel: 'opener');
      addTearDown(opener.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  focusNode: opener,
                  autofocus: true,
                  onPressed: () => showLoopSheet<void>(
                    context,
                    builder: (context) => const SizedBox(
                      height: 120,
                      child: Center(child: Text('弹层内容')),
                    ),
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(opener.hasFocus, isTrue);

      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      expect(find.text('弹层内容'), findsOneWidget);
      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.color, LoopColors.veil);
      expect(barrier.semanticsLabel, '关闭弹层');
      final sheet = tester.widget<Container>(
        find.byKey(const ValueKey<String>('loop-sheet')),
      );
      final decoration = sheet.decoration! as BoxDecoration;
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(26)),
      );
      expect(decoration.border!.top.color, LoopColors.line2);
      expect(opener.hasFocus, isFalse);

      // Tapping the veil closes the sheet (background stays inert meanwhile).
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.text('弹层内容'), findsNothing);
      expect(opener.hasFocus, isTrue);
    },
  );

  testWidgets('a sheet grounds its own words, whatever is behind it', (
    tester,
  ) async {
    // The ground is declared as Chalk: whatever the page behind the sheet
    // happens to be, the words inside the sheet must land on the sheet's own
    // surface. A sheet that paints only its glow grounds nothing, and Chalk
    // copy on a Chalk page is the transparent panel the walkthrough shot.
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          backgroundColor: LoopColors.chalk,
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showLoopSheet<void>(
                  context,
                  builder: (context) => const SizedBox(
                    height: 120,
                    child: Center(child: Text('弹层内容')),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    loopExpectVisibleOnGround(
      tester,
      subtree: find.byKey(const ValueKey<String>('loop-sheet')),
      ground: LoopColors.chalk,
    );
  });

  testWidgets('LoopToast shows above the bar for 2.6s with a live region', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: LoopTabBarScope(
          child: Scaffold(
            body: Builder(
              builder: (context) {
                hostContext = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    LoopToast.show(hostContext, message: '地址已复制');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final toast = find.byKey(const ValueKey<String>('loop-toast-ok'));
    expect(toast, findsOneWidget);
    final rect = tester.getRect(toast);
    final screen = tester.getSize(find.byType(LoopToastHost));
    expect(screen.height - rect.bottom, LoopToast.bottomOffset);
    expect(rect.left, LoopSpacing.page);
    expect(
      tester.getSemantics(find.bySemanticsLabel('成功：地址已复制')),
      matchesSemantics(label: '成功：地址已复制', isLiveRegion: true),
    );
    expect(
      (tester.widget<Container>(toast).decoration! as BoxDecoration).color,
      LoopColors.chalk,
    );

    // Still visible before 2.6s, gone after.
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('地址已复制'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('地址已复制'), findsNothing);

    LoopToast.show(hostContext, message: '价格已变动', kind: LoopToastKind.warn);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('loop-toast-warn')),
      findsOneWidget,
    );
    LoopToast.show(
      hostContext,
      message: '交易失败：gas 不足',
      kind: LoopToastKind.err,
    );
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('loop-toast-warn')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('loop-toast-err')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('错误：交易失败：gas 不足'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    semantics.dispose();
  });

  testWidgets('a page with no tab bar keeps the toast at the page gutter', (
    tester,
  ) async {
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    LoopToast.show(
      pageContext,
      message: '设备已离线，这一页没有读到数据，也没有提交任何操作。',
      kind: LoopToastKind.warn,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final toast = find.byKey(const ValueKey<String>('loop-toast-warn'));
    final rect = tester.getRect(toast);
    final screen = tester.getSize(find.byType(LoopToastHost));
    // 94px of clearance is the tab bar's reserve. A pushed page draws no bar,
    // and the reserve applied there parked the toast on top of that page's
    // primary action instead of over chrome.
    expect(screen.height - rect.bottom, LoopToast.pageBottomOffset);
    expect(LoopToast.pageBottomOffset, lessThan(LoopToast.bottomOffset));
    await tester.pump(const Duration(seconds: 3));
  });
}
