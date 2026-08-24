import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';

@immutable
final class LoopBackendEndpoint {
  const LoopBackendEndpoint._(this.uri);

  final Uri uri;

  String get baseUrl => uri.toString();

  /// Accepts HTTPS origins and HTTP loopback origins for local development.
  ///
  /// Paths, credentials, query parameters, and fragments are rejected so a
  /// build-time value cannot silently redirect authenticated requests.
  static LoopBackendEndpoint? tryParse(String rawValue) {
    final value = rawValue.trim();
    final parsed = Uri.tryParse(value);
    if (value.isEmpty ||
        parsed == null ||
        !parsed.hasScheme ||
        !parsed.hasAuthority ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        (parsed.path.isNotEmpty && parsed.path != '/')) {
      return null;
    }

    final scheme = parsed.scheme.toLowerCase();
    final host = parsed.host.toLowerCase();
    final loopback =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    if (scheme != 'https' && !(scheme == 'http' && loopback)) {
      return null;
    }

    return LoopBackendEndpoint._(
      parsed.replace(
        scheme: scheme,
        host: host,
        path: '/',
        query: null,
        fragment: null,
      ),
    );
  }
}

/// Strict client for the implemented `POST /v1/bootstrap` contract.
final class DioLoopBootstrapRepository implements LoopBootstrapRepository {
  DioLoopBootstrapRepository(this._dio);

  static const endpointPath = '/v1/bootstrap';

  static final RegExp _loopUserIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final RegExp _streamUserIdPattern = RegExp(r'^loop_[a-z0-9_-]{8,58}$');

  final Dio _dio;

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    if (accessToken.isEmpty || accessToken != accessToken.trim()) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }

    try {
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
      return _parse(response);
    } on DioException catch (error) {
      throw _mapDioFailure(error);
    }
  }

  LoopBootstrapIdentity _parse(Response<Object?> response) {
    if (response.statusCode != 200) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final cacheDirectives = response.headers['cache-control']
        ?.expand((value) => value.split(','))
        .map((value) => value.trim().toLowerCase());
    if (cacheDirectives == null || !cacheDirectives.contains('no-store')) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    final root = _strictMap(response.data, const <String>{
      'user',
      'stream_user_id',
    });
    final user = _strictMap(root['user'], const <String>{'id'});
    final loopUserId = user['id'];
    final streamUserId = root['stream_user_id'];
    if (loopUserId is! String ||
        !_loopUserIdPattern.hasMatch(loopUserId) ||
        streamUserId is! String ||
        !_streamUserIdPattern.hasMatch(streamUserId) ||
        streamUserId != 'loop_${loopUserId.replaceAll('-', '')}') {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }

    return LoopBootstrapIdentity(
      loopUserId: loopUserId,
      streamUserId: streamUserId,
    );
  }

  Map<String, Object?> _strictMap(Object? value, Set<String> expectedKeys) {
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

  LoopBackendFailure _mapDioFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    final code = _publicErrorCode(error.response?.data);
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
        503 when code == 'request_timeout' => LoopBackendFailureKind.timeout,
        503 => LoopBackendFailureKind.unavailable,
        final status when status != null && status >= 500 =>
          LoopBackendFailureKind.unavailable,
        _ => LoopBackendFailureKind.unexpected,
      },
      DioExceptionType.unknown => LoopBackendFailureKind.unexpected,
    };
    return LoopBackendFailure(kind, statusCode: statusCode, code: code);
  }

  String? _publicErrorCode(Object? value) {
    if (value is! Map) return null;
    final code = value['code'];
    if (code is! String ||
        code.isEmpty ||
        code.length > 64 ||
        !RegExp(r'^[a-z0-9_]+$').hasMatch(code)) {
      return null;
    }
    return code;
  }
}
