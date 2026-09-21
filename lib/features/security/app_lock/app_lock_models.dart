import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What this device can use to prove the person holding it is the owner.
///
/// LOOP does not invent a credential of its own. The lock asks the operating
/// system, which answers with whatever the owner already set up: a face, a
/// fingerprint, or the device passcode / PIN / pattern that stands behind
/// them. Nothing is stored, derived or compared by LOOP.
enum LoopDeviceAuthFactor {
  /// A biometric is enrolled and offered first.
  biometric,

  /// No biometric is enrolled, but the device has a passcode, PIN or pattern
  /// the system will ask for instead. This is the 6-digit fallback: it is the
  /// system's own, so LOOP never holds a PIN.
  deviceCredential,
}

/// Why this device cannot be asked to authenticate.
enum LoopDeviceAuthUnavailableReason {
  /// The device has no screen lock at all: no biometric, no passcode.
  noCredentialSet,

  /// The platform has no local authentication for LOOP to call.
  unsupportedPlatform,

  /// The capability could not be read. It is not "no": it is "not known".
  unknown,
}

@immutable
final class LoopDeviceAuthCapability {
  const LoopDeviceAuthCapability.available(this.factor)
    : unavailableReason = null;

  const LoopDeviceAuthCapability.unavailable(this.unavailableReason)
    : factor = null;

  /// The strongest factor the system will offer, or `null` when it will offer
  /// none.
  final LoopDeviceAuthFactor? factor;

  final LoopDeviceAuthUnavailableReason? unavailableReason;

  bool get isAvailable => factor != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopDeviceAuthCapability &&
          other.factor == factor &&
          other.unavailableReason == unavailableReason;

  @override
  int get hashCode => Object.hash(factor, unavailableReason);
}

/// How one authentication attempt ended.
///
/// `failed` and `canceled` are different facts and are kept apart: one is the
/// system saying "that was not you", the other is the owner saying "not now".
/// Neither is ever reported as an unlocked App.
enum LoopDeviceAuthOutcome {
  succeeded,
  failed,
  canceled,

  /// Too many attempts; the system has closed the door for a while.
  lockedOut,

  /// The device turned out to have nothing to authenticate with.
  unavailable,

  /// The platform reported an error. The description, when there is one, is
  /// the system's own and is shown as such.
  error,
}

@immutable
final class LoopDeviceAuthResult {
  const LoopDeviceAuthResult(this.outcome, {this.systemMessage});

  final LoopDeviceAuthOutcome outcome;

  /// What the platform said, verbatim, when it said anything. LOOP does not
  /// translate it into a promise of its own.
  final String? systemMessage;

  bool get succeeded => outcome == LoopDeviceAuthOutcome.succeeded;
}

/// The device's own authentication, as a port.
///
/// The one implementation that talks to `local_auth` lives in
/// `lib/integrations/device/`; nothing under `lib/features/` may import the
/// plugin.
abstract interface class LoopDeviceAuthenticator {
  Future<LoopDeviceAuthCapability> readCapability();

  /// Asks the system to authenticate the owner. [reason] is shown by the
  /// system prompt and must say what it is for.
  Future<LoopDeviceAuthResult> authenticate({required String reason});
}

/// A device that cannot authenticate anybody.
///
/// The default for any composition that installed no adapter, so a tree that
/// forgot to wire one offers the lock as unavailable instead of claiming it.
final class UnavailableLoopDeviceAuthenticator
    implements LoopDeviceAuthenticator {
  const UnavailableLoopDeviceAuthenticator();

  @override
  Future<LoopDeviceAuthCapability> readCapability() async =>
      const LoopDeviceAuthCapability.unavailable(
        LoopDeviceAuthUnavailableReason.unsupportedPlatform,
      );

  @override
  Future<LoopDeviceAuthResult> authenticate({required String reason}) async =>
      const LoopDeviceAuthResult(LoopDeviceAuthOutcome.unavailable);
}

/// Where the one bit the lock persists is kept.
///
/// One boolean per installation: whether the owner turned the lock on. It is
/// not an account resource, it proves no enrolment, and it never carries a
/// PIN, a biometric template or anything derived from one — LOOP has no such
/// material to store.
abstract interface class LoopAppLockStore {
  Future<bool?> read();

  Future<void> write(bool enabled);
}

final class UnavailableLoopAppLockStore implements LoopAppLockStore {
  const UnavailableLoopAppLockStore();

  @override
  Future<bool?> read() async => null;

  @override
  Future<void> write(bool enabled) async =>
      throw UnsupportedError('app_lock_store_unavailable');
}

final class InMemoryLoopAppLockStore implements LoopAppLockStore {
  InMemoryLoopAppLockStore([this._enabled]);

  bool? _enabled;

  @override
  Future<bool?> read() async => _enabled;

  @override
  Future<void> write(bool enabled) async => _enabled = enabled;
}

final loopDeviceAuthenticatorProvider = Provider<LoopDeviceAuthenticator>(
  (ref) => const UnavailableLoopDeviceAuthenticator(),
);

final loopAppLockStoreProvider = Provider<LoopAppLockStore>(
  (ref) => const UnavailableLoopAppLockStore(),
);
