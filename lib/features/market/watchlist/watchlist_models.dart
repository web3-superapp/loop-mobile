import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';

/// Server-enforced Watchlist limits (`docs/frontend-v2-wallet-api.md` §9).
const int watchlistMaxGroups = 20;
const int watchlistMaxItems = 100;
const int watchlistMaxNameCodePoints = 40;
const int watchlistMaximumVersion = 2147483647;

final RegExp _watchlistGroupKeyPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,31}$');
final RegExp _forbiddenDisplayCodePoint = RegExp(
  r'[\p{Cc}\p{Cf}\p{Cs}\p{Zl}\p{Zp}]',
  unicode: true,
);

/// The group the star on `token` writes into.
///
/// The server generates no key: `PUT /v2/watchlist` takes whatever key the
/// client sends, as long as it matches `^[a-z0-9][a-z0-9_-]{0,31}$` and is
/// unique in the document. So "the default group" is a client convention, and
/// this constant is the whole of it — one key, looked up by equality, created
/// in the same replacement that adds the first asset.
const String watchlistDefaultGroupKey = 'default';
const String watchlistDefaultGroupName = '自选';

/// Why a proposed group name cannot be written.
///
/// The same function answers for the input field and for the controller, so
/// what the field explains is exactly what the write would refuse.
enum WatchlistGroupNameIssue {
  empty,
  tooLong,
  invalidCharacters,
  duplicate,
  groupLimitReached,

  /// The page is not showing a committed resource, so there is nothing to add
  /// a group to. Only the controller can answer this one.
  notEditable,
}

/// Validates a new group name against the write contract.
///
/// `null` means the name is writable. The bounds are the server's own
/// (`watchlist-v2-service.ts`): trimmed, 1–40 code points, and no control,
/// format, surrogate or line/paragraph separator code point.
WatchlistGroupNameIssue? watchlistGroupNameIssue(
  String name, {
  required Iterable<WatchlistGroup> existing,
}) {
  final groups = existing.toList(growable: false);
  if (groups.length >= watchlistMaxGroups) {
    return WatchlistGroupNameIssue.groupLimitReached;
  }
  final trimmed = name.trim();
  if (trimmed.isEmpty) return WatchlistGroupNameIssue.empty;
  if (trimmed.runes.length > watchlistMaxNameCodePoints) {
    return WatchlistGroupNameIssue.tooLong;
  }
  if (_forbiddenDisplayCodePoint.hasMatch(trimmed)) {
    return WatchlistGroupNameIssue.invalidCharacters;
  }
  if (groups.any((group) => group.name == trimmed)) {
    return WatchlistGroupNameIssue.duplicate;
  }
  return null;
}

/// The sentence the input field and the editor both show for one issue.
String watchlistGroupNameIssueText(WatchlistGroupNameIssue issue) =>
    switch (issue) {
      WatchlistGroupNameIssue.empty => '分组名称不能为空。',
      WatchlistGroupNameIssue.tooLong =>
        '分组名称最多 $watchlistMaxNameCodePoints 个字符。',
      WatchlistGroupNameIssue.invalidCharacters => '分组名称里有服务端不接受的不可见字符。',
      WatchlistGroupNameIssue.duplicate => '已经有同名分组了。',
      WatchlistGroupNameIssue.groupLimitReached =>
        '分组已达上限 $watchlistMaxGroups 个，先移除一个再新建。',
      WatchlistGroupNameIssue.notEditable => '自选还没有读取成功，暂时不能新建分组。',
    };

/// The first free `g<n>` key, so a new group never collides with an existing
/// one. The key is an identity the owner never sees; the name is what they
/// typed, and the two are deliberately independent.
String nextWatchlistGroupKey(Iterable<String> existingKeys) {
  final taken = existingKeys.toSet();
  for (var index = 1; index <= watchlistMaxGroups + 1; index += 1) {
    final candidate = 'g$index';
    if (!taken.contains(candidate)) return candidate;
  }
  throw const InvalidWatchlistContractException();
}

/// Sanitized validation failure for a value outside the Watchlist contract.
/// The rejected value is deliberately never included in the error.
final class InvalidWatchlistContractException implements Exception {
  const InvalidWatchlistContractException();

  String get code => 'invalid_watchlist_contract';

  @override
  String toString() => 'The Watchlist contract value is invalid';
}

/// One watched asset.
///
/// The identity is the canonical CAIP `assetId` — never a ticker, never an
/// address on its own. [asset] is `null` with a `reasonCode` when the registry
/// can no longer read it; the row is still listed so the owner can remove it.
@immutable
final class WatchlistItem {
  factory WatchlistItem({
    required String assetId,
    LoopAssetSummary? asset,
    String? reasonCode,
  }) {
    if (!loopAssetIdPattern.hasMatch(assetId)) {
      throw const InvalidWatchlistContractException();
    }
    return WatchlistItem._(assetId, asset, reasonCode);
  }

  const WatchlistItem._(this.assetId, this.asset, this.reasonCode);

  final String assetId;
  final LoopAssetSummary? asset;
  final String? reasonCode;

  bool get isReadable => asset != null;

  String get displayName => asset?.symbol ?? loopTruncatedAssetId(assetId);

  String get displayDetail =>
      asset?.name ?? loopReasonCodeText(reasonCode ?? 'ASSET_NOT_READABLE');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchlistItem &&
          other.assetId == assetId &&
          other.asset == asset &&
          other.reasonCode == reasonCode;

  @override
  int get hashCode => Object.hash(assetId, asset, reasonCode);
}

@immutable
final class WatchlistGroup {
  factory WatchlistGroup({
    required String key,
    required String name,
    required Iterable<WatchlistItem> items,
  }) {
    if (!_watchlistGroupKeyPattern.hasMatch(key) ||
        name.length > 256 ||
        _forbiddenDisplayCodePoint.hasMatch(name)) {
      throw const InvalidWatchlistContractException();
    }
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const InvalidWatchlistContractException();
    }
    final copied = List<WatchlistItem>.unmodifiable(items);
    if (copied.length > watchlistMaxItems ||
        copied.map((item) => item.assetId).toSet().length != copied.length) {
      throw const InvalidWatchlistContractException();
    }
    return WatchlistGroup._(key, normalizedName, copied);
  }

  const WatchlistGroup._(this.key, this.name, this.items);

  final String key;
  final String name;
  final List<WatchlistItem> items;

  /// Whether this group's name is short enough for a write. Reads accept the
  /// wider schema bound; only the editor enforces the documented 1–40.
  bool get nameFitsWriteContract =>
      name.runes.isNotEmpty && name.runes.length <= watchlistMaxNameCodePoints;

  WatchlistGroup copyWith({String? name, Iterable<WatchlistItem>? items}) =>
      WatchlistGroup(
        key: key,
        name: name ?? this.name,
        items: items ?? this.items,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchlistGroup &&
          other.key == key &&
          other.name == name &&
          listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(key, name, Object.hashAll(items));
}

/// The whole owner-scoped Watchlist resource with its CAS version.
@immutable
final class WatchlistSnapshot {
  factory WatchlistSnapshot({
    required int version,
    required DateTime? updatedAt,
    required Iterable<WatchlistGroup> groups,
  }) {
    if (version < 0 || version > watchlistMaximumVersion) {
      throw const InvalidWatchlistContractException();
    }
    final copied = List<WatchlistGroup>.unmodifiable(groups);
    if (copied.length > watchlistMaxGroups ||
        copied.map((group) => group.key).toSet().length != copied.length) {
      throw const InvalidWatchlistContractException();
    }
    var total = 0;
    for (final group in copied) {
      total += group.items.length;
    }
    if (total > watchlistMaxItems) {
      throw const InvalidWatchlistContractException();
    }
    return WatchlistSnapshot._(version, updatedAt, copied, total);
  }

  const WatchlistSnapshot._(
    this.version,
    this.updatedAt,
    this.groups,
    this.itemCount,
  );

  final int version;
  final DateTime? updatedAt;
  final List<WatchlistGroup> groups;
  final int itemCount;

  bool get isEmpty => itemCount == 0;

  /// Whether [assetId] is watched in any group. The Watchlist is one list to
  /// the owner even though the resource groups it, so the star on `token`
  /// asks this and never "is it in the default group".
  bool containsAsset(String assetId) =>
      groups.any((group) => group.items.any((item) => item.assetId == assetId));

  /// Assets in Watchlist order, de-duplicated across groups — the same order
  /// `GET /v2/market/overview` returns them in.
  List<String> get orderedAssetIds {
    final seen = <String>{};
    final ordered = <String>[];
    for (final group in groups) {
      for (final item in group.items) {
        if (seen.add(item.assetId)) ordered.add(item.assetId);
      }
    }
    return List<String>.unmodifiable(ordered);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchlistSnapshot &&
          other.version == version &&
          other.updatedAt == updatedAt &&
          listEquals(other.groups, groups);

  @override
  int get hashCode => Object.hash(version, updatedAt, Object.hashAll(groups));
}
