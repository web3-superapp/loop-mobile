import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/surface_catalog.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/catalog/catalog_surface_screen.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/review/signing_review_surface.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_fixture_adapter.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_repository.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_trading_gateway.dart';
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

  testWidgets('fixture Perp order opens exactly one shared F11 surface', (
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
          hyperliquidTradingGatewayProvider.overrideWithValue(
            const HyperliquidFixtureAdapter(),
          ),
        ],
        child: const LoopApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, 'Market'));
    await tester.pumpAndSettle();
    final perpEntry = find.widgetWithText(ActionChip, 'Perp trading · 开发预览');
    await tester.ensureVisible(perpEntry);
    await tester.pumpAndSettle();
    await tester.tap(perpEntry);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ETH-PERP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ETH-PERP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review preview order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to intent review'));
    await tester.pumpAndSettle();

    expect(find.byType(SigningReviewSurface), findsOneWidget);
    expect(find.text('Transaction intent review'), findsOneWidget);
    expect(find.text('Backend execution unavailable'), findsWidgets);
    expect(find.text('1.25'), findsOneWidget);
    expect(find.text('20×'), findsOneWidget);
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
