import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/spot_candle_chart.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';

void main() {
  testWidgets('projects fractional exact candles and exposes chart semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await _pumpChart(
      tester,
      candles: <HyperliquidSpotCandle>[
        _candle(
          open: '0.000123456789',
          high: '0.000129999999',
          low: '0.000120000001',
          close: '0.000128765432',
        ),
        _candle(
          index: 1,
          open: '0.000128765432',
          high: '0.000130000001',
          low: '0.000119999999',
          close: '0.000121234567',
        ),
      ],
      semanticLabel: 'PURR/USDC 1H real Testnet candle chart',
    );

    expect(find.byType(SpotCandleChart), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('spot-candle-chart-canvas')),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(
            find.byKey(const ValueKey<String>('spot-candle-chart-semantics')),
          )
          .label,
      'PURR/USDC 1H real Testnet candle chart',
    );
    expect(
      find.byKey(const ValueKey<String>('spot-candle-chart-canvas')),
      paints
        ..line()
        ..rrect()
        ..line()
        ..rrect(),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('keeps a flat candle visible at 390px and 200 percent text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await _pumpChart(
      tester,
      candles: <HyperliquidSpotCandle>[
        _candle(
          open: '12345.67890123456789',
          high: '12345.67890123456789',
          low: '12345.67890123456789',
          close: '12345.67890123456789',
        ),
      ],
      semanticLabel: 'Flat exact candle',
      textScaler: const TextScaler.linear(2),
    );

    expect(
      find.byKey(const ValueKey<String>('spot-candle-chart-boundary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('spot-candle-chart-canvas')),
      paints
        ..line()
        ..rrect(),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('projects missing candle intervals as a visible time-axis gap', (
    tester,
  ) async {
    await _pumpChart(
      tester,
      candles: <HyperliquidSpotCandle>[
        _candle(open: '1', high: '2', low: '0', close: '1'),
        _candle(index: 1, open: '1', high: '2', low: '0', close: '1'),
        _candle(index: 4, open: '1', high: '2', low: '0', close: '1'),
      ],
      semanticLabel: 'Candles with a three-hour gap',
    );

    final pattern = paints;
    for (var index = 0; index < 11; index++) {
      pattern.line();
    }
    pattern
      ..line(p1: const Offset(10, 8), p2: const Offset(10, 212))
      ..rrect()
      ..line(p1: const Offset(197, 8), p2: const Offset(197, 212))
      ..rrect()
      ..line(p1: const Offset(758, 8), p2: const Offset(758, 212))
      ..rrect();

    expect(
      find.byKey(const ValueKey<String>('spot-candle-chart-canvas')),
      pattern,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps a lowest-price doji body inside the plot', (tester) async {
    await _pumpChart(
      tester,
      candles: <HyperliquidSpotCandle>[
        _candle(open: '1', high: '1', low: '1', close: '1'),
        _candle(index: 1, open: '2', high: '3', low: '2', close: '3'),
      ],
      semanticLabel: 'Doji at the visible low',
    );

    expect(
      find.byKey(const ValueKey<String>('spot-candle-chart-canvas')),
      paints..rrect(
        rrect: RRect.fromRectAndRadius(
          const Rect.fromLTRB(6, 209.75, 14, 212),
          const Radius.circular(1.25),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpChart(
  WidgetTester tester, {
  required List<HyperliquidSpotCandle> candles,
  required String semanticLabel,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SpotCandleChart(
            candles: candles,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

HyperliquidSpotCandle _candle({
  required String open,
  required String high,
  required String low,
  required String close,
  int index = 0,
}) {
  final openTime = DateTime.utc(2026, 8, 26, index);
  return HyperliquidSpotCandle(
    openTime: openTime,
    closeTime: openTime.add(const Duration(hours: 1)),
    providerCoin: '@1035',
    interval: HyperliquidSpotCandleInterval.oneHour,
    open: _exact(open),
    high: _exact(high),
    low: _exact(low),
    close: _exact(close),
    volume: _exact('123.45000000000001'),
    tradeCount: 7,
  );
}

HyperliquidSpotDecimal _exact(String source) {
  return HyperliquidSpotDecimal(source: source, value: Decimal.parse(source));
}
