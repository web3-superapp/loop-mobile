import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:loop_mobile/features/dapp/dapp_store.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _ReadString = Future<String?> Function(String key);
typedef _WriteString = Future<void> Function(String key, String value);
typedef _Remove = Future<void> Function(String key);

/// Device-local storage of the DApp browser (S342 · decision 0270): the last
/// 20 pages, the saved pages and the connected sites.
///
/// S346 · M3: one key per account, partitioned by [LoopV2OwnerPartition] —
/// the same opaque per-account value the V2 session journal and the opening
/// sequence use — so one account's sites are never read for another and the
/// raw Privy principal never reaches SharedPreferences. The single shared
/// key of the first build is dropped, unread: it cannot say whose it was.
///
/// It holds no key, balance or signature. Every read and write fails open
/// after one second: a refusing store leaves the lists run-local, and an
/// unreadable value reads as empty.
class SharedPreferencesDappBrowserStore implements DappBrowserStore {
  factory SharedPreferencesDappBrowserStore() {
    final preferences = SharedPreferencesAsync();
    return SharedPreferencesDappBrowserStore.forTesting(
      preferences.getString,
      preferences.setString,
      preferences.remove,
    );
  }

  @visibleForTesting
  SharedPreferencesDappBrowserStore.forTesting(
    this._readString,
    this._writeString,
    this._remove,
  );

  /// The unpartitioned key of the S342 build.
  static const String legacyKey = 'loop.dapp.v1.browser';

  static const String keyPrefix = 'loop.dapp.v2.browser.';

  static const Duration _budget = Duration(seconds: 1);

  final _ReadString _readString;
  final _WriteString _writeString;
  final _Remove _remove;
  bool _legacyDropped = false;

  /// The key of [account]'s partition, or `null` when it has none.
  static String? keyFor(String? account) {
    if (account == null) return null;
    try {
      return '$keyPrefix${LoopV2OwnerPartition.fromPrincipal(account)}';
    } on Object {
      return null;
    }
  }

  @override
  bool get persistent => true;

  Future<void> _dropLegacy() async {
    if (_legacyDropped) return;
    _legacyDropped = true;
    try {
      await _remove(legacyKey).timeout(_budget);
    } on Object {
      _legacyDropped = false;
    }
  }

  @override
  Future<DappBrowserLocalState> read(String? account) async {
    await _dropLegacy();
    final key = keyFor(account);
    if (key == null) return DappBrowserLocalState();
    try {
      return DappBrowserLocalState.decode(
        await _readString(key).timeout(_budget),
      );
    } on Object {
      return DappBrowserLocalState();
    }
  }

  @override
  Future<void> write(String? account, DappBrowserLocalState state) async {
    final key = keyFor(account);
    if (key == null) return;
    try {
      await _writeString(key, state.encode()).timeout(_budget);
    } on Object {
      // Losing the lists costs one empty first page.
    }
  }

  @override
  Future<void> forgetAccount(String account) async {
    final key = keyFor(account);
    if (key == null) return;
    final state = await read(account);
    try {
      if (state.bookmarks.isEmpty) {
        await _remove(key).timeout(_budget);
      } else {
        await _writeString(
          key,
          DappBrowserLocalState(bookmarks: state.bookmarks).encode(),
        ).timeout(_budget);
      }
    } on Object {
      // The partition is the account's own; nobody else reads it.
    }
  }
}
