import 'package:flutter/foundation.dart';

const int profileMaximumVersion = 2147483647;

final RegExp _profileAvatarReferencePattern = RegExp(
  r'^avatar:[A-Za-z0-9][A-Za-z0-9._/-]{0,126}$',
);

/// Sanitized validation failure for data outside the backend Profile contract.
///
/// Rejected user input is deliberately never included in this exception.
final class InvalidProfileContractException implements Exception {
  const InvalidProfileContractException();

  String get code => 'invalid_profile_contract';

  @override
  String toString() => 'The Profile contract value is invalid';
}

@immutable
final class ProfileValues {
  factory ProfileValues({required String? alias, required String? avatarRef}) {
    final normalizedAlias = _normalizeProfileAlias(alias);
    if (avatarRef != null &&
        !_profileAvatarReferencePattern.hasMatch(avatarRef)) {
      throw const InvalidProfileContractException();
    }
    return ProfileValues._(normalizedAlias, avatarRef);
  }

  const ProfileValues._(this.alias, this.avatarRef);

  factory ProfileValues.empty() => ProfileValues(alias: null, avatarRef: null);

  factory ProfileValues.copyOf(ProfileValues source) =>
      ProfileValues(alias: source.alias, avatarRef: source.avatarRef);

  final String? alias;
  final String? avatarRef;

  /// Returns a validated value with an explicitly replaced nullable alias.
  ProfileValues withAlias(String? alias) =>
      ProfileValues(alias: alias, avatarRef: avatarRef);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileValues &&
          other.alias == alias &&
          other.avatarRef == avatarRef;

  @override
  int get hashCode => Object.hash(alias, avatarRef);
}

@immutable
final class ProfileResource {
  factory ProfileResource({
    required int version,
    required ProfileValues values,
    required DateTime? updatedAt,
  }) {
    if (version < 0 ||
        version > profileMaximumVersion ||
        ((version == 0) != (updatedAt == null))) {
      throw const InvalidProfileContractException();
    }
    return ProfileResource._(
      version,
      ProfileValues.copyOf(values),
      updatedAt?.toUtc(),
    );
  }

  const ProfileResource._(this.version, this.values, this.updatedAt);

  factory ProfileResource.empty() => ProfileResource(
    version: 0,
    values: ProfileValues.empty(),
    updatedAt: null,
  );

  factory ProfileResource.copyOf(ProfileResource source) => ProfileResource(
    version: source.version,
    values: source.values,
    updatedAt: source.updatedAt,
  );

  final int version;
  final ProfileValues values;
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileResource &&
          other.version == version &&
          other.values == values &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(version, values, updatedAt);
}

String? _normalizeProfileAlias(String? value) {
  if (value == null) return null;
  if (value.length > 256 || _containsForbiddenAliasCodePoint(value)) {
    throw const InvalidProfileContractException();
  }

  final normalized = value.trim();
  final codePointLength = normalized.runes.length;
  if (codePointLength < 1 || codePointLength > 40) {
    throw const InvalidProfileContractException();
  }
  return normalized;
}

bool _containsForbiddenAliasCodePoint(String value) {
  final codeUnits = value.codeUnits;
  for (var index = 0; index < codeUnits.length; index++) {
    final unit = codeUnits[index];
    int codePoint;
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      if (index + 1 >= codeUnits.length) return true;
      final low = codeUnits[index + 1];
      if (low < 0xDC00 || low > 0xDFFF) return true;
      codePoint = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
      index += 1;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return true;
    } else {
      codePoint = unit;
    }

    if ((codePoint >= 0x0000 && codePoint <= 0x001F) ||
        (codePoint >= 0x007F && codePoint <= 0x009F) ||
        codePoint == 0x061C ||
        codePoint == 0x200E ||
        codePoint == 0x200F ||
        (codePoint >= 0x202A && codePoint <= 0x202E) ||
        (codePoint >= 0x2066 && codePoint <= 0x2069)) {
      return true;
    }
  }
  return false;
}
