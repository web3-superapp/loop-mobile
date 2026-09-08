import 'package:flutter/foundation.dart';

const int privacyMaximumVersion = 2147483647;

/// Sanitized validation failure for data outside the backend Privacy contract.
final class InvalidPrivacyContractException implements Exception {
  const InvalidPrivacyContractException();

  String get code => 'invalid_privacy_contract';

  @override
  String toString() => 'The Privacy contract value is invalid';
}

/// Display preference only. It never grants an authorization, proves a social
/// relationship, or shares a holding.
enum PrivacyAudience {
  self('self'),
  everyone('everyone');

  const PrivacyAudience(this.wireValue);

  final String wireValue;

  static PrivacyAudience fromWire(String value) {
    for (final audience in values) {
      if (audience.wireValue == value) return audience;
    }
    throw const InvalidPrivacyContractException();
  }
}

/// The four V2 visibility facets. Copy-trade visibility is deliberately absent:
/// copytrade is retired and must not return.
enum PrivacyVisibilityFacet {
  totalAssets('totalAssets', '总资产'),
  miningPower('miningPower', '挖矿算力'),
  communities('communities', '加入的社区'),
  tradeHistory('tradeHistory', '交易记录');

  const PrivacyVisibilityFacet(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

@immutable
final class PrivacyVisibility {
  factory PrivacyVisibility({
    PrivacyAudience totalAssets = PrivacyAudience.self,
    PrivacyAudience miningPower = PrivacyAudience.self,
    PrivacyAudience communities = PrivacyAudience.self,
    PrivacyAudience tradeHistory = PrivacyAudience.self,
  }) =>
      PrivacyVisibility._(totalAssets, miningPower, communities, tradeHistory);

  const PrivacyVisibility._(
    this.totalAssets,
    this.miningPower,
    this.communities,
    this.tradeHistory,
  );

  /// Fail-closed default: nothing is visible to anyone but the owner.
  const PrivacyVisibility.defaults()
    : totalAssets = PrivacyAudience.self,
      miningPower = PrivacyAudience.self,
      communities = PrivacyAudience.self,
      tradeHistory = PrivacyAudience.self;

  final PrivacyAudience totalAssets;
  final PrivacyAudience miningPower;
  final PrivacyAudience communities;
  final PrivacyAudience tradeHistory;

  PrivacyAudience operator [](PrivacyVisibilityFacet facet) => switch (facet) {
    PrivacyVisibilityFacet.totalAssets => totalAssets,
    PrivacyVisibilityFacet.miningPower => miningPower,
    PrivacyVisibilityFacet.communities => communities,
    PrivacyVisibilityFacet.tradeHistory => tradeHistory,
  };

  PrivacyVisibility withFacet(
    PrivacyVisibilityFacet facet,
    PrivacyAudience audience,
  ) => PrivacyVisibility(
    totalAssets: facet == PrivacyVisibilityFacet.totalAssets
        ? audience
        : totalAssets,
    miningPower: facet == PrivacyVisibilityFacet.miningPower
        ? audience
        : miningPower,
    communities: facet == PrivacyVisibilityFacet.communities
        ? audience
        : communities,
    tradeHistory: facet == PrivacyVisibilityFacet.tradeHistory
        ? audience
        : tradeHistory,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyVisibility &&
          other.totalAssets == totalAssets &&
          other.miningPower == miningPower &&
          other.communities == communities &&
          other.tradeHistory == tradeHistory;

  @override
  int get hashCode =>
      Object.hash(totalAssets, miningPower, communities, tradeHistory);
}

@immutable
final class PrivacyValues {
  const PrivacyValues({
    required this.discoverable,
    required this.anonymousMode,
    this.visibility = const PrivacyVisibility.defaults(),
  });

  const PrivacyValues.defaults()
    : discoverable = false,
      anonymousMode = false,
      visibility = const PrivacyVisibility.defaults();

  factory PrivacyValues.copyOf(PrivacyValues source) => PrivacyValues(
    discoverable: source.discoverable,
    anonymousMode: source.anonymousMode,
    visibility: source.visibility,
  );

  /// Shows the LOOP ID and allows the owner to be found by search.
  final bool discoverable;

  /// Shows the alias only; the wallet address is never displayed.
  final bool anonymousMode;

  final PrivacyVisibility visibility;

  PrivacyValues withDiscoverable(bool value) => PrivacyValues(
    discoverable: value,
    anonymousMode: anonymousMode,
    visibility: visibility,
  );

  PrivacyValues withAnonymousMode(bool value) => PrivacyValues(
    discoverable: discoverable,
    anonymousMode: value,
    visibility: visibility,
  );

  PrivacyValues withVisibility(PrivacyVisibility value) => PrivacyValues(
    discoverable: discoverable,
    anonymousMode: anonymousMode,
    visibility: value,
  );

  PrivacyValues withFacet(
    PrivacyVisibilityFacet facet,
    PrivacyAudience audience,
  ) => withVisibility(visibility.withFacet(facet, audience));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyValues &&
          other.discoverable == discoverable &&
          other.anonymousMode == anonymousMode &&
          other.visibility == visibility;

  @override
  int get hashCode => Object.hash(discoverable, anonymousMode, visibility);
}

@immutable
final class PrivacyResource {
  factory PrivacyResource({
    required int version,
    required PrivacyValues values,
    required DateTime? updatedAt,
  }) {
    if (version < 0 ||
        version > privacyMaximumVersion ||
        ((version == 0) != (updatedAt == null))) {
      throw const InvalidPrivacyContractException();
    }
    return PrivacyResource._(
      version,
      PrivacyValues.copyOf(values),
      updatedAt?.toUtc(),
    );
  }

  const PrivacyResource._(this.version, this.values, this.updatedAt);

  factory PrivacyResource.empty() => PrivacyResource(
    version: 0,
    values: const PrivacyValues.defaults(),
    updatedAt: null,
  );

  factory PrivacyResource.copyOf(PrivacyResource source) => PrivacyResource(
    version: source.version,
    values: source.values,
    updatedAt: source.updatedAt,
  );

  final int version;
  final PrivacyValues values;
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyResource &&
          other.version == version &&
          other.values == values &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(version, values, updatedAt);
}
