import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_rewards_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_dynamic_pool_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_dynamic_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// S168 / S168b · the LoopDynamic 外盘 Hook kind (client decisions 0157, 0159)
// ---------------------------------------------------------------------------
//
// Every payload below comes from test/fixtures/s168b-launch2-dynamic/, written
// by hand from loop-api frontend-v2-launch2-api.md §3.12 and the openapi
// schemas (来源：frontend-v2-launch2-api.md §3.12，待真实抓包替换).

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _requestId = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
const String _txHash =
    '0x3000000000000000000000000000000000000000000000000000000000000003';
const String _dynHook = '0xcccccccccccccccccccccccccccccccccccc10c4';

Map<String, Object?> _copy(Object? value) =>
    jsonDecode(jsonEncode(value)) as Map<String, Object?>;

Map<String, Object?> _file(String dir, String name) =>
    jsonDecode(File('test/fixtures/$dir/$name.json').readAsStringSync())
        as Map<String, Object?>;

/// One S168b fixture's response body (a fresh copy).
Map<String, Object?> _fx(String name) =>
    _copy(_file('s168b-launch2-dynamic', name)['body']);

Map<String, Object?> _s146(String name) =>
    _copy(_file('s146-launch2-pool', name)['body']);

Launch2PoolKind _kind(Map<String, Object?> body) =>
    LoopV2Launch2DynamicPoolCodec.pool(body, instanceId: l2InstanceA);

/// The `dynamicPool` object of a fixture, to edit before decoding.
Map<String, Object?> _poolJson(String name) =>
    _fx(name)['dynamicPool']! as Map<String, Object?>;

Launch2PoolKind _kindWith(Map<String, Object?> pool) =>
    _kind(<String, Object?>{'dynamicPool': pool, 'contractVersion': '2.0'});

Launch2DynamicPoolState _state({
  bool armed = false,
  void Function(Map<String, Object?> pool)? edit,
}) {
  final pool = _poolJson(
    armed ? 'dynamic_pool_active_armed' : 'dynamic_pool_active_idle',
  );
  edit?.call(pool);
  return (_kindWith(pool) as Launch2LoopDynamicPool).state;
}

Launch2DynamicRewards _rewards([String name = 'dynamic_rewards']) =>
    LoopV2Launch2DynamicPoolCodec.rewards(
      _fx(name),
      instanceId: l2InstanceA,
      walletId: l2WalletId,
    );

Launch2DynamicRewards _rewardsWith(
  void Function(List<Map<String, Object?>> rounds) edit,
) {
  final body = _fx('dynamic_rewards');
  final rounds = (body['rounds']! as List<Object?>)
      .cast<Map<String, Object?>>();
  edit(rounds);
  return LoopV2Launch2DynamicPoolCodec.rewards(
    body,
    instanceId: l2InstanceA,
    walletId: l2WalletId,
  );
}

Launch2DynamicClaimPrepared _prepared([Map<String, Object?>? body]) =>
    LoopV2Launch2DynamicPoolCodec.claimPrepared(
      body ?? _fx('dynamic_claim_prepare'),
      instanceId: l2InstanceA,
      walletId: l2WalletId,
      roundId: BigInt.two,
    );

Launch2DynamicClaimReport _report(String name) =>
    LoopV2Launch2DynamicPoolCodec.report(
      _fx(name),
      instanceId: l2InstanceA,
      walletId: l2WalletId,
      roundId: BigInt.two,
      intentId: l2IntentId,
      transactionHash: _txHash,
    );

Launch2PoolQuote _quote(Launch2Side side, [Map<String, Object?>? body]) =>
    LoopV2Launch2PoolCodec.quote(
      body ??
          _fx(
            side == Launch2Side.buy
                ? 'pool_quote_buy_dynamic'
                : 'pool_quote_sell_dynamic',
          ),
      instanceId: l2InstanceA,
      side: side,
      mode: Launch2PoolMode.exactIn,
      walletId: l2WalletId,
    );

Map<String, Object?> _quoteDynamic(Map<String, Object?> body) =>
    (body['quote']! as Map<String, Object?>)['dynamic']!
        as Map<String, Object?>;

Launch2InstanceDetail _graduated() =>
    l2Detail(stage: 'graduated', noNextChange: true, pool: l2PoolSummaryJson());

final Matcher _invalid = throwsA(isA<LoopBackendFailure>());

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
    this.reportName = 'dynamic_claim_report_submitted',
  });

  Launch2PoolKind kind;

  /// When set, the next kind reads fail with it.
  LoopChainException? kindError;
  final Launch2DynamicRewards? rewards;
  final Launch2DynamicRewards? rewardsAfterClaim;
  final Future<Launch2DynamicClaimPrepared> Function()? claim;
  final String reportName;
  int kindReads = 0;
  int rewardReads = 0;
  final List<String> rewardWallets = <String>[];
  final List<BigInt> claimRounds = <BigInt>[];
  final List<String> reports = <String>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2PoolKind> loadPoolKind(String instanceId) {
    kindReads += 1;
    final error = kindError;
    if (error != null) return Future<Launch2PoolKind>.error(error);
    return Future<Launch2PoolKind>.value(kind);
  }

  @override
  Future<Launch2DynamicRewards> loadRewards({
    required String instanceId,
    required String walletId,
  }) {
    rewardReads += 1;
    rewardWallets.add(walletId);
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
  Future<Launch2DynamicClaimPrepared> prepareClaim({
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
      LoopV2Launch2DynamicPoolCodec.report(
        _fx(reportName),
        instanceId: instanceId,
        walletId: walletId,
        roundId: roundId,
        intentId: intentId,
        transactionHash: transactionHash,
      ),
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
  'launch2-dyn-unavailable',
];

void main() {
  loopWatchGround();

  group('codec (§3.12, decision 0159)', () {
    test('dynamic-pool: officialTax / not_applicable and loopDynamic / '
        'not_graduated carry only the four set keys', () {
      expect(
        _kind(_fx('dynamic_pool_not_applicable')),
        isA<Launch2OfficialTaxPool>(),
      );
      expect(
        _kind(_fx('dynamic_pool_not_graduated')),
        isA<Launch2LoopDynamicNotGraduated>(),
      );
      // A null-only answer with any other key set is invalid.
      final leaked = _poolJson('dynamic_pool_not_applicable')
        ..['armed'] = false;
      expect(() => _kindWith(leaked), _invalid);
      // officialTax is never active; loopDynamic is never not_applicable.
      final wrong = _poolJson('dynamic_pool_not_applicable')
        ..['status'] = 'active';
      expect(() => _kindWith(wrong), _invalid);
      final wrong2 = _poolJson('dynamic_pool_not_graduated')
        ..['status'] = 'not_applicable';
      expect(() => _kindWith(wrong2), _invalid);
      // Another instance's answer is refused.
      final other = _poolJson('dynamic_pool_not_applicable')
        ..['instanceId'] = l2InstanceB;
      expect(() => _kindWith(other), _invalid);
      expect(
        () => _kind(<String, Object?>{
          'dynamicPool': _poolJson('dynamic_pool_not_applicable'),
        }),
        _invalid,
      );
    });

    test('dynamic-pool active: amounts are decimal strings, ids integer '
        'strings, counts and bps JSON integers', () {
      final armed = _state(armed: true);
      expect(armed.hook, _dynHook);
      expect(armed.armed, isTrue);
      expect(armed.currentRoundId, BigInt.from(3));
      expect(armed.candleId, BigInt.from(6000000));
      expect(armed.candleSeconds, 300);
      expect(armed.currentDropWad, Decimal.parse('0.3'));
      expect(armed.currentDropBps, 3000);
      expect(armed.potUsd1, Decimal.fromInt(45));
      expect(armed.roundTotalBuyWeightUsd1, Decimal.fromInt(100));
      expect(armed.viewer!.currentRoundWeightUsd1, Decimal.fromInt(25));
      expect(armed.viewerSharePercent, Decimal.fromInt(25));
      expect(armed.routingPolicy, Launch2RoutingPolicy.open);
      expect(armed.priceTiming, Launch2PriceTiming.postSwap);
      expect(armed.summary.roundCount, 3);
      expect(armed.summary.closedRoundCount, 2);
      expect(armed.basisBlockNumber, BigInt.from(6000));
      final idle = _state();
      expect(idle.armed, isFalse);
      expect(idle.currentRoundId, isNull);
      expect(idle.viewerSharePercent, isNull);
      // The S168 guesses are refused now.
      for (final edit in <void Function(Map<String, Object?>)>[
        (p) => p['currentDropWad'] = '300000000000000000',
        (p) => p['currentDropBps'] = '3000',
        (p) => p['potUsd1'] = 45,
        (p) => p['candleSeconds'] = 60,
        (p) => p['currentRoundId'] = 3,
        (p) => p['currentRoundId'] = null,
        (p) => p['routingPolicy'] = 'LOOP_ROUTER_ONLY',
        (p) => p['hook'] = null,
        (p) => p['viewer'] = <String, Object?>{
          'walletId': l2WalletId,
          'currentRoundWeightUsd1': '101',
        },
        (p) => p['hookAddress'] = _dynHook,
        (p) => (p['summary']! as Map<String, Object?>)['roundCount'] = '3',
      ]) {
        final pool = _poolJson('dynamic_pool_active_armed');
        edit(pool);
        expect(() => _kindWith(pool), _invalid);
      }
      // No wallet: viewer null.
      expect(
        _state(armed: true, edit: (p) => p['viewer'] = null).viewer,
        isNull,
      );
    });

    test('rewards: status per round, allocation null while open, '
        'claimedUsd1 only when claimed; ids unique; walletId echoed', () {
      final rewards = _rewards();
      expect(rewards.claimableUsd1, Decimal.fromInt(10));
      expect(rewards.claimedUsd1, Decimal.fromInt(5));
      final [open, claimable, claimed] = rewards.rounds;
      expect(open.status, Launch2DynamicRoundStatus.open);
      expect(open.allocationUsd1, isNull);
      expect(open.endCandle, isNull);
      expect(open.canClaim, isFalse);
      expect(claimable.status, Launch2DynamicRoundStatus.claimable);
      expect(claimable.allocationUsd1, Decimal.fromInt(30));
      expect(claimable.claimableUsd1, Decimal.fromInt(10));
      expect(claimable.claimedUsd1, isNull);
      expect(claimable.canClaim, isTrue);
      expect(claimed.alreadyClaimed, isTrue);
      expect(claimed.claimedUsd1, Decimal.fromInt(5));
      expect(claimed.claimTransactionHash, isNotNull);
      expect(claimed.canClaim, isFalse);
      expect(_rewards('dynamic_rewards_official_tax').rounds, isEmpty);
      for (final edit in <void Function(List<Map<String, Object?>>)>[
        (r) => r[0]['endCandle'] = '6000000',
        (r) => r[0]['allocationUsd1'] = '1',
        (r) => r[1]['endCandle'] = null,
        (r) => r[1]['endCandle'] = '99',
        (r) => r[1]['claimedUsd1'] = '1',
        (r) => r[2]['claimedUsd1'] = null,
        (r) => r[1]['status'] = 'closed',
        (r) => r[1]['claimed'] = false,
        (r) => r[1]['weightUsd1'] = '301',
        (r) => r[2]['roundId'] = '2',
        (r) => r[1]['startCandle'] = 100,
      ]) {
        expect(() => _rewardsWith(edit), _invalid);
      }
      expect(
        () => LoopV2Launch2DynamicPoolCodec.rewards(
          _fx('dynamic_rewards'),
          instanceId: l2InstanceA,
          walletId: 'a64786bb-408d-415d-8a69-6277d56c921b',
        ),
        _invalid,
      );
    });

    test('claim prepare: {launch2Intent, claim, contractVersion}; one kind, '
        'no approval, the claim\'s Hook and round', () {
      final prepared = _prepared();
      expect(prepared.intent.kind, Launch2IntentKind.rewardClaim);
      expect(prepared.intent.venue, Launch2Venue.loopDynamicRewards);
      expect(prepared.intent.payloadMatchesReview, isTrue);
      expect(prepared.intent.expectedOut, Decimal.fromInt(10));
      expect(prepared.claim.roundId, BigInt.two);
      expect(prepared.claim.hook, _dynHook);
      expect(prepared.claim.claimableUsd1, Decimal.fromInt(10));
      Map<String, Object?> edited(void Function(Map<String, Object?>) edit) =>
          _fx('dynamic_claim_prepare')..let(edit);
      for (final edit in <void Function(Map<String, Object?>)>[
        (b) =>
            (b['launch2Intent']! as Map<String, Object?>)['kind'] = 'pool_sell',
        (b) => (b['claim']! as Map<String, Object?>)['roundId'] = '3',
        (b) => (b['claim']! as Map<String, Object?>)['hook'] = l2Router,
        (b) => b.remove('claim'),
        (b) => b.remove('contractVersion'),
      ]) {
        expect(() => _prepared(edited(edit)), _invalid);
      }
      // The curve routes never answer a claim.
      expect(
        () => LoopV2Launch2Codec.intentBody(
          _fx('dynamic_claim_prepare')['launch2Intent'],
        ),
        _invalid,
      );
    });

    test('claim report: submitted until the indexer has RewardClaimed; '
        'confirmed carries the amount; every echo is checked', () {
      final submitted = _report('dynamic_claim_report_submitted');
      expect(submitted.status, Launch2DynamicClaimStatus.submitted);
      expect(submitted.confirmed, isFalse);
      expect(submitted.amountUsd1, isNull);
      final confirmed = _report('dynamic_claim_report_confirmed');
      expect(confirmed.confirmed, isTrue);
      expect(confirmed.amountUsd1, Decimal.fromInt(10));
      expect(confirmed.blockNumber, BigInt.from(6010));
      Launch2DynamicClaimReport edited(void Function(Map<String, Object?>) e) {
        final body = _fx('dynamic_claim_report_confirmed');
        e(body['dynamicClaimReport']! as Map<String, Object?>);
        return LoopV2Launch2DynamicPoolCodec.report(
          body,
          instanceId: l2InstanceA,
          walletId: l2WalletId,
          roundId: BigInt.two,
          intentId: l2IntentId,
          transactionHash: _txHash,
        );
      }

      for (final edit in <void Function(Map<String, Object?>)>[
        (r) => r['status'] = 'failed',
        (r) => r['amountUsd1'] = null,
        (r) => r['roundId'] = '3',
        (r) => r['transactionHash'] = '0x4000000000000000000000000000000000000000000000000000000000000004',
        (r) => r['walletId'] = 'a64786bb-408d-415d-8a69-6277d56c921b',
        (r) => r['blockNumber'] = 6010,
      ]) {
        expect(() => edited(edit), _invalid);
      }
    });

    test('pool quote: `dynamic` is one optional object; taxBps is the base, '
        'taxAmount base + dynamic, expectedOut already net', () {
      final official = LoopV2Launch2PoolCodec.quote(
        _s146('pool_quote_buy_exact_in'),
        instanceId: l2InstanceA,
        side: Launch2Side.buy,
        mode: Launch2PoolMode.exactIn,
        walletId: l2WalletId,
      );
      expect(official.loopDynamic, isNull);
      final sell = _quote(Launch2Side.sell);
      final dyn = sell.loopDynamic!;
      expect(sell.taxBps, 200);
      expect(dyn.baseTaxBps, 200);
      expect(dyn.dynamicTaxBps, 3000);
      expect(dyn.baseTaxAmount + dyn.dynamicTaxAmount, sell.taxAmount);
      expect(sell.expectedOut, Decimal.parse('68.6'));
      final buy = _quote(Launch2Side.buy);
      expect(buy.loopDynamic!.rewardWeight, Decimal.fromInt(100));
      expect(buy.loopDynamic!.armed, isTrue);
      for (final edit in <void Function(Map<String, Object?>)>[
        (d) => d['hookKind'] = 'officialTax',
        (d) => d['hook'] = l2Hook,
        (d) => d['baseTaxBps'] = 300,
        (d) => d['dynamicTaxBps'] = '3000',
        (d) => d['rewardWeight'] = '1',
        (d) => d['extra'] = 1,
      ]) {
        final body = _fx('pool_quote_sell_dynamic');
        edit(_quoteDynamic(body));
        expect(() => _quote(Launch2Side.sell, body), _invalid);
      }
      // The S168 top-level keys are gone.
      final flat = _s146('pool_quote_buy_exact_in');
      (flat['quote']! as Map<String, Object?>)['rewardWeight'] = '98';
      expect(
        () => LoopV2Launch2PoolCodec.quote(
          flat,
          instanceId: l2InstanceA,
          side: Launch2Side.buy,
          mode: Launch2PoolMode.exactIn,
          walletId: l2WalletId,
        ),
        _invalid,
      );
    });
  });

  group('pool kind controller', () {
    test('a closed capability before any answer is OfficialTax; after a '
        'LoopDynamic answer it is 外盘暂不可用, never OfficialTax', () async {
      final fake = _FakeDynamic(kind: Launch2LoopDynamicPool(_state()))
        ..kindError = const LoopChainException(
          LoopChainFailureKind.unavailable,
          reasonCode: 'LAUNCH2_CHAIN_READ_FAILED',
        );
      final container = ProviderContainer(
        overrides: <Override>[
          launch2DynamicPoolGatewayProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      final provider = launch2PoolKindControllerProvider(l2InstanceA);
      final sub = container.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await container.read(provider.notifier).reload();
      expect(container.read(provider).value, isA<Launch2OfficialTaxPool>());
      // A fresh block that first reads LoopDynamic.
      fake.kindError = null;
      container.invalidate(provider);
      final sub2 = container.listen(provider, (_, _) {});
      addTearDown(sub2.close);
      await container.read(provider.notifier).reload();
      expect(container.read(provider).value, isA<Launch2LoopDynamicPool>());
      fake.kindError = const LoopChainException(
        LoopChainFailureKind.unavailable,
        reasonCode: 'LAUNCH2_CHAIN_READ_FAILED',
      );
      await container.read(provider.notifier).reload();
      final kind = container.read(provider).value;
      expect(kind, isA<Launch2LoopDynamicUnavailable>());
      expect(
        (kind as Launch2LoopDynamicUnavailable).reasonCode,
        'LAUNCH2_CHAIN_READ_FAILED',
      );
      // Any other failure keeps the last answer on screen.
      fake.kindError = const LoopChainException(LoopChainFailureKind.offline);
      await container.read(provider.notifier).reload();
      expect(
        container.read(provider).value,
        isA<Launch2LoopDynamicUnavailable>(),
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

    Map<String, Object?> error(
      String code,
      String category, [
      String? reason,
    ]) => <String, Object?>{
      'code': code,
      'category': category,
      'retryable': false,
      'userMessageKey': 'errors.test',
      'correlationId': _requestId,
      'detailsSafe': reason == null
          ? null
          : <String, Object?>{'reasonCode': reason},
      'providerReferenceSafe': null,
    };

    test(
      '200 answers the kind; 404 (no route) is OfficialTax; a 503 with a '
      'LoopDynamic reason is unavailable; other failures are thrown',
      () async {
        final (client, requests) = api(<(int, Object?)>[
          (200, _fx('dynamic_pool_not_applicable')),
          (200, _fx('dynamic_pool_active_armed')),
          (200, _fx('dynamic_pool_not_graduated')),
          (404, <String, Object?>{'message': 'Route not found'}),
          (503, _fx('error_dynamic_hook_not_indexed')),
          (
            503,
            error(
              'CAPABILITY_UNAVAILABLE',
              'availability',
              'LAUNCH2_CHAIN_READ_FAILED',
            ),
          ),
          (500, error('INTERNAL_ERROR', 'internal')),
        ]);
        Future<Launch2PoolKind> read() => client.getPoolKind(
          accessToken: 'token',
          clientVersion: '1.0.0',
          instanceId: l2InstanceA,
        );
        expect(await read(), isA<Launch2OfficialTaxPool>());
        expect(
          requests.single.path,
          '/v2/launch2/instances/$l2InstanceA/dynamic-pool',
        );
        expect(await read(), isA<Launch2LoopDynamicPool>());
        expect(await read(), isA<Launch2LoopDynamicNotGraduated>());
        expect(await read(), isA<Launch2OfficialTaxPool>());
        final unavailable = await read();
        expect(unavailable, isA<Launch2LoopDynamicUnavailable>());
        expect(
          (unavailable as Launch2LoopDynamicUnavailable).reasonCode,
          'LAUNCH2_DYNAMIC_HOOK_NOT_INDEXED',
        );
        await expectLater(read(), throwsA(isA<LoopBackendFailure>()));
        await expectLater(read(), throwsA(isA<LoopBackendFailure>()));
      },
    );

    test('rewards: walletId in the query', () async {
      final (client, requests) = api(<(int, Object?)>[
        (200, _fx('dynamic_rewards')),
      ]);
      final rewards = await client.getRewards(
        accessToken: 'token',
        clientVersion: '1.0.0',
        instanceId: l2InstanceA,
        walletId: l2WalletId,
      );
      expect(rewards.rounds, hasLength(3));
      final request = requests.single;
      expect(
        request.path,
        '/v2/launch2/instances/$l2InstanceA/dynamic-pool/rewards',
      );
      expect(request.queryParameters, <String, Object?>{
        'walletId': l2WalletId,
      });
    });

    test(
      'claim prepare: 201, body {walletId, roundId}, an idempotency key',
      () async {
        final (client, requests) = api(<(int, Object?)>[
          (201, _fx('dynamic_claim_prepare')),
        ]);
        final prepared = await client.postClaimPrepare(
          accessToken: 'token',
          clientVersion: '1.0.0',
          idempotencyKey: '0d3b2a6c-6c55-4b8d-9e7f-1a2b3c4d5e6f',
          instanceId: l2InstanceA,
          walletId: l2WalletId,
          roundId: BigInt.two,
        );
        expect(prepared.intent.kind, Launch2IntentKind.rewardClaim);
        final request = requests.single;
        expect(
          request.path,
          '/v2/launch2/instances/$l2InstanceA/dynamic-pool/claim/prepare',
        );
        expect(request.data, <String, Object?>{
          'walletId': l2WalletId,
          'roundId': '2',
        });
        expect(request.headers['Idempotency-Key'], isNotNull);
      },
    );

    test('claim report: 200, body {intentId, transactionHash, walletId, '
        'roundId}; a 409 RESOURCE_CONFLICT keeps its reason', () async {
      final (client, requests) = api(<(int, Object?)>[
        (200, _fx('dynamic_claim_report_confirmed')),
        (409, _fx('error_dynamic_already_claimed')),
      ]);
      final report = await client.postClaimReport(
        accessToken: 'token',
        clientVersion: '1.0.0',
        idempotencyKey: '0d3b2a6c-6c55-4b8d-9e7f-1a2b3c4d5e6f',
        instanceId: l2InstanceA,
        walletId: l2WalletId,
        roundId: BigInt.two,
        intentId: l2IntentId,
        transactionHash: _txHash,
      );
      expect(report.confirmed, isTrue);
      expect(
        requests.single.path,
        '/v2/launch2/instances/$l2InstanceA/dynamic-pool/claim/report',
      );
      expect(requests.single.data, <String, Object?>{
        'intentId': l2IntentId,
        'transactionHash': _txHash,
        'walletId': l2WalletId,
        'roundId': '2',
      });
      await expectLater(
        client.postClaimPrepare(
          accessToken: 'token',
          clientVersion: '1.0.0',
          idempotencyKey: '0d3b2a6c-6c55-4b8d-9e7f-1a2b3c4d5e6f',
          instanceId: l2InstanceA,
          walletId: l2WalletId,
          roundId: BigInt.two,
        ),
        throwsA(
          isA<LoopBackendFailure>()
              .having((f) => f.code, 'code', 'RESOURCE_CONFLICT')
              .having(
                (f) => f.detailsSafe?.reasonCode,
                'reasonCode',
                'LAUNCH2_DYNAMIC_ALREADY_CLAIMED',
              ),
        ),
      );
    });
  });

  group('view model and copy', () {
    test('every §3.12.6 reason reads exactly the server copy; the S168 '
        'guesses are gone', () {
      const table = <String, String>{
        'LAUNCH2_DYNAMIC_ROUTER_NOT_CONFIGURED': '外盘路由未配置，暂不可交易',
        'LAUNCH2_DYNAMIC_ROUTER_CODE_MISMATCH': '外盘路由校验未通过，暂不可交易',
        'LAUNCH2_DYNAMIC_ROUTER_MANAGER_MISMATCH': '外盘路由与池子不匹配，暂不可交易',
        'LAUNCH2_DYNAMIC_HOOK_NOT_INDEXED': '外盘池子正在同步，请稍后再试',
        'LAUNCH2_DYNAMIC_HOOK_MISMATCH': '外盘池子校验未通过，暂不可交易',
        'LAUNCH2_DYNAMIC_HOOK_NOT_INITIALIZED': '外盘池子尚未初始化',
        'LAUNCH2_EXACT_OUT_UNSUPPORTED': '该池子只支持按支付金额交易',
        'LAUNCH2_DYNAMIC_POOL_NOT_APPLICABLE': '该项目的外盘没有奖励轮次',
        'LAUNCH2_DYNAMIC_ROUND_INVALID': '轮次编号无效',
        'LAUNCH2_DYNAMIC_ROUTER_UNAUTHORIZED': '池子拒绝了这个交易入口',
        'LAUNCH2_DYNAMIC_SWAP_UNSUPPORTED': '池子不支持这种交易方式',
        'LAUNCH2_DYNAMIC_HOOK_BUSY': '池子正忙，请稍后重试',
        'LAUNCH2_DYNAMIC_ROUND_NOT_CLOSED': '本轮还没有结束，结束后才能领取',
        'LAUNCH2_DYNAMIC_ALREADY_CLAIMED': '本轮奖励已经领取过',
        'LAUNCH2_DYNAMIC_CLAIM_TRANSACTION_CONFLICT': '这次领取已经记录了另一笔交易',
        'LAUNCH2_DYNAMIC_NOTHING_TO_CLAIM': '本轮没有可领取的奖励',
        'LAUNCH2_DYNAMIC_CLAIM_INTENT_NOT_FOUND': '找不到这次领取请求',
      };
      expect(launch2DynamicReasonMessagesZh, table);
      table.forEach((code, text) {
        expect(launch2PoolReasonText(code), text, reason: code);
      });
      for (final guess in <String>[
        'UNAUTHORIZED_ROUTER',
        'POOL_BUSY',
        'ROUND_NOT_CLOSED',
        'LAUNCH2_ALREADY_CLAIMED',
      ]) {
        expect(launch2DynamicReasonText(guess), isNull, reason: guess);
      }
      expect(
        launch2PoolReasonText('POOL_QUOTE_UNAVAILABLE'),
        '官方池试算没有通过，换个金额再试',
      );
    });

    test('an OfficialTax quote reads exactly as before', () {
      final quote = LoopV2Launch2PoolCodec.quote(
        _s146('pool_quote_buy_exact_in'),
        instanceId: l2InstanceA,
        side: Launch2Side.buy,
        mode: Launch2PoolMode.exactIn,
        walletId: l2WalletId,
      );
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

    test('a LoopDynamic buy says the MEME tax and the weight; a sell the '
        'base + dynamic tax from quote.dynamic, with the split', () {
      final buy = launch2PoolQuoteLines(_quote(Launch2Side.buy), 'FROG');
      expect(
        buy.firstWhere((l) => l.key == 'tax').label,
        '基础税 2%（从到手的 MEME 扣）',
      );
      final weight = buy.firstWhere((l) => l.key == 'reward-weight');
      expect(weight.label, '本笔计入奖励权重');
      expect(weight.value, '100 USD1');
      final sell = launch2PoolQuoteLines(_quote(Launch2Side.sell), 'FROG');
      final tax = sell.firstWhere((l) => l.key == 'tax');
      expect(tax.label, '基础税 2% + 当前动态税 30%（扣 USD1）');
      expect(tax.value, '31.4 USD1');
      expect(sell.firstWhere((l) => l.key == 'tax-split').value, '29.4 USD1');
      expect(sell.firstWhere((l) => l.key == 'expected').value, '68.6 USD1');
      expect(sell.any((l) => l.key == 'reward-weight'), isFalse);
      // Not armed: no weight.
      final body = _fx('pool_quote_buy_dynamic');
      _quoteDynamic(body)
        ..['armed'] = false
        ..['roundId'] = null
        ..['rewardWeight'] = '0';
      final idle = launch2PoolQuoteLines(
        _quote(Launch2Side.buy, body),
        'FROG',
      ).firstWhere((l) => l.key == 'reward-weight');
      expect(idle.value, '当前未激活，不计奖励');
    });

    test('the project page says a step-up stop after the approval the way '
        'the MEME sheets do', () {
      for (final code in <String>[
        loopStepUpCancelledCode,
        loopStepUpFailedCode,
      ]) {
        expect(
          launch2ApprovalOnlyText(code, '买入'),
          loopStepUpAfterApprovalText,
          reason: code,
        );
      }
      expect(
        launch2ApprovalOnlyText('wallet_rejected', '买入'),
        '授权已广播，买入没有签名。可以重新发起。',
      );
    });

    test('the signing sheet names both halves of a LoopDynamic sell tax', () {
      final raw = _s146('pool_prepare_sell_ready')['launch2Intent'];
      final intent = LoopV2Launch2Codec.intentBody(
        raw,
        venue: Launch2Venue.officialPool,
        taxBps: 200,
        dynamicTaxBps: 3000,
      );
      final labels = launch2IntentFields(
        intent,
        ticker: 'FROG',
      ).map((field) => field.label).toList();
      expect(labels, contains('基础税 2% + 动态税 30%'));
      final plain = LoopV2Launch2Codec.intentBody(
        raw,
        venue: Launch2Venue.officialPool,
        taxBps: 200,
      );
      expect(
        launch2IntentFields(plain, ticker: 'FROG').map((f) => f.label),
        contains('外盘税 2%'),
      );
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

    testWidgets('officialTax / not_applicable: the S146 page, unchanged, and '
        'never asked again', (tester) async {
      final dynamicPool = _FakeDynamic(
        kind: _kind(_fx('dynamic_pool_not_applicable')),
      );
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

    testWidgets('a LoopDynamic Hook that cannot be read: 外盘暂不可用 with a '
        'retry, never the OfficialTax panel', (tester) async {
      final dynamicPool = _FakeDynamic(
        kind: const Launch2LoopDynamicUnavailable(
          'LAUNCH2_DYNAMIC_HOOK_NOT_INDEXED',
        ),
      );
      await _openInstance(
        tester,
        launch2: _FakeLaunch2(),
        dynamicPool: dynamicPool,
      );
      expect(_key('launch2-dyn-unavailable'), findsOneWidget);
      expect(find.text('外盘暂不可用'), findsOneWidget);
      expect(find.textContaining('外盘池子正在同步，请稍后再试'), findsOneWidget);
      expect(_key('launch2-pool-panel'), findsNothing);
      expect(_key('launch2-go-swap'), findsNothing);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      dynamicPool.kind = Launch2LoopDynamicPool(_state());
      await _scrollTo(tester, _key('launch2-dyn-unavailable-retry'));
      await tester.tap(_key('launch2-dyn-unavailable-retry'));
      await tester.pumpAndSettle();
      expect(dynamicPool.kindReads, 2);
      expect(_key('launch2-dyn-unavailable'), findsNothing);
      expect(_key('launch2-pool-panel'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('loopDynamic / not_graduated on a graduated page: the pool '
        'panel waits for the Hook', (tester) async {
      await _openInstance(
        tester,
        launch2: _FakeLaunch2(),
        dynamicPool: _FakeDynamic(
          kind: _kind(_fx('dynamic_pool_not_graduated')),
        ),
      );
      expect(_key('launch2-dyn-unavailable'), findsOneWidget);
      expect(_key('launch2-pool-panel'), findsNothing);
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
      // Decision 0169: the round's facts sit in one `.record-card`.
      expect(
        find.descendant(
          of: find.byType(LoopRecordCard),
          matching: _key('launch2-dyn-pot'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('launch2-dyn-round-card'),
          matching: _key('launch2-dyn-idle-line'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('launch2-dyn-pot'),
          matching: find.text('40 USD1'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(_key('launch2-dyn-round')).dy,
        lessThan(tester.getTopLeft(_key('launch2-pool-stats')).dy),
      );
      expect(_key('launch2-pool-mode-caption'), findsNothing);
      expect(_key('launch2-pool-mode-exactOut'), findsNothing);
      expect(find.text('用任何软件买入都计入奖励，记给收到 MEME 的地址'), findsOneWidget);
      expect(find.text('外盘税 2% + 卖出动态税'), findsOneWidget);
      expect(_key('launch2-go-swap'), findsNothing);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await tester.tap(_key('launch2-dyn-rewards-link'));
      expect(opened.single, Launch2Route.dynamicRewards(l2InstanceA));
      await _drain(tester);
    });

    testWidgets('LoopDynamic, armed 30% down: drop in bps, pot, my weight '
        'and share, candle end, end rule', (tester) async {
      final state = _state(armed: true);
      await _openInstance(
        tester,
        launch2: _FakeLaunch2(),
        dynamicPool: _FakeDynamic(kind: Launch2LoopDynamicPool(state)),
      );
      expect(_key('launch2-dyn-armed'), findsOneWidget);
      expect(find.text('已激活'), findsOneWidget);
      expect(_key('launch2-dyn-idle-line'), findsNothing);
      Finder inRow(String row, String text) => find.descendant(
        of: _key('launch2-dyn-$row'),
        matching: find.text(text),
      );
      expect(inRow('drop', '30%'), findsOneWidget);
      expect(inRow('pot', '45 USD1'), findsOneWidget);
      expect(inRow('my-weight', '25 USD1 · 占 25%'), findsOneWidget);
      expect(_key('launch2-dyn-candle-end'), findsOneWidget);
      expect(
        find.text('出现一根收盘不低于开盘的 5 分钟 K 线即结束（收涨、收平或无成交都算）'),
        findsOneWidget,
      );
      await _drain(tester);
    });

    testWidgets('armed with a roll pending, and no wallet: the drop waits '
        'for the next trade; the weight reads 暂无', (tester) async {
      await _openInstance(
        tester,
        launch2: _FakeLaunch2(),
        dynamicPool: _FakeDynamic(
          kind: Launch2LoopDynamicPool(
            _state(
              armed: true,
              edit: (p) => p
                ..['rollPending'] = true
                ..['currentDropWad'] = '0'
                ..['currentDropBps'] = 0
                ..['viewer'] = null,
            ),
          ),
        ),
      );
      expect(
        find.descendant(
          of: _key('launch2-dyn-drop'),
          matching: find.text('K 线已结束，待结算'),
        ),
        findsOneWidget,
      );
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
        'sell the base + dynamic tax', (tester) async {
      final launch2 = _FakeLaunch2(quoteAnswer: (side) async => _quote(side));
      await _openInstance(
        tester,
        launch2: launch2,
        dynamicPool: _FakeDynamic(
          kind: Launch2LoopDynamicPool(_state(armed: true)),
        ),
      );
      await _type(tester, '100');
      expect(launch2.quoteModes.last, Launch2PoolMode.exactIn);
      expect(find.text('基础税 2%（从到手的 MEME 扣）'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('launch2-pool-line-reward-weight'),
          matching: find.text('100 USD1'),
        ),
        findsOneWidget,
      );
      await _scrollTo(tester, _key('launch2-pool-side'));
      await tester.tap(find.text('卖出').first);
      await tester.pumpAndSettle();
      await _type(tester, '160000');
      expect(find.text('基础税 2% + 当前动态税 30%（扣 USD1）'), findsOneWidget);
      expect(find.text('31.4 USD1'), findsOneWidget);
      expect(find.text('29.4 USD1'), findsOneWidget);
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
      expect(find.text('没有取到报价 · 该池子只支持按支付金额交易'), findsOneWidget);
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
      final official = _FakeDynamic(
        kind: _kind(_fx('dynamic_pool_not_applicable')),
      );
      await openRewards(tester, official);
      expect(_key('launch2-dyn-rewards-none'), findsOneWidget);
      // Decision 0169: the illustrated empty state, not the old strip.
      expect(
        tester.widget(_key('launch2-dyn-rewards-none')),
        isA<LoopEmptyState>(),
      );
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

    testWidgets('a LoopDynamic Hook that cannot be read: 外盘暂不可用', (
      tester,
    ) async {
      final dynamicPool = _FakeDynamic(
        kind: const Launch2LoopDynamicUnavailable(
          'LAUNCH2_DYNAMIC_ROUTER_NOT_CONFIGURED',
        ),
      );
      await openRewards(tester, dynamicPool);
      expect(_key('launch2-dyn-unavailable'), findsOneWidget);
      expect(find.textContaining('外盘路由未配置，暂不可交易'), findsOneWidget);
      expect(dynamicPool.rewardReads, 0);
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
      expect(
        tester.widget(_key('launch2-dyn-rewards-invalid-identity')),
        isA<LoopEmptyState>(),
      );
      expect(dynamicPool.kindReads, 0);
      await _drain(tester);
    });

    testWidgets('no rounds yet: the empty state', (tester) async {
      await openRewards(
        tester,
        _FakeDynamic(
          kind: Launch2LoopDynamicPool(_state()),
          rewards: _rewardsWith((rounds) => rounds.clear()),
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

    testWidgets('rounds list: the active wallet is asked; span, weights, '
        'claimable, claimed; only a claimable round can be claimed', (
      tester,
    ) async {
      final dynamicPool = _FakeDynamic(
        kind: Launch2LoopDynamicPool(_state(armed: true)),
        rewards: _rewards(),
      );
      await openRewards(tester, dynamicPool);
      expect(dynamicPool.rewardWallets.toSet(), <String>{l2WalletId});
      expect(find.text('第 3 轮'), findsOneWidget);
      // Decision 0169: each round is a `.label` over one `.record-card`
      // that holds its key/value lines.
      expect(
        find.ancestor(of: find.text('第 3 轮'), matching: find.byType(LoopLabel)),
        findsOneWidget,
      );
      for (final id in <String>['3', '2', '1']) {
        final card = _key('launch2-dyn-round-$id-card');
        if (card.evaluate().isEmpty) continue;
        expect(tester.widget(card), isA<LoopRecordCard>());
        expect(
          find.descendant(
            of: card,
            matching: _key('launch2-dyn-round-$id-claimable'),
          ),
          findsOneWidget,
        );
      }
      expect(_key('launch2-dyn-round-3-card'), findsOneWidget);
      expect(find.text('K 线 #5999990 起 · 进行中'), findsOneWidget);
      expect(find.text('K 线 #100 – #104'), findsOneWidget);
      expect(find.text('K 线 #40 – #43'), findsOneWidget);
      expect(find.text('进行中'), findsOneWidget);
      expect(find.text('100 / 300 USD1'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('launch2-dyn-round-2-claimable'),
          matching: find.text('10 USD1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('launch2-dyn-round-1-claimed'),
          matching: find.text('5 USD1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('launch2-dyn-round-3-allocation'),
          matching: find.text('本轮结束后结算'),
        ),
        findsOneWidget,
      );
      VoidCallback? onPressed(String id) =>
          (tester.widget<Widget>(
                _key('launch2-dyn-claim-$id'),
              ) as dynamic).onPressed
              as VoidCallback?;
      expect(onPressed('3'), isNull);
      expect(find.text('本轮结束后可领'), findsOneWidget);
      expect(onPressed('2'), isNotNull);
      expect(onPressed('1'), isNull);
      expect(find.text('已领取'), findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await _drain(tester);
    });

    testWidgets('领取: the signing exit, a submitted report reads 领取已提交 '
        'until the rounds say claimed', (tester) async {
      final wallet = _RecordingWallet();
      final dynamicPool = _FakeDynamic(
        kind: Launch2LoopDynamicPool(_state()),
        rewards: _rewards(),
        rewardsAfterClaim: _rewards('dynamic_rewards_after_claim'),
        claim: () async => _prepared(),
      );
      await openRewards(tester, dynamicPool, wallet: wallet);
      await tester.tap(_key('launch2-dyn-claim-2'));
      await tester.pumpAndSettle();
      expect(dynamicPool.claimRounds.single, BigInt.two);
      expect(_key('launch2-sign-sheet'), findsOneWidget);
      expect(find.text('确认领取外盘奖励'), findsOneWidget);
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(wallet.handed.single.kind, IntentKind.launchPurchase);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(dynamicPool.reports.single, '2:$l2IntentId:$_txHash');
      expect(_key('launch2-dyn-claim-pending'), findsOneWidget);
      expect(find.text('外盘奖励已领取，已在链上确认。'), findsOneWidget);
      expect(find.text('已领取'), findsNWidgets(2));
      await _drain(tester);
    });

    testWidgets('领取: a submitted report with no claimed round yet keeps '
        '领取确认中…', (tester) async {
      final dynamicPool = _FakeDynamic(
        kind: Launch2LoopDynamicPool(_state()),
        rewards: _rewards(),
        claim: () async => _prepared(),
      );
      await openRewards(tester, dynamicPool, wallet: _RecordingWallet());
      await tester.tap(_key('launch2-dyn-claim-2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.textContaining('领取已提交'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('launch2-dyn-claim-2'),
          matching: find.text('领取确认中…'),
        ),
        findsOneWidget,
      );
      await _drain(tester);
    });

    testWidgets('领取: a confirmed report says 已领取 at once', (tester) async {
      final dynamicPool = _FakeDynamic(
        kind: Launch2LoopDynamicPool(_state()),
        rewards: _rewards(),
        claim: () async => _prepared(),
        reportName: 'dynamic_claim_report_confirmed',
      );
      await openRewards(tester, dynamicPool, wallet: _RecordingWallet());
      await tester.tap(_key('launch2-dyn-claim-2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('外盘奖励已领取，已在链上确认。'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('launch2-dyn-claim-2'),
          matching: find.text('已领取'),
        ),
        findsOneWidget,
      );
      await _drain(tester);
    });

    testWidgets('a refusal stays above the round\'s button; an intent to '
        'another contract is refused before the wallet', (tester) async {
      final wallet = _RecordingWallet();
      var answer = 0;
      final dynamicPool = _FakeDynamic(
        kind: Launch2LoopDynamicPool(_state()),
        rewards: _rewards(),
        claim: () async {
          answer += 1;
          if (answer == 1) {
            throw const LoopChainException(
              LoopChainFailureKind.validationFailed,
              reasonCode: 'LAUNCH2_DYNAMIC_ALREADY_CLAIMED',
            );
          }
          // The server's own claim names another Hook than the pool read.
          final body = _fx('dynamic_claim_prepare');
          final intent = body['launch2Intent']! as Map<String, Object?>;
          intent['contractAddress'] = l2Router;
          (intent['calldata']! as Map<String, Object?>)['to'] = l2Router;
          (intent['unsignedTransaction']! as Map<String, Object?>)['to'] =
              l2Router;
          (body['claim']! as Map<String, Object?>)['hook'] = l2Router;
          return _prepared(body);
        },
      );
      await openRewards(tester, dynamicPool, wallet: wallet);
      await tester.tap(_key('launch2-dyn-claim-2'));
      await tester.pumpAndSettle();
      expect(_key('launch2-dyn-claim-failed-2'), findsOneWidget);
      expect(find.text('本轮奖励已经领取过'), findsOneWidget);
      await tester.tap(_key('launch2-dyn-claim-2'));
      await tester.pumpAndSettle();
      expect(_key('launch2-sign-sheet'), findsNothing);
      expect(wallet.handed, isEmpty);
      expect(find.textContaining('交易内容与确认内容不一致'), findsOneWidget);
      await _drain(tester);
    });
  });

  // -------------------------------------------------------------------------
  // decision 0197 · S209 buy fee in USD1, fee totals by token
  // -------------------------------------------------------------------------
  group('decision 0197', () {
    /// The S168b buy quote as an S209 Hook answers it: the 2% kept out of
    /// the 100 USD1 paid in, the MEME out untaxed (the server's figure).
    Map<String, Object?> usd1Buy([
      void Function(Map<String, Object?> quote)? edit,
    ]) {
      final body = _fx('pool_quote_buy_dynamic');
      final quote = body['quote']! as Map<String, Object?>;
      quote
        ..['taxAmount'] = '2'
        ..['taxToken'] = 'usd1'
        ..['taxUsd1'] = '2'
        ..['expectedOut'] = '159999.9'
        ..['minOut'] = '158399.9';
      (quote['dynamic']! as Map<String, Object?>)
        ..['baseTaxAmount'] = '2'
        ..['baseTaxToken'] = 'usd1';
      edit?.call(quote);
      return body;
    }

    Map<String, Object?> dyn(Map<String, Object?> quote) =>
        quote['dynamic']! as Map<String, Object?>;

    test('quote codec: baseTaxToken absent reads as the old MEME buy fee; '
        'usd1 reads with taxToken usd1 and taxUsd1 = taxAmount', () {
      final legacy = _quote(Launch2Side.buy);
      expect(legacy.taxToken, Launch2PoolTaxToken.meme);
      expect(legacy.loopDynamic!.baseTaxToken, Launch2PoolTaxToken.meme);
      expect(legacy.loopDynamic!.buyFeeFromUsd1, isFalse);
      final legacySell = _quote(Launch2Side.sell);
      expect(legacySell.loopDynamic!.baseTaxToken, Launch2PoolTaxToken.usd1);

      final explicitMeme = _fx('pool_quote_buy_dynamic');
      _quoteDynamic(explicitMeme)['baseTaxToken'] = 'meme';
      expect(
        _quote(Launch2Side.buy, explicitMeme).loopDynamic!.baseTaxToken,
        Launch2PoolTaxToken.meme,
      );

      final s209 = _quote(Launch2Side.buy, usd1Buy());
      expect(s209.taxToken, Launch2PoolTaxToken.usd1);
      expect(s209.taxUsd1, Decimal.fromInt(2));
      expect(s209.loopDynamic!.buyFeeFromUsd1, isTrue);
      expect(s209.expectedOut, Decimal.parse('159999.9'));

      final sell = _fx('pool_quote_sell_dynamic');
      _quoteDynamic(sell)['baseTaxToken'] = 'usd1';
      expect(
        _quote(Launch2Side.sell, sell).loopDynamic!.baseTaxToken,
        Launch2PoolTaxToken.usd1,
      );
    });

    test('quote codec refuses a token that disagrees with the generation', () {
      void refuses(Launch2Side side, Map<String, Object?> body) =>
          expect(() => _quote(side, body), _invalid);

      // A USD1 buy fee without the S209 key, or with it saying MEME.
      refuses(Launch2Side.buy, usd1Buy((q) => dyn(q).remove('baseTaxToken')));
      refuses(Launch2Side.buy, usd1Buy((q) => dyn(q)['baseTaxToken'] = 'meme'));
      // The S209 key saying USD1 while the quote is taxed in MEME.
      final mismatch = _fx('pool_quote_buy_dynamic');
      _quoteDynamic(mismatch)['baseTaxToken'] = 'usd1';
      refuses(Launch2Side.buy, mismatch);
      // taxUsd1 must be the USD1 buy fee.
      refuses(Launch2Side.buy, usd1Buy((q) => q['taxUsd1'] = '0'));
      // Wire case is exact; a sell is never taxed in MEME.
      refuses(Launch2Side.buy, usd1Buy((q) => dyn(q)['baseTaxToken'] = 'USD1'));
      final sell = _fx('pool_quote_sell_dynamic');
      _quoteDynamic(sell)['baseTaxToken'] = 'meme';
      refuses(Launch2Side.sell, sell);
      // An OfficialTax buy stays MEME-taxed.
      final official = _s146('pool_quote_buy_exact_in');
      final officialQuote = official['quote']! as Map<String, Object?>;
      officialQuote
        ..['taxToken'] = 'usd1'
        ..['taxUsd1'] = officialQuote['taxAmount'];
      expect(
        () => LoopV2Launch2PoolCodec.quote(
          official,
          instanceId: l2InstanceA,
          side: Launch2Side.buy,
          mode: Launch2PoolMode.exactIn,
          walletId: l2WalletId,
        ),
        _invalid,
      );
    });

    test('quote lines: S209 「从付出的 USD1 扣」, before 「从到手的 MEME 扣」; '
        'the expected MEME is the server figure', () {
      final s209 = launch2PoolQuoteLines(
        _quote(Launch2Side.buy, usd1Buy()),
        'FROG',
      );
      final tax = s209.firstWhere((l) => l.key == 'tax');
      expect(tax.label, '基础税 2%（从付出的 USD1 扣）');
      expect(tax.value, '2 USD1');
      expect(
        s209.firstWhere((l) => l.key == 'expected').value,
        '159,999.9 \$FROG',
      );
      final legacy = launch2PoolQuoteLines(_quote(Launch2Side.buy), 'FROG');
      final old = legacy.firstWhere((l) => l.key == 'tax');
      expect(old.label, '基础税 2%（从到手的 MEME 扣）');
      expect(old.value, '3,200 \$FROG');
      expect(
        legacy.firstWhere((l) => l.key == 'expected').value,
        '156,800 \$FROG',
      );
    });

    test('dynamic-pool codec: buyFeeToken / buyFeesUsd1 absent = MEME, '
        'present = read; the 0144 / 0146 keys are accepted', () {
      final legacy = _state(armed: true);
      expect(legacy.buyFeeToken, Launch2BuyFeeToken.meme);
      expect(legacy.summary.buyFeesUsd1, isNull);
      expect(legacy.summary.buyFeesMeme, Decimal.fromInt(1000));

      final s209 = _state(
        armed: true,
        edit: (p) {
          p['buyFeeToken'] = 'usd1';
          (p['summary']! as Map<String, Object?>)
            ..['buyFeesMeme'] = '0'
            ..['buyFeesUsd1'] = '12.5';
          p
            ..['maxDynamicFeeWad'] = '0.2'
            ..['maxDynamicFeeBps'] = 2000
            ..['currentDynamicTaxBps'] = 2000
            ..['roundCloseRule'] = 'closeAtOrAboveOpen'
            ..['armedAfterRoll'] = true
            ..['currentRoundBuyers'] = <String, Object?>{
              'roundId': '3',
              'buyerCount': 0,
              'buyers': <Object?>[],
            };
        },
      );
      expect(s209.buyFeeToken, Launch2BuyFeeToken.usd1);
      expect(s209.summary.buyFeesUsd1, Decimal.parse('12.5'));

      // not_applicable answers the new keys as null.
      final official = _poolJson('dynamic_pool_not_applicable')
        ..['buyFeeToken'] = null
        ..['maxDynamicFeeBps'] = null;
      expect(_kindWith(official), isA<Launch2OfficialTaxPool>());
    });

    test('dynamic-pool codec refuses a bad buyFeeToken or a stray key', () {
      void refuses(void Function(Map<String, Object?> pool) edit) {
        final pool = _poolJson('dynamic_pool_active_armed');
        edit(pool);
        expect(() => _kindWith(pool), _invalid);
      }

      Map<String, Object?> summary(Map<String, Object?> p) =>
          p['summary']! as Map<String, Object?>;

      refuses((p) => p['buyFeeToken'] = 'USD1');
      refuses((p) => p['buyFeeToken'] = null);
      refuses((p) => p['buyFeeToken'] = 2);
      refuses((p) => summary(p)['buyFeesUsd1'] = 12);
      refuses((p) => summary(p)['buyFeesExtra'] = '1');
      refuses((p) => p['roundCloseRule'] = 'sometimes');
      refuses((p) => p['maxDynamicFeeBps'] = 20000);
      refuses((p) => p['somethingElse'] = 1);
      final official = _poolJson('dynamic_pool_not_applicable')
        ..['buyFeeToken'] = 'meme';
      expect(() => _kindWith(official), _invalid);
    });

    test('fee rows: an S209 Hook says USD1, an older one MEME, both when '
        'both totals hold fees', () {
      List<(String, String)> rows(Launch2DynamicPoolState state) =>
          <(String, String)>[
            for (final (key, _, value) in launch2DynamicBuyFeeRows(
              state,
              ticker: 'FROG',
            ))
              (key, value),
          ];
      expect(rows(_state()), <(String, String)>[
        ('buy-fees-meme', '1,000 \$FROG'),
      ]);
      expect(
        launch2DynamicBuyFeeRows(_state()).single.$3,
        '1,000 MEME',
        reason: 'no ticker: the row names MEME',
      );
      final usd1 = _state(
        edit: (p) {
          p['buyFeeToken'] = 'usd1';
          (p['summary']! as Map<String, Object?>)
            ..['buyFeesMeme'] = '0'
            ..['buyFeesUsd1'] = '12.5';
        },
      );
      expect(rows(usd1), <(String, String)>[('buy-fees-usd1', '12.5 USD1')]);
      final both = _state(
        edit: (p) {
          p['buyFeeToken'] = 'usd1';
          (p['summary']! as Map<String, Object?>)['buyFeesUsd1'] = '12.5';
        },
      );
      expect(rows(both), <(String, String)>[
        ('buy-fees-usd1', '12.5 USD1'),
        ('buy-fees-meme', '1,000 \$FROG'),
      ]);
      expect(
        launch2DynamicBuyFeeRows(both).map((row) => row.$2).toSet(),
        <String>{'买入基础税累计'},
      );
      expect(
        launch2DynamicFeeRows(_state(armed: true)).map((row) => row.$1),
        <String>['dynamic-fees', 'sell-fees', 'buy-fees-meme'],
      );
    });

    testWidgets('project page: an S209 buy quote says the USD1 fee; the fee '
        'card says 买入基础税累计 in USD1', (tester) async {
      final launch2 = _FakeLaunch2(
        quoteAnswer: (side) async =>
            side == Launch2Side.buy ? _quote(side, usd1Buy()) : _quote(side),
      );
      await _openInstance(
        tester,
        launch2: launch2,
        dynamicPool: _FakeDynamic(
          kind: Launch2LoopDynamicPool(
            _state(
              armed: true,
              edit: (p) {
                p['buyFeeToken'] = 'usd1';
                (p['summary']! as Map<String, Object?>)
                  ..['buyFeesMeme'] = '0'
                  ..['buyFeesUsd1'] = '12.5';
              },
            ),
          ),
        ),
      );
      await _scrollTo(tester, _key('launch2-dyn-buy-fees-usd1'));
      expect(
        find.descendant(
          of: _key('launch2-dyn-buy-fees-usd1'),
          matching: find.text('12.5 USD1'),
        ),
        findsOneWidget,
      );
      expect(_key('launch2-dyn-buy-fees-meme'), findsNothing);
      await _type(tester, '100');
      expect(find.text('基础税 2%（从付出的 USD1 扣）'), findsOneWidget);
      expect(find.text('基础税 2%（从到手的 MEME 扣）'), findsNothing);
      expect(
        find.descendant(
          of: _key('launch2-pool-line-tax'),
          matching: find.text('2 USD1'),
        ),
        findsOneWidget,
      );
      await _drain(tester);
    });

    testWidgets('外盘奖励: the fee card above the rounds, in MEME before S209', (
      tester,
    ) async {
      await _pump(
        tester,
        const Launch2DynamicRewardsScreen(instanceId: l2InstanceA),
        launch2: _FakeLaunch2(),
        dynamicPool: _FakeDynamic(
          kind: Launch2LoopDynamicPool(_state(armed: true)),
          rewards: _rewards(),
        ),
      );
      expect(_key('launch2-dyn-fees'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('launch2-dyn-buy-fees-meme'),
          matching: find.text('1,000 \$FROG'),
        ),
        findsOneWidget,
      );
      expect(_key('launch2-dyn-buy-fees-usd1'), findsNothing);
      await _drain(tester);
    });
  });

  // -------------------------------------------------------------------------
  // S222 · decision 0198: the loop-api 0146 keys on viewer and rounds
  // -------------------------------------------------------------------------
  group('decision 0198', () {
    test('dynamic-pool viewer: the 0146 index weight and reconciled flag '
        'are accepted; bad types are not', () {
      final state = _state(
        armed: true,
        edit: (p) => (p['viewer']! as Map<String, Object?>)
          ..['indexedCurrentRoundWeightUsd1'] = '25'
          ..['weightReconciled'] = true,
      );
      expect(state.viewer?.currentRoundWeightUsd1, Decimal.fromInt(25));
      // Null on both is the server's "no round armed".
      _state(
        armed: true,
        edit: (p) => (p['viewer']! as Map<String, Object?>)
          ..['indexedCurrentRoundWeightUsd1'] = null
          ..['weightReconciled'] = null,
      );
      void refuses(void Function(Map<String, Object?> viewer) edit) {
        final pool = _poolJson('dynamic_pool_active_armed');
        edit(pool['viewer']! as Map<String, Object?>);
        expect(() => _kindWith(pool), _invalid);
      }

      refuses((v) => v['weightReconciled'] = 'yes');
      refuses((v) => v['indexedCurrentRoundWeightUsd1'] = 25);
      refuses((v) => v['somethingElse'] = 1);
    });

    test('rewards rounds: the 0146 credit totals and entries are accepted; '
        'bad types are not', () {
      final rewards = _rewardsWith((rounds) {
        for (final round in rounds) {
          round
            ..['creditedUsd1'] = '25'
            ..['movedInUsd1'] = '0'
            ..['movedOutUsd1'] = '0'
            ..['credits'] = <Object?>[
              <String, Object?>{
                'direction': 'in',
                'attribution': 'loopRouter',
                'counterparty': null,
                'amountUsd1': '25',
                'transactionHash': '0x${'ab' * 32}',
                'logIndex': 3,
                'creditedAt': '2026-10-16T07:00:00.000Z',
              },
            ];
        }
      });
      expect(rewards.rounds, hasLength(3));
      for (final edit in <void Function(Map<String, Object?> round)>[
        (r) => r['creditedUsd1'] = 25,
        (r) => r['movedInUsd1'] = '-1',
        (r) => r['credits'] = 'none',
        (r) => r['credits'] = <Object?>[1],
        (r) => r['credits'] = List<Object?>.filled(21, <String, Object?>{}),
        (r) => r['somethingElse'] = 1,
      ]) {
        expect(() => _rewardsWith((rounds) => edit(rounds.first)), _invalid);
      }
    });
  });
}

extension<T> on T {
  T let(void Function(T value) edit) {
    edit(this);
    return this;
  }
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
