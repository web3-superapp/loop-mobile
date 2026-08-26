import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/market_screens.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_repository.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';

void main() {
  testWidgets(
    'primary Market renders public spot rows and never requests perp',
    (tester) async {
      final perpRepository = _FakeMarketRepository(markets: _markets);
      final spotRepository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
      await _pumpSpotMarket(
        tester,
        spotRepository,
        perpRepository: perpRepository,
      );

      expect(perpRepository.fetchCount, 0);
      expect(spotRepository.fetchCount, 1);
      expect(find.text('Spot market'), findsOneWidget);
      expect(find.text('TESTNET · SPOT · 实时公共数据 · 只读'), findsOneWidget);
      expect(find.text('PURR/USDC'), findsOneWidget);
      expect(find.text('HYPE/USDC'), findsOneWidget);
      expect(find.text('LIVE SPOT MARKETS · 2'), findsOneWidget);
      expect(
        find.textContaining('client received 03:04:05 UTC'),
        findsOneWidget,
      );
      expect(find.textContaining('Perp trading'), findsNothing);
      expect(find.textContaining('Live perpetual markets'), findsNothing);
    },
  );

  testWidgets('tapping a spot row opens that exact market detail', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
    await _pumpRoutableSpotMarket(tester, repository);

    await tester.tap(find.byKey(const ValueKey<String>('spot-market-1')));
    await tester.pumpAndSettle();

    expect(find.text('spot-detail-route-1'), findsOneWidget);
  });

  testWidgets(
    'spot detail renders exact public facts without preview or execution',
    (tester) async {
      final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
      final candleRepository = _FakeSpotCandleRepository();
      await _pumpSpotDetail(
        tester,
        repository,
        spotIndex: 1,
        candleRepository: candleRepository,
      );

      expect(find.text('PURR/USDC'), findsOneWidget);
      expect(find.text('0.50000001 USDC'), findsWidgets);
      expect(find.text('0.625 USDC'), findsOneWidget);
      expect(find.text('987654.321 USDC'), findsOneWidget);
      expect(find.text('1975308.62 PURR'), findsOneWidget);
      expect(find.text('@1'), findsOneWidget);
      expect(
        find.text('Client received 2026-08-25 03:04:05 UTC'),
        findsOneWidget,
      );
      expect(find.text('真实 K 线'), findsOneWidget);
      expect(find.text('4H'), findsWidgets);
      expect(find.text('2 candles'), findsOneWidget);
      expect(candleRepository.requests, <HyperliquidSpotCandleRequest>[
        const HyperliquidSpotCandleRequest(
          providerCoin: '@1',
          interval: HyperliquidSpotCandleInterval.fourHours,
        ),
      ]);
      expect(find.textContaining('历史图表尚不可用'), findsNothing);
      expect(find.textContaining('开发预览'), findsNothing);
      expect(find.textContaining('Buy'), findsNothing);
      expect(find.textContaining('Sell'), findsNothing);
      expect(find.textContaining('Perpetual'), findsNothing);
    },
  );

  testWidgets(
    'spot detail never substitutes another market when index is absent',
    (tester) async {
      final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
      final candleRepository = _FakeSpotCandleRepository();
      await _pumpSpotDetail(
        tester,
        repository,
        spotIndex: 9999,
        candleRepository: candleRepository,
      );

      expect(find.text('找不到这个现货市场'), findsOneWidget);
      expect(find.text('PURR/USDC'), findsNothing);
      expect(find.text('HYPE/USDC'), findsNothing);
      expect(candleRepository.requests, isEmpty);
    },
  );

  testWidgets('invalid spot detail index fails closed without a request', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
    final candleRepository = _FakeSpotCandleRepository();
    await _pumpSpotDetail(
      tester,
      repository,
      spotIndex: null,
      candleRepository: candleRepository,
    );

    expect(repository.fetchCount, 0);
    expect(find.text('Invalid spot market'), findsOneWidget);
    expect(find.textContaining('未加载行情或回退到演示币种'), findsOneWidget);
    expect(find.text('Ethereum'), findsNothing);
    expect(candleRepository.requests, isEmpty);
  });

  testWidgets('spot detail supports a narrow screen at 200 percent text', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(
      snapshot: HyperliquidSpotSnapshot(
        receivedAt: DateTime.utc(2026, 8, 25, 3, 4, 5),
        markets: <HyperliquidSpotMarket>[
          _spotMarket(
            spotIndex: 77,
            providerCoin: '@77',
            baseSymbol: 'NARROW',
            markPrice: '123456.78900001',
            previousDayPrice: '0',
            dayNotionalVolume: '987654.321',
            dayBaseVolume: '1975308.62',
          ),
        ],
      ),
    );

    await _pumpSpotDetail(
      tester,
      repository,
      spotIndex: 77,
      size: const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text('24h change unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marks a final candle still forming at receipt time', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
    await _pumpSpotDetail(tester, repository, spotIndex: 1);

    expect(find.text('最后一根形成中'), findsOneWidget);
    expect(find.textContaining('刷新后 OHLCV 可能变化'), findsOneWidget);
  });

  testWidgets('spot detail switches exact candle periods and refreshes both', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
    final candleRepository = _FakeSpotCandleRepository();
    await _pumpSpotDetail(
      tester,
      repository,
      spotIndex: 1,
      candleRepository: candleRepository,
    );

    final oneDay = find.byKey(const ValueKey<String>('spot-candle-period-1D'));
    await tester.ensureVisible(oneDay);
    await tester.tap(oneDay);
    await tester.pumpAndSettle();

    expect(candleRepository.requests, <HyperliquidSpotCandleRequest>[
      const HyperliquidSpotCandleRequest(
        providerCoin: '@1',
        interval: HyperliquidSpotCandleInterval.fourHours,
      ),
      const HyperliquidSpotCandleRequest(
        providerCoin: '@1',
        interval: HyperliquidSpotCandleInterval.oneDay,
      ),
    ]);
    expect(tester.widget<ChoiceChip>(oneDay).selected, isTrue);

    await tester.tap(
      find.byKey(const ValueKey<String>('refresh-spot-market-detail')),
    );
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 2);
    expect(
      candleRepository.requests.last.interval,
      HyperliquidSpotCandleInterval.oneDay,
    );
    expect(candleRepository.requests, hasLength(3));
    expect(tester.widget<ChoiceChip>(oneDay).selected, isTrue);
  });

  testWidgets('candle failure keeps spot facts visible and retries safely', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
    final candleRepository = _FakeSpotCandleRepository(
      failure: const HyperliquidMarketFailure(
        HyperliquidMarketFailureKind.connection,
      ),
    );
    await _pumpSpotDetail(
      tester,
      repository,
      spotIndex: 1,
      candleRepository: candleRepository,
    );

    expect(find.text('K 线暂不可用'), findsOneWidget);
    expect(find.text('无法连接 Testnet，请检查网络。'), findsOneWidget);
    expect(find.text('987654.321 USDC'), findsOneWidget);
    expect(find.textContaining('演示 K 线'), findsNothing);

    candleRepository.failure = null;
    final retry = find.byKey(const ValueKey<String>('retry-live-spot-candles'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(candleRepository.requests, hasLength(2));
    expect(find.text('2 candles'), findsOneWidget);
  });

  testWidgets('empty candle history never falls back to preview data', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
    final candleRepository = _FakeSpotCandleRepository(empty: true);
    await _pumpSpotDetail(
      tester,
      repository,
      spotIndex: 1,
      candleRepository: candleRepository,
    );

    expect(find.text('这个时间窗口没有 K 线'), findsOneWidget);
    expect(find.textContaining('未用演示 K 线或其他币种补齐'), findsOneWidget);
    expect(find.text('2 candles'), findsNothing);
  });

  testWidgets('candle loading hides all chart facts until data arrives', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
    final candleRepository = _CompletingSpotCandleRepository();
    await _pumpSpotDetail(
      tester,
      repository,
      spotIndex: 1,
      candleRepository: candleRepository,
      settle: false,
    );

    expect(find.text('正在加载 4H 真实 K 线'), findsOneWidget);
    expect(find.text('2 candles'), findsNothing);
    expect(find.textContaining('Latest O'), findsNothing);

    candleRepository.complete();
    await tester.pumpAndSettle();

    expect(find.text('2 candles'), findsOneWidget);
  });

  testWidgets('primary spot Market searches protocol and token identities', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
    await _pumpSpotMarket(tester, repository);

    await tester.enterText(
      find.byKey(const ValueKey<String>('live-spot-market-search')),
      ' hype ',
    );
    await tester.pump();

    expect(find.text('HYPE/USDC'), findsOneWidget);
    expect(find.text('PURR/USDC'), findsNothing);
    expect(find.text('LIVE SPOT MARKETS · 1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('live-spot-market-search')),
      '@1035',
    );
    await tester.pump();

    expect(find.text('HYPE/USDC'), findsOneWidget);
    expect(find.text('PURR/USDC'), findsNothing);
  });

  testWidgets('primary spot Market refreshes the public snapshot', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
    await _pumpSpotMarket(tester, repository);

    await tester.tap(
      find.byKey(const ValueKey<String>('refresh-live-spot-markets')),
    );
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 2);
    expect(find.text('HYPE/USDC'), findsOneWidget);
  });

  testWidgets('primary spot Market sanitizes failures and retries', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(
      snapshot: _spotSnapshot,
      failure: const HyperliquidMarketFailure(
        HyperliquidMarketFailureKind.connection,
      ),
    );
    await _pumpSpotMarket(tester, repository);

    expect(find.text('现货行情暂不可用'), findsOneWidget);
    expect(find.text('无法连接 Testnet，请检查网络。'), findsOneWidget);

    repository.failure = null;
    await tester.tap(
      find.byKey(const ValueKey<String>('retry-live-spot-markets')),
    );
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 2);
    expect(find.text('HYPE/USDC'), findsOneWidget);
  });

  testWidgets('restricted sessions never request the public spot repository', (
    tester,
  ) async {
    final repository = _FakeSpotMarketRepository(snapshot: _spotSnapshot);
    await _pumpSpotMarket(tester, repository, networkAllowed: false);

    expect(repository.fetchCount, 0);
    expect(find.text('现货行情暂不可用'), findsOneWidget);
    expect(find.textContaining('受限会话保持离线'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('retry-live-spot-markets')),
      findsNothing,
    );
  });

  testWidgets(
    'primary spot Market distinguishes inactive and no-match states',
    (tester) async {
      final repository = _FakeSpotMarketRepository(
        snapshot: HyperliquidSpotSnapshot(
          receivedAt: DateTime.utc(2026, 8, 25),
          markets: <HyperliquidSpotMarket>[_inactiveSpotMarket],
        ),
      );
      await _pumpSpotMarket(tester, repository);

      expect(find.text('暂无活跃现货市场'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('live-spot-market-search')),
        'NO-SUCH-SPOT',
      );
      await tester.pump();

      expect(find.text('没有匹配的现货市场'), findsOneWidget);
    },
  );

  testWidgets('restricted sessions stay offline and never call Testnet', (
    tester,
  ) async {
    final repository = _FakeMarketRepository(markets: _markets);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hyperliquidMarketNetworkAllowedProvider.overrideWithValue(false),
          hyperliquidMarketRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: const LegacyPerpetualMarketScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 0);
    expect(find.textContaining('受限会话保持离线'), findsOneWidget);
  });

  testWidgets('keeps provider facts hidden while the feed is loading', (
    tester,
  ) async {
    final repository = _CompletingMarketRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hyperliquidMarketNetworkAllowedProvider.overrideWithValue(true),
          hyperliquidMarketRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: const LegacyPerpetualMarketScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('BTC-USD'), findsNothing);

    repository.completer.complete(_markets);
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('BTC-USD'), findsOneWidget);
  });

  testWidgets('shows live Testnet rows, searches, and refreshes', (
    tester,
  ) async {
    final repository = _FakeMarketRepository(markets: _markets);
    await _pumpMarket(tester, repository);

    expect(find.text('TESTNET · 实时公共数据 · 只读'), findsOneWidget);
    expect(find.text('BTC-USD'), findsOneWidget);
    expect(find.text('ETH-USD'), findsOneWidget);
    expect(find.text('实时列表 · 详情为开发预览'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const ValueKey<String>('live-market-search')),
      ' eth ',
    );
    await tester.pump();

    expect(find.text('BTC-USD'), findsNothing);
    expect(find.text('ETH-USD'), findsOneWidget);
    expect(find.text('LIVE PERPETUAL MARKETS · 1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('refresh-live-markets')),
    );
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 2);
  });

  testWidgets('shows a sanitized failure and retries successfully', (
    tester,
  ) async {
    final repository = _FakeMarketRepository(
      markets: _markets,
      failure: const HyperliquidMarketFailure(
        HyperliquidMarketFailureKind.connection,
      ),
    );
    await _pumpMarket(tester, repository);

    expect(find.text('行情暂不可用'), findsOneWidget);
    expect(find.text('无法连接 Testnet，请检查网络。'), findsOneWidget);

    repository.failure = null;
    await tester.tap(find.byKey(const ValueKey<String>('retry-live-markets')));
    await tester.pumpAndSettle();

    expect(find.text('BTC-USD'), findsOneWidget);
    expect(repository.fetchCount, 2);
  });

  testWidgets('distinguishes an empty provider result from search no-match', (
    tester,
  ) async {
    final repository = _FakeMarketRepository(markets: const []);
    await _pumpMarket(tester, repository);

    expect(find.text('暂无可展示市场'), findsOneWidget);

    repository.markets = _markets;
    await tester.tap(
      find.byKey(const ValueKey<String>('refresh-live-markets')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('live-market-search')),
      'NO-SUCH-MARKET',
    );
    await tester.pump();

    expect(find.text('没有匹配的市场'), findsOneWidget);
  });

  testWidgets(
    'static token details stay visibly labelled development preview',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const TokenDetailScreen(symbol: 'BTC'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('开发预览 · 只读'), findsOneWidget);
      expect(find.text('演示数据'), findsOneWidget);
      expect(find.textContaining('不是实时行情'), findsOneWidget);
    },
  );
}

Future<void> _pumpSpotMarket(
  WidgetTester tester,
  HyperliquidSpotMarketRepository repository, {
  bool networkAllowed = true,
  HyperliquidMarketRepository? perpRepository,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hyperliquidSpotMarketNetworkAllowedProvider.overrideWithValue(
          networkAllowed,
        ),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(repository),
        if (perpRepository != null) ...[
          hyperliquidMarketNetworkAllowedProvider.overrideWithValue(true),
          hyperliquidMarketRepositoryProvider.overrideWithValue(perpRepository),
        ],
      ],
      child: MaterialApp(theme: LoopTheme.dark, home: const MarketScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRoutableSpotMarket(
  WidgetTester tester,
  HyperliquidSpotMarketRepository repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final router = GoRouter(
    initialLocation: '/market',
    routes: <RouteBase>[
      GoRoute(
        path: '/market',
        builder: (context, state) => const MarketScreen(),
      ),
      GoRoute(
        path: '/market/token',
        builder: (context, state) => Scaffold(
          body: Text(
            'spot-detail-route-${state.uri.queryParameters['spotIndex']}',
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hyperliquidSpotMarketNetworkAllowedProvider.overrideWithValue(true),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(theme: LoopTheme.dark, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSpotDetail(
  WidgetTester tester,
  HyperliquidSpotMarketRepository repository, {
  required int? spotIndex,
  HyperliquidSpotCandleRepository? candleRepository,
  Size size = const Size(800, 1600),
  TextScaler textScaler = TextScaler.noScaling,
  bool settle = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hyperliquidSpotMarketNetworkAllowedProvider.overrideWithValue(true),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(repository),
        hyperliquidSpotCandleRepositoryProvider.overrideWithValue(
          candleRepository ?? _FakeSpotCandleRepository(),
        ),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: SpotMarketDetailScreen(spotIndex: spotIndex),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _pumpMarket(
  WidgetTester tester,
  HyperliquidMarketRepository repository,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1600);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hyperliquidMarketNetworkAllowedProvider.overrideWithValue(true),
        hyperliquidMarketRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: const LegacyPerpetualMarketScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final List<HyperliquidMarket> _markets = <HyperliquidMarket>[
  HyperliquidMarket(
    symbol: 'BTC',
    sizeDecimals: 5,
    maxLeverage: 50,
    markPrice: ExactDecimal(
      source: '64231.125',
      value: Decimal.parse('64231.125'),
    ),
    dayNotionalVolume: ExactDecimal(
      source: '123456789.00000001',
      value: Decimal.parse('123456789.00000001'),
    ),
    fundingRate: ExactDecimal(
      source: '0.0000125',
      value: Decimal.parse('0.0000125'),
    ),
  ),
  HyperliquidMarket(
    symbol: 'ETH',
    sizeDecimals: 4,
    maxLeverage: 50,
    markPrice: ExactDecimal(source: '3456.75', value: Decimal.parse('3456.75')),
    dayNotionalVolume: ExactDecimal(
      source: '98765432.10',
      value: Decimal.parse('98765432.10'),
    ),
    fundingRate: ExactDecimal(
      source: '-0.0000042',
      value: Decimal.parse('-0.0000042'),
    ),
  ),
];

final HyperliquidSpotSnapshot _spotSnapshot = HyperliquidSpotSnapshot(
  receivedAt: DateTime.utc(2026, 8, 25, 3, 4, 5),
  markets: <HyperliquidSpotMarket>[
    _spotMarket(
      spotIndex: 1035,
      providerCoin: '@1035',
      baseSymbol: 'HYPE',
      markPrice: '32.50000001',
      previousDayPrice: '30',
      dayNotionalVolume: '123456.78900001',
      dayBaseVolume: '3798.67',
    ),
    _spotMarket(
      spotIndex: 1,
      providerCoin: '@1',
      baseSymbol: 'PURR',
      markPrice: '0.50000001',
      previousDayPrice: '0.625',
      dayNotionalVolume: '987654.321',
      dayBaseVolume: '1975308.62',
    ),
  ],
);

final HyperliquidSpotMarket _inactiveSpotMarket = _spotMarket(
  spotIndex: 77,
  providerCoin: '@77',
  baseSymbol: 'IDLE',
  markPrice: '1',
  previousDayPrice: '1',
  dayNotionalVolume: '0',
  dayBaseVolume: '0',
);

HyperliquidSpotMarket _spotMarket({
  required int spotIndex,
  required String providerCoin,
  required String baseSymbol,
  required String markPrice,
  required String previousDayPrice,
  required String dayNotionalVolume,
  required String dayBaseVolume,
}) {
  return HyperliquidSpotMarket(
    spotIndex: spotIndex,
    providerCoin: providerCoin,
    baseTokenIndex: spotIndex + 1000,
    quoteTokenIndex: 0,
    baseTokenId: '0x11111111111111111111111111111111',
    quoteTokenId: '0x00000000000000000000000000000000',
    baseSymbol: baseSymbol,
    quoteSymbol: 'USDC',
    baseSizeDecimals: 8,
    isCanonical: true,
    markPrice: HyperliquidSpotDecimal(
      source: markPrice,
      value: Decimal.parse(markPrice),
    ),
    midPrice: null,
    previousDayPrice: HyperliquidSpotDecimal(
      source: previousDayPrice,
      value: Decimal.parse(previousDayPrice),
    ),
    dayNotionalVolume: HyperliquidSpotDecimal(
      source: dayNotionalVolume,
      value: Decimal.parse(dayNotionalVolume),
    ),
    dayBaseVolume: HyperliquidSpotDecimal(
      source: dayBaseVolume,
      value: Decimal.parse(dayBaseVolume),
    ),
  );
}

final class _FakeMarketRepository implements HyperliquidMarketRepository {
  _FakeMarketRepository({required this.markets, this.failure});

  List<HyperliquidMarket> markets;
  HyperliquidMarketFailure? failure;
  int fetchCount = 0;

  @override
  Future<List<HyperliquidMarket>> fetchMarkets() async {
    fetchCount += 1;
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    return markets;
  }
}

final class _CompletingMarketRepository implements HyperliquidMarketRepository {
  final Completer<List<HyperliquidMarket>> completer =
      Completer<List<HyperliquidMarket>>();

  @override
  Future<List<HyperliquidMarket>> fetchMarkets() => completer.future;
}

final class _FakeSpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  _FakeSpotMarketRepository({required this.snapshot, this.failure});

  HyperliquidSpotSnapshot snapshot;
  HyperliquidMarketFailure? failure;
  int fetchCount = 0;

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async {
    fetchCount += 1;
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    return snapshot;
  }
}

final class _FakeSpotCandleRepository
    implements HyperliquidSpotCandleRepository {
  _FakeSpotCandleRepository({this.failure, this.empty = false});

  HyperliquidMarketFailure? failure;
  final bool empty;
  final List<HyperliquidSpotCandleRequest> requests =
      <HyperliquidSpotCandleRequest>[];

  @override
  Future<HyperliquidSpotCandleSnapshot> fetchCandles({
    required String providerCoin,
    required HyperliquidSpotCandleInterval interval,
  }) async {
    requests.add(
      HyperliquidSpotCandleRequest(
        providerCoin: providerCoin,
        interval: interval,
      ),
    );
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    return _spotCandleSnapshot(
      providerCoin: providerCoin,
      interval: interval,
      empty: empty,
    );
  }
}

final class _CompletingSpotCandleRepository
    implements HyperliquidSpotCandleRepository {
  final Completer<void> _completion = Completer<void>();
  String? _providerCoin;
  HyperliquidSpotCandleInterval? _interval;

  void complete() => _completion.complete();

  @override
  Future<HyperliquidSpotCandleSnapshot> fetchCandles({
    required String providerCoin,
    required HyperliquidSpotCandleInterval interval,
  }) async {
    _providerCoin = providerCoin;
    _interval = interval;
    await _completion.future;
    return _spotCandleSnapshot(
      providerCoin: _providerCoin!,
      interval: _interval!,
    );
  }
}

HyperliquidSpotCandleSnapshot _spotCandleSnapshot({
  required String providerCoin,
  required HyperliquidSpotCandleInterval interval,
  bool empty = false,
}) {
  final receivedAt = DateTime.utc(2026, 8, 25, 3, 4, 5);
  return HyperliquidSpotCandleSnapshot(
    providerCoin: providerCoin,
    interval: interval,
    requestedFrom: receivedAt.subtract(interval.lookback),
    requestedUntil: receivedAt,
    receivedAt: receivedAt,
    candles: empty
        ? <HyperliquidSpotCandle>[]
        : <HyperliquidSpotCandle>[
            _spotCandle(
              providerCoin: providerCoin,
              interval: interval,
              openTime: DateTime.utc(2026, 8, 25),
              closeTime: DateTime.utc(2026, 8, 25, 1, 59, 59, 999),
              open: '0.5',
              close: '0.75',
              high: '0.8',
              low: '0.45',
              volume: '120.5',
              trades: 12,
            ),
            _spotCandle(
              providerCoin: providerCoin,
              interval: interval,
              openTime: DateTime.utc(2026, 8, 25, 2),
              closeTime: DateTime.utc(2026, 8, 25, 3, 59, 59, 999),
              open: '0.75',
              close: '0.625',
              high: '0.9',
              low: '0.6',
              volume: '80.25',
              trades: 7,
            ),
          ],
  );
}

HyperliquidSpotCandle _spotCandle({
  required String providerCoin,
  required HyperliquidSpotCandleInterval interval,
  required DateTime openTime,
  required DateTime closeTime,
  required String open,
  required String close,
  required String high,
  required String low,
  required String volume,
  required int trades,
}) {
  return HyperliquidSpotCandle(
    openTime: openTime,
    closeTime: closeTime,
    providerCoin: providerCoin,
    interval: interval,
    open: HyperliquidSpotDecimal(source: open, value: Decimal.parse(open)),
    close: HyperliquidSpotDecimal(source: close, value: Decimal.parse(close)),
    high: HyperliquidSpotDecimal(source: high, value: Decimal.parse(high)),
    low: HyperliquidSpotDecimal(source: low, value: Decimal.parse(low)),
    volume: HyperliquidSpotDecimal(
      source: volume,
      value: Decimal.parse(volume),
    ),
    tradeCount: trades,
  );
}
