import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_models.dart';

enum SocialPrivacyMode { unavailable, preview, production }

enum SocialPrivacyGatewayFailureKind {
  unavailable,
  versionConflict,
  invalidData,
  unexpected,
}

final class SocialPrivacyGatewayException implements Exception {
  const SocialPrivacyGatewayException(this.kind);

  final SocialPrivacyGatewayFailureKind kind;

  String get code => switch (kind) {
    SocialPrivacyGatewayFailureKind.unavailable => 'social_privacy_unavailable',
    SocialPrivacyGatewayFailureKind.versionConflict =>
      'social_privacy_version_conflict',
    SocialPrivacyGatewayFailureKind.invalidData =>
      'invalid_social_privacy_data',
    SocialPrivacyGatewayFailureKind.unexpected =>
      'social_privacy_request_failed',
  };

  @override
  String toString() => code;
}

abstract interface class SocialPrivacyGateway {
  SocialPrivacyMode get mode;

  Future<SocialPrivacyResource> load();

  Future<SocialPrivacyResource> replace({
    required int expectedVersion,
    required SocialPrivacyValues values,
  });
}

/// Production-safe default while the authenticated Social Privacy transport is
/// absent.
final class UnavailableSocialPrivacyGateway implements SocialPrivacyGateway {
  const UnavailableSocialPrivacyGateway();

  @override
  SocialPrivacyMode get mode => SocialPrivacyMode.unavailable;

  @override
  Future<SocialPrivacyResource> load() => Future<SocialPrivacyResource>.error(
    const SocialPrivacyGatewayException(
      SocialPrivacyGatewayFailureKind.unavailable,
    ),
  );

  @override
  Future<SocialPrivacyResource> replace({
    required int expectedVersion,
    required SocialPrivacyValues values,
  }) => Future<SocialPrivacyResource>.error(
    const SocialPrivacyGatewayException(
      SocialPrivacyGatewayFailureKind.unavailable,
    ),
  );
}

final socialPrivacyGatewayProvider = Provider<SocialPrivacyGateway>(
  (ref) => const UnavailableSocialPrivacyGateway(),
);
