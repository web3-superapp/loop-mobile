import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/surface_catalog.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  testWidgets(
    'A11 exposes no providerless protection switch or secure-storage claim',
    (tester) async {
      final destinations = <String>[];
      await _pumpPhone(
        tester,
        AccountSurfaceScreen.fromId(
          'security-setup',
          capabilities: const PrivyWalletCapabilities(
            canUsePasskey: true,
            canUseBiometrics: true,
          ),
          onNavigate: destinations.add,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('protection-setup-unavailable')),
        findsOneWidget,
      );
      expect(find.text('Protection setup is not connected'), findsWidgets);
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Save protection'), findsNothing);
      expect(find.textContaining('stored by the app'), findsNothing);
      expect(find.textContaining('No app PIN is stored'), findsOneWidget);

      final continueWithoutChanges = find.text('Continue without changes');
      await _tap(tester, continueWithoutChanges);

      expect(destinations, <String>['profile-setup']);
    },
  );

  testWidgets(
    'H5 keeps capability availability separate from configured protection',
    (tester) async {
      final destinations = <String>[];
      await _pumpPhone(
        tester,
        ProfileSurfaceScreen.fromId(
          'security',
          capabilities: const PrivyProfileCapabilities(
            mfaAvailable: true,
            appLockAvailable: true,
            deviceManagementAvailable: true,
            recoveryPhraseRevealAvailable: true,
            socialRecoveryAvailable: true,
          ),
          onNavigate: destinations.add,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('protection-status-unavailable')),
        findsOneWidget,
      );
      expect(find.text('Protection status is not connected'), findsOneWidget);
      expect(find.text('Core protections ready'), findsNothing);
      expect(find.text('Add another protection'), findsNothing);
      expect(find.text('3/3'), findsNothing);
      expect(find.text('Recovery is not set'), findsNothing);
      expect(find.textContaining('enrollment status is unknown'), findsWidgets);

      final walletMfa = find.text('Wallet multi-factor authentication');
      final appLock = find.text('App lock');
      final walletMfaSemantics = _settingsSemantics(
        tester,
        'Wallet multi-factor authentication',
      );
      final appLockSemantics = _settingsSemantics(tester, 'App lock');
      expect(walletMfaSemantics.properties.enabled, isFalse);
      expect(appLockSemantics.properties.enabled, isFalse);

      await _tap(tester, walletMfa);
      await _tap(tester, appLock);
      expect(destinations, isEmpty);

      await _tap(tester, find.text('Devices & sessions'));
      await _tap(tester, find.text('Recovery phrase'));
      await _tap(tester, find.text('Social recovery'));

      expect(destinations, <String>[
        'devices',
        'seed-backup',
        'social-recovery',
      ]);
    },
  );

  testWidgets('production LoopApp A11 keeps every setup method unavailable', (
    tester,
  ) async {
    final router = await _pumpAuthenticatedLoopApp(tester);

    router.go('/auth/security');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('protection-setup-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Available'), findsNothing);
    expect(find.text('Unavailable'), findsNWidgets(3));
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('production LoopApp H5 keeps protection status unavailable', (
    tester,
  ) async {
    final router = await _pumpAuthenticatedLoopApp(tester);

    router.go('/profile/security');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('protection-status-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Available'), findsNothing);
    expect(find.text('Unavailable'), findsNWidgets(5));
    expect(find.text('Core protections ready'), findsNothing);
  });

  test('A11 and H5 catalog copy reports current delivery truth', () {
    final a11 = SurfaceCatalog.byPath('/auth/security');
    final h5 = SurfaceCatalog.byPath('/profile/security');
    expect(a11.description, contains('no protection setting is saved'));
    expect(
      h5.description,
      contains('availability without claiming enrollment'),
    );
  });
}

Future<void> _pumpPhone(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(theme: LoopTheme.dark, home: home));
  await tester.pumpAndSettle();
}

Future<GoRouter> _pumpAuthenticatedLoopApp(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

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

  return GoRouter.of(tester.element(find.text('Home overview')));
}

Semantics _settingsSemantics(WidgetTester tester, String title) =>
    tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            (widget.properties.label ?? '').startsWith('$title.'),
      ),
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
