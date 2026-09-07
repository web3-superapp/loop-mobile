import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_showcase_preview.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production sign-sheet-states route shows no fixture sheets', (
    tester,
  ) async {
    await expectProductionUnavailable(
      tester,
      location: '/system/sign-sheet',
      unavailableKey: 'sign-sheet-showcase-unavailable',
      absentClaims: <String>['5,000 USDC', '演示数据', '触发待确认弹层'],
    );
  });

  testWidgets('preview showcase renders the four states and opens the sheet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = await pumpProductionApp(
      tester,
      overrides: [
        loopSystemShowcaseProvider.overrideWithValue(
          buildLoopSystemShowcasePreview(),
        ),
      ],
    );
    router.go('/system/sign-sheet');
    // The signing-state dots pulse forever; pump bounded frames instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('演示数据 · 开发预览'), findsOneWidget);
    for (final state in <LoopSignSheetState>[
      LoopSignSheetState.simulationFailed,
      LoopSignSheetState.signing,
      LoopSignSheetState.policyRejected,
    ]) {
      final key = ValueKey<String>('loop-sign-sheet-${state.name}');
      await scrollPageTo(tester, find.byKey(key));
      final sheet = tester.widget<LoopSignSheet>(
        find.ancestor(
          of: find.byKey(key),
          matching: find.byType(LoopSignSheet),
        ),
      );
      expect(sheet.confirmEnabled, isFalse, reason: state.name);
    }
    expect(
      find.byKey(const ValueKey<String>('loop-sign-sheet-pending')),
      findsNothing,
    );

    await scrollPageTo(
      tester,
      find.byKey(const ValueKey<String>('sign-sheet-trigger-pending')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('sign-sheet-trigger-pending')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey<String>('loop-sheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('loop-sign-sheet-pending')),
      findsOneWidget,
    );
    await tester.tap(find.text('取消').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey<String>('loop-sheet')), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.path,
      '/system/sign-sheet',
    );
  });

  testWidgets('sign-sheet page remains usable at 2x text', (tester) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'sign-sheet-states',
        showcase: buildLoopSystemShowcasePreview(),
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
  });
}
