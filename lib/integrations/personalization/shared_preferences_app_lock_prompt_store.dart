import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:loop_mobile/features/security/app_lock/app_lock_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _ReadBool = Future<bool?> Function(String key);
typedef _WriteBool = Future<void> Function(String key, bool value);

/// Device-local record that this installation was offered the application
/// lock (decision 0186).
///
/// One installation-scoped Boolean under one exact key. It is not the lock's
/// state — that stays in the secure store — and it never holds an identity,
/// a credential or anything an account owns. Deleting the App deletes it,
/// which is the point: a reinstall is asked again.
class SharedPreferencesLoopAppLockPromptStore
    implements LoopAppLockPromptStore {
  factory SharedPreferencesLoopAppLockPromptStore() {
    final preferences = SharedPreferencesAsync();
    return SharedPreferencesLoopAppLockPromptStore.forTesting(
      preferences.getBool,
      preferences.setBool,
    );
  }

  @visibleForTesting
  const SharedPreferencesLoopAppLockPromptStore.forTesting(
    this._readBool,
    this._writeBool,
  );

  static const String promptedKey = 'loop.display.v1.app_lock_prompted';

  final _ReadBool _readBool;
  final _WriteBool _writeBool;

  @override
  Future<bool?> readPrompted() => _readBool(promptedKey);

  @override
  Future<void> writePrompted() => _writeBool(promptedKey, true);
}

/// The production store, or the unavailable one when the platform store
/// cannot even be constructed: the prompt is then once per run.
LoopAppLockPromptStore createSharedPreferencesAppLockPromptStore() {
  try {
    return SharedPreferencesLoopAppLockPromptStore();
  } on Object {
    return const UnavailableLoopAppLockPromptStore();
  }
}
