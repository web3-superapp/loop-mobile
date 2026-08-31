import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/text/loop_human_text.dart';

const int friendDirectoryMaximumItems = 1000;
const int friendDirectoryPageMaximumItems = 50;
const int friendSearchMaximumItems = 20;
const int friendRequestPageMaximumItems = 50;
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

/// `requestPending` is retained only for Development Preview compatibility.
/// Production adapters use the direction-specific pending values.
enum FriendRelationship {
  none,
  requestPending,
  outgoingPending,
  incomingPending,
  friend,
}

enum FriendRequestDirection { incoming, outgoing }

enum FriendRequestDecision { accept, reject }

/// Stable public profile identifier used by the LOOP friend graph.
///
/// It is never a wallet address, Privy principal, LOOP owner ID, or Stream
/// user ID. Production adapters must use [fromPublicProfileId], which accepts
/// only the backend's canonical UUID form. [fromWire] remains available for
/// labelled Development Preview fixtures and legacy tests.
@immutable
final class FriendProfileRef {
  factory FriendProfileRef.fromPublicProfileId(String value) {
    _validateUuid(value);
    return FriendProfileRef._(value);
  }

  factory FriendProfileRef.fromWire(String value) {
    _validateOpaqueId(value);
    return FriendProfileRef._(value);
  }

  const FriendProfileRef._(this._value);

  final String _value;

  /// Integration-only `public_profile_id` wire value.
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
  /// Compatibility constructor for Preview fixtures and feature tests.
  factory FriendIdentity({
    required FriendProfileRef profileRef,
    required String alias,
    String? profileCode,
    String? avatarRef,
    DateTime? acceptedAt,
    int colorSeed = 0,
  }) {
    final normalizedAlias = normalizeFriendDisplayName(alias);
    final normalizedCode = profileCode == null
        ? _previewProfileCode(profileRef.wireValue)
        : validateFriendProfileCode(profileCode);
    return FriendIdentity._validated(
      profileRef: profileRef,
      profileCode: normalizedCode,
      accountAlias: normalizedAlias,
      avatarRef: _validateOptionalAvatarRef(avatarRef),
      acceptedAt: acceptedAt?.toUtc(),
      colorSeed: _validateColorSeed(colorSeed),
    );
  }

  /// Strict constructor for authenticated backend payloads.
  factory FriendIdentity.fromBackend({
    required FriendProfileRef publicProfileId,
    required String profileCode,
    required String? alias,
    required String? avatarRef,
    DateTime? acceptedAt,
  }) {
    final normalizedAlias = alias == null
        ? null
        : normalizeFriendDisplayName(alias);
    return FriendIdentity._validated(
      profileRef: publicProfileId,
      profileCode: validateFriendProfileCode(profileCode),
      accountAlias: normalizedAlias,
      avatarRef: _validateOptionalAvatarRef(avatarRef),
      acceptedAt: acceptedAt?.toUtc(),
      colorSeed: _stableColorSeed(profileCode),
    );
  }

  const FriendIdentity._validated({
    required this.profileRef,
    required this.profileCode,
    required this.accountAlias,
    required this.avatarRef,
    required this.acceptedAt,
    required this.colorSeed,
  });

  final FriendProfileRef profileRef;

  /// Immutable, globally unique, display-only discriminator. It must never be
  /// used as a command target or copied into Stream identity fields.
  final String profileCode;

  /// Mutable account Alias. It may be null for an accepted friend and may be
  /// shared by multiple accounts.
  final String? accountAlias;
  final String? avatarRef;
  final DateTime? acceptedAt;
  final int colorSeed;

  /// Safe presentation fallback for nullable account Alias values.
  String get alias => accountAlias ?? profileCode;

  factory FriendIdentity.copyOf(FriendIdentity source) =>
      FriendIdentity._validated(
        profileRef: source.profileRef,
        profileCode: source.profileCode,
        accountAlias: source.accountAlias,
        avatarRef: source.avatarRef,
        acceptedAt: source.acceptedAt,
        colorSeed: source.colorSeed,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendIdentity &&
          other.profileRef == profileRef &&
          other.profileCode == profileCode &&
          other.accountAlias == accountAlias &&
          other.avatarRef == avatarRef &&
          other.acceptedAt == acceptedAt &&
          other.colorSeed == colorSeed;

  @override
  int get hashCode => Object.hash(
    profileRef,
    profileCode,
    accountAlias,
    avatarRef,
    acceptedAt,
    colorSeed,
  );
}

@immutable
final class FriendSearchResult {
  FriendSearchResult({
    required FriendIdentity identity,
    required this.relationship,
    String? friendRequestId,
  }) : identity = FriendIdentity.copyOf(identity),
       friendRequestId = _validateSearchRequestId(
         relationship,
         friendRequestId,
       );

  final FriendIdentity identity;
  final FriendRelationship relationship;
  final String? friendRequestId;

  bool get isOutgoingPending =>
      relationship == FriendRelationship.outgoingPending ||
      relationship == FriendRelationship.requestPending;

  factory FriendSearchResult.copyOf(FriendSearchResult source) =>
      FriendSearchResult(
        identity: source.identity,
        relationship: source.relationship,
        friendRequestId: source.friendRequestId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FriendSearchResult &&
          other.identity == identity &&
          other.relationship == relationship &&
          other.friendRequestId == friendRequestId;

  @override
  int get hashCode => Object.hash(identity, relationship, friendRequestId);
}

@immutable
final class FriendDirectoryPage {
  FriendDirectoryPage({
    required Iterable<FriendIdentity> items,
    required String? nextCursor,
  }) : items = _validateFriendDirectoryPage(items),
       nextCursor = _validateOptionalCursor(nextCursor);

  final List<FriendIdentity> items;
  final String? nextCursor;
}

@immutable
final class FriendSearchPage {
  FriendSearchPage({
    required Iterable<FriendSearchResult> items,
    required this.truncated,
  }) : items = validateFriendSearchResults(items);

  final List<FriendSearchResult> items;
  final bool truncated;
}

@immutable
final class FriendRequestRecord {
  FriendRequestRecord({
    required String friendRequestId,
    required FriendIdentity counterparty,
    required this.direction,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) : friendRequestId = validateFriendEntityId(friendRequestId),
       counterparty = FriendIdentity.copyOf(counterparty),
       createdAt = createdAt.toUtc(),
       expiresAt = expiresAt.toUtc() {
    if (!this.expiresAt.isAfter(this.createdAt)) {
      throw const InvalidFriendContractException();
    }
  }

  final String friendRequestId;
  final FriendIdentity counterparty;
  final FriendRequestDirection direction;
  final DateTime createdAt;
  final DateTime expiresAt;
}

@immutable
final class FriendRequestPage {
  FriendRequestPage({
    required Iterable<FriendRequestRecord> items,
    required String? nextCursor,
  }) : items = _validateFriendRequestPage(items),
       nextCursor = _validateOptionalCursor(nextCursor);

  final List<FriendRequestRecord> items;
  final String? nextCursor;
}

@immutable
final class FriendRequestDecisionReceipt {
  FriendRequestDecisionReceipt({
    required String operationId,
    required String friendRequestId,
    required this.decision,
  }) : operationId = validateFriendOperationId(operationId),
       friendRequestId = validateFriendEntityId(friendRequestId);

  final String operationId;
  final String friendRequestId;
  final FriendRequestDecision decision;
}

@immutable
final class FriendRequestSendReceipt {
  FriendRequestSendReceipt({
    required String operationId,
    required this.targetProfileRef,
    required String friendRequestId,
  }) : operationId = validateFriendOperationId(operationId),
       friendRequestId = validateFriendEntityId(friendRequestId);

  final String operationId;
  final FriendProfileRef targetProfileRef;
  final String friendRequestId;
}

@immutable
final class CreatedDirectFriendChannel {
  factory CreatedDirectFriendChannel({
    required String operationId,
    required FriendProfileRef targetProfileRef,
    required String streamCid,
  }) {
    validateFriendOperationId(operationId);
    final address = parseLoopStreamChannelCid(streamCid);
    if (address == null || !address.id.startsWith('loop_direct_')) {
      throw const InvalidFriendContractException();
    }
    return CreatedDirectFriendChannel._(
      operationId,
      targetProfileRef,
      streamCid,
    );
  }

  const CreatedDirectFriendChannel._(
    this.operationId,
    this.targetProfileRef,
    this.streamCid,
  );

  final String operationId;
  final FriendProfileRef targetProfileRef;
  final String streamCid;
}

@immutable
final class CreatedFriendGroup {
  factory CreatedFriendGroup({
    required String requestId,
    required String name,
    required Iterable<FriendProfileRef> friendRefs,
    String? groupId,
    String? streamCid,
  }) {
    validateFriendOperationId(requestId);
    final normalizedName = normalizeFriendGroupName(name);
    final copiedRefs = validateSelectedFriendRefs(friendRefs);
    final normalizedGroupId = groupId == null
        ? null
        : validateFriendEntityId(groupId);
    if (streamCid != null) {
      final address = parseLoopStreamChannelCid(streamCid);
      if (address == null || !address.id.startsWith('loop_group_')) {
        throw const InvalidFriendContractException();
      }
    }
    if ((normalizedGroupId == null) != (streamCid == null)) {
      throw const InvalidFriendContractException();
    }
    return CreatedFriendGroup._(
      requestId,
      normalizedGroupId,
      normalizedName,
      copiedRefs,
      streamCid,
    );
  }

  const CreatedFriendGroup._(
    this.requestId,
    this.groupId,
    this.name,
    this.friendRefs,
    this.streamCid,
  );

  /// The command idempotency key and backend operation locator.
  final String requestId;
  String get operationId => requestId;
  final String? groupId;
  final String name;
  final List<FriendProfileRef> friendRefs;
  final String? streamCid;

  factory CreatedFriendGroup.copyOf(CreatedFriendGroup source) =>
      CreatedFriendGroup(
        requestId: source.requestId,
        groupId: source.groupId,
        name: source.name,
        friendRefs: source.friendRefs,
        streamCid: source.streamCid,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreatedFriendGroup &&
          other.requestId == requestId &&
          other.groupId == groupId &&
          other.name == name &&
          setEquals(other.friendRefs.toSet(), friendRefs.toSet()) &&
          other.streamCid == streamCid;

  @override
  int get hashCode => Object.hash(
    requestId,
    groupId,
    name,
    Object.hashAllUnordered(friendRefs),
    streamCid,
  );
}

final RegExp _friendOperationIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final RegExp _friendEntityIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final RegExp _friendProfileCodePattern = RegExp(
  r'^[0-9ABCDEFGHJKMNPQRSTVWXYZ]{10}$',
);
final RegExp _friendAvatarReferencePattern = RegExp(
  r'^avatar:[A-Za-z0-9][A-Za-z0-9._/-]{0,126}$',
);

String validateFriendOperationId(String value) {
  if (!_friendOperationIdPattern.hasMatch(value)) {
    throw const InvalidFriendContractException();
  }
  return value;
}

String validateFriendEntityId(String value) {
  if (!_friendEntityIdPattern.hasMatch(value)) {
    throw const InvalidFriendContractException();
  }
  return value;
}

String validateFriendProfileCode(String value) {
  if (!_friendProfileCodePattern.hasMatch(value)) {
    throw const InvalidFriendContractException();
  }
  return value;
}

String normalizeFriendAliasQuery(String raw) {
  if (raw.length > 256 || containsLoopForbiddenHumanTextCodePoint(raw)) {
    throw const InvalidFriendContractException();
  }
  final normalized = raw.trim();
  final length = loopSearchValidationCodePointLength(normalized);
  if (length < 2 || length > 40) {
    throw const InvalidFriendContractException();
  }
  return normalized;
}

String normalizeFriendDisplayName(String raw) =>
    _normalizeDisplayValue(raw, maximumRunes: 40, maximumCodeUnits: 256);

String normalizeFriendGroupName(String raw) =>
    _normalizeDisplayValue(raw, maximumRunes: 60, maximumCodeUnits: 512);

List<FriendIdentity> validateFriendDirectory(
  Iterable<FriendIdentity> identities,
) {
  final copied = List<FriendIdentity>.unmodifiable(
    identities.map(FriendIdentity.copyOf),
  );
  if (copied.length > friendDirectoryMaximumItems ||
      copied.map((identity) => identity.profileRef).toSet().length !=
          copied.length ||
      copied.map((identity) => identity.profileCode).toSet().length !=
          copied.length) {
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
  if (copied.length > friendSearchMaximumItems ||
      copied.map((result) => result.identity.profileRef).toSet().length !=
          copied.length ||
      copied.map((result) => result.identity.profileCode).toSet().length !=
          copied.length) {
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

List<FriendIdentity> _validateFriendDirectoryPage(
  Iterable<FriendIdentity> items,
) {
  final copied = validateFriendDirectory(items);
  if (copied.length > friendDirectoryPageMaximumItems) {
    throw const InvalidFriendContractException();
  }
  return copied;
}

List<FriendRequestRecord> _validateFriendRequestPage(
  Iterable<FriendRequestRecord> items,
) {
  final copied = List<FriendRequestRecord>.unmodifiable(items);
  if (copied.length > friendRequestPageMaximumItems ||
      copied.map((item) => item.friendRequestId).toSet().length !=
          copied.length ||
      copied.map((item) => item.counterparty.profileRef).toSet().length !=
          copied.length) {
    throw const InvalidFriendContractException();
  }
  return copied;
}

String? _validateSearchRequestId(
  FriendRelationship relationship,
  String? requestId,
) {
  final pending =
      relationship == FriendRelationship.outgoingPending ||
      relationship == FriendRelationship.incomingPending;
  if (pending) {
    if (requestId == null) throw const InvalidFriendContractException();
    return validateFriendEntityId(requestId);
  }
  // Development Preview's legacy pending state intentionally has no backend
  // request locator.
  if (relationship == FriendRelationship.requestPending) {
    return requestId == null ? null : validateFriendEntityId(requestId);
  }
  if (requestId != null) throw const InvalidFriendContractException();
  return null;
}

String? _validateOptionalCursor(String? value) {
  if (value == null) return null;
  _validateOpaqueId(value, maximumCodeUnits: 1024);
  return value;
}

String? _validateOptionalAvatarRef(String? value) {
  if (value == null) return null;
  if (!_friendAvatarReferencePattern.hasMatch(value)) {
    throw const InvalidFriendContractException();
  }
  return value;
}

String _normalizeDisplayValue(
  String raw, {
  required int maximumRunes,
  required int maximumCodeUnits,
}) {
  if (raw.length > maximumCodeUnits ||
      containsLoopForbiddenHumanTextCodePoint(raw)) {
    throw const InvalidFriendContractException();
  }
  final normalized = raw.trim();
  final length = normalized.runes.length;
  if (length < 1 || length > maximumRunes) {
    throw const InvalidFriendContractException();
  }
  return normalized;
}

void _validateUuid(String value) {
  if (!_friendEntityIdPattern.hasMatch(value)) {
    throw const InvalidFriendContractException();
  }
}

void _validateOpaqueId(String value, {int maximumCodeUnits = 128}) {
  if (value.isEmpty ||
      value != value.trim() ||
      value.length > maximumCodeUnits ||
      containsLoopForbiddenHumanTextCodePoint(value)) {
    throw const InvalidFriendContractException();
  }
}

int _validateColorSeed(int value) {
  if (value < 0 || value > 2147483647) {
    throw const InvalidFriendContractException();
  }
  return value;
}

String _previewProfileCode(String value) {
  const alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  var hash = 2166136261;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  final buffer = StringBuffer();
  var current = hash;
  for (var index = 0; index < 10; index++) {
    buffer.write(alphabet[current & 31]);
    current = ((current >> 5) ^ (hash * (index + 17))) & 0x7fffffff;
  }
  return buffer.toString();
}

int _stableColorSeed(String value) {
  var hash = 0;
  for (final codeUnit in value.codeUnits) {
    hash = ((hash * 31) + codeUnit) & 0x7fffffff;
  }
  return hash;
}
