import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/community/search_models.dart';

/// 「最近搜索」 (S187-6, decision 0178): the results the reader opened from the
/// global search, newest first.
///
/// It is a device-local convenience, not an account resource. An entry holds
/// the three things needed to show a name and to open the result again — the
/// server's opaque `stableId`, the result type and the display name it had
/// when it was opened — and nothing else: no avatar, no member count, no
/// price, no follow state. Those are facts that change, and a stored copy of
/// one would be shown as if it were current.
@immutable
final class SearchRecentEntry {
  const SearchRecentEntry({
    required this.type,
    required this.stableId,
    required this.title,
  });

  /// The entry for a result the reader opened.
  factory SearchRecentEntry.fromResult(SearchResult result) =>
      SearchRecentEntry(
        type: result.resultType,
        stableId: result.stableId,
        title: result.title,
      );

  final SearchResultType type;
  final String stableId;
  final String title;

  /// The destination this entry opens, rebuilt from the type alone. An asset
  /// result's `stableId` is its canonical CAIP `assetId` (backend decision
  /// 0071), so no route is ever assembled from [title].
  SearchDestination get destination => switch (type) {
    SearchResultType.user => const SearchPublicProfileDestination(),
    SearchResultType.community => const SearchCommunityProfileDestination(),
    SearchResultType.asset => SearchAssetDestination(stableId),
  };

  /// A result shaped from the entry, so the page opens it through the same
  /// `destination.kind` switch as a live result.
  SearchResult toResult() => SearchResult(
    resultType: type,
    stableId: stableId,
    title: title,
    subtitle: null,
    avatarRef: null,
    memberCount: null,
    verificationStatus: null,
    destination: destination,
  );

  bool sameTarget(SearchRecentEntry other) =>
      other.type == type && other.stableId == stableId;

  @override
  bool operator ==(Object other) =>
      other is SearchRecentEntry &&
      other.type == type &&
      other.stableId == stableId &&
      other.title == title;

  @override
  int get hashCode => Object.hash(type, stableId, title);
}

/// How many entries are kept. The eleventh drops the oldest.
const int searchRecentLimit = 10;

/// The longest id or name accepted back from storage. Anything longer was not
/// written by this build and is dropped rather than shown.
const int _searchRecentFieldLimit = 256;

/// Encodes [entries] as the stored value: a JSON list of `{t, id, n}`.
String encodeSearchRecent(List<SearchRecentEntry> entries) =>
    jsonEncode(<Map<String, String>>[
      for (final entry in entries)
        <String, String>{
          't': entry.type.wireName,
          'id': entry.stableId,
          'n': entry.title,
        },
    ]);

/// Decodes a stored value. Malformed input reads as "nothing stored"; an
/// unknown type or an over-long field drops that one entry; duplicates and
/// entries past [searchRecentLimit] are dropped. It never throws.
List<SearchRecentEntry> decodeSearchRecent(String? raw) {
  if (raw == null || raw.isEmpty) return const <SearchRecentEntry>[];
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const <SearchRecentEntry>[];
  }
  if (decoded is! List) return const <SearchRecentEntry>[];
  final entries = <SearchRecentEntry>[];
  for (final item in decoded) {
    if (entries.length == searchRecentLimit) break;
    if (item is! Map) continue;
    final type = item['t'];
    final id = item['id'];
    final name = item['n'];
    if (type is! String || id is! String || name is! String) continue;
    final parsed = SearchResultType.tryParse(type);
    if (parsed == null) continue;
    if (id.isEmpty || name.trim().isEmpty) continue;
    if (id.length > _searchRecentFieldLimit ||
        name.length > _searchRecentFieldLimit) {
      continue;
    }
    final entry = SearchRecentEntry(type: parsed, stableId: id, title: name);
    if (entries.any(entry.sameTarget)) continue;
    entries.add(entry);
  }
  return List<SearchRecentEntry>.unmodifiable(entries);
}

/// Device-local persistence for 「最近搜索」.
///
/// Reads and writes fail open: a store that cannot answer leaves the list
/// run-local, and the page says nothing was lost because nothing was promised.
abstract interface class SearchRecentStore {
  /// Whether entries outlive the process. The page states it when they do not.
  bool get persistent;

  Future<List<SearchRecentEntry>> read();

  Future<void> write(List<SearchRecentEntry> entries);
}

/// The default: nothing is kept past the run. Tests, the Preview entry point
/// and any composition without device storage use it.
final class RunLocalSearchRecentStore implements SearchRecentStore {
  const RunLocalSearchRecentStore();

  @override
  bool get persistent => false;

  @override
  Future<List<SearchRecentEntry>> read() async => const <SearchRecentEntry>[];

  @override
  Future<void> write(List<SearchRecentEntry> entries) async {}
}

final searchRecentStoreProvider = Provider<SearchRecentStore>(
  (ref) => const RunLocalSearchRecentStore(),
);

/// The page's list of recent entries.
///
/// Only a result from the production gateway is written to the store. A
/// Preview result is kept for the run and never persisted, so a fixture name
/// can never reappear in a production session's 「最近搜索」.
final class SearchRecentController extends Notifier<List<SearchRecentEntry>> {
  var _loaded = false;
  var _touched = false;

  /// Writes are chained so they land in the order they were made.
  Future<void> _writes = Future<void>.value();

  @override
  List<SearchRecentEntry> build() {
    if (!_loaded) {
      _loaded = true;
      unawaited(_load());
    }
    return const <SearchRecentEntry>[];
  }

  bool get _persists =>
      ref.read(searchGatewayProvider).mode == CommunityGatewayMode.production;

  Future<void> _load() async {
    if (!_persists) return;
    final List<SearchRecentEntry> stored;
    try {
      stored = await ref.read(searchRecentStoreProvider).read();
    } on Object {
      return;
    }
    // A change made before the read answered wins over what was stored.
    if (!ref.mounted || _touched) return;
    state = stored;
  }

  /// Records [result] as the newest entry.
  void record(SearchResult result) {
    final entry = SearchRecentEntry.fromResult(result);
    _set(
      <SearchRecentEntry>[
        entry,
        ...state.where((item) => !item.sameTarget(entry)),
      ].take(searchRecentLimit).toList(),
    );
  }

  void remove(SearchRecentEntry entry) =>
      _set(state.where((item) => !item.sameTarget(entry)).toList());

  void clear() => _set(const <SearchRecentEntry>[]);

  void _set(List<SearchRecentEntry> next) {
    _touched = true;
    state = List<SearchRecentEntry>.unmodifiable(next);
    if (!_persists) return;
    final store = ref.read(searchRecentStoreProvider);
    final snapshot = state;
    _writes = _writes.then((_) async {
      try {
        await store.write(snapshot);
      } on Object {
        // Fail open: the list on screen is still the reader's for this run.
      }
    });
  }
}

/// Kept for the life of the app, not of one search page: going back and
/// opening search again shows the same list without another read.
final searchRecentControllerProvider =
    NotifierProvider<SearchRecentController, List<SearchRecentEntry>>(
      SearchRecentController.new,
    );
