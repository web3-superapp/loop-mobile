import 'dart:async';

import 'package:loop_mobile/widgets/loop_atmosphere.dart';

/// The whole suite runs with the brand loops still (decision 0224): a
/// settling pump must have an end. A test about the motion turns it back on
/// through `loopAmbientMotionProvider`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  debugLoopAmbientMotionDefault = false;
  await testMain();
}
