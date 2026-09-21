import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';

const _loopAppLockSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    resetOnError: false,
    storageNamespace: 'loop_app_lock',
  ),
  iOptions: IOSOptions(
    accountName: 'com.cywd.loop.app.lock',
    // The lock is this installation's, on this device. It is never synced to
    // another one, where the credential it depends on may not exist.
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  ),
);

/// Where the lock's single boolean lives.
///
/// One value, `'1'` or `'0'`, under one key. There is nothing else to keep:
/// LOOP holds no PIN, no biometric template and nothing derived from either —
/// the device authenticates, and the device keeps what that takes.
final class SecureStorageLoopAppLockStore implements LoopAppLockStore {
  const SecureStorageLoopAppLockStore([FlutterSecureStorage? storage])
    : _storage = storage ?? _loopAppLockSecureStorage;

  static const key = 'loop.app_lock.v1.enabled';

  final FlutterSecureStorage _storage;

  @override
  Future<bool?> read() async {
    final value = await _storage.read(key: key);
    return switch (value) {
      '1' => true,
      '0' => false,
      // Anything else was not written by this build. It is read as "no
      // choice recorded", never as "on".
      _ => null,
    };
  }

  @override
  Future<void> write(bool enabled) =>
      _storage.write(key: key, value: enabled ? '1' : '0');
}
