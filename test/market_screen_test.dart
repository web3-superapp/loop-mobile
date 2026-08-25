import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/market_screens.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_repository.dart';
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
