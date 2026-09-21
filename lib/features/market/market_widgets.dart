import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_mining_hooks.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_card_chart.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_membership_controller.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// Builds one asset row for `market`.
///
/// Price and 24h change are separate facts with their own quality, so a stale
/// price never borrows a fresh change's credibility. A missing figure renders
/// its reason, never `0` and never an em dash.
///
/// The secondary line is the asset's mining weight, as the prototype's
/// `.row-s .mining-accent` states it. LOOP publishes no member count per
/// asset, so the prototype's 「128,420 成员 ·」 half is omitted rather than
/// invented; a weight the rules version does not list is omitted too, and the
/// line falls back to the registry's own name. Source and observation time
/// move to the block's own provenance footer — a row that spent its second
/// line on 「来源 DexScreener · 观察于 27 秒前」 had nowhere left to say what
/// the asset is (audit 2026-09-21 §G.1).
LoopRecordRow marketAssetRow(
  MarketAssetRow row, {
  VoidCallback? onTap,
  DateTime? now,
  MarketMiningWeight? miningWeight,
  Widget? sparkline,
}) {
  final price = row.price;
  final priceValue = price.value;
  final changeValue = row.priceChange24h.value;
  final changeIsUp = changeValue != null && changeValue > Decimal.zero;
  final marker = loopFactQualityMarker(price.quality);

  final identity = row.asset?.name;
  final weightLabel = miningWeight == null
      ? null
      : <String>[
          '权重 ${miningWeight.label}',
          if (miningWeight.baseline) miningBaselineLabel,
        ].join(' · ');
  final subtitle = price.isAvailable
      ? <String>[?identity, ?weightLabel].join(' · ')
      : loopReasonCodeText(price.reasonCode);

  return LoopRecordRow(
    key: ValueKey<String>('market-asset-${row.assetId}'),
    onTap: onTap,
    leading: LoopTokenLogo(
      assetSymbol: row.displayName,
      fallbackMonogram: row.displayName,
    ),
    title: row.displayName,
    subtitle: subtitle.isEmpty ? null : subtitle,
    // `.row-s .mining-accent`: the weight is a decision fact and the name
    // beside it is not, so the two do not share one weight and colour.
    subtitleSpans: !price.isAvailable || weightLabel == null
        ? null
        : <InlineSpan>[
            if (identity != null) TextSpan(text: '$identity · '),
            TextSpan(
              text: weightLabel,
              style: LoopTypography.figure(
                12.5,
                weight: FontWeight.w700,
                color: LoopColors.lime,
              ),
            ),
          ],
    // Name plus source plus observation time does not fit the column a
    // quality badge leaves: the line ended at 「来源 D…」, which names no
    // source at all.
    subtitleMaxLines: 2,
    // A row has one right-hand column. When the price also has to carry a
    // quality marker, the badge wins and the line is dropped: a 「数据可能过期」
    // pill is the more important statement, and the prototype's row has no
    // badge slot to compete with the shape at all.
    trailingChart: marker == null ? sparkline : null,
    trailing: priceValue == null ? null : loopFormatUsd(priceValue),
    trailingCaption: changeValue == null
        ? null
        : loopFormatPercent(changeValue),
    trailingCaptionUp: changeValue == null ? null : changeIsUp,
    trailingBadge: marker == null
        ? null
        : LoopBadge(
            marker,
            kind: price.quality == LoopFactQuality.stale
                ? LoopBadgeKind.down
                : LoopBadgeKind.mute,
          ),
    semanticLabel:
        '${row.displayName}，'
        '${priceValue == null ? '价格不可用' : loopFormatUsd(priceValue)}'
        '${changeValue == null ? '' : '，24 小时 ${loopFormatPercent(changeValue)}'}'
        '${weightLabel == null ? '' : '，$weightLabel'}'
        '${price.isAvailable ? '，${loopFactProvenance(price, now: now)}' : ''}',
  );
}

/// The 1H line the prototype draws inside every 行情 row (`.market-spark`).
///
/// It reads the same `1h` candle series the Token Card's line does, through
/// the same controller family, so a row and the token page behind it never
/// show two different shapes. There is no second source and no fallback: a
/// series that is loading, unavailable or empty leaves the slot blank, and the
/// price and change in the value column beside it are unaffected. The reason
/// belongs to the token page, which has the room to state it.
class MarketRowSparkline extends ConsumerStatefulWidget {
  const MarketRowSparkline({required this.assetId, super.key});

  final String assetId;

  @override
  ConsumerState<MarketRowSparkline> createState() => _MarketRowSparklineState();
}

class _MarketRowSparklineState extends ConsumerState<MarketRowSparkline> {
  @override
  Widget build(BuildContext context) {
    final request = MarketCandleRequest(
      assetId: widget.assetId,
      interval: LoopCandleInterval.oneHour,
    );
    final state = ref.watch(marketCandlesControllerProvider(request));
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketCandlesControllerProvider(request).notifier).load(),
          );
        }
      });
    }
    if (tokenCardSparklineAbsence(state) != null) {
      return const SizedBox.shrink(
        key: ValueKey<String>('market-spark-absent'),
      );
    }
    final available = state.value!.candles as MarketCandlesAvailable;
    final closes = loopSparklineCloses(available.items);
    return LoopSparkline(
      key: ValueKey<String>('market-spark-${widget.assetId}'),
      closes: closes,
      semanticLabel:
          '${closes.length} 个 1H 收盘价的走势线，'
          '来源 ${loopFactSourceLabel(available.source)}',
    );
  }
}

/// A whole-block provenance line: "来源 X · 观察于 Y".
class MarketBlockProvenance extends StatelessWidget {
  const MarketBlockProvenance({
    required this.observedAt,
    super.key,
    this.sourceLabel,
    this.now,
    this.prefix,
  });

  /// The provenance of a list of rows, stated once for the whole list.
  ///
  /// Every source the readable rows name is listed, so a block whose rows
  /// came from two providers never claims one. A block with no readable price
  /// has nothing to attribute and renders nothing at all.
  static Widget ofRows({
    required List<MarketAssetRow> rows,
    Key? key,
    DateTime? now,
  }) {
    final sources = <String>{};
    DateTime? oldest;
    for (final row in rows) {
      final price = row.price;
      if (!price.isAvailable) continue;
      final source = price.source;
      if (source != null) sources.add(loopFactSourceLabel(source));
      final fetchedAt = price.fetchedAt;
      if (fetchedAt != null && (oldest == null || fetchedAt.isBefore(oldest))) {
        oldest = fetchedAt;
      }
    }
    if (sources.isEmpty && oldest == null) {
      return SizedBox.shrink(key: key);
    }
    return LoopProvenanceFooter(
      key: key,
      text: <String>[
        if (sources.isNotEmpty) '来源 ${sources.join(' · ')}',
        if (oldest != null) '观察于 ${loopRelativeTime(oldest, now: now)}',
      ].join(' · '),
    );
  }

  final DateTime observedAt;
  final String? sourceLabel;
  final DateTime? now;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      ?prefix,
      if (sourceLabel != null) '来源 $sourceLabel',
      '观察于 ${loopRelativeTime(observedAt, now: now)}',
    ];
    return LoopProvenanceFooter(text: parts.join(' · '));
  }
}

/// The prototype's `.segs` control, kept honest: a segment with no backend is
/// rendered but not selectable, so the page never implies a filter it cannot
/// apply.
class MarketSegmentBar extends StatelessWidget {
  const MarketSegmentBar({
    required this.labels,
    required this.onSelected,
    required this.enabled,
    super.key,
    this.selectedIndex,
    this.selectedIndices,
    this.blockedMessages = const <String?>[],
  });

  final List<String> labels;

  /// The one chosen segment, for a bar that filters a list.
  final int? selectedIndex;

  /// Every chosen segment, for a bar whose chips are independent switches —
  /// `.kline-tools`, where MA and VOL are both on at once.
  final Set<int>? selectedIndices;
  final ValueChanged<int> onSelected;
  final List<bool> enabled;

  /// What a tap on a disabled chip says, per index.
  ///
  /// 聪明钱 sat greyed and took every tap in silence, which reads as a control
  /// that is broken rather than one with no source behind it. A chip with a
  /// message here keeps its disabled look and its disabled semantics, and
  /// answers the finger with the reason the page already holds.
  final List<String?> blockedMessages;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (var index = 0; index < labels.length; index += 1) ...<Widget>[
              Opacity(
                opacity: enabled[index] ? 1 : 0.45,
                child: LoopSeg(
                  key: ValueKey<String>('market-seg-${labels[index]}'),
                  label: labels[index],
                  selected:
                      enabled[index] &&
                      (selectedIndices?.contains(index) ??
                          index == selectedIndex),
                  onSelected: enabled[index] ? () => onSelected(index) : null,
                  onBlocked:
                      enabled[index] ||
                          index >= blockedMessages.length ||
                          blockedMessages[index] == null
                      ? null
                      : () => LoopToast.show(
                          context,
                          message: blockedMessages[index]!,
                          kind: LoopToastKind.warn,
                        ),
                ),
              ),
              if (index != labels.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Says what one watchlist press did, wherever it was pressed.
///
/// The star on the Token page and the 加自选 action on 新币发现 write through the
/// same controller, so they say the same thing about the same outcome: the two
/// limit refusals were composed on device and name the limit, and only a
/// failure carries a server reason.
void showWatchlistToggleToast(
  BuildContext context,
  WatchlistToggleResult result,
) {
  switch (result.outcome) {
    case WatchlistToggleOutcome.added:
      LoopToast.show(context, message: '已加入自选', kind: LoopToastKind.ok);
    case WatchlistToggleOutcome.removed:
      LoopToast.show(context, message: '已移出自选', kind: LoopToastKind.ok);
    // Refused on device, so the sentence names the limit rather than the
    // server's `VALIDATION_FAILED`, which is about an unregistered asset.
    case WatchlistToggleOutcome.itemLimitReached:
      LoopToast.show(
        context,
        message: '自选已达 $watchlistMaxItems 项，先在自选管理里移除一个再加入。',
        kind: LoopToastKind.warn,
      );
    case WatchlistToggleOutcome.groupLimitReached:
      LoopToast.show(
        context,
        message:
            '分组已达 $watchlistMaxGroups 个，无法新建默认分组「$watchlistDefaultGroupName」。',
        kind: LoopToastKind.warn,
      );
    case WatchlistToggleOutcome.failed:
      LoopToast.show(
        context,
        message: result.failureKind == LoopChainFailureKind.versionConflict
            ? '自选已在其他设备上改动，这次没有保存。请重试。'
            : loopChainFailureReason(result.failureKind),
        kind: LoopToastKind.err,
      );
  }
}

/// `.row-ico` with a direction glyph on a soft ground.
///
/// `style-v2.css` resolves `--red` to `--chalk` and `--red-soft` to Chalk at
/// 10%: a sell is the neutral half of the same single-hue system, never a
/// second colour. The audit found the 成交 and 聪明钱 rows with no leading
/// mark at all (§G.5, §G.9, §D item 7).
class MarketDirectionAvatar extends StatelessWidget {
  const MarketDirectionAvatar({
    required this.inbound,
    super.key,
    this.size = 36,
  });

  /// True for the direction the prototype draws in Lime (买入 / 流入).
  final bool inbound;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: inbound
            ? LoopColors.limeSoft
            : LoopColors.chalk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: LoopIcon(
        inbound ? 'arrow-up' : 'arrow-down',
        size: size * 0.5,
        color: inbound ? LoopColors.lime : LoopColors.chalk,
      ),
    );
  }
}

/// `.row-ico.mono`: the rank square the prototype puts beside a Top holder.
class MarketRankAvatar extends StatelessWidget {
  const MarketRankAvatar({required this.rank, super.key, this.size = 36});

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoopGround.fillOf(context),
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Text('$rank', style: LoopMono.stamp),
    );
  }
}

/// `.stat-grid`: two or three cells of label over figure.
///
/// A cell with no figure states why in the figure's place, so the grid keeps
/// its shape and never prints a zero for a fact that was not read.
class MarketStatGrid extends StatelessWidget {
  const MarketStatGrid({required this.cells, super.key});

  final List<MarketStatCell> cells;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var index = 0; index < cells.length; index += 1) ...<Widget>[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                  decoration: BoxDecoration(
                    color: LoopColors.card,
                    borderRadius: LoopRadius.control,
                    border: Border.all(color: LoopColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        cells[index].value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: cells[index].available
                            ? LoopTypography.figure(19, height: 1.2)
                            : LoopTypography.caption(
                                11,
                                color: LoopColors.text3,
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cells[index].label,
                        style: LoopTypography.caption(
                          11,
                          color: LoopColors.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

@immutable
final class MarketStatCell {
  const MarketStatCell({
    required this.label,
    required this.value,
    required this.available,
  });

  /// The figure, or the short phrase that stands where it would have been.
  factory MarketStatCell.fact(
    String label,
    LoopFact fact, {
    String Function(Decimal)? formatter,
  }) => fact.isAvailable
      ? MarketStatCell(
          label: label,
          value: (formatter ?? loopFormatDecimal)(fact.value!),
          available: true,
        )
      : MarketStatCell(
          label: label,
          value: loopReasonCodeSummaryText(fact.reasonCode),
          available: false,
        );

  final String label;
  final String value;
  final bool available;
}
