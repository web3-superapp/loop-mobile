import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
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
///
/// Colour: `style-v2.css` publishes ink / lime / chalk and nothing else, and
/// its `.kline-body` rules are a single-hue system — `.kline-up` is solid
/// Lime, `.kline-down` is a hollow Chalk outline. LOOP drew green-and-red
/// candles, which is a fourth and fifth hue the design system does not have
/// (audit 2026-09-21 §D+ item 12). Direction is carried by fill versus
/// outline here, exactly as the prototype carries it.
class LoopCandleChart extends StatelessWidget {
  const LoopCandleChart({
    required this.candles,
    required this.semanticLabel,
    super.key,
    this.height = 220,
    this.movingAveragePeriods = const <int>[],
    this.showVolume = true,
  });

  final List<LoopCandle> candles;
  final String semanticLabel;
  final double height;

  /// Close-price moving averages drawn over the bodies, shortest first.
  ///
  /// Each line is a mean of the closes already on screen and of nothing else:
  /// no server publishes it, so it is never presented as a fact with a source.
  /// The caller labels it and says where it came from.
  final List<int> movingAveragePeriods;

  /// `.kline-volume`: the bar row under the price panel.
  final bool showVolume;

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
              painter: _LoopCandlePainter(
                candles: candles,
                movingAveragePeriods: movingAveragePeriods,
                showVolume: showVolume,
                textScaler: MediaQuery.textScalerOf(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The closes a moving average of [period] buckets is drawn through.
///
/// Position `i` is the mean of the closes in `[i - period + 1, i]`, clamped at
/// the start of the series, so the line begins where the data begins instead
/// of being padded. The division is the only place a `Decimal` becomes a
/// `double`, and the result is used for drawing alone.
List<Decimal> loopCandleMovingAverage(List<LoopCandle> candles, int period) {
  if (candles.isEmpty || period < 1) return const <Decimal>[];
  final out = <Decimal>[];
  for (var index = 0; index < candles.length; index += 1) {
    final start = math.max(0, index - period + 1);
    var sum = Decimal.zero;
    for (var step = start; step <= index; step += 1) {
      sum += candles[step].close;
    }
    out.add(
      (sum / Decimal.fromInt(index - start + 1)).toDecimal(
        scaleOnInfinitePrecision: 24,
      ),
    );
  }
  return List<Decimal>.unmodifiable(out);
}

/// `MA7 0.0000080` — one readout for the indicator row above the chart.
///
/// It states the latest point of the same line the chart draws. The copy says
/// the figure is computed here; it is never given a source.
String? loopCandleMovingAverageLabel(List<LoopCandle> candles, int period) {
  final series = loopCandleMovingAverage(candles, period);
  if (series.isEmpty) return null;
  return 'MA$period ${loopFormatDecimal(series.last)}';
}

class _LoopCandlePainter extends CustomPainter {
  const _LoopCandlePainter({
    required this.candles,
    required this.movingAveragePeriods,
    required this.showVolume,
    required this.textScaler,
  });

  final List<LoopCandle> candles;
  final List<int> movingAveragePeriods;
  final bool showVolume;
  final TextScaler textScaler;

  static const _plotPadding = EdgeInsets.fromLTRB(6, 8, 6, 8);

  /// `.kline-axis-label`: the right-edge price scale takes this much width.
  static const double _axisWidth = 46;

  /// `.chart-panel` splits price and volume at 72% / 79% of its height.
  static const double _priceFraction = 0.72;
  static const double _volumeTopFraction = 0.79;

  /// `.kline-body.kline-up{fill:var(--lime)}`.
  static const Color _upBody = LoopColors.lime;

  /// `.kline-body.kline-down{fill:rgba(243,245,239,.14);stroke:rgba(243,245,239,.78)}`.
  static const Color _downFill = Color(0x24F3F5EF);
  static const Color _downStroke = Color(0xC7F3F5EF);

  /// `.kline-volume.kline-up` / `.kline-down`.
  static const Color _upVolume = Color(0x3DB8FF20);
  static const Color _downVolume = Color(0x24F3F5EF);

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty || size.isEmpty) return;

    final outer = Rect.fromLTRB(
      _plotPadding.left,
      _plotPadding.top,
      math.max(_plotPadding.left, size.width - _plotPadding.right),
      math.max(_plotPadding.top, size.height - _plotPadding.bottom),
    );
    if (outer.isEmpty) return;

    final right = math.max(outer.left + 1, outer.right - _axisWidth);
    final plot = showVolume
        ? Rect.fromLTRB(
            outer.left,
            outer.top,
            right,
            outer.top + outer.height * _priceFraction,
          )
        : Rect.fromLTRB(outer.left, outer.top, right, outer.bottom);
    final volume = showVolume
        ? Rect.fromLTRB(
            outer.left,
            outer.top + outer.height * _volumeTopFraction,
            right,
            outer.bottom,
          )
        : Rect.zero;
    if (plot.isEmpty) return;

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

    _paintGrid(canvas, plot, showVolume ? volume.bottom : plot.bottom);
    _paintPriceAxis(canvas, plot, outer.right, lowest, highest);

    for (final candle in candles) {
      // One hue. A falling bucket is the hollow body, not a second colour.
      final rising = !candle.isDown;
      final stroke = rising ? _upBody : _downStroke;
      final centerX = xFor(candle);
      final wickPaint = Paint()
        ..color = stroke
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
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      } else if (rising) {
        canvas.drawRRect(body, Paint()..color = _upBody);
      } else {
        canvas
          ..drawRRect(body, Paint()..color = _downFill)
          ..drawRRect(
            body,
            Paint()
              ..color = _downStroke
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
      }
    }

    if (showVolume && !volume.isEmpty) {
      _paintVolume(canvas, volume, xFor, bodyWidth);
    }
    _paintMovingAverages(canvas, plot, xFor, yFor);
    _paintLastPrice(canvas, plot, yFor(candles.last.close));
  }

  void _paintVolume(
    Canvas canvas,
    Rect volume,
    double Function(LoopCandle) xFor,
    double bodyWidth,
  ) {
    var peak = candles.first.volume;
    for (final candle in candles.skip(1)) {
      if (candle.volume > peak) peak = candle.volume;
    }
    if (peak <= Decimal.zero) return;
    for (final candle in candles) {
      // The same normalisation rule: exact model in, visual ratio out.
      final ratio = (candle.volume / peak).toDouble().clamp(0.0, 1.0);
      final top = volume.bottom - ratio * volume.height;
      final centerX = xFor(candle);
      canvas.drawRect(
        Rect.fromLTRB(
          centerX - (bodyWidth / 2),
          math.min(top, volume.bottom - 0.5),
          centerX + (bodyWidth / 2),
          volume.bottom,
        ),
        Paint()..color = candle.isDown ? _downVolume : _upVolume,
      );
    }
  }

  void _paintMovingAverages(
    Canvas canvas,
    Rect plot,
    double Function(LoopCandle) xFor,
    double Function(Decimal) yFor,
  ) {
    for (var index = 0; index < movingAveragePeriods.length; index += 1) {
      final series = loopCandleMovingAverage(
        candles,
        movingAveragePeriods[index],
      );
      if (series.length < 2) continue;
      final path = Path()..moveTo(xFor(candles.first), yFor(series.first));
      for (var step = 1; step < series.length; step += 1) {
        path.lineTo(xFor(candles[step]), yFor(series[step]));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = index == 0
              ? LoopColors.lime.withValues(alpha: 0.72)
              : LoopColors.chalk.withValues(alpha: 0.42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.15,
      );
    }
  }

  /// `.kline-last-line`: a dashed Lime rule at the latest close.
  void _paintLastPrice(Canvas canvas, Rect plot, double y) {
    _drawDashedLine(
      canvas,
      Offset(plot.left, y),
      Offset(plot.right, y),
      Paint()
        ..color = LoopColors.lime.withValues(alpha: 0.68)
        ..strokeWidth = 0.8,
    );
  }

  /// `.kline-axis-label`: four prices down the right edge.
  void _paintPriceAxis(
    Canvas canvas,
    Rect plot,
    double right,
    Decimal lowest,
    Decimal highest,
  ) {
    if (right - plot.right < 12) return;
    final span = highest - lowest;
    for (var index = 0; index < 4; index += 1) {
      final y = plot.top + (plot.height * index / 3);
      final value = span == Decimal.zero
          ? highest
          : highest -
                (span * Decimal.fromInt(index) / Decimal.fromInt(3)).toDecimal(
                  scaleOnInfinitePrecision: 24,
                );
      final painter = TextPainter(
        text: TextSpan(
          text: loopFormatDecimal(value, maxFractionDigits: 8),
          style: LoopTypography.figure(
            7,
            color: LoopColors.chalk.withValues(alpha: 0.46),
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout(maxWidth: right - plot.right - 2);
      painter.paint(canvas, Offset(right - painter.width, y - 4));
      painter.dispose();
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

  /// `.chart-grid-line{opacity:.1}` and `.chart-grid-vertical{opacity:.055}`.
  ///
  /// LOOP drew the same lines at 62% and the page read like a trading
  /// terminal instead of the prototype's line drawing (audit §G.3).
  void _paintGrid(Canvas canvas, Rect plot, double bottom) {
    final horizontal = Paint()
      ..color = LoopColors.chalk.withValues(alpha: 0.1)
      ..strokeWidth = 1;
    final vertical = Paint()
      ..color = LoopColors.chalk.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    for (var index = 0; index < 4; index++) {
      final y = plot.top + (plot.height * index / 3);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), horizontal);
    }
    for (var index = 0; index <= 4; index++) {
      final x = plot.left + (plot.width * index / 4);
      canvas.drawLine(Offset(x, plot.top), Offset(x, bottom), vertical);
    }
  }

  @override
  bool shouldRepaint(covariant _LoopCandlePainter oldDelegate) =>
      oldDelegate.candles != candles ||
      oldDelegate.showVolume != showVolume ||
      oldDelegate.textScaler != textScaler ||
      !listEquals(oldDelegate.movingAveragePeriods, movingAveragePeriods);
}
