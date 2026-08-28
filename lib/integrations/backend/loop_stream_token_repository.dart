import 'package:dio/dio.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';

final class LoopStreamToken {
  const LoopStreamToken({
    required this.apiKey,
    required this.token,
    required this.expiresAt,
    required this.userId,
  });

  final String apiKey;
  final String token;
  final DateTime expiresAt;
  final String userId;
}

abstract interface class LoopStreamTokenRepository {
  Future<LoopStreamToken> issueChatToken({required String accessToken});
}

/// Strict native adapter for LOOP's short-lived Stream Chat token contract.
///
/// It owns neither Privy token refresh nor Stream SDK state. One current Privy
/// access token is accepted for one immediate request, and provider token
/// material is returned only to the principal-bound SDK session source.
final class DioLoopStreamTokenRepository implements LoopStreamTokenRepository {
  DioLoopStreamTokenRepository(
    this._dio, {
    required String expectedApiKey,
    DateTime Function()? now,
  }) : _expectedApiKey = expectedApiKey,
       _now = now ?? DateTime.now {
    if (!isValidApiKey(expectedApiKey)) {
      throw ArgumentError.value(
        expectedApiKey,
        'expectedApiKey',
        'must be a canonical public Stream API key',
      );
    }
  }

  static const chatTokenPath = '/v1/chat/token';
  static const _maximumClockSkew = Duration(minutes: 5);

  static final RegExp _apiKeyPattern = RegExp(r'^[\x21-\x7e]{1,512}$');
  static final RegExp _tokenPattern = RegExp(r'^[\x21-\x7e]{32,16384}$');
  static final RegExp _streamUserIdPattern = RegExp(r'^loop_[a-z0-9_-]{8,58}$');
  static final RegExp _requestIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp _canonicalExpiryPattern = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.000Z$',
  );
  static const Set<String> _stableErrorCodes = <String>{
    'invalid_request',
    'authentication_required',
    'invalid_access_token',
    'bootstrap_required',
    'rate_limit_exceeded',
    'internal_error',
    'authentication_unavailable',
    'stream_unavailable',
    'request_timeout',
  };

  final Dio _dio;
  final String _expectedApiKey;
  final DateTime Function() _now;

  static bool isValidApiKey(String value) => _matches(_apiKeyPattern, value);

  static bool _matches(RegExp pattern, String value) {
    final match = pattern.matchAsPrefix(value);
    return match != null && match.end == value.length;
  }

  @override
  Future<LoopStreamToken> issueChatToken({required String accessToken}) async {
    _validateAccessToken(accessToken);

    try {
      final response = await _dio.post<Object?>(
        chatTokenPath,
        options: Options(
          headers: <String, String>{
            'authorization': 'Bearer $accessToken',
            'accept': Headers.jsonContentType,
          },
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      return _parseSuccess(response);
    } on DioException catch (error) {
      throw _mapDioFailure(error);
    }
  }

  LoopStreamToken _parseSuccess(Response<Object?> response) {
    if (response.statusCode != 200 ||
        !_hasNoStore(response.headers) ||
        _requestIdHeader(response.headers) == null) {
      return _invalidPayload();
    }

    final root = _strictMap(response.data, const <String>{
      'api_key',
      'token',
      'expires_at',
      'user',
    });
    final user = _strictMap(root['user'], const <String>{'id'});
    final apiKey = root['api_key'];
    final token = root['token'];
    final userId = user['id'];
    if (apiKey is! String ||
        !_matches(_apiKeyPattern, apiKey) ||
        apiKey != _expectedApiKey ||
        token is! String ||
        !_matches(_tokenPattern, token) ||
        userId is! String ||
        !_matches(_streamUserIdPattern, userId)) {
      return _invalidPayload();
    }

    final expiresAt = _canonicalExpiry(root['expires_at']);
    final now = _now().toUtc();
    final minimumExpiry = now.add(const Duration(hours: 1) - _maximumClockSkew);
    if (expiresAt.isBefore(minimumExpiry) ||
        expiresAt.isAfter(
          now.add(const Duration(hours: 1) + _maximumClockSkew),
        )) {
      return _invalidPayload();
    }

    return LoopStreamToken(
      apiKey: apiKey,
      token: token,
      expiresAt: expiresAt,
      userId: userId,
    );
  }

  DateTime _canonicalExpiry(Object? value) {
    if (value is! String || !_matches(_canonicalExpiryPattern, value)) {
      return _invalidPayload();
    }
    final parsed = DateTime.tryParse(value)?.toUtc();
    if (parsed == null || parsed.toIso8601String() != value) {
      return _invalidPayload();
    }
    return parsed;
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
    final values = headers['cache-control'];
    return values != null && values.length == 1 && values.single == 'no-store';
  }

  String? _requestIdHeader(Headers headers) {
    final values = headers['x-request-id'];
    if (values == null || values.length != 1) return null;
    final value = values.single;
    return _matches(_requestIdPattern, value) ? value : null;
  }

  LoopBackendFailure _mapDioFailure(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final metadata = _errorMetadata(response);
    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => LoopBackendFailureKind.timeout,
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => LoopBackendFailureKind.connection,
      DioExceptionType.cancel => LoopBackendFailureKind.cancelled,
      DioExceptionType.badResponse when !metadata.valid =>
        LoopBackendFailureKind.invalidPayload,
      DioExceptionType.badResponse => switch (statusCode) {
        400 => LoopBackendFailureKind.invalidRequest,
        401 => LoopBackendFailureKind.authentication,
        409 => LoopBackendFailureKind.invalidRequest,
        429 => LoopBackendFailureKind.unavailable,
        503 when metadata.code == 'request_timeout' =>
          LoopBackendFailureKind.timeout,
        500 || 503 => LoopBackendFailureKind.unavailable,
        _ => LoopBackendFailureKind.unexpected,
      },
      DioExceptionType.unknown => LoopBackendFailureKind.unexpected,
    };
    return LoopBackendFailure(
      kind,
      statusCode: statusCode,
      code: metadata.valid ? metadata.code : null,
      requestId: metadata.valid ? metadata.requestId : null,
    );
  }

  ({bool valid, String? code, String? requestId}) _errorMetadata(
    Response<Object?>? response,
  ) {
    if (response == null || !_hasNoStore(response.headers)) {
      return (valid: false, code: null, requestId: null);
    }
    final headerRequestId = _requestIdHeader(response.headers);
    if (headerRequestId == null ||
        (response.statusCode == 401 &&
            !_hasExactBearerChallenge(response.headers))) {
      return (valid: false, code: null, requestId: null);
    }
    final data = response.data;
    if (data is! Map || data.length != 3) {
      return (valid: false, code: null, requestId: null);
    }
    if (!data.keys.every((key) => key is String) ||
        !data.containsKey('code') ||
        !data.containsKey('message') ||
        !data.containsKey('request_id')) {
      return (valid: false, code: null, requestId: null);
    }
    final code = data['code'];
    final message = data['message'];
    final requestId = data['request_id'];
    if (code is! String ||
        !_stableErrorCodes.contains(code) ||
        message is! String ||
        message.isEmpty ||
        requestId is! String ||
        requestId != headerRequestId ||
        !_codeMatchesStatus(response.statusCode, code)) {
      return (valid: false, code: null, requestId: null);
    }
    return (valid: true, code: code, requestId: requestId);
  }

  bool _hasExactBearerChallenge(Headers headers) {
    final values = headers['www-authenticate'];
    return values != null &&
        values.length == 1 &&
        values.single == 'Bearer realm="loop-api"';
  }

  bool _codeMatchesStatus(int? statusCode, String code) => switch (statusCode) {
    400 => code == 'invalid_request',
    401 => code == 'authentication_required' || code == 'invalid_access_token',
    409 => code == 'bootstrap_required',
    429 => code == 'rate_limit_exceeded',
    500 => code == 'internal_error',
    503 =>
      code == 'authentication_unavailable' ||
          code == 'stream_unavailable' ||
          code == 'request_timeout',
    _ => false,
  };

  T _invalidPayload<T>() =>
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
}
