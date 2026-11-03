import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

// ---------------------------------------------------------------------------
// The chart's two control rows (decision 0273)
// ---------------------------------------------------------------------------
//
// One toolbar above the plot (the MA figures, then K线 / MA / VOL) and one
// interval row under it (the periods, then the caller's trailing control),
// shared by the market `token` detail, `chart-full`, the MEME v2 project page
// and the MEME curve token page, so all four read the same.

/// The MA figures the toolbar prints while MA is on: `MA7 … · MA25 …`, or
/// an empty string when no average can be computed.
String loopChartAveragesText(
  List<LoopCandle>? candles, {
  String Function(Decimal price)? priceFormatter,
}) {
  if (candles == null || candles.isEmpty) return '';
  final format = priceFormatter ?? loopFormatCandlePrice;
  final labels = <String>[
    for (final period in LoopMarketChart.averagePeriods)
      if (loopCandleMovingAverage(candles, period) case final series
          when series.isNotEmpty)
        'MA$period ${format(series.last)}',
  ];
  return labels.isEmpty ? '' : '${labels.join(' · ')} · 本机计算';
}

/// The row above the plot: the MA figures at the start, then K线 / MA / VOL.
/// Keys are `<keyPrefix>-moving-averages`, `<keyPrefix>-chart-style`,
/// `<keyPrefix>-chart-ma` and `<keyPrefix>-chart-vol`.
class LoopChartToolbar extends StatelessWidget {
  const LoopChartToolbar({
    required this.keyPrefix,
    required this.averagesText,
    required this.style,
    required this.averages,
    required this.volume,
    required this.onStyleChanged,
    required this.onAveragesChanged,
    required this.onVolumeChanged,
    super.key,
    this.volumeAvailable = true,
  });

  final String keyPrefix;
  final String averagesText;
  final LoopChartStyle style;
  final bool averages;
  final bool volume;
  final ValueChanged<LoopChartStyle> onStyleChanged;
  final ValueChanged<bool> onAveragesChanged;
  final ValueChanged<bool> onVolumeChanged;

  /// A series without traded volume has no VOL switch.
  final bool volumeAvailable;

  @override
  Widget build(BuildContext context) {
    final line = style == LoopChartStyle.line;
    return Padding(
      padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 0, 4, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              averagesText,
              key: ValueKey<String>('$keyPrefix-moving-averages'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopType.figureXs.copyWith(color: LoopColors.text2),
            ),
          ),
          LoopChartToggle(
            key: ValueKey<String>('$keyPrefix-chart-style'),
            label: line ? 'K线' : '折线',
            semantic: line ? '切换到 K 线' : '切换到折线',
            on: false,
            onTap: () => onStyleChanged(
              line ? LoopChartStyle.candles : LoopChartStyle.line,
            ),
          ),
          LoopChartToggle(
            key: ValueKey<String>('$keyPrefix-chart-ma'),
            label: 'MA',
            semantic: '均线',
            on: averages,
            onTap: () => onAveragesChanged(!averages),
          ),
          if (volumeAvailable)
            LoopChartToggle(
              key: ValueKey<String>('$keyPrefix-chart-vol'),
              label: 'VOL',
              semantic: '成交量',
              on: volume,
              onTap: () => onVolumeChanged(!volume),
            ),
        ],
      ),
    );
  }
}

/// A chart toolbar switch (K线 / MA / VOL).
///
/// Decision 0171 (docs/33 L4): the shared quiet `.seg` — a word, and the
/// solid dark-grey pill while it is on — instead of a hand-made r6 capsule.
/// A screen reader hears what it switches, not the abbreviation.
class LoopChartToggle extends StatelessWidget {
  const LoopChartToggle({
    required this.label,
    required this.semantic,
    required this.on,
    required this.onTap,
    super.key,
  });

  final String label;
  final String semantic;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: on,
    label: semantic,
    excludeSemantics: true,
    child: LoopSeg(label: label, quiet: true, selected: on, onSelected: onTap),
  );
}

/// One period of a [LoopChartIntervalRow]: its widget key and its text.
typedef LoopChartIntervalOption = ({String keyName, String label});

/// The periods under the plot, then the caller's trailing control.
///
/// Decision 0171 (docs/33 L4): the periods are quiet `LoopSeg`s, the same
/// OKX filter pill as every other peer choice. The row scrolls rather than
/// overflowing on a narrow phone, and the trailing control keeps its place.
class LoopChartIntervalRow extends StatelessWidget {
  const LoopChartIntervalRow({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
    this.periodsKey,
    this.trailing,
  });

  final List<LoopChartIntervalOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// The key of the scrolling periods alone (without [trailing]).
  final Key? periodsKey;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              key: periodsKey,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final (index, option) in options.indexed) ...<Widget>[
                    if (index > 0) const SizedBox(width: 4),
                    LoopSeg(
                      key: ValueKey<String>(option.keyName),
                      label: option.label,
                      quiet: true,
                      selected: index == selectedIndex,
                      onSelected: () => onSelected(index),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
