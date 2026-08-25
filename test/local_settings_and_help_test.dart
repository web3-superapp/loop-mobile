import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  testWidgets('Reduce motion is a real app-run setting', (tester) async {
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
    router.go('/profile/settings');
    await tester.pumpAndSettle();

    final setting = find.byKey(const ValueKey<String>('reduce-motion-setting'));
    final providerContainer = ProviderScope.containerOf(
      tester.element(setting),
    );
    expect(
      providerContainer.read(loopDisplayPreferencesProvider).reduceMotion,
      isFalse,
    );
    expect(
      find.text('Build-defined copy; localization is not connected'),
      findsOneWidget,
    );
    expect(find.text('Unavailable'), findsNWidgets(3));

    await tester.tap(
      find.descendant(of: setting, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(
      providerContainer.read(loopDisplayPreferencesProvider).reduceMotion,
      isTrue,
    );
    expect(MediaQuery.disableAnimationsOf(tester.element(setting)), isTrue);
  });

  testWidgets('bundled Help search filters real local answers', (tester) async {
    await _pumpSurface(tester, 'support');

    expect(find.text('LOCAL ANSWERS · 5'), findsOneWidget);
    expect(
      find.text('Why does Chat say Stream not connected?'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('local-help-search')),
      'server-derived',
    );
    await tester.pump();

    expect(find.text('LOCAL ANSWERS · 1'), findsOneWidget);
    expect(
      find.text('Why does Chat say Stream not connected?'),
      findsOneWidget,
    );
    expect(find.text('What does the Spot market show?'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('local-help-search')),
      'no matching bundled article',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('local-help-empty')),
      findsOneWidget,
    );
    expect(find.text('Online support is not connected'), findsOneWidget);
  });

  testWidgets('account-backed settings never render fixture account records', (
    tester,
  ) async {
    const surfaces = <String, String>{
      'connections': 'connections-unavailable',
      'blocklist': 'blocklist-unavailable',
      'security': 'recent-sign-ins-unavailable',
      'devices': 'device-management-unavailable',
      'social-recovery': 'social-recovery-unavailable',
    };
    for (final entry in surfaces.entries) {
      await _pumpSurface(tester, entry.key);
      expect(find.byKey(ValueKey<String>(entry.value)), findsOneWidget);
      expect(find.text('Guardian one'), findsNothing);
      expect(find.text('iPhone 16 Pro'), findsNothing);
      expect(find.text('Safari on Mac'), findsNothing);
      expect(find.text('NorthSignal'), findsNothing);
      expect(find.text('LoudOrbit'), findsNothing);
    }
  });

  testWidgets('About opens licenses but disables missing legal documents', (
    tester,
  ) async {
    await _pumpSurface(tester, 'about');

    expect(find.text('Document not included in this build'), findsNWidgets(2));
    expect(
      find.text('Document not included; Spot execution is disabled'),
      findsOneWidget,
    );

    final licenses = find.text('Open-source licenses');
    await tester.ensureVisible(licenses);
    await tester.tap(licenses);
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
  });
}

Future<void> _pumpSurface(WidgetTester tester, String surfaceId) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: ProfileSurfaceScreen.fromId(surfaceId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
