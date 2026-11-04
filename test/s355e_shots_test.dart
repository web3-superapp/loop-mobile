// S355e · decision 0281: English 360x800 frames of the account, profile and
// system pages, to look for truncation after the copy moved to ARB. Runs only
// with `--dart-define=LOOP_SHOTS=true`; PNGs go to `LOOP_SHOTS_DIR`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/profile/about/about_screen.dart';
import 'package:loop_mobile/features/profile/about/network_diagnostics_screen.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';
import 'package:loop_mobile/features/profile/support/support_screen.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s8_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment('LOOP_SHOTS_DIR');
const Size _size = Size(360, 800);

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(loopLoadShotFonts);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final element = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _pumpPlain(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _size;
  addTearDown(tester.view.reset);
  loopArmGroundProbe(tester);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: page,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  loopWatchGround();

  for (final id in <String>[
    'auth-wallet',
    'wallet-create',
    'wallet-recovery',
    'security-setup',
  ]) {
    testWidgets('account $id', skip: !_shots, (tester) async {
      await _pumpPlain(tester, AccountSurfaceScreen.fromId(id));
      await _shot(tester, 'account-$id');
    });
  }

  for (final id in <String>[
    'offline',
    'server-error',
    'maintenance',
    'force-update',
    'region-restricted',
    'permission',
    'toast',
    'loading',
    'token-card-states',
    'sign-sheet-states',
  ]) {
    testWidgets('system $id', skip: !_shots, (tester) async {
      await _pumpPlain(tester, SystemSurfaceScreen.fromId(id));
      await _shot(tester, 'system-$id');
    });
  }

  final observed = <String, Widget Function()>{
    'offline-market': () => const SystemSurfaceScreen.fromId(
      'offline',
      connectivityObservation: LoopConnectivityObservation(
        scope: LoopConnectivityScope.marketDataUnavailable,
      ),
    ),
    'region-restricted-observed': () => const SystemSurfaceScreen.fromId(
      'region-restricted',
      featureAvailabilityRestriction: LoopFeatureAvailabilityRestriction(),
    ),
    'server-error-observed': () => const SystemSurfaceScreen.fromId(
      'server-error',
      serviceErrorObservation: LoopServiceErrorObservation(traceId: 'L-2048'),
    ),
  };
  for (final entry in observed.entries) {
    testWidgets('system ${entry.key}', skip: !_shots, (tester) async {
      await _pumpPlain(tester, entry.value());
      await _shot(tester, 'system-${entry.key}');
    });
  }

  final profilePages = <String, Widget Function()>{
    'security': () => SecurityCenterScreen(onNavigate: (_) {}),
    'devices': () => const DeviceManagementScreen(),
    'key-export': () => const KeyExportScreen(),
    'social-recovery': () => const SocialRecoveryScreen(),
    'about': () => const AboutScreen(),
    'network-diagnostics': () => const NetworkDiagnosticsScreen(),
    'support': () => SupportScreen(onNavigate: (_) {}),
  };
  for (final entry in profilePages.entries) {
    testWidgets('profile ${entry.key}', skip: !_shots, (tester) async {
      await pumpS8Page(
        tester,
        entry.value(),
        security: FakeSecurityGateway(),
        about: FakeAboutGateway(),
        support: FakeSupportGateway(),
        size: _size,
      );
      await _shot(tester, 'profile-${entry.key}');
    });
  }
}
