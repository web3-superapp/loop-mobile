// S267 · the MEME v2 project page's K line (client decision 0227).
//
// loop-api S267 publishes `GET /v2/launch2/instances/{id}/candles`; the
// project page draws it with the shared token chart under the 内盘 heading
// (and, after graduation, under 官方池 with a 毕业 rule).
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_chart.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_models.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_api.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_candle_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const String _requestId = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';

/// The fixture's graduation moment (`l2DetailJson`, stage `graduated`).
final DateTime _graduatedAt = DateTime.utc(2027, 1, 24, 7);

int _seconds(DateTime at) => at.millisecondsSinceEpoch ~/ 1000;

Map<String, Object?> _candleJson(int t, Decimal close, {Decimal? open}) =>
    <String, Object?>{
      't': t,
      'o': (open ?? close).toString(),
      'h': close.toString(),
      'l': (open ?? close).toString(),
      'c': close.toString(),
      'v': '2095493.0',
      'q': '90.0',
      'n': 3,
    };

/// [count] buckets of [interval] from [start], each a little above the last.
List<Map<String, Object?>> _candles(
  int count, {
  required DateTime start,
  Launch2CandleInterval interval = Launch2CandleInterval.fiveMinutes,
}) {
  final step = interval.width.inSeconds;
  final base = Decimal.parse('0.00004');
  final tick = Decimal.parse('0.00000001');
  return <Map<String, Object?>>[
    for (var i = 0; i < count; i += 1)
      _candleJson(
        _seconds(start) + i * step,
        base + tick * Decimal.fromInt(i + 1),
        open: base + tick * Decimal.fromInt(i),
      ),
  ];
}

Map<String, Object?> _seriesJson({
  String interval = '5m',
  String source = 'curve',
  List<Map<String, Object?>> candles = const <Map<String, Object?>>[],
  Object? latest = const <String, Object?>{
    'price': '0.00004286',
    'at': 1792575997,
  },
}) => <String, Object?>{
  'instanceId': l2InstanceA,
  'interval': interval,
  'quoteAsset': 'USD1',
  'source': source,
  'candles': candles,
  'latest': latest,
  'contractVersion': '2.0',
};

Launch2CandleSeries _series(
  Map<String, Object?> json,
  Launch2CandleInterval interval,
) => LoopV2Launch2CandleCodec.series(
  json,
  instanceId: l2InstanceA,
  requested: interval,
);

typedef _Call = ({Launch2CandleInterval interval, int limit, DateTime? before});

final class _CandleGateway implements Launch2Gateway {
  _CandleGateway(this.detail, this.answer);

  final Launch2InstanceDetail detail;
  Future<Launch2CandleSeries> Function(_Call call) answer;
  final List<_Call> calls = <_Call>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) =>
      Future<Launch2InstanceDetail>.value(detail);

  @override
  Future<Launch2CandleSeries> candles(
    String instanceId,
    Launch2CandleInterval interval, {
    int limit = launch2CandlePageSize,
    DateTime? before,
  }) {
    final call = (interval: interval, limit: limit, before: before);
    calls.add(call);
    return answer(call);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
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
  _CandleGateway gateway, {
  ValueNotifier<bool>? visible,
  bool settle = true,
}) {
  const page = Launch2InstanceScreen(instanceId: l2InstanceA);
  return pumpS7Page(
    tester,
    visible == null
        ? page
        : ValueListenableBuilder<bool>(
            valueListenable: visible,
            builder: (context, on, child) =>
                TickerMode(enabled: on, child: child!),
            child: page,
          ),
    meta: _meta(),
    settle: settle,
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

Future<void> _drain(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

Launch2InstanceDetail _public() => l2Detail(
  stage: 'public',
  viewer: l2ViewerJson(member: true, eligibleNow: true),
);

Launch2InstanceDetail _graduated() =>
    l2Detail(stage: 'graduated', noNextChange: true, pool: l2PoolSummaryJson());

Future<Launch2CandleSeries> _ok(_Call call, List<Map<String, Object?>> rows) =>
    Future<Launch2CandleSeries>.value(
      _series(
        _seriesJson(interval: call.interval.wireName, candles: rows),
        call.interval,
      ),
    );

void main() {
  loopWatchGround();

  group('codec', () {
    test('reads the contract sample, exact and ascending', () {
      final series = _series(
        _seriesJson(
          candles: <Map<String, Object?>>[
            <String, Object?>{
              't': 1792575300,
              'o': '0.00004200',
              'h': '0.00004300',
              'l': '0.00004100',
              'c': '0.00004286',
              'v': '100.5',
              'q': '4.3',
              'n': 2,
            },
            <String, Object?>{
              't': 1792575000,
              'o': '0.00004167',
              'h': '0.00004200',
              'l': '0.00004167',
              'c': '0.00004200',
              'v': '2095493.0',
              'q': '90.0',
              'n': 3,
            },
          ],
        ),
        Launch2CandleInterval.fiveMinutes,
      );
      expect(series.instanceId, l2InstanceA);
      expect(series.interval, Launch2CandleInterval.fiveMinutes);
      expect(series.quoteAsset, 'USD1');
      expect(series.source, Launch2CandleSource.curve);
      expect(series.candles, hasLength(2));
      final first = series.candles.first;
      expect(first.openTime, DateTime.utc(2026, 10, 21, 9, 30));
      expect(first.open, Decimal.parse('0.00004167'));
      expect(first.close, Decimal.parse('0.00004200'));
      expect(first.volumeMeme, Decimal.parse('2095493'));
      expect(first.quoteUsd1, Decimal.parse('90'));
      expect(first.tradeCount, 3);
      expect(series.candles.last.close, Decimal.parse('0.00004286'));
      expect(series.latest!.price, Decimal.parse('0.00004286'));
      expect(series.latest!.at.isUtc, isTrue);
    });

    test('ignores unknown keys and accepts latest null', () {
      final json = _seriesJson(
        latest: null,
        candles: <Map<String, Object?>>[
          <String, Object?>{
            ..._candleJson(1792575000, Decimal.parse('0.5')),
            'vwap': '0.4',
          },
        ],
      )..['futureField'] = <String, Object?>{'x': 1};
      final series = _series(json, Launch2CandleInterval.fiveMinutes);
      expect(series.latest, isNull);
      expect(series.candles.single.close, Decimal.parse('0.5'));
    });

    test('missing fields take neutral values; unreadable buckets drop', () {
      final series = _series(<String, Object?>{
        'candles': <Object?>[
          <String, Object?>{'t': 1792575000, 'c': '0.00004'},
          <String, Object?>{'t': 1792575300},
          <String, Object?>{'c': '0.1'},
          <String, Object?>{'t': 'soon', 'c': '0.1'},
          <String, Object?>{'t': 1792575600, 'c': '-1'},
          'bucket',
        ],
        'source': 'somewhere-new',
      }, Launch2CandleInterval.oneHour);
      expect(series.interval, Launch2CandleInterval.oneHour);
      expect(series.quoteAsset, 'USD1');
      expect(series.source, Launch2CandleSource.unknown);
      expect(series.latest, isNull);
      final only = series.candles.single;
      expect(only.open, Decimal.parse('0.00004'));
      expect(only.high, Decimal.parse('0.00004'));
      expect(only.volumeMeme, Decimal.zero);
      expect(only.tradeCount, 0);
    });

    test('no trade yet is an empty list, not a failure', () {
      final series = _series(_seriesJson(), Launch2CandleInterval.fiveMinutes);
      expect(series.candles, isEmpty);
      expect(series.latest, isNotNull);
    });

    test('a root that is not an object is an invalid payload', () {
      expect(
        () => _series(<String, Object?>{
          'candles': 'none',
        }, Launch2CandleInterval.fiveMinutes),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2Launch2CandleCodec.series(
          <Object?>[],
          instanceId: l2InstanceA,
          requested: Launch2CandleInterval.fiveMinutes,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('transport', () {
    (DioLoopV2Launch2Api, _ScriptAdapter) api(int status, Object? body) {
      final adapter = _ScriptAdapter(status, body);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = adapter;
      return (DioLoopV2Launch2Api(dio, mediaUrl: (_) => null), adapter);
    }

    test('sends interval, limit and before as the route names them', () async {
      final (client, adapter) = api(200, _seriesJson(interval: '1h'));
      await client.getCandles(
        accessToken: 'token',
        clientVersion: '1.0.0',
        instanceId: l2InstanceA,
        interval: Launch2CandleInterval.oneHour,
        limit: 200,
        before: DateTime.fromMillisecondsSinceEpoch(
          1792575000 * 1000,
          isUtc: true,
        ),
      );
      final sent = adapter.requests.single;
      expect(sent.path, '/v2/launch2/instances/$l2InstanceA/candles');
      expect(sent.queryParameters, <String, Object?>{
        'interval': '1h',
        'limit': '200',
        'before': '1792575000',
      });
    });

    test('a bare 404 (a server before S267) reads as notFound', () async {
      final (client, _) = api(404, <String, Object?>{'message': 'Not Found'});
      await expectLater(
        client.getCandles(
          accessToken: 'token',
          clientVersion: '1.0.0',
          instanceId: l2InstanceA,
          interval: Launch2CandleInterval.fiveMinutes,
          limit: 200,
        ),
        throwsA(
          isA<LoopChainException>().having(
            (e) => e.kind,
            'kind',
            LoopChainFailureKind.notFound,
          ),
        ),
      );
    });

    test('a limit outside 1..500 is never sent', () async {
      final (client, adapter) = api(200, _seriesJson());
      await expectLater(
        client.getCandles(
          accessToken: 'token',
          clientVersion: '1.0.0',
          instanceId: l2InstanceA,
          interval: Launch2CandleInterval.fiveMinutes,
          limit: 501,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('graduation rule', () {
    final rows = _series(
      _seriesJson(
        interval: '1h',
        source: 'mixed',
        candles: _candles(
          10,
          start: _graduatedAt.subtract(const Duration(hours: 5)),
          interval: Launch2CandleInterval.oneHour,
        ),
      ),
      Launch2CandleInterval.oneHour,
    ).candles;

    DateTime? mark({
      Launch2Stage stage = Launch2Stage.graduated,
      DateTime? at,
      Launch2CandleSource source = Launch2CandleSource.mixed,
      List<Launch2Candle>? candles,
    }) => launch2CandleGraduationMark(
      stage: stage,
      graduatedAt: at ?? _graduatedAt,
      source: source,
      candles: candles ?? rows,
      interval: Launch2CandleInterval.oneHour,
    );

    test('a graduated, mixed series that spans the moment carries it', () {
      expect(mark(), _graduatedAt);
    });

    test('nothing before graduation, for one market, or off the series', () {
      expect(mark(stage: Launch2Stage.public), isNull);
      expect(mark(source: Launch2CandleSource.curve), isNull);
      expect(mark(source: Launch2CandleSource.pool), isNull);
      expect(mark(candles: const <Launch2Candle>[]), isNull);
      expect(mark(at: _graduatedAt.subtract(const Duration(days: 2))), isNull);
      expect(mark(at: _graduatedAt.add(const Duration(days: 2))), isNull);
    });
  });

  group('project page', () {
    testWidgets('内盘: the card sits between the heading and the figures, '
        'asks for 5 分 first and re-asks on a capsule', (tester) async {
      final start = l2Now.subtract(const Duration(hours: 2));
      final gateway = _CandleGateway(
        _public(),
        (call) =>
            _ok(call, _candles(24, start: start, interval: call.interval)),
      );
      await _pump(tester, gateway);

      expect(_key('launch2-candles'), findsOneWidget);
      expect(find.byType(LoopMarketChart), findsOneWidget);
      expect(
        tester.getTopLeft(_key('launch2-candles')).dy,
        lessThan(tester.getTopLeft(_key('launch2-curve-price')).dy),
      );
      expect(
        tester.getTopLeft(_key('launch2-candles')).dy,
        greaterThan(tester.getTopLeft(find.text('内盘').first).dy),
      );
      expect(gateway.calls.single, (
        interval: Launch2CandleInterval.fiveMinutes,
        limit: 200,
        before: null,
      ));
      for (final interval in Launch2CandleInterval.values) {
        expect(
          find.descendant(
            of: _key('launch2-candles-intervals'),
            matching: find.text(interval.label),
          ),
          findsOneWidget,
        );
      }

      await tester.tap(
        find.descendant(
          of: _key('launch2-candles-intervals'),
          matching: find.text('1时'),
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.calls, hasLength(2));
      expect(gateway.calls.last.interval, Launch2CandleInterval.oneHour);
      expect(gateway.calls.last.before, isNull);
      expect(_key('launch2-candles-chart-1h'), findsOneWidget);
      await _drain(tester);
    });

    testWidgets('loading draws the skeleton in the chart\'s place', (
      tester,
    ) async {
      final gateway = _CandleGateway(
        _public(),
        (call) => Future<Launch2CandleSeries>.delayed(
          const Duration(seconds: 3),
          () => _series(_seriesJson(), call.interval),
        ),
      );
      await _pump(tester, gateway, settle: false);
      await tester.pump();
      await tester.pump();
      expect(_key('launch2-candles-loading'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(_key('launch2-candles-loading'), findsNothing);
      await _drain(tester);
    });

    testWidgets('no trade yet: the grey placeholder and its line', (
      tester,
    ) async {
      final gateway = _CandleGateway(
        _public(),
        (call) => Future<Launch2CandleSeries>.value(
          _series(_seriesJson(), call.interval),
        ),
      );
      await _pump(tester, gateway);
      expect(_key('launch2-candles-empty'), findsOneWidget);
      expect(find.text(launch2CandlesEmptyText), findsOneWidget);
      expect(find.text('还没有成交，第一笔成交后出现 K 线'), findsOneWidget);
      expect(find.byType(LoopMarketChart), findsNothing);
      await _drain(tester);
    });

    testWidgets('a failed read says so and the block retries', (tester) async {
      var fail = true;
      final gateway = _CandleGateway(_public(), (call) {
        if (fail) {
          return Future<Launch2CandleSeries>.error(
            const LoopChainException(LoopChainFailureKind.readFailed),
          );
        }
        return _ok(call, _candles(12, start: l2Now, interval: call.interval));
      });
      await _pump(tester, gateway);
      expect(find.text('K 线暂时读不到，点按重试'), findsOneWidget);
      expect(find.byType(LoopMarketChart), findsNothing);

      fail = false;
      await tester.tap(_key('launch2-candles-retry'));
      await tester.pumpAndSettle();
      expect(gateway.calls, hasLength(2));
      expect(find.text(launch2CandlesFailedText), findsNothing);
      expect(find.byType(LoopMarketChart), findsOneWidget);
      await _drain(tester);
    });

    for (final kind in <LoopChainFailureKind>[
      LoopChainFailureKind.notFound,
      LoopChainFailureKind.unavailable,
    ]) {
      testWidgets('${kind.name}: the whole card is not drawn', (tester) async {
        final gateway = _CandleGateway(
          _public(),
          (call) => Future<Launch2CandleSeries>.error(LoopChainException(kind)),
        );
        await _pump(tester, gateway);
        expect(_key('launch2-candles-intervals'), findsNothing);
        expect(find.text(launch2CandlesFailedText), findsNothing);
        expect(_key('launch2-candles-loading'), findsNothing);
        expect(_key('launch2-curve-price'), findsOneWidget);
        // Hidden is final: no poll keeps asking.
        await tester.pump(const Duration(minutes: 1));
        expect(gateway.calls, hasLength(1));
        await _drain(tester);
      });
    }

    testWidgets('graduated: 1 时 by default, the 毕业 rule on a mixed series', (
      tester,
    ) async {
      var source = 'mixed';
      final gateway = _CandleGateway(
        _graduated(),
        (call) => Future<Launch2CandleSeries>.value(
          _series(
            _seriesJson(
              interval: call.interval.wireName,
              source: source,
              candles: _candles(
                40,
                start: _graduatedAt.subtract(const Duration(hours: 20)),
                interval: call.interval,
              ),
            ),
            call.interval,
          ),
        ),
      );
      await _pump(tester, gateway);
      expect(gateway.calls.first.interval, Launch2CandleInterval.oneHour);
      expect(_key('launch2-candles-graduation'), findsOneWidget);
      expect(find.text('毕业'), findsOneWidget);
      expect(
        tester.getTopLeft(_key('launch2-candles')).dy,
        lessThan(tester.getTopLeft(find.text('毕业时间')).dy),
      );

      // A series of the pool alone has no crossing to mark.
      source = 'pool';
      await tester.tap(
        find.descendant(
          of: _key('launch2-candles-intervals'),
          matching: find.text('4时'),
        ),
      );
      await tester.pumpAndSettle();
      expect(_key('launch2-candles-graduation'), findsNothing);
      await _drain(tester);
    });

    testWidgets('re-reads every 15 s while seen, never while covered', (
      tester,
    ) async {
      final visible = ValueNotifier<bool>(true);
      addTearDown(visible.dispose);
      final gateway = _CandleGateway(
        _public(),
        (call) =>
            _ok(call, _candles(30, start: l2Now, interval: call.interval)),
      );
      await _pump(tester, gateway, visible: visible);
      expect(gateway.calls, hasLength(1));

      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(gateway.calls, hasLength(2));
      expect(gateway.calls.last.before, isNull);

      visible.value = false;
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(gateway.calls, hasLength(2));

      visible.value = true;
      await tester.pump();
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(gateway.calls, hasLength(3));
      await _drain(tester);
    });

    testWidgets('panning to the oldest bucket pages back with before', (
      tester,
    ) async {
      final start = l2Now.subtract(const Duration(hours: 24));
      final gateway = _CandleGateway(_public(), (call) {
        final before = call.before;
        if (before == null) {
          return _ok(
            call,
            _candles(200, start: start, interval: call.interval),
          );
        }
        return _ok(
          call,
          _candles(
            50,
            start: before.subtract(call.interval.width * 50),
            interval: call.interval,
          ),
        );
      });
      await _pump(tester, gateway);
      final chart = find.byType(LoopMarketChart);
      final before = tester.state<LoopMarketChartState>(chart).viewport;
      expect(before.total, 200);

      await tester.drag(
        _key('loop-market-chart-gestures'),
        const Offset(2000, 0),
      );
      await tester.pumpAndSettle();
      expect(gateway.calls, hasLength(2));
      expect(gateway.calls.last.before, start);
      expect(gateway.calls.last.interval, Launch2CandleInterval.fiveMinutes);

      final after = tester.state<LoopMarketChartState>(chart).viewport;
      expect(after.total, 250);
      // The window stays on the buckets the reader was looking at.
      expect(after.visible, before.visible);
      expect(after.start, greaterThanOrEqualTo(49));

      // Fewer than a page came back: there is nothing older to ask for.
      await tester.drag(
        _key('loop-market-chart-gestures'),
        const Offset(4000, 0),
      );
      await tester.pumpAndSettle();
      expect(gateway.calls, hasLength(2));
      await _drain(tester);
    });

    testWidgets('reduced motion: the loading skeleton holds still', (
      tester,
    ) async {
      final gateway = _CandleGateway(
        _public(),
        (call) => Future<Launch2CandleSeries>.delayed(
          const Duration(seconds: 3),
          () => _series(_seriesJson(), call.interval),
        ),
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pump(tester, gateway, settle: false);
      await tester.pump();
      await tester.pump();
      expect(_key('launch2-candles-loading'), findsOneWidget);
      final opacity = find.descendant(
        of: _key('launch2-candles-loading'),
        matching: find.byType(Opacity),
      );
      final first = tester.widget<Opacity>(opacity).opacity;
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.widget<Opacity>(opacity).opacity, first);
      await tester.pump(const Duration(seconds: 3));
      await _drain(tester);
    });
  });
}

final class _ScriptAdapter implements HttpClientAdapter {
  _ScriptAdapter(this.status, this.body);

  final int status;
  final Object? body;
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
        'cache-control': <String>['no-store'],
        'x-request-id': <String>[_requestId],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
