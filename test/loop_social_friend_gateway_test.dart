import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/social/dio_loop_social_friend_gateway.dart';
import 'package:loop_mobile/integrations/social/loop_social_repository.dart';

const _httpRequestId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _operationId = '11111111-1111-4111-8111-111111111111';
const _profileA = 'aaaaaaaa-1111-4111-8111-111111111111';
const _profileB = 'bbbbbbbb-2222-4222-8222-222222222222';
const _friendRequestId = 'cccccccc-3333-4333-8333-333333333333';
const _groupId = 'dddddddd-4444-4444-8444-444444444444';

void main() {
  test(
    'ambiguous friend command queries operation then replays exact UUID/body',
    () async {
      var call = 0;
      final harness = _GatewayHarness((options, handler) {
        switch (call++) {
          case 0:
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              ),
            );
            return;
          case 1:
            handler.reject(
              _httpError(
                options,
                statusCode: 404,
                code: 'social_operation_not_found',
              ),
            );
            return;
          case 2:
            handler.resolve(
              _response(options, _friendRequestSucceeded(_operationId)),
            );
            return;
          default:
            throw StateError('unexpected request');
        }
      });
      addTearDown(harness.dispose);

      final receipt = await harness.gateway.sendFriendRequestCommand(
        operationId: _operationId,
        targetProfileRef: FriendProfileRef.fromPublicProfileId(_profileA),
      );

      expect(receipt.operationId, _operationId);
      expect(receipt.friendRequestId, _friendRequestId);
      expect(
        harness.requests.map((item) => '${item.method} ${item.path}'),
        <String>[
          'POST /v1/friend-requests',
          'GET /v1/social/operations/$_operationId',
          'POST /v1/friend-requests',
        ],
      );
      expect(harness.requests[0].data, harness.requests[2].data);
      expect(_header(harness.requests[0], 'idempotency-key'), _operationId);
      expect(_header(harness.requests[2], 'idempotency-key'), _operationId);
      expect(_header(harness.requests[1], 'idempotency-key'), isNull);
    },
  );

  test('a failed reconciliation query never replays the write', () async {
    var call = 0;
    final harness = _GatewayHarness((options, handler) {
      switch (call++) {
        case 0:
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionTimeout,
            ),
          );
          return;
        case 1:
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            ),
          );
          return;
        default:
          throw StateError('write was incorrectly replayed');
      }
    });
    addTearDown(harness.dispose);

    await expectLater(
      harness.gateway.sendFriendRequestCommand(
        operationId: _operationId,
        targetProfileRef: FriendProfileRef.fromPublicProfileId(_profileA),
      ),
      throwsA(_gatewayFailure(FriendGatewayFailureKind.outcomeUnknown)),
    );

    expect(
      harness.requests.map((item) => '${item.method} ${item.path}'),
      <String>[
        'POST /v1/friend-requests',
        'GET /v1/social/operations/$_operationId',
      ],
    );
    expect(
      harness.requests.where((item) => item.method == 'POST'),
      hasLength(1),
    );
  });

  test(
    'a rate-limited reconciliation keeps the original operation uncertain',
    () async {
      var call = 0;
      final harness = _GatewayHarness((options, handler) {
        switch (call++) {
          case 0:
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              ),
            );
            return;
          case 1:
            handler.reject(
              _httpError(options, statusCode: 429, code: 'social_rate_limited'),
            );
            return;
          default:
            throw StateError('write was incorrectly replayed');
        }
      });
      addTearDown(harness.dispose);

      await expectLater(
        harness.gateway.sendFriendRequestCommand(
          operationId: _operationId,
          targetProfileRef: FriendProfileRef.fromPublicProfileId(_profileA),
        ),
        throwsA(
          _gatewayFailure(FriendGatewayFailureKind.outcomeUnknown).having(
            (failure) => failure.operationId,
            'retained operationId',
            _operationId,
          ),
        ),
      );

      expect(
        harness.requests.map((item) => '${item.method} ${item.path}'),
        <String>[
          'POST /v1/friend-requests',
          'GET /v1/social/operations/$_operationId',
        ],
      );
    },
  );

  test(
    'ordinary read connection failure is never automatically replayed',
    () async {
      final harness = _GatewayHarness((options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ),
        );
      });
      addTearDown(harness.dispose);

      await expectLater(
        harness.gateway.loadFriendPage(),
        throwsA(_gatewayFailure(FriendGatewayFailureKind.unavailable)),
      );
      expect(harness.requests, hasLength(1));
      expect(harness.requests.single.path, '/v1/friends');
    },
  );

  test(
    'group creation accepts backend member order as an unordered set',
    () async {
      final harness = _GatewayHarness((options, handler) {
        handler.resolve(
          _response(
            options,
            _groupSucceeded(
              _operationId,
              memberIds: const <String>[_profileB, _profileA],
            ),
          ),
        );
      });
      addTearDown(harness.dispose);
      final selected = <FriendProfileRef>[
        FriendProfileRef.fromPublicProfileId(_profileA),
        FriendProfileRef.fromPublicProfileId(_profileB),
      ];

      final group = await harness.gateway.createGroup(
        requestId: _operationId,
        normalizedName: 'Core group',
        friendRefs: selected,
      );

      expect(group.groupId, _groupId);
      expect(group.streamCid, 'messaging:loop_group_12345678');
      expect(group.friendRefs.toSet(), selected.toSet());
      expect(harness.requests, hasLength(1));
      expect(harness.requests.single.path, '/v1/chat/groups');
    },
  );

  test(
    'malformed committed POST payload reconciles before any replay',
    () async {
      var call = 0;
      final malformed = _groupSucceeded(
        _operationId,
        memberIds: const <String>[_profileA, _profileB],
      );
      (malformed['result']! as Map<String, Object?>)['group_id'] = 'invalid';
      final harness = _GatewayHarness((options, handler) {
        switch (call++) {
          case 0:
            handler.resolve(_response(options, malformed));
            return;
          case 1:
            handler.resolve(
              _response(
                options,
                _groupSucceeded(
                  _operationId,
                  memberIds: const <String>[_profileA, _profileB],
                ),
              ),
            );
            return;
          default:
            throw StateError('malformed response caused a write replay');
        }
      });
      addTearDown(harness.dispose);

      final result = await harness.gateway.createGroup(
        requestId: _operationId,
        normalizedName: 'Core group',
        friendRefs: <FriendProfileRef>[
          FriendProfileRef.fromPublicProfileId(_profileA),
          FriendProfileRef.fromPublicProfileId(_profileB),
        ],
      );

      expect(result.groupId, _groupId);
      expect(
        harness.requests.map((request) => '${request.method} ${request.path}'),
        <String>[
          'POST /v1/chat/groups',
          'GET /v1/chat/operations/$_operationId',
        ],
      );
    },
  );

  test(
    'chat polling deadline includes request time, not only delays',
    () async {
      var call = 0;
      var monotonicNow = Duration.zero;
      final waits = <Duration>[];
      final harness = _GatewayHarness(
        (options, handler) {
          switch (call++) {
            case 0:
              handler.resolve(
                _response(
                  options,
                  _chatPending(_operationId),
                  statusCode: 202,
                  location: '/v1/chat/operations/$_operationId',
                  retryAfter: '1',
                ),
              );
              return;
            case 1:
              monotonicNow = const Duration(minutes: 5);
              handler.resolve(
                _response(
                  options,
                  _chatPending(_operationId),
                  statusCode: 202,
                  location: '/v1/chat/operations/$_operationId',
                  retryAfter: '1',
                ),
              );
              return;
            default:
              throw StateError(
                'polling continued past its wall-clock deadline',
              );
          }
        },
        delay: (duration) async {
          waits.add(duration);
          monotonicNow += duration;
        },
        monotonicNow: () => monotonicNow,
      );
      addTearDown(harness.dispose);

      await expectLater(
        harness.gateway.createGroup(
          requestId: _operationId,
          normalizedName: 'Core group',
          friendRefs: <FriendProfileRef>[
            FriendProfileRef.fromPublicProfileId(_profileA),
            FriendProfileRef.fromPublicProfileId(_profileB),
          ],
        ),
        throwsA(_gatewayFailure(FriendGatewayFailureKind.outcomeUnknown)),
      );

      expect(waits, const <Duration>[Duration(seconds: 1)]);
      expect(harness.requests.map((request) => request.method), const <String>[
        'POST',
        'GET',
      ]);
    },
  );

  test('operator_required is terminal and repeated intent never allocates another channel', () async {
    var call = 0;
    final waits = <Duration>[];
    final harness = _GatewayHarness((options, handler) {
      switch (call++) {
        case 0:
          handler.resolve(
            _response(
              options,
              _chatPending(_operationId),
              statusCode: 202,
              location: '/v1/chat/operations/$_operationId',
              retryAfter: '1',
            ),
          );
          return;
        case 1 || 2:
          handler.resolve(_response(options, _operatorRequired(_operationId)));
          return;
        default:
          throw StateError('a second channel allocation was attempted');
      }
    }, delay: (duration) async => waits.add(duration));
    addTearDown(harness.dispose);
    final selected = <FriendProfileRef>[
      FriendProfileRef.fromPublicProfileId(_profileA),
      FriendProfileRef.fromPublicProfileId(_profileB),
    ];

    Future<void> create() async {
      await harness.gateway.createGroup(
        requestId: _operationId,
        normalizedName: 'Core group',
        friendRefs: selected,
      );
    }

    await expectLater(
      create(),
      throwsA(
        _gatewayFailure(
          FriendGatewayFailureKind.operatorRequired,
        ).having((failure) => failure.operationId, 'operationId', _operationId),
      ),
    );
    await expectLater(
      create(),
      throwsA(_gatewayFailure(FriendGatewayFailureKind.operatorRequired)),
    );

    expect(waits, const <Duration>[Duration(seconds: 1)]);
    expect(
      harness.requests.map((item) => '${item.method} ${item.path}'),
      <String>[
        'POST /v1/chat/groups',
        'GET /v1/chat/operations/$_operationId',
        'GET /v1/chat/operations/$_operationId',
      ],
    );
    expect(
      harness.requests.where((item) => item.path == '/v1/chat/groups'),
      hasLength(1),
    );
    expect(
      harness.requests.map((item) => item.path),
      everyElement(isNot(contains('loop_group_'))),
    );
  });

  test('direct_channel_unavailable is an operator hold and never starts a second allocation', () async {
    var call = 0;
    final harness = _GatewayHarness((options, handler) {
      switch (call++) {
        case 0 || 1:
          handler.resolve(
            _response(
              options,
              _directFailed(
                _operationId,
                errorCode: 'direct_channel_unavailable',
              ),
            ),
          );
          return;
        default:
          throw StateError('a second direct allocation was attempted');
      }
    });
    addTearDown(harness.dispose);
    final target = FriendProfileRef.fromPublicProfileId(_profileA);

    Future<void> createDirect() async {
      await harness.gateway.createDirectChannel(
        operationId: _operationId,
        targetProfileRef: target,
      );
    }

    await expectLater(
      createDirect(),
      throwsA(_gatewayFailure(FriendGatewayFailureKind.operatorRequired)),
    );
    await expectLater(
      createDirect(),
      throwsA(_gatewayFailure(FriendGatewayFailureKind.operatorRequired)),
    );

    expect(
      harness.requests.map((item) => '${item.method} ${item.path}'),
      <String>[
        'POST /v1/chat/direct-channels',
        'GET /v1/chat/operations/$_operationId',
      ],
    );
  });
}

final class _GatewayHarness {
  _GatewayHarness(
    void Function(RequestOptions, RequestInterceptorHandler) onRequest, {
    Future<void> Function(Duration)? delay,
    Duration Function()? monotonicNow,
  }) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            onRequest(options, handler);
          },
        ),
      );
    accessTokens = _TokenSource();
    bootstrapRepository = _BootstrapRepository();
    bootstrapSession = LoopBootstrapSession(
      principalKey: 'did:privy:test-user',
      accessTokens: accessTokens,
      repository: bootstrapRepository,
    );
    authenticatedSession = LoopAuthenticatedSession(
      principalKey: 'did:privy:test-user',
      bootstrapSession: bootstrapSession,
      accessTokens: accessTokens,
    );
    gateway = DioLoopSocialFriendGateway(
      authenticatedSession,
      DioLoopSocialRepository(dio),
      delay: delay,
      monotonicNow: monotonicNow,
    );
  }

  final List<RequestOptions> requests = <RequestOptions>[];
  late final _TokenSource accessTokens;
  late final _BootstrapRepository bootstrapRepository;
  late final LoopBootstrapSession bootstrapSession;
  late final LoopAuthenticatedSession authenticatedSession;
  late final DioLoopSocialFriendGateway gateway;

  void dispose() {
    gateway.dispose();
    authenticatedSession.dispose();
    bootstrapSession.dispose();
  }
}

final class _TokenSource implements LoopBackendAccessTokenSource {
  var calls = 0;

  @override
  Future<String> loadAccessToken() async => 'access-token-${++calls}';
}

final class _BootstrapRepository implements LoopBootstrapRepository {
  final tokens = <String>[];

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    tokens.add(accessToken);
    return const LoopBootstrapIdentity(
      loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
      streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
    );
  }
}

Response<Object?> _response(
  RequestOptions options,
  Object? data, {
  int statusCode = 200,
  String? location,
  String? retryAfter,
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': const <String>['no-store'],
      'x-request-id': const <String>[_httpRequestId],
      if (location != null) 'location': <String>[location],
      if (retryAfter != null) 'retry-after': <String>[retryAfter],
    }),
  );
}

DioException _httpError(
  RequestOptions options, {
  required int statusCode,
  required String code,
}) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: _response(options, <String, Object?>{
      'code': code,
      'message': 'Sanitized public message',
      'request_id': _httpRequestId,
    }, statusCode: statusCode),
  );
}

Object? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

Map<String, Object?> _friendRequestSucceeded(String operationId) =>
    <String, Object?>{
      'operation_id': operationId,
      'kind': 'friend_request_send',
      'status': 'succeeded',
      'terminal': true,
      'retry_after_ms': null,
      'result': const <String, Object?>{
        'friend_request_id': _friendRequestId,
        'status': 'pending',
      },
      'error': null,
      'created_at': '2026-08-31T01:00:00.000Z',
      'updated_at': '2026-08-31T01:00:01.000Z',
    };

Map<String, Object?> _chatPending(String operationId) => <String, Object?>{
  'operation_id': operationId,
  'kind': 'group_create',
  'status': 'reconciling',
  'terminal': false,
  'retry_after_ms': 500,
  'result': null,
  'error': null,
  'created_at': '2026-08-31T01:00:00.000Z',
  'updated_at': '2026-08-31T01:00:01.000Z',
};

Map<String, Object?> _groupSucceeded(
  String operationId, {
  required List<String> memberIds,
}) => <String, Object?>{
  'operation_id': operationId,
  'kind': 'group_create',
  'status': 'succeeded',
  'terminal': true,
  'retry_after_ms': null,
  'result': <String, Object?>{
    'group_id': _groupId,
    'name': 'Core group',
    'friend_public_profile_ids': memberIds,
    'stream_cid': 'messaging:loop_group_12345678',
  },
  'error': null,
  'created_at': '2026-08-31T01:00:00.000Z',
  'updated_at': '2026-08-31T01:00:01.000Z',
};

Map<String, Object?> _operatorRequired(String operationId) => <String, Object?>{
  'operation_id': operationId,
  'kind': 'group_create',
  'status': 'operator_required',
  'terminal': true,
  'retry_after_ms': null,
  'result': null,
  'error': const <String, Object?>{'code': 'stream_channel_not_created'},
  'created_at': '2026-08-31T01:00:00.000Z',
  'updated_at': '2026-08-31T01:00:01.000Z',
};

Map<String, Object?> _directFailed(
  String operationId, {
  required String errorCode,
}) => <String, Object?>{
  'operation_id': operationId,
  'kind': 'direct_get_or_create',
  'status': 'failed',
  'terminal': true,
  'retry_after_ms': null,
  'result': null,
  'error': <String, Object?>{'code': errorCode},
  'created_at': '2026-08-31T01:00:00.000Z',
  'updated_at': '2026-08-31T01:00:01.000Z',
};

TypeMatcher<FriendGatewayException> _gatewayFailure(
  FriendGatewayFailureKind kind,
) => isA<FriendGatewayException>().having(
  (failure) => failure.kind,
  'kind',
  kind,
);
