import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_api.dart';

void main() {
  const requestId = '11111111-1111-4111-8111-111111111111';
  const accountId = '6d12a86e-4134-47e6-9312-c5ef75a30f55';
  const sessionId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  const deviceId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const streamUserId = 'loop_6d12a86e413447e69312c5ef75a30f55';
  const command = LoopV2CommandMetadata(
    deviceId: deviceId,
    idempotencyKey: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    clientVersion: '0.1.0+1',
    platform: LoopV2Platform.android,
  );

  test('account/me sends only its exact V2 business headers', () async {
    RequestOptions? captured;
    final api = DioLoopV2SessionApi(
      _dio((options, handler) {
        captured = options;
        handler.resolve(
          _response(options, <String, Object?>{
            'account': <String, Object?>{'accountId': accountId},
            'authentication': <String, Object?>{
              'provider': 'privy',
              'authStrength': 'providerAuthenticated',
            },
            'communication': <String, Object?>{'streamUserId': streamUserId},
            'policyVersion': 'sessionPolicyV1',
            'contractVersion': '2.0',
          }),
        );
      }),
    );

    final account = await api.getAccount(
      accessToken: 'current-token',
      clientVersion: '0.1.0+1',
    );

    expect(captured?.method, 'GET');
    expect(captured?.uri.path, DioLoopV2SessionApi.accountPath);
    expect(captured?.queryParameters, isEmpty);
    expect(captured?.data, isNull);
    expect(_authorization(captured!), 'Bearer current-token');
    expect(_loopHeaders(captured!), <String, Object?>{
      'x-loop-client-version': '0.1.0+1',
      'x-loop-contract-version': '2.0',
    });
    expect(account.accountId, accountId);
    expect(account.streamUserId, streamUserId);
  });

  test('bootstrap sends persisted metadata and parses opaque IDs', () async {
    RequestOptions? captured;
    final api = DioLoopV2SessionApi(
      _dio((options, handler) {
        captured = options;
        handler.resolve(
          _response(options, <String, Object?>{
            'account': <String, Object?>{'accountId': accountId},
            'session': <String, Object?>{
              'sessionId': sessionId,
              'deviceId': deviceId,
              'status': 'active',
              'authStrength': 'providerAuthenticated',
              'policyVersion': 'sessionPolicyV1',
              'createdAt': '2026-09-02T01:00:00.000Z',
              'lastSeenAt': '2026-09-02T01:00:00.000Z',
              'revokedAt': null,
            },
            'communication': <String, Object?>{'streamUserId': streamUserId},
            'contractVersion': '2.0',
          }),
        );
      }),
    );

    final result = await api.bootstrap(
      accessToken: 'current-token',
      command: command,
    );

    expect(captured?.method, 'POST');
    expect(captured?.uri.path, DioLoopV2SessionApi.bootstrapPath);
    expect(captured?.queryParameters, isEmpty);
    expect(captured?.data, isNull);
    expect(_loopHeaders(captured!), <String, Object?>{
      'x-loop-client-version': '0.1.0+1',
      'x-loop-contract-version': '2.0',
      'x-loop-device-id': deviceId,
      'x-loop-platform': 'android',
    });
    expect(_header(captured!, 'idempotency-key'), command.idempotencyKey);
    expect(_header(captured!, 'x-loop-session-id'), isNull);
    expect(result.activeSession.accountId, accountId);
    expect(result.activeSession.sessionId, sessionId);
    expect(result.activeSession.streamUserId, streamUserId);
  });

  test('logout adds only the opaque session header', () async {
    RequestOptions? captured;
    final api = DioLoopV2SessionApi(
      _dio((options, handler) {
        captured = options;
        handler.resolve(
          _response(options, <String, Object?>{
            'session': <String, Object?>{
              'sessionId': sessionId,
              'status': 'revoked',
              'revokedAt': '2026-09-03T01:00:00.000Z',
            },
            'providerLogoutRequired': true,
            'contractVersion': '2.0',
          }),
        );
      }),
    );

    final result = await api.logout(
      accessToken: 'current-token',
      sessionId: sessionId,
      command: command,
    );

    expect(captured?.method, 'POST');
    expect(captured?.uri.path, DioLoopV2SessionApi.logoutPath);
    expect(captured?.data, isNull);
    expect(_header(captured!, 'x-loop-session-id'), sessionId);
    expect(result.sessionId, sessionId);
  });

  test('strict success rejects extra fields and missing response proof', () {
    for (final response in <Response<Object?>>[
      _response(
        RequestOptions(path: DioLoopV2SessionApi.accountPath),
        <String, Object?>{
          'account': <String, Object?>{'accountId': accountId},
          'authentication': <String, Object?>{
            'provider': 'privy',
            'authStrength': 'providerAuthenticated',
          },
          'communication': <String, Object?>{'streamUserId': streamUserId},
          'policyVersion': 'sessionPolicyV1',
          'contractVersion': '2.0',
          'futureField': true,
        },
      ),
      _response(
        RequestOptions(path: DioLoopV2SessionApi.accountPath),
        const <String, Object?>{},
        includeRequestId: false,
      ),
      _response(
        RequestOptions(path: DioLoopV2SessionApi.accountPath),
        const <String, Object?>{},
        cacheControl: 'private, no-store',
      ),
    ]) {
      final api = DioLoopV2SessionApi(
        _dio((options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: response.statusCode,
              data: response.data,
              headers: response.headers,
            ),
          );
        }),
      );
      expect(
        api.getAccount(accessToken: 'current-token', clientVersion: '0.1.0+1'),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    }
  });

  test('V2 errors require the exact envelope and correlation proof', () async {
    final api = DioLoopV2SessionApi(
      _dio((options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: _response(options, <String, Object?>{
              'code': 'ACCOUNT_BOOTSTRAP_REQUIRED',
              'category': 'conflict',
              'retryable': false,
              'userMessageKey': 'errors.account.bootstrapRequired',
              'correlationId': requestId,
              'detailsSafe': null,
              'providerReferenceSafe': null,
            }, statusCode: 409),
          ),
        );
      }),
    );

    await expectLater(
      api.getAccount(accessToken: 'current-token', clientVersion: '0.1.0+1'),
      throwsA(
        _failure(LoopBackendFailureKind.invalidRequest)
            .having((value) => value.statusCode, 'status', 409)
            .having((value) => value.code, 'code', 'ACCOUNT_BOOTSTRAP_REQUIRED')
            .having((value) => value.requestId, 'request id', requestId),
      ),
    );
  });

  test('a mismatched V2 correlation ID is invalid payload', () async {
    final api = DioLoopV2SessionApi(
      _dio((options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: _response(
              options,
              const <String, Object?>{
                'code': 'AUTH_INVALID',
                'category': 'authentication',
                'retryable': false,
                'userMessageKey': 'errors.auth.invalid',
                'correlationId': '22222222-2222-4222-8222-222222222222',
                'detailsSafe': null,
                'providerReferenceSafe': null,
              },
              statusCode: 401,
              bearerChallenge: true,
            ),
          ),
        );
      }),
    );

    await expectLater(
      api.getAccount(accessToken: 'current-token', clientVersion: '0.1.0+1'),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });
}

Dio _dio(void Function(RequestOptions, RequestInterceptorHandler) onRequest) {
  return Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
}

Response<Object?> _response(
  RequestOptions options,
  Object? data, {
  int statusCode = 200,
  String cacheControl = 'no-store',
  bool includeRequestId = true,
  bool bearerChallenge = false,
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': <String>[cacheControl],
      if (includeRequestId)
        'x-request-id': const <String>['11111111-1111-4111-8111-111111111111'],
      if (bearerChallenge)
        'www-authenticate': const <String>['Bearer realm="loop-api"'],
    }),
  );
}

Object? _authorization(RequestOptions options) {
  return _header(options, 'authorization');
}

Object? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name) return entry.value;
  }
  return null;
}

Map<String, Object?> _loopHeaders(RequestOptions options) {
  return <String, Object?>{
    for (final entry in options.headers.entries)
      if (entry.key.toLowerCase().startsWith('x-loop-'))
        entry.key.toLowerCase(): entry.value,
  };
}

TypeMatcher<LoopBackendFailure> _failure(LoopBackendFailureKind kind) {
  return isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    kind,
  );
}
