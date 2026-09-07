import 'package:flutter/foundation.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

/// Pure projection of the D0 client policy onto the two system pages that
/// consume it (`force-update`, `region-blocked`). No provider, no I/O.
///
/// Decision 0029: two floors. Below `forceUpdateBelow[platform]` the client
/// must update; at or above it but below `minimumSupportedVersions[platform]`
/// the client sees a dismissible prompt. An `unavailable` gate, an unknown
/// platform or an unparsable client version never blocks (fail closed means
/// "unknown", not "blocked", for a policy that was never asserted).
enum LoopVersionPolicyDecision {
  unknown,
  supported,
  updateRecommended,
  updateRequired,
}

@immutable
final class LoopVersionPolicyProjection {
  const LoopVersionPolicyProjection({
    required this.decision,
    required this.configVersion,
    required this.effectiveAt,
    this.minimumVersion,
    this.forceUpdateBelow,
    this.storeUrl,
  });

  const LoopVersionPolicyProjection.unknown()
    : decision = LoopVersionPolicyDecision.unknown,
      configVersion = null,
      effectiveAt = null,
      minimumVersion = null,
      forceUpdateBelow = null,
      storeUrl = null;

  final LoopVersionPolicyDecision decision;
  final String? configVersion;
  final DateTime? effectiveAt;
  final String? minimumVersion;
  final String? forceUpdateBelow;
  final Uri? storeUrl;
}

enum LoopRegionPolicyDecision { unknown, allowed, blocked }

@immutable
final class LoopRegionPolicyProjection {
  const LoopRegionPolicyProjection({
    required this.decision,
    this.reasonCode,
    this.supportUrl,
    this.readOnlyAssetAccess,
    this.configVersion,
    this.effectiveAt,
  });

  const LoopRegionPolicyProjection.unknown()
    : decision = LoopRegionPolicyDecision.unknown,
      reasonCode = null,
      supportUrl = null,
      readOnlyAssetAccess = null,
      configVersion = null,
      effectiveAt = null;

  final LoopRegionPolicyDecision decision;
  final String? reasonCode;
  final Uri? supportUrl;
  final bool? readOnlyAssetAccess;
  final String? configVersion;
  final DateTime? effectiveAt;
}

abstract final class LoopClientPolicyProjection {
  static LoopVersionPolicyProjection version(
    LoopV2ClientPolicy? policy, {
    required TargetPlatform platform,
    required String clientVersion,
  }) {
    if (policy == null) return const LoopVersionPolicyProjection.unknown();
    final gate = policy.versionGate;
    if (!gate.isAvailable) return const LoopVersionPolicyProjection.unknown();
    final (minimum, floor, storeUrl) = switch (platform) {
      TargetPlatform.iOS => (
        gate.minimumSupportedVersions.ios,
        gate.forceUpdateBelow?.ios,
        gate.storeUrls.ios,
      ),
      TargetPlatform.android => (
        gate.minimumSupportedVersions.android,
        gate.forceUpdateBelow?.android,
        gate.storeUrls.android,
      ),
      _ => (null, null, null),
    };
    final client = LoopSemver.tryParse(clientVersion);
    final minimumSemver = minimum == null ? null : LoopSemver.tryParse(minimum);
    final floorSemver = floor == null ? null : LoopSemver.tryParse(floor);
    if (client == null || minimumSemver == null || floorSemver == null) {
      return const LoopVersionPolicyProjection.unknown();
    }
    final decision = client < floorSemver
        ? LoopVersionPolicyDecision.updateRequired
        : client < minimumSemver
        ? LoopVersionPolicyDecision.updateRecommended
        : LoopVersionPolicyDecision.supported;
    return LoopVersionPolicyProjection(
      decision: decision,
      configVersion: policy.configVersion,
      effectiveAt: policy.effectiveAt,
      minimumVersion: minimum,
      forceUpdateBelow: floor,
      storeUrl: storeUrl,
    );
  }

  static LoopRegionPolicyProjection region(LoopV2ClientPolicy? policy) {
    if (policy == null) return const LoopRegionPolicyProjection.unknown();
    final gate = policy.regionGate;
    final decision = switch (gate.status) {
      LoopV2RegionGateStatus.allowed => LoopRegionPolicyDecision.allowed,
      LoopV2RegionGateStatus.blocked => LoopRegionPolicyDecision.blocked,
      LoopV2RegionGateStatus.unavailable => LoopRegionPolicyDecision.unknown,
    };
    if (decision == LoopRegionPolicyDecision.unknown) {
      return const LoopRegionPolicyProjection.unknown();
    }
    return LoopRegionPolicyProjection(
      decision: decision,
      reasonCode: gate.reasonCode,
      supportUrl: gate.supportUrl,
      readOnlyAssetAccess: gate.readOnlyAssetAccess,
      configVersion: policy.configVersion,
      effectiveAt: policy.effectiveAt,
    );
  }
}

/// Minimal SemVer 2.0 comparison: numeric core, then pre-release precedence;
/// build metadata is ignored.
@immutable
final class LoopSemver implements Comparable<LoopSemver> {
  const LoopSemver(this.major, this.minor, this.patch, this.preRelease);

  static final RegExp _pattern = RegExp(
    r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-((?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*))?'
    r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  final int major;
  final int minor;
  final int patch;
  final List<String> preRelease;

  static LoopSemver? tryParse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) return null;
    return LoopSemver(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      match.group(4)?.split('.') ?? const <String>[],
    );
  }

  bool operator <(LoopSemver other) => compareTo(other) < 0;

  @override
  int compareTo(LoopSemver other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (preRelease.isEmpty && other.preRelease.isEmpty) return 0;
    if (preRelease.isEmpty) return 1;
    if (other.preRelease.isEmpty) return -1;
    final length = preRelease.length < other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var index = 0; index < length; index++) {
      final a = preRelease[index];
      final b = other.preRelease[index];
      final aNumber = int.tryParse(a);
      final bNumber = int.tryParse(b);
      final result = aNumber != null && bNumber != null
          ? aNumber.compareTo(bNumber)
          : aNumber != null
          ? -1
          : bNumber != null
          ? 1
          : a.compareTo(b);
      if (result != 0) return result;
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }
}
