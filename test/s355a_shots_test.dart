// S355a · decision 0281: 360×800 English self-review renders of the launch2
// pages (MEME home desk, the project page at each stage, the trade sheet),
// to catch truncation, overflow and wrapping in the longer English copy.
//
// Not a check: it runs only with `--dart-define=LOOP_SHOTS=true` and writes
// to `LOOP_SHOTS_DIR`; a plain `flutter test` skips every case.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/launch2_fixtures.dart';
import 'support/launch2_trade_sheet.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s269_pages.dart';
import 'support/s285_page.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'build/s355a-shots',
);

const Size _phone = Size(360, 800);

Future<void> _shot(WidgetTester tester, String name) =>
    loopShot(tester, 's355a-$name', slice: 800, dir: _dir);

S285Launch2 _graduated() => S285Launch2(
  candleSource: 'pool',
  detail: l2Detail(
    stage: 'graduated',
    noNextChange: true,
    pool: l2PoolSummaryJson(),
    viewer: l2ViewerJson(holding: l2HoldingJson()),
  ),
  positions: s285Value(
    l2Positions(stage: 'graduated', holding: l2HoldingJson()),
  ),
);

void main() {
  loopWatchGround();

  for (final tab in <String>['live', 'upcoming', 'graduated']) {
    testWidgets('MEME home · $tab', skip: !_shots, (tester) async {
      await pumpS279MemeHome(tester, size: _phone);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump();
      final target = find.byKey(ValueKey<String>('launch2-desk-tab-$tab'));
      if (target.evaluate().isNotEmpty) {
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      await _shot(tester, 'meme-home-$tab');
      await drainS269(tester);
    });
  }

  for (final stage in <String>['upcoming', 'nft_sale', 'priority', 'public']) {
    testWidgets('project · $stage', skip: !_shots, (tester) async {
      await pumpS285Project(
        tester,
        launch2: S285Launch2(
          candleSource: 'curve',
          detail: l2Detail(
            stage: stage,
            viewer: l2ViewerJson(member: true, eligibleNow: true),
            trades: <Map<String, Object?>>[l2TradeJson()],
          ),
        ),
        size: _phone,
      );
      await _shot(tester, 'project-$stage');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await _shot(tester, 'project-$stage-lower');
      await drainS285(tester);
    });
  }

  for (final tab in <String>['trades', 'info']) {
    testWidgets('project · graduated · $tab', skip: !_shots, (tester) async {
      await pumpS285Project(
        tester,
        launch2: _graduated(),
        recent: S285RecentTrades(s285Value(s285SampleTrades())),
        size: _phone,
      );
      if (tab != 'trades') await l2OpenTab(tester, tab);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await _shot(tester, 'graduated-$tab');
      await drainS285(tester);
    });
  }

  testWidgets('project · graduated · buy sheet', skip: !_shots, (tester) async {
    await pumpS285Project(
      tester,
      launch2: _graduated(),
      recent: S285RecentTrades(s285Value(s285SampleTrades())),
      size: _phone,
    );
    await l2OpenTradeSheet(tester);
    await _shot(tester, 'graduated-buy-sheet');
    await drainS285(tester);
  });
}
