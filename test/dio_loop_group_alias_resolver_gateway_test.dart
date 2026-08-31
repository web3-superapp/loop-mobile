import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/social/dio_loop_group_alias_gateway.dart';

const _channelIdValue = 'loop_group_aabbccddeeff00112233';
const _groupIdValue = 'e464386d-cd85-472d-9b22-2d94412ad413';
const _requestId = '7a7448be-64e2-4f9f-a9f1-891f1beec7fd';

void main() {
  group('DioLoopGroupAliasGateway.resolveGroup', () {
    test('sends the exact authenticated resolver request', () async {
      late RequestOptions captured;
      final fixture = await _fixture((options, handler) {
        captured = options;
        handler.resolve(
          _response(
            options,
            data: const <String, Object?>{'group_id': _groupIdValue},
          ),
        );
      });
      addTearDown(fixture.dispose);

      final groupId = await fixture.gateway.resolveGroup(_channelId());

      expect(groupId, GroupId.fromWire(_groupIdValue));
      expect(captured.method, 'POST');
      expect(captured.uri.path, '/v1/chat/groups/resolve');
      expect(captured.queryParameters, isEmpty);
      expect(captured.data, <String, Object?>{
        'stream_channel_id': _channelIdValue,
      });
      expect(captured.data.toString(), isNot(contains('messaging:')));
      expect(_header(captured, 'authorization'), 'Bearer access-token-1');
      expect(_header(captured, 'accept'), Headers.jsonContentType);
      expect(_header(captured, 'content-type'), Headers.jsonContentType);
      expect(_header(captured, 'idempotency-key'), isNull);
      expect(captured.followRedirects, isFalse);
      expect(fixture.requestTokens.calls, 1);
    });

    test('requires an exact body and strict response proof', () async {
      final cases = <({Object? body, Headers headers})>[
        (
          body: const <String, Object?>{
            'group_id': _groupIdValue,
            'stream_channel_id': _channelIdValue,
          },
          headers: _strictHeaders(),
        ),
        (body: const <String, Object?>{}, headers: _strictHeaders()),
        (
          body: const <String, Object?>{
            'group_id': 'E464386D-CD85-472D-9B22-2D94412AD413',
          },
          headers: _strictHeaders(),
        ),
        (
          body: const <String, Object?>{'group_id': _groupIdValue},
          headers: Headers.fromMap(<String, List<String>>{
            'x-request-id': <String>[_requestId],
          }),
        ),
        (
          body: const <String, Object?>{'group_id': _groupIdValue},
          headers: Headers.fromMap(<String, List<String>>{
            'cache-control': <String>['private', 'no-store'],
            'x-request-id': <String>['not-a-uuid'],
          }),
        ),
        (
          body: const <String, Object?>{'group_id': _groupIdValue},
          headers: Headers.fromMap(<String, List<String>>{
            'cache-control': <String>['no-store'],
            'x-request-id': <String>[_requestId, _requestId],
          }),
        ),
      ];

      for (final testCase in cases) {
        var requests = 0;
        final fixture = await _fixture((options, handler) {
          requests += 1;
          handler.resolve(
            _response(options, data: testCase.body, headers: testCase.headers),
          );
        });
        try {
          await expectLater(
            fixture.gateway.resolveGroup(_channelId()),
            throwsA(_failure(GroupAliasGatewayFailureKind.invalidData)),
          );
          expect(requests, 1);
        } finally {
          fixture.dispose();
        }
      }
    });

    test(
      'rejects a known direct CID locally without token or HTTP work',
      () async {
        var requests = 0;
        final fixture = await _fixture((options, handler) {
          requests += 1;
          handler.resolve(
            _response(
              options,
              data: const <String, Object?>{'group_id': _groupIdValue},
            ),
          );
        });
        addTearDown(fixture.dispose);

        expect(
          () => GroupAliasStreamChannelId.fromCid(
            'messaging:loop_direct_aabbccddeeff00112233',
          ),
          throwsA(isA<InvalidGroupAliasContractException>()),
        );
        expect(requests, 0);
        expect(fixture.requestTokens.calls, 0);
      },
    );

    test('maps strict 404 and 503 responses without retrying', () async {
      final cases =
          <({int statusCode, String code, GroupAliasGatewayFailureKind kind})>[
            (
              statusCode: 404,
              code: 'not_found',
              kind: GroupAliasGatewayFailureKind.notFound,
            ),
            (
              statusCode: 503,
              code: 'chat_group_unavailable',
              kind: GroupAliasGatewayFailureKind.unavailable,
            ),
          ];

      for (final testCase in cases) {
        var requests = 0;
        final fixture = await _fixture((options, handler) {
          requests += 1;
          handler.reject(
            _httpError(
              options,
              statusCode: testCase.statusCode,
              code: testCase.code,
            ),
          );
        });
        try {
          await expectLater(
            fixture.gateway.resolveGroup(_channelId()),
            throwsA(_failure(testCase.kind)),
          );
          expect(requests, 1);
          expect(fixture.requestTokens.calls, 1);
        } finally {
          fixture.dispose();
        }
      }
    });

    test('uses the session one-401 refresh budget', () async {
      final requests = <RequestOptions>[];
      final fixture = await _fixture((options, handler) {
        requests.add(options);
        if (requests.length == 1) {
          handler.reject(
            _httpError(options, statusCode: 401, code: 'invalid_access_token'),
          );
          return;
        }
        handler.resolve(
          _response(
            options,
            data: const <String, Object?>{'group_id': _groupIdValue},
          ),
        );
      });
      addTearDown(fixture.dispose);

      final result = await fixture.gateway.resolveGroup(_channelId());

      expect(result, GroupId.fromWire(_groupIdValue));
      expect(requests, hasLength(2));
      expect(
        requests.map((request) => _header(request, 'authorization')),
        <Object?>['Bearer access-token-1', 'Bearer access-token-2'],
      );
      expect(fixture.requestTokens.calls, 2);
      expect(fixture.bootstrapRepository.calls, 1);
    });

    test('uses the session one-bootstrap recovery budget', () async {
      final requests = <RequestOptions>[];
      final fixture = await _fixture((options, handler) {
        requests.add(options);
        if (requests.length == 1) {
          handler.reject(
            _httpError(options, statusCode: 409, code: 'bootstrap_required'),
          );
          return;
        }
        handler.resolve(
          _response(
            options,
            data: const <String, Object?>{'group_id': _groupIdValue},
          ),
        );
      });
      addTearDown(fixture.dispose);

      final result = await fixture.gateway.resolveGroup(_channelId());

      expect(result, GroupId.fromWire(_groupIdValue));
      expect(requests, hasLength(2));
      expect(fixture.bootstrapRepository.calls, 2);
      expect(fixture.bootstrapTokens.calls, 2);
      expect(fixture.requestTokens.calls, 2);
    });
  });
}

GroupAliasStreamChannelId _channelId() =>
    GroupAliasStreamChannelId.fromCid('messaging:$_channelIdValue');

Future<_Fixture> _fixture(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) async {
  final bootstrapRepository = _BootstrapRepository();
  final bootstrapTokens = _AccessTokens(prefix: 'bootstrap-token');
  final bootstrapSession = LoopBootstrapSession(
    principalKey: 'did:privy:owner-a',
    accessTokens: bootstrapTokens,
    repository: bootstrapRepository,
  );
  expect(
    await bootstrapSession.authorize(),
    LoopBootstrapAuthorization.authorized,
  );
  final requestTokens = _AccessTokens(prefix: 'access-token');
  final session = LoopAuthenticatedSession(
    principalKey: 'did:privy:owner-a',
    bootstrapSession: bootstrapSession,
    accessTokens: requestTokens,
  );
  final dio = Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return _Fixture(
    dio: dio,
    gateway: DioLoopGroupAliasGateway(dio: dio, session: session),
    session: session,
    bootstrapSession: bootstrapSession,
    bootstrapRepository: bootstrapRepository,
    bootstrapTokens: bootstrapTokens,
    requestTokens: requestTokens,
  );
}

final class _Fixture {
  const _Fixture({
    required this.dio,
    required this.gateway,
    required this.session,
    required this.bootstrapSession,
    required this.bootstrapRepository,
    required this.bootstrapTokens,
    required this.requestTokens,
  });

  final Dio dio;
  final DioLoopGroupAliasGateway gateway;
  final LoopAuthenticatedSession session;
  final LoopBootstrapSession bootstrapSession;
  final _BootstrapRepository bootstrapRepository;
  final _AccessTokens bootstrapTokens;
  final _AccessTokens requestTokens;

  void dispose() {
    session.dispose();
    bootstrapSession.dispose();
    dio.close(force: true);
  }
}

final class _AccessTokens implements LoopBackendAccessTokenSource {
  _AccessTokens({required this.prefix});

  final String prefix;
  var calls = 0;

  @override
  Future<String> loadAccessToken() async {
    calls += 1;
    return '$prefix-$calls';
  }
}

final class _BootstrapRepository implements LoopBootstrapRepository {
  var calls = 0;

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    calls += 1;
    return const LoopBootstrapIdentity(
      loopUserId: _requestId,
      streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
    );
  }
}

Response<Object?> _response(
  RequestOptions options, {
  required Object? data,
  Headers? headers,
}) => Response<Object?>(
  requestOptions: options,
  statusCode: 200,
  data: data,
  headers: headers ?? _strictHeaders(),
);

DioException _httpError(
  RequestOptions options, {
  required int statusCode,
  required String code,
}) => DioException(
  requestOptions: options,
  type: DioExceptionType.badResponse,
  response: Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: <String, Object?>{
      'code': code,
      'message': 'Sanitized public message.',
      'request_id': _requestId,
    },
    headers: _strictHeaders(),
  ),
);

Headers _strictHeaders() => Headers.fromMap(<String, List<String>>{
  'cache-control': <String>['private', 'no-store'],
  'x-request-id': <String>[_requestId],
});

Object? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

TypeMatcher<GroupAliasGatewayException> _failure(
  GroupAliasGatewayFailureKind kind,
) => isA<GroupAliasGatewayException>().having(
  (failure) => failure.kind,
  'kind',
  kind,
);
