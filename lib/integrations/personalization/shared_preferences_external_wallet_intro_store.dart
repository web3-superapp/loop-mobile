import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:loop_mobile/features/wallet/external_wallet_intro_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _ReadBool = Future<bool?> Function(String key);
typedef _WriteBool = Future<void> Function(String key, bool value);

/// Device-local record that this installation read the note in front of
/// 连接外部钱包 (S306, decision 0246). One Boolean under one exact key; a
/// reinstall shows the note again.
class SharedPreferencesLoopExternalWalletIntroStore
    implements LoopExternalWalletIntroStore {
  factory SharedPreferencesLoopExternalWalletIntroStore() {
    final preferences = SharedPreferencesAsync();
    return SharedPreferencesLoopExternalWalletIntroStore.forTesting(
      preferences.getBool,
      preferences.setBool,
    );
  }

  @visibleForTesting
  const SharedPreferencesLoopExternalWalletIntroStore.forTesting(
    this._readBool,
    this._writeBool,
  );

  static const String seenKey = 'loop.display.v1.external_wallet_intro_seen';

  final _ReadBool _readBool;
  final _WriteBool _writeBool;

  @override
  Future<bool?> readSeen() => _readBool(seenKey);

  @override
  Future<void> writeSeen() => _writeBool(seenKey, true);
}

/// The production store, or the unavailable one when the platform store
/// cannot even be constructed: the note is then shown on every tap.
LoopExternalWalletIntroStore createSharedPreferencesExternalWalletIntroStore() {
  try {
    return SharedPreferencesLoopExternalWalletIntroStore();
  } on Object {
    return const UnavailableLoopExternalWalletIntroStore();
  }
}
