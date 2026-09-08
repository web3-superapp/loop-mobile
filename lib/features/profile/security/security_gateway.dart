import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/profile/security/security_models.dart';

/// `security` / `devices` / `key-export` / `social-recovery` port.
///
/// The UI never sees a transport detail: every failure arrives as a
/// [LoopChainException] carrying one narrow [LoopChainFailureKind].
abstract interface class SecurityGateway {
  LoopChainGatewayMode get mode;

  Future<LoopDeviceDirectory> loadDevices();

  /// Revokes one *other* session. Revoking the current session is a step-up
  /// command the server always refuses, so it is not offered here.
  Future<LoopDeviceRevocation> revokeDevice(String sessionId);

  Future<LoopSecurityCapabilities> loadCapabilities();

  Future<LoopSecuritySummary> loadSummary();
}

/// Production-safe default while the authenticated transport is absent.
final class UnavailableSecurityGateway implements SecurityGateway {
  const UnavailableSecurityGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  static Future<T> _closed<T>() => Future<T>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<LoopDeviceDirectory> loadDevices() => _closed<LoopDeviceDirectory>();

  @override
  Future<LoopDeviceRevocation> revokeDevice(String sessionId) =>
      _closed<LoopDeviceRevocation>();

  @override
  Future<LoopSecurityCapabilities> loadCapabilities() =>
      _closed<LoopSecurityCapabilities>();

  @override
  Future<LoopSecuritySummary> loadSummary() => _closed<LoopSecuritySummary>();
}

final securityGatewayProvider = Provider<SecurityGateway>(
  (ref) => const UnavailableSecurityGateway(),
);
