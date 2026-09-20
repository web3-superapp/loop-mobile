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
    expect(find.text('地区策略还没有开放'), findsOneWidget);
    expect(find.textContaining('不会从设备语言、SIM 或 IP 推断'), findsOneWidget);
    expect(find.text('部分功能在当前地区不可用'), findsNothing);
    // An unknown region grows no exit: the three only belong to a decision.
    expect(find.text('查看资产'), findsNothing);
    expect(find.text('导出私钥'), findsNothing);
    expect(find.text('联系客服'), findsNothing);
    expect(find.text('查看资格政策'), findsNothing);
    expect(find.text('返回 LOOP'), findsOneWidget);
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
    expect(find.text('部分功能在当前地区不可用'), findsOneWidget);
    // The stamp states the decision, never the server's own code for it.
    expect(find.text('REGION_BLOCKED'), findsNothing);
    expect(find.text('RESTRICTED'), findsOneWidget);
    expect(find.textContaining('资产保持只读可见'), findsOneWidget);
    expect(find.text('地区策略还没有开放'), findsNothing);
    expect(find.text('返回 LOOP'), findsNothing);
    expect(find.textContaining('Spot'), findsNothing);
    await tester.tap(find.text('查看资产'));
    await tester.tap(find.text('查看资格政策'));
    expect((continues, policy), (1, 1));

    await pumpSystemSurface(
      tester,
      const SystemSurfaceScreen.fromId(
        'region-restricted',
        featureAvailabilityRestriction: LoopFeatureAvailabilityRestriction(),
      ),
    );
    expect(find.text('RESTRICTED'), findsOneWidget);
    expect(find.textContaining('不列出未确认的可用范围'), findsOneWidget);
    // Every exit is still on the page, off, with the reason under it.
    expect(find.text('查看资产'), findsOneWidget);
    expect(find.text('导出私钥'), findsOneWidget);
    expect(find.text('联系客服'), findsOneWidget);
    expect(find.text('钱包页当前不可达。'), findsOneWidget);
    expect(find.text('查看资格政策'), findsNothing);
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
    expect(find.text('查看资格政策'), findsNothing);
    await tester.tap(find.text('查看资产'));
    await tester.tap(find.text('导出私钥'));
    await tester.tap(find.text('联系客服'));
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
    expect(find.text('钱包页当前不可达。'), findsOneWidget);
    await tester.tap(find.text('查看资产'));
    expect(assets, 1);
    await tester.tap(find.text('查看资格政策'));
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
    expect(find.text('查看资格政策'), findsNothing);
    expect(find.text('返回 LOOP'), findsNothing);
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
    await tester.ensureVisible(find.text('查看资格政策'));
    await tester.tap(find.text('查看资格政策'));
  });
}
