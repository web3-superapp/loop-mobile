import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_repository.dart';

void main() {
  group('LoopBackendEndpoint', () {
    test('accepts HTTPS and loopback HTTP development origins only', () {
      expect(
        LoopBackendEndpoint.tryParse(' https://api-dev.quant-dinger.cc ')
            ?.baseUrl,
        'https://api-dev.quant-dinger.cc/',
      );
      expect(
        LoopBackendEndpoint.tryParse('http://127.0.0.1:3000')?.baseUrl,
        'http://127.0.0.1:3000/',
      );
      expect(LoopBackendEndpoint.tryParse('http://api.example.com'), isNull);
      expect(LoopBackendEndpoint.tryParse('https://user@example.com'), isNull);
      expect(
        LoopBackendEndpoint.tryParse('https://api.example.com/base'),
        isNull,
      );
      expect(
        LoopBackendEndpoint.tryParse('https://api.example.com?token=x'),
        isNull,
      );
    });
  });

  group('DioLoopBootstrapRepository', () {
    test(
      'posts the exact Bearer-only bootstrap request and parses identity',
      () async {
        RequestOptions? captured;
        final repository = DioLoopBootstrapRepository(
          _dio((options, handler) {
            captured = options;
            handler.resolve(
              _response(options, const <String, Object?>{
                'user': <String, Object?>{
                  'id': '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
                },
                'stream_user_id': 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
              }),
            );
          }),
        );

        final identity = await repository.bootstrap(
          accessToken: 'current-access-token',
        );

        expect(captured?.method, 'POST');
        expect(
          captured?.uri,
          Uri.parse('https://api-dev.quant-dinger.cc/v1/bootstrap'),
        );
        expect(captured?.queryParameters, isEmpty);
        expect(captured?.data, isNull);
        expect(captured?.followRedirects, isFalse);
        expect(_authorization(captured!), 'Bearer current-access-token');
        expect(identity.loopUserId, '7a7448be-64e2-4f9f-a9f1-891f1beec7fd');
        expect(identity.streamUserId, 'loop_7a7448be64e24f9fa9f1891f1beec7fd');
      },
    );

    test('accepts no-store across repeated cache-control fields', () async {
      final repository = DioLoopBootstrapRepository(
        _dio((options, handler) {
          handler.resolve(
            _response(
              options,
              const <String, Object?>{
                'user': <String, Object?>{
                  'id': '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
                },
                'stream_user_id': 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
              },
              cacheControlValues: const <String>['private', 'no-store'],
            ),
          );
        }),
      );

      final identity = await repository.bootstrap(accessToken: 'access-token');

      expect(identity.loopUserId, '7a7448be-64e2-4f9f-a9f1-891f1beec7fd');
    });

    test('rejects contract drift and a missing no-store response', () async {
      final payloads = <(Object?, String?)>[
        (
          const <String, Object?>{
            'user': <String, Object?>{
              'id': '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
            },
            'stream_user_id': 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
            'token': 'must-not-enter-bootstrap',
          },
          'no-store',
        ),
        (
          const <String, Object?>{
            'user': <String, Object?>{'id': 'not-a-uuid'},
            'stream_user_id': 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
          },
          'no-store',
        ),
        (
          const <String, Object?>{
            'user': <String, Object?>{
              'id': '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
            },
            'stream_user_id': 'did:privy:client-selected',
          },
          'no-store',
        ),
        (
          const <String, Object?>{
            'user': <String, Object?>{
              'id': '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
            },
            'stream_user_id': 'loop_11111111111111111111111111111111',
          },
          'no-store',
        ),
        (
          const <String, Object?>{
            'user': <String, Object?>{
              'id': '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
            },
            'stream_user_id': 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
          },
          null,
        ),
      ];

      for (final (payload, cacheControl) in payloads) {
        final repository = DioLoopBootstrapRepository(
          _dio((options, handler) {
            handler.resolve(
              _response(options, payload, cacheControl: cacheControl),
            );
          }),
        );

        await expectLater(
          repository.bootstrap(accessToken: 'access-token'),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      }
    });

    test(
      'rejects a valid identity returned under a non-contract 2xx',
      () async {
        final repository = DioLoopBootstrapRepository(
          _dio((options, handler) {
            handler.resolve(
              _response(options, const <String, Object?>{
                'user': <String, Object?>{
                  'id': '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
                },
                'stream_user_id': 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
              }, statusCode: 201),
            );
          }),
        );

        await expectLater(
          repository.bootstrap(accessToken: 'access-token'),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      },
    );

    test('maps sanitized HTTP and transport failures', () async {
      final cases = <(DioExceptionType, int?, String?, LoopBackendFailureKind)>[
        (
          DioExceptionType.badResponse,
          401,
          'invalid_access_token',
          LoopBackendFailureKind.authentication,
        ),
        (
          DioExceptionType.badResponse,
          400,
          'invalid_request',
          LoopBackendFailureKind.invalidRequest,
        ),
        (
          DioExceptionType.badResponse,
          503,
          'authentication_unavailable',
          LoopBackendFailureKind.unavailable,
        ),
        (
          DioExceptionType.badResponse,
          503,
          'request_timeout',
          LoopBackendFailureKind.timeout,
        ),
        (
          DioExceptionType.connectionTimeout,
          null,
          null,
          LoopBackendFailureKind.timeout,
        ),
        (
          DioExceptionType.connectionError,
          null,
          null,
          LoopBackendFailureKind.connection,
        ),
        (DioExceptionType.cancel, null, null, LoopBackendFailureKind.cancelled),
      ];

      for (final (type, status, code, expected) in cases) {
        final repository = DioLoopBootstrapRepository(
          _dio((options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                response: status == null
                    ? null
                    : Response<Object?>(
                        requestOptions: options,
                        statusCode: status,
                        data: <String, Object?>{
                          'code': code,
                          'message': 'private provider details',
                          'request_id': 'request-1',
                        },
                      ),
                type: type,
              ),
            );
          }),
        );

        await expectLater(
          repository.bootstrap(accessToken: 'access-token'),
          throwsA(
            _failure(expected)
                .having((failure) => failure.statusCode, 'status', status)
                .having((failure) => failure.code, 'code', code)
                .having(
                  (failure) => failure.toString(),
                  'sanitized',
                  isNot(contains('private provider details')),
                ),
          ),
        );
      }
    });

    test('rejects blank tokens before any request is sent', () async {
      var requests = 0;
      final repository = DioLoopBootstrapRepository(
        _dio((options, handler) {
          requests += 1;
          handler.resolve(_response(options, const <String, Object?>{}));
        }),
      );

      await expectLater(
        repository.bootstrap(accessToken: '  '),
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

Response<Object?> _response(
  RequestOptions options,
  Object? data, {
  String? cacheControl = 'no-store',
  List<String>? cacheControlValues,
  int statusCode = 200,
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: cacheControl == null && cacheControlValues == null
        ? Headers()
        : Headers.fromMap(<String, List<String>>{
            'cache-control': cacheControlValues ?? <String>[cacheControl!],
          }),
  );
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
