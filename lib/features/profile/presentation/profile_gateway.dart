import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';

enum ProfileMode { unavailable, preview, production }

enum ProfileGatewayFailureKind {
  unavailable,
  offline,

  /// `403 PERMISSION_DENIED` / `POLICY_BLOCKED` / `REGION_BLOCKED`: the server
  /// knows the owner and still refuses. It is a policy answer, never a
  /// retryable transport fault.
  permissionDenied,

  /// `403 AUTH_STEP_UP_REQUIRED`: the command needs a second factor. Step-up
  /// is not delivered, so the only honest next step is the security centre.
  stepUpRequired,
  versionConflict,
  idempotencyConflict,
  bootstrapRequired,
  validationFailed,
  aliasReserved,
  aliasBlocked,
  invalidData,
  unexpected,
}

final class ProfileGatewayException implements Exception {
  const ProfileGatewayException(this.kind);

  final ProfileGatewayFailureKind kind;

  String get code => switch (kind) {
    ProfileGatewayFailureKind.unavailable => 'profile_unavailable',
    ProfileGatewayFailureKind.offline => 'profile_offline',
    ProfileGatewayFailureKind.permissionDenied => 'profile_permission_denied',
    ProfileGatewayFailureKind.stepUpRequired => 'profile_step_up_required',
    ProfileGatewayFailureKind.versionConflict => 'profile_version_conflict',
    ProfileGatewayFailureKind.idempotencyConflict =>
      'profile_idempotency_conflict',
    ProfileGatewayFailureKind.bootstrapRequired => 'profile_bootstrap_required',
    ProfileGatewayFailureKind.validationFailed => 'profile_validation_failed',
    ProfileGatewayFailureKind.aliasReserved => 'profile_alias_reserved',
    ProfileGatewayFailureKind.aliasBlocked => 'profile_alias_blocked',
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

/// One-time public-profile activation (`POST /v2/profile/loop-id`).
///
/// Separated from [ProfileGateway] because activation is a write command with
/// an idempotency key, not an optimistic-concurrency replace.
abstract interface class ProfileActivationGateway {
  ProfileMode get mode;

  /// Activates the owner's public profile. The implementation owns the durable
  /// idempotency record: an identical retry must reuse the original key and
  /// the original body, including the submitted interest order.
  Future<ProfileResource> activate({
    required String alias,
    required String? avatarRef,
    required List<ProfileInterest> interests,
  });
}

final class UnavailableProfileActivationGateway
    implements ProfileActivationGateway {
  const UnavailableProfileActivationGateway();

  @override
  ProfileMode get mode => ProfileMode.unavailable;

  @override
  Future<ProfileResource> activate({
    required String alias,
    required String? avatarRef,
    required List<ProfileInterest> interests,
  }) => Future<ProfileResource>.error(
    const ProfileGatewayException(ProfileGatewayFailureKind.unavailable),
  );
}

final profileActivationGatewayProvider = Provider<ProfileActivationGateway>(
  (ref) => const UnavailableProfileActivationGateway(),
);
