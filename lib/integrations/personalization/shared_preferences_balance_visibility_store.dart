import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:loop_mobile/app/loop_balance_visibility.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _ReadBool = Future<bool?> Function(String key);
typedef _WriteBool = Future<void> Function(String key, bool value);

/// Device-local storage for the 「隐藏余额」 display choice only (decision
/// 0175).
///
/// One installation-scoped Boolean under one exact key. It never holds a
/// figure, a wallet, an identity or anything an account owns.
class SharedPreferencesLoopBalanceVisibilityStore
    implements LoopBalanceVisibilityStore {
  factory SharedPreferencesLoopBalanceVisibilityStore() {
    final preferences = SharedPreferencesAsync();
    return SharedPreferencesLoopBalanceVisibilityStore.forTesting(
      preferences.getBool,
      preferences.setBool,
    );
  }

  @visibleForTesting
  const SharedPreferencesLoopBalanceVisibilityStore.forTesting(
    this._readBool,
    this._writeBool,
  );

  static const String hideBalanceKey = 'loop.display.v1.hide_balance';

  final _ReadBool _readBool;
  final _WriteBool _writeBool;

  @override
  Future<bool?> readHideBalance() => _readBool(hideBalanceKey);

  @override
  Future<void> writeHideBalance(bool value) =>
      _writeBool(hideBalanceKey, value);
}

/// The production store, or the unavailable one when the platform store
/// cannot even be constructed: the choice then stays run-local.
LoopBalanceVisibilityStore createSharedPreferencesBalanceVisibilityStore() {
  try {
    return SharedPreferencesLoopBalanceVisibilityStore();
  } on Object {
    return const UnavailableLoopBalanceVisibilityStore();
  }
}
