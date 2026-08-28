import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

const _legacyPermissionClaims = <String>[
  'Use the camera to scan',
  'Camera access is off',
  'LOOP needs camera access only while you scan a QR code.',
  'Scanning stays unavailable until camera access is enabled in device settings.',
  'Used to read a QR code while the scanner is open.',
  'Receive time-sensitive alerts',
  'Notification access is off',
  'Allow notifications for price alerts, provider activity, security events, and selected community activity.',
  'Alerts cannot reach you while LOOP is closed until notifications are enabled in device settings.',
  'Used for the categories you enable in Notification settings.',
  'Confirm sensitive actions locally',
  'Biometric access is off',
  'Use device biometrics for app lock, recovery, and other protected account changes.',
  'Biometric confirmation is unavailable. Use another configured account check or enable it in settings.',
  'The device returns only whether the check succeeded. Biometric data stays on the device.',
  'LOOP will not use this permission for unrelated activity.',
];

void main() {
  testWidgets('production I6 route stays unknown without a permission prompt', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go('/system/permission');
    await tester.pumpAndSettle();

    expect(find.text('Permission status unavailable'), findsOneWidget);
    expect(find.text('Allow camera access to scan'), findsNothing);
    expect(find.text('Choose whether LOOP can notify you'), findsNothing);
    expect(find.text('Allow microphone access?'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Open settings'), findsNothing);
    expect(find.text('Not now'), findsNothing);
    for (final claim in _legacyPermissionClaims) {
      expect(find.text(claim), findsNothing);
    }

    await tester.tap(find.text('Return to LOOP'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('naked I6 never invents a permission context or exact action', (
    tester,
  ) async {
    var returned = false;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        onRetry: () => fail('generic retry must not authorize I6'),
        onPrimaryAction: () => fail('generic primary must not authorize I6'),
        onPermissionRequest: () => fail('request requires an exact prompt'),
        onPermissionOpenSettings: () =>
            fail('settings requires an exact prompt'),
        onPermissionNotNow: () => fail('dismiss requires an exact prompt'),
        onSecondaryAction: () => returned = true,
      ),
    );

    expect(find.text('Permission status unavailable'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Open settings'), findsNothing);
    expect(find.text('Not now'), findsNothing);
    expect(
      tester
          .widget<PopScope<void>>(
            find.byKey(const ValueKey<String>('system-state-dismissible')),
          )
          .canPop,
      isTrue,
    );

    await tester.tap(find.text('Return to LOOP'));
    expect(returned, isTrue);
  });

  testWidgets(
    'I6 education renders only the selected bounded permission copy',
    (tester) async {
      const cases =
          <
            ({
              LoopPermissionKind kind,
              String title,
              String message,
              String detail,
            })
          >[
            (
              kind: LoopPermissionKind.camera,
              title: 'Allow camera access to scan',
              message: 'This permission request is for QR scanning.',
              detail: 'The device controls the final permission choice. This page does not start a scanner.',
            ),
            (
              kind: LoopPermissionKind.notifications,
              title: 'Choose whether LOOP can notify you',
              message: 'This permission controls whether the operating system may show LOOP notifications.',
              detail: 'Notification preferences and operating-system permission are separate. Allowing access does not enable a category or prove delivery.',
            ),
            (
              kind: LoopPermissionKind.microphone,
              title: 'Allow microphone access?',
              message: 'LOOP uses the microphone only after you tap Speak in an audio room.',
              detail: 'Joining an audio room starts with the microphone off. The device controls the final permission choice.',
            ),
          ];

      for (final item in cases) {
        await _pump(
          tester,
          SystemSurfaceScreen.fromId(
            'permission',
            permissionPrompt: LoopPermissionPrompt(
              kind: item.kind,
              mode: LoopPermissionPromptMode.education,
            ),
          ),
        );

        expect(find.text(item.title), findsOneWidget);
        expect(find.text(item.message), findsOneWidget);
        expect(find.text(item.detail), findsOneWidget);
        expect(find.text('Continue'), findsNothing);
        expect(find.text('Open settings'), findsNothing);
        expect(find.text('Not now'), findsNothing);
        for (final other in cases) {
          if (other.kind == item.kind) continue;
          expect(find.text(other.title), findsNothing);
          expect(find.text(other.message), findsNothing);
          expect(find.text(other.detail), findsNothing);
        }
        for (final claim in _legacyPermissionClaims) {
          expect(find.text(claim), findsNothing);
        }
      }
    },
  );

  testWidgets('I6 settings recovery stays bounded to the selected kind', (
    tester,
  ) async {
    const cases = <({LoopPermissionKind kind, String name})>[
      (kind: LoopPermissionKind.camera, name: 'camera'),
      (kind: LoopPermissionKind.notifications, name: 'notification'),
      (kind: LoopPermissionKind.microphone, name: 'microphone'),
    ];

    for (final item in cases) {
      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'permission',
          permissionPrompt: LoopPermissionPrompt(
            kind: item.kind,
            mode: LoopPermissionPromptMode.settingsRecovery,
          ),
        ),
      );

      expect(
        find.text('Review ${item.name} access in settings'),
        findsOneWidget,
      );
      expect(
        find.text(
          'To change ${item.name} access, review LOOP in device settings.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Returning to LOOP does not prove that this permission changed.',
        ),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Open settings'), findsNothing);
      expect(find.text('Not now'), findsNothing);
      for (final other in cases) {
        if (other.kind == item.kind) continue;
        expect(
          find.text('Review ${other.name} access in settings'),
          findsNothing,
        );
        expect(
          find.text(
            'To change ${other.name} access, review LOOP in device settings.',
          ),
          findsNothing,
        );
      }
      for (final claim in _legacyPermissionClaims) {
        expect(find.text(claim), findsNothing);
      }
    }
  });

  testWidgets('I6 modes authorize only their exact dedicated actions', (
    tester,
  ) async {
    var requests = 0;
    var settingsOpens = 0;
    var dismissals = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        permissionPrompt: const LoopPermissionPrompt(
          kind: LoopPermissionKind.microphone,
          mode: LoopPermissionPromptMode.education,
        ),
        onPermissionRequest: () => requests += 1,
        onPermissionOpenSettings: () =>
            fail('education must not open settings'),
        onPermissionNotNow: () => dismissals += 1,
      ),
    );

    expect(find.text('Open settings'), findsNothing);
    await tester.tap(find.text('Continue'));
    await tester.tap(find.text('Not now'));
    expect(requests, 1);
    expect(dismissals, 1);

    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        permissionPrompt: const LoopPermissionPrompt(
          kind: LoopPermissionKind.camera,
          mode: LoopPermissionPromptMode.settingsRecovery,
        ),
        onPermissionRequest: () => fail('settings must not request again'),
        onPermissionOpenSettings: () => settingsOpens += 1,
        onPermissionNotNow: () => dismissals += 1,
      ),
    );

    expect(find.text('Continue'), findsNothing);
    await tester.tap(find.text('Open settings'));
    await tester.tap(find.text('Not now'));
    expect(settingsOpens, 1);
    expect(dismissals, 2);
  });

  testWidgets('explicit I6 prompt ignores generic system actions', (
    tester,
  ) async {
    await _pump(
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

    expect(find.text('Continue'), findsNothing);
    expect(find.text('Open settings'), findsNothing);
    expect(find.text('Not now'), findsNothing);
    expect(find.text('Return to LOOP'), findsNothing);
  });

  testWidgets('I6 states expose accessible exact actions', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        SystemSurfaceScreen.fromId('permission', onSecondaryAction: () {}),
      );
      _expectHeader(tester, 'Permission status unavailable');
      _expectTapButton(tester, find.text('Return to LOOP'), 'Return to LOOP');

      await _pump(
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
      );
      _expectHeader(tester, 'Allow microphone access?');
      _expectTapButton(tester, find.text('Continue'), 'Continue');
      _expectTapButton(tester, find.text('Not now'), 'Not now');

      await _pump(
        tester,
        SystemSurfaceScreen.fromId(
          'permission',
          permissionPrompt: const LoopPermissionPrompt(
            kind: LoopPermissionKind.camera,
            mode: LoopPermissionPromptMode.settingsRecovery,
          ),
          onPermissionOpenSettings: () {},
          onPermissionNotNow: () {},
        ),
      );
      _expectHeader(tester, 'Review camera access in settings');
      _expectTapButton(tester, find.text('Open settings'), 'Open settings');
      _expectTapButton(tester, find.text('Not now'), 'Not now');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('unknown I6 remains usable at large text', (tester) async {
    var returns = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        onSecondaryAction: () => returns += 1,
      ),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    await tester.ensureVisible(find.text('Return to LOOP'));
    await tester.tap(find.text('Return to LOOP'));
    expect(returns, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('education I6 actions remain usable at large text', (
    tester,
  ) async {
    var requests = 0;
    var dismissals = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        permissionPrompt: const LoopPermissionPrompt(
          kind: LoopPermissionKind.microphone,
          mode: LoopPermissionPromptMode.education,
        ),
        onPermissionRequest: () => requests += 1,
        onPermissionNotNow: () => dismissals += 1,
      ),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    expect(requests, 1);
    expect(dismissals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings I6 actions remain usable at large text', (
    tester,
  ) async {
    var settingsOpens = 0;
    var dismissals = 0;
    await _pump(
      tester,
      SystemSurfaceScreen.fromId(
        'permission',
        permissionPrompt: const LoopPermissionPrompt(
          kind: LoopPermissionKind.notifications,
          mode: LoopPermissionPromptMode.settingsRecovery,
        ),
        onPermissionOpenSettings: () => settingsOpens += 1,
        onPermissionNotNow: () => dismissals += 1,
      ),
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    await tester.ensureVisible(find.text('Open settings'));
    await tester.tap(find.text('Open settings'));
    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    expect(settingsOpens, 1);
    expect(dismissals, 1);
    expect(tester.takeException(), isNull);
  });
}

void _expectHeader(WidgetTester tester, String label) {
  final semantics = tester.getSemantics(find.text(label));
  expect(semantics.flagsCollection.isHeader, isTrue);
}

void _expectTapButton(WidgetTester tester, Finder finder, String label) {
  final semantics = tester.getSemantics(finder);
  expect(semantics.label, label);
  expect(semantics.flagsCollection.isButton, isTrue);
  expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(900, 1400),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}
