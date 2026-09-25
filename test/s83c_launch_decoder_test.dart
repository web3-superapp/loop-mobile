import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';

/// Decision 0088 · the Launch decoder against loop-api decision 0076.
///
/// `test/fixtures/s83a-baseline/*.json` are byte copies of
/// `loop-api/test/fixtures/s83a-baseline/` (loop-api `6002830`, merged into
/// `integration/v2` = `101ca4a`): the responses the server returns while no
/// contract is configured, locked there as byte-identical to `1ab26d7`. They
/// must decode, and into the same `unavailable` projection the step-7 decoder
/// produced. The `available` bodies below are 测试专用, written by hand from
/// `openapi/loop-api.v2.json`; no server has emitted them yet.

const _token = 'access-token';
const _clientVersion = '1.4.0';
const _requestId = '11111111-2222-4333-8444-555555555555';
const _idempotencyKey = '66666666-7777-4888-8999-aaaaaaaaaaaa';
const _launchId = '9c1f0f2e-5a7b-4c3d-8e9f-0a1b2c3d4e5f';
const _projectId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const _roundId = '0b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
const _walletId = '4d5e6f70-8a9b-4c1d-8e2f-3a4b5c6d7e8f';
const _intentId = '7a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
const _contract = '0x1111111111111111111111111111111111111111';
final _digest = '0x${'cd' * 32}';
final _hash = '0x${'12' * 32}';
final _configVersion = '0x${'ab' * 32}';
final _root = '0x${'ef' * 32}';

final class _Adapter implements HttpClientAdapter {
  _Adapter({required this.statusCode, required this.body});

  final int statusCode;

  /// Either a JSON-encodable value or the raw response text.
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
    final text = body is String ? body! as String : jsonEncode(body);
    return ResponseBody.fromString(
      text,
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>[_requestId],
      },
    );
  }
}

LoopV2LaunchApi _api(int status, Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _Adapter(statusCode: status, body: body);
  return DioLoopV2LaunchApi(dio);
}

String _baseline(String name) =>
    File('test/fixtures/s83a-baseline/$name.json').readAsStringSync();

Map<String, Object?> _baselineJson(String name) =>
    jsonDecode(_baseline(name)) as Map<String, Object?>;

Matcher _invalid() => throwsA(
  isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

// ---------------------------------------------------------------------------
// hand-written `available` bodies (测试专用)
// ---------------------------------------------------------------------------

Map<String, Object?> _chainAxes() => <String, Object?>{
  'saleState': 'LIVE',
  'entitlementState': 'NONE',
  'liquidityState': 'NOT_STARTED',
  'operationalState': 'ACTIVE',
  'stateTupleDigest': _digest,
  'snapshotBlockNumber': '45000000',
  'snapshotBlockHash': _hash,
  'configVersion': _configVersion,
  'source': 'chain',
  'reasonCode': null,
};

Map<String, Object?> _chainConfig() => <String, Object?>{
  'status': 'available',
  'projectToken': '0x3333333333333333333333333333333333333333',
  'usd1': '0x2222222222222222222222222222222222222222',
  'softCapUsd1': '20000000000000000000000',
  'hardCapUsd1': '100000000000000000000000',
  'walletProjectCapUsd1': '1000000000000000000000',
  'minPurchaseUsd1': '10000000000000000000',
  'protocolFeeBps': 300,
  'liquidityBps': 5000,
  'tgeBps': 2500,
  'cliffSeconds': 0,
  'vestingSeconds': 7776000,
  'poolFeeTier': 2500,
  'lpLockSeconds': 31536000,
  'configVersion': _configVersion,
};

Map<String, Object?> _chainRound({int index = 1, Object? roundId = _roundId}) =>
    <String, Object?>{
      'status': 'available',
      'roundId': roundId,
      'roundIndex': index,
      'startAt': '2026-09-21T14:13:20.000Z',
      'endAt': '2026-09-23T14:13:20.000Z',
      'priceUsd1PerToken': '10000000000000000',
      'roundCapUsd1': '40000000000000000000000',
      'walletRoundCapUsd1': '500000000000000000000',
      'allowlistRoot': _root,
      'raisedUsd1': '1234000000000000000000',
    };

/// The S83a.2 example of `frontend-v2-launch-api.md`, on top of a baseline.
Map<String, Object?> _chainDetail() {
  final body = _baselineJson('launch-detail-confirmed');
  final launch = Map<String, Object?>.of(
    body['launch']! as Map<String, Object?>,
  );
  launch['contractAddress'] = _contract;
  launch['configVersion'] = null;
  launch['onChainState'] = _chainAxes();
  return <String, Object?>{
    ...body,
    'launch': launch,
    'config': _chainConfig(),
    'configPending': null,
    'rounds': <Object?>[_chainRound(), _chainRound(index: 2, roundId: null)],
  };
}

Map<String, Object?> _intentBody() => <String, Object?>{
  'launchIntent': <String, Object?>{
    'launchIntentId': _intentId,
    'state': 'prepared',
    'launchId': _launchId,
    'projectId': _projectId,
    'walletId': _walletId,
    'roundId': _roundId,
    'roundIndex': 1,
    'chainId': loopLaunchTestnetChainId,
    'contractAddress': _contract,
    'quoteAssetId': 'usd1',
    'usd1Amount': '500000000000000000000',
    'expectedTokenAmount': '50000000000000000000000',
    'minTokenAmount': '49500000000000000000000',
    'walletCumulativeUsd1': '0',
    'deadline': '2026-09-22T15:00:00.000Z',
    'eligibilityProof': <Object?>[_root],
    'configVersion': _configVersion,
    'stateTupleDigest': _digest,
    'snapshotBlockNumber': '45000000',
    'snapshotBlockHash': _hash,
    'payloadDigest': 'ab' * 32,
    'unsignedTransaction': <String, Object?>{
      'chainId': loopChainReference(loopLaunchTestnetChainId),
      'to': _contract,
      'data': '0x${'00' * 36}',
      'value': '0x0',
    },
    'expiresAt': '2026-09-22T14:05:00.000Z',
    'createdAt': '2026-09-22T14:00:00.000Z',
  },
  'contractVersion': '2.0',
};

Future<LaunchPurchasePrepared> _prepare(LoopV2LaunchApi api) =>
    api.postPurchaseIntent(
      accessToken: _token,
      clientVersion: _clientVersion,
      idempotencyKey: _idempotencyKey,
      launchId: _launchId,
      walletId: _walletId,
      roundId: _roundId,
      payAmount: '500',
    );

void main() {
  group('the twelve S83a baseline responses (unavailable branch)', () {
    test('both overview baselines decode with unavailable axes', () async {
      for (final name in <String>['overview-pending', 'overview-confirmed']) {
        final overview = await _api(
          200,
          _baseline(name),
        ).getOverview(accessToken: _token, clientVersion: _clientVersion);
        final all = <LaunchSummary>[
          ...overview.segments.live,
          ...overview.segments.upcoming,
          ...overview.segments.awaitingSchedule,
          ...overview.segments.ended,
        ];
        expect(all, isNotEmpty, reason: name);
        for (final summary in all) {
          expect(summary.contractAddress, isNull, reason: name);
          expect(
            summary.onChainState,
            isA<LaunchOnChainUnavailable>().having(
              (state) => state.reasonCode,
              'reasonCode',
              'LAUNCH_CONTRACT_BASELINE_PENDING',
            ),
            reason: name,
          );
        }
      }
    });

    test('both detail baselines keep LOOP slots and LOOP rounds', () async {
      for (final name in <String>[
        'launch-detail-pending',
        'launch-detail-confirmed',
      ]) {
        final detail = await _api(200, _baseline(name)).getLaunch(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        );
        expect(detail.launch.contractAddress, isNull, reason: name);
        expect(detail.onChain, isNull, reason: name);
        expect(
          detail.launch.onChainState.reasonCode,
          'LAUNCH_CONTRACT_BASELINE_PENDING',
        );
        expect(detail.saleConfig, isNull, reason: name);
        expect(detail.chainRounds, isEmpty, reason: name);
        expect(detail.config, isNotNull, reason: name);
        expect(detail.rounds, isNotEmpty, reason: name);
        expect(detail.graduation.steps, hasLength(4));
        expect(
          detail.graduation.steps.every((step) => step.status == 'pending'),
          isTrue,
        );
      }
    });

    test('both eligibility baselines stay pending with no tier', () async {
      for (final name in <String>[
        'eligibility-pending',
        'eligibility-confirmed',
      ]) {
        final eligibility = await _api(200, _baseline(name)).getEligibility(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        );
        expect(eligibility.result, isA<LaunchEligibilityPending>());
        expect(eligibility.tier, isNull);
        expect(eligibility.snapshotBlock, isNull);
        expect(eligibility.reasonCode, isNotNull);
        expect(eligibility.dependsOnStaking, isFalse);
      }
    });

    test('both holders baselines keep three unavailable facts', () async {
      for (final name in <String>['holders-pending', 'holders-confirmed']) {
        final holders = await _api(200, _baseline(name)).getHolders(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        );
        expect(holders.holders, isA<LaunchReadingUnavailable<Object?>>());
        expect(holders.myPosition, isA<LaunchReadingUnavailable<Object?>>());
        expect(holders.walletCap, isA<LaunchReadingUnavailable<Object?>>());
      }
    });

    test(
      'both history baselines are empty behind an unavailable source',
      () async {
        for (final name in <String>['history-pending', 'history-confirmed']) {
          final history = await _api(200, _baseline(name)).getHistory(
            accessToken: _token,
            clientVersion: _clientVersion,
            launchId: _launchId,
          );
          expect(history.source, isA<LaunchReadingUnavailable<Object?>>());
          expect(history.isEmpty, isTrue);
        }
      },
    );

    test('both intent baselines surface the 503 refusal', () async {
      for (final name in <String>['intents-pending', 'intents-confirmed']) {
        final recorded = _baselineJson(name);
        // The recorder replaced the per-request correlation id with `<id>`;
        // the envelope requires it to equal `x-request-id`, so it is
        // restored here and nothing else is touched.
        final body = (recorded['body']! as String).replaceFirst(
          '<id>',
          _requestId,
        );
        await expectLater(
          _prepare(_api(recorded['statusCode']! as int, body)),
          throwsA(
            isA<LoopBackendFailure>()
                .having((failure) => failure.statusCode, 'status', 503)
                .having(
                  (failure) => failure.code,
                  'code',
                  'CAPABILITY_UNAVAILABLE',
                ),
          ),
        );
      }
    });

    test('an unavailable reasonCode is any reason-code string', () async {
      final body = _baselineJson('launch-detail-pending');
      final launch = body['launch']! as Map<String, Object?>;
      (launch['onChainState']! as Map<String, Object?>)['reasonCode'] =
          'LAUNCH_SOMETHING_NEW_ENTIRELY';
      final detail = await _api(200, body).getLaunch(
        accessToken: _token,
        clientVersion: _clientVersion,
        launchId: _launchId,
      );
      expect(
        detail.launch.onChainState.reasonCode,
        'LAUNCH_SOMETHING_NEW_ENTIRELY',
      );
    });

    test('the unavailable branch keeps its null digest and block', () {
      final body = _baselineJson('launch-detail-pending');
      final launch = body['launch']! as Map<String, Object?>;
      (launch['onChainState']! as Map<String, Object?>)['stateTupleDigest'] =
          _digest;
      expect(
        () => _api(200, body).getLaunch(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        _invalid(),
      );
    });

    test('an unavailable history source with a row is refused', () {
      final body = _baselineJson('history-pending')
        ..['refunds'] = <Object?>[<String, Object?>{}];
      expect(
        () => _api(200, body).getHistory(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        _invalid(),
      );
    });
  });

  group('launch detail · available branch', () {
    test('the four axes, config and rounds decode from one block', () async {
      final detail = await _api(200, _chainDetail()).getLaunch(
        accessToken: _token,
        clientVersion: _clientVersion,
        launchId: _launchId,
      );
      final chain = detail.onChain!;
      expect(chain.saleState, LaunchSaleState.live);
      expect(chain.operationalState, LaunchOperationalState.active);
      expect(chain.isPurchasable, isTrue);
      expect(chain.stateTupleDigest, _digest);
      expect(detail.launch.contractAddress, _contract);
      expect(detail.config, isNull);
      expect(detail.rounds, isEmpty);
      expect(detail.saleConfig!.protocolFeeBps, 300);
      // Amounts stay the server's strings.
      expect(detail.saleConfig!.hardCapUsd1, '100000000000000000000000');
      expect(detail.chainRounds.map((round) => round.roundIndex), <int>[1, 2]);
      expect(detail.chainRounds.last.roundId, isNull);
    });

    test('an unknown key inside the chain axes is refused', () {
      final body = _chainDetail();
      ((body['launch']! as Map<String, Object?>)['onChainState']!
              as Map<String, Object?>)['graduated'] =
          true;
      expect(
        () => _api(200, body).getLaunch(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        _invalid(),
      );
    });

    test('an axis value outside 06 §2 is refused', () {
      final body = _chainDetail();
      ((body['launch']! as Map<String, Object?>)['onChainState']!
              as Map<String, Object?>)['saleState'] =
          'GRADUATED';
      expect(
        () => _api(200, body).getLaunch(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        _invalid(),
      );
    });

    test('chain axes with LOOP config slots are two sources, refused', () {
      final body = _chainDetail()
        ..['config'] = _baselineJson('launch-detail-confirmed')['config'];
      expect(
        () => _api(200, body).getLaunch(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        _invalid(),
      );
    });

    test('a round list mixing both branches is refused', () {
      final baseline = _baselineJson('launch-detail-confirmed');
      final body = _chainDetail()
        ..['rounds'] = <Object?>[
          _chainRound(),
          (baseline['rounds']! as List<Object?>).first,
        ];
      expect(
        () => _api(200, body).getLaunch(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        _invalid(),
      );
    });

    test('a config version that disagrees with the axes is refused', () {
      final body = _chainDetail();
      (body['config']! as Map<String, Object?>)['configVersion'] =
          '0x${'01' * 32}';
      expect(
        () => _api(200, body).getLaunch(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        _invalid(),
      );
    });

    test('chain axes without a contract address are refused', () {
      final body = _chainDetail();
      (body['launch']! as Map<String, Object?>)['contractAddress'] = null;
      expect(
        () => _api(200, body).getLaunch(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        _invalid(),
      );
    });

    test('a round amount sent as a number is refused', () {
      final body = _chainDetail();
      ((body['rounds']! as List<Object?>).first!
              as Map<String, Object?>)['raisedUsd1'] =
          1234;
      expect(
        () => _api(200, body).getLaunch(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        _invalid(),
      );
    });
  });

  group('eligibility · holders · history · available branch', () {
    test('an evaluated eligibility carries tier, block and proof', () async {
      final body = _baselineJson('eligibility-confirmed')
        ..['result'] = <String, Object?>{
          'status': 'available',
          'tier': 'priority',
          'reasonCode': null,
          'snapshotBlock': '44999000',
          'roundIndex': 1,
          'allowlistRoot': _root,
          'eligibilityProof': <Object?>[_root, _digest],
        };
      final eligibility = await _api(200, body).getEligibility(
        accessToken: _token,
        clientVersion: _clientVersion,
        launchId: _launchId,
      );
      expect(eligibility.tier, LaunchEligibilityTier.priority);
      expect(eligibility.snapshotBlock, '44999000');
      expect(eligibility.evaluated!.eligibilityProof, hasLength(2));
    });

    test('an evaluated eligibility with an unknown key is refused', () {
      final body = _baselineJson('eligibility-confirmed')
        ..['result'] = <String, Object?>{
          'status': 'available',
          'tier': null,
          'reasonCode': null,
          'snapshotBlock': '1',
          'roundIndex': 1,
          'allowlistRoot': _root,
          'eligibilityProof': <Object?>[],
          'score': 3,
        };
      expect(
        () => _api(200, body).getEligibility(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
        ),
        _invalid(),
      );
    });

    test('holders decode each available fact on its own', () async {
      final body = _baselineJson('holders-confirmed')
        ..['holders'] = <String, Object?>{
          'status': 'available',
          'holderCount': 1842,
          'indexedBlockNumber': '45000100',
        }
        ..['walletCap'] = <String, Object?>{
          'status': 'available',
          'walletProjectCapUsd1': '1000000000000000000000',
          'rounds': <Object?>[
            <String, Object?>{
              'roundIndex': 1,
              'walletRoundCapUsd1': '500000000000000000000',
              'cumulativeUsd1': '0',
            },
          ],
          'snapshotBlockNumber': '45000000',
          'snapshotBlockHash': _hash,
        };
      final holders = await _api(200, body).getHolders(
        accessToken: _token,
        clientVersion: _clientVersion,
        launchId: _launchId,
      );
      expect(
        holders.holders,
        isA<LaunchReadingAvailable<LaunchHolderCount>>().having(
          (reading) => reading.value.holderCount,
          'holderCount',
          1842,
        ),
      );
      // The position stayed unavailable: one fact never implies another.
      expect(holders.myPosition, isA<LaunchReadingUnavailable<Object?>>());
      expect(holders.walletCap, isA<LaunchReadingAvailable<LaunchWalletCap>>());
    });

    test('an indexed history decodes its rows strictly', () async {
      final body = _baselineJson('history-confirmed')
        ..['source'] = <String, Object?>{
          'status': 'available',
          'indexedBlockNumber': '45000100',
          'indexedBlockHash': _hash,
        }
        ..['purchaseRecords'] = <Object?>[
          <String, Object?>{
            'purchaseRecordId': '5e6f7a8b-9c0d-4e1f-8a2b-3c4d5e6f7a8b',
            'walletId': _walletId,
            'roundId': null,
            'roundIndex': 1,
            'usd1Amount': '200000000000000000000',
            'tokenAmount': '20000000000000000000000',
            'transactionHash': _digest,
            'logIndex': 3,
            'blockNumber': '45000050',
            'blockHash': _hash,
            'confirmationState': 'pending',
            'observedAt': '2026-09-22T14:02:00.000Z',
          },
        ];
      final history = await _api(200, body).getHistory(
        accessToken: _token,
        clientVersion: _clientVersion,
        launchId: _launchId,
      );
      expect(history.purchaseRecords.single.confirmationState.label, '待确认');
      expect(history.entitlements, isEmpty);
    });
  });

  group('purchase intent · 201', () {
    test('a prepared intent decodes and names this request', () async {
      final prepared = await _prepare(_api(201, _intentBody()));
      final intent = prepared.intent;
      expect(intent.chainId, loopLaunchTestnetChainId);
      expect(intent.unsignedTransaction.to, _contract);
      expect(intent.payloadMatchesReview, isTrue);
      expect(prepared.usd1, isNull);
    });

    test('an intent for another round is refused', () {
      final body = _intentBody();
      (body['launchIntent']! as Map<String, Object?>)['roundId'] =
          '1c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f';
      expect(() => _prepare(_api(201, body)), _invalid());
    });

    test('a transaction to another address is refused', () {
      final body = _intentBody();
      final intent = body['launchIntent']! as Map<String, Object?>;
      (intent['unsignedTransaction']! as Map<String, Object?>)['to'] =
          '0x5555555555555555555555555555555555555555';
      expect(() => _prepare(_api(201, body)), _invalid());
    });

    test('a transaction on another chain is refused', () {
      final body = _intentBody();
      final intent = body['launchIntent']! as Map<String, Object?>;
      (intent['unsignedTransaction']! as Map<String, Object?>)['chainId'] =
          loopChainReference(loopPrimaryChainId);
      expect(() => _prepare(_api(201, body)), _invalid());
    });

    test(
      'an unknown root key is refused; balances is read leniently',
      () async {
        expect(
          () => _prepare(_api(201, _intentBody()..['quote'] = <Object?>[])),
          _invalid(),
        );
        final prepared = await _prepare(
          _api(
            201,
            _intentBody()
              ..['balances'] = <String, Object?>{
                'launchChain': <String, Object?>{
                  'usd1': <String, Object?>{
                    'balance': '900000000000000000000',
                    'allowance': '0',
                  },
                },
              },
          ),
        );
        expect(prepared.usd1!.balance, '900000000000000000000');
        expect(prepared.usd1!.allowance, '0');
        // A shape this build cannot read is 未读取, never a failed intent.
        final odd = await _prepare(
          _api(201, _intentBody()..['balances'] = <String, Object?>{'x': 1}),
        );
        expect(odd.usd1, isNull);
      },
    );
  });

  group('projections', () {
    LaunchOnChainAvailable axes(
      LaunchSaleState sale,
      LaunchEntitlementState entitlement,
      LaunchLiquidityState liquidity, [
      LaunchOperationalState operational = LaunchOperationalState.active,
    ]) => LaunchOnChainAvailable(
      saleState: sale,
      entitlementState: entitlement,
      liquidityState: liquidity,
      operationalState: operational,
      stateTupleDigest: _digest,
      snapshotBlockNumber: '1',
      snapshotBlockHash: _hash,
      configVersion: _configVersion,
    );

    test('the combined sentence is composed from the four axes only', () {
      expect(
        launchStateProjection(
          axes(
            LaunchSaleState.succeeded,
            LaunchEntitlementState.frozen,
            LaunchLiquidityState.preparing,
          ),
        ),
        '销售成功，流动性准备中',
      );
      expect(
        launchStateProjection(
          axes(
            LaunchSaleState.succeeded,
            LaunchEntitlementState.frozen,
            LaunchLiquidityState.v3Live,
          ),
        ),
        isNot(contains('已毕业')),
      );
      expect(
        launchStateProjection(
          axes(
            LaunchSaleState.live,
            LaunchEntitlementState.none,
            LaunchLiquidityState.notStarted,
            LaunchOperationalState.paused,
          ),
        ),
        '已暂停 · 销售进行中',
      );
      expect(
        axes(
          LaunchSaleState.live,
          LaunchEntitlementState.none,
          LaunchLiquidityState.notStarted,
          LaunchOperationalState.paused,
        ).isPurchasable,
        isFalse,
      );
    });

    test('graduation steps follow liquidity and entitlement alone', () {
      List<LaunchGraduationProgress> rail(LaunchOnChainAvailable state) =>
          <LaunchGraduationProgress>[
            for (final step in LaunchGraduationStepKind.values)
              launchGraduationStepProgress(step, state),
          ];
      expect(
        rail(
          axes(
            LaunchSaleState.succeeded,
            LaunchEntitlementState.frozen,
            LaunchLiquidityState.retryScheduled,
          ),
        ),
        <LaunchGraduationProgress>[
          LaunchGraduationProgress.done,
          LaunchGraduationProgress.retrying,
          LaunchGraduationProgress.pending,
          LaunchGraduationProgress.pending,
        ],
      );
      expect(
        rail(
          axes(
            LaunchSaleState.succeeded,
            LaunchEntitlementState.vesting,
            LaunchLiquidityState.lpLocked,
          ),
        ),
        everyElement(LaunchGraduationProgress.done),
      );
      expect(
        rail(
          axes(
            LaunchSaleState.failed,
            LaunchEntitlementState.refunding,
            LaunchLiquidityState.notStarted,
          ),
        ),
        everyElement(LaunchGraduationProgress.notApplicable),
      );
    });

    test('display helpers shift 18 decimals without rounding the model', () {
      expect(launchUsd1Label('1234000000000000000000'), '1,234 USD1');
      expect(launchUnitsFigure('10000000000000000'), '0.01');
      expect(launchBpsLabel(300), '3%');
      expect(launchBpsLabel(25), '0.25%');
      expect(launchPoolFeeTierLabel(2500), '0.25%');
      expect(launchDurationLabel(7776000), '90 天');
    });

    test('a refusal names a known reason, and an unknown one by its code', () {
      expect(
        launchPurchaseRefusalText(
          LaunchFailureKind.unavailable,
          'LAUNCH_SALE_NOT_REGISTERED',
        ),
        contains('还没有登记到链上'),
      );
      expect(
        launchPurchaseRefusalText(
          LaunchFailureKind.validationFailed,
          'LAUNCH_ROUND_CAP_EXCEEDED',
        ),
        allOf(contains('错误代码'), isNot(contains('LAUNCH_ROUND_CAP_EXCEEDED'))),
      );
      expect(
        launchUnexplainedReasonCode('LAUNCH_ROUND_CAP_EXCEEDED'),
        'LAUNCH_ROUND_CAP_EXCEEDED',
      );
      expect(launchUnexplainedReasonCode('LAUNCH_SALE_NOT_REGISTERED'), isNull);
      expect(
        launchPurchaseRefusalText(LaunchFailureKind.unavailable, null),
        launchFailureReason(LaunchFailureKind.unavailable),
      );
    });
  });
}
