import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';

/// A tappable region that answers the finger the way an iOS control does
/// (decision 0130): while held it dims to [LoopMotion.pressOpacity] and
/// shrinks to [LoopMotion.pressScale]; lifting restores it. Android draws the
/// same thing — no ripple anywhere.
///
/// It replaces a bare `GestureDetector(onTap:)`, which accepted the tap and
/// showed nothing until the next page appeared (audit 2026-10-09 m2). With
/// motion reduced the dim stays and the shrink goes: the dim is feedback,
/// the shrink is movement.
///
/// [haptic] plays when the tap lands, for the few controls whose action is
/// itself a touch event (a copy, a selection); most leave it null and let the
/// destination answer.
///
/// The detector keeps its own semantics (a tap action), so a caller that
/// already wraps it in `Semantics(button: true, excludeSemantics: true,
/// onTap: …)` keeps doing so unchanged.
class LoopPressable extends StatefulWidget {
  const LoopPressable({
    required this.child,
    super.key,
    this.onTap,
    this.onLongPress,
    this.haptic,
    this.behavior = HitTestBehavior.opaque,
    this.scale = true,
    this.excludeFromSemantics = false,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// A long press also shows the pressed state while it is held, and plays
  /// [LoopHaptic.medium] when it fires: a long press opens something.
  final VoidCallback? onLongPress;

  /// Played when [onTap] fires.
  final LoopHaptic? haptic;
  final HitTestBehavior behavior;

  /// Whether the pressed state shrinks the child as well as dimming it. A
  /// full-width row turns it off: 2 % of a row's width is a visible jump at
  /// its edges, which reads as the layout moving.
  final bool scale;
  final bool excludeFromSemantics;

  bool get enabled => onTap != null || onLongPress != null;

  @override
  State<LoopPressable> createState() => _LoopPressableState();
}

class _LoopPressableState extends State<LoopPressable> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed == pressed || !mounted) return;
    setState(() => _pressed = pressed);
  }

  @override
  void didUpdateWidget(covariant LoopPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _pressed = false;
  }

  void _tap() {
    final haptic = widget.haptic;
    if (haptic != null) LoopHaptics.play(haptic);
    widget.onTap?.call();
  }

  void _longPress() {
    LoopHaptics.medium();
    _set(false);
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = LoopMotion.reduced(context);
    final duration = reduced
        ? Duration.zero
        : (_pressed ? LoopMotion.pressIn : LoopMotion.pressOut);
    Widget child = AnimatedOpacity(
      opacity: _pressed ? LoopMotion.pressOpacity : 1,
      duration: duration,
      curve: LoopMotion.pressCurve,
      child: widget.child,
    );
    if (widget.scale && !reduced) {
      child = AnimatedScale(
        scale: _pressed ? LoopMotion.pressScale : 1,
        duration: duration,
        curve: LoopMotion.pressCurve,
        child: child,
      );
    }
    // The tap callbacks exist only when there is a tap: a tap recognizer
    // with nothing but onTapDown would still publish a semantic tap action
    // that does nothing. A long-press-only region shows its pressed state
    // through the long-press callbacks instead.
    final tappable = widget.onTap != null;
    final holdable = widget.onLongPress != null;
    return GestureDetector(
      behavior: widget.behavior,
      excludeFromSemantics: widget.excludeFromSemantics,
      dragStartBehavior: DragStartBehavior.down,
      onTapDown: tappable ? (_) => _set(true) : null,
      onTapUp: tappable ? (_) => _set(false) : null,
      onTapCancel: tappable ? () => _set(false) : null,
      onTap: tappable ? _tap : null,
      onLongPressDown: holdable && !tappable ? (_) => _set(true) : null,
      onLongPressCancel: holdable && !tappable ? () => _set(false) : null,
      onLongPress: holdable ? _longPress : null,
      child: child,
    );
  }
}
