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
const _handRaiseId = '3a4b5c6d-7e8f-4a90-8b1c-2d3e4f5a6b7c';
const _otherHandRaiseId = '1d2c3b4a-5e6f-4a7b-8c9d-0e1f2a3b4c5d';
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
  Object? participants,
  String state = 'live',
  Object? handRaise,
  String providerSyncStatus = 'confirmed',
  Object? providerSyncReason,
}) => <String, Object?>{
  'room': <String, Object?>{
    'voiceRoomId': _roomId,
    'communityId': _communityId,
    'communityName': 'Builders Guild',
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
  'participants':
      participants ??
      <String, Object?>{
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

Map<String, Object?> _memberRow({
  String role = 'listener',
  Object? publicProfileId = _profileId,
  String? alias = 'Voyager_344',
  bool handRaised = false,
  bool muted = false,
  bool isSelf = false,
  List<String> commands = const <String>[],
}) => <String, Object?>{
  'publicProfileId': publicProfileId,
  'display': alias == null
      ? <String, Object?>{
          'kind': 'anonymous',
          'labelKey': 'voiceRoom.member.anonymousMember',
        }
      : <String, Object?>{
          'kind': 'alias',
          'alias': alias,
          'publicProfileId': publicProfileId,
          'audience': 'everyone',
        },
  'role': role,
  'joinedAt': '2026-09-17T13:45:10.600Z',
  'handRaised': handRaised,
  'muted': muted,
  'isSelf': isSelf,
  'commands': commands,
};

Map<String, Object?> _handRaiseRow({
  String handRaiseId = _handRaiseId,
  String sequence = '1',
  Object? publicProfileId = _profileId,
  String? alias = 'DeFiMaxi_349',
  bool isSelf = false,
  List<String> commands = const <String>[],
}) => <String, Object?>{
  'handRaiseId': handRaiseId,
  'sequence': sequence,
  'state': 'pending',
  'createdAt': '2026-09-08T12:20:00.000Z',
  'publicProfileId': publicProfileId,
  'display': alias == null
      ? <String, Object?>{
          'kind': 'anonymous',
          'labelKey': 'voiceRoom.member.anonymousMember',
        }
      : <String, Object?>{
          'kind': 'alias',
          'alias': alias,
          'publicProfileId': publicProfileId,
          'audience': 'everyone',
        },
  'isSelf': isSelf,
  'commands': commands,
};

Map<String, Object?> _handRaisesBody({List<Object?>? items}) =>
    <String, Object?>{
      'items': items ?? <Object?>[_handRaiseRow()],
      'display': <String, Object?>{
        'anonymousMemberKey': 'voiceRoom.member.anonymousMember',
        'ruleKey': 'voiceRoom.member.display.anonymousModeOnly',
      },
      'contractVersion': '2.0',
    };

Map<String, Object?> _membersBody({
  String role = 'listener',
  List<Object?>? items,
  Object? nextCursor,
}) => <String, Object?>{
  'role': role,
  'items': items ?? <Object?>[_memberRow(role: role)],
  'nextCursor': nextCursor,
  'display': <String, Object?>{
    'anonymousMemberKey': 'voiceRoom.member.anonymousMember',
    'ruleKey': 'voiceRoom.member.display.anonymousModeOnly',
  },
  'contractVersion': '2.0',
};

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

    test('the live participant count is read apart from the members', () async {
      // Decision 0051: `participantCount` is the only figure that means
      // "people in the room now"; `memberCount` is who is allowed in.
      final (api, _) = _api(
        _roomBody(
          participants: <String, Object?>{
            'speakerCount': 3,
            'listenerCount': 42,
            'joinedCount': 46,
            'observed': <String, Object?>{
              'status': 'available',
              'participantCount': 12,
              'memberCount': 45,
              'observedAt': '2026-09-08T12:30:00.000Z',
            },
          },
        ),
      );

      final snapshot = await api.getVoiceRoom(
        accessToken: _token,
        clientVersion: _clientVersion,
        voiceRoomId: _roomId,
      );

      expect(snapshot.participants.joinedCount, 46);
      expect(snapshot.participants.observed.participantCount, 12);
      expect(snapshot.participants.observed.memberCount, 45);
    });

    test('a server without the new counts is still read', () async {
      // The two fields arrive with a server deploy this client does not
      // schedule; the room stays readable in the meantime and simply has no
      // figure for them.
      final (api, _) = _api(_roomBody());

      final snapshot = await api.getVoiceRoom(
        accessToken: _token,
        clientVersion: _clientVersion,
        voiceRoomId: _roomId,
      );

      expect(snapshot.participants.joinedCount, isNull);
      expect(snapshot.participants.observed.participantCount, isNull);
      expect(snapshot.participants.observed.memberCount, 45);
    });

    test('a count the contract does not define fails the payload', () async {
      final (api, _) = _api(
        _roomBody(
          participants: <String, Object?>{
            'speakerCount': 3,
            'listenerCount': 42,
            'onlineCount': 9,
            'observed': <String, Object?>{
              'status': 'available',
              'memberCount': 45,
              'observedAt': '2026-09-08T12:30:00.000Z',
            },
          },
        ),
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

    test('the room carries the community name for the banner', () async {
      final (api, _) = _api(_roomBody());

      final snapshot = await api.getVoiceRoom(
        accessToken: _token,
        clientVersion: _clientVersion,
        voiceRoomId: _roomId,
      );

      expect(snapshot.room.communityName, 'Builders Guild');
    });

    test('a room without a community name is an invalid payload', () async {
      final body = _roomBody();
      (body['room']! as Map<String, Object?>).remove('communityName');
      final (api, _) = _api(body);

      // Decision 0052 froze the key set: a room that does not name its
      // community is not the resource this client reads.
      await expectLater(
        api.getVoiceRoom(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
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

    test(
      'the roster is read for one view, with no limit beside a cursor',
      () async {
        final (api, captured) = _api(
          _membersBody(
            items: <Object?>[
              _memberRow(commands: <String>['invite_speaker']),
              _memberRow(publicProfileId: null, alias: null),
            ],
            nextCursor: 'next.page',
          ),
        );

        final page = await api.listMembers(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
          role: VoiceRoomRosterView.listener,
        );

        expect(captured.single.uri.path, '/v2/voice-rooms/$_roomId/members');
        expect(captured.single.uri.queryParameters, <String, String>{
          'role': 'listener',
        });
        expect(page.view, VoiceRoomRosterView.listener);
        expect(page.nextCursor, 'next.page');
        expect(page.items.first.commands, <VoiceRoomMemberCommand>[
          VoiceRoomMemberCommand.inviteSpeaker,
        ]);
        // An anonymous row a plain member reads carries no identifier at all.
        expect(page.items.last.publicProfileId, isNull);
        expect(page.items.last.name, isA<VoiceRoomMemberAnonymousName>());
        expect(page.items.last.commands, isEmpty);
      },
    );

    test(
      'a cursor continues the same view and carries its own page size',
      () async {
        final (api, captured) = _api(_membersBody(role: 'speaker'));

        await api.listMembers(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
          role: VoiceRoomRosterView.speaker,
          cursor: 'page2.cursor',
        );

        expect(captured.single.uri.queryParameters, <String, String>{
          'role': 'speaker',
          'cursor': 'page2.cursor',
        });
      },
    );

    test('a limit beside a cursor is refused before it is sent', () async {
      final (api, captured) = _api(_membersBody());

      await expectLater(
        api.listMembers(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
          role: VoiceRoomRosterView.listener,
          limit: 50,
          cursor: 'page2.cursor',
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.kind,
            'kind',
            LoopBackendFailureKind.invalidRequest,
          ),
        ),
      );
      expect(captured, isEmpty);
    });

    test('a roster page of the other view is an invalid payload', () async {
      final (api, _) = _api(_membersBody(role: 'speaker'));

      await expectLater(
        api.listMembers(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
          role: VoiceRoomRosterView.listener,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test(
      'a row command this client cannot render is an invalid payload',
      () async {
        final (api, _) = _api(
          _membersBody(
            items: <Object?>[
              _memberRow(commands: <String>['invite_speaker', 'transfer_host']),
            ],
          ),
        );

        // Rendering the subset would offer a row whose command list the reader
        // cannot see in full.
        await expectLater(
          api.listMembers(
            accessToken: _token,
            clientVersion: _clientVersion,
            voiceRoomId: _roomId,
            role: VoiceRoomRosterView.listener,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
      },
    );

    test('a command with no target is an invalid payload', () async {
      final (api, _) = _api(
        _membersBody(
          items: <Object?>[
            _memberRow(
              publicProfileId: null,
              alias: null,
              commands: <String>['invite_speaker'],
            ),
          ],
        ),
      );

      await expectLater(
        api.listMembers(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
          role: VoiceRoomRosterView.listener,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test(
      'a muted speaker row carries the way back out of the intent',
      () async {
        final (api, _) = _api(
          _membersBody(
            role: 'speaker',
            items: <Object?>[
              _memberRow(
                role: 'speaker',
                muted: true,
                commands: <String>['remove_speaker', 'unmute'],
              ),
            ],
          ),
        );

        final page = await api.listMembers(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
          role: VoiceRoomRosterView.speaker,
        );

        expect(page.items.single.muted, isTrue);
        expect(page.items.single.commands, <VoiceRoomMemberCommand>[
          VoiceRoomMemberCommand.removeSpeaker,
          VoiceRoomMemberCommand.unmute,
        ]);
      },
    );

    test(
      'the one command a viewer that is not the host may be given is its own',
      () async {
        final (api, _) = _api(
          _membersBody(
            role: 'speaker',
            items: <Object?>[
              _memberRow(
                role: 'speaker',
                muted: true,
                isSelf: true,
                commands: <String>['unmute_self'],
              ),
            ],
          ),
        );

        final page = await api.listMembers(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
          role: VoiceRoomRosterView.speaker,
        );

        expect(page.items.single.isSelf, isTrue);
        expect(page.items.single.commands, <VoiceRoomMemberCommand>[
          VoiceRoomMemberCommand.unmuteSelf,
        ]);
      },
    );

    test(
      'clearing the mute intent deletes the same resource with a write key',
      () async {
        final (api, captured) = _api(_roomBody(role: 'speaker'));

        final snapshot = await api.command(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _key,
          voiceRoomId: _roomId,
          command: VoiceRoomCommand.unmuteSpeaker,
          publicProfileId: _profileId,
        );

        expect(
          captured.single.uri.path,
          '/v2/voice-rooms/$_roomId/speakers/$_profileId/mute',
        );
        expect(captured.single.method, 'DELETE');
        expect(captured.single.headers['idempotency-key'], _key);
        expect(snapshot.room.voiceRoomId, _roomId);
      },
    );

    test(
      'muting one speaker addresses that speaker and answers with the room',
      () async {
        final (api, captured) = _api(_roomBody(role: 'host', host: true));

        final snapshot = await api.command(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _key,
          voiceRoomId: _roomId,
          command: VoiceRoomCommand.muteSpeaker,
          publicProfileId: _profileId,
        );

        expect(
          captured.single.uri.path,
          '/v2/voice-rooms/$_roomId/speakers/$_profileId/mute',
        );
        expect(captured.single.method, 'POST');
        expect(snapshot.room.voiceRoomId, _roomId);
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

    test('opening a room posts one key and reads the created room', () async {
      final (api, captured) = _api(
        _roomBody(role: 'host', host: true),
        statusCode: 201,
      );

      final snapshot = await api.createVoiceRoom(
        accessToken: _token,
        clientVersion: _clientVersion,
        idempotencyKey: _key,
        communityId: _communityId,
      );

      expect(snapshot.room.voiceRoomId, _roomId);
      expect(snapshot.viewer.isHost, isTrue);
      expect(
        captured.single.uri.path,
        '/v2/communities/$_communityId/voice-rooms',
      );
      expect(captured.single.method, 'POST');
      expect(captured.single.headers['idempotency-key'], _key);
      expect(captured.single.headers['x-loop-contract-version'], '2.0');
      // The command has no body of its own: the community is in the path.
      expect(captured.single.data, isNull);
    });

    test('a created room answered with 200 is an invalid payload', () async {
      final (api, _) = _api(_roomBody(role: 'host', host: true));

      await expectLater(
        api.createVoiceRoom(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _key,
          communityId: _communityId,
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

    test('a created room for another community is rejected', () async {
      final body = _roomBody(role: 'host', host: true);
      (body['room']! as Map<String, Object?>)['communityId'] = _profileId;
      final (api, _) = _api(body, statusCode: 201);

      await expectLater(
        api.createVoiceRoom(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _key,
          communityId: _communityId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a live room answers the open command with a conflict', () async {
      final api = DioLoopV2CommunicationApi(
        _dio((options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: _response(options, <String, Object?>{
                'code': 'RESOURCE_CONFLICT',
                'category': 'conflict',
                'retryable': false,
                'userMessageKey': 'errors.community.voiceRoomLive',
                'correlationId': _requestId,
                'detailsSafe': null,
                'providerReferenceSafe': null,
              }, statusCode: 409),
              type: DioExceptionType.badResponse,
            ),
          );
        }),
      );

      await expectLater(
        api.createVoiceRoom(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _key,
          communityId: _communityId,
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.code,
            'code',
            'RESOURCE_CONFLICT',
          ),
        ),
      );
    });

    test('the hand-raise queue rejects a duplicated entry', () async {
      final entry = _handRaiseRow();
      final (api, _) = _api(_handRaisesBody(items: <Object?>[entry, entry]));

      await expectLater(
        api.listHandRaises(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the queue is read under the roster identity projection', () async {
      final (api, captured) = _api(
        _handRaisesBody(
          items: <Object?>[
            _handRaiseRow(commands: <String>['invite_speaker']),
            _handRaiseRow(
              handRaiseId: _otherHandRaiseId,
              sequence: '2',
              publicProfileId: null,
              alias: null,
            ),
          ],
        ),
      );

      final entries = await api.listHandRaises(
        accessToken: _token,
        clientVersion: _clientVersion,
        voiceRoomId: _roomId,
      );

      expect(captured.single.uri.path, '/v2/voice-rooms/$_roomId/hand-raises');
      expect(entries.first.publicProfileId, _profileId);
      expect(entries.first.name, isA<VoiceRoomMemberAlias>());
      expect(entries.first.commands, <VoiceRoomMemberCommand>[
        VoiceRoomMemberCommand.inviteSpeaker,
      ]);
      // An anonymous member in the queue is as unaddressable as one in the
      // roster, and it carries no command at all.
      expect(entries.last.publicProfileId, isNull);
      expect(entries.last.name, isA<VoiceRoomMemberAnonymousName>());
      expect(entries.last.commands, isEmpty);
    });

    test('the queue entry the 0032 contract published is refused', () async {
      final (api, _) = _api(<String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'handRaiseId': _handRaiseId,
            'sequence': '1',
            'state': 'pending',
            'createdAt': '2026-09-08T12:20:00.000Z',
            'profile': <String, Object?>{
              'publicProfileId': _profileId,
              'loopId': 'LOOP-7HJKMNPQ',
              'alias': 'demo_owner',
              'avatarRef': null,
            },
          },
        ],
        'contractVersion': '2.0',
      });

      // Reading the old shape would publish a full identity the display rule
      // no longer allows, and it carries no display rule to read it under.
      await expectLater(
        api.listHandRaises(
          accessToken: _token,
          clientVersion: _clientVersion,
          voiceRoomId: _roomId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a queue command with no target is an invalid payload', () async {
      final (api, _) = _api(
        _handRaisesBody(
          items: <Object?>[
            _handRaiseRow(
              publicProfileId: null,
              alias: null,
              commands: <String>['invite_speaker'],
            ),
          ],
        ),
      );

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
