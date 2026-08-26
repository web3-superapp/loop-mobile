import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/surface_catalog.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/catalog/catalog_surface_screen.dart';

void main() {
  test('catalog keeps all 103 product surfaces addressable', () {
    expect(SurfaceCatalog.all, hasLength(103));
    expect(
      SurfaceCatalog.all.map((surface) => surface.id).toSet(),
      hasLength(103),
    );
    expect(
      SurfaceCatalog.all.map((surface) => surface.path).toSet(),
      hasLength(103),
    );
  });

  test(
    'payment priority stays fixed while all payment delivery is deferred',
    () {
      final payments = SurfaceCatalog.all
          .where(
            (surface) =>
                surface.path.startsWith('/pay') || surface.path == '/onramp',
          )
          .toList(growable: false);
      expect(payments.map((surface) => surface.id), <String>[
        'B5',
        'B6',
        'B7',
        'B8',
      ]);
      expect(payments.every((surface) => surface.deferred), isTrue);
      expect(payments.map((surface) => surface.priority), <ProductPriority>[
        ProductPriority.a,
        ProductPriority.b,
        ProductPriority.b,
        ProductPriority.c,
      ]);

      expect(
        SurfaceCatalog.all.where(
          (surface) => surface.priority == ProductPriority.a,
        ),
        hasLength(47),
      );
      expect(
        SurfaceCatalog.all.where(
          (surface) => surface.priority == ProductPriority.b,
        ),
        hasLength(46),
      );
      expect(
        SurfaceCatalog.all.where(
          (surface) => surface.priority == ProductPriority.c,
        ),
        hasLength(10),
      );

      expect(SurfaceCatalog.primaryPaths, <String>[
        '/home',
        '/market',
        '/launchpad',
        '/chat',
        '/wallet',
        '/profile',
      ]);
      expect(SurfaceCatalog.primaryPaths, isNot(contains('/perp')));
      expect(SurfaceCatalog.byPath('/perp').module, SurfaceModule.perp);

      final retainedPerpSurfaces = SurfaceCatalog.all
          .where((surface) => surface.module == SurfaceModule.perp)
          .toList(growable: false);
      expect(
        retainedPerpSurfaces.map((surface) => surface.path).toSet(),
        LoopRouteRegistry.retainedPerpPaths,
      );
      expect(
        retainedPerpSurfaces.every((surface) => surface.retainedHistory),
        isTrue,
      );
      expect(
        SurfaceCatalog.all
            .where((surface) => surface.module != SurfaceModule.perp)
            .every((surface) => !surface.retainedHistory),
        isTrue,
      );
    },
  );

  test('generic catalog pages are reserved for deferred capabilities', () {
    final genericSurfaces = SurfaceCatalog.all.where(
      (surface) => !LoopRouteRegistry.customSurfacePaths.contains(surface.path),
    );

    expect(genericSurfaces, isNotEmpty);
    expect(genericSurfaces.every((surface) => surface.deferred), isTrue);
  });

  test('Wallet catalog describes current delivery truth', () {
    final wallet = <String, AppSurface>{
      for (final surface in SurfaceCatalog.all.where(
        (surface) => surface.module == SurfaceModule.wallet,
      ))
        surface.id: surface,
    };

    expect(wallet, hasLength(20));
    expect(
      wallet['F1']!.description,
      contains('balances and funds actions remain unavailable'),
    );
    expect(wallet['F2']!.description, contains('typed labelled asset fixture'));
    expect(wallet['F6']!.description, contains('no QR code'));
    expect(wallet['F7']!.description, contains('no provider quote'));
    expect(wallet['F11']!.description, contains('local drafts fail closed'));
    expect(
      wallet['F14']!.description,
      contains('first current Privy wallet identity'),
    );
    expect(
      wallet['F15']!.description,
      contains('wallet injection remain disabled'),
    );
    expect(
      wallet['F17']!.description,
      contains('revocation remain unavailable'),
    );
    expect(
      wallet['F19']!.description,
      contains('no provider support or RPC health'),
    );

    const obsoleteClaims = <String>[
      'supported accounts',
      'Holdings, cost basis and activity by chain',
      'Address, QR and network warning',
      'Provider quote, slippage and simulation',
      'Switch, rename and manage wallet capabilities',
      'Wallet-aware browser',
      'Review and revoke token permissions',
      'Enabled chains, testnets and RPC health',
    ];
    expect(
      wallet.values.expand(
        (surface) => obsoleteClaims.where(surface.description.contains),
      ),
      isEmpty,
    );
  });

  testWidgets('inventory keeps retained Perp history out of scope', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: LoopTheme.dark, home: const UiInventoryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Out of scope'), findsNWidgets(12));
    expect(find.text('Perpetuals'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('Perpetuals'),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });
}
