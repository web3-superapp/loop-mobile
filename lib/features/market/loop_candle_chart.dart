import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';

/// A read-only projection of exact [LoopCandle] values.
///
/// The model stays `Decimal`. Floating-point conversion happens only inside
/// [_LoopCandlePainter], after a value has been normalised into the zero-to-one
/// pixel coordinate space; the result is a dimensionless visual ratio and must
/// never be reused for a quote or a balance.
///
/// The last bucket may still be open (`isOpen`). It is drawn with a dashed
/// outline and announced in the semantic label, so a moving figure is never
/// mistaken for a settled one.
class LoopCandleChart extends StatelessWidget {
  const LoopCandleChart({
    required this.candles,
    required this.semanticLabel,
    super.key,
    this.height = 220,
  });

  final List<LoopCandle> candles;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const ValueKey<String>('loop-candle-chart-boundary'),
      child: Semantics(
        key: const ValueKey<String>('loop-candle-chart-semantics'),
        container: true,
        image: true,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: CustomPaint(
              key: const ValueKey<String>('loop-candle-chart-canvas'),
              painter: _LoopCandlePainter(candles: candles),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoopCandlePainter extends CustomPainter {
  const _LoopCandlePainter({required this.candles});

  final List<LoopCandle> candles;

  static const _plotPadding = EdgeInsets.fromLTRB(6, 8, 6, 8);

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty || size.isEmpty) return;

    final plot = Rect.fromLTRB(
      _plotPadding.left,
      _plotPadding.top,
      math.max(_plotPadding.left, size.width - _plotPadding.right),
      math.max(_plotPadding.top, size.height - _plotPadding.bottom),
    );
    if (plot.isEmpty) return;

    _paintGrid(canvas, plot);

    var lowest = candles.first.low;
    var highest = candles.first.high;
    for (final candle in candles.skip(1)) {
      if (candle.low < lowest) lowest = candle.low;
      if (candle.high > highest) highest = candle.high;
    }

    final priceSpan = highest - lowest;
    final slotWidth = plot.width / candles.length;
    final bodyWidth = (slotWidth * 0.56).clamp(1.25, 8.0).toDouble();
    final firstOpenTime = candles.first.openTime;
    final timeSpan = candles.last.openTime.difference(firstOpenTime);
    final centerLeft = plot.left + (bodyWidth / 2);
    final centerRight = plot.right - (bodyWidth / 2);

    double xFor(LoopCandle candle) {
      if (candles.length == 1 || timeSpan <= Duration.zero) {
        return plot.center.dx;
      }
      final elapsed = candle.openTime.difference(firstOpenTime).inMicroseconds;
      final normalized =
          elapsed.clamp(0, timeSpan.inMicroseconds) / timeSpan.inMicroseconds;
      return centerLeft + (normalized * (centerRight - centerLeft));
    }

    double yFor(Decimal value) {
      if (priceSpan == Decimal.zero) return plot.center.dy;

      // The sole Decimal -> double boundary. The result is a dimensionless
      // visual ratio and never replaces the exact model value.
      final normalized = ((value - lowest) / priceSpan).toDouble().clamp(
        0.0,
        1.0,
      );
      return plot.bottom - (normalized * plot.height);
    }

    for (final candle in candles) {
      // Lime is the only accent: an unchanged bucket is neutral, not blue.
      final color = candle.isUp
          ? LoopColors.mint
          : candle.isDown
          ? LoopColors.danger
          : LoopColors.vapor;
      final centerX = xFor(candle);
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = math.max(1, math.min(1.5, bodyWidth * 0.55))
        ..strokeCap = StrokeCap.round;
      final wickTop = Offset(centerX, yFor(candle.high));
      final wickBottom = Offset(centerX, yFor(candle.low));
      if (candle.isOpen) {
        _drawDashedLine(canvas, wickTop, wickBottom, wickPaint);
      } else {
        canvas.drawLine(wickTop, wickBottom, wickPaint);
      }

      final openY = yFor(candle.open);
      final closeY = yFor(candle.close);
      final bodyTop = math.min(openY, closeY);
      final bodyBottom = math.max(openY, closeY);
      final minimumBodyHeight = math.min(2.25, plot.height);
      final hasVisibleHeight = bodyBottom - bodyTop >= minimumBodyHeight;
      final visibleTop = hasVisibleHeight
          ? bodyTop
          : ((bodyTop + bodyBottom) / 2 - (minimumBodyHeight / 2))
                .clamp(plot.top, plot.bottom - minimumBodyHeight)
                .toDouble();
      final visibleBottom = hasVisibleHeight
          ? bodyBottom
          : visibleTop + minimumBodyHeight;
      final body = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          centerX - (bodyWidth / 2),
          visibleTop,
          centerX + (bodyWidth / 2),
          visibleBottom,
        ),
        const Radius.circular(1.25),
      );
      if (candle.isOpen) {
        // An open bucket is an outline: its close, high and low will still
        // move, so it must not read like a settled candle.
        canvas.drawRRect(
          body,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      } else {
        canvas.drawRRect(body, Paint()..color = color);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 3.0;
    const gap = 2.5;
    final total = (to - from).distance;
    if (total <= 0) return;
    final direction = (to - from) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final segment = math.min(dash, total - travelled);
      canvas.drawLine(
        from + direction * travelled,
        from + direction * (travelled + segment),
        paint,
      );
      travelled += dash + gap;
    }
  }

  void _paintGrid(Canvas canvas, Rect plot) {
    final paint = Paint()
      ..color = LoopColors.line.withValues(alpha: 0.62)
      ..strokeWidth = 1;
    for (var index = 0; index <= 4; index++) {
      final y = plot.top + (plot.height * index / 4);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
    }
    for (var index = 0; index <= 5; index++) {
      final x = plot.left + (plot.width * index / 5);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoopCandlePainter oldDelegate) =>
      oldDelegate.candles != candles;
}
