// S345 · decision 0273: scripted MEME v2 and MEME curve gateways for the
// chart-parity tests and shots. Every value here is 测试专用.
import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart' show loopChartFullPage;
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_models.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/meme/meme_controllers.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/meme/meme_routes.dart';
import 'package:loop_mobile/features/meme/meme_token_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_candle_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_overview_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'launch2_fixtures.dart';
import 'meme_fixtures.dart';
import 's7_page_harness.dart';

/// The graduation moment in `l2DetailJson` (stage `graduated`).
final DateTime s345GraduatedAt = DateTime.utc(2027, 1, 24, 7);

/// A gentle K line of [count] buckets ending at [end].
List<Map<String, Object?>> s345CandleRows(
  Launch2CandleInterval interval, {
  required DateTime end,
  int count = 48,
}) {
  final step = interval.width.inSeconds;
  final start = end.subtract(Duration(seconds: step * count));
  final base = Decimal.parse('0.00004');
  return <Map<String, Object?>>[
    for (var i = 0; i < count; i += 1)
      () {
        final wave = (i % 7) - 3;
        final open = base + Decimal.parse('0.0000004') * Decimal.fromInt(i);
        final close = open + Decimal.parse('0.0000003') * Decimal.fromInt(wave);
        final high = (open > close ? open : close) + Decimal.parse('2e-7');
        final low = (open < close ? open : close) - Decimal.parse('2e-7');
        return <String, Object?>{
          't': start.millisecondsSinceEpoch ~/ 1000 + i * step,
          'o': open.toString(),
          'h': high.toString(),
          'l': low.toString(),
          'c': close.toString(),
          'v': '${2000000 + (i % 5) * 400000}',
          'q': '90.0',
          'n': 3,
        };
      }(),
  ];
}

/// The MEME v2 gateway: one detail and a K line (`mixed` across the
/// graduation for a graduated detail, `curve` otherwise).
final class S345Launch2 implements Launch2Gateway {
  S345Launch2(
    this.detail, {
    this.page,
    this.detailFailure,
    this.detailPending = false,
    this.noCandles = false,
  });

  final Launch2InstanceDetail detail;
  final Launch2InstancePage? page;

  /// The detail read fails with this kind.
  final LoopChainFailureKind? detailFailure;

  /// The detail read never answers.
  final bool detailPending;

  /// The K line has no bucket yet.
  final bool noCandles;
  final List<Launch2CandleInterval> candleCalls = <Launch2CandleInterval>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) {
    if (detailPending) return Completer<Launch2InstanceDetail>().future;
    final failure = detailFailure;
    if (failure != null) {
      return Future<Launch2InstanceDetail>.error(LoopChainException(failure));
    }
    return Future<Launch2InstanceDetail>.value(detail);
  }

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) {
    final value = page;
    if (value == null || cursor != null) {
      return Future<Launch2InstancePage>.error(
        const LoopChainException(LoopChainFailureKind.unavailable),
      );
    }
    return Future<Launch2InstancePage>.value(value);
  }

  @override
  Future<Launch2CandleSeries> candles(
    String instanceId,
    Launch2CandleInterval interval, {
    int limit = launch2CandlePageSize,
    DateTime? before,
  }) {
    candleCalls.add(interval);
    if (before != null) {
      return Future<Launch2CandleSeries>.error(
        const LoopChainException(LoopChainFailureKind.unavailable),
      );
    }
    final graduated = detail.stage == Launch2Stage.graduated;
    final end = graduated ? s345GraduatedAt.add(interval.width * 12) : l2Now;
    return Future<Launch2CandleSeries>.value(
      LoopV2Launch2CandleCodec.series(
        <String, Object?>{
          'instanceId': l2InstanceA,
          'interval': interval.wireName,
          'quoteAsset': 'USD1',
          'source': graduated ? 'mixed' : 'curve',
          'candles': noCandles
              ? const <Map<String, Object?>>[]
              : s345CandleRows(interval, end: end),
          'latest': null,
          'contractVersion': '2.0',
        },
        instanceId: l2InstanceA,
        requested: interval,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

/// The MEME v2 overview, figures included (they are no longer drawn).
final class S345Overview implements Launch2OverviewGateway {
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Overview> loadOverview() => Future<Launch2Overview>.value(
    LoopV2Launch2OverviewCodec.overview(<String, Object?>{
      'activity': <Object?>[],
      'stats': <String, Object?>{
        'liveCount': 9,
        'mintingCount': 2,
        'priorityCount': 1,
        'curveCount': 5,
        'upcomingCount': 3,
        'graduatedTotal': 12,
        'graduatedThisWeek': 3,
        'buybackUsd1Total': '4200.5',
        'nftMintedTotal': 318,
      },
      'observedAt': l2Now.toIso8601String(),
      'contractVersion': '2.0',
    }, mediaUrl: (_) => null),
  );
}

/// The MEME curve gateway: one token and a few hours of candles.
final class S345Meme implements MemeGateway {
  S345Meme(this.detail);

  final MemeTokenDetail detail;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<MemeTokenDetail> loadToken(String memeTokenId) =>
      Future<MemeTokenDetail>.value(detail);

  @override
  Future<MemeCandleSeries> loadCandles(
    String memeTokenId,
    MemeCandleInterval interval,
  ) => Future<MemeCandleSeries>.value(
    memeCandles(interval: interval, count: 12),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

LoopV2MetaSnapshot s345Meta({bool launch2Open = true}) {
  final base = s7MetaSnapshot();
  const evidence = LoopV2CapabilityEvidence(
    status: LoopV2CapabilityEvidenceStatus.notApplicable,
    reasonCode: null,
  );
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.launch2 ||
              capability.id == LoopV2CapabilityId.meme)
            LoopV2Capability(
              id: capability.id,
              availability:
                  launch2Open || capability.id != LoopV2CapabilityId.launch2
                  ? LoopV2CapabilityAvailability.available
                  : LoopV2CapabilityAvailability.unavailable,
              reasonCode:
                  launch2Open || capability.id != LoopV2CapabilityId.launch2
                  ? null
                  : 'LAUNCH2_RUNTIME_UNAVAILABLE',
              evidence: evidence,
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

/// [initial] inside a router that knows the project page, the curve token
/// page and `chart-full` exactly as the App builds it.
Future<GoRouter> pumpS345Router(
  WidgetTester tester, {
  required String initial,
  S345Launch2? launch2,
  S345Meme? meme,
  Size size = const Size(390, 2000),
  List<Override> overrides = const <Override>[],
  bool launch2Open = true,
  bool settle = true,
}) async {
  final router = GoRouter(
    initialLocation: initial,
    routes: <RouteBase>[
      GoRoute(
        path: Launch2Route.instancePath,
        builder: (context, state) => Launch2InstanceScreen(
          instanceId: Launch2Route.idOf(state.uri),
          onNavigate: (location) => context.push(location),
        ),
      ),
      GoRoute(
        path: MemeRoute.tokenPath,
        builder: (context, state) => MemeTokenScreen(
          memeTokenId: MemeRoute.idOf(state.uri),
          onNavigate: (location) => context.push(location),
        ),
      ),
      GoRoute(
        path: '/market/chart',
        builder: (context, state) => loopChartFullPage(
          state.uri,
          assetId: MarketAssetRoute.parse(
            state.uri,
            MarketAssetRoute.chartPath,
          ),
          onBack: () => context.pop(),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await pumpS7Page(
    tester,
    Router.withConfig(config: router),
    size: size,
    settle: settle,
    meta: s345Meta(launch2Open: launch2Open),
    wallet: FakeWalletDirectory(
      activeWalletId: l2WalletId,
      wallets: <LoopWalletAccount>[_wallet()],
    ),
    overrides: <Override>[
      if (launch2 != null) launch2GatewayProvider.overrideWithValue(launch2),
      if (meme != null) memeGatewayProvider.overrideWithValue(meme),
      launch2ClockProvider.overrideWithValue(() => l2Now),
      launch2PollingProvider.overrideWithValue(
        const Launch2Polling(
          detailInterval: Duration(hours: 1),
          tradingInterval: Duration(hours: 1),
        ),
      ),
      memePollingProvider.overrideWithValue(
        const MemePolling(
          intentInterval: Duration(milliseconds: 10),
          intentMaxAttempts: 5,
          tokenInterval: Duration(hours: 1),
        ),
      ),
      loopFeatureSwitchesProvider.overrideWithValue(
        const LoopFeatureSwitchValues(
          launch2Visible: true,
          classicMemeLaunchVisible: true,
        ),
      ),
      ...overrides,
    ],
  );
  return router;
}

/// Lets the pages' timers run out before teardown.
Future<void> drainS345(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

Launch2InstanceDetail s345Public() =>
    l2Detail(stage: 'public', viewer: l2ViewerJson(member: true));

Launch2InstanceDetail s345Graduated() =>
    l2Detail(stage: 'graduated', noNextChange: true, pool: l2PoolSummaryJson());
