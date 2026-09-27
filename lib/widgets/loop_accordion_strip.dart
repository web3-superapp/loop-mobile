import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
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

/// One strip of a [LoopAccordionStrip].
@immutable
class LoopAccordionItem {
  const LoopAccordionItem({
    required this.id,
    required this.shortTitle,
    required this.semanticLabel,
    required this.detail,
    this.dot = LoopAccordionDot.idle,
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
}

/// A row of equal narrow strips; tapping one widens it and narrows the rest
/// (decision 0096).
///
/// Closed, every strip takes `1/N` of the width and shows only its
/// [LoopAccordionItem.shortTitle] and a state dot. A tap opens that strip to
/// a weight of [LoopMotion.accordionOpenWeight] against 1 for each other
/// strip over [LoopMotion.accordionExpand]; its detail fades in from
/// [LoopMotion.accordionFadeStart] of the same controller. A tap on the open
/// strip returns the row to equal widths. With motion reduced every change is
/// one frame.
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
    required this.height,
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

  final List<LoopAccordionItem> items;

  /// The vertical rendering of the same facts.
  final Widget fallback;

  /// The row's height at a text scale of 1; it grows with the text scale.
  final double height;

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
        final height = widget.height * math.max(1.0, scale);
        final openWidth = LoopAccordionStrip.openWidthFor(width, count);
        return Padding(
          padding: widget.margin,
          child: SizedBox(
            key: widget.rowKey ?? ValueKey<String>('${widget.keyPrefix}-row'),
            height: height,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final weights = <double>[
                  for (var index = 0; index < count; index += 1)
                    1 + (LoopMotion.accordionOpenWeight - 1) * _openness(index),
                ];
                final total = weights.fold<double>(0, (a, b) => a + b);
                final inner = width - LoopAccordionStrip.gap * (count - 1);
                return Row(
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
                          openness: _openness(index),
                          showDetail: _detailOpacity(index) > 0,
                          detailFade: _detailFade(index),
                          openWidth: openWidth,
                          onTap: () => _toggle(index),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

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

  static const double _padding = 10;

  final LoopAccordionItem item;
  final Key detailKey;
  final bool open;
  final double openness;
  final bool showDetail;
  final Animation<double> detailFade;
  final double openWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (item.dot) {
      LoopAccordionDot.live => LoopColors.lime,
      LoopAccordionDot.upcoming => LoopGround.secondaryOf(context),
      LoopAccordionDot.idle => LoopGround.auxiliaryOf(context),
    };
    final ground = Color.lerp(
      LoopGround.tintOf(context),
      LoopGround.fillOf(context),
      openness,
    )!;
    final edge = Color.lerp(
      LoopGround.hairlineOf(context),
      LoopGround.edgeOf(context),
      openness,
    )!;
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
              border: Border.all(color: edge),
            ),
            child: ClipRRect(
              borderRadius: LoopRadius.control,
              child: Padding(
                padding: const EdgeInsets.all(_padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 18),
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              item.shortTitle,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              softWrap: false,
                              style: LoopMono.label.copyWith(
                                color: LoopGround.inkOf(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(dimension: 6),
                          ),
                        ],
                      ),
                    ),
                    if (showDetail)
                      Expanded(
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topLeft,
                            minWidth: 0,
                            maxWidth: math.max(0, openWidth - _padding * 2),
                            minHeight: 0,
                            maxHeight: double.infinity,
                            child: FadeTransition(
                              key: detailKey,
                              opacity: detailFade,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: math.max(0, openWidth - _padding * 2),
                                  child: item.detail,
                                ),
                              ),
                            ),
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
}
