import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
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
      <String>['Chat', 'Square', 'MEME', 'Intel', 'Me'],
    );
    expect(find.text('Home'), findsNothing);
    expect(find.text('Profile'), findsNothing);

    // Decision 0221: the App lands on MEME.
    expect(find.byType(MemeScreen), findsOneWidget);
    final router = GoRouter.of(tester.element(find.byType(MemeScreen)));
    final destinations = <(String, String, Finder)>[
      (
        'Square',
        '/square',
        find.byKey(const ValueKey<String>('square-screen')),
      ),
      ('MEME', '/meme', find.byKey(const ValueKey<String>('meme-screen'))),
      ('Intel', '/intel', find.byKey(const ValueKey<String>('intel-screen'))),
      ('Me', '/wallet', find.byKey(const ValueKey<String>('wallet-screen'))),
      ('Chat', '/chat', find.byKey(const ValueKey<String>('chat-tab-screen'))),
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
    expect(router.routeInformationProvider.value.uri.path, '/meme');
    expect(find.byType(MemeScreen), findsOneWidget);

    router.go('/launchpad');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/launch');
    expect(find.byKey(const ValueKey<String>('launch-screen')), findsOneWidget);
  });

  testWidgets('unknown routes fall back directly to MEME', (tester) async {
    await _pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));

    router.go('/not-a-loop-route');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/meme');
    expect(find.byType(MemeScreen), findsOneWidget);
    expect(find.byType(LoopTabBar), findsOneWidget);
  });

  testWidgets('the four v2 tabs are child pages that return to MEME', (
    tester,
  ) async {
    await _pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));

    for (final (path, key) in <(String, String)>[
      ('/community', 'community-screen'),
      ('/launch', 'launch-screen'),
      ('/market', 'market-screen'),
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(find.byKey(ValueKey<String>(key)), findsOneWidget, reason: path);
      expect(find.byType(LoopTabBar), findsNothing, reason: path);

      await tester.tap(find.byKey(const ValueKey<String>('loop-topbar-back')));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/meme',
        reason: path,
      );
      expect(find.byType(LoopTabBar), findsOneWidget);
    }
  });

  // S343 · decision 0271: 我 is the 我的 tab; 聊天 has no avatar into it,
  // and `/profile` lands on the tab.
  testWidgets('/profile lands on the 我的 tab; 聊天 has no avatar', (tester) async {
    await _pumpApp(tester);
    final router = GoRouter.of(tester.element(find.byType(LoopTabBar)));
    await tester.tap(find.widgetWithText(LoopTabItem, 'Chat'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('chat-open-profile')),
      findsNothing,
    );

    router.go('/profile');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet');
    expect(find.byKey(const ValueKey<String>('wallet-screen')), findsOneWidget);
    expect(find.byType(LoopTabBar), findsOneWidget);
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
