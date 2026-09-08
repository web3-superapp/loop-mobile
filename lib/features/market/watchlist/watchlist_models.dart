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
