import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_models.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/wallet/testnet_faucet/testnet_faucet_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/test_hints.dart';
import 'support/testnet_faucet_fakes.dart';

// ---------------------------------------------------------------------------
// S266 · a wallet with no USD1 is offered funding, not a dead quote
// (client decision 0225)
// ---------------------------------------------------------------------------

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// The curve panel's gateway: one detail, scripted quotes, nothing else.
final class _Launch2 implements Launch2Gateway {
  _Launch2({required this.detail, this.quoteAnswer});

  final Launch2InstanceDetail detail;

  /// `null` answers every quote with a fresh [l2Quote].
  Object? quoteAnswer;
  final List<(Launch2Side, Decimal)> quoteCalls = <(Launch2Side, Decimal)>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<Launch2CandleSeries> candles(
    String instanceId,
    Launch2CandleInterval interval, {
    int limit = launch2CandlePageSize,
    DateTime? before,
  }) => _unavailable();

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
    quoteCalls.add((side, amount));
    final answer = quoteAnswer;
    if (answer is LoopChainException) return Future<Launch2Quote>.error(answer);
    return Future<Launch2Quote>.value(
      answer is Launch2Quote ? answer : l2Quote(),
    );
  }

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
  Future<Launch2BuybackPage> loadBuybacks(String instanceId) => _unavailable();

  @override
  Future<Launch2Positions> loadPositions() => _unavailable();

  @override
  Future<Launch2PoolQuote> poolQuote({
    required String instanceId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
    required String walletId,
  }) => _unavailable();

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
  Future<Launch2PoolTrades> loadPoolTrades({
    required String instanceId,
    required String walletId,
    int limit = launch2PoolTradesShown,
  }) => _unavailable();
}

LoopV2MetaSnapshot _meta({required bool faucet}) {
  final base = s7MetaSnapshot();
  LoopV2Capability open(LoopV2CapabilityId id) => LoopV2Capability(
    id: id,
    availability: LoopV2CapabilityAvailability.available,
    reasonCode: null,
    evidence: const LoopV2CapabilityEvidence(
      status: LoopV2CapabilityEvidenceStatus.notApplicable,
      reasonCode: null,
    ),
  );
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.launch2)
            open(LoopV2CapabilityId.launch2)
          else if (capability.id == LoopV2CapabilityId.testnetFaucet && faucet)
            open(LoopV2CapabilityId.testnetFaucet)
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

/// The wallet balances with the Launch slot's USD1 at [usd1Units] (base
/// units, 18 decimals).
LoopWalletBalances _balances(String usd1Units) => s5Balances(
  launchChain: LoopLaunchChainBalance(
    chainId: 'eip155:97',
    available: true,
    reasonCode: null,
    nativeBalance: LoopLaunchChainNativeBalance(
      assetId: 'eip155:97:native',
      symbol: 'tBNB',
      decimals: 18,
      rawValue: '20000000000000000',
      displayBalance: Decimal.parse('0.02'),
      availableBalance: Decimal.parse('0.02'),
      spendableBalance: Decimal.parse('0.015'),
      gasReserve: Decimal.parse('0.005'),
      snapshot: LoopBalanceSnapshot(
        blockNumber: BigInt.from(52000000),
        blockHash: s5BlockHash,
        observedAt: DateTime.utc(2027, 1, 20, 6, 59),
        confirmations: 5,
      ),
    ),
    usd1: LoopLaunchUsd1Reading(balance: usd1Units, allowance: '0'),
  ),
);

Launch2InstanceDetail _public({Map<String, Object?>? holding}) => l2Detail(
  stage: 'public',
  viewer: l2ViewerJson(member: true, eligibleNow: true, holding: holding),
);

Future<void> _pump(
  WidgetTester tester, {
  required _Launch2 launch2,
  bool faucet = true,
  List<LoopWalletBalances> balances = const <LoopWalletBalances>[],
  FakeTestnetFaucetGateway? faucetGateway,
}) => pumpS7Page(
  tester,
  const Launch2InstanceScreen(instanceId: l2InstanceA),
  meta: _meta(faucet: faucet),
  wallet: FakeWalletDirectory(
    activeWalletId: l2WalletId,
    wallets: <LoopWalletAccount>[_wallet()],
    balances: balances,
  ),
  overrides: <Override>[
    launch2GatewayProvider.overrideWithValue(launch2),
    launch2ClockProvider.overrideWithValue(() => l2Now),
    launch2PollingProvider.overrideWithValue(
      const Launch2Polling(
        detailInterval: Duration(hours: 1),
        tradingInterval: Duration(hours: 1),
      ),
    ),
    loopFeatureSwitchesProvider.overrideWithValue(
      const LoopFeatureSwitchValues(
        launch2Visible: true,
        classicMemeLaunchVisible: true,
      ),
    ),
    testnetFaucetGatewayProvider.overrideWithValue(
      faucetGateway ??
          FakeTestnetFaucetGateway(status: faucetStatus(walletId: l2WalletId)),
    ),
  ],
);

Future<void> _type(WidgetTester tester, String amount) async {
  await tester.enterText(_key('launch2-trade-amount'), amount);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

bool _confirmEnabled(WidgetTester tester) =>
    (tester.widget<Widget>(
      _key('launch2-trade-confirm'),
    ) as dynamic).onPressed !=
    null;

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

void main() {
  loopShowTestHints();
  loopWatchGround();

  group('copy', () {
    test('QUOTE_ZERO and DEADLINE_TOO_FAR no longer share a sentence', () {
      expect(launch2ReasonText('LAUNCH2_QUOTE_ZERO'), '这个金额买不到最小单位，换个金额试试');
      expect(launch2ReasonText('LAUNCH2_DEADLINE_TOO_FAR'), '报价已变化，请重新报价');
    });

    test('only the two balance refusals count as the wallet being short', () {
      expect(
        launch2IsBalanceRefusal(
          const LoopChainException(
            LoopChainFailureKind.insufficientBalance,
            reasonCode: 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
          ),
        ),
        isTrue,
      );
      expect(
        launch2IsBalanceRefusal(
          const LoopChainException(
            LoopChainFailureKind.insufficientBalance,
            reasonCode: 'LAUNCH2_MEME_BALANCE_INSUFFICIENT',
          ),
        ),
        isTrue,
      );
      expect(
        launch2IsBalanceRefusal(
          const LoopChainException(
            LoopChainFailureKind.versionConflict,
            reasonCode: 'LAUNCH2_QUOTE_ZERO',
          ),
        ),
        isFalse,
      );
    });
  });

  group('a quote refused for the balance', () {
    testWidgets('says the shortfall and offers 获取资金, which opens the faucet '
        'sheet', (tester) async {
      final launch2 = _Launch2(
        detail: _public(),
        quoteAnswer: const LoopChainException(
          LoopChainFailureKind.insufficientBalance,
          reasonCode: 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
          requiredAmountIn: '50',
          balanceUsd1: '0',
        ),
      );
      await _pump(tester, launch2: launch2);
      await _type(tester, '50');
      expect(launch2.quoteCalls, hasLength(1));
      expect(_key('launch2-trade-quote-failed'), findsNothing);
      expect(_key('launch2-trade-quote-short'), findsOneWidget);
      expect(find.text('USD1 余额不足：需要 50 USD1，当前 0 USD1'), findsOneWidget);
      expect(find.textContaining('没有取到报价'), findsNothing);
      expect(_key('launch2-trade-quote-topup'), findsOneWidget);
      expect(_key('launch2-trade-quote-faucet'), findsOneWidget);
      expect(_confirmEnabled(tester), isFalse);
      await tester.ensureVisible(_key('launch2-trade-quote-faucet'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-trade-quote-faucet'));
      await tester.pumpAndSettle();
      expect(_key('testnet-faucet-sheet'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('without the faucet only 去充值 is offered', (tester) async {
      final launch2 = _Launch2(
        detail: _public(),
        quoteAnswer: const LoopChainException(
          LoopChainFailureKind.insufficientBalance,
          reasonCode: 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
          maxAmountIn: '0',
        ),
      );
      await _pump(tester, launch2: launch2, faucet: false);
      await _type(tester, '50');
      expect(find.text('USD1 余额不足：需要 50 USD1，最多可付 0 USD1'), findsOneWidget);
      expect(_key('launch2-trade-quote-topup'), findsOneWidget);
      expect(_key('launch2-trade-quote-faucet'), findsNothing);
      await _drain(tester);
    });

    testWidgets('a MEME shortfall on the sell side has no funding link', (
      tester,
    ) async {
      final launch2 = _Launch2(
        detail: _public(),
        quoteAnswer: const LoopChainException(
          LoopChainFailureKind.insufficientBalance,
          reasonCode: 'LAUNCH2_MEME_BALANCE_INSUFFICIENT',
          balanceMeme: '0',
        ),
      );
      await _pump(tester, launch2: launch2);
      await tester.tap(find.text('卖出'));
      await tester.pumpAndSettle();
      await _type(tester, '100');
      expect(_key('launch2-trade-quote-short'), findsOneWidget);
      expect(find.textContaining('卖出数量超过持有'), findsOneWidget);
      expect(_key('launch2-trade-quote-topup'), findsNothing);
      expect(_key('launch2-trade-quote-faucet'), findsNothing);
      await _drain(tester);
    });

    testWidgets('QUOTE_ZERO keeps the quote line with its new sentence', (
      tester,
    ) async {
      final launch2 = _Launch2(
        detail: _public(),
        quoteAnswer: const LoopChainException(
          LoopChainFailureKind.versionConflict,
          reasonCode: 'LAUNCH2_QUOTE_ZERO',
        ),
      );
      await _pump(tester, launch2: launch2);
      await _type(tester, '0.0000001');
      expect(_key('launch2-trade-quote-failed'), findsOneWidget);
      expect(find.text('没有取到报价 · 这个金额买不到最小单位，换个金额试试'), findsOneWidget);
      expect(_key('launch2-trade-quote-faucet'), findsNothing);
      expect(_key('launch2-trade-empty-balance'), findsNothing);
      await _drain(tester);
    });
  });

  group('a balance read as zero', () {
    testWidgets('wallet balances: 钱包里还没有 USD1 with 获取资金, no quote asked; '
        'a grant re-reads the balances and the quote follows', (tester) async {
      final launch2 = _Launch2(detail: _public());
      final directory = FakeWalletDirectory(
        activeWalletId: l2WalletId,
        wallets: <LoopWalletAccount>[_wallet()],
        balances: <LoopWalletBalances>[
          _balances('0'),
          _balances('500000000000000000000'),
        ],
      );
      final faucet = FakeTestnetFaucetGateway(
        status: faucetStatus(walletId: l2WalletId),
        claimResult: faucetGranted(
          walletId: l2WalletId,
          grantedAt: DateTime.now().toUtc(),
        ),
      );
      await pumpS7Page(
        tester,
        const Launch2InstanceScreen(instanceId: l2InstanceA),
        meta: _meta(faucet: true),
        wallet: directory,
        overrides: <Override>[
          launch2GatewayProvider.overrideWithValue(launch2),
          launch2ClockProvider.overrideWithValue(() => l2Now),
          launch2PollingProvider.overrideWithValue(
            const Launch2Polling(
              detailInterval: Duration(hours: 1),
              tradingInterval: Duration(hours: 1),
            ),
          ),
          loopFeatureSwitchesProvider.overrideWithValue(
            const LoopFeatureSwitchValues(
              launch2Visible: true,
              classicMemeLaunchVisible: true,
            ),
          ),
          testnetFaucetGatewayProvider.overrideWithValue(faucet),
        ],
      );
      // Before anything is typed the line already stands under the field.
      expect(_key('launch2-trade-empty-balance'), findsOneWidget);
      expect(find.text('钱包里还没有 USD1'), findsOneWidget);
      expect(_key('launch2-trade-empty-topup'), findsOneWidget);
      expect(_key('launch2-trade-empty-faucet'), findsOneWidget);
      await _type(tester, '50');
      expect(launch2.quoteCalls, isEmpty);
      expect(_key('launch2-trade-quote-empty'), findsNothing);
      expect(_confirmEnabled(tester), isFalse);
      // MAX asks nothing either.
      await tester.tap(_key('launch2-trade-max'));
      await tester.pumpAndSettle();
      expect(launch2.quoteCalls, isEmpty);

      await tester.ensureVisible(_key('launch2-trade-empty-faucet'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-trade-empty-faucet'));
      await tester.pumpAndSettle();
      expect(_key('testnet-faucet-sheet'), findsOneWidget);
      final reads = directory.balanceReads;
      await tester.tap(_key('testnet-faucet-claim'));
      await tester.pumpAndSettle();
      expect(faucet.claims, <String>[l2WalletId]);
      expect(directory.balanceReads, greaterThan(reads));
      // Close the sheet; the panel now quotes the amount still typed.
      await tester.tapAt(const Offset(20, 20));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(_key('launch2-trade-empty-balance'), findsNothing);
      expect(launch2.quoteCalls, hasLength(1));
      expect(launch2.quoteCalls.single.$2, Decimal.fromInt(50));
      expect(_key('launch2-trade-quote'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('the detail holding: zero USD1 closes buying; zero MEME says '
        '还没有这个代币 without a link', (tester) async {
      final launch2 = _Launch2(
        detail: _public(
          holding: l2HoldingJson(meme: '0', usd1: '0'),
        ),
      );
      await _pump(tester, launch2: launch2);
      expect(find.text('钱包里还没有 USD1'), findsOneWidget);
      await tester.tap(find.text('卖出'));
      await tester.pumpAndSettle();
      expect(find.text('还没有这个代币'), findsOneWidget);
      expect(_key('launch2-trade-empty-topup'), findsNothing);
      expect(_key('launch2-trade-empty-faucet'), findsNothing);
      await _type(tester, '10');
      expect(launch2.quoteCalls, isEmpty);
      await _drain(tester);
    });

    testWidgets('a quote whose balance-limited MAX is zero shows the same '
        'line, not 「填入 0」', (tester) async {
      final quote = LoopV2Launch2Codec.quote(
        l2QuoteJson(exceedsMax: true, maxIn: '0', limitedBy: 'balance'),
        instanceId: l2InstanceA,
        side: Launch2Side.buy,
        walletId: l2WalletId,
      );
      expect(quote.maxAmountIn, Decimal.zero);
      final launch2 = _Launch2(detail: _public(), quoteAnswer: quote);
      await _pump(tester, launch2: launch2);
      await _type(tester, '50');
      expect(_key('launch2-trade-empty-balance'), findsOneWidget);
      expect(_key('launch2-trade-fill-max'), findsNothing);
      expect(_confirmEnabled(tester), isFalse);
      await _drain(tester);
    });
  });

  group('with funds', () {
    testWidgets('a positive balance quotes as before', (tester) async {
      final launch2 = _Launch2(detail: _public());
      await _pump(
        tester,
        launch2: launch2,
        balances: <LoopWalletBalances>[_balances('195000000000000000000')],
      );
      expect(_key('launch2-trade-empty-balance'), findsNothing);
      await _type(tester, '50');
      expect(launch2.quoteCalls, hasLength(1));
      expect(_key('launch2-trade-quote'), findsOneWidget);
      expect(_confirmEnabled(tester), isTrue);
      await _drain(tester);
    });

    testWidgets('a balance not read never stops a quote', (tester) async {
      final launch2 = _Launch2(detail: _public());
      await _pump(tester, launch2: launch2);
      expect(_key('launch2-trade-empty-balance'), findsNothing);
      await _type(tester, '50');
      expect(launch2.quoteCalls, hasLength(1));
      expect(_key('launch2-trade-quote'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('a zero read for another chain is not this wallet\'s USD1', (
      tester,
    ) async {
      final launch2 = _Launch2(detail: _public());
      final other = _balances('0');
      await _pump(
        tester,
        launch2: launch2,
        balances: <LoopWalletBalances>[
          s5Balances(
            launchChain: LoopLaunchChainBalance(
              chainId: 'eip155:56',
              available: true,
              reasonCode: null,
              nativeBalance: other.launchChain!.nativeBalance,
              usd1: other.launchChain!.usd1,
            ),
          ),
        ],
      );
      expect(_key('launch2-trade-empty-balance'), findsNothing);
      await _type(tester, '50');
      expect(launch2.quoteCalls, hasLength(1));
      await _drain(tester);
    });
  });
}
