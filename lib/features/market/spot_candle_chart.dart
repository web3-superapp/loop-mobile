import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle.dart';

/// A read-only projection of exact Hyperliquid Spot candle values.
///
/// The candle model remains Decimal-backed. Floating-point conversion happens
/// only inside [_SpotCandlePainter] after a value has been normalized into the
/// zero-to-one pixel coordinate space; it must never be reused for quotes or
/// trading calculations.
class SpotCandleChart extends StatelessWidget {
  const SpotCandleChart({
    required this.candles,
    required this.semanticLabel,
    super.key,
    this.height = 220,
  });

  final List<HyperliquidSpotCandle> candles;
  final String semanticLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: const ValueKey<String>('spot-candle-chart-boundary'),
      child: Semantics(
        key: const ValueKey<String>('spot-candle-chart-semantics'),
        container: true,
        image: true,
        label: semanticLabel,
        child: ExcludeSemantics(
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: CustomPaint(
              key: const ValueKey<String>('spot-candle-chart-canvas'),
              painter: _SpotCandlePainter(candles: candles),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotCandlePainter extends CustomPainter {
  const _SpotCandlePainter({required this.candles});

  final List<HyperliquidSpotCandle> candles;

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

    var lowest = candles.first.low.value;
    var highest = candles.first.high.value;
    for (final candle in candles.skip(1)) {
      if (candle.low.value < lowest) lowest = candle.low.value;
      if (candle.high.value > highest) highest = candle.high.value;
    }

    final priceSpan = highest - lowest;
    final slotWidth = plot.width / candles.length;
    final bodyWidth = (slotWidth * 0.56).clamp(1.25, 8.0).toDouble();
    final firstOpenTime = candles.first.openTime;
    final timeSpan = candles.last.openTime.difference(firstOpenTime);
    final centerLeft = plot.left + (bodyWidth / 2);
    final centerRight = plot.right - (bodyWidth / 2);

    double xFor(HyperliquidSpotCandle candle) {
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

      // This is the sole Decimal -> double boundary. The result is a
      // dimensionless visual ratio and never replaces the exact model value.
      final normalized = ((value - lowest) / priceSpan).toDouble().clamp(
        0.0,
        1.0,
      );
      return plot.bottom - (normalized * plot.height);
    }

    for (final candle in candles) {
      final direction = candle.close.value.compareTo(candle.open.value);
      final color = switch (direction) {
        > 0 => LoopColors.mint,
        < 0 => LoopColors.danger,
        _ => LoopColors.market,
      };
      final centerX = xFor(candle);
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = math.max(1, math.min(1.5, bodyWidth * 0.55))
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(centerX, yFor(candle.high.value)),
        Offset(centerX, yFor(candle.low.value)),
        wickPaint,
      );

      final openY = yFor(candle.open.value);
      final closeY = yFor(candle.close.value);
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
      final body = Rect.fromLTRB(
        centerX - (bodyWidth / 2),
        visibleTop,
        centerX + (bodyWidth / 2),
        visibleBottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(1.25)),
        Paint()..color = color,
      );
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
  bool shouldRepaint(covariant _SpotCandlePainter oldDelegate) {
    return oldDelegate.candles != candles;
  }
}
