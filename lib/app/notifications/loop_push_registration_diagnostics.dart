import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

/// Where this device's push registration stopped, last time it was attempted.
///
/// The registration is a chain of conditions that are true at different
/// moments — an account the backend has accepted, a build with a push
/// provider, a server that has a push runtime, an owner who said yes. Until
/// 2026-09-22 a device that stopped at any of them was indistinguishable from
/// a device that had registered and simply never received anything, both on
/// the device and in the notification-preferences page. This names the step,
/// and nothing else: no token, no address, no session id, no configuration.
enum LoopPushRegistrationGate {
  /// Nothing has been attempted yet in this run.
  notStarted,

  /// No account the backend has accepted. Either nobody is signed in, or the
  /// LOOP identity behind the session has not been established yet.
  noPrincipal,

  /// A platform LOOP registered no push application for.
  noPlatform,

  /// The device-registration port is not the production one: the session, the
  /// client metadata or the session id it needs is missing.
  gatewayNotProduction,

  /// `GET /v2/meta/capabilities` does not call `pushNotifications` available.
  capabilityUnavailable,

  /// This build has no push provider at all, or the provider refused to
  /// answer the permission question.
  tokenSourceDisabled,

  /// The owner has not allowed notifications on this device.
  permissionDenied,

  /// Permission is granted but the provider has not issued a token yet. It is
  /// the ordinary iOS state until APNs answers; the refresh stream finishes
  /// the registration when it does.
  noTokenYet,

  /// The server accepted this device's token.
  registered,

  /// The server answered that it has no push runtime. Not retried.
  runtimeDeferred,

  /// The registration request itself failed.
  registerFailed,
}

/// One observation of [LoopPushRegistrationGate], with when it was made.
@immutable
final class LoopPushRegistrationDiagnostics {
  const LoopPushRegistrationDiagnostics({
    required this.gate,
    required this.observedAt,
    this.failureKind,
  });

  const LoopPushRegistrationDiagnostics.notStarted()
    : gate = LoopPushRegistrationGate.notStarted,
      observedAt = null,
      failureKind = null;

  final LoopPushRegistrationGate gate;

  /// `null` only before the first observation.
  final DateTime? observedAt;

  /// How the registration request failed, when [gate] is
  /// [LoopPushRegistrationGate.registerFailed] and the failure was one LOOP
  /// classifies. `null` means the failure had no kind, not that there was
  /// none.
  final LoopChainFailureKind? failureKind;

  bool get isRegistered => gate == LoopPushRegistrationGate.registered;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopPushRegistrationDiagnostics &&
          other.gate == gate &&
          other.observedAt == observedAt &&
          other.failureKind == failureKind;

  @override
  int get hashCode => Object.hash(gate, observedAt, failureKind);
}

/// The one place the push registration writes down where it got to.
///
/// It is a device-local observation, not a report: nothing is sent anywhere,
/// and the only reader is the notification-preferences page, which turns the
/// step into a sentence about this device.
final class LoopPushRegistrationDiagnosticsRecorder
    extends ValueNotifier<LoopPushRegistrationDiagnostics> {
  LoopPushRegistrationDiagnosticsRecorder({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(const LoopPushRegistrationDiagnostics.notStarted());

  final DateTime Function() _clock;

  void record(
    LoopPushRegistrationGate gate, {
    LoopChainFailureKind? failureKind,
  }) {
    value = LoopPushRegistrationDiagnostics(
      gate: gate,
      observedAt: _clock(),
      failureKind: failureKind,
    );
  }
}
