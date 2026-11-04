// S345 · decision 0273 (docs/56 §二 MEME): the MEME v2 desk has no 战绩, and
// the project page and the curve token page carry the market token detail's
// chart rows — K线 / MA / VOL above the plot, the periods and the full-screen
// glyph under it — and open `chart-full` for their own series.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_models.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_full_chart_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
import 'package:loop_mobile/features/meme/meme_design.dart';
import 'package:loop_mobile/features/meme/meme_routes.dart';
import 'package:loop_mobile/features/meme/meme_token_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/meme_fixtures.dart';
import 'support/s345_charts.dart';
import 'support/s7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

LoopMarketChart _chart(WidgetTester tester) =>
    tester.widget<LoopMarketChart>(find.byType(LoopMarketChart));

/// The four controls every chart block carries, in the market's order.
void _expectToolbar(WidgetTester tester, String prefix, String expandKey) {
  final style = _key('$prefix-chart-style');
  final ma = _key('$prefix-chart-ma');
  final vol = _key('$prefix-chart-vol');
  final expand = _key(expandKey);
  for (final finder in <Finder>[style, ma, vol, expand]) {
    expect(finder, findsOneWidget);
  }
  // K线 · MA · VOL on one line above the plot, left to right.
  final plot = tester.getRect(find.byType(LoopMarketChart));
  expect(tester.getRect(style).bottom, lessThanOrEqualTo(plot.top));
  expect(tester.getCenter(style).dy, tester.getCenter(ma).dy);
  expect(tester.getCenter(ma).dy, tester.getCenter(vol).dy);
  expect(tester.getCenter(style).dx, lessThan(tester.getCenter(ma).dx));
  expect(tester.getCenter(ma).dx, lessThan(tester.getCenter(vol).dx));
  // The full-screen glyph ends the period row under the plot.
  expect(tester.getRect(expand).top, greaterThanOrEqualTo(plot.bottom));
  // Same faces and sizes as the market's own toolbar.
  for (final (finder, label) in <(Finder, String)>[
    (style, 'Candles'),
    (ma, 'MA'),
    (vol, 'VOL'),
  ]) {
    expect(
      find.descendant(of: finder, matching: find.text(label)),
      findsOneWidget,
    );
    expect(
      tester
          .widget<LoopSeg>(
            find.descendant(of: finder, matching: find.byType(LoopSeg)),
          )
          .quiet,
      isTrue,
    );
  }
}

void main() {
  loopWatchGround();

  group('desk · 战绩 is gone', () {
    testWidgets('figures read, none drawn: no heading, (i) or grid', (
      tester,
    ) async {
      final gateway = S345Launch2(
        s345Public(),
        page: l2Page(<Map<String, Object?>>[l2RowJson(stage: 'public')]),
      );
      await pumpS7Page(
        tester,
        Scaffold(
          body: Launch2ListSegment(
            scope: Launch2ListScope.all,
            onNavigate: (_) {},
          ),
        ),
        meta: s345Meta(),
        overrides: [
          launch2GatewayProvider.overrideWithValue(gateway),
          launch2OverviewGatewayProvider.overrideWithValue(S345Overview()),
          launch2ClockProvider.overrideWithValue(() => l2Now),
          loopFeatureSwitchesProvider.overrideWithValue(
            const LoopFeatureSwitchValues(launch2Visible: true),
          ),
        ],
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text('战绩'), findsNothing);
      expect(_key('launch2-stats'), findsNothing);
      expect(_key('launch2-stats-heading'), findsNothing);
      expect(_key('launch2-stats-source'), findsNothing);
      expect(find.byType(MemeStatFigures), findsNothing);
      for (final label in <String>['本周毕业', '累计回购', '勋章已铸', '进行中']) {
        expect(find.text(label), findsNothing, reason: label);
      }
      expect(_key('launch2-list-all-provenance'), findsOneWidget);
      await drainS345(tester);
    });
  });

  group('launch2-instance · the market chart rows', () {
    testWidgets('K线 · MA · VOL above, six periods and 全屏 under', (
      tester,
    ) async {
      final gateway = S345Launch2(s345Public());
      await pumpS345Router(
        tester,
        initial: Launch2Route.instance(l2InstanceA),
        launch2: gateway,
      );
      _expectToolbar(tester, 'launch2-candles', 'launch2-candles-expand');
      for (final interval in Launch2CandleInterval.values) {
        expect(
          find.descendant(
            of: _key('launch2-candles-intervals'),
            matching: find.text(interval.label),
          ),
          findsOneWidget,
        );
      }
      // The market's defaults: a line, MA off, VOL on, the latest price on
      // the axis.
      final chart = _chart(tester);
      expect(chart.style, LoopChartStyle.line);
      expect(chart.showMovingAverages, isFalse);
      expect(chart.showVolume, isTrue);
      expect(chart.lastPriceTag, isFalse);
      expect(chart.candles.last.volume.toString(), isNot('0'));
      // MA off: no figures line at all.
      expect(_key('launch2-candles-moving-averages'), findsNothing);
      await drainS345(tester);
    });

    testWidgets('K线, MA and VOL switch the shared chart', (tester) async {
      await pumpS345Router(
        tester,
        initial: Launch2Route.instance(l2InstanceA),
        launch2: S345Launch2(s345Public()),
      );
      await tester.tap(_key('launch2-candles-chart-style'));
      await tester.pumpAndSettle();
      expect(_chart(tester).style, LoopChartStyle.candles);
      expect(find.text('Line'), findsOneWidget);

      await tester.tap(_key('launch2-candles-chart-ma'));
      await tester.pumpAndSettle();
      expect(_chart(tester).showMovingAverages, isTrue);
      final averages = tester
          .widget<Text>(_key('launch2-candles-moving-averages'))
          .data!;
      expect(averages, startsWith('MA7 '));
      expect(averages, contains('MA25 '));
      // Its own line under the switches, in `meta`, never cut short.
      final figures = _key('launch2-candles-moving-averages');
      final text = tester.widget<Text>(figures);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      expect(text.style, LoopType.meta);
      expect(
        tester.getRect(figures).top,
        greaterThanOrEqualTo(
          tester.getRect(_key('launch2-candles-chart-ma')).bottom,
        ),
      );
      expect(
        tester.getRect(figures).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(LoopMarketChart)).top),
      );
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: figures, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);

      await tester.tap(_key('launch2-candles-chart-vol'));
      await tester.pumpAndSettle();
      expect(_chart(tester).showVolume, isFalse);
      await tester.tap(_key('launch2-candles-chart-vol'));
      await tester.pumpAndSettle();
      expect(_chart(tester).showVolume, isTrue);
      await drainS345(tester);
    });

    testWidgets('graduated: the 毕业 rule stays, in both styles', (tester) async {
      await pumpS345Router(
        tester,
        initial: Launch2Route.instance(l2InstanceA),
        launch2: S345Launch2(s345Graduated()),
      );
      expect(_key('launch2-candles-graduation'), findsOneWidget);
      expect(_chart(tester).onReachStart, isNotNull);
      await tester.tap(_key('launch2-candles-chart-style'));
      await tester.pumpAndSettle();
      expect(_key('launch2-candles-graduation'), findsOneWidget);
      await drainS345(tester);
    });

    testWidgets('全屏 opens chart-full for the project and comes back', (
      tester,
    ) async {
      final gateway = S345Launch2(s345Graduated());
      final router = await pumpS345Router(
        tester,
        initial: Launch2Route.instance(l2InstanceA),
        launch2: gateway,
        size: const Size(390, 844),
      );
      await tester.ensureVisible(_key('launch2-candles-expand'));
      await tester.pumpAndSettle();
      await tester.tap(_key('launch2-candles-expand'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/market/chart?launch2=$l2InstanceA');
      expect(find.byType(Launch2FullChartScreen), findsOneWidget);
      // The page is the chart: the toolbar, a tall plot, the 毕业 rule, and
      // no glyph to open itself again.
      expect(_key('launch2-candles-chart-style'), findsOneWidget);
      expect(_key('launch2-candles-chart-vol'), findsOneWidget);
      expect(_key('launch2-candles-expand'), findsNothing);
      expect(_key('launch2-candles-graduation'), findsOneWidget);
      expect(
        tester.getSize(find.byType(LoopMarketChart)).height,
        greaterThan(400),
      );
      await tester.tap(_key('loop-topbar-back'));
      await tester.pumpAndSettle();
      expect(find.byType(Launch2FullChartScreen), findsNothing);
      expect(_key('launch2-candles-expand'), findsOneWidget);
      await drainS345(tester);
    });

    testWidgets('a malformed project chart fails closed', (tester) async {
      await pumpS345Router(
        tester,
        initial: '/market/chart?launch2=nope',
        launch2: S345Launch2(s345Public()),
      );
      expect(_key('launch2-chart-full-invalid-identity'), findsOneWidget);
      expect(find.byType(LoopMarketChart), findsNothing);
      await drainS345(tester);
    });
  });

  group('period row · six periods and 全屏 on one line', () {
    /// Every period's word is drawn whole, inside the screen, left of the
    /// full-screen glyph, and the row does not scroll.
    void expectWhole(
      WidgetTester tester,
      String rowKey,
      List<String> labels,
      String expandKey,
      double width,
    ) {
      final row = _key(rowKey);
      expect(
        find.descendant(of: row, matching: find.byType(Scrollable)),
        findsNothing,
      );
      final expand = tester.getRect(_key(expandKey));
      expect(expand.right, lessThanOrEqualTo(width));
      for (final label in labels) {
        final word = find.descendant(of: row, matching: find.text(label));
        expect(word, findsOneWidget, reason: label);
        final rect = tester.getRect(word);
        expect(rect.left, greaterThanOrEqualTo(0), reason: label);
        expect(rect.right, lessThanOrEqualTo(expand.left), reason: label);
        // Drawn at its own size: the fit never had to shrink it.
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: word, matching: find.byType(RichText)),
        );
        expect(rect.width, closeTo(paragraph.size.width, 0.5), reason: label);
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
      final first = tester.getRect(find.byKey(ValueKey<String>(rowKey)));
      expect(first.right, lessThanOrEqualTo(expand.left + 0.5));
    }

    for (final width in <double>[360, 390]) {
      testWidgets('launch2-instance at $width', (tester) async {
        // The App's own faces: the test font draws every glyph a full em.
        await tester.runAsync(loopLoadShotFonts);
        await pumpS345Router(
          tester,
          initial: Launch2Route.instance(l2InstanceA),
          launch2: S345Launch2(s345Public()),
          size: Size(width, 2000),
        );
        expectWhole(
          tester,
          'launch2-candles-intervals',
          <String>[for (final i in Launch2CandleInterval.values) i.label],
          'launch2-candles-expand',
          width,
        );
        // Each period keeps a finger-sized target.
        for (final i in Launch2CandleInterval.values) {
          final size = tester.getSize(
            _key('launch2-candles-interval-${i.wireName}'),
          );
          expect(size.width, greaterThanOrEqualTo(44));
          expect(size.height, greaterThanOrEqualTo(44));
        }
        expect(tester.takeException(), isNull);
        await drainS345(tester);
      });

      testWidgets('meme-token at $width', (tester) async {
        // The App's own faces: the test font draws every glyph a full em.
        await tester.runAsync(loopLoadShotFonts);
        await pumpS345Router(
          tester,
          initial: MemeRoute.token(memeTokenIdA),
          meme: S345Meme(memeDetail()),
          size: Size(width, 2000),
        );
        expectWhole(
          tester,
          'meme-interval-strip',
          <String>[for (final (_, label) in memeChartRanges) label],
          'meme-chart-expand',
          width,
        );
        expect(tester.takeException(), isNull);
        await drainS345(tester);
      });
    }
  });

  group('chart-full · a project\'s five states', () {
    final location = Launch2Route.chart(l2InstanceA);

    testWidgets('loading: the chart skeleton, no plot', (tester) async {
      await pumpS345Router(
        tester,
        initial: location,
        launch2: S345Launch2(s345Public(), detailPending: true),
        settle: false,
      );
      expect(_key('launch2-chart-full-state-loading'), findsOneWidget);
      expect(find.byType(LoopMarketChart), findsNothing);
      await drainS345(tester);
    });

    testWidgets('empty: no trade yet, no plot', (tester) async {
      await pumpS345Router(
        tester,
        initial: location,
        launch2: S345Launch2(s345Public(), noCandles: true),
      );
      expect(_key('launch2-candles-empty'), findsOneWidget);
      expect(find.byType(LoopMarketChart), findsNothing);
      await drainS345(tester);
    });

    testWidgets('error: the read failed, a retry', (tester) async {
      await pumpS345Router(
        tester,
        initial: location,
        launch2: S345Launch2(
          s345Public(),
          detailFailure: LoopChainFailureKind.readFailed,
        ),
      );
      expect(_key('launch2-chart-full-state-error'), findsOneWidget);
      expect(find.byType(LoopMarketChart), findsNothing);
      await drainS345(tester);
    });

    testWidgets('offline: said as offline, nothing drawn', (tester) async {
      await pumpS345Router(
        tester,
        initial: location,
        launch2: S345Launch2(
          s345Public(),
          detailFailure: LoopChainFailureKind.offline,
        ),
      );
      expect(_key('launch2-chart-full-state-offline'), findsOneWidget);
      expect(find.byType(LoopMarketChart), findsNothing);
      await drainS345(tester);
    });

    testWidgets('permission: a closed launch2 capability blocks the page', (
      tester,
    ) async {
      final gateway = S345Launch2(s345Public());
      await pumpS345Router(
        tester,
        initial: location,
        launch2: gateway,
        launch2Open: false,
      );
      expect(_key('launch2-chart-full-capability-block'), findsOneWidget);
      expect(find.byType(LoopMarketChart), findsNothing);
      expect(gateway.candleCalls, isEmpty);
      await drainS345(tester);
    });
  });

  group('meme-token · the market chart rows', () {
    testWidgets('toolbar, MA / VOL switches, 全屏 in and out', (tester) async {
      final router = await pumpS345Router(
        tester,
        initial: MemeRoute.token(memeTokenIdA),
        meme: S345Meme(memeDetail()),
        size: const Size(390, 844),
      );
      _expectToolbar(tester, 'meme', 'meme-chart-expand');
      for (final (_, label) in memeChartRanges) {
        expect(
          find.descendant(
            of: _key('meme-interval-strip'),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      expect(_chart(tester).showVolume, isTrue);
      await tester.tap(_key('meme-chart-ma'));
      await tester.pumpAndSettle();
      expect(_chart(tester).showMovingAverages, isTrue);
      await tester.tap(_key('meme-chart-vol'));
      await tester.pumpAndSettle();
      expect(_chart(tester).showVolume, isFalse);

      await tester.ensureVisible(_key('meme-chart-expand'));
      await tester.pumpAndSettle();
      await tester.tap(_key('meme-chart-expand'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/market/chart?meme=$memeTokenIdA');
      expect(find.byType(MemeFullChartScreen), findsOneWidget);
      expect(_key('meme-chart-expand'), findsNothing);
      expect(_key('meme-chart-style'), findsOneWidget);
      await tester.tap(_key('loop-topbar-back'));
      await tester.pumpAndSettle();
      expect(find.byType(MemeFullChartScreen), findsNothing);
      expect(_key('meme-chart-expand'), findsOneWidget);
      await drainS345(tester);
    });
  });

  test('chart-full locations', () {
    expect(
      Launch2Route.chart(l2InstanceA),
      '/market/chart?launch2=$l2InstanceA',
    );
    expect(
      Launch2Route.chartIdOf(Uri.parse(Launch2Route.chart(l2InstanceA))),
      l2InstanceA,
    );
    expect(
      Launch2Route.chartIdOf(Uri.parse('/market/chart?launch2=x')),
      isNull,
    );
    expect(MemeRoute.chart(memeTokenIdA), '/market/chart?meme=$memeTokenIdA');
    expect(
      MemeRoute.chartIdOf(Uri.parse(MemeRoute.chart(memeTokenIdA))),
      memeTokenIdA,
    );
    expect(Launch2Route.isChart(Uri.parse('/market/chart?assetId=x')), isFalse);
    expect(MemeRoute.isChart(Uri.parse('/market/chart?assetId=x')), isFalse);
  });
}
