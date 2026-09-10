import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/surface_catalog.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/security/security_models.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/s8_harness.dart';

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
      expect(find.text('保护设置还没有开放'), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Save protection'), findsNothing);
      expect(find.textContaining('stored by the app'), findsNothing);
      expect(find.textContaining('App 不会自行存储 PIN'), findsOneWidget);
      // A declared device capability is never reported as an enabled
      // protection: the passed-in capabilities only relabel the rows.
      expect(find.text('可用'), findsOneWidget);
      expect(find.text('不可用'), findsNWidgets(3));

      await _tap(
        tester,
        find.byKey(const ValueKey<String>('security-setup-continue')),
      );

      expect(destinations, <String>['loop-id-setup']);
    },
  );

  testWidgets('H5 states each protection method is off, with its reason', (
    tester,
  ) async {
    final destinations = <String>[];
    await pumpS8Page(
      tester,
      SecurityCenterScreen(onNavigate: destinations.add),
      security: FakeSecurityGateway(),
    );

    // No score, no badge, no "protections ready" claim.
    expect(find.text('GOOD'), findsNothing);
    expect(find.textContaining('项保护已开启'), findsNothing);
    expect(find.text('2 台设备 · 2 个会话'), findsOneWidget);

    for (final id in LoopSecurityCapabilityId.values) {
      final row = find.byKey(
        ValueKey<String>('security-method-${id.wireName}'),
      );
      await scrollToS8Section(tester, row);
      expect(row, findsOneWidget, reason: id.wireName);
    }
    expect(find.text('未开启'), findsNWidgets(6));
    expect(find.text('已开启'), findsOneWidget); // security.event only

    // The two rows that lead somewhere lead to their own explanation page.
    await tester.tap(
      find.byKey(const ValueKey<String>('security-method-socialRecovery')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('security-method-keyExport')),
    );
    await tester.pumpAndSettle();
    expect(destinations, <String>['social-recovery', 'key-export']);
    expect(find.text('Recovery phrase'), findsNothing);
    expect(ProfileSurfaceScreen.supportedIds, isNot(contains('seed-backup')));
  });

  testWidgets('no recovery-phrase or seed surface is reachable from Profile', (
    tester,
  ) async {
    for (final retiredId in <String>[
      'seed-backup',
      'seed',
      'recovery-phrase',
    ]) {
      expect(ProfileSurfaceScreen.supportedIds, isNot(contains(retiredId)));

      await _pumpPhone(tester, ProfileSurfaceScreen.fromId(retiredId));

      expect(find.text('Setting unavailable'), findsOneWidget);
      expect(find.text('No changes made'), findsOneWidget);
      expect(find.textContaining('Recovery phrase'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    }
  });

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
    expect(find.text('可用'), findsNothing);
    expect(find.text('不可用'), findsNWidgets(4));
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('production LoopApp H5 fails closed with no adapter', (
    tester,
  ) async {
    final router = await _pumpAuthenticatedLoopApp(tester);

    router.go('/profile/security');
    await tester.pumpAndSettle();

    // Production has no assembled security adapter, so the whole page is
    // unavailable with a reason instead of claiming anything about the
    // account's protection.
    expect(
      find.byKey(const ValueKey<String>('security-capability-block')),
      findsOneWidget,
    );
    expect(find.text('安全中心当前不可用'), findsOneWidget);
    expect(find.textContaining('项保护已开启'), findsNothing);
    expect(find.text('已开启'), findsNothing);
    expect(find.text('Recovery phrase'), findsNothing);
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

  return GoRouter.of(
    tester.element(find.byKey(const ValueKey<String>('community-screen'))),
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
