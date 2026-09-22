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

  /// Reads, and the refusals **any** authenticated route may answer with.
  ///
  /// Decision 0061 §3 kept them out of the read catalogues on the grounds that
  /// a client allowlist wider than the server's is how a genuinely invalid
  /// payload becomes a rendered refusal. The device answered that: the
  /// catalogue in `loop-api` gives `PERMISSION_DENIED`, `POLICY_BLOCKED` and
  /// `REGION_BLOCKED` the status `403` and `RATE_LIMITED` the status `429`
  /// without restricting either to a route family, so a read that met one was
  /// parsed as an unreadable payload and rendered as an unresolved submission
  /// — 「结果未确认…不要重复提交」 over a page the reader had only opened
  /// (R3-2). A refusal is now read as the refusal it is: every read catalogue
  /// below lists the same `403` triple and `429 RATE_LIMITED`.
  static const readErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED', 'REGION_BLOCKED'},
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

  static const searchErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED', 'REGION_BLOCKED'},
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

  /// The community member directory. `403` also covers the `banned`
  /// governance view, and `429` the alias-prefix query that exhausts the
  /// shared public search quota.
  static const memberListErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED', 'REGION_BLOCKED'},
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

  /// The two Community AI writes (decision 0066).
  ///
  /// They are the write catalogue plus `429 RATE_LIMITED`: a model call is
  /// paid for out of two durable budgets — the caller's own minute and the
  /// community's day — and an exhausted budget is a refusal the reader has to
  /// be told about, not an unreadable payload.
  static const communityAiWriteErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'IDEMPOTENCY_CONFLICT',
      'VERSION_CONFLICT',
    },
    422: <String>{'VALIDATION_FAILED'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  /// S5 reads add the two codes only the chain and market routes can answer
  /// with: a non-BSC `assetId` and an indexer that has never run.
  static const chainReadErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED', 'REGION_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'VERSION_CONFLICT'},
    422: <String>{'CHAIN_MISMATCH', 'VALIDATION_FAILED'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'INDEXING_DELAYED',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  /// A compare-and-set write: no `Idempotency-Key`, `expectedVersion` instead.
  static const casWriteErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'VERSION_CONFLICT'},
    422: <String>{'CHAIN_MISMATCH', 'VALIDATION_FAILED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  /// S6 money-action reads (`preflight`, intent reads, approval inventory).
  /// `403 POLICY_BLOCKED` is the canary ceiling's own answer.
  static const moneyActionReadErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED', 'REGION_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED'},
    422: <String>{'CHAIN_MISMATCH', 'VALIDATION_FAILED'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'INDEXING_DELAYED',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  /// S6 money-action writes. The five conflict codes are outcomes, not
  /// transport faults: a `SUBMISSION_UNKNOWN` reply means the operation is
  /// locked and must never be resubmitted.
  static const moneyActionWriteErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'IDEMPOTENCY_CONFLICT',
      'INSUFFICIENT_BALANCE',
      'DATA_STALE',
      'QUOTE_EXPIRED',
      'SIMULATION_FAILED',
      'SUBMISSION_UNKNOWN',
    },
    422: <String>{'CHAIN_MISMATCH', 'VALIDATION_FAILED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'INDEXING_DELAYED',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  /// An idempotent create: one canonical UUIDv4 per logical operation.
  static const chainIdempotentWriteErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    403: <String>{'PERMISSION_DENIED', 'POLICY_BLOCKED'},
    404: <String>{'NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'IDEMPOTENCY_CONFLICT',
      'VERSION_CONFLICT',
    },
    422: <String>{'CHAIN_MISMATCH', 'VALIDATION_FAILED'},
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
    LoopV2WriteOrigin? origin,
  }) => Options(
    headers: <String, String>{
      ...writeHeaders(accessToken, clientVersion, idempotencyKey),
      ...?origin?.headers,
    },
    contentType: hasBody ? Headers.jsonContentType : null,
    followRedirects: false,
    responseType: ResponseType.json,
  );

  /// A compare-and-set write. It deliberately carries no `Idempotency-Key`:
  /// the server answers `400 INVALID_REQUEST` when one is present, because the
  /// version, not a key, is what makes the write safe to retry.
  static Options casOptions(
    String accessToken,
    String clientVersion, {
    bool hasBody = false,
    LoopV2WriteOrigin? origin,
  }) => Options(
    headers: <String, String>{
      ...readHeaders(accessToken, clientVersion),
      ...?origin?.headers,
    },
    contentType: hasBody ? Headers.jsonContentType : null,
    followRedirects: false,
    responseType: ResponseType.json,
  );
}

/// The optional platform and device annotation a write may carry.
///
/// Both headers are validated by the server when present, so a malformed value
/// is rejected here rather than sent. They are never added to a read.
final class LoopV2WriteOrigin {
  const LoopV2WriteOrigin({required this.platform, required this.deviceId});

  static const iosPlatform = 'ios';
  static const androidPlatform = 'android';

  final String platform;
  final String deviceId;

  /// `null` when either value would break the contract; the write then goes
  /// out without the optional annotation instead of failing.
  static LoopV2WriteOrigin? tryCreate({
    required String? platform,
    required String? deviceId,
  }) {
    if (platform == null || deviceId == null) return null;
    if (platform != iosPlatform && platform != androidPlatform) return null;
    if (!LoopV2Contract.uuidV4Pattern.hasMatch(deviceId)) return null;
    return LoopV2WriteOrigin(platform: platform, deviceId: deviceId);
  }

  Map<String, String> get headers => <String, String>{
    'x-loop-platform': platform,
    'x-loop-device-id': deviceId,
  };
}
