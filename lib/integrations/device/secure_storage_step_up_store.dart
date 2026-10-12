import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';

const _loopStepUpSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    resetOnError: false,
    storageNamespace: 'loop_step_up',
  ),
  iOptions: IOSOptions(
    accountName: 'com.cywd.loop.step_up',
    // The rule leans on this device's own authentication, so it is this
    // device's: never synced to another one.
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  ),
);

typedef _Read = Future<String?> Function(String key);
typedef _Write = Future<void> Function(String key, String value);

/// Where the large-amount step-up's two choices live (decision 0152).
///
/// One value per account, `1:1000` or `0:1000`, under a key partitioned by
/// [LoopV2OwnerPartition] — the same opaque per-account value the V2 session
/// journal and the opening sequence use — so one account's rule is never
/// read for another and the raw principal never reaches storage. It is kept
/// in the platform's secure storage rather than plain preferences because
/// switching it off is exactly what someone holding an unlocked phone would
/// want to do quietly.
final class SecureStorageLoopStepUpSettingsStore
    implements LoopStepUpSettingsStore {
  factory SecureStorageLoopStepUpSettingsStore([
    FlutterSecureStorage? storage,
  ]) {
    final secure = storage ?? _loopStepUpSecureStorage;
    return SecureStorageLoopStepUpSettingsStore.forTesting(
      (key) => secure.read(key: key),
      (key, value) => secure.write(key: key, value: value),
    );
  }

  @visibleForTesting
  const SecureStorageLoopStepUpSettingsStore.forTesting(
    this._read,
    this._write,
  );

  static const String keyPrefix = 'loop.step_up.v1.';

  final _Read _read;
  final _Write _write;

  /// The key for [principalKey], or `null` when it cannot be partitioned.
  static String? keyFor(String principalKey) {
    try {
      return '$keyPrefix${LoopV2OwnerPartition.fromPrincipal(principalKey)}';
    } on Object {
      return null;
    }
  }

  @override
  Future<LoopStepUpSettings?> read(String principalKey) async {
    final key = keyFor(principalKey);
    if (key == null) return null;
    return LoopStepUpSettings.tryDecode(await _read(key));
  }

  @override
  Future<void> write(String principalKey, LoopStepUpSettings settings) async {
    final key = keyFor(principalKey);
    if (key == null) throw StateError('step_up_partition_unavailable');
    await _write(key, settings.encode());
  }
}
