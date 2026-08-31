import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/text/loop_human_text.dart';

const int groupAliasMaximumRawCodeUnits = 256;
const int groupAliasMaximumCodePoints = 40;
const int groupAliasSearchMinimumCodePoints = 2;
const int groupAliasSearchMaximumItems = 20;

final RegExp _canonicalUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final RegExp _streamChannelIdPattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$',
);

/// Sanitized validation failure for values outside the reviewed group-Alias
/// contract. Rejected input is deliberately never included in the error.
final class InvalidGroupAliasContractException implements Exception {
  const InvalidGroupAliasContractException();

  String get code => 'invalid_group_alias_contract';

  @override
  String toString() => 'The group Alias contract value is invalid';
}

/// LOOP's server-issued identifier for a communication group.
///
/// This type accepts only a canonical UUID. It deliberately has no constructor
/// for a Stream channel ID/CID: direct channels do not have a group-Alias
/// namespace and must never enter the group-Alias gateway.
@immutable
final class GroupId {
  factory GroupId.fromWire(String value) {
    _validateCanonicalUuid(value);
    return GroupId._(value);
  }

  const GroupId._(this._value);

  factory GroupId.copyOf(GroupId source) => GroupId.fromWire(source._value);

  final String _value;

  /// Integration-only value for the reviewed LOOP backend adapter.
  String get wireValue => _value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GroupId && other._value == _value;

  @override
  int get hashCode => _value.hashCode;
}

/// A validated Stream messaging channel ID that may enter the backend's
/// existing-group resolver.
///
/// The route accepts a full CID so the shared Chat parser first proves the
/// `messaging:<id>` boundary. Only the ID is retained because the backend
/// contract explicitly rejects full CIDs. Known LOOP direct-channel IDs are
/// rejected locally; the backend remains authoritative for legacy metadata.
@immutable
final class GroupAliasStreamChannelId {
  factory GroupAliasStreamChannelId.fromCid(String cid) {
    final address = parseLoopStreamChannelCid(cid);
    if (address == null ||
        !_streamChannelIdPattern.hasMatch(address.id) ||
        address.id.startsWith('loop_direct_')) {
      throw const InvalidGroupAliasContractException();
    }
    return GroupAliasStreamChannelId._(address.id);
  }

  const GroupAliasStreamChannelId._(this._value);

  factory GroupAliasStreamChannelId.copyOf(GroupAliasStreamChannelId source) =>
      GroupAliasStreamChannelId.fromCid(source.cid);

  final String _value;

  /// Integration-only channel ID; this is deliberately not a full CID.
  String get wireValue => _value;

  String get cid => 'messaging:$_value';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupAliasStreamChannelId && other._value == _value;

  @override
  int get hashCode => _value.hashCode;
}

/// Opaque, group-local reference for one member's immutable Alias.
///
/// It is display/search plumbing only. It is not a public profile, LOOP owner,
/// Privy, wallet, or Stream user identifier and cannot be correlated across
/// groups by this feature boundary.
@immutable
final class GroupAliasId {
  factory GroupAliasId.fromWire(String value) {
    _validateCanonicalUuid(value);
    return GroupAliasId._(value);
  }

  const GroupAliasId._(this._value);

  factory GroupAliasId.copyOf(GroupAliasId source) =>
      GroupAliasId.fromWire(source._value);

  final String _value;

  /// Integration-only value for the reviewed LOOP backend adapter.
  String get wireValue => _value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GroupAliasId && other._value == _value;

  @override
  int get hashCode => _value.hashCode;
}

enum GroupAliasProjectionState { pending, confirmed }

/// The current member's permanently reserved Alias inside one group.
@immutable
final class GroupAliasResource {
  factory GroupAliasResource({
    required GroupAliasId groupAliasId,
    required String alias,
    required GroupAliasProjectionState projectionState,
  }) => GroupAliasResource._(
    GroupAliasId.copyOf(groupAliasId),
    normalizeGroupAlias(alias),
    projectionState,
  );

  const GroupAliasResource._(
    this.groupAliasId,
    this.alias,
    this.projectionState,
  );

  factory GroupAliasResource.copyOf(GroupAliasResource source) =>
      GroupAliasResource(
        groupAliasId: source.groupAliasId,
        alias: source.alias,
        projectionState: source.projectionState,
      );

  final GroupAliasId groupAliasId;
  final String alias;
  final GroupAliasProjectionState projectionState;

  bool get requiresProjectionRetry =>
      projectionState == GroupAliasProjectionState.pending;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupAliasResource &&
          other.groupAliasId == groupAliasId &&
          other.alias == alias &&
          other.projectionState == projectionState;

  @override
  int get hashCode => Object.hash(groupAliasId, alias, projectionState);
}

/// One group-local search result. No account-level or Stream identity is
/// representable by this model.
@immutable
final class GroupAliasSearchItem {
  factory GroupAliasSearchItem({
    required GroupAliasId groupAliasId,
    required String alias,
  }) => GroupAliasSearchItem._(
    GroupAliasId.copyOf(groupAliasId),
    normalizeGroupAlias(alias),
  );

  const GroupAliasSearchItem._(this.groupAliasId, this.alias);

  factory GroupAliasSearchItem.copyOf(GroupAliasSearchItem source) =>
      GroupAliasSearchItem(
        groupAliasId: source.groupAliasId,
        alias: source.alias,
      );

  final GroupAliasId groupAliasId;
  final String alias;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupAliasSearchItem &&
          other.groupAliasId == groupAliasId &&
          other.alias == alias;

  @override
  int get hashCode => Object.hash(groupAliasId, alias);
}

/// One bounded, cursor-free group-Alias prefix result.
@immutable
final class GroupAliasSearchPage {
  factory GroupAliasSearchPage({
    required Iterable<GroupAliasSearchItem> items,
    required bool truncated,
  }) {
    final copied = List<GroupAliasSearchItem>.unmodifiable(
      items.map(GroupAliasSearchItem.copyOf),
    );
    if (copied.length > groupAliasSearchMaximumItems ||
        copied.map((item) => item.groupAliasId).toSet().length !=
            copied.length ||
        copied.map((item) => item.alias).toSet().length != copied.length) {
      throw const InvalidGroupAliasContractException();
    }
    return GroupAliasSearchPage._(copied, truncated);
  }

  const GroupAliasSearchPage._(this.items, this.truncated);

  factory GroupAliasSearchPage.empty() => GroupAliasSearchPage(
    items: const <GroupAliasSearchItem>[],
    truncated: false,
  );

  factory GroupAliasSearchPage.copyOf(GroupAliasSearchPage source) =>
      GroupAliasSearchPage(items: source.items, truncated: source.truncated);

  final List<GroupAliasSearchItem> items;
  final bool truncated;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupAliasSearchPage &&
          listEquals(other.items, items) &&
          other.truncated == truncated;

  @override
  int get hashCode => Object.hash(Object.hashAll(items), truncated);
}

String normalizeGroupAlias(String raw) => _normalizeAliasText(raw, minimum: 1);

String normalizeGroupAliasSearchPrefix(String raw) =>
    _normalizeAliasText(raw, minimum: groupAliasSearchMinimumCodePoints);

int validateGroupAliasSearchLimit(int limit) {
  if (limit < 1 || limit > groupAliasSearchMaximumItems) {
    throw const InvalidGroupAliasContractException();
  }
  return limit;
}

String _normalizeAliasText(String raw, {required int minimum}) {
  if (raw.length > groupAliasMaximumRawCodeUnits ||
      containsLoopForbiddenHumanTextCodePoint(raw)) {
    throw const InvalidGroupAliasContractException();
  }
  final normalized = raw.trim();
  final length = minimum == groupAliasSearchMinimumCodePoints
      ? loopSearchValidationCodePointLength(normalized)
      : normalized.runes.length;
  if (length < minimum || length > groupAliasMaximumCodePoints) {
    throw const InvalidGroupAliasContractException();
  }
  return normalized;
}

void _validateCanonicalUuid(String value) {
  if (!_canonicalUuidPattern.hasMatch(value)) {
    throw const InvalidGroupAliasContractException();
  }
}
