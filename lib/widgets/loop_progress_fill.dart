import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

/// A surface whose own background states how far a process has come
/// (decision 0092).
///
/// The fill runs from the leading edge to `progress` of the width, under the
/// [child]. When `progress` changes the fill advances to the new fraction over
/// [LoopMotion.progressFill]; when it arrives at the whole width from anywhere
/// short of it, the component brightens once — a [highlightColor] layer that
/// goes 0 → [LoopMotion.progressCompletePeak] → 0 over
/// [LoopMotion.progressComplete]. With motion reduced both collapse: the fill
/// stands at its value and nothing flashes.
///
/// The fill states progress and nothing else. A caller hands a fraction it
/// can name the steps of — 「第 3 步，共 5 步」 — never an estimate of time.
///
/// Colours are tokens, never literals. The default fill is [LoopGround]'s
/// inset weight, which is Chalk on the Ink page and Ink on a Chalk or Lime
/// card, so the fill is visible on whichever ground the component lands on; a
/// caller that passes its own colour passes a `LoopColors` token that holds on
/// that ground.
class LoopProgressFill extends StatefulWidget {
  const LoopProgressFill({
    required this.progress,
    super.key,
    this.from,
    this.child,
    this.fillColor,
    this.trackColor,
    this.highlightColor = LoopColors.limeHighlight,
    this.borderRadius = BorderRadius.zero,
    this.height,
  });

  /// The completed fraction, clamped to `[0, 1]`.
  final double progress;

  /// Where the fill stands on the first frame, when it should advance into
  /// [progress] as the component appears — a step page that the previous
  /// step's fill carries forward into. `null` starts at [progress].
  final double? from;

  /// What the fill sits under. `null` draws the bare track.
  final Widget? child;

  /// The fill; defaults to [LoopGround.fillOf] of the ambient ground.
  final Color? fillColor;

  /// The unfilled part of the width; `null` paints nothing there, so the
  /// ground or the child's own background shows through.
  final Color? trackColor;

  /// The layer the completion brightening is painted in. It is shown at most
  /// at [LoopMotion.progressCompletePeak] of its own strength.
  final Color highlightColor;

  final BorderRadius borderRadius;

  /// A fixed height for a bare track; `null` takes the child's.
  final double? height;

  @override
  State<LoopProgressFill> createState() => _LoopProgressFillState();
}

class _LoopProgressFillState extends State<LoopProgressFill>
    with TickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(
    vsync: this,
    duration: LoopMotion.progressFill,
  )..addStatusListener(_onFillStatus);

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: LoopMotion.progressComplete,
  );

  late final Animation<double> _flashOpacity = TweenSequence<double>(
    <TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 0, end: LoopMotion.progressCompletePeak),
        weight: 1,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: LoopMotion.progressCompletePeak, end: 0),
        weight: 1,
      ),
    ],
  ).animate(CurvedAnimation(parent: _flash, curve: Curves.easeInOut));

  late double _begin = _clamp(widget.from ?? widget.progress);
  late double _end = _clamp(widget.progress);
  bool _started = false;

  static double _clamp(double value) => value.clamp(0.0, 1.0);

  double get _value => _begin + (_end - _begin) * _curved;

  double get _curved => LoopMotion.progressCurve.transform(_fill.value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // The first advance reads the ambient motion setting, which is not
    // available in `initState`.
    _advance();
  }

  @override
  void didUpdateWidget(LoopProgressFill oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _clamp(widget.progress);
    if (target == _end) return;
    _begin = _value;
    _end = target;
    _advance();
  }

  void _advance() {
    if (_begin == _end) {
      _fill.value = 1;
      return;
    }
    if (LoopMotion.reduced(context)) {
      // An instant switch: the fill stands at its value, and the brightening
      // — which is motion and nothing else — is not played.
      _flash.value = 0;
      _fill.value = 1;
      return;
    }
    _fill.forward(from: 0);
  }

  void _onFillStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_end < 1 || _begin >= 1) return;
    if (!mounted || LoopMotion.reduced(context)) return;
    _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _fill.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fill = widget.fillColor ?? LoopGround.fillOf(context);
    final track = widget.trackColor;
    final child = widget.child;
    final body = Stack(
      children: <Widget>[
        if (track != null)
          Positioned.fill(
            child: ColoredBox(
              key: const ValueKey<String>('loop-progress-fill-track'),
              color: track,
            ),
          ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _fill,
            builder: (context, _) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                key: const ValueKey<String>('loop-progress-fill-bar'),
                widthFactor: _value,
                heightFactor: 1,
                child: ColoredBox(color: fill),
              ),
            ),
          ),
        ),
        if (child != null)
          child
        else
          SizedBox(width: double.infinity, height: widget.height ?? 4),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (context, _) {
                // Mounted only while it plays: a settled component carries
                // no highlight layer at all.
                if (!_flash.isAnimating) return const SizedBox.shrink();
                return FadeTransition(
                  opacity: _flashOpacity,
                  child: ColoredBox(
                    key: const ValueKey<String>('loop-progress-fill-flash'),
                    color: widget.highlightColor,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: widget.height == null || child == null
          ? body
          : SizedBox(height: widget.height, child: body),
    );
  }
}
