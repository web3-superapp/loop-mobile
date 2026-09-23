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
const _otherCommunityId = '439cabe6-4c98-4f99-860f-192ad52403a1';
const _publicProfileId = '8c2b7a15-4d3e-4f60-9a11-2b3c4d5e6f70';
const _otherPublicProfileId = '5f1c2d3e-9a8b-4c7d-8e6f-0a1b2c3d4e5f';

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

/// A default that is not `null`, so a test may pass `null` on purpose.
const Object _absent = Object();

Map<String, Object?> _unavailable(String reasonCode) => <String, Object?>{
  'status': 'unavailable',
  'reasonCode': reasonCode,
};

const _baselineVersion = 'miningFormula-devBaseline-2026-09-15-r2';

/// The boost's own reason code (Decision 0046). The server answers it on
/// `summary.referralBoost` and on `referral.boost` whether or not a formula
/// version is in effect.
const _referralBoostPending = 'MINING_REFERRAL_BOOST_PENDING';

/// The `formula` block the summary, the composition page and the ranking all
/// publish, from the same source.
Map<String, Object?> _effectiveFormula() => <String, Object?>{
  'status': 'approved',
  'configVersion': _baselineVersion,
  'effectiveAt': '2026-09-15T14:57:37.026Z',
  'scope': 'development_baseline',
};

Map<String, Object?> _pendingFormula() => <String, Object?>{
  'status': 'unavailable',
  'reasonCode': 'MINING_FORMULA_BASELINE_PENDING',
  'pendingVersion': 'miningFormulaV1-draft',
};

/// The Development snapshot of 2026-09-15, field for field.
Map<String, Object?> _miningSnapshot() => <String, Object?>{
  'snapshotId': '0e358b31-e49f-48b9-89b2-c5c908c3ad5e',
  'blockNumber': '122037728',
  'blockHash':
      '0x3decab82b150493d90cb8fe47b3873c6e3b8c72aecf08ce91b4aceb266bda28a',
  'formulaVersion': _baselineVersion,
  'priceVersion': 'dexscreener:2026-09-15T14:58:51.862Z',
  'computedAt': '2026-09-15T14:58:54.366Z',
};

const _cakeAssetId = 'eip155:56:0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82';
const _usdtAssetId = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';
const _wbnbAssetId = 'eip155:56:0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c';
const _nativeAssetId = 'eip155:56:native';
const _priceVersion = 'dexscreener:2026-09-15T14:58:51.862Z';

/// One `included[]` row, field for field as the Development lane answers.
Map<String, Object?> _assetRow({
  String assetId = _cakeAssetId,
  Object? symbol = 'Cake',
  String holding = '0',
  String referencePriceUsd = '2.26',
  String quality = 'fresh',
  Object? proxyAssetId,
  String weight = '0.8',
  String power = '0',
}) => <String, Object?>{
  'assetId': assetId,
  'symbol': symbol,
  'logo': <String, Object?>{
    'status': 'available',
    'url':
        'https://raw.githubusercontent.com/trustwallet/assets/master/'
        'blockchains/smartchain/assets/'
        '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82/logo.png',
    'source': 'trustwallet',
    'observedAt': null,
  },
  'holding': holding,
  'referencePriceUsd': referencePriceUsd,
  'referencePriceQuality': quality,
  'referencePriceProxyAssetId': proxyAssetId,
  'weight': weight,
  'power': power,
  'blockNumber': '122037728',
};

/// The 2026-09-15 Development response for `GET /v2/mining/assets`.
Map<String, Object?> _miningAssets({
  List<Object?>? included,
  List<Object?>? excluded,
  Object? source,
  Object? totalPower,
  Object? referencePrice,
  Object? formula,
}) => <String, Object?>{
  'totalPower':
      totalPower ?? <String, Object?>{'status': 'available', 'value': '0'},
  'included':
      included ??
      <Object?>[
        _assetRow(),
        _assetRow(
          assetId: _usdtAssetId,
          symbol: 'USDT',
          referencePriceUsd: '0.9994',
          weight: '1.5',
        ),
        _assetRow(
          assetId: _wbnbAssetId,
          symbol: 'WBNB',
          referencePriceUsd: '713.42',
          weight: '1',
        ),
        _assetRow(
          assetId: _nativeAssetId,
          symbol: 'BNB',
          referencePriceUsd: '713.42',
          quality: 'proxied',
          proxyAssetId: _wbnbAssetId,
          weight: '1',
        ),
      ],
  'excluded': excluded ?? <Object?>[],
  'source': source ?? _miningSnapshot(),
  'referencePrice':
      referencePrice ??
      <String, Object?>{'status': 'available', 'priceVersion': _priceVersion},
  'formula': formula ?? _effectiveFormula(),
  'contractVersion': '2.0',
};

Map<String, Object?> _rankDisplay() => <String, Object?>{
  'anonymousMemberKey': 'mining.rank.anonymousMember',
  'ruleKey': 'mining.rank.display.anonymousModeOnly',
  'powerRuleKey': 'mining.rank.power.ownerVisibility',
};

Map<String, Object?> _aliasRow({
  Object? position = 1,
  Object? power = '3000',
  bool isSelf = false,
  String profileId = _publicProfileId,
  String audience = 'everyone',
  String powerVisibility = 'everyone',
}) => <String, Object?>{
  'position': position,
  'power': power,
  'powerVisibility': powerVisibility,
  'display': <String, Object?>{
    'kind': 'alias',
    'alias': 'whale',
    'publicProfileId': profileId,
    'audience': audience,
  },
  'isSelf': isSelf,
};

Map<String, Object?> _anonymousRow({
  Object? position = 2,
  Object? power = '1000',
  bool isSelf = false,
  String powerVisibility = 'everyone',
}) => <String, Object?>{
  'position': position,
  'power': power,
  'powerVisibility': powerVisibility,
  'display': <String, Object?>{
    'kind': 'anonymous',
    'labelKey': 'mining.rank.anonymousMember',
  },
  'isSelf': isSelf,
};

Map<String, Object?> _communityRankRow({
  Object? position,
  String power = '0',
  String communityId = _otherCommunityId,
  String weight = '1.5',
  int participants = 0,
}) => <String, Object?>{
  'position': position,
  'power': power,
  'community': <String, Object?>{
    'communityId': communityId,
    'name': 'Builders Guild',
    'boundAssetId': _usdtAssetId,
  },
  'weight': weight,
  'participants': participants,
};

Map<String, Object?> _miningRank({
  String scope = 'users',
  Object? ranking,
  Object? myPosition,
  Object? snapshot,
  Object? formula,
}) => <String, Object?>{
  'scope': scope,
  'ranking': ranking,
  'myPosition': myPosition ?? _unavailable('MINING_RANK_NOT_RANKED'),
  'snapshot': snapshot ?? _miningSnapshot(),
  'display': _rankDisplay(),
  'formula': formula ?? _effectiveFormula(),
  'contractVersion': '2.0',
};

Map<String, Object?> _board({
  String scope = 'users',
  List<Object?>? items,
  int participants = 2,
}) => <String, Object?>{
  'status': 'available',
  'scope': scope,
  'items': items ?? <Object?>[_aliasRow(), _anonymousRow()],
  'participants': participants,
};

/// The 2026-09-15 Development response for one community's mining panel.
Map<String, Object?> _miningCommunity({
  Object? weight,
  Object? communityPower,
  Object? myContribution,
  Object? rank,
  Object? participants,
  Object? snapshot,
  Object? boundAssetId = _cakeAssetId,
}) => <String, Object?>{
  'community': <String, Object?>{
    'communityId': _communityId,
    'name': 'DeFi 早读会',
    'boundAssetId': boundAssetId,
  },
  'weight':
      weight ??
      <String, Object?>{
        'status': 'approved',
        'value': '0.8',
        'configVersion': _baselineVersion,
        'reviewedAt': '2026-09-15T14:58:52.089Z',
      },
  'communityPower':
      communityPower ?? <String, Object?>{'status': 'available', 'value': '0'},
  'myContribution':
      myContribution ?? <String, Object?>{'status': 'available', 'value': '0'},
  'rank': rank ?? _unavailable('MINING_RANK_NOT_RANKED'),
  'participants':
      participants ?? <String, Object?>{'status': 'available', 'count': 0},
  'snapshot': snapshot ?? _miningSnapshot(),
  'contractVersion': '2.0',
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
            'source': 'loop',
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
          'source': 'loop',
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
                'referralBoost': _unavailable(_referralBoostPending),
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

        expect(
          (summary.formula as MiningFormulaPending).pendingVersion,
          'miningFormulaV1-draft',
        );
        expect(summary.snapshot, isA<MiningSnapshotUnavailable>());
        expect(summary.claimable.reasonCode, 'REWARD_AUTHORITY_PENDING');
        expect(summary.referralBoost.reasonCode, _referralBoostPending);
      },
    );

    test(
      'the summary carries the baseline figures, budget and version',
      () async {
        final summary = await DioLoopV2MiningApi(
          _dio(
            _RecordingAdapter(
              statusCode: 200,
              body: <String, Object?>{
                'power': <String, Object?>{
                  'status': 'available',
                  'value': '1000',
                },
                'networkPower': <String, Object?>{
                  'status': 'available',
                  'value': '4000',
                },
                'estimatedToday': <String, Object?>{
                  'status': 'available',
                  'value': '250000',
                  'budget': '1000000',
                  'unitKey': 'mining.rules.dailyOutput.unit.loopTokenPending',
                  'budgetStatus': 'development_placeholder',
                  'formulaVersion': _baselineVersion,
                  'scope': 'development_baseline',
                },
                'accumulated': _unavailable('REWARD_AUTHORITY_PENDING'),
                'claimable': _unavailable('REWARD_AUTHORITY_PENDING'),
                'referralBoost': _unavailable(_referralBoostPending),
                'formula': <String, Object?>{
                  'status': 'approved',
                  'configVersion': _baselineVersion,
                  'effectiveAt': '2026-09-15T14:57:37.026Z',
                  'scope': 'development_baseline',
                },
                'snapshot': _miningSnapshot(),
                'contractVersion': '2.0',
              },
            ),
          ),
        ).getSummary(accessToken: _token, clientVersion: _clientVersion);

        expect((summary.power as MiningFigureValue).value, '1000');
        expect((summary.networkPower as MiningFigureValue).value, '4000');
        final output = summary.estimatedToday as MiningDailyOutputEstimate;
        expect(output.value, '250000');
        expect(output.budget, '1000000');
        expect(output.budgetStatus, 'development_placeholder');
        expect(output.isPlaceholderBudget, isTrue);
        expect(output.formulaVersion, _baselineVersion);
        expect(output.scope, MiningFormulaScope.developmentBaseline);
        final formula = summary.formula as MiningFormulaEffective;
        expect(formula.configVersion, _baselineVersion);
        expect(formula.effectiveAt, DateTime.utc(2026, 9, 15, 14, 57, 37, 26));
        expect(formula.scope.isBaseline, isTrue);
        final snapshot = summary.snapshot as MiningSnapshotComputed;
        expect(snapshot.blockNumber, '122037728');
        expect(snapshot.formulaVersion, _baselineVersion);
      },
    );

    test('a zero power under an effective version stays a figure', () async {
      final summary = await DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: <String, Object?>{
              'power': <String, Object?>{'status': 'available', 'value': '0'},
              'networkPower': <String, Object?>{
                'status': 'available',
                'value': '0',
              },
              'estimatedToday': _unavailable('MINING_NETWORK_POWER_ZERO'),
              'accumulated': _unavailable('REWARD_AUTHORITY_PENDING'),
              'claimable': _unavailable('REWARD_AUTHORITY_PENDING'),
              'referralBoost': _unavailable(_referralBoostPending),
              'formula': <String, Object?>{
                'status': 'approved',
                'configVersion': _baselineVersion,
                'effectiveAt': '2026-09-15T14:57:37.026Z',
                'scope': 'development_baseline',
              },
              'snapshot': _miningSnapshot(),
              'contractVersion': '2.0',
            },
          ),
        ),
      ).getSummary(accessToken: _token, clientVersion: _clientVersion);

      expect((summary.power as MiningFigureValue).value, '0');
      expect(
        (summary.estimatedToday as MiningDailyOutputUnavailable).reasonCode,
        'MINING_NETWORK_POWER_ZERO',
      );
    });

    test('a daily output without its budget is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: <String, Object?>{
              'power': <String, Object?>{'status': 'available', 'value': '10'},
              'networkPower': <String, Object?>{
                'status': 'available',
                'value': '10',
              },
              // No budget, unitKey, budgetStatus, formulaVersion or scope: the
              // number would reach the screen with nothing qualifying it.
              'estimatedToday': <String, Object?>{
                'status': 'available',
                'value': '1000',
              },
              'accumulated': _unavailable('REWARD_AUTHORITY_PENDING'),
              'claimable': _unavailable('REWARD_AUTHORITY_PENDING'),
              'referralBoost': _unavailable(_referralBoostPending),
              'formula': <String, Object?>{
                'status': 'approved',
                'configVersion': _baselineVersion,
                'effectiveAt': '2026-09-15T14:57:37.026Z',
                'scope': 'development_baseline',
              },
              'snapshot': _miningSnapshot(),
              'contractVersion': '2.0',
            },
          ),
        ),
      );

      expect(
        () =>
            api.getSummary(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an unknown formula scope is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: <String, Object?>{
              'power': <String, Object?>{'status': 'available', 'value': '0'},
              'networkPower': <String, Object?>{
                'status': 'available',
                'value': '0',
              },
              'estimatedToday': _unavailable('MINING_NETWORK_POWER_ZERO'),
              'accumulated': _unavailable('REWARD_AUTHORITY_PENDING'),
              'claimable': _unavailable('REWARD_AUTHORITY_PENDING'),
              'referralBoost': _unavailable(_referralBoostPending),
              'formula': <String, Object?>{
                'status': 'approved',
                'configVersion': _baselineVersion,
                'effectiveAt': '2026-09-15T14:57:37.026Z',
                'scope': 'staging_baseline',
              },
              'snapshot': _miningSnapshot(),
              'contractVersion': '2.0',
            },
          ),
        ),
      );

      expect(
        () =>
            api.getSummary(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a power figure carrying a negative value is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: <String, Object?>{
              'power': <String, Object?>{'status': 'available', 'value': '-1'},
              'networkPower': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
              'estimatedToday': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
              'accumulated': _unavailable('REWARD_AUTHORITY_PENDING'),
              'claimable': _unavailable('REWARD_AUTHORITY_PENDING'),
              'referralBoost': _unavailable(_referralBoostPending),
              'formula': <String, Object?>{
                'status': 'unavailable',
                'reasonCode': 'MINING_FORMULA_BASELINE_PENDING',
                'pendingVersion': null,
              },
              'snapshot': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
              'contractVersion': '2.0',
            },
          ),
        ),
      );

      expect(
        () =>
            api.getSummary(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the weighted rows carry their inputs and their proxy', () async {
      final assets = await DioLoopV2MiningApi(
        _dio(_RecordingAdapter(statusCode: 200, body: _miningAssets())),
      ).getAssets(accessToken: _token, clientVersion: _clientVersion);

      expect((assets.totalPower as MiningFigureValue).value, '0');
      expect(assets.included, hasLength(4));
      final cake = assets.included.first;
      expect(cake.assetId, _cakeAssetId);
      expect(cake.symbol, 'Cake');
      expect(cake.referencePriceUsd, '2.26');
      expect(cake.weight, '0.8');
      expect(cake.isProxiedPrice, isFalse);
      expect(cake.referencePriceProxyAssetId, isNull);
      expect(cake.blockNumber, '122037728');
      // The chain's own coin has no pair of its own, so its price is the
      // declared proxy's and the row says which asset that is.
      final native = assets.included.last;
      expect(native.assetId, _nativeAssetId);
      // The chain's own coin is named BNB by the registry, not derived from
      // the `native` slot in its id.
      expect(native.symbol, 'BNB');
      expect(native.isProxiedPrice, isTrue);
      expect(native.referencePriceProxyAssetId, _wbnbAssetId);
      expect(native.referencePriceUsd, '713.42');
      expect(assets.excluded, isEmpty);
      expect(assets.isUnsettled, isFalse);
      expect(
        (assets.source as MiningSnapshotComputed).blockNumber,
        '122037728',
      );
      expect(
        (assets.referencePrice as MiningReferencePriceSettled).priceVersion,
        _priceVersion,
      );
      // The same block the summary publishes, from the same source: the page
      // stamps its own figures without reading the version string.
      final formula = assets.formula as MiningFormulaEffective;
      expect(formula.configVersion, _baselineVersion);
      expect(formula.scope, MiningFormulaScope.developmentBaseline);
    });

    test('a composition page without a formula block is refused', () {
      final body = _miningAssets()..remove('formula');
      final api = DioLoopV2MiningApi(
        _dio(_RecordingAdapter(statusCode: 200, body: body)),
      );

      expect(
        () => api.getAssets(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test(
      'no version in force reaches the composition page as pending',
      () async {
        final assets = await DioLoopV2MiningApi(
          _dio(
            _RecordingAdapter(
              statusCode: 200,
              body: _miningAssets(
                included: <Object?>[],
                totalPower: _unavailable('MINING_FORMULA_BASELINE_PENDING'),
                source: _unavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
                referencePrice: _unavailable('MINING_FORMULA_BASELINE_PENDING'),
                formula: _pendingFormula(),
              ),
            ),
          ),
        ).getAssets(accessToken: _token, clientVersion: _clientVersion);

        expect(
          (assets.formula as MiningFormulaPending).pendingVersion,
          'miningFormulaV1-draft',
        );
      },
    );

    test('an excluded asset keeps the server reason', () async {
      final assets = await DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(
              included: <Object?>[],
              excluded: <Object?>[
                <String, Object?>{
                  'assetId': _usdtAssetId,
                  'symbol': 'USDT',
                  'logo': <String, Object?>{
                    'status': 'unavailable',
                    'reasonCode': 'TOKEN_LOGO_ADDRESS_UNKNOWN',
                  },
                  'reasonCode': 'COMMUNITY_WEIGHT_AMBIGUOUS',
                },
              ],
            ),
          ),
        ),
      ).getAssets(accessToken: _token, clientVersion: _clientVersion);

      expect(assets.excluded.single.assetId, _usdtAssetId);
      expect(assets.excluded.single.symbol, 'USDT');
      expect(assets.excluded.single.reasonCode, 'COMMUNITY_WEIGHT_AMBIGUOUS');
    });

    test(
      'a registry with no row for the asset answers a null symbol',
      () async {
        final assets = await DioLoopV2MiningApi(
          _dio(
            _RecordingAdapter(
              statusCode: 200,
              body: _miningAssets(
                included: <Object?>[_assetRow(symbol: null)],
                excluded: <Object?>[
                  <String, Object?>{
                    'assetId': _usdtAssetId,
                    'symbol': null,
                    'logo': <String, Object?>{
                      'status': 'unavailable',
                      'reasonCode': 'TOKEN_LOGO_ADDRESS_UNKNOWN',
                    },
                    'reasonCode': 'MINING_PRICE_NOT_FRESH',
                  },
                ],
              ),
            ),
          ),
        ).getAssets(accessToken: _token, clientVersion: _clientVersion);

        expect(assets.included.single.symbol, isNull);
        expect(assets.excluded.single.symbol, isNull);
      },
    );

    test('a row with no symbol key at all is refused', () {
      final row = _assetRow()..remove('symbol');
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(included: <Object?>[row]),
          ),
        ),
      );

      // The key is required. Its absence would leave the page naming assets
      // by address and calling that the registry's answer.
      expect(
        () => api.getAssets(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an empty symbol is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(included: <Object?>[_assetRow(symbol: '')]),
          ),
        ),
      );

      expect(
        () => api.getAssets(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a proxied price with no proxy asset is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(
              included: <Object?>[_assetRow(quality: 'proxied')],
            ),
          ),
        ),
      );

      expect(
        () => api.getAssets(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a fresh price carrying a proxy asset is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(
              included: <Object?>[_assetRow(proxyAssetId: _wbnbAssetId)],
            ),
          ),
        ),
      );

      expect(
        () => api.getAssets(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the same asset weighted twice is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(included: <Object?>[_assetRow(), _assetRow()]),
          ),
        ),
      );

      expect(
        () => api.getAssets(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a weighted row without a settlement is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(
              source: _unavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
              totalPower: _unavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
              referencePrice: _unavailable('MINING_SNAPSHOT_NOT_AVAILABLE'),
            ),
          ),
        ),
      );

      expect(
        () => api.getAssets(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an empty composition without a settlement stays readable', () async {
      final assets = await DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(
              included: <Object?>[],
              source: _unavailable('MINING_FORMULA_BASELINE_PENDING'),
              totalPower: _unavailable('MINING_FORMULA_BASELINE_PENDING'),
              referencePrice: _unavailable('MINING_FORMULA_BASELINE_PENDING'),
            ),
          ),
        ),
      ).getAssets(accessToken: _token, clientVersion: _clientVersion);

      expect(assets.isUnsettled, isTrue);
      expect(assets.included, isEmpty);
      expect(
        (assets.totalPower as MiningFigureUnavailable).reasonCode,
        'MINING_FORMULA_BASELINE_PENDING',
      );
      expect(
        (assets.referencePrice as MiningReferencePriceUnavailable).reasonCode,
        'MINING_FORMULA_BASELINE_PENDING',
      );
    });

    test('a negative holding is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(included: <Object?>[_assetRow(holding: '-1')]),
          ),
        ),
      );

      expect(
        () => api.getAssets(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an unknown reference price quality is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(
              included: <Object?>[_assetRow(quality: 'stale')],
            ),
          ),
        ),
      );

      expect(
        () => api.getAssets(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    Map<String, Object?> rewardsBody({Object? estimatedToday}) =>
        <String, Object?>{
          'claimable': _unavailable('REWARD_AUTHORITY_PENDING'),
          'claimExecutable': false,
          'estimatedToday':
              estimatedToday ??
              <String, Object?>{
                'status': 'available',
                'value': '1000000',
                'budget': '1000000',
                'unitKey': 'mining.rules.dailyOutput.unit.loopTokenPending',
                'budgetStatus': 'development_placeholder',
                'formulaVersion': _baselineVersion,
                'scope': 'development_baseline',
              },
          'accumulated': _unavailable('REWARD_AUTHORITY_PENDING'),
          'ledger': <Object?>[],
          'source': _unavailable('REWARD_AUTHORITY_PENDING'),
          'contractVersion': '2.0',
        };

    test('the rewards share is read as the summary reads it', () async {
      final api = DioLoopV2MiningApi(
        _dio(_RecordingAdapter(statusCode: 200, body: rewardsBody())),
      );

      final rewards = await api.getRewards(
        accessToken: _token,
        clientVersion: _clientVersion,
      );

      final output = rewards.estimatedToday as MiningDailyOutputEstimate;
      expect(output.value, '1000000');
      expect(output.budget, '1000000');
      expect(output.isPlaceholderBudget, isTrue);
      expect(output.formulaVersion, _baselineVersion);
      expect(output.scope, MiningFormulaScope.developmentBaseline);
      // The three the reward authority closes are unchanged.
      expect(rewards.claimable.reasonCode, 'REWARD_AUTHORITY_PENDING');
      expect(rewards.claimExecutable, isFalse);
    });

    test('a rewards share without a settlement keeps its reason', () async {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: rewardsBody(
              estimatedToday: _unavailable('MINING_NETWORK_POWER_ZERO'),
            ),
          ),
        ),
      );

      final rewards = await api.getRewards(
        accessToken: _token,
        clientVersion: _clientVersion,
      );

      expect(
        (rewards.estimatedToday as MiningDailyOutputUnavailable).reasonCode,
        'MINING_NETWORK_POWER_ZERO',
      );
    });

    test('a rewards share without its budget is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: rewardsBody(
              estimatedToday: <String, Object?>{
                'status': 'available',
                'value': '1000000',
              },
            ),
          ),
        ),
      );

      expect(
        () =>
            api.getRewards(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

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

    test(
      'an unreadable answer to a read is not an unresolved submission',
      () async {
        // 奖励与领取 is a GET. When its payload failed to decode the page showed
        // "结果未确认…不要重复提交" over a submission the owner never made.
        final api = DioLoopV2MiningApi(
          _dio(
            _RecordingAdapter(
              statusCode: 200,
              body: <String, Object?>{'contractVersion': '2.0'},
            ),
          ),
        );

        LoopBackendFailure? failure;
        try {
          await api.getRewards(
            accessToken: _token,
            clientVersion: _clientVersion,
          );
          fail('an incomplete rewards payload must be refused');
        } on LoopBackendFailure catch (error) {
          failure = error;
        }
        expect(failure.kind, LoopBackendFailureKind.invalidPayload);

        final read = launchFailureKindForV2(failure, write: false);
        expect(read, LaunchFailureKind.invalidData);
        expect(launchFailureReason(read), isNot(contains('重复提交')));
        expect(launchFailureReason(read), isNot(contains('结果未确认')));
        // The same transport failure after a write is still unresolved: the
        // server may have applied it.
        expect(
          launchFailureKindForV2(failure, write: true),
          LaunchFailureKind.outcomeUnknown,
        );
        expect(
          launchOutcomeIsUnresolved(LaunchFailureKind.invalidData),
          isFalse,
        );
      },
    );

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
              'display': _rankDisplay(),
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

    test('the user board carries both display kinds and my place', () async {
      final rank =
          await DioLoopV2MiningApi(
            _dio(
              _RecordingAdapter(
                statusCode: 200,
                body: _miningRank(
                  ranking: _board(),
                  myPosition: <String, Object?>{
                    'status': 'available',
                    'position': 2,
                    'power': '1000',
                  },
                ),
              ),
            ),
          ).getRank(
            accessToken: _token,
            clientVersion: _clientVersion,
            scope: MiningRankScope.users,
          );

      final board = rank.ranking as MiningRankingUsers;
      expect(board.participants, 2);
      expect(board.items, hasLength(2));
      final first = board.items.first;
      expect(first.position, 1);
      expect((first.display as MiningRankAlias).alias, 'whale');
      expect(first.isSelf, isFalse);
      // An account in anonymous mode is a label to everybody else, never an
      // id.
      final other = board.items.last;
      expect(other.isSelf, isFalse);
      expect(
        (other.display as MiningRankAnonymous).labelKey,
        'mining.rank.anonymousMember',
      );
      final place = rank.myPosition as MiningRankPositionSettled;
      expect(place.position, 2);
      expect(place.power, '1000');
      // The board's own places were produced under this version, and the page
      // reads it from the same block the other two pages read.
      final formula = rank.formula as MiningFormulaEffective;
      expect(formula.configVersion, _baselineVersion);
      expect(formula.scope, MiningFormulaScope.developmentBaseline);
    });

    test('a ranking without a formula block is refused', () {
      final body = _miningRank(ranking: _board())..remove('formula');
      final api = DioLoopV2MiningApi(
        _dio(_RecordingAdapter(statusCode: 200, body: body)),
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

    test('a zero power is in the settlement with no position', () async {
      final rank =
          await DioLoopV2MiningApi(
            _dio(
              _RecordingAdapter(
                statusCode: 200,
                body: _miningRank(
                  ranking: _board(
                    items: <Object?>[
                      _aliasRow(position: null, power: '0'),
                      _anonymousRow(position: null, power: '0'),
                    ],
                    participants: 0,
                  ),
                ),
              ),
            ),
          ).getRank(
            accessToken: _token,
            clientVersion: _clientVersion,
            scope: MiningRankScope.users,
          );

      final board = rank.ranking as MiningRankingUsers;
      expect(board.participants, 0);
      expect(board.items.every((row) => !row.isRanked), isTrue);
      expect(board.items.first.power, '0');
      expect(
        (rank.myPosition as MiningRankPositionUnavailable).reasonCode,
        'MINING_RANK_NOT_RANKED',
      );
    });

    test('a withheld power is a null, and the position stays', () async {
      final rank =
          await DioLoopV2MiningApi(
            _dio(
              _RecordingAdapter(
                statusCode: 200,
                body: _miningRank(
                  ranking: _board(
                    items: <Object?>[
                      // Somebody else's row: the owner publishes the number to
                      // themselves alone, and the place is public regardless.
                      _aliasRow(power: null, powerVisibility: 'self'),
                      // The reader's own row while anonymous mode is on.
                      _aliasRow(
                        position: 2,
                        power: '1000',
                        isSelf: true,
                        profileId: _otherPublicProfileId,
                        audience: 'self',
                        powerVisibility: 'self',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ).getRank(
            accessToken: _token,
            clientVersion: _clientVersion,
            scope: MiningRankScope.users,
          );

      final board = rank.ranking as MiningRankingUsers;
      final withheld = board.items.first;
      expect(withheld.power, isNull);
      expect(withheld.isPowerWithheld, isTrue);
      expect(withheld.powerVisibility, MiningRankAudience.self);
      expect(withheld.position, 1);
      final mine = board.items.last;
      expect(mine.power, '1000');
      expect(
        (mine.display as MiningRankAlias).audience,
        MiningRankAudience.self,
      );
      expect(rank.display.ruleKey, 'mining.rank.display.anonymousModeOnly');
      expect(rank.display.powerRuleKey, 'mining.rank.power.ownerVisibility');
    });

    test('a power withheld from nobody is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningRank(
              ranking: _board(
                items: <Object?>[_aliasRow(power: null)],
                participants: 1,
              ),
            ),
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

    test('the reader is never withheld their own power', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningRank(
              ranking: _board(
                items: <Object?>[
                  _aliasRow(power: null, isSelf: true, powerVisibility: 'self'),
                ],
                participants: 1,
              ),
            ),
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

    test('nobody is anonymous to themselves', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningRank(
              ranking: _board(
                items: <Object?>[_anonymousRow(position: 1, isSelf: true)],
                participants: 1,
              ),
            ),
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

    test('another account cannot claim a private audience', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningRank(
              ranking: _board(
                items: <Object?>[_aliasRow(audience: 'self')],
                participants: 1,
              ),
            ),
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

    test('an unknown power visibility is refused', () {
      final row = _aliasRow()..['powerVisibility'] = 'friends';
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningRank(
              ranking: _board(items: <Object?>[row], participants: 1),
            ),
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

    test('a display block without the power rule is refused', () {
      final body = _miningRank(ranking: _board());
      (body['display']! as Map<String, Object?>).remove('powerRuleKey');
      final api = DioLoopV2MiningApi(
        _dio(_RecordingAdapter(statusCode: 200, body: body)),
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

    test('the community board carries the weight and the head count', () async {
      final rank =
          await DioLoopV2MiningApi(
            _dio(
              _RecordingAdapter(
                statusCode: 200,
                body: _miningRank(
                  scope: 'communities',
                  ranking: _board(
                    scope: 'communities',
                    items: <Object?>[
                      _communityRankRow(),
                      _communityRankRow(
                        communityId: _communityId,
                        weight: '0.8',
                      ),
                    ],
                    participants: 0,
                  ),
                  myPosition: _unavailable('MINING_RANK_NOT_APPLICABLE'),
                ),
              ),
            ),
          ).getRank(
            accessToken: _token,
            clientVersion: _clientVersion,
            scope: MiningRankScope.communities,
          );

      final board = rank.ranking as MiningRankingCommunities;
      expect(board.items.first.community.boundAssetId, _usdtAssetId);
      expect(board.items.first.weight, '1.5');
      expect(board.items.first.participants, 0);
      expect(board.items.first.isRanked, isFalse);
      expect(
        (rank.myPosition as MiningRankPositionUnavailable).reasonCode,
        'MINING_RANK_NOT_APPLICABLE',
      );
    });

    test('the board rows must match the scope that was asked for', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            // A communities board answered under the users scope: the rows
            // would be read as accounts.
            body: _miningRank(ranking: _board(scope: 'communities')),
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

    test('a position on a zero power is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningRank(
              ranking: _board(
                items: <Object?>[_aliasRow(position: 1, power: '0')],
                participants: 0,
              ),
            ),
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

    test('a ranked row after an unranked one is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningRank(
              ranking: _board(
                items: <Object?>[
                  _aliasRow(position: null, power: '0'),
                  _anonymousRow(position: 1, power: '500'),
                ],
                participants: 1,
              ),
            ),
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

    test('two rows claiming to be the reader are refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningRank(
              ranking: _board(
                items: <Object?>[
                  _aliasRow(isSelf: true),
                  _aliasRow(
                    position: 2,
                    power: '1000',
                    isSelf: true,
                    profileId: _otherPublicProfileId,
                  ),
                ],
              ),
            ),
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

    test('my own place is never a settled zero', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningRank(
              ranking: _board(),
              myPosition: <String, Object?>{
                'status': 'available',
                'position': 3,
                'power': '0',
              },
            ),
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

    test('an alias row without its profile id is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningRank(
              ranking: _board(
                items: <Object?>[
                  <String, Object?>{
                    'position': 1,
                    'power': '3000',
                    'powerVisibility': 'everyone',
                    'display': <String, Object?>{
                      'kind': 'alias',
                      'alias': 'whale',
                      'audience': 'everyone',
                    },
                    'isSelf': false,
                  },
                ],
                participants: 1,
              ),
            ),
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
                    'snapshot': _unavailable('MINING_FORMULA_BASELINE_PENDING'),
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

    test(
      'the community panel carries its settlement and its four figures',
      () async {
        final community =
            await DioLoopV2MiningApi(
              _dio(
                _RecordingAdapter(statusCode: 200, body: _miningCommunity()),
              ),
            ).getCommunity(
              accessToken: _token,
              clientVersion: _clientVersion,
              communityId: _communityId,
            );

        final weight = community.weight as MiningCommunityWeightApproved;
        expect(weight.value, '0.8');
        expect(weight.configVersion, _baselineVersion);
        expect(weight.reviewedAt, DateTime.utc(2026, 9, 15, 14, 58, 52, 89));
        expect(community.community.boundAssetId, _cakeAssetId);
        expect((community.communityPower as MiningFigureValue).value, '0');
        expect((community.myContribution as MiningFigureValue).value, '0');
        // A zero power has no place on the board, and the server says which
        // rule that is rather than the client inferring it.
        expect(
          (community.rank as MiningRankPositionUnavailable).reasonCode,
          'MINING_RANK_NOT_RANKED',
        );
        expect((community.participants as MiningParticipantsCount).count, 0);
        expect(
          (community.snapshot as MiningSnapshotComputed).formulaVersion,
          _baselineVersion,
        );
      },
    );

    test('a ranked community carries the place and the power', () async {
      final community =
          await DioLoopV2MiningApi(
            _dio(
              _RecordingAdapter(
                statusCode: 200,
                body: _miningCommunity(
                  communityPower: <String, Object?>{
                    'status': 'available',
                    'value': '38200',
                  },
                  rank: <String, Object?>{
                    'status': 'available',
                    'position': 7,
                    'power': '38200',
                  },
                  participants: <String, Object?>{
                    'status': 'available',
                    'count': 42,
                  },
                ),
              ),
            ),
          ).getCommunity(
            accessToken: _token,
            clientVersion: _clientVersion,
            communityId: _communityId,
          );

      final place = community.rank as MiningRankPositionSettled;
      expect(place.position, 7);
      expect(place.power, '38200');
      expect((community.participants as MiningParticipantsCount).count, 42);
    });

    test('an unbound community keeps every figure unavailable', () async {
      final community =
          await DioLoopV2MiningApi(
            _dio(
              _RecordingAdapter(
                statusCode: 200,
                body: _miningCommunity(
                  boundAssetId: null,
                  weight: <String, Object?>{
                    'status': 'unavailable',
                    'reasonCode': 'COMMUNITY_ASSET_NOT_BOUND',
                    'reviewStatus': 'not_applicable',
                  },
                  communityPower: _unavailable('COMMUNITY_ASSET_NOT_BOUND'),
                  myContribution: _unavailable('COMMUNITY_ASSET_NOT_BOUND'),
                  rank: _unavailable('COMMUNITY_ASSET_NOT_BOUND'),
                  participants: _unavailable('COMMUNITY_ASSET_NOT_BOUND'),
                ),
              ),
            ),
          ).getCommunity(
            accessToken: _token,
            clientVersion: _clientVersion,
            communityId: _communityId,
          );

      expect(community.community.boundAssetId, isNull);
      final weight = community.weight as MiningCommunityWeightPending;
      expect(weight.reasonCode, 'COMMUNITY_ASSET_NOT_BOUND');
      // Nothing is under review here: there is no weight to review (0046).
      expect(weight.reviewStatus, MiningWeightReviewStatus.notApplicable);
      expect(
        (community.participants as MiningParticipantsUnavailable).reasonCode,
        'COMMUNITY_ASSET_NOT_BOUND',
      );
      // The settlement exists; it simply weighed nothing for this community.
      expect(community.snapshot, isA<MiningSnapshotComputed>());
    });

    test(
      'a bound community without an approved weight is under review',
      () async {
        final community =
            await DioLoopV2MiningApi(
              _dio(
                _RecordingAdapter(
                  statusCode: 200,
                  body: _miningCommunity(
                    weight: <String, Object?>{
                      'status': 'unavailable',
                      'reasonCode': 'COMMUNITY_WEIGHT_PENDING_REVIEW',
                      'reviewStatus': 'pending_review',
                    },
                  ),
                ),
              ),
            ).getCommunity(
              accessToken: _token,
              clientVersion: _clientVersion,
              communityId: _communityId,
            );

        final weight = community.weight as MiningCommunityWeightPending;
        expect(weight.reasonCode, 'COMMUNITY_WEIGHT_PENDING_REVIEW');
        expect(weight.reviewStatus, MiningWeightReviewStatus.pendingReview);
      },
    );

    test('an unknown review status is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningCommunity(
              weight: <String, Object?>{
                'status': 'unavailable',
                'reasonCode': 'COMMUNITY_WEIGHT_PENDING_REVIEW',
                'reviewStatus': 'approved',
              },
            ),
          ),
        ),
      );

      expect(
        () => api.getCommunity(
          accessToken: _token,
          clientVersion: _clientVersion,
          communityId: _communityId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a community panel without its settlement is refused', () {
      final body = _miningCommunity()..remove('snapshot');
      final api = DioLoopV2MiningApi(
        _dio(_RecordingAdapter(statusCode: 200, body: body)),
      );

      expect(
        () => api.getCommunity(
          accessToken: _token,
          clientVersion: _clientVersion,
          communityId: _communityId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a negative participant count is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningCommunity(
              participants: <String, Object?>{
                'status': 'available',
                'count': -1,
              },
            ),
          ),
        ),
      );

      expect(
        () => api.getCommunity(
          accessToken: _token,
          clientVersion: _clientVersion,
          communityId: _communityId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a community place on a zero power is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningCommunity(
              rank: <String, Object?>{
                'status': 'available',
                'position': 3,
                'power': '0',
              },
            ),
          ),
        ),
      );

      expect(
        () => api.getCommunity(
          accessToken: _token,
          clientVersion: _clientVersion,
          communityId: _communityId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    /// The `approved` / `pendingApproval[]` document, field for field as
    /// `/v2/mining/rules` answers it on the Development lane.
    Map<String, Object?> formulaVersion({
      String configVersion = _baselineVersion,
      String status = 'approved',
      Object? scope = 'development_baseline',
      Object? assetWeights,
      Object? dailyOutput = _absent,
      Object? communityBand,
    }) => <String, Object?>{
      'configVersion': configVersion,
      'status': status,
      'scope': scope,
      'effectiveAt': '2026-09-15T14:57:37.026Z',
      'approvedAt': '2026-09-15T14:57:37.026Z',
      'expressionKey':
          'mining.rules.formula.holdingTimesReferencePriceTimesWeight',
      'dailyOutputKey': 'mining.rules.dailyOutput.shareOfNetworkPower',
      'assetWeights':
          assetWeights ??
          <String, Object?>{
            _nativeAssetId: '1',
            _cakeAssetId: '1',
            _usdtAssetId: '1',
            _wbnbAssetId: '1',
          },
      'dailyOutput': identical(dailyOutput, _absent)
          ? <String, Object?>{
              'status': 'development_placeholder',
              'budget': '1000000',
              'unitKey': 'mining.rules.dailyOutput.unit.loopTokenPending',
            }
          : dailyOutput,
      'weightRange': <String, Object?>{
        'loop': <String, Object?>{
          'status': 'pending_approval',
          'descriptionKey': 'mining.rules.weight.loopFixedMaximum',
        },
        'community':
            communityBand ??
            <String, Object?>{
              'status': 'approved',
              'descriptionKey': 'mining.rules.weight.communityReviewed',
              'range': <String, Object?>{'min': '0.5', 'max': '2'},
            },
        'reviewFactorKeys': <Object?>[
          'mining.rules.reviewFactor.communityQuality',
        ],
      },
      'priceGuardRules': <Object?>[
        <String, Object?>{
          'ruleKey': 'mining.rules.priceGuard.twap',
          'status': 'pending_approval',
        },
      ],
      'referralBoost': <String, Object?>{'status': 'pending_approval'},
    };

    Map<String, Object?> rulesBody({
      Object? approved,
      List<Object?>? pendingApproval,
      Object? baseline,
    }) => <String, Object?>{
      'approved': approved ?? formulaVersion(),
      'pendingApproval': pendingApproval ?? <Object?>[],
      'baseline':
          baseline ??
          <String, Object?>{
            'status': 'approved',
            'configVersion': _baselineVersion,
            'effectiveAt': '2026-09-15T14:57:37.026Z',
            'scope': 'development_baseline',
          },
      'referral': <String, Object?>{
        'configVersion': 'referralRulesV1',
        'effectiveAt': '2026-09-01T00:00:00.000Z',
        'levels': <Object?>[
          for (var level = 1; level <= 5; level += 1)
            <String, Object?>{
              'level': level,
              'boostPercent': <String>['10', '5', '3', '2', '1'][level - 1],
              'descriptionKey': 'mining.referral.level$level',
            },
        ],
      },
      'contractVersion': '2.0',
    };

    test(
      'the approved baseline carries its scope, weights, budget and range',
      () async {
        final api = DioLoopV2MiningApi(
          _dio(_RecordingAdapter(statusCode: 200, body: rulesBody())),
        );

        final rules = await api.getRules(
          accessToken: _token,
          clientVersion: _clientVersion,
        );

        final approved = rules.approved!;
        expect(approved.configVersion, _baselineVersion);
        expect(approved.scope, MiningFormulaScope.developmentBaseline);
        expect(approved.assetWeights, <String, String>{
          _nativeAssetId: '1',
          _cakeAssetId: '1',
          _usdtAssetId: '1',
          _wbnbAssetId: '1',
        });
        expect(approved.dailyOutput!.budget, '1000000');
        expect(approved.dailyOutput!.isPlaceholder, isTrue);
        expect(
          approved.dailyOutput!.unitKey,
          'mining.rules.dailyOutput.unit.loopTokenPending',
        );
        expect(approved.weightRange.community.range!.min, '0.5');
        expect(approved.weightRange.community.range!.max, '2');
        // The band that was not pinned keeps no range at all.
        expect(approved.weightRange.loop.range, isNull);
        final baseline = rules.baseline as MiningFormulaEffective;
        expect(baseline.configVersion, _baselineVersion);
        expect(baseline.scope, MiningFormulaScope.developmentBaseline);
      },
    );

    test('a product draft publishes no weights and no budget', () async {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: rulesBody(
              approved: null,
              pendingApproval: <Object?>[
                formulaVersion(
                  configVersion: 'miningFormulaV1-draft',
                  status: 'pending_approval',
                  scope: null,
                  assetWeights: <String, Object?>{},
                  dailyOutput: null,
                  communityBand: <String, Object?>{
                    'status': 'pending_approval',
                    'descriptionKey': 'mining.rules.weight.communityReviewed',
                  },
                ),
              ],
              baseline: _unavailable('MINING_FORMULA_BASELINE_PENDING'),
            ),
          ),
        ),
      );

      final rules = await api.getRules(
        accessToken: _token,
        clientVersion: _clientVersion,
      );

      final draft = rules.pendingApproval.single;
      expect(draft.scope, MiningFormulaScope.product);
      expect(draft.assetWeights, isEmpty);
      expect(draft.dailyOutput, isNull);
      expect(draft.weightRange.community.range, isNull);
      final baseline = rules.baseline as MiningFormulaPending;
      expect(baseline.reasonCode, 'MINING_FORMULA_BASELINE_PENDING');
      // The rules page's own block never names the draft: the page lists it.
      expect(baseline.pendingVersion, isNull);
    });

    test('an unknown key on a formula version is refused', () {
      final body = rulesBody();
      (body['approved']! as Map<String, Object?>)['emissionRate'] = '1';
      final api = DioLoopV2MiningApi(
        _dio(_RecordingAdapter(statusCode: 200, body: body)),
      );

      expect(
        () => api.getRules(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a weight that is not a decimal is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: rulesBody(
              approved: formulaVersion(
                assetWeights: <String, Object?>{_nativeAssetId: 'one'},
              ),
            ),
          ),
        ),
      );

      expect(
        () => api.getRules(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('an asset id the client cannot name is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: rulesBody(
              approved: formulaVersion(
                assetWeights: <String, Object?>{'bip122:0:native': '1'},
              ),
            ),
          ),
        ),
      );

      expect(
        () => api.getRules(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the baseline block may not carry the pending version key', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: rulesBody(
              approved: null,
              baseline: <String, Object?>{
                'status': 'unavailable',
                'reasonCode': 'MINING_FORMULA_BASELINE_PENDING',
                'pendingVersion': 'miningFormulaV1-draft',
              },
            ),
          ),
        ),
      );

      expect(
        () => api.getRules(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a daily output budget without its status is refused', () {
      final api = DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: rulesBody(
              approved: formulaVersion(
                dailyOutput: <String, Object?>{
                  'budget': '1000000',
                  'unitKey': 'mining.rules.dailyOutput.unit.loopTokenPending',
                },
              ),
            ),
          ),
        ),
      );

      expect(
        () => api.getRules(accessToken: _token, clientVersion: _clientVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

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

  // Decision 0057: a run that cannot value a held asset is never published,
  // so every read keeps answering the last complete snapshot and says that a
  // later run did not finish. The fields are additive, so the same decoders
  // must still read a deployment that does not send them.
  group('mining snapshot attempts', () {
    const attemptId = '9d2913e7-811a-42c9-a9c2-0f5f97671629';
    const snapshotId = '0e358b31-e49f-48b9-89b2-c5c908c3ad5e';

    Map<String, Object?> attempt({
      String id = attemptId,
      String status = 'incomplete',
      Object? reasonCode = 'MINING_SNAPSHOT_INCOMPLETE',
      List<Object?>? unreadInputs,
    }) => <String, Object?>{
      'snapshotId': id,
      'status': status,
      'computedAt': '2026-09-20T15:05:00.000Z',
      'reasonCode': reasonCode,
      'unreadInputs':
          unreadInputs ??
          <Object?>[
            <String, Object?>{
              'assetId': _usdtAssetId,
              'reasonCode': 'MINING_PRICE_PAIR_NOT_FOUND',
            },
          ],
    };

    Map<String, Object?> snapshot({
      Object? stale = _absent,
      Object? latestAttempt = _absent,
    }) => <String, Object?>{
      ..._miningSnapshot(),
      if (!identical(stale, _absent)) 'stale': stale,
      if (!identical(latestAttempt, _absent)) 'latestAttempt': latestAttempt,
    };

    Map<String, Object?> summaryBody(
      Object? snapshotBlock,
    ) => <String, Object?>{
      'power': <String, Object?>{'status': 'available', 'value': '4.482309'},
      'networkPower': <String, Object?>{
        'status': 'available',
        'value': '4.482309',
      },
      'estimatedToday': _unavailable('MINING_NETWORK_POWER_ZERO'),
      'accumulated': _unavailable('REWARD_AUTHORITY_PENDING'),
      'claimable': _unavailable('REWARD_AUTHORITY_PENDING'),
      'referralBoost': _unavailable(_referralBoostPending),
      'formula': _effectiveFormula(),
      'snapshot': snapshotBlock,
      'contractVersion': '2.0',
    };

    Future<MiningSummary> readSummary(Object? snapshotBlock) =>
        DioLoopV2MiningApi(
          _dio(
            _RecordingAdapter(
              statusCode: 200,
              body: summaryBody(snapshotBlock),
            ),
          ),
        ).getSummary(accessToken: _token, clientVersion: _clientVersion);

    test('a stale snapshot carries the run that did not finish', () async {
      final summary = await readSummary(
        snapshot(stale: true, latestAttempt: attempt()),
      );

      final block = summary.snapshot as MiningSnapshotComputed;
      expect(block.snapshotId, snapshotId);
      expect(block.stale, isTrue);
      // The numbers stay the published snapshot's: reading nothing is never
      // published as a zero.
      expect((summary.power as MiningFigureValue).value, '4.482309');
      final run = block.latestAttempt!;
      expect(run.status, MiningSnapshotAttemptStatus.incomplete);
      expect(run.snapshotId, attemptId);
      expect(run.computedAt, DateTime.utc(2026, 9, 20, 15, 5));
      expect(run.reasonCode, 'MINING_SNAPSHOT_INCOMPLETE');
      expect(run.unreadInputs, <MiningUnreadInput>[
        const MiningUnreadInput(
          assetId: _usdtAssetId,
          reasonCode: 'MINING_PRICE_PAIR_NOT_FOUND',
        ),
      ]);
      expect(miningSnapshotIsStale(block), isTrue);
    });

    test('a deployment without the two fields reads as before', () async {
      final summary = await readSummary(snapshot());

      final block = summary.snapshot as MiningSnapshotComputed;
      expect(block.stale, isFalse);
      expect(block.latestAttempt, isNull);
      expect(miningSnapshotIsStale(block), isFalse);
    });

    test('the newest run being this snapshot is not stale', () async {
      final summary = await readSummary(
        snapshot(
          stale: false,
          latestAttempt: attempt(
            id: snapshotId,
            status: 'complete',
            reasonCode: null,
            unreadInputs: <Object?>[],
          ),
        ),
      );

      final block = summary.snapshot as MiningSnapshotComputed;
      expect(block.stale, isFalse);
      expect(block.latestAttempt!.isComplete, isTrue);
      expect(block.latestAttempt!.snapshotId, snapshotId);
    });

    test('an operator-withdrawn run reads as invalidated', () async {
      final summary = await readSummary(
        snapshot(
          stale: true,
          latestAttempt: attempt(
            status: 'invalidated',
            reasonCode: 'MINING_SNAPSHOT_PUBLISHED_INCOMPLETE',
            unreadInputs: <Object?>[],
          ),
        ),
      );

      final run = (summary.snapshot as MiningSnapshotComputed).latestAttempt!;
      expect(run.isInvalidated, isTrue);
      expect(run.reasonCode, 'MINING_SNAPSHOT_PUBLISHED_INCOMPLETE');
      expect(run.unreadInputs, isEmpty);
    });

    test('no complete snapshot still explains itself', () async {
      final summary = await readSummary(<String, Object?>{
        'status': 'unavailable',
        'reasonCode': 'MINING_SNAPSHOT_INCOMPLETE',
        'latestAttempt': attempt(),
      });

      final block = summary.snapshot as MiningSnapshotUnavailable;
      expect(block.reasonCode, 'MINING_SNAPSHOT_INCOMPLETE');
      expect(
        block.latestAttempt!.unreadInputs.single.reasonCode,
        'MINING_PRICE_PAIR_NOT_FOUND',
      );
      expect(miningSnapshotIsStale(block), isFalse);
    });

    test('a run status outside the three is refused', () async {
      await expectLater(
        readSummary(
          snapshot(stale: true, latestAttempt: attempt(status: 'failed')),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a page that is not stale cannot carry an unfinished run', () async {
      await expectLater(
        readSummary(snapshot(stale: false, latestAttempt: attempt())),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a stale page cannot carry a completed run', () async {
      await expectLater(
        readSummary(
          snapshot(
            stale: true,
            latestAttempt: attempt(
              id: snapshotId,
              status: 'complete',
              reasonCode: null,
              unreadInputs: <Object?>[],
            ),
          ),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a completed run naming another snapshot is refused', () async {
      await expectLater(
        readSummary(
          snapshot(
            stale: false,
            latestAttempt: attempt(
              status: 'complete',
              reasonCode: null,
              unreadInputs: <Object?>[],
            ),
          ),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a completed run with an unread holding is refused', () async {
      await expectLater(
        readSummary(
          snapshot(
            stale: false,
            latestAttempt: attempt(
              id: snapshotId,
              status: 'complete',
              reasonCode: null,
            ),
          ),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the same unread asset twice is refused', () async {
      await expectLater(
        readSummary(
          snapshot(
            stale: true,
            latestAttempt: attempt(
              unreadInputs: <Object?>[
                <String, Object?>{
                  'assetId': _usdtAssetId,
                  'reasonCode': 'MINING_PRICE_PAIR_NOT_FOUND',
                },
                <String, Object?>{
                  'assetId': _usdtAssetId,
                  'reasonCode': 'MINING_PRICE_NOT_FRESH',
                },
              ],
            ),
          ),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('the composition page reads the same block on `source`', () async {
      final assets = await DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(
              source: snapshot(stale: true, latestAttempt: attempt()),
            ),
          ),
        ),
      ).getAssets(accessToken: _token, clientVersion: _clientVersion);

      final source = assets.source as MiningSnapshotComputed;
      expect(source.stale, isTrue);
      expect(source.latestAttempt!.unreadInputs.single.assetId, _usdtAssetId);
    });

    test('an excluded row carries the new price reason verbatim', () async {
      final assets = await DioLoopV2MiningApi(
        _dio(
          _RecordingAdapter(
            statusCode: 200,
            body: _miningAssets(
              excluded: <Object?>[
                <String, Object?>{
                  'assetId': _usdtAssetId,
                  'symbol': 'USDT',
                  'logo': <String, Object?>{
                    'status': 'unavailable',
                    'reasonCode': 'TOKEN_LOGO_ADDRESS_UNKNOWN',
                  },
                  'reasonCode': 'MINING_PRICE_PAIR_NOT_FOUND',
                },
              ],
            ),
          ),
        ),
      ).getAssets(accessToken: _token, clientVersion: _clientVersion);

      expect(assets.excluded.single.reasonCode, 'MINING_PRICE_PAIR_NOT_FOUND');
    });

    test(
      'a wallet no snapshot includes yet is an unavailable figure',
      () async {
        final summary = await DioLoopV2MiningApi(
          _dio(
            _RecordingAdapter(
              statusCode: 200,
              body: <String, Object?>{
                ...summaryBody(_miningSnapshot()),
                'power': _unavailable('MINING_SNAPSHOT_PENDING'),
              },
            ),
          ),
        ).getSummary(accessToken: _token, clientVersion: _clientVersion);

        expect(
          (summary.power as MiningFigureUnavailable).reasonCode,
          'MINING_SNAPSHOT_PENDING',
        );
      },
    );
  });

  // Decision 0059: a stablecoin that is only ever the quote token of its own
  // deepest pairs is priced by dividing that pair out, inside a declared
  // band. The row has to say which pool it was read from.
  group('mining derived reference prices', () {
    const pairAddress = '0x16b9a82891338f9ba80e2d6970fdda79d1eb0dae';

    Future<MiningAssets> readAssets(Map<String, Object?> row) =>
        DioLoopV2MiningApi(
          _dio(
            _RecordingAdapter(
              statusCode: 200,
              body: _miningAssets(included: <Object?>[row]),
            ),
          ),
        ).getAssets(accessToken: _token, clientVersion: _clientVersion);

    test('a derived row names its pool', () async {
      final assets = await readAssets(<String, Object?>{
        ..._assetRow(
          assetId: _usdtAssetId,
          symbol: 'USDT',
          holding: '2.99',
          referencePriceUsd: '0.999535369961668021',
          quality: 'derived',
          weight: '1.5',
          power: '4.487909963',
        ),
        'referencePricePairAddress': pairAddress,
      });

      final row = assets.included.single;
      expect(row.referencePriceQuality, MiningReferencePriceQuality.derived);
      expect(row.isDerivedPrice, isTrue);
      expect(row.isProxiedPrice, isFalse);
      expect(row.referencePricePairAddress, pairAddress);
      expect(miningPricePoolLabel(pairAddress), '0x16b9…0dae');
    });

    test('a row without the added key reads as before', () async {
      final assets = await readAssets(_assetRow());

      expect(assets.included.single.referencePricePairAddress, isNull);
      expect(
        assets.included.single.referencePriceQuality,
        MiningReferencePriceQuality.fresh,
      );
    });

    test('a derived price with no pool is refused', () async {
      await expectLater(
        readAssets(
          _assetRow(assetId: _usdtAssetId, symbol: 'USDT', quality: 'derived'),
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a quality outside the three is refused', () async {
      await expectLater(
        readAssets(_assetRow(quality: 'guessed')),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a pool that is not an address is refused', () async {
      await expectLater(
        readAssets(<String, Object?>{
          ..._assetRow(quality: 'derived'),
          'referencePricePairAddress': 'PancakeSwap v2',
        }),
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
      'boost': _unavailable(_referralBoostPending),
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
      // The boost's own code, not the formula baseline's: it is answered the
      // same way under an effective version.
      expect(overview.boost.reasonCode, _referralBoostPending);
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
              (failure) => launchFailureKindForV2(failure, write: true),
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
