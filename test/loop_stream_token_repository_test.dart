import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token_repository.dart';

void main() {
  const streamUserId = 'loop_7a7448be64e24f9fa9f1891f1beec7fd';
  const apiKey = 'public-stream-api-key';
  const requestId = '7a7448be-64e2-4f9f-a9f1-891f1beec7fd';
  final now = DateTime.utc(2026, 8, 29, 12);
  final expiresAt = now.add(const Duration(hours: 1));
  final token = List<String>.filled(64, 't').join();

  group('DioLoopStreamTokenRepository', () {
    test(
      'posts exact Chat and Video requests and returns only SDK token',
      () async {
        final requests = <RequestOptions>[];
        final repository = DioLoopStreamTokenRepository(
          _dio((options, handler) {
            requests.add(options);
            handler.resolve(
              _successResponse(
                options,
                apiKey: apiKey,
                token: token,
                streamUserId: streamUserId,
                expiresAt: expiresAt,
              ),
            );
          }),
          expectedApiKey: apiKey,
          now: () => now,
        );

        final chat = await repository.issue(
          product: LoopStreamTokenProduct.chat,
          expectedStreamUserId: streamUserId,
          accessToken: 'current-chat-access-token',
        );
        final video = await repository.issue(
          product: LoopStreamTokenProduct.video,
          expectedStreamUserId: streamUserId,
          accessToken: 'current-video-access-token',
        );

        expect(requests.map((request) => request.uri.path), <String>[
          '/v1/chat/token',
          '/v1/video/token',
        ]);
        expect(requests.every((request) => request.method == 'POST'), isTrue);
        expect(requests.every((request) => request.data == null), isTrue);
        expect(
          requests.every((request) => request.queryParameters.isEmpty),
          isTrue,
        );
        expect(requests.every((request) => !request.followRedirects), isTrue);
        expect(
          _authorization(requests.first),
          'Bearer current-chat-access-token',
        );
        expect(
          _authorization(requests.last),
          'Bearer current-video-access-token',
        );
        expect(chat.token, token);
        expect(chat.expiresAt, expiresAt);
        expect(video.token, token);
        expect(video.expiresAt, expiresAt);
      },
    );

    test('accepts no-store across repeated cache-control fields', () async {
      final repository = DioLoopStreamTokenRepository(
        _dio((options, handler) {
          handler.resolve(
            _successResponse(
              options,
              apiKey: apiKey,
              token: token,
              streamUserId: streamUserId,
              expiresAt: expiresAt,
              cacheControlValues: const <String>['private', 'no-store'],
            ),
          );
        }),
        expectedApiKey: apiKey,
        now: () => now,
      );

      final credential = await repository.issue(
        product: LoopStreamTokenProduct.chat,
        expectedStreamUserId: streamUserId,
        accessToken: 'access-token',
      );

      expect(credential.token, token);
    });

    test('rejects response drift before exposing a token', () async {
      final valid = <String, Object?>{
        'api_key': apiKey,
        'token': token,
        'expires_at': expiresAt.toIso8601String(),
        'user': <String, Object?>{'id': streamUserId},
      };
      final cases = <(Object?, Headers)>[
        (<String, Object?>{...valid, 'role': 'admin'}, _noStoreHeaders()),
        (
          <String, Object?>{...valid, 'api_key': 'other-app'},
          _noStoreHeaders(),
        ),
        (
          <String, Object?>{
            ...valid,
            'user': <String, Object?>{
              'id': 'loop_11111111111111111111111111111111',
            },
          },
          _noStoreHeaders(),
        ),
        (<String, Object?>{...valid, 'token': 'too-short'}, _noStoreHeaders()),
        (
          <String, Object?>{
            ...valid,
            'expires_at': now
                .subtract(const Duration(seconds: 1))
                .toIso8601String(),
          },
          _noStoreHeaders(),
        ),
        (
          <String, Object?>{
            ...valid,
            'expires_at': now
                .add(const Duration(minutes: 66))
                .toIso8601String(),
          },
          _noStoreHeaders(),
        ),
        (valid, Headers()),
      ];

      for (final (payload, headers) in cases) {
        final repository = DioLoopStreamTokenRepository(
          _dio((options, handler) {
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: payload,
                headers: headers,
              ),
            );
          }),
          expectedApiKey: apiKey,
          now: () => now,
        );

        await expectLater(
          repository.issue(
            product: LoopStreamTokenProduct.chat,
            expectedStreamUserId: streamUserId,
            accessToken: 'access-token',
          ),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      }
    });

    test('maps only strict sanitized backend errors', () async {
      final cases = <(int, String, LoopBackendFailureKind)>[
        (400, 'invalid_request', LoopBackendFailureKind.invalidRequest),
        (401, 'authentication_required', LoopBackendFailureKind.authentication),
        (401, 'invalid_access_token', LoopBackendFailureKind.authentication),
        (409, 'bootstrap_required', LoopBackendFailureKind.invalidRequest),
        (429, 'rate_limit_exceeded', LoopBackendFailureKind.unavailable),
        (503, 'request_timeout', LoopBackendFailureKind.timeout),
        (503, 'authentication_unavailable', LoopBackendFailureKind.unavailable),
        (503, 'stream_unavailable', LoopBackendFailureKind.unavailable),
        (500, 'internal_error', LoopBackendFailureKind.unavailable),
      ];

      for (final (status, code, expectedKind) in cases) {
        final repository = DioLoopStreamTokenRepository(
          _dio((options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: _errorResponse(
                  options,
                  statusCode: status,
                  code: code,
                  requestId: requestId,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          }),
          expectedApiKey: apiKey,
          now: () => now,
        );

        await expectLater(
          repository.issue(
            product: LoopStreamTokenProduct.video,
            expectedStreamUserId: streamUserId,
            accessToken: 'private-access-token',
          ),
          throwsA(
            _failure(expectedKind)
                .having((failure) => failure.statusCode, 'status', status)
                .having((failure) => failure.code, 'code', code)
                .having((failure) => failure.requestId, 'request ID', requestId)
                .having(
                  (failure) => failure.toString(),
                  'sanitized',
                  isNot(contains('private-access-token')),
                ),
          ),
        );
      }
    });

    test('malformed HTTP errors cannot trigger credential recovery', () async {
      final repository = DioLoopStreamTokenRepository(
        _dio((options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response<Object?>(
                requestOptions: options,
                statusCode: 401,
                data: const <String, Object?>{
                  'code': 'invalid_access_token',
                  'message': 'Authentication failed.',
                  'request_id': requestId,
                },
                headers: _noStoreHeaders(),
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        }),
        expectedApiKey: apiKey,
        now: () => now,
      );

      await expectLater(
        repository.issue(
          product: LoopStreamTokenProduct.chat,
          expectedStreamUserId: streamUserId,
          accessToken: 'access-token',
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test(
      'status and public error code must match the exact contract',
      () async {
        for (final (statusCode, code) in <(int, String)>[
          (401, 'bootstrap_required'),
          (409, 'invalid_access_token'),
          (429, 'internal_error'),
          (500, 'stream_unavailable'),
          (503, 'unknown_public_code'),
        ]) {
          final repository = DioLoopStreamTokenRepository(
            _dio((options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: _errorResponse(
                    options,
                    statusCode: statusCode,
                    code: code,
                    requestId: requestId,
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            }),
            expectedApiKey: apiKey,
            now: () => now,
          );

          await expectLater(
            repository.issue(
              product: LoopStreamTokenProduct.chat,
              expectedStreamUserId: streamUserId,
              accessToken: 'access-token',
            ),
            throwsA(
              _failure(LoopBackendFailureKind.invalidPayload)
                  .having((failure) => failure.statusCode, 'status', statusCode)
                  .having((failure) => failure.code, 'code', isNull)
                  .having((failure) => failure.requestId, 'request ID', isNull),
            ),
          );
        }
      },
    );

    test('rejects invalid local inputs before dispatch', () async {
      var requests = 0;
      final repository = DioLoopStreamTokenRepository(
        _dio((options, handler) {
          requests += 1;
          handler.resolve(
            _successResponse(
              options,
              apiKey: apiKey,
              token: token,
              streamUserId: streamUserId,
              expiresAt: expiresAt,
            ),
          );
        }),
        expectedApiKey: apiKey,
        now: () => now,
      );

      await expectLater(
        repository.issue(
          product: LoopStreamTokenProduct.chat,
          expectedStreamUserId: 'client-selected-user',
          accessToken: 'access-token',
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
      );
      await expectLater(
        repository.issue(
          product: LoopStreamTokenProduct.video,
          expectedStreamUserId: streamUserId,
          accessToken: '  ',
        ),
        throwsA(_failure(LoopBackendFailureKind.authentication)),
      );
      expect(requests, 0);
    });
  });
}

Dio _dio(void Function(RequestOptions, RequestInterceptorHandler) onRequest) {
  return Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
}

Response<Object?> _successResponse(
  RequestOptions options, {
  required String apiKey,
  required String token,
  required String streamUserId,
  required DateTime expiresAt,
  List<String>? cacheControlValues,
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: 200,
    data: <String, Object?>{
      'api_key': apiKey,
      'token': token,
      'expires_at': expiresAt.toIso8601String(),
      'user': <String, Object?>{'id': streamUserId},
    },
    headers: cacheControlValues == null
        ? _noStoreHeaders()
        : Headers.fromMap(<String, List<String>>{
            'cache-control': cacheControlValues,
          }),
  );
}

Response<Object?> _errorResponse(
  RequestOptions options, {
  required int statusCode,
  required String code,
  required String requestId,
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: <String, Object?>{
      'code': code,
      'message': 'Sanitized public message.',
      'request_id': requestId,
    },
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': <String>['no-store'],
      'x-request-id': <String>[requestId],
    }),
  );
}

Headers _noStoreHeaders() {
  return Headers.fromMap(<String, List<String>>{
    'cache-control': <String>['no-store'],
  });
}

Object? _authorization(RequestOptions options) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == 'authorization') return entry.value;
  }
  return null;
}

TypeMatcher<LoopBackendFailure> _failure(LoopBackendFailureKind kind) {
  return isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    kind,
  );
}
