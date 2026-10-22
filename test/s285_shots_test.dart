// S285 · decision 0240: the self-review shots of the MEME v2 project page
// (需求方 2026-10-22 第 04 条): after graduation the 成交 and 信息 tabs, a
// curve-stage page and the 买入 sheet.
//
// Not a check: it writes 390-wide renders to docs/integration/S285/shots/
// (or `LOOP_SHOTS_DIR`). It runs only with `--dart-define=LOOP_SHOTS=true`;
// a plain `flutter test` skips every case and writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/launch2_fixtures.dart';
import 'support/launch2_trade_sheet.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s285_page.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'docs/integration/S285/shots',
);

const Size _phone = Size(390, 1500);

Future<void> _shot(WidgetTester tester, String name) =>
    loopShot(tester, name, slice: 1500, dir: _dir);

S285Launch2 _graduated() => S285Launch2(
  candleSource: 'pool',
  detail: l2Detail(
    stage: 'graduated',
    noNextChange: true,
    pool: l2PoolSummaryJson(),
    viewer: l2ViewerJson(
      holding: <String, Object?>{
        ...l2HoldingJson(),
        'avgCostUsd1': '0.0005',
        'costBasisUsd1': '3.66',
        'realizedPnlUsd1': '-0.5',
        'unrealizedPnlUsd1': '1.32',
        'costCoverage': 'partial',
      },
    ),
  ),
  positions: s285Value(
    l2Positions(
      stage: 'graduated',
      holding: l2HoldingJson(),
      extra: <String, Object?>{
        'priceUsd1': '0.00068',
        'valueUsd1': '4.98',
        'priceSource': 'pool',
      },
    ),
  ),
);

void main() {
  loopWatchGround();

  for (final tab in <String>['trades', 'info']) {
    testWidgets('graduated · $tab', skip: !_shots, (tester) async {
      await pumpS285Project(
        tester,
        launch2: _graduated(),
        recent: S285RecentTrades(s285Value(s285SampleTrades())),
        size: _phone,
      );
      if (tab != 'trades') await l2OpenTab(tester, tab);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await _shot(tester, 'graduated-$tab');
      await drainS285(tester);
    });
  }

  testWidgets('curve · public', skip: !_shots, (tester) async {
    await pumpS285Project(
      tester,
      launch2: S285Launch2(
        candleSource: 'curve',
        detail: l2Detail(
          stage: 'public',
          noNextChange: true,
          viewer: l2ViewerJson(
            member: true,
            eligibleNow: true,
            bought: '1125000.5',
            net: '1125000.5',
          ),
          trades: <Map<String, Object?>>[l2TradeJson()],
        ),
      ),
      size: _phone,
    );
    await _shot(tester, 'curve-public');
    await drainS285(tester);
  });

  testWidgets('graduated · 买入 sheet', skip: !_shots, (tester) async {
    await pumpS285Project(
      tester,
      launch2: _graduated(),
      recent: S285RecentTrades(s285Value(s285SampleTrades())),
      size: const Size(390, 844),
    );
    await l2OpenTradeSheet(tester);
    await _shot(tester, 'graduated-buy-sheet');
    await drainS285(tester);
  });
}
