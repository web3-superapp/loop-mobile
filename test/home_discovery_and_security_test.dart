import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/loop_routing_error_log.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/home/home_screens.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  // The former Home-era `GlobalSearchScreen` (Preview fixture suggestions)
  // was retired in step 3: `/search` is now the V2 five-domain search page,
  // covered by the `search` group in `test/community_social_pages_test.dart`
  // and by `test/community_public_profile_and_apply_test.dart`.
  testWidgets(
    'production Security is unavailable and contains no fixture facts or actions',
    (tester) async {
      await _pumpScreen(
        tester,
        session: _AuthenticatedSession.new,
        child: const SecurityActivityScreen(),
      );

      expect(
        find.byKey(
          const ValueKey<String>('security-activity-provider-unavailable'),
        ),
        findsOneWidget,
      );
      expect(find.text('Security activity not connected'), findsOneWidget);
      expect(find.text('No urgent action'), findsNothing);
      expect(find.textContaining('MFA is active'), findsNothing);
      expect(find.text('Unlimited approval blocked'), findsNothing);
      expect(find.text('Revoke'), findsNothing);
      expect(find.text('Block'), findsNothing);
    },
  );

  testWidgets(
    'production LoopApp retires the Home security route to Community',
    (tester) async {
      final routingErrors = LoopRoutingErrorLog();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(
              const AuthenticatedTestPrivyGateway(),
            ),
            loopRoutingErrorLogProvider.overrideWithValue(routingErrors),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();

      final router = GoRouter.of(
        tester.element(find.byKey(const ValueKey<String>('community-screen'))),
      );
      router.go('/home/security');
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/community');
      expect(routingErrors.last?.location, '/home/security');
      expect(
        find.byKey(
          const ValueKey<String>('security-activity-provider-unavailable'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('security-activity-preview-fixtures'),
        ),
        findsNothing,
      );
      expect(find.text('No urgent action'), findsNothing);
      expect(find.textContaining('MFA is active'), findsNothing);
    },
  );

  testWidgets(
    'explicit Preview Security is visibly labelled and has no score or provider action',
    (tester) async {
      await _pumpScreen(
        tester,
        session: _PreviewSession.new,
        child: const SecurityActivityScreen(),
      );

      expect(
        find.byKey(
          const ValueKey<String>('security-activity-preview-fixtures'),
        ),
        findsOneWidget,
      );
      expect(find.text('开发预览'), findsWidgets);
      expect(find.textContaining('演示数据'), findsWidgets);
      expect(find.text('Example summary · 演示数据'), findsOneWidget);
      expect(find.text('Unlimited approval blocked'), findsOneWidget);
      expect(find.textContaining('MFA'), findsNothing);
      expect(find.text('Risk score'), findsNothing);
      expect(find.text('AI Guard'), findsNothing);
      expect(find.text('Revoke'), findsNothing);
      expect(find.text('Block'), findsNothing);
    },
  );

  testWidgets('Home security activity opens the bounded security surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = _homeSecurityRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [loopSessionProvider.overrideWith(_PreviewSession.new)],
        child: MaterialApp.router(theme: LoopTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final activity = find.text('One approval can spend your USDC');
    await tester.ensureVisible(activity);
    await tester.pumpAndSettle();
    await tester.tap(activity);
    await tester.pumpAndSettle();

    expect(find.text('Security activity'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('security-activity-preview-fixtures')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required LoopSessionController Function() session,
  required Widget child,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loopSessionProvider.overrideWith(session)],
      child: MaterialApp(theme: LoopTheme.dark, home: child),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _homeSecurityRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/home/security',
        builder: (context, state) => const SecurityActivityScreen(),
      ),
    ],
  );
}

final class _AuthenticatedSession extends LoopSessionController {
  @override
  LoopSessionState build() {
    return const LoopSessionState(mode: LoopSessionMode.authenticated);
  }
}

final class _PreviewSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState.preview();
}
