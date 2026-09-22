import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

/// The two platforms LOOP registered a push application for.
///
/// The wire names are the server's, not Dart's: a renamed enum member must not
/// change what `POST /v2/devices/push-token` receives, and the value must
/// equal the `X-Loop-Platform` header on the same request.
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
    required this.pushTokenId,
    required this.platform,
    required this.provider,
    required this.appVersion,
    required this.observedAt,
  });

  /// Decision 0067: every platform is delivered through Firebase. iOS reaches
  /// APNs from there, using the key uploaded to the same Firebase project, so
  /// LOOP never sends an APNs device token to its own backend.
  static const String firebaseProvider = 'fcm';

  final bool registered;

  /// The server's row id for this device's token. The same session resending
  /// the same token keeps the same id and only refreshes [observedAt]; a new
  /// token, or the same token on another session, retires the old row and
  /// answers with a new id.
  final String pushTokenId;

  final LoopPushPlatform platform;
  final String provider;
  final String appVersion;

  /// When the server observed this token. A registration with no observation
  /// time is not a registration; the decoder refuses the payload instead.
  final DateTime observedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopPushTokenRegistration &&
          other.registered == registered &&
          other.pushTokenId == pushTokenId &&
          other.platform == platform &&
          other.provider == provider &&
          other.appVersion == appVersion &&
          other.observedAt == observedAt;

  @override
  int get hashCode => Object.hash(
    registered,
    pushTokenId,
    platform,
    provider,
    appVersion,
    observedAt,
  );
}

/// What the server answered when this session's token was dropped.
///
/// `revokedAt` is null when there was nothing to revoke. That is a `200`, not
/// a failure: the request asked for a state, not for an event.
@immutable
final class LoopPushTokenRevocation {
  const LoopPushTokenRevocation({
    required this.registered,
    required this.revokedAt,
    required this.observedAt,
  });

  final bool registered;
  final DateTime? revokedAt;
  final DateTime observedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopPushTokenRevocation &&
          other.registered == registered &&
          other.revokedAt == revokedAt &&
          other.observedAt == observedAt;

  @override
  int get hashCode => Object.hash(registered, revokedAt, observedAt);
}

/// Feature-facing port for the account's push device registration.
///
/// This is not a notification-delivery promise. A registered token means the
/// server knows where it *could* send; whether anything is sent stays with the
/// notification preferences and the server's own push runtime.
abstract interface class PushDeviceGateway {
  LoopChainGatewayMode get mode;

  /// `POST /v2/devices/push-token`.
  ///
  /// [token] is the Firebase registration token on both platforms.
  Future<LoopPushTokenRegistration> registerToken({
    required LoopPushPlatform platform,
    required String token,
    required String appVersion,
  });

  /// `DELETE /v2/devices/push-token`.
  ///
  /// It carries no body and names no token: the server drops whatever this
  /// device session registered. Sign-out and remote revocation already void
  /// the row in the same transaction, so this is local tidiness rather than a
  /// step logout depends on.
  Future<LoopPushTokenRevocation> revokeToken();
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
  Future<LoopPushTokenRevocation> revokeToken() => _unavailable();
}

final pushDeviceGatewayProvider = Provider<PushDeviceGateway>(
  (ref) => const UnavailablePushDeviceGateway(),
);
