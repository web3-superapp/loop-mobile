import 'package:dio/dio.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token.dart';

/// Strict client for `POST /v1/chat/token` and `POST /v1/video/token`.
final class DioLoopStreamTokenRepository implements LoopStreamTokenRepository {
  DioLoopStreamTokenRepository(
    this._dio, {
    required String expectedApiKey,
    DateTime Function()? now,
  }) : _expectedApiKey = _validateApiKey(expectedApiKey),
       _now = now ?? DateTime.now;

  static const _maximumRemainingLifetime = Duration(minutes: 65);
  static final RegExp _streamUserIdPattern = RegExp(r'^loop_[a-z0-9_-]{8,58}$');
  static final RegExp _canonicalUtcDateTimePattern = RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$',
  );
  static final RegExp _requestIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  final Dio _dio;
  final String _expectedApiKey;
  final DateTime Function() _now;

  @override
  Future<LoopStreamTokenCredential> issue({
    required LoopStreamTokenProduct product,
    required String expectedStreamUserId,
    required String accessToken,
  }) async {
    if (!_streamUserIdPattern.hasMatch(expectedStreamUserId)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    if (accessToken.isEmpty || accessToken != accessToken.trim()) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }

    try {
      final endpointPath = switch (product) {
        LoopStreamTokenProduct.chat => '/v1/chat/token',
        LoopStreamTokenProduct.video => '/v1/video/token',
      };
      final response = await _dio.post<Object?>(
        endpointPath,
        options: Options(
          headers: <String, String>{
            'authorization': 'Bearer $accessToken',
            'accept': Headers.jsonContentType,
          },
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      return _parse(response, expectedStreamUserId);
    } on DioException catch (error) {
      throw _mapDioFailure(error);
    }
  }

  LoopStreamTokenCredential _parse(
    Response<Object?> response,
    String expectedStreamUserId,
  ) {
    if (response.statusCode != 200 || !_hasNoStore(response.headers)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
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
    final rawExpiresAt = root['expires_at'];
    final streamUserId = user['id'];
    if (apiKey is! String ||
        apiKey != _expectedApiKey ||
        !_isPrintableAscii(apiKey, minimum: 1, maximum: 512) ||
        token is! String ||
        !_isPrintableAscii(token, minimum: 32, maximum: 16384) ||
        streamUserId is! String ||
        streamUserId != expectedStreamUserId ||
        !_streamUserIdPattern.hasMatch(streamUserId) ||
        rawExpiresAt is! String ||
        !_canonicalUtcDateTimePattern.hasMatch(rawExpiresAt)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    final expiresAt = DateTime.tryParse(rawExpiresAt)?.toUtc();
    final now = _now().toUtc();
    if (expiresAt == null ||
        expiresAt.toIso8601String() != rawExpiresAt ||
        !expiresAt.isAfter(now) ||
        expiresAt.difference(now) > _maximumRemainingLifetime) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    return LoopStreamTokenCredential(token: token, expiresAt: expiresAt);
  }

  LoopBackendFailure _mapDioFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    final metadata = error.type == DioExceptionType.badResponse
        ? _parseErrorMetadata(error.response)
        : null;
    if (error.type == DioExceptionType.badResponse && metadata == null) {
      return LoopBackendFailure(
        LoopBackendFailureKind.invalidPayload,
        statusCode: statusCode,
      );
    }
    final code = metadata?.code;
    final requestId = metadata?.requestId;
    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => LoopBackendFailureKind.timeout,
      DioExceptionType.connectionError ||
      DioExceptionType.badCertificate => LoopBackendFailureKind.connection,
      DioExceptionType.cancel => LoopBackendFailureKind.cancelled,
      DioExceptionType.badResponse => switch (statusCode) {
        400 => LoopBackendFailureKind.invalidRequest,
        401 => LoopBackendFailureKind.authentication,
        409 when code == 'bootstrap_required' =>
          LoopBackendFailureKind.invalidRequest,
        429 when code == 'rate_limit_exceeded' =>
          LoopBackendFailureKind.unavailable,
        503 when code == 'request_timeout' => LoopBackendFailureKind.timeout,
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
      code: code,
      requestId: requestId,
    );
  }

  static bool _hasNoStore(Headers headers) {
    final directives = headers['cache-control']
        ?.expand((value) => value.split(','))
        .map((value) => value.trim().toLowerCase());
    return directives?.contains('no-store') ?? false;
  }

  static Map<String, Object?> _strictMap(
    Object? value,
    Set<String> expectedKeys,
  ) {
    if (value is! Map) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String || result.containsKey(key)) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      result[key] = entry.value;
    }
    if (result.length != expectedKeys.length ||
        !expectedKeys.every(result.containsKey)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return result;
  }

  static bool _isPrintableAscii(
    String value, {
    required int minimum,
    required int maximum,
  }) {
    if (value.length < minimum || value.length > maximum) return false;
    return value.codeUnits.every((unit) => unit >= 0x21 && unit <= 0x7e);
  }

  static _LoopStreamErrorMetadata? _parseErrorMetadata(
    Response<Object?>? response,
  ) {
    if (response == null || !_hasNoStore(response.headers)) return null;
    Map<String, Object?> body;
    try {
      body = _strictMap(response.data, const <String>{
        'code',
        'message',
        'request_id',
      });
    } on LoopBackendFailure {
      return null;
    }
    final code = body['code'];
    final message = body['message'];
    final requestId = body['request_id'];
    final responseRequestIds = response.headers['x-request-id'];
    if (code is! String ||
        code.isEmpty ||
        code.length > 64 ||
        !RegExp(r'^[a-z0-9_]+$').hasMatch(code) ||
        !_isStableErrorCodeForStatus(response.statusCode, code) ||
        message is! String ||
        message.isEmpty ||
        message.length > 512 ||
        requestId is! String ||
        !_requestIdPattern.hasMatch(requestId) ||
        responseRequestIds == null ||
        responseRequestIds.length != 1 ||
        responseRequestIds.single != requestId) {
      return null;
    }
    return _LoopStreamErrorMetadata(code: code, requestId: requestId);
  }

  static bool _isStableErrorCodeForStatus(int? statusCode, String code) {
    return switch (statusCode) {
      400 => code == 'invalid_request',
      401 =>
        code == 'authentication_required' || code == 'invalid_access_token',
      409 => code == 'bootstrap_required',
      429 => code == 'rate_limit_exceeded',
      500 => code == 'internal_error',
      503 =>
        code == 'authentication_unavailable' ||
            code == 'stream_unavailable' ||
            code == 'request_timeout',
      _ => false,
    };
  }

  static String _validateApiKey(String value) {
    if (value != value.trim() ||
        !_isPrintableAscii(value, minimum: 1, maximum: 512)) {
      throw ArgumentError('expectedApiKey must be a canonical public value');
    }
    return value;
  }
}

final class _LoopStreamErrorMetadata {
  const _LoopStreamErrorMetadata({required this.code, required this.requestId});

  final String code;
  final String requestId;
}
