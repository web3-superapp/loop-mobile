import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:loop_mobile/app/loop_display_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _ReadBool = Future<bool?> Function(String key);
typedef _WriteBool = Future<void> Function(String key, bool value);

/// Device-local storage for LOOP's non-sensitive display preferences only.
///
/// This adapter is deliberately not a generic application database and must
/// never be used for account resources, credentials, wallets, or app-lock
/// state.
class SharedPreferencesLoopDisplayStore implements LoopDisplayPreferencesStore {
  factory SharedPreferencesLoopDisplayStore() {
    final preferences = SharedPreferencesAsync();
    return SharedPreferencesLoopDisplayStore.forTesting(
      preferences.getBool,
      preferences.setBool,
    );
  }

  @visibleForTesting
  const SharedPreferencesLoopDisplayStore.forTesting(
    this._readBool,
    this._writeBool,
  );

  static const String reduceMotionKey = 'loop.display.v1.reduce_motion';

  final _ReadBool _readBool;
  final _WriteBool _writeBool;

  @override
  Future<bool?> readReduceMotion() => _readBool(reduceMotionKey);

  @override
  Future<void> writeReduceMotion(bool value) =>
      _writeBool(reduceMotionKey, value);
}

Future<LoopDisplayPreferencesBootstrap>
bootstrapSharedPreferencesDisplayPreferences({
  Duration timeout = loopDisplayPreferencesIoTimeout,
}) => bootstrapSharedPreferencesDisplayPreferencesForTesting(
  SharedPreferencesLoopDisplayStore.new,
  timeout: timeout,
);

@visibleForTesting
Future<LoopDisplayPreferencesBootstrap>
bootstrapSharedPreferencesDisplayPreferencesForTesting(
  LoopDisplayPreferencesStore Function() createStore, {
  Duration timeout = loopDisplayPreferencesIoTimeout,
}) async {
  try {
    final store = createStore();
    return (
      initial: await loadLoopDisplayPreferences(store, timeout: timeout),
      store: store,
    );
  } on Object {
    return (
      initial: const LoopDisplayPreferences(),
      store: const UnavailableLoopDisplayPreferencesStore(),
    );
  }
}
