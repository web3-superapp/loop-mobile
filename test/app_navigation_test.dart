import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/spot_market_route.dart';
import 'package:loop_mobile/core/navigation/surface_catalog.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/catalog/catalog_surface_screen.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/bridge_preview_snapshot.dart';
import 'package:loop_mobile/features/wallet/swap_preview_snapshot.dart';
import 'package:loop_mobile/features/wallet/wallet_preview_asset.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_repository.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart';
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
    expect(find.text('Search not connected'), findsOneWidget);
    expect(find.text('ETH'), findsNothing);
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
    final spotRepository = _TrackingSpotMarketRepository(
      HyperliquidSpotSnapshot(
        receivedAt: DateTime.utc(2026, 8, 28),
        markets: const <HyperliquidSpotMarket>[],
      ),
    );
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
            spotRepository,
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    final discover = find.byKey(
      const ValueKey<String>('home-open-public-market'),
    );
    await tester.ensureVisible(discover);
    await tester.pumpAndSettle();
    await tester.tap(discover);
    await tester.pumpAndSettle();

    expect(find.text('Spot market'), findsOneWidget);
    expect(find.textContaining('开发预览 K 线'), findsNothing);

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go('/search');
    await tester.pumpAndSettle();
    expect(find.text('Search not connected'), findsOneWidget);
    expect(find.text('ETH'), findsNothing);

    router.go('/market/token');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/market');
    expect(find.text('Spot market'), findsOneWidget);
    expect(find.textContaining('开发预览 K 线'), findsNothing);

    final fetchCountBeforeNewPairs = spotRepository.fetchCount;
    router.go('/market/new');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/market/new');
    expect(router.routeInformationProvider.value.uri.query, isEmpty);
    expect(
      find.byKey(
        const ValueKey<String>('market-new-pairs-production-unavailable'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('market-new-pairs-preview-fixtures')),
      findsNothing,
    );
    expect(find.text('BTC / USDC'), findsNothing);
    expect(find.text('ETH / USDC'), findsNothing);
    expect(find.text('SOL / USDC'), findsNothing);
    expect(find.textContaining('开发预览'), findsNothing);
    expect(find.textContaining('演示数据'), findsNothing);
    expect(spotRepository.fetchCount, fetchCountBeforeNewPairs);

    // End of the authenticated C10 application-navigation evidence.
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

  testWidgets(
    'production C3 rejects legacy extras and malformed query before requests',
    (tester) async {
      final marketRepository = _TrackingSpotMarketRepository(
        HyperliquidSpotSnapshot(
          receivedAt: DateTime.utc(2026, 8, 28),
          markets: const <HyperliquidSpotMarket>[],
        ),
      );
      final candleRepository = _TrackingSpotCandleRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(
              const AuthenticatedTestPrivyGateway(),
            ),
            hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
              marketRepository,
            ),
            hyperliquidSpotCandleRepositoryProvider.overrideWithValue(
              candleRepository,
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();

      final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
      final malformed = <(String, Object?)>[
        ('/market/chart', 'ETH'),
        ('/market/chart?spotIndex=1&spotIndex=2', null),
        ('/market/chart?spotIndex=1&source=preview', null),
        ('/market/chart?spotIndex=1#fragment', null),
      ];
      for (final (location, extra) in malformed) {
        router.go(location, extra: extra);
        await tester.pumpAndSettle();

        expect(
          find.text('Invalid spot chart'),
          findsOneWidget,
          reason: location,
        );
        expect(find.byType(NavigationBar), findsNothing, reason: location);
      }

      expect(marketRepository.fetchCount, 0);
      expect(candleRepository.requests, isEmpty);
    },
  );

  testWidgets('production C3 is full-screen and closes a root link to Market', (
    tester,
  ) async {
    final marketRepository = _TrackingSpotMarketRepository(_singleSpotSnapshot);
    final candleRepository = _TrackingSpotCandleRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(
            const AuthenticatedTestPrivyGateway(),
          ),
          hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
            marketRepository,
          ),
          hyperliquidSpotCandleRepositoryProvider.overrideWithValue(
            candleRepository,
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go(SpotMarketRoute.chartLocation(7));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/market/chart');
    expect(find.text('SEVEN/USDC'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(candleRepository.requests, <HyperliquidSpotCandleRequest>[
      const HyperliquidSpotCandleRequest(
        providerCoin: '@7',
        interval: HyperliquidSpotCandleInterval.fourHours,
      ),
    ]);

    await tester.tap(find.byTooltip('关闭全屏 K 线'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/market');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Spot market'), findsOneWidget);
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

  testWidgets('incomplete Send deep links return to asset selection', (
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

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go('/wallet/send/to');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');
    expect(find.text('Choose asset'), findsOneWidget);

    router.go('/wallet/send/to', extra: 'wrong draft type');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');

    router.go('/wallet/send/confirm');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');

    router.go('/wallet/send/confirm', extra: 'wrong draft type');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');

    router.go(
      '/wallet/send/confirm',
      extra: const TransferDraft(asset: 'ETH', network: 'Ethereum'),
    );
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');
    expect(find.text('Choose asset'), findsOneWidget);

    router.go(
      '/wallet/send/confirm',
      extra: const TransferDraft(
        asset: 'ETH',
        network: 'Ethereum',
        recipient: '   ',
      ),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/send');
  });

  testWidgets('orphan Wallet review and asset routes fail closed', (
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

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go('/wallet/asset');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/wallet');
    expect(find.text('Wallet'), findsWidgets);

    router.go('/preview/signing-review');
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/wallet');
    expect(find.text('Transaction intent review'), findsNothing);
  });

  testWidgets('asset detail consumes the exact typed preview asset', (
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

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go('/wallet/asset', extra: WalletPreviewAsset.usdCoin);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/wallet/asset');
    expect(find.text('USD Coin'), findsOneWidget);
    expect(find.text('6,810.20 USDC'), findsWidgets);
    expect(find.text('Asset activity unavailable'), findsOneWidget);
    expect(find.text('4.82 ETH'), findsNothing);
  });

  testWidgets('Swap quote route requires the exact typed snapshot', (
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

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go('/wallet/swap/route');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/swap');

    router.go('/wallet/swap/route', extra: 'wrong snapshot type');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/swap');

    router.go('/wallet/swap/route', extra: SwapPreviewSnapshot.demo);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/wallet/swap/route',
    );
    expect(find.text(SwapPreviewSnapshot.demo.payLabel), findsOneWidget);
    expect(find.text(SwapPreviewSnapshot.demo.receiveLabel), findsOneWidget);
  });

  testWidgets('Bridge status route requires the exact typed snapshot', (
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

    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));
    router.go('/wallet/bridge/status');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/bridge');

    router.go('/wallet/bridge/status', extra: 'wrong Bridge snapshot type');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/wallet/bridge');

    final claimSnapshot = BridgePreviewSnapshot.demo.withNeedsClaim(true);
    router.go('/wallet/bridge/status', extra: claimSnapshot);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/wallet/bridge/status',
    );
    expect(find.text(claimSnapshot.sourceConfirmationLabel), findsOneWidget);
    expect(find.text(claimSnapshot.destinationStepDetail), findsOneWidget);
    expect(find.text('Manual claim required'), findsOneWidget);
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
    expect(find.text('Audio Room'), findsOneWidget);
    expect(find.text('ETH Macro Room'), findsNothing);
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

final HyperliquidSpotSnapshot _singleSpotSnapshot = HyperliquidSpotSnapshot(
  receivedAt: DateTime.utc(2026, 8, 28, 6),
  markets: <HyperliquidSpotMarket>[
    HyperliquidSpotMarket(
      spotIndex: 7,
      providerCoin: '@7',
      baseTokenIndex: 7,
      quoteTokenIndex: 0,
      baseTokenId: '0x77777777777777777777777777777777',
      quoteTokenId: '0x00000000000000000000000000000000',
      baseSymbol: 'SEVEN',
      quoteSymbol: 'USDC',
      baseSizeDecimals: 4,
      isCanonical: true,
      markPrice: HyperliquidSpotDecimal(
        source: '7.25',
        value: Decimal.parse('7.25'),
      ),
      previousDayPrice: HyperliquidSpotDecimal(
        source: '7',
        value: Decimal.parse('7'),
      ),
      dayNotionalVolume: HyperliquidSpotDecimal(
        source: '7000',
        value: Decimal.parse('7000'),
      ),
      dayBaseVolume: HyperliquidSpotDecimal(
        source: '1000',
        value: Decimal.parse('1000'),
      ),
    ),
  ],
);

final class _TrackingSpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  _TrackingSpotMarketRepository(this.snapshot);

  final HyperliquidSpotSnapshot snapshot;
  int fetchCount = 0;

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async {
    fetchCount += 1;
    return snapshot;
  }
}

final class _TrackingSpotCandleRepository
    implements HyperliquidSpotCandleRepository {
  final List<HyperliquidSpotCandleRequest> requests =
      <HyperliquidSpotCandleRequest>[];

  @override
  Future<HyperliquidSpotCandleSnapshot> fetchCandles({
    required String providerCoin,
    required HyperliquidSpotCandleInterval interval,
  }) async {
    requests.add(
      HyperliquidSpotCandleRequest(
        providerCoin: providerCoin,
        interval: interval,
      ),
    );
    final receivedAt = DateTime.utc(2026, 8, 28, 6);
    return HyperliquidSpotCandleSnapshot(
      providerCoin: providerCoin,
      interval: interval,
      requestedFrom: receivedAt.subtract(interval.lookback),
      requestedUntil: receivedAt,
      receivedAt: receivedAt,
      candles: const <HyperliquidSpotCandle>[],
    );
  }
}
