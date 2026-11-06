import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';

/// A card that leans toward the finger (S379 · decision 0303, 我的's wallet
/// card).
///
/// While a finger rests on [child] the card turns about its centre, up to
/// [maxTilt] radians on each axis, so the pressed side sinks away under a
/// light perspective, and a soft radial light follows the finger. On lift
/// both settle back to rest on one spring. The card only listens: it never
/// joins the gesture arena, so the buttons inside it still take their taps
/// and the list around it still scrolls; once the finger has travelled
/// [kTouchSlop] vertically the lean lets go. With ambient motion off or the
/// system's reduced motion on, [child] is drawn as it is.
class LoopTiltCard extends ConsumerStatefulWidget {
  const LoopTiltCard({
    required this.child,
    super.key,
    this.borderRadius = LoopRadius.card,
  });

  final Widget child;

  /// The card's corners, so the light stays inside them.
  final BorderRadius borderRadius;

  /// The largest lean on each axis (±6°).
  static const double maxTilt = 6 * math.pi / 180;

  /// The perspective entry (3, 2) of the lean's matrix.
  static const double perspective = 0.0012;

  /// The light's radius, as a share of the card's width.
  static const double glowRadius = 0.7;

  /// The light's centre colour: white 12 %.
  static const Color glowColor = Color(0x1FFFFFFF);

  /// The spring the lean and the light settle back on.
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 180,
    damping: 14,
  );

  /// The lean's transform layer (a test's handle).
  static const Key transformKey = ValueKey<String>('loop-tilt-transform');

  /// The light layer, drawn only while the card is pressed or settling.
  static const Key glowKey = ValueKey<String>('loop-tilt-glow');

  /// The lean for a finger at [offset] (each axis in −1 … 1 from the centre)
  /// scaled by [amount] (1 pressed, 0 at rest).
  static Matrix4 matrixFor(Offset offset, double amount) {
    return Matrix4.identity()
      ..setEntry(3, 2, perspective)
      // A finger below the centre sinks the bottom edge; right of the
      // centre, the right edge.
      ..rotateX(offset.dy * maxTilt * amount)
      ..rotateY(-offset.dx * maxTilt * amount);
  }

  @override
  ConsumerState<LoopTiltCard> createState() => _LoopTiltCardState();
}

class _LoopTiltCardState extends ConsumerState<LoopTiltCard>
    with SingleTickerProviderStateMixin {
  /// 1 while pressed, settling to 0 on the spring (it may dip just under).
  late final AnimationController _amount = AnimationController.unbounded(
    vsync: this,
  );

  /// The finger, each axis in −1 … 1 from the card's centre.
  final ValueNotifier<Offset> _offset = ValueNotifier<Offset>(Offset.zero);

  /// The finger in the card's own box, for the light.
  final ValueNotifier<Offset?> _touch = ValueNotifier<Offset?>(null);

  Offset? _down;
  int? _pointer;

  @override
  void dispose() {
    _amount.dispose();
    _offset.dispose();
    _touch.dispose();
    super.dispose();
  }

  void _follow(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final size = box.size;
    if (size.isEmpty) return;
    final half = size.center(Offset.zero);
    _offset.value = Offset(
      ((local.dx - half.dx) / half.dx).clamp(-1.0, 1.0),
      ((local.dy - half.dy) / half.dy).clamp(-1.0, 1.0),
    );
    _touch.value = local;
  }

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _down = event.localPosition;
    _follow(event.localPosition);
    _amount
      ..stop()
      ..value = 1;
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    final down = _down;
    if (down != null && (event.localPosition.dy - down.dy).abs() > kTouchSlop) {
      // The list took the finger: stop following and settle.
      _release();
      return;
    }
    _follow(event.localPosition);
  }

  void _onEnd(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _release();
  }

  void _release() {
    _pointer = null;
    _down = null;
    _amount
        .animateWith(SpringSimulation(LoopTiltCard.spring, _amount.value, 0, 0))
        .whenComplete(() {
          // The spring stops within its tolerance; rest is exactly flat.
          if (mounted && _pointer == null) _amount.value = 0;
        });
  }

  @override
  Widget build(BuildContext context) {
    if (!loopAmbientMotion(context, ref)) {
      if (_amount.value != 0) _amount.value = 0;
      return widget.child;
    }
    final child = Stack(
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: _TiltGlow(
              amount: _amount,
              touch: _touch,
              borderRadius: widget.borderRadius,
            ),
          ),
        ),
      ],
    );
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onEnd,
      onPointerCancel: _onEnd,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_amount, _offset]),
        child: child,
        builder: (context, child) {
          final amount = _amount.value;
          return Transform(
            key: LoopTiltCard.transformKey,
            alignment: Alignment.center,
            transform: amount == 0
                ? Matrix4.identity()
                : LoopTiltCard.matrixFor(_offset.value, amount),
            child: child,
          );
        },
      ),
    );
  }
}

/// The light under the finger: only the paint layer repaints as it moves.
class _TiltGlow extends StatelessWidget {
  const _TiltGlow({
    required this.amount,
    required this.touch,
    required this.borderRadius,
  });

  final AnimationController amount;
  final ValueNotifier<Offset?> touch;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(<Listenable>[amount, touch]),
    builder: (context, _) {
      final strength = amount.value.clamp(0.0, 1.0);
      final at = touch.value;
      if (strength <= 0.001 || at == null) return const SizedBox.expand();
      return CustomPaint(
        key: LoopTiltCard.glowKey,
        painter: _GlowPainter(
          at: at,
          strength: strength,
          borderRadius: borderRadius,
        ),
        child: const SizedBox.expand(),
      );
    },
  );
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.at,
    required this.strength,
    required this.borderRadius,
  });

  final Offset at;
  final double strength;
  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = LoopTiltCard.glowColor.withValues(
      alpha: LoopTiltCard.glowColor.a * strength,
    );
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          size.width == 0 ? 0 : at.dx / size.width * 2 - 1,
          size.height == 0 ? 0 : at.dy / size.height * 2 - 1,
        ),
        // RadialGradient's radius is a share of the shorter side.
        radius: size.shortestSide == 0
            ? 0
            : LoopTiltCard.glowRadius * size.width / size.shortestSide,
        colors: <Color>[centre, centre.withValues(alpha: 0)],
      ).createShader(rect);
    canvas
      ..save()
      ..clipRRect(borderRadius.toRRect(rect))
      ..drawRect(rect, paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.at != at ||
      oldDelegate.strength != strength ||
      oldDelegate.borderRadius != borderRadius;
}
