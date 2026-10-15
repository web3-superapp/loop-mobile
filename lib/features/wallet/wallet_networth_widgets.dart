import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
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
            color: LoopColors.lime,
          ),
        ),
      ),
    );
  }
}

/// ⌄ / ⌃ — the one-line switch that opens or closes the chart.
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
          child: Center(
            child: RotatedBox(
              // The chevron sprite points right; a quarter turn points down.
              quarterTurns: expanded ? 3 : 1,
              child: LoopIcon('chevron', size: 14, color: auxiliary),
            ),
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
              message: '这个区间还没有净值记录',
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
    return LoopProvenanceLine(
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
  }
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
    final labelStyle = LoopTypography.figure(11, color: LoopColors.text2);
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
    LoopColors.lime.withValues(alpha: washAlpha),
    LoopColors.lime.withValues(alpha: 0),
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
        ..color = LoopColors.lime
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
                  style: LoopTypography.figure(12, color: colour),
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
