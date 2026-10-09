import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';

// ---------------------------------------------------------------------------
// The token chart (decision 0118)
// ---------------------------------------------------------------------------
//
// One component for `token` and `chart-full`: a close-price line by default,
// candles on request, panned by a horizontal drag, zoomed by a pinch between
// [LoopChartViewport.minVisible] and [LoopChartViewport.maxVisible] buckets,
// and read with a crosshair while a finger is held on it. The time axis
// under the plot carries four to six ticks and the price axis on the right
// four levels of the buckets on screen.
//
// Number discipline (AGENTS rule 25): every figure the chart prints — an
// axis level, the crosshair price, the latest close — is a `Decimal` read
// from the series or computed from two of its values. `double` exists only
// after a value has been normalised against the whole series' range, and is
// used for drawing alone.

/// How the series is drawn.
enum LoopChartStyle {
  /// The close of each bucket, joined (the default).
  line,

  /// Open / high / low / close bodies.
  candles,
}

/// Which slice of the series is on screen.
///
/// [endOffset] counts buckets hidden to the right of the window — 0 keeps the
/// newest bucket at the right edge. It is fractional while a finger pans.
@immutable
final class LoopChartViewport {
  const LoopChartViewport({
    required this.total,
    required this.visible,
    required this.endOffset,
  });

  /// The window a series opens on: the newest [defaultVisible] buckets.
  factory LoopChartViewport.initial(int total) => LoopChartViewport(
    total: total,
    visible: clampVisible(defaultVisible, total),
    endOffset: 0,
  );

  /// The fewest buckets a pinch may zoom in to.
  static const int minVisible = 20;

  /// The most buckets a pinch may zoom out to — one full candle read.
  static const int maxVisible = 300;

  /// The window the chart opens on.
  static const int defaultVisible = 60;

  final int total;
  final int visible;
  final double endOffset;

  /// [visible] bounded by the zoom limits and by the series itself: a series
  /// shorter than [minVisible] is shown whole.
  static int clampVisible(int value, int total) {
    if (total <= 0) return 0;
    final upper = math.min(maxVisible, total);
    final lower = math.min(minVisible, upper);
    return value.clamp(lower, upper);
  }

  /// The farthest the window may be panned into the past.
  double get maxEndOffset => math.max(0, total - visible).toDouble();

  /// The fractional index of the window's left edge.
  double get start => total - visible - endOffset;

  /// The first and last bucket index at least partly on screen.
  int get firstIndex => math.max(0, start.floor());
  int get lastIndex => math.min(total - 1, (start + visible).ceil() - 1);

  /// The window moved by [buckets]: positive looks further into the past.
  LoopChartViewport panBy(double buckets) => LoopChartViewport(
    total: total,
    visible: visible,
    endOffset: (endOffset + buckets).clamp(0.0, maxEndOffset),
  );

  /// The window at [count] buckets, its right edge kept where it was.
  LoopChartViewport zoomTo(int count) {
    final next = clampVisible(count, total);
    return LoopChartViewport(
      total: total,
      visible: next,
      endOffset: endOffset.clamp(0.0, math.max(0, total - next).toDouble()),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LoopChartViewport &&
      other.total == total &&
      other.visible == visible &&
      other.endOffset == endOffset;

  @override
  int get hashCode => Object.hash(total, visible, endOffset);
}

/// How many time ticks a time axis [width] wide carries: one per ~80pt,
/// never fewer than four or more than six (decision 0118).
int loopChartTimeTickCount(double width) => (width / 80).floor().clamp(4, 6);

/// The bucket indices the time axis labels for [viewport], evenly spaced
/// across the window and never outside it.
List<int> loopChartTimeTickIndices(LoopChartViewport viewport, double width) {
  if (viewport.total == 0 || viewport.visible == 0) return const <int>[];
  final count = math.min(loopChartTimeTickCount(width), viewport.visible);
  final first = viewport.start.ceil().clamp(0, viewport.total - 1);
  final last = (viewport.start + viewport.visible - 1).floor().clamp(
    first,
    viewport.total - 1,
  );
  final out = <int>[];
  for (var tick = 0; tick < count; tick += 1) {
    final index = (viewport.start + (tick + 0.5) * viewport.visible / count)
        .floor();
    final bounded = index.clamp(first, last);
    if (out.isEmpty || out.last != bounded) out.add(bounded);
  }
  return List<int>.unmodifiable(out);
}

/// A tick's label: the clock for intraday buckets, the date for daily ones.
String loopChartTimeLabel(DateTime at, LoopCandleInterval interval) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return switch (interval) {
    LoopCandleInterval.fifteenMinutes ||
    LoopCandleInterval.oneHour => '${two(local.hour)}:${two(local.minute)}',
    LoopCandleInterval.fourHours =>
      '${two(local.month)}-${two(local.day)} ${two(local.hour)}:00',
    LoopCandleInterval.oneDay => '${two(local.month)}-${two(local.day)}',
    LoopCandleInterval.oneWeek => '${local.year}-${two(local.month)}',
  };
}

/// The crosshair's time: date and clock, so a bucket is never ambiguous.
String loopChartCrosshairTime(DateTime at) {
  final local = at.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// The chip label of each interval on the token chart.
String loopChartIntervalLabel(LoopCandleInterval interval) =>
    switch (interval) {
      LoopCandleInterval.fifteenMinutes => '15分',
      LoopCandleInterval.oneHour => '1时',
      LoopCandleInterval.fourHours => '4时',
      LoopCandleInterval.oneDay => '1日',
      LoopCandleInterval.oneWeek => '1周',
    };

/// The series normalised once against its own whole range.
///
/// Every value is `(v − low) / (high − low)` computed in `Decimal` and only
/// then turned into a `double`; the window rescales those ratios, which are
/// dimensionless, and never turns one back into a price.
final class _NormalisedSeries {
  _NormalisedSeries(this.candles, List<int> averagePeriods)
    : low = _low(candles),
      high = _high(candles) {
    final span = high - low;
    double ratio(Decimal value) => span == Decimal.zero
        ? 0.5
        : ((value - low) / span).toDouble().clamp(0.0, 1.0);
    open = <double>[for (final c in candles) ratio(c.open)];
    close = <double>[for (final c in candles) ratio(c.close)];
    highs = <double>[for (final c in candles) ratio(c.high)];
    lows = <double>[for (final c in candles) ratio(c.low)];
    var peak = Decimal.zero;
    for (final candle in candles) {
      if (candle.volume > peak) peak = candle.volume;
    }
    volume = <double>[
      for (final c in candles)
        peak <= Decimal.zero ? 0 : (c.volume / peak).toDouble().clamp(0.0, 1.0),
    ];
    averages = <List<double>>[
      for (final period in averagePeriods)
        <double>[
          for (final value in loopCandleMovingAverage(candles, period))
            ratio(value),
        ],
    ];
  }

  final List<LoopCandle> candles;
  final Decimal low;
  final Decimal high;
  late final List<double> open;
  late final List<double> close;
  late final List<double> highs;
  late final List<double> lows;
  late final List<double> volume;
  late final List<List<double>> averages;

  static Decimal _low(List<LoopCandle> candles) {
    var value = candles.first.low;
    for (final candle in candles) {
      if (candle.low < value) value = candle.low;
      if (candle.close < value) value = candle.close;
    }
    return value;
  }

  static Decimal _high(List<LoopCandle> candles) {
    var value = candles.first.high;
    for (final candle in candles) {
      if (candle.high > value) value = candle.high;
      if (candle.close > value) value = candle.close;
    }
    return value;
  }
}

/// Where everything sits for one size and one window.
final class _ChartGeometry {
  _ChartGeometry({
    required this.size,
    required this.viewport,
    required this.series,
    required this.style,
    required this.showVolume,
    required this.showAverages,
  }) {
    final plotBottom = size.height - timeAxisHeight;
    final right = math.max(1.0, size.width - priceAxisWidth);
    final volumeHeight = showVolume ? (plotBottom - topPadding) * 0.18 : 0.0;
    price = Rect.fromLTRB(
      0,
      topPadding,
      right,
      math.max(
        topPadding + 1,
        plotBottom - volumeHeight - (showVolume ? 6 : 4),
      ),
    );
    volume = showVolume
        ? Rect.fromLTRB(0, plotBottom - volumeHeight, right, plotBottom - 1)
        : Rect.zero;
    slot = price.width / math.max(1, viewport.visible);
    var lo = 1.0;
    var hi = 0.0;
    var lowIndex = viewport.firstIndex;
    var highIndex = viewport.firstIndex;
    var volumePeak = 0.0;
    for (var i = viewport.firstIndex; i <= viewport.lastIndex; i += 1) {
      final bottom = style == LoopChartStyle.line
          ? series.close[i]
          : series.lows[i];
      final top = style == LoopChartStyle.line
          ? series.close[i]
          : series.highs[i];
      if (bottom < lo) {
        lo = bottom;
        lowIndex = i;
      }
      if (top > hi) {
        hi = top;
        highIndex = i;
      }
      if (series.volume[i] > volumePeak) volumePeak = series.volume[i];
    }
    if (hi < lo) {
      lo = 0;
      hi = 1;
    }
    lowRatio = lo;
    highRatio = hi;
    this.lowIndex = lowIndex;
    this.highIndex = highIndex;
    this.volumePeak = volumePeak;
  }

  static const double priceAxisWidth = 58;
  static const double timeAxisHeight = 18;
  static const double topPadding = 10;

  final Size size;
  final LoopChartViewport viewport;
  final _NormalisedSeries series;
  final LoopChartStyle style;
  final bool showVolume;
  final bool showAverages;

  late final Rect price;
  late final Rect volume;
  late final double slot;
  late final double lowRatio;
  late final double highRatio;
  late final int lowIndex;
  late final int highIndex;
  late final double volumePeak;

  double xFor(int index) => price.left + (index - viewport.start + 0.5) * slot;

  double yFor(double ratio) {
    final span = highRatio - lowRatio;
    final inner = price.deflate(4);
    if (span <= 0) return inner.center.dy;
    final t = ((ratio - lowRatio) / span).clamp(-0.2, 1.2);
    return inner.bottom - t * inner.height;
  }

  /// The bucket under [dx], held inside the window.
  int indexAt(double dx) {
    final raw = (viewport.start + (dx - price.left) / slot).floor();
    return raw.clamp(viewport.firstIndex, viewport.lastIndex);
  }

  /// The value of the window's lowest and highest drawn point, exactly.
  Decimal get windowLow {
    final candle = series.candles[lowIndex];
    return style == LoopChartStyle.line ? candle.close : candle.low;
  }

  Decimal get windowHigh {
    final candle = series.candles[highIndex];
    return style == LoopChartStyle.line ? candle.close : candle.high;
  }
}

/// The token chart: line or candles, pan, pinch, crosshair, two axes.
class LoopMarketChart extends StatefulWidget {
  const LoopMarketChart({
    required this.candles,
    required this.interval,
    required this.semanticLabel,
    super.key,
    this.style = LoopChartStyle.line,
    this.showMovingAverages = false,
    this.showVolume = true,
    this.height = 280,
    this.edgeGuard = 24,
  });

  final List<LoopCandle> candles;
  final LoopCandleInterval interval;
  final String semanticLabel;
  final LoopChartStyle style;

  /// MA7 and MA25 over the closes on screen. Computed here, never sourced.
  final bool showMovingAverages;
  final bool showVolume;
  final double height;

  /// The strip along the left edge that answers no gesture, so the system's
  /// edge-swipe back is never taken by the chart (decision 0118).
  final double edgeGuard;

  /// The two averages the MA switch draws.
  static const List<int> averagePeriods = <int>[7, 25];

  @override
  State<LoopMarketChart> createState() => LoopMarketChartState();
}

/// Public so a test can read the window and the crosshair.
class LoopMarketChartState extends State<LoopMarketChart> {
  late _NormalisedSeries _series;
  late LoopChartViewport _viewport;
  int? _crosshair;

  int _gestureVisible = 0;
  double _lastFocalX = 0;
  int _lastPointers = 0;
  double _width = 0;

  /// The window on screen.
  LoopChartViewport get viewport => _viewport;

  /// The bucket the crosshair is on, or `null` while no finger is held.
  int? get crosshairIndex => _crosshair;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(covariant LoopMarketChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.candles, widget.candles) ||
        oldWidget.interval != widget.interval) {
      _reset();
    }
  }

  void _reset() {
    _series = _NormalisedSeries(widget.candles, LoopMarketChart.averagePeriods);
    _viewport = LoopChartViewport.initial(widget.candles.length);
    _crosshair = null;
  }

  _ChartGeometry _geometry(Size size) => _ChartGeometry(
    size: size,
    viewport: _viewport,
    series: _series,
    style: widget.style,
    showVolume: widget.showVolume,
    showAverages: widget.showMovingAverages,
  );

  void _onScaleStart(ScaleStartDetails details) {
    _gestureVisible = _viewport.visible;
    _lastFocalX = details.localFocalPoint.dx;
    _lastPointers = details.pointerCount;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount != _lastPointers) {
      // A finger joined or left: start measuring again from here.
      _lastPointers = details.pointerCount;
      _lastFocalX = details.localFocalPoint.dx;
      _gestureVisible = _viewport.visible;
      return;
    }
    if (details.pointerCount >= 2) {
      final scale = details.scale <= 0 ? 1.0 : details.scale;
      final target = (_gestureVisible / scale).round();
      final next = _viewport.zoomTo(target);
      if (next != _viewport) setState(() => _viewport = next);
      return;
    }
    final dx = details.localFocalPoint.dx - _lastFocalX;
    _lastFocalX = details.localFocalPoint.dx;
    final slot =
        (_width - _ChartGeometry.priceAxisWidth) /
        math.max(1, _viewport.visible);
    if (slot <= 0) return;
    final next = _viewport.panBy(dx / slot);
    if (next != _viewport) setState(() => _viewport = next);
  }

  void _crosshairAt(double dx) {
    final geometry = _geometry(Size(_width, widget.height));
    final index = geometry.indexAt(dx + widget.edgeGuard);
    if (index != _crosshair) setState(() => _crosshair = index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) {
      return SizedBox(height: widget.height);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final size = Size(constraints.maxWidth, widget.height);
        final geometry = _geometry(size);
        final crosshair = _crosshair;
        final ticks = loopChartTimeTickIndices(_viewport, geometry.price.width);
        return Semantics(
          key: const ValueKey<String>('loop-market-chart-semantics'),
          container: true,
          image: true,
          label: widget.semanticLabel,
          child: SizedBox(
            key: const ValueKey<String>('loop-market-chart'),
            height: widget.height,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      key: const ValueKey<String>('loop-market-chart-canvas'),
                      painter: _LoopMarketChartPainter(
                        geometry: geometry,
                        style: widget.style,
                        showVolume: widget.showVolume,
                        showAverages: widget.showMovingAverages,
                        crosshair: crosshair,
                        textScaler: MediaQuery.textScalerOf(context),
                      ),
                    ),
                  ),
                ),
                // The time axis is laid out as text so it can be read and
                // counted; the painter draws only the tick marks above it.
                for (final index in ticks)
                  Positioned(
                    key: ValueKey<String>('loop-market-chart-tick-$index'),
                    left: (geometry.xFor(index) - 36).clamp(
                      0.0,
                      math.max(0.0, geometry.price.right - 72),
                    ),
                    width: 72,
                    bottom: 0,
                    height: _ChartGeometry.timeAxisHeight,
                    child: ExcludeSemantics(
                      child: Text(
                        loopChartTimeLabel(
                          widget.candles[index].openTime,
                          widget.interval,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: LoopType.figureXs.copyWith(
                          color: LoopColors.text3,
                        ),
                      ),
                    ),
                  ),
                if (crosshair != null)
                  ..._crosshairBubbles(geometry, crosshair),
                // Gestures start [edgeGuard] in from the left edge.
                Positioned(
                  left: widget.edgeGuard,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    key: const ValueKey<String>('loop-market-chart-gestures'),
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onLongPressStart: (details) {
                      // Decision 0130: the crosshair appearing is a pick-up.
                      LoopHaptics.medium();
                      _crosshairAt(details.localPosition.dx);
                    },
                    onLongPressMoveUpdate: (details) =>
                        _crosshairAt(details.localPosition.dx),
                    onLongPressEnd: (_) => setState(() => _crosshair = null),
                    onLongPressCancel: () => setState(() => _crosshair = null),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _crosshairBubbles(_ChartGeometry geometry, int index) {
    final candle = widget.candles[index];
    final y = geometry.yFor(_series.close[index]);
    final x = geometry.xFor(index);
    return <Widget>[
      Positioned(
        key: const ValueKey<String>('loop-market-chart-crosshair-price'),
        right: 0,
        top: (y - 10).clamp(0.0, math.max(0.0, widget.height - 40)),
        height: 20,
        width: _ChartGeometry.priceAxisWidth,
        child: _Bubble(text: loopFormatCandlePrice(candle.close)),
      ),
      Positioned(
        key: const ValueKey<String>('loop-market-chart-crosshair-time'),
        left: (x - 48).clamp(0.0, math.max(0.0, geometry.price.right - 96)),
        bottom: 0,
        height: _ChartGeometry.timeAxisHeight,
        width: 96,
        child: _Bubble(text: loopChartCrosshairTime(candle.openTime)),
      ),
    ];
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: LoopColors.chalk,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Center(
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: LoopType.figureXs.copyWith(color: LoopColors.ink),
      ),
    ),
  );
}

class _LoopMarketChartPainter extends CustomPainter {
  _LoopMarketChartPainter({
    required this.geometry,
    required this.style,
    required this.showVolume,
    required this.showAverages,
    required this.crosshair,
    required this.textScaler,
  });

  final _ChartGeometry geometry;
  final LoopChartStyle style;
  final bool showVolume;
  final bool showAverages;
  final int? crosshair;
  final TextScaler textScaler;

  _NormalisedSeries get series => geometry.series;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.price;
    _paintGrid(canvas, plot);
    _paintPriceAxis(canvas, size);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(plot.left, 0, plot.right, size.height));
    if (showVolume) _paintVolume(canvas);
    if (style == LoopChartStyle.line) {
      _paintLine(canvas);
    } else {
      _paintCandles(canvas);
    }
    if (showAverages) _paintAverages(canvas);
    _paintTicks(canvas);
    final index = crosshair;
    if (index != null) _paintCrosshair(canvas, index);
    canvas.restore();
    _paintLastPrice(canvas, size);
  }

  void _paintGrid(Canvas canvas, Rect plot) {
    final paint = Paint()
      ..color = LoopColors.chalk.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var row = 0; row < 4; row += 1) {
      final y = plot.top + 4 + (plot.height - 8) * row / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
    }
  }

  /// Four levels between the window's lowest and highest point, exactly.
  void _paintPriceAxis(Canvas canvas, Size size) {
    final low = geometry.windowLow;
    final high = geometry.windowHigh;
    final span = high - low;
    final plot = geometry.price;
    for (var row = 0; row < 4; row += 1) {
      final y = plot.top + 4 + (plot.height - 8) * row / 3;
      final value = span == Decimal.zero
          ? high
          : high -
                (span * Decimal.fromInt(row) / Decimal.fromInt(3)).toDecimal(
                  scaleOnInfinitePrecision: 24,
                );
      final painter = TextPainter(
        text: TextSpan(
          text: loopFormatCandlePrice(value),
          style: LoopTypography.figure(
            9,
            color: LoopColors.chalk.withValues(alpha: 0.5),
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
        maxLines: 1,
      )..layout(maxWidth: _ChartGeometry.priceAxisWidth - 6);
      painter.paint(
        canvas,
        Offset(size.width - painter.width - 2, y - painter.height / 2),
      );
      painter.dispose();
    }
  }

  Color get _lineColor {
    final first = series.candles[geometry.viewport.firstIndex].close;
    final last = series.candles[geometry.viewport.lastIndex].close;
    final move = LoopPriceMove.between(open: first, close: last);
    return move.isDirectional ? move.color : LoopColors.chalk;
  }

  void _paintLine(Canvas canvas) {
    final viewport = geometry.viewport;
    final path = Path();
    for (var i = viewport.firstIndex; i <= viewport.lastIndex; i += 1) {
      final point = Offset(geometry.xFor(i), geometry.yFor(series.close[i]));
      if (i == viewport.firstIndex) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    final color = _lineColor;
    final plot = geometry.price;
    final fill = Path.from(path)
      ..lineTo(geometry.xFor(viewport.lastIndex), plot.bottom)
      ..lineTo(geometry.xFor(viewport.firstIndex), plot.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0),
          ],
        ).createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintCandles(Canvas canvas) {
    final viewport = geometry.viewport;
    final body = (geometry.slot * 0.62).clamp(1.0, 12.0);
    for (var i = viewport.firstIndex; i <= viewport.lastIndex; i += 1) {
      final candle = series.candles[i];
      final move = LoopPriceMove.between(
        open: candle.open,
        close: candle.close,
      );
      final color = move == LoopPriceMove.down
          ? LoopColors.fall
          : LoopColors.rise;
      final x = geometry.xFor(i);
      final wick = Paint()
        ..color = color
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(x, geometry.yFor(series.highs[i])),
        Offset(x, geometry.yFor(series.lows[i])),
        wick,
      );
      final openY = geometry.yFor(series.open[i]);
      final closeY = geometry.yFor(series.close[i]);
      var top = math.min(openY, closeY);
      var bottom = math.max(openY, closeY);
      if (bottom - top < 1.5) {
        final middle = (top + bottom) / 2;
        top = middle - 0.75;
        bottom = middle + 0.75;
      }
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x - body / 2, top, x + body / 2, bottom),
        const Radius.circular(1),
      );
      if (candle.isOpen) {
        // A bucket that has not closed is an outline: it will still move.
        canvas.drawRRect(
          rect,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      } else {
        canvas.drawRRect(rect, Paint()..color = color);
      }
    }
  }

  void _paintVolume(Canvas canvas) {
    final area = geometry.volume;
    final peak = geometry.volumePeak;
    if (area.isEmpty || peak <= 0) return;
    final viewport = geometry.viewport;
    final body = (geometry.slot * 0.62).clamp(1.0, 12.0);
    for (var i = viewport.firstIndex; i <= viewport.lastIndex; i += 1) {
      final candle = series.candles[i];
      final down = candle.close < candle.open;
      final ratio = (series.volume[i] / peak).clamp(0.0, 1.0);
      final x = geometry.xFor(i);
      canvas.drawRect(
        Rect.fromLTRB(
          x - body / 2,
          area.bottom - math.max(0.5, ratio * area.height),
          x + body / 2,
          area.bottom,
        ),
        Paint()
          ..color = (down ? LoopColors.fall : LoopColors.rise).withValues(
            alpha: 0.32,
          ),
      );
    }
  }

  void _paintAverages(Canvas canvas) {
    final viewport = geometry.viewport;
    for (var line = 0; line < series.averages.length; line += 1) {
      final values = series.averages[line];
      if (values.length < 2) continue;
      final path = Path();
      for (var i = viewport.firstIndex; i <= viewport.lastIndex; i += 1) {
        final point = Offset(geometry.xFor(i), geometry.yFor(values[i]));
        if (i == viewport.firstIndex) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = line == 0
              ? LoopColors.warning.withValues(alpha: 0.85)
              : LoopColors.chalk.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
    }
  }

  void _paintTicks(Canvas canvas) {
    final plot = geometry.price;
    final paint = Paint()
      ..color = LoopColors.chalk.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (final index in loopChartTimeTickIndices(
      geometry.viewport,
      plot.width,
    )) {
      final x = geometry.xFor(index);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), paint);
    }
  }

  void _paintCrosshair(Canvas canvas, int index) {
    final plot = geometry.price;
    final x = geometry.xFor(index);
    final y = geometry.yFor(series.close[index]);
    final paint = Paint()
      ..color = LoopColors.chalk.withValues(alpha: 0.7)
      ..strokeWidth = 0.8;
    _dashed(
      canvas,
      Offset(x, plot.top),
      Offset(x, geometry.size.height - _ChartGeometry.timeAxisHeight),
      paint,
    );
    _dashed(canvas, Offset(plot.left, y), Offset(plot.right, y), paint);
    canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = LoopColors.chalk);
  }

  /// The newest close: a dashed rule across the plot and its figure on the
  /// price axis, while the newest bucket is on screen.
  void _paintLastPrice(Canvas canvas, Size size) {
    final viewport = geometry.viewport;
    if (viewport.endOffset >= 1) return;
    final lastIndex = series.candles.length - 1;
    final y = geometry.yFor(series.close[lastIndex]);
    final color = style == LoopChartStyle.line ? _lineColor : LoopColors.chalk;
    final plot = geometry.price;
    _dashed(
      canvas,
      Offset(plot.left, y),
      Offset(plot.right, y),
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..strokeWidth = 0.8,
    );
    if (style == LoopChartStyle.line) {
      canvas.drawCircle(
        Offset(geometry.xFor(lastIndex), y),
        3.5,
        Paint()..color = color,
      );
    }
    final painter = TextPainter(
      text: TextSpan(
        text: loopFormatCandlePrice(series.candles[lastIndex].close),
        style: LoopTypography.figure(9, color: LoopColors.ink),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout(maxWidth: _ChartGeometry.priceAxisWidth - 6);
    final box = Rect.fromLTWH(
      size.width - _ChartGeometry.priceAxisWidth + 1,
      (y - 8).clamp(0.0, size.height - 16),
      _ChartGeometry.priceAxisWidth - 2,
      16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(3)),
      Paint()..color = color,
    );
    painter.paint(
      canvas,
      Offset(box.right - painter.width - 3, box.center.dy - painter.height / 2),
    );
    painter.dispose();
  }

  void _dashed(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 3.0;
    const gap = 3.0;
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

  @override
  bool shouldRepaint(covariant _LoopMarketChartPainter oldDelegate) =>
      oldDelegate.geometry.viewport != geometry.viewport ||
      oldDelegate.geometry.size != geometry.size ||
      !identical(oldDelegate.series, series) ||
      oldDelegate.style != style ||
      oldDelegate.showVolume != showVolume ||
      oldDelegate.showAverages != showAverages ||
      oldDelegate.crosshair != crosshair ||
      oldDelegate.textScaler != textScaler;
}
