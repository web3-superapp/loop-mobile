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

void main() {
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
        child: MaterialApp(theme: LoopTheme.dark, home: const MarketScreen()),
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
        child: MaterialApp(theme: LoopTheme.dark, home: const MarketScreen()),
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
      child: MaterialApp(theme: LoopTheme.dark, home: const MarketScreen()),
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
