import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The five touches LOOP answers with (decision 0130).
///
/// Each one names what happened, not how strong the motor runs, so a call site
/// never picks an intensity:
///
/// * [selection] — a choice among peers moved: a tab, a segment, a slippage
///   step, a chart period.
/// * [light] — something small and done: a copy, a pull that is now far
///   enough to refresh.
/// * [medium] — something was picked up: a long-press menu opened, the chart
///   crosshair appeared, a row lifted for reordering.
/// * [success] / [error] — the signing exit's own outcome: broadcast, or
///   refused / failed.
enum LoopHaptic { selection, light, medium, success, error }

/// Plays one [LoopHaptic] on the device.
typedef LoopHapticPlayer = Future<void> Function(LoopHaptic haptic);

/// The one entry point for touch feedback (decision 0130).
///
/// `Reduce motion` does not silence it: a touch is not an animation, and
/// somebody who asked for less movement on screen has not asked for less
/// confirmation under the finger. Nothing here reads `MediaQuery`.
///
/// The player is a static seam so a widget test can record what was played
/// ([debugRecord]) without a platform channel; production plays through
/// Flutter's own [HapticFeedback], which is silent where a device has no
/// motor or the owner turned system haptics off.
abstract final class LoopHaptics {
  static LoopHapticPlayer _player = platformPlayer;

  /// A choice among peers moved (tab, segment, step, period).
  static void selection() => play(LoopHaptic.selection);

  /// A small action completed (copy, refresh armed).
  static void light() => play(LoopHaptic.light);

  /// Something was picked up (long-press menu, crosshair, drag lift).
  static void medium() => play(LoopHaptic.medium);

  /// The signing exit reported a broadcast.
  static void success() => play(LoopHaptic.success);

  /// The signing exit reported a refusal or a failure.
  static void error() => play(LoopHaptic.error);

  /// Plays [haptic] and never throws: a missing motor or channel is not a
  /// failure of the action the touch was confirming.
  static void play(LoopHaptic haptic) {
    unawaited(
      Future<void>.sync(() => _player(haptic))
          .catchError((Object _, StackTrace _) {}),
    );
  }

  /// The production mapping onto [HapticFeedback].
  ///
  /// iOS gets its notification generator for the two outcomes; Android maps
  /// the same calls onto its own `CONFIRM` / `REJECT` constants where the
  /// device has them.
  static Future<void> platformPlayer(LoopHaptic haptic) => switch (haptic) {
    LoopHaptic.selection => HapticFeedback.selectionClick(),
    LoopHaptic.light => HapticFeedback.lightImpact(),
    LoopHaptic.medium => HapticFeedback.mediumImpact(),
    LoopHaptic.success => HapticFeedback.successNotification(),
    LoopHaptic.error => HapticFeedback.errorNotification(),
  };

  /// Replaces the player; `null` restores [platformPlayer].
  @visibleForTesting
  static set debugPlayer(LoopHapticPlayer? player) =>
      _player = player ?? platformPlayer;

  /// Records every haptic into the returned list until [debugPlayer] is reset.
  @visibleForTesting
  static List<LoopHaptic> debugRecord() {
    final played = <LoopHaptic>[];
    _player = (haptic) async => played.add(haptic);
    return played;
  }
}
