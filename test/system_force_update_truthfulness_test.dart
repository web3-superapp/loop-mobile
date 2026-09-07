import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';

import 'support/system_surface_harness.dart';

void main() {
  testWidgets('production force-update route stays unknown without a policy', (
    tester,
  ) async {
    await expectProductionUnavailable(
      tester,
      location: '/system/update',
      unavailableKey: 'update-policy-unavailable',
      absentClaims: <String>['请更新 LOOP 后继续', '立即更新', '不可跳过'],
    );
  });

  testWidgets('production route blocks only when the D0 policy requires it', (
    tester,
  ) async {
    final router = await pumpProductionApp(
      tester,
      overrides: [
        appConfigProvider.overrideWithValue(_clientConfig),
        loopV2MetaRepositoryProvider.overrideWithValue(
          _PolicyRepository(_availableGate(floor: '9.0.0', minimum: '9.5.0')),
        ),
      ],
    );
    router.go('/system/update');
    await tester.pumpAndSettle();

    expect(find.text('请更新 LOOP 后继续'), findsOneWidget);
    expect(find.text('9.0.0'), findsOneWidget);
    expect(find.text('productPolicyV2.2026-09-07'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('system-state-blocking')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('loop-topbar-back')),
      findsNothing,
    );
    expect(find.text('返回 LOOP'), findsNothing);
    // No reviewed store action is wired yet: the page says so, no button.
    expect(
      find.byKey(const ValueKey<String>('force-update-store-unavailable')),
      findsOneWidget,
    );
    expect(find.text('立即更新'), findsNothing);
  });

  testWidgets('a supported client is never blocked by an available policy', (
    tester,
  ) async {
    final router = await pumpProductionApp(
      tester,
      overrides: [
        appConfigProvider.overrideWithValue(_clientConfig),
        loopV2MetaRepositoryProvider.overrideWithValue(
          _PolicyRepository(_availableGate(floor: '0.0.1', minimum: '0.0.2')),
        ),
      ],
    );
    router.go('/system/update');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('update-policy-unavailable')),
      findsOneWidget,
    );
    expect(find.text('请更新 LOOP 后继续'), findsNothing);
  });

  testWidgets('explicit requirement blocks and invokes only its action', (
    tester,
  ) async {
    var updates = 0;
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'force-update',
        forceUpdateRequirement: const LoopForceUpdateRequirement(
          minimumVersion: '1.2.0',
        ),
        onForceUpdate: () => updates += 1,
        onSecondaryAction: () {},
      ),
    );
    expect(find.text('请更新 LOOP 后继续'), findsOneWidget);
    expect(find.text('REQUIRED'), findsOneWidget);
    expect(find.text('1.2.0'), findsOneWidget);
    expect(find.text('返回 LOOP'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('system-state-blocking')),
      findsOneWidget,
    );
    await tester.tap(find.text('立即更新'));
    expect(updates, 1);
  });

  testWidgets('force-update dialog requires the same explicit evidence', (
    tester,
  ) async {
    var updates = 0;
    await pumpSystemSurface(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showLoopForceUpdateDialog(
              context,
              requirement: const LoopForceUpdateRequirement(
                minimumVersion: '2.0.0',
              ),
              onUpdate: () => updates += 1,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('请更新 LOOP 后继续'), findsOneWidget);
    expect(find.textContaining('最低 2.0.0'), findsOneWidget);
    await tester.tap(find.text('立即更新'));
    expect(updates, 1);
  });

  testWidgets('force-update states remain usable at 2x text', (tester) async {
    await pumpSystemSurface(
      tester,
      SystemSurfaceScreen.fromId(
        'force-update',
        forceUpdateRequirement: const LoopForceUpdateRequirement(),
        onForceUpdate: () {},
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('立即更新'));
  });
}

const _clientConfig = AppConfig(
  privyAppId: '',
  privyAppClientId: '',
  streamApiKey: '',
  backendBaseUrl: '',
  firebaseConfigured: false,
  loopClientVersion: '1.0.0',
);

LoopV2ClientPolicy _availableGate({
  required String floor,
  required String minimum,
}) {
  return LoopV2ClientPolicy(
    contractVersion: '2.0',
    configVersion: 'productPolicyV2.2026-09-07',
    effectiveAt: DateTime.utc(2026, 9, 7),
    defaultRoute: LoopV2PrimaryTab.community,
    navigation: LoopV2Navigation(primaryTabs: LoopV2PrimaryTab.values),
    versionGate: LoopV2VersionGate(
      status: LoopV2VersionGateStatus.available,
      minimumSupportedVersions: LoopV2PlatformVersions(
        ios: minimum,
        android: minimum,
      ),
      forceUpdateBelow: LoopV2PlatformVersions(ios: floor, android: floor),
      storeUrls: LoopV2StoreUrls(
        ios: Uri.parse('https://apps.apple.com/app/loop'),
        android: Uri.parse('https://play.google.com/store/apps/details?id=x'),
      ),
      reasonCode: null,
    ),
    regionGate: const LoopV2RegionGate(
      status: LoopV2RegionGateStatus.unavailable,
      reasonCode: 'REGION_POLICY_UNAVAILABLE',
      supportUrl: null,
      readOnlyAssetAccess: null,
    ),
    termsGate: const LoopV2TermsGate(
      status: LoopV2TermsGateStatus.unavailable,
      requiredVersion: null,
      reasonCode: 'TERMS_POLICY_UNAVAILABLE',
    ),
  );
}

final class _PolicyRepository implements LoopV2MetaRepository {
  const _PolicyRepository(this.policy);

  final LoopV2ClientPolicy policy;

  @override
  Future<LoopV2ClientPolicy> getClientPolicy() async => policy;

  @override
  Future<LoopV2Capabilities> getCapabilities() async {
    return LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: policy.configVersion,
      effectiveAt: policy.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final id in LoopV2CapabilityId.values)
          LoopV2Capability(
            id: id,
            availability: LoopV2CapabilityAvailability.deferred,
            reasonCode: 'RUNTIME_DEFERRED',
            evidence: const LoopV2CapabilityEvidence(
              status: LoopV2CapabilityEvidenceStatus.notApplicable,
              reasonCode: null,
            ),
          ),
      ],
    );
  }
}
