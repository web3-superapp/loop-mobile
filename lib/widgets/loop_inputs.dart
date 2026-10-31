import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// UX-008 (decision 0254): one focus rule for every field LOOP draws.
///
/// A [TextField] that takes the theme's decoration already draws the 1px
/// Purple edge on focus and the 12 corner. A field that is drawn by hand — a
/// filled box with a borderless [TextField] inside, the chat composer, the
/// six code cells — has no decoration that could react, so it wraps its box
/// in this ring instead. The ring watches whether anything under it holds the
/// focus and draws the same edge over the box, on the box's own corners.
class LoopFocusRing extends StatefulWidget {
  const LoopFocusRing({
    required this.child,
    super.key,
    this.borderRadius = LoopRadius.control,
    this.enabled = true,
  });

  final Widget child;

  /// The corners of the box the ring sits on. Every field box is
  /// [LoopRadius.control] unless its own shape says otherwise (the composer
  /// is a capsule).
  final BorderRadius borderRadius;

  /// A disabled field never shows focus.
  final bool enabled;

  /// The key of the drawn edge. It never changes with focus: a key that
  /// changed would rebuild the field under it and drop what was typed.
  static const Key edgeKey = ValueKey<String>('loop-focus-ring');

  @override
  State<LoopFocusRing> createState() => _LoopFocusRingState();
}

class _LoopFocusRingState extends State<LoopFocusRing> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final on = _focused && widget.enabled;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (focused) {
        if (focused != _focused) setState(() => _focused = focused);
      },
      child: DecoratedBox(
        key: LoopFocusRing.edgeKey,
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: on ? LoopColors.purple : Colors.transparent,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

/// The edge of one code cell (verification code, six cells): the same
/// filled ground and corners as every other field, Purple on the cell that
/// takes the next digit while the field holds focus.
BoxDecoration loopCodeCellDecoration({
  required bool focused,
  required bool filled,
}) => BoxDecoration(
  color: LoopColors.input,
  borderRadius: LoopRadius.control,
  border: Border.all(
    color: focused
        ? LoopColors.purple
        : filled
        ? LoopColors.line3
        : LoopColors.inputLine,
  ),
);
