import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/navigation/surface_catalog.dart';

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
    },
  );

  test('generic catalog pages are reserved for deferred capabilities', () {
    final genericSurfaces = SurfaceCatalog.all.where(
      (surface) => !LoopRouteRegistry.customSurfacePaths.contains(surface.path),
    );

    expect(genericSurfaces, isNotEmpty);
    expect(genericSurfaces.every((surface) => surface.deferred), isTrue);
  });
}
