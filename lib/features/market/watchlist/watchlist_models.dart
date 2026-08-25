import 'package:flutter/foundation.dart';

const int watchlistMaxGroups = 20;
const int watchlistMaxItems = 100;
const int watchlistMaximumVersion = 2147483647;

final RegExp _watchlistGroupKeyPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,31}$');
final RegExp _watchlistAssetKeyPattern = RegExp(r'^[A-Z0-9][A-Z0-9:_-]{0,63}$');

/// Sanitized validation failure for a value outside the backend Watchlist
/// contract. The rejected value is deliberately never included in the error.
final class InvalidWatchlistContractException implements Exception {
  const InvalidWatchlistContractException();

  String get code => 'invalid_watchlist_contract';

  @override
  String toString() => 'The Watchlist contract value is invalid';
}

@immutable
final class WatchlistItem {
  factory WatchlistItem({required String assetKey}) {
    if (!_watchlistAssetKeyPattern.hasMatch(assetKey)) {
      throw const InvalidWatchlistContractException();
    }
    return WatchlistItem._(assetKey);
  }

  const WatchlistItem._(this.assetKey);

  final String assetKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchlistItem && other.assetKey == assetKey;

  @override
  int get hashCode => assetKey.hashCode;
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
        _containsForbiddenDisplayCodePoint(name)) {
      throw const InvalidWatchlistContractException();
    }

    final normalizedName = name.trim();
    if (!_isValidNormalizedDisplayName(normalizedName)) {
      throw const InvalidWatchlistContractException();
    }

    final copiedItems = List<WatchlistItem>.unmodifiable(
      items.map((item) => WatchlistItem(assetKey: item.assetKey)),
    );
    if (copiedItems.length > watchlistMaxItems ||
        copiedItems.map((item) => item.assetKey).toSet().length !=
            copiedItems.length) {
      throw const InvalidWatchlistContractException();
    }

    return WatchlistGroup._(key, normalizedName, copiedItems);
  }

  const WatchlistGroup._(this.key, this.name, this.items);

  final String key;
  final String name;
  final List<WatchlistItem> items;

  WatchlistGroup copyWith({String? name, Iterable<WatchlistItem>? items}) {
    return WatchlistGroup(
      key: key,
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }

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

@immutable
final class WatchlistSnapshot {
  factory WatchlistSnapshot({
    required int version,
    required Iterable<WatchlistGroup> groups,
    required DateTime? updatedAt,
  }) {
    if (version < 0 || version > watchlistMaximumVersion) {
      throw const InvalidWatchlistContractException();
    }
    final copiedGroups = validateWatchlistGroups(groups);
    if (version == 0) {
      if (copiedGroups.isNotEmpty || updatedAt != null) {
        throw const InvalidWatchlistContractException();
      }
    } else if (updatedAt == null) {
      throw const InvalidWatchlistContractException();
    }
    return WatchlistSnapshot._(version, copiedGroups, updatedAt?.toUtc());
  }

  const WatchlistSnapshot._(this.version, this.groups, this.updatedAt);

  factory WatchlistSnapshot.empty() => WatchlistSnapshot(
    version: 0,
    groups: const <WatchlistGroup>[],
    updatedAt: null,
  );

  factory WatchlistSnapshot.copyOf(WatchlistSnapshot source) =>
      WatchlistSnapshot(
        version: source.version,
        groups: source.groups,
        updatedAt: source.updatedAt,
      );

  final int version;
  final List<WatchlistGroup> groups;
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchlistSnapshot &&
          other.version == version &&
          listEquals(other.groups, groups) &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(version, Object.hashAll(groups), updatedAt);
}

/// Returns a defensive, validated copy while preserving group and item order.
List<WatchlistGroup> validateWatchlistGroups(Iterable<WatchlistGroup> groups) {
  final copiedGroups = List<WatchlistGroup>.unmodifiable(
    groups.map(
      (group) =>
          WatchlistGroup(key: group.key, name: group.name, items: group.items),
    ),
  );
  if (copiedGroups.length > watchlistMaxGroups ||
      copiedGroups.map((group) => group.key).toSet().length !=
          copiedGroups.length ||
      copiedGroups.fold<int>(0, (total, group) => total + group.items.length) >
          watchlistMaxItems) {
    throw const InvalidWatchlistContractException();
  }
  return copiedGroups;
}

bool watchlistGroupsEqual(
  Iterable<WatchlistGroup> left,
  Iterable<WatchlistGroup> right,
) {
  return listEquals(
    left.toList(growable: false),
    right.toList(growable: false),
  );
}

bool _isValidNormalizedDisplayName(String value) {
  if (value.isEmpty || _containsForbiddenDisplayCodePoint(value)) return false;
  final codePointLength = value.runes.length;
  return codePointLength >= 1 && codePointLength <= 40;
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
