import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';

import 'support/system_surface_harness.dart';
import 'support/test_hints.dart';

void main() {
  // S237 · decision 0204: these cases pin the testnet / specimen behaviour.
  loopShowTestHints();

  testWidgets('production permission route explains but requests nothing', (
    tester,
  ) async {
    await expectProductionSpecimen(
      tester,
      location: '/system/permission',
      kicker: 'Permissions',
      specimenKeys: <String>['permission-denied-specimen'],
      specimenText: <String>[
        'Notification permission',
        'Camera permission',
        'Biometrics',
        'Notifications are turned off in system settings',
      ],
    );
  });

  testWidgets('without a prompt the page draws the denied-state specimen', (
    tester,
  ) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        onPermissionRequest: () => fail('a specimen never requests'),
        onPermissionNotNow: () => fail('a specimen has no 暂不'),
        onSecondaryAction: () => fail('a specimen page has no 返回 LOOP'),
      ),
    );
    expect(find.text('Asked only when needed'), findsOneWidget);
    expect(find.text('Notification permission'), findsOneWidget);
    expect(find.text('Camera permission'), findsOneWidget);
    expect(find.text('Biometrics'), findsOneWidget);
    expect(find.text('After denial (component specimen)'), findsOneWidget);
    expect(
      find.text('Notifications are turned off in system settings'),
      findsOneWidget,
    );
    expect(find.text('当前没有待处理的权限申请'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Not now'), findsNothing);
    expect(find.text('Back to LOOP'), findsNothing);
    // The specimen's own exit is the prototype's toast, not a system call.
    // Decision 0281 transition: the shared permission card is lib/widgets.
    await scrollPageTo(tester, find.text('前往系统设置'));
    await tester.tap(find.text('前往系统设置'));
    await tester.pump();
    expect(find.text('Allow LOOP in system settings'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
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
        onRetry: () => fail('generic retry must stay isolated from I6'),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
      ),
    );
    expect(
      find.byKey(const ValueKey<String>('permission-prompt-camera-education')),
      findsOneWidget,
    );
    expect(find.text('This request'), findsOneWidget);
    expect(find.text('Open system settings'), findsNothing);
    expect(find.text('Back to LOOP'), findsNothing);
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
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
    expect(find.text('After denial'), findsOneWidget);
    expect(
      find.text('Notifications permission is turned off in system settings'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Settings → LOOP → Notifications'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsNothing);
    await tester.ensureVisible(find.text('Open system settings'));
    await tester.tap(find.text('Open system settings'));
    expect((requests, settings), (1, 1));
  });

  testWidgets('an explicit prompt never accepts generic system actions', (
    tester,
  ) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        permissionPrompt: const LoopPermissionPrompt(
          kind: LoopPermissionKind.notifications,
          mode: LoopPermissionPromptMode.education,
        ),
        onRetry: () => fail('generic retry must stay isolated from I6'),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
      ),
    );

    expect(find.text('This request'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Open system settings'), findsNothing);
    expect(find.text('Not now'), findsNothing);
    expect(find.text('Back to LOOP'), findsNothing);
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
    await scrollPageTo(tester, find.text('Not now'));
    await tester.tap(find.text('Not now'));
  });
}
