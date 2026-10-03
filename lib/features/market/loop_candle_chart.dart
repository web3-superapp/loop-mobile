import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';

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
/// Green indicates a rising candle, red a falling candle. Open buckets remain
/// outlined/dashed so direction never implies a settled close (decision 0116).
class LoopCandleChart extends StatefulWidget {
  const LoopCandleChart({
    required this.candles,
    required this.semanticLabel,
    super.key,
    this.height = 220,
    this.movingAveragePeriods = const <int>[],
    this.showVolume = true,
    this.onCandleSelected,
  });
  final List<LoopCandle> candles;
  final String semanticLabel;
  final double height;
  final List<int> movingAveragePeriods;
  final bool showVolume;
  final ValueChanged<LoopCandle?>? onCandleSelected;
  @override
  State<LoopCandleChart> createState() => _LoopCandleChartState();
}

class _LoopCandleChartState extends State<LoopCandleChart> {
  int _count = 60;
  double _start = 0;
  LoopCandle? _selected;
  int _gestureAnchor = 0;
  int _gestureCount = 60;
  double _previousScale = 1;
  double _gestureScale = 1;
  @override
  void initState() {
    super.initState();
    _latest();
  }

  void _latest() {
    _count = math.min(60, widget.candles.length);
    _start = math.max(0, widget.candles.length - _count).toDouble();
  }

  @override
  void didUpdateWidget(covariant LoopCandleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.candles == oldWidget.candles) return;
    final followedLatest = _start + _count >= oldWidget.candles.length - 1;
    _count = math.min(math.max(1, _count), widget.candles.length);
    if (oldWidget.candles.isEmpty) _count = math.min(60, widget.candles.length);
    _start = followedLatest
        ? math.max(0, widget.candles.length - _count).toDouble()
        : _bounded(_start);
    if (_selected != null) {
      final matching = widget.candles.where(
        (c) => c.openTime == _selected!.openTime,
      );
      _selected = matching.isEmpty ? null : matching.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCandleSelected?.call(_selected);
      });
    }
  }

  double _bounded(double value) =>
      value.clamp(0, math.max(0, widget.candles.length - _count)).toDouble();
  void _clearSelection() {
    if (_selected == null) return;
    setState(() => _selected = null);
    widget.onCandleSelected?.call(null);
  }

  void _select(Offset position, double plotWidth, List<LoopCandle> visible) {
    if (visible.isEmpty) return;
    final fraction = ((position.dx - 6) / plotWidth).clamp(0.0, 1.0);
    final target =
        visible.first.openTime.microsecondsSinceEpoch +
        (visible.last.openTime
                    .difference(visible.first.openTime)
                    .inMicroseconds *
                fraction)
            .round();
    final candle = visible.reduce(
      (a, b) =>
          (a.openTime.microsecondsSinceEpoch - target).abs() <=
              (b.openTime.microsecondsSinceEpoch - target).abs()
          ? a
          : b,
    );
    if (_selected == candle) return;
    setState(() => _selected = candle);
    widget.onCandleSelected?.call(candle);
  }

  int _timeAt(double fraction) {
    if (widget.candles.isEmpty) return 0;
    final first =
        widget.candles[_start.round()].openTime.microsecondsSinceEpoch;
    final last = widget
        .candles[math.min(
          widget.candles.length - 1,
          _start.round() + _count - 1,
        )]
        .openTime
        .microsecondsSinceEpoch;
    return first + ((last - first) * fraction).round();
  }

  // Choose the discrete window whose timestamp at the finger is closest to
  // the original timestamp. Index fractions would shift the anchor at gaps.
  double _startForTime(int anchor, double fraction) {
    var best = 0;
    var distance = double.infinity;
    for (var start = 0; start <= widget.candles.length - _count; start++) {
      final first = widget.candles[start].openTime.microsecondsSinceEpoch;
      final last =
          widget.candles[start + _count - 1].openTime.microsecondsSinceEpoch;
      final delta = (first + (last - first) * fraction - anchor).abs();
      if (delta < distance) {
        best = start;
        distance = delta;
      }
    }
    return best.toDouble();
  }

  void _pan(double pixels, double plotWidth) {
    if (widget.candles.isEmpty) return;
    _clearSelection();
    setState(() => _start = _bounded(_start - pixels / plotWidth * _count));
  }

  void _zoom(double factor, double fraction) {
    if (widget.candles.isEmpty) return;
    _clearSelection();
    setState(() {
      final anchor = _timeAt(fraction);
      _count = (_count * factor).round().clamp(
        math.min(8, widget.candles.length),
        widget.candles.length,
      );
      _start = _startForTime(anchor, fraction);
    });
  }

  @override
  Widget build(BuildContext context) {
    final from = _start
        .round()
        .clamp(0, math.max(0, widget.candles.length - _count))
        .toInt();
    final visible = widget.candles
        .skip(from)
        .take(_count)
        .toList(growable: false);
    final averages = <List<Decimal>>[
      for (final period in widget.movingAveragePeriods)
        loopCandleMovingAverage(
          widget.candles,
          period,
        ).skip(from).take(_count).toList(growable: false),
    ];
    final textScaler = MediaQuery.textScalerOf(context);
    final axisWidth = _chartAxisWidth(visible, textScaler);
    return RepaintBoundary(
      key: const ValueKey<String>('loop-candle-chart-boundary'),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final plotWidth = math.max(
                    1.0,
                    constraints.maxWidth - axisWidth - 12,
                  );
                  return Semantics(
                    key: const ValueKey<String>('loop-candle-chart-semantics'),
                    container: true,
                    image: true,
                    label: widget.semanticLabel,
                    child: MouseRegion(
                      onExit: (_) => _clearSelection(),
                      onHover: (event) =>
                          _select(event.localPosition, plotWidth, visible),
                      child: Listener(
                        onPointerSignal: (event) {
                          if (event is PointerScrollEvent &&
                              widget.candles.isNotEmpty) {
                            GestureBinding.instance.pointerSignalResolver
                                .register(event, (_) {
                                  if (event.scrollDelta.dx.abs() >
                                      event.scrollDelta.dy.abs()) {
                                    _pan(-event.scrollDelta.dx, plotWidth);
                                  } else {
                                    _zoom(
                                      math.exp(event.scrollDelta.dy * 0.002),
                                      ((event.localPosition.dx - 6) / plotWidth)
                                          .clamp(0.0, 1.0),
                                    );
                                  }
                                });
                          }
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (event) =>
                              _select(event.localPosition, plotWidth, visible),
                          onLongPressStart: (event) =>
                              _select(event.localPosition, plotWidth, visible),
                          onLongPressMoveUpdate: (event) =>
                              _select(event.localPosition, plotWidth, visible),
                          onScaleStart: (event) {
                            _clearSelection();
                            _gestureCount = _count;
                            _previousScale = 1;
                            _gestureScale = 1;
                            _gestureAnchor = _timeAt(
                              ((event.localFocalPoint.dx - 6) / plotWidth)
                                  .clamp(0.0, 1.0),
                            );
                          },
                          onScaleUpdate: (event) {
                            if (widget.candles.isEmpty) return;
                            // Incremental movement discards overscroll at either
                            // edge, so reversing direction responds immediately.
                            if (event.scale == _previousScale) {
                              _pan(event.focalPointDelta.dx, plotWidth);
                              _gestureCount = _count;
                              _gestureScale = event.scale;
                              _gestureAnchor = _timeAt(
                                ((event.localFocalPoint.dx - 6) / plotWidth)
                                    .clamp(0.0, 1.0),
                              );
                              return;
                            }
                            _previousScale = event.scale;
                            setState(() {
                              final currentFraction =
                                  (event.localFocalPoint.dx - 6) / plotWidth;
                              _count =
                                  (_gestureCount * _gestureScale / event.scale)
                                      .round()
                                      .clamp(
                                        math.min(8, widget.candles.length),
                                        widget.candles.length,
                                      );
                              _start = _startForTime(
                                _gestureAnchor,
                                currentFraction,
                              );
                            });
                          },
                          child: ExcludeSemantics(
                            child: CustomPaint(
                              key: const ValueKey<String>(
                                'loop-candle-chart-canvas',
                              ),
                              size: Size.infinite,
                              painter: _LoopCandlePainter(
                                candles: visible,
                                movingAveragePeriods:
                                    widget.movingAveragePeriods,
                                averages: averages,
                                latest: widget.candles.lastOrNull,
                                selected: _selected,
                                axisWidth: axisWidth,
                                showVolume: widget.showVolume,
                                textScaler: textScaler,
                              ),
                              child: _selected == null
                                  ? null
                                  : Align(
                                      alignment: Alignment.topLeft,
                                      child: Container(
                                        color: LoopColors.ink,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          '${_chartTime(_selected!.openTime)} UTC · ${loopFormatCandlePrice(_selected!.close)}',
                                          key: const ValueKey<String>(
                                            'candle-selection',
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: LoopTypography.figure(11),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      visible.isEmpty
                          ? '暂无 K 线'
                          : '${from + 1}–${from + visible.length}/${widget.candles.length} · UTC',
                      key: const ValueKey<String>('candle-visible-range'),
                      style: LoopTypography.caption(11),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('candle-zoom-out'),
                    tooltip: '缩小',
                    onPressed: visible.isEmpty ? null : () => _zoom(1.3, .5),
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                  IconButton(
                    key: const ValueKey<String>('candle-zoom-in'),
                    tooltip: '放大',
                    onPressed: visible.isEmpty ? null : () => _zoom(.75, .5),
                    icon: const Icon(Icons.add, size: 18),
                  ),
                  TextButton(
                    key: const ValueKey<String>('candle-reset'),
                    onPressed: visible.isEmpty
                        ? null
                        : () {
                            setState(() {
                              _latest();
                              _selected = null;
                            });
                            widget.onCandleSelected?.call(null);
                          },
                    child: const Text('最新'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _chartTime(DateTime time) {
  final utc = time.toUtc();
  return '${utc.month.toString().padLeft(2, '0')}/${utc.day.toString().padLeft(2, '0')} ${utc.hour.toString().padLeft(2, '0')}:${utc.minute.toString().padLeft(2, '0')}';
}

String _chartAxisLabel(Decimal value) {
  final normal = loopFormatCandlePrice(value);
  if (normal.length <= 12) return normal;
  if (value == Decimal.zero) return '0';
  final negative = value < Decimal.zero;
  var scaled = negative ? -value : value;
  var exponent = 0;
  while (scaled < Decimal.one && exponent > -100) {
    scaled = scaled.shift(1);
    exponent--;
  }
  while (scaled >= Decimal.fromInt(10) && exponent < 100) {
    scaled = scaled.shift(-1);
    exponent++;
  }
  return '${negative ? '-' : ''}${loopFormatDecimal(scaled, maxFractionDigits: 3)}e$exponent';
}

/// Projects an exact price into pixel space without clamping. A moving average
/// outside the visible candle range must leave the plot, never flatten on its edge.
double loopCandlePriceY(
  Decimal value, {
  required Decimal lowest,
  required Decimal highest,
  required double top,
  required double bottom,
}) {
  final priceSpan = highest - lowest;
  if (priceSpan == Decimal.zero) return (top + bottom) / 2;
  // Decimal crosses to double only as a dimensionless visual ratio.
  final normalized = ((value - lowest) / priceSpan).toDouble();
  return bottom - normalized * (bottom - top);
}

Decimal _chartPricePadding(Decimal low, Decimal high) {
  final span = high - low;
  return span == Decimal.zero
      ? (high.abs() == Decimal.zero
            ? Decimal.parse('0.000000000000000000000001')
            : high.abs().shift(-2))
      : (span / Decimal.fromInt(12)).toDecimal(scaleOnInfinitePrecision: 30);
}

double _chartAxisWidth(List<LoopCandle> candles, TextScaler scaler) {
  if (candles.isEmpty) return 58;
  var low = candles.first.low;
  var high = candles.first.high;
  for (final candle in candles) {
    if (candle.low < low) low = candle.low;
    if (candle.high > high) high = candle.high;
  }
  final padding = _chartPricePadding(low, high);
  low -= padding;
  high += padding;
  var width = 58.0;
  for (var i = 0; i < 4; i++) {
    final value =
        high -
        ((high - low) * Decimal.fromInt(i) / Decimal.fromInt(3)).toDecimal(
          scaleOnInfinitePrecision: 24,
        );
    final painter = TextPainter(
      text: TextSpan(
        text: _chartAxisLabel(value),
        style: LoopTypography.figure(11),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    width = math.max(width, painter.width + 12);
    painter.dispose();
  }
  return width.clamp(58.0, 140.0);
}

/// The closes a moving average of [period] buckets is drawn through.
///
/// Position `i` is the mean of the closes in `[i - period + 1, i]`, clamped at
/// the start of the series, so the line begins where the data begins instead
/// of being padded. Averages remain Decimal over the full history; the chart
/// slices this series only after computing it, so panning never changes a mean.
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
  return 'MA$period ${loopFormatCandlePrice(series.last)}';
}

class _LoopCandlePainter extends CustomPainter {
  const _LoopCandlePainter({
    required this.candles,
    required this.movingAveragePeriods,
    required this.showVolume,
    required this.textScaler,
    required this.averages,
    required this.latest,
    required this.selected,
    required this.axisWidth,
  });

  final List<LoopCandle> candles;
  final List<int> movingAveragePeriods;
  final bool showVolume;
  final TextScaler textScaler;
  final List<List<Decimal>> averages;
  final LoopCandle? latest;
  final LoopCandle? selected;
  final double axisWidth;

  static const _plotPadding = EdgeInsets.fromLTRB(6, 8, 6, 8);

  /// `.kline-axis-label`: the right-edge price scale takes this much width.

  /// `.chart-panel` splits price and volume at 72% / 79% of its height.
  static const double _priceFraction = 0.72;
  static const double _volumeTopFraction = 0.79;

  static const Color _upBody = LoopColors.marketUp;
  static const Color _downFill = LoopColors.marketDown;
  static const Color _downStroke = LoopColors.marketDown;
  static final Color _upVolume = LoopColors.marketUp.withValues(alpha: 0.55);
  static final Color _downVolume = LoopColors.marketDown.withValues(
    alpha: 0.55,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty || size.isEmpty) return;

    final outer = Rect.fromLTRB(
      _plotPadding.left,
      _plotPadding.top,
      math.max(_plotPadding.left, size.width - _plotPadding.right),
      math.max(_plotPadding.top, size.height - _plotPadding.bottom - 20),
    );
    if (outer.isEmpty) return;

    final right = math.max(outer.left + 1, outer.right - axisWidth);
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

    final padding = _chartPricePadding(lowest, highest);
    lowest -= padding;
    highest += padding;
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

    double yFor(Decimal value) => loopCandlePriceY(
      value,
      lowest: lowest,
      highest: highest,
      top: plot.top,
      bottom: plot.bottom,
    );

    _paintGrid(canvas, plot, showVolume ? volume.bottom : plot.bottom);
    _paintPriceAxis(canvas, plot, outer.right, lowest, highest);

    for (final candle in candles) {
      // Direction colours are independent of the brand accent.
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
    final last = latest ?? candles.last;
    final lastColor = LoopPriceMove.between(
      open: last.open,
      close: last.close,
    ).color;
    if (last.close >= lowest && last.close <= highest) {
      _paintLastPrice(canvas, plot, yFor(last.close), lastColor);
    }
    _paintTag(
      canvas,
      '${last.close > highest
          ? '↑ '
          : last.close < lowest
          ? '↓ '
          : ''}${_chartAxisLabel(last.close)}',
      Offset(
        plot.right + 3,
        yFor(last.close).clamp(plot.top + 7, plot.bottom - 7) - 7,
      ),
      color: lastColor,
      backgroundWidth: outer.right - plot.right,
    );
    for (final fraction
        in (plot.width < 300 ? <double>[0, 1] : <double>[0, .5, 1])) {
      final time = firstOpenTime.add(
        Duration(microseconds: (timeSpan.inMicroseconds * fraction).round()),
      );
      _paintTag(
        canvas,
        _chartTime(time),
        Offset(plot.left + fraction * (plot.width - 75), outer.bottom + 4),
      );
    }
    final chosen = selected;
    if (chosen != null &&
        !chosen.openTime.isBefore(candles.first.openTime) &&
        !chosen.openTime.isAfter(candles.last.openTime)) {
      final x = xFor(chosen);
      final y = yFor(chosen.close);
      final cross = Paint()
        ..color = LoopColors.chalk
        ..strokeWidth = .8;
      _drawDashedLine(
        canvas,
        Offset(x, plot.top),
        Offset(x, showVolume ? volume.bottom : plot.bottom),
        cross,
      );
      _drawDashedLine(
        canvas,
        Offset(plot.left, y),
        Offset(plot.right, y),
        cross,
      );
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = LoopColors.chalk);
    }
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
    canvas.save();
    canvas.clipRect(plot);
    for (var index = 0; index < movingAveragePeriods.length; index += 1) {
      final series = averages[index];
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
    canvas.restore();
  }

  /// The latest candle's direction colours its price marker and dashed line.
  void _paintLastPrice(Canvas canvas, Rect plot, double y, Color color) {
    _drawDashedLine(
      canvas,
      Offset(plot.left, y),
      Offset(plot.right, y),
      Paint()
        ..color = color.withValues(alpha: 0.68)
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
      final current = latest;
      if (current != null) {
        final markerY = loopCandlePriceY(
          current.close,
          lowest: lowest,
          highest: highest,
          top: plot.top,
          bottom: plot.bottom,
        ).clamp(plot.top + 7, plot.bottom - 7);
        // A current-price badge replaces a nearby tick in full, rather than
        // covering half its digits when the two labels almost coincide.
        if ((y - markerY).abs() < textScaler.scale(18)) continue;
      }
      final value = span == Decimal.zero
          ? highest
          : highest -
                (span * Decimal.fromInt(index) / Decimal.fromInt(3)).toDecimal(
                  scaleOnInfinitePrecision: 24,
                );
      final painter = TextPainter(
        text: TextSpan(
          text: _chartAxisLabel(value),
          style: LoopTypography.figure(11, color: LoopColors.text2),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout(maxWidth: right - plot.right - 2);
      painter.paint(canvas, Offset(right - painter.width, y - 4));
      painter.dispose();
    }
  }

  void _paintTag(
    Canvas canvas,
    String text,
    Offset position, {
    Color color = LoopColors.text2,
    double? backgroundWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: LoopTypography.figure(11, color: color),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    canvas.drawRect(
      Rect.fromLTWH(
        position.dx - 2,
        position.dy - 1,
        math.max(painter.width + 4, backgroundWidth ?? 0),
        painter.height + 2,
      ),
      Paint()..color = LoopColors.ink,
    );
    painter.paint(canvas, position);
    painter.dispose();
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
      oldDelegate.selected != selected ||
      oldDelegate.latest != latest ||
      oldDelegate.axisWidth != axisWidth ||
      oldDelegate.showVolume != showVolume ||
      oldDelegate.textScaler != textScaler ||
      !listEquals(oldDelegate.movingAveragePeriods, movingAveragePeriods);
}

// ---------------------------------------------------------------------------
// candle figures
// ---------------------------------------------------------------------------

/// A price on a chart, at the precision its own magnitude deserves.
///
/// The OHLC readout used one rule for every asset — eight fraction digits —
/// and printed `O 2,759.67162123` over an ETH chart: eleven digits of which
/// the last six are noise, and a figure so long it wrapped. A 1e-6 launchpad
/// price needs the opposite treatment, and two decimals would print it as
/// `0.00`.
///
/// So the scale follows the figure:
///
/// * `≥ 1000` — two fraction digits. Cents are the last thing that matters at
///   that size, and the integer part carries thousands separators.
/// * `≥ 1` — four fraction digits. That is the resolution a dollar-scale pool
///   actually quotes at.
/// * `< 1` — four significant digits, counted from the first non-zero one, so
///   `0.0000078123` prints as `0.000007812` and never as `0.00`.
///
/// Grouping comes from [loopFormatDecimal], and no `double` is involved
/// anywhere: the rounding runs on [Decimal].
String loopFormatCandlePrice(Decimal value) {
  final absolute = value < Decimal.zero ? -value : value;
  if (absolute >= _candleLargeFrom) {
    return loopFormatDecimal(value, maxFractionDigits: 2);
  }
  if (absolute >= Decimal.one) {
    return loopFormatDecimal(value, maxFractionDigits: 4);
  }
  if (absolute == Decimal.zero) return loopFormatDecimal(value);
  // Find the first significant digit, then keep four of them.
  var scale = 0;
  var scaled = absolute;
  while (scaled < Decimal.one && scale < _candleSubUnitMaxScale) {
    scaled = scaled.shift(1);
    scale += 1;
  }
  return loopFormatDecimal(
    value,
    maxFractionDigits: scale + _candleSignificantDigits - 1,
  );
}

final Decimal _candleLargeFrom = Decimal.fromInt(1000);

/// How far below a dollar the sub-unit rule will look for a first significant
/// digit. A four.meme pool trades around 1e-6; this cap covers every price a
/// BSC pool has quoted and still terminates.
const int _candleSubUnitMaxScale = 18;
const int _candleSignificantDigits = 4;
