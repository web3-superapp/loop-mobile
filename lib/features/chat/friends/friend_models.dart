import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';

const int friendDirectoryMaximumItems = 100;
const int friendSearchMaximumItems = 50;
const int groupMinimumSelectedFriends = 2;
const int groupMaximumSelectedFriends = 29;

/// Sanitized validation failure for values outside the reviewed social graph
/// boundary. Rejected user input is deliberately never included in the error.
final class InvalidFriendContractException implements Exception {
  const InvalidFriendContractException();

  String get code => 'invalid_friend_contract';

  @override
  String toString() => 'The friend contract value is invalid';
}

enum FriendRelationship { none, requestPending, friend }

/// Typed viewer-scoped social reference.
///
/// Keeping the wire value behind this type prevents wallet addresses, Privy
/// principals, LOOP owner IDs, and Stream user IDs from being passed into the
/// friend graph by accident. Only an integration adapter may construct it from
/// a reviewed backend field.
@immutable
final class FriendProfileRef {
  factory FriendProfileRef.fromWire(String value) {
    _validateOpaqueId(value);
    return FriendProfileRef._(value);
  }

  const FriendProfileRef._(this._value);

  final String _value;

  /// Integration-only value for a future reviewed transport adapter.
  String get wireValue => _value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendProfileRef && other._value == _value;

  @override
  int get hashCode => _value.hashCode;
}

@immutable
final class FriendIdentity {
  factory FriendIdentity({
    required FriendProfileRef profileRef,
    required String alias,
    int colorSeed = 0,
  }) {
    final normalizedAlias = normalizeFriendDisplayName(alias);
    if (colorSeed < 0 || colorSeed > 2147483647) {
      throw const InvalidFriendContractException();
    }
    return FriendIdentity._(profileRef, normalizedAlias, colorSeed);
  }

  const FriendIdentity._(this.profileRef, this.alias, this.colorSeed);

  /// Opaque, viewer-scoped reference returned by the future backend adapter.
  /// It is not a Privy DID, wallet address, internal LOOP ID, or Stream user ID.
  final FriendProfileRef profileRef;

  /// The account-level, discoverable LOOP Alias. Group-scoped aliases are not
  /// represented here and must never be used as a discovery key.
  final String alias;
  final int colorSeed;

  factory FriendIdentity.copyOf(FriendIdentity source) => FriendIdentity(
    profileRef: source.profileRef,
    alias: source.alias,
    colorSeed: source.colorSeed,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendIdentity &&
          other.profileRef == profileRef &&
          other.alias == alias &&
          other.colorSeed == colorSeed;

  @override
  int get hashCode => Object.hash(profileRef, alias, colorSeed);
}

@immutable
final class FriendSearchResult {
  FriendSearchResult({
    required FriendIdentity identity,
    required this.relationship,
  }) : identity = FriendIdentity.copyOf(identity);

  final FriendIdentity identity;
  final FriendRelationship relationship;

  factory FriendSearchResult.copyOf(FriendSearchResult source) =>
      FriendSearchResult(
        identity: source.identity,
        relationship: source.relationship,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendSearchResult &&
          other.identity == identity &&
          other.relationship == relationship;

  @override
  int get hashCode => Object.hash(identity, relationship);
}

@immutable
final class CreatedFriendGroup {
  factory CreatedFriendGroup({
    required String requestId,
    required String name,
    required Iterable<FriendProfileRef> friendRefs,
    String? streamCid,
  }) {
    validateFriendOperationId(requestId);
    final normalizedName = normalizeFriendDisplayName(name);
    final copiedRefs = validateSelectedFriendRefs(friendRefs);
    if (streamCid != null && parseLoopStreamChannelCid(streamCid) == null) {
      throw const InvalidFriendContractException();
    }
    return CreatedFriendGroup._(
      requestId,
      normalizedName,
      copiedRefs,
      streamCid,
    );
  }

  const CreatedFriendGroup._(
    this.requestId,
    this.name,
    this.friendRefs,
    this.streamCid,
  );

  final String requestId;
  final String name;
  final List<FriendProfileRef> friendRefs;

  /// Present only after an official Stream-backed adapter has created and
  /// verified the channel. Preview receipts deliberately leave this null.
  final String? streamCid;

  factory CreatedFriendGroup.copyOf(CreatedFriendGroup source) =>
      CreatedFriendGroup(
        requestId: source.requestId,
        name: source.name,
        friendRefs: source.friendRefs,
        streamCid: source.streamCid,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatedFriendGroup &&
          other.requestId == requestId &&
          other.name == name &&
          listEquals(other.friendRefs, friendRefs) &&
          other.streamCid == streamCid;

  @override
  int get hashCode =>
      Object.hash(requestId, name, Object.hashAll(friendRefs), streamCid);
}

final RegExp _friendOperationIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

String validateFriendOperationId(String value) {
  if (!_friendOperationIdPattern.hasMatch(value)) {
    throw const InvalidFriendContractException();
  }
  return value;
}

String normalizeFriendAliasQuery(String raw) {
  if (raw.length > 256 || _containsForbiddenDisplayCodePoint(raw)) {
    throw const InvalidFriendContractException();
  }
  final normalized = raw.trim();
  final length = normalized.runes.length;
  if (length < 1 || length > 40) {
    throw const InvalidFriendContractException();
  }
  return normalized;
}

String normalizeFriendDisplayName(String raw) {
  if (raw.length > 256 || _containsForbiddenDisplayCodePoint(raw)) {
    throw const InvalidFriendContractException();
  }
  final normalized = raw.trim();
  final length = normalized.runes.length;
  if (length < 1 || length > 40) {
    throw const InvalidFriendContractException();
  }
  return normalized;
}

List<FriendIdentity> validateFriendDirectory(
  Iterable<FriendIdentity> identities,
) {
  final copied = List<FriendIdentity>.unmodifiable(
    identities.map(FriendIdentity.copyOf),
  );
  final normalizedAliases = copied
      .map((identity) => identity.alias.toLowerCase())
      .toSet();
  if (copied.length > friendDirectoryMaximumItems ||
      copied.map((identity) => identity.profileRef).toSet().length !=
          copied.length ||
      normalizedAliases.length != copied.length) {
    throw const InvalidFriendContractException();
  }
  return copied;
}

List<FriendSearchResult> validateFriendSearchResults(
  Iterable<FriendSearchResult> results,
) {
  final copied = List<FriendSearchResult>.unmodifiable(
    results.map(FriendSearchResult.copyOf),
  );
  final normalizedAliases = copied
      .map((result) => result.identity.alias.toLowerCase())
      .toSet();
  if (copied.length > friendSearchMaximumItems ||
      copied.map((result) => result.identity.profileRef).toSet().length !=
          copied.length ||
      normalizedAliases.length != copied.length) {
    throw const InvalidFriendContractException();
  }
  return copied;
}

List<FriendProfileRef> validateSelectedFriendRefs(
  Iterable<FriendProfileRef> friendRefs,
) {
  final copied = List<FriendProfileRef>.unmodifiable(friendRefs);
  if (copied.length < groupMinimumSelectedFriends ||
      copied.length > groupMaximumSelectedFriends ||
      copied.toSet().length != copied.length) {
    throw const InvalidFriendContractException();
  }
  return copied;
}

void _validateOpaqueId(String value, {int maximumCodeUnits = 128}) {
  if (value.isEmpty ||
      value != value.trim() ||
      value.length > maximumCodeUnits ||
      _containsForbiddenDisplayCodePoint(value)) {
    throw const InvalidFriendContractException();
  }
}

bool _containsForbiddenDisplayCodePoint(String value) {
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
