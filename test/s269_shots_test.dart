// S269 · 字体与间距规范 v3 (client decision 0229): the self-review shots.
//
// Not a check: it writes 390-wide renders of the priority pages to
// docs/integration/S269/shots/ so the type ladder and the spacing can be read
// by eye. It runs only with `--dart-define=LOOP_SHOTS=true`; a plain
// `flutter test` skips every case and writes nothing.
import 'package:flutter_test/flutter_test.dart';

import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';
import 'support/s269_pages.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');

Future<void> _shot(WidgetTester tester, String name) =>
    loopShot(tester, name, slice: 844, dir: 'docs/integration/S269/shots');

void main() {
  loopWatchGround();

  for (final (name, file, pump)
      in <(String, String, Future<void> Function(WidgetTester))>[
        ('MEME home', 'meme-home', pumpS269MemeHome),
        ('MEME project page', 'project', pumpS269Project),
        ('情报', 'intel', pumpS269Intel),
        ('广场 · 社区', 'square-communities', pumpS269Square),
        ('钱包', 'wallet', pumpS269Wallet),
        ('代币页', 'token', pumpS269Token),
      ]) {
    testWidgets(name, skip: !_shots, (tester) async {
      await pump(tester);
      await _shot(tester, file);
      await drainS269(tester);
    });
  }
}
