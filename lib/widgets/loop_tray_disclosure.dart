import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// A card with a darker tray tucked under it (decision 0092).
///
/// The [card] is drawn exactly as its owner builds it, and it neither moves
/// nor resizes: the tray sits beneath it, a little narrower than the card
/// and with larger corners, in the theme's secondary panel colour. Closed,
/// the tray shows one line — [summary]. A tap on the tray opens it downward
/// to [detail] (the height grows over [LoopMotion.trayExpand] while the detail
/// fades in); a second tap closes it. With motion reduced the tray simply
/// switches between the two heights.
///
/// The card keeps its own tap. The tray is a separate target, at least
/// [LoopTouch.minimum] tall, so opening the detail never also opens the
/// card's page.
///
/// The tray is always the Graphite panel, whatever ground the card sits on,
/// and it declares that dark ground to its content: [summary] and [detail]
/// read Chalk from the ambient [DefaultTextStyle], so a detail built with
/// [LoopGround] derives the right ink.
class LoopTrayDisclosure extends StatefulWidget {
  const LoopTrayDisclosure({
    required this.card,
    required this.summary,
    required this.detail,
    super.key,
    this.initiallyExpanded = false,
    this.trayInset = defaultTrayInset,
    this.overlap = defaultOverlap,
    this.semanticLabel,
    this.onExpansionChanged,
    this.margin = EdgeInsets.zero,
  });

  /// How much narrower the tray is than the card, on each side.
  static const double defaultTrayInset = 10;

  /// How far the tray's top edge runs up under the card. It matches the
  /// card radius, so the tray's corners are hidden and only its lower part
  /// shows.
  static const double defaultOverlap = LoopRadius.cardValue;

  /// The tray's corner radius: one step larger than a card's.
  static const double trayRadius = LoopRadius.shellValue;

  /// The main component. It is laid out at the full width it is given.
  final Widget card;

  /// The one line the closed tray shows.
  final Widget summary;

  /// What the open tray adds under [summary].
  final Widget detail;

  final bool initiallyExpanded;

  /// Horizontal inset of the tray relative to the card's own box. A card
  /// that pads itself inside its box (a page-width row) adds that padding.
  final double trayInset;

  final double overlap;

  /// What a screen reader hears for the tray control; the state is added.
  final String? semanticLabel;

  final ValueChanged<bool>? onExpansionChanged;

  final EdgeInsets margin;

  @override
  State<LoopTrayDisclosure> createState() => _LoopTrayDisclosureState();
}

class _LoopTrayDisclosureState extends State<LoopTrayDisclosure>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LoopMotion.trayExpand,
    value: widget.initiallyExpanded ? 1 : 0,
  );

  late final Animation<double> _size = CurvedAnimation(
    parent: _controller,
    curve: LoopMotion.trayCurve,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(LoopMotion.trayFadeStart, 1, curve: Curves.easeOut),
  );

  late bool _expanded = widget.initiallyExpanded;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final expanded = !_expanded;
    setState(() => _expanded = expanded);
    if (LoopMotion.reduced(context)) {
      _controller.value = expanded ? 1 : 0;
    } else if (expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    widget.onExpansionChanged?.call(expanded);
  }

  @override
  Widget build(BuildContext context) {
    final base = DefaultTextStyle.of(context).style;
    final tray = DefaultTextStyle(
      style: base.copyWith(color: LoopColors.chalk),
      child: IconTheme(
        data: const IconThemeData(color: LoopColors.text2),
        child: Semantics(
          button: true,
          expanded: _expanded,
          label: widget.semanticLabel,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const ValueKey<String>('loop-tray-toggle'),
              onTap: _toggle,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(LoopTrayDisclosure.trayRadius),
              ),
              child: DecoratedBox(
                key: const ValueKey<String>('loop-tray'),
                decoration: const BoxDecoration(
                  color: LoopColors.graphite,
                  borderRadius: BorderRadius.all(
                    Radius.circular(LoopTrayDisclosure.trayRadius),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, widget.overlap + 8, 14, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(
                            0,
                            LoopTouch.minimum - widget.overlap - 18,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Expanded(child: widget.summary),
                            const SizedBox(width: 8),
                            // The sprite's chevron points to the trailing
                            // edge: a quarter turn points it down (closed),
                            // three quarters point it up (open).
                            RotationTransition(
                              turns: Tween<double>(
                                begin: 0.25,
                                end: 0.75,
                              ).animate(_size),
                              child: const LoopIcon(
                                'chevron',
                                size: 14,
                                color: LoopColors.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // A closed tray does not build its detail at all, so
                      // a screen reader, a search and a test read the one
                      // line that is on screen and not a copy of the detail
                      // clipped to nothing underneath it.
                      AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          if (_controller.isDismissed) {
                            return const SizedBox.shrink();
                          }
                          return SizeTransition(
                            sizeFactor: _size,
                            alignment: Alignment.topCenter,
                            child: FadeTransition(
                              key: const ValueKey<String>('loop-tray-detail'),
                              opacity: _fade,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: widget.detail,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: widget.margin,
      child: _TrayUnderlay(
        trayInset: widget.trayInset,
        overlap: widget.overlap,
        children: <Widget>[tray, widget.card],
      ),
    );
  }
}

/// Lays the card out at full width and the tray under it: narrower by
/// [trayInset] on each side, starting [overlap] above the card's bottom edge,
/// painted first so the card covers it. Its size is the card plus whatever of
/// the tray shows below, so the page flows under both.
class _TrayUnderlay extends MultiChildRenderObjectWidget {
  const _TrayUnderlay({
    required this.trayInset,
    required this.overlap,
    required super.children,
  });

  final double trayInset;
  final double overlap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTrayUnderlay(trayInset, overlap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTrayUnderlay renderObject,
  ) {
    renderObject
      ..trayInset = trayInset
      ..overlap = overlap;
  }
}

class _TrayUnderlayParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderTrayUnderlay extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TrayUnderlayParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TrayUnderlayParentData> {
  _RenderTrayUnderlay(this._trayInset, this._overlap);

  double _trayInset;
  set trayInset(double value) {
    if (value == _trayInset) return;
    _trayInset = value;
    markNeedsLayout();
  }

  double _overlap;
  set overlap(double value) {
    if (value == _overlap) return;
    _overlap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TrayUnderlayParentData) {
      child.parentData = _TrayUnderlayParentData();
    }
  }

  RenderBox get _tray => firstChild!;
  RenderBox get _card => lastChild!;

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    _card.layout(
      BoxConstraints(minWidth: width, maxWidth: width),
      parentUsesSize: true,
    );
    final trayWidth = math.max(0.0, width - _trayInset * 2);
    _tray.layout(
      BoxConstraints(minWidth: trayWidth, maxWidth: trayWidth),
      parentUsesSize: true,
    );
    final cardHeight = _card.size.height;
    final trayTop = math.max(0.0, cardHeight - _overlap);
    (_card.parentData! as _TrayUnderlayParentData).offset = Offset.zero;
    (_tray.parentData! as _TrayUnderlayParentData).offset = Offset(
      _trayInset,
      trayTop,
    );
    size = constraints.constrain(
      Size(width, math.max(cardHeight, trayTop + _tray.size.height)),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _height(width);

  double _height(double width) {
    final card = _card.getMinIntrinsicHeight(width);
    final tray = _tray.getMinIntrinsicHeight(
      math.max(0.0, width - _trayInset * 2),
    );
    return math.max(card, math.max(0.0, card - _overlap) + tray);
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
