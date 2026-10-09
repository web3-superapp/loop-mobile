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

  // --- Loading (decision 0095) -------------------------------------------

  /// Content replacing its skeleton: one fade, no travel. A block that was
  /// already on screen when a refresh answered does not fade again.
  static const Duration contentFadeIn = Duration(milliseconds: 180);
  static const Curve contentFadeCurve = Curves.easeOutCubic;

  /// The freshness line at the top of a page (「数据来自 N 秒前，正在更新」)
  /// fading in over a restored snapshot and out once the new answer landed.
  static const Duration freshnessFade = Duration(milliseconds: 220);
  static const Curve freshnessCurve = Curves.easeOutCubic;

  // --- LoopAccordionStrip (decision 0096) --------------------------------

  /// One strip widening while the others narrow, and the reverse.
  static const Duration accordionExpand = Duration(milliseconds: 280);
  static const Curve accordionCurve = Curves.easeOutCubic;

  /// The open strip's detail fades in over the back part of
  /// [accordionExpand], from 40 % of the same controller; a closing strip's
  /// detail is gone by the same point.
  static const double accordionFadeStart = 0.4;

  /// The open strip's width weight against every other strip's 1.
  static const double accordionOpenWeight = 3;

  // --- LoopDockBar (decision 0096) ---------------------------------------

  /// A glyph under the finger.
  static const double dockPeakScale = 1.45;

  /// A glyph one cell away from the finger. The decay is Gaussian in cells —
  /// `1 + (peak − 1) · 3^(−d²)` — which lands exactly on this at `d = 1`.
  static const double dockNeighbourScale = 1.15;

  /// Beyond this many cells the glyph is at rest (the Gaussian tail there is
  /// under 1 %, so the cut is invisible).
  static const double dockReach = 2;

  /// The magnification rising once a press becomes a slide.
  static const Duration dockEngage = Duration(milliseconds: 120);

  /// The magnification settling after the finger lifts.
  static const Duration dockRelease = Duration(milliseconds: 180);
  static const Curve dockCurve = Curves.easeOutCubic;

  // --- LoopPressable (decision 0130) -------------------------------------

  /// How far a pressed control shrinks. Small on purpose: it says "this is
  /// under your finger", not "this is moving".
  static const double pressScale = 0.98;

  /// The opacity a pressed control dims to. The dim is the feedback that
  /// stays when motion is reduced; only the shrink goes.
  static const double pressOpacity = 0.6;

  /// Going down follows the finger at once; coming back up eases out.
  static const Duration pressIn = Duration(milliseconds: 60);
  static const Duration pressOut = Duration(milliseconds: 160);
  static const Curve pressCurve = Curves.easeOut;

  /// Whether motion is switched off for [context]: either the platform's own
  /// accessibility setting or the app's 减弱动态效果, which `LoopApp` folds
  /// into the same [MediaQuery] flag.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or [Duration.zero] when motion is reduced.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
