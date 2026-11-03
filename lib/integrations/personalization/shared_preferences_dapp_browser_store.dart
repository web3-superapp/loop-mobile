import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:loop_mobile/features/dapp/dapp_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _ReadString = Future<String?> Function(String key);
typedef _WriteString = Future<void> Function(String key, String value);

/// Device-local storage of the DApp browser (S342 · decision 0270): the last
/// 20 pages, the saved pages and the connected origins, in one key.
///
/// It is not an account resource and holds no key, balance or signature.
/// Every read and write fails open after one second: a refusing store leaves
/// the lists run-local, and an unreadable value reads as empty.
class SharedPreferencesDappBrowserStore implements DappBrowserStore {
  factory SharedPreferencesDappBrowserStore() {
    final preferences = SharedPreferencesAsync();
    return SharedPreferencesDappBrowserStore.forTesting(
      preferences.getString,
      preferences.setString,
    );
  }

  @visibleForTesting
  const SharedPreferencesDappBrowserStore.forTesting(
    this._readString,
    this._writeString,
  );

  static const String storageKey = 'loop.dapp.v1.browser';

  static const Duration _budget = Duration(seconds: 1);

  final _ReadString _readString;
  final _WriteString _writeString;

  @override
  bool get persistent => true;

  @override
  Future<DappBrowserLocalState> read() async {
    try {
      return DappBrowserLocalState.decode(
        await _readString(storageKey).timeout(_budget),
      );
    } on Object {
      return DappBrowserLocalState();
    }
  }

  @override
  Future<void> write(DappBrowserLocalState state) async {
    try {
      await _writeString(storageKey, state.encode()).timeout(_budget);
    } on Object {
      // Losing the lists costs one empty first page.
    }
  }
}
