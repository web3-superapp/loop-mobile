import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';

enum PrivacyMode { unavailable, preview, production }

enum PrivacyGatewayFailureKind {
  unavailable,
  offline,
  versionConflict,
  bootstrapRequired,
  validationFailed,
  invalidData,
  unexpected,
}

final class PrivacyGatewayException implements Exception {
  const PrivacyGatewayException(this.kind);

  final PrivacyGatewayFailureKind kind;

  String get code => switch (kind) {
    PrivacyGatewayFailureKind.unavailable => 'privacy_unavailable',
    PrivacyGatewayFailureKind.offline => 'privacy_offline',
    PrivacyGatewayFailureKind.versionConflict => 'privacy_version_conflict',
    PrivacyGatewayFailureKind.bootstrapRequired => 'privacy_bootstrap_required',
    PrivacyGatewayFailureKind.validationFailed => 'privacy_validation_failed',
    PrivacyGatewayFailureKind.invalidData => 'invalid_privacy_data',
    PrivacyGatewayFailureKind.unexpected => 'privacy_request_failed',
  };

  @override
  String toString() => code;
}

abstract interface class PrivacyGateway {
  PrivacyMode get mode;

  Future<PrivacyResource> load();

  Future<PrivacyResource> replace({
    required int expectedVersion,
    required PrivacyValues values,
  });
}

/// Production-safe default while the authenticated Privacy transport is absent.
final class UnavailablePrivacyGateway implements PrivacyGateway {
  const UnavailablePrivacyGateway();

  @override
  PrivacyMode get mode => PrivacyMode.unavailable;

  @override
  Future<PrivacyResource> load() => Future<PrivacyResource>.error(
    const PrivacyGatewayException(PrivacyGatewayFailureKind.unavailable),
  );

  @override
  Future<PrivacyResource> replace({
    required int expectedVersion,
    required PrivacyValues values,
  }) => Future<PrivacyResource>.error(
    const PrivacyGatewayException(PrivacyGatewayFailureKind.unavailable),
  );
}

final privacyGatewayProvider = Provider<PrivacyGateway>(
  (ref) => const UnavailablePrivacyGateway(),
);
