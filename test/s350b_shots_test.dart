// S350b · decision 0275: the self-review shots of the polish round — 情报 ·
// 算力 (代币 / 空 / 邀请列表 / 邀请加成), 算力榜 (社区 / 用户) and the MEME
// home (with and without a main event, and an empty tab).
//
// Not a check: it writes renders to `LOOP_SHOTS_DIR` (by default
// docs/integration/S350b/shots), each name suffixed with `LOOP_SHOTS_TAG`
// (`before` / `after`). It runs only with `--dart-define=LOOP_SHOTS=true`; a
// plain `flutter test` skips every case and writes nothing.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';

import 'support/launch2_fixtures.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s269_pages.dart';
import 'support/s345_charts.dart';
import 'support/s350b_pages.dart';
import 'support/s7_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'docs/integration/S350b/shots',
);
const String _tag = String.fromEnvironment(
  'LOOP_SHOTS_TAG',
  defaultValue: 'after',
);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// Writes the frame to [_dir] (an absolute directory is used as is).
Future<void> _shot(
  WidgetTester tester,
  String name, {
  double width = 390,
}) async {
  await tester.runAsync(loopLoadShotFonts);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final element = tester.element(find.byType(MaterialApp).first);
  final file = 'S350b-$name-$_tag${width == 390 ? '' : '-${width.toInt()}'}';
  final dir = _dir.startsWith('/') ? _dir : '${Directory.current.path}/$_dir';
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$file.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  loopWatchGround();

  for (final width in <double>[390, 360]) {
    testWidgets('算力 · 代币 @$width', skip: !_shots, (tester) async {
      await s350bPumpPower(tester, size: Size(width, 1500));
      await _shot(tester, 'power-token', width: width);
    });

    testWidgets('算力 · 邀请列表 @$width', skip: !_shots, (tester) async {
      await s350bPumpPower(tester, sub: 'invite', size: Size(width, 1700));
      await _shot(tester, 'power-invite-list', width: width);
    });

    testWidgets('算力榜 · 社区 @$width', skip: !_shots, (tester) async {
      await s350bPumpRank(tester, size: Size(width, 1500));
      await _shot(tester, 'rank-community', width: width);
    });

    testWidgets('MEME home @$width', skip: !_shots, (tester) async {
      await tester.runAsync(loopLoadShotFonts);
      await pumpS279MemeHome(tester, size: Size(width, 1400));
      await tester.tap(_key('launch2-desk-tab-live'));
      await tester.pumpAndSettle();
      await _shot(tester, 'meme-home', width: width);
      await drainS269(tester);
    });
  }

  testWidgets('算力 · 空', skip: !_shots, (tester) async {
    await s350bPumpPower(tester, empty: true, size: const Size(390, 1100));
    await _shot(tester, 'power-empty');
  });

  testWidgets('算力 · NFT', skip: !_shots, (tester) async {
    await s350bPumpPower(tester, sub: 'nft', size: const Size(390, 1100));
    await _shot(tester, 'power-nft');
  });

  testWidgets('算力 · 邀请加成', skip: !_shots, (tester) async {
    await s350bPumpPower(tester, sub: 'invite', size: const Size(390, 1600));
    await s350bSubTab(tester, '邀请加成');
    await _shot(tester, 'power-invite-boost');
  });

  testWidgets('算力榜 · 用户', skip: !_shots, (tester) async {
    await s350bPumpRank(tester);
    await tester.tap(
      find.descendant(of: _key('intel-rank-scope'), matching: find.text('用户')),
    );
    await tester.pumpAndSettle();
    await _shot(tester, 'rank-users');
  });

  testWidgets('MEME home · main event', skip: !_shots, (tester) async {
    await tester.runAsync(loopLoadShotFonts);
    await pumpS269MemeHomeWith(tester, <Map<String, Object?>>[
      s350bRow(1, 'public', soldBps: 8200, name: '天才少年', ticker: 'TC'),
      s350bRow(2, 'public', soldBps: 2500, name: 'Frog Launch'),
      s350bRow(3, 'public', soldBps: 900, name: 'S234W', ticker: 'S234W'),
      s350bRow(4, 'graduated', soldBps: 10000, name: 'Doge on LOOP'),
    ], size: const Size(390, 1200));
    await _shot(tester, 'meme-event');
    await drainS269(tester);
  });

  for (final width in <double>[390, 360]) {
    testWidgets('MEME home · empty desk @$width', skip: !_shots, (
      tester,
    ) async {
      await tester.runAsync(loopLoadShotFonts);
      await pumpS7Page(
        tester,
        const MemeScreen(),
        size: Size(width, 1000),
        meta: s345Meta(),
        overrides: [
          launch2GatewayProvider.overrideWithValue(
            S345Launch2(
              s345Public(),
              page: l2Page(<Map<String, Object?>>[
                s350bRow(2, 'public', soldBps: 2500, name: 'Frog Launch'),
                s350bRow(
                  3,
                  'public',
                  soldBps: 900,
                  name: 'S234W',
                  ticker: 'S234W',
                ),
              ]),
            ),
          ),
          launch2OverviewGatewayProvider.overrideWithValue(S345Overview()),
          launch2ClockProvider.overrideWithValue(() => l2Now),
          loopFeatureSwitchesProvider.overrideWithValue(
            const LoopFeatureSwitchValues(launch2Visible: true),
          ),
        ],
      );
      await _shot(tester, 'meme-desk-empty', width: width);
      await drainS345(tester);
    });
  }

  testWidgets('MEME home · 预告 empty', skip: !_shots, (tester) async {
    await tester.runAsync(loopLoadShotFonts);
    await pumpS269MemeHomeWith(tester, <Map<String, Object?>>[
      s350bRow(2, 'public', soldBps: 2500, name: 'Frog Launch'),
    ], size: const Size(390, 1100));
    await tester.tap(_key('launch2-desk-tab-upcoming'));
    await tester.pumpAndSettle();
    await _shot(tester, 'meme-upcoming-empty');
    await drainS269(tester);
  });
}
