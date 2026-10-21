import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

// ---------------------------------------------------------------------------
// 钱包 C · the net-worth history under 总资产 (decision 0188)
// ---------------------------------------------------------------------------
//
// A 7-day sparkline beside the total, which opens in place into a 200-high
// area chart with its high and low marked and five windows to choose from.
// Every figure is a snapshot the server stored; nothing here is summed from
// the balances, and `double` appears only once a value has been normalised
// into the plot's pixel space (AGENTS rule 25).

/// What a masked figure prints (the same four stars as the rest of 钱包).
const String _masked = '****';

/// `+$12.08 (+10.4%)` — a signed USD move and its percent.
///
/// Masked, the amount is four stars and the percent stays: a share of the
/// total discloses no figure.
String walletSignedUsdText(Decimal usd, Decimal pct, {bool hidden = false}) {
  final sign = usd > Decimal.zero
      ? '+'
      : usd < Decimal.zero
      ? '-'
      : '';
  final magnitude = usd < Decimal.zero ? -usd : usd;
  final amount = hidden ? _masked : '$sign${loopFormatUsd(magnitude)}';
  return '$amount (${loopFormatPercent(pct)})';
}

/// The 88 × 44 seven-day line beside the total. Drawn only for a history
/// with two snapshots or more; tapping it opens the chart.
class WalletNetWorthSpark extends StatelessWidget {
  const WalletNetWorthSpark({
    required this.history,
    required this.onTap,
    super.key,
  });

  static const Size size = Size(88, 44);

  final LoopNetWorthHistory history;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '7 天净值走势，点按展开',
      excludeSemantics: true,
      child: LoopPressable(
        key: const ValueKey<String>('wallet-networth-spark'),
        onTap: onTap,
        child: SizedBox.fromSize(
          size: size,
          child: LoopSparkline(
            closes: <Decimal>[
              for (final point in history.points) point.netWorthUsd,
            ],
            semanticLabel: '7 天净值走势',
            color: LoopColors.yellow,
          ),
        ),
      ),
    );
  }
}

/// Whether every snapshot of [history] is zero (decision 0224): its line
/// would be a flat rule.
bool walletNetWorthAllZero(LoopNetWorthHistory history) =>
    history.points.every((point) => point.netWorthUsd == Decimal.zero);

/// The 88 × 44 slot when the history is zero all the way (decision 0224): no
/// flat Yellow rule, a short Yellow spray stroke instead. It still opens the
/// chart.
class WalletNetWorthSparkSpray extends StatelessWidget {
  const WalletNetWorthSparkSpray({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '7 天净值走势，点按展开',
    excludeSemantics: true,
    child: LoopPressable(
      key: const ValueKey<String>('wallet-networth-spark-spray'),
      onTap: onTap,
      child: SizedBox.fromSize(
        size: WalletNetWorthSpark.size,
        child: Center(
          child: Opacity(
            opacity: 0.8,
            child: Transform.rotate(
              angle: -8 * math.pi / 180,
              child: loopAtmoArt(LoopAtmoAssets.splatYellow, width: 44),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The 88 × 44 slot when the 7-day history was read but cannot be drawn
/// (fewer than two snapshots — a new or empty wallet): a dashed Text3
/// baseline over 「净值走势 · 记录中」, so the slot still says a chart lives
/// here (decision 0193). It carries no figure, so 隐藏余额 leaves it alone.
/// Tapping it opens the chart, as the sparkline does.
class WalletNetWorthSparkPlaceholder extends StatelessWidget {
  const WalletNetWorthSparkPlaceholder({required this.onTap, super.key});

  static const String caption = '净值走势 · 记录中';

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final auxiliary = LoopGround.auxiliaryOf(context);
    final secondary = LoopGround.secondaryOf(context);
    return Semantics(
      button: true,
      label: '净值走势记录中，点按展开',
      excludeSemantics: true,
      child: LoopPressable(
        key: const ValueKey<String>('wallet-networth-spark-placeholder'),
        onTap: onTap,
        child: SizedBox.fromSize(
          size: WalletNetWorthSpark.size,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: CustomPaint(
                  key: const ValueKey<String>(
                    'wallet-networth-spark-placeholder-line',
                  ),
                  painter: WalletNetWorthDashPainter(color: auxiliary),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  caption,
                  key: const ValueKey<String>(
                    'wallet-networth-spark-placeholder-text',
                  ),
                  maxLines: 1,
                  style: LoopType.captionSm.copyWith(color: secondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One dashed horizontal line through the middle of its box.
class WalletNetWorthDashPainter extends CustomPainter {
  const WalletNetWorthDashPainter({required this.color});

  final Color color;

  static const double dash = 4;
  static const double gap = 3;
  static const double strokeWidth = 1;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WalletNetWorthDashPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The same slot while the 7-day history is being read.
class WalletNetWorthSparkSkeleton extends StatelessWidget {
  const WalletNetWorthSparkSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      key: const ValueKey<String>('wallet-networth-spark-loading'),
      size: WalletNetWorthSpark.size,
      child: LoopSkeletonBlock(
        width: WalletNetWorthSpark.size.width,
        height: WalletNetWorthSpark.size.height,
      ),
    );
  }
}

/// ⌄ / ⌃ — the one-line switch that opens or closes the chart, labelled
/// 「净值走势」 closed and 「收起」 open (decision 0193).
class WalletNetWorthChevron extends StatelessWidget {
  const WalletNetWorthChevron({
    required this.expanded,
    required this.onTap,
    super.key,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final auxiliary = LoopGround.auxiliaryOf(context);
    return Semantics(
      button: true,
      expanded: expanded,
      label: expanded ? '收起净值走势' : '展开净值走势',
      excludeSemantics: true,
      child: LoopPressable(
        key: ValueKey<String>(
          expanded ? 'wallet-networth-collapse' : 'wallet-networth-expand',
        ),
        scale: false,
        onTap: onTap,
        child: SizedBox(
          height: LoopTouch.minimum,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                expanded ? '收起' : '净值走势',
                key: const ValueKey<String>('wallet-networth-chevron-label'),
                maxLines: 1,
                style: LoopType.captionSm.copyWith(
                  color: LoopGround.secondaryOf(context),
                ),
              ),
              const SizedBox(width: 4),
              RotatedBox(
                // The chevron sprite points right; a quarter turn points down.
                quarterTurns: expanded ? 3 : 1,
                child: LoopIcon('chevron', size: 14, color: auxiliary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The opened chart: the area, the five windows and ⌃.
///
/// [state] is the read for [range]; `null` while it has not been asked for.
/// A failed read is one [LoopInlineUnavailable] line — it never holds the
/// chart's 200 points of height open for nothing.
class WalletNetWorthPanel extends StatelessWidget {
  const WalletNetWorthPanel({
    required this.state,
    required this.range,
    required this.hidden,
    required this.onRange,
    required this.onRetry,
    required this.onCollapse,
    super.key,
  });

  static const double chartHeight = 200;

  final LoopChainResourceState<LoopNetWorthHistory>? state;
  final LoopNetWorthRange range;
  final bool hidden;
  final ValueChanged<LoopNetWorthRange> onRange;
  final VoidCallback onRetry;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final read = state;
    final history = read?.value;
    final Widget body;
    if (history != null && history.range == range) {
      body = history.drawable
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                WalletNetWorthChart(history: history, hidden: hidden),
                _provenance(history),
              ],
            )
          : const LoopInlineUnavailable(
              key: ValueKey<String>('wallet-networth-chart-empty'),
              icon: 'info',
              message: '这个区间还没有净值记录 · 每小时记一次，有资产后开始画线',
              padding: EdgeInsets.zero,
            );
    } else if (read == null ||
        read.phase == LoopChainViewPhase.loading ||
        read.failureKind == null) {
      body = const Padding(
        key: ValueKey<String>('wallet-networth-chart-loading'),
        padding: EdgeInsets.only(top: 4),
        child: LoopSkeletonBlock(height: chartHeight, radius: 12),
      );
    } else {
      body = LoopInlineUnavailable(
        key: const ValueKey<String>('wallet-networth-chart-unavailable'),
        message: '净值走势暂时读不到',
        onRetry: read.phase == LoopChainViewPhase.permission ? null : onRetry,
        retrying: read.refreshing,
        padding: EdgeInsets.zero,
      );
    }
    return Column(
      key: const ValueKey<String>('wallet-networth-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(padding: const EdgeInsets.only(top: 4, right: 8), child: body),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              key: const ValueKey<String>('wallet-networth-ranges'),
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final option in LoopNetWorthRange.values)
                  LoopSeg(
                    key: ValueKey<String>(
                      'wallet-networth-range-${option.wireName}',
                    ),
                    label: option.label,
                    quiet: true,
                    selected: option == range,
                    onSelected: () => onRange(option),
                  ),
              ],
            ),
          ),
        ),
        WalletNetWorthChevron(expanded: true, onTap: onCollapse),
      ],
    );
  }

  Widget _provenance(LoopNetWorthHistory history) {
    final source = history.source;
    final parsed = source == null ? null : LoopFactSource.tryParse(source);
    final fx = history.fiat == null
        ? null
        : walletFxProvenanceText(history.fiat!);
    final line = LoopProvenanceLine(
      key: const ValueKey<String>('wallet-networth-provenance'),
      prefix: '净值快照',
      sources: <String>[
        if (parsed != null) loopFactSourceLabel(parsed) else 'LOOP 净值快照',
      ],
      observedAt: history.observedAt ?? history.currentAt,
      detail:
          '走势是服务端每小时为这个钱包记下的 USD 估值，只用于展示，'
          '不是可用余额。',
      padding: EdgeInsets.zero,
    );
    if (fx == null) return line;
    // Decision 0194: the ¥ beside the total is a restatement at a published
    // rate, so the rate says where it came from right under the chart too.
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          line,
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              fx,
              key: const ValueKey<String>('wallet-networth-fx-provenance'),
              style: LoopType.captionSm.copyWith(
                color: LoopGround.secondaryOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// zh-CN name of a rate publisher. An identifier LOOP does not know is
/// 「参考汇率」, never the raw word.
String walletFxSourceLabel(String source) => switch (source) {
  'ecb' => '欧洲央行参考汇率',
  _ => '参考汇率',
};

/// Decision 0194: the sentence that says where the ¥ came from —
/// 「人民币按欧洲央行参考汇率 1 USD = 6.6921 CNY（10-15 发布，观察于 11:20）折算」,
/// with 「，数据可能过期」 when the rate is stale. `null` for a non-CNY
/// restatement or a pre-0194 body without provenance: nothing is invented.
///
/// The publication day is a calendar date (UTC); the observation time is
/// the device's local clock, with its date when it is not today.
String? walletFxProvenanceText(LoopNetWorthFiat fiat, {DateTime? now}) {
  final source = fiat.source;
  final asOf = fiat.asOf;
  final fetchedAt = fiat.fetchedAt;
  if (fiat.currency != 'CNY' ||
      !fiat.hasProvenance ||
      source == null ||
      asOf == null ||
      fetchedAt == null) {
    return null;
  }
  String two(int value) => value.toString().padLeft(2, '0');
  final today = (now ?? DateTime.now()).toLocal();
  final seen = fetchedAt.toLocal();
  final sameDay =
      seen.year == today.year &&
      seen.month == today.month &&
      seen.day == today.day;
  final observed = sameDay
      ? loopClockLabel(seen)
      : '${two(seen.month)}-${two(seen.day)} ${loopClockLabel(seen)}';
  final published = '${two(asOf.month)}-${two(asOf.day)}';
  final rate = loopFormatDecimal(fiat.rate, maxFractionDigits: 6);
  final stale = fiat.stale
      ? '，${loopFactQualityMarker(LoopFactQuality.stale)}'
      : '';
  return '人民币按${walletFxSourceLabel(source)} 1 USD = $rate CNY'
      '（$published 发布，观察于 $observed）折算$stale';
}

/// The 200-high area chart: a Lime line over a Lime wash that fades from
/// 28 % to nothing, with the window's high and low printed beside them.
class WalletNetWorthChart extends StatelessWidget {
  const WalletNetWorthChart({
    required this.history,
    required this.hidden,
    super.key,
  });

  final LoopNetWorthHistory history;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final values = <Decimal>[
      for (final point in history.points) point.netWorthUsd,
    ];
    final extremes = WalletNetWorthChartPainter.extremes(values);
    final high = values[extremes.high];
    final low = values[extremes.low];
    final highText = hidden ? _masked : loopFormatUsd(high);
    final lowText = hidden ? _masked : loopFormatUsd(low);
    final labelStyle = LoopType.figureXs.copyWith(color: LoopColors.text2);
    return Semantics(
      container: true,
      image: true,
      label: '${history.range.label}净值走势，最高 $highText，最低 $lowText',
      child: ExcludeSemantics(
        child: SizedBox(
          key: const ValueKey<String>('wallet-networth-chart'),
          height: WalletNetWorthPanel.chartHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth,
                WalletNetWorthPanel.chartHeight,
              );
              final points = WalletNetWorthChartPainter.points(values, size);
              final highAt = points[extremes.high];
              final lowAt = points[extremes.low];
              const labelWidth = 96.0;
              double left(double x) => (x - labelWidth / 2)
                  .clamp(0.0, math.max(0.0, size.width - labelWidth))
                  .toDouble();
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: WalletNetWorthChartPainter(values: values),
                    ),
                  ),
                  Positioned(
                    left: left(highAt.dx),
                    top: 0,
                    width: labelWidth,
                    child: Text(
                      highText,
                      key: const ValueKey<String>('wallet-networth-high'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: labelStyle,
                    ),
                  ),
                  Positioned(
                    left: left(lowAt.dx),
                    bottom: 0,
                    width: labelWidth,
                    child: Text(
                      lowText,
                      key: const ValueKey<String>('wallet-networth-low'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      style: labelStyle,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Paints the area. Exposed so a test can read the geometry and the wash.
class WalletNetWorthChartPainter extends CustomPainter {
  const WalletNetWorthChartPainter({required this.values});

  final List<Decimal> values;

  /// Room above for the high's label and below for the low's.
  static const EdgeInsets plotPadding = EdgeInsets.fromLTRB(0, 18, 0, 18);
  static const double strokeWidth = 2;

  /// The wash at the line, as an alpha of Lime; it fades to zero at the
  /// bottom of the plot (docs/35 · 钱包 C).
  static const double washAlpha = 0.28;

  /// The indices of the first highest and the first lowest snapshot.
  static ({int high, int low}) extremes(List<Decimal> values) {
    var high = 0;
    var low = 0;
    for (var index = 1; index < values.length; index++) {
      if (values[index] > values[high]) high = index;
      if (values[index] < values[low]) low = index;
    }
    return (high: high, low: low);
  }

  static Rect plotRect(Size size) => Rect.fromLTRB(
    plotPadding.left,
    plotPadding.top,
    math.max(plotPadding.left, size.width - plotPadding.right),
    math.max(plotPadding.top, size.height - plotPadding.bottom),
  );

  /// The points the line runs through, oldest at the left edge. A flat
  /// history sits on the plot's middle.
  static List<Offset> points(List<Decimal> values, Size size) {
    if (values.isEmpty) return const <Offset>[];
    final plot = plotRect(size);
    final range = extremes(values);
    final lowest = values[range.low];
    final span = values[range.high] - lowest;
    final steps = values.length - 1;
    return <Offset>[
      for (var index = 0; index < values.length; index++)
        Offset(
          steps == 0 ? plot.center.dx : plot.left + plot.width * index / steps,
          span == Decimal.zero
              ? plot.center.dy
              // The sole Decimal -> double boundary.
              : plot.bottom -
                    ((values[index] - lowest) / span).toDouble().clamp(
                          0.0,
                          1.0,
                        ) *
                        plot.height,
        ),
    ];
  }

  /// The wash's two stops, top to bottom.
  static List<Color> washColors() => <Color>[
    LoopColors.yellow.withValues(alpha: washAlpha),
    LoopColors.yellow.withValues(alpha: 0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final plotted = points(values, size);
    if (plotted.length < 2) return;
    final line = Path()..moveTo(plotted.first.dx, plotted.first.dy);
    for (final point in plotted.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final area = Path.from(line)
      ..lineTo(plotted.last.dx, size.height)
      ..lineTo(plotted.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: washColors(),
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = LoopColors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(WalletNetWorthChartPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values);
}

/// 今日盈亏 in its two states: the server's 24h move in rise / fall, or
/// 「暂无」 when it had no snapshot 24 hours old. Tapping it opens the chart.
class WalletPnlLine extends StatelessWidget {
  const WalletPnlLine({
    required this.keyPrefix,
    required this.change,
    required this.hidden,
    required this.onTap,
    super.key,
  });

  final String keyPrefix;
  final LoopNetWorthChangeAvailable? change;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = LoopGround.secondaryOf(context);
    final auxiliary = LoopGround.auxiliaryOf(context);
    final move = change;
    final value = move == null
        ? '暂无'
        : walletSignedUsdText(move.usd, move.pct, hidden: hidden);
    final colour = move == null
        ? auxiliary
        : hidden
        ? secondary
        : LoopPriceMove.of(move.usd).color;
    return Semantics(
      button: true,
      label: '今日盈亏 $value，查看净值走势',
      excludeSemantics: true,
      child: LoopPressable(
        key: ValueKey<String>('$keyPrefix-pnl'),
        scale: false,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('今日盈亏', style: LoopType.caption.copyWith(color: secondary)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  key: ValueKey<String>('$keyPrefix-pnl-value'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.figureSm.copyWith(color: colour),
                ),
              ),
              const SizedBox(width: 2),
              LoopIcon('chevron', size: 12, color: auxiliary),
            ],
          ),
        ),
      ),
    );
  }
}
