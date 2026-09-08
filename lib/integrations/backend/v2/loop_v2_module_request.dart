import 'package:dio/dio.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';

/// Header construction shared by the S3 module transports.
///
/// A read request never carries `Idempotency-Key`; a write request always
/// carries exactly one canonical lowercase UUIDv4.
abstract final class LoopV2ModuleRequest {
  static final RegExp clientVersionPattern = RegExp(
    r'^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  static const readErrors = <int, Set<String>>{
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

  static const searchErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    404: <String>{'NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'VERSION_CONFLICT'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  static const writeErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'DATA_STALE',
      'IDEMPOTENCY_CONFLICT',
      'PROFILE_ACTIVATION_REQUIRED',
      'RESOURCE_CONFLICT',
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

  static void validateToken(String accessToken) {
    if (accessToken.isEmpty ||
        accessToken.length > 4096 ||
        accessToken != accessToken.trim()) {
      throw const LoopBackendFailure(LoopBackendFailureKind.authentication);
    }
  }

  static void validateClientVersion(String clientVersion) {
    if (!clientVersionPattern.hasMatch(clientVersion)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
  }

  static void validateIdempotencyKey(String key) {
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(key)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
  }

  static Map<String, String> readHeaders(
    String accessToken,
    String clientVersion,
  ) {
    validateToken(accessToken);
    validateClientVersion(clientVersion);
    return <String, String>{
      'authorization': 'Bearer $accessToken',
      'accept': Headers.jsonContentType,
      'x-loop-contract-version': LoopV2ClientMetadata.contractVersion,
      'x-loop-client-version': clientVersion,
    };
  }

  static Map<String, String> writeHeaders(
    String accessToken,
    String clientVersion,
    String idempotencyKey,
  ) {
    validateIdempotencyKey(idempotencyKey);
    return <String, String>{
      ...readHeaders(accessToken, clientVersion),
      'idempotency-key': idempotencyKey,
    };
  }

  static Options readOptions(String accessToken, String clientVersion) =>
      Options(
        headers: readHeaders(accessToken, clientVersion),
        followRedirects: false,
        responseType: ResponseType.json,
      );

  static Options writeOptions(
    String accessToken,
    String clientVersion,
    String idempotencyKey, {
    bool hasBody = false,
  }) => Options(
    headers: writeHeaders(accessToken, clientVersion, idempotencyKey),
    contentType: hasBody ? Headers.jsonContentType : null,
    followRedirects: false,
    responseType: ResponseType.json,
  );
}
