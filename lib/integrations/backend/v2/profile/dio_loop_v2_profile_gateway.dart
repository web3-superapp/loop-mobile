import 'package:loop_mobile/features/profile/presentation/avatar_catalog.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/loop_v2_activation_store.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/loop_v2_profile_api.dart';
import 'package:uuid/uuid.dart';

/// Authenticated V2 adapter for the owner-scoped Profile resource.
///
/// The access token is supplied by [LoopAuthenticatedSession] for exactly one
/// immediate request. This adapter owns no credential cache and no generic
/// transport retry.
final class DioLoopV2ProfileGateway implements ProfileGateway {
  DioLoopV2ProfileGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
  });

  final LoopV2ProfileApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;

  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() => _execute(
    (accessToken) => _api.getProfile(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
    ),
  );

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) async {
    if (expectedVersion < 0 || expectedVersion > profileMaximumVersion) {
      throw const ProfileGatewayException(
        ProfileGatewayFailureKind.invalidData,
      );
    }
    late final ProfileValues candidate;
    try {
      candidate = ProfileValues.copyOf(values);
    } on InvalidProfileContractException {
      throw const ProfileGatewayException(
        ProfileGatewayFailureKind.invalidData,
      );
    }
    return _execute(
      (accessToken) => _api.replaceProfile(
        accessToken: accessToken,
        clientVersion: _clientMetadata.clientVersion,
        expectedVersion: expectedVersion,
        values: candidate,
      ),
    );
  }

  Future<ProfileResource> _execute(
    Future<ProfileResource> Function(String accessToken) request,
  ) => executeProfileRequest(_session, request);
}

/// One-time activation with a durable idempotency record.
///
/// The command key and the exact request body are persisted before dispatch,
/// mirroring the bootstrap journal. A retry of the same logical activation
/// replays the original key and the original bytes; a changed body is a new
/// logical activation and receives a new key, which can never collide with the
/// recorded one.
final class DioLoopV2ProfileActivationGateway
    implements ProfileActivationGateway {
  DioLoopV2ProfileActivationGateway({
    required String principalKey,
    required LoopV2ProfileApi api,
    required LoopV2ClientMetadata clientMetadata,
    required LoopV2ActivationJournalStore store,
    required LoopAuthenticatedSession session,
    Uuid uuid = const Uuid(),
  }) : _ownerPartition = LoopV2OwnerPartition.fromPrincipal(
         principalKey,
         uuid: uuid,
       ),
       // ignore: prefer_initializing_formals
       _api = api,
       // ignore: prefer_initializing_formals
       _clientMetadata = clientMetadata,
       // ignore: prefer_initializing_formals
       _store = store,
       // ignore: prefer_initializing_formals
       _session = session,
       _uuid = uuid;

  final String _ownerPartition;
  final LoopV2ProfileApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopV2ActivationJournalStore _store;
  final LoopAuthenticatedSession _session;
  final Uuid _uuid;

  Future<ProfileResource>? _inFlight;

  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> activate({
    required String alias,
    required String? avatarRef,
    required List<ProfileInterest> interests,
  }) {
    final active = _inFlight;
    if (active != null) return active;
    late final Future<ProfileResource> operation;
    operation =
        _activate(
          alias: alias,
          avatarRef: avatarRef,
          interests: interests,
        ).whenComplete(() {
          if (identical(_inFlight, operation)) _inFlight = null;
        });
    _inFlight = operation;
    return operation;
  }

  Future<ProfileResource> _activate({
    required String alias,
    required String? avatarRef,
    required List<ProfileInterest> interests,
  }) async {
    late final LoopV2ActivationRequest request;
    try {
      // The contract validation lives in the shared model so the recorded
      // body can never differ from what the model would accept.
      final values = ProfileValues(
        alias: alias,
        avatarRef: avatarRef,
        interests: interests,
      );
      final normalizedAlias = values.alias;
      if (normalizedAlias == null) {
        throw const InvalidProfileContractException();
      }
      request = LoopV2ActivationRequest(
        alias: normalizedAlias,
        // A V1 row's non-preset reference is readable but not submittable.
        avatarRef: profileSubmittableAvatarRef(values.avatarRef),
        interests: values.interests,
      );
    } on InvalidProfileContractException {
      throw const ProfileGatewayException(
        ProfileGatewayFailureKind.invalidData,
      );
    }

    LoopV2ActivationRecord record;
    try {
      final deviceId = await _store.loadOrCreateDeviceId();
      final stored = await _store.readRecord(_ownerPartition);
      final reusable =
          stored != null &&
          stored.request == request &&
          stored.command.deviceId == deviceId &&
          stored.command.platform == _clientMetadata.platform &&
          stored.command.clientVersion == _clientMetadata.clientVersion &&
          stored.command.contractVersion ==
              LoopV2ClientMetadata.contractVersion;
      if (reusable) {
        record = stored;
      } else {
        record = LoopV2ActivationRecord(
          command: LoopV2CommandMetadata(
            deviceId: deviceId,
            idempotencyKey: _uuid.v4().toLowerCase(),
            clientVersion: _clientMetadata.clientVersion,
            platform: _clientMetadata.platform,
          ),
          request: request,
        );
        await _store.writeRecord(_ownerPartition, record);
      }
    } on LoopV2SessionStorageException {
      throw const ProfileGatewayException(
        ProfileGatewayFailureKind.unavailable,
      );
    }

    final resource = await executeProfileRequest(
      _session,
      (accessToken) => _api.activateLoopId(
        accessToken: accessToken,
        command: record.command,
        request: record.request,
      ),
      onTerminalRejection: () async {
        // A rejected body is never replayed under the same key.
        try {
          await _store.deleteRecord(_ownerPartition);
        } on LoopV2SessionStorageException {
          // The next attempt rewrites the record before dispatch.
        }
      },
    );

    try {
      await _store.deleteRecord(_ownerPartition);
    } on LoopV2SessionStorageException {
      // The server already applied the activation; a stale record only
      // replays the same idempotent command.
    }
    return resource;
  }
}

/// Authenticated V2 adapter for owner-only Privacy preferences.
final class DioLoopV2PrivacyGateway implements PrivacyGateway {
  DioLoopV2PrivacyGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
  });

  final LoopV2ProfileApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;

  @override
  PrivacyMode get mode => PrivacyMode.production;

  @override
  Future<PrivacyResource> load() => _execute(
    (accessToken) => _api.getPrivacy(
      accessToken: accessToken,
      clientVersion: _clientMetadata.clientVersion,
    ),
  );

  @override
  Future<PrivacyResource> replace({
    required int expectedVersion,
    required PrivacyValues values,
  }) {
    if (expectedVersion < 0 || expectedVersion > privacyMaximumVersion) {
      return Future<PrivacyResource>.error(
        const PrivacyGatewayException(PrivacyGatewayFailureKind.invalidData),
      );
    }
    final candidate = PrivacyValues.copyOf(values);
    return _execute(
      (accessToken) => _api.replacePrivacy(
        accessToken: accessToken,
        clientVersion: _clientMetadata.clientVersion,
        expectedVersion: expectedVersion,
        values: candidate,
      ),
    );
  }

  Future<PrivacyResource> _execute(
    Future<PrivacyResource> Function(String accessToken) request,
  ) async {
    try {
      return await _session.execute(request);
    } on LoopBackendFailure catch (failure) {
      throw PrivacyGatewayException(privacyFailureKindForV2(failure));
    } on InvalidPrivacyContractException {
      throw const PrivacyGatewayException(
        PrivacyGatewayFailureKind.invalidData,
      );
    } catch (_) {
      throw const PrivacyGatewayException(PrivacyGatewayFailureKind.unexpected);
    }
  }
}

/// Public read-only catalog of the preset avatars a client may submit.
///
/// No access token is used and no fallback list exists: a failure keeps the
/// avatar picker unavailable rather than inventing references the backend
/// would reject.
final class LoopV2AvatarCatalogRepository implements AvatarCatalogGateway {
  LoopV2AvatarCatalogRepository(this._api);

  final LoopV2ProfileApi _api;

  @override
  Future<List<AvatarPreset>> load() async {
    try {
      final presets = await _api.getAvatars();
      return List<AvatarPreset>.unmodifiable(<AvatarPreset>[
        for (final preset in presets)
          AvatarPreset(
            avatarRef: preset.avatarRef,
            atlas: preset.atlas,
            slot: preset.slot,
            label: preset.label,
          ),
      ]);
    } on LoopBackendFailure catch (failure) {
      throw AvatarCatalogException(switch (failure.kind) {
        LoopBackendFailureKind.connection ||
        LoopBackendFailureKind.timeout => AvatarCatalogFailureKind.offline,
        LoopBackendFailureKind.invalidPayload =>
          AvatarCatalogFailureKind.invalidData,
        LoopBackendFailureKind.unavailable ||
        LoopBackendFailureKind.invalidConfiguration =>
          AvatarCatalogFailureKind.unavailable,
        _ => AvatarCatalogFailureKind.unexpected,
      });
    } catch (_) {
      throw const AvatarCatalogException(AvatarCatalogFailureKind.unexpected);
    }
  }
}

/// Runs one authenticated Profile request and maps every transport failure to
/// the narrow feature-facing kind.
Future<ProfileResource> executeProfileRequest(
  LoopAuthenticatedSession session,
  Future<ProfileResource> Function(String accessToken) request, {
  Future<void> Function()? onTerminalRejection,
}) async {
  try {
    return await session.execute(request);
  } on LoopBackendFailure catch (failure) {
    final kind = profileFailureKindForV2(failure);
    if (onTerminalRejection != null && _isTerminalRejection(kind)) {
      await onTerminalRejection();
    }
    throw ProfileGatewayException(kind);
  } on InvalidProfileContractException {
    if (onTerminalRejection != null) await onTerminalRejection();
    throw const ProfileGatewayException(ProfileGatewayFailureKind.invalidData);
  } catch (_) {
    throw const ProfileGatewayException(ProfileGatewayFailureKind.unexpected);
  }
}

/// A rejection the recorded command can never recover from.
///
/// `IDEMPOTENCY_CONFLICT` is terminal for the recorded key: the backend has
/// already bound it to different bytes, so replaying it can only conflict
/// again. Clearing the record lets the next attempt generate a fresh key.
bool _isTerminalRejection(ProfileGatewayFailureKind kind) =>
    kind == ProfileGatewayFailureKind.validationFailed ||
    kind == ProfileGatewayFailureKind.aliasReserved ||
    kind == ProfileGatewayFailureKind.aliasBlocked ||
    kind == ProfileGatewayFailureKind.idempotencyConflict ||
    kind == ProfileGatewayFailureKind.invalidData;

ProfileGatewayFailureKind profileFailureKindForV2(LoopBackendFailure failure) {
  return switch (failure.code) {
    'ALIAS_RESERVED' => ProfileGatewayFailureKind.aliasReserved,
    'ALIAS_BLOCKED' => ProfileGatewayFailureKind.aliasBlocked,
    'VALIDATION_FAILED' => ProfileGatewayFailureKind.validationFailed,
    'VERSION_CONFLICT' => ProfileGatewayFailureKind.versionConflict,
    'IDEMPOTENCY_CONFLICT' => ProfileGatewayFailureKind.idempotencyConflict,
    'ACCOUNT_BOOTSTRAP_REQUIRED' => ProfileGatewayFailureKind.bootstrapRequired,
    'INVALID_REQUEST' => ProfileGatewayFailureKind.invalidData,
    _ => switch (failure.kind) {
      LoopBackendFailureKind.connection ||
      LoopBackendFailureKind.timeout => ProfileGatewayFailureKind.offline,
      LoopBackendFailureKind.invalidPayload =>
        ProfileGatewayFailureKind.invalidData,
      LoopBackendFailureKind.unavailable ||
      LoopBackendFailureKind.authentication ||
      LoopBackendFailureKind.invalidConfiguration =>
        ProfileGatewayFailureKind.unavailable,
      _ => ProfileGatewayFailureKind.unexpected,
    },
  };
}

PrivacyGatewayFailureKind privacyFailureKindForV2(LoopBackendFailure failure) {
  return switch (failure.code) {
    'VALIDATION_FAILED' => PrivacyGatewayFailureKind.validationFailed,
    'VERSION_CONFLICT' => PrivacyGatewayFailureKind.versionConflict,
    'ACCOUNT_BOOTSTRAP_REQUIRED' => PrivacyGatewayFailureKind.bootstrapRequired,
    'INVALID_REQUEST' => PrivacyGatewayFailureKind.invalidData,
    _ => switch (failure.kind) {
      LoopBackendFailureKind.connection ||
      LoopBackendFailureKind.timeout => PrivacyGatewayFailureKind.offline,
      LoopBackendFailureKind.invalidPayload =>
        PrivacyGatewayFailureKind.invalidData,
      LoopBackendFailureKind.unavailable ||
      LoopBackendFailureKind.authentication ||
      LoopBackendFailureKind.invalidConfiguration =>
        PrivacyGatewayFailureKind.unavailable,
      _ => PrivacyGatewayFailureKind.unexpected,
    },
  };
}
