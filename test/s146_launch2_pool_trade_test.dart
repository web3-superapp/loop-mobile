import 'dart:async';
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
import 'package:loop_mobile/features/launch2/launch2_candle_models.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/launch2/launch2_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/launch2_fixtures.dart';
import 'support/launch2_trade_sheet.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';
import 'support/test_hints.dart';

// ---------------------------------------------------------------------------
// S146 · MEME v2 外盘交易 on the graduated page (client decision 0145)
// ---------------------------------------------------------------------------
//
// The samples under `test/fixtures/s146-launch2-pool/` are handwritten from
// loop-api S146 (each carries `_handwritten`); there is no Development
// capture of the two pool routes yet.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _requestId = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';
const String _txHash =
    '0x3000000000000000000000000000000000000000000000000000000000000003';

Map<String, Object?> _record(String name) => jsonDecode(
  File('test/fixtures/s146-launch2-pool/$name.json').readAsStringSync(),
) as Map<String, Object?>;

Map<String, Object?> _body(String name) =>
    _record(name)['body']! as Map<String, Object?>;

Map<String, Object?> _copy(Object? value) =>
    jsonDecode(jsonEncode(value)) as Map<String, Object?>;

Launch2PoolQuote _buyQuote({bool exceeds = false}) {
  final body = _body('pool_quote_buy_exact_in');
  if (exceeds) {
    (body['quote']! as Map<String, Object?>)['exceedsBalance'] = true;
  }
  return LoopV2Launch2PoolCodec.quote(
    body,
    instanceId: l2InstanceA,
    side: Launch2Side.buy,
    mode: Launch2PoolMode.exactIn,
    walletId: l2WalletId,
  );
}

Launch2PoolQuote _sellQuote() => LoopV2Launch2PoolCodec.quote(
  _body('pool_quote_sell_exact_out'),
  instanceId: l2InstanceA,
  side: Launch2Side.sell,
  mode: Launch2PoolMode.exactOut,
  walletId: l2WalletId,
);

Launch2PoolPrepared _buyPrepared() => LoopV2Launch2PoolCodec.prepared(
  _body('pool_prepare_buy_approval'),
  instanceId: l2InstanceA,
  side: Launch2Side.buy,
  mode: Launch2PoolMode.exactIn,
  walletId: l2WalletId,
);

Launch2InstanceDetail _graduated({
  Map<String, Object?>? pool,
  bool noPool = false,
  bool noViewer = false,
}) => l2Detail(
  stage: 'graduated',
  noNextChange: true,
  noViewer: noViewer,
  pool: noPool ? null : (pool ?? l2PoolSummaryJson()),
);

// ---------------------------------------------------------------------------
// transport
// ---------------------------------------------------------------------------

final class _ScriptAdapter implements HttpClientAdapter {
  _ScriptAdapter(this.responses);

  final List<(int, Object?)> responses;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = responses.removeAt(0);
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

(DioLoopV2Launch2Api, _ScriptAdapter) _api(List<String> records) {
  final adapter = _ScriptAdapter(<(int, Object?)>[
    for (final name in records)
      (_record(name)['status']! as int, _record(name)['body']),
  ]);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = adapter;
  return (DioLoopV2Launch2Api(dio, mediaUrl: (_) => null), adapter);
}

Matcher _failure(int status, String code, String reasonCode) =>
    isA<LoopBackendFailure>()
        .having((f) => f.statusCode, 'statusCode', status)
        .having((f) => f.code, 'code', code)
        .having((f) => f.detailsSafe?.reasonCode, 'reasonCode', reasonCode);

// ---------------------------------------------------------------------------
// page harness
// ---------------------------------------------------------------------------

/// One scripted answer: a value or a failure.
final class _Answer<T> {
  const _Answer.value(T this.value) : failure = null, exception = null;
  const _Answer.fail(LoopChainFailureKind kind, {String? reasonCode})
    : value = null,
      failure = (kind, reasonCode),
      exception = null;

  /// A refusal carrying the server's figures (decision 0153).
  const _Answer.error(LoopChainException this.exception)
    : value = null,
      failure = null;

  final T? value;
  final (LoopChainFailureKind, String?)? failure;
  final LoopChainException? exception;

  Future<T> resolve() {
    final thrown = exception;
    if (thrown != null) return Future<T>.error(thrown);
    final f = failure;
    if (f != null) {
      return Future<T>.error(LoopChainException(f.$1, reasonCode: f.$2));
    }
    return Future<T>.value(value as T);
  }
}

final class _FakePool implements Launch2Gateway {
  // S267 (decision 0227): no K line in these fixtures; the card hides.
  @override
  Future<Launch2CandleSeries> candles(
    String instanceId,
    Launch2CandleInterval interval, {
    int limit = launch2CandlePageSize,
    DateTime? before,
  }) => Future<Launch2CandleSeries>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  _FakePool({
    required this.details,
    List<_Answer<Launch2PoolQuote>>? quotes,
    List<_Answer<Launch2PoolPrepared>>? prepares,
  }) : quotes = quotes ?? <_Answer<Launch2PoolQuote>>[],
       prepares = prepares ?? <_Answer<Launch2PoolPrepared>>[];

  final List<Launch2InstanceDetail> details;
  final List<_Answer<Launch2PoolQuote>> quotes;
  final List<_Answer<Launch2PoolPrepared>> prepares;
  final List<Map<String, Object?>> quoteCalls = <Map<String, Object?>>[];
  final List<Map<String, Object?>> prepareCalls = <Map<String, Object?>>[];
  int detailReads = 0;

  static T _pick<T>(List<T> answers, int index) =>
      answers[index < answers.length ? index : answers.length - 1];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  Future<Never> _unavailable() => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) {
    final index = detailReads;
    detailReads += 1;
    return Future<Launch2InstanceDetail>.value(_pick(details, index));
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
    final index = quoteCalls.length;
    quoteCalls.add(<String, Object?>{
      'side': side,
      'mode': mode,
      'amount': amount,
      'slippageBps': slippageBps,
    });
    if (quotes.isEmpty) return _unavailable();
    return _pick(quotes, index).resolve();
  }

  @override
  Future<Launch2PoolPrepared> preparePoolTrade({
    required String instanceId,
    required String walletId,
    required Launch2Side side,
    required Launch2PoolMode mode,
    required Decimal amount,
    required int slippageBps,
  }) {
    final index = prepareCalls.length;
    prepareCalls.add(<String, Object?>{
      'side': side,
      'mode': mode,
      'amount': amount,
      'slippageBps': slippageBps,
    });
    if (prepares.isEmpty) return _unavailable();
    return _pick(prepares, index).resolve();
  }

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

  /// Decision 0148: the wallet's own pool trades.
  _Answer<Launch2PoolTrades>? poolTrades;
  int poolTradeReads = 0;

  @override
  Future<Launch2PoolTrades> loadPoolTrades({
    required String instanceId,
    required String walletId,
    int limit = launch2PoolTradesShown,
  }) {
    poolTradeReads += 1;
    return poolTrades?.resolve() ?? _unavailable();
  }
}

final class _RecordingWallet implements WalletSigningGateway {
  _RecordingWallet({this.onHandoff});

  /// Runs before each answer (decision 0148: a slow approval moves the
  /// clock).
  final void Function(SigningIntent intent)? onHandoff;

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
    onHandoff?.call(intent);
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

/// Opens the graduated page and, unless [sheet] is false, the 外盘 trade
/// sheet behind its 买入 key (decision 0240).
Future<void> _open(
  WidgetTester tester,
  _FakePool gateway, {
  _RecordingWallet? wallet,
  bool hasWallet = true,
  bool sheet = true,
}) async {
  await _openPage(tester, gateway, wallet: wallet, hasWallet: hasWallet);
  if (sheet) await l2OpenTradeSheet(tester);
}

Future<void> _openPage(
  WidgetTester tester,
  _FakePool gateway, {
  _RecordingWallet? wallet,
  bool hasWallet = true,
}) => pumpS7Page(
  tester,
  const Launch2InstanceScreen(instanceId: l2InstanceA),
  meta: _meta(),
  wallet: FakeWalletDirectory(
    activeWalletId: hasWallet ? l2WalletId : null,
    wallets: hasWallet ? <LoopWalletAccount>[_wallet()] : <LoopWalletAccount>[],
  ),
  overrides: <Override>[
    launch2GatewayProvider.overrideWithValue(gateway),
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

/// The fixed bar's 买入 action (decision 0240), `null` while disabled.
VoidCallback? _barBuy(WidgetTester tester) =>
    tester.widget<LoopButton>(_key('launch2-bar-buy')).onPressed;

VoidCallback? _confirmCallback(WidgetTester tester) =>
    (tester.widget<Widget>(_key('launch2-pool-confirm')) as dynamic).onPressed
        as VoidCallback?;

void main() {
  // S237 · decision 0204: these cases pin the testnet / specimen behaviour.
  loopShowTestHints();

  loopWatchGround();

  group('codec (loop-api S146 pool routes)', () {
    test('a buy exactIn quote decodes; the tax is MEME, taxUsd1 is 0', () {
      final quote = _buyQuote();
      expect(quote.side, Launch2Side.buy);
      expect(quote.mode, Launch2PoolMode.exactIn);
      expect(quote.amountIn, Decimal.fromInt(100));
      expect(quote.expectedOut, Decimal.fromInt(147000));
      expect(quote.minOut, Decimal.fromInt(145530));
      expect(quote.taxBps, 200);
      expect(quote.taxToken, Launch2PoolTaxToken.meme);
      expect(quote.taxAmount, Decimal.fromInt(3000));
      expect(quote.taxUsd1, Decimal.zero);
      expect(quote.balanceMeme, Decimal.fromInt(250000));
      expect(quote.router, l2Router);
      expect(quote.poolId, l2PoolId);
      expect(quote.quotedAtBlock, BigInt.from(1500));
      expect(quote.expiresAt, DateTime.utc(2027, 1, 20, 7, 1));
    });

    test('a sell exactOut quote decodes with maxIn above amountIn', () {
      final quote = _sellQuote();
      expect(quote.mode, Launch2PoolMode.exactOut);
      expect(quote.taxToken, Launch2PoolTaxToken.usd1);
      expect(quote.maxIn, Decimal.fromInt(76760));
      expect(quote.inputBalance, Decimal.fromInt(250000));
    });

    test('a quote for another side, mode, wallet, venue or tax token, or '
        'with an unknown key, is refused', () {
      void refuses(
        void Function(Map<String, Object?> quote) edit, {
        Launch2Side side = Launch2Side.buy,
        Launch2PoolMode mode = Launch2PoolMode.exactIn,
      }) {
        final body = _copy(_body('pool_quote_buy_exact_in'));
        edit(body['quote']! as Map<String, Object?>);
        expect(
          () => LoopV2Launch2PoolCodec.quote(
            body,
            instanceId: l2InstanceA,
            side: side,
            mode: mode,
            walletId: l2WalletId,
          ),
          throwsA(isA<LoopBackendFailure>()),
          reason: 'edit should be refused',
        );
      }

      refuses((_) {}, side: Launch2Side.sell);
      refuses((_) {}, mode: Launch2PoolMode.exactOut);
      refuses((q) => q['walletId'] = '00000000-0000-4000-8000-000000000001');
      refuses((q) => q['venue'] = 'curve');
      refuses((q) => q['stage'] = 'public');
      refuses((q) => q['taxToken'] = 'usd1');
      refuses((q) => q['minOut'] = '999999');
      refuses((q) => q['extra'] = 1);
      refuses((q) => q.remove('balance'));
    });

    test('the prepare: pool_buy with a router approval reads as a buy on '
        'the official pool', () {
      final prepared = _buyPrepared();
      final intent = prepared.intent;
      expect(intent.kind, Launch2IntentKind.buy);
      expect(intent.venue, Launch2Venue.officialPool);
      expect(intent.taxBps, 200);
      expect(intent.contractAddress, l2Router);
      expect(intent.approval!.spender, l2Router);
      expect(intent.approval!.token, l2Usd1);
      expect(intent.payloadMatchesReview, isTrue);
      expect(prepared.quote.requestedAmount, Decimal.fromInt(100));
    });

    test('a prepare sent elsewhere, of a curve kind, or a pool kind on a '
        'curve route is refused', () {
      void refuses(void Function(Map<String, Object?> body) edit) {
        final body = _copy(_body('pool_prepare_buy_approval'));
        edit(body);
        expect(
          () => LoopV2Launch2PoolCodec.prepared(
            body,
            instanceId: l2InstanceA,
            side: Launch2Side.buy,
            mode: Launch2PoolMode.exactIn,
            walletId: l2WalletId,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
      }

      Map<String, Object?> intentOf(Map<String, Object?> body) =>
          body['launch2Intent']! as Map<String, Object?>;
      refuses((b) => intentOf(b)['kind'] = 'buy');
      refuses((b) => intentOf(b)['kind'] = 'pool_sell');
      refuses((b) => b.remove('quote'));
      refuses(
        (b) => (b['quote']! as Map<String, Object?>)['router'] =
            '0x1111111111111111111111111111111111111111',
      );
      // The curve route never answers a pool kind.
      final curve = _copy(_body('pool_prepare_buy_approval'))..remove('quote');
      expect(
        () => LoopV2Launch2Codec.intent(curve),
        throwsA(isA<LoopBackendFailure>()),
      );
      // A sell that already holds the allowance has no approval.
      final sell = LoopV2Launch2PoolCodec.prepared(
        _body('pool_prepare_sell_ready'),
        instanceId: l2InstanceA,
        side: Launch2Side.sell,
        mode: Launch2PoolMode.exactOut,
        walletId: l2WalletId,
      );
      expect(sell.intent.kind, Launch2IntentKind.sell);
      expect(sell.intent.approval, isNull);
    });

    test('the detail reads pool, absent pool, and refuses a pool with an '
        'unknown key', () {
      final detail = _graduated();
      final pool = detail.pool!;
      expect(pool.tradeCount, BigInt.from(12));
      expect(pool.buyCount, BigInt.from(8));
      expect(pool.lastPriceUsd1, Decimal.parse('0.00068'));
      expect(pool.router, l2Router);
      expect(_graduated(noPool: true).pool, isNull);
      expect(
        LoopV2Launch2Codec.detail(
          l2DetailJson(stage: 'graduated', includePool: true),
          mediaUrl: (_) => null,
        ).pool,
        isNull,
      );
      expect(
        () => LoopV2Launch2Codec.detail(
          l2DetailJson(
            stage: 'graduated',
            pool: <String, Object?>{...l2PoolSummaryJson(), 'extra': 1},
          ),
          mediaUrl: (_) => null,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('transport', () {
    test('the quote asks side, mode, amount, wallet and slippage; no '
        'idempotency key', () async {
      final (api, adapter) = _api(<String>['pool_quote_buy_exact_in']);
      final quote = await api.getPoolQuote(
        accessToken: 'token',
        clientVersion: '1.0.0',
        instanceId: l2InstanceA,
        side: Launch2Side.buy,
        mode: Launch2PoolMode.exactIn,
        amount: Decimal.fromInt(100),
        slippageBps: 100,
        walletId: l2WalletId,
      );
      expect(quote.expectedOut, Decimal.fromInt(147000));
      final sent = adapter.requests.single;
      expect(sent.method, 'GET');
      expect(sent.path, '/v2/launch2/instances/$l2InstanceA/pool/quote');
      expect(sent.queryParameters, <String, Object?>{
        'side': 'buy',
        'mode': 'exactIn',
        'amount': '100',
        'walletId': l2WalletId,
        'slippageBps': '100',
      });
      expect(sent.headers['idempotency-key'], isNull);
    });

    test('the prepare posts the body with one idempotency key', () async {
      final (api, adapter) = _api(<String>['pool_prepare_buy_approval']);
      final prepared = await api.postPoolTradePrepare(
        accessToken: 'token',
        clientVersion: '1.0.0',
        idempotencyKey: '4f1c2d3e-5a6b-4c7d-8e9f-0a1b2c3d4e5f',
        instanceId: l2InstanceA,
        walletId: l2WalletId,
        side: Launch2Side.buy,
        mode: Launch2PoolMode.exactIn,
        amount: Decimal.fromInt(100),
        slippageBps: 100,
      );
      expect(prepared.intent.venue, Launch2Venue.officialPool);
      final sent = adapter.requests.single;
      expect(sent.method, 'POST');
      expect(
        sent.path,
        '/v2/launch2/instances/$l2InstanceA/pool/trade/prepare',
      );
      expect(sent.data, <String, Object?>{
        'walletId': l2WalletId,
        'side': 'buy',
        'mode': 'exactIn',
        'amount': '100',
        'slippageBps': 100,
      });
      expect(
        sent.headers['idempotency-key'],
        '4f1c2d3e-5a6b-4c7d-8e9f-0a1b2c3d4e5f',
      );
    });

    test('quote unavailable, not graduated and no router keep the server '
        'reason', () async {
      Future<Launch2PoolQuote> ask(String record) {
        final (api, _) = _api(<String>[record]);
        return api.getPoolQuote(
          accessToken: 'token',
          clientVersion: '1.0.0',
          instanceId: l2InstanceA,
          side: Launch2Side.buy,
          mode: Launch2PoolMode.exactIn,
          amount: Decimal.fromInt(100),
          slippageBps: 100,
          walletId: l2WalletId,
        );
      }

      await expectLater(
        ask('error_pool_quote_unavailable'),
        throwsA(_failure(422, 'VALIDATION_FAILED', 'POOL_QUOTE_UNAVAILABLE')),
      );
      await expectLater(
        ask('error_pool_not_graduated'),
        throwsA(_failure(422, 'VALIDATION_FAILED', 'POOL_NOT_GRADUATED')),
      );
      await expectLater(
        ask('error_pool_router_not_configured'),
        throwsA(
          _failure(503, 'CAPABILITY_UNAVAILABLE', 'POOL_ROUTER_NOT_CONFIGURED'),
        ),
      );
    });
  });

  group('view model', () {
    Launch2PoolTradeView view({
      Launch2InstanceDetail? detail,
      String? walletId = l2WalletId,
      Launch2Side side = Launch2Side.buy,
      Launch2PoolMode mode = Launch2PoolMode.exactIn,
      String? amount = '100',
      int? slippage = 100,
      Launch2PoolQuote? quote,
      bool quoting = false,
      bool preparing = false,
      bool locked = false,
      LoopChainException? failure,
      Launch2PoolHolding? holding,
    }) => launch2PoolTradeView(
      detail: detail ?? _graduated(),
      walletId: walletId,
      side: side,
      mode: mode,
      amount: amount == null ? null : Decimal.parse(amount),
      slippageBps: slippage,
      quote: quote,
      quoting: quoting,
      preparing: preparing,
      locked: locked,
      quoteFailure: failure,
      holding: holding,
    );

    test('the field says what the mode fixes, per side', () {
      expect(launch2PoolField(Launch2Side.buy, Launch2PoolMode.exactIn, 'F'), (
        '支付（含税）',
        'USD1',
      ));
      expect(launch2PoolField(Launch2Side.buy, Launch2PoolMode.exactOut, 'F'), (
        '想买入',
        r'$F',
      ));
      expect(launch2PoolField(Launch2Side.sell, Launch2PoolMode.exactIn, 'F'), (
        '卖出',
        r'$F',
      ));
      expect(
        launch2PoolField(Launch2Side.sell, Launch2PoolMode.exactOut, 'F'),
        ('想到手', 'USD1'),
      );
    });

    test('a buy exactIn quote: expected, least, the 2% tax in MEME, the '
        'average price and the slippage; confirm opens', () {
      final v = view(quote: _buyQuote());
      expect(v.taxLabel, '外盘税 2%');
      expect(v.lines.map((l) => '${l.label}=${l.value}').toList(), <String>[
        r'预计获得=147,000 $FROG',
        r'最少获得=145,530 $FROG',
        r'外盘税 2%=3,000 $FROG',
        '成交均价=${v.lines[3].value}',
        '滑点上限=1%',
      ]);
      expect(v.canConfirm, isTrue);
      expect(v.confirmLabel, '确认买入');
      expect(v.provenance, contains('区块 1500'));
    });

    test('a sell exactOut quote: what is sold at most and the USD1 tax', () {
      final v = view(
        side: Launch2Side.sell,
        mode: Launch2PoolMode.exactOut,
        amount: '50',
        quote: _sellQuote(),
      );
      final labels = v.lines.map((l) => l.label).toList();
      expect(labels.take(3), <String>['预计卖出', '最多卖出', '外盘税 2%']);
      expect(v.lines[1].value, r'76,760 $FROG');
      expect(v.lines[2].value, endsWith('USD1'));
      expect(v.confirmLabel, '确认卖出');
      expect(v.canConfirm, isTrue);
    });

    test('blocked: not graduated, no router, no wallet', () {
      expect(
        view(detail: l2Detail(stage: 'public')).blockedLine,
        '项目还没有毕业，官方池尚未开放',
      );
      expect(
        view(detail: _graduated(pool: l2PoolSummaryJson(router: null)))
            .blockedLine,
        contains('路由未配置'),
      );
      final noWallet = view(walletId: null, quote: _buyQuote());
      expect(noWallet.blockedLine, '还没有可用的钱包，激活钱包后可交易');
      expect(noWallet.canConfirm, isFalse);
    });

    test('a sell above what can be sold is refused before any quote; MAX '
        'shows only for a sell typed in MEME', () {
      final holding = Launch2PoolHolding(balance: Decimal.ten);
      final v = view(side: Launch2Side.sell, amount: '11', holding: holding);
      expect(v.overHolding, isTrue);
      expect(v.quotePlaceholder, contains('卖出数量超过可卖'));
      expect(v.canConfirm, isFalse);
      expect(v.showMax, isTrue);
      expect(v.holdingLine, r'持有 10 $FROG · 可卖 10 $FROG');
      expect(view(holding: holding).showMax, isFalse);
      expect(
        view(
          side: Launch2Side.sell,
          mode: Launch2PoolMode.exactOut,
          holding: holding,
        ).showMax,
        isFalse,
      );
    });

    test('before a quote the curve net is said as what it is, not as a '
        'balance', () {
      final detail = l2Detail(
        stage: 'graduated',
        noNextChange: true,
        viewer: l2ViewerJson(bought: '1000', net: '1000'),
        pool: l2PoolSummaryJson(),
      );
      expect(
        view(detail: detail).holdingLine,
        r'内盘净买入 1,000 $FROG · 钱包余额报价后显示',
      );
      expect(view().holdingLine, isNull);
      expect(
        view(
          detail: detail,
          holding: launch2PoolHoldingOf(quote: _buyQuote()),
        ).holdingLine,
        r'持有 250,000 $FROG',
      );
    });

    test('exceedsBalance says how much is missing and keeps confirm shut', () {
      final v = view(quote: _buyQuote(exceeds: true));
      expect(v.balanceLine, startsWith('USD1 余额不足'));
      expect(v.canConfirm, isFalse);
    });

    test('loading, empty, error and locked each say their own line', () {
      expect(view(amount: null).quotePlaceholder, '输入金额后显示报价');
      expect(view(quoting: true).quotePlaceholder, '正在向官方池报价…');
      final failed = view(
        failure: const LoopChainException(
          LoopChainFailureKind.validationFailed,
          reasonCode: 'POOL_QUOTE_UNAVAILABLE',
        ),
      );
      expect(failed.quoteFailureLine, '没有取到报价 · 官方池试算没有通过，换个金额再试');
      expect(failed.quotePlaceholder, isNull);
      final offline = view(
        failure: const LoopChainException(LoopChainFailureKind.offline),
      );
      expect(offline.quoteFailureLine, startsWith('没有取到报价 · '));
      final locked = view(quote: _buyQuote(), locked: true);
      expect(locked.canConfirm, isFalse);
      expect(locked.confirmLabel, '上一笔确认中…');
      expect(view(quote: _buyQuote(), slippage: null).canConfirm, isFalse);
      expect(
        view(quote: _buyQuote(), mode: Launch2PoolMode.exactOut).canConfirm,
        isFalse,
      );
    });

    test('the pool refusals read in zh-CN', () {
      expect(launch2PoolReasonText('POOL_NOT_GRADUATED'), '项目还没有毕业，官方池尚未开放');
      expect(
        launch2PoolReasonText('POOL_INSUFFICIENT_LIQUIDITY'),
        contains('流动性不足'),
      );
      expect(launch2PoolReasonText('POOL_QUOTE_ZERO'), contains('为 0'));
      expect(
        launch2PoolReasonText('POOL_ROUTER_NOT_CONFIGURED'),
        '外盘交易暂时关闭，平台正在核对官方池',
      );
      expect(
        launch2PoolReasonText('LAUNCH2_USD1_BALANCE_INSUFFICIENT'),
        contains('USD1 余额不足'),
      );
      // Anything else falls through to the curve catalogue.
      expect(
        launch2PoolReasonText('LAUNCH2_GAS_INSUFFICIENT'),
        contains('手续费'),
      );
    });

    test('slippage input: two decimals, 0.01–50', () {
      expect(launch2PoolSlippageFromInput('0.5'), 50);
      expect(launch2PoolSlippageFromInput('3'), 300);
      expect(launch2PoolSlippageFromInput('50'), 5000);
      expect(launch2PoolSlippageFromInput('0'), isNull);
      expect(launch2PoolSlippageFromInput('51'), isNull);
      expect(launch2PoolSlippageFromInput('0.001'), isNull);
      expect(launch2PoolSlippageFromInput('abc'), isNull);
    });

    test('the signing facts name the router and the 2% pool tax', () {
      final intent = _buyPrepared().intent;
      final fields = launch2IntentFields(intent, ticker: 'FROG');
      final byLabel = <String, String>{
        for (final f in fields) f.label: f.value,
      };
      expect(byLabel['操作'], r'在官方池买入 $FROG');
      // A pool buy is taxed in MEME, taken from what it receives.
      expect(byLabel['外盘税 2%'], r'3,000 $FROG');
      expect(byLabel['最多支付'], '100 USD1');
      // Decision 0148: the amount alone; the spender is the address row.
      expect(byLabel['先授权'], '100 USD1');
      expect(byLabel['授权给官方池路由'], isNotNull);
      expect(byLabel.containsKey('路由'), isFalse);
      expect(byLabel.containsKey('税 10%'), isFalse);
      expect(launch2IntentTitle(intent.kind, venue: intent.venue), '确认外盘买入');
    });
  });

  group('graduated page · 外盘交易', () {
    testWidgets('the pool figures and the panel replace 去外盘交易; the swap '
        'is one secondary link', (tester) async {
      final opened = <String>[];
      await pumpS7Page(
        tester,
        Launch2InstanceScreen(instanceId: l2InstanceA, onNavigate: opened.add),
        meta: _meta(),
        wallet: FakeWalletDirectory(
          activeWalletId: l2WalletId,
          wallets: <LoopWalletAccount>[_wallet()],
        ),
        overrides: <Override>[
          launch2GatewayProvider.overrideWithValue(
            _FakePool(details: <Launch2InstanceDetail>[_graduated()]),
          ),
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
      // Decision 0240: the pool's figures and the swap link are the 信息
      // tab's; the panel is the sheet behind 买入.
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await l2OpenTab(tester, 'info');
      // S294 · decision 0244: no pool rows on 信息 any more.
      expect(_key('launch2-pool-stats'), findsNothing);
      expect(find.text('外盘最新价'), findsNothing);
      expect(find.text('12 笔 · 买 8 / 卖 4'), findsNothing);
      expect(find.text('去外盘交易'), findsNothing);
      await _scrollTo(tester, _key('launch2-go-swap'));
      await tester.tap(_key('launch2-go-swap'));
      expect(opened.single, '/wallet/swap?to=eip155%3A97%3A$l2Meme');
      await l2OpenTradeSheet(tester);
      expect(_key('launch2-pool-panel'), findsOneWidget);
      expect(find.text('外盘税 2%'), findsWidgets);
      // The 44 pt rule (iOS guideline), around the panel.
      await _scrollTo(tester, _key('launch2-pool-confirm'));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await _drain(tester);
    });

    testWidgets('a pool that has not synced: 信息 draws no pool rows; the '
        'panel stays', (tester) async {
      await _open(
        tester,
        _FakePool(details: <Launch2InstanceDetail>[_graduated(noPool: true)]),
        sheet: false,
      );
      await l2OpenTab(tester, 'info');
      // S294 · decision 0244: the rows and their 还在同步 line are gone.
      expect(_key('launch2-pool-stats-unavailable'), findsNothing);
      expect(_key('launch2-graduated'), findsOneWidget);
      await l2OpenTradeSheet(tester);
      expect(_key('launch2-pool-panel'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('no wallet: the panel is grey with the reason and asks '
        'nothing', (tester) async {
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[_graduated(noViewer: true)],
        quotes: <_Answer<Launch2PoolQuote>>[
          _Answer<Launch2PoolQuote>.value(_buyQuote()),
        ],
      );
      await _open(tester, gateway, hasWallet: false);
      expect(_key('launch2-pool-blocked'), findsOneWidget);
      expect(
        tester.widget<Launch2Greyed>(_key('launch2-pool-controls')).greyed,
        isTrue,
      );
      expect(gateway.quoteCalls, isEmpty);
      await _drain(tester);
    });

    testWidgets('loading, then the quote; approval + buy go through the '
        'two-step signing exit', (tester) async {
      final wallet = _RecordingWallet();
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[_graduated()],
        quotes: <_Answer<Launch2PoolQuote>>[
          _Answer<Launch2PoolQuote>.value(_buyQuote()),
        ],
        prepares: <_Answer<Launch2PoolPrepared>>[
          _Answer<Launch2PoolPrepared>.value(_buyPrepared()),
        ],
      );
      await _open(tester, gateway, wallet: wallet);
      expect(find.text('输入金额后显示报价'), findsOneWidget);
      await _scrollTo(tester, _key('launch2-pool-amount'));
      await tester.enterText(_key('launch2-pool-amount'), '100');
      await tester.pump();
      expect(find.text('正在向官方池报价…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(gateway.quoteCalls.single, <String, Object?>{
        'side': Launch2Side.buy,
        'mode': Launch2PoolMode.exactIn,
        'amount': Decimal.fromInt(100),
        'slippageBps': 100,
      });
      expect(_key('launch2-pool-quote'), findsOneWidget);
      expect(find.text(r'145,530 $FROG'), findsOneWidget);
      expect(find.text(r'持有 250,000 $FROG'), findsOneWidget);
      await _scrollTo(tester, _key('launch2-pool-confirm'));
      await tester.tap(_key('launch2-pool-confirm'));
      await tester.pumpAndSettle();
      expect(gateway.prepareCalls.single['amount'], Decimal.fromInt(100));
      expect(gateway.prepareCalls.single['slippageBps'], 100);
      expect(_key('launch2-sign-sheet'), findsOneWidget);
      expect(find.text('确认外盘买入'), findsOneWidget);
      expect(_key('launch2-sign-steps'), findsOneWidget);
      expect(_key('launch2-sign-step-approval-waiting'), findsOneWidget);
      expect(_key('launch2-sign-step-main-waiting'), findsOneWidget);
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(wallet.handed.map((i) => i.kind).toList(), <IntentKind>[
        IntentKind.launchApproval,
        IntentKind.launchPurchase,
      ]);
      expect(_key('launch2-sign-step-approval-done'), findsOneWidget);
      expect(_key('launch2-sign-step-main-done'), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(_key('launch2-pending'), findsOneWidget);
      expect(find.textContaining('广播不代表已成交'), findsOneWidget);
      // Our broadcast is settling: the sheet closed and the bar offers no
      // second signature (decision 0240).
      expect(_key('launch2-trade-sheet'), findsNothing);
      expect(_barBuy(tester), isNull);
      expect(_key('launch2-bar-reason'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('the pool count moving settles our broadcast', (tester) async {
      final wallet = _RecordingWallet();
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[
          _graduated(),
          _graduated(pool: l2PoolSummaryJson(tradeCount: '13')),
        ],
        quotes: <_Answer<Launch2PoolQuote>>[
          _Answer<Launch2PoolQuote>.value(_buyQuote()),
        ],
        prepares: <_Answer<Launch2PoolPrepared>>[
          _Answer<Launch2PoolPrepared>.value(_buyPrepared()),
        ],
      );
      await _open(tester, gateway, wallet: wallet);
      await _type(tester, '100');
      await _scrollTo(tester, _key('launch2-pool-confirm'));
      await tester.tap(_key('launch2-pool-confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(gateway.detailReads, greaterThanOrEqualTo(2));
      expect(find.textContaining('官方池已记录新成交'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('quote unavailable and not graduated stay one line in the '
        'panel; no error page', (tester) async {
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[_graduated()],
        quotes: <_Answer<Launch2PoolQuote>>[
          const _Answer<Launch2PoolQuote>.fail(
            LoopChainFailureKind.validationFailed,
            reasonCode: 'POOL_QUOTE_UNAVAILABLE',
          ),
          const _Answer<Launch2PoolQuote>.fail(
            LoopChainFailureKind.validationFailed,
            reasonCode: 'POOL_NOT_GRADUATED',
          ),
        ],
      );
      await _open(tester, gateway);
      await _type(tester, '100');
      expect(_key('launch2-pool-quote-failed'), findsOneWidget);
      expect(find.text('没有取到报价 · 官方池试算没有通过，换个金额再试'), findsOneWidget);
      expect(_confirmCallback(tester), isNull);
      await _type(tester, '101');
      expect(find.text('没有取到报价 · 项目还没有毕业，官方池尚未开放'), findsOneWidget);
      expect(_key('launch2-instance-error'), findsNothing);
      await _drain(tester);
    });

    // Decision 0225: a quote refused for the balance says the shortfall with
    // 去充值, not 「没有取到报价」.
    testWidgets('a quote refused for the USD1 balance offers 去充值', (
      tester,
    ) async {
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[_graduated()],
        quotes: <_Answer<Launch2PoolQuote>>[
          const _Answer<Launch2PoolQuote>.fail(
            LoopChainFailureKind.insufficientBalance,
            reasonCode: 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
          ),
        ],
      );
      await _open(tester, gateway);
      await _type(tester, '100');
      expect(_key('launch2-pool-quote-failed'), findsNothing);
      expect(_key('launch2-pool-quote-short'), findsOneWidget);
      expect(find.textContaining('没有取到报价'), findsNothing);
      expect(_key('launch2-pool-quote-topup'), findsOneWidget);
      expect(_confirmCallback(tester), isNull);
      await _drain(tester);
    });

    testWidgets('a prepare refusal stays one line; offline quote says so', (
      tester,
    ) async {
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[_graduated()],
        quotes: <_Answer<Launch2PoolQuote>>[
          _Answer<Launch2PoolQuote>.value(_buyQuote()),
          const _Answer<Launch2PoolQuote>.fail(LoopChainFailureKind.offline),
        ],
        prepares: <_Answer<Launch2PoolPrepared>>[
          const _Answer<Launch2PoolPrepared>.fail(
            LoopChainFailureKind.insufficientBalance,
            reasonCode: 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
          ),
        ],
      );
      await _open(tester, gateway);
      await _type(tester, '100');
      await _scrollTo(tester, _key('launch2-pool-confirm'));
      await tester.tap(_key('launch2-pool-confirm'));
      await tester.pumpAndSettle();
      expect(_key('launch2-pool-prepare-failed'), findsOneWidget);
      expect(find.text('USD1 余额不足，没有发起任何交易'), findsOneWidget);
      expect(_key('launch2-sign-sheet'), findsNothing);
      await _type(tester, '99');
      expect(_key('launch2-pool-quote-failed'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('0153 · USD1 short: required and balance above the confirm '
        'button, a live region, 去充值; tBNB short says the fee', (tester) async {
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[_graduated()],
        quotes: <_Answer<Launch2PoolQuote>>[
          _Answer<Launch2PoolQuote>.value(_buyQuote()),
        ],
        prepares: <_Answer<Launch2PoolPrepared>>[
          const _Answer<Launch2PoolPrepared>.error(
            LoopChainException(
              LoopChainFailureKind.insufficientBalance,
              reasonCode: 'LAUNCH2_USD1_BALANCE_INSUFFICIENT',
              requiredAmountIn: '100.5',
              maxAmountIn: '20',
            ),
          ),
          const _Answer<Launch2PoolPrepared>.fail(
            LoopChainFailureKind.insufficientBalance,
            reasonCode: 'LAUNCH2_GAS_INSUFFICIENT',
          ),
          const _Answer<Launch2PoolPrepared>.error(
            LoopChainException(
              LoopChainFailureKind.insufficientBalance,
              reasonCode: 'LAUNCH2_GAS_INSUFFICIENT',
              requiredBnb: '0.000412',
              balanceBnb: '0.0001',
            ),
          ),
        ],
      );
      await _open(tester, gateway);
      await _type(tester, '100');
      await _scrollTo(tester, _key('launch2-pool-confirm'));
      await tester.tap(_key('launch2-pool-confirm'));
      await tester.pumpAndSettle();
      final line = _key('launch2-pool-prepare-failed');
      expect(
        find.descendant(
          of: line,
          matching: find.text('USD1 余额不足：需要 100.5 USD1，当前 20 USD1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: line,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && (widget.properties.liveRegion ?? false),
          ),
        ),
        findsOneWidget,
      );
      expect(_key('launch2-pool-topup'), findsOneWidget);
      expect(
        tester.getRect(line).bottom,
        lessThanOrEqualTo(tester.getRect(_key('launch2-pool-confirm')).top),
      );
      await tester.tap(_key('launch2-pool-confirm'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: line, matching: find.text(launch2GasShortText)),
        findsOneWidget,
      );
      expect(_key('launch2-pool-topup'), findsOneWidget);
      // Decision 0156: the same refusal with the server's figures.
      await tester.tap(_key('launch2-pool-confirm'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: line,
          matching: find.text(
            'tBNB 手续费不足：这笔约需 0.000412 tBNB，钱包有 0.0001 tBNB，充值后再试',
          ),
        ),
        findsOneWidget,
      );
      expect(_key('launch2-pool-topup'), findsOneWidget);
      expect(_key('launch2-sign-sheet'), findsNothing);
      await _drain(tester);
    });

    testWidgets('sell, by what lands (exactOut), with a typed slippage', (
      tester,
    ) async {
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[_graduated()],
        quotes: <_Answer<Launch2PoolQuote>>[
          _Answer<Launch2PoolQuote>.value(_sellQuote()),
        ],
      );
      // Decision 0240: the bar's 卖出 opens the panel on the sell side.
      await _open(tester, gateway, sheet: false);
      await l2OpenTradeSheet(tester, sell: true);
      await tester.tap(_key('launch2-pool-mode-exactOut'));
      await tester.pumpAndSettle();
      expect(find.text('想到手'), findsOneWidget);
      await _scrollTo(tester, _key('launch2-pool-slippage-custom'));
      await tester.tap(_key('launch2-pool-slippage-custom'));
      await tester.pumpAndSettle();
      await tester.enterText(
        _key('launch2-pool-slippage-custom-input'),
        '0.75',
      );
      await _type(tester, '50');
      expect(gateway.quoteCalls.last, <String, Object?>{
        'side': Launch2Side.sell,
        'mode': Launch2PoolMode.exactOut,
        'amount': Decimal.fromInt(50),
        'slippageBps': 75,
      });
      expect(find.text('最多卖出'), findsOneWidget);
      await _drain(tester);
    });
  });

  group('0148 · S150 follow-ups on the graduated page', () {
    Map<String, Object?> s150(String name) => jsonDecode(
      File('test/fixtures/s150-launch2/$name.json').readAsStringSync(),
    ) as Map<String, Object?>;

    Launch2PoolPrepared s150Prepared(String name) =>
        LoopV2Launch2PoolCodec.prepared(
          s150(name)['body'],
          instanceId: l2InstanceA,
          side: Launch2Side.buy,
          mode: Launch2PoolMode.exactIn,
          walletId: l2WalletId,
        );

    Launch2InstanceDetail held({
      Map<String, Object?>? holding,
      Map<String, Object?>? pool,
    }) => l2Detail(
      stage: 'graduated',
      noNextChange: true,
      viewer: l2ViewerJson(holding: holding ?? l2HoldingJson()),
      pool: pool ?? l2PoolSummaryJson(),
    );

    /// The page's clock, moved by a slow approval.
    DateTime now = l2Now;

    Future<void> openPageAt(
      WidgetTester tester,
      _FakePool gateway, {
      _RecordingWallet? wallet,
    }) => pumpS7Page(
      tester,
      const Launch2InstanceScreen(instanceId: l2InstanceA),
      meta: _meta(),
      wallet: FakeWalletDirectory(
        activeWalletId: l2WalletId,
        wallets: <LoopWalletAccount>[_wallet()],
      ),
      overrides: <Override>[
        launch2GatewayProvider.overrideWithValue(gateway),
        launch2ClockProvider.overrideWithValue(() => now),
        launch2PollingProvider.overrideWithValue(
          const Launch2Polling(
            detailInterval: Duration(hours: 1),
            tradingInterval: Duration(hours: 1),
          ),
        ),
        launch2IntentSignerProvider.overrideWith(
          (ref) => Launch2IntentSigner(
            wallet: ref.watch(walletSigningGatewayProvider),
            refreshRetryDelay: Duration.zero,
          ),
        ),
        loopFeatureSwitchesProvider.overrideWithValue(
          const LoopFeatureSwitchValues(launch2Visible: true),
        ),
        if (wallet != null)
          walletSigningGatewayProvider.overrideWithValue(wallet),
      ],
    );

    Future<void> openAt(
      WidgetTester tester,
      _FakePool gateway, {
      _RecordingWallet? wallet,
      bool sheet = true,
    }) async {
      await openPageAt(tester, gateway, wallet: wallet);
      if (sheet) await l2OpenTradeSheet(tester);
    }

    setUp(() => now = l2Now);

    testWidgets('the server balance is there before any quote; the quote '
        'balance is only the fallback', (tester) async {
      final gateway = _FakePool(details: <Launch2InstanceDetail>[held()]);
      await openAt(tester, gateway);
      await _scrollTo(tester, _key('launch2-pool-holding'));
      // Decision 0149: the buy side says what is held, once.
      expect(find.text(r'持有 7,333.18 $FROG'), findsOneWidget);
      expect(gateway.quoteCalls, isEmpty);
      // MAX on a sell fills the server's balance, still before any quote.
      await tester.tap(
        find.descendant(
          of: _key('launch2-pool-side'),
          matching: find.text('卖出'),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollTo(tester, _key('launch2-pool-max'));
      await tester.tap(_key('launch2-pool-max'));
      await tester.pump();
      expect(find.text('7333.18'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('a balance the server could not read says so before the '
        'quote', (tester) async {
      await openAt(
        tester,
        _FakePool(
          details: <Launch2InstanceDetail>[
            held(
              holding: l2HoldingJson(status: 'unavailable', count: '0'),
            ),
          ],
        ),
      );
      await _scrollTo(tester, _key('launch2-pool-holding'));
      expect(find.text('钱包余额暂时读不到 · 报价后显示'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('an approval that outlasts the quote: the exit re-quotes, '
        're-prepares and signs the trade-only intent, saying 已刷新报价', (
      tester,
    ) async {
      final wallet = _RecordingWallet(
        onHandoff: (intent) {
          // The approval prompt took 45 s: 15 s left on the intent.
          if (intent.kind == IntentKind.launchApproval) {
            now = l2Now.add(const Duration(seconds: 45));
          }
        },
      );
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[held()],
        quotes: <_Answer<Launch2PoolQuote>>[
          _Answer<Launch2PoolQuote>.value(_buyQuote()),
        ],
        prepares: <_Answer<Launch2PoolPrepared>>[
          _Answer<Launch2PoolPrepared>.value(_buyPrepared()),
          _Answer<Launch2PoolPrepared>.value(
            s150Prepared('pool_prepare_buy_ready'),
          ),
        ],
      );
      await openAt(tester, gateway, wallet: wallet);
      await _type(tester, '100');
      await _scrollTo(tester, _key('launch2-pool-confirm'));
      await tester.tap(_key('launch2-pool-confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      // Quote once for the panel, once for the refresh; prepare twice with
      // the same trade.
      expect(gateway.quoteCalls, hasLength(2));
      expect(gateway.prepareCalls, hasLength(2));
      expect(gateway.prepareCalls.last, gateway.prepareCalls.first);
      expect(wallet.handed.map((i) => i.kind).toList(), <IntentKind>[
        IntentKind.launchApproval,
        IntentKind.launchPurchase,
      ]);
      // The trade signed is the fresh intent's, not the reviewed one's.
      expect(
        wallet.handed.last.revision,
        '5b0e8c2a-7f3d-4e1b-9a6c-2d8f4e0b1a48',
      );
      expect(_key('launch2-sign-refreshed'), findsOneWidget);
      expect(find.textContaining('已刷新报价'), findsOneWidget);
      expect(_key('launch2-sign-step-main-done'), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(find.textContaining('广播不代表已成交'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('a refresh worse than the reviewed intent stops at step 2 '
        'with the reason; the trade is not signed', (tester) async {
      final wallet = _RecordingWallet(
        onHandoff: (intent) {
          if (intent.kind == IntentKind.launchApproval) {
            now = l2Now.add(const Duration(seconds: 45));
          }
        },
      );
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[held()],
        quotes: <_Answer<Launch2PoolQuote>>[
          _Answer<Launch2PoolQuote>.value(_buyQuote()),
        ],
        prepares: <_Answer<Launch2PoolPrepared>>[
          _Answer<Launch2PoolPrepared>.value(_buyPrepared()),
          _Answer<Launch2PoolPrepared>.value(
            s150Prepared('pool_prepare_buy_moved'),
          ),
        ],
      );
      await openAt(tester, gateway, wallet: wallet);
      await _type(tester, '100');
      await _scrollTo(tester, _key('launch2-pool-confirm'));
      await tester.tap(_key('launch2-pool-confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(wallet.handed.map((i) => i.kind).toList(), <IntentKind>[
        IntentKind.launchApproval,
      ]);
      expect(_key('launch2-sign-step-approval-done'), findsOneWidget);
      expect(_key('launch2-sign-step-main-failed'), findsOneWidget);
      expect(find.textContaining('最新报价超出了你确认的范围'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      // The page says the same; nothing was broadcast, so nothing is locked.
      expect(_key('launch2-pending'), findsOneWidget);
      expect(find.textContaining('最新报价超出了你确认的范围'), findsOneWidget);
      expect(find.textContaining('广播不代表已成交'), findsNothing);
      await _drain(tester);
    });

    testWidgets('a refresh that keeps asking for an approval, or fails, stops '
        'at step 2 in Chinese', (tester) async {
      final wallet = _RecordingWallet(
        onHandoff: (intent) {
          if (intent.kind == IntentKind.launchApproval) {
            now = l2Now.add(const Duration(seconds: 50));
          }
        },
      );
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[held()],
        quotes: <_Answer<Launch2PoolQuote>>[
          _Answer<Launch2PoolQuote>.value(_buyQuote()),
        ],
        prepares: <_Answer<Launch2PoolPrepared>>[
          _Answer<Launch2PoolPrepared>.value(_buyPrepared()),
        ],
      );
      await openAt(tester, gateway, wallet: wallet);
      await _type(tester, '100');
      await _scrollTo(tester, _key('launch2-pool-confirm'));
      await tester.tap(_key('launch2-pool-confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      // The first prepare, then four refreshes that still carry approvals.
      expect(gateway.prepareCalls, hasLength(5));
      expect(wallet.handed, hasLength(1));
      expect(find.textContaining('授权还在链上确认'), findsOneWidget);
      expect(_key('launch2-sign-step-main-failed'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('the wallet\'s own count moving settles the broadcast in a '
        'definite sentence; the pool count alone does not', (tester) async {
      final wallet = _RecordingWallet();
      final gateway = _FakePool(
        details: <Launch2InstanceDetail>[
          held(holding: l2HoldingJson(count: '0')),
          // Someone else's swap: the pool moved, ours did not.
          held(
            holding: l2HoldingJson(count: '0'),
            pool: l2PoolSummaryJson(tradeCount: '13'),
          ),
          held(
            holding: l2HoldingJson(
              count: '1',
              lastTradeAt: l2Now.add(const Duration(seconds: 6)),
            ),
            pool: l2PoolSummaryJson(tradeCount: '14'),
          ),
        ],
        quotes: <_Answer<Launch2PoolQuote>>[
          _Answer<Launch2PoolQuote>.value(_buyQuote()),
        ],
        prepares: <_Answer<Launch2PoolPrepared>>[
          _Answer<Launch2PoolPrepared>.value(_buyPrepared()),
        ],
      );
      gateway.poolTrades = _Answer<Launch2PoolTrades>.value(
        LoopV2Launch2PoolCodec.trades(
          s150('pool_trades')['body'],
          instanceId: l2InstanceA,
          walletId: l2WalletId,
        ),
      );
      await openAt(tester, gateway, wallet: wallet);
      await _type(tester, '100');
      await _scrollTo(tester, _key('launch2-pool-confirm'));
      await tester.tap(_key('launch2-pool-confirm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      // The re-read after the broadcast: only the pool moved.
      expect(gateway.detailReads, 2);
      expect(find.textContaining('广播不代表已成交'), findsOneWidget);
      expect(find.textContaining('官方池已记录新成交'), findsNothing);
      // The next poll: our own count moved.
      await tester.pump(const Duration(hours: 1));
      await tester.pumpAndSettle();
      expect(gateway.detailReads, 3);
      expect(find.text('你的外盘买入已在链上确认。'), findsOneWidget);
      // 我的外盘成交: the 成交 tab's 「只看我的」 (decision 0240).
      await _scrollTo(tester, _key('launch2-trades-mine-only'));
      await tester.tap(find.text('只看我的'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, _key('launch2-my-pool-trades-provenance'));
      expect(gateway.poolTradeReads, 1);
      expect(find.textContaining('共 1 笔'), findsOneWidget);
      expect(find.text(r'2,000 $FROG · 得 1.3032 USD1'), findsOneWidget);
      expect(find.text(r'7,333.18 $FROG · 付 5 USD1'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('我的外盘成交: a failed read is one line with a retry', (
      tester,
    ) async {
      final gateway = _FakePool(details: <Launch2InstanceDetail>[held()]);
      gateway.poolTrades = const _Answer<Launch2PoolTrades>.fail(
        LoopChainFailureKind.offline,
      );
      await openAt(tester, gateway, sheet: false);
      await _scrollTo(tester, _key('launch2-trades-mine-only'));
      await tester.tap(find.text('只看我的'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, _key('launch2-my-pool-trades-failed'));
      expect(find.textContaining('我的外盘成交暂时读不到'), findsOneWidget);
      await _drain(tester);
    });
  });
}
