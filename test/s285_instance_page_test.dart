import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_parts.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_recent_trades.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_recent_trades_api.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/launch2_fixtures.dart';
import 'support/launch2_trade_sheet.dart';
import 'support/loop_ground_probe.dart';
import 'support/s285_page.dart';
import 'support/test_hints.dart';

// ---------------------------------------------------------------------------
// S285 · client decision 0240: the MEME v2 project page restructured
// (需求方 2026-10-22 第 04 条, 第 03 条客户端部分). Every value is 测试专用.
// ---------------------------------------------------------------------------

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _requestId = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';

Matcher _invalid() => isA<LoopBackendFailure>().having(
  (f) => f.kind,
  'kind',
  LoopBackendFailureKind.invalidPayload,
);

final class _ScriptAdapter implements HttpClientAdapter {
  _ScriptAdapter(this.status, this.body, {this.cacheControl = 'no-store'});

  final int status;
  final Object? body;
  final String cacheControl;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
        'cache-control': <String>[cacheControl],
        'x-request-id': <String>[_requestId],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

(DioLoopV2Launch2RecentTradesApi, _ScriptAdapter) _api(
  int status,
  Object? body, {
  String cacheControl = 'no-store',
}) {
  final adapter = _ScriptAdapter(status, body, cacheControl: cacheControl);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = adapter;
  return (DioLoopV2Launch2RecentTradesApi(dio), adapter);
}

Map<String, Object?> _costKeys({
  Object? avg = '0.0005',
  Object? basis = '3.66',
  Object? realized = '-0.5',
  Object? unrealized = '1.32',
  Object? coverage = 'full',
}) => <String, Object?>{
  'avgCostUsd1': avg,
  'costBasisUsd1': basis,
  'realizedPnlUsd1': realized,
  'unrealizedPnlUsd1': unrealized,
  'costCoverage': coverage,
};

Launch2InstanceDetail _graduated({
  Map<String, Object?>? holding,
  Map<String, Object?>? cost,
  bool noViewer = false,
}) => l2Detail(
  stage: 'graduated',
  noNextChange: true,
  noViewer: noViewer,
  pool: l2PoolSummaryJson(),
  viewer: noViewer
      ? null
      : l2ViewerJson(
          holding: <String, Object?>{
            ...(holding ?? l2HoldingJson(count: '0')),
            ...?cost,
          },
        ),
);

Launch2PoolTrades _ownTrades() => LoopV2Launch2PoolCodec.trades(
  (jsonDecode(
    File('test/fixtures/s150-launch2/pool_trades.json').readAsStringSync(),
  ) as Map<String, Object?>)['body'],
  instanceId: l2InstanceA,
  walletId: l2WalletId,
);

/// A public-trades gateway whose answer waits until [release].
final class _Pending implements Launch2RecentPoolTradesGateway {
  final Completer<Launch2PublicPoolTrades> release =
      Completer<Launch2PublicPoolTrades>();

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2PublicPoolTrades> loadRecentPoolTrades(
    String instanceId, {
    int limit = launch2RecentPoolTradesLimit,
  }) => release.future;
}

void main() {
  loopShowTestHints();
  loopWatchGround();

  group('codec · public pool trades (loop-api decision 0174 §B)', () {
    test('reads both items: a masked trader and an anonymous one', () {
      final page = s285SampleTrades();
      expect(page.items, hasLength(4));
      final first = page.items.first;
      expect(first.side, Launch2Side.buy);
      expect(first.txHash, '0x${'a' * 64}');
      expect(first.blockNumber, BigInt.from(136098447));
      expect(first.at, DateTime.utc(2027, 1, 20, 6, 58, 40));
      expect(first.memeAmount, Decimal.fromInt(16000));
      expect(first.usd1Amount, Decimal.fromInt(10));
      expect(first.priceUsd1, Decimal.parse('0.000625'));
      expect(first.wallet, '0x1234…abcd');
      expect(page.items[1].side, Launch2Side.sell);
      expect(page.items[1].wallet, isNull);
      expect(page.observedAt, DateTime.utc(2027, 1, 20, 7));
    });

    test('an empty list (before graduation) is an answer', () {
      final page = s285Trades(const <Map<String, Object?>>[]);
      expect(page.items, isEmpty);
    });

    test('an item that does not read is dropped; the others stay', () {
      final page = s285Trades(<Map<String, Object?>>[
        s285TradeJson(),
        s285TradeJson(side: 'swap'),
        s285TradeJson(hashDigit: 'z'),
        // A full address is never what the server sends.
        s285TradeJson(wallet: '0x${'1' * 40}'),
        s285TradeJson(meme: '-1'),
        s285TradeJson(usd1: 'abc'),
        <String, Object?>{...s285TradeJson(), 'priceUsd1': null},
        <String, Object?>{...s285TradeJson(), 'at': 'yesterday'},
        <String, Object?>{...s285TradeJson(), 'blockNumber': 12},
        <String, Object?>{...s285TradeJson(), 'extra': true},
      ]);
      // The first and the one with an unknown extra key read.
      expect(page.items, hasLength(2));
    });

    test('a root that does not read is a failure, never an empty list', () {
      expect(
        () => LoopV2Launch2RecentTradesCodec.recentTrades(
          'nope',
          instanceId: l2InstanceA,
        ),
        throwsA(_invalid()),
      );
      expect(
        () => LoopV2Launch2RecentTradesCodec.recentTrades(<String, Object?>{
          ...s285TradesJson(const []),
          'items': null,
        }, instanceId: l2InstanceA),
        throwsA(_invalid()),
      );
      expect(
        () => LoopV2Launch2RecentTradesCodec.recentTrades(
          s285TradesJson(const []),
          instanceId: l2InstanceB,
        ),
        throwsA(_invalid()),
      );
      expect(
        () => LoopV2Launch2RecentTradesCodec.recentTrades(<String, Object?>{
          ...s285TradesJson(const []),
          'contractVersion': '1.0',
        }, instanceId: l2InstanceA),
        throwsA(_invalid()),
      );
    });

    test(
      'the route: public cache header, the limit, no idempotency key',
      () async {
        final (api, adapter) = _api(
          200,
          s285TradesJson(<Map<String, Object?>>[s285TradeJson()]),
          cacheControl: 'public, max-age=10',
        );
        final page = await api.getRecentTrades(
          accessToken: 'token',
          clientVersion: '1.0.0',
          instanceId: l2InstanceA,
          limit: 20,
        );
        expect(page.items, hasLength(1));
        final request = adapter.requests.single;
        expect(
          request.path,
          '/v2/launch2/instances/$l2InstanceA/pool/recent-trades',
        );
        expect(request.queryParameters, <String, Object?>{'limit': '20'});
        expect(request.headers['X-Loop-Contract-Version'], '2.0');
        expect(request.headers.containsKey('Idempotency-Key'), isFalse);
        // 51 is refused before any request.
        await expectLater(
          api.getRecentTrades(
            accessToken: 'token',
            clientVersion: '1.0.0',
            instanceId: l2InstanceA,
            limit: 51,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
        expect(adapter.requests, hasLength(1));
      },
    );

    test('429 RATE_LIMITED is its own failure', () async {
      final (api, _) = _api(429, <String, Object?>{
        'code': 'RATE_LIMITED',
        'category': 'rateLimit',
        'retryable': true,
        'userMessageKey': 'errors.rateLimited',
        'correlationId': _requestId,
        'detailsSafe': null,
        'providerReferenceSafe': null,
      });
      await expectLater(
        api.getRecentTrades(
          accessToken: 'token',
          clientVersion: '1.0.0',
          instanceId: l2InstanceA,
          limit: 20,
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (f) => f.code,
            'code',
            'RATE_LIMITED',
          ),
        ),
      );
    });
  });

  group('codec · cost basis (loop-api S284, client first)', () {
    test('a position row reads the five keys; profits may be negative', () {
      final position = l2Positions(
        stage: 'graduated',
        holding: l2HoldingJson(),
        extra: _costKeys(unrealized: '-2.75', coverage: 'partial'),
      ).items.single;
      expect(position.cost.avgCostUsd1, Decimal.parse('0.0005'));
      expect(position.cost.costBasisUsd1, Decimal.parse('3.66'));
      expect(position.cost.realizedPnlUsd1, Decimal.parse('-0.5'));
      expect(position.cost.unrealizedPnlUsd1, Decimal.parse('-2.75'));
      expect(position.cost.coverage, Launch2CostCoverage.partial);
    });

    test('absent keys are no cost basis', () {
      final position = l2Positions().items.single;
      expect(position.cost.isEmpty, isTrue);
      expect(identical(position.cost, Launch2CostBasis.none), isTrue);
    });

    test('null, a number or a malformed string reads as no figure, never a '
        'refused row', () {
      for (final bad in <Object?>[null, 12, 'abc', '1.2.3', '+1', '', '1e3']) {
        final position = l2Positions(
          extra: _costKeys(
            avg: bad,
            basis: bad,
            realized: bad,
            unrealized: bad,
            coverage: bad,
          ),
        ).items.single;
        expect(position.cost.isEmpty, isTrue, reason: '$bad');
      }
      final odd = l2Positions(
        extra: _costKeys(avg: '-0.1', coverage: 'most'),
      ).items.single;
      // A cost is never negative; an unknown coverage is no coverage.
      expect(odd.cost.avgCostUsd1, isNull);
      expect(odd.cost.coverage, isNull);
      expect(odd.cost.unrealizedPnlUsd1, Decimal.parse('1.32'));
    });

    test('the detail viewer reads the same keys', () {
      final detail = _graduated(cost: _costKeys());
      expect(detail.viewer!.cost.avgCostUsd1, Decimal.parse('0.0005'));
      expect(detail.viewer!.cost.coverage, Launch2CostCoverage.full);
      expect(_graduated().viewer!.cost.isEmpty, isTrue);
    });

    test('the percent is (price − avg) / avg; signed figures', () {
      expect(
        launch2PnlPercent(
          price: Decimal.parse('0.00068'),
          avg: Decimal.parse('0.0005'),
        ),
        Decimal.fromInt(36),
      );
      expect(launch2PnlPercent(price: Decimal.one, avg: Decimal.zero), isNull);
      expect(launch2PnlPercent(price: null, avg: Decimal.one), isNull);
      expect(launch2SignedFigure(Decimal.parse('1.234')), '+1.23');
      expect(launch2SignedFigure(Decimal.parse('-0.5')), '-0.5');
      expect(launch2SignedFigure(Decimal.zero), '0');
      expect(launch2SignedColor(Decimal.one), LoopColors.rise);
      expect(launch2SignedColor(-Decimal.one), LoopColors.fall);
      expect(launch2PnlText(amount: null, percent: null), isNull);
    });
  });

  group('graduated page', () {
    testWidgets('three tabs: 成交 lists the public trades, 信息 the pool, 回购 '
        'the buyback', (tester) async {
      final recent = S285RecentTrades(s285Value(s285SampleTrades()));
      await pumpS285Project(
        tester,
        launch2: S285Launch2(detail: _graduated()),
        recent: recent,
      );
      expect(_key('launch2-instance-tabs'), findsOneWidget);
      for (final tab in <String>['trades', 'info', 'buyback']) {
        expect(_key('launch2-tab-$tab'), findsOneWidget, reason: tab);
      }
      // 成交 is the first tab.
      expect(_key('launch2-pool-trades'), findsOneWidget);
      expect(recent.reads, 1);
      expect(
        _key('launch2-pool-trade-0x${'a' * 64}-136098447-0'),
        findsOneWidget,
      );
      expect(find.textContaining('0x1234…abcd'), findsOneWidget);
      expect(find.textContaining('匿名'), findsOneWidget);
      expect(find.text('49 USD1'), findsOneWidget);
      expect(
        find.textContaining(
          '价格 ${launch2PriceLabel(Decimal.parse('0.000625'))}',
        ),
        findsOneWidget,
      );
      expect(_key('launch2-pool-trades-provenance'), findsOneWidget);
      // Price area: the pool's last price and its 24 h volume.
      expect(
        tester.widget<Text>(_key('launch2-pool-price')).data,
        launch2PriceLabel(Decimal.parse('0.00068')),
      );
      expect(find.text('24h 成交 1,500.5 USD1'), findsOneWidget);

      await l2OpenTab(tester, 'info');
      expect(_key('launch2-pool-trades'), findsNothing);
      expect(_key('launch2-graduated'), findsOneWidget);
      // S294 · decision 0244: 外盘最新价 … 最近成交 are off 信息.
      expect(_key('launch2-pool-stats'), findsNothing);
      for (final label in <String>[
        '外盘最新价',
        '外盘成交',
        '用户买入 / 卖出',
        '24 小时成交额',
        '最近成交',
      ]) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(_key('launch2-buyback'), findsNothing);

      await l2OpenTab(tester, 'buyback');
      expect(_key('launch2-buyback'), findsOneWidget);
      expect(_key('launch2-pool-stats'), findsNothing);
      await drainS285(tester);
    });

    testWidgets('只看我的 reads the wallet\'s own pool trades and back', (
      tester,
    ) async {
      final recent = S285RecentTrades(s285Value(s285SampleTrades()));
      final launch2 = S285Launch2(
        detail: _graduated(holding: l2HoldingJson()),
        poolTrades: s285Value(_ownTrades()),
      );
      await pumpS285Project(tester, launch2: launch2, recent: recent);
      expect(launch2.poolTradeReads, 0);
      await tester.tap(find.text('只看我的'));
      await tester.pumpAndSettle();
      expect(launch2.poolTradeReads, 1);
      expect(find.text('我的外盘成交 · 共 1 笔'), findsOneWidget);
      expect(find.text(r'2,000 $FROG · 得 1.3032 USD1'), findsOneWidget);
      expect(
        _key('launch2-pool-trade-0x${'a' * 64}-136098447-0'),
        findsNothing,
      );
      await tester.tap(find.text('只看我的'));
      await tester.pumpAndSettle();
      expect(find.text('全部外盘成交'), findsOneWidget);
      expect(
        _key('launch2-pool-trade-0x${'a' * 64}-136098447-0'),
        findsOneWidget,
      );
      await drainS285(tester);
    });

    testWidgets('只看我的 without a trade of its own, or without a wallet', (
      tester,
    ) async {
      await pumpS285Project(
        tester,
        launch2: S285Launch2(detail: _graduated()),
        recent: S285RecentTrades(s285Value(s285SampleTrades())),
      );
      await tester.tap(find.text('只看我的'));
      await tester.pumpAndSettle();
      expect(_key('launch2-my-pool-trades-none'), findsOneWidget);
      await drainS285(tester);

      await pumpS285Project(
        tester,
        launch2: S285Launch2(detail: _graduated(noViewer: true)),
        recent: S285RecentTrades(s285Value(s285SampleTrades())),
      );
      await tester.tap(find.text('只看我的'));
      await tester.pumpAndSettle();
      expect(_key('launch2-my-pool-trades-no-wallet'), findsOneWidget);
      await drainS285(tester);
    });

    testWidgets('成交: loading, empty, rate limited, offline and no adapter', (
      tester,
    ) async {
      final pending = _Pending();
      await pumpS285Project(
        tester,
        launch2: S285Launch2(detail: _graduated()),
        settle: false,
      );
      await tester.pumpAndSettle();
      // No adapter: unavailable, never an empty list, nothing to retry.
      expect(_key('launch2-pool-trades-failed'), findsOneWidget);
      expect(_key('launch2-pool-trades-empty'), findsNothing);
      await drainS285(tester);

      await pumpS285Project(
        tester,
        launch2: S285Launch2(detail: _graduated()),
        recent: pending,
        settle: false,
      );
      await tester.pump();
      await tester.pump();
      expect(_key('launch2-pool-trades-loading'), findsOneWidget);
      pending.release.complete(s285Trades(const <Map<String, Object?>>[]));
      await tester.pumpAndSettle();
      expect(_key('launch2-pool-trades-empty'), findsOneWidget);
      expect(find.text('还没有外盘成交'), findsOneWidget);
      await drainS285(tester);

      final limited = S285RecentTrades(
        s285Fail(LoopChainFailureKind.rateLimited),
      );
      await pumpS285Project(
        tester,
        launch2: S285Launch2(detail: _graduated()),
        recent: limited,
      );
      expect(find.textContaining('请求太频繁，稍后再试'), findsOneWidget);
      await drainS285(tester);

      final offline = S285RecentTrades(s285Fail(LoopChainFailureKind.offline));
      await pumpS285Project(
        tester,
        launch2: S285Launch2(detail: _graduated()),
        recent: offline,
      );
      expect(_key('launch2-pool-trades-failed'), findsOneWidget);
      offline.answer = s285Value(s285SampleTrades());
      final before = offline.reads;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(offline.reads, greaterThan(before));
      expect(_key('launch2-pool-trades-failed'), findsNothing);
      expect(
        _key('launch2-pool-trade-0x${'a' * 64}-136098447-0'),
        findsOneWidget,
      );
      await drainS285(tester);
    });

    testWidgets('the fixed bar: 买入 opens the pool panel on buy, 卖出 on sell', (
      tester,
    ) async {
      await pumpS285Project(
        tester,
        launch2: S285Launch2(detail: _graduated()),
        recent: S285RecentTrades(s285Value(s285SampleTrades())),
        size: const Size(390, 844),
      );
      // The bar does not scroll with the page.
      final bar = tester.getRect(_key('launch2-bar-buy'));
      expect(bar.bottom, lessThanOrEqualTo(844));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.getRect(_key('launch2-bar-buy')), bar);
      expect(
        tester.getSize(_key('launch2-bar-buy')).height,
        greaterThanOrEqualTo(44),
      );

      await l2OpenTradeSheet(tester);
      expect(_key('launch2-trade-sheet'), findsOneWidget);
      expect(_key('launch2-pool-panel'), findsOneWidget);
      expect(
        tester.widget<LoopSegBar>(_key('launch2-pool-side')).selectedIndex,
        0,
      );
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(_key('launch2-trade-sheet'), findsNothing);

      await l2OpenTradeSheet(tester, sell: true);
      expect(
        tester.widget<LoopSegBar>(_key('launch2-pool-side')).selectedIndex,
        1,
      );
      expect(find.text('按卖出数量'), findsOneWidget);
      await drainS285(tester);
    });
  });

  group('curve stages', () {
    testWidgets('public: 成交 / 信息 only; the curve trades and the template', (
      tester,
    ) async {
      await pumpS285Project(
        tester,
        launch2: S285Launch2(
          detail: l2Detail(
            stage: 'public',
            noNextChange: true,
            viewer: l2ViewerJson(member: true, eligibleNow: true),
            trades: <Map<String, Object?>>[l2TradeJson()],
          ),
        ),
      );
      expect(_key('launch2-tab-trades'), findsOneWidget);
      expect(_key('launch2-tab-info'), findsOneWidget);
      expect(_key('launch2-tab-buyback'), findsNothing);
      expect(_key('launch2-trade-t-1'), findsOneWidget);
      expect(_key('launch2-curve-price'), findsOneWidget);
      expect(find.text('内盘已售 0%'), findsOneWidget);
      await l2OpenTab(tester, 'info');
      expect(_key('launch2-template'), findsOneWidget);
      expect(_key('launch2-trade-t-1'), findsNothing);
      // Both keys open; the panel is the sheet.
      expect(
        tester.widget<LoopButton>(_key('launch2-bar-sell')).onPressed,
        isNotNull,
      );
      await l2OpenTradeSheet(tester);
      expect(_key('launch2-trade-panel'), findsOneWidget);
      await drainS285(tester);
    });

    testWidgets('priority: 卖出 is closed with its reason', (tester) async {
      await pumpS285Project(
        tester,
        launch2: S285Launch2(
          detail: l2Detail(
            stage: 'priority',
            viewer: l2ViewerJson(member: true, eligibleNow: true),
          ),
        ),
      );
      expect(
        tester.widget<LoopButton>(_key('launch2-bar-sell')).onPressed,
        isNull,
      );
      expect(
        tester.widget<LoopButton>(_key('launch2-bar-buy')).onPressed,
        isNotNull,
      );
      expect(_key('launch2-bar-sell-reason'), findsOneWidget);
      await drainS285(tester);
    });

    testWidgets('nft_sale keeps its 铸造勋章 bar; two tabs under the sale', (
      tester,
    ) async {
      await pumpS285Project(tester, launch2: S285Launch2(detail: l2Detail()));
      expect(_key('launch2-buy-nft'), findsOneWidget);
      expect(_key('launch2-bar-buy'), findsNothing);
      expect(_key('launch2-bar-sell'), findsNothing);
      expect(_key('launch2-tab-trades'), findsOneWidget);
      expect(_key('launch2-tab-info'), findsOneWidget);
      expect(_key('launch2-tab-buyback'), findsNothing);
      await drainS285(tester);
    });

    testWidgets('upcoming has no tabs and no bar', (tester) async {
      await pumpS285Project(
        tester,
        launch2: S285Launch2(detail: l2Detail(stage: 'upcoming')),
      );
      expect(_key('launch2-instance-tabs'), findsNothing);
      expect(_key('launch2-bar-buy'), findsNothing);
      await drainS285(tester);
    });
  });

  group('我的持仓 under the K line', () {
    testWidgets('with the cost keys: quantity, value, cost and profit with '
        'the percent in the rise colour', (tester) async {
      final launch2 = S285Launch2(
        detail: _graduated(holding: l2HoldingJson(), cost: _costKeys()),
        positions: s285Value(
          l2Positions(
            stage: 'graduated',
            holding: l2HoldingJson(),
            extra: <String, Object?>{
              'priceUsd1': '0.00068',
              'valueUsd1': '4.98',
              'priceSource': 'pool',
            },
          ),
        ),
      );
      await pumpS285Project(
        tester,
        launch2: launch2,
        recent: S285RecentTrades(s285Value(s285SampleTrades())),
      );
      expect(_key('launch2-holding'), findsOneWidget);
      expect(
        tester.widget<Text>(_key('launch2-holding-quantity')).data,
        r'7,333.18 $FROG',
      );
      expect(
        tester.widget<Text>(_key('launch2-holding-value')).data,
        '4.98 USD1',
      );
      expect(
        tester.widget<Text>(_key('launch2-holding-avg-cost')).data,
        launch2PriceLabel(Decimal.parse('0.0005')),
      );
      final pnl = tester.widget<Text>(_key('launch2-holding-pnl'));
      expect(pnl.data, '+1.32 USD1 · +36%');
      expect(pnl.style?.color, LoopColors.rise);
      // Full coverage: the realized profit is still behind (i).
      expect(_key('launch2-holding-pnl-info'), findsOneWidget);
      // The strip sits under the K line, above the tabs.
      expect(
        tester.getTopLeft(_key('launch2-holding')).dy,
        lessThan(tester.getTopLeft(_key('launch2-instance-tabs')).dy),
      );
      await drainS285(tester);
    });

    testWidgets('partial coverage: (i) says why, with the realized profit', (
      tester,
    ) async {
      await pumpS285Project(
        tester,
        launch2: S285Launch2(
          detail: _graduated(
            holding: l2HoldingJson(),
            cost: _costKeys(unrealized: '-2.5', coverage: 'partial'),
          ),
        ),
        recent: S285RecentTrades(s285Value(s285SampleTrades())),
      );
      final pnl = tester.widget<Text>(_key('launch2-holding-pnl'));
      expect(pnl.data, '-2.5 USD1 · +36%');
      expect(pnl.style?.color, LoopColors.fall);
      // No positions read: no value cell, never a derived one.
      expect(_key('launch2-holding-value'), findsNothing);
      await tester.tap(_key('launch2-holding-pnl-info'));
      await tester.pumpAndSettle();
      expect(_key('launch2-holding-partial-note'), findsOneWidget);
      expect(find.textContaining('部分持仓为链上转入，无成本记录'), findsOneWidget);
      expect(find.text('-0.5 USD1'), findsOneWidget);
      await drainS285(tester);
    });

    testWidgets('without the cost keys only the quantity shows', (
      tester,
    ) async {
      await pumpS285Project(
        tester,
        launch2: S285Launch2(detail: _graduated(holding: l2HoldingJson())),
        recent: S285RecentTrades(s285Value(s285SampleTrades())),
      );
      expect(_key('launch2-holding-quantity'), findsOneWidget);
      expect(_key('launch2-holding-avg-cost'), findsNothing);
      expect(_key('launch2-holding-pnl'), findsNothing);
      expect(_key('launch2-holding-pnl-info'), findsNothing);
      await drainS285(tester);
    });

    testWidgets('no holding, no strip; the curve strip reads the curve net', (
      tester,
    ) async {
      await pumpS285Project(
        tester,
        launch2: S285Launch2(
          detail: _graduated(
            holding: l2HoldingJson(meme: '0', count: '0'),
          ),
        ),
        recent: S285RecentTrades(s285Value(s285SampleTrades())),
      );
      expect(_key('launch2-holding'), findsNothing);
      await drainS285(tester);

      await pumpS285Project(
        tester,
        launch2: S285Launch2(
          detail: l2Detail(
            stage: 'public',
            noNextChange: true,
            viewer: l2ViewerJson(
              member: true,
              eligibleNow: true,
              bought: '1000',
              net: '1000',
            ),
          ),
        ),
      );
      expect(
        tester.widget<Text>(_key('launch2-curve-holding')).data,
        r'1,000 $FROG',
      );
      await drainS285(tester);
    });
  });
}
