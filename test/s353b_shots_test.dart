// S353b · decision 0279: the self-review shots of the Figma alignment round
// for MEME, 情报 · 算力 (with its 邀请 tab) and 算力榜, in English at 390 and
// 360 wide (viewport 844 / 800 high, plus a tall render of the long pages).
//
// Not a check: it writes renders to `LOOP_SHOTS_DIR`, each name suffixed with
// `LOOP_SHOTS_TAG` (`before` / `after`). It runs only with
// `--dart-define=LOOP_SHOTS=true`; a plain `flutter test` skips every case.
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
import 'support/loop_shots.dart';
import 'support/s269_pages.dart';
import 'support/s345_charts.dart';
import 'support/s350b_pages.dart';
import 'support/s7_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'docs/integration/S353b/shots',
);
const String _tag = String.fromEnvironment(
  'LOOP_SHOTS_TAG',
  defaultValue: 'after',
);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Size _phone(double width) => Size(width, width == 390 ? 844 : 800);

Future<void> _shot(WidgetTester tester, String name, double width) async {
  await tester.runAsync(loopLoadShotFonts);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final element = tester.element(find.byType(MaterialApp).first);
  final file = 'S353b-$name-$_tag-${width.toInt()}';
  final dir = _dir.startsWith('/') ? _dir : '${Directory.current.path}/$_dir';
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$file.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _memeEmptyDesk(WidgetTester tester, Size size) async {
  await tester.runAsync(loopLoadShotFonts);
  await pumpS7Page(
    tester,
    const MemeScreen(),
    size: size,
    meta: s345Meta(),
    overrides: [
      launch2GatewayProvider.overrideWithValue(
        S345Launch2(
          s345Public(),
          page: l2Page(<Map<String, Object?>>[
            s350bRow(2, 'public', soldBps: 2500, name: 'Frog Launch'),
            s350bRow(3, 'public', soldBps: 900, name: 'S234W', ticker: 'S234W'),
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
}

void main() {
  for (final width in <double>[390, 360]) {
    testWidgets('MEME home @$width', skip: !_shots, (tester) async {
      await tester.runAsync(loopLoadShotFonts);
      await pumpS279MemeHome(tester, size: _phone(width));
      await tester.tap(_key('launch2-desk-tab-live'));
      await tester.pumpAndSettle();
      await _shot(tester, 'meme-home', width);
      await drainS269(tester);
    });

    testWidgets('MEME home · main event @$width', skip: !_shots, (
      tester,
    ) async {
      await tester.runAsync(loopLoadShotFonts);
      await pumpS269MemeHomeWith(tester, <Map<String, Object?>>[
        s350bRow(1, 'public', soldBps: 8200, name: 'Genius Kid', ticker: 'TC'),
        s350bRow(2, 'public', soldBps: 2500, name: 'Frog Launch'),
        s350bRow(3, 'public', soldBps: 900, name: 'S234W', ticker: 'S234W'),
        s350bRow(4, 'graduated', soldBps: 10000, name: 'Doge on LOOP'),
      ], size: _phone(width));
      await _shot(tester, 'meme-event', width);
      await drainS269(tester);
    });

    testWidgets('MEME home · empty desk @$width', skip: !_shots, (
      tester,
    ) async {
      await _memeEmptyDesk(tester, _phone(width));
      await _shot(tester, 'meme-desk-empty', width);
      await drainS345(tester);
    });

    testWidgets('MEME home · upcoming empty @$width', skip: !_shots, (
      tester,
    ) async {
      await tester.runAsync(loopLoadShotFonts);
      await pumpS269MemeHomeWith(tester, <Map<String, Object?>>[
        s350bRow(2, 'public', soldBps: 2500, name: 'Frog Launch'),
      ], size: _phone(width));
      await tester.tap(_key('launch2-desk-tab-upcoming'));
      await tester.pumpAndSettle();
      await _shot(tester, 'meme-upcoming-empty', width);
      await drainS269(tester);
    });

    testWidgets('Power · token @$width', skip: !_shots, (tester) async {
      await s350bPumpPower(tester, size: _phone(width));
      await _shot(tester, 'power-token', width);
    });

    testWidgets('Power · token tall @$width', skip: !_shots, (tester) async {
      await s350bPumpPower(tester, size: Size(width, 1500));
      await _shot(tester, 'power-token-tall', width);
    });

    testWidgets('Power · empty @$width', skip: !_shots, (tester) async {
      await s350bPumpPower(tester, empty: true, size: _phone(width));
      await _shot(tester, 'power-empty', width);
    });

    testWidgets('Power · NFT @$width', skip: !_shots, (tester) async {
      await s350bPumpPower(tester, sub: 'nft', size: _phone(width));
      await _shot(tester, 'power-nft', width);
    });

    testWidgets('Invite · list @$width', skip: !_shots, (tester) async {
      await s350bPumpPower(tester, sub: 'invite', size: Size(width, 1500));
      await _shot(tester, 'invite-list', width);
    });

    testWidgets('Invite · boost @$width', skip: !_shots, (tester) async {
      await s350bPumpPower(tester, sub: 'invite', size: Size(width, 1500));
      await s350bSubTab(tester, 'Invite boost');
      await _shot(tester, 'invite-boost', width);
    });

    testWidgets('Rank · community @$width', skip: !_shots, (tester) async {
      await s350bPumpRank(tester, size: _phone(width));
      await _shot(tester, 'rank-community', width);
    });

    testWidgets('Rank · community tall @$width', skip: !_shots, (tester) async {
      await s350bPumpRank(tester, size: Size(width, 1400));
      await _shot(tester, 'rank-community-tall', width);
    });

    testWidgets('Rank · users @$width', skip: !_shots, (tester) async {
      await s350bPumpRank(tester, size: _phone(width));
      await tester.tap(
        find.descendant(
          of: _key('intel-rank-scope'),
          matching: find.text('User'),
        ),
      );
      await tester.pumpAndSettle();
      await _shot(tester, 'rank-users', width);
    });
  }
}
