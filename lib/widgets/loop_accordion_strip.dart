import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// The state dot a strip carries.
enum LoopAccordionDot {
  /// Happening now: Lime.
  live,

  /// Not yet: the ground's secondary ink.
  upcoming,

  /// Over, or nothing to say: the ground's auxiliary ink.
  idle,
}

/// How a strip's surface reads (decision 0100).
enum LoopAccordionTone {
  /// Happening now: a Lime edge on a soft Lime ground.
  live,

  /// Not yet: an outline on no ground of its own.
  upcoming,

  /// Over: greyscale — tint ground, hairline edge, auxiliary ink.
  ended,

  /// No state to state: the tint ground of decision 0096.
  neutral,
}

/// One strip of a [LoopAccordionStrip].
@immutable
class LoopAccordionItem {
  const LoopAccordionItem({
    required this.id,
    required this.shortTitle,
    required this.semanticLabel,
    required this.detail,
    this.dot = LoopAccordionDot.idle,
    this.tone,
    this.stateLabel,
    this.progress,
    this.badge,
    this.footer,
  });

  /// Stable identifier; the strip's key is `<keyPrefix>-strip-<id>` and the
  /// open detail's `<keyPrefix>-detail-<id>`.
  final String id;

  /// What a narrow strip shows: an abbreviation (`R1`, `END`), never a
  /// sentence.
  final String shortTitle;

  /// What a screen reader hears for the strip; the expanded state is added.
  final String semanticLabel;

  /// The open strip's content, laid out at the open width.
  final Widget detail;

  final LoopAccordionDot dot;

  /// The strip's surface; `null` follows [dot] (live → live, upcoming →
  /// upcoming, idle → neutral).
  final LoopAccordionTone? tone;

  /// The word a narrow strip reads upright, one character per line
  /// (「进行中」, 「毕业」).
  /// Screen readers hear [semanticLabel] instead.
  final String? stateLabel;

  /// A narrow strip's vertical bar, filled from the bottom; `null` draws none.
  final double? progress;

  /// Drawn at the right of the title line while the strip is open, in place
  /// of the dot.
  final Widget? badge;

  /// A thin information line pinned to the bottom of the open strip, laid out
  /// at the open width like [detail].
  final Widget? footer;

  LoopAccordionTone get resolvedTone =>
      tone ??
      switch (dot) {
        LoopAccordionDot.live => LoopAccordionTone.live,
        LoopAccordionDot.upcoming => LoopAccordionTone.upcoming,
        LoopAccordionDot.idle => LoopAccordionTone.neutral,
      };
}

/// A row of equal narrow strips; tapping one widens it and narrows the rest
/// (decision 0096).
///
/// Closed, every strip takes `1/N` of the width and shows its
/// [LoopAccordionItem.shortTitle], a state dot, its [LoopAccordionItem
/// .stateLabel] along the long edge and a vertical progress bar. A tap opens
/// that strip to a weight of [LoopMotion.accordionOpenWeight] against 1 for
/// each other strip over [LoopMotion.accordionExpand]; its detail fades in
/// from [LoopMotion.accordionFadeStart] of the same controller. A tap on the
/// open strip returns the row to equal widths. With motion reduced every
/// change is one frame.
///
/// The row is as tall as the open strip's content (decision 0100), never less
/// than [minHeight]; between two open strips the height follows the same
/// curve as the widths. Each strip's natural open height is measured by
/// laying its content out, unpainted, at the open width.
///
/// The detail is laid out once, at the width the open strip ends at, and
/// clipped by the strip while it grows, so the text never reflows mid-motion.
///
/// A horizontal row cannot hold large type or a narrow screen: from a text
/// scale of [maxTextScale], below a screen width of [minScreenWidth], or when
/// the open strip would be narrower than [minOpenWidth], the component builds
/// [fallback] instead — the same facts as a vertical list.
class LoopAccordionStrip extends StatefulWidget {
  const LoopAccordionStrip({
    required this.items,
    required this.fallback,
    required this.minHeight,
    super.key,
    this.initialIndex,
    this.keyPrefix = 'loop-accordion',
    this.rowKey,
    this.margin = EdgeInsets.zero,
    this.onChanged,
  });

  /// Text scale from which the row gives way to [fallback].
  static const double maxTextScale = 1.3;

  /// Screen width below which the row gives way to [fallback].
  static const double minScreenWidth = 360;

  /// The narrowest an open strip may be before the row gives way.
  static const double minOpenWidth = 132;

  /// The gap between two strips.
  static const double gap = 6;

  /// The inner padding of a strip.
  static const double padding = 10;

  /// The strip's edge. [Ink] insets its child by the decoration's padding,
  /// so the edge is part of what the detail loses on each side.
  static const double border = 1;

  /// The title line: the short title and the dot, or the badge when open.
  static const double titleHeight = 24;

  /// The gap between two lines of a narrow strip's upright state word.
  static const double wordGap = 2;

  /// A narrow strip's vertical progress bar.
  static const double barWidth = 4;
  static const double barHeight = 40;

  final List<LoopAccordionItem> items;

  /// The vertical rendering of the same facts.
  final Widget fallback;

  /// The row's least height at a text scale of 1; it grows with the text
  /// scale. The open strip's content decides the rest.
  final double minHeight;

  /// The strip open on the first frame; `null` starts with equal widths.
  final int? initialIndex;

  final String keyPrefix;

  /// The row's key; defaults to `<keyPrefix>-row`. A caller whose [fallback]
  /// carries a key of its own can give the row the same one, since only one
  /// of the two is ever built.
  final Key? rowKey;

  /// Space around the row. [fallback] is built without it: a list draws its
  /// own margins.
  final EdgeInsets margin;

  /// Called with the open strip after a tap, or `null` when all are closed.
  final ValueChanged<int?>? onChanged;

  /// Whether a row of [count] strips fits [context] at [width].
  static bool fits(BuildContext context, double width, int count) {
    if (count <= 0) return false;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    if (scale >= maxTextScale) return false;
    if (MediaQuery.sizeOf(context).width < minScreenWidth) return false;
    return openWidthFor(width, count) >= minOpenWidth;
  }

  /// The open strip's width in a row [width] wide of [count] strips.
  static double openWidthFor(double width, int count) {
    final inner = width - gap * (count - 1);
    final weight = LoopMotion.accordionOpenWeight;
    return inner * weight / (weight + count - 1);
  }

  /// The width an open strip leaves its detail: the open width less the edge
  /// and the padding on both sides.
  static double detailWidthFor(double openWidth) =>
      math.max(0, openWidth - (padding + border) * 2);

  @override
  State<LoopAccordionStrip> createState() => _LoopAccordionStripState();
}

class _LoopAccordionStripState extends State<LoopAccordionStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LoopMotion.accordionExpand,
    value: 1,
  );

  /// The opening strip's detail: in over the back part of the motion.
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(
      LoopMotion.accordionFadeStart,
      1,
      curve: Curves.easeOut,
    ),
  );

  /// A closing strip's detail: out by the point the new one starts.
  late final Animation<double> _fadeOut = ReverseAnimation(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, LoopMotion.accordionFadeStart),
    ),
  );

  static const Animation<double> _shown = AlwaysStoppedAnimation<double>(1);

  late int? _open = _validIndex(widget.initialIndex);

  /// Each strip's openness (0 closed, 1 open) when the current motion began.
  late List<double> _from = _targets(_open);

  int? _validIndex(int? index) =>
      index != null && index >= 0 && index < widget.items.length ? index : null;

  List<double> _targets(int? open) => <double>[
    for (var index = 0; index < widget.items.length; index += 1)
      index == open ? 1 : 0,
  ];

  double get _t => LoopMotion.accordionCurve.transform(_controller.value);

  /// Strip [index]'s openness at this frame.
  double _openness(int index) {
    final to = index == _open ? 1.0 : 0.0;
    final from = index < _from.length ? _from[index] : 0.0;
    return lerpDouble(from, to, _t)!;
  }

  /// Strip [index]'s detail opacity at this frame: the opening strip fades
  /// in over the back part of the motion, a closing one is gone by the same
  /// point.
  Animation<double> _detailFade(int index) {
    if (index == _open) {
      final wasOpen = index < _from.length && _from[index] >= 1;
      return wasOpen ? _shown : _fadeIn;
    }
    return _fadeOut;
  }

  double _detailOpacity(int index) {
    final raw = _controller.value;
    final start = LoopMotion.accordionFadeStart;
    if (index == _open) {
      final wasOpen = index < _from.length && _from[index] >= 1;
      if (wasOpen) return 1;
      return ((raw - start) / (1 - start)).clamp(0.0, 1.0);
    }
    final from = index < _from.length ? _from[index] : 0.0;
    if (from <= 0) return 0;
    return (from * (1 - raw / start)).clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(LoopAccordionStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _open = _validIndex(_open);
      _from = _targets(_open);
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(int index) {
    final next = _open == index ? null : index;
    setState(() {
      _from = <double>[
        for (var i = 0; i < widget.items.length; i += 1) _openness(i),
      ];
      _open = next;
    });
    if (LoopMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - widget.margin.horizontal;
        final count = widget.items.length;
        if (!LoopAccordionStrip.fits(context, width, count)) {
          return widget.fallback;
        }
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final minHeight = widget.minHeight * math.max(1.0, scale);
        final openWidth = LoopAccordionStrip.openWidthFor(width, count);
        // Built once per layout, outside the per-frame builder: the same
        // widget instances every frame, so the measurement is not rebuilt.
        final probes = <Widget>[
          for (final item in widget.items)
            SizedBox(
              width: openWidth,
              child: _OpenContentProbe(item: item, openWidth: openWidth),
            ),
        ];
        return Padding(
          padding: widget.margin,
          child: AnimatedBuilder(
            key: widget.rowKey ?? ValueKey<String>('${widget.keyPrefix}-row'),
            animation: _controller,
            builder: (context, _) {
              final openness = <double>[
                for (var index = 0; index < count; index += 1) _openness(index),
              ];
              final weights = <double>[
                for (final value in openness)
                  1 + (LoopMotion.accordionOpenWeight - 1) * value,
              ];
              final total = weights.fold<double>(0, (a, b) => a + b);
              final inner = width - LoopAccordionStrip.gap * (count - 1);
              return _AccordionBody(
                openness: openness,
                minHeight: minHeight,
                probeWidth: openWidth,
                row: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (var index = 0; index < count; index += 1) ...<Widget>[
                      if (index > 0)
                        const SizedBox(width: LoopAccordionStrip.gap),
                      SizedBox(
                        width: inner * weights[index] / total,
                        child: _Strip(
                          key: ValueKey<String>(
                            '${widget.keyPrefix}-strip-'
                            '${widget.items[index].id}',
                          ),
                          item: widget.items[index],
                          detailKey: ValueKey<String>(
                            '${widget.keyPrefix}-detail-'
                            '${widget.items[index].id}',
                          ),
                          open: index == _open,
                          openness: openness[index],
                          showDetail: _detailOpacity(index) > 0,
                          detailFade: _detailFade(index),
                          openWidth: openWidth,
                          onTap: () => _toggle(index),
                        ),
                      ),
                    ],
                  ],
                ),
                probes: probes,
              );
            },
          ),
        );
      },
    );
  }
}

/// The openness below which a narrow strip's own content is drawn: the point
/// on the width curve at which a closing strip's detail has faded out, so the
/// two never share a frame.
double get _collapsedThreshold =>
    1 - LoopMotion.accordionCurve.transform(LoopMotion.accordionFadeStart);

class _Strip extends StatelessWidget {
  const _Strip({
    required this.item,
    required this.detailKey,
    required this.open,
    required this.openness,
    required this.showDetail,
    required this.detailFade,
    required this.openWidth,
    required this.onTap,
    super.key,
  });

  final LoopAccordionItem item;
  final Key detailKey;
  final bool open;
  final double openness;
  final bool showDetail;
  final Animation<double> detailFade;
  final double openWidth;
  final VoidCallback onTap;

  double get _detailWidth => LoopAccordionStrip.detailWidthFor(openWidth);

  @override
  Widget build(BuildContext context) {
    final tone = item.resolvedTone;
    final (ground, edge) = _surface(context, tone, openness);
    final collapsedOpacity = showDetail
        ? 0.0
        : (1 - openness / _collapsedThreshold).clamp(0.0, 1.0);
    final footer = item.footer;
    return Semantics(
      button: true,
      expanded: open,
      label: item.semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: LoopRadius.control,
          child: Ink(
            decoration: BoxDecoration(
              color: ground,
              borderRadius: LoopRadius.control,
              border: Border.all(color: edge, width: LoopAccordionStrip.border),
            ),
            child: ClipRRect(
              borderRadius: LoopRadius.control,
              child: Padding(
                padding: const EdgeInsets.all(LoopAccordionStrip.padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TitleLine(
                      item: item,
                      tone: tone,
                      badgeFade: showDetail && item.badge != null
                          ? detailFade
                          : null,
                    ),
                    if (showDetail) ...<Widget>[
                      const SizedBox(height: 8),
                      Expanded(
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: 0,
                            maxWidth: _detailWidth,
                            minHeight: 0,
                            maxHeight: double.infinity,
                            child: FadeTransition(
                              key: detailKey,
                              opacity: detailFade,
                              child: SizedBox(
                                width: _detailWidth,
                                child: item.detail,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (footer != null)
                        ClipRect(
                          child: OverflowBox(
                            fit: OverflowBoxFit.deferToChild,
                            alignment: Alignment.bottomLeft,
                            minWidth: _detailWidth,
                            maxWidth: _detailWidth,
                            child: FadeTransition(
                              opacity: detailFade,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: footer,
                              ),
                            ),
                          ),
                        ),
                    ] else if (collapsedOpacity > 0)
                      Expanded(
                        // A transition, not a resting state: the value is
                        // strictly between 0 and 1 only while the strip
                        // moves, and it is 1 whenever the row is at rest.
                        child: FadeTransition(
                          opacity: AlwaysStoppedAnimation<double>(
                            collapsedOpacity,
                          ),
                          child: ExcludeSemantics(
                            child: _CollapsedContent(item: item, tone: tone),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The strip's ground and edge for [tone] at [openness].
  static (Color, Color) _surface(
    BuildContext context,
    LoopAccordionTone tone,
    double openness,
  ) => switch (tone) {
    LoopAccordionTone.live => (LoopColors.limeSoft, LoopColors.lime),
    LoopAccordionTone.upcoming => (
      Color.lerp(
        LoopGround.tintOf(context).withValues(alpha: 0),
        LoopGround.tintOf(context),
        openness,
      )!,
      LoopGround.edgeOf(context),
    ),
    LoopAccordionTone.ended || LoopAccordionTone.neutral => (
      Color.lerp(
        LoopGround.tintOf(context),
        LoopGround.fillOf(context),
        openness,
      )!,
      Color.lerp(
        LoopGround.hairlineOf(context),
        LoopGround.edgeOf(context),
        openness,
      )!,
    ),
  };
}

/// The ink of a strip's own words for [tone].
Color _inkFor(BuildContext context, LoopAccordionTone tone) => switch (tone) {
  LoopAccordionTone.live ||
  LoopAccordionTone.neutral => LoopGround.inkOf(context),
  LoopAccordionTone.upcoming => LoopGround.secondaryOf(context),
  LoopAccordionTone.ended => LoopGround.auxiliaryOf(context),
};

/// The top line of every strip: the short title and the dot, with the badge
/// at the right while the strip is open.
class _TitleLine extends StatelessWidget {
  const _TitleLine({required this.item, required this.tone, this.badgeFade});

  final LoopAccordionItem item;
  final LoopAccordionTone tone;

  /// Non-null while the badge is drawn, with the detail's own fade.
  final Animation<double>? badgeFade;

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (item.dot) {
      LoopAccordionDot.live => LoopColors.lime,
      LoopAccordionDot.upcoming => LoopGround.secondaryOf(context),
      LoopAccordionDot.idle => LoopGround.auxiliaryOf(context),
    };
    final fade = badgeFade;
    return SizedBox(
      height: LoopAccordionStrip.titleHeight,
      child: Row(
        children: <Widget>[
          Flexible(
            flex: fade == null ? 1 : 0,
            child: Text(
              item.shortTitle,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: LoopMono.label.copyWith(color: _inkFor(context, tone)),
            ),
          ),
          if (fade == null) ...<Widget>[
            const SizedBox(width: 6),
            DecoratedBox(
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 6),
            ),
          ] else ...<Widget>[
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FadeTransition(
                  opacity: fade,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: item.badge,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A narrow strip below its title: the state word along the long edge and
/// the vertical progress bar at the foot.
class _CollapsedContent extends StatelessWidget {
  const _CollapsedContent({required this.item, required this.tone});

  final LoopAccordionItem item;
  final LoopAccordionTone tone;

  @override
  Widget build(BuildContext context) {
    final label = item.stateLabel;
    final progress = item.progress;
    final wordColor = tone == LoopAccordionTone.live
        ? LoopColors.lime
        : _inkFor(context, tone);
    final barColor = switch (tone) {
      LoopAccordionTone.live => LoopColors.lime,
      LoopAccordionTone.ended => LoopGround.auxiliaryOf(context),
      LoopAccordionTone.upcoming ||
      LoopAccordionTone.neutral => LoopGround.secondaryOf(context),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 10),
        Expanded(
          child: label == null
              ? const SizedBox.shrink()
              : ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topLeft,
                    minWidth: 0,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: Column(
                      key: ValueKey<String>('loop-accordion-word-${item.id}'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final (index, run) in loopVerticalRuns(
                          label,
                        ).indexed) ...<Widget>[
                          if (index > 0)
                            const SizedBox(height: LoopAccordionStrip.wordGap),
                          Text(
                            run,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: LoopTypography.label(
                              12,
                              weight: FontWeight.w600,
                              color: wordColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        if (progress != null) ...<Widget>[
          const SizedBox(height: 8),
          LoopVerticalBar(
            key: ValueKey<String>('loop-accordion-bar-${item.id}'),
            value: progress,
            color: barColor,
          ),
        ],
      ],
    );
  }
}

/// The lines of an upright vertical word (S91 ruling): every Han character
/// on a line of its own, while a run of Latin letters or digits stays one
/// horizontal line (「R1」 is not split into 「R」 over 「1」). Spaces separate
/// runs and are dropped.
List<String> loopVerticalRuns(String text) {
  final runs = <String>[];
  final latin = StringBuffer();
  void flush() {
    if (latin.isNotEmpty) {
      runs.add(latin.toString());
      latin.clear();
    }
  }

  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (char.trim().isEmpty) {
      flush();
    } else if (rune < 0x80) {
      latin.write(char);
    } else {
      flush();
      runs.add(char);
    }
  }
  flush();
  return runs;
}

/// A thin vertical bar filled from the bottom: [value] of its height in
/// [color] on the ground's fill.
class LoopVerticalBar extends StatelessWidget {
  const LoopVerticalBar({required this.value, required this.color, super.key});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      child: Container(
        width: LoopAccordionStrip.barWidth,
        height: LoopAccordionStrip.barHeight,
        color: LoopGround.fillOf(context),
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: value.clamp(0.0, 1.0),
          widthFactor: 1,
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

/// What an open strip lays out, unpainted: its natural height at the open
/// width is the row's height while it is open.
class _OpenContentProbe extends StatelessWidget {
  const _OpenContentProbe({required this.item, required this.openWidth});

  final LoopAccordionItem item;
  final double openWidth;

  @override
  Widget build(BuildContext context) {
    final detailWidth = LoopAccordionStrip.detailWidthFor(openWidth);
    final footer = item.footer;
    return Padding(
      padding: const EdgeInsets.all(
        LoopAccordionStrip.padding + LoopAccordionStrip.border,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: LoopAccordionStrip.titleHeight + 8),
          SizedBox(width: detailWidth, child: item.detail),
          if (footer != null)
            SizedBox(
              width: detailWidth,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: footer,
              ),
            ),
        ],
      ),
    );
  }
}

/// The row of strips plus one unpainted probe per strip. The row's height is
/// the probes' heights weighted by each strip's openness.
class _AccordionBody extends MultiChildRenderObjectWidget {
  _AccordionBody({
    required Widget row,
    required List<Widget> probes,
    required this.openness,
    required this.minHeight,
    required this.probeWidth,
  }) : super(children: <Widget>[row, ...probes]);

  final List<double> openness;
  final double minHeight;
  final double probeWidth;

  @override
  MultiChildRenderObjectElement createElement() => _AccordionBodyElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAccordionBody(
    openness: openness,
    minHeight: minHeight,
    probeWidth: probeWidth,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderAccordionBody renderObject,
  ) {
    renderObject
      ..openness = openness
      ..minHeight = minHeight
      ..probeWidth = probeWidth;
  }
}

/// Finders see the row only: the probes are a measurement, not the page.
class _AccordionBodyElement extends MultiChildRenderObjectElement {
  _AccordionBodyElement(super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final first = children.isEmpty ? null : children.first;
    if (first != null) visitor(first);
  }
}

class _AccordionBodyParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderAccordionBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _AccordionBodyParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _AccordionBodyParentData> {
  _RenderAccordionBody({
    required this._openness,
    required this._minHeight,
    required this._probeWidth,
  });

  List<double> _openness;
  set openness(List<double> value) {
    if (listEquals(_openness, value)) return;
    _openness = value;
    markNeedsLayout();
  }

  double _minHeight;
  set minHeight(double value) {
    if (_minHeight == value) return;
    _minHeight = value;
    markNeedsLayout();
  }

  double _probeWidth;
  set probeWidth(double value) {
    if (_probeWidth == value) return;
    _probeWidth = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _AccordionBodyParentData) {
      child.parentData = _AccordionBodyParentData();
    }
  }

  RenderBox? get _row => firstChild;

  /// The height the row takes at [openness].
  double _heightFor(List<double> heights) {
    var sum = 0.0;
    var height = 0.0;
    for (var index = 0; index < heights.length; index += 1) {
      final open = index < _openness.length ? _openness[index] : 0.0;
      sum += open;
      height += open * math.max(_minHeight, heights[index]);
    }
    height += (1 - sum).clamp(0.0, 1.0) * _minHeight;
    return math.max(_minHeight, height);
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final heights = <double>[];
    var probe = _row == null ? null : childAfter(_row!);
    while (probe != null) {
      probe.layout(
        BoxConstraints(maxWidth: math.min(_probeWidth, width)),
        parentUsesSize: true,
      );
      heights.add(probe.size.height);
      probe = childAfter(probe);
    }
    final height = constraints.constrainHeight(_heightFor(heights));
    _row?.layout(BoxConstraints.tightFor(width: width, height: height));
    size = constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(Size(constraints.maxWidth, _minHeight));

  @override
  void paint(PaintingContext context, Offset offset) {
    final row = _row;
    if (row != null) context.paintChild(row, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final row = _row;
    if (row == null) return false;
    return row.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final row = _row;
    if (row != null) visitor(row);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    // Every child sits at the origin; the probes are never painted.
  }
}
