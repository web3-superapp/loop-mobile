import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/search/loop_v2_search_api.dart';
import 'package:loop_mobile/integrations/backend/v2/social/loop_v2_social_api.dart';

const requestId = '11111111-1111-4111-8111-111111111111';
const otherId = '22222222-2222-4222-8222-222222222222';
const communityId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const profileId = '9c1f0f2e-5a7b-4c3d-8e9f-0a1b2c3d4e5f';
const idempotencyKey = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const clientVersion = '0.1.0+1';

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
}) => <String, Object?>{
  'community': community(),
  'viewer': viewer(),
  'miningPower': unavailable('MINING_FORMULA_BASELINE_PENDING'),
  'onlineCount': unavailable('STREAM_PRESENCE_NOT_CONNECTED'),
  'announcements': unavailable('COMMUNITY_ANNOUNCEMENTS_DEFERRED'),
  'officialLinks': unavailable('COMMUNITY_LINKS_DEFERRED'),
  'chat': chat ?? chatSection(),
  'voice': voice ?? voiceSection(),
  'contractVersion': '2.0',
};

Map<String, Object?> memberBody({Object? nextCursor}) => <String, Object?>{
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
      'miningPower': unavailable('MINING_FORMULA_BASELINE_PENDING'),
    },
    <String, Object?>{
      'profile': profile(publicProfileId: null),
      'role': 'member',
      'status': 'active',
      'joinedAt': '2026-09-07T02:00:00.000Z',
      'isSelf': false,
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
                      'role': 'owner',
                      'status': 'active',
                      'joinedAt': '2026-09-07T01:00:00.000Z',
                    },
                  },
                ],
                'truncated': true,
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
          expect(communityFailureKindForV2(failure).name, 'activationRequired');
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
        expect(directory.items.first.isActionable, isTrue);
        expect(directory.items.last.profile.publicProfileId, isNull);
        expect(directory.items.last.isActionable, isFalse);
        expect(
          directory.counts.online.reasonCode,
          'STREAM_PRESENCE_NOT_CONNECTED',
        );
      },
    );

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
                'domain': 'assets',
                'status': 'unavailable',
                'reasonCode': 'ASSET_REGISTRY_DEFERRED',
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
          domain: SearchDomain.assets,
          query: 'pepe',
        );

        expect(page.available, isFalse);
        expect(page.reasonCode, 'ASSET_REGISTRY_DEFERRED');
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
          SearchDestinationKind.communityProfile,
        );
        expect(page.results.single.memberCount, 128);
      },
    );

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
          expect(communityFailureKindForV2(failure).name, 'rateLimited');
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
        expect(communityFailureKindForV2(failure).name, 'rateLimited');
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
        expect(communityFailureKindForV2(failure).name, 'permissionDenied');
      }
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
