import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production permission route explains but requests nothing', (
    tester,
  ) async {
    await expectProductionUnavailable(
      tester,
      location: '/system/permission',
      unavailableKey: 'permission-prompt-unavailable',
      absentClaims: <String>['前往系统设置', '已被系统关闭', '暂不'],
    );
  });

  testWidgets('naked permission surface keeps the explanations only', (
    tester,
  ) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        onPermissionRequest: () {},
        onPermissionOpenSettings: () {},
        onPermissionNotNow: () {},
        onSecondaryAction: () {},
      ),
    );
    expect(find.text('使用前再申请'), findsOneWidget);
    expect(find.text('通知权限'), findsOneWidget);
    expect(find.text('相机权限'), findsOneWidget);
    expect(find.text('生物识别'), findsOneWidget);
    expect(find.text('当前没有待处理的权限申请'), findsOneWidget);
    expect(find.text('继续'), findsNothing);
    expect(find.text('前往系统设置'), findsNothing);
    expect(find.text('暂不'), findsNothing);
    expect(find.text('返回 LOOP'), findsOneWidget);
  });

  testWidgets('education and settings modes expose only their exact actions', (
    tester,
  ) async {
    var requests = 0;
    var settings = 0;
    var notNow = 0;
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        permissionPrompt: const LoopPermissionPrompt(
          kind: LoopPermissionKind.camera,
          mode: LoopPermissionPromptMode.education,
        ),
        onPermissionRequest: () => requests += 1,
        onPermissionOpenSettings: () => settings += 1,
        onPermissionNotNow: () => notNow += 1,
        onSecondaryAction: () {},
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('permission-prompt-camera-education')),
      findsOneWidget,
    );
    expect(find.text('本次申请'), findsOneWidget);
    expect(find.text('前往系统设置'), findsNothing);
    expect(find.text('返回 LOOP'), findsNothing);
    await tester.ensureVisible(find.text('继续'));
    await tester.tap(find.text('继续'));
    await tester.ensureVisible(find.text('暂不'));
    await tester.tap(find.text('暂不'));
    expect((requests, settings, notNow), (1, 0, 1));

    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        permissionPrompt: const LoopPermissionPrompt(
          kind: LoopPermissionKind.notifications,
          mode: LoopPermissionPromptMode.settingsRecovery,
        ),
        onPermissionRequest: () => requests += 1,
        onPermissionOpenSettings: () => settings += 1,
        onPermissionNotNow: () => notNow += 1,
      ),
    );
    expect(find.text('被拒后的引导'), findsOneWidget);
    expect(find.text('通知权限已被系统关闭'), findsOneWidget);
    expect(find.textContaining('系统设置 → LOOP → 通知'), findsOneWidget);
    expect(find.text('继续'), findsNothing);
    await tester.ensureVisible(find.text('前往系统设置'));
    await tester.tap(find.text('前往系统设置'));
    expect((requests, settings), (1, 1));
  });

  testWidgets('permission states remain usable at 2x text', (tester) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        permissionPrompt: const LoopPermissionPrompt(
          kind: LoopPermissionKind.microphone,
          mode: LoopPermissionPromptMode.education,
        ),
        onPermissionRequest: () {},
        onPermissionNotNow: () {},
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await scrollPageTo(tester, find.text('暂不'));
    await tester.tap(find.text('暂不'));
  });
}
