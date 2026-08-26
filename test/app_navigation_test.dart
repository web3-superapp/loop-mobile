import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/surface_catalog.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/catalog/catalog_surface_screen.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_repository.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  testWidgets('navigates the six primary destinations with one shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
          hyperliquidMarketRepositoryProvider.overrideWithValue(
            const _EmptyMarketRepository(),
          ),
          hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
            const _EmptySpotMarketRepository(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home overview'), findsOneWidget);
    for (final destination in <String>[
      'Market',
      'Launch',
      'Chat',
      'Wallet',
      'Profile',
      'Home',
    ]) {
      await tester.tap(find.widgetWithText(NavigationDestination, destination));
      await tester.pumpAndSettle();
    }
    expect(find.text('Home overview'), findsOneWidget);
  });

  testWidgets('spot-only primary navigation exposes no Perp entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
          hyperliquidMarketRepositoryProvider.overrideWithValue(
            const _EmptyMarketRepository(),
          ),
          hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
            const _EmptySpotMarketRepository(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(NavigationDestination, 'Market'));
    await tester.pumpAndSettle();
    expect(find.text('Spot market'), findsOneWidget);
    expect(find.textContaining('Perp trading'), findsNothing);
    expect(find.textContaining('Live perpetual markets'), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Wallet'));
    await tester.pumpAndSettle();
    expect(find.text('Trading account'), findsNothing);
    expect(find.textContaining('Hyperliquid margin'), findsNothing);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PERP EQUITY'), findsNothing);
    expect(find.textContaining('Spot to perp'), findsNothing);

    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Spot assets, groups and people.'), findsOneWidget);
    expect(find.text('ETH-PERP'), findsNothing);
  });

  testWidgets('retained Perp deep links redirect to the Spot market', (
    tester,
  ) async {
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

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    for (final path in LoopRouteRegistry.retainedPerpPaths) {
      router.go(path);
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/market');
      expect(find.text('Spot market'), findsOneWidget, reason: path);
      expect(find.text('Perpetuals'), findsNothing, reason: path);
      expect(find.text('Positions'), findsNothing, reason: path);
    }
  });

  testWidgets('providerless token links return to the live Spot ledger', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    final activity = find.text('ETH moved above your alert');
    await tester.ensureVisible(activity);
    await tester.pumpAndSettle();
    await tester.tap(activity);
    await tester.pumpAndSettle();

    expect(find.text('Spot market'), findsOneWidget);
    expect(find.textContaining('开发预览 K 线'), findsNothing);

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go('/search');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Suggested results and prices are static examples. Search is not connected.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('ETH'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/market');
    expect(find.text('Spot market'), findsOneWidget);

    router.go('/market/token');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/market');
    expect(find.text('Spot market'), findsOneWidget);
    expect(find.textContaining('开发预览 K 线'), findsNothing);

    router.go('/market/new');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('BTC / USDC'), 200);
    final newPair = find.bySemanticsLabel(
      RegExp('Open live Spot market after reviewing BTC preview'),
    );
    expect(newPair, findsOneWidget);
    await tester.tap(newPair);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/market');

    router.go('/market/smart-money');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Atlas 07'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
    final walletActivity = find.bySemanticsLabel(
      RegExp('Open live Spot market after reviewing Atlas 07 activity'),
    );
    expect(walletActivity, findsOneWidget);
    await tester.tap(walletActivity);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/market');
    semantics.dispose();
  });

  testWidgets('home Pay card opens an informational Coming soon route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    final payNotice = find.byKey(
      const ValueKey<String>('home-pay-coming-soon'),
    );
    expect(payNotice, findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('A priority · Delivery status: Deferred'), findsOneWidget);
    await tester.ensureVisible(payNotice);
    await tester.pumpAndSettle();
    await tester.tap(payNotice);
    await tester.pumpAndSettle();

    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.textContaining('Pay is not available yet'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
  });

  testWidgets('every Pay surface renders the same non-actionable placeholder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final payments = SurfaceCatalog.all.where(
      (surface) => surface.path.startsWith('/pay') || surface.path == '/onramp',
    );

    for (final surface in payments) {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: CatalogSurfaceScreen(surface: surface),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coming soon'), findsOneWidget);
      final priorityLabel = switch (surface.priority) {
        ProductPriority.a => 'A PRIORITY',
        ProductPriority.b => 'B PRIORITY',
        ProductPriority.c => 'C PRIORITY',
      };
      expect(find.text('${surface.id} · $priorityLabel'), findsOneWidget);
      expect(find.text('Product priority'), findsOneWidget);
      expect(find.text('Delivery status'), findsOneWidget);
      expect(find.text('Deferred'), findsOneWidget);
      expect(find.textContaining('PHASE ONE'), findsNothing);
      expect(find.textContaining('LATER'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
    }
  });

  testWidgets('communication preview is persistently identified as offline', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
          communicationGatewayProvider.overrideWithValue(
            MemoryCommunicationGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offline preview · not connected'), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Offline preview · not connected'), findsWidgets);
    expect(find.byKey(const ValueKey('communication-mode-status')), findsOne);
    expect(find.textContaining('126 online'), findsNothing);
    expect(find.textContaining('listening'), findsNothing);
  });

  testWidgets('default production communication mode stays unconfigured', (
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

    expect(find.text('Stream not connected'), findsOneWidget);
    expect(find.textContaining('Offline preview'), findsNothing);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Chat'));
    await tester.pumpAndSettle();

    expect(find.text('Stream not connected'), findsOneWidget);
    expect(find.text('Glyph Hunters'), findsNothing);
  });

  testWidgets('mobile voice preview never presents a connected room', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
          communicationGatewayProvider.overrideWithValue(
            MemoryCommunicationGateway(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Chat'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ETH Macro Room'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ETH Macro Room'));
    await tester.pumpAndSettle();

    expect(find.text('Offline preview'), findsOneWidget);
    expect(
      find.text('Offline preview · simulated room layout'),
      findsOneWidget,
    );
    expect(find.text('Open offline preview'), findsOneWidget);
    expect(find.textContaining('listening'), findsNothing);
    expect(find.textContaining('speaking'), findsNothing);

    await tester.tap(find.text('Open offline preview'));
    await tester.pumpAndSettle();

    expect(find.text('Offline preview'), findsOneWidget);
    expect(find.text('SIMULATED SEATS'), findsOneWidget);
    expect(find.text('Close preview'), findsOneWidget);
  });
}

final class _EmptyMarketRepository implements HyperliquidMarketRepository {
  const _EmptyMarketRepository();

  @override
  Future<List<HyperliquidMarket>> fetchMarkets() async => const [];
}

final class _EmptySpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  const _EmptySpotMarketRepository();

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async {
    return HyperliquidSpotSnapshot(
      receivedAt: DateTime.utc(2026, 8, 25),
      markets: const <HyperliquidSpotMarket>[],
    );
  }
}
