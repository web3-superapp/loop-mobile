import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// Global components of the Lime Ledger system (01 handover chapter 6.1),
/// each mapped from its `style-v2.css` class. Colours, radii and spacing come
/// only from `loop_theme.dart`; no widget here fabricates data or state.

// ---------------------------------------------------------------------------
// Topbar (.topbar / .back)
// ---------------------------------------------------------------------------

/// `.topbar`: 44px back button, 24/800 title, 44px tool buttons; long titles
/// truncate but never drop the leading business word.
class LoopTopbar extends StatelessWidget {
  const LoopTopbar({
    required this.title,
    super.key,
    this.kicker,
    this.onBack,
    this.backLabel = '返回',
    this.actions = const <Widget>[],
    this.minHeight = LoopLayout.topbarContentHeight,
    this.updating = false,
  });

  final String title;

  /// Small line above the title (`.topbar small`).
  final String? kicker;
  final VoidCallback? onBack;
  final String backLabel;
  final List<Widget> actions;
  final double minHeight;

  /// The page is re-reading data it already shows. The topbar wears the
  /// 更新中 mark; the page keeps its content and its actions.
  final bool updating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        6,
        LoopSpacing.page,
        0,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Row(
          children: <Widget>[
            if (onBack != null) ...<Widget>[
              LoopIconButton(
                key: const ValueKey<String>('loop-topbar-back'),
                icon: 'back',
                label: backLabel,
                onPressed: onBack,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (kicker != null)
                    Text(
                      kicker!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopMono.label,
                    ),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineLarge,
                    ),
                  ),
                ],
              ),
            ),
            if (updating) ...<Widget>[
              const SizedBox(width: 8),
              const LoopUpdatingBadge(),
            ],
            for (final action in actions) ...<Widget>[
              const SizedBox(width: 6),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// 44×44 icon button with a sprite glyph (`.back` and topbar tools).
class LoopIconButton extends StatelessWidget {
  const LoopIconButton({
    required this.icon,
    required this.label,
    super.key,
    this.onPressed,
    this.color,
    this.toggled,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  /// Whether this button reports an on/off state a screen reader should hear.
  /// `null` — the default — is a plain button with no toggle semantics.
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      toggled: toggled,
      enabled: onPressed != null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: LoopTouch.minimum,
            height: LoopTouch.minimum,
            child: Center(
              child: LoopIcon(icon, size: 19, color: color ?? LoopColors.chalk),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label (.label)
// ---------------------------------------------------------------------------

/// `.label`: mono 10/600, .15em tracking, uppercase, text3; 30px above (22px
/// when it follows another label) and 8px below.
class LoopLabel extends StatelessWidget {
  const LoopLabel(
    this.text, {
    super.key,
    this.followsLabel = false,
    this.tight = false,
  });

  final String text;

  /// `.label + .label` keeps 22px instead of 30px above.
  final bool followsLabel;

  /// `[data-page-archetype="state"] .folio-body > .label`: 14px above.
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final top = tight
        ? 14.0
        : followsLabel
        ? LoopSpacing.group
        : LoopSpacing.section;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        LoopSpacing.page,
        top,
        LoopSpacing.page,
        LoopSpacing.tight,
      ),
      child: Semantics(
        header: true,
        child: Text(text.toUpperCase(), style: LoopMono.label),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Folio primary (.folio-primary / .ledger-card / .chalk-card / .folio-state)
// ---------------------------------------------------------------------------

enum LoopFolioVariant {
  /// `.ledger-card`: full Lime, Ink text.
  lime,

  /// `.ledger-card.ledger-quiet`: low-saturation Lime tint, Chalk text.
  quiet,

  /// `.chalk-card`: Chalk ground, Ink text.
  chalk,
}

/// Per-archetype folio metrics (`[data-page-archetype] .folio-*`).
enum LoopFolioArchetype {
  intro('intro', minHeight: 216, headingSize: 30, headingTop: 28),

  /// `data-page-archetype="index"` (`index` is reserved on Dart enums).
  listing('index', minHeight: 158, headingSize: 25, headingTop: 16),
  record('record', minHeight: 178, headingSize: 29, headingTop: 16),
  action('action', minHeight: 174, headingSize: 27, headingTop: 16),
  state('state', minHeight: 194, headingSize: 29, headingTop: 22);

  const LoopFolioArchetype(
    this.wireName, {
    required this.minHeight,
    required this.headingSize,
    required this.headingTop,
  });

  /// Prototype `data-page-archetype` value.
  final String wireName;
  final double minHeight;
  final double headingSize;
  final double headingTop;
}

/// `.folio-primary`: the page's single primary narrative — kicker, heading,
/// caption and an optional stamp.
class LoopFolioPrimary extends StatelessWidget {
  const LoopFolioPrimary({
    required this.heading,
    super.key,
    this.kicker,
    this.caption,
    this.stamp,
    this.variant = LoopFolioVariant.quiet,
    this.archetype = LoopFolioArchetype.action,
    this.compact = false,
    this.trailing,
  });

  final String heading;
  final String? kicker;
  final String? caption;

  /// `.folio-stamp`: pill at the bottom-right, uppercase mono.
  final String? stamp;
  final LoopFolioVariant variant;
  final LoopFolioArchetype archetype;

  /// `.page-focus-stack .folio-primary`: 142 min-height, 14 padding.
  final bool compact;

  /// Optional widget (identity, figure) on the right of the heading.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final foreground = switch (variant) {
      LoopFolioVariant.lime || LoopFolioVariant.chalk => LoopColors.ink,
      LoopFolioVariant.quiet => LoopColors.chalk,
    };
    final headingColor = variant == LoopFolioVariant.quiet
        ? LoopColors.lime
        : LoopColors.ink;
    final decoration = switch (variant) {
      LoopFolioVariant.lime => const BoxDecoration(
        color: LoopColors.lime,
        borderRadius: LoopRadius.shell,
        boxShadow: LoopDepth.liftPrimaryLight,
      ),
      LoopFolioVariant.chalk => const BoxDecoration(
        color: LoopColors.chalk,
        borderRadius: LoopRadius.shell,
        boxShadow: LoopDepth.liftPrimaryLight,
      ),
      LoopFolioVariant.quiet => BoxDecoration(
        color: LoopColors.lime.withValues(alpha: 0.075),
        gradient: const RadialGradient(
          center: Alignment(0.76, -1.24),
          radius: 1.2,
          colors: <Color>[Color(0x2BB8FF20), Color(0x00B8FF20)],
          stops: <double>[0, 0.62],
        ),
        borderRadius: LoopRadius.shell,
        border: Border.all(color: LoopColors.lime.withValues(alpha: 0.34)),
        boxShadow: LoopDepth.liftPrimary,
      ),
    };
    final ringColor = variant == LoopFolioVariant.quiet
        ? LoopColors.lime.withValues(alpha: 0.2)
        : LoopColors.ink.withValues(alpha: 0.14);
    final kickerOpacity = variant == LoopFolioVariant.quiet ? 0.78 : 0.66;
    final captionOpacity = variant == LoopFolioVariant.quiet ? 0.86 : 0.72;
    final padding = compact ? 14.0 : 18.0;
    return Semantics(
      container: true,
      child: Container(
        key: const ValueKey<String>('loop-folio-primary'),
        margin: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          LoopSpacing.group,
        ),
        constraints: BoxConstraints(
          minHeight: compact ? 142 : archetype.minHeight,
        ),
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: <Widget>[
            // `.folio-state::after` ring.
            Positioned(
              right: -30,
              top: -36,
              child: IgnorePointer(
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ringColor),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: ringColor.withValues(alpha: 0.035),
                        spreadRadius: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (kicker != null)
                    FractionallySizedBox(
                      widthFactor: 0.72,
                      alignment: Alignment.centerLeft,
                      child: Opacity(
                        opacity: kickerOpacity,
                        child: Text(
                          kicker!.toUpperCase(),
                          style: LoopTypography.eyebrow(11, color: foreground),
                        ),
                      ),
                    ),
                  SizedBox(height: compact ? 10 : archetype.headingTop),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: FractionallySizedBox(
                          widthFactor: trailing == null ? 0.88 : 1,
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                            header: true,
                            child: Text(
                              heading,
                              style: LoopTypography.display(
                                compact ? 24 : archetype.headingSize,
                                color: headingColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  if (caption != null) ...<Widget>[
                    SizedBox(height: compact ? 8 : 15),
                    FractionallySizedBox(
                      widthFactor: stamp == null ? 0.8 : 0.57,
                      alignment: Alignment.centerLeft,
                      child: Opacity(
                        opacity: captionOpacity,
                        child: Text(
                          caption!,
                          style: LoopTypography.caption(12, color: foreground),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (stamp != null)
              Positioned(
                right: 14,
                bottom: 14,
                child: Opacity(
                  opacity: variant == LoopFolioVariant.quiet ? 0.8 : 0.68,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                    decoration: BoxDecoration(
                      borderRadius: LoopRadius.pill,
                      border: Border.all(
                        color: variant == LoopFolioVariant.quiet
                            ? LoopColors.lime
                            : foreground,
                      ),
                    ),
                    child: Text(
                      stamp!.toUpperCase(),
                      style: LoopTypography.eyebrow(
                        11,
                        color: variant == LoopFolioVariant.quiet
                            ? LoopColors.lime
                            : foreground,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cards (.ledger-card / .chalk-card / .card / .record-card)
// ---------------------------------------------------------------------------

/// `.ledger-card`: Lime primary card for key figures and actions. `quiet`
/// (`.ledger-quiet`) is for information so Lime is not misread as tappable.
class LoopLedgerCard extends StatelessWidget {
  const LoopLedgerCard({
    required this.child,
    super.key,
    this.quiet = false,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  });

  final Widget child;
  final bool quiet;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final decoration = quiet
        ? BoxDecoration(
            color: LoopColors.lime.withValues(alpha: 0.075),
            borderRadius: LoopRadius.shell,
            border: Border.all(color: LoopColors.lime.withValues(alpha: 0.34)),
            boxShadow: LoopDepth.liftPrimary,
          )
        : const BoxDecoration(
            color: LoopColors.lime,
            borderRadius: LoopRadius.shell,
            boxShadow: LoopDepth.liftPrimaryLight,
          );
    final body = DefaultTextStyle.merge(
      style: TextStyle(color: quiet ? LoopColors.chalk : LoopColors.ink),
      child: IconTheme.merge(
        data: IconThemeData(color: quiet ? LoopColors.lime : LoopColors.ink),
        child: Padding(padding: padding, child: child),
      ),
    );
    return Padding(
      padding: margin,
      child: _Pressable(
        key: ValueKey<String>(quiet ? 'loop-ledger-quiet' : 'loop-ledger'),
        onTap: onTap,
        semanticLabel: semanticLabel,
        decoration: decoration,
        borderRadius: LoopRadius.shell,
        // `.ledger-card::before`: a static dot texture under the content. It
        // is painted, never animated, so reduced motion changes nothing here.
        // The boundary keeps the grid out of the parent's repaints, and
        // `isComplex` lets the engine cache the raster.
        child: RepaintBoundary(
          child: CustomPaint(
            key: ValueKey<String>(
              quiet ? 'loop-ledger-quiet-texture' : 'loop-ledger-texture',
            ),
            isComplex: true,
            painter: LoopLedgerTexturePainter(
              spec: quiet ? LoopLedgerTexture.quiet : LoopLedgerTexture.primary,
            ),
            child: body,
          ),
        ),
      ),
    );
  }
}

/// The exact `.ledger-card::before` parameters, kept as values so they can be
/// asserted without a golden image.
///
/// The prototype declares the layer as a radial-gradient dot grid under a
/// linear mask:
///
/// ```css
/// .ledger-card::before{
///   opacity:.24;
///   background-image:radial-gradient(rgba(5,6,4,.7) 1px,transparent 1px);
///   background-size:9px 9px;
///   mask-image:linear-gradient(105deg,transparent 28%,var(--ink))
/// }
/// .ledger-card.ledger-quiet::before{
///   opacity:.12;background-image:radial-gradient(rgba(184,255,32,.5) 1px,transparent 1px)
/// }
/// ```
@immutable
final class LoopLedgerTexture {
  const LoopLedgerTexture({
    required this.dotColor,
    required this.dotAlpha,
    required this.layerOpacity,
  });

  /// `.ledger-card::before` — Ink dots at 70% under a 24% layer.
  static const primary = LoopLedgerTexture(
    dotColor: LoopColors.ink,
    dotAlpha: 0.7,
    layerOpacity: 0.24,
  );

  /// `.ledger-card.ledger-quiet::before` — Lime dots at 50% under a 12% layer.
  static const quiet = LoopLedgerTexture(
    dotColor: LoopColors.lime,
    dotAlpha: 0.5,
    layerOpacity: 0.12,
  );

  /// `background-size:9px 9px`.
  static const double spacing = 9;

  /// `radial-gradient(<color> 1px, transparent 1px)`.
  static const double dotRadius = 1;

  /// `mask-image:linear-gradient(105deg, …)`.
  static const double maskAngleDegrees = 105;

  /// The mask is fully transparent up to this stop and reaches full opacity at
  /// the end of the gradient line.
  static const double maskTransparentStop = 0.28;

  final Color dotColor;
  final double dotAlpha;
  final double layerOpacity;

  /// The alpha one dot is painted with before the mask is applied.
  double get effectiveAlpha => dotAlpha * layerOpacity;

  /// The CSS gradient-line length for [size] at [maskAngleDegrees].
  ///
  /// CSS measures 0deg as "to top" and turns clockwise, so the line length is
  /// `|W·sin(theta)| + |H·cos(theta)|`.
  static double maskLineLength(Size size) {
    final theta = maskAngleDegrees * math.pi / 180;
    return (size.width * math.sin(theta)).abs() +
        (size.height * math.cos(theta)).abs();
  }

  /// Where [point] falls on the mask gradient line, as `0..1` from its start.
  static double maskPosition(Offset point, Size size) {
    final length = maskLineLength(size);
    if (length <= 0) return 1;
    final theta = maskAngleDegrees * math.pi / 180;
    // Screen coordinates put y downwards, so "to top" is -y.
    final dx = math.sin(theta);
    final dy = -math.cos(theta);
    final projected =
        (point.dx - size.width / 2) * dx + (point.dy - size.height / 2) * dy;
    return (projected / length + 0.5).clamp(0.0, 1.0);
  }

  /// The mask multiplier at [point]: 0 before the transparent stop, then a
  /// linear ramp to 1 at the end of the gradient line.
  static double maskFactor(Offset point, Size size) {
    // An empty box has no gradient line and nothing to paint on.
    if (size.isEmpty) return 0;
    final position = maskPosition(point, size);
    if (position <= maskTransparentStop) return 0;
    return (position - maskTransparentStop) / (1 - maskTransparentStop);
  }

  /// How many alpha steps the mask ramp is quantised into.
  ///
  /// The ramp is a visual gradient, not a fact, so a step finer than the eye
  /// can resolve only costs draw calls. Quantising lets every dot in a step be
  /// drawn by one [Canvas.drawPoints] call instead of one call per dot, which
  /// caps the painter at [maskSteps] calls whatever the card's size.
  static const int maskSteps = 12;

  /// The dots of one card, bucketed by quantised mask alpha.
  ///
  /// The mask is evaluated once per dot here and never again during painting.
  /// Buckets with no visible dot are omitted, so a fully masked corner costs
  /// nothing.
  static List<({double alpha, List<Offset> points})> dotBuckets(Size size) {
    final buckets = <int, List<Offset>>{};
    for (final center in dotCenters(size)) {
      final factor = maskFactor(center, size);
      if (factor <= 0) continue;
      final step = (factor * maskSteps).ceil().clamp(1, maskSteps);
      (buckets[step] ??= <Offset>[]).add(center);
    }
    final steps = buckets.keys.toList()..sort();
    return List<({double alpha, List<Offset> points})>.unmodifiable(
      <({double alpha, List<Offset> points})>[
        for (final step in steps)
          (
            alpha: step / maskSteps,
            points: List<Offset>.unmodifiable(buckets[step]!),
          ),
      ],
    );
  }

  /// The dot centres for [size], in the CSS background grid's own order.
  static List<Offset> dotCenters(Size size) {
    if (size.isEmpty) return const <Offset>[];
    final centers = <Offset>[];
    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        centers.add(Offset(x, y));
      }
    }
    return List<Offset>.unmodifiable(centers);
  }
}

/// Paints [LoopLedgerTexture] behind a ledger card's content.
///
/// One [Canvas.drawPoints] call per quantised mask step, never one per dot: a
/// 360x200 card holds roughly 900 dots and would otherwise cost 900 draw calls
/// on every raster.
class LoopLedgerTexturePainter extends CustomPainter {
  const LoopLedgerTexturePainter({required this.spec});

  final LoopLedgerTexture spec;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    for (final bucket in LoopLedgerTexture.dotBuckets(size)) {
      canvas.drawPoints(
        PointMode.points,
        bucket.points,
        Paint()
          ..color = spec.dotColor.withValues(
            alpha: spec.effectiveAlpha * bucket.alpha,
          )
          // A round cap turns a point into the CSS dot; the stroke width is
          // the gradient's diameter.
          ..strokeCap = StrokeCap.round
          ..strokeWidth = LoopLedgerTexture.dotRadius * 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant LoopLedgerTexturePainter oldDelegate) =>
      oldDelegate.spec != spec;
}

/// `.chalk-card`: high-contrast explanation, confirmation or review surface.
class LoopChalkCard extends StatelessWidget {
  const LoopChalkCard({
    required this.child,
    super.key,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: _Pressable(
        key: const ValueKey<String>('loop-chalk-card'),
        onTap: onTap,
        semanticLabel: semanticLabel,
        decoration: const BoxDecoration(
          color: LoopColors.chalk,
          borderRadius: LoopRadius.card,
          boxShadow: LoopDepth.liftPrimaryLight,
        ),
        borderRadius: LoopRadius.card,
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: LoopColors.ink),
          child: IconTheme.merge(
            data: const IconThemeData(color: LoopColors.ink),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// `.card`: the standard card (Card tint, Line border, radius 20, lift-card).
class LoopSurfaceCard extends StatelessWidget {
  const LoopSurfaceCard({
    required this.child,
    super.key,
    this.onTap,
    this.semanticLabel,
    this.background,
    this.borderColor,
    this.padding = const EdgeInsets.all(15),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? background;
  final Color? borderColor;
  final EdgeInsets padding;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: _Pressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        decoration: BoxDecoration(
          color: background ?? LoopColors.card,
          borderRadius: LoopRadius.card,
          border: Border.all(color: borderColor ?? LoopColors.line),
          boxShadow: LoopDepth.liftCard,
        ),
        borderRadius: LoopRadius.card,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// `.record-card`: detail record with the Chalk text and lift-card depth.
class LoopRecordCard extends StatelessWidget {
  const LoopRecordCard({required this.child, super.key, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, LoopSpacing.card),
      child: _Pressable(
        onTap: onTap,
        decoration: BoxDecoration(
          color: LoopColors.chalk.withValues(alpha: 0.045),
          gradient: const RadialGradient(
            center: Alignment(0.84, -1.28),
            radius: 1.3,
            colors: <Color>[Color(0x0DF3F5EF), Color(0x00F3F5EF)],
            stops: <double>[0, 0.6],
          ),
          borderRadius: LoopRadius.card,
          border: Border.all(color: LoopColors.line),
          boxShadow: LoopDepth.liftCard,
        ),
        borderRadius: LoopRadius.card,
        child: Padding(padding: const EdgeInsets.all(15), child: child),
      ),
    );
  }
}

class _Pressable extends StatelessWidget {
  const _Pressable({
    required this.child,
    required this.decoration,
    required this.borderRadius,
    super.key,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final BoxDecoration decoration;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final box = DecoratedBox(decoration: decoration, child: child);
    if (onTap == null) return box;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: borderRadius, child: box),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rows (.row inside .refined-page .folio-body)
// ---------------------------------------------------------------------------

enum LoopRowPosition { single, first, middle, last }

/// `.row`: identity, primary copy, secondary copy and a stable trailing value.
/// Consecutive rows form one card: first gets the top radius and light edge,
/// last the bottom radius and shadow. Taps feedback with the ground colour.
class LoopRecordRow extends StatelessWidget {
  const LoopRecordRow({
    required this.title,
    super.key,
    this.leading,
    this.subtitle,
    this.trailing,
    this.trailingCaption,
    this.trailingCaptionUp,
    this.trailingBadge,
    this.onTap,
    this.position = LoopRowPosition.single,
    this.semanticLabel,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;

  /// Mono value on the right (`.row-end .v`).
  final String? trailing;

  /// Small delta/status under the value (`.row-end .d`).
  final String? trailingCaption;

  /// null: neutral (text3); true: `.up` Lime; false: `.down` Chalk.
  final bool? trailingCaptionUp;

  /// `.row .badge`: a status pill instead of a mono figure. A row that carries
  /// a state rather than a number uses this so the value column is never read
  /// as data.
  final Widget? trailingBadge;
  final VoidCallback? onTap;
  final LoopRowPosition position;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topRadius =
        position == LoopRowPosition.first || position == LoopRowPosition.single;
    final bottomRadius =
        position == LoopRowPosition.last || position == LoopRowPosition.single;
    final radius = BorderRadius.vertical(
      top: topRadius
          ? const Radius.circular(LoopRadius.cardValue)
          : Radius.zero,
      bottom: bottomRadius
          ? const Radius.circular(LoopRadius.cardValue)
          : Radius.zero,
    );
    final content = Container(
      constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
      child: Row(
        children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (trailingBadge != null) ...<Widget>[
            const SizedBox(width: 10),
            trailingBadge!,
          ],
          if (trailing != null || trailingCaption != null) ...<Widget>[
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (trailing != null)
                  Text(trailing!, style: LoopTypography.figure(13)),
                if (trailingCaption != null)
                  Text(
                    trailingCaption!,
                    style: LoopTypography.figure(
                      11,
                      color: switch (trailingCaptionUp) {
                        true => LoopColors.lime,
                        false => LoopColors.chalk,
                        null => LoopColors.text3,
                      },
                    ),
                  ),
              ],
            ),
          ],
          if (onTap != null) ...<Widget>[
            const SizedBox(width: 8),
            const LoopIcon('chevron', size: 15, color: LoopColors.text3),
          ],
        ],
      ),
    );
    // Light top edge (first) and separator (not last) are drawn as rows so
    // the rounded decoration keeps a uniform border.
    final row = Container(
      decoration: BoxDecoration(
        color: LoopColors.chalk.withValues(alpha: 0.045),
        borderRadius: radius,
        boxShadow: bottomRadius
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66050604),
                  offset: Offset(0, 8),
                  blurRadius: 22,
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (topRadius) Container(height: 1, color: LoopDepth.liftCardEdge),
          content,
          if (!bottomRadius)
            Container(
              height: 1,
              color: LoopColors.chalk.withValues(alpha: 0.1),
            ),
        ],
      ),
    );
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: row,
    );
    if (onTap == null) return padded;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          highlightColor: LoopColors.card2,
          child: padded,
        ),
      ),
    );
  }
}

/// Lays out [rows] as one grouped card by assigning [LoopRowPosition].
class LoopRecordGroup extends StatelessWidget {
  const LoopRecordGroup({required this.rows, super.key});

  final List<LoopRecordRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var index = 0; index < rows.length; index++)
          LoopRecordRow(
            key: rows[index].key,
            leading: rows[index].leading,
            title: rows[index].title,
            subtitle: rows[index].subtitle,
            trailing: rows[index].trailing,
            trailingCaption: rows[index].trailingCaption,
            trailingCaptionUp: rows[index].trailingCaptionUp,
            trailingBadge: rows[index].trailingBadge,
            onTap: rows[index].onTap,
            semanticLabel: rows[index].semanticLabel,
            position: rows.length == 1
                ? LoopRowPosition.single
                : index == 0
                ? LoopRowPosition.first
                : index == rows.length - 1
                ? LoopRowPosition.last
                : LoopRowPosition.middle,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notice (.notice / .notice-warn / .notice-danger)
// ---------------------------------------------------------------------------

enum LoopNoticeTone { normal, warn, danger }

/// `.notice`: icon + bold title + body. Risk notices must say what happened,
/// what it affects and what to do next — use [LoopNotice.structured].
class LoopNotice extends StatelessWidget {
  const LoopNotice({
    required this.body,
    super.key,
    this.title,
    this.icon = 'info',
    this.tone = LoopNoticeTone.normal,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
    this.chalk = false,
    this.trailing,
  }) : happened = null,
       impact = null,
       next = null;

  const LoopNotice.structured({
    required String this.happened,
    required String this.impact,
    required String this.next,
    super.key,
    this.title,
    this.icon = 'warn',
    this.tone = LoopNoticeTone.warn,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
    this.chalk = false,
    this.trailing,
  }) : body = null;

  final String? title;
  final String? body;
  final String? happened;
  final String? impact;
  final String? next;
  final String icon;
  final LoopNoticeTone tone;
  final EdgeInsets margin;

  /// `.notice.chalk-card`.
  final bool chalk;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final (background, border) = chalk
        ? (LoopColors.chalk, Colors.transparent)
        : switch (tone) {
            LoopNoticeTone.normal => (LoopColors.card, LoopColors.line),
            LoopNoticeTone.warn => (LoopColors.limeSoft, Colors.transparent),
            LoopNoticeTone.danger => (LoopColors.card2, LoopColors.line2),
          };
    final foreground = chalk ? LoopColors.ink : LoopColors.chalk;
    final bodyStyle = LoopTypography.caption(11, color: foreground);
    final structured = happened != null;
    final label = <String?>[
      title,
      body,
      if (structured) '发生了什么：$happened',
      if (structured) '影响什么：$impact',
      if (structured) '下一步：$next',
    ].whereType<String>().join('。');
    return Padding(
      padding: margin,
      child: Semantics(
        container: true,
        label: label,
        child: ExcludeSemantics(
          child: Container(
            key: ValueKey<String>('loop-notice-${tone.name}'),
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: LoopIcon(icon, size: 17, color: foreground),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (title != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            title!,
                            style: LoopTypography.withWeight(
                              bodyStyle,
                              FontWeight.w700,
                            ),
                          ),
                        ),
                      if (body != null) Text(body!, style: bodyStyle),
                      if (structured) ...<Widget>[
                        _NoticeSegment(
                          label: '发生了什么',
                          text: happened!,
                          style: bodyStyle,
                        ),
                        _NoticeSegment(
                          label: '影响什么',
                          text: impact!,
                          style: bodyStyle,
                        ),
                        _NoticeSegment(
                          label: '下一步',
                          text: next!,
                          style: bodyStyle,
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 10),
                  ?trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeSegment extends StatelessWidget {
  const _NoticeSegment({
    required this.label,
    required this.text,
    required this.style,
  });

  final String label;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label ',
            style: LoopTypography.withWeight(style, FontWeight.w700),
          ),
          TextSpan(text: text),
        ],
      ),
      style: style,
    );
  }
}

// ---------------------------------------------------------------------------
// Badge (.badge) and Seg (.seg / .segs)
// ---------------------------------------------------------------------------

enum LoopBadgeKind { mining, launch, up, down, mute }

/// `.badge`: status only, never an action. Lime-soft for mining/launch/up,
/// Card2 for down/mute.
class LoopBadge extends StatelessWidget {
  const LoopBadge(
    this.text, {
    super.key,
    this.kind = LoopBadgeKind.mute,
    this.onLedger = false,
  });

  final String text;
  final LoopBadgeKind kind;

  /// `.ledger-card .badge`: Ink 12% ground, Ink text.
  final bool onLedger;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = onLedger
        ? (LoopColors.ink.withValues(alpha: 0.12), LoopColors.ink)
        : switch (kind) {
            LoopBadgeKind.mining ||
            LoopBadgeKind.launch ||
            LoopBadgeKind.up => (LoopColors.limeSoft, LoopColors.lime),
            LoopBadgeKind.down ||
            LoopBadgeKind.mute => (LoopColors.card2, LoopColors.text2),
          };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: LoopTypography.label(
          12,
          weight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// `.seg`: peer filter chip, 44px minimum, Lime when selected.
class LoopSeg extends StatelessWidget {
  const LoopSeg({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      enabled: onSelected != null,
      child: Material(
        color: selected ? LoopColors.lime : LoopColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? LoopColors.lime : LoopColors.line),
        ),
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: LoopTouch.minimum,
              minHeight: LoopTouch.minimum,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            alignment: Alignment.center,
            child: ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                // `.seg{font-size:11px;font-weight:600}` / `.seg.on{700}` —
                // the selected chip is the only one that goes bold.
                style: LoopTypography.label(
                  12,
                  weight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? LoopColors.ink : LoopColors.text2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.segs`: horizontal, scrollable seg row with 7px gaps and 16px gutters.
class LoopSegBar extends StatelessWidget {
  const LoopSegBar({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < labels.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 7),
            LoopSeg(
              label: labels[index],
              selected: index == selectedIndex,
              onSelected: () => onSelected(index),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons (.btn / .btn-primary / .btn-block / .btn-pair)
// ---------------------------------------------------------------------------

/// `.btn` (Card2 ground, Line2 border) and `.btn-primary` (Lime gradient with
/// glow). 53px minimum height, disabled at 40% opacity with the exact
/// disabled semantics.
class LoopButton extends StatelessWidget {
  const LoopButton({
    required this.label,
    super.key,
    this.onPressed,
    this.primary = false,
    this.block = false,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  /// `.btn-block`: full width.
  final bool block;
  final String? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = primary ? LoopColors.ink : LoopColors.chalk;
    final decoration = primary
        ? const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[LoopColors.limeHighlight, LoopColors.lime],
              stops: <double>[0, 0.62],
            ),
            borderRadius: BorderRadius.all(Radius.circular(14)),
            border: Border.fromBorderSide(BorderSide(color: LoopColors.lime)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Color(0x3DB8FF20),
                offset: Offset(0, 8),
                blurRadius: 22,
              ),
              BoxShadow(
                color: Color(0x66050604),
                offset: Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          )
        : const BoxDecoration(
            color: LoopColors.card2,
            borderRadius: BorderRadius.all(Radius.circular(14)),
            border: Border.fromBorderSide(BorderSide(color: LoopColors.line2)),
          );
    final child = Container(
      constraints: BoxConstraints(
        minHeight: LoopTouch.primaryButton,
        minWidth: block ? double.infinity : LoopTouch.minimum,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: decoration,
      child: Row(
        mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            LoopIcon(icon!, size: 17, color: foreground),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: LoopTypography.label(
                12,
                weight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: semanticLabel ?? label,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey<String>(
                'loop-button-${primary ? 'primary' : 'secondary'}',
              ),
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: ExcludeSemantics(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.btn-pair`: buttons share the row with 10px gaps and 16px gutters.
class LoopButtonPair extends StatelessWidget {
  const LoopButtonPair({required this.children, super.key, this.padded = true});

  final List<Widget> children;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padded ? LoopSpacing.page : 0),
      child: Row(
        children: <Widget>[
          for (var index = 0; index < children.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 10),
            Expanded(child: children[index]),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Key/value (.kv)
// ---------------------------------------------------------------------------

/// `.kv`: label (Text2) on the left, mono value on the right.
class LoopKeyValue extends StatelessWidget {
  const LoopKeyValue({
    required this.label,
    required this.value,
    super.key,
    this.valueUp,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  });

  final String label;
  final String value;

  /// true: `.up` Lime; false: `.down` Chalk; null: default.
  final bool? valueUp;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: LoopTypography.caption(11, color: LoopColors.text2),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: LoopTypography.figure(
                11,
                weight: FontWeight.w500,
                color: switch (valueUp) {
                  true => LoopColors.lime,
                  false => LoopColors.chalk,
                  null => LoopColors.chalk,
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Composer (.composer)
// ---------------------------------------------------------------------------

/// `.composer`: chat input pinned under the stream, never covered by the bar.
class LoopComposer extends StatefulWidget {
  const LoopComposer({
    super.key,
    this.controller,
    this.hintText = '发送消息',
    this.onSend,
    this.enabled = true,
    this.sendLabel = '发送',
    this.leading,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onSend;
  final bool enabled;
  final String sendLabel;
  final Widget? leading;

  @override
  State<LoopComposer> createState() => _LoopComposerState();
}

class _LoopComposerState extends State<LoopComposer> {
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  bool get _canSend => widget.enabled && widget.onSend != null;

  void _send() {
    if (!_canSend) return;
    widget.onSend!(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, math.max(10, safeBottom)),
      decoration: const BoxDecoration(
        color: LoopColors.ink,
        border: Border(top: BorderSide(color: LoopColors.line)),
      ),
      child: Row(
        children: <Widget>[
          if (widget.leading != null) ...<Widget>[
            widget.leading!,
            const SizedBox(width: 9),
          ],
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 43),
              child: TextField(
                key: const ValueKey<String>('loop-composer-input'),
                controller: _controller,
                enabled: _canSend,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: LoopTypography.caption(11),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  isDense: true,
                  filled: true,
                  fillColor: LoopColors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: LoopColors.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: LoopColors.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: LoopColors.lime),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: LoopColors.line),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Semantics(
            button: true,
            label: widget.sendLabel,
            enabled: _canSend,
            child: Material(
              color: _canSend ? LoopColors.lime : LoopColors.card2,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                key: const ValueKey<String>('loop-composer-send'),
                onTap: _canSend ? _send : null,
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: LoopTouch.minimum,
                  height: LoopTouch.minimum,
                  child: Center(
                    child: LoopIcon(
                      'arrow-up',
                      size: 17,
                      color: _canSend ? LoopColors.ink : LoopColors.text3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Power hint (.power-hint)
// ---------------------------------------------------------------------------

enum LoopPowerHintState { active, none, pending }

/// `.power-hint`: the "buy → mining power" loop hint on Wallet, Asset, Swap
/// and Tx Result. `none`/`pending` fall back to the Card ground.
class LoopPowerHint extends StatelessWidget {
  const LoopPowerHint({
    required this.text,
    super.key,
    this.figure,
    this.state = LoopPowerHintState.active,
    this.onTap,
  });

  final String text;

  /// Mono figure emphasised inside the hint (`b`).
  final String? figure;
  final LoopPowerHintState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = state == LoopPowerHintState.active;
    final foreground = active ? LoopColors.chalk : LoopColors.text3;
    final accent = active ? LoopColors.lime : LoopColors.text3;
    final content = Container(
      constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: active ? LoopColors.limeSoft : LoopColors.card,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: <Widget>[
          LoopIcon('mine', size: 17, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: text),
                  if (figure != null)
                    TextSpan(
                      text: ' $figure',
                      style: LoopTypography.figure(11, color: accent),
                    ),
                ],
              ),
              style: LoopTypography.caption(11, color: foreground),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: onTap == null
          ? Semantics(container: true, child: content)
          : Semantics(
              button: true,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(15),
                  child: content,
                ),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton (.sk / .sk-row / .sk-circle)
// ---------------------------------------------------------------------------

enum LoopSkeletonType {
  list,
  detail,
  chart,

  /// One or more inline list rows, without the list block's own page padding.
  row,

  /// One card-shaped placeholder: label line, figure line, meta line.
  card,

  /// One figure block: the number, then its caption.
  figure,
}

/// `.sk`: Card2 block, radius 8, 1.4s opacity pulse to 45% (static under
/// reduced motion). Skeletons keep the final layout and claim nothing.
class LoopSkeletonBlock extends StatefulWidget {
  const LoopSkeletonBlock({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 8,
    this.widthFactor,
  });

  final double? width;
  final double height;
  final double radius;

  /// Fraction of the available width (`width:42%`).
  final double? widthFactor;

  @override
  State<LoopSkeletonBlock> createState() => _LoopSkeletonBlockState();
}

class _LoopSkeletonBlockState extends State<LoopSkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // 0 → 1 → 0 over the cycle, dipping to 45% at the midpoint.
        final t = _controller.value;
        final dip = 1 - 0.55 * math.sin(t * math.pi);
        return Opacity(opacity: dip, child: child);
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: LoopColors.card2,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
    if (widget.widthFactor == null) return block;
    return FractionallySizedBox(
      widthFactor: widget.widthFactor,
      alignment: Alignment.centerLeft,
      child: block,
    );
  }
}

/// The prototype skeleton layouts (`skeleton-states`) plus the three inline
/// shapes a single block loads with.
///
/// A skeleton draws the layout that is about to arrive and nothing else: a
/// list loads as rows, a card as a card, a figure as a figure. A block never
/// borrows the whole page's shape, so nothing jumps when the data lands.
class LoopSkeleton extends StatelessWidget {
  const LoopSkeleton({required this.type, super.key, this.rows = 3});

  /// Inline list rows, for a block that already sits inside page padding.
  const LoopSkeleton.row({Key? key, int rows = 3})
    : this(type: LoopSkeletonType.row, rows: rows, key: key);

  /// One card-shaped placeholder.
  const LoopSkeleton.card({Key? key})
    : this(type: LoopSkeletonType.card, key: key);

  /// One figure-shaped placeholder (balance, count, price).
  const LoopSkeleton.figure({Key? key})
    : this(type: LoopSkeletonType.figure, key: key);

  final LoopSkeletonType type;

  /// List rows; bounded to 1..8 like the existing presentation contract.
  final int rows;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      LoopSkeletonType.list || LoopSkeletonType.row => '列表加载中',
      LoopSkeletonType.detail => '详情加载中',
      LoopSkeletonType.chart => '图表加载中',
      LoopSkeletonType.card => '卡片加载中',
      LoopSkeletonType.figure => '数字加载中',
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: switch (type) {
          LoopSkeletonType.list => Column(
            key: const ValueKey<String>('loop-skeleton-list'),
            children: <Widget>[
              for (var index = 0; index < rows.clamp(1, 8); index++)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: <Widget>[
                      const LoopSkeletonBlock(
                        width: 44,
                        height: 44,
                        radius: 15,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            LoopSkeletonBlock(
                              height: 13,
                              widthFactor: <double>[0.4, 0.52, 0.34][index % 3],
                            ),
                            const SizedBox(height: 6),
                            LoopSkeletonBlock(
                              height: 11,
                              widthFactor: <double>[0.65, 0.48, 0.7][index % 3],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          LoopSkeletonType.detail => Padding(
            key: const ValueKey<String>('loop-skeleton-detail'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const LoopSkeletonBlock(height: 34, widthFactor: 0.56),
                const SizedBox(height: 8),
                const LoopSkeletonBlock(height: 12, widthFactor: 0.34),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.6,
                  children: const <Widget>[
                    LoopSkeletonBlock(height: 62),
                    LoopSkeletonBlock(height: 62),
                    LoopSkeletonBlock(height: 62),
                    LoopSkeletonBlock(height: 62),
                  ],
                ),
              ],
            ),
          ),
          LoopSkeletonType.chart => Padding(
            key: const ValueKey<String>('loop-skeleton-chart'),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                LoopSkeletonBlock(height: 150),
                SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    LoopSkeletonBlock(width: 52, height: 30),
                    SizedBox(width: 6),
                    LoopSkeletonBlock(width: 52, height: 30),
                    SizedBox(width: 6),
                    LoopSkeletonBlock(width: 52, height: 30),
                  ],
                ),
              ],
            ),
          ),
          // The inline shapes carry no page padding: the block that owns them
          // already has its own.
          LoopSkeletonType.row => Column(
            key: const ValueKey<String>('loop-skeleton-row'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var index = 0; index < rows.clamp(1, 8); index++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: LoopSkeletonBlock(
                          height: 12,
                          widthFactor: <double>[0.46, 0.58, 0.38][index % 3],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const LoopSkeletonBlock(width: 46, height: 12),
                    ],
                  ),
                ),
            ],
          ),
          LoopSkeletonType.card => Container(
            key: const ValueKey<String>('loop-skeleton-card'),
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
            decoration: BoxDecoration(
              color: LoopColors.card,
              borderRadius: LoopRadius.control,
              border: Border.all(color: LoopColors.line),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LoopSkeletonBlock(height: 10, widthFactor: 0.28),
                SizedBox(height: 10),
                LoopSkeletonBlock(height: 20, widthFactor: 0.54),
                SizedBox(height: 10),
                LoopSkeletonBlock(height: 10, widthFactor: 0.4),
              ],
            ),
          ),
          LoopSkeletonType.figure => const Column(
            key: ValueKey<String>('loop-skeleton-figure'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LoopSkeletonBlock(height: 24, widthFactor: 0.42),
              SizedBox(height: 6),
              LoopSkeletonBlock(height: 10, widthFactor: 0.24),
            ],
          ),
        },
      ),
    );
  }
}

/// The corner mark a block wears while it re-reads data it already has.
///
/// A refresh is not a load: the block keeps the values it read last time and
/// says only that a newer answer is on the way. It never covers content,
/// never disables an action and never claims the new answer arrived.
class LoopUpdatingBadge extends StatelessWidget {
  const LoopUpdatingBadge({super.key, this.visible = true, this.label = '更新中'});

  final bool visible;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: LoopBadge(
          label,
          key: const ValueKey<String>('loop-updating-badge'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty and recovery states (.empty + chapter 9 contract)
// ---------------------------------------------------------------------------

/// `.empty` (S16-C): an inline strip, not a framed panel.
///
/// A missing collection is a sentence, not a room. The block is one 17px
/// Text3 glyph, one line of copy, an optional second line and an optional
/// action; its height follows its content, it draws no border and it claims
/// no vertical space it does not use. The 190 call sites keep their existing
/// arguments and the `loop-empty` key: only the presentation changed.
///
/// Whole-page unavailability is a different job — use [LoopPageBlock].
class LoopEmpty extends StatelessWidget {
  const LoopEmpty({
    required this.message,
    super.key,
    this.icon = 'info',
    this.reason,
    this.action,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.iconSize = compactIconSize,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
  });

  /// `.ico-sm` — the inline glyph size for a state strip.
  static const double compactIconSize = 17;

  final String message;
  final String icon;

  /// Why the collection is empty (never "0" for figures — use `—`).
  final String? reason;
  final Widget? action;
  final EdgeInsets margin;

  /// Kept inside the prototype's inline glyph range (`.ico-xs`..`.ico`).
  final double iconSize;

  /// Inner padding. It stays small on purpose; a state strip is a line of
  /// copy, so nothing here reserves a panel's worth of space.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    assert(
      iconSize >= 15 && iconSize <= 20,
      'LoopEmpty keeps the inline glyph between 15 and 20 px.',
    );
    final copy = LoopTypography.caption(11);
    return Padding(
      padding: margin,
      child: Semantics(
        container: true,
        child: Padding(
          key: const ValueKey<String>('loop-empty'),
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                // Optical alignment with the first text line.
                padding: const EdgeInsets.only(top: 1),
                child: LoopIcon(
                  icon,
                  size: iconSize,
                  color: LoopColors.text3,
                  semanticLabel: message,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(message, style: copy),
                    if (reason != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(reason!, style: copy),
                    ],
                    if (action != null) ...<Widget>[
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: action!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The whole-page counterpart of [LoopEmpty].
///
/// A page that has nothing to show is the one place that earns the room: the
/// brand mark, one heading, one explanation and at most one next step,
/// centred in the space the page already owns. Blocks inside a page never
/// use it — they use [LoopEmpty].
class LoopPageBlock extends StatelessWidget {
  const LoopPageBlock({
    required this.title,
    required this.message,
    super.key,
    this.action,
    this.margin = const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
  });

  /// The one whole-page state that carries no server reason, because the
  /// client never reached LOOP.
  ///
  /// "LOOP did not answer" and "LOOP answered that a provider is down" are two
  /// different facts with two different next steps — change network and try
  /// again, versus wait, because nothing on this device can change it. They
  /// never share a sentence and are never derived from one another.
  const LoopPageBlock.unreachable({Key? key, Widget? action})
    : this(
        title: unreachableTitle,
        message: unreachableMessage,
        action: action,
        key: key,
      );

  /// Heading for [LoopPageBlock.unreachable].
  static const String unreachableTitle = '现在连不上 LOOP';

  /// Body for [LoopPageBlock.unreachable]. It names no provider and no rule,
  /// because none was received.
  static const String unreachableMessage = '这一页没有读到任何内容，也没有提交任何操作。请检查网络后重试。';

  final String title;
  final String message;
  final Widget? action;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Center(
        key: const ValueKey<String>('loop-page-block'),
        child: Padding(
          padding: margin,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const LoopBrandMark(
                  kind: LoopBrandMarkKind.appIcon,
                  height: 40,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: LoopTypography.caption(11, color: LoopColors.text3),
                ),
                if (action != null) ...<Widget>[
                  const SizedBox(height: 18),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chapter 9 Error: identifiable reason, trace id / source, retry and an
/// alternative path. Local failures never clear already loaded content.
class LoopErrorState extends StatelessWidget {
  const LoopErrorState({
    required this.reason,
    super.key,
    this.title = '暂时无法完成',
    this.traceId,
    this.source,
    this.onRetry,
    this.retryLabel = '重试',
    this.alternative,
    this.alternativeLabel,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String title;
  final String reason;
  final String? traceId;
  final String? source;
  final VoidCallback? onRetry;
  final String retryLabel;
  final VoidCallback? alternative;
  final String? alternativeLabel;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: LoopSurfaceCard(
          key: const ValueKey<String>('loop-error-state'),
          background: LoopColors.card2,
          borderColor: LoopColors.line2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const LoopIcon('warn', size: 17),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(reason, style: Theme.of(context).textTheme.bodyMedium),
              if (traceId != null || source != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  <String>[
                    if (traceId != null) '追踪号 $traceId',
                    if (source != null) '来源 $source',
                  ].join(' · '),
                  style: LoopMono.stamp,
                ),
              ],
              if (onRetry != null || alternative != null) ...<Widget>[
                const SizedBox(height: 12),
                LoopButtonPair(
                  padded: false,
                  children: <Widget>[
                    if (alternative != null)
                      LoopButton(
                        label: alternativeLabel ?? '其他方式',
                        onPressed: alternative,
                      ),
                    if (onRetry != null)
                      LoopButton(
                        label: retryLabel,
                        primary: true,
                        onPressed: onRetry,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chapter 9 Offline: shows the cache time and which actions are paused.
class LoopOfflineState extends StatelessWidget {
  const LoopOfflineState({
    super.key,
    this.cachedAtLabel,
    this.pausedActions = const <String>['发送', '兑换', '跨链', '签名'],
    this.onRetry,
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  });

  /// Formatted last-sync time supplied by the owner; null renders `—`.
  final String? cachedAtLabel;
  final List<String> pausedActions;
  final VoidCallback? onRetry;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          key: const ValueKey<String>('loop-offline-state'),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: LoopColors.card2,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: LoopColors.line2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const LoopIcon('offline', size: 17),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '离线 · 显示缓存',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text('缓存 ${cachedAtLabel ?? '—'}', style: LoopMono.stamp),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '已暂停：${pausedActions.join('、')}。缓存值可能已过期。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (onRetry != null) ...<Widget>[
                const SizedBox(height: 12),
                LoopButton(label: '重试连接', onPressed: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chapter 9 Permission: explain purpose, trigger and data scope before the
/// request; after a denial offer the settings path without hiding data.
class LoopPermissionState extends StatelessWidget {
  const LoopPermissionState({
    required this.title,
    required this.purpose,
    super.key,
    this.icon = 'bell',
    this.denied = false,
    this.onRequest,
    this.onOpenSettings,
    this.requestLabel = '继续',
    this.settingsLabel = '前往系统设置',
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  });

  final String title;
  final String purpose;
  final String icon;
  final bool denied;
  final VoidCallback? onRequest;
  final VoidCallback? onOpenSettings;
  final String requestLabel;
  final String settingsLabel;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LoopNotice(
          key: const ValueKey<String>('loop-permission-state'),
          icon: denied ? 'warn' : icon,
          tone: denied ? LoopNoticeTone.warn : LoopNoticeTone.normal,
          title: title,
          body: purpose,
          margin: margin,
        ),
        if (denied && onOpenSettings != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: LoopButton(
              label: settingsLabel,
              block: true,
              onPressed: onOpenSettings,
            ),
          )
        else if (!denied && onRequest != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: LoopButton(
              label: requestLabel,
              block: true,
              primary: true,
              onPressed: onRequest,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Disclosure (.focus-disclosure)
// ---------------------------------------------------------------------------

/// `.focus-disclosure`: supplementary copy on focus pages, collapsed by
/// default, 44px summary with a Lime `+`/`−`.
class LoopDisclosure extends StatefulWidget {
  const LoopDisclosure({
    required this.summary,
    required this.child,
    super.key,
    this.initiallyOpen = false,
  });

  final String summary;
  final Widget child;
  final bool initiallyOpen;

  @override
  State<LoopDisclosure> createState() => _LoopDisclosureState();
}

class _LoopDisclosureState extends State<LoopDisclosure> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: LoopColors.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: LoopColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: _open,
            label: widget.summary,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey<String>('loop-disclosure-summary'),
                onTap: () => setState(() => _open = !_open),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: LoopTouch.minimum,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ExcludeSemantics(
                          child: Text(
                            widget.summary,
                            style: LoopTypography.label(
                              12,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      ExcludeSemantics(
                        child: Text(
                          _open ? '−' : '+',
                          style: LoopTypography.figure(
                            17,
                            height: 1.15,
                            color: LoopColors.lime,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_open) widget.child,
        ],
      ),
    );
  }
}
