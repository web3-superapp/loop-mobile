import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_membership_controller.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
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
          borderRadius: LoopRadius.control,
          child: Container(
            height: LoopTouch.minimum,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: LoopColors.input,
              borderRadius: LoopRadius.control,
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
    child: Row(
      children: <Widget>[
        for (var index = 0; index < labels.length; index += 1) ...<Widget>[
          if (index > 0) const SizedBox(width: 4),
          Semantics(
            button: true,
            selected: index == selectedIndex,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey<String>('$keyPrefix-${labels[index]}'),
                onTap: () => onSelected(index),
                borderRadius: LoopRadius.pill,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: LoopTouch.minimum,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    // Decision 0211: the chosen tab is a Purple 18 % capsule
                    // with a Yellow word; the rest are grey words.
                    decoration: BoxDecoration(
                      color: index == selectedIndex
                          ? LoopColors.purpleSelected
                          : Colors.transparent,
                      borderRadius: LoopRadius.pill,
                    ),
                    // R16 the quiet segment's word (decision 0190 M24): `action`
                    // 14 at 600, 700 when chosen — the step `LoopSeg(quiet:)`
                    // draws; the underline stays the strip's own.
                    child: Text(
                      labels[index],
                      style: index == selectedIndex
                          ? LoopTypography.withWeight(
                              LoopType.action,
                              FontWeight.w700,
                            ).copyWith(color: LoopColors.yellow)
                          : LoopType.action.copyWith(color: LoopColors.text3),
                    ),
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
              // Decision 0171: the same one-line state the new-pairs page
              // uses, never the block-sized strip.
              LoopInlineUnavailable(
                key: const ValueKey<String>('market-new-pairs-unavailable'),
                message: '新币发现不可用 · ${loopReasonCodeText(reasonCode)}',
                maxLines: 3,
              ),
            ],
            MarketNewPairsAvailable(items: final items) => <Widget>[
              if (items.isEmpty)
                const LoopEmptyState(
                  key: ValueKey<String>('market-new-pairs-empty'),
                  illustration: LoopIllustration.search,
                  compact: true,
                  title: '当前没有新的池',
                  message: '这是数据本身的结果，不是筛选后的结论。',
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
                  quiet: true,
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
        // Decision 0211: a 10 radius tile, Yellow inbound, no edge.
        color: inbound ? LoopColors.yellowSoft : LoopColors.card2,
        borderRadius: LoopRadius.tile,
      ),
      child: LoopIcon(
        inbound ? 'arrow-up' : 'arrow-down',
        size: size * 0.5,
        color: inbound ? LoopColors.yellow : LoopColors.chalk,
      ),
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
  const MarketQuoteCells({
    required this.cells,
    super.key,
    this.padding = defaultPadding,
  });

  static const EdgeInsets defaultPadding = EdgeInsets.fromLTRB(
    LoopSpacing.page,
    12,
    LoopSpacing.page,
    10,
  );

  final List<MarketStatCell> cells;

  /// Space around the cells; a caller that sets them on a panel of its own
  /// passes the panel's inner padding.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
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
                // R13 / R12, the steps `LoopStatGrid` draws (decision 0190
                // M25); the four-up strip keeps its own layout.
                Text(
                  cells[index].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.kicker,
                ),
                const SizedBox(height: 3),
                Text(
                  cells[index].value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cells[index].available
                      ? LoopType.figure
                      : LoopType.kicker,
                ),
              ],
            ),
          ),
        ],
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
      // S241b (decision 0210): the flat looplabs bar — the page ground
      // behind a 1px rule, no fade.
      decoration: const BoxDecoration(
        color: LoopColors.ink,
        border: Border(top: BorderSide(color: LoopColors.line)),
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

  /// The same cell as one shared `.stat` (decision 0171, docs/33 L6): a page
  /// that lays these out as a grid uses `LoopStatGrid`, not a copy of it.
  LoopStat toStat({Key? statKey}) =>
      LoopStat(label: label, value: value, statKey: statKey);
}
