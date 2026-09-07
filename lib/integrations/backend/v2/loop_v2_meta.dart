import 'package:flutter/foundation.dart';

enum LoopV2PrimaryTab {
  community('community'),
  mining('mining'),
  launch('launch'),
  market('market'),
  wallet('wallet');

  const LoopV2PrimaryTab(this.wireName);

  final String wireName;

  static LoopV2PrimaryTab? tryParse(String value) {
    for (final tab in values) {
      if (tab.wireName == value) return tab;
    }
    return null;
  }
}

enum LoopV2VersionGateStatus {
  active('active'),
  unavailable('unavailable');

  const LoopV2VersionGateStatus(this.wireName);

  final String wireName;

  static LoopV2VersionGateStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

enum LoopV2RegionGateStatus {
  allowed('allowed'),
  blocked('blocked'),
  unavailable('unavailable');

  const LoopV2RegionGateStatus(this.wireName);

  final String wireName;

  static LoopV2RegionGateStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

enum LoopV2TermsGateStatus {
  accepted('accepted'),
  required('required'),
  unavailable('unavailable');

  const LoopV2TermsGateStatus(this.wireName);

  final String wireName;

  static LoopV2TermsGateStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

@immutable
final class LoopV2ClientPolicy {
  const LoopV2ClientPolicy({
    required this.contractVersion,
    required this.configVersion,
    required this.effectiveAt,
    required this.defaultRoute,
    required this.navigation,
    required this.versionGate,
    required this.regionGate,
    required this.termsGate,
  });

  final String contractVersion;
  final String configVersion;
  final DateTime effectiveAt;
  final LoopV2PrimaryTab defaultRoute;
  final LoopV2Navigation navigation;
  final LoopV2VersionGate versionGate;
  final LoopV2RegionGate regionGate;
  final LoopV2TermsGate termsGate;
}

@immutable
final class LoopV2Navigation {
  LoopV2Navigation({required List<LoopV2PrimaryTab> primaryTabs})
    : primaryTabs = List<LoopV2PrimaryTab>.unmodifiable(primaryTabs);

  final List<LoopV2PrimaryTab> primaryTabs;
}

@immutable
final class LoopV2MinimumSupportedVersions {
  const LoopV2MinimumSupportedVersions({this.ios, this.android});

  final String? ios;
  final String? android;
}

@immutable
final class LoopV2StoreUrls {
  const LoopV2StoreUrls({this.ios, this.android});

  final Uri? ios;
  final Uri? android;
}

@immutable
final class LoopV2VersionGate {
  const LoopV2VersionGate({
    required this.status,
    required this.minimumSupportedVersions,
    required this.forceUpdate,
    required this.storeUrls,
    required this.reasonCode,
  });

  final LoopV2VersionGateStatus status;
  final LoopV2MinimumSupportedVersions minimumSupportedVersions;
  final bool? forceUpdate;
  final LoopV2StoreUrls storeUrls;
  final String? reasonCode;
}

@immutable
final class LoopV2RegionGate {
  const LoopV2RegionGate({
    required this.status,
    required this.reasonCode,
    required this.supportUrl,
    required this.readOnlyAssetAccess,
  });

  final LoopV2RegionGateStatus status;
  final String? reasonCode;
  final Uri? supportUrl;
  final bool? readOnlyAssetAccess;
}

@immutable
final class LoopV2TermsGate {
  const LoopV2TermsGate({
    required this.status,
    required this.requiredVersion,
    required this.reasonCode,
  });

  final LoopV2TermsGateStatus status;
  final String? requiredVersion;
  final String? reasonCode;
}

enum LoopV2CapabilityId {
  privyAuthentication('privyAuthentication'),
  accountSession('accountSession'),
  streamChatToken('streamChatToken'),
  streamVideoToken('streamVideoToken'),
  community('community'),
  bscRead('bscRead'),
  walletRead('walletRead'),
  privySwap('privySwap'),
  sendApprovals('sendApprovals'),
  launch('launch'),
  mining('mining'),
  pushNotifications('pushNotifications'),
  pay('pay'),
  bridge('bridge'),
  dappExecution('dappExecution'),
  communityAi('communityAi');

  const LoopV2CapabilityId(this.wireName);

  final String wireName;

  static LoopV2CapabilityId? tryParse(String value) {
    for (final id in values) {
      if (id.wireName == value) return id;
    }
    return null;
  }
}

enum LoopV2CapabilityAvailability {
  available('available'),
  deferred('deferred'),
  unavailable('unavailable');

  const LoopV2CapabilityAvailability(this.wireName);

  final String wireName;

  static LoopV2CapabilityAvailability? tryParse(String value) {
    for (final availability in values) {
      if (availability.wireName == value) return availability;
    }
    return null;
  }
}

enum LoopV2CapabilityEvidenceStatus {
  notApplicable('notApplicable'),
  pending('pending');

  const LoopV2CapabilityEvidenceStatus(this.wireName);

  final String wireName;

  static LoopV2CapabilityEvidenceStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

@immutable
final class LoopV2CapabilityEvidence {
  const LoopV2CapabilityEvidence({
    required this.status,
    required this.reasonCode,
  });

  final LoopV2CapabilityEvidenceStatus status;
  final String? reasonCode;
}

@immutable
final class LoopV2Capability {
  const LoopV2Capability({
    required this.id,
    required this.availability,
    required this.reasonCode,
    required this.evidence,
  });

  final LoopV2CapabilityId id;
  final LoopV2CapabilityAvailability availability;
  final String? reasonCode;
  final LoopV2CapabilityEvidence evidence;
}

@immutable
final class LoopV2Capabilities {
  LoopV2Capabilities({
    required this.contractVersion,
    required this.configVersion,
    required this.effectiveAt,
    required List<LoopV2Capability> capabilities,
  }) : capabilities = List<LoopV2Capability>.unmodifiable(capabilities),
       _byId = Map<LoopV2CapabilityId, LoopV2Capability>.unmodifiable(
         <LoopV2CapabilityId, LoopV2Capability>{
           for (final capability in capabilities) capability.id: capability,
         },
       );

  final String contractVersion;
  final String configVersion;
  final DateTime effectiveAt;
  final List<LoopV2Capability> capabilities;
  final Map<LoopV2CapabilityId, LoopV2Capability> _byId;

  LoopV2Capability operator [](LoopV2CapabilityId id) => _byId[id]!;
}

/// One immutable observation of both public D0 metadata resources.
///
/// The snapshot intentionally exposes policy and capability states without an
/// `enabled` or `allowed` projection. Product gates remain responsible for
/// their own stricter reviewed decisions.
@immutable
final class LoopV2MetaSnapshot {
  const LoopV2MetaSnapshot({
    required this.clientPolicy,
    required this.capabilities,
  });

  final LoopV2ClientPolicy clientPolicy;
  final LoopV2Capabilities capabilities;
}
