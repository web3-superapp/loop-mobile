import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:loop_mobile/features/community/search_recent.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _ReadString = Future<String?> Function(String key);
typedef _WriteString = Future<void> Function(String key, String value);
typedef _Remove = Future<void> Function(String key);

/// Device-local storage for the global search's 「最近搜索」 (decision 0178).
///
/// One installation-scoped key holds at most ten `{type, stableId, name}`
/// entries. It is not an account resource: no credential, no principal, no
/// price, no follow state and no Preview result is ever written here. Every
/// read and write fails open after one second, like the display store
/// (AGENTS rule 23): a slow or refusing store leaves the list run-local.
class SharedPreferencesSearchRecentStore implements SearchRecentStore {
  factory SharedPreferencesSearchRecentStore() {
    final preferences = SharedPreferencesAsync();
    return SharedPreferencesSearchRecentStore.forTesting(
      preferences.getString,
      preferences.setString,
      preferences.remove,
    );
  }

  @visibleForTesting
  const SharedPreferencesSearchRecentStore.forTesting(
    this._readString,
    this._writeString,
    this._remove,
  );

  static const String recentKey = 'loop.search.v1.recent';

  static const Duration _budget = Duration(seconds: 1);

  final _ReadString _readString;
  final _WriteString _writeString;
  final _Remove _remove;

  @override
  bool get persistent => true;

  @override
  Future<List<SearchRecentEntry>> read() async {
    try {
      return decodeSearchRecent(await _readString(recentKey).timeout(_budget));
    } on Object {
      return const <SearchRecentEntry>[];
    }
  }

  @override
  Future<void> write(List<SearchRecentEntry> entries) async {
    try {
      if (entries.isEmpty) {
        await _remove(recentKey).timeout(_budget);
      } else {
        await _writeString(
          recentKey,
          encodeSearchRecent(entries),
        ).timeout(_budget);
      }
    } on Object {
      // The list is a convenience; losing it costs one empty 「最近搜索」.
    }
  }
}
