import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/preview_conversation_identity.dart';
import 'package:loop_mobile/features/home/home_screens.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  testWidgets(
    'production Search is unavailable and contains no Preview facts',
    (tester) async {
      await _pumpScreen(
        tester,
        session: _AuthenticatedSession.new,
        child: const GlobalSearchScreen(),
      );

      expect(
        find.byKey(
          const ValueKey<String>('global-search-provider-unavailable'),
        ),
        findsOneWidget,
      );
      expect(find.text('Search not connected'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('ETH'), findsNothing);
      expect(find.text(PreviewConversationIdentity.group.title), findsNothing);
      expect(find.text(PreviewConversationIdentity.direct.title), findsNothing);
    },
  );

  testWidgets('query filters local suggestions and Clear restores them', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      session: _PreviewSession.new,
      child: const GlobalSearchScreen(),
    );

    expect(
      find.byKey(const ValueKey<String>('global-search-preview-fixtures')),
      findsOneWidget,
    );
    expect(find.text('ETH'), findsOneWidget);
    expect(find.text(PreviewConversationIdentity.group.title), findsOneWidget);
    expect(find.text(PreviewConversationIdentity.direct.title), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  gLyPh   group  ');
    await tester.pump();

    expect(find.text('ETH'), findsNothing);
    expect(find.text(PreviewConversationIdentity.group.title), findsOneWidget);
    expect(find.text(PreviewConversationIdentity.direct.title), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(find.text('ETH'), findsOneWidget);
    expect(find.text(PreviewConversationIdentity.group.title), findsOneWidget);
    expect(find.text(PreviewConversationIdentity.direct.title), findsOneWidget);
  });

  testWidgets('no-match never restores unrelated suggestions', (tester) async {
    await _pumpScreen(
      tester,
      session: _PreviewSession.new,
      child: const GlobalSearchScreen(),
    );

    await tester.enterText(find.byType(TextField), 'not-a-preview-target');
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('global-search-preview-empty')),
      findsOneWidget,
    );
    expect(find.text('No local preview matches'), findsOneWidget);
    expect(find.text('ETH'), findsNothing);
    expect(find.text(PreviewConversationIdentity.group.title), findsNothing);
    expect(find.text(PreviewConversationIdentity.direct.title), findsNothing);
  });

  testWidgets('ETH opens bare Spot ledger and person opens exact Preview ID', (
    tester,
  ) async {
    final router = _searchRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [loopSessionProvider.overrideWith(_PreviewSession.new)],
        child: MaterialApp.router(theme: LoopTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('global-search-preview-eth')),
    );
    await tester.pumpAndSettle();
    final marketLocation = router.routeInformationProvider.value.uri;
    expect(marketLocation.path, '/market');
    expect(marketLocation.queryParameters, isEmpty);

    router.go('/search');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'sable person');
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('global-search-preview-person')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('global-search-preview-person')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Preview direct ${PreviewConversationIdentity.direct.id}'),
      findsOneWidget,
    );
  });

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
    'production LoopApp security route mounts the unavailable surface',
    (tester) async {
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

      final router = GoRouter.of(tester.element(find.text('Home overview')));
      router.go('/home/security');
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('security-activity-provider-unavailable'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('security-activity-preview-fixtures'),
        ),
        findsNothing,
      );
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

GoRouter _searchRouter() {
  return GoRouter(
    initialLocation: '/search',
    routes: <RouteBase>[
      GoRoute(
        path: '/search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),
      GoRoute(
        path: '/market',
        builder: (context, state) => const Scaffold(body: Text('Spot market')),
      ),
      GoRoute(
        path: '/chat/dm',
        builder: (context, state) => Scaffold(
          body: Text(
            'Preview direct ${state.uri.queryParameters['conversationId'] ?? 'missing'}',
          ),
        ),
      ),
    ],
  );
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
