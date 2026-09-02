import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  testWidgets('navigates the five V2 primary destinations in order', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(
      tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((destination) => destination.label),
      <String>['Community', 'Mining', 'Launch', 'Market', 'Wallet'],
    );
    expect(find.text('Home'), findsNothing);
    expect(find.text('Chat'), findsNothing);
    expect(find.text('Profile'), findsNothing);

    final router = GoRouter.of(
      tester.element(find.byKey(const ValueKey<String>('community-screen'))),
    );
    final destinations = <(String, String, Finder)>[
      (
        'Community',
        '/community',
        find.byKey(const ValueKey<String>('community-screen')),
      ),
      (
        'Mining',
        '/mining',
        find.byKey(const ValueKey<String>('mining-screen')),
      ),
      (
        'Launch',
        '/launch',
        find.byKey(const ValueKey<String>('launchpad-unavailable')),
      ),
      ('Market', '/market', find.text('Spot market')),
      ('Wallet', '/wallet', find.text('Portfolio remains 开发预览')),
    ];

    for (final (label, path, content) in destinations) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(content, findsOneWidget, reason: label);
    }
  });

  testWidgets('legacy Home and Launchpad routes redirect to V2 destinations', (
    tester,
  ) async {
    await _pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));

    router.go('/home');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/community');
    expect(
      find.byKey(const ValueKey<String>('community-screen')),
      findsOneWidget,
    );

    router.go('/launchpad');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/launch');
    expect(
      find.byKey(const ValueKey<String>('launchpad-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('unknown routes fall back directly to Community', (tester) async {
    await _pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));

    router.go('/not-a-loop-route');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/community');
    expect(
      find.byKey(const ValueKey<String>('community-screen')),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'Chat and Profile stay outside the primary shell and return to Community',
    (tester) async {
      await _pumpApp(tester);
      final router = GoRouter.of(tester.element(find.byType(NavigationBar)));

      router.go('/chat');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/chat');
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('stream-chat-back-to-community')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('stream-chat-back-to-community')),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/community');
      expect(find.byType(NavigationBar), findsOneWidget);

      router.go('/profile');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/profile');
      expect(find.byType(NavigationBar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('profile-back-to-community')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('profile-back-to-community')),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/community');
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
          const _EmptySpotMarketRepository(),
        ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
}

final class _EmptySpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  const _EmptySpotMarketRepository();

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async {
    return HyperliquidSpotSnapshot(
      receivedAt: DateTime.utc(2026, 9, 2),
      markets: const <HyperliquidSpotMarket>[],
    );
  }
}
