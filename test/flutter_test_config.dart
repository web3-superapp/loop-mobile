import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';

/// The whole suite runs with the brand loops still (decision 0224): a
/// settling pump must have an end. A test about the motion turns it back on
/// through `loopAmbientMotionProvider`.
///
/// Decision 0281: the suite runs in English, the default language. A test
/// that switches to Chinese (`LoopL10n.use`, or the locale provider) is put
/// back after it, so no other test inherits its language.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugLoopAmbientMotionDefault = false;
  LoopL10n.debugReset();
  tearDown(LoopL10n.debugReset);
  await testMain();
}
