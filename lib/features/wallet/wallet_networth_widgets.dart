import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_segmented_control.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';

// ---------------------------------------------------------------------------
// 钱包 C · the net-worth history under 总资产 (decision 0188)
// ---------------------------------------------------------------------------
//
// Decision 0259 (S329): an area chart under 今日盈亏, folded by default and
// opened from the 今日盈亏 line, with its high and low marked and five
// windows to choose from.
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

/// The opened chart under 总资产: the area and the five windows (decision
/// 0259: shown only while 「净值走势 ⌄」 is open; the windows are a quiet
/// word row, [WalletQuietTabs]).
///
/// [state] is the read for [range]; `null` while it has not been asked for.
/// A failed read is one [LoopInlineUnavailable] line — it never holds the
/// chart's height open for nothing.
class WalletNetWorthPanel extends StatelessWidget {
  const WalletNetWorthPanel({
    required this.state,
    required this.range,
    required this.hidden,
    required this.onRange,
    required this.onRetry,
    super.key,
  });

  /// UX-015: shorter than the 200 the folded chart opened to.
  static const double chartHeight = 150;

  final LoopChainResourceState<LoopNetWorthHistory>? state;
  final LoopNetWorthRange range;
  final bool hidden;
  final ValueChanged<LoopNetWorthRange> onRange;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final read = state;
    final history = read?.value;
    final Widget body;
    if (history != null && history.range == range) {
      // S278 · decision 0236 (需求方第 13 条): the snapshot's source and the
      // ¥ rate no longer stand under the chart; they are in 「关于总资产」,
      // the (i) beside 总资产 ([walletNetWorthProvenanceNotes]).
      body = history.drawable
          ? WalletNetWorthChart(history: history, hidden: hidden)
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
        Padding(padding: const EdgeInsets.only(top: 4), child: body),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: WalletQuietTabs<LoopNetWorthRange>(
            key: const ValueKey<String>('wallet-networth-ranges'),
            semanticLabel: '净值走势区间',
            options: LoopNetWorthRange.values,
            labelOf: (option) => option.label,
            keyOf: (option) =>
                ValueKey<String>('wallet-networth-range-${option.wireName}'),
            selected: range,
            onSelected: onRange,
          ),
        ),
      ],
    );
  }
}

/// What 「关于总资产」 says about the net-worth history (S278 · decision
/// 0236): the snapshot's source and time, what the line is, and — decision
/// 0194 — where the ¥ came from. These were two grey lines under the chart.
({String source, DateTime? observedAt, String detail})?
walletNetWorthProvenance(LoopNetWorthHistory? history) {
  if (history == null) return null;
  final source = history.source;
  final parsed = source == null ? null : LoopFactSource.tryParse(source);
  return (
    source: parsed != null ? loopFactSourceLabel(parsed) : 'LOOP 净值快照',
    observedAt: history.observedAt ?? history.currentAt,
    detail: '走势是服务端每小时为这个钱包记下的 USD 估值，只用于展示，不是可用余额。',
  );
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

/// The one line that opens and closes the chart (decision 0259): 今日盈亏
/// and its figure on the left — the server's 24h move in rise / fall, or
/// 「暂无」 when it had no snapshot 24 hours old — and 「净值走势 ⌄」 /
/// 「收起 ⌃」 at its right edge. The whole line is one target: it only folds,
/// so there is no second meaning to tell apart.
///
/// [change] `null` with [hasHistory] off is a week that has not been read
/// (or failed): the line keeps only its right-hand switch, so the chart can
/// still be opened to show its own loading or unavailable state.
class WalletPnlLine extends StatelessWidget {
  const WalletPnlLine({
    required this.keyPrefix,
    required this.change,
    required this.hidden,
    required this.expanded,
    required this.onTap,
    super.key,
    this.hasHistory = true,
  });

  final String keyPrefix;
  final LoopNetWorthChangeAvailable? change;
  final bool hidden;
  final bool expanded;
  final VoidCallback onTap;

  /// Whether the week was read, so 今日盈亏 has something true to say.
  final bool hasHistory;

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
    final action = expanded ? '收起净值走势' : '展开净值走势';
    return Semantics(
      button: true,
      expanded: expanded,
      label: hasHistory ? '今日盈亏 $value，$action' : action,
      excludeSemantics: true,
      child: LoopPressable(
        key: ValueKey<String>(
          hasHistory ? '$keyPrefix-pnl' : '$keyPrefix-networth-toggle',
        ),
        scale: false,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
          child: Row(
            children: <Widget>[
              if (hasHistory) ...<Widget>[
                Text(
                  '今日盈亏',
                  style: LoopType.body.copyWith(color: LoopColors.chalk),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    value,
                    key: ValueKey<String>('$keyPrefix-pnl-value'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.figureSm.copyWith(color: colour),
                  ),
                ),
                const SizedBox(width: 8),
              ] else
                const Spacer(),
              WalletNetWorthChevron(expanded: expanded),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「净值走势 ⌄」 closed, 「收起 ⌃」 open — the right end of [WalletPnlLine].
/// It draws only; the line around it takes the tap.
class WalletNetWorthChevron extends StatelessWidget {
  const WalletNetWorthChevron({required this.expanded, super.key});

  final bool expanded;

  @override
  Widget build(BuildContext context) => Row(
    key: ValueKey<String>(
      expanded ? 'wallet-networth-collapse' : 'wallet-networth-expand',
    ),
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        expanded ? '收起' : '净值走势',
        key: const ValueKey<String>('wallet-networth-chevron-label'),
        maxLines: 1,
        style: LoopType.captionSm.copyWith(
          color: LoopGround.secondaryOf(context),
        ),
      ),
      const SizedBox(width: 2),
      RotatedBox(
        // The chevron sprite points right; a quarter turn points down.
        quarterTurns: expanded ? 3 : 1,
        child: LoopIcon(
          'chevron',
          size: 14,
          color: LoopGround.auxiliaryOf(context),
        ),
      ),
    ],
  );
}
