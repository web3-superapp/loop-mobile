// S279 · decision 0237: the self-review shots of the MEME home's three tabs
// and the block grounds (需求方 2026-10-22 第 15、16 条).
//
// Not a check: it writes 390-wide renders to docs/integration/S279/shots/
// (or `LOOP_SHOTS_DIR`) so the tabs and the contrast between the wall, a
// block and a block inside it can be read by eye. It runs only with
// `--dart-define=LOOP_SHOTS=true`; a plain `flutter test` skips every case
// and writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/security/security_screens.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s269_pages.dart';
import 'support/s8_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'docs/integration/S279/shots',
);

const Size _phone = Size(390, 1266);

Future<void> _shot(WidgetTester tester, String name) =>
    loopShot(tester, name, slice: 1266, dir: _dir);

Finder _key(String value) => find.byKey(ValueKey<String>(value));

void main() {
  loopWatchGround();

  for (final tab in <String>['live', 'upcoming', 'graduated']) {
    testWidgets('MEME home · $tab', skip: !_shots, (tester) async {
      await pumpS279MemeHome(tester, size: _phone);
      // Let the wall and the banner art finish decoding before the shot.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump();
      final target = _key('launch2-desk-tab-$tab');
      if (target.evaluate().isNotEmpty) {
        await tester.tap(target);
        await tester.pumpAndSettle();
      } else if (tab != 'live') {
        // Before S279 the home has no tabs: one shot is enough.
        await drainS269(tester);
        return;
      }
      await _shot(tester, 'meme-home-$tab');
      await drainS269(tester);
    });
  }

  testWidgets('钱包', skip: !_shots, (tester) async {
    await pumpS269Wallet(tester);
    tester.view.physicalSize = _phone;
    await tester.pumpAndSettle();
    await _shot(tester, 'wallet');
    await drainS269(tester);
  });

  testWidgets('launch2 详情', skip: !_shots, (tester) async {
    await pumpS269Project(tester);
    await _shot(tester, 'launch2-detail');
    await drainS269(tester);
  });

  testWidgets('安全中心', skip: !_shots, (tester) async {
    await pumpS8Page(
      tester,
      SecurityCenterScreen(onNavigate: (_) {}),
      security: FakeSecurityGateway(),
      size: _phone,
    );
    await _shot(tester, 'security-center');
  });
}
