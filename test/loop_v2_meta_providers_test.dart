import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/authenticated_test_privy_gateway.dart';

void main() {
  test('missing backend origin composes no public metadata client', () async {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            privyAppId: '',
            privyAppClientId: '',
            streamApiKey: '',
            backendBaseUrl: '',
            firebaseConfigured: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(loopV2MetaRepositoryProvider), isNull);
    expect(await container.read(loopV2MetaSnapshotProvider.future), isNull);
  });

  test('snapshot starts policy and capabilities reads concurrently', () async {
    final repository = _ControlledRepository();
    final container = ProviderContainer(
      overrides: [loopV2MetaRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final pending = container.read(loopV2MetaSnapshotProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(repository.policyCalls, 1);
    expect(repository.capabilityCalls, 1);
    repository.policyResult.complete(_policy());
    repository.capabilitiesResult.complete(_capabilities());

    final snapshot = await pending;
    expect(
      snapshot?.clientPolicy.versionGate.status,
      LoopV2VersionGateStatus.unavailable,
    );
    expect(
      snapshot?.capabilities[LoopV2CapabilityId.accountSession].evidence.status,
      LoopV2CapabilityEvidenceStatus.pending,
    );
    expect(
      snapshot?.capabilities[LoopV2CapabilityId.community].availability,
      LoopV2CapabilityAvailability.deferred,
    );
  });

  test(
    'snapshot does not automatically retry a failed metadata read',
    () async {
      final repository = _FailingRepository();
      final container = ProviderContainer(
        overrides: [loopV2MetaRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(loopV2MetaSnapshotProvider.future),
        throwsA(isA<StateError>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.policyCalls, 1);
      expect(repository.capabilityCalls, 1);
    },
  );

  testWidgets(
    'LoopApp starts D0 reads and a failure cannot block authenticated UI',
    (tester) async {
      final repository = _FailingRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopV2MetaRepositoryProvider.overrideWithValue(repository),
            privyAuthGatewayProvider.overrideWithValue(
              const AuthenticatedTestPrivyGateway(),
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.policyCalls, 1);
      expect(repository.capabilityCalls, 1);
      expect(
        find.byKey(const ValueKey<String>('community-screen')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unavailable and pending D0 observations cannot bypass authentication',
    (tester) async {
      final repository = _ControlledRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopV2MetaRepositoryProvider.overrideWithValue(repository),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pump();

      expect(repository.policyCalls, 1);
      expect(repository.capabilityCalls, 1);
      repository.policyResult.complete(_policy());
      repository.capabilitiesResult.complete(_capabilities());
      await tester.pumpAndSettle();

      expect(find.text('Welcome to LOOP'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-screen')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

final class _ControlledRepository implements LoopV2MetaRepository {
  final Completer<LoopV2ClientPolicy> policyResult =
      Completer<LoopV2ClientPolicy>();
  final Completer<LoopV2Capabilities> capabilitiesResult =
      Completer<LoopV2Capabilities>();
  int policyCalls = 0;
  int capabilityCalls = 0;

  @override
  Future<LoopV2ClientPolicy> getClientPolicy() {
    policyCalls += 1;
    return policyResult.future;
  }

  @override
  Future<LoopV2Capabilities> getCapabilities() {
    capabilityCalls += 1;
    return capabilitiesResult.future;
  }
}

final class _FailingRepository implements LoopV2MetaRepository {
  int policyCalls = 0;
  int capabilityCalls = 0;

  @override
  Future<LoopV2ClientPolicy> getClientPolicy() async {
    policyCalls += 1;
    throw StateError('policy unavailable');
  }

  @override
  Future<LoopV2Capabilities> getCapabilities() async {
    capabilityCalls += 1;
    return _capabilities();
  }
}

LoopV2ClientPolicy _policy() {
  return LoopV2ClientPolicy(
    contractVersion: '2.0',
    configVersion: DioLoopV2MetaRepository.productConfigVersion,
    effectiveAt: DateTime.utc(2026, DateTime.september),
    defaultRoute: LoopV2PrimaryTab.community,
    navigation: LoopV2Navigation(primaryTabs: LoopV2PrimaryTab.values),
    versionGate: const LoopV2VersionGate(
      status: LoopV2VersionGateStatus.unavailable,
      minimumSupportedVersions: LoopV2MinimumSupportedVersions(),
      forceUpdate: null,
      storeUrls: LoopV2StoreUrls(),
      reasonCode: 'CLIENT_VERSION_POLICY_UNAVAILABLE',
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

LoopV2Capabilities _capabilities() {
  return LoopV2Capabilities(
    contractVersion: '2.0',
    configVersion: DioLoopV2MetaRepository.productConfigVersion,
    effectiveAt: DateTime.utc(2026, DateTime.september),
    capabilities: <LoopV2Capability>[
      for (final id in LoopV2CapabilityId.values)
        LoopV2Capability(
          id: id,
          availability: id == LoopV2CapabilityId.accountSession
              ? LoopV2CapabilityAvailability.available
              : LoopV2CapabilityAvailability.deferred,
          reasonCode: id == LoopV2CapabilityId.accountSession
              ? null
              : 'RUNTIME_DEFERRED',
          evidence: LoopV2CapabilityEvidence(
            status: id == LoopV2CapabilityId.accountSession
                ? LoopV2CapabilityEvidenceStatus.pending
                : LoopV2CapabilityEvidenceStatus.notApplicable,
            reasonCode: id == LoopV2CapabilityId.accountSession
                ? 'PHYSICAL_DEVICE_EVIDENCE_PENDING'
                : null,
          ),
        ),
    ],
  );
}
