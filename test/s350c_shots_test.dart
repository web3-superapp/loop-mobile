// S350c · decision 0276: 我的 and another account's page, before and after
// the visual pass. Runs only with `--dart-define=LOOP_SHOTS=true`; the PNGs
// go to `LOOP_SHOTS_DIR` with `LOOP_SHOTS_TAG` (before / after) in the name.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/me_page_fixtures.dart';
import 'support/s5_fixtures.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment('LOOP_SHOTS_DIR');
const String _tag = String.fromEnvironment(
  'LOOP_SHOTS_TAG',
  defaultValue: 'after',
);

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(loopLoadShotFonts);
  // The wall and the splat are decoded off the test clock; the first page
  // of a run would otherwise be shot before they land.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  final element = tester.element(find.byType(MaterialApp).first);
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dir/$name-$_tag.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _section(WidgetTester tester, String bar, String label) async {
  final chip = find.descendant(
    of: find.byKey(ValueKey<String>(bar)),
    matching: find.text(label),
  );
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  loopWatchGround();

  for (final width in <double>[390, 360]) {
    final w = width.toInt();
    testWidgets('我的 · 持仓 $w', skip: !_shots, (tester) async {
      await pumpMePage(tester, size: Size(width, 1300));
      await _shot(tester, 'me-holdings-$w');
    });

    testWidgets('我的 · 持仓 空 $w', skip: !_shots, (tester) async {
      await pumpMePage(
        tester,
        balances: s5Balances(rows: const <LoopAssetBalanceRow>[]),
        size: Size(width, 1100),
      );
      await _shot(tester, 'me-holdings-empty-$w');
    });

    testWidgets('我的 · 交易 $w', skip: !_shots, (tester) async {
      await pumpMePage(
        tester,
        activity: meLongTape(nextCursor: null),
        size: Size(width, 1300),
      );
      await _section(tester, 'me-sections', '交易');
      await _shot(tester, 'me-trades-$w');
    });

    testWidgets('我的 · 交易 空 $w', skip: !_shots, (tester) async {
      await pumpMePage(
        tester,
        activity: s5Activity(items: const <LoopWalletActivityEntry>[]),
        size: Size(width, 1100),
      );
      await _section(tester, 'me-sections', '交易');
      await _shot(tester, 'me-trades-empty-$w');
    });

    testWidgets('我的 · 社区 $w', skip: !_shots, (tester) async {
      await pumpMePage(tester, size: Size(width, 1100));
      await _section(tester, 'me-sections', '社区');
      await _shot(tester, 'me-communities-$w');
    });

    testWidgets('我的 · 社区 空 $w', skip: !_shots, (tester) async {
      await pumpMePage(
        tester,
        home: meHome(
          joined: const <JoinedCommunity>[],
          owned: const <OwnedCommunity>[],
        ),
        size: Size(width, 1100),
      );
      await _section(tester, 'me-sections', '社区');
      await _shot(tester, 'me-communities-empty-$w');
    });

    testWidgets('他人主页 · 持仓 $w', skip: !_shots, (tester) async {
      await pumpOtherProfile(tester, size: Size(width, 1000));
      await _shot(tester, 'user-holdings-$w');
    });

    testWidgets('他人主页 · 交易 $w', skip: !_shots, (tester) async {
      await pumpOtherProfile(tester, size: Size(width, 1000));
      await _section(tester, 'user-profile-sections', '交易');
      await _shot(tester, 'user-trades-$w');
    });

    testWidgets('他人主页 · 社区 $w', skip: !_shots, (tester) async {
      await pumpOtherProfile(tester, size: Size(width, 1000));
      await _section(tester, 'user-profile-sections', '社区');
      await _shot(tester, 'user-communities-$w');
    });

    testWidgets('他人主页 · 空 $w', skip: !_shots, (tester) async {
      await pumpOtherProfile(tester, empty: true, size: Size(width, 1000));
      await _shot(tester, 'user-holdings-empty-$w');
      await _section(tester, 'user-profile-sections', '交易');
      await _shot(tester, 'user-trades-empty-$w');
      await _section(tester, 'user-profile-sections', '社区');
      await _shot(tester, 'user-communities-empty-$w');
    });
  }
}
