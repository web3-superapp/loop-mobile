import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_stream_token_repository.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_communication_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_projection_codec.dart';

const _token = 'privy-access-token';
const _clientVersion = '1.0.0';
const _requestId = '2f7c8a90-1b2c-4d3e-8f90-1a2b3c4d5e6f';
const _key = '6f5e4d3c-2b1a-4098-8765-4321fedcba98';
const _roomId = '5cc85f64-5717-4562-b3fc-2c963f66afc8';
const _communityId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const _profileId = '9c1f0f2e-5a7b-4c3d-8e9f-0a1b2c3d4e5f';
const _hex = '0123456789abcdef0123456789abcdef';

Map<String, Object?> _operationBody({
  String status = 'succeeded',
  bool terminal = true,
  Object? retryAfterMs,
  Object? result,
  Object? error,
  String kind = 'directGetOrCreate',
}) => <String, Object?>{
  'operationId': _key,
  'kind': kind,
  'status': status,
  'terminal': terminal,
  'retryAfterMs': retryAfterMs,
  'result':
      result ??
      (status == 'succeeded'
          ? <String, Object?>{
              'targetPublicProfileId': _profileId,
              'streamCid': 'messaging:loop_direct_$_hex',
            }
          : null),
  'error': error,
  'createdAt': '2026-09-08T01:00:00.000Z',
  'updatedAt': '2026-09-08T01:00:01.000Z',
  'contractVersion': '2.0',
};

Map<String, Object?> _roomBody({
  String? role = 'listener',
  bool host = false,
  Object? observed,
  String state = 'live',
  Object? handRaise,
  String providerSyncStatus = 'confirmed',
  Object? providerSyncReason,
}) => <String, Object?>{
  'room': <String, Object?>{
    'voiceRoomId': _roomId,
    'communityId': _communityId,
    'callCid': 'audio_room:loop_voice_$_hex',
    'state': state,
    'provisionState': 'provisioned',
    'backstage': true,
    'createdAt': '2026-09-08T12:00:00.000Z',
    'endedAt': null,
  },
  'viewer': <String, Object?>{
    'role': role,
    'canInviteSpeakers': host,
    'canMuteAll': host,
    'canEndRoom': host,
    'handRaise': handRaise,
    'expiresAt': '2026-09-08T13:00:00.000Z',
  },
  'participants': <String, Object?>{
    'speakerCount': 3,
    'listenerCount': 42,
    'observed':
        observed ??
        <String, Object?>{
          'status': 'available',
          'memberCount': 45,
          'observedAt': '2026-09-08T12:30:00.000Z',
        },
  },
  'providerSync': <String, Object?>{
    'status': providerSyncStatus,
    'reasonCode': providerSyncReason,
  },
  'contractVersion': '2.0',
};

Dio _dio(void Function(RequestOptions, RequestInterceptorHandler) onRequest) {
  return Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest));
}

Response<Object?> _response(
  RequestOptions options,
  Object? data, {
  int statusCode = 200,
  Map<String, List<String>> extraHeaders = const <String, List<String>>{},
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': <String>['no-store'],
      'x-request-id': const <String>[_requestId],
      ...extraHeaders,
    }),
  );
}

/// Builds one transport whose single stubbed response is [body], capturing the
/// request the adapter would have sent.
(DioLoopV2CommunicationApi, List<RequestOptions>) _api(
  Object? body, {
  int statusCode = 200,
  Map<String, List<String>> extraHeaders = const <String, List<String>>{},
}) {
  final captured = <RequestOptions>[];
  final api = DioLoopV2CommunicationApi(
    _dio((options, handler) {
      captured.add(options);
      handler.resolve(
        _response(
          options,
          body,
          statusCode: statusCode,
          extraHeaders: extraHeaders,
        ),
      );
    }),
  );
  return (api, captured);
}

void main() {
  group('communication transport', () {
    test(
      'a direct-channel write carries exactly one canonical UUIDv4 key',
      () async {
        final (api, captured) = _api(_operationBody());

        final operation = await api.openDirectChannel(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _key,
          targetPublicProfileId: _profileId,
        );

        expect(operation.isSucceeded, isTrue);
        expect(operation.streamCid, 'messaging:loop_direct_$_hex');
        expect(captured.single.uri.path, '/v2/chat/direct-channels');
        expect(captured.single.headers['idempotency-key'], _key);
        expect(captured.single.headers['x-loop-contract-version'], '2.0');
      },
    );

    test(
      'a 202 without the poll Location header is an invalid payload',
      () async {
        final (api, _) = _api(
          _operationBody(
            status: 'pending',
            terminal: false,
            retryAfterMs: 250,
            result: null,
          ),
          statusCode: 202,
        );

        await expectLater(
          api.openDirectChannel(
            accessToken: _token,
            clientVersion: _clientVersion,
            idempotencyKey: _key,
            targetPublicProfileId: _profileId,
          ),
          throwsA(
            isA<LoopBackendFailure>().having(
              (failure) => failure.kind,
              'kind',
              LoopBackendFailureKind.invalidPayload,
            ),
          ),
        );
      },
    );

    test(
      'a 202 with the exact Location header keeps the operation pollable',
      () async {
        final (api, _) = _api(
          _operationBody(
            status: 'submitting',
            terminal: false,
            retryAfterMs: 400,
            result: null,
          ),
          statusCode: 202,
          extraHeaders: <String, List<String>>{
            'location': <String>['/v2/chat/operations/$_key'],
          },
        );

        final operation = await api.openDirectChannel(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _key,
          targetPublicProfileId: _profileId,
        );

        expect(operation.terminal, isFalse);
        expect(operation.retryAfterMs, 400);
        expect(operation.operationId, _key);
      },
    );

    test(
      'operatorRequired is a terminal unresolved outcome, not a failure',
      () async {
        final (api, _) = _api(
          _operationBody(
            status: 'operatorRequired',
            result: null,
            error: <String, Object?>{'code': 'operator_required'},
          ),
        );

        final operation = await api.getOperation(
          accessToken: _token,
          clientVersion: _clientVersion,
          operationId: _key,
        );

        expect(operation.terminal, isTrue);
        expect(operation.needsOperator, isTrue);
        expect(operation.isSucceeded, isFalse);
        expect(operation.streamCid, isNull);
      },
    );

    test(
      'a terminal operation that still asks for a retry is rejected',
      () async {
        final (api, _) = _api(_operationBody(retryAfterMs: 500));

        await expectLater(
          api.getOperation(
            accessToken: _token,
            clientVersion: _clientVersion,
            operationId: _key,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
      },
    );

    test(
      'leaving a group requires the echoed group and a null membership',
      () async {
        final (api, captured) = _api(<String, Object?>{
          'groupId': _roomId,
          'membership': null,
          'contractVersion': '2.0',
        });

        await api.leaveGroup(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _key,
          groupId: _roomId,
        );

        expect(captured.single.uri.path, '/v2/chat/groups/$_roomId/membership');
        expect(captured.single.method, 'DELETE');
        expect(captured.single.headers['idempotency-key'], _key);
      },
    );

    test(
      'a room snapshot keeps the hand-raise sequence a decimal string',
      () async {
        final (api, _) = _api(
          _roomBody(
            handRaise: <String, Object?>{
              'handRaiseId': _profileId,
              'sequence': '9007199254740993',
              'state': 'pending',
              'createdAt': '2026-09-08T12:30:00.000Z',
            },
          ),
        );

        final snapshot = await api.getVoiceRoom(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
        );

        expect(snapshot.viewer.handRaise!.sequence, '9007199254740993');
        expect(snapshot.viewer.role, VoiceRoomRole.listener);
        expect(snapshot.viewer.isHost, isFalse);
        expect(snapshot.participants.observed.memberCount, 45);
        expect(snapshot.participants.observed.observedAt, isNotNull);
      },
    );

    test(
      'an unobserved participant count is unavailable, never zero',
      () async {
        final (api, _) = _api(
          _roomBody(
            observed: <String, Object?>{
              'status': 'unavailable',
              'reasonCode': 'STREAM_PARTICIPANT_COUNT_NOT_OBSERVED',
            },
          ),
        );

        final snapshot = await api.getVoiceRoom(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
        );

        expect(snapshot.participants.observed.isAvailable, isFalse);
        expect(snapshot.participants.observed.memberCount, isNull);
        expect(
          snapshot.participants.observed.unavailable!.reasonCode,
          'STREAM_PARTICIPANT_COUNT_NOT_OBSERVED',
        );
      },
    );

    test('a confirmed provider sync may not also carry a reason', () async {
      final (api, _) = _api(
        _roomBody(providerSyncReason: 'STREAM_CALL_MUTE_UNCONFIRMED'),
      );

      await expectLater(
        api.getVoiceRoom(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test(
      'a host command posts to the exact speaker path with its key',
      () async {
        final (api, captured) = _api(_roomBody(role: 'host', host: true));

        final snapshot = await api.command(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _key,
          voiceRoomId: _roomId,
          command: VoiceRoomCommand.inviteSpeaker,
          publicProfileId: _profileId,
        );

        expect(snapshot.viewer.isHost, isTrue);
        expect(snapshot.viewer.showsHostControls, isTrue);
        expect(
          captured.single.uri.path,
          '/v2/voice-rooms/$_roomId/speakers/$_profileId',
        );
        expect(captured.single.method, 'POST');
      },
    );

    test(
      'a command that targets a profile refuses to run without one',
      () async {
        final (api, _) = _api(_roomBody());

        await expectLater(
          api.command(
            accessToken: _token,
            clientVersion: _clientVersion,
            idempotencyKey: _key,
            voiceRoomId: _roomId,
            command: VoiceRoomCommand.inviteSpeaker,
          ),
          throwsA(
            isA<LoopBackendFailure>().having(
              (failure) => failure.kind,
              'kind',
              LoopBackendFailureKind.invalidRequest,
            ),
          ),
        );
      },
    );

    test('a snapshot for another room is an invalid payload', () async {
      final (api, _) = _api(_roomBody());

      await expectLater(
        api.getVoiceRoom(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _communityId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('no live room returns the server reason and no snapshot', () async {
      final (api, _) = _api(<String, Object?>{
        'current': null,
        'reasonCode': 'COMMUNITY_VOICE_ROOM_NOT_LIVE',
        'contractVersion': '2.0',
      });

      final current = await api.getCurrentVoiceRoom(
        accessToken: _token,
        clientVersion: _clientVersion,
        communityId: _communityId,
      );

      expect(current.isLive, isFalse);
      expect(current.reasonCode, 'COMMUNITY_VOICE_ROOM_NOT_LIVE');
    });

    test('the hand-raise queue rejects a duplicated entry', () async {
      final entry = <String, Object?>{
        'handRaiseId': _profileId,
        'sequence': '1',
        'state': 'pending',
        'createdAt': '2026-09-08T12:20:00.000Z',
        'profile': <String, Object?>{
          'publicProfileId': _profileId,
          'loopId': 'LOOP-7HJKMNPQ',
          'alias': 'demo_owner',
          'avatarRef': null,
        },
      };
      final (api, _) = _api(<String, Object?>{
        'items': <Object?>[entry, entry],
        'contractVersion': '2.0',
      });

      await expectLater(
        api.listHandRaises(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('V2 Stream token loader', () {
    const streamUserId = 'loop_7a7448be64e24f9fa9f1891f1beec7fd';
    const apiKey = 'public-stream-api-key';

    Map<String, Object?> tokenBody({
      String userId = streamUserId,
      String key = apiKey,
      String expiresAt = '2026-09-08T02:00:00.000Z',
    }) => <String, Object?>{
      'apiKey': key,
      'token': 'a' * 64,
      'expiresAt': expiresAt,
      'user': <String, Object?>{'id': userId},
      'contractVersion': '2.0',
    };

    DioLoopV2StreamTokenRepository repository(
      List<RequestOptions> captured, {
      Object? body,
    }) => DioLoopV2StreamTokenRepository(
      _dio((options, handler) {
        captured.add(options);
        handler.resolve(_response(options, body ?? tokenBody()));
      }),
      expectedApiKey: apiKey,
      clientVersion: _clientVersion,
      now: () => DateTime.utc(2026, 9, 8, 1),
    );

    test(
      'chat and video tokens post to the V2 paths with the write headers',
      () async {
        final captured = <RequestOptions>[];
        final api = repository(captured);

        for (final product in LoopStreamTokenProduct.values) {
          await api.issue(
            product: product,
            expectedStreamUserId: streamUserId,
            accessToken: _token,
          );
        }

        expect(captured.map((request) => request.uri.path), <String>[
          '/v2/chat/token',
          '/v2/video/token',
        ]);
        for (final request in captured) {
          expect(request.method, 'POST');
          expect(request.headers['x-loop-contract-version'], '2.0');
          expect(request.headers['x-loop-client-version'], _clientVersion);
          expect(
            LoopV2Contract.uuidV4Pattern.hasMatch(
              request.headers['idempotency-key']! as String,
            ),
            isTrue,
          );
          // The identity is never client-selected: no body, no query.
          expect(request.data, isNull);
          expect(request.queryParameters, isEmpty);
        }
        // Every attempt is its own logical operation.
        expect(
          captured.first.headers['idempotency-key'],
          isNot(captured.last.headers['idempotency-key']),
        );
      },
    );

    test('a token for another Stream identity is an invalid payload', () async {
      final api = repository(
        <RequestOptions>[],
        body: tokenBody(userId: 'loop_0000000000000000000000000000ffff'),
      );

      await expectLater(
        api.issue(
          product: LoopStreamTokenProduct.chat,
          expectedStreamUserId: streamUserId,
          accessToken: _token,
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.kind,
            'kind',
            LoopBackendFailureKind.invalidPayload,
          ),
        ),
      );
    });

    test('a token for another public API key is an invalid payload', () async {
      final api = repository(
        <RequestOptions>[],
        body: tokenBody(key: 'another-public-key'),
      );

      await expectLater(
        api.issue(
          product: LoopStreamTokenProduct.chat,
          expectedStreamUserId: streamUserId,
          accessToken: _token,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a lifetime beyond the contract hour is an invalid payload', () async {
      final api = repository(
        <RequestOptions>[],
        body: tokenBody(expiresAt: '2026-09-09T01:00:00.000Z'),
      );

      await expectLater(
        api.issue(
          product: LoopStreamTokenProduct.chat,
          expectedStreamUserId: streamUserId,
          accessToken: _token,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test(
      'the seven-field envelope keeps the 401 and bootstrap policy',
      () async {
        for (final (status, code, kind)
            in <(int, String, LoopBackendFailureKind)>[
              (401, 'AUTH_INVALID', LoopBackendFailureKind.authentication),
              (
                409,
                'ACCOUNT_BOOTSTRAP_REQUIRED',
                LoopBackendFailureKind.invalidRequest,
              ),
              (429, 'RATE_LIMITED', LoopBackendFailureKind.unavailable),
            ]) {
          final api = DioLoopV2StreamTokenRepository(
            _dio((options, handler) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<Object?>(
                    requestOptions: options,
                    statusCode: status,
                    data: <String, Object?>{
                      'code': code,
                      'category': status == 401
                          ? 'authentication'
                          : status == 409
                          ? 'conflict'
                          : 'rateLimit',
                      'retryable': status != 401,
                      'userMessageKey': 'errors.streamToken',
                      'correlationId': _requestId,
                      'detailsSafe': null,
                      'providerReferenceSafe': null,
                    },
                    headers: Headers.fromMap(<String, List<String>>{
                      'cache-control': <String>['no-store'],
                      'x-request-id': const <String>[_requestId],
                      if (status == 401)
                        'www-authenticate': const <String>[
                          'Bearer realm="loop-api"',
                        ],
                    }),
                  ),
                ),
              );
            }),
            expectedApiKey: apiKey,
            clientVersion: _clientVersion,
          );

          await expectLater(
            api.issue(
              product: LoopStreamTokenProduct.chat,
              expectedStreamUserId: streamUserId,
              accessToken: _token,
            ),
            throwsA(
              isA<LoopBackendFailure>()
                  .having((failure) => failure.kind, 'kind', kind)
                  .having((failure) => failure.statusCode, 'statusCode', status)
                  .having((failure) => failure.code, 'code', code),
            ),
            reason: code,
          );
        }
      },
    );
  });

  group('community chat and voice sections', () {
    test('only `available` may carry a channel CID', () {
      expect(
        () => LoopV2ProjectionCodec.chatSection(<String, Object?>{
          'status': 'syncing',
          'channelCid': 'messaging:loop_community_$_hex',
          'memberState': 'pending',
          'reasonCode': 'COMMUNITY_CHANNEL_MEMBER_SYNCING',
        }),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2ProjectionCodec.chatSection(<String, Object?>{
          'status': 'available',
          'channelCid': null,
          'memberState': 'synced',
          'reasonCode': null,
        }),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the three chat states decode with their own reason codes', () {
      final syncing = LoopV2ProjectionCodec.chatSection(<String, Object?>{
        'status': 'syncing',
        'channelCid': null,
        'memberState': 'pending',
        'reasonCode': 'COMMUNITY_CHANNEL_MEMBER_SYNCING',
      });
      expect(syncing.isSyncing, isTrue);
      expect(syncing.isAvailable, isFalse);
      expect(syncing.memberState, CommunityChatMemberState.pending);

      final available = LoopV2ProjectionCodec.chatSection(<String, Object?>{
        'status': 'available',
        'channelCid': 'messaging:loop_community_$_hex',
        'memberState': 'synced',
        'reasonCode': null,
      });
      expect(available.isAvailable, isTrue);
      expect(available.channelCid, 'messaging:loop_community_$_hex');

      final unavailable = LoopV2ProjectionCodec.chatSection(<String, Object?>{
        'status': 'unavailable',
        'channelCid': null,
        'memberState': null,
        'reasonCode': 'COMMUNITY_MEMBERSHIP_REQUIRED',
      });
      expect(unavailable.isAvailable, isFalse);
      expect(unavailable.isSyncing, isFalse);
      expect(unavailable.reasonCode, 'COMMUNITY_MEMBERSHIP_REQUIRED');
    });

    test('a live voice section must carry the room it claims', () {
      expect(
        () => LoopV2ProjectionCodec.voiceSection(<String, Object?>{
          'status': 'available',
          'currentRoomId': null,
          'reasonCode': null,
        }),
        throwsA(isA<LoopBackendFailure>()),
      );
      final live = LoopV2ProjectionCodec.voiceSection(<String, Object?>{
        'status': 'available',
        'currentRoomId': _roomId,
        'reasonCode': null,
      });
      expect(live.isLive, isTrue);
      expect(live.currentRoomId, _roomId);
    });
  });
}
