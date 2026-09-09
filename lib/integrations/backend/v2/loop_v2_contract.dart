import 'package:dio/dio.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';

abstract final class LoopV2Contract {
  static final RegExp uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  static final RegExp streamUserIdPattern = RegExp(r'^loop_[a-z0-9_-]{8,58}$');
  static final RegExp reasonCodePattern = RegExp(r'^[A-Z][A-Z0-9_]*$');
  static final RegExp userMessageKeyPattern = RegExp(
    r'^errors\.[A-Za-z0-9.]+$',
  );
  static final RegExp providerReferencePattern = RegExp(r'^[A-Za-z0-9._:-]+$');

  static const categories = <String>{
    'authentication',
    'authorization',
    'availability',
    'conflict',
    'internal',
    'rateLimit',
    'stale',
    'validation',
  };

  static String validateSuccess(
    Response<Object?> response, {
    required int statusCode,
  }) {
    if (response.statusCode != statusCode || !_hasExactNoStore(response)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return _requestId(response);
  }

  static LoopBackendFailure mapDioFailure(
    DioException error, {
    required Map<int, Set<String>> allowedCodes,
  }) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const LoopBackendFailure(LoopBackendFailureKind.timeout);
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return const LoopBackendFailure(LoopBackendFailureKind.connection);
      case DioExceptionType.cancel:
        return const LoopBackendFailure(LoopBackendFailureKind.cancelled);
      case DioExceptionType.unknown:
        return const LoopBackendFailure(LoopBackendFailureKind.unexpected);
      case DioExceptionType.badResponse:
        break;
    }

    final response = error.response;
    final statusCode = response?.statusCode;
    if (response == null ||
        statusCode == null ||
        !_hasExactNoStore(response) ||
        !allowedCodes.containsKey(statusCode)) {
      return LoopBackendFailure(
        LoopBackendFailureKind.invalidPayload,
        statusCode: statusCode,
      );
    }

    try {
      final requestId = _requestId(response);
      final root = strictMap(response.data, const <String>{
        'code',
        'category',
        'retryable',
        'userMessageKey',
        'correlationId',
        'detailsSafe',
        'providerReferenceSafe',
      });
      final code = root['code'];
      final category = root['category'];
      final retryable = root['retryable'];
      final userMessageKey = root['userMessageKey'];
      final correlationId = root['correlationId'];
      final detailsSafe = root['detailsSafe'];
      final providerReferenceSafe = root['providerReferenceSafe'];
      final allowedForStatus = allowedCodes[statusCode]!;
      if (code is! String ||
          !allowedForStatus.contains(code) ||
          category is! String ||
          !categories.contains(category) ||
          retryable is! bool ||
          userMessageKey is! String ||
          userMessageKey.length > 128 ||
          !userMessageKeyPattern.hasMatch(userMessageKey) ||
          correlationId is! String ||
          correlationId != requestId ||
          !uuidPattern.hasMatch(correlationId) ||
          (detailsSafe != null && detailsSafe is! Map) ||
          (providerReferenceSafe != null &&
              (providerReferenceSafe is! String ||
                  providerReferenceSafe.length > 128 ||
                  !providerReferencePattern.hasMatch(providerReferenceSafe)))) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      if (statusCode == 401 && !_hasExactBearerChallenge(response)) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      return LoopBackendFailure(
        _kindForCode(code),
        statusCode: statusCode,
        code: code,
        requestId: requestId,
        category: category,
        retryable: retryable,
        userMessageKey: userMessageKey,
        // `detailsSafe` is an open object on the wire, so it is read through a
        // fixed scalar allowlist rather than carried through as-is.
        detailsSafe: LoopFailureDetails.tryRead(detailsSafe),
      );
    } on LoopBackendFailure catch (failure) {
      return LoopBackendFailure(failure.kind, statusCode: statusCode);
    } catch (_) {
      return LoopBackendFailure(
        LoopBackendFailureKind.invalidPayload,
        statusCode: statusCode,
      );
    }
  }

  static Map<String, Object?> strictMap(
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

  static String requiredString(
    Map<String, Object?> source,
    String key, {
    required RegExp pattern,
    int? minLength,
    int? maxLength,
  }) {
    final value = source[key];
    if (value is! String ||
        (minLength != null && value.length < minLength) ||
        (maxLength != null && value.length > maxLength) ||
        !pattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return value;
  }

  static bool _hasExactNoStore(Response<Object?> response) {
    final values = response.headers['cache-control'];
    return values != null &&
        values.length == 1 &&
        values.single.trim().toLowerCase() == 'no-store';
  }

  static String _requestId(Response<Object?> response) {
    final values = response.headers['x-request-id'];
    if (values == null || values.length != 1) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final value = values.single.trim().toLowerCase();
    if (!uuidPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return value;
  }

  static bool _hasExactBearerChallenge(Response<Object?> response) {
    final values = response.headers['www-authenticate'];
    return values != null &&
        values.length == 1 &&
        values.single == 'Bearer realm="loop-api"';
  }

  static LoopBackendFailureKind _kindForCode(String code) {
    return switch (code) {
      'AUTH_REQUIRED' ||
      'AUTH_INVALID' => LoopBackendFailureKind.authentication,
      'INVALID_REQUEST' ||
      'VERSION_CONFLICT' ||
      'IDEMPOTENCY_CONFLICT' ||
      'ACCOUNT_BOOTSTRAP_REQUIRED' ||
      'SESSION_NOT_FOUND' ||
      'VALIDATION_FAILED' ||
      'ALIAS_RESERVED' ||
      'ALIAS_BLOCKED' ||
      'DATA_STALE' ||
      'RESOURCE_CONFLICT' ||
      'PROFILE_ACTIVATION_REQUIRED' ||
      'CHAIN_MISMATCH' ||
      'INSUFFICIENT_BALANCE' ||
      'QUOTE_EXPIRED' ||
      'SIMULATION_FAILED' ||
      'SUBMISSION_UNKNOWN' => LoopBackendFailureKind.invalidRequest,
      'REQUEST_TIMEOUT' => LoopBackendFailureKind.timeout,
      'RATE_LIMITED' ||
      'NOT_FOUND' ||
      'AUTH_STEP_UP_REQUIRED' ||
      'PERMISSION_DENIED' ||
      'POLICY_BLOCKED' ||
      'REGION_BLOCKED' ||
      'CAPABILITY_UNAVAILABLE' ||
      'PROVIDER_DISCONNECTED' ||
      'INDEXING_DELAYED' ||
      'INTERNAL_ERROR' => LoopBackendFailureKind.unavailable,
      _ => LoopBackendFailureKind.invalidPayload,
    };
  }
}
