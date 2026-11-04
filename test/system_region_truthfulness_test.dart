import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production region route stays unknown without a decision', (
    tester,
  ) async {
    await expectProductionUnavailable(
      tester,
      location: '/system/region',
      unavailableKey: 'region-policy-unavailable',
      absentClaims: <String>['部分功能在当前地区不可用', '查看资产', '导出私钥', '查看资格政策'],
    );
  });

  testWidgets('naked region surface never infers a restriction', (
    tester,
  ) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
        onRegionViewAssets: () {},
        onRegionExportKey: () {},
        onRegionSupport: () {},
        onRegionPolicy: () {},
        onSecondaryAction: () {},
      ),
    );
    expect(find.text('Region policy isn\'t open yet'), findsOneWidget);
    expect(
      find.textContaining(
        "doesn't infer your region from device language, SIM or IP",
      ),
      findsOneWidget,
    );
    expect(find.text('Limited in your region'), findsNothing);
    // An unknown region grows no exit: the three only belong to a decision.
    expect(find.text('View assets'), findsNothing);
    expect(find.text('Export private key'), findsNothing);
    expect(find.text('Contact support'), findsNothing);
    expect(find.text('View eligibility policy'), findsNothing);
    expect(find.text('Back to LOOP'), findsOneWidget);
  });

  testWidgets('explicit decision renders only its bounded projection', (
    tester,
  ) async {
    var continues = 0;
    var policy = 0;
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction:
            const LoopFeatureAvailabilityRestriction(
              reasonCode: 'REGION_BLOCKED',
              readOnlyAssetAccess: true,
            ),
        onRegionViewAssets: () => continues += 1,
        onRegionPolicy: () => policy += 1,
        onRetry: () => fail('generic retry must stay isolated from region'),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
      ),
    );
    expect(find.text('Limited in your region'), findsOneWidget);
    // The stamp states the decision, never the server's own code for it.
    expect(find.text('REGION_BLOCKED'), findsNothing);
    expect(find.text('Restricted'), findsOneWidget);
    expect(
      find.textContaining('Assets stay visible read-only'),
      findsOneWidget,
    );
    expect(find.text('Region policy isn\'t open yet'), findsNothing);
    expect(find.text('Back to LOOP'), findsNothing);
    expect(find.textContaining('Spot'), findsNothing);
    await tester.tap(find.text('View assets'));
    await tester.tap(find.text('View eligibility policy'));
    expect((continues, policy), (1, 1));

    await pumpSystemSurface(
      tester,
      const SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction: LoopFeatureAvailabilityRestriction(),
      ),
    );
    expect(find.text('Restricted'), findsOneWidget);
    expect(
      find.textContaining("unconfirmed availability isn't listed"),
      findsOneWidget,
    );
    // Every exit is still on the page, off, with the reason under it.
    expect(find.text('View assets'), findsOneWidget);
    expect(find.text('Export private key'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    expect(
      find.text('The Wallet page can\'t be reached right now.'),
      findsOneWidget,
    );
    expect(find.text('View eligibility policy'), findsNothing);
  });

  testWidgets('region actions appear independently and never generically', (
    tester,
  ) async {
    var assets = 0;
    var exports = 0;
    var supports = 0;
    var policyOpens = 0;
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction:
            const LoopFeatureAvailabilityRestriction(),
        onRegionViewAssets: () => assets += 1,
        onRegionExportKey: () => exports += 1,
        onRegionSupport: () => supports += 1,
      ),
    );
    expect(find.text('View eligibility policy'), findsNothing);
    await tester.tap(find.text('View assets'));
    await tester.tap(find.text('Export private key'));
    await tester.tap(find.text('Contact support'));
    expect((assets, exports, supports), (1, 1, 1));

    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction:
            const LoopFeatureAvailabilityRestriction(),
        onRegionPolicy: () => policyOpens += 1,
      ),
    );
    // An exit with no destination is shown off, and it cannot be invoked.
    expect(
      find.text('The Wallet page can\'t be reached right now.'),
      findsOneWidget,
    );
    await tester.tap(find.text('View assets'));
    expect(assets, 1);
    await tester.ensureVisible(find.text('View eligibility policy'));
    await tester.tap(find.text('View eligibility policy'));
    expect(policyOpens, 1);

    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction:
            const LoopFeatureAvailabilityRestriction(),
        onRetry: () => fail('generic retry must stay isolated from region'),
        onPrimaryAction: () => fail('generic primary must stay isolated'),
        onSecondaryAction: () => fail('generic secondary must stay isolated'),
      ),
    );
    expect(find.text('View eligibility policy'), findsNothing);
    expect(find.text('Back to LOOP'), findsNothing);
  });

  testWidgets('region states remain usable at 2x text', (tester) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction:
            const LoopFeatureAvailabilityRestriction(),
        onRegionViewAssets: () {},
        onRegionPolicy: () {},
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('View eligibility policy'));
    await tester.tap(find.text('View eligibility policy'));
  });
}
