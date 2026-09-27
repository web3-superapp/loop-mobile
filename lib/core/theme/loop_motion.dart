import 'package:flutter/widgets.dart';

/// The durations and curves of the motion components (decision 0092).
///
/// Every animated shared primitive reads its timing here, so the whole
/// product moves on one clock and one set of curves, and a later adjustment
/// is one edit rather than a search through every widget.
///
/// Motion never carries information of its own: each component states its
/// end state in full without it. When the platform asks for less motion —
/// `MediaQuery.disableAnimations`, which `LoopApp` also raises for the
/// device-local 减弱动态效果 preference — every transition here collapses into
/// an instant switch through [LoopMotion.reduced].
abstract final class LoopMotion {
  // --- LoopAvatarStack ---------------------------------------------------

  /// One avatar's travel between the stacked and the spread position.
  static const Duration avatarSpread = Duration(milliseconds: 280);

  /// The delay between two consecutive avatars starting their travel.
  static const Duration avatarStagger = Duration(milliseconds: 35);

  /// Spread and gather share this curve, so gathering retraces the path.
  static const Curve avatarCurve = Curves.easeInOutCubic;

  /// How much of an avatar the next one covers: the offset between two
  /// stacked avatars is `size × avatarStackStep`, i.e. each covers a third.
  static const double avatarStackStep = 2 / 3;

  // --- LoopProgressFill --------------------------------------------------

  /// The fill advancing to a new fraction.
  static const Duration progressFill = Duration(milliseconds: 260);
  static const Curve progressCurve = Curves.easeOutCubic;

  /// The single brightening when the fill reaches the whole width.
  static const Duration progressComplete = Duration(milliseconds: 600);

  /// The highlight's peak opacity during [progressComplete]: 0 → 0.12 → 0.
  static const double progressCompletePeak = 0.12;

  // --- LoopTrayDisclosure ------------------------------------------------

  /// The tray opening or closing under its card.
  static const Duration trayExpand = Duration(milliseconds: 280);
  static const Curve trayCurve = Curves.easeOutCubic;

  /// The detail fading in once the tray has started to open. It runs over the
  /// back part of [trayExpand], as an [Interval] of the same controller.
  static const double trayFadeStart = 0.35;

  /// Whether motion is switched off for [context]: either the platform's own
  /// accessibility setting or the app's 减弱动态效果, which `LoopApp` folds
  /// into the same [MediaQuery] flag.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or [Duration.zero] when motion is reduced.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
