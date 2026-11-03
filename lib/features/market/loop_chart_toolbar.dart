import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/loop_market_chart.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
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
    this.averagesOnOwnLine = false,
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

  /// The MA figures take their own line under the switches (in the `meta`
  /// style, wrapping rather than cut) instead of sharing the switches' line.
  /// A MEME price is long (`$0.0₄576`), so two of them never fit beside
  /// the three switches on a phone. Nothing is drawn while MA is off.
  final bool averagesOnOwnLine;

  @override
  Widget build(BuildContext context) {
    final line = style == LoopChartStyle.line;
    final switches = <Widget>[
      LoopChartToggle(
        key: ValueKey<String>('$keyPrefix-chart-style'),
        label: line ? 'K线' : '折线',
        semantic: line ? '切换到 K 线' : '切换到折线',
        on: false,
        onTap: () =>
            onStyleChanged(line ? LoopChartStyle.candles : LoopChartStyle.line),
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
    ];
    if (averagesOnOwnLine) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 0, 4, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: switches,
            ),
          ),
          if (averagesText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                0,
                LoopSpacing.page,
                4,
              ),
              child: Text(
                averagesText,
                key: ValueKey<String>('$keyPrefix-moving-averages'),
                style: LoopType.meta,
              ),
            ),
        ],
      );
    }
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
          ...switches,
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
    this.fill = false,
  });

  final List<LoopChartIntervalOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// The key of the periods alone (without [trailing]).
  final Key? periodsKey;
  final Widget? trailing;

  /// Every period takes an equal share of the line, so the whole row and
  /// [trailing] fit on a 360 pt phone without scrolling (the MEME pages'
  /// six periods). Unset, the periods are their own width and scroll (the
  /// market's five).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    if (fill) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 4, 0),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Row(
                key: periodsKey,
                children: <Widget>[
                  for (final (index, option) in options.indexed)
                    Expanded(
                      child: LoopChartPeriod(
                        key: ValueKey<String>(option.keyName),
                        label: option.label,
                        selected: index == selectedIndex,
                        onSelected: () => onSelected(index),
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      );
    }
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

/// One period of a filled [LoopChartIntervalRow]: the quiet [LoopSeg]'s look
/// (a plain word; the chosen one a solid Purple pill with a white bold word
/// and the splat) at the width its share of the line gives it, 44 tall. The
/// word shrinks rather than overflows under a large text scale.
class LoopChartPeriod extends StatelessWidget {
  const LoopChartPeriod({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final chip = Material(
      color: selected ? LoopColors.purpleSelected : Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: LoopRadius.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (!selected) LoopHaptics.selection();
          onSelected();
        },
        borderRadius: LoopRadius.pill,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: double.infinity,
            minHeight: LoopTouch.minimum,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    maxLines: 1,
                    style:
                        LoopTypography.withWeight(
                          LoopType.action,
                          selected ? FontWeight.w700 : FontWeight.w600,
                        ).copyWith(
                          color: selected
                              ? LoopColors.onPurple
                              : LoopColors.text2,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: selected ? loopSplatted(chip) : chip,
    );
  }
}
