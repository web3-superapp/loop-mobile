import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';

enum ProfileMode { unavailable, preview, production }

enum ProfileGatewayFailureKind {
  unavailable,
  versionConflict,
  invalidData,
  unexpected,
}

final class ProfileGatewayException implements Exception {
  const ProfileGatewayException(this.kind);

  final ProfileGatewayFailureKind kind;

  String get code => switch (kind) {
    ProfileGatewayFailureKind.unavailable => 'profile_unavailable',
    ProfileGatewayFailureKind.versionConflict => 'profile_version_conflict',
    ProfileGatewayFailureKind.invalidData => 'invalid_profile_data',
    ProfileGatewayFailureKind.unexpected => 'profile_request_failed',
  };

  @override
  String toString() => code;
}

abstract interface class ProfileGateway {
  ProfileMode get mode;

  Future<ProfileResource> load();

  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  });
}

/// Production-safe default while the authenticated Profile transport is absent.
final class UnavailableProfileGateway implements ProfileGateway {
  const UnavailableProfileGateway();

  @override
  ProfileMode get mode => ProfileMode.unavailable;

  @override
  Future<ProfileResource> load() => Future<ProfileResource>.error(
    const ProfileGatewayException(ProfileGatewayFailureKind.unavailable),
  );

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) => Future<ProfileResource>.error(
    const ProfileGatewayException(ProfileGatewayFailureKind.unavailable),
  );
}

final profileGatewayProvider = Provider<ProfileGateway>(
  (ref) => const UnavailableProfileGateway(),
);
