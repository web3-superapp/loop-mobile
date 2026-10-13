import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_rewards_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_dynamic_pool_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_dynamic_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// S168 · the LoopDynamic 外盘 Hook kind (client decision 0157)
// ---------------------------------------------------------------------------
//
// loop-api S166 had not published its contract when this was written; the
// shapes below are the 2026-10-13 draft in the S168 task sheet.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _requestId = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
const String _txHash =
    '0x3000000000000000000000000000000000000000000000000000000000000003';
const String _dynHook = '0x5555555555555555555555555555555555555555';

Map<String, Object?> _copy(Object? value) =>
    jsonDecode(jsonEncode(value)) as Map<String, Object?>;

Map<String, Object?> _s146(String name) =>
    (jsonDecode(
          File('test/fixtures/s146-launch2-pool/$name.json').readAsStringSync(),
        ) as Map<String, Object?>)['body']!
        as Map<String, Object?>;

Map<String, Object?> _stateJson({
  bool armed = false,
  String? roundId,
  String drop = '0',
  String pot = '120.5',
  String total = '0',
  String? mine = '0',
}) => <String, Object?>{
  'hookAddress': _dynHook,
  'armed': armed,
  'currentRoundId': roundId,
  'currentDropWad': drop,
  'pot': pot,
  'totalBuyWeight': total,
  'myBuyWeight': mine,
  'priceTiming': 'POST_SWAP',
  'baseSellFeePpm': 20000,
  'routingPolicy': 'LOOP_ROUTER_ONLY',
};

Launch2DynamicPoolState _state({
  bool armed = false,
  String drop = '0',
  String? mine = '0',
}) => LoopV2Launch2DynamicPoolCodec.state(
  _stateJson(
    armed: armed,
    roundId: armed ? '7' : null,
    drop: drop,
    total: armed ? '900' : '0',
    mine: mine,
  ),
);

Map<String, Object?> _roundJson({
  String roundId = '7',
  bool closed = true,
  String claimable = '12.5',
  String claimed = '0',
}) => <String, Object?>{
  'roundId': roundId,
  'startCandle': '5684100',
  'endCandle': closed ? '5684107' : null,
  'closed': closed,
  'allocation': closed ? '100' : null,
  'myWeight': '90',
  'totalWeight': '720',
  'claimable': closed ? claimable : '0',
  'claimed': claimed,
};

Launch2DynamicRewards _rewards(List<Map<String, Object?>> rounds) =>
    LoopV2Launch2DynamicPoolCodec.rewards(<String, Object?>{'rounds': rounds});

/// A claim intent shaped like the MEME v2 intents, sent to [to].
Map<String, Object?> _claimIntentJson({
  String to = _dynHook,
  String kind = 'dynamic_claim',
}) {
  final intent = _copy(_s146('pool_prepare_sell_ready')['launch2Intent']);
  intent['kind'] = kind;
  intent['contractAddress'] = to;
  intent['amountIn'] = '0';
  intent['expectedOut'] = '12.5';
  intent['minOut'] = '12.5';
  intent['taxUsd1'] = '0';
  (intent['calldata']! as Map<String, Object?>)['to'] = to;
  (intent['unsignedTransaction']! as Map<String, Object?>)['to'] = to;
  return intent;
}

Launch2Intent _claimIntent({String to = _dynHook}) =>
    LoopV2Launch2DynamicPoolCodec.claimIntent(
      <String, Object?>{
        'launch2Intent': _claimIntentJson(to: to),
        'contractVersion': '2.0',
      },
      instanceId: l2InstanceA,
      walletId: l2WalletId,
    );

Launch2PoolQuote _quote({
  required Launch2Side side,
  int? dynamicTaxBps,
  String? rewardWeight,
  bool dynamicKeys = true,
}) {
  final body = _s146(
    side == Launch2Side.buy
        ? 'pool_quote_buy_exact_in'
        : 'pool_quote_sell_exact_out',
  );
  final quote = body['quote']! as Map<String, Object?>;
  quote['mode'] = 'exactIn';
  if (dynamicKeys) {
    quote['dynamicTaxBps'] = dynamicTaxBps;
    quote['rewardWeight'] = rewardWeight;
  }
  return LoopV2Launch2PoolCodec.quote(
    body,
    instanceId: l2InstanceA,
    side: side,
    mode: Launch2PoolMode.exactIn,
    walletId: l2WalletId,
  );
}

Launch2InstanceDetail _graduated() =>
    l2Detail(stage: 'graduated', noNextChange: true, pool: l2PoolSummaryJson());

// ---------------------------------------------------------------------------
// fakes
// ---------------------------------------------------------------------------

final class _FakeLaunch2 implements Launch2Gateway {
  _FakeLaunch2({this.quoteAnswer});

  /// Answers every pool quote; `null` = unavailable.
  final Future<Launch2PoolQuote> Function(Launch2Side side)? quoteAnswer;
  final List<Launch2PoolMode> quoteModes = <Launch2PoolMode>[];

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) =>
      Future<Launch2InstanceDetail>.value(_graduated());

  @override
  Future<Launch2PoolQuote> poolQuote({
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
    required String walletId,
  }) {
    quoteModes.add(mode);
    final answer = quoteAnswer;
    return answer == null ? _unavailable() : answer(side);
  }

  @override
  Future<Launch2PoolPrepared> preparePoolTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
  }) => _unavailable();

  @override
  Future<Launch2BuybackPage> loadBuybacks(String instanceId) =>
      Future<Launch2BuybackPage>.value(l2Buybacks());

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) => _unavailable();

  @override
  Future<Launch2Quote> quote({
    required String instanceId,
    required Launch2Side side,
    required Decimal amount,
    required String walletId,
  }) => _unavailable();

  @override
  Future<Launch2Intent> prepareNftMint({
    required String instanceId,
    required String walletId,
  }) => _unavailable();

  @override
  Future<Launch2Intent> prepareTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Decimal amount,
    required Decimal minOut,
    required DateTime deadline,
  }) => _unavailable();

  @override
  Future<Launch2Positions> loadPositions() => _unavailable();

  @override
  Future<Launch2PoolTrades> loadPoolTrades({
    required String instanceId,
    required String walletId,
    int limit = launch2PoolTradesShown,
  }) => _unavailable();
}

final class _FakeDynamic implements Launch2DynamicPoolGateway {
  _FakeDynamic({
    required this.kind,
    this.rewards,
    this.claim,
    this.rewardsAfterClaim,
  });

  final Launch2PoolKind kind;
  final Launch2DynamicRewards? rewards;
  final Launch2DynamicRewards? rewardsAfterClaim;
  final Future<Launch2Intent> Function()? claim;
  int kindReads = 0;
  int rewardReads = 0;
  final List<BigInt> claimRounds = <BigInt>[];
  final List<String> reports = <String>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2PoolKind> loadPoolKind(String instanceId) {
    kindReads += 1;
    return Future<Launch2PoolKind>.value(kind);
  }

  @override
  Future<Launch2DynamicRewards> loadRewards(String instanceId) {
    rewardReads += 1;
    final after = rewardsAfterClaim;
    final value = reports.isNotEmpty && after != null ? after : rewards;
    if (value == null) {
      return Future<Launch2DynamicRewards>.error(
        const LoopChainException(LoopChainFailureKind.offline),
      );
    }
    return Future<Launch2DynamicRewards>.value(value);
  }

  @override
  Future<Launch2Intent> prepareClaim({
    required String instanceId,
    required String walletId,
    required BigInt roundId,
  }) {
    claimRounds.add(roundId);
    return claim!();
  }

  @override
  Future<Launch2DynamicClaimReport> reportClaim({
    required String instanceId,
    required String walletId,
    required BigInt roundId,
    required String intentId,
    required String transactionHash,
  }) {
    reports.add('$roundId:$intentId:$transactionHash');
    return Future<Launch2DynamicClaimReport>.value(
      Launch2DynamicClaimReport(roundId: roundId, status: 'submitted'),
    );
  }
}

final class _RecordingWallet implements WalletSigningGateway {
  final List<SigningIntent> handed = <SigningIntent>[];

  @override
  WalletGatewayAvailability get availability =>
      WalletGatewayAvailability.available;

  @override
  String get label => 'test';

  @override
  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  }) async {
    handed.add(intent);
    final refusal = walletHandoffRefusal(intent, now: now);
    if (refusal != null) return WalletHandoffResult.rejected(refusal);
    return const WalletHandoffResult(
      accepted: true,
      code: 'wallet_accepted',
      value: _txHash,
    );
  }
}

LoopV2MetaSnapshot _meta() {
  final base = s7MetaSnapshot();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.launch2)
            const LoopV2Capability(
              id: LoopV2CapabilityId.launch2,
              availability: LoopV2CapabilityAvailability.available,
              reasonCode: null,
              evidence: LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.notApplicable,
                reasonCode: null,
              ),
            )
          else
            capability,
      ],
    ),
  );
}

LoopWalletAccount _wallet() => LoopWalletAccount(
  walletId: l2WalletId,
  address: l2WalletAddress,
  kind: LoopWalletKind.embedded,
  status: LoopWalletStatus.active,
  isActive: true,
  firstSeenAt: DateTime.utc(2026, 9),
  lastSeenAt: DateTime.utc(2026, 10, 8),
);

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required _FakeLaunch2 launch2,
  _FakeDynamic? dynamicPool,
  _RecordingWallet? wallet,
}) => pumpS7Page(
  tester,
  page,
  meta: _meta(),
  wallet: FakeWalletDirectory(
    activeWalletId: l2WalletId,
    wallets: <LoopWalletAccount>[_wallet()],
  ),
  overrides: <Override>[
    launch2GatewayProvider.overrideWithValue(launch2),
    if (dynamicPool != null)
      launch2DynamicPoolGatewayProvider.overrideWithValue(dynamicPool),
    launch2ClockProvider.overrideWithValue(() => l2Now),
    launch2PollingProvider.overrideWithValue(
      const Launch2Polling(
        detailInterval: Duration(hours: 1),
        tradingInterval: Duration(hours: 1),
      ),
    ),
    loopFeatureSwitchesProvider.overrideWithValue(
      const LoopFeatureSwitchValues(launch2Visible: true),
    ),
    if (wallet != null) walletSigningGatewayProvider.overrideWithValue(wallet),
  ],
);

Future<void> _openInstance(
  WidgetTester tester, {
  required _FakeLaunch2 launch2,
  _FakeDynamic? dynamicPool,
  List<String>? opened,
}) => _pump(
  tester,
  Launch2InstanceScreen(instanceId: l2InstanceA, onNavigate: opened?.add),
  launch2: launch2,
  dynamicPool: dynamicPool,
);

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await _scrollTo(tester, _key('launch2-pool-amount'));
  await tester.enterText(_key('launch2-pool-amount'), text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// Every element S168 adds; none may appear on an OfficialTax page.
const List<String> _newKeys = <String>[
  'launch2-dyn-round',
  'launch2-dyn-panel-note',
  'launch2-dyn-rewards-link',
  'launch2-dyn-armed',
  'launch2-dyn-idle',
  'launch2-dyn-idle-line',
];

void main() {
  loopWatchGround();

  group('codec (S166 draft)', () {
    test('state: strict keys, an armed round has an id, drop ≤ 100%', () {
      final idle = _state();
      expect(idle.armed, isFalse);
      expect(idle.currentRoundId, isNull);
      expect(idle.hookAddress, _dynHook);
      expect(idle.baseSellFeeBps, 200);
      final armed = _state(armed: true, drop: '200000000000000000');
      expect(armed.dropPercent, Decimal.fromInt(20));
      expect(armed.currentRoundId, BigInt.from(7));
      final Matcher invalid = throwsA(isA<LoopBackendFailure>());
      expect(
        () => LoopV2Launch2DynamicPoolCodec.state(
          _stateJson(armed: true, roundId: null),
        ),
        invalid,
      );
      expect(
        () => LoopV2Launch2DynamicPoolCodec.state(
          _stateJson(drop: '1000000000000000001'),
        ),
        invalid,
      );
      expect(
        () => LoopV2Launch2DynamicPoolCodec.state(<String, Object?>{
          ..._stateJson(),
          'extra': 1,
        }),
        invalid,
      );
      expect(
        () => LoopV2Launch2DynamicPoolCodec.state(<String, Object?>{
          ..._stateJson(),
          'priceTiming': 'LATER',
        }),
        invalid,
      );
      expect(
        () => LoopV2Launch2DynamicPoolCodec.state(
          _stateJson(total: '1', mine: '2'),
        ),
        invalid,
      );
      expect(
        LoopV2Launch2DynamicPoolCodec.state(<String, Object?>{
          ..._stateJson(),
          'contractVersion': '2.0',
        }).armed,
        isFalse,
      );
    });

    test('rewards: an open round has no end and nothing to claim; ids are '
        'unique', () {
      final rewards = _rewards(<Map<String, Object?>>[
        _roundJson(roundId: '8', closed: false),
        _roundJson(),
      ]);
      expect(rewards.rounds.first.canClaim, isFalse);
      expect(rewards.rounds.last.canClaim, isTrue);
      final Matcher invalid = throwsA(isA<LoopBackendFailure>());
      final open = _roundJson(closed: false)..['claimable'] = '1';
      expect(() => _rewards(<Map<String, Object?>>[open]), invalid);
      expect(
        () => _rewards(<Map<String, Object?>>[_roundJson(), _roundJson()]),
        invalid,
      );
      final noEnd = _roundJson()..['endCandle'] = null;
      expect(() => _rewards(<Map<String, Object?>>[noEnd]), invalid);
      final early = _roundJson()..['endCandle'] = '5684099';
      expect(() => _rewards(<Map<String, Object?>>[early]), invalid);
      // `claimed` may be a flag.
      final flagged = _rewards(<Map<String, Object?>>[
        _roundJson()..['claimed'] = true,
      ]).rounds.single;
      expect(flagged.alreadyClaimed, isTrue);
      expect(flagged.canClaim, isFalse);
      expect(
        () =>
            _rewards(<Map<String, Object?>>[_roundJson()..['claimed'] = 'yes']),
        invalid,
      );
    });

    test('claim intent: one kind from one route, no approval', () {
      final intent = _claimIntent();
      expect(intent.kind, Launch2IntentKind.rewardClaim);
      expect(intent.venue, Launch2Venue.loopDynamicRewards);
      expect(intent.payloadMatchesReview, isTrue);
      final Matcher invalid = throwsA(isA<LoopBackendFailure>());
      expect(
        () => LoopV2Launch2DynamicPoolCodec.claimIntent(
          <String, Object?>{
            'launch2Intent': _claimIntentJson(kind: 'pool_sell'),
            'contractVersion': '2.0',
          },
          instanceId: l2InstanceA,
          walletId: l2WalletId,
        ),
        invalid,
      );
      // The curve routes never answer a claim.
      expect(() => LoopV2Launch2Codec.intentBody(_claimIntentJson()), invalid);
    });

    test('pool quote: the two dynamic keys are optional and nullable; any '
        'other key is still refused', () {
      final official = _quote(side: Launch2Side.buy, dynamicKeys: false);
      expect(official.dynamicTaxBps, isNull);
      expect(official.rewardWeight, isNull);
      final buy = _quote(side: Launch2Side.buy, rewardWeight: '98');
      expect(buy.rewardWeight, Decimal.fromInt(98));
      final sell = _quote(side: Launch2Side.sell, dynamicTaxBps: 500);
      expect(sell.dynamicTaxBps, 500);
      final body = _s146('pool_quote_buy_exact_in');
      (body['quote']! as Map<String, Object?>)['dynamicTaxNote'] = 'x';
      expect(
        () => LoopV2Launch2PoolCodec.quote(
          body,
          instanceId: l2InstanceA,
          side: Launch2Side.buy,
          mode: Launch2PoolMode.exactIn,
          walletId: l2WalletId,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('transport', () {
    (DioLoopV2Launch2DynamicPoolApi, List<RequestOptions>) api(
      List<(int, Object?)> answers,
    ) {
      final requests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = _Script(answers, requests);
      return (DioLoopV2Launch2DynamicPoolApi(dio), requests);
    }

    Map<String, Object?> error(String code, String category) =>
        <String, Object?>{
          'code': code,
          'category': category,
          'retryable': false,
          'userMessageKey': 'errors.test',
          'correlationId': _requestId,
          'detailsSafe': null,
          'providerReferenceSafe': null,
        };

    test('200 is LoopDynamic; 404 (any body) and 503 capability are '
        'OfficialTax; other failures stay failures', () async {
      final (client, requests) = api(<(int, Object?)>[
        (200, _stateJson()),
        (404, <String, Object?>{'message': 'Route not found'}),
        (503, error('CAPABILITY_UNAVAILABLE', 'availability')),
        (500, error('INTERNAL_ERROR', 'internal')),
      ]);
      Future<Launch2PoolKind> read() => client.getPoolKind(
        accessToken: 'token',
        clientVersion: '1.0.0',
        instanceId: l2InstanceA,
      );
      expect(await read(), isA<Launch2LoopDynamicPool>());
      expect(
        requests.single.path,
        '/v2/launch2/instances/$l2InstanceA/dynamic-pool',
      );
      expect(await read(), isA<Launch2OfficialTaxPool>());
      expect(await read(), isA<Launch2OfficialTaxPool>());
      await expectLater(read(), throwsA(isA<LoopBackendFailure>()));
    });

    test('claim prepare: path, body and an idempotency key', () async {
      final (client, requests) = api(<(int, Object?)>[
        (
          201,
          <String, Object?>{
            'launch2Intent': _claimIntentJson(),
            'contractVersion': '2.0',
          },
        ),
      ]);
      final intent = await client.postClaimPrepare(
        accessToken: 'token',
        clientVersion: '1.0.0',
        idempotencyKey: '0d3b2a6c-6c55-4b8d-9e7f-1a2b3c4d5e6f',
        instanceId: l2InstanceA,
        walletId: l2WalletId,
        roundId: BigInt.from(7),
      );
      expect(intent.kind, Launch2IntentKind.rewardClaim);
      final request = requests.single;
      expect(
        request.path,
        '/v2/launch2/instances/$l2InstanceA/dynamic-pool/claim/prepare',
      );
      expect(request.data, <String, Object?>{
        'walletId': l2WalletId,
        'roundId': '7',
      });
      expect(request.headers['Idempotency-Key'], isNotNull);
    });
  });

  group('view model and copy', () {
    test('the new refusals read in Chinese, prefixed or not', () {
      expect(
        launch2PoolReasonText('LAUNCH2_EXACT_OUT_UNSUPPORTED'),
        '这个项目只支持按支付金额买入',
      );
      expect(launch2PoolReasonText('UNAUTHORIZED_ROUTER'), '这个交易入口不被该项目接受');
      expect(
        launch2PoolReasonText('LAUNCH2_UNSUPPORTED_SWAP'),
        '这个项目不支持这种交易方式',
      );
      expect(launch2PoolReasonText('POOL_BUSY'), '池子正忙，几秒后再试');
      expect(launch2PoolReasonText('ROUND_NOT_CLOSED'), '本轮还没结束，结束后可领');
      expect(launch2PoolReasonText('LAUNCH2_ALREADY_CLAIMED'), '这一轮已经领过');
      // The S146 catalogue is untouched.
      expect(
        launch2PoolReasonText('POOL_QUOTE_UNAVAILABLE'),
        '官方池试算没有通过，换个金额再试',
      );
    });

    test('an OfficialTax quote reads exactly as before', () {
      final quote = _quote(side: Launch2Side.buy, dynamicKeys: false);
      final lines = launch2PoolQuoteLines(quote, 'FROG');
      expect(lines.map((line) => line.key), <String>[
        'expected',
        'min',
        'tax',
        'price',
        'slippage',
      ]);
      expect(lines[2].label, '外盘税 2%');
    });

    test('a LoopDynamic buy says the MEME tax and the round weight; a sell '
        'the base and the dynamic tax', () {
      final state = _state(armed: true, drop: '200000000000000000');
      final buy = launch2DynamicQuoteLines(
        _quote(side: Launch2Side.buy, rewardWeight: '98'),
        'FROG',
        state,
      );
      expect(buy.firstWhere((l) => l.key == 'tax').label, '外盘税 2%（扣 MEME）');
      final weight = buy.firstWhere((l) => l.key == 'reward-weight');
      expect(weight.label, '本笔计入本轮奖励权重');
      expect(weight.value, '98 USD1');
      final sell = launch2DynamicQuoteLines(
        _quote(side: Launch2Side.sell, dynamicTaxBps: 500),
        'FROG',
        state,
      );
      expect(
        sell.firstWhere((l) => l.key == 'tax').label,
        '基础税 2% + 当前动态税 5%（扣 USD1）',
      );
      expect(sell.any((l) => l.key == 'reward-weight'), isFalse);
      final unknown = launch2DynamicQuoteLines(
        _quote(side: Launch2Side.sell),
        'FROG',
        state,
      ).firstWhere((l) => l.key == 'tax');
      expect(unknown.label, '基础税 2% + 当前动态税（扣 USD1）');
      expect(unknown.value, '成交后按跌幅计');
    });
  });

  group('project page', () {
    testWidgets('no adapter (production default): nothing new, no read', (
      tester,
    ) async {
      await _openInstance(tester, launch2: _FakeLaunch2());
      expect(_key('launch2-pool-panel'), findsOneWidget);
      for (final key in _newKeys) {
        expect(_key(key), findsNothing, reason: key);
      }
      expect(_key('launch2-pool-mode-caption'), findsOneWidget);
      expect(find.text('外盘税 2%'), findsWidgets);
      await _scrollTo(tester, _key('launch2-go-swap'));
      expect(_key('launch2-go-swap'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('OfficialTax answered (404): the S146 page, unchanged', (
      tester,
    ) async {
      final dynamicPool = _FakeDynamic(kind: const Launch2OfficialTaxPool());
      await _openInstance(
        tester,
        launch2: _FakeLaunch2(),
        dynamicPool: dynamicPool,
      );
      expect(dynamicPool.kindReads, 1);
      for (final key in _newKeys) {
        expect(_key(key), findsNothing, reason: key);
      }
      expect(_key('launch2-pool-mode-exactOut'), findsOneWidget);
      await _scrollTo(tester, _key('launch2-go-swap'));
      expect(_key('launch2-go-swap'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('LoopDynamic, not armed: one line on what arms a round; the '
        'panel is exactIn only and says where rewards count', (tester) async {
      final opened = <String>[];
      await _openInstance(
        tester,
        launch2: _FakeLaunch2(),
        dynamicPool: _FakeDynamic(kind: Launch2LoopDynamicPool(_state())),
        opened: opened,
      );
      expect(_key('launch2-dyn-round'), findsOneWidget);
      expect(_key('launch2-dyn-idle'), findsOneWidget);
      expect(find.text('未激活'), findsOneWidget);
      expect(find.text('价格 5 分钟内跌超 10% 将开启动态税与买入奖励'), findsOneWidget);
      expect(_key('launch2-dyn-drop'), findsNothing);
      expect(find.text('120.5 USD1'), findsOneWidget);
      // The round card sits above the pool figures.
      expect(
        tester.getTopLeft(_key('launch2-dyn-round')).dy,
        lessThan(tester.getTopLeft(_key('launch2-pool-stats')).dy),
      );
      expect(_key('launch2-pool-mode-caption'), findsNothing);
      expect(_key('launch2-pool-mode-exactOut'), findsNothing);
      expect(find.text('在 LOOP 里买入才保证记入奖励'), findsOneWidget);
      expect(find.text('外盘税 2% + 卖出动态税'), findsOneWidget);
      expect(_key('launch2-go-swap'), findsNothing);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await tester.tap(_key('launch2-dyn-rewards-link'));
      expect(opened.single, Launch2Route.dynamicRewards(l2InstanceA));
      expect(opened.single, '/launch2/dynamic-rewards?id=$l2InstanceA');
      await _drain(tester);
    });

    testWidgets('LoopDynamic, armed 20% down: drop, pot, end rule, my weight', (
      tester,
    ) async {
      await _openInstance(
        tester,
        launch2: _FakeLaunch2(),
        dynamicPool: _FakeDynamic(
          kind: Launch2LoopDynamicPool(
            _state(armed: true, drop: '200000000000000000', mine: '45.5'),
          ),
        ),
      );
      expect(_key('launch2-dyn-armed'), findsOneWidget);
      expect(find.text('已激活'), findsOneWidget);
      expect(_key('launch2-dyn-idle-line'), findsNothing);
      expect(find.text('20%'), findsOneWidget);
      expect(find.text('120.5 USD1'), findsOneWidget);
      expect(find.text('出现一根收绿的 5 分钟 K 线即结束'), findsOneWidget);
      expect(find.text('45.5 USD1'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('LoopDynamic, armed and back at the open: 0% while the round '
        'runs; no account weight reads 暂无', (tester) async {
      await _openInstance(
        tester,
        launch2: _FakeLaunch2(),
        dynamicPool: _FakeDynamic(
          kind: Launch2LoopDynamicPool(_state(armed: true, mine: null)),
        ),
      );
      expect(_key('launch2-dyn-armed'), findsOneWidget);
      expect(
        tester.widget<Text>(
          find.descendant(
            of: _key('launch2-dyn-drop'),
            matching: find.text('0%'),
          ),
        ),
        isNotNull,
      );
      expect(find.text('出现一根收绿的 5 分钟 K 线即结束'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('launch2-dyn-my-weight'),
          matching: find.text('暂无'),
        ),
        findsOneWidget,
      );
      await _drain(tester);
    });

    testWidgets('the dynamic panel quotes exactIn; a buy shows the weight, a '
        'sell the dynamic tax', (tester) async {
      final launch2 = _FakeLaunch2(
        quoteAnswer: (side) async => side == Launch2Side.buy
            ? _quote(side: side, rewardWeight: '98')
            : _quote(side: side),
      );
      await _openInstance(
        tester,
        launch2: launch2,
        dynamicPool: _FakeDynamic(
          kind: Launch2LoopDynamicPool(
            _state(armed: true, drop: '200000000000000000'),
          ),
        ),
      );
      await _type(tester, '100');
      expect(launch2.quoteModes.last, Launch2PoolMode.exactIn);
      expect(find.text('外盘税 2%（扣 MEME）'), findsOneWidget);
      expect(find.text('本笔计入本轮奖励权重'), findsOneWidget);
      expect(find.text('98 USD1'), findsOneWidget);
      await _scrollTo(tester, _key('launch2-pool-side'));
      await tester.tap(find.text('卖出').first);
      await tester.pumpAndSettle();
      await _type(tester, '1000');
      expect(find.text('基础税 2% + 当前动态税（扣 USD1）'), findsOneWidget);
      expect(find.text('成交后按跌幅计'), findsOneWidget);
      expect(
        launch2.quoteModes.every((m) => m == Launch2PoolMode.exactIn),
        isTrue,
      );
      await _drain(tester);
    });

    testWidgets('an exactOut refusal from the server reads in Chinese', (
      tester,
    ) async {
      await _openInstance(
        tester,
        launch2: _FakeLaunch2(
          quoteAnswer: (_) => Future<Launch2PoolQuote>.error(
            const LoopChainException(
              LoopChainFailureKind.validationFailed,
              reasonCode: 'LAUNCH2_EXACT_OUT_UNSUPPORTED',
            ),
          ),
        ),
        dynamicPool: _FakeDynamic(kind: Launch2LoopDynamicPool(_state())),
      );
      await _type(tester, '100');
      expect(find.text('没有取到报价 · 这个项目只支持按支付金额买入'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('外盘奖励 page', () {
    Future<void> openRewards(
      WidgetTester tester,
      _FakeDynamic dynamicPool, {
      _RecordingWallet? wallet,
    }) => _pump(
      tester,
      const Launch2DynamicRewardsScreen(instanceId: l2InstanceA),
      launch2: _FakeLaunch2(),
      dynamicPool: dynamicPool,
      wallet: wallet,
    );

    testWidgets('an OfficialTax instance, or no adapter, has no rounds', (
      tester,
    ) async {
      final official = _FakeDynamic(kind: const Launch2OfficialTaxPool());
      await openRewards(tester, official);
      expect(_key('launch2-dyn-rewards-none'), findsOneWidget);
      expect(official.rewardReads, 0);
      await _drain(tester);
      await _pump(
        tester,
        const Launch2DynamicRewardsScreen(instanceId: l2InstanceA),
        launch2: _FakeLaunch2(),
      );
      expect(_key('launch2-dyn-rewards-none'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('an invalid id asks nothing', (tester) async {
      final dynamicPool = _FakeDynamic(kind: Launch2LoopDynamicPool(_state()));
      await _pump(
        tester,
        const Launch2DynamicRewardsScreen(instanceId: 'nope'),
        launch2: _FakeLaunch2(),
        dynamicPool: dynamicPool,
      );
      expect(_key('launch2-dyn-rewards-invalid-identity'), findsOneWidget);
      expect(dynamicPool.kindReads, 0);
      await _drain(tester);
    });

    testWidgets('no rounds yet: the empty state', (tester) async {
      await openRewards(
        tester,
        _FakeDynamic(
          kind: Launch2LoopDynamicPool(_state()),
          rewards: _rewards(const <Map<String, Object?>>[]),
        ),
      );
      expect(_key('launch2-dyn-rewards-empty'), findsOneWidget);
      expect(find.text('还没有外盘奖励'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('a failed read is the offline state with a retry', (
      tester,
    ) async {
      await openRewards(
        tester,
        _FakeDynamic(kind: Launch2LoopDynamicPool(_state())),
      );
      expect(_key('launch2-dyn-rewards-state-offline'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('rounds list: span, weights, claimable, claimed; only a '
        'closed unclaimed round can be claimed', (tester) async {
      await openRewards(
        tester,
        _FakeDynamic(
          kind: Launch2LoopDynamicPool(_state(armed: true)),
          rewards: _rewards(<Map<String, Object?>>[
            _roundJson(roundId: '9', closed: false),
            _roundJson(roundId: '8'),
            _roundJson(claimable: '0', claimed: '3'),
          ]),
        ),
      );
      expect(find.text('第 9 轮'), findsOneWidget);
      expect(find.text('K 线 #5684100 起 · 进行中'), findsOneWidget);
      expect(find.text('K 线 #5684100 – #5684107'), findsNWidgets(2));
      expect(find.text('进行中'), findsOneWidget);
      expect(find.text('90 / 720 USD1'), findsNWidgets(3));
      expect(find.text('12.5 USD1'), findsOneWidget);
      VoidCallback? onPressed(String id) =>
          (tester.widget<Widget>(
                _key('launch2-dyn-claim-$id'),
              ) as dynamic).onPressed
              as VoidCallback?;
      expect(onPressed('9'), isNull);
      expect(find.text('本轮结束后可领'), findsOneWidget);
      expect(onPressed('8'), isNotNull);
      expect(onPressed('7'), isNull);
      expect(find.text('已领取'), findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await _drain(tester);
    });

    testWidgets('领取 goes through the MEME v2 signing exit, reports the '
        'broadcast and locks the round', (tester) async {
      final wallet = _RecordingWallet();
      final dynamicPool = _FakeDynamic(
        kind: Launch2LoopDynamicPool(_state()),
        rewards: _rewards(<Map<String, Object?>>[_roundJson()]),
        rewardsAfterClaim: _rewards(<Map<String, Object?>>[
          _roundJson(claimable: '0', claimed: '12.5'),
        ]),
        claim: () async => _claimIntent(),
      );
      await openRewards(tester, dynamicPool, wallet: wallet);
      await tester.tap(_key('launch2-dyn-claim-7'));
      await tester.pumpAndSettle();
      expect(dynamicPool.claimRounds.single, BigInt.from(7));
      expect(_key('launch2-sign-sheet'), findsOneWidget);
      expect(find.text('确认领取外盘奖励'), findsOneWidget);
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(wallet.handed.single.kind, IntentKind.launchPurchase);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(dynamicPool.reports.single, '7:$l2IntentId:$_txHash');
      expect(_key('launch2-dyn-claim-pending'), findsOneWidget);
      expect(find.text('外盘奖励已领取，已在链上确认。'), findsOneWidget);
      expect(find.text('已领取'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('a refusal stays above the round\'s button; an intent to '
        'another contract is refused before the wallet', (tester) async {
      final wallet = _RecordingWallet();
      var answer = 0;
      final dynamicPool = _FakeDynamic(
        kind: Launch2LoopDynamicPool(_state()),
        rewards: _rewards(<Map<String, Object?>>[_roundJson()]),
        claim: () async {
          answer += 1;
          if (answer == 1) {
            throw const LoopChainException(
              LoopChainFailureKind.validationFailed,
              reasonCode: 'LAUNCH2_ALREADY_CLAIMED',
            );
          }
          return _claimIntent(to: l2Router);
        },
      );
      await openRewards(tester, dynamicPool, wallet: wallet);
      await tester.tap(_key('launch2-dyn-claim-7'));
      await tester.pumpAndSettle();
      expect(_key('launch2-dyn-claim-failed-7'), findsOneWidget);
      expect(find.text('这一轮已经领过'), findsOneWidget);
      await tester.tap(_key('launch2-dyn-claim-7'));
      await tester.pumpAndSettle();
      expect(_key('launch2-sign-sheet'), findsNothing);
      expect(wallet.handed, isEmpty);
      expect(find.textContaining('交易内容与确认内容不一致'), findsOneWidget);
      await _drain(tester);
    });
  });
}

final class _Script implements HttpClientAdapter {
  _Script(this.answers, this.requests);

  final List<(int, Object?)> answers;
  final List<RequestOptions> requests;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = answers.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>[_requestId],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
