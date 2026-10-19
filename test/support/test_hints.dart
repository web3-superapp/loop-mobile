import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';

/// S237 · decision 0204: turns the test-hints switch on for every test in
/// the calling `main`, for the suites that pin the testnet / specimen
/// behaviour the switch now gates. Each test file runs in its own isolate, so
/// the override never reaches another file.
void loopShowTestHints() {
  setUpAll(() => debugSetLoopTestHintsVisible(true));
  tearDownAll(() => debugSetLoopTestHintsVisible(null));
}
