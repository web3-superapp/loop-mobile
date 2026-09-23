import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_mining_hooks.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_membership_controller.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_price_move.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

// ---------------------------------------------------------------------------
// Provider names
// ---------------------------------------------------------------------------

/// The DEX names LOOP has seen on BSC, keyed by the provider's own slug.
///
/// The table is small on purpose: it renames only what it recognises, and an
/// unknown slug is still printed, because the set is open and a page that
/// dropped the venue would be hiding where the pool lives. What it does not do
/// is print `pancakeswap_v2` and `uniswap-v4-bsc` at a reader (walkthrough
/// 2026-09-23, d06) — those are wire identifiers, and the same venue arrives
/// spelled three different ways.
const Map<String, String> _marketDexNames = <String, String>{
  'four-meme': 'four.meme',
  'fourmeme': 'four.meme',
  'four_meme': 'four.meme',
  'pancakeswap': 'PancakeSwap',
  'pancakeswap_v2': 'PancakeSwap V2',
  'pancakeswap-v2': 'PancakeSwap V2',
  'pancakeswap_v3': 'PancakeSwap V3',
  'pancakeswap-v3': 'PancakeSwap V3',
  'uniswap': 'Uniswap',
  'uniswap_v2': 'Uniswap V2',
  'uniswap-v2': 'Uniswap V2',
  'uniswap_v3': 'Uniswap V3',
  'uniswap-v3': 'Uniswap V3',
  'uniswap_v4': 'Uniswap V4',
  'uniswap-v4': 'Uniswap V4',
  'uniswap-v4-bsc': 'Uniswap V4',
  'uniswap_v4_bsc': 'Uniswap V4',
  'biswap': 'Biswap',
  'thena': 'THENA',
  'apeswap': 'ApeSwap',
  'bakeryswap': 'BakerySwap',
  'squadswap': 'SquadSwap',
};

/// The venue name a row prints for the provider's [dexId].
///
/// An unrecognised slug is title-cased on its separators rather than dropped:
/// `my_new_dex` reads `My New Dex`, which is still the provider's word but no
/// longer looks like a database column.
String marketDexLabel(String dexId) {
  final slug = dexId.trim();
  if (slug.isEmpty) return '';
  final known = _marketDexNames[slug.toLowerCase()];
  if (known != null) return known;
  final words = slug
      .split(RegExp('[-_ ]+'))
      .where((word) => word.isNotEmpty)
      .map(
        (word) => word.length == 1
            ? word.toUpperCase()
            : '${word[0].toUpperCase()}${word.substring(1)}',
      );
  final joined = words.join(' ');
  return joined.isEmpty ? slug : joined;
}

/// What a 新币发现 row may be used for.
///
/// Every row on that page is read-only for one of two reasons — the pool has
/// no page (a Uniswap V4 singleton has no address-keyed facts) or its base
/// token is not a registry asset, so there is nothing to star. Stating both as
/// separate refusals gave every row 「暂不支持加自选 · 暂不支持详情」 and three
/// lines of height (walkthrough 2026-09-23, d06). One neutral pill says the
/// same thing without saying it twice, and a row that *can* be opened or
/// starred still carries the control rather than the pill.
const String marketBrowseOnlyLabel = '仅浏览';

// ---------------------------------------------------------------------------
// Eyebrows
// ---------------------------------------------------------------------------

/// `.folio-kicker`: the small line above a hero heading.
///
/// The prototype's kickers are English because the prototype's Latin voice is
/// the design's, not the product's: 「MARKET SIGNALS」, 「NEW PAIRS」,
/// 「HOLDER LEDGER」 and 「ACTIVITY TAPE」 were read by the walkthrough as
/// untranslated strings on a Chinese page (2026-09-23, d01/d05, token-holders,
/// token-trades). The eyebrow keeps its mono face and its tracking; only the
/// words are the reader's.
const String marketSignalsKicker = '行情概览';
const String marketNewPairsKicker = '新币';
const String marketNewPairsStamp = '高风险';
const String marketHoldersKicker = '持有人';
const String marketTradesKicker = '成交记录';
const String marketSmartMoneyKicker = '聪明钱';
const String marketAlertsKicker = '价格提醒';
const String marketWatchlistKicker = '自选管理';

// ---------------------------------------------------------------------------
// The 行情 row
// ---------------------------------------------------------------------------

/// The one height every 行情 row takes (approved design, 2026-09-23).
///
/// A price list is read down its columns: the eye follows the value column and
/// stops at the one that moved. That only works when every row starts and ends
/// at the same place, and the walkthrough (2026-09-23, d01–d03) found rows
/// between two and three lines tall because the second line carried a chain of
/// facts that wrapped. The row therefore has a fixed height and every line in
/// it is one line: what does not fit is moved out of the row, not wrapped
/// inside it.
const double marketRowHeight = 58;

/// `.market-spark`: the slot the 1H line is drawn in.
///
/// It is reserved on every row, including the rows that have no line. Half
/// the list carried a shape and half did not (walkthrough, 趋势区), and with
/// the slot collapsed the value column moved sideways from row to row.
const Size marketRowSparklineSize = Size(48, 24);

/// The price column's floor.
///
/// The design's grid is `1fr 96px 88px` with 8pt gaps, which on a 390pt screen
/// leaves the name cell 60pt once the 32pt mark and the 56pt line are inside
/// it — and 「成交额 $1.28B」 ellipsised to 「成交额 $…」 (first render, S78b).
/// The fixed columns are trimmed to what their own content actually needs at
/// the ladder's steps, and the difference goes to the name.
///
/// It is a floor and not a width: decision 0085. A fixed 84pt cell ellipsised
/// 「$85,866.13」 to 「$85,866…」 on a real iPhone — the column that the whole
/// list is read down lost the one thing it carries. The price is the last
/// thing in a 行情 row that may be abbreviated, so when the figure needs more
/// than the floor it takes it, up to [marketRowPriceMaxWidth], out of the name
/// cell beside it: a truncated 「PancakeSwap Tok…」 still names the row, a
/// truncated price names nothing. The change block never moves.
const double marketRowPriceWidth = 84;

/// How far the price column may grow into the name.
///
/// The widest figure the row can print is a four-significant-digit sub-dollar
/// price (`$0.0000012345`, 13 characters). Past this the name would be down to
/// a couple of glyphs, so the price ellipsises instead — with the magnitude
/// rule below that case does not arise for any price BSC has quoted.
const double marketRowPriceMaxWidth = 124;

/// The change block: `76×30`, radius 6.
const double marketRowChangeWidth = 70;
const double marketRowChangeHeight = 30;
const double marketRowChangeRadius = 6;

/// The logo tile on a list row.
const double marketRowLogoSize = 32;

/// The price column's step.
///
/// The design sets the price at the symbol's own size and weight with tabular
/// figures; band 7 has no 15 step, so this is band 3's step with the figure
/// feature turned on — same face, same size, same weight, and a column that
/// lines up. It writes no size, weight or family of its own. If the ladder
/// ever grows a `figure 15`, this becomes that name.
final TextStyle marketRowPriceStyle = LoopType.title.copyWith(
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

/// The registry artwork for this row, when the asset contract published one.
///
/// One function, so the `logo` field (decision 0072) has exactly one place to
/// land and every 行情 surface picks it up at once.
String? marketAssetLogoUrl(MarketAssetRow row) => row.logoUrl;

/// The secondary line of a 行情 row.
///
/// The design puts the 24-hour turnover there, because that is what the list
/// is ordered by and the one fact that separates two rows at a glance. A row
/// with no turnover figure (the Watchlist block carries none) falls back to
/// the asset's own name, and then to its truncated identity.
///
/// The weight joins it only when the published rules are not a development
/// baseline. A column of 「权重 1× · 开发基线」 repeated the same internal
/// label on every row in the accent colour, which is the loudest thing on the
/// page and says nothing about any of them (walkthrough 2026-09-23, d01). The
/// development label belongs to 关于, the weight to 代币页 and 挖矿.
String marketAssetSubtitle(MarketAssetRow row, {MarketMiningWeight? weight}) {
  if (!row.price.isAvailable) return loopReasonCodeText(row.price.reasonCode);
  final volume = row.volume24h;
  final parts = <String>[
    if (volume != null && volume.isAvailable)
      '成交额 ${loopFormatCompactFigure(volume.value!)}'
    else
      row.asset?.name ?? loopTruncatedAssetId(row.assetId),
    if (weight != null && !weight.baseline) '权重 ${weight.label}',
  ];
  return parts.join(' · ');
}

/// The price a 行情 row prints.
///
/// `loopFormatUsd` rounds to cents at every magnitude, which prints
/// 「$85,866.13」 for BTCB and `$0` for every sub-cent asset. Both are wrong in
/// the same way: cents are meaningful for a $12 token and noise for a $85,866
/// one, and a page that refuses to print a zero for a fact it could not read
/// must not print one for a fact it did.
///
/// So the precision follows the magnitude (decision 0085) — the rule every
/// exchange price list uses:
///
/// | figure | fraction digits | example |
/// | --- | --- | --- |
/// | ≥ 10,000 | 0 | `$85,866` |
/// | ≥ 1,000 | 1 | `$1,248.4` |
/// | ≥ 1 | 2 | `$747.39` |
/// | < 1 | four significant digits | `$0.0000012345`, `$0.8741` |
///
/// The digits are kept, not trimmed: `$12.00` and `$12.30` are one column, and
/// `$12` beside `$12.34` is a ragged one. The threshold is re-read after
/// rounding, because 9,999.96 rounds to 10,000.0 and belongs one row up.
String marketRowPrice(Decimal value) {
  final negative = value < Decimal.zero;
  final absolute = negative ? -value : value;
  if (absolute < Decimal.one) {
    return loopFormatCompactFigure(
      value,
      preciseBelowOne: true,
      significantDigits: marketRowPriceSubUnitDigits,
    );
  }
  var digits = _marketRowPriceDigits(absolute);
  var rounded = absolute.round(scale: digits);
  final settled = _marketRowPriceDigits(rounded);
  if (settled != digits) {
    digits = settled;
    rounded = absolute.round(scale: digits);
  }
  var body = loopFormatDecimal(rounded, maxFractionDigits: digits);
  if (digits > 0) {
    final dot = body.indexOf('.');
    final present = dot < 0 ? 0 : body.length - dot - 1;
    if (dot < 0) body = '$body.';
    body = '$body${'0' * (digits - present)}';
  }
  return '\$${negative ? '-' : ''}$body';
}

/// Significant digits a 行情 price below a dollar keeps.
const int marketRowPriceSubUnitDigits = 4;

final Decimal _marketRowPriceNoDigitsFrom = Decimal.fromInt(10000);
final Decimal _marketRowPriceOneDigitFrom = Decimal.fromInt(1000);

int _marketRowPriceDigits(Decimal absolute) {
  if (absolute >= _marketRowPriceNoDigitsFrom) return 0;
  if (absolute >= _marketRowPriceOneDigitFrom) return 1;
  return 2;
}

/// Which way a row moved over 24 hours.
enum MarketMove {
  up,
  down,

  /// Read, and exactly zero. A pegged asset lives here, and so does a row
  /// nothing moved; the page counts it in neither direction and claims
  /// nothing about the peg — LOOP publishes no such flag.
  flat,

  /// Not read. The block says so; the statistics line counts it nowhere.
  unread;

  static MarketMove of(LoopFact change) => MarketMove.from(
    LoopPriceMove.of(change.isAvailable ? change.value : null),
  );

  /// The application-wide direction, narrowed to this page's own names.
  static MarketMove from(LoopPriceMove move) => switch (move) {
    LoopPriceMove.up => MarketMove.up,
    LoopPriceMove.down => MarketMove.down,
    LoopPriceMove.flat => MarketMove.flat,
    LoopPriceMove.unread => MarketMove.unread,
  };

  /// The application-wide direction this one stands for; the colour comes
  /// from there and from nowhere else (decision 0086).
  LoopPriceMove get shared => switch (this) {
    MarketMove.up => LoopPriceMove.up,
    MarketMove.down => LoopPriceMove.down,
    MarketMove.flat => LoopPriceMove.flat,
    MarketMove.unread => LoopPriceMove.unread,
  };
}

/// `76×30`, radius 6: the solid 24-hour block the approved design puts at the
/// end of every row.
///
/// Lime rises, `danger` falls, `muted` stands still — the design's own three,
/// and the first place in LOOP where a fall is red. A change that was not
/// readable renders 「读不到」 on the muted ground: never `0.00%`, which would
/// claim the price stood still.
class MarketChangeBlock extends StatelessWidget {
  const MarketChangeBlock({
    required this.fact,
    super.key,
    this.width = marketRowChangeWidth,
    this.height = marketRowChangeHeight,
  });

  final LoopFact fact;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final move = MarketMove.of(fact);
    final ground = move.shared.ground;
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: ground,
        borderRadius: BorderRadius.circular(marketRowChangeRadius),
      ),
      child: Text(
        switch (move) {
          MarketMove.unread => '读不到',
          // `loopFormatPercent` signs every figure, so a row that did not move
          // read 「+0%」 — a rise of nothing. Zero has no direction.
          MarketMove.flat => '0.00%',
          MarketMove.up || MarketMove.down => loopFormatPercent(fact.value!),
        },
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        // Ink on all three grounds: every one of them is opaque and light.
        style: LoopTypography.withWeight(
          LoopType.figure.copyWith(color: LoopColors.ink),
          FontWeight.w700,
        ),
      ),
    );
  }
}

/// One asset row for 行情, at the density a price list is read at.
///
/// Logo · ticker over one grey line · the 1H shape · the price · the 24-hour
/// block. Every column is in the same place on every row, and the row is
/// [marketRowHeight] tall whether or not it has a shape and whether or not its
/// change was readable. A price that could not be read spends the identity
/// line on the reason, and the value column stays empty rather than printing
/// the same sentence twice.
class MarketAssetTile extends StatelessWidget {
  const MarketAssetTile({
    required this.row,
    super.key,
    this.onTap,
    this.now,
    this.miningWeight,
    this.sparkline,
  });

  final MarketAssetRow row;
  final VoidCallback? onTap;
  final DateTime? now;
  final MarketMiningWeight? miningWeight;

  /// The 1H line, when this surface draws one. The slot is reserved either
  /// way.
  final Widget? sparkline;

  @override
  Widget build(BuildContext context) {
    final price = row.price;
    final priceValue = price.value;
    final marker = loopFactQualityMarker(price.quality);
    final subtitle = marketAssetSubtitle(row, weight: miningWeight);
    final semanticLabel =
        '${row.displayName}，'
        '${priceValue == null ? '价格不可用' : marketRowPrice(priceValue)}'
        '${row.priceChange24h.isAvailable ? '，24 小时 ${loopFormatPercent(row.priceChange24h.value!)}' : '，24 小时涨跌读不到'}'
        '${price.isAvailable ? '，${loopFactProvenance(price, now: now)}' : ''}';

    final content = Container(
      height: marketRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: LoopColors.line)),
      ),
      child: Row(
        children: <Widget>[
          LoopTokenLogo(
            assetSymbol: row.displayName,
            logoUrl: marketAssetLogoUrl(row),
            fallbackMonogram: row.displayName,
            size: marketRowLogoSize,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  row.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.title,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            key: const ValueKey<String>('market-row-spark-slot'),
            width: marketRowSparklineSize.width,
            height: marketRowSparklineSize.height,
            child: sparkline,
          ),
          const SizedBox(width: 6),
          // The price cell sizes to its own figure between a floor and a cap.
          // A `Row`'s non-flexible children are laid out first and against
          // unbounded width, so what this takes above the floor comes off the
          // `Expanded` name beside it — which is the order a price list is
          // read in (decision 0085).
          ConstrainedBox(
            key: const ValueKey<String>('market-row-price-slot'),
            constraints: const BoxConstraints(
              minWidth: marketRowPriceWidth,
              maxWidth: marketRowPriceMaxWidth,
            ),
            child: Text(
              // No figure and no stand-in: the identity line beside this
              // column already carries the whole reason, and a second,
              // shorter copy of it here would be the same sentence twice on
              // one row.
              priceValue == null ? '' : marketRowPrice(priceValue),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: marketRowPriceStyle,
            ),
          ),
          const SizedBox(width: 6),
          // A stale or estimated price says so where the change would be: the
          // two never appear at once, and the marker is the more important of
          // the two statements.
          if (marker != null)
            SizedBox(
              width: marketRowChangeWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: LoopBadge(
                  marker,
                  kind: price.quality == LoopFactQuality.stale
                      ? LoopBadgeKind.down
                      : LoopBadgeKind.mute,
                ),
              ),
            )
          else
            MarketChangeBlock(fact: row.priceChange24h),
        ],
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          highlightColor: LoopColors.card2,
          child: content,
        ),
      ),
    );
  }
}

/// The design's continuous table: rows in a column, no card around them.
///
/// The exchange list the requester approved has no card: a card draws a box
/// around eight rows that are already a table, and the box costs the row the
/// page margins on both sides. The hairline under each row is the table.
class MarketAssetTileGroup extends StatelessWidget {
  const MarketAssetTileGroup({required this.tiles, super.key});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: tiles,
  );
}

// ---------------------------------------------------------------------------
// The list's own chrome
// ---------------------------------------------------------------------------

/// The search field at the top of 行情.
///
/// It is a control, not an input: LOOP searches across five domains on its own
/// page, with its own filters and its own provenance, so typing here would be
/// a second, weaker search. Pressing it opens that page.
class MarketSearchField extends StatelessWidget {
  const MarketSearchField({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      0,
      LoopSpacing.page,
      10,
    ),
    child: Semantics(
      button: true,
      label: '搜索代币或合约地址',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey<String>('market-search-field'),
          onTap: onPressed,
          borderRadius: LoopRadius.inner,
          child: Container(
            height: LoopTouch.minimum,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: LoopColors.card,
              borderRadius: LoopRadius.inner,
              border: Border.all(color: LoopColors.line),
            ),
            child: Row(
              children: <Widget>[
                const LoopIcon('search', size: 16, color: LoopColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '搜索代币 / 合约地址',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopType.body.copyWith(color: LoopColors.text3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The underlined tab strip the approved design puts under the search field.
///
/// Switching a tab changes which block is listed and nothing else: the page is
/// not rebuilt, no read is re-issued for a block already held, and the bar
/// itself keeps its place.
class MarketTabBar extends StatelessWidget {
  const MarketTabBar({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
    this.keyPrefix = 'market-tab',
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Two strips of tabs now exist — the 行情 list's and 代币's lower half —
  /// and a key that named only the label would collide the moment the two
  /// pages ever shared a word.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: LoopColors.line)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
    child: Row(
      children: <Widget>[
        for (var index = 0; index < labels.length; index += 1) ...<Widget>[
          if (index > 0) const SizedBox(width: 20),
          Semantics(
            button: true,
            selected: index == selectedIndex,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey<String>('$keyPrefix-${labels[index]}'),
                onTap: () => onSelected(index),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: LoopTouch.minimum,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: index == selectedIndex
                            ? LoopColors.lime
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    labels[index],
                    style: index == selectedIndex
                        ? LoopType.title
                        : LoopType.title.copyWith(color: LoopColors.text3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// The one statistics line under the tabs.
///
/// Counts, not figures: a row whose 24-hour change was not read is counted
/// nowhere, and the page does not announce it — 「1 项涨跌读不到」 was USDT,
/// which has no move to report (walkthrough 2026-09-23, d01). 持平 is a row
/// that was read and did not move; it is not a claim that the asset is pegged,
/// because LOOP publishes no such flag.
class MarketStatsLine extends StatelessWidget {
  const MarketStatsLine({
    required this.total,
    required this.up,
    required this.down,
    required this.flat,
    required this.observedAt,
    super.key,
    this.label = '自选',
    this.now,
  });

  final String label;
  final int total;
  final int up;
  final int down;
  final int flat;
  final DateTime? observedAt;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final observed = observedAt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        10,
        LoopSpacing.page,
        4,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: '$label $total · '),
                  TextSpan(
                    text: '涨 $up',
                    style: LoopType.caption.copyWith(color: LoopColors.lime),
                  ),
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: '跌 $down',
                    style: LoopType.caption.copyWith(color: LoopColors.danger),
                  ),
                  if (flat > 0) TextSpan(text: ' · 持平 $flat'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopType.caption,
            ),
          ),
          if (observed != null) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              '${loopRelativeTime(observed, now: now)}更新',
              maxLines: 1,
              style: LoopType.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// What a 行情 list is ordered by.
enum MarketSort {
  volume('成交额'),
  price('最新价'),
  change('24h 涨跌');

  const MarketSort(this.label);

  final String label;
}

/// The design's sortable column header.
///
/// The server sends the trending list in its own published order and says so;
/// re-ordering it here is the reader's choice and is labelled as this device's
/// doing, never as a second ranking LOOP publishes.
class MarketColumnHeader extends StatelessWidget {
  const MarketColumnHeader({
    required this.sort,
    required this.descending,
    required this.onSelected,
    super.key,
  });

  final MarketSort sort;
  final bool descending;
  final ValueChanged<MarketSort> onSelected;

  Widget _cell(MarketSort key, {required TextAlign align, double? width}) {
    final active = key == sort;
    final text = Text(
      key.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: active
          ? LoopType.caption.copyWith(color: LoopColors.chalk)
          : LoopType.caption,
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: align == TextAlign.right
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: <Widget>[
        if (key == MarketSort.volume) ...<Widget>[
          Text('名称 / ', style: LoopType.caption),
        ],
        Flexible(child: text),
        if (active) ...<Widget>[
          const SizedBox(width: 4),
          LoopIcon(
            descending ? 'arrow-down' : 'arrow-up',
            size: 11,
            color: LoopColors.chalk,
          ),
        ],
      ],
    );
    final tappable = Semantics(
      button: true,
      label: '按${key.label}排序',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey<String>('market-sort-${key.name}'),
          onTap: () => onSelected(key),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: child,
          ),
        ),
      ),
    );
    if (width == null) return Expanded(child: tappable);
    return SizedBox(width: width, child: tappable);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
    child: Row(
      children: <Widget>[
        _cell(MarketSort.volume, align: TextAlign.left),
        const SizedBox(width: 6),
        _cell(
          MarketSort.price,
          align: TextAlign.right,
          width: marketRowPriceWidth,
        ),
        const SizedBox(width: 6),
        _cell(
          MarketSort.change,
          align: TextAlign.right,
          width: marketRowChangeWidth,
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// 新币发现, wherever it is listed
// ---------------------------------------------------------------------------

/// One 新币发现 row, shared by the 新币 tab and the page of the same name.
///
/// [watchAction] is the star, and only the surface that owns the write hands
/// one. A row with neither a star nor a page behind it carries the single
/// neutral [marketBrowseOnlyLabel] pill instead: stating 「暂不支持加自选」
/// and 「暂不支持详情」 separately gave every row two refusals and a third
/// line of height (walkthrough 2026-09-23, d06).
LoopRecordRow marketNewPairRow(
  MarketNewPair pair, {
  Widget? watchAction,
  VoidCallback? onTap,
  DateTime? now,
}) => LoopRecordRow(
  key: ValueKey<String>('new-pair-${pair.poolRef.rowKey}'),
  // `.row-ico`: every row on this page is headed by the pool's own token
  // mark. A pool whose Provider name was nothing but display-unsafe code
  // points is left without one; the row still belongs to the reader, so it
  // says the name is missing and falls back to the DEX for the mark.
  leading: LoopTokenLogo(
    assetSymbol: pair.name.isEmpty ? pair.dexId : pair.name,
    logoUrl: pair.logoUrl,
    fallbackMonogram: pair.name.isEmpty ? pair.dexId : pair.name,
  ),
  title: pair.name.isEmpty ? '未命名池' : pair.name,
  subtitle: <String>[
    // The provider's own DEX slug, under the name a reader knows the venue
    // by. An unrecognised slug is still printed — the set is open.
    marketDexLabel(pair.dexId),
    // A zero quote address is the coin itself, not a missing token.
    if (pair.quotesNativeCoin) '计价 BNB',
    // A pool minutes old holds fractions of a dollar. Rounded to cents that
    // printed 「$0」, which on a page that promises to say why a figure is
    // missing rather than show a zero reads as "no liquidity at all" — a
    // pulled pool. Bounding it at 「<$1」 was no better: a launchpad pool is
    // quoted at 1e-6, so the bound is true of every row and tells the reader
    // nothing. This row has the width for three significant digits.
    if (pair.reserveUsd != null)
      '储备 '
          '${loopFormatCompactFigure(pair.reserveUsd!, preciseBelowOne: true)}'
    else
      '储备暂时读不到',
    // The trailing slot holds the 24-hour figure; when it is missing the row
    // says so rather than leaving an empty corner the reader has to explain.
    if (pair.volumeH24Usd == null) '24 小时成交额暂时读不到',
  ].join(' · '),
  // Two lines, not three.
  subtitleMaxLines: 2,
  trailingBadge:
      watchAction ??
      (pair.registryAssetId == null
          ? const LoopBadge(marketBrowseOnlyLabel)
          : null),
  trailing: pair.volumeH24Usd == null
      ? null
      : loopFormatCompactFigure(pair.volumeH24Usd!, preciseBelowOne: true),
  // `.row-end .d`: the prototype's age column. It read as the fourth fact of
  // a two-line subtitle before.
  trailingCaption: pair.createdAt == null
      ? null
      : loopRelativeTime(pair.createdAt!, now: now),
  onTap: onTap,
);

/// The 新币 tab's list.
///
/// The read is issued the first time the tab is opened and not before: a
/// reader on 自选 does not pay for a provider they did not ask for. The page
/// of the same name still exists and still carries the risk-screening block
/// and the whole warning; this tab ends with the row that opens it.
class MarketNewPairsList extends ConsumerStatefulWidget {
  const MarketNewPairsList({
    required this.onOpenAsset,
    required this.onOpenPage,
    super.key,
  });

  final void Function(String assetId) onOpenAsset;
  final VoidCallback onOpenPage;

  @override
  ConsumerState<MarketNewPairsList> createState() => _MarketNewPairsListState();
}

class _MarketNewPairsListState extends ConsumerState<MarketNewPairsList> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(marketNewPairsControllerProvider);
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(marketNewPairsControllerProvider.notifier).load());
        }
      });
    }
    final block = state.value?.newPairs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!state.isReady || block == null)
          LoopChainStateBlock(
            keyPrefix: 'market-new-pairs',
            phase: state.phase,
            failureKind: state.failureKind,
            onRetry: () => unawaited(
              ref.read(marketNewPairsControllerProvider.notifier).reload(),
            ),
          )
        else
          ...switch (block) {
            MarketNewPairsUnavailable(reasonCode: final reasonCode) => <Widget>[
              LoopUnavailableCard(
                key: const ValueKey<String>('market-new-pairs-unavailable'),
                label: '新币发现不可用',
                reasonCode: reasonCode,
              ),
            ],
            MarketNewPairsAvailable(items: final items) => <Widget>[
              if (items.isEmpty)
                const LoopEmpty(
                  key: ValueKey<String>('market-new-pairs-empty'),
                  message: '当前没有新的池',
                  reason: '这是数据本身的结果，不是筛选后的结论。',
                )
              else
                LoopRecordGroup(
                  rows: <LoopRecordRow>[
                    for (final pair in items)
                      marketNewPairRow(
                        pair,
                        onTap: !pair.opensDetail
                            ? null
                            : () => widget.onOpenAsset(pair.registryAssetId!),
                      ),
                  ],
                ),
              LoopProvenanceFooter(
                text:
                    '来源 ${loopFactSourceLabel(block.source)} · '
                    '观察于 ${loopRelativeTime(block.fetchedAt)}',
              ),
            ],
          },
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('market-new-pairs-page'),
              title: '新币发现',
              subtitle: '风险预筛、被折叠的行与完整说明都在这一页',
              onTap: widget.onOpenPage,
            ),
          ],
        ),
      ],
    );
  }
}

/// The 1H line the prototype draws inside every 行情 row (`.market-spark`).
///
/// It draws the series the **row itself** carried
/// ([MarketAssetRow.sparkline]) and reads nothing. Until decision 0085 this
/// widget asked the candles controller for its own `1h` series when it
/// mounted: one request per visible row, per scroll, against a rate-limited
/// provider — which is why most rows on a real phone showed no line at all
/// (iPhone report, 2026-09-23). There is no second source and no fallback: a
/// row with no series, or with fewer than two closes, leaves the slot blank
/// and the value column beside it is unaffected. The reason belongs to the
/// token page, which has the room to state it.
class MarketRowSparkline extends StatelessWidget {
  const MarketRowSparkline({required this.series, super.key});

  /// The row's own closes, or `null` when the list delivered none.
  final MarketRowSparklineSeries? series;

  @override
  Widget build(BuildContext context) {
    final resolved = series;
    if (resolved == null || !resolved.hasShape) {
      return const SizedBox.shrink(
        key: ValueKey<String>('market-spark-absent'),
      );
    }
    final closes = resolved.closes;
    return LoopSparkline(
      key: const ValueKey<String>('market-spark-line'),
      closes: closes,
      semanticLabel:
          '${closes.length} 个 ${resolved.interval.label} 收盘价的走势线，'
          '观察于 ${loopRelativeTime(resolved.observedAt)}',
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

/// One provenance line for a set of facts that are shown in more than one
/// place on the same page.
///
/// The Token Card's cells and the fact list below it are the same read, so
/// only one of the two prints each figure now; the sources and the oldest
/// observation time still have to be stated, and this is the line that states
/// them for the whole set. A set with nothing readable in it renders nothing,
/// because there is no read to attribute.
class MarketFactProvenance extends StatelessWidget {
  const MarketFactProvenance({
    required this.facts,
    super.key,
    this.prefix,
    this.now,
  });

  final List<LoopFact> facts;

  /// Which figures this line is about. Every fact that renders through
  /// `LoopFactLine` already states its own source, so a line with no subject
  /// reads as a third copy of theirs.
  final String? prefix;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final sources = <String>{};
    DateTime? oldest;
    for (final fact in facts) {
      if (!fact.isAvailable) continue;
      final source = fact.source;
      if (source != null) sources.add(loopFactSourceLabel(source));
      final fetchedAt = fact.fetchedAt;
      if (fetchedAt != null && (oldest == null || fetchedAt.isBefore(oldest))) {
        oldest = fetchedAt;
      }
    }
    if (sources.isEmpty && oldest == null) return const SizedBox.shrink();
    return LoopProvenanceFooter(
      text: <String>[
        ?prefix,
        if (sources.isNotEmpty) '来源 ${sources.join(' · ')}',
        if (oldest != null) '观察于 ${loopRelativeTime(oldest, now: now)}',
      ].join(' · '),
    );
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

// ---------------------------------------------------------------------------
// The 代币 quote header
// ---------------------------------------------------------------------------

/// The four-cell strip under a token's quote.
///
/// A cell with no figure says so in the figure's place, so the strip keeps its
/// shape and never prints a zero for a fact that was not read.
class MarketQuoteCells extends StatelessWidget {
  const MarketQuoteCells({required this.cells, super.key});

  final List<MarketStatCell> cells;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      12,
      LoopSpacing.page,
      10,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < cells.length; index += 1) ...<Widget>[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  cells[index].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.captionSm,
                ),
                const SizedBox(height: 3),
                Text(
                  cells[index].value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cells[index].available
                      ? LoopType.figure
                      : LoopType.captionSm,
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

/// The quote the approved design opens a token page with: the price at the
/// display step, the 24-hour block beside it, and the move in the quote
/// currency under the two.
class MarketQuoteHeader extends StatelessWidget {
  const MarketQuoteHeader({
    required this.price,
    required this.change,
    super.key,
  });

  final LoopFact price;
  final LoopFact change;

  @override
  Widget build(BuildContext context) {
    final priceValue = price.isAvailable ? price.value : null;
    final changeValue = change.isAvailable ? change.value : null;
    // 「≈ +44.72 · 24h」: the same change, restated in the quote currency, so
    // a reader who does not think in percentages has the move in dollars. It
    // is derived from the two figures already on this line and from nothing
    // else, and it is omitted whenever either of them was not read.
    Decimal? absolute;
    if (priceValue != null && changeValue != null) {
      // price − price ÷ (1 + change/100): the move restated in the quote
      // currency. `Decimal.operator /` is exact, so the one place it can run
      // forever is pinned to eight places — two more than any quote this app
      // prints. A −100% change would divide by zero and is left unstated.
      final hundred = Decimal.fromInt(100);
      final ratio =
          (Decimal.one +
          (changeValue / hundred).toDecimal(scaleOnInfinitePrecision: 18));
      if (ratio != Decimal.zero) {
        final previous = (priceValue / ratio).toDecimal(
          scaleOnInfinitePrecision: 8,
        );
        absolute = priceValue - previous;
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        8,
        LoopSpacing.page,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Flexible(
            child: Text(
              priceValue == null
                  ? loopReasonCodeSummaryText(price.reasonCode)
                  : marketRowPrice(priceValue),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: priceValue == null ? LoopType.body : LoopType.figureXl,
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: MarketChangeBlock(
              key: const ValueKey<String>('token-change-block'),
              fact: change,
              width: 72,
              height: 26,
            ),
          ),
          if (absolute != null) ...<Widget>[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '≈ ${absolute >= Decimal.zero ? '+' : ''}'
                '${loopFormatDecimal(absolute, maxFractionDigits: 2)} · 24h',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The two actions the approved design pins under a token's quote.
///
/// Both are shut by the one gate the entry card further down states in a full
/// sentence; the buttons never carry a second version of the reason.
class MarketTradeActions extends StatelessWidget {
  const MarketTradeActions({
    required this.tradable,
    required this.onTrade,
    super.key,
  });

  /// The one gate. While it is false both buttons stay on the first screen
  /// and stay disabled: dropping them moved the question 「能不能买」 off the
  /// page entirely (audit 2026-09-21 §G.2), and a reason on the button would
  /// be a second version of the sentence the card at the foot already states.
  final bool tradable;
  final VoidCallback onTrade;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      2,
      LoopSpacing.page,
      14,
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          child: LoopButton(
            key: const ValueKey<String>('token-buy-action'),
            label: '买入',
            primary: true,
            block: true,
            onPressed: tradable ? onTrade : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LoopButton(
            key: const ValueKey<String>('token-sell-action'),
            label: '卖出',
            block: true,
            onPressed: tradable ? onTrade : null,
          ),
        ),
      ],
    ),
  );
}

/// One end of the 24-hour window, as a quote-strip cell.
///
/// The window is the server's (decision 0074 §4.1) and only the server's: a
/// high taken from whichever candle series this page happens to be holding
/// would be a figure LOOP computed and presented as a reading. A refused or
/// absent window prints 「—」 — not a zero, and not the last price.
MarketStatCell marketRangeCell(
  String label,
  MarketRange24h? range, {
  required bool high,
}) => switch (range) {
  MarketRange24hAvailable(high: final top, low: final bottom) => MarketStatCell(
    label: label,
    value: marketRowPrice(high ? top : bottom),
    available: true,
  ),
  // A window the server refused, and a payload that carried none, read the
  // same on screen: this page has no figure for the cell. The reason is not
  // printed in a 88pt cell; it belongs to the provenance line.
  MarketRange24hUnavailable() || null => MarketStatCell(
    label: label,
    value: marketMissingFigure,
    available: false,
  ),
};

/// What a cell prints where a figure it could not read would have gone.
const String marketMissingFigure = '—';

/// The pinned 买入 / 卖出 bar the approved design puts at the foot of 代币.
///
/// It is the same single gate [MarketTradeActions] reads, the same two labels
/// and the same shut state; only the place changed. The pair used to sit in
/// the scrolling column under the quote, which the reader leaves the moment
/// they open the chart — on an exchange the two actions are reachable from
/// wherever in the page the reader is (decision 0084's first unlanded item).
///
/// The bar carries no reason of its own: a closed gate is stated once, in full,
/// by the card at the foot of the page. Two sentences for one closed switch is
/// what 0084 §8 removed.
class MarketTradeBar extends StatelessWidget {
  const MarketTradeBar({
    required this.tradable,
    required this.onTrade,
    super.key,
  });

  /// The one gate (`capability.swappable`). Never derived locally.
  final bool tradable;
  final VoidCallback onTrade;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        // The design fades the page into the bar rather than drawing a rule,
        // so the rows underneath are seen to continue past it.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0x00050604), LoopColors.ink, LoopColors.ink],
          stops: <double>[0, 0.3, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          LoopSpacing.page,
          12,
          LoopSpacing.page,
          12 + bottom,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: LoopButton(
                key: const ValueKey<String>('token-buy-action'),
                label: '买入',
                primary: true,
                block: true,
                onPressed: tradable ? onTrade : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LoopButton(
                key: const ValueKey<String>('token-sell-action'),
                label: '卖出',
                block: true,
                onPressed: tradable ? onTrade : null,
              ),
            ),
          ],
        ),
      ),
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
