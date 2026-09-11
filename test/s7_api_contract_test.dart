import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_s7_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/mining/loop_v2_mining_api.dart';
import 'package:loop_mobile/integrations/backend/v2/referral/loop_v2_referral_api.dart';

const _token = 'access-token';
const _clientVersion = '1.4.0';
const _requestId = '11111111-2222-4333-8444-555555555555';
const _idempotencyKey = '66666666-7777-4888-8999-aaaaaaaaaaaa';
const _launchId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const _projectId = '17f6a9b2-2f22-4c11-9f3a-1a2b3c4d5e6f';
const _roundId = '9c1d6e2a-7c3b-4a55-8d21-0f1e2d3c4b5a';
const _walletId = '4d5e6f70-8a9b-4c1d-8e2f-3a4b5c6d7e8f';
const _communityId = '5b0c9d18-6a44-4f39-b0d2-9e8f7a6b5c4d';

/// A Dio double that replays one canned response and records the request.
final class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.statusCode, required this.body});

  final int statusCode;
  final Object? body;

  RequestOptions? seen;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options;
    return ResponseBody.fromString(
      _encode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>[_requestId],
      },
    );
  }

  static String _encode(Object? value) => jsonEncode(value);
}

Dio _dio(_RecordingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, Object?> _unavailable(String reasonCode) => <String, Object?>{
  'status': 'unavailable',
  'reasonCode': reasonCode,
};

Map<String, Object?> _onChainState() => <String, Object?>{
  'saleState': 'unavailable',
  'entitlementState': 'unavailable',
  'liquidityState': 'unavailable',
  'operationalState': 'unavailable',
  'stateTupleDigest': null,
  'snapshotBlockNumber': null,
  'snapshotBlockHash': null,
  'source': 'unavailable',
  'reasonCode': 'LAUNCH_CONTRACT_BASELINE_PENDING',
};

Map<String, Object?> _summary({String scheduleStatus = 'unscheduled'}) =>
    <String, Object?>{
      'launchId': _launchId,
      'projectId': _projectId,
      'name': 'MoonCat',
      'ticker': 'MCAT',
      'chainId': 'eip155:56',
      'contractAddress': null,
      'configDigest': null,
      'scheduleStatus': scheduleStatus,
      'onChainState': _onChainState(),
      'configVersion': null,
      'createdAt': '2026-09-08T01:00:00.000Z',
    };

Map<String, Object?> _links() => <String, Object?>{
  'website': 'https://mooncat.example',
  'x': null,
  'telegram': null,
  'discord': null,
};

Map<String, Object?> _project({
  String reviewStatus = 'draft',
  Object? version = 1,
}) => <String, Object?>{
  'projectId': _projectId,
  'name': 'MoonCat',
  'ticker': 'MCAT',
  'narrative': null,
  'officialLinks': _links(),
  'materialVersion': 1,
  'reviewStatus': reviewStatus,
  'reviewReasonCode': null,
  'reviewReasonText': null,
  'kyb': <String, Object?>{
    'status': 'unavailable',
    'state': 'unavailable',
    'reasonCode': 'KYB_PROVIDER_NOT_SELECTED',
  },
  'attachments': _unavailable('ATTACHMENT_STORAGE_NOT_SELECTED'),
  'submittedAt': null,
  'reviewedAt': null,
  'launchId': null,
  'version': version,
  'createdAt': '2026-09-08T01:00:00.000Z',
  'updatedAt': '2026-09-08T02:00:00.000Z',
  'configVersion': 'launchCatalogV1',
};

Map<String, Object?> _pendingSlot() =>
    _unavailable('LAUNCH_CONFIG_PENDING_CONFIRMATION');

Map<String, Object?> _launchDetailBody() => <String, Object?>{
  'launch': _summary(),
  'project': <String, Object?>{
    'projectId': _projectId,
    'name': 'MoonCat',
    'ticker': 'MCAT',
    'narrative': null,
    'officialLinks': _links(),
    'materialVersion': 2,
  },
  'config': <String, Object?>{
    'configVersion': 'launchMoonCatV1',
    'status': 'pending_confirmation',
    'effectiveAt': null,
    'slots': <String, Object?>{
      'walletRoundCap': _pendingSlot(),
      'walletProjectCap': _pendingSlot(),
      'feeBps': _pendingSlot(),
      'softCap': _pendingSlot(),
      'hardCap': _pendingSlot(),
      'tge': _pendingSlot(),
      'vesting': _pendingSlot(),
      'tierModeV1': _pendingSlot(),
    },
  },
  'configPending': _unavailable('LAUNCH_CONFIG_PENDING_CONFIRMATION'),
  'rounds': <Object?>[
    <String, Object?>{
      'roundId': _roundId,
      'roundIndex': 1,
      'configVersion': 'launchMoonCatV1',
      'status': 'pending_confirmation',
      'startsAt': null,
      'endsAt': null,
      'priceUsd1': null,
      'eligibilityTier': null,
      'walletRoundCapRaw': null,
    },
  ],
  'graduation': <String, Object?>{
    'steps': <Object?>[
      <String, Object?>{'step': 'stop_internal_trading', 'status': 'pending'},
      <String, Object?>{'step': 'prepare_pool', 'status': 'pending'},
      <String, Object?>{'step': 'add_and_lock_liquidity', 'status': 'pending'},
      <String, Object?>{'step': 'open_external_trading', 'status': 'pending'},
    ],
    'poolEvidence': _unavailable('LAUNCH_POOL_EVIDENCE_UNAVAILABLE'),
  },
  'market': _unavailable('LAUNCH_CONTRACT_BASELINE_PENDING'),
  'holders': _unavailable('LAUNCH_CONTRACT_BASELINE_PENDING'),
  'contractVersion': '2.0',
};

Map<String, Object?> _milestone({
  required String venue,
  required String marketType,
  String state = 'PREPARING',
  Object? venueMilestoneId,
  int version = 0,
  Object? updatedAt,
  Object? digest,
  Object? recordedAt,
  Object? observedAt,
  Object? reviewer,
}) => <String, Object?>{
  'venueMilestoneId': venueMilestoneId,
  'venue': venue,
  'marketType': marketType,
  'state': state,
  'evidence': <String, Object?>{
    'digest': digest,
    'recordedAt': recordedAt,
    'observedAt': observedAt,
    'reviewer': reviewer,
  },
  'version': version,
  'updatedAt': updatedAt,
};

/// The five tracks 03 §8.4 fixes; the server always returns all of them.
List<Object?> _allTracks({Map<String, Object?>? override}) {
  const tracks = <(String, String)>[
    ('lbank', 'spot'),
    ('binance', 'alpha'),
    ('binance', 'perpetual'),
    ('binance', 'spot'),
    ('bithumb', 'spot'),
  ];
  return <Object?>[
    for (final (venue, marketType) in tracks)
      if (override != null &&
          override['venue'] == venue &&
          override['marketType'] == marketType)
        override
      else
        _milestone(venue: venue, marketType: marketType),
  ];
}

Map<String, Object?> _milestonesBody(List<Object?> items) => <String, Object?>{
  'projectId': _projectId,
  'items': items,
  'contractVersion': '2.0',
};

Map<String, Object?> _errorBody(String code, String category) =>
    <String, Object?>{
      'code': code,
      'category': category,
      'retryable': false,
      'userMessageKey': 'errors.v2.refused',
      'correlationId': _requestId,
      'detailsSafe': null,
      'providerReferenceSafe': null,
    };

void main() {
  group('capability ids', () {
    test('the enum mirrors the frozen contract set and order', () {
      expect(LoopV2CapabilityId.values, hasLength(31));
      // The three S7 ids sit between `sendApprovals` and `priceAlerts`.
      final names = LoopV2CapabilityId.values
          .map((id) => id.wireName)
          .toList(growable: false);
      expect(
        names.sublist(names.indexOf('launch'), names.indexOf('launch') + 3),
        <String>['launch', 'mining', 'referral'],
      );
      expect(names.contains('security'), isTrue);
      expect(names.contains('settings'), isTrue);
      expect(names.contains('support'), isTrue);
    });
  });

  group('launch transport', () {
    test('the overview keeps awaitingSchedule as its own segment', () async {
      final adapter = _RecordingAdapter(
        statusCode: 200,
        body: <String, Object?>{
          'segments': <String, Object?>{
            'live': <Object?>[],
            'upcoming': <Object?>[],
            'awaitingSchedule': <Object?>[_summary()],
            'ended': <Object?>[],
          },
          'graduated': _unavailable('LAUNCH_CONTRACT_BASELINE_PENDING'),
          'myEligibility': _unavailable('TIER_MODE_PENDING'),
          'staking': _unavailable('STAKING_CONTRACT_PENDING'),
          'catalog': <String, Object?>{
            'configVersion': 'launchCatalogV1',
            'source': 'loop_db',
            'observedAt': '2026-09-09T06:30:00.000Z',
          },
          'contractVersion': '2.0',
        },
      );
      final overview = await DioLoopV2LaunchApi(_dio(adapter))
          .getOverview(accessToken: _token, clientVersion: _clientVersion);

      expect(overview.segments.awaitingSchedule, hasLength(1));
      expect(overview.segments.upcoming, isEmpty);
      expect(overview.segments.awaitingSchedule.single.contractAddress, isNull);
      // A read never carries an idempotency key.
      expect(adapter.seen!.headers.containsKey('idempotency-key'), isFalse);
      expect(adapter.seen!.path, '/v2/launch/overview');
    });

    test('an unknown field is an invalid payload, not a partial view', () {
      final body = <String, Object?>{
        'segments': <String, Object?>{
          'live': <Object?>[],
          'upcoming': <Object?>[],
          'awaitingSchedule': <Object?>[],
          'ended': <Object?>[],
        },
        'graduated': _unavailable('LAUNCH_CONTRACT_BASELINE_PENDING'),
        'myEligibility': _unavailable('TIER_MODE_PENDING'),
        'staking': _unavailable('STAKING_CONTRACT_PENDING'),
        'catalog': <String, Object?>{
          'configVersion': 'launchCatalogV1',
          'source': 'loop_db',
          'observedAt': '2026-09-09T06:30:00.000Z',
        },
        'contractVersion': '2.0',
        'extra': 1,
      };
      final api = DioLoopV2LaunchApi(
        _dio(_RecordingAdapter(statusCode: 200, body: body)),
      );

      expect(
        () =>
            api.getOverview(accessToken: _token, clientVersion: _clientVersion),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.kind,
            'kind',
            LoopBackendFailureKind.invalidPayload,
          ),
        ),
      );
    });

    test('a contract address would break the step-7 contract', () {
      final summary = _summary()..['contractAddress'] = '0x${'a' * 40}';
      final body = _launchDetailBody()..['launch'] = summary;
      final api = DioLoopV2LaunchApi(
        _dio(_RecordingAdapter(statusCode: 200, body: body)),
      );

      expect(
        () => api.getLaunch(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the detail keeps every slot and round pending', () async {
      final detail =
          await DioLoopV2LaunchApi(
            _dio(_RecordingAdapter(statusCode: 200, body: _launchDetailBody())),
          ).getLaunch(
            accessToken: _token,
            clientVersion: _clientVersion,
            launchId: _launchId,
          );

      expect(
        detail.config!.slots.walletRoundCap,
        isA<LaunchConfigSlotPending>(),
      );
      expect(detail.rounds.single.priceUsd1, isNull);
      expect(detail.rounds.single.isConfirmed, isFalse);
      expect(detail.graduation.steps, hasLength(4));
      expect(detail.hasConfirmedConfig, isFalse);
    });

    test('a missing graduation step is refused', () {
      final body = _launchDetailBody();
      final graduation = body['graduation']! as Map<String, Object?>;
      graduation['steps'] = (graduation['steps']! as List<Object?>)
          .take(3)
          .toList();
      final api = DioLoopV2LaunchApi(
        _dio(_RecordingAdapter(statusCode: 200, body: body)),
      );

      expect(
        () => api.getLaunch(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a non-empty history collection is refused', () {
      final api = DioLoopV2LaunchApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: <String, Object?>{
              'launchId': _launchId,
              'purchaseRecords': <Object?>[<String, Object?>{}],
              'entitlements': <Object?>[],
              'refunds': <Object?>[],
              'source': _unavailable('LAUNCH_CONTRACT_BASELINE_PENDING'),
              'contractVersion': '2.0',
            },
          ),
        ),
      );

      expect(
        () => api.getHistory(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the stake read is pinned to non-executable', () async {
      final stake = await DioLoopV2LaunchApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: <String, Object?>{
              'stake': _unavailable('STAKING_CONTRACT_PENDING'),
              'executable': false,
              'contractVersion': '2.0',
            },
          ),
        ),
      ).getStake(accessToken: _token, clientVersion: _clientVersion);

      expect(stake.executable, isFalse);
    });

    test('an executable stake response is refused', () {
      final api = DioLoopV2LaunchApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: <String, Object?>{
              'stake': _unavailable('STAKING_CONTRACT_PENDING'),
              'executable': true,
              'contractVersion': '2.0',
            },
          ),
        ),
      );

      expect(
        () => api.getStake(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('eligibility never depends on staking and has no tier', () async {
      final eligibility =
          await DioLoopV2LaunchApi(
            _dio(
              _RecordingAdapter(
                statusCode: 200,
                body: <String, Object?>{
                  'launchId': _launchId,
                  'mode': 'unavailable',
                  'result': <String, Object?>{
                    'tier': null,
                    'reasonCode': 'TIER_MODE_PENDING',
                    'snapshotBlock': null,
                  },
                  'configVersion': null,
                  'effectiveAt': null,
                  'dependsOnStaking': false,
                  'contractVersion': '2.0',
                },
              ),
            ),
          ).getEligibility(
            accessToken: _token,
            clientVersion: _clientVersion,
            launchId: _launchId,
          );

      expect(eligibility.dependsOnStaking, isFalse);
      expect(eligibility.tier, isNull);
      expect(eligibility.mode, LaunchEligibilityMode.unavailable);
    });

    test(
      'a create carries exactly one idempotency key and a JSON body',
      () async {
        final adapter = _RecordingAdapter(
          statusCode: 201,
          body: <String, Object?>{
            'project': _project(),
            'contractVersion': '2.0',
          },
        );
        await DioLoopV2LaunchApi(_dio(adapter)).createProject(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _idempotencyKey,
          draft: const LaunchProjectDraft(
            name: 'MoonCat',
            ticker: 'MCAT',
            narrative: null,
            officialLinks: LaunchOfficialLinks(),
          ),
        );

        expect(adapter.seen!.headers['idempotency-key'], _idempotencyKey);
        expect(adapter.seen!.method, 'POST');
        final body = adapter.seen!.data! as Map<String, Object?>;
        expect(body.keys, <String>{
          'name',
          'ticker',
          'narrative',
          'officialLinks',
        });
      },
    );

    test('the CAS edit sends no idempotency key', () async {
      final adapter = _RecordingAdapter(
        statusCode: 200,
        body: <String, Object?>{
          'project': _project(version: 2),
          'contractVersion': '2.0',
        },
      );
      await DioLoopV2LaunchApi(_dio(adapter)).putProject(
        accessToken: _token,
        clientVersion: _clientVersion,
        projectId: _projectId,
        expectedVersion: 1,
        draft: const LaunchProjectDraft(
          name: 'MoonCat',
          ticker: 'MCAT',
          narrative: null,
          officialLinks: LaunchOfficialLinks(),
        ),
      );

      expect(adapter.seen!.headers.containsKey('idempotency-key'), isFalse);
      expect(adapter.seen!.method, 'PUT');
      expect(
        (adapter.seen!.data! as Map<String, Object?>)['expectedVersion'],
        1,
      );
    });

    test('a non-owner projection keeps the review trail null', () async {
      final project =
          await DioLoopV2LaunchApi(
            _dio(
              _RecordingAdapter(
                statusCode: 200,
                body: <String, Object?>{
                  'project': _project(reviewStatus: 'approved', version: null),
                  'contractVersion': '2.0',
                },
              ),
            ),
          ).getProject(
            accessToken: _token,
            clientVersion: _clientVersion,
            projectId: _projectId,
          );

      expect(project.version, isNull);
      expect(project.isOwnerProjection, isFalse);
      expect(project.canEdit, isFalse);
    });

    test(
      'the review reason arrives as a code and as its own sentence',
      () async {
        const sentence = '官方链接无法访问或核对，换成可访问的链接后可以重新提交。';
        final body = _project(reviewStatus: 'returned')
          ..['reviewReasonCode'] = 'official_links_unreachable'
          ..['reviewReasonText'] = sentence;
        final project =
            await DioLoopV2LaunchApi(
              _dio(
                _RecordingAdapter(
                  statusCode: 200,
                  body: <String, Object?>{
                    'project': body,
                    'contractVersion': '2.0',
                  },
                ),
              ),
            ).getProject(
              accessToken: _token,
              clientVersion: _clientVersion,
              projectId: _projectId,
            );

        // The client keeps the code for non-display use and takes the sentence
        // exactly as the server wrote it; it never derives one from the other.
        expect(project.reviewReasonCode, 'official_links_unreachable');
        expect(project.reviewReasonText, sentence);
      },
    );

    test('a review reason missing half of its pair is a broken payload', () {
      final codeOnly = _project(reviewStatus: 'returned')
        ..['reviewReasonCode'] = 'ticker_conflict';
      final textOnly = _project(reviewStatus: 'returned')
        ..['reviewReasonText'] = '这个代币符号已被占用，换一个后可以重新提交。';
      // The field itself is part of the contract: an older server that never
      // sends it is refused rather than silently read as "no reason".
      final absent = _project()..remove('reviewReasonText');

      for (final broken in <Map<String, Object?>>[codeOnly, textOnly, absent]) {
        final api = DioLoopV2LaunchApi(
          _dio(
            _RecordingAdapter(
              statusCode: 200,
              body: <String, Object?>{
                'project': broken,
                'contractVersion': '2.0',
              },
            ),
          ),
        );

        expect(
          () => api.getProject(
            accessToken: _token,
            clientVersion: _clientVersion,
            projectId: _projectId,
          ),
          throwsA(
            isA<LoopBackendFailure>().having(
              (failure) => failure.kind,
              'kind',
              LoopBackendFailureKind.invalidPayload,
            ),
          ),
        );
      }
    });

    test('the purchase intent always surfaces the server 503', () {
      final api = DioLoopV2LaunchApi(
        _dio(
          _RecordingAdapter(
            statusCode: 503,
            body: _errorBody('CAPABILITY_UNAVAILABLE', 'availability'),
          ),
        ),
      );

      expect(
        () => api.postPurchaseIntent(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _idempotencyKey,
          launchId: _launchId,
          walletId: _walletId,
          roundId: _roundId,
          payAmount: '500',
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.code,
            'code',
            'CAPABILITY_UNAVAILABLE',
          ),
        ),
      );
    });

    test('the pay amount is a string; a malformed one never leaves', () {
      final api = DioLoopV2LaunchApi(
        _dio(_RecordingAdapter(statusCode: 503, body: <String, Object?>{})),
      );

      expect(
        () => api.postPurchaseIntent(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _idempotencyKey,
          launchId: _launchId,
          walletId: _walletId,
          roundId: _roundId,
          payAmount: '5,00',
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.kind,
            'kind',
            LoopBackendFailureKind.invalidRequest,
          ),
        ),
      );
    });

    test('an implicit PREPARING row carries no id, version or time', () async {
      final milestones =
          await DioLoopV2LaunchApi(
            _dio(
              _RecordingAdapter(
                statusCode: 200,
                body: _milestonesBody(_allTracks()),
              ),
            ),
          ).getMilestones(
            accessToken: _token,
            clientVersion: _clientVersion,
            projectId: _projectId,
          );

      expect(milestones.items, hasLength(5));
      expect(milestones.items.every((item) => item.isImplicit), isTrue);
      final first = milestones.items.first;
      expect(first.venueMilestoneId, isNull);
      expect(first.version, 0);
      expect(first.updatedAt, isNull);
      expect(first.state, LaunchMilestoneState.preparing);
      expect(first.state.carriesEvidence, isFalse);
    });

    test('a stored row keeps recordedAt and observedAt apart', () async {
      final milestones =
          await DioLoopV2LaunchApi(
            _dio(
              _RecordingAdapter(
                statusCode: 200,
                body: _milestonesBody(
                  _allTracks(
                    override: _milestone(
                      venue: 'binance',
                      marketType: 'alpha',
                      state: 'FEATURED',
                      venueMilestoneId: _walletId,
                      version: 2,
                      updatedAt: '2026-09-05T03:00:00.000Z',
                      digest: 'b' * 64,
                      recordedAt: '2026-09-05T03:00:00.000Z',
                      observedAt: '2026-09-01T00:00:00.000Z',
                      reviewer: 'ops.alice',
                    ),
                  ),
                ),
              ),
            ),
          ).getMilestones(
            accessToken: _token,
            clientVersion: _clientVersion,
            projectId: _projectId,
          );

      final stored = milestones.items.singleWhere((item) => !item.isImplicit);
      expect(stored.state, LaunchMilestoneState.featured);
      expect(stored.state.carriesEvidence, isTrue);
      // Alpha is its own track and never implies the spot one.
      expect(stored.marketType, LaunchMarketType.alpha);
      expect(stored.trackKey, 'binance/alpha');
      // Two different facts; neither is derived from the other.
      expect(stored.evidence.recordedAt, isNot(stored.evidence.observedAt));
    });

    test('a stored row without a version or an update time is refused', () {
      for (final broken in <Map<String, Object?>>[
        _milestone(
          venue: 'lbank',
          marketType: 'spot',
          state: 'APPLIED',
          venueMilestoneId: _walletId,
          updatedAt: '2026-09-05T03:00:00.000Z',
        ),
        _milestone(
          venue: 'lbank',
          marketType: 'spot',
          state: 'APPLIED',
          venueMilestoneId: _walletId,
          version: 1,
        ),
      ]) {
        final api = DioLoopV2LaunchApi(
          _dio(
            _RecordingAdapter(
              statusCode: 200,
              body: _milestonesBody(_allTracks(override: broken)),
            ),
          ),
        );
        expect(
          () => api.getMilestones(
            accessToken: _token,
            clientVersion: _clientVersion,
            projectId: _projectId,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
      }
    });

    test('an implicit row that is not PREPARING is refused', () {
      final api = DioLoopV2LaunchApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _milestonesBody(
              _allTracks(
                override: _milestone(
                  venue: 'lbank',
                  marketType: 'spot',
                  state: 'LISTED',
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        () => api.getMilestones(
          accessToken: _token,
          clientVersion: _clientVersion,
          projectId: _projectId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a missing track is a contract break, not an absent track', () {
      final api = DioLoopV2LaunchApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _milestonesBody(_allTracks().take(4).toList()),
          ),
        ),
      );

      expect(
        () => api.getMilestones(
          accessToken: _token,
          clientVersion: _clientVersion,
          projectId: _projectId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('mining transport', () {
    test(
      'the summary names the pending version and stays unavailable',
      () async {
        final summary = await DioLoopV2MiningApi(
          _dio(
            _RecordingAdapter(
              statusCode: 200,
              body: <String, Object?>{
                'power': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
                'networkPower': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
                'estimatedToday': _unavailable(
                  'MINING_FORMULA_BASELINE_PENDING',
                ),
                'accumulated': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
                'claimable': _unavailable('REWARD_AUTHORITY_PENDING'),
                'referralBoost': _unavailable(
                  'MINING_FORMULA_BASELINE_PENDING',
                ),
                'formula': <String, Object?>{
                  'status': 'unavailable',
                  'reasonCode': 'MINING_FORMULA_BASELINE_PENDING',
                  'pendingVersion': 'miningFormulaV1-draft',
                },
                'snapshot': _unavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
                'contractVersion': '2.0',
              },
            ),
          ),
        ).getSummary(accessToken: _token, clientVersion: _clientVersion);

        expect(summary.formula.pendingVersion, 'miningFormulaV1-draft');
        expect(summary.snapshot, isA<MiningSnapshotUnavailable>());
        expect(summary.claimable.reasonCode, 'REWARD_AUTHORITY_PENDING');
      },
    );

    test('a claimable rewards response is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: <String, Object?>{
              'claimable': _unavailable('REWARD_AUTHORITY_PENDING'),
              'claimExecutable': true,
              'estimatedToday': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
              'accumulated': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
              'ledger': <Object?>[],
              'source': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
              'contractVersion': '2.0',
            },
          ),
        ),
      );

      expect(
        () =>
            api.getRewards(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the rank scope must match what was asked for', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: <String, Object?>{
              'scope': 'communities',
              'ranking': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
              'myPosition': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
              'snapshot': _unavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
              'display': <String, Object?>{
                'anonymousMemberKey': 'mining.rank.anonymousMember',
                'ruleKey': 'mining.rank.display.aliasOrAnonymous',
              },
              'contractVersion': '2.0',
            },
          ),
        ),
      );

      expect(
        () => api.getRank(
          accessToken: _token,
          clientVersion: _clientVersion,
          scope: MiningRankScope.users,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test(
      'a reviewed community weight keeps the server decimal string',
      () async {
        final community =
            await DioLoopV2MiningApi(
              _dio(
                _RecordingAdapter(
                  statusCode: 200,
                  body: <String, Object?>{
                    'community': <String, Object?>{
                      'communityId': _communityId,
                      'name': 'Frog Holders',
                      'boundAssetId': null,
                    },
                    'weight': <String, Object?>{
                      'status': 'approved',
                      'value': '0.35',
                      'configVersion': 'communityWeightV1',
                      'reviewedAt': '2026-09-07T00:00:00.000Z',
                    },
                    'communityPower': _unavailable(
                      'MINING_FORMULA_BASELINE_PENDING',
                    ),
                    'myContribution': _unavailable(
                      'MINING_FORMULA_BASELINE_PENDING',
                    ),
                    'rank': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
                    'participants': _unavailable(
                      'MINING_FORMULA_BASELINE_PENDING',
                    ),
                    'contractVersion': '2.0',
                  },
                ),
              ),
            ).getCommunity(
              accessToken: _token,
              clientVersion: _clientVersion,
              communityId: _communityId,
            );

        expect(
          (community.weight as MiningCommunityWeightApproved).value,
          '0.35',
        );
      },
    );

    test('the rules read requires exactly five referral levels', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: <String, Object?>{
              'approved': null,
              'pendingApproval': <Object?>[],
              'baseline': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
              'referral': <String, Object?>{
                'configVersion': 'referralRulesV1',
                'effectiveAt': '2026-09-01T00:00:00.000Z',
                'levels': <Object?>[
                  <String, Object?>{
                    'level': 1,
                    'boostPercent': '10',
                    'descriptionKey': 'mining.referral.level1',
                  },
                ],
              },
              'contractVersion': '2.0',
            },
          ),
        ),
      );

      expect(
        () => api.getRules(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('referral transport', () {
    Map<String, Object?> referralBody({
      String status = 'unbound',
      Object? inviter,
      Map<String, Object?>? claimWindow,
    }) => <String, Object?>{
      'inviteCode': <String, Object?>{
        'code': 'LOOP-7HJKM',
        'issuedAt': '2026-09-08T00:00:00.000Z',
      },
      'binding': <String, Object?>{
        'status': status,
        'inviter': inviter,
        'claimWindow':
            claimWindow ??
            <String, Object?>{
              'status': 'open',
              'activatedAt': '2026-09-06T00:00:00.000Z',
              'closesAt': '2026-09-13T00:00:00.000Z',
            },
      },
      'levels': <Object?>[
        for (var level = 1; level <= 5; level += 1)
          <String, Object?>{
            'level': level,
            'boostPercent': '1',
            'counts': <String, Object?>{
              'pending_activation': 0,
              'pending_wallet': level == 1 ? 2 : 0,
              'pending_mining': 0,
              'valid': 0,
              'invalidated': 0,
            },
            'total': level == 1 ? 2 : 0,
          },
      ],
      'boost': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
      'rules': <String, Object?>{
        'configVersion': 'referralRulesV1',
        'effectiveAt': '2026-09-01T00:00:00.000Z',
        'appliesTo': 'miningPower',
        'maximumDepth': 5,
        'claimWindowDays': 7,
      },
      'contractVersion': '2.0',
    };

    test('the overview groups counts by validation status', () async {
      final overview = await DioLoopV2ReferralApi(
        _dio(_RecordingAdapter(statusCode: 200, body: referralBody())),
      ).getOverview(accessToken: _token, clientVersion: _clientVersion);

      expect(overview.inviteCode.code, 'LOOP-7HJKM');
      expect(overview.levels, hasLength(5));
      expect(overview.levels.first.counts.pendingWallet, 2);
      expect(overview.validRelationships, 0);
      expect(overview.binding.canClaim, isTrue);
    });

    test('a count total that does not add up is refused', () {
      final body = referralBody();
      final levels = body['levels']! as List<Object?>;
      (levels.first! as Map<String, Object?>)['total'] = 9;
      final api = DioLoopV2ReferralApi(
        _dio(_RecordingAdapter(statusCode: 200, body: body)),
      );

      expect(
        () =>
            api.getOverview(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a bound status without an inviter is refused', () {
      final api = DioLoopV2ReferralApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: referralBody(status: 'bound'),
          ),
        ),
      );

      expect(
        () =>
            api.getOverview(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an unactivated account has an unavailable window', () async {
      final overview = await DioLoopV2ReferralApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: referralBody(
              claimWindow: _unavailable('PROFILE_ACTIVATION_REQUIRED'),
            ),
          ),
        ),
      ).getOverview(accessToken: _token, clientVersion: _clientVersion);

      expect(
        overview.binding.claimWindow,
        isA<ReferralClaimWindowUnavailable>(),
      );
      expect(overview.binding.canClaim, isFalse);
    });

    test('the claim normalises the code and carries one key', () async {
      final adapter = _RecordingAdapter(
        statusCode: 200,
        body: <String, Object?>{
          'binding': <String, Object?>{
            'status': 'bound',
            'inviter': <String, Object?>{
              'depth': 1,
              'validationStatus': 'pending_mining',
              'lockedAt': '2026-09-09T04:00:00.000Z',
              'effectiveFrom': '2026-09-09T04:00:00.000Z',
              'configVersion': 'referralRulesV1',
            },
            'claimWindow': <String, Object?>{
              'status': 'open',
              'activatedAt': '2026-09-06T00:00:00.000Z',
              'closesAt': '2026-09-13T00:00:00.000Z',
            },
          },
          'contractVersion': '2.0',
        },
      );
      final binding = await DioLoopV2ReferralApi(_dio(adapter)).postClaim(
        accessToken: _token,
        clientVersion: _clientVersion,
        idempotencyKey: _idempotencyKey,
        inviteCode: 'loop-7hjkm',
      );

      expect(binding.isBound, isTrue);
      expect(binding.inviter!.depth, 1);
      expect(adapter.seen!.headers['idempotency-key'], _idempotencyKey);
      expect(
        (adapter.seen!.data! as Map<String, Object?>)['inviteCode'],
        'LOOP-7HJKM',
      );
    });

    test('each documented refusal maps to its own feature kind', () {
      final cases = <(int, String, String, LaunchFailureKind)>[
        (
          409,
          'PROFILE_ACTIVATION_REQUIRED',
          'conflict',
          LaunchFailureKind.activationRequired,
        ),
        (
          403,
          'POLICY_BLOCKED',
          'authorization',
          LaunchFailureKind.policyBlocked,
        ),
        (404, 'NOT_FOUND', 'authorization', LaunchFailureKind.notFound),
        (
          422,
          'VALIDATION_FAILED',
          'validation',
          LaunchFailureKind.validationFailed,
        ),
        (409, 'DATA_STALE', 'stale', LaunchFailureKind.stale),
        (
          409,
          'IDEMPOTENCY_CONFLICT',
          'conflict',
          LaunchFailureKind.idempotencyConflict,
        ),
      ];
      for (final (status, code, category, expected) in cases) {
        final api = DioLoopV2ReferralApi(
          _dio(
            _RecordingAdapter(
              statusCode: status,
              body: _errorBody(code, category),
            ),
          ),
        );
        expect(
          () => api.postClaim(
            accessToken: _token,
            clientVersion: _clientVersion,
            idempotencyKey: _idempotencyKey,
            inviteCode: 'LOOP-7HJKM',
          ),
          throwsA(
            isA<LoopBackendFailure>().having(
              (failure) => launchFailureKindForV2(failure),
              'mapped kind for $code',
              expected,
            ),
          ),
        );
      }
    });

    test('a malformed code never becomes a request', () {
      final adapter = _RecordingAdapter(
        statusCode: 200,
        body: <String, Object?>{},
      );
      final api = DioLoopV2ReferralApi(_dio(adapter));

      expect(
        () => api.postClaim(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _idempotencyKey,
          inviteCode: 'nope',
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(adapter.seen, isNull);
    });
  });

  group('codec', () {
    test('a reason code must match the frozen pattern', () {
      expect(
        () => LoopV2S7Codec.unavailable(<String, Object?>{
          'status': 'unavailable',
          'reasonCode': 'lower_case',
        }),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a pinned-null field refuses a value', () {
      expect(
        () => LoopV2S7Codec.requireNull(<String, Object?>{'x': 1}, 'x'),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        LoopV2S7Codec.requireNull(<String, Object?>{'x': null}, 'x'),
        isNull,
      );
    });
  });
}
