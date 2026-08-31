import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/social/dio_loop_group_alias_gateway.dart';

const _groupIdValue = 'e464386d-cd85-472d-9b22-2d94412ad413';
const _aliasIdValue = 'bb5e12c2-40e2-4577-9951-57fac0b5ce5e';
const _secondAliasIdValue = 'a36c5221-ea25-4577-89e8-825b376fd12d';
const _requestId = '7a7448be-64e2-4f9f-a9f1-891f1beec7fd';

void main() {
  group('DioLoopGroupAliasGateway transport', () {
    test('sends the exact authenticated group-only requests', () async {
      final requests = <RequestOptions>[];
      final fixture = await _fixture((options, handler) {
        requests.add(options);
        final data = switch ('${options.method} ${options.uri.path}') {
          'GET /v1/chat/groups/$_groupIdValue/me/alias' => _aliasBody(
            projectionState: 'confirmed',
          ),
          'PUT /v1/chat/groups/$_groupIdValue/me/alias' => _aliasBody(
            projectionState: 'pending',
          ),
          'GET /v1/chat/groups/$_groupIdValue/aliases' => _searchBody(),
          _ => throw StateError('unexpected request'),
        };
        handler.resolve(_success(options, data: data));
      });
      addTearDown(fixture.dispose);
      final gateway = fixture.gateway;
      final groupId = GroupId.fromWire(_groupIdValue);

      final loaded = await gateway.loadCurrentAlias(groupId);
      final saved = await gateway.putCurrentAlias(
        groupId: groupId,
        normalizedAlias: 'Night Owl',
      );
      final search = await gateway.searchAliases(
        groupId: groupId,
        normalizedPrefix: 'Ni',
        limit: 7,
      );

      expect(gateway.mode, GroupAliasGatewayMode.production);
      expect(loaded.alias, 'Night Owl');
      expect(loaded.projectionState, GroupAliasProjectionState.confirmed);
      expect(saved.projectionState, GroupAliasProjectionState.pending);
      expect(search.items.map((item) => item.alias), <String>[
        'Night Owl',
        'Nightingale',
      ]);
      expect(search.truncated, isTrue);
      expect(
        requests.map((request) => '${request.method} ${request.uri.path}'),
        <String>[
          'GET /v1/chat/groups/$_groupIdValue/me/alias',
          'PUT /v1/chat/groups/$_groupIdValue/me/alias',
          'GET /v1/chat/groups/$_groupIdValue/aliases',
        ],
      );
      expect(requests[0].queryParameters, isEmpty);
      expect(requests[1].queryParameters, isEmpty);
      expect(requests[2].queryParameters, <String, Object?>{
        'alias_prefix': 'Ni',
        'limit': 7,
      });
      expect(requests[0].data, isNull);
      expect(requests[1].data, <String, Object?>{'alias': 'Night Owl'});
      expect(requests[2].data, isNull);
      expect(requests.map(_authorization), <String>[
        'Bearer current-access-token-1',
        'Bearer current-access-token-2',
        'Bearer current-access-token-3',
      ]);
      expect(requests.every((request) => !request.followRedirects), isTrue);
      expect(
        requests.every((request) => !_hasHeader(request, 'if-match')),
        true,
      );
      expect(
        requests.every((request) => !_hasHeader(request, 'idempotency-key')),
        true,
      );
      expect(_header(requests[1], 'content-type'), Headers.jsonContentType);
    });

    test(
      'rejects account identity fields and strict response-proof drift',
      () async {
        final cases = <Object? Function()>[
          () => <String, Object?>{
            ..._aliasBody(projectionState: 'confirmed'),
            'public_profile_id': _requestId,
          },
          () {
            final body = _searchBody();
            final first = Map<String, Object?>.from(
              (body['items']! as List<Object?>).first! as Map<String, Object?>,
            );
            first['stream_user_id'] = 'loop_private_identity';
            body['items'] = <Object?>[first];
            return body;
          },
        ];

        for (final body in cases) {
          final fixture = await _fixture((options, handler) {
            handler.resolve(_success(options, data: body()));
          });
          try {
            final action = body == cases.first
                ? fixture.gateway.loadCurrentAlias(_groupId())
                : fixture.gateway.searchAliases(
                    groupId: _groupId(),
                    normalizedPrefix: 'Ni',
                    limit: 20,
                  );
            await expectLater(
              action,
              throwsA(_failure(GroupAliasGatewayFailureKind.invalidData)),
            );
          } finally {
            fixture.dispose();
          }
        }

        final missingProof = await _fixture((options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: _aliasBody(projectionState: 'confirmed'),
              headers: Headers.fromMap(<String, List<String>>{
                'x-request-id': <String>[_requestId],
              }),
            ),
          );
        });
        try {
          await expectLater(
            missingProof.gateway.loadCurrentAlias(_groupId()),
            throwsA(_failure(GroupAliasGatewayFailureKind.invalidData)),
          );
        } finally {
          missingProof.dispose();
        }
      },
    );

    test('maps definitive group Alias errors without guessing', () async {
      final cases =
          <
            ({
              int status,
              String code,
              GroupAliasGatewayFailureKind expected,
              _TestOperation operation,
            })
          >[
            (
              status: 404,
              code: 'not_found',
              expected: GroupAliasGatewayFailureKind.notFound,
              operation: _TestOperation.load,
            ),
            (
              status: 409,
              code: 'group_alias_immutable',
              expected: GroupAliasGatewayFailureKind.immutable,
              operation: _TestOperation.put,
            ),
            (
              status: 409,
              code: 'group_alias_unavailable',
              expected: GroupAliasGatewayFailureKind.taken,
              operation: _TestOperation.put,
            ),
            (
              status: 429,
              code: 'search_rate_limited',
              expected: GroupAliasGatewayFailureKind.unavailable,
              operation: _TestOperation.search,
            ),
          ];

      for (final testCase in cases) {
        final fixture = await _fixture((options, handler) {
          handler.reject(
            _httpError(
              options,
              statusCode: testCase.status,
              code: testCase.code,
            ),
          );
        });
        try {
          final action = switch (testCase.operation) {
            _TestOperation.load => fixture.gateway.loadCurrentAlias(_groupId()),
            _TestOperation.put => fixture.gateway.putCurrentAlias(
              groupId: _groupId(),
              normalizedAlias: 'Night Owl',
            ),
            _TestOperation.search => fixture.gateway.searchAliases(
              groupId: _groupId(),
              normalizedPrefix: 'Ni',
              limit: 20,
            ),
          };
          await expectLater(action, throwsA(_failure(testCase.expected)));
        } finally {
          fixture.dispose();
        }
      }
    });

    test('keeps an attempted PUT outcome unknown on transport, projection, or response-proof loss', () async {
      final responders =
          <void Function(RequestOptions, RequestInterceptorHandler)>[
            (options, handler) => handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            ),
            (options, handler) => handler.reject(
              _httpError(
                options,
                statusCode: 503,
                code: 'chat_group_unavailable',
              ),
            ),
            (options, handler) => handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: _aliasBody(projectionState: 'pending'),
                headers: Headers.fromMap(<String, List<String>>{
                  'cache-control': <String>['no-store'],
                }),
              ),
            ),
          ];

      for (final responder in responders) {
        var requests = 0;
        final fixture = await _fixture((options, handler) {
          requests += 1;
          responder(options, handler);
        });
        try {
          await expectLater(
            fixture.gateway.putCurrentAlias(
              groupId: _groupId(),
              normalizedAlias: 'Night Owl',
            ),
            throwsA(_failure(GroupAliasGatewayFailureKind.outcomeUnknown)),
          );
          expect(requests, 1);
        } finally {
          fixture.dispose();
        }
      }
    });

    test('rejects non-normalized input before token or HTTP work', () async {
      var requests = 0;
      final fixture = await _fixture((options, handler) {
        requests += 1;
        handler.resolve(
          _success(options, data: _aliasBody(projectionState: 'confirmed')),
        );
      });
      addTearDown(fixture.dispose);

      await expectLater(
        fixture.gateway.putCurrentAlias(
          groupId: _groupId(),
          normalizedAlias: ' Night Owl ',
        ),
        throwsA(_failure(GroupAliasGatewayFailureKind.invalidData)),
      );
      await expectLater(
        fixture.gateway.searchAliases(
          groupId: _groupId(),
          normalizedPrefix: 'N',
          limit: 20,
        ),
        throwsA(_failure(GroupAliasGatewayFailureKind.invalidData)),
      );
      expect(requests, 0);
      expect(fixture.requestTokens.calls, 0);
      expect(
        () => GroupId.fromWire('messaging:loop_direct_$_groupIdValue'),
        throwsA(isA<InvalidGroupAliasContractException>()),
      );
    });

    test('uses the session one-401 refresh budget', () async {
      var requests = 0;
      final fixture = await _fixture((options, handler) {
        requests += 1;
        if (requests == 1) {
          handler.reject(
            _httpError(options, statusCode: 401, code: 'invalid_access_token'),
          );
          return;
        }
        handler.resolve(
          _success(options, data: _aliasBody(projectionState: 'confirmed')),
        );
      });
      addTearDown(fixture.dispose);

      final resource = await fixture.gateway.loadCurrentAlias(_groupId());

      expect(resource.alias, 'Night Owl');
      expect(requests, 2);
      expect(fixture.requestTokens.calls, 2);
    });

    test('uses the session one-bootstrap recovery budget', () async {
      var requests = 0;
      final fixture = await _fixture((options, handler) {
        requests += 1;
        if (requests == 1) {
          handler.reject(
            _httpError(options, statusCode: 409, code: 'bootstrap_required'),
          );
          return;
        }
        handler.resolve(
          _success(options, data: _aliasBody(projectionState: 'confirmed')),
        );
      });
      addTearDown(fixture.dispose);

      final resource = await fixture.gateway.putCurrentAlias(
        groupId: _groupId(),
        normalizedAlias: 'Night Owl',
      );

      expect(resource.alias, 'Night Owl');
      expect(requests, 2);
      expect(fixture.bootstrapRepository.calls, 2);
      expect(fixture.requestTokens.calls, 2);
    });
  });
}

enum _TestOperation { load, put, search }

GroupId _groupId() => GroupId.fromWire(_groupIdValue);

Future<_Fixture> _fixture(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) async {
  final bootstrapRepository = _BootstrapRepository();
  final bootstrapSession = LoopBootstrapSession(
    principalKey: 'did:privy:owner-a',
    accessTokens: _AccessTokens(prefix: 'bootstrap-access-token'),
    repository: bootstrapRepository,
  );
  expect(
    await bootstrapSession.authorize(),
    LoopBootstrapAuthorization.authorized,
  );
  final requestTokens = _AccessTokens(prefix: 'current-access-token');
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
    required this.requestTokens,
  });

  final Dio dio;
  final DioLoopGroupAliasGateway gateway;
  final LoopAuthenticatedSession session;
  final LoopBootstrapSession bootstrapSession;
  final _BootstrapRepository bootstrapRepository;
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

Map<String, Object?> _aliasBody({required String projectionState}) =>
    <String, Object?>{
      'group_alias_id': _aliasIdValue,
      'alias': 'Night Owl',
      'projection_state': projectionState,
    };

Map<String, Object?> _searchBody() => <String, Object?>{
  'items': <Object?>[
    <String, Object?>{'group_alias_id': _aliasIdValue, 'alias': 'Night Owl'},
    <String, Object?>{
      'group_alias_id': _secondAliasIdValue,
      'alias': 'Nightingale',
    },
  ],
  'truncated': true,
};

Response<Object?> _success(RequestOptions options, {required Object? data}) =>
    Response<Object?>(
      requestOptions: options,
      statusCode: 200,
      data: data,
      headers: _strictHeaders(),
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

String _authorization(RequestOptions options) =>
    _header(options, 'authorization')! as String;

bool _hasHeader(RequestOptions options, String name) =>
    _header(options, name) != null;

TypeMatcher<GroupAliasGatewayException> _failure(
  GroupAliasGatewayFailureKind kind,
) => isA<GroupAliasGatewayException>().having(
  (failure) => failure.kind,
  'kind',
  kind,
);
