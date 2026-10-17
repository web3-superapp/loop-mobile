// S177 · the chain guard's hold on a MEME v2 instance (client decision 0161).
//
// loop-api S177 adds `instance.tradingHold` ({kind: usd1_paused |
// address_frozen, since}) to the detail and refuses every write while it
// holds (`LAUNCH2_USD1_PAUSED` / `LAUNCH2_ADDRESS_FROZEN`). The samples are
// the S134 / S146 / S168b fixtures with the field added by hand.
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_dynamic_rewards_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_dynamic_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _since = '2027-01-20T06:30:00.000Z';
const String _pausedText = 'USD1 已被发行方暂停，买卖和领取暂不可用';
const String _frozenText = '本项目合约地址被 USD1 发行方限制，买卖和领取暂不可用';

Map<String, Object?> _fixture(String dir, String name) =>
    (jsonDecode(File('test/fixtures/$dir/$name.json').readAsStringSync())
            as Map<String, Object?>)['body']!
        as Map<String, Object?>;

/// A detail body with `tradingHold` set to [hold]; [omit] leaves the key out.
Launch2InstanceDetail _detail({
  String stage = 'priority',
  Object? hold,
  bool omit = false,
}) {
  final body = l2DetailJson(
    stage: stage,
    noNextChange: stage == 'graduated',
    viewer: l2ViewerJson(member: true, eligibleNow: true),
    pool: stage == 'graduated' ? l2PoolSummaryJson() : null,
  );
  if (!omit) {
    (body['instance']! as Map<String, Object?>)['tradingHold'] = hold;
  }
  return LoopV2Launch2Codec.detail(body, mediaUrl: (_) => null);
}

Map<String, Object?> _hold(String kind) => <String, Object?>{
  'kind': kind,
  'since': _since,
};

final class _Fake implements Launch2Gateway {
  _Fake(this.detail);

  final Launch2InstanceDetail detail;
  int curveQuotes = 0;
  int poolQuotes = 0;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) =>
      Future<Launch2InstanceDetail>.value(detail);

  @override
  Future<Launch2Quote> quote({
    required String instanceId,
    required Launch2Side side,
    required Decimal amount,
    required String walletId,
  }) {
    curveQuotes += 1;
    return Future<Launch2Quote>.value(l2Quote());
  }

  @override
  Future<Launch2PoolQuote> poolQuote({
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
    required String walletId,
  }) {
    poolQuotes += 1;
    return Future<Launch2PoolQuote>.value(
      LoopV2Launch2PoolCodec.quote(
        _fixture('s146-launch2-pool', 'pool_quote_buy_exact_in'),
        instanceId: l2InstanceA,
        side: Launch2Side.buy,
        mode: Launch2PoolMode.exactIn,
        walletId: l2WalletId,
      ),
    );
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
  int claims = 0;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2PoolKind> loadPoolKind(String instanceId) =>
      Future<Launch2PoolKind>.value(
        LoopV2Launch2DynamicPoolCodec.pool(
          _fixture('s168b-launch2-dynamic', 'dynamic_pool_active_idle'),
          instanceId: l2InstanceA,
        ),
      );

  @override
  Future<Launch2DynamicRewards> loadRewards({
    required String instanceId,
    required String walletId,
  }) => Future<Launch2DynamicRewards>.value(
    LoopV2Launch2DynamicPoolCodec.rewards(
      _fixture('s168b-launch2-dynamic', 'dynamic_rewards'),
      instanceId: l2InstanceA,
      walletId: l2WalletId,
    ),
  );

  @override
  Future<Launch2DynamicClaimPrepared> prepareClaim({
    required String instanceId,
    required String walletId,
    required BigInt roundId,
  }) {
    claims += 1;
    return Future<Launch2DynamicClaimPrepared>.error(
      const LoopChainException(LoopChainFailureKind.unavailable),
    );
  }

  @override
  Future<Launch2DynamicClaimReport> reportClaim({
    required String instanceId,
    required String walletId,
    required BigInt roundId,
    required String intentId,
    required String transactionHash,
  }) => Future<Launch2DynamicClaimReport>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
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

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  _Fake gateway, {
  _FakeDynamic? dynamicPool,
}) => pumpS7Page(
  tester,
  page,
  meta: _meta(),
  wallet: FakeWalletDirectory(
    activeWalletId: l2WalletId,
    wallets: <LoopWalletAccount>[
      LoopWalletAccount(
        walletId: l2WalletId,
        address: l2WalletAddress,
        kind: LoopWalletKind.embedded,
        status: LoopWalletStatus.active,
        isActive: true,
        firstSeenAt: DateTime.utc(2026, 9),
        lastSeenAt: DateTime.utc(2026, 10, 8),
      ),
    ],
  ),
  overrides: <Override>[
    launch2GatewayProvider.overrideWithValue(gateway),
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
  ],
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

Future<void> _type(WidgetTester tester, String field, String text) async {
  await _scrollTo(tester, _key(field));
  await tester.enterText(_key(field), text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

VoidCallback? _onPressed(WidgetTester tester, String key) =>
    (tester.widget<Widget>(_key(key)) as dynamic).onPressed as VoidCallback?;

void main() {
  loopWatchGround();

  group('codec · instance.tradingHold', () {
    test('absent and null both read as no hold', () {
      expect(_detail(omit: true).tradingHold, isNull);
      expect(_detail().tradingHold, isNull);
    });

    test('usd1_paused and address_frozen decode with since', () {
      final paused = _detail(hold: _hold('usd1_paused')).tradingHold!;
      expect(paused.kind, Launch2TradingHoldKind.usd1Paused);
      expect(paused.since, DateTime.utc(2027, 1, 20, 6, 30));
      final frozen = _detail(hold: _hold('address_frozen')).tradingHold!;
      expect(frozen.kind, Launch2TradingHoldKind.addressFrozen);
      expect(frozen.since, DateTime.utc(2027, 1, 20, 6, 30));
    });

    test('an unknown kind or a non-object reads as none and does not fail '
        'the page; an unreadable since keeps the hold', () {
      expect(_detail(hold: _hold('issuer_blacklisted')).tradingHold, isNull);
      expect(_detail(hold: <String, Object?>{'kind': 7}).tradingHold, isNull);
      expect(_detail(hold: 'usd1_paused').tradingHold, isNull);
      final noSince = _detail(
        hold: <String, Object?>{'kind': 'usd1_paused', 'since': 'yesterday'},
      ).tradingHold!;
      expect(noSince.kind, Launch2TradingHoldKind.usd1Paused);
      expect(noSince.since, isNull);
    });
  });

  group('copy', () {
    test('the two refusal codes say the hold sentences, curve and pool', () {
      expect(launch2ReasonText('LAUNCH2_USD1_PAUSED'), _pausedText);
      expect(launch2ReasonText('LAUNCH2_ADDRESS_FROZEN'), _frozenText);
      expect(launch2PoolReasonText('LAUNCH2_USD1_PAUSED'), _pausedText);
      expect(launch2PoolReasonText('LAUNCH2_ADDRESS_FROZEN'), _frozenText);
      expect(
        launch2TradingHoldText(Launch2TradingHoldKind.usd1Paused),
        _pausedText,
      );
      expect(
        launch2TradingHoldText(Launch2TradingHoldKind.addressFrozen),
        _frozenText,
      );
    });

    test('since: the clock today, the date before', () {
      final since = DateTime(2027, 1, 20, 14, 5);
      expect(
        launch2TradingHoldSinceText(since, now: DateTime(2027, 1, 20, 18)),
        '自 14:05 起',
      );
      expect(
        launch2TradingHoldSinceText(since, now: DateTime(2027, 1, 21, 9)),
        '自 2027-01-20 14:05 起',
      );
    });
  });

  group('project page', () {
    for (final (kind, text) in <(String?, String)>[
      (null, ''),
      ('usd1_paused', _pausedText),
      ('address_frozen', _frozenText),
    ]) {
      testWidgets('提前购 · hold ${kind ?? 'none'}: banner and confirm', (
        tester,
      ) async {
        final gateway = _Fake(_detail(hold: kind == null ? null : _hold(kind)));
        await _pump(
          tester,
          const Launch2InstanceScreen(instanceId: l2InstanceA),
          gateway,
        );
        if (kind == null) {
          expect(_key('launch2-trading-hold'), findsNothing);
        } else {
          expect(_key('launch2-trading-hold'), findsOneWidget);
          expect(
            find.descendant(
              of: _key('launch2-trading-hold'),
              matching: find.text(text),
            ),
            findsOneWidget,
          );
          expect(
            find.text(launch2TradingHoldSinceText(DateTime.parse(_since))),
            findsOneWidget,
          );
        }
        // The field stays live and still quotes.
        expect(
          tester.widget<TextField>(_key('launch2-trade-amount')).enabled,
          isTrue,
        );
        await _type(tester, 'launch2-trade-amount', '50');
        expect(gateway.curveQuotes, 1);
        expect(_key('launch2-trade-quote'), findsOneWidget);
        // Decision 0200: the curve's 「最少获得」 says how it is computed.
        expect(
          find.descendant(
            of: _key('launch2-trade-quote'),
            matching: _key('launch2-trade-min-out-note'),
          ),
          findsOneWidget,
        );
        if (kind == null) {
          expect(_onPressed(tester, 'launch2-trade-confirm'), isNotNull);
          expect(_key('launch2-trade-hold'), findsNothing);
        } else {
          expect(_onPressed(tester, 'launch2-trade-confirm'), isNull);
          expect(
            find.descendant(
              of: _key('launch2-trade-hold'),
              matching: find.text(text),
            ),
            findsOneWidget,
          );
        }
        await _drain(tester);
      });

      testWidgets('外盘交易 · hold ${kind ?? 'none'}: banner and confirm', (
        tester,
      ) async {
        final gateway = _Fake(
          _detail(stage: 'graduated', hold: kind == null ? null : _hold(kind)),
        );
        await _pump(
          tester,
          const Launch2InstanceScreen(instanceId: l2InstanceA),
          gateway,
        );
        expect(
          _key('launch2-trading-hold'),
          kind == null ? findsNothing : findsOneWidget,
        );
        await _type(tester, 'launch2-pool-amount', '100');
        expect(gateway.poolQuotes, 1);
        if (kind == null) {
          expect(_onPressed(tester, 'launch2-pool-confirm'), isNotNull);
          expect(_key('launch2-pool-hold'), findsNothing);
        } else {
          expect(_onPressed(tester, 'launch2-pool-confirm'), isNull);
          expect(
            find.descendant(
              of: _key('launch2-pool-hold'),
              matching: find.text(text),
            ),
            findsOneWidget,
          );
        }
        await _drain(tester);
      });
    }

    testWidgets('NFT 发售 under a hold: 购买 NFT is closed with the reason', (
      tester,
    ) async {
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        _Fake(_detail(stage: 'nft_sale', hold: _hold('address_frozen'))),
      );
      expect(_key('launch2-trading-hold'), findsOneWidget);
      expect(_onPressed(tester, 'launch2-buy-nft'), isNull);
      expect(
        find.descendant(
          of: _key('launch2-bar-hold'),
          matching: find.text(_frozenText),
        ),
        findsOneWidget,
      );
      await _drain(tester);
    });

    testWidgets('NFT 发售 without a hold: 购买 NFT is open', (tester) async {
      await _pump(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        _Fake(_detail(stage: 'nft_sale')),
      );
      expect(_key('launch2-trading-hold'), findsNothing);
      expect(_key('launch2-bar-hold'), findsNothing);
      expect(_onPressed(tester, 'launch2-buy-nft'), isNotNull);
      await _drain(tester);
    });
  });

  group('外盘奖励 page', () {
    for (final kind in <String?>[null, 'usd1_paused']) {
      testWidgets('hold ${kind ?? 'none'}: 领取', (tester) async {
        final dynamicPool = _FakeDynamic();
        await _pump(
          tester,
          const Launch2DynamicRewardsScreen(instanceId: l2InstanceA),
          _Fake(
            _detail(
              stage: 'graduated',
              hold: kind == null ? null : _hold(kind),
            ),
          ),
          dynamicPool: dynamicPool,
        );
        expect(_key('launch2-dyn-claim-2'), findsOneWidget);
        if (kind == null) {
          expect(_key('launch2-trading-hold'), findsNothing);
          expect(_onPressed(tester, 'launch2-dyn-claim-2'), isNotNull);
        } else {
          expect(_key('launch2-trading-hold'), findsOneWidget);
          expect(find.text(_pausedText), findsOneWidget);
          expect(_onPressed(tester, 'launch2-dyn-claim-2'), isNull);
        }
        expect(dynamicPool.claims, 0);
        await _drain(tester);
      });
    }
  });
}
