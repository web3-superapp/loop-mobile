// S352 · decision 0277: the nine pages of the Figma design-system round —
// 聊天, 广场 · 动态, 广场 · 社区 (S350a), MEME, 算力 (with its 邀请 list),
// 算力榜 (S350b), 我的 and another account's page (S350c) — shot before and
// after the new type, colour and shape tokens, plus the tab bar on its own.
//
// Not a check: it re-runs the S350a / S350b / S350c shot cases, so every
// render lands in `LOOP_SHOTS_DIR` (an absolute directory is used as is) at
// 390 and 360 wide, tagged with `LOOP_SHOTS_TAG` where the case names one.
// It runs only with `--dart-define=LOOP_SHOTS=true`; a plain `flutter test`
// skips every case and writes nothing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/shell/loop_shell.dart';

import 's350a_shots_test.dart' as chat_square;
import 's350b_shots_test.dart' as meme_power;
import 's350c_shots_test.dart' as me_pages;
import 'support/loop_shots.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'docs/integration/S352/shots',
);
const String _tag = String.fromEnvironment(
  'LOOP_SHOTS_TAG',
  defaultValue: 'after',
);

void main() {
  group('S352 · 聊天 / 广场', chat_square.main);
  group('S352 · MEME / 算力 / 算力榜 / 邀请', meme_power.main);
  group('S352 · 我的 / 他人主页', me_pages.main);

  for (final size in const <Size>[Size(390, 844), Size(360, 780)]) {
    testWidgets('S352 · 底栏 @${size.width.toInt()}', skip: !_shots, (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: LoopShell(location: '/meme', child: const SizedBox.expand()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      await loopShot(
        tester,
        'tab-bar-${size.width.toInt()}-$_tag',
        slice: size.height,
        dir: _dir,
      );
    });
  }
}
