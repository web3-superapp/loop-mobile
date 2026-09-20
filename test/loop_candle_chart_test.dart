import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';

LoopCandle _candle({
  required int hour,
  required String open,
  required String close,
  String? high,
  String? low,
  bool isOpen = false,
}) => LoopCandle(
  openTime: DateTime.utc(2026, 9, 8, hour),
  closeTime: DateTime.utc(2026, 9, 8, hour + 1),
  open: Decimal.parse(open),
  high: Decimal.parse(high ?? close),
  low: Decimal.parse(low ?? open),
  close: Decimal.parse(close),
  volume: Decimal.parse('1'),
  swapCount: 3,
  isOpen: isOpen,
);

Future<void> _pump(
  WidgetTester tester,
  List<LoopCandle> candles, {
  String label = 'candles',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 220,
          child: LoopCandleChart(candles: candles, semanticLabel: label),
        ),
      ),
    ),
  );
}

void main() {
  group('LoopCandleChart', () {
    testWidgets('renders exactly one painted canvas', (tester) async {
      await _pump(tester, <LoopCandle>[
        _candle(hour: 1, open: '10', close: '12'),
        _candle(hour: 2, open: '12', close: '11'),
      ]);

      expect(
        find.byKey(const ValueKey<String>('loop-candle-chart-canvas')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-candle-chart-boundary')),
        findsOneWidget,
      );
    });

    testWidgets('announces the series through one semantic label', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, <LoopCandle>[
        _candle(hour: 1, open: '10', close: '12'),
      ], label: '2 根 K 线，单位 USDT per WBNB，最后一根尚未收盘');

      expect(
        find.bySemanticsLabel('2 根 K 线，单位 USDT per WBNB，最后一根尚未收盘'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('an empty series paints nothing and does not throw', (
      tester,
    ) async {
      await _pump(tester, const <LoopCandle>[]);

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey<String>('loop-candle-chart-canvas')),
        findsOneWidget,
      );
    });

    testWidgets('a flat series does not divide by a zero price span', (
      tester,
    ) async {
      await _pump(tester, <LoopCandle>[
        _candle(hour: 1, open: '10', close: '10', high: '10', low: '10'),
        _candle(hour: 2, open: '10', close: '10', high: '10', low: '10'),
      ]);

      expect(tester.takeException(), isNull);
    });

    testWidgets('an open bucket repaints when its close moves', (tester) async {
      final first = <LoopCandle>[
        _candle(hour: 1, open: '10', close: '12', high: '13', low: '9'),
        _candle(
          hour: 2,
          open: '12',
          close: '13',
          high: '14',
          low: '11',
          isOpen: true,
        ),
      ];
      await _pump(tester, first);

      final moved = <LoopCandle>[
        first.first,
        _candle(
          hour: 2,
          open: '12',
          close: '9',
          high: '14',
          low: '8',
          isOpen: true,
        ),
      ];
      await _pump(tester, moved);

      expect(tester.takeException(), isNull);
    });
  });

  group('candle model', () {
    test('direction comes from the exact Decimal comparison', () {
      final up = _candle(hour: 1, open: '0.0000078', close: '0.0000082');
      final down = _candle(hour: 1, open: '0.0000082', close: '0.0000078');
      final flat = _candle(hour: 1, open: '0.0000080', close: '0.0000080');

      expect(up.isUp, isTrue);
      expect(up.isDown, isFalse);
      expect(down.isDown, isTrue);
      expect(flat.isUp, isFalse);
      expect(flat.isDown, isFalse);
    });

    test('a value survives a precision a double would lose', () {
      final candle = _candle(
        hour: 1,
        open: '747.482453211647133359',
        close: '747.482453211647133360',
      );

      expect(candle.open.toString(), '747.482453211647133359');
      expect(candle.isUp, isTrue);
      // The same comparison collapses to equality in binary floating point.
      expect(
        double.parse('747.482453211647133359') ==
            double.parse('747.482453211647133360'),
        isTrue,
      );
    });
  });

  group('display formatting', () {
    test('groups the integer part and trims trailing zeros', () {
      expect(loopFormatDecimal(Decimal.parse('1234567.8900')), '1,234,567.89');
      expect(loopFormatDecimal(Decimal.parse('7.000')), '7');
      expect(loopFormatDecimal(Decimal.parse('0.005')), '0.005');
    });

    test('keeps the sign and never invents one', () {
      expect(loopFormatPercent(Decimal.parse('-3.2')), '-3.2%');
      expect(loopFormatPercent(Decimal.parse('0.27')), '+0.27%');
      expect(loopFormatUsd(Decimal.parse('747.39')), r'$747.39');
    });

    test('a quality marker exists for every non-fresh quality', () {
      expect(loopFactQualityMarker(LoopFactQuality.fresh), isNull);
      expect(loopFactQualityMarker(LoopFactQuality.stale), '数据可能过期');
      expect(loopFactQualityMarker(LoopFactQuality.derived), '按成交价折算');
      expect(loopFactQualityMarker(LoopFactQuality.proxied), '以 WBNB 计价');
    });

    test('a summary figure switches to K/M/B/T at 100,000', () {
      // Below the threshold the whole figure fits in the cell's seven
      // characters, so it is kept — without the cents, which do not.
      expect(loopFormatCompactFigure(Decimal.parse('99999')), r'$99,999');
      expect(loopFormatCompactFigure(Decimal.parse('8200')), r'$8,200');
      expect(loopFormatCompactFigure(Decimal.parse('42750.31')), r'$42,750');
      expect(loopFormatCompactFigure(Decimal.parse('99999.4')), r'$99,999');
      expect(
        loopFormatCompactFigure(Decimal.parse('99999'), usd: false),
        '99,999',
      );
      // At it, and above, the magnitude replaces the digits.
      expect(loopFormatCompactFigure(Decimal.parse('100000')), r'$100K');
      expect(
        loopFormatCompactFigure(Decimal.parse('100000'), usd: false),
        '100K',
      );
      // The branch is decided after rounding: these two print as `100,000`,
      // which is one character too wide for the cell.
      expect(loopFormatCompactFigure(Decimal.parse('99999.5')), r'$100K');
      expect(loopFormatCompactFigure(Decimal.parse('99999.995')), r'$100K');
    });

    test('a sub-dollar price keeps three significant digits when asked', () {
      // 「<$1」 is true of every launchpad pool and tells the reader nothing:
      // these trade at 1e-6. The slot that has the width prints the figure.
      expect(
        loopFormatCompactFigure(
          Decimal.parse('0.0000012345'),
          preciseBelowOne: true,
        ),
        r'$0.00000123',
      );
      expect(
        loopFormatCompactFigure(Decimal.parse('0.0041'), preciseBelowOne: true),
        r'$0.0041',
      );
      expect(
        loopFormatCompactFigure(
          Decimal.parse('0.874321'),
          preciseBelowOne: true,
        ),
        r'$0.874',
      );
      expect(
        loopFormatCompactFigure(
          Decimal.parse('-0.0000012345'),
          preciseBelowOne: true,
        ),
        r'$-0.00000123',
      );
      expect(
        loopFormatCompactFigure(
          Decimal.parse('0.0041'),
          usd: false,
          preciseBelowOne: true,
        ),
        '0.0041',
      );
      // A dollar and over is exactly the summary form, and an exact zero is
      // still the fact it always was.
      expect(
        loopFormatCompactFigure(
          Decimal.parse('42800000'),
          preciseBelowOne: true,
        ),
        r'$42.8M',
      );
      expect(
        loopFormatCompactFigure(Decimal.zero, preciseBelowOne: true),
        r'$0',
      );
      // Smaller than the deepest form this prints is still bounded, and the
      // bound says how small instead of 「<$1」.
      expect(
        loopFormatCompactFigure(
          Decimal.parse('0.0000000000000000000001'),
          preciseBelowOne: true,
        ),
        r'<$0.000000000000000001',
      );
    });

    test('a value under one dollar is bounded, never rounded to zero', () {
      // `$0` liquidity reads as a pulled pool. This value is not zero.
      expect(loopFormatCompactFigure(Decimal.parse('0.004')), r'<$1');
      expect(loopFormatCompactFigure(Decimal.parse('0.49')), r'<$1');
      expect(loopFormatCompactFigure(Decimal.parse('0.004'), usd: false), '<1');
      expect(loopFormatCompactFigure(Decimal.parse('-0.004')), r'>-$1');
      expect(
        loopFormatCompactFigure(Decimal.parse('-0.004'), usd: false),
        '>-1',
      );
      // Half away from zero, so this one is a dollar and says so.
      expect(loopFormatCompactFigure(Decimal.parse('0.5')), r'$1');
      // An exact zero is a fact and prints as one.
      expect(loopFormatCompactFigure(Decimal.zero), r'$0');
      expect(loopFormatCompactFigure(Decimal.zero, usd: false), '0');
    });

    test('a summary figure keeps one decimal and drops a trailing zero', () {
      expect(loopFormatCompactFigure(Decimal.parse('142000')), r'$142K');
      expect(loopFormatCompactFigure(Decimal.parse('2400000')), r'$2.4M');
      expect(loopFormatCompactFigure(Decimal.parse('42750000')), r'$42.8M');
      // Half away from zero, not half to even: this one is `.7`, not `.6`.
      expect(loopFormatCompactFigure(Decimal.parse('42650000')), r'$42.7M');
      expect(loopFormatCompactFigure(Decimal.parse('5400000000')), r'$5.4B');
      expect(loopFormatCompactFigure(Decimal.parse('5412003118.24')), r'$5.4B');
      expect(loopFormatCompactFigure(Decimal.parse('1500000000000')), r'$1.5T');
      expect(
        loopFormatCompactFigure(Decimal.parse('418000'), usd: false),
        '418K',
      );
      expect(
        loopFormatCompactFigure(Decimal.parse('8019338'), usd: false),
        '8M',
      );
    });

    test('a summary figure carries into the next unit instead of 1000K', () {
      expect(loopFormatCompactFigure(Decimal.parse('999950')), r'$1M');
      expect(loopFormatCompactFigure(Decimal.parse('999999999')), r'$1B');
      expect(loopFormatCompactFigure(Decimal.parse('999949')), r'$999.9K');
    });

    test('a summary figure keeps the sign where a USD figure keeps it', () {
      expect(loopFormatCompactFigure(Decimal.parse('-2400000')), r'$-2.4M');
      expect(
        loopFormatCompactFigure(Decimal.parse('-2400000'), usd: false),
        '-2.4M',
      );
      expect(loopFormatCompactFigure(Decimal.parse('-8200')), r'$-8,200');
    });

    test('a summary slot names the gap instead of explaining it', () {
      // Two phrases only: one for a value still on its way, one for the rest.
      expect(
        loopReasonCodeSummaryText('BSC_CHAIN_VERIFICATION_PENDING'),
        '等待数据',
      );
      expect(loopReasonCodeSummaryText('INDEXING_DELAYED'), '等待数据');
      expect(loopReasonCodeSummaryText('MARKET_FACT_NOT_REPORTED'), '未报告');
      expect(
        loopReasonCodeSummaryText('MARKET_PROVIDER_RATE_LIMITED'),
        '数据不可得',
      );
      expect(loopReasonCodeSummaryText('SOMETHING_NEW'), '数据不可得');
      expect(loopReasonCodeSummaryText(null), '数据不可得');
      // Every code a market fact can carry lands on the second phrase; the
      // first one is not reached from a Token Card at all.
      expect(
        loopReasonCodeSummaryText('MARKET_PROVIDER_REQUEST_REJECTED'),
        '数据不可得',
      );
      expect(
        loopReasonCodeSummaryText('MARKET_FACT_CACHE_UNAVAILABLE'),
        '数据不可得',
      );
      // The full sentence is unchanged; only the summary slot is short.
      expect(loopReasonCodeText('MARKET_FACT_NOT_REPORTED'), '数据源没有报告这一项。');
    });

    test('the summary formatter is confined to the Token Card', () {
      // `loopFormatCompactFigure` rounds a figure away. That is right for a
      // 94pt cell and wrong everywhere a number is the commitment — an amount
      // being signed, a balance, a fee. `chain_widgets.dart` is imported all
      // over the money surfaces, so the function is pinned to the screens
      // that are allowed to summarise: the Token Card's metric cells, and the
      // new-pairs rows, whose trailing column is the same kind of slot and
      // whose sub-cent pools otherwise printed 「$0」. The community record
      // carries the same Token Card, reading the same market fact into the
      // same three cells, so it summarises on the same terms.
      const allowed = <String>{
        'lib/features/chain/chain_widgets.dart',
        'lib/features/community/community_profile_screen.dart',
        'lib/features/market/market_secondary_screens.dart',
        'lib/features/market/token_screen.dart',
        // The same Token Card, under a chat bubble: the same three metric
        // cells, and nothing a member is committing to.
        'lib/features/chat/token_card/chat_token_card.dart',
      };
      final callers = <String>{};
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (!file.readAsStringSync().contains('loopFormatCompactFigure')) {
          continue;
        }
        callers.add(file.path);
      }
      expect(callers, allowed);
    });

    test('an unknown reason code keeps a neutral sentence', () {
      expect(loopReasonCodeText('SOMETHING_NEW'), '这一项暂时读不到。');
      expect(loopReasonCodeText(null), '这一项暂时读不到。');
      expect(
        loopReasonCodeText('BSC_CHAIN_ID_MISMATCH'),
        contains('不是 BNB Smart Chain'),
      );
      // Two codes the market service emits that the table used to miss, so
      // the fact list fell back to the neutral sentence for both.
      expect(
        loopReasonCodeText('MARKET_PROVIDER_REQUEST_REJECTED'),
        '数据服务拒绝了这次请求，与你的网络无关，稍后再看。',
      );
      expect(
        loopReasonCodeText('MARKET_FACT_CACHE_UNAVAILABLE'),
        '行情数据暂时读不到，这一项没有数值，稍后再看。',
      );
    });
  });
}
