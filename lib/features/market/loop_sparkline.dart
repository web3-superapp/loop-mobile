import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';

/// The number of closed-price points a Token Card's small line renders.
///
/// One day of the contract's `1h` buckets. Fewer points are drawn as they are;
/// more are trimmed to the most recent [loopSparklineWindow].
const int loopSparklineWindow = 24;

/// The closes a [LoopSparkline] renders for [candles], newest last.
///
/// Only the last [loopSparklineWindow] buckets are kept. Nothing is padded and
/// nothing is interpolated: a shorter series is a shorter line, never a line
/// that invents buckets the server did not report.
List<Decimal> loopSparklineCloses(List<LoopCandle> candles) {
  if (candles.isEmpty) return const <Decimal>[];
  final start = math.max(0, candles.length - loopSparklineWindow);
  return List<Decimal>.unmodifiable(
    candles.sublist(start).map((candle) => candle.close),
  );
}

/// A Token Card's small close-price line.
///
/// It shares [LoopCandleChart]'s rule: the model stays `Decimal`, and the only
/// `double` appears after a value has been normalised into the plot's
/// zero-to-one coordinate space. The result is a dimensionless visual ratio and
/// must never be reused for a quote, a balance or a comparison.
///
/// The widget draws a line and nothing else — no axis, no figure, no label —
/// because every figure on the card carries its own provenance elsewhere.
class LoopSparkline extends StatelessWidget {
  const LoopSparkline({
    required this.closes,
    required this.semanticLabel,
    super.key,
    this.color = LoopColors.lime,
  });

  final List<Decimal> closes;
  final String semanticLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Semantics(
        key: const ValueKey<String>('loop-sparkline-semantics'),
        container: true,
        image: true,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: CustomPaint(
            key: const ValueKey<String>('loop-sparkline-canvas'),
            size: Size.infinite,
            painter: LoopSparklinePainter(closes: closes, color: color),
          ),
        ),
      ),
    );
  }
}

/// Paints the normalised close line. Exposed so the geometry can be asserted
/// without a golden image.
class LoopSparklinePainter extends CustomPainter {
  const LoopSparklinePainter({required this.closes, required this.color});

  final List<Decimal> closes;
  final Color color;

  static const EdgeInsets plotPadding = EdgeInsets.fromLTRB(1, 6, 1, 6);
  static const double strokeWidth = 1.6;

  /// The plot rectangle for [size], or `null` when there is nothing to draw in.
  static Rect? plotRect(Size size) {
    if (size.isEmpty) return null;
    final rect = Rect.fromLTRB(
      plotPadding.left,
      plotPadding.top,
      math.max(plotPadding.left, size.width - plotPadding.right),
      math.max(plotPadding.top, size.height - plotPadding.bottom),
    );
    return rect.isEmpty ? null : rect;
  }

  /// The points the line is drawn through, in order.
  ///
  /// A single point, or a series whose values are all equal, sits on the plot's
  /// vertical centre: a flat line is the honest rendering of an unchanged
  /// price, and a zero span must never become a divide-by-zero.
  static List<Offset> points(List<Decimal> closes, Size size) {
    final plot = plotRect(size);
    if (plot == null || closes.isEmpty) return const <Offset>[];
    var lowest = closes.first;
    var highest = closes.first;
    for (final close in closes.skip(1)) {
      if (close < lowest) lowest = close;
      if (close > highest) highest = close;
    }
    final span = highest - lowest;
    final steps = closes.length - 1;
    return List<Offset>.unmodifiable(<Offset>[
      for (var index = 0; index < closes.length; index++)
        Offset(
          steps == 0
              ? plot.center.dx
              : plot.left + (plot.width * index / steps),
          span == Decimal.zero
              ? plot.center.dy
              // The sole Decimal -> double boundary.
              : plot.bottom -
                    ((closes[index] - lowest) / span).toDouble().clamp(
                          0.0,
                          1.0,
                        ) *
                        plot.height,
        ),
    ]);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plotted = points(closes, size);
    if (plotted.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (plotted.length == 1) {
      canvas.drawPoints(PointMode.points, plotted, paint);
      return;
    }
    final path = Path()..moveTo(plotted.first.dx, plotted.first.dy);
    for (final point in plotted.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LoopSparklinePainter oldDelegate) =>
      oldDelegate.color != color || !listEquals(oldDelegate.closes, closes);
}
