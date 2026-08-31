import 'package:dio/dio.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';

/// Authenticated production adapter for the owner-scoped Profile resource.
///
/// The access token is supplied by [LoopAuthenticatedSession] for exactly one
/// immediate request. This adapter owns no credential cache or generic retry.
final class DioLoopProfileGateway implements ProfileGateway {
  DioLoopProfileGateway({required Dio dio, required this._session})
    : _transport = _DioLoopPersonalizationTransport(dio);

  final _DioLoopPersonalizationTransport _transport;
  final LoopAuthenticatedSession _session;

  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() => _execute(
    (accessToken) => _transport.loadProfile(accessToken: accessToken),
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
      (accessToken) => _transport.replaceProfile(
        accessToken: accessToken,
        expectedVersion: expectedVersion,
        values: candidate,
      ),
    );
  }

  Future<ProfileResource> _execute(
    Future<ProfileResource> Function(String accessToken) request,
  ) async {
    try {
      return await _session.execute(request);
    } on LoopBackendFailure catch (failure) {
      throw ProfileGatewayException(_profileFailureKind(failure));
    } on InvalidProfileContractException {
      throw const ProfileGatewayException(
        ProfileGatewayFailureKind.invalidData,
      );
    } catch (_) {
      throw const ProfileGatewayException(ProfileGatewayFailureKind.unexpected);
    }
  }
}

/// Authenticated production adapter for owner-only Privacy preferences.
final class DioLoopPrivacyGateway implements PrivacyGateway {
  DioLoopPrivacyGateway({required Dio dio, required this._session})
    : _transport = _DioLoopPersonalizationTransport(dio);

  final _DioLoopPersonalizationTransport _transport;
  final LoopAuthenticatedSession _session;

  @override
  PrivacyMode get mode => PrivacyMode.production;

  @override
  Future<PrivacyResource> load() => _execute(
    (accessToken) => _transport.loadPrivacy(accessToken: accessToken),
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
      (accessToken) => _transport.replacePrivacy(
        accessToken: accessToken,
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
      throw PrivacyGatewayException(_privacyFailureKind(failure));
    } on InvalidPrivacyContractException {
      throw const PrivacyGatewayException(
        PrivacyGatewayFailureKind.invalidData,
      );
    } catch (_) {
      throw const PrivacyGatewayException(PrivacyGatewayFailureKind.unexpected);
    }
  }
}

/// Authenticated production adapter for fail-closed Social Privacy settings.
final class DioLoopSocialPrivacyGateway implements SocialPrivacyGateway {
  DioLoopSocialPrivacyGateway({required Dio dio, required this._session})
    : _transport = _DioLoopPersonalizationTransport(dio);

  final _DioLoopPersonalizationTransport _transport;
  final LoopAuthenticatedSession _session;

  @override
  SocialPrivacyMode get mode => SocialPrivacyMode.production;

  @override
  Future<SocialPrivacyResource> load() => _execute(
    (accessToken) => _transport.loadSocialPrivacy(accessToken: accessToken),
  );

  @override
  Future<SocialPrivacyResource> replace({
    required int expectedVersion,
    required SocialPrivacyValues values,
  }) {
    if (expectedVersion < 0 || expectedVersion > socialPrivacyMaximumVersion) {
      return Future<SocialPrivacyResource>.error(
        const SocialPrivacyGatewayException(
          SocialPrivacyGatewayFailureKind.invalidData,
        ),
      );
    }
    final candidate = SocialPrivacyValues.copyOf(values);
    return _execute(
      (accessToken) => _transport.replaceSocialPrivacy(
        accessToken: accessToken,
        expectedVersion: expectedVersion,
        values: candidate,
      ),
    );
  }

  Future<SocialPrivacyResource> _execute(
    Future<SocialPrivacyResource> Function(String accessToken) request,
  ) async {
    try {
      return await _session.execute(request);
    } on LoopBackendFailure catch (failure) {
      throw SocialPrivacyGatewayException(_socialPrivacyFailureKind(failure));
    } on InvalidSocialPrivacyContractException {
      throw const SocialPrivacyGatewayException(
        SocialPrivacyGatewayFailureKind.invalidData,
      );
    } catch (_) {
      throw const SocialPrivacyGatewayException(
        SocialPrivacyGatewayFailureKind.unexpected,
      );
    }
  }
}

final class _DioLoopPersonalizationTransport {
  const _DioLoopPersonalizationTransport(this._dio);

  static const _profilePath = '/v1/profile';
  static const _privacyPath = '/v1/profile/privacy';
  static const _socialPrivacyPath = '/v1/profile/social-privacy';

  static final RegExp _requestIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _rfc3339Pattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,9})?(?:Z|[+-](\d{2}):(\d{2}))$',
  );
  static final RegExp _publicErrorCodePattern = RegExp(r'^[a-z0-9_]+$');

  static const _profilePrivacyErrorCodes = <String>{
    'authentication_required',
    'invalid_access_token',
    'invalid_request',
    'bootstrap_required',
    'version_conflict',
    'authentication_unavailable',
    'request_timeout',
    'internal_error',
  };
  static const _socialPrivacyErrorCodes = <String>{
    ..._profilePrivacyErrorCodes,
    'idempotency_conflict',
    'profile_required',
    'incoming_request_pending',
    'outgoing_request_pending',
    'already_friends',
    'friend_request_cooldown',
    'friend_request_already_decided',
    'search_rate_limited',
    'social_rate_limited',
    'social_unavailable',
  };

  final Dio _dio;

  Future<ProfileResource> loadProfile({required String accessToken}) async {
    final response = await _get(
      _profilePath,
      accessToken: accessToken,
      resource: _PersonalizationResource.profile,
    );
    return _parseSuccess(response, _parseProfileResource);
  }

  Future<ProfileResource> replaceProfile({
    required String accessToken,
    required int expectedVersion,
    required ProfileValues values,
  }) async {
    final response = await _put(
      _profilePath,
      accessToken: accessToken,
      resource: _PersonalizationResource.profile,
      data: <String, Object?>{
        'expected_version': expectedVersion,
        'profile': <String, Object?>{
          'alias': values.alias,
          'avatar_ref': values.avatarRef,
        },
      },
    );
    return _parseSuccess(response, _parseProfileResource);
  }

  Future<PrivacyResource> loadPrivacy({required String accessToken}) async {
    final response = await _get(
      _privacyPath,
      accessToken: accessToken,
      resource: _PersonalizationResource.privacy,
    );
    return _parseSuccess(response, _parsePrivacyResource);
  }

  Future<PrivacyResource> replacePrivacy({
    required String accessToken,
    required int expectedVersion,
    required PrivacyValues values,
  }) async {
    final response = await _put(
      _privacyPath,
      accessToken: accessToken,
      resource: _PersonalizationResource.privacy,
      data: <String, Object?>{
        'expected_version': expectedVersion,
        'privacy': <String, Object?>{
          'discoverable': values.discoverable,
          'copy_trade_visibility': values.copyTradeVisibility.wireValue,
        },
      },
    );
    return _parseSuccess(response, _parsePrivacyResource);
  }

  Future<SocialPrivacyResource> loadSocialPrivacy({
    required String accessToken,
  }) async {
    final response = await _get(
      _socialPrivacyPath,
      accessToken: accessToken,
      resource: _PersonalizationResource.socialPrivacy,
    );
    return _parseSuccess(response, _parseSocialPrivacyResource);
  }

  Future<SocialPrivacyResource> replaceSocialPrivacy({
    required String accessToken,
    required int expectedVersion,
    required SocialPrivacyValues values,
  }) async {
    final response = await _put(
      _socialPrivacyPath,
      accessToken: accessToken,
      resource: _PersonalizationResource.socialPrivacy,
      data: <String, Object?>{
        'expected_version': expectedVersion,
        'social_privacy': <String, Object?>{
          'friend_requests': values.friendRequests.wireValue,
          'group_invites': values.groupInvites.wireValue,
          'direct_messages': values.directMessages.wireValue,
        },
      },
    );
    return _parseSuccess(response, _parseSocialPrivacyResource);
  }

  Future<Response<Object?>> _get(
    String path, {
    required String accessToken,
    required _PersonalizationResource resource,
  }) async {
    _validateAccessToken(accessToken);
    try {
      return await _dio.get<Object?>(path, options: _options(accessToken));
    } on DioException catch (error) {
      throw _mapDioFailure(error, resource: resource, isWrite: false);
    }
  }

  Future<Response<Object?>> _put(
    String path, {
    required String accessToken,
    required _PersonalizationResource resource,
    required Map<String, Object?> data,
  }) async {
    _validateAccessToken(accessToken);
    try {
      return await _dio.put<Object?>(
        path,
        data: data,
        options: _options(accessToken, sendsJson: true),
      );
    } on DioException catch (error) {
      throw _mapDioFailure(error, resource: resource, isWrite: true);
    }
  }

  Options _options(String accessToken, {bool sendsJson = false}) => Options(
    headers: <String, String>{
      'authorization': 'Bearer $accessToken',
      'accept': Headers.jsonContentType,
    },
    contentType: sendsJson ? Headers.jsonContentType : null,
    followRedirects: false,
    responseType: ResponseType.json,
  );

  T _parseSuccess<T>(Response<Object?> response, T Function(Object?) parser) {
    if (response.statusCode != 200 ||
        !_hasNoStore(response.headers) ||
        _requestIdHeader(response.headers) == null) {
      return _invalidPayload();
    }
    try {
      return parser(response.data);
    } on LoopBackendFailure {
      rethrow;
    } catch (_) {
      return _invalidPayload();
    }
  }

  ProfileResource _parseProfileResource(Object? payload) {
    final root = _strictMap(payload, const <String>{
      'version',
      'profile',
      'updated_at',
    });
    final rawValues = _strictMap(root['profile'], const <String>{
      'alias',
      'avatar_ref',
    });
    final rawAlias = rawValues['alias'];
    final rawAvatarRef = rawValues['avatar_ref'];
    if ((rawAlias != null && rawAlias is! String) ||
        (rawAvatarRef != null && rawAvatarRef is! String)) {
      return _invalidPayload();
    }

    final values = ProfileValues(
      alias: rawAlias as String?,
      avatarRef: rawAvatarRef as String?,
    );
    if (values.alias != rawAlias) return _invalidPayload();
    return ProfileResource(
      version: _version(root['version']),
      values: values,
      updatedAt: _nullableTimestamp(root['updated_at']),
    );
  }

  PrivacyResource _parsePrivacyResource(Object? payload) {
    final root = _strictMap(payload, const <String>{
      'version',
      'privacy',
      'updated_at',
    });
    final rawValues = _strictMap(root['privacy'], const <String>{
      'discoverable',
      'copy_trade_visibility',
    });
    final discoverable = rawValues['discoverable'];
    final visibility = rawValues['copy_trade_visibility'];
    if (discoverable is! bool || visibility is! String) {
      return _invalidPayload();
    }
    return PrivacyResource(
      version: _version(root['version']),
      values: PrivacyValues(
        discoverable: discoverable,
        copyTradeVisibility: CopyTradeVisibility.fromWire(visibility),
      ),
      updatedAt: _nullableTimestamp(root['updated_at']),
    );
  }

  SocialPrivacyResource _parseSocialPrivacyResource(Object? payload) {
    final root = _strictMap(payload, const <String>{
      'version',
      'social_privacy',
      'updated_at',
    });
    final rawValues = _strictMap(root['social_privacy'], const <String>{
      'friend_requests',
      'group_invites',
      'direct_messages',
    });
    final friendRequests = rawValues['friend_requests'];
    final groupInvites = rawValues['group_invites'];
    final directMessages = rawValues['direct_messages'];
    if (friendRequests is! String ||
        groupInvites is! String ||
        directMessages is! String) {
      return _invalidPayload();
    }
    return SocialPrivacyResource(
      version: _version(root['version']),
      values: SocialPrivacyValues(
        friendRequests: FriendRequestsPreference.fromWire(friendRequests),
        groupInvites: GroupInvitesPreference.fromWire(groupInvites),
        directMessages: DirectMessagesPreference.fromWire(directMessages),
      ),
      updatedAt: _nullableTimestamp(root['updated_at']),
    );
  }

  int _version(Object? value) {
    if (value is! int || value < 0 || value > profileMaximumVersion) {
      return _invalidPayload();
    }
    return value;
  }

  DateTime? _nullableTimestamp(Object? value) {
    if (value == null) return null;
    if (value is! String || value.length > 40) return _invalidPayload();
    final match = _rfc3339Pattern.firstMatch(value);
    if (match == null) return _invalidPayload();
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    final offsetHour = int.parse(match.group(7) ?? '0');
    final offsetMinute = int.parse(match.group(8) ?? '0');
    final calendarDate = DateTime.utc(year, month, day);
    if (calendarDate.year != year ||
        calendarDate.month != month ||
        calendarDate.day != day ||
        hour > 23 ||
        minute > 59 ||
        second > 59 ||
        offsetHour > 23 ||
        offsetMinute > 59) {
      return _invalidPayload();
    }
    final parsed = DateTime.tryParse(value);
    return parsed?.toUtc() ?? _invalidPayload();
  }

  Map<String, Object?> _strictMap(Object? value, Set<String> expectedKeys) {
    if (value is! Map) return _invalidPayload();
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || result.containsKey(key)) {
        return _invalidPayload();
      }
      result[key] = entry.value;
    }
    if (result.length != expectedKeys.length ||
        !expectedKeys.every(result.containsKey)) {
      return _invalidPayload();
    }
    return result;
  }

  void _validateAccessToken(String accessToken) {
    if (accessToken.isEmpty || accessToken != accessToken.trim()) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
  }

  bool _hasNoStore(Headers headers) {
    final directives = headers['cache-control']
        ?.expand((value) => value.split(','))
        .map((value) => value.trim().toLowerCase());
    return directives?.contains('no-store') ?? false;
  }

  String? _requestIdHeader(Headers headers) {
    final values = headers['x-request-id'];
    if (values == null || values.length != 1) return null;
    final value = values.single;
    return _requestIdPattern.hasMatch(value) ? value : null;
  }

  LoopBackendFailure _mapDioFailure(
    DioException error, {
    required _PersonalizationResource resource,
    required bool isWrite,
  }) {
    final statusCode = error.response?.statusCode;
    final metadata = error.type == DioExceptionType.badResponse
        ? _errorMetadata(error.response, resource: resource, isWrite: isWrite)
        : null;
    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => LoopBackendFailureKind.timeout,
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => LoopBackendFailureKind.connection,
      DioExceptionType.cancel => LoopBackendFailureKind.cancelled,
      DioExceptionType.badResponse when metadata == null =>
        LoopBackendFailureKind.invalidPayload,
      DioExceptionType.badResponse => switch (statusCode) {
        400 => LoopBackendFailureKind.invalidRequest,
        401 => LoopBackendFailureKind.authentication,
        409 => LoopBackendFailureKind.invalidRequest,
        429 => LoopBackendFailureKind.unavailable,
        503 when metadata?.code == 'request_timeout' =>
          LoopBackendFailureKind.timeout,
        503 => LoopBackendFailureKind.unavailable,
        final status when status != null && status >= 500 =>
          LoopBackendFailureKind.unavailable,
        _ => LoopBackendFailureKind.unexpected,
      },
      DioExceptionType.unknown => LoopBackendFailureKind.unexpected,
    };
    return LoopBackendFailure(
      kind,
      statusCode: statusCode,
      code: metadata?.code,
      requestId: metadata?.requestId,
    );
  }

  _PersonalizationErrorMetadata? _errorMetadata(
    Response<Object?>? response, {
    required _PersonalizationResource resource,
    required bool isWrite,
  }) {
    if (response == null || !_hasNoStore(response.headers)) return null;
    final headerRequestId = _requestIdHeader(response.headers);
    if (headerRequestId == null) return null;
    final data = response.data;
    if (data is! Map || data.length != 3) return null;
    final map = <String, Object?>{};
    for (final entry in data.entries) {
      final key = entry.key;
      if (key is! String || map.containsKey(key)) return null;
      map[key] = entry.value;
    }
    if (!const <String>{
      'code',
      'message',
      'request_id',
    }.every(map.containsKey)) {
      return null;
    }

    final code = map['code'];
    final message = map['message'];
    final requestId = map['request_id'];
    if (code is! String ||
        code.isEmpty ||
        code.length > 64 ||
        !_publicErrorCodePattern.hasMatch(code) ||
        message is! String ||
        message.isEmpty ||
        message.length > 512 ||
        requestId is! String ||
        requestId != headerRequestId ||
        !_requestIdPattern.hasMatch(requestId) ||
        !_codeMatchesStatus(
          statusCode: response.statusCode,
          code: code,
          resource: resource,
          isWrite: isWrite,
        )) {
      return null;
    }
    return _PersonalizationErrorMetadata(code: code, requestId: requestId);
  }

  bool _codeMatchesStatus({
    required int? statusCode,
    required String code,
    required _PersonalizationResource resource,
    required bool isWrite,
  }) {
    final allowed = resource == _PersonalizationResource.socialPrivacy
        ? _socialPrivacyErrorCodes
        : _profilePrivacyErrorCodes;
    if (!allowed.contains(code)) return false;
    return switch (statusCode) {
      400 => code == 'invalid_request',
      401 =>
        code == 'authentication_required' || code == 'invalid_access_token',
      409 when resource == _PersonalizationResource.socialPrivacy =>
        code == 'bootstrap_required' ||
            (isWrite && code == 'version_conflict') ||
            code == 'idempotency_conflict' ||
            code == 'profile_required' ||
            code == 'incoming_request_pending' ||
            code == 'outgoing_request_pending' ||
            code == 'already_friends' ||
            code == 'friend_request_cooldown' ||
            code == 'friend_request_already_decided',
      409 =>
        code == 'bootstrap_required' || (isWrite && code == 'version_conflict'),
      429 when resource == _PersonalizationResource.socialPrivacy =>
        code == 'search_rate_limited' || code == 'social_rate_limited',
      500 => code == 'internal_error',
      503 when resource == _PersonalizationResource.socialPrivacy =>
        code == 'authentication_unavailable' ||
            code == 'social_unavailable' ||
            code == 'request_timeout',
      503 => code == 'authentication_unavailable' || code == 'request_timeout',
      _ => false,
    };
  }

  T _invalidPayload<T>() =>
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
}

enum _PersonalizationResource { profile, privacy, socialPrivacy }

final class _PersonalizationErrorMetadata {
  const _PersonalizationErrorMetadata({
    required this.code,
    required this.requestId,
  });

  final String code;
  final String requestId;
}

ProfileGatewayFailureKind _profileFailureKind(LoopBackendFailure failure) {
  if (failure.statusCode == 409 && failure.code == 'version_conflict') {
    return ProfileGatewayFailureKind.versionConflict;
  }
  if (failure.kind == LoopBackendFailureKind.invalidPayload ||
      (failure.kind == LoopBackendFailureKind.invalidRequest &&
          failure.code == 'invalid_request')) {
    return ProfileGatewayFailureKind.invalidData;
  }
  if (_isUnavailableFailure(failure)) {
    return ProfileGatewayFailureKind.unavailable;
  }
  return ProfileGatewayFailureKind.unexpected;
}

PrivacyGatewayFailureKind _privacyFailureKind(LoopBackendFailure failure) {
  if (failure.statusCode == 409 && failure.code == 'version_conflict') {
    return PrivacyGatewayFailureKind.versionConflict;
  }
  if (failure.kind == LoopBackendFailureKind.invalidPayload ||
      (failure.kind == LoopBackendFailureKind.invalidRequest &&
          failure.code == 'invalid_request')) {
    return PrivacyGatewayFailureKind.invalidData;
  }
  if (_isUnavailableFailure(failure)) {
    return PrivacyGatewayFailureKind.unavailable;
  }
  return PrivacyGatewayFailureKind.unexpected;
}

SocialPrivacyGatewayFailureKind _socialPrivacyFailureKind(
  LoopBackendFailure failure,
) {
  if (failure.statusCode == 409 && failure.code == 'version_conflict') {
    return SocialPrivacyGatewayFailureKind.versionConflict;
  }
  if (failure.kind == LoopBackendFailureKind.invalidPayload ||
      (failure.kind == LoopBackendFailureKind.invalidRequest &&
          failure.code == 'invalid_request')) {
    return SocialPrivacyGatewayFailureKind.invalidData;
  }
  if (_isUnavailableFailure(failure)) {
    return SocialPrivacyGatewayFailureKind.unavailable;
  }
  return SocialPrivacyGatewayFailureKind.unexpected;
}

bool _isUnavailableFailure(LoopBackendFailure failure) =>
    failure.kind == LoopBackendFailureKind.invalidConfiguration ||
    failure.kind == LoopBackendFailureKind.authentication ||
    failure.kind == LoopBackendFailureKind.unavailable ||
    failure.kind == LoopBackendFailureKind.timeout ||
    failure.kind == LoopBackendFailureKind.connection ||
    failure.kind == LoopBackendFailureKind.cancelled ||
    (failure.statusCode == 409 && failure.code == 'bootstrap_required');
