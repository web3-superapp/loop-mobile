import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/market_screens.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';

void main() {
  testWidgets('authenticated C10 hides every unobserved new-pair fact', (
    tester,
  ) async {
    final evidence = await _expectProductionBoundary(
      tester,
      LoopSessionMode.authenticated,
    );
    expect(evidence.$1.fetchCount, 0);
    expect(evidence.$2.requests, isEmpty);
  });

  testWidgets(
    'authenticated-unverified C10 hides every unobserved new-pair fact',
    (tester) async {
      final evidence = await _expectProductionBoundary(
        tester,
        LoopSessionMode.authenticatedUnverified,
      );
      expect(evidence.$1.fetchCount, 0);
      expect(evidence.$2.requests, isEmpty);
    },
  );

  testWidgets('only exact Preview renders continuously labelled C10 fixtures', (
    tester,
  ) async {
    final markets = _TrackingSpotMarketRepository();
    final candles = _TrackingSpotCandleRepository();
    await _pumpNewPairs(
      tester,
      session: const LoopSessionState.preview(),
      markets: markets,
      candles: candles,
    );

    expect(
      find.byKey(const ValueKey<String>('market-new-pairs-preview-fixtures')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('market-new-pairs-production-unavailable'),
      ),
      findsNothing,
    );
    expect(find.text('开发预览 · 只读'), findsOneWidget);
    expect(find.text('演示数据'), findsOneWidget);
    expect(find.text('Sample-only preview'), findsOneWidget);
    expect(find.text('BTC / USDC'), findsOneWidget);
    expect(find.text('ETH / USDC'), findsOneWidget);
    expect(find.text('SOL / USDC'), findsOneWidget);
    expect(find.text('Spot preview · Fixture age · 18 min'), findsOneWidget);
    expect(find.text('Spot preview · Fixture age · 42 min'), findsOneWidget);
    expect(find.text('Spot preview · Fixture age · 1 hr'), findsOneWidget);
    expect(find.text('Non-core results hidden'), findsOneWidget);
    expect(find.text('New pairs not connected'), findsNothing);
    expect(markets.fetchCount, 0);
    expect(candles.requests, isEmpty);
  });

  testWidgets('production Market hides the Preview quick-action rail', (
    tester,
  ) async {
    final markets = _TrackingSpotMarketRepository();
    final candles = _TrackingSpotCandleRepository();
    await _pumpSurface(
      tester,
      session: const LoopSessionState(mode: LoopSessionMode.authenticated),
      markets: markets,
      candles: candles,
      child: const MarketScreen(),
    );

    expect(
      find.byKey(const ValueKey<String>('market-preview-quick-actions')),
      findsNothing,
    );
    expect(find.text('FRONTEND PREVIEWS'), findsNothing);
    expect(find.text('Watchlist · 开发预览'), findsNothing);
    expect(find.text('New · 开发预览'), findsNothing);
    expect(find.text('Smart money · 开发预览'), findsNothing);
    expect(markets.fetchCount, 1);
    expect(candles.requests, isEmpty);
  });

  testWidgets('exact Preview keeps C10 entry visibly labelled', (tester) async {
    final markets = _TrackingSpotMarketRepository();
    final candles = _TrackingSpotCandleRepository();
    await _pumpSurface(
      tester,
      session: const LoopSessionState.preview(),
      markets: markets,
      candles: candles,
      child: const MarketScreen(),
    );

    expect(
      find.byKey(const ValueKey<String>('market-preview-quick-actions')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('market-new-pairs-preview-entry')),
      findsOneWidget,
    );
    expect(find.text('FRONTEND PREVIEWS'), findsOneWidget);
    expect(find.text('Watchlist · 开发预览'), findsOneWidget);
    expect(find.text('New · 开发预览'), findsOneWidget);
    expect(find.text('Smart money · 开发预览'), findsOneWidget);
    expect(markets.fetchCount, 1);
    expect(candles.requests, isEmpty);
  });

  testWidgets('Preview pair returns only to the bare public Spot ledger', (
    tester,
  ) async {
    final markets = _TrackingSpotMarketRepository();
    final candles = _TrackingSpotCandleRepository();
    final router = GoRouter(
      initialLocation: '/market/new',
      routes: <RouteBase>[
        GoRoute(
          path: '/market/new',
          builder: (context, state) => const NewPairsScreen(),
        ),
        GoRoute(
          path: '/market',
          builder: (context, state) =>
              const Scaffold(body: Text('Public Spot market ledger')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loopSessionProvider.overrideWith(
            () => _FixedSession(const LoopSessionState.preview()),
          ),
          hyperliquidSpotMarketRepositoryProvider.overrideWithValue(markets),
          hyperliquidSpotCandleRepositoryProvider.overrideWithValue(candles),
        ],
        child: MaterialApp.router(theme: LoopTheme.dark, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final firstPair = find.bySemanticsLabel(
      RegExp('Open live Spot market after reviewing BTC preview'),
    );
    expect(firstPair, findsOneWidget);
    await tester.tap(firstPair);
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/market');
    expect(router.routeInformationProvider.value.uri.query, isEmpty);
    expect(find.text('Public Spot market ledger'), findsOneWidget);
    expect(markets.fetchCount, 0);
    expect(candles.requests, isEmpty);
  });

  testWidgets(
    'mounted Market and C10 remove Preview facts after session rotation',
    (tester) async {
      final markets = _TrackingSpotMarketRepository();
      final candles = _TrackingSpotCandleRepository();
      final container = ProviderContainer(
        overrides: [
          loopSessionProvider.overrideWith(_MutableSession.new),
          hyperliquidSpotMarketRepositoryProvider.overrideWithValue(markets),
          hyperliquidSpotCandleRepositoryProvider.overrideWithValue(candles),
        ],
      );
      addTearDown(container.dispose);
      final router = GoRouter(
        initialLocation: '/market',
        routes: <RouteBase>[
          GoRoute(
            path: '/market',
            builder: (context, state) => const MarketScreen(),
          ),
          GoRoute(
            path: '/market/new',
            builder: (context, state) => const NewPairsScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: LoopTheme.dark,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('market-preview-quick-actions')),
        findsOneWidget,
      );
      final session =
          container.read(loopSessionProvider.notifier) as _MutableSession;
      session.setMode(LoopSessionMode.authenticatedUnverified);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('market-preview-quick-actions')),
        findsNothing,
      );

      session.setMode(LoopSessionMode.preview);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('market-new-pairs-preview-entry')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('market-new-pairs-preview-fixtures')),
        findsOneWidget,
      );

      session.setMode(LoopSessionMode.authenticated);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('market-new-pairs-production-unavailable'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('market-new-pairs-preview-fixtures')),
        findsNothing,
      );
      expect(find.text('BTC / USDC'), findsNothing);
      expect(markets.fetchCount, 1);
      expect(candles.requests, isEmpty);
    },
  );

  testWidgets('C10 remains scrollable at compact sizes and 200% text', (
    tester,
  ) async {
    for (final session in <LoopSessionState>[
      const LoopSessionState(mode: LoopSessionMode.authenticated),
      const LoopSessionState(mode: LoopSessionMode.authenticatedUnverified),
      const LoopSessionState.preview(),
    ]) {
      for (final size in <Size>[const Size(390, 844), const Size(844, 390)]) {
        final markets = _TrackingSpotMarketRepository();
        final candles = _TrackingSpotCandleRepository();
        await _pumpNewPairs(
          tester,
          session: session,
          markets: markets,
          candles: candles,
          size: size,
          textScaler: const TextScaler.linear(2),
        );

        final contentEnd = session.isPreview
            ? find.byKey(
                const ValueKey<String>('market-new-pairs-preview-content-end'),
              )
            : find.byKey(
                const ValueKey<String>(
                  'market-new-pairs-production-content-end',
                ),
              );
        await tester.ensureVisible(contentEnd);
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        final diagnostics = exception is FlutterError
            ? exception.diagnostics
                  .map((node) => node.toStringDeep())
                  .join('\n')
            : '$exception';
        expect(
          exception,
          isNull,
          reason: '${session.mode} · $size\n$diagnostics',
        );
        expect(markets.fetchCount, 0);
        expect(candles.requests, isEmpty);
      }
    }
  });
}

Future<(_TrackingSpotMarketRepository, _TrackingSpotCandleRepository)>
_expectProductionBoundary(WidgetTester tester, LoopSessionMode mode) async {
  final markets = _TrackingSpotMarketRepository();
  final candles = _TrackingSpotCandleRepository();
  await _pumpNewPairs(
    tester,
    session: LoopSessionState(mode: mode),
    markets: markets,
    candles: candles,
  );

  expect(
    find.byKey(
      const ValueKey<String>('market-new-pairs-production-unavailable'),
    ),
    findsOneWidget,
  );
  expect(find.text('New pairs not connected'), findsOneWidget);
  expect(find.text('Open public Spot market'), findsOneWidget);
  expect(
    find.text(
      'No listing-time source is connected. Price, client receipt time, first local observation, volume, and canonical status do not prove that a pair is new.',
    ),
    findsOneWidget,
  );

  expect(
    find.byKey(const ValueKey<String>('market-new-pairs-preview-fixtures')),
    findsNothing,
  );
  expect(find.textContaining('开发预览'), findsNothing);
  expect(find.textContaining('演示数据'), findsNothing);
  expect(find.text('BTC / USDC'), findsNothing);
  expect(find.text('ETH / USDC'), findsNothing);
  expect(find.text('SOL / USDC'), findsNothing);
  expect(find.textContaining('18 min'), findsNothing);
  expect(find.textContaining('42 min'), findsNothing);
  expect(find.textContaining('1 hr'), findsNothing);
  expect(find.text('Recently observed'), findsNothing);
  expect(find.text('Non-core results hidden'), findsNothing);
  return (markets, candles);
}

Future<void> _pumpNewPairs(
  WidgetTester tester, {
  required LoopSessionState session,
  required _TrackingSpotMarketRepository markets,
  required _TrackingSpotCandleRepository candles,
  Size size = const Size(800, 1600),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  return _pumpSurface(
    tester,
    session: session,
    markets: markets,
    candles: candles,
    size: size,
    textScaler: textScaler,
    child: const NewPairsScreen(),
  );
}

Future<void> _pumpSurface(
  WidgetTester tester, {
  required LoopSessionState session,
  required _TrackingSpotMarketRepository markets,
  required _TrackingSpotCandleRepository candles,
  required Widget child,
  Size size = const Size(800, 1600),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        loopSessionProvider.overrideWith(() => _FixedSession(session)),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(markets),
        hyperliquidSpotCandleRepositoryProvider.overrideWithValue(candles),
      ],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FixedSession extends LoopSessionController {
  _FixedSession(this.fixedState);

  final LoopSessionState fixedState;

  @override
  LoopSessionState build() => fixedState;
}

final class _MutableSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState.preview();

  void setMode(LoopSessionMode mode) {
    state = LoopSessionState(mode: mode);
  }
}

final class _TrackingSpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  var fetchCount = 0;

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async {
    fetchCount += 1;
    return HyperliquidSpotSnapshot(
      receivedAt: DateTime.utc(2026, 8, 28),
      markets: const <HyperliquidSpotMarket>[],
    );
  }
}

final class _TrackingSpotCandleRepository
    implements HyperliquidSpotCandleRepository {
  final List<(String, HyperliquidSpotCandleInterval)> requests =
      <(String, HyperliquidSpotCandleInterval)>[];

  @override
  Future<HyperliquidSpotCandleSnapshot> fetchCandles({
    required String providerCoin,
    required HyperliquidSpotCandleInterval interval,
  }) {
    requests.add((providerCoin, interval));
    throw StateError('C10 must not request public candle data.');
  }
}
