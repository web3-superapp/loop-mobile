import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// Builds one asset row for `market`.
///
/// Price and 24h change are separate facts with their own quality, so a stale
/// price never borrows a fresh change's credibility. A missing figure renders
/// its reason, never `0` and never an em dash.
LoopRecordRow marketAssetRow(
  MarketAssetRow row, {
  VoidCallback? onTap,
  DateTime? now,
}) {
  final price = row.price;
  final priceValue = price.value;
  final changeValue = row.priceChange24h.value;
  final changeIsUp = changeValue != null && changeValue > Decimal.zero;
  final marker = loopFactQualityMarker(price.quality);

  final subtitle = price.isAvailable
      ? <String>[
          if (row.asset != null) row.asset!.name,
          loopFactProvenance(price, now: now),
        ].join(' · ')
      : loopReasonCodeText(price.reasonCode);

  return LoopRecordRow(
    key: ValueKey<String>('market-asset-${row.assetId}'),
    onTap: onTap,
    leading: LoopTokenLogo(
      assetSymbol: row.displayName,
      fallbackMonogram: row.displayName,
    ),
    title: row.displayName,
    subtitle: subtitle,
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
        '${changeValue == null ? '' : '，24 小时 ${loopFormatPercent(changeValue)}'}',
  );
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
    required this.selectedIndex,
    required this.onSelected,
    required this.enabled,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<bool> enabled;

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
                  selected: index == selectedIndex && enabled[index],
                  onSelected: enabled[index] ? () => onSelected(index) : null,
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
