// S307 · 情报 · 行情 rows draw the E-design trend column (decision 0247).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_fomo_widgets.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/market/loop_v2_market_api.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

List<Decimal> _d(List<String> values) => values.map(Decimal.parse).toList();

Map<String, Object?> _row({
  Object? sparkline24h = _absent,
  String assetId = s5WbnbAssetId,
}) => <String, Object?>{
  'assetId': assetId,
  'symbol': 'WBNB',
  'name': 'Wrapped BNB',
  'logoUrl': null,
  'quote': <String, Object?>{
    'priceUsd': '747.39',
    'change24hPct': '-1.01',
    'marketCapUsd': '1640000000',
    'volume24hUsd': '512345678.9',
    'observedAt': '2026-10-08T09:30:00.000Z',
    'source': 'dexscreener',
    'quality': 'fresh',
  },
  'sparkline': <String, Object?>{
    'status': 'unavailable',
    'reasonCode': 'MARKET_SPARKLINE_NOT_CACHED',
  },
  if (!identical(sparkline24h, _absent)) 'sparkline24h': sparkline24h,
};

const Object _absent = Object();

Map<String, Object?> _page(List<Object?> items) => <String, Object?>{
  'category': 'major',
  'sort': 'marketCap',
  'items': items,
  'nextCursor': null,
  'rules': <String, Object?>{
    'configVersion': 'marketCategoriesV1',
    'effectiveAt': '2026-10-08T00:00:00.000Z',
    'ordering': 'dexscreener_market_cap_desc',
  },
  'observedAt': '2026-10-08T09:30:01.123Z',
  'contractVersion': '2.0',
};

MarketCategoryRow _decodeOne(Object? sparkline24h) =>
    DioLoopV2MarketApi.decodeCategory(
      _page(<Object?>[_row(sparkline24h: sparkline24h)]),
      category: MarketCategory.major,
      sort: MarketCategorySort.marketCap,
    ).items.single;

Future<void> _pumpRow(
  WidgetTester tester,
  Widget row, {
  double width = 390,
  bool reduceMotion = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 200),
          disableAnimations: reduceMotion,
        ),
        child: Scaffold(
          body: Align(alignment: Alignment.topCenter, child: row),
        ),
      ),
    ),
  );
  await tester.pump();
}

MarketFomoRow _trendRow({
  String symbol = 'LOOP',
  String subtitle = 'LOOP',
  String price = '1.00',
  String? change = '8.4',
  List<Decimal>? closes,
}) => MarketFomoRow(
  symbol: symbol,
  subtitle: subtitle,
  price: Decimal.parse(price),
  change: change == null ? null : Decimal.parse(change),
  trend: true,
  trendCloses: closes,
);

LoopSparklinePainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_key('market-trend-line')).painter!
        as LoopSparklinePainter;

void main() {
  group('codec · optional sparkline24h (decision 0247)', () {
    test('a numeric array of 2–24 points is the series, oldest first', () {
      final row = _decodeOne(<Object?>[1, 1.5, '2.25', 0.000001]);
      expect(row.sparkline24h, _d(<String>['1', '1.5', '2.25', '0.000001']));
      expect(row.trendCloses, row.sparkline24h);
    });

    test('more than 24 points keep the newest 24', () {
      final row = _decodeOne(<Object?>[for (var i = 0; i < 30; i++) i]);
      expect(row.sparkline24h, hasLength(24));
      expect(row.sparkline24h!.first, Decimal.fromInt(6));
      expect(row.sparkline24h!.last, Decimal.fromInt(29));
    });

    final degraded = <String, Object?>{
      'key absent': _absent,
      'null': null,
      'not an array': '1,2,3',
      'an object': <String, Object?>{
        'closes': <int>[1, 2],
      },
      'a non-numeric element': <Object?>[1, 'abc', 3],
      'a null element': <Object?>[1, null, 3],
      'a boolean element': <Object?>[1, true],
      'a negative element': <Object?>[1, -2],
      'fewer than two points': <Object?>[1],
      'empty': <Object?>[],
    };
    degraded.forEach((label, value) {
      test('$label → no series, and the row and list still decode', () {
        final page = DioLoopV2MarketApi.decodeCategory(
          _page(<Object?>[
            _row(sparkline24h: value),
            _row(sparkline24h: <Object?>[1, 2], assetId: s5UsdtAssetId),
          ]),
          category: MarketCategory.major,
          sort: MarketCategorySort.marketCap,
        );
        expect(page.items, hasLength(2));
        expect(page.items.first.sparkline24h, isNull);
        expect(page.items.first.trendCloses, isNull);
        expect(page.items.first.quote!.priceUsd, Decimal.parse('747.39'));
        expect(page.items.last.sparkline24h, _d(<String>['1', '2']));
      });
    });

    test('the overview watchlist / trending rows accept the key too', () {
      Map<String, Object?> watchRow(Object? series) => <String, Object?>{
        'assetId': s5WbnbAssetId,
        'asset': s5AssetSummary(),
        'logo': s5Logo(),
        'price': s5Fact(),
        'priceChange24h': s5Fact(value: '-3.2', ttlSeconds: 30),
        'sparkline': s5SparklineUnavailable(),
        'sparkline24h': series,
      };
      for (final entry in <Object?, List<Decimal>?>{
        <Object?>[3, 2, 1]: _d(<String>['3', '2', '1']),
        null: null,
        'x': null,
        <Object?>[1, 'x']: null,
        <Object?>[1]: null,
      }.entries) {
        final overview = DioLoopV2MarketApi.decodeOverview(
          s5OverviewBody(
            watchlist: <String, Object?>{
              'status': 'available',
              'version': 3,
              'items': <Object?>[watchRow(entry.key)],
            },
          ),
        );
        final row =
            (overview.watchlist as MarketWatchlistAvailable).items.single;
        expect(row.sparkline24h, entry.value, reason: '${entry.key}');
        expect(row.trendCloses, entry.value, reason: '${entry.key}');
      }
      // Absent everywhere: the frozen fixture still decodes unchanged.
      final plain = DioLoopV2MarketApi.decodeOverview(s5OverviewBody());
      expect(
        (plain.watchlist as MarketWatchlistAvailable).items.single.sparkline24h,
        isNull,
      );
    });

    test('a row without sparkline24h falls back to an available sparkline', () {
      final series = MarketRowSparklineSeries(
        interval: LoopCandleInterval.oneHour,
        observedAt: DateTime.utc(2026, 10, 25),
        closes: _d(<String>['1', '2', '3']),
      );
      expect(marketTrendCloses(null, series), series.closes);
      expect(
        marketTrendCloses(_d(<String>['5', '4']), series),
        _d(<String>['5', '4']),
      );
      final dot = MarketRowSparklineSeries(
        interval: LoopCandleInterval.oneHour,
        observedAt: DateTime.utc(2026, 10, 25),
        closes: _d(<String>['1']),
      );
      expect(marketTrendCloses(null, dot), isNull);
      expect(marketTrendCloses(null, null), isNull);
    });
  });

  group('trend column (E 稿)', () {
    testWidgets('a rising series: rise line, end dot, signed percent', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        _trendRow(closes: _d(<String>['1', '1.02', '0.99', '1.08'])),
      );
      expect(_key('loop-change-pill'), findsNothing);
      expect(tester.getSize(_key('market-trend-column')).width, 96);
      expect(tester.getSize(_key('market-trend-line')), const Size(96, 32));
      final painter = _painter(tester);
      expect(painter.color, LoopColors.rise);
      expect(painter.endDotRadius, 2.6);
      expect(LoopSparklinePainter.strokeWidth, 1.6);
      expect(painter.progress, 1, reason: 'reduced motion: no draw-in');
      // Normalised between the series' own low and high: x 2 → 92, y 3 → 29.
      final points = LoopSparklinePainter.points(
        painter.closes,
        const Size(96, 32),
        padding: marketTrendLinePadding,
      );
      expect(points.first.dx, 2);
      expect(points.last.dx, 92);
      expect(points.last.dy, 3);
      expect(points[2].dy, 29);
      final percent = tester.widget<Text>(_key('market-trend-percent'));
      expect(percent.data, '+8.40%');
      expect(percent.style!.color, LoopColors.rise);
      expect(percent.style!.fontSize, 14);
      expect(percent.style!.fontWeight, FontWeight.w700);
      expect(find.bySemanticsLabel(RegExp('24 小时走势上涨 8.40%')), findsOneWidget);
    });

    testWidgets('a falling series is fall red', (tester) async {
      await _pumpRow(
        tester,
        _trendRow(change: '-1.45', closes: _d(<String>['2', '1.9', '1.8'])),
      );
      expect(_painter(tester).color, LoopColors.fall);
      final percent = tester.widget<Text>(_key('market-trend-percent'));
      expect(percent.data, '-1.45%');
      expect(percent.style!.color, LoopColors.fall);
      expect(find.bySemanticsLabel(RegExp('24 小时走势下跌 1.45%')), findsOneWidget);
    });

    testWidgets('a flat move: line3 grey line and an ink 0.00%', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        _trendRow(change: '0', closes: _d(<String>['1', '1.0001', '1'])),
      );
      expect(_painter(tester).color, LoopColors.line3);
      final percent = tester.widget<Text>(_key('market-trend-percent'));
      expect(percent.data, '0.00%');
      expect(percent.style!.color, isNot(LoopColors.rise));
      expect(percent.style!.color, isNot(LoopColors.fall));
      expect(find.bySemanticsLabel(RegExp('24 小时走势持平 0.00%')), findsOneWidget);
    });

    testWidgets('no series: percent only, same width and right edge', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        Column(
          children: <Widget>[
            _trendRow(
              symbol: 'LOOP',
              closes: _d(<String>['1', '2']),
              change: '184',
            ),
            _trendRow(symbol: 'MCAT', change: '184'),
          ],
        ),
      );
      expect(_key('market-trend-line'), findsOneWidget);
      final columns = _key('market-trend-column');
      expect(columns, findsNWidgets(2));
      expect(tester.getSize(columns.at(1)).width, 96);
      expect(tester.getTopRight(columns.at(0)).dx, 370);
      expect(tester.getTopRight(columns.at(1)).dx, 370);
      final percents = _key('market-trend-percent');
      // Same right edge, and the same height inside its own 80 row.
      expect(
        tester.getBottomRight(percents.at(0)) + const Offset(0, 80),
        tester.getBottomRight(percents.at(1)),
      );
      expect(
        find.bySemanticsLabel(RegExp(r'24 小时涨跌 \+184.00%')),
        findsOneWidget,
      );
    });

    testWidgets('an unreported move prints 未报告 and no colour', (tester) async {
      await _pumpRow(tester, _trendRow(change: null));
      expect(find.text('未报告'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('24 小时涨跌未报告')), findsOneWidget);
    });

    testWidgets('with motion the line draws in, then settles whole', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        _trendRow(closes: _d(<String>['1', '2', '3'])),
        reduceMotion: false,
      );
      expect(_painter(tester).progress, lessThan(1));
      await tester.pumpAndSettle();
      expect(_painter(tester).progress, 1);
    });

    for (final width in <double>[390, 320]) {
      testWidgets('$width wide: a long name ends in an ellipsis, no overflow', (
        tester,
      ) async {
        await _pumpRow(
          tester,
          _trendRow(
            symbol: 'WORLDLIBERTYFINANCIALUSD',
            subtitle: 'World Liberty Financial USD Stable Coin',
            price: '0.000005601',
            change: '-12345.67',
            closes: _d(<String>['3', '2', '1']),
          ),
          width: width,
        );
        expect(tester.takeException(), isNull);
        final title = tester.widget<Text>(
          find.text('WORLDLIBERTYFINANCIALUSD'),
        );
        expect(title.overflow, TextOverflow.ellipsis);
        expect(tester.getTopRight(_key('market-trend-column')).dx, width - 20);
        if (width == 390) {
          // The name column keeps its 112 on a 390 phone.
          expect(
            tester.getSize(find.text('WORLDLIBERTYFINANCIALUSD')).width,
            greaterThanOrEqualTo(112),
          );
        }
      });
    }
  });

  group('only the 情报 · 行情 list draws the trend column', () {
    testWidgets('a category row in the market list draws it', (tester) async {
      final market = FakeMarketReadGateway(
        categories: <MarketCategory, S5Answer<MarketCategoryPage>>{
          MarketCategory.major: S5Answer<MarketCategoryPage>(
            value: s5CategoryPage(
              items: <MarketCategoryRow>[
                MarketCategoryRow(
                  assetId: s5WbnbAssetId,
                  symbol: 'WBNB',
                  name: 'Wrapped BNB',
                  logoUrl: null,
                  quote: s5CategoryRow().quote,
                  quoteUnavailableReason: null,
                  sparkline: null,
                  sparkline24h: _d(<String>['700', '720', '747.39']),
                ),
              ],
            ),
          ),
        },
      );
      await pumpS5Page(
        tester,
        const MarketScreen(embedded: true),
        market: market,
      );
      await tester.tap(find.text('主流'));
      await tester.pumpAndSettle();
      final row = _key('market-asset-$s5WbnbAssetId');
      expect(
        find.descendant(of: row, matching: _key('market-trend-line')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: _key('loop-change-pill')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the default row (MEME list and others) keeps its pill', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        MarketFomoRow.category(
          s5CategoryRow(),
          key: const ValueKey<String>('meme-row'),
        ),
      );
      expect(_key('loop-change-pill'), findsOneWidget);
      expect(_key('market-trend-column'), findsNothing);
    });
  });
}
