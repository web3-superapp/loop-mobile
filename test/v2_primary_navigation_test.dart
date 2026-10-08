import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/loop_ground_probe.dart';

void main() {
  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

  testWidgets('navigates the five v3 primary destinations in order', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(
      tester
          .widgetList<LoopTabItem>(find.byType(LoopTabItem))
          .map((destination) => destination.label),
      <String>['聊天', '广场', 'MEME', '情报', '钱包'],
    );
    expect(find.text('Home'), findsNothing);
    expect(find.text('Profile'), findsNothing);

    final router = GoRouter.of(
      tester.element(find.byKey(const ValueKey<String>('chat-tab-screen'))),
    );
    final destinations = <(String, String, Finder)>[
      ('广场', '/square', find.byKey(const ValueKey<String>('square-screen'))),
      ('MEME', '/meme', find.byKey(const ValueKey<String>('meme-screen'))),
      ('情报', '/intel', find.byKey(const ValueKey<String>('intel-screen'))),
      ('钱包', '/wallet', find.byKey(const ValueKey<String>('wallet-screen'))),
      ('聊天', '/chat', find.byKey(const ValueKey<String>('chat-tab-screen'))),
    ];

    for (final (label, path, content) in destinations) {
      await tester.tap(find.widgetWithText(LoopTabItem, label));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(content, findsOneWidget, reason: label);
    }
  });

  testWidgets('legacy Home and Launchpad routes redirect to v3 destinations', (
    tester,
  ) async {
    await _pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));

    router.go('/home');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/chat');
    expect(
      find.byKey(const ValueKey<String>('chat-tab-screen')),
      findsOneWidget,
    );

    router.go('/launchpad');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/launch');
    expect(find.byKey(const ValueKey<String>('launch-screen')), findsOneWidget);
  });

  testWidgets('unknown routes fall back directly to Chat', (tester) async {
    await _pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));

    router.go('/not-a-loop-route');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/chat');
    expect(
      find.byKey(const ValueKey<String>('chat-tab-screen')),
      findsOneWidget,
    );
    expect(find.byType(LoopTabBar), findsOneWidget);
  });

  testWidgets(
    'the four v2 tabs and Profile are child pages that return to Chat',
    (tester) async {
      await _pumpApp(tester);
      final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));

      for (final (path, key) in <(String, String)>[
        ('/community', 'community-screen'),
        ('/mining', 'mining-screen'),
        ('/launch', 'launch-screen'),
        ('/market', 'market-screen'),
        ('/profile', 'profile-home-screen'),
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, path);
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget, reason: path);
        expect(find.byType(LoopTabBar), findsNothing, reason: path);

        await tester.tap(
          find.byKey(const ValueKey<String>('loop-topbar-back')),
        );
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          '/chat',
          reason: path,
        );
        expect(find.byType(LoopTabBar), findsOneWidget);
      }
    },
  );

  testWidgets('the avatar on Chat pushes 我 and back returns to Chat', (
    tester,
  ) async {
    await _pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));

    await tester.tap(find.byKey(const ValueKey<String>('chat-open-profile')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('profile-home-screen')),
      findsOneWidget,
    );
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/profile',
    );
    await tester.tap(find.byKey(const ValueKey<String>('loop-topbar-back')));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/chat',
    );
    expect(
      find.byKey(const ValueKey<String>('chat-tab-screen')),
      findsOneWidget,
    );
  });
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
