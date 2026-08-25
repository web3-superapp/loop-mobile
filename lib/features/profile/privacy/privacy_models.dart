import 'package:flutter/foundation.dart';

const int privacyMaximumVersion = 2147483647;

/// Sanitized validation failure for data outside the backend Privacy contract.
final class InvalidPrivacyContractException implements Exception {
  const InvalidPrivacyContractException();

  String get code => 'invalid_privacy_contract';

  @override
  String toString() => 'The Privacy contract value is invalid';
}

/// Owner preference only. It never grants copy-trading authorization.
enum CopyTradeVisibility {
  private,
  followers,
  public;

  String get wireValue => switch (this) {
    CopyTradeVisibility.private => 'private',
    CopyTradeVisibility.followers => 'followers',
    CopyTradeVisibility.public => 'public',
  };

  static CopyTradeVisibility fromWire(String value) => switch (value) {
    'private' => CopyTradeVisibility.private,
    'followers' => CopyTradeVisibility.followers,
    'public' => CopyTradeVisibility.public,
    _ => throw const InvalidPrivacyContractException(),
  };
}

@immutable
final class PrivacyValues {
  const PrivacyValues({
    required this.discoverable,
    required this.copyTradeVisibility,
  });

  const PrivacyValues.defaults()
    : discoverable = false,
      copyTradeVisibility = CopyTradeVisibility.private;

  factory PrivacyValues.copyOf(PrivacyValues source) => PrivacyValues(
    discoverable: source.discoverable,
    copyTradeVisibility: source.copyTradeVisibility,
  );

  final bool discoverable;
  final CopyTradeVisibility copyTradeVisibility;

  PrivacyValues withDiscoverable(bool value) => PrivacyValues(
    discoverable: value,
    copyTradeVisibility: copyTradeVisibility,
  );

  PrivacyValues withCopyTradeVisibility(CopyTradeVisibility value) =>
      PrivacyValues(discoverable: discoverable, copyTradeVisibility: value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyValues &&
          other.discoverable == discoverable &&
          other.copyTradeVisibility == copyTradeVisibility;

  @override
  int get hashCode => Object.hash(discoverable, copyTradeVisibility);
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
