import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';

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
    this.color,
  });

  final List<Decimal> closes;
  final String semanticLabel;

  /// The line's colour. `null` paints the series' own direction — first close
  /// to last — through [LoopPriceMove]: rise green, fall red, and `muted`
  /// for a flat or one-point series (decision 0117).
  final Color? color;

  /// The colour [build] paints, given [color] and [closes].
  Color get resolvedColor => color ?? LoopPriceMove.ofSeries(closes).color;

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
            painter: LoopSparklinePainter(closes: closes, color: resolvedColor),
          ),
        ),
      ),
    );
  }
}

/// Paints the normalised close line. Exposed so the geometry can be asserted
/// without a golden image.
class LoopSparklinePainter extends CustomPainter {
  const LoopSparklinePainter({
    required this.closes,
    required this.color,
    this.padding = plotPadding,
    this.endDotRadius = 0,
    this.progress = 1,
  });

  final List<Decimal> closes;
  final Color color;

  /// The inset of the plot inside the canvas. [plotPadding] by default; the
  /// 情报 · 行情 trend column uses its own (decision 0247).
  final EdgeInsets padding;

  /// A solid dot on the newest point, or none at `0` (decision 0247).
  final double endDotRadius;

  /// How much of the line is drawn, `0`–`1`. Below `1` the line is a draw-in
  /// in progress and the end dot follows its tip.
  final double progress;

  static const EdgeInsets plotPadding = EdgeInsets.fromLTRB(1, 6, 1, 6);
  static const double strokeWidth = 1.6;

  /// The plot rectangle for [size], or `null` when there is nothing to draw in.
  static Rect? plotRect(Size size, {EdgeInsets padding = plotPadding}) {
    if (size.isEmpty) return null;
    final rect = Rect.fromLTRB(
      padding.left,
      padding.top,
      math.max(padding.left, size.width - padding.right),
      math.max(padding.top, size.height - padding.bottom),
    );
    return rect.isEmpty ? null : rect;
  }

  /// The points the line is drawn through, in order.
  ///
  /// A single point, or a series whose values are all equal, sits on the plot's
  /// vertical centre: a flat line is the honest rendering of an unchanged
  /// price, and a zero span must never become a divide-by-zero.
  static List<Offset> points(
    List<Decimal> closes,
    Size size, {
    EdgeInsets padding = plotPadding,
  }) {
    final plot = plotRect(size, padding: padding);
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
    final plotted = points(closes, size, padding: padding);
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
    final shown = progress.clamp(0.0, 1.0);
    var tip = plotted.last;
    if (shown < 1) {
      if (shown == 0) return;
      final metric = path.computeMetrics().first;
      final length = metric.length * shown;
      canvas.drawPath(metric.extractPath(0, length), paint);
      tip = metric.getTangentForOffset(length)?.position ?? plotted.first;
    } else {
      canvas.drawPath(path, paint);
    }
    if (endDotRadius > 0) {
      canvas.drawCircle(
        tip,
        endDotRadius,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant LoopSparklinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.padding != padding ||
      oldDelegate.endDotRadius != endDotRadius ||
      oldDelegate.progress != progress ||
      !listEquals(oldDelegate.closes, closes);
}
