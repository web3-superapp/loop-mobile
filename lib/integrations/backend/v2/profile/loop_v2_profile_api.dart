import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';

/// One preset avatar from the public `GET /v2/profile/avatars` catalog.
///
/// [slot] is a one-based row-major index into the 4x3 people atlas and is null
/// for the client-rendered monogram.
@immutable
final class LoopV2AvatarPreset {
  const LoopV2AvatarPreset({
    required this.avatarRef,
    required this.atlas,
    required this.slot,
    required this.label,
  });

  final String avatarRef;
  final String atlas;
  final int? slot;
  final String label;

  bool get isMonogram => atlas == 'monogram';

  /// One-based atlas column (1..4). Null for the monogram.
  int? get column => slot == null ? null : (slot! - 1) % 4 + 1;

  /// One-based atlas row (1..3). Null for the monogram.
  int? get row => slot == null ? null : (slot! - 1) ~/ 4 + 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopV2AvatarPreset &&
          other.avatarRef == avatarRef &&
          other.atlas == atlas &&
          other.slot == slot &&
          other.label == label;

  @override
  int get hashCode => Object.hash(avatarRef, atlas, slot, label);
}

/// The exact activation body. It is persisted with the idempotency key so a
/// retry replays the same bytes, including the submitted interest order.
@immutable
final class LoopV2ActivationRequest {
  const LoopV2ActivationRequest({
    required this.alias,
    required this.avatarRef,
    required this.interests,
  });

  final String alias;
  final String? avatarRef;
  final List<ProfileInterest> interests;

  Map<String, Object?> toRequestBody() => <String, Object?>{
    'alias': alias,
    'avatarRef': avatarRef,
    'interests': <String>[for (final interest in interests) interest.wireValue],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopV2ActivationRequest &&
          other.alias == alias &&
          other.avatarRef == avatarRef &&
          listEquals(other.interests, interests);

  @override
  int get hashCode => Object.hash(alias, avatarRef, Object.hashAll(interests));
}

abstract interface class LoopV2ProfileApi {
  Future<List<LoopV2AvatarPreset>> getAvatars();

  Future<ProfileResource> getProfile({
    required String accessToken,
    required String clientVersion,
  });

  Future<ProfileResource> replaceProfile({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required ProfileValues values,
  });

  Future<ProfileResource> activateLoopId({
    required String accessToken,
    required LoopV2CommandMetadata command,
    required LoopV2ActivationRequest request,
  });

  Future<PrivacyResource> getPrivacy({
    required String accessToken,
    required String clientVersion,
  });

  Future<PrivacyResource> replacePrivacy({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required PrivacyValues values,
  });
}

/// Strict V2 transport for the `profile` module (loop-api decision 0030).
///
/// Every response is parsed with [LoopV2Contract.strictMap]: unknown or
/// missing fields, a wrong `contractVersion`, a missing `Cache-Control:
/// no-store`, or a `correlationId` that differs from `X-Request-ID` is an
/// invalid payload, never a partially trusted projection.
final class DioLoopV2ProfileApi implements LoopV2ProfileApi {
  DioLoopV2ProfileApi(this._dio);

  static const avatarsPath = '/v2/profile/avatars';
  static const profilePath = '/v2/profile';
  static const loopIdPath = '/v2/profile/loop-id';
  static const privacyPath = '/v2/profile/privacy';

  static final RegExp _clientVersionPattern = RegExp(
    r'^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );
  static final RegExp _avatarRefPattern = RegExp(
    r'^avatar:[A-Za-z0-9][A-Za-z0-9._/-]{0,126}$',
  );
  static final RegExp _atlasPattern = RegExp(r'^[a-z][a-z0-9-]{0,31}$');
  static final RegExp _labelPattern = RegExp(
    r'^[^\p{Cc}\p{Cf}]{1,64}$',
    unicode: true,
  );

  static const _publicErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    404: <String>{'NOT_FOUND'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{'REQUEST_TIMEOUT'},
  };
  static const _readErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    404: <String>{'NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'VERSION_CONFLICT'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };
  static const _profileWriteErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    404: <String>{'NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'VERSION_CONFLICT'},
    422: <String>{'VALIDATION_FAILED', 'ALIAS_RESERVED', 'ALIAS_BLOCKED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };
  static const _activationErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'IDEMPOTENCY_CONFLICT',
      'VERSION_CONFLICT',
    },
    422: <String>{'VALIDATION_FAILED', 'ALIAS_RESERVED', 'ALIAS_BLOCKED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };
  static const _privacyWriteErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    404: <String>{'NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'VERSION_CONFLICT'},
    422: <String>{'VALIDATION_FAILED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  final Dio _dio;

  @override
  Future<List<LoopV2AvatarPreset>> getAvatars() async {
    try {
      final response = await _dio.get<Object?>(
        avatarsPath,
        options: Options(
          headers: <String, String>{'accept': Headers.jsonContentType},
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'avatars',
        'contractVersion',
      });
      _requireContractVersion(root);
      final rawAvatars = root['avatars'];
      if (rawAvatars is! List || rawAvatars.isEmpty || rawAvatars.length > 64) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      final seen = <String>{};
      final avatars = <LoopV2AvatarPreset>[];
      for (final raw in rawAvatars) {
        final item = LoopV2Contract.strictMap(raw, const <String>{
          'avatarRef',
          'atlas',
          'slot',
          'label',
        });
        final avatarRef = LoopV2Contract.requiredString(
          item,
          'avatarRef',
          pattern: _avatarRefPattern,
        );
        final atlas = LoopV2Contract.requiredString(
          item,
          'atlas',
          pattern: _atlasPattern,
        );
        final label = LoopV2Contract.requiredString(
          item,
          'label',
          pattern: _labelPattern,
        );
        final slot = item['slot'];
        if (!seen.add(avatarRef) ||
            (slot != null && (slot is! int || slot < 1 || slot > 64))) {
          throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
        }
        avatars.add(
          LoopV2AvatarPreset(
            avatarRef: avatarRef,
            atlas: atlas,
            slot: slot as int?,
            label: label,
          ),
        );
      }
      return List<LoopV2AvatarPreset>.unmodifiable(avatars);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: _publicErrors);
    }
  }

  @override
  Future<ProfileResource> getProfile({
    required String accessToken,
    required String clientVersion,
  }) async {
    _validateToken(accessToken);
    _validateClientVersion(clientVersion);
    try {
      final response = await _dio.get<Object?>(
        profilePath,
        options: Options(
          headers: _readHeaders(accessToken, clientVersion),
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      return _parseProfile(response);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: _readErrors);
    }
  }

  @override
  Future<ProfileResource> replaceProfile({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required ProfileValues values,
  }) async {
    _validateToken(accessToken);
    _validateClientVersion(clientVersion);
    if (expectedVersion < 0 || expectedVersion > profileMaximumVersion) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.put<Object?>(
        profilePath,
        data: <String, Object?>{
          'expectedVersion': expectedVersion,
          'profile': <String, Object?>{
            'alias': values.alias,
            'avatarRef': values.avatarRef,
            'bio': values.bio,
            'interests': <String>[
              for (final interest in values.interests) interest.wireValue,
            ],
          },
        },
        options: Options(
          headers: _readHeaders(accessToken, clientVersion),
          contentType: Headers.jsonContentType,
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      return _parseProfile(response);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: _profileWriteErrors,
      );
    }
  }

  @override
  Future<ProfileResource> activateLoopId({
    required String accessToken,
    required LoopV2CommandMetadata command,
    required LoopV2ActivationRequest request,
  }) async {
    _validateToken(accessToken);
    _validateCommand(command);
    try {
      final response = await _dio.post<Object?>(
        loopIdPath,
        data: request.toRequestBody(),
        options: Options(
          headers: <String, String>{
            'authorization': 'Bearer $accessToken',
            'accept': Headers.jsonContentType,
            'x-loop-contract-version': command.contractVersion,
            'x-loop-client-version': command.clientVersion,
            'x-loop-device-id': command.deviceId,
            'idempotency-key': command.idempotencyKey,
            'x-loop-platform': command.platform.wireName,
          },
          contentType: Headers.jsonContentType,
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      final resource = _parseProfile(response);
      if (resource.profileStatus != ProfileStatus.active) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      return resource;
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: _activationErrors,
      );
    }
  }

  @override
  Future<PrivacyResource> getPrivacy({
    required String accessToken,
    required String clientVersion,
  }) async {
    _validateToken(accessToken);
    _validateClientVersion(clientVersion);
    try {
      final response = await _dio.get<Object?>(
        privacyPath,
        options: Options(
          headers: _readHeaders(accessToken, clientVersion),
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      return _parsePrivacy(response);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: _readErrors);
    }
  }

  @override
  Future<PrivacyResource> replacePrivacy({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required PrivacyValues values,
  }) async {
    _validateToken(accessToken);
    _validateClientVersion(clientVersion);
    if (expectedVersion < 0 || expectedVersion > privacyMaximumVersion) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.put<Object?>(
        privacyPath,
        data: <String, Object?>{
          'expectedVersion': expectedVersion,
          'privacy': <String, Object?>{
            'discoverable': values.discoverable,
            'anonymousMode': values.anonymousMode,
            'visibility': <String, Object?>{
              'totalAssets': values.visibility.totalAssets.wireValue,
              'miningPower': values.visibility.miningPower.wireValue,
              'communities': values.visibility.communities.wireValue,
              'tradeHistory': values.visibility.tradeHistory.wireValue,
            },
          },
        },
        options: Options(
          headers: _readHeaders(accessToken, clientVersion),
          contentType: Headers.jsonContentType,
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      return _parsePrivacy(response);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: _privacyWriteErrors,
      );
    }
  }

  ProfileResource _parseProfile(Response<Object?> response) {
    LoopV2Contract.validateSuccess(response, statusCode: 200);
    final root = LoopV2Contract.strictMap(response.data, const <String>{
      'profile',
      'version',
      'updatedAt',
      'contractVersion',
    });
    _requireContractVersion(root);
    final profile = LoopV2Contract.strictMap(root['profile'], const <String>{
      'loopId',
      'alias',
      'avatarRef',
      'bio',
      'interests',
      'profileStatus',
      'activatedAt',
    });
    final loopId = LoopV2Contract.requiredString(
      profile,
      'loopId',
      pattern: profileLoopIdPattern,
    );
    final alias = profile['alias'];
    final avatarRef = profile['avatarRef'];
    final bio = profile['bio'];
    final rawInterests = profile['interests'];
    final rawStatus = profile['profileStatus'];
    if ((alias != null && alias is! String) ||
        (avatarRef != null && avatarRef is! String) ||
        (bio != null && bio is! String) ||
        rawInterests is! List ||
        rawInterests.length > profileMaximumInterests ||
        rawStatus is! String) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final interests = <ProfileInterest>[];
    for (final raw in rawInterests) {
      if (raw is! String) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      interests.add(_interest(raw));
    }
    final status = _status(rawStatus);
    try {
      final values = ProfileValues(
        alias: alias as String?,
        avatarRef: avatarRef as String?,
        bio: bio as String?,
        interests: interests,
      );
      // The server is authoritative: a value it would have trimmed or
      // normalized differently is a contract violation, not a silent fix.
      if (values.alias != alias || values.bio != bio) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      return ProfileResource(
        version: _version(root['version'], profileMaximumVersion),
        values: values,
        updatedAt: _nullableTimestamp(root['updatedAt']),
        loopId: loopId,
        profileStatus: status,
        activatedAt: _nullableTimestamp(profile['activatedAt']),
      );
    } on InvalidProfileContractException {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
  }

  PrivacyResource _parsePrivacy(Response<Object?> response) {
    LoopV2Contract.validateSuccess(response, statusCode: 200);
    final root = LoopV2Contract.strictMap(response.data, const <String>{
      'privacy',
      'version',
      'updatedAt',
      'contractVersion',
    });
    _requireContractVersion(root);
    final privacy = LoopV2Contract.strictMap(root['privacy'], const <String>{
      'discoverable',
      'anonymousMode',
      'visibility',
    });
    final visibility = LoopV2Contract.strictMap(
      privacy['visibility'],
      const <String>{
        'totalAssets',
        'miningPower',
        'communities',
        'tradeHistory',
      },
    );
    final discoverable = privacy['discoverable'];
    final anonymousMode = privacy['anonymousMode'];
    if (discoverable is! bool || anonymousMode is! bool) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    try {
      return PrivacyResource(
        version: _version(root['version'], privacyMaximumVersion),
        values: PrivacyValues(
          discoverable: discoverable,
          anonymousMode: anonymousMode,
          visibility: PrivacyVisibility(
            totalAssets: _audience(visibility['totalAssets']),
            miningPower: _audience(visibility['miningPower']),
            communities: _audience(visibility['communities']),
            tradeHistory: _audience(visibility['tradeHistory']),
          ),
        ),
        updatedAt: _nullableTimestamp(root['updatedAt']),
      );
    } on InvalidPrivacyContractException {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
  }

  void _requireContractVersion(Map<String, Object?> root) {
    if (root['contractVersion'] != LoopV2ClientMetadata.contractVersion) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
  }

  Map<String, String> _readHeaders(String accessToken, String clientVersion) =>
      <String, String>{
        'authorization': 'Bearer $accessToken',
        'accept': Headers.jsonContentType,
        'x-loop-contract-version': LoopV2ClientMetadata.contractVersion,
        'x-loop-client-version': clientVersion,
      };

  ProfileInterest _interest(String value) {
    try {
      return ProfileInterest.fromWire(value);
    } on InvalidProfileContractException {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
  }

  ProfileStatus _status(String value) {
    try {
      return ProfileStatus.fromWire(value);
    } on InvalidProfileContractException {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
  }

  PrivacyAudience _audience(Object? value) {
    if (value is! String) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    try {
      return PrivacyAudience.fromWire(value);
    } on InvalidPrivacyContractException {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
  }

  int _version(Object? value, int maximum) {
    if (value is! int || value < 0 || value > maximum) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return value;
  }

  DateTime? _nullableTimestamp(Object? value) {
    if (value == null) return null;
    if (value is! String) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return parsed;
  }

  void _validateToken(String value) {
    if (value.isEmpty || value != value.trim()) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
  }

  void _validateClientVersion(String value) {
    if (value.length < 5 ||
        value.length > 64 ||
        !_clientVersionPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
  }

  void _validateCommand(LoopV2CommandMetadata command) {
    _validateClientVersion(command.clientVersion);
    if (command.contractVersion != LoopV2ClientMetadata.contractVersion ||
        !LoopV2Contract.uuidV4Pattern.hasMatch(command.deviceId) ||
        !LoopV2Contract.uuidV4Pattern.hasMatch(command.idempotencyKey)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
  }
}
