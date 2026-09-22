import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

/// The two platforms LOOP registered a push application for.
///
/// The wire names are the server's, not Dart's: a renamed enum member must not
/// change what `POST /v2/devices/push-token` receives.
enum LoopPushPlatform {
  android('android'),
  ios('ios');

  const LoopPushPlatform(this.wireName);

  final String wireName;

  static LoopPushPlatform? tryParse(String value) {
    for (final platform in values) {
      if (platform.wireName == value) return platform;
    }
    return null;
  }
}

/// What the server answered when it accepted a device's push token.
///
/// `registered` is deliberately kept even though the contract only ever sends
/// `true`: the client must read the server's own answer rather than infer
/// acceptance from a `200`.
@immutable
final class LoopPushTokenRegistration {
  const LoopPushTokenRegistration({
    required this.registered,
    required this.observedAt,
  });

  final bool registered;

  /// When the server observed this token. A registration with no observation
  /// time is not a registration; the decoder refuses the payload instead.
  final DateTime observedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopPushTokenRegistration &&
          other.registered == registered &&
          other.observedAt == observedAt;

  @override
  int get hashCode => Object.hash(registered, observedAt);
}

/// Feature-facing port for the account's push device registration.
///
/// This is not a notification-delivery promise. A registered token means the
/// server knows where it *could* send; whether anything is sent stays with the
/// notification preferences and the server's own push runtime.
abstract interface class PushDeviceGateway {
  LoopChainGatewayMode get mode;

  /// `POST /v2/devices/push-token`.
  Future<LoopPushTokenRegistration> registerToken({
    required LoopPushPlatform platform,
    required String token,
    required String appVersion,
  });

  /// `DELETE /v2/devices/push-token`. Called on sign-out, so the account that
  /// left this device stops being addressable on it.
  Future<void> revokeToken({
    required LoopPushPlatform platform,
    required String token,
  });
}

final class UnavailablePushDeviceGateway implements PushDeviceGateway {
  const UnavailablePushDeviceGateway();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<LoopPushTokenRegistration> registerToken({
    required LoopPushPlatform platform,
    required String token,
    required String appVersion,
  }) => _unavailable();

  @override
  Future<void> revokeToken({
    required LoopPushPlatform platform,
    required String token,
  }) => _unavailable();
}

final pushDeviceGatewayProvider = Provider<PushDeviceGateway>(
  (ref) => const UnavailablePushDeviceGateway(),
);
