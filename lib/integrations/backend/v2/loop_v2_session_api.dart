import 'package:dio/dio.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';

abstract interface class LoopV2SessionApi {
  Future<LoopV2AccountProjection> getAccount({
    required String accessToken,
    required String clientVersion,
  });

  Future<LoopV2BootstrapProjection> bootstrap({
    required String accessToken,
    required LoopV2CommandMetadata command,
  });

  Future<LoopV2LogoutProjection> logout({
    required String accessToken,
    required String sessionId,
    required LoopV2CommandMetadata command,
  });
}

final class DioLoopV2SessionApi implements LoopV2SessionApi {
  DioLoopV2SessionApi(this._dio);

  static const accountPath = '/v2/account/me';
  static const bootstrapPath = '/v2/session/bootstrap';
  static const logoutPath = '/v2/session/logout';

  static final RegExp _clientVersionPattern = RegExp(
    r'^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );

  static const _accountErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    409: <String>{'ACCOUNT_BOOTSTRAP_REQUIRED', 'VERSION_CONFLICT'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };
  static const _bootstrapErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    409: <String>{'IDEMPOTENCY_CONFLICT', 'VERSION_CONFLICT'},
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };
  static const _logoutErrors = <int, Set<String>>{
    400: <String>{'INVALID_REQUEST'},
    401: <String>{'AUTH_REQUIRED', 'AUTH_INVALID'},
    404: <String>{'SESSION_NOT_FOUND'},
    409: <String>{
      'ACCOUNT_BOOTSTRAP_REQUIRED',
      'IDEMPOTENCY_CONFLICT',
      'VERSION_CONFLICT',
    },
    429: <String>{'RATE_LIMITED'},
    500: <String>{'INTERNAL_ERROR'},
    503: <String>{
      'CAPABILITY_UNAVAILABLE',
      'PROVIDER_DISCONNECTED',
      'REQUEST_TIMEOUT',
    },
  };

  final Dio _dio;

  @override
  Future<LoopV2AccountProjection> getAccount({
    required String accessToken,
    required String clientVersion,
  }) async {
    _validateToken(accessToken);
    _validateClientVersion(clientVersion);
    try {
      final response = await _dio.get<Object?>(
        accountPath,
        options: Options(
          headers: <String, String>{
            'authorization': 'Bearer $accessToken',
            'accept': Headers.jsonContentType,
            'x-loop-contract-version': LoopV2ClientMetadata.contractVersion,
            'x-loop-client-version': clientVersion,
          },
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'account',
        'authentication',
        'communication',
        'policyVersion',
        'contractVersion',
      });
      final account = LoopV2Contract.strictMap(root['account'], const <String>{
        'accountId',
      });
      final authentication = LoopV2Contract.strictMap(
        root['authentication'],
        const <String>{'provider', 'authStrength'},
      );
      final communication = LoopV2Contract.strictMap(
        root['communication'],
        const <String>{'streamUserId'},
      );
      final accountId = LoopV2Contract.requiredString(
        account,
        'accountId',
        pattern: LoopV2Contract.uuidPattern,
      );
      final streamUserId = LoopV2Contract.requiredString(
        communication,
        'streamUserId',
        pattern: LoopV2Contract.streamUserIdPattern,
      );
      if (authentication['provider'] != 'privy' ||
          authentication['authStrength'] != 'providerAuthenticated' ||
          root['policyVersion'] != 'sessionPolicyV1' ||
          root['contractVersion'] != LoopV2ClientMetadata.contractVersion) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      return LoopV2AccountProjection(
        accountId: accountId,
        streamUserId: streamUserId,
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: _accountErrors);
    }
  }

  @override
  Future<LoopV2BootstrapProjection> bootstrap({
    required String accessToken,
    required LoopV2CommandMetadata command,
  }) async {
    _validateToken(accessToken);
    _validateCommand(command);
    try {
      final response = await _dio.post<Object?>(
        bootstrapPath,
        options: Options(
          headers: _commandHeaders(accessToken, command),
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'account',
        'session',
        'communication',
        'contractVersion',
      });
      final account = LoopV2Contract.strictMap(root['account'], const <String>{
        'accountId',
      });
      final session = LoopV2Contract.strictMap(root['session'], const <String>{
        'sessionId',
        'deviceId',
        'status',
        'authStrength',
        'policyVersion',
        'createdAt',
        'lastSeenAt',
        'revokedAt',
      });
      final communication = LoopV2Contract.strictMap(
        root['communication'],
        const <String>{'streamUserId'},
      );
      final accountId = LoopV2Contract.requiredString(
        account,
        'accountId',
        pattern: LoopV2Contract.uuidPattern,
      );
      final sessionId = LoopV2Contract.requiredString(
        session,
        'sessionId',
        pattern: LoopV2Contract.uuidPattern,
      );
      final deviceId = LoopV2Contract.requiredString(
        session,
        'deviceId',
        pattern: LoopV2Contract.uuidV4Pattern,
      );
      final streamUserId = LoopV2Contract.requiredString(
        communication,
        'streamUserId',
        pattern: LoopV2Contract.streamUserIdPattern,
      );
      final createdAt = _utcDateTime(session['createdAt']);
      final lastSeenAt = _utcDateTime(session['lastSeenAt']);
      if (deviceId != command.deviceId ||
          session['status'] != 'active' ||
          session['authStrength'] != 'providerAuthenticated' ||
          session['policyVersion'] != 'sessionPolicyV1' ||
          session['revokedAt'] != null ||
          root['contractVersion'] != LoopV2ClientMetadata.contractVersion) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      return LoopV2BootstrapProjection(
        activeSession: LoopV2ActiveSession(
          accountId: accountId,
          sessionId: sessionId,
          streamUserId: streamUserId,
          deviceId: deviceId,
        ),
        createdAt: createdAt,
        lastSeenAt: lastSeenAt,
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: _bootstrapErrors);
    }
  }

  @override
  Future<LoopV2LogoutProjection> logout({
    required String accessToken,
    required String sessionId,
    required LoopV2CommandMetadata command,
  }) async {
    _validateToken(accessToken);
    _validateCommand(command);
    if (!LoopV2Contract.uuidPattern.hasMatch(sessionId)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.post<Object?>(
        logoutPath,
        options: Options(
          headers: <String, String>{
            ..._commandHeaders(accessToken, command),
            'x-loop-session-id': sessionId,
          },
          followRedirects: false,
          responseType: ResponseType.json,
        ),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'session',
        'providerLogoutRequired',
        'contractVersion',
      });
      final session = LoopV2Contract.strictMap(root['session'], const <String>{
        'sessionId',
        'status',
        'revokedAt',
      });
      final returnedSessionId = LoopV2Contract.requiredString(
        session,
        'sessionId',
        pattern: LoopV2Contract.uuidPattern,
      );
      final revokedAt = _utcDateTime(session['revokedAt']);
      if (returnedSessionId != sessionId ||
          session['status'] != 'revoked' ||
          root['providerLogoutRequired'] != true ||
          root['contractVersion'] != LoopV2ClientMetadata.contractVersion) {
        throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
      }
      return LoopV2LogoutProjection(
        sessionId: returnedSessionId,
        revokedAt: revokedAt,
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(error, allowedCodes: _logoutErrors);
    }
  }

  Map<String, String> _commandHeaders(
    String accessToken,
    LoopV2CommandMetadata command,
  ) {
    return <String, String>{
      'authorization': 'Bearer $accessToken',
      'accept': Headers.jsonContentType,
      'x-loop-contract-version': command.contractVersion,
      'x-loop-client-version': command.clientVersion,
      'x-loop-device-id': command.deviceId,
      'idempotency-key': command.idempotencyKey,
      'x-loop-platform': command.platform.wireName,
    };
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

  DateTime _utcDateTime(Object? value) {
    if (value is! String) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidPayload);
    }
    return parsed;
  }
}
