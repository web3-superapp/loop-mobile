import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/search/loop_v2_search_api.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/integrations/backend/v2/social/loop_v2_social_api.dart';

const requestId = '11111111-1111-4111-8111-111111111111';
const otherId = '22222222-2222-4222-8222-222222222222';
const communityId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const profileId = '9c1f0f2e-5a7b-4c3d-8e9f-0a1b2c3d4e5f';
const idempotencyKey = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const clientVersion = '0.1.0+1';
const _snapshotId = '0e358b31-e49f-48b9-89b2-c5c908c3ad5e';
const _formulaVersion = 'miningFormula-devBaseline-2026-09-15-r2';

Map<String, Object?> community({
  String verificationStatus = 'verified',
  Object? boundAssetKey,
  int memberCount = 128,
}) => <String, Object?>{
  'communityId': communityId,
  'name': 'Frog Holders',
  'slug': 'frog-holders',
  'description': null,
  'logoRef': 'avatar:preset/community-03',
  'verificationStatus': verificationStatus,
  'boundAssetKey': boundAssetKey,
  'memberCount': memberCount,
  'createdAt': '2026-09-07T01:00:00.000Z',
  'configVersion': 'communityV1',
};

Map<String, Object?> unavailable(String reasonCode) => <String, Object?>{
  'status': 'unavailable',
  'reasonCode': reasonCode,
};

Map<String, Object?> profile({Object? publicProfileId = profileId}) =>
    <String, Object?>{
      'publicProfileId': publicProfileId,
      'loopId': 'LOOP-7HJKMNPQ',
      'alias': 'frog_maxi',
      'avatarRef': 'avatar:preset/people-03',
    };

Map<String, Object?> viewer({
  bool canInviteAdmin = true,
  bool canMute = true,
  bool canBan = true,
  Object? membership = const <String, Object?>{
    'role': 'owner',
    'status': 'active',
    'joinedAt': '2026-09-07T01:00:00.000Z',
  },
}) => <String, Object?>{
  'membership': membership,
  'canInviteAdmin': canInviteAdmin,
  'canMute': canMute,
  'canBan': canBan,
};

Map<String, Object?> chatSection({
  String status = 'available',
  Object? channelCid =
      'messaging:loop_community_0123456789abcdef0123456789abcdef',
  Object? memberState = 'synced',
  Object? reasonCode,
}) => <String, Object?>{
  'status': status,
  'channelCid': channelCid,
  'memberState': memberState,
  'reasonCode': reasonCode,
};

Map<String, Object?> voiceSection({
  String status = 'unavailable',
  Object? currentRoomId,
  Object? reasonCode = 'COMMUNITY_VOICE_ROOM_NOT_LIVE',
}) => <String, Object?>{
  'status': status,
  'currentRoomId': currentRoomId,
  'reasonCode': reasonCode,
};

Map<String, Object?> detailBody({
  Map<String, Object?>? chat,
  Map<String, Object?>? voice,
  // Always sent since backend decision 0073; `null` for a viewer who is not
  // the current owner, which is what most of this file reads as.
  Object? application,
}) => <String, Object?>{
  'community': community(),
  'viewer': viewer(),
  'application': application,
  'miningPower': unavailable('MINING_FORMULA_BASELINE_PENDING'),
  'onlineCount': unavailable('STREAM_PRESENCE_NOT_CONNECTED'),
  'announcements': unavailable('COMMUNITY_ANNOUNCEMENTS_DEFERRED'),
  'officialLinks': unavailable('COMMUNITY_LINKS_DEFERRED'),
  'chat': chat ?? chatSection(),
  'voice': voice ?? voiceSection(),
  'contractVersion': '2.0',
};

Map<String, Object?> memberBody({
  Object? nextCursor,
  Object? ownerActions = const <Object?>[],
  Object? memberActions = const <Object?>[],
}) => <String, Object?>{
  'community': community(),
  'viewer': viewer(),
  'counts': <String, Object?>{
    'all': 128,
    'owner': 1,
    'admin': 3,
    'online': unavailable('STREAM_PRESENCE_NOT_CONNECTED'),
  },
  'items': <Object?>[
    <String, Object?>{
      'profile': profile(),
      'role': 'owner',
      'status': 'active',
      'joinedAt': '2026-09-07T01:00:00.000Z',
      'isSelf': false,
      'actions': ownerActions,
      'miningPower': unavailable('MINING_FORMULA_BASELINE_PENDING'),
    },
    <String, Object?>{
      'profile': profile(publicProfileId: null),
      'role': 'member',
      'status': 'active',
      'joinedAt': '2026-09-07T02:00:00.000Z',
      'isSelf': false,
      'actions': memberActions,
      'miningPower': unavailable('MINING_FORMULA_BASELINE_PENDING'),
    },
  ],
  'nextCursor': nextCursor,
  'contractVersion': '2.0',
};

void main() {
  group('community transport', () {
    test('GET /v2/community/home carries no idempotency key', () async {
      RequestOptions? captured;
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          captured = options;
          handler.resolve(
            _response(options, <String, Object?>{
              'joined': <String, Object?>{
                'items': <Object?>[
                  <String, Object?>{
                    'community': community(),
                    'membership': <String, Object?>{
                      'role': 'member',
                      'status': 'active',
                      'joinedAt': '2026-09-07T01:00:00.000Z',
                    },
                  },
                ],
                'truncated': true,
              },
              'owned': <String, Object?>{
                'items': <Object?>[],
                'truncated': false,
              },
              'discover': <Object?>[community()],
              'unread': unavailable('STREAM_UNREAD_NOT_CONNECTED'),
              'liveVoice': unavailable('STREAM_VOICE_NOT_CONNECTED'),
              'freshness': <String, Object?>{
                'observedAt': '2026-09-08T01:00:00.000Z',
                'source': 'database',
              },
              'recommendation': <String, Object?>{
                'recommendationId': otherId,
                'ruleVersion': 'rule:verified-members-v1',
              },
              'contractVersion': '2.0',
            }),
          );
        }),
      );

      final home = await api.getHome(
        accessToken: 'token',
        clientVersion: clientVersion,
      );

      expect(captured?.method, 'GET');
      expect(captured?.uri.path, DioLoopV2CommunityApi.homePath);
      expect(_header(captured!, 'idempotency-key'), isNull);
      expect(_loopHeaders(captured!), <String, Object?>{
        'x-loop-client-version': clientVersion,
        'x-loop-contract-version': '2.0',
      });
      expect(home.joined, hasLength(1));
      expect(home.joinedTruncated, isTrue);
      expect(home.unread.reasonCode, 'STREAM_UNREAD_NOT_CONNECTED');
      expect(home.recommendation.ruleVersion, 'rule:verified-members-v1');
    });

    test(
      'an observed online count carries what it observed and when',
      () async {
        final api = DioLoopV2CommunityApi(
          _dio((options, handler) {
            // The 2026-09-16 Development response for builders-guild, with one
            // member holding a Stream connection.
            final body = detailBody()
              ..['onlineCount'] = <String, Object?>{
                'status': 'available',
                'count': 1,
                'observedAt': '2026-09-16T06:44:39.224Z',
                'source': 'stream_member_presence',
              };
            handler.resolve(_response(options, body));
          }),
        );

        final detail = await api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        );

        final online = detail.onlineCount as CommunityOnlineCountObserved;
        expect(online.count, 1);
        expect(online.observedAt, DateTime.utc(2026, 9, 16, 6, 44, 39, 224));
        // What was counted decides what the number means, so the source is read
        // and not assumed.
        expect(online.source, CommunityPresenceSource.streamMemberPresence);
      },
    );

    test('a channel with nobody connected is a reading of zero', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = detailBody()
            ..['onlineCount'] = <String, Object?>{
              'status': 'available',
              'count': 0,
              'observedAt': '2026-09-16T06:44:39.224Z',
              'source': 'stream_member_presence',
            };
          handler.resolve(_response(options, body));
        }),
      );

      final detail = await api.getCommunity(
        accessToken: 'token',
        clientVersion: clientVersion,
        communityId: communityId,
      );

      // Stream answered zero. That is not the same fact as not having asked.
      expect((detail.onlineCount as CommunityOnlineCountObserved).count, 0);
    });

    test('a presence read that failed stays unavailable', () async {
      for (final reasonCode in <String>[
        'COMMUNITY_CHANNEL_NOT_PROVISIONED',
        'COMMUNITY_CHANNEL_PROVISION_FAILED',
        'STREAM_PRESENCE_READ_FAILED',
        'STREAM_PRESENCE_READ_TIMEOUT',
        'STREAM_PRESENCE_MEMBER_BOUND_EXCEEDED',
        'STREAM_PRESENCE_NOT_OBSERVED',
        'STREAM_PRESENCE_NOT_CONNECTED',
        'COMMUNICATION_RUNTIME_UNAVAILABLE',
      ]) {
        final api = DioLoopV2CommunityApi(
          _dio((options, handler) {
            final body = detailBody()
              ..['onlineCount'] = unavailable(reasonCode);
            handler.resolve(_response(options, body));
          }),
        );

        final detail = await api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        );

        expect(
          (detail.onlineCount as CommunityOnlineCountUnavailable).reasonCode,
          reasonCode,
          reason: reasonCode,
        );
        // The unavailable branch never resolves to a number.
        expect(detail.onlineCount, isNot(isA<CommunityOnlineCountObserved>()));
      }
    });

    test('an online count from an unknown source is refused', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = detailBody()
            ..['onlineCount'] = <String, Object?>{
              'status': 'available',
              'count': 3,
              'observedAt': '2026-09-16T06:44:39.224Z',
              'source': 'channel_watchers',
            };
          handler.resolve(_response(options, body));
        }),
      );

      // A different source is a different fact under the same name.
      await expectLater(
        api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an observation with no time is refused', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = detailBody()
            ..['onlineCount'] = <String, Object?>{
              'status': 'available',
              'count': 3,
              'source': 'stream_member_presence',
            };
          handler.resolve(_response(options, body));
        }),
      );

      await expectLater(
        api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test(
      "a community's settled power carries the weight that made it",
      () async {
        final api = DioLoopV2CommunityApi(
          _dio((options, handler) {
            // The 2026-09-16 Development projection for mock-defi-morning.
            final body = detailBody()
              ..['miningPower'] = <String, Object?>{
                'status': 'available',
                'subject': 'community',
                'power': '0',
                'snapshotId': _snapshotId,
                'formulaVersion': _formulaVersion,
                'computedAt': '2026-09-15T14:58:54.366Z',
                'scope': 'development_baseline',
                'weight': <String, Object?>{
                  'status': 'approved',
                  'value': '0.8',
                  'configVersion': _formulaVersion,
                  'reviewedAt': '2026-09-15T14:58:52.089Z',
                },
                'participants': <String, Object?>{
                  'status': 'available',
                  'count': 0,
                },
              };
            handler.resolve(_response(options, body));
          }),
        );

        final detail = await api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        );

        final power = detail.miningPower as LoopCommunityMiningPower;
        expect(power.power, '0');
        expect(power.snapshotId, _snapshotId);
        expect(power.formulaVersion, _formulaVersion);
        expect(power.computedAt, DateTime.utc(2026, 9, 15, 14, 58, 54, 366));
        // The label comes from the version's own declaration, never from the
        // version string.
        expect(power.scope, MiningFormulaScope.developmentBaseline);
        expect(power.isBaseline, isTrue);
        final weight = power.weight as MiningCommunityWeightApproved;
        expect(weight.value, '0.8');
        expect(weight.configVersion, _formulaVersion);
        expect((power.participants as MiningParticipantsCount).count, 0);
      },
    );

    test("an account's settled power carries no community weight", () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = memberBody();
          final first =
              (body['items']! as List<Object?>).first as Map<String, Object?>;
          first['miningPower'] = <String, Object?>{
            'status': 'available',
            'subject': 'account',
            'power': '230.5',
            'snapshotId': _snapshotId,
            'formulaVersion': _formulaVersion,
            'computedAt': '2026-09-15T14:58:54.366Z',
            'scope': 'development_baseline',
          };
          handler.resolve(_response(options, body));
        }),
      );

      final directory = await api.listMembers(
        accessToken: 'token',
        clientVersion: clientVersion,
        communityId: communityId,
        role: CommunityMemberFilter.all,
      );

      final power = directory.items.first.miningPower as LoopAccountMiningPower;
      expect(power.power, '230.5');
      expect(power.isBaseline, isTrue);
      // One person's total across every asset: no single community weight
      // explains it, so the shape carries none.
      expect(power, isNot(isA<LoopCommunityMiningPower>()));
    });

    // Decision 0057. A later run that could not value a holding is never
    // published, so the card keeps this number and says which moment it is
    // from. The key is added, so a deployment without it reads as before.
    test('a settled power says when a later run did not finish', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = detailBody()
            ..['miningPower'] = <String, Object?>{
              'status': 'available',
              'subject': 'community',
              'power': '4.482309',
              'snapshotId': _snapshotId,
              'formulaVersion': _formulaVersion,
              'computedAt': '2026-09-15T14:58:54.366Z',
              'scope': 'development_baseline',
              'stale': true,
              'weight': <String, Object?>{
                'status': 'approved',
                'value': '0.8',
                'configVersion': _formulaVersion,
                'reviewedAt': '2026-09-15T14:58:52.089Z',
              },
              'participants': <String, Object?>{
                'status': 'available',
                'count': 1,
              },
            };
          handler.resolve(_response(options, body));
        }),
      );

      final detail = await api.getCommunity(
        accessToken: 'token',
        clientVersion: clientVersion,
        communityId: communityId,
      );

      final power = detail.miningPower as LoopCommunityMiningPower;
      expect(power.stale, isTrue);
      expect(power.power, '4.482309');
    });

    test('a member row carries the same flag, and defaults to false', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = memberBody();
          final items = body['items']! as List<Object?>;
          (items.first
              as Map<String, Object?>)['miningPower'] = <String, Object?>{
            'status': 'available',
            'subject': 'account',
            'power': '230.5',
            'snapshotId': _snapshotId,
            'formulaVersion': _formulaVersion,
            'computedAt': '2026-09-15T14:58:54.366Z',
            'scope': 'development_baseline',
            'stale': true,
          };
          (items.last
              as Map<String, Object?>)['miningPower'] = <String, Object?>{
            'status': 'available',
            'subject': 'account',
            'power': '0',
            'snapshotId': _snapshotId,
            'formulaVersion': _formulaVersion,
            'computedAt': '2026-09-15T14:58:54.366Z',
            'scope': 'development_baseline',
          };
          handler.resolve(_response(options, body));
        }),
      );

      final directory = await api.listMembers(
        accessToken: 'token',
        clientVersion: clientVersion,
        communityId: communityId,
        role: CommunityMemberFilter.all,
      );

      expect(
        (directory.items.first.miningPower as LoopAccountMiningPower).stale,
        isTrue,
      );
      expect(
        (directory.items.last.miningPower as LoopAccountMiningPower).stale,
        isFalse,
      );
    });

    test('a staleness flag that is not a boolean is refused', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = detailBody()
            ..['miningPower'] = <String, Object?>{
              'status': 'available',
              'subject': 'account',
              'power': '1',
              'snapshotId': _snapshotId,
              'formulaVersion': _formulaVersion,
              'computedAt': '2026-09-15T14:58:54.366Z',
              'scope': 'development_baseline',
              'stale': 'true',
            };
          handler.resolve(_response(options, body));
        }),
      );

      await expectLater(
        api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a product version puts no development label on a row', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = detailBody()
            ..['miningPower'] = <String, Object?>{
              'status': 'available',
              'subject': 'community',
              'power': '38200',
              'snapshotId': _snapshotId,
              'formulaVersion': 'miningFormulaV1',
              'computedAt': '2026-09-15T14:58:54.366Z',
              'scope': null,
              'weight': <String, Object?>{
                'status': 'unavailable',
                'reasonCode': 'COMMUNITY_WEIGHT_PENDING_REVIEW',
                'reviewStatus': 'pending_review',
              },
              'participants': <String, Object?>{
                'status': 'unavailable',
                'reasonCode': 'COMMUNITY_WEIGHT_PENDING_REVIEW',
              },
            };
          handler.resolve(_response(options, body));
        }),
      );

      final detail = await api.getCommunity(
        accessToken: 'token',
        clientVersion: clientVersion,
        communityId: communityId,
      );

      final power = detail.miningPower as LoopCommunityMiningPower;
      expect(power.scope, MiningFormulaScope.product);
      expect(power.isBaseline, isFalse);
      final weight = power.weight as MiningCommunityWeightPending;
      expect(weight.reasonCode, 'COMMUNITY_WEIGHT_PENDING_REVIEW');
      expect(weight.reviewStatus, MiningWeightReviewStatus.pendingReview);
      expect(power.participants, isA<MiningParticipantsUnavailable>());
    });

    test('a mining power without a subject is refused', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          // The shape before the subject existed: it can no longer be read,
          // because nothing says what the number is a number of.
          final body = detailBody()
            ..['miningPower'] = <String, Object?>{
              'status': 'available',
              'power': '230.5',
              'snapshotId': _snapshotId,
              'formulaVersion': _formulaVersion,
              'computedAt': '2026-09-15T14:58:54.366Z',
            };
          handler.resolve(_response(options, body));
        }),
      );

      await expectLater(
        api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('a community power without its weight is refused', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = detailBody()
            ..['miningPower'] = <String, Object?>{
              'status': 'available',
              'subject': 'community',
              'power': '0',
              'snapshotId': _snapshotId,
              'formulaVersion': _formulaVersion,
              'computedAt': '2026-09-15T14:58:54.366Z',
              'scope': 'development_baseline',
              'participants': <String, Object?>{
                'status': 'available',
                'count': 0,
              },
            };
          handler.resolve(_response(options, body));
        }),
      );

      await expectLater(
        api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('an account power carrying a community weight is refused', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = detailBody()
            ..['miningPower'] = <String, Object?>{
              'status': 'available',
              'subject': 'account',
              'power': '230.5',
              'snapshotId': _snapshotId,
              'formulaVersion': _formulaVersion,
              'computedAt': '2026-09-15T14:58:54.366Z',
              'scope': 'development_baseline',
              'weight': <String, Object?>{
                'status': 'approved',
                'value': '0.8',
                'configVersion': _formulaVersion,
                'reviewedAt': '2026-09-15T14:58:52.089Z',
              },
            };
          handler.resolve(_response(options, body));
        }),
      );

      await expectLater(
        api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('an unknown scope is refused', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = detailBody()
            ..['miningPower'] = <String, Object?>{
              'status': 'available',
              'subject': 'account',
              'power': '230.5',
              'snapshotId': _snapshotId,
              'formulaVersion': _formulaVersion,
              'computedAt': '2026-09-15T14:58:54.366Z',
              'scope': 'staging_baseline',
            };
          handler.resolve(_response(options, body));
        }),
      );

      await expectLater(
        api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('a mining power without its snapshot is refused', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          // A bare number is a figure with no source: the row would print it
          // without being able to say what produced it.
          final body = detailBody()
            ..['miningPower'] = <String, Object?>{
              'status': 'available',
              'subject': 'account',
              'power': '230.5',
            };
          handler.resolve(_response(options, body));
        }),
      );

      await expectLater(
        api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('a negative mining power is refused', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = detailBody()
            ..['miningPower'] = <String, Object?>{
              'status': 'available',
              'subject': 'account',
              'power': '-1',
              'snapshotId': _snapshotId,
              'formulaVersion': _formulaVersion,
              'computedAt': '2026-09-15T14:58:54.366Z',
              'scope': 'development_baseline',
            };
          handler.resolve(_response(options, body));
        }),
      );

      await expectLater(
        api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('an unknown response field is an invalid payload', () async {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          final body = detailBody()..['extra'] = 'unexpected';
          handler.resolve(_response(options, body));
        }),
      );

      await expectLater(
        api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('a missing Cache-Control: no-store is an invalid payload', () async {
      final api = DioLoopV2CommunityApi(
        _dio(
          (options, handler) => handler.resolve(
            _response(options, detailBody(), cacheControl: 'private'),
          ),
        ),
      );

      await expectLater(
        api.getCommunity(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test(
      'a correlationId that differs from X-Request-ID is rejected',
      () async {
        final api = DioLoopV2CommunityApi(
          _dio(
            (options, handler) => handler.reject(
              _errorResponse(
                options,
                statusCode: 403,
                code: 'PERMISSION_DENIED',
                category: 'authorization',
                userMessageKey: 'errors.permission.denied',
                correlationId: otherId,
              ),
            ),
          ),
        );

        await expectLater(
          api.join(
            accessToken: 'token',
            clientVersion: clientVersion,
            idempotencyKey: idempotencyKey,
            communityId: communityId,
          ),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      },
    );

    test(
      'the seven-field envelope maps onto the feature failure kind',
      () async {
        final api = DioLoopV2CommunityApi(
          _dio(
            (options, handler) => handler.reject(
              _errorResponse(
                options,
                statusCode: 409,
                code: 'PROFILE_ACTIVATION_REQUIRED',
                category: 'conflict',
                userMessageKey: 'errors.profile.activationRequired',
              ),
            ),
          ),
        );

        try {
          await api.join(
            accessToken: 'token',
            clientVersion: clientVersion,
            idempotencyKey: idempotencyKey,
            communityId: communityId,
          );
          fail('the join must not succeed');
        } on LoopBackendFailure catch (failure) {
          expect(failure.code, 'PROFILE_ACTIVATION_REQUIRED');
          expect(failure.requestId, requestId);
          expect(
            communityFailureKindForV2(failure, write: true).name,
            'activationRequired',
          );
        }
      },
    );

    test('a write carries exactly one canonical UUIDv4 key', () async {
      RequestOptions? captured;
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          captured = options;
          handler.resolve(_response(options, detailBody()));
        }),
      );

      await api.join(
        accessToken: 'token',
        clientVersion: clientVersion,
        idempotencyKey: idempotencyKey,
        communityId: communityId,
      );

      expect(captured?.method, 'POST');
      expect(_header(captured!, 'idempotency-key'), idempotencyKey);
    });

    test('a non-UUIDv4 idempotency key never leaves the device', () async {
      var dispatched = false;
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          dispatched = true;
          handler.resolve(_response(options, detailBody()));
        }),
      );

      await expectLater(
        api.join(
          accessToken: 'token',
          clientVersion: clientVersion,
          idempotencyKey: 'not-a-uuid',
          communityId: communityId,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
      );
      expect(dispatched, isFalse);
    });

    test(
      'a list cursor is echoed verbatim and never sent with a limit',
      () async {
        RequestOptions? captured;
        final api = DioLoopV2CommunityApi(
          _dio((options, handler) {
            captured = options;
            handler.resolve(
              _response(options, <String, Object?>{
                'items': <Object?>[community()],
                'nextCursor': 'AbC-1_2.dEf-3_4',
                'recommendation': <String, Object?>{
                  'recommendationId': otherId,
                  'ruleVersion': 'rule:verified-members-v1',
                },
                'contractVersion': '2.0',
              }),
            );
          }),
        );

        final page = await api.listCommunities(
          accessToken: 'token',
          clientVersion: clientVersion,
          sort: CommunityDirectorySort.newest,
          verification: CommunityVerificationFilter.all,
          membership: CommunityMembershipFilter.joined,
          cursor: 'Zzz-9_9.Yyy-8_8',
        );

        expect(captured?.queryParameters, <String, Object?>{
          'sort': 'newest',
          'verification': 'all',
          'membership': 'joined',
          'cursor': 'Zzz-9_9.Yyy-8_8',
        });
        expect(captured?.queryParameters.containsKey('limit'), isFalse);
        expect(page.nextCursor, 'AbC-1_2.dEf-3_4');
      },
    );

    test(
      'a member without a profile row is listed but not a command target',
      () async {
        final api = DioLoopV2CommunityApi(
          _dio(
            (options, handler) =>
                handler.resolve(_response(options, memberBody())),
          ),
        );

        final directory = await api.listMembers(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
          role: CommunityMemberFilter.all,
        );

        expect(directory.items, hasLength(2));
        expect(directory.items.last.profile.publicProfileId, isNull);
        // The server is the one that decides a row carries no command; the
        // client neither adds nor removes an entry.
        expect(directory.items.last.actions, isEmpty);
        expect(
          directory.counts.online.reasonCode,
          'STREAM_PRESENCE_NOT_CONNECTED',
        );
      },
    );

    test(
      "a member row's commands are taken verbatim from the server",
      () async {
        final api = DioLoopV2CommunityApi(
          _dio(
            (options, handler) => handler.resolve(
              _response(
                options,
                memberBody(
                  ownerActions: const <Object?>[],
                  memberActions: const <Object?>[
                    'assignAdmin',
                    'transferOwnership',
                    'mute',
                    'ban',
                  ],
                ),
              ),
            ),
          ),
        );

        final directory = await api.listMembers(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
          role: CommunityMemberFilter.all,
        );

        expect(directory.items.first.actions, isEmpty);
        expect(directory.items.last.actions, <CommunityGovernanceAction>[
          CommunityGovernanceAction.promote,
          CommunityGovernanceAction.transfer,
          CommunityGovernanceAction.mute,
          CommunityGovernanceAction.ban,
        ]);
      },
    );

    test(
      'a member row without an actions list is an invalid payload',
      () async {
        final body = memberBody();
        for (final item in body['items']! as List<Object?>) {
          (item! as Map<String, Object?>).remove('actions');
        }
        final api = DioLoopV2CommunityApi(
          _dio((options, handler) => handler.resolve(_response(options, body))),
        );

        await expectLater(
          api.listMembers(
            accessToken: 'token',
            clientVersion: clientVersion,
            communityId: communityId,
            role: CommunityMemberFilter.all,
          ),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      },
    );

    test('an unrenderable governance command is an invalid payload', () async {
      // A name this build cannot render, a repeat, a non-string, and a
      // non-list are all contract breaks: a half-understood governance list
      // is never partially rendered.
      for (final actions in <Object?>[
        <Object?>['mute', 'purge'],
        <Object?>['mute', 'mute'],
        <Object?>['mute', 7],
        'mute',
        null,
      ]) {
        final api = DioLoopV2CommunityApi(
          _dio(
            (options, handler) => handler.resolve(
              _response(options, memberBody(memberActions: actions)),
            ),
          ),
        );

        await expectLater(
          api.listMembers(
            accessToken: 'token',
            clientVersion: clientVersion,
            communityId: communityId,
            role: CommunityMemberFilter.all,
          ),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
          reason: '$actions',
        );
      }
    });

    test('referral rules keep the decimal boost as a string', () async {
      final api = DioLoopV2CommunityApi(
        _dio(
          (options, handler) => handler.resolve(
            _response(options, <String, Object?>{
              'configVersion': 'referralRulesV1',
              'effectiveAt': '2026-09-01T00:00:00.000Z',
              'appliesTo': 'miningPower',
              'levels': <Object?>[
                for (final level in <(int, String)>[
                  (1, '10'),
                  (2, '5'),
                  (3, '3'),
                  (4, '2'),
                  (5, '1'),
                ])
                  <String, Object?>{
                    'level': level.$1,
                    'boostPercent': level.$2,
                    'descriptionKey': 'mining.referral.level${level.$1}',
                  },
              ],
              'edges': unavailable('REFERRAL_GRAPH_DEFERRED'),
              'inviteCode': unavailable('INVITE_CODE_DEFERRED'),
              'contractVersion': '2.0',
            }),
          ),
        ),
      );

      final rules = await api.getReferralRules(
        accessToken: 'token',
        clientVersion: clientVersion,
      );

      expect(rules.levels.map((level) => level.boostPercent), <String>[
        '10',
        '5',
        '3',
        '2',
        '1',
      ]);
      expect(rules.edges.reasonCode, 'REFERRAL_GRAPH_DEFERRED');
      expect(rules.inviteCode.reasonCode, 'INVITE_CODE_DEFERRED');
    });
  });

  group('social transport', () {
    test('a follow write posts to the exact target with its key', () async {
      RequestOptions? captured;
      final api = DioLoopV2SocialApi(
        _dio((options, handler) {
          captured = options;
          handler.resolve(
            _response(options, <String, Object?>{
              'profile': profile(),
              'viewerFollows': true,
              'contractVersion': '2.0',
            }),
          );
        }),
      );

      final outcome = await api.setFollowing(
        accessToken: 'token',
        clientVersion: clientVersion,
        idempotencyKey: idempotencyKey,
        publicProfileId: profileId,
        following: true,
      );

      expect(captured?.method, 'POST');
      expect(captured?.uri.path, '/v2/connections/follow/$profileId');
      expect(_header(captured!, 'idempotency-key'), idempotencyKey);
      expect(outcome.viewerFollows, isTrue);
    });

    test('the decision response decides the blocked flag', () async {
      final api = DioLoopV2SocialApi(
        _dio(
          (options, handler) => handler.resolve(
            _response(options, <String, Object?>{
              'messageRequestId': communityId,
              'decision': 'report',
              'blocked': true,
              'contractVersion': '2.0',
            }),
          ),
        ),
      );

      final outcome = await api.decideMessageRequest(
        accessToken: 'token',
        clientVersion: clientVersion,
        idempotencyKey: idempotencyKey,
        messageRequestId: communityId,
        decision: MessageRequestDecision.report,
      );

      expect(outcome.blocked, isTrue);
      expect(outcome.decision, MessageRequestDecision.report);
    });

    test(
      'a decision echoed for another request is an invalid payload',
      () async {
        final api = DioLoopV2SocialApi(
          _dio(
            (options, handler) => handler.resolve(
              _response(options, <String, Object?>{
                'messageRequestId': profileId,
                'decision': 'report',
                'blocked': true,
                'contractVersion': '2.0',
              }),
            ),
          ),
        );

        await expectLater(
          api.decideMessageRequest(
            accessToken: 'token',
            clientVersion: clientVersion,
            idempotencyKey: idempotencyKey,
            messageRequestId: communityId,
            decision: MessageRequestDecision.report,
          ),
          throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
        );
      },
    );

    test('a message request never carries a body preview', () async {
      final api = DioLoopV2SocialApi(
        _dio(
          (options, handler) => handler.resolve(
            _response(options, <String, Object?>{
              'items': <Object?>[
                <String, Object?>{
                  'messageRequestId': communityId,
                  'profile': profile(),
                  'createdAt': '2026-09-07T01:00:00.000Z',
                  'expiresAt': '2026-09-14T01:00:00.000Z',
                  'preview': unavailable('MESSAGE_PREVIEW_DEFERRED'),
                  'aiModeration': unavailable('AI_MODERATION_DEFERRED'),
                },
              ],
              'nextCursor': null,
              'contractVersion': '2.0',
            }),
          ),
        ),
      );

      final page = await api.listMessageRequests(
        accessToken: 'token',
        clientVersion: clientVersion,
      );

      expect(page.items.single.preview.reasonCode, 'MESSAGE_PREVIEW_DEFERRED');
      expect(
        page.items.single.aiModeration.reasonCode,
        'AI_MODERATION_DEFERRED',
      );
    });

    test('a blocks page rejects an entry of another kind', () async {
      final api = DioLoopV2SocialApi(
        _dio(
          (options, handler) => handler.resolve(
            _response(options, <String, Object?>{
              'kind': 'user',
              'items': <Object?>[
                <String, Object?>{
                  'kind': 'domain',
                  'stableId': 'example.test',
                  'profile': null,
                  'reasonCode': 'user_request',
                  'createdAt': '2026-09-07T01:00:00.000Z',
                },
              ],
              'counts': <String, Object?>{'user': 1},
              'nextCursor': null,
              'contractVersion': '2.0',
            }),
          ),
        ),
      );

      await expectLater(
        api.listBlocks(
          accessToken: 'token',
          clientVersion: clientVersion,
          kind: BlockKind.user,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });
  });

  group('search transport', () {
    test(
      'an unavailable domain returns its server reason and no results',
      () async {
        final api = DioLoopV2SearchApi(
          _dio(
            (options, handler) => handler.resolve(
              _response(options, <String, Object?>{
                'domain': 'dapps',
                'status': 'unavailable',
                'reasonCode': 'DAPP_DIRECTORY_NOT_INTEGRATED',
                'results': <Object?>[],
                'nextCursor': null,
                'contractVersion': '2.0',
              }),
            ),
          ),
        );

        final page = await api.search(
          accessToken: 'token',
          clientVersion: clientVersion,
          domain: SearchDomain.dapps,
          query: 'pepe',
        );

        expect(page.available, isFalse);
        expect(page.reasonCode, 'DAPP_DIRECTORY_NOT_INTEGRATED');
        expect(page.results, isEmpty);
      },
    );

    test(
      'a result carries its destination kind, never a derived route',
      () async {
        RequestOptions? captured;
        final api = DioLoopV2SearchApi(
          _dio((options, handler) {
            captured = options;
            handler.resolve(
              _response(options, <String, Object?>{
                'domain': 'communities',
                'status': 'available',
                'reasonCode': null,
                'results': <Object?>[
                  <String, Object?>{
                    'resultType': 'community',
                    'stableId': communityId,
                    'displaySnapshot': <String, Object?>{
                      'title': 'Frog Holders',
                      'subtitle': 'frog-holders',
                      'avatarRef': 'avatar:preset/community-03',
                      // Required on every domain since backend decision 0072
                      // (token logos); null for a community row.
                      'logo': null,
                      'memberCount': 128,
                      'verificationStatus': 'verified',
                    },
                    'destination': <String, Object?>{
                      'kind': 'communityProfile',
                    },
                  },
                ],
                'nextCursor': null,
                'contractVersion': '2.0',
              }),
            );
          }),
        );

        final page = await api.search(
          accessToken: 'token',
          clientVersion: clientVersion,
          domain: SearchDomain.communities,
          query: '  pepe  ',
        );

        expect(captured?.queryParameters['q'], 'pepe');
        expect(
          page.results.single.destination,
          isA<SearchCommunityProfileDestination>(),
        );
        expect(page.results.single.memberCount, 128);
      },
    );

    test('an asset row is named by its CAIP id and opens by it', () async {
      // Backend decision 0071: `stableId` is the registry's own asset id, and
      // `assetDetail` is the one destination that carries a parameter.
      const assetId = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';
      final api = DioLoopV2SearchApi(
        _dio(
          (options, handler) => handler.resolve(
            _response(options, <String, Object?>{
              'domain': 'assets',
              'status': 'available',
              'reasonCode': null,
              'results': <Object?>[
                <String, Object?>{
                  'resultType': 'asset',
                  'stableId': assetId,
                  'displaySnapshot': <String, Object?>{
                    'title': 'USDT',
                    'subtitle': 'Tether USD',
                    'avatarRef': null,
                    'logo': <String, Object?>{
                      'status': 'available',
                      'url':
                          'https://raw.githubusercontent.com/trustwallet/'
                          'assets/master/blockchains/smartchain/assets/'
                          '0x55d398326f99059fF775485246999027B3197955/'
                          'logo.png',
                      'source': 'trustwallet',
                      'observedAt': null,
                    },
                    'memberCount': null,
                    'verificationStatus': 'pending',
                  },
                  'destination': <String, Object?>{
                    'kind': 'assetDetail',
                    'assetId': assetId,
                  },
                },
              ],
              'nextCursor': null,
              'contractVersion': '2.0',
            }),
          ),
        ),
      );

      final page = await api.search(
        accessToken: 'token',
        clientVersion: clientVersion,
        domain: SearchDomain.assets,
        query: 'usd',
      );

      final row = page.results.single;
      expect(row.resultType, SearchResultType.asset);
      expect(row.stableId, assetId);
      expect(row.title, 'USDT');
      expect(row.subtitle, 'Tether USD');
      // Decision 0086: the asset row's published artwork reaches the model, so
      // 搜索 draws the token's own mark. The user and community rows carry a
      // `null` logo and keep drawing the identity atlas.
      expect(
        row.logoUrl,
        'https://raw.githubusercontent.com/trustwallet/assets/master/'
        'blockchains/smartchain/assets/'
        '0x55d398326f99059fF775485246999027B3197955/logo.png',
      );
      expect(
        row.destination,
        isA<SearchAssetDestination>().having(
          (destination) => destination.assetId,
          'assetId',
          assetId,
        ),
      );
    });

    test('an asset id that is not canonical is refused', () async {
      final api = DioLoopV2SearchApi(
        _dio(
          (options, handler) => handler.resolve(
            _response(options, <String, Object?>{
              'domain': 'assets',
              'status': 'available',
              'reasonCode': null,
              'results': <Object?>[
                <String, Object?>{
                  'resultType': 'asset',
                  'stableId': 'USDT',
                  'displaySnapshot': <String, Object?>{
                    'title': 'USDT',
                    'subtitle': 'Tether USD',
                    'avatarRef': null,
                    'logo': <String, Object?>{
                      'status': 'available',
                      'url':
                          'https://raw.githubusercontent.com/trustwallet/'
                          'assets/master/blockchains/smartchain/assets/'
                          '0x55d398326f99059fF775485246999027B3197955/'
                          'logo.png',
                      'source': 'trustwallet',
                      'observedAt': null,
                    },
                    'memberCount': null,
                    'verificationStatus': 'pending',
                  },
                  'destination': <String, Object?>{
                    'kind': 'assetDetail',
                    'assetId': 'USDT',
                  },
                },
              ],
              'nextCursor': null,
              'contractVersion': '2.0',
            }),
          ),
        ),
      );

      await expectLater(
        api.search(
          accessToken: 'token',
          clientVersion: clientVersion,
          domain: SearchDomain.assets,
          query: 'usd',
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('a prefix shorter than two code points spends no quota', () async {
      var dispatched = false;
      final api = DioLoopV2SearchApi(
        _dio((options, handler) {
          dispatched = true;
          handler.resolve(_response(options, <String, Object?>{}));
        }),
      );

      await expectLater(
        api.search(
          accessToken: 'token',
          clientVersion: clientVersion,
          domain: SearchDomain.users,
          query: 'a',
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
      );
      expect(dispatched, isFalse);
    });

    test(
      'a rate-limited search maps onto the retryable feature kind',
      () async {
        final api = DioLoopV2SearchApi(
          _dio(
            (options, handler) => handler.reject(
              _errorResponse(
                options,
                statusCode: 429,
                code: 'RATE_LIMITED',
                category: 'rateLimit',
                userMessageKey: 'errors.rateLimit.exceeded',
                retryable: true,
              ),
            ),
          ),
        );

        try {
          await api.search(
            accessToken: 'token',
            clientVersion: clientVersion,
            domain: SearchDomain.users,
            query: 'pepe',
          );
          fail('the search must not succeed');
        } on LoopBackendFailure catch (failure) {
          expect(failure.code, 'RATE_LIMITED');
          expect(failure.retryable, isTrue);
          expect(
            communityFailureKindForV2(failure, write: false).name,
            'rateLimited',
          );
        }
      },
    );

    test('a member alias prefix is trimmed and sent as q', () async {
      RequestOptions? captured;
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          captured = options;
          handler.resolve(_response(options, memberBody()));
        }),
      );

      await api.listMembers(
        accessToken: 'token',
        clientVersion: clientVersion,
        communityId: communityId,
        role: CommunityMemberFilter.admin,
        q: '  Frog  ',
        cursor: 'Zzz-9_9.Yyy-8_8',
      );

      expect(captured?.queryParameters, <String, Object?>{
        'role': 'admin',
        'q': 'Frog',
        'cursor': 'Zzz-9_9.Yyy-8_8',
      });
      expect(captured?.headers.containsKey('idempotency-key'), isFalse);
    });

    test('an absent or blank member prefix sends no q at all', () async {
      RequestOptions? captured;
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          captured = options;
          handler.resolve(_response(options, memberBody()));
        }),
      );

      for (final query in <String?>[null, '', '   ']) {
        await api.listMembers(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
          role: CommunityMemberFilter.all,
          q: query,
        );
        expect(
          captured?.queryParameters.containsKey('q'),
          isFalse,
          reason: 'q=${query ?? 'null'}',
        );
      }
    });

    test(
      'a member prefix the alias rules reject is never dispatched',
      () async {
        var dispatched = false;
        final api = DioLoopV2CommunityApi(
          _dio((options, handler) {
            dispatched = true;
            handler.resolve(_response(options, memberBody()));
          }),
        );

        for (final query in <String>['fr\u0000og', 'fr\u200bog', 'a' * 257]) {
          await expectLater(
            api.listMembers(
              accessToken: 'token',
              clientVersion: clientVersion,
              communityId: communityId,
              role: CommunityMemberFilter.all,
              q: query,
            ),
            throwsA(
              isA<LoopBackendFailure>().having(
                (failure) => failure.kind,
                'kind',
                LoopBackendFailureKind.invalidRequest,
              ),
            ),
          );
        }
        expect(dispatched, isFalse);
      },
    );

    test('a rate-limited member search keeps its catalogue code', () async {
      final api = DioLoopV2CommunityApi(
        _dio(
          (options, handler) => handler.reject(
            _errorResponse(
              options,
              statusCode: 429,
              code: 'RATE_LIMITED',
              category: 'rateLimit',
              userMessageKey: 'errors.rateLimit.exceeded',
              retryable: true,
            ),
          ),
        ),
      );

      try {
        await api.listMembers(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
          role: CommunityMemberFilter.all,
          q: 'fro',
        );
        fail('the member search must not succeed');
      } on LoopBackendFailure catch (failure) {
        expect(failure.code, 'RATE_LIMITED');
        expect(
          communityFailureKindForV2(failure, write: false).name,
          'rateLimited',
        );
      }
    });

    test('the banned governance view keeps its 403 code', () async {
      final api = DioLoopV2CommunityApi(
        _dio(
          (options, handler) => handler.reject(
            _errorResponse(
              options,
              statusCode: 403,
              code: 'PERMISSION_DENIED',
              category: 'authorization',
              userMessageKey: 'errors.permission.denied',
            ),
          ),
        ),
      );

      try {
        await api.listMembers(
          accessToken: 'token',
          clientVersion: clientVersion,
          communityId: communityId,
          role: CommunityMemberFilter.banned,
        );
        fail('the governance view must not succeed');
      } on LoopBackendFailure catch (failure) {
        expect(failure.code, 'PERMISSION_DENIED');
        expect(
          communityFailureKindForV2(failure, write: false).name,
          'permissionDenied',
        );
      }
    });
  });

  group('community application review (backend decision 0073)', () {
    Map<String, Object?> homeBody({
      Object? ownedRow,
      String verificationStatus = 'pending',
    }) => <String, Object?>{
      'joined': <String, Object?>{'items': <Object?>[], 'truncated': false},
      'owned': <String, Object?>{
        'items': <Object?>[
          ownedRow ??
              <String, Object?>{
                'community': community(verificationStatus: verificationStatus),
                'membership': <String, Object?>{
                  'role': 'owner',
                  'status': 'active',
                  'joinedAt': '2026-09-07T01:00:00.000Z',
                },
                'application': <String, Object?>{
                  'status': verificationStatus,
                  'submittedAt': '2026-09-07T01:00:00.000Z',
                  'reviewedAt': verificationStatus == 'pending'
                      ? null
                      : '2026-09-08T02:00:00.000Z',
                  'rejectedReason': null,
                },
              },
        ],
        'truncated': true,
      },
      'discover': <Object?>[],
      'unread': unavailable('STREAM_UNREAD_NOT_CONNECTED'),
      'liveVoice': unavailable('STREAM_VOICE_NOT_CONNECTED'),
      'freshness': <String, Object?>{
        'observedAt': '2026-09-08T01:00:00.000Z',
        'source': 'database',
      },
      'recommendation': <String, Object?>{
        'recommendationId': otherId,
        'ruleVersion': 'rule:verified-members-v1',
      },
      'contractVersion': '2.0',
    };

    Future<CommunityHome> readHome(Map<String, Object?> body) {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) => handler.resolve(_response(options, body))),
      );
      return api.getHome(accessToken: 'token', clientVersion: clientVersion);
    }

    Future<CommunityDetail> readDetail(Map<String, Object?> body) {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) => handler.resolve(_response(options, body))),
      );
      return api.getCommunity(
        accessToken: 'token',
        clientVersion: clientVersion,
        communityId: communityId,
      );
    }

    test('the home aggregate reads the owned group and its review', () async {
      final home = await readHome(homeBody());

      expect(home.joined, isEmpty);
      expect(home.owned, hasLength(1));
      expect(home.ownedTruncated, isTrue);
      final review = home.owned.single.application!;
      expect(review.status, CommunityVerification.pending);
      expect(review.submittedAt, DateTime.utc(2026, 9, 7, 1));
      expect(review.reviewedAt, isNull);
      expect(review.rejectedReason, isNull);
    });

    test('an aggregate with no owned group at all is refused', () async {
      final body = homeBody()..remove('owned');
      await expectLater(
        readHome(body),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('an owned row with no review block is refused', () async {
      final row = <String, Object?>{
        'community': community(verificationStatus: 'pending'),
        'membership': <String, Object?>{
          'role': 'owner',
          'status': 'active',
          'joinedAt': '2026-09-07T01:00:00.000Z',
        },
      };
      await expectLater(
        readHome(homeBody(ownedRow: row)),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('a row whose two statuses disagree is refused', () async {
      final row = <String, Object?>{
        'community': community(verificationStatus: 'verified'),
        'membership': <String, Object?>{
          'role': 'owner',
          'status': 'active',
          'joinedAt': '2026-09-07T01:00:00.000Z',
        },
        'application': <String, Object?>{
          'status': 'pending',
          'submittedAt': '2026-09-07T01:00:00.000Z',
          'reviewedAt': null,
          'rejectedReason': null,
        },
      };
      await expectLater(
        readHome(homeBody(ownedRow: row)),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('a refusal carries the operator reason to the owner', () async {
      final body = detailBody()
        ..['community'] = community(verificationStatus: 'rejected')
        ..['application'] = <String, Object?>{
          'status': 'rejected',
          'submittedAt': '2026-09-07T01:00:00.000Z',
          'reviewedAt': '2026-09-08T02:00:00.000Z',
          'rejectedReason': '名称与官方社区重复',
        };
      final detail = await readDetail(body);

      final review = detail.application!;
      expect(review.isRejected, isTrue);
      expect(review.reviewedAt, DateTime.utc(2026, 9, 8, 2));
      expect(review.rejectedReason, '名称与官方社区重复');
    });

    test('a null application block is a stranger record', () async {
      final detail = await readDetail(detailBody());
      expect(detail.application, isNull);
    });

    test('a record that omits the application key is refused', () async {
      final body = detailBody()..remove('application');
      await expectLater(
        readDetail(body),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('a pending review that carries a verdict is refused', () async {
      final body = detailBody()
        ..['application'] = <String, Object?>{
          'status': 'pending',
          'submittedAt': '2026-09-07T01:00:00.000Z',
          'reviewedAt': '2026-09-08T02:00:00.000Z',
          'rejectedReason': null,
        };
      await expectLater(
        readDetail(body),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('a verified review that carries a reason is refused', () async {
      final body = detailBody()
        ..['application'] = <String, Object?>{
          'status': 'verified',
          'submittedAt': '2026-09-07T01:00:00.000Z',
          'reviewedAt': '2026-09-08T02:00:00.000Z',
          'rejectedReason': '名称与官方社区重复',
        };
      await expectLater(
        readDetail(body),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('a refusal with no review time is refused', () async {
      final body = detailBody()
        ..['application'] = <String, Object?>{
          'status': 'rejected',
          'submittedAt': '2026-09-07T01:00:00.000Z',
          'reviewedAt': null,
          'rejectedReason': '名称与官方社区重复',
        };
      await expectLater(
        readDetail(body),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('a reason past the server bound is refused', () async {
      final body = detailBody()
        ..['application'] = <String, Object?>{
          'status': 'rejected',
          'submittedAt': '2026-09-07T01:00:00.000Z',
          'reviewedAt': '2026-09-08T02:00:00.000Z',
          'rejectedReason': '名' * 281,
        };
      await expectLater(
        readDetail(body),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
    });

    test('resubmit is one body-less write with one key', () async {
      RequestOptions? captured;
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) {
          captured = options;
          handler.resolve(_response(options, detailBody()));
        }),
      );

      await api.resubmitApplication(
        accessToken: 'token',
        clientVersion: clientVersion,
        idempotencyKey: idempotencyKey,
        communityId: communityId,
      );

      expect(captured?.method, 'POST');
      expect(captured?.uri.path, '/v2/communities/$communityId/resubmit');
      expect(captured?.data, isNull);
      expect(_header(captured!, 'idempotency-key'), idempotencyKey);
      expect(_loopHeaders(captured!), <String, Object?>{
        'x-loop-client-version': clientVersion,
        'x-loop-contract-version': '2.0',
      });
    });

    test('resubmit refuses an id that is not a community id', () {
      final api = DioLoopV2CommunityApi(
        _dio((options, handler) => handler.resolve(_response(options, null))),
      );
      // The shape check runs before the request, so it throws rather than
      // returning a rejected future: nothing is ever dispatched.
      expect(
        () => api.resubmitApplication(
          accessToken: 'token',
          clientVersion: clientVersion,
          idempotencyKey: idempotencyKey,
          communityId: 'frog-holders',
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
      );
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
  String cacheControl = 'no-store',
}) {
  return Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': <String>[cacheControl],
      'x-request-id': const <String>[requestId],
    }),
  );
}

DioException _errorResponse(
  RequestOptions options, {
  required int statusCode,
  required String code,
  required String category,
  required String userMessageKey,
  String correlationId = requestId,
  bool retryable = false,
}) {
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: statusCode,
      data: <String, Object?>{
        'code': code,
        'category': category,
        'retryable': retryable,
        'userMessageKey': userMessageKey,
        'correlationId': correlationId,
        'detailsSafe': null,
        'providerReferenceSafe': null,
      },
      headers: Headers.fromMap(<String, List<String>>{
        'cache-control': const <String>['no-store'],
        'x-request-id': const <String>[requestId],
      }),
    ),
  );
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
