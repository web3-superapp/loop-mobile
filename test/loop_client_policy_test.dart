import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/policy/loop_client_policy.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

void main() {
  LoopV2ClientPolicy policy({
    LoopV2VersionGate? versionGate,
    LoopV2RegionGate? regionGate,
  }) {
    return LoopV2ClientPolicy(
      contractVersion: '2.0',
      configVersion: 'productPolicyV2.2026-09-07',
      effectiveAt: DateTime.utc(2026, 9, 7, 8),
      defaultRoute: LoopV2PrimaryTab.community,
      navigation: LoopV2Navigation(primaryTabs: LoopV2PrimaryTab.values),
      versionGate:
          versionGate ??
          const LoopV2VersionGate.unavailable(
            reasonCode: 'CLIENT_VERSION_POLICY_UNAVAILABLE',
          ),
      regionGate:
          regionGate ??
          const LoopV2RegionGate(
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

  final available = LoopV2VersionGate(
    status: LoopV2VersionGateStatus.available,
    minimumSupportedVersions: const LoopV2PlatformVersions(
      ios: '1.4.0',
      android: '1.3.2',
    ),
    forceUpdateBelow: const LoopV2PlatformVersions(
      ios: '1.2.0',
      android: '1.3.2',
    ),
    storeUrls: LoopV2StoreUrls(
      ios: Uri.parse('https://apps.apple.com/app/loop'),
      android: Uri.parse('https://play.google.com/store/apps/details?id=x'),
    ),
    reasonCode: null,
  );

  test('two floors: required below the hard floor, recommended between', () {
    LoopVersionPolicyDecision decide(TargetPlatform platform, String version) {
      return LoopClientPolicyProjection.version(
        policy(versionGate: available),
        platform: platform,
        clientVersion: version,
      ).decision;
    }

    expect(
      decide(TargetPlatform.iOS, '1.1.9'),
      LoopVersionPolicyDecision.updateRequired,
    );
    expect(
      decide(TargetPlatform.iOS, '1.2.0'),
      LoopVersionPolicyDecision.updateRecommended,
    );
    expect(
      decide(TargetPlatform.iOS, '1.3.9+42'),
      LoopVersionPolicyDecision.updateRecommended,
    );
    expect(
      decide(TargetPlatform.iOS, '1.4.0'),
      LoopVersionPolicyDecision.supported,
    );
    expect(
      decide(TargetPlatform.iOS, '1.4.0-beta.1'),
      LoopVersionPolicyDecision.updateRecommended,
      reason: 'pre-release sorts before the release',
    );
    // Android: both floors equal, so the minimum alone is a hard block.
    expect(
      decide(TargetPlatform.android, '1.3.1'),
      LoopVersionPolicyDecision.updateRequired,
    );
    expect(
      decide(TargetPlatform.android, '1.3.2'),
      LoopVersionPolicyDecision.supported,
    );
    expect(
      decide(TargetPlatform.macOS, '0.0.1'),
      LoopVersionPolicyDecision.unknown,
    );
    expect(
      decide(TargetPlatform.iOS, 'not-a-version'),
      LoopVersionPolicyDecision.unknown,
    );

    final projection = LoopClientPolicyProjection.version(
      policy(versionGate: available),
      platform: TargetPlatform.iOS,
      clientVersion: '1.0.0',
    );
    expect(projection.minimumVersion, '1.4.0');
    expect(projection.forceUpdateBelow, '1.2.0');
    expect(projection.storeUrl, Uri.parse('https://apps.apple.com/app/loop'));
    expect(projection.configVersion, 'productPolicyV2.2026-09-07');
  });

  test('unavailable or absent policy never blocks', () {
    expect(
      LoopClientPolicyProjection.version(
        policy(),
        platform: TargetPlatform.iOS,
        clientVersion: '0.0.1',
      ).decision,
      LoopVersionPolicyDecision.unknown,
    );
    expect(
      LoopClientPolicyProjection.version(
        null,
        platform: TargetPlatform.android,
        clientVersion: '0.0.1',
      ).decision,
      LoopVersionPolicyDecision.unknown,
    );
    expect(
      LoopClientPolicyProjection.region(policy()).decision,
      LoopRegionPolicyDecision.unknown,
    );
    expect(
      LoopClientPolicyProjection.region(null).decision,
      LoopRegionPolicyDecision.unknown,
    );
  });

  test('region projection carries only the asserted gate facts', () {
    final blocked = LoopClientPolicyProjection.region(
      policy(
        regionGate: LoopV2RegionGate(
          status: LoopV2RegionGateStatus.blocked,
          reasonCode: 'REGION_BLOCKED',
          supportUrl: Uri.parse('https://quant-dinger.cc/support'),
          readOnlyAssetAccess: true,
        ),
      ),
    );
    expect(blocked.decision, LoopRegionPolicyDecision.blocked);
    expect(blocked.reasonCode, 'REGION_BLOCKED');
    expect(blocked.readOnlyAssetAccess, isTrue);
    expect(blocked.supportUrl, Uri.parse('https://quant-dinger.cc/support'));
    expect(blocked.effectiveAt, DateTime.utc(2026, 9, 7, 8));
  });

  test('semver ordering follows SemVer 2.0 precedence', () {
    LoopSemver v(String value) => LoopSemver.tryParse(value)!;
    expect(v('1.0.0') < v('1.0.1'), isTrue);
    expect(v('1.0.0-alpha') < v('1.0.0'), isTrue);
    expect(v('1.0.0-alpha') < v('1.0.0-alpha.1'), isTrue);
    expect(v('1.0.0-alpha.1') < v('1.0.0-alpha.beta'), isTrue);
    expect(v('1.0.0-beta.2') < v('1.0.0-beta.11'), isTrue);
    expect(v('1.0.0-rc.1') < v('1.0.0'), isTrue);
    expect(v('1.0.0+build.1').compareTo(v('1.0.0')), 0);
    expect(LoopSemver.tryParse('01.0.0'), isNull);
    expect(LoopSemver.tryParse('1.0'), isNull);
  });
}
