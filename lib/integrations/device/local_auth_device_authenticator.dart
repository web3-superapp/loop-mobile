import 'package:local_auth/local_auth.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';

/// The one place `local_auth` is spoken to.
///
/// Everything the product reads is a [LoopDeviceAuthCapability] or a
/// [LoopDeviceAuthResult]; the plugin's types, codes and platform messages
/// stop here. LOOP never asks for a biometric *only*: the device passcode is
/// the fallback the owner already has, and it is the system that holds it.
final class LocalAuthDeviceAuthenticator implements LoopDeviceAuthenticator {
  const LocalAuthDeviceAuthenticator([LocalAuthentication? plugin])
    : _plugin = plugin;

  final LocalAuthentication? _plugin;

  LocalAuthentication get _local => _plugin ?? LocalAuthentication();

  @override
  Future<LoopDeviceAuthCapability> readCapability() async {
    final local = _local;
    try {
      // "Supported" here means the system will accept *something* — a
      // biometric or the device credential behind it. A device with neither
      // cannot be asked, and saying so is the honest answer.
      if (!await local.isDeviceSupported()) {
        return const LoopDeviceAuthCapability.unavailable(
          LoopDeviceAuthUnavailableReason.noCredentialSet,
        );
      }
      final biometrics = await local.getAvailableBiometrics();
      return LoopDeviceAuthCapability.available(
        biometrics.isEmpty
            ? LoopDeviceAuthFactor.deviceCredential
            : LoopDeviceAuthFactor.biometric,
      );
    } on Object {
      return const LoopDeviceAuthCapability.unavailable(
        LoopDeviceAuthUnavailableReason.unknown,
      );
    }
  }

  @override
  Future<LoopDeviceAuthResult> authenticate({required String reason}) async {
    try {
      final passed = await _local.authenticate(
        localizedReason: reason,
        // The device passcode stays allowed: it is the 6-digit fallback, and
        // it belongs to the system rather than to LOOP.
        biometricOnly: false,
        // An authentication interrupted by the app switcher is retried on
        // return instead of failing, which is what an unlock prompt should do.
        persistAcrossBackgrounding: true,
      );
      return LoopDeviceAuthResult(
        passed ? LoopDeviceAuthOutcome.succeeded : LoopDeviceAuthOutcome.failed,
      );
    } on LocalAuthException catch (error) {
      return LoopDeviceAuthResult(
        _outcomeFor(error.code),
        systemMessage: error.description,
      );
    } on Object catch (error) {
      return LoopDeviceAuthResult(
        LoopDeviceAuthOutcome.error,
        systemMessage: error.toString(),
      );
    }
  }

  /// The plugin documents this enum as open, so the default is deliberate:
  /// an unrecognised code is an error LOOP reports, never a pass.
  static LoopDeviceAuthOutcome _outcomeFor(LocalAuthExceptionCode code) =>
      switch (code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout => LoopDeviceAuthOutcome.canceled,
        LocalAuthExceptionCode.temporaryLockout ||
        LocalAuthExceptionCode.biometricLockout =>
          LoopDeviceAuthOutcome.lockedOut,
        LocalAuthExceptionCode.noCredentialsSet =>
          LoopDeviceAuthOutcome.unavailable,
        _ => LoopDeviceAuthOutcome.error,
      };
}
