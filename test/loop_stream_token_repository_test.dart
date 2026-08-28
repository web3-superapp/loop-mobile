import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token_repository.dart';

const _apiKey = 'public-stream-key';
const _providerToken = 'abcdefghijklmnopqrstuvwxyz123456';
const _streamUserId = 'loop_7a7448be64e24f9fa9f1891f1beec7fd';
const _requestId = '7a7448be-64e2-4f9f-a9f1-891f1beec7fd';
final _now = DateTime.utc(2026, 8, 28);

void main() {
  group('DioLoopStreamTokenRepository', () {
    test('posts the exact Bearer-only Chat request and parses token', () async {
      RequestOptions? captured;
      final repository = _repository((options, handler) {
        captured = options;
        handler.resolve(_success(options));
      });

      final issued = await repository.issueChatToken(
        accessToken: 'current-access-token',
      );

      expect(captured?.method, 'POST');
      expect(
        captured?.uri,
        Uri.parse('https://api-dev.quant-dinger.cc/v1/chat/token'),
      );
      expect(captured?.queryParameters, isEmpty);
      expect(captured?.data, isNull);
      expect(captured?.followRedirects, isFalse);
      expect(_authorization(captured!), 'Bearer current-access-token');
      expect(issued.apiKey, _apiKey);
      expect(issued.token, _providerToken);
      expect(issued.userId, _streamUserId);
      expect(issued.expiresAt, DateTime.utc(2026, 8, 28, 0, 59));
    });

    test('rejects success contract drift before returning a token', () async {
      final cases = <Response<Object?> Function(RequestOptions)>[
        (options) => _success(
          options,
          data: <String, Object?>{..._successBody(), 'role': 'admin'},
        ),
        (options) => _success(
          options,
          data: <String, Object?>{
            ..._successBody(),
            'api_key': 'different-public-key',
          },
        ),
        (options) => _success(
          options,
          data: <String, Object?>{..._successBody(), 'token': 'too-short'},
        ),
        (options) => _success(
          options,
          data: <String, Object?>{
            ..._successBody(),
            'token': '$_providerToken\n',
          },
        ),
        (options) => _success(
          options,
          data: <String, Object?>{
            ..._successBody(),
            'expires_at': '2026-08-28T02:00:00.000Z',
          },
        ),
        (options) => _success(
          options,
          data: <String, Object?>{
            ..._successBody(),
            'user': <String, Object?>{'id': 'did:privy:client-selected'},
          },
        ),
        (options) => _success(options, noStore: false),
        (options) => _success(
          options,
          cacheControlValues: const <String>['private', 'no-store'],
        ),
        (options) => _success(options, requestId: null),
        (options) => _success(options, statusCode: 201),
      ];

      for (final response in cases) {
        final repository = _repository((options, handler) {
          handler.resolve(response(options));
        });

        await expectLater(
          repository.issueChatToken(accessToken: 'access-token'),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      }
    });

    test('rejects expired and non-canonical expiry values', () async {
      for (final expiry in <String>[
        '2026-08-27T23:59:59.000Z',
        '2026-08-28T00:10:00.000Z',
        '2026-08-28T00:59:00Z',
        '2026-08-28T01:59:00+01:00',
      ]) {
        final repository = _repository((options, handler) {
          handler.resolve(
            _success(
              options,
              data: <String, Object?>{..._successBody(), 'expires_at': expiry},
            ),
          );
        });

        await expectLater(
          repository.issueChatToken(accessToken: 'access-token'),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      }
    });

    test('maps only exact sanitized backend errors', () async {
      final cases = <(int, String, LoopBackendFailureKind)>[
        (400, 'invalid_request', LoopBackendFailureKind.invalidRequest),
        (401, 'invalid_access_token', LoopBackendFailureKind.authentication),
        (409, 'bootstrap_required', LoopBackendFailureKind.invalidRequest),
        (429, 'rate_limit_exceeded', LoopBackendFailureKind.unavailable),
        (500, 'internal_error', LoopBackendFailureKind.unavailable),
        (503, 'stream_unavailable', LoopBackendFailureKind.unavailable),
        (503, 'request_timeout', LoopBackendFailureKind.timeout),
      ];

      for (final (status, code, expectedKind) in cases) {
        final repository = _repository((options, handler) {
          handler.reject(_backendError(options, status: status, code: code));
        });

        await expectLater(
          repository.issueChatToken(accessToken: 'access-token'),
          throwsA(
            _failure(expectedKind)
                .having((failure) => failure.statusCode, 'status', status)
                .having((failure) => failure.code, 'code', code)
                .having(
                  (failure) => failure.requestId,
                  'request ID',
                  _requestId,
                )
                .having(
                  (failure) => failure.toString(),
                  'sanitized',
                  isNot(contains('provider-secret')),
                ),
          ),
        );
      }
    });

    test(
      'malformed 401 is a protocol failure and is not refreshable',
      () async {
        final repository = _repository((options, handler) {
          handler.reject(
            _backendError(
              options,
              status: 401,
              code: 'invalid_access_token',
              includeChallenge: false,
            ),
          );
        });

        await expectLater(
          repository.issueChatToken(accessToken: 'access-token'),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      },
    );

    test('maps transport failures without retaining Dio details', () async {
      final cases = <(DioExceptionType, LoopBackendFailureKind)>[
        (DioExceptionType.connectionTimeout, LoopBackendFailureKind.timeout),
        (DioExceptionType.connectionError, LoopBackendFailureKind.connection),
        (DioExceptionType.cancel, LoopBackendFailureKind.cancelled),
      ];

      for (final (type, expectedKind) in cases) {
        final repository = _repository((options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: type,
              message: 'access-token-and-provider-secret',
            ),
          );
        });

        await expectLater(
          repository.issueChatToken(accessToken: 'access-token'),
          throwsA(_failure(expectedKind)),
        );
      }
    });

    test('rejects blank access tokens before making a request', () async {
      var requests = 0;
      final repository = _repository((options, handler) {
        requests += 1;
        handler.resolve(_success(options));
      });

      await expectLater(
        repository.issueChatToken(accessToken: '  '),
        throwsA(_failure(LoopBackendFailureKind.authentication)),
      );
      expect(requests, 0);
    });
  });
}

DioLoopStreamTokenRepository _repository(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return DioLoopStreamTokenRepository(
    dio,
    expectedApiKey: _apiKey,
    now: () => _now,
  );
}

Map<String, Object?> _successBody() => <String, Object?>{
  'api_key': _apiKey,
  'token': _providerToken,
  'expires_at': '2026-08-28T00:59:00.000Z',
  'user': <String, Object?>{'id': _streamUserId},
};

Response<Object?> _success(
  RequestOptions options, {
  Object? data,
  bool noStore = true,
  List<String>? cacheControlValues,
  String? requestId = _requestId,
  int statusCode = 200,
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data ?? _successBody(),
    headers: Headers.fromMap(<String, List<String>>{
      if (noStore)
        'cache-control': cacheControlValues ?? const <String>['no-store'],
      if (requestId != null) 'x-request-id': <String>[requestId],
    }),
  );
}

DioException _backendError(
  RequestOptions options, {
  required int status,
  required String code,
  bool includeChallenge = true,
}) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: <String, Object?>{
        'code': code,
        'message': 'provider-secret must not escape',
        'request_id': _requestId,
      },
      headers: Headers.fromMap(<String, List<String>>{
        'cache-control': <String>['no-store'],
        'x-request-id': <String>[_requestId],
        if (status == 401 && includeChallenge)
          'www-authenticate': <String>['Bearer realm="loop-api"'],
      }),
    ),
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
