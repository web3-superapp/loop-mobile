import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product switches that hide a finished surface without removing it
/// (decision 0110).
///
/// A switch only decides whether an entry is drawn and which branch a page
/// renders. It never changes the route table, a request or the backend: a
/// hidden page stays mounted and reachable by its own location.
abstract final class LoopFeatureSwitches {
  /// 需求方 2026-10-08：IDO Launch 保留代码、UI 隐藏；改 true 即恢复。
  static const bool idoLaunchVisible = false;

  /// S102 群内昵称：UI 隐藏、不移除（第二批接入）。
  static const bool groupAliasVisible = false;
}

/// The switch values one build runs with.
///
/// Pages read the switches through [loopFeatureSwitchesProvider] instead of
/// the constants, so a test can render both branches of the same page.
@immutable
final class LoopFeatureSwitchValues {
  const LoopFeatureSwitchValues({
    this.idoLaunchVisible = LoopFeatureSwitches.idoLaunchVisible,
    this.groupAliasVisible = LoopFeatureSwitches.groupAliasVisible,
  });

  final bool idoLaunchVisible;
  final bool groupAliasVisible;
}

/// The build's switches. Production never overrides it; tests override it to
/// cover the other value of a switch.
final loopFeatureSwitchesProvider = Provider<LoopFeatureSwitchValues>(
  (ref) => const LoopFeatureSwitchValues(),
);
