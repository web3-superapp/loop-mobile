// S285 · decision 0240: the MEME v2 project page's test harness — one
// scripted MEME v2 gateway, one scripted public-trades gateway, and the page
// pumped at a phone size. Every value here is 测试专用.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_models.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_recent_trades.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_candle_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_recent_trades_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'launch2_fixtures.dart';
import 'loop_ground_probe.dart';
import 's7_page_harness.dart';

/// A scripted answer: a value, or a failure of [kind].
typedef S285Answer<T> = ({T? value, LoopChainFailureKind? kind});

S285Answer<T> s285Value<T>(T value) => (value: value, kind: null);
S285Answer<T> s285Fail<T>(LoopChainFailureKind kind) =>
    (value: null, kind: kind);

Future<T> _resolve<T>(S285Answer<T>? answer) {
  if (answer == null) {
    return Future<T>.error(
      const LoopChainException(LoopChainFailureKind.unavailable),
    );
  }
  final kind = answer.kind;
  if (kind != null) return Future<T>.error(LoopChainException(kind));
  return Future<T>.value(answer.value as T);
}

/// The MEME v2 gateway: one detail, positions, the wallet's own pool trades,
/// buybacks and (for the shots) a gentle K line.
final class S285Launch2 implements Launch2Gateway {
  S285Launch2({
    required this.detail,
    this.positions,
    this.poolTrades,
    this.candleSource,
  });

  Launch2InstanceDetail detail;
  S285Answer<Launch2Positions>? positions;
  S285Answer<Launch2PoolTrades>? poolTrades;

  /// `curve` / `pool` / `mixed` draws a K line; `null` hides the card.
  final String? candleSource;
  int poolTradeReads = 0;
  int positionReads = 0;

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
  }) {
    final source = candleSource;
    if (source == null || before != null) return _unavailable();
    final step = interval.width.inSeconds;
    final start = l2Now.subtract(Duration(seconds: step * 48));
    final base = Decimal.parse('0.00004');
    final rows = <Map<String, Object?>>[
      for (var i = 0; i < 48; i += 1)
        () {
          final wave = (i % 7) - 3;
          final open = base + Decimal.parse('0.0000004') * Decimal.fromInt(i);
          final close =
              open + Decimal.parse('0.0000003') * Decimal.fromInt(wave);
          final high = (open > close ? open : close) + Decimal.parse('2e-7');
          final low = (open < close ? open : close) - Decimal.parse('2e-7');
          return <String, Object?>{
            't': start.millisecondsSinceEpoch ~/ 1000 + i * step,
            'o': open.toString(),
            'h': high.toString(),
            'l': low.toString(),
            'c': close.toString(),
            'v': '2095493.0',
            'q': '90.0',
            'n': 3,
          };
        }(),
    ];
    return Future<Launch2CandleSeries>.value(
      LoopV2Launch2CandleCodec.series(
        <String, Object?>{
          'instanceId': l2InstanceA,
          'interval': interval.wireName,
          'quoteAsset': 'USD1',
          'source': source,
          'candles': rows,
          'latest': null,
          'contractVersion': '2.0',
        },
        instanceId: l2InstanceA,
        requested: interval,
      ),
    );
  }

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) =>
      Future<Launch2InstanceDetail>.value(detail);

  @override
  Future<Launch2Positions> loadPositions() {
    positionReads += 1;
    return _resolve(positions);
  }

  @override
  Future<Launch2PoolTrades> loadPoolTrades({
    required String instanceId,
    required String walletId,
    int limit = launch2PoolTradesShown,
  }) {
    poolTradeReads += 1;
    return _resolve(poolTrades);
  }

  @override
  Future<Launch2BuybackPage> loadBuybacks(String instanceId) =>
      Future<Launch2BuybackPage>.value(l2Buybacks());

  @override
  Future<Launch2Quote> quote({
    required String instanceId,
    required Launch2Side side,
    required Decimal amount,
    required String walletId,
  }) => _unavailable();

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
}

/// The public pool trades' gateway.
final class S285RecentTrades implements Launch2RecentPoolTradesGateway {
  S285RecentTrades(this.answer);

  S285Answer<Launch2PublicPoolTrades>? answer;
  int reads = 0;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2PublicPoolTrades> loadRecentPoolTrades(
    String instanceId, {
    int limit = launch2RecentPoolTradesLimit,
  }) {
    reads += 1;
    return _resolve(answer);
  }
}

/// One public trade item on the wire (loop-api decision 0174 §B).
Map<String, Object?> s285TradeJson({
  String side = 'buy',
  String hashDigit = 'a',
  String block = '136098447',
  String at = '2027-01-20T06:58:40.000Z',
  String meme = '16000',
  String usd1 = '10',
  String price = '0.000625',
  Object? wallet = '0x1234…abcd',
}) => <String, Object?>{
  'txHash': '0x${hashDigit * 64}',
  'blockNumber': block,
  'at': at,
  'side': side,
  'memeAmount': meme,
  'usd1Amount': usd1,
  'priceUsd1': price,
  'wallet': wallet,
};

Map<String, Object?> s285TradesJson(List<Map<String, Object?>> items) =>
    <String, Object?>{
      'instanceId': l2InstanceA,
      'items': items,
      'observedAt': '2027-01-20T07:00:00.000Z',
      'contractVersion': '2.0',
    };

Launch2PublicPoolTrades s285Trades(List<Map<String, Object?>> items) =>
    LoopV2Launch2RecentTradesCodec.recentTrades(
      s285TradesJson(items),
      instanceId: l2InstanceA,
    );

/// A day of mixed public trades for the 成交 tab.
Launch2PublicPoolTrades s285SampleTrades() => s285Trades(<Map<String, Object?>>[
  s285TradeJson(),
  s285TradeJson(
    side: 'sell',
    hashDigit: 'b',
    block: '136098440',
    at: '2027-01-20T06:58:19.000Z',
    meme: '80400',
    usd1: '49',
    price: '0.000611',
    wallet: null,
  ),
  s285TradeJson(
    hashDigit: 'c',
    block: '136098431',
    at: '2027-01-20T06:57:02.000Z',
    meme: '250000',
    usd1: '152.5',
    price: '0.000608',
    wallet: '0x9f3e…0b21',
  ),
  s285TradeJson(
    side: 'sell',
    hashDigit: 'd',
    block: '136098420',
    at: '2027-01-20T06:55:47.000Z',
    meme: '12000',
    usd1: '7.3',
    price: '0.000604',
    wallet: '0x77aa…c0de',
  ),
]);

LoopV2MetaSnapshot s285Meta() {
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

/// The project page over [launch2] and, when given, [recent].
Future<void> pumpS285Project(
  WidgetTester tester, {
  required S285Launch2 launch2,
  Launch2RecentPoolTradesGateway? recent,
  Size size = const Size(390, 2400),
  bool settle = true,
}) {
  loopArmGroundProbe(tester);
  return pumpS7Page(
    tester,
    const Launch2InstanceScreen(instanceId: l2InstanceA),
    size: size,
    settle: settle,
    meta: s285Meta(),
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
      launch2GatewayProvider.overrideWithValue(launch2),
      if (recent != null)
        launch2RecentPoolTradesGatewayProvider.overrideWithValue(recent),
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
}

/// Lets the page's timers run out before teardown.
Future<void> drainS285(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}
