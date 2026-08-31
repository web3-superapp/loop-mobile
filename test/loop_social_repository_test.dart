import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/social/loop_social_repository.dart';
import 'package:loop_mobile/integrations/social/loop_social_transport_models.dart';

const _httpRequestId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _operationA = '11111111-1111-4111-8111-111111111111';
const _operationB = '22222222-2222-4222-8222-222222222222';
const _operationC = '33333333-3333-4333-8333-333333333333';
const _operationD = '44444444-4444-4444-8444-444444444444';
const _profileA = 'aaaaaaaa-1111-4111-8111-111111111111';
const _profileB = 'bbbbbbbb-2222-4222-8222-222222222222';
const _profileC = 'cccccccc-3333-4333-8333-333333333333';
const _profileD = 'dddddddd-4444-4444-8444-444444444444';
const _requestA = 'eeeeeeee-1111-4111-8111-111111111111';
const _requestB = 'eeeeeeee-2222-4222-8222-222222222222';
const _groupId = 'ffffffff-1111-4111-8111-111111111111';

void main() {
  group('DioLoopSocialRepository reads', () {
    test('uses exact first/cursor queries and parses nullable aliases plus all relationships', () async {
      final captured = <RequestOptions>[];
      var call = 0;
      final repository = DioLoopSocialRepository(
        _dio((options, handler) {
          captured.add(options);
          final response = switch (call++) {
            0 => _response(options, _friendPage()),
            1 => _response(options, _emptyCursorPage()),
            2 => _response(options, _searchPage()),
            3 => _response(options, _friendRequestPage()),
            4 => _response(options, _emptyCursorPage()),
            _ => throw StateError('unexpected request'),
          };
          handler.resolve(response);
        }),
      );

      final firstFriends = await repository.loadFriendPage(
        accessToken: 'access-token',
      );
      final cursorFriends = await repository.loadFriendPage(
        accessToken: 'access-token',
        cursor: 'friend-cursor',
      );
      final search = await repository.searchFriends(
        accessToken: 'access-token',
        normalizedQuery: '  Al  ',
      );
      final firstRequests = await repository.loadFriendRequests(
        accessToken: 'access-token',
        direction: FriendRequestDirection.incoming,
      );
      final cursorRequests = await repository.loadFriendRequests(
        accessToken: 'access-token',
        direction: FriendRequestDirection.outgoing,
        cursor: 'request-cursor',
      );

      expect(captured.map((item) => item.method), everyElement('GET'));
      expect(captured[0].path, '/v1/friends');
      expect(captured[0].queryParameters, const <String, Object?>{'limit': 20});
      expect(captured[1].queryParameters, const <String, Object?>{
        'cursor': 'friend-cursor',
      });
      expect(captured[1].queryParameters, isNot(contains('limit')));
      expect(captured[2].path, '/v1/friends/search');
      expect(captured[2].queryParameters, const <String, Object?>{
        'alias_prefix': 'Al',
        'limit': 20,
      });
      expect(captured[3].path, '/v1/friend-requests');
      expect(captured[3].queryParameters, const <String, Object?>{
        'direction': 'incoming',
        'status': 'pending',
        'limit': 20,
      });
      expect(captured[4].queryParameters, const <String, Object?>{
        'direction': 'outgoing',
        'status': 'pending',
        'cursor': 'request-cursor',
      });
      expect(captured[4].queryParameters, isNot(contains('limit')));
      for (final request in captured) {
        expect(_header(request, 'authorization'), 'Bearer access-token');
        expect(_header(request, 'idempotency-key'), isNull);
        expect(request.followRedirects, isFalse);
      }

      expect(firstFriends.nextCursor, 'friend-cursor');
      expect(firstFriends.items.single.accountAlias, isNull);
      expect(firstFriends.items.single.alias, '0123456789');
      expect(cursorFriends.items, isEmpty);
      expect(search.truncated, isTrue);
      expect(
        search.items.map((item) => item.relationship),
        const <FriendRelationship>[
          FriendRelationship.none,
          FriendRelationship.outgoingPending,
          FriendRelationship.incomingPending,
          FriendRelationship.friend,
        ],
      );
      expect(search.items[0].friendRequestId, isNull);
      expect(search.items[1].friendRequestId, _requestA);
      expect(search.items[2].friendRequestId, _requestB);
      expect(search.items[3].friendRequestId, isNull);
      expect(firstRequests.items.single.counterparty.accountAlias, isNull);
      expect(
        firstRequests.items.single.direction,
        FriendRequestDirection.incoming,
      );
      expect(cursorRequests.items, isEmpty);
    });

    test('fails closed on missing response proof and unknown keys', () async {
      final cases = <Response<Object?> Function(RequestOptions)>[
        (options) => _response(options, _friendPage(), cacheControl: null),
        (options) =>
            _response(options, _friendPage(), requestIds: const <String>[]),
        (options) => _response(
          options,
          _friendPage(),
          requestIds: const <String>[_httpRequestId, _operationA],
        ),
        (options) =>
            _response(options, <String, Object?>{..._friendPage(), 'total': 1}),
        (options) {
          final page = _friendPage();
          final item = Map<String, Object?>.from(
            (page['items']! as List<Object?>).single! as Map<String, Object?>,
          );
          item['wallet_address'] = '0xnot-allowed';
          page['items'] = <Object?>[item];
          return _response(options, page);
        },
        (options) => _response(options, <String, Object?>{
          ..._friendPage(),
          'next_cursor': List<String>.filled(1025, 'c').join(),
        }),
      ];

      for (final response in cases) {
        final repository = DioLoopSocialRepository(
          _dio((options, handler) => handler.resolve(response(options))),
        );
        await expectLater(
          repository.loadFriendPage(accessToken: 'access-token'),
          throwsA(_backendFailure(LoopBackendFailureKind.invalidPayload)),
        );
      }
    });
  });

  group('DioLoopSocialRepository commands', () {
    test(
      'sends exact idempotency headers and bodies for all commands',
      () async {
        final captured = <RequestOptions>[];
        final repository = DioLoopSocialRepository(
          _dio((options, handler) {
            captured.add(options);
            final data = switch (options.path) {
              '/v1/friend-requests' => _socialSucceeded(
                operationId: _operationA,
                kind: 'friend_request_send',
                friendRequestId: _requestA,
                status: 'pending',
              ),
              '/v1/friend-requests/$_requestA/decision' => _socialSucceeded(
                operationId: _operationB,
                kind: 'friend_request_decide',
                friendRequestId: _requestA,
                status: 'accepted',
              ),
              '/v1/chat/groups' => _chatGroupSucceeded(_operationC),
              '/v1/chat/direct-channels' => _chatDirectSucceeded(_operationD),
              _ => throw StateError('unexpected request: ${options.path}'),
            };
            handler.resolve(_response(options, data));
          }),
        );

        await repository.sendFriendRequest(
          accessToken: 'command-token',
          operationId: _operationA,
          targetProfileRef: FriendProfileRef.fromPublicProfileId(_profileA),
        );
        await repository.decideFriendRequest(
          accessToken: 'command-token',
          operationId: _operationB,
          friendRequestId: _requestA,
          decision: FriendRequestDecision.accept,
        );
        await repository.createGroup(
          accessToken: 'command-token',
          operationId: _operationC,
          normalizedName: '  Core group  ',
          friendRefs: <FriendProfileRef>[
            FriendProfileRef.fromPublicProfileId(_profileA),
            FriendProfileRef.fromPublicProfileId(_profileB),
          ],
        );
        await repository.createDirectChannel(
          accessToken: 'command-token',
          operationId: _operationD,
          targetProfileRef: FriendProfileRef.fromPublicProfileId(_profileD),
        );

        expect(captured.map((item) => item.method), everyElement('POST'));
        expect(
          captured.map((item) => item.queryParameters),
          everyElement(isEmpty),
        );
        expect(
          captured.map((item) => item.followRedirects),
          everyElement(isFalse),
        );
        expect(
          captured.map((item) => _header(item, 'authorization')),
          everyElement('Bearer command-token'),
        );
        expect(_header(captured[0], 'idempotency-key'), _operationA);
        expect(captured[0].data, const <String, Object?>{
          'target_public_profile_id': _profileA,
        });
        expect(_header(captured[1], 'idempotency-key'), _operationB);
        expect(captured[1].data, const <String, Object?>{'decision': 'accept'});
        expect(_header(captured[2], 'idempotency-key'), _operationC);
        expect(captured[2].data, const <String, Object?>{
          'name': 'Core group',
          'friend_public_profile_ids': <String>[_profileA, _profileB],
        });
        expect(_header(captured[3], 'idempotency-key'), _operationD);
        expect(captured[3].data, const <String, Object?>{
          'target_public_profile_id': _profileD,
        });
        expect(
          captured.map((item) => _header(item, 'content-type')),
          everyElement(Headers.jsonContentType),
        );
      },
    );

    test(
      'validates social operation id, kind, and terminal invariants',
      () async {
        final validRepository = DioLoopSocialRepository(
          _dio(
            (options, handler) => handler.resolve(
              _response(
                options,
                _socialSucceeded(
                  operationId: _operationA,
                  kind: 'friend_request_send',
                  friendRequestId: _requestA,
                  status: 'pending',
                ),
              ),
            ),
          ),
        );
        final operation = await validRepository.getSocialOperation(
          accessToken: 'access-token',
          operationId: _operationA,
          expectedKind: LoopSocialOperationKind.friendRequestSend,
        );
        expect(operation.operationId, _operationA);
        expect(operation.kind, LoopSocialOperationKind.friendRequestSend);
        expect(operation.status, LoopSocialOperationStatus.succeeded);
        expect(operation.result?.status, LoopSocialResultStatus.pending);

        final malformed = <Map<String, Object?>>[
          <String, Object?>{
            ..._socialSucceeded(
              operationId: _operationA,
              kind: 'friend_request_send',
              friendRequestId: _requestA,
              status: 'pending',
            ),
            'operation_id': _operationB,
          },
          <String, Object?>{
            ..._socialSucceeded(
              operationId: _operationA,
              kind: 'friend_request_send',
              friendRequestId: _requestA,
              status: 'pending',
            ),
            'kind': 'friend_request_decide',
          },
          <String, Object?>{
            ..._socialSucceeded(
              operationId: _operationA,
              kind: 'friend_request_send',
              friendRequestId: _requestA,
              status: 'pending',
            ),
            'status': 'pending',
          },
          <String, Object?>{
            ..._socialSucceeded(
              operationId: _operationA,
              kind: 'friend_request_send',
              friendRequestId: _requestA,
              status: 'pending',
            ),
            'terminal': false,
          },
          <String, Object?>{
            ..._socialSucceeded(
              operationId: _operationA,
              kind: 'friend_request_send',
              friendRequestId: _requestA,
              status: 'pending',
            ),
            'retry_after_ms': 1,
          },
          <String, Object?>{
            ..._socialSucceeded(
              operationId: _operationA,
              kind: 'friend_request_send',
              friendRequestId: _requestA,
              status: 'pending',
            ),
            'error': const <String, Object?>{'code': 'already_friends'},
          },
          <String, Object?>{
            ..._socialFailed(
              operationId: _operationA,
              kind: 'friend_request_send',
            ),
            'result': const <String, Object?>{
              'friend_request_id': _requestA,
              'status': 'pending',
            },
          },
          <String, Object?>{
            ..._socialFailed(
              operationId: _operationA,
              kind: 'friend_request_send',
            ),
            'error': const <String, Object?>{
              'code': 'stream_channel_not_created',
            },
          },
        ];

        for (final payload in malformed) {
          final repository = DioLoopSocialRepository(
            _dio(
              (options, handler) =>
                  handler.resolve(_response(options, payload)),
            ),
          );
          await expectLater(
            repository.getSocialOperation(
              accessToken: 'access-token',
              operationId: _operationA,
              expectedKind: LoopSocialOperationKind.friendRequestSend,
            ),
            throwsA(_backendFailure(LoopBackendFailureKind.invalidPayload)),
          );
        }
      },
    );
  });

  group('DioLoopSocialRepository Chat operations', () {
    test('accepts 202 proof and uses the greater retry delay', () async {
      var call = 0;
      final repository = DioLoopSocialRepository(
        _dio((options, handler) {
          final operationId = call++ == 0 ? _operationA : _operationB;
          final bodyDelay = operationId == _operationA ? 500 : 2500;
          handler.resolve(
            _response(
              options,
              _chatPending(operationId, retryAfterMs: bodyDelay),
              statusCode: 202,
              location: '/v1/chat/operations/$operationId',
              retryAfter: '2',
            ),
          );
        }),
      );

      final headerWins = await repository.getChatOperation(
        accessToken: 'access-token',
        operationId: _operationA,
        expectedKind: LoopChatOperationKind.groupCreate,
      );
      final bodyWins = await repository.getChatOperation(
        accessToken: 'access-token',
        operationId: _operationB,
        expectedKind: LoopChatOperationKind.groupCreate,
      );

      expect(headerWins.status, LoopChatOperationStatus.reconciling);
      expect(headerWins.terminal, isFalse);
      expect(headerWins.retryDelay, const Duration(seconds: 2));
      expect(bodyWins.retryDelay, const Duration(milliseconds: 2500));
    });

    test(
      'accepts terminal group members as an unordered set payload',
      () async {
        final repository = DioLoopSocialRepository(
          _dio(
            (options, handler) => handler.resolve(
              _response(
                options,
                _chatGroupSucceeded(
                  _operationA,
                  memberIds: const <String>[_profileB, _profileA],
                ),
              ),
            ),
          ),
        );

        final operation = await repository.getChatOperation(
          accessToken: 'access-token',
          operationId: _operationA,
          expectedKind: LoopChatOperationKind.groupCreate,
        );

        expect(operation.status, LoopChatOperationStatus.succeeded);
        final result = operation.result! as LoopChatGroupResult;
        expect(
          result.friendProfileRefs.map((item) => item.wireValue),
          const <String>[_profileB, _profileA],
        );
        expect(result.streamCid, 'messaging:loop_group_12345678');
      },
    );

    test('fails closed on malformed 200/202 operation envelopes', () async {
      final cases =
          <
            ({
              Map<String, Object?> body,
              int status,
              String? location,
              String? retryAfter,
            })
          >[
            (
              body: _chatPending(_operationA),
              status: 202,
              location: null,
              retryAfter: '2',
            ),
            (
              body: _chatPending(_operationA),
              status: 202,
              location: '/v1/chat/operations/$_operationB',
              retryAfter: '2',
            ),
            (
              body: _chatPending(_operationA),
              status: 202,
              location: '/v1/chat/operations/$_operationA',
              retryAfter: '61',
            ),
            (
              body: <String, Object?>{
                ..._chatPending(_operationA),
                'retry_after_ms': 60001,
              },
              status: 202,
              location: '/v1/chat/operations/$_operationA',
              retryAfter: '2',
            ),
            (
              body: <String, Object?>{
                ..._chatPending(_operationA),
                'terminal': true,
              },
              status: 202,
              location: '/v1/chat/operations/$_operationA',
              retryAfter: '2',
            ),
            (
              body: <String, Object?>{
                ..._chatGroupSucceeded(_operationA),
                'result': null,
              },
              status: 200,
              location: null,
              retryAfter: null,
            ),
            (
              body: _chatPending(_operationA),
              status: 200,
              location: null,
              retryAfter: null,
            ),
            (
              body: <String, Object?>{
                ..._chatGroupSucceeded(_operationA),
                'unexpected': true,
              },
              status: 200,
              location: null,
              retryAfter: null,
            ),
            (
              body: <String, Object?>{
                ..._chatGroupSucceeded(_operationA),
                'result': const <String, Object?>{
                  'group_id': _groupId,
                  'name': 'Core group',
                  'friend_public_profile_ids': <String>[_profileA, _profileB],
                  'stream_cid': 'messaging:loop_direct_wrong-kind',
                },
              },
              status: 200,
              location: null,
              retryAfter: null,
            ),
            (
              body: <String, Object?>{
                ..._chatGroupSucceeded(_operationA),
                'result': const <String, Object?>{
                  'group_id': _groupId,
                  'name': 'Core group',
                  'friend_public_profile_ids': <String>[_profileA, _profileB],
                  'stream_cid': 'messaging:loop_group_INVALID!',
                },
              },
              status: 200,
              location: null,
              retryAfter: null,
            ),
          ];

      for (final item in cases) {
        final repository = DioLoopSocialRepository(
          _dio(
            (options, handler) => handler.resolve(
              _response(
                options,
                item.body,
                statusCode: item.status,
                location: item.location,
                retryAfter: item.retryAfter,
              ),
            ),
          ),
        );
        await expectLater(
          repository.getChatOperation(
            accessToken: 'access-token',
            operationId: _operationA,
            expectedKind: LoopChatOperationKind.groupCreate,
          ),
          throwsA(_backendFailure(LoopBackendFailureKind.invalidPayload)),
        );
      }
    });
  });

  group('DioLoopSocialRepository failures', () {
    test('requires matching body/header request IDs on errors', () async {
      final matching = DioLoopSocialRepository(
        _dio(
          (options, handler) => handler.reject(
            _httpError(options, statusCode: 429, code: 'search_rate_limited'),
          ),
        ),
      );
      await expectLater(
        matching.searchFriends(
          accessToken: 'access-token',
          normalizedQuery: 'alice',
        ),
        throwsA(
          isA<LoopSocialHttpFailure>()
              .having(
                (failure) => failure.requestId,
                'requestId',
                _httpRequestId,
              )
              .having(
                (failure) => failure.retryAfter,
                'fallback retry delay',
                const Duration(seconds: 60),
              ),
        ),
      );

      final explicitRetry = DioLoopSocialRepository(
        _dio(
          (options, handler) => handler.reject(
            _httpError(
              options,
              statusCode: 429,
              code: 'social_rate_limited',
              retryAfter: '7',
            ),
          ),
        ),
      );
      await expectLater(
        explicitRetry.searchFriends(
          accessToken: 'access-token',
          normalizedQuery: 'alice',
        ),
        throwsA(
          isA<LoopSocialHttpFailure>().having(
            (failure) => failure.retryAfter,
            'header retry delay',
            const Duration(seconds: 7),
          ),
        ),
      );

      final mismatched = DioLoopSocialRepository(
        _dio(
          (options, handler) => handler.reject(
            _httpError(
              options,
              statusCode: 429,
              code: 'search_rate_limited',
              bodyRequestId: _operationB,
            ),
          ),
        ),
      );
      await expectLater(
        mismatched.searchFriends(
          accessToken: 'access-token',
          normalizedQuery: 'alice',
        ),
        throwsA(_backendFailure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test(
      'rejects error codes outside the endpoint and HTTP status contract',
      () async {
        final invalidAuthentication = DioLoopSocialRepository(
          _dio(
            (options, handler) => handler.reject(
              _httpError(options, statusCode: 401, code: 'target_unavailable'),
            ),
          ),
        );
        await expectLater(
          invalidAuthentication.loadFriendPage(accessToken: 'access-token'),
          throwsA(_backendFailure(LoopBackendFailureKind.invalidPayload)),
        );

        final invalidOperationNotFound = DioLoopSocialRepository(
          _dio(
            (options, handler) => handler.reject(
              _httpError(options, statusCode: 404, code: 'target_unavailable'),
            ),
          ),
        );
        await expectLater(
          invalidOperationNotFound.getSocialOperation(
            accessToken: 'access-token',
            operationId: _operationA,
            expectedKind: LoopSocialOperationKind.friendRequestSend,
          ),
          throwsA(_backendFailure(LoopBackendFailureKind.invalidPayload)),
        );

        final invalidChatAvailability = DioLoopSocialRepository(
          _dio(
            (options, handler) => handler.reject(
              _httpError(options, statusCode: 503, code: 'social_unavailable'),
            ),
          ),
        );
        await expectLater(
          invalidChatAvailability.getChatOperation(
            accessToken: 'access-token',
            operationId: _operationA,
            expectedKind: LoopChatOperationKind.groupCreate,
          ),
          throwsA(_backendFailure(LoopBackendFailureKind.invalidPayload)),
        );

        final validTargetUnavailable = DioLoopSocialRepository(
          _dio(
            (options, handler) => handler.reject(
              _httpError(options, statusCode: 404, code: 'target_unavailable'),
            ),
          ),
        );
        await expectLater(
          validTargetUnavailable.sendFriendRequest(
            accessToken: 'access-token',
            operationId: _operationA,
            targetProfileRef: FriendProfileRef.fromPublicProfileId(_profileA),
          ),
          throwsA(
            isA<LoopSocialHttpFailure>()
                .having((failure) => failure.statusCode, 'status', 404)
                .having(
                  (failure) => failure.code,
                  'code',
                  'target_unavailable',
                ),
          ),
        );
      },
    );

    test('rejects blank bearer before dispatch', () async {
      var requests = 0;
      final repository = DioLoopSocialRepository(
        _dio((options, handler) {
          requests += 1;
          handler.resolve(_response(options, _emptyCursorPage()));
        }),
      );

      await expectLater(
        repository.loadFriendPage(accessToken: '  '),
        throwsA(_backendFailure(LoopBackendFailureKind.authentication)),
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
  int statusCode = 200,
  String? cacheControl = 'private, no-store',
  List<String>? requestIds = const <String>[_httpRequestId],
  String? location,
  String? retryAfter,
}) {
  final headers = <String, List<String>>{
    if (cacheControl != null) 'cache-control': <String>[cacheControl],
    'x-request-id': ?requestIds,
    if (location != null) 'location': <String>[location],
    if (retryAfter != null) 'retry-after': <String>[retryAfter],
  };
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(headers),
  );
}

DioException _httpError(
  RequestOptions options, {
  required int statusCode,
  required String code,
  String bodyRequestId = _httpRequestId,
  String? retryAfter,
}) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: _response(
      options,
      <String, Object?>{
        'code': code,
        'message': 'Sanitized public message',
        'request_id': bodyRequestId,
      },
      statusCode: statusCode,
      retryAfter: retryAfter,
    ),
  );
}

Object? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
  }
  return null;
}

Map<String, Object?> _friendPage() => <String, Object?>{
  'items': <Object?>[
    <String, Object?>{
      'public_profile_id': _profileA,
      'profile_code': '0123456789',
      'alias': null,
      'avatar_ref': null,
      'accepted_at': '2026-08-31T01:00:00.000Z',
    },
  ],
  'next_cursor': 'friend-cursor',
};

Map<String, Object?> _emptyCursorPage() => <String, Object?>{
  'items': const <Object?>[],
  'next_cursor': null,
};

Map<String, Object?> _searchPage() => <String, Object?>{
  'items': <Object?>[
    _searchItem(_profileA, '0123456789', 'Alice', 'none', null),
    _searchItem(
      _profileB,
      'ABCDEFGHJK',
      'Alice',
      'outgoing_pending',
      _requestA,
    ),
    _searchItem(
      _profileC,
      'MNPQRSTVWX',
      'Alice',
      'incoming_pending',
      _requestB,
    ),
    _searchItem(_profileD, 'ZYXWVTSRQP', 'Alice', 'friend', null),
  ],
  'truncated': true,
};

Map<String, Object?> _searchItem(
  String profileId,
  String profileCode,
  String alias,
  String relationship,
  String? friendRequestId,
) => <String, Object?>{
  'public_profile_id': profileId,
  'profile_code': profileCode,
  'alias': alias,
  'avatar_ref': null,
  'relationship': relationship,
  'friend_request_id': friendRequestId,
};

Map<String, Object?> _friendRequestPage() => <String, Object?>{
  'items': <Object?>[
    <String, Object?>{
      'friend_request_id': _requestA,
      'counterparty': <String, Object?>{
        'public_profile_id': _profileB,
        'profile_code': 'ABCDEFGHJK',
        'alias': null,
        'avatar_ref': null,
      },
      'direction': 'incoming',
      'status': 'pending',
      'created_at': '2026-08-31T01:00:00.000Z',
      'expires_at': '2026-09-07T01:00:00.000Z',
    },
  ],
  'next_cursor': null,
};

Map<String, Object?> _socialSucceeded({
  required String operationId,
  required String kind,
  required String friendRequestId,
  required String status,
}) => <String, Object?>{
  'operation_id': operationId,
  'kind': kind,
  'status': 'succeeded',
  'terminal': true,
  'retry_after_ms': null,
  'result': <String, Object?>{
    'friend_request_id': friendRequestId,
    'status': status,
  },
  'error': null,
  'created_at': '2026-08-31T01:00:00.000Z',
  'updated_at': '2026-08-31T01:00:01.000Z',
};

Map<String, Object?> _socialFailed({
  required String operationId,
  required String kind,
}) => <String, Object?>{
  'operation_id': operationId,
  'kind': kind,
  'status': 'failed',
  'terminal': true,
  'retry_after_ms': null,
  'result': null,
  'error': const <String, Object?>{'code': 'already_friends'},
  'created_at': '2026-08-31T01:00:00.000Z',
  'updated_at': '2026-08-31T01:00:01.000Z',
};

Map<String, Object?> _chatPending(
  String operationId, {
  int retryAfterMs = 500,
}) => <String, Object?>{
  'operation_id': operationId,
  'kind': 'group_create',
  'status': 'reconciling',
  'terminal': false,
  'retry_after_ms': retryAfterMs,
  'result': null,
  'error': null,
  'created_at': '2026-08-31T01:00:00.000Z',
  'updated_at': '2026-08-31T01:00:01.000Z',
};

Map<String, Object?> _chatGroupSucceeded(
  String operationId, {
  List<String> memberIds = const <String>[_profileA, _profileB],
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

Map<String, Object?> _chatDirectSucceeded(String operationId) =>
    <String, Object?>{
      'operation_id': operationId,
      'kind': 'direct_get_or_create',
      'status': 'succeeded',
      'terminal': true,
      'retry_after_ms': null,
      'result': const <String, Object?>{
        'target_public_profile_id': _profileD,
        'stream_cid': 'messaging:loop_direct_12345678',
      },
      'error': null,
      'created_at': '2026-08-31T01:00:00.000Z',
      'updated_at': '2026-08-31T01:00:01.000Z',
    };

TypeMatcher<LoopBackendFailure> _backendFailure(LoopBackendFailureKind kind) =>
    isA<LoopBackendFailure>().having((failure) => failure.kind, 'kind', kind);
