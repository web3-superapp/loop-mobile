import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoPageTransition, CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/market/loop_v2_market_api.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

// ---------------------------------------------------------------------------
// § 1 · the edge swipe goes back (decision 0085)
// ---------------------------------------------------------------------------

/// The app's own shape: five tabs inside a `ShellRoute`, every other page
/// pushed on the root navigator above it.
GoRouter _shellRouter({Widget detail = const Scaffold(body: Text('detail'))}) {
  return GoRouter(
    initialLocation: '/community',
    routes: <RouteBase>[
      ShellRoute(
        builder: (context, state, child) =>
            LoopShell(location: state.uri.path, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/community',
            pageBuilder: (context, state) => LoopTabPage<void>(
              key: state.pageKey,
              child: const Center(child: Text('community')),
            ),
          ),
        ],
      ),
      GoRoute(path: '/market/token', builder: (context, state) => detail),
    ],
  );
}

Future<GoRouter> _pumpPushedDetail(
  WidgetTester tester, {
  required TargetPlatform platform,
  bool reduceMotion = false,
  Widget detail = const Scaffold(body: Text('detail')),
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final router = _shellRouter(detail: detail);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      // `PageTransitionsTheme` picks its builder off `ThemeData.platform`,
      // which is the honest way to ask "what would an iPhone do" without
      // touching a foundation debug flag.
      theme: LoopTheme.dark.copyWith(platform: platform),
      routerConfig: router,
      builder: reduceMotion
          ? (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )
          : null,
    ),
  );
  await tester.pumpAndSettle();
  unawaited(router.push('/market/token'));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  loopWatchGround();

  group('右滑返回 · the push is the platform\'s own', () {
    testWidgets('the theme installs Cupertino on iOS and predictive back on '
        'Android', (tester) async {
      final builders = LoopTheme.dark.pageTransitionsTheme.builders;
      expect(
        builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
      expect(
        builders[TargetPlatform.macOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          builders[platform],
          isA<PredictiveBackPageTransitionsBuilder>(),
          reason: '$platform',
        );
      }
    });

    testWidgets('a pushed page on iOS is a Cupertino transition that can be '
        'swiped back', (tester) async {
      final router = await _pumpPushedDetail(
        tester,
        platform: TargetPlatform.iOS,
      );
      expect(find.text('detail'), findsOneWidget);
      // The gesture detector LOOP lost between S59 and this build lives inside
      // this transition; its presence is the gesture's presence.
      expect(find.byType(CupertinoPageTransition), findsWidgets);

      final route = ModalRoute.of(tester.element(find.text('detail')))!;
      expect(route.isFirst, isFalse);
      expect(route.popGestureEnabled, isTrue);

      // The real thing: a drag that starts inside the left edge pops.
      await tester.dragFrom(const Offset(2, 400), const Offset(360, 0));
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsNothing);
      expect(find.text('community'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/community');
    });

    testWidgets('reduced motion keeps the swipe', (tester) async {
      await _pumpPushedDetail(
        tester,
        platform: TargetPlatform.iOS,
        reduceMotion: true,
      );
      expect(find.text('detail'), findsOneWidget);
      expect(
        ModalRoute.of(tester.element(find.text('detail')))!.popGestureEnabled,
        isTrue,
      );

      await tester.dragFrom(const Offset(2, 400), const Offset(360, 0));
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsNothing);
    });

    testWidgets('a drag that starts away from the edge does not pop', (
      tester,
    ) async {
      await _pumpPushedDetail(tester, platform: TargetPlatform.iOS);
      await tester.dragFrom(const Offset(200, 400), const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);
    });

    testWidgets('a pushed page on Android can still be popped by the system', (
      tester,
    ) async {
      await _pumpPushedDetail(tester, platform: TargetPlatform.android);
      final route = ModalRoute.of(tester.element(find.text('detail')))!;
      expect(route.popGestureEnabled, isTrue);
      expect(
        Theme.of(tester.element(find.text('detail')))
            .pageTransitionsTheme
            .builders[TargetPlatform.android],
        isA<PredictiveBackPageTransitionsBuilder>(),
      );

      // What the system back gesture does, once the framework has said it
      // handles back.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsNothing);
    });
  });

  group('PopScope · only a page that must hold the reader turns it off', () {
    testWidgets('a PopScope that only listens leaves the gesture on', (
      tester,
    ) async {
      // The Audio Room's shape: `onPopInvokedWithResult` releases presence and
      // `canPop` is left alone. A listener is not a veto.
      var popped = false;
      await _pumpPushedDetail(
        tester,
        platform: TargetPlatform.iOS,
        detail: PopScope<Object?>(
          onPopInvokedWithResult: (didPop, _) => popped = didPop,
          child: const Scaffold(body: Text('detail')),
        ),
      );
      expect(
        ModalRoute.of(tester.element(find.text('detail')))!.popGestureEnabled,
        isTrue,
      );
      await tester.dragFrom(const Offset(2, 400), const Offset(360, 0));
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsNothing);
      expect(popped, isTrue);
    });

    testWidgets('a signing sheet that says canPop: false turns it off', (
      tester,
    ) async {
      // The money sign sheet while the wallet is open, and the blocking policy
      // gate. Those two, and nothing else, may take the gesture away.
      await _pumpPushedDetail(
        tester,
        platform: TargetPlatform.iOS,
        detail: const PopScope<Object?>(
          canPop: false,
          child: Scaffold(body: Text('detail')),
        ),
      );
      expect(
        ModalRoute.of(tester.element(find.text('detail')))!.popGestureEnabled,
        isFalse,
      );
      await tester.dragFrom(const Offset(2, 400), const Offset(360, 0));
      await tester.pumpAndSettle();
      expect(find.text('detail'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // § 2 · the price column prints the price
  // -------------------------------------------------------------------------

  group('行情 price · the digits follow the magnitude', () {
    test('a figure is rounded to what its magnitude can carry', () {
      expect(marketRowPrice(s5Decimal('85866.13')), r'$85,866');
      expect(marketRowPrice(s5Decimal('85866.72')), r'$85,867');
      expect(marketRowPrice(s5Decimal('10000')), r'$10,000');
      expect(marketRowPrice(s5Decimal('1248.37')), r'$1,248.4');
      expect(marketRowPrice(s5Decimal('1000')), r'$1,000.0');
      expect(marketRowPrice(s5Decimal('747.39')), r'$747.39');
      expect(marketRowPrice(s5Decimal('12')), r'$12.00');
      expect(marketRowPrice(s5Decimal('1')), r'$1.00');
    });

    test('the threshold is re-read after rounding', () {
      // 9,999.96 at one decimal is 10,000.0, which belongs one row up.
      expect(marketRowPrice(s5Decimal('9999.96')), r'$10,000');
    });

    test('below a dollar the figure keeps four significant digits', () {
      expect(marketRowPrice(s5Decimal('0.874123')), r'$0.8741');
      expect(marketRowPrice(s5Decimal('0.0000012345')), r'$0.000001235');
      // Not a rounded-away zero, and not 「<$1」 either.
      expect(marketRowPrice(s5Decimal('0.004')), r'$0.004');
    });

    test('a sign sits where every other LOOP figure puts it', () {
      expect(marketRowPrice(s5Decimal('-12.5')), r'$-12.50');
    });
  });

  group('行情 row · the price column takes its width from the name', () {
    Future<void> pumpRow(WidgetTester tester, String price) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            backgroundColor: LoopColors.ink,
            body: Column(
              children: <Widget>[
                MarketAssetTileGroup(
                  tiles: <Widget>[
                    MarketAssetTile(
                      row: s5MarketRow(price: s5FreshFact(price)),
                      sparkline: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    double priceWidth(WidgetTester tester) => tester
        .getSize(find.byKey(const ValueKey<String>('market-row-price-slot')))
        .width;

    double nameWidth(WidgetTester tester) =>
        tester.getSize(find.text('WBNB')).width;

    testWidgets('a five-figure price is printed whole, not ellipsised', (
      tester,
    ) async {
      await pumpRow(tester, '85866.13');
      expect(find.text(r'$85,866'), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(r'$85,866'),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(priceWidth(tester), greaterThanOrEqualTo(marketRowPriceWidth));
      expect(priceWidth(tester), lessThanOrEqualTo(marketRowPriceMaxWidth));
    });

    testWidgets('a wider figure takes the width off the name, never off the '
        'change block', (tester) async {
      await pumpRow(tester, '7.39');
      final narrowPrice = priceWidth(tester);
      final wideName = nameWidth(tester);
      final change = tester.getSize(find.byType(MarketChangeBlock)).width;

      await pumpRow(tester, '0.0000012345');
      expect(priceWidth(tester), greaterThan(narrowPrice));
      expect(nameWidth(tester), lessThan(wideName));
      expect(tester.getSize(find.byType(MarketChangeBlock)).width, change);
      expect(change, marketRowChangeWidth);
    });

    testWidgets('a short figure still holds the column floor', (tester) async {
      await pumpRow(tester, '7.39');
      expect(priceWidth(tester), marketRowPriceWidth);
    });
  });

  // -------------------------------------------------------------------------
  // § 3 · the line comes with the row
  // -------------------------------------------------------------------------

  group('行情 折线 · the row carries its own series', () {
    testWidgets('a row with a series draws it and asks for no candles', (
      tester,
    ) async {
      final market = FakeMarketReadGateway();
      await pumpS5Page(tester, const MarketScreen(), market: market);

      expect(find.byType(LoopSparkline), findsWidgets);
      // The regression this replaces: one `1h` candle request per visible row
      // against a rate-limited provider.
      expect(market.candles.resolves, 0);
      expect(market.intervals, isEmpty);
    });

    testWidgets('a row with no series leaves the slot reserved and empty', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            backgroundColor: LoopColors.ink,
            body: Column(
              children: <Widget>[
                MarketAssetTileGroup(
                  tiles: <Widget>[
                    MarketAssetTile(
                      key: const ValueKey<String>('tile-without'),
                      row: s5MarketRow(withSparkline: false),
                      sparkline: MarketRowSparkline(
                        series: s5MarketRow(withSparkline: false).sparkline,
                      ),
                    ),
                    MarketAssetTile(
                      key: const ValueKey<String>('tile-with'),
                      row: s5MarketRow(),
                      sparkline: MarketRowSparkline(
                        series: s5MarketRow().sparkline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('market-spark-absent')),
        findsOneWidget,
      );
      expect(find.byType(LoopSparkline), findsOneWidget);
      // Both rows keep the same slot, so the value column does not move.
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey<String>('market-row-spark-slot')).first,
            )
            .width,
        marketRowSparklineSize.width,
      );
      expect(
        tester.getSize(find.byType(MarketAssetTile).first).height,
        tester.getSize(find.byType(MarketAssetTile).last).height,
      );
    });

    testWidgets('a single close is not a line', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: marketRowSparklineSize.width,
                height: marketRowSparklineSize.height,
                child: MarketRowSparkline(
                  series: s5RowSparkline(closes: const <String>['1']),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoopSparkline), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('market-spark-absent')),
        findsOneWidget,
      );
    });
  });

  group('行情 折线 · the row contract decodes the series', () {
    const accessToken = 'privy-access-token';

    Map<String, Object?> watchlistBlock(Map<String, Object?> item) =>
        <String, Object?>{
          'status': 'available',
          'version': 3,
          'items': <Object?>[item],
        };

    Map<String, Object?> rowPayload({Object? sparkline, bool withKey = true}) =>
        <String, Object?>{
          'assetId': s5WbnbAssetId,
          'asset': s5AssetSummary(),
          'logo': s5Logo(),
          'price': s5Fact(),
          'priceChange24h': s5Fact(value: '-3.2', ttlSeconds: 30),
          if (withKey) 'sparkline': sparkline,
        };

    Future<MarketAssetRow> decode(Map<String, Object?> row) async {
      final api = DioLoopV2MarketApi(
        s5Dio(
          (options, handler) => handler.resolve(
            s5Response(options, s5OverviewBody(watchlist: watchlistBlock(row))),
          ),
        ),
      );
      final overview = await api.getOverview(
        accessToken: accessToken,
        clientVersion: s5ClientVersion,
      );
      return (overview.watchlist as MarketWatchlistAvailable).items.single;
    }

    test('an available series arrives as Decimal closes', () async {
      final row = await decode(
        rowPayload(
          sparkline: <String, Object?>{
            'status': 'available',
            'interval': '1h',
            'closes': <String>['1.5', '2.25', '2'],
            'observedAt': '2026-09-08T07:31:00.000Z',
          },
        ),
      );
      final series = row.sparkline!;
      expect(series.interval, LoopCandleInterval.oneHour);
      expect(series.closes, <Decimal>[
        s5Decimal('1.5'),
        s5Decimal('2.25'),
        s5Decimal('2'),
      ]);
      expect(series.observedAt, DateTime.utc(2026, 9, 8, 7, 31));
      expect(series.hasShape, isTrue);
    });

    test(
      'an unavailable series is a row with no line, not a failure',
      () async {
        final row = await decode(
          rowPayload(
            sparkline: <String, Object?>{
              'status': 'unavailable',
              'reasonCode': 'MARKET_PROVIDER_RATE_LIMITED',
            },
          ),
        );
        expect(row.sparkline, isNull);
        expect(row.price.isAvailable, isTrue);
      },
    );

    test('a server that sends no key at all still renders the row', () async {
      expect((await decode(rowPayload(withKey: false))).sparkline, isNull);
      expect((await decode(rowPayload())).sparkline, isNull);
    });

    test('a malformed available series is an invalid payload', () async {
      for (final broken in <Object?>[
        // An interval LOOP does not publish.
        <String, Object?>{
          'status': 'available',
          'interval': '2h',
          'closes': <String>['1', '2'],
          'observedAt': '2026-09-08T07:31:00.000Z',
        },
        // A close that is a JSON number rather than a decimal string.
        <String, Object?>{
          'status': 'available',
          'interval': '1h',
          'closes': <Object?>[1.5],
          'observedAt': '2026-09-08T07:31:00.000Z',
        },
        // No observation time.
        <String, Object?>{
          'status': 'available',
          'interval': '1h',
          'closes': <String>['1', '2'],
        },
        // A key the contract does not name.
        <String, Object?>{
          'status': 'available',
          'interval': '1h',
          'closes': <String>['1', '2'],
          'observedAt': '2026-09-08T07:31:00.000Z',
          'note': 'extra',
        },
      ]) {
        await expectLater(
          decode(rowPayload(sparkline: broken)),
          throwsA(
            isA<LoopBackendFailure>().having(
              (failure) => failure.kind,
              'kind',
              LoopBackendFailureKind.invalidPayload,
            ),
          ),
          reason: '$broken',
        );
      }
    });
  });
}
