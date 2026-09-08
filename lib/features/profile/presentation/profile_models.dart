import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/text/loop_human_text.dart';

const int profileMaximumVersion = 2147483647;

/// Maximum number of followed tracks accepted by the V2 contract.
const int profileMaximumInterests = 6;

/// Maximum bio length in code points after trimming.
const int profileMaximumBioCodePoints = 160;

final RegExp _profileAvatarReferencePattern = RegExp(
  r'^avatar:[A-Za-z0-9][A-Za-z0-9._/-]{0,126}$',
);

/// Server-generated, immutable, non-enumerable public identifier.
final RegExp profileLoopIdPattern = RegExp(r'^LOOP-[0-9A-HJKMNP-TV-Z]{8}$');

/// Sanitized validation failure for data outside the backend Profile contract.
///
/// Rejected user input is deliberately never included in this exception.
final class InvalidProfileContractException implements Exception {
  const InvalidProfileContractException();

  String get code => 'invalid_profile_contract';

  @override
  String toString() => 'The Profile contract value is invalid';
}

/// One-time activation state of the owner's public profile.
enum ProfileStatus {
  pending('pending'),
  active('active');

  const ProfileStatus(this.wireValue);

  final String wireValue;

  static ProfileStatus fromWire(String value) {
    for (final status in values) {
      if (status.wireValue == value) return status;
    }
    throw const InvalidProfileContractException();
  }
}

/// Followed tracks. The enumeration is closed by the V2 contract; an unknown
/// value is a contract violation, never a silently dropped chip.
enum ProfileInterest {
  meme('MEME', 'MEME'),
  defi('DEFI', 'DeFi'),
  ai('AI', 'AI'),
  gamefi('GAMEFI', 'GameFi'),
  nft('NFT', 'NFT'),
  rwa('RWA', 'RWA');

  const ProfileInterest(this.wireValue, this.label);

  final String wireValue;

  /// Prototype casing for the `loop-id-setup` chips.
  final String label;

  static ProfileInterest fromWire(String value) {
    for (final interest in values) {
      if (interest.wireValue == value) return interest;
    }
    throw const InvalidProfileContractException();
  }
}

@immutable
final class ProfileValues {
  factory ProfileValues({
    required String? alias,
    required String? avatarRef,
    String? bio,
    List<ProfileInterest> interests = const <ProfileInterest>[],
  }) {
    final normalizedAlias = _normalizeProfileAlias(alias);
    if (avatarRef != null &&
        !_profileAvatarReferencePattern.hasMatch(avatarRef)) {
      throw const InvalidProfileContractException();
    }
    final normalizedBio = _normalizeProfileBio(bio);
    return ProfileValues._(
      normalizedAlias,
      avatarRef,
      normalizedBio,
      _normalizeInterests(interests),
    );
  }

  const ProfileValues._(this.alias, this.avatarRef, this.bio, this.interests);

  factory ProfileValues.empty() => ProfileValues(alias: null, avatarRef: null);

  factory ProfileValues.copyOf(ProfileValues source) => ProfileValues(
    alias: source.alias,
    avatarRef: source.avatarRef,
    bio: source.bio,
    interests: source.interests,
  );

  final String? alias;
  final String? avatarRef;
  final String? bio;

  /// Ordered and de-duplicated; the submitted order is preserved so an
  /// idempotent activation retry can send the exact same body.
  final List<ProfileInterest> interests;

  /// Returns a validated value with an explicitly replaced nullable alias.
  ProfileValues withAlias(String? alias) => ProfileValues(
    alias: alias,
    avatarRef: avatarRef,
    bio: bio,
    interests: interests,
  );

  ProfileValues withAvatarRef(String? avatarRef) => ProfileValues(
    alias: alias,
    avatarRef: avatarRef,
    bio: bio,
    interests: interests,
  );

  ProfileValues withBio(String? bio) => ProfileValues(
    alias: alias,
    avatarRef: avatarRef,
    bio: bio,
    interests: interests,
  );

  ProfileValues withInterests(List<ProfileInterest> interests) => ProfileValues(
    alias: alias,
    avatarRef: avatarRef,
    bio: bio,
    interests: interests,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileValues &&
          other.alias == alias &&
          other.avatarRef == avatarRef &&
          other.bio == bio &&
          listEquals(other.interests, interests);

  @override
  int get hashCode =>
      Object.hash(alias, avatarRef, bio, Object.hashAll(interests));
}

@immutable
final class ProfileResource {
  factory ProfileResource({
    required int version,
    required ProfileValues values,
    required DateTime? updatedAt,
    String? loopId,
    ProfileStatus profileStatus = ProfileStatus.pending,
    DateTime? activatedAt,
  }) {
    if (version < 0 ||
        version > profileMaximumVersion ||
        ((version == 0) != (updatedAt == null)) ||
        (loopId != null && !profileLoopIdPattern.hasMatch(loopId)) ||
        ((profileStatus == ProfileStatus.active) != (activatedAt != null))) {
      throw const InvalidProfileContractException();
    }
    return ProfileResource._(
      version,
      ProfileValues.copyOf(values),
      updatedAt?.toUtc(),
      loopId,
      profileStatus,
      activatedAt?.toUtc(),
    );
  }

  const ProfileResource._(
    this.version,
    this.values,
    this.updatedAt,
    this.loopId,
    this.profileStatus,
    this.activatedAt,
  );

  factory ProfileResource.empty() => ProfileResource(
    version: 0,
    values: ProfileValues.empty(),
    updatedAt: null,
  );

  factory ProfileResource.copyOf(ProfileResource source) => ProfileResource(
    version: source.version,
    values: source.values,
    updatedAt: source.updatedAt,
    loopId: source.loopId,
    profileStatus: source.profileStatus,
    activatedAt: source.activatedAt,
  );

  final int version;
  final ProfileValues values;
  final DateTime? updatedAt;

  /// Null only for the frozen V1 transport, which does not carry a LOOP ID.
  final String? loopId;
  final ProfileStatus profileStatus;
  final DateTime? activatedAt;

  bool get isActivated => profileStatus == ProfileStatus.active;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileResource &&
          other.version == version &&
          other.values == values &&
          other.updatedAt == updatedAt &&
          other.loopId == loopId &&
          other.profileStatus == profileStatus &&
          other.activatedAt == activatedAt;

  @override
  int get hashCode => Object.hash(
    version,
    values,
    updatedAt,
    loopId,
    profileStatus,
    activatedAt,
  );
}

String? _normalizeProfileAlias(String? value) {
  if (value == null) return null;
  if (value.length > 256 || containsLoopForbiddenHumanTextCodePoint(value)) {
    throw const InvalidProfileContractException();
  }

  final normalized = value.trim();
  final codePointLength = normalized.runes.length;
  if (codePointLength < 1 || codePointLength > 40) {
    throw const InvalidProfileContractException();
  }
  return normalized;
}

String? _normalizeProfileBio(String? value) {
  if (value == null) return null;
  if (value.length > 1024 || containsLoopForbiddenHumanTextCodePoint(value)) {
    throw const InvalidProfileContractException();
  }

  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  if (normalized.runes.length > profileMaximumBioCodePoints) {
    throw const InvalidProfileContractException();
  }
  return normalized;
}

List<ProfileInterest> _normalizeInterests(List<ProfileInterest> value) {
  if (value.length > profileMaximumInterests) {
    throw const InvalidProfileContractException();
  }
  final seen = <ProfileInterest>{};
  for (final interest in value) {
    if (!seen.add(interest)) {
      throw const InvalidProfileContractException();
    }
  }
  return List<ProfileInterest>.unmodifiable(value);
}
