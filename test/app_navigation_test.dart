import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/surface_catalog.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/catalog/catalog_surface_screen.dart';
import 'package:loop_mobile/features/review/signing_review_surface.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_fixture_adapter.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_trading_gateway.dart';

void main() {
  testWidgets('navigates the six primary destinations with one shell', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: LoopApp()));
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
    await tester.tap(find.text('Perpetual'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ETH-PERP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ETH-PERP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review preview order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to Privy review'));
    await tester.pumpAndSettle();

    expect(find.byType(SigningReviewSurface), findsOneWidget);
    expect(find.text('Privy signing review'), findsOneWidget);
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

    await tester.pumpWidget(const ProviderScope(child: LoopApp()));
    await tester.pumpAndSettle();

    final payNotice = find.byKey(
      const ValueKey<String>('home-pay-coming-soon'),
    );
    expect(payNotice, findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
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
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
    }
  });
}
