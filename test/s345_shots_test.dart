// S345 · decision 0273: the self-review shots — the MEME home without 战绩,
// the project page's chart block with K / MA / VOL on, and its full-screen
// chart.
//
// Not a check: it writes 390-wide renders to `LOOP_SHOTS_DIR` (by default
// docs/integration/S345/shots). It runs only with
// `--dart-define=LOOP_SHOTS=true`; a plain `flutter test` skips every case
// and writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s345_charts.dart';
import 'support/s7_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'docs/integration/S345/shots',
);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Future<void> _shot(WidgetTester tester, String name) =>
    loopShot(tester, name, slice: 2400, dir: _dir);

void main() {
  loopWatchGround();

  testWidgets('MEME home', skip: !_shots, (tester) async {
    final rows = <Map<String, Object?>>[
      l2RowJson(stage: 'public'),
      l2RowJson(
        instanceId: '8b9f3c1e-2d4a-4f6b-9c8d-000000000002',
        stage: 'graduated',
        ticker: 'MOON',
        name: 'Moon Walk',
        noNextChange: true,
      ),
    ];
    await pumpS7Page(
      tester,
      const MemeScreen(),
      size: const Size(390, 1600),
      meta: s345Meta(),
      overrides: [
        launch2GatewayProvider.overrideWithValue(
          S345Launch2(s345Public(), page: l2Page(rows)),
        ),
        launch2OverviewGatewayProvider.overrideWithValue(S345Overview()),
        launch2ClockProvider.overrideWithValue(() => l2Now),
        loopFeatureSwitchesProvider.overrideWithValue(
          const LoopFeatureSwitchValues(launch2Visible: true),
        ),
      ],
    );
    await _shot(tester, 'S345-meme-home');
    await drainS345(tester);
  });

  testWidgets('launch2-instance chart, K / MA / VOL on', skip: !_shots, (
    tester,
  ) async {
    await pumpS345Router(
      tester,
      initial: Launch2Route.instance(l2InstanceA),
      launch2: S345Launch2(s345Graduated()),
      size: const Size(390, 1400),
    );
    await tester.tap(_key('launch2-candles-chart-style'));
    await tester.pumpAndSettle();
    await tester.tap(_key('launch2-candles-chart-ma'));
    await tester.pumpAndSettle();
    await _shot(tester, 'S345-launch2-chart');
    await drainS345(tester);
  });

  testWidgets('launch2-instance chart at 360', skip: !_shots, (tester) async {
    await pumpS345Router(
      tester,
      initial: Launch2Route.instance(l2InstanceA),
      launch2: S345Launch2(s345Graduated()),
      size: const Size(360, 1400),
    );
    await tester.tap(_key('launch2-candles-chart-ma'));
    await tester.pumpAndSettle();
    await _shot(tester, 'S345-launch2-chart-360');
    await drainS345(tester);
  });

  testWidgets('launch2 chart-full', skip: !_shots, (tester) async {
    await pumpS345Router(
      tester,
      initial: Launch2Route.chart(l2InstanceA),
      launch2: S345Launch2(s345Graduated()),
      size: const Size(390, 844),
    );
    await tester.tap(_key('launch2-candles-chart-style'));
    await tester.pumpAndSettle();
    await tester.tap(_key('launch2-candles-chart-ma'));
    await tester.pumpAndSettle();
    await _shot(tester, 'S345-launch2-chart-full');
    await drainS345(tester);
  });
}
