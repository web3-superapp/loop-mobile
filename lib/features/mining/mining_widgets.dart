import 'package:flutter/material.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/text/loop_power_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_title_doodle.dart';

/// The formula gate, as the summary, the composition page and the ranking all
/// read it.
///
/// The three endpoints publish the same block from the same source (Decision
/// 0046), so the three pages say the same thing about the version in force
/// instead of each deciding for itself. The row says whether a version is in
/// effect and whether it is the development baseline; the version string is a
/// backend identifier and stays inside the collapsed 详情.
class MiningFormulaBlock extends StatelessWidget {
  const MiningFormulaBlock({required this.formula, super.key});

  final MiningFormulaGate formula;

  @override
  Widget build(BuildContext context) {
    final (LoopRecordRow row, String? detail) = switch (formula) {
      MiningFormulaPending(:final reasonCode, :final pendingVersion) => (
        LoopRecordRow(
          key: const ValueKey<String>('mining-formula-row'),
          title: context.l10n.mining_widgetsMiningFormulaRowTitle,
          // A pending draft already carries the block's own sentence in
          // 算力与产出 above; repeating it here would be the same screen
          // saying one thing twice.
          subtitle: pendingVersion == null
              ? launchReasonCodeText(reasonCode)
              : context.l10n.mining_widgetsMiningFormulaRowSubtitle,
          trailing: pendingVersion == null
              ? launchMissingFigure
              : context.l10n.mining_modelsPendingApproval,
          semanticLabel: pendingVersion == null
              ? context.l10n.mining_widgetsMiningFormulaRowSemanticLabel
              : context.l10n.mining_widgetsMiningFormulaRowSemanticLabel2,
        ),
        pendingVersion == null ? null : context.l10n.mining_screenSwitch4,
      ),
      MiningFormulaEffective(:final scope, :final effectiveAt) => (
        LoopRecordRow(
          key: const ValueKey<String>('mining-formula-row'),
          title: context.l10n.mining_widgetsMiningFormulaRowTitle,
          subtitle: scope.isBaseline
              ? miningBaselineLabel
              : context.l10n.mining_widgetsMiningFormulaRowSubtitle2(
                  launchTimestampLabel(effectiveAt),
                ),
          trailing: context.l10n.mining_widgetsMiningFormulaRowTrailing,
          semanticLabel:
              context.l10n.mining_widgetsMiningFormulaRowSemanticLabel3,
        ),
        context.l10n.mining_screenSwitch6,
      ),
    };
    final identifier = switch (formula) {
      MiningFormulaPending(:final pendingVersion) => pendingVersion,
      MiningFormulaEffective(:final configVersion) => configVersion,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(
          key: const ValueKey<String>('mining-formula'),
          rows: <LoopRecordRow>[row],
        ),
        if (detail != null && identifier != null)
          LoopDisclosure(
            key: const ValueKey<String>('mining-formula-details'),
            summary: context.l10n.common_details,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                '$detail $identifier',
                key: const ValueKey<String>('mining-formula-pending-version'),
                style: LoopType.captionSm,
              ),
            ),
          ),
      ],
    );
  }
}

/// One mining figure as a line of its own.
///
/// A figure prints only when the server settled it; without one the row keeps
/// the em dash and the server's own reason. The development-baseline label,
/// and any note the figure carries with it, are the caption beneath it — the
/// summary and the rewards page say the same figure the same way.
class MiningMetricRow extends StatelessWidget {
  const MiningMetricRow({
    required this.slug,
    required this.label,
    required this.figure,
    required this.baseline,
    this.note,
    super.key,
  });

  final String slug;
  final String label;
  final MiningFigure figure;
  final bool baseline;
  final String? note;

  @override
  Widget build(BuildContext context) {
    if (figure is MiningFigureUnavailable) {
      return LaunchEmptyMetric(
        key: ValueKey<String>('mining-metric-$slug'),
        label: label,
        reasonCode: (figure as MiningFigureUnavailable).reasonCode,
      );
    }
    // The server owns the figure; the separators are display only and are
    // dropped when they cannot be added without changing what it says.
    final value = loopGroupedFigure((figure as MiningFigureValue).value);
    final caption = <String>[
      if (baseline) miningBaselineLabel,
      ?note,
    ].join(' · ');
    return Padding(
      key: ValueKey<String>('mining-metric-$slug'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Semantics(
        container: true,
        label: caption.isEmpty
            ? '$label${LoopL10n.current.common_listSeparator}$value'
            : '$label${LoopL10n.current.common_listSeparator}$value${LoopL10n.current.widgets_sentenceJoin}$caption',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: LoopType.kicker),
              const SizedBox(height: 4),
              Text(value, style: LoopType.figureLg),
              if (caption.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: LoopType.captionSm.copyWith(color: LoopColors.text2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The line a page prints beside figures that a later run has overtaken
/// (Decision 0057).
///
/// A run that could not value a held holding is never published, so the page
/// keeps showing the last complete snapshot instead of falling to zero. That
/// is the right behaviour and the wrong thing to show silently: the reader is
/// looking at a moment that is no longer the newest one. The line says which
/// moment it is and what stopped the next one; it never withdraws the
/// numbers, and it prints nothing at all when the newest run is the snapshot
/// on the page.
class MiningStaleNotice extends StatelessWidget {
  const MiningStaleNotice({
    required this.slug,
    required this.snapshot,
    this.symbols = const <String, String>{},
    super.key,
  });

  final String slug;
  final MiningSnapshotRef? snapshot;

  /// Registry symbols by asset id, where the page has them. Without one an
  /// unread holding is named by the id it stands for, never by a guess.
  final Map<String, String> symbols;

  @override
  Widget build(BuildContext context) {
    final source = snapshot;
    if (source is! MiningSnapshotComputed || !source.stale) {
      return const SizedBox.shrink();
    }
    return LoopNotice(
      key: ValueKey<String>('mining-stale-$slug'),
      icon: 'clock',
      body: miningStaleLine(
        computedAtLabel: launchTimestampLabel(source.computedAt),
        attempt: source.latestAttempt,
        symbols: symbols,
      ),
      margin: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        14,
        LoopSpacing.page,
        0,
      ),
    );
  }
}

/// What the ⓘ of a mining figure's source line adds about the holdings the
/// snapshot counted (decision 0121), or `null` when there is nothing to add.
///
/// Decision 0061 marks a snapshot that counted holdings written for a
/// demonstration instead of observed on chain: the arithmetic is real, the
/// holdings are not held by anyone. That used to be a warning banner under
/// the figures (「含演示持仓 · 仅开发环境」); the device report of 2026-10-09
/// (§4) asked for no development-build banners, so the fact moved into the
/// source line's sheet, in the reader's words. Production publishes no such
/// snapshot, and this answers `null` there.
///
/// S121b's 情报算力榜 hands this to its own `LoopProvenanceLine.detail`.
///
/// With [formula], a baseline formula adds [miningBaselineDetail] too
/// (coordinator ruling 2026-10-09).
String? miningProvenanceDetail(
  MiningSnapshotRef? snapshot, {
  MiningFormulaGate? formula,
}) {
  final lines = <String>[
    if (formula case MiningFormulaEffective(:final scope) when scope.isBaseline)
      miningBaselineDetail,
    if (miningSnapshotIncludesDemonstrationHoldings(snapshot))
      miningDemoHoldingsDetail,
  ];
  return lines.isEmpty ? null : lines.join('\n');
}

/// The sentence [miningProvenanceDetail] answers for a demonstration snapshot.
String get miningDemoHoldingsDetail =>
    LoopL10n.current.mining_widgetsMiningDemoHoldingsDetail;

/// The 11px source line under a mining page's figures: the snapshot they
/// came from and when it was computed, with [miningProvenanceDetail] in its
/// sheet. A snapshot that was never computed prints nothing.
class MiningSnapshotProvenanceLine extends StatelessWidget {
  const MiningSnapshotProvenanceLine({
    required this.slug,
    required this.snapshot,
    super.key,
    this.formula,
    this.markStale = false,
  });

  final String slug;
  final MiningSnapshotRef? snapshot;

  /// The formula the figures were computed under, when the page has it.
  final MiningFormulaGate? formula;

  /// S315: on a page that prints no [MiningStaleNotice], a snapshot a later
  /// run overtook wears 未更新 beside the (i), and the notice's sentence
  /// moves into the sheet.
  final bool markStale;

  @override
  Widget build(BuildContext context) {
    final source = snapshot;
    final stale = markStale && source is MiningSnapshotComputed && source.stale;
    final detail = <String>[
      if (stale)
        miningStaleLine(
          computedAtLabel: launchTimestampLabel(source.computedAt),
          attempt: source.latestAttempt,
        ),
      ?miningProvenanceDetail(source, formula: formula),
    ].join('\n');
    if (source is! MiningSnapshotComputed) {
      // No snapshot to date, but a baseline formula still has its ⓘ.
      if (detail.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: LoopProvenanceLine(
          key: ValueKey<String>('mining-provenance-$slug'),
          prefix: miningBaselineLabel,
          sources: <String>[
            context.l10n.mining_secondaryScreensLoopProvenanceLine,
          ],
          detail: detail.isEmpty ? null : detail,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: LoopProvenanceLine(
        key: ValueKey<String>('mining-provenance-$slug'),
        sources: <String>[context.l10n.intel_rankBoardS],
        observedAt: source.computedAt,
        detail: detail.isEmpty ? null : detail,
        marker: stale ? context.l10n.mining_widgetsMarker : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The prototype's mining primaries (`docs/prototype/screens/mining*.html`)
// ---------------------------------------------------------------------------

/// `.mining-summary-card` — the composite dashboard the `mining` tab opens on.
///
/// The frozen prototype puts five things inside one saturated Lime card: the
/// rank, the power figure, the sentence, three metrics divided by hairlines,
/// and the two next steps. The page used to spread them over a hero, five
/// stacked key-value blocks and a menu group, so a reader had to scroll three
/// screens to reach 领取奖励 (visual audit 2026-09-21 §I.2).
///
/// It states nothing it was not given: a metric with no settled figure keeps
/// the em dash, and the rank badge is omitted rather than invented.
class MiningSummaryHero extends StatelessWidget {
  const MiningSummaryHero({
    required this.heading,
    required this.metrics,
    this.caption,
    super.key,
    this.unit,
    this.rank,
    this.stamp,
    this.onClaim,
    this.claimSemanticLabel,
    this.onOpenAssets,
    this.powerOnly = false,
    this.split = const <MiningHeroMetric>[],
    this.network,
    this.onOpenRank,
    this.rankPosition,
  });

  /// The reader's settled place as a number (S353b: it sets the colour of
  /// 「第 N 名」); null with no place.
  final int? rankPosition;

  /// S350b · decision 0275: 全网总算力 under a hairline inside the hero
  /// ([MiningNetworkPowerCard] with `inline: true`); null draws none.
  final Widget? network;

  /// 算力榜: the crown and the place at the hero's top right.
  final VoidCallback? onOpenRank;

  /// The power itself, or the words for its absence. Never a 44px dash.
  final String heading;

  /// `.mining-power-value small`: the unit that follows a settled figure.
  final String? unit;

  /// The snapshot line; null draws none (S344: no 「快照 · —」).
  final String? caption;

  /// `.mining-rank`: the reader's place, when the server settled one.
  final String? rank;

  /// The scope label a development baseline carries with it.
  final String? stamp;

  /// `.mining-summary-metrics`: exactly three cells, each a figure or `—`.
  final List<MiningHeroMetric> metrics;

  /// Decision 0253: 代币算力 and NFT 算力, the two pools of the last settled
  /// hour, in a second strip under [metrics]. Empty draws no strip.
  final List<MiningHeroMetric> split;

  /// `.mining-summary-actions button:first-child`: Ink-filled on Lime, the
  /// strongest contrast in the app. Null while the server keeps the claim
  /// closed; the reason for that stays with the block that owns it.
  final VoidCallback? onClaim;
  final String? claimSemanticLabel;
  final VoidCallback? onOpenAssets;

  /// Decision 0184: the LOOP token is not live ([miningTokenLive] is false).
  /// The first button opens the hour's power rather than a claim. S315: the
  /// line that explained this under the actions is gone.
  final bool powerOnly;

  @override
  Widget build(BuildContext context) {
    // S350b · decision 0275: one hero for 情报 · 算力 — 我的总算力 leads in
    // Inter Bold Yellow, the place and the crown are the way into 算力榜 at the
    // top right, 全网总算力 sits under a hairline as the supporting figure,
    // and a cell with no figure is left out rather than drawn as 「—」.
    const muted = LoopColors.text3;
    final shown = <MiningHeroMetric>[
      for (final metric in metrics)
        if (metric.value != launchMissingFigure) metric,
    ];
    final shownSplit = <MiningHeroMetric>[
      for (final metric in split)
        if (metric.value != launchMissingFigure) metric,
    ];
    final settled = unit != null;
    final figure = Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: heading),
          if (unit != null)
            TextSpan(
              text: ' $unit',
              style: LoopType.figureSm.copyWith(color: muted),
            ),
        ],
      ),
      key: const ValueKey<String>('mining-summary-hero-power'),
      maxLines: settled ? 1 : 2,
      overflow: TextOverflow.ellipsis,
      // S353b · decision 0279 (docs/58 §5.14): the power card's value is
      // Inter 30 / 700 white; words in that slot stay a Chalk heading.
      style: settled
          ? LoopType.heroFigure.copyWith(color: LoopColors.textPrimary)
          : LoopType.displayXl.copyWith(color: LoopColors.chalk),
    );
    // docs/58 §5.14: the power card — a 12 corner, the 107° gradient
    // #14151a → #1b1028 and the doodle wall at 30 % over it.
    return Container(
      key: const ValueKey<String>('mining-summary-hero'),
      margin: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LoopColors.powerCardGradient,
        borderRadius: LoopRadius.card,
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.3,
                child: loopAtmoArt(
                  LoopAtmoAssets.wall,
                  fit: BoxFit.cover,
                  key: const ValueKey<String>('mining-summary-hero-watermark'),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.card + 1,
              14,
              LoopSpacing.card - 4,
              LoopSpacing.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          context.l10n.mining_widgetsText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopType.eyebrow.copyWith(
                            color: LoopColors.text2,
                          ),
                        ),
                      ),
                      // docs/58 §5.14: the snapshot at the top right,
                      // 10 / 400 white 30 %.
                      if (caption case final String caption) ...<Widget>[
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              caption,
                              key: const ValueKey<String>(
                                'mining-summary-hero-caption',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: LoopType.metaSm.copyWith(
                                color: LoopColors.white30,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: settled
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: figure,
                        )
                      : figure,
                ),
                MiningRankEntry(
                  rank: rank,
                  position: rankPosition,
                  onTap: onOpenRank,
                ),
                if (stamp != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: LoopFolioStamp(
                      stamp!,
                      key: const ValueKey<String>('mining-summary-hero-stamp'),
                    ),
                  ),
                ],
                if (shown.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  _MiningHeroStrip(metrics: shown, top: true),
                ],
                if (shownSplit.isNotEmpty)
                  _MiningHeroStrip(
                    key: const ValueKey<String>('mining-summary-hero-split'),
                    metrics: shownSplit,
                    top: shown.isEmpty,
                  ),
                if (network case final Widget network) ...<Widget>[
                  SizedBox(
                    height: shown.isEmpty && shownSplit.isEmpty ? 14 : 0,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: network,
                  ),
                ],
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        // `.mining-summary-actions button:first-child`: the
                        // yellow CTA.
                        child: LoopButton(
                          key: const ValueKey<String>(
                            'mining-summary-hero-claim',
                          ),
                          // Decision 0184: before the token is live the
                          // page it opens counts power, so the button says
                          // so.
                          label: powerOnly
                              ? context
                                    .l10n
                                    .mining_widgetsMiningSummaryHeroClaimLabel
                              : context
                                    .l10n
                                    .mining_widgetsMiningSummaryHeroClaimLabel2,
                          primary: true,
                          onPressed: onClaim,
                          semanticLabel: powerOnly
                              ? context
                                    .l10n
                                    .mining_widgetsMiningSummaryHeroClaimSemanticLabel
                              : claimSemanticLabel,
                        ),
                      ),
                      // Decision 0272: on 情报 · 算力 the composition is the
                      // tabs right under this card, so the second button is
                      // drawn only where a separate composition page is
                      // still reachable.
                      if (onOpenAssets != null) ...<Widget>[
                        const SizedBox(width: 9),
                        Expanded(
                          child: LoopButton(
                            key: const ValueKey<String>(
                              'mining-summary-hero-assets',
                            ),
                            label: context
                                .l10n
                                .mining_widgetsMiningSummaryHeroAssetsLabel,
                            onPressed: onOpenAssets,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The way into 算力榜 (S350b · decision 0275), drawn as the power card's
/// 「当前排名 第 N 名」 line since S353b · decision 0279 (docs/58 §5.14): the
/// label 12 / 500, the place 13 / 600 with its number in Inter Black Italic
/// 16 — Yellow for the first, bronze for the third — and the crown bitmap
/// after it, inside a 44 target. With no place it is the crown and a
/// chevron, read aloud as 「算力榜」.
class MiningRankEntry extends StatelessWidget {
  const MiningRankEntry({super.key, this.rank, this.position, this.onTap});

  /// 「第 12 名」, or null when the reader has no place.
  final String? rank;

  /// The place as a number, for its colour.
  final int? position;

  /// Null while no 算力榜 is reachable from here: the entry is drawn but
  /// does nothing, as the crown icon it replaces did.
  final VoidCallback? onTap;

  /// The crown bitmap's box (the Figma's 61 × 37).
  static const Size crownSize = Size(61, 37);

  /// The place number's colour.
  static Color placeColor(int? position) => switch (position) {
    1 => LoopColors.yellow,
    3 => LoopColors.bronze,
    _ => LoopColors.textPrimary,
  };

  @override
  Widget build(BuildContext context) {
    final place = rank;
    final number = position;
    final label = LoopType.meta.copyWith(color: LoopColors.text2);
    Widget placeText(String text) {
      final digits = number?.toString();
      final at = digits == null ? -1 : text.indexOf(digits);
      final word = LoopType.figureXs.copyWith(color: placeColor(number));
      return Text.rich(
        TextSpan(
          style: word,
          children: at < 0
              ? <InlineSpan>[TextSpan(text: text)]
              : <InlineSpan>[
                  TextSpan(text: text.substring(0, at)),
                  TextSpan(
                    text: digits,
                    style: LoopType.rankFigure.copyWith(
                      color: placeColor(number),
                    ),
                  ),
                  TextSpan(text: text.substring(at + digits!.length)),
                ],
        ),
        key: const ValueKey<String>('mining-summary-hero-rank'),
        maxLines: 1,
      );
    }

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: place == null
          ? context.l10n.intel_rankBoardIntelRankBoardTitle
          : context.l10n.mining_widgetsMiningNetworkRankActionLabel2(place),
      excludeSemantics: true,
      child: LoopPressable(
        key: const ValueKey<String>('mining-network-rank-action'),
        onTap: onTap,
        scale: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: LoopTouch.minimum,
            minWidth: LoopTouch.minimum,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (place == null) ...<Widget>[
                // No place: the crown and a chevron, read as 「算力榜」.
                SizedBox.fromSize(
                  size: crownSize * 0.8,
                  child: loopAtmoArt(
                    LoopFigmaAssets.crownPowerCard,
                    fit: BoxFit.contain,
                    key: const ValueKey<String>('mining-summary-hero-crown'),
                  ),
                ),
                const LoopIcon('chevron', size: 14, color: LoopColors.text3),
              ] else ...<Widget>[
                Text(
                  context.l10n.mining_widgetsCurrentRank,
                  maxLines: 1,
                  style: label,
                ),
                const SizedBox(width: 8),
                // 「第 12 名」 / 「#12」: the label already says 当前排名.
                placeText(
                  number == null
                      ? place
                      : context.l10n.mining_widgetsRankPlace(number),
                ),
                const SizedBox(width: 2),
                SizedBox.fromSize(
                  size: crownSize * 0.8,
                  child: loopAtmoArt(
                    LoopFigmaAssets.crownPowerCard,
                    fit: BoxFit.contain,
                    key: const ValueKey<String>('mining-summary-hero-crown'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 情报 · 算力's first card (decision 0272): 全网总算力, split into NFT and
/// 代币, with the way into 算力榜 at its top right.
///
/// The split is the last settled hour's two network pools
/// (`tracks.nft.networkPower` / `tracks.asset.networkPower`), so the card
/// says 上一小时. Without them the card prints the snapshot's
/// `summary.networkPower` alone and draws no split it was not given.
class MiningNetworkPowerCard extends StatelessWidget {
  const MiningNetworkPowerCard({
    required this.total,
    required this.spoken,
    super.key,
    this.nft,
    this.token,
    this.lastHour = false,
    this.onOpenRank,
    this.inline = false,
  });

  /// S350b · decision 0275: drawn inside 我的总算力's hero, under a hairline
  /// — the supporting figure, no card and no crown of its own (the hero's
  /// top right is the way into 算力榜).
  final bool inline;

  /// The total figure, or [launchMissingFigure].
  final String total;
  final String spoken;
  final String? nft;
  final String? token;

  /// The figures are the last settled hour's.
  final bool lastHour;
  final VoidCallback? onOpenRank;

  @override
  Widget build(BuildContext context) {
    if (inline) return _inline();
    final settled = total != launchMissingFigure;
    return LoopRecordCard(
      key: const ValueKey<String>('mining-network-card'),
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  lastHour
                      ? context.l10n.mining_widgetsMiningNetworkKicker
                      : context.l10n.mining_widgetsMiningNetworkKicker2,
                  key: const ValueKey<String>('mining-network-kicker'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LoopType.kicker.copyWith(color: LoopColors.text2),
                ),
              ),
              LoopIconButton(
                key: const ValueKey<String>('mining-network-rank-action'),
                icon: 'crown',
                label: context.l10n.intel_rankBoardIntelRankBoardTitle,
                onPressed: onOpenRank,
              ),
            ],
          ),
          Semantics(
            container: true,
            label: context.l10n.mining_widgetsMiningNetworkTotalLabel(spoken),
            child: ExcludeSemantics(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: total),
                    if (settled)
                      TextSpan(
                        text: ' H',
                        style: LoopType.figureMd.copyWith(
                          color: LoopColors.text3,
                        ),
                      ),
                  ],
                ),
                key: const ValueKey<String>('mining-network-total'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.statFigure.copyWith(
                  color: settled ? LoopColors.chalk : LoopColors.text3,
                ),
              ),
            ),
          ),
          if (nft != null && token != null) ...<Widget>[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _MiningHeroStrip(
                key: const ValueKey<String>('mining-network-split'),
                metrics: <MiningHeroMetric>[
                  MiningHeroMetric(
                    slug: 'network-nft',
                    label: 'NFT',
                    value: nft!,
                    spoken: nft!,
                  ),
                  MiningHeroMetric(
                    slug: 'network-token',
                    label: context.l10n.common_token,
                    value: token!,
                    spoken: token!,
                  ),
                ],
                top: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The inline form: 「全网总算力」 and the total on one line, the NFT and
  /// 代币 split under it in grey, both quieter than 我的总算力 above.
  Widget _inline() {
    final settled = total != launchMissingFigure;
    final label = LoopType.caption.copyWith(color: LoopColors.text3);
    final small = LoopType.figureSm.copyWith(color: LoopColors.text2);
    return Container(
      key: const ValueKey<String>('mining-network-card'),
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LoopColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text(
                  lastHour
                      ? LoopL10n.current.mining_widgetsMiningNetworkKicker
                      : LoopL10n.current.mining_widgetsMiningNetworkKicker2,
                  key: const ValueKey<String>('mining-network-kicker'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: label,
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                container: true,
                label: LoopL10n.current.mining_widgetsMiningNetworkTotalLabel(
                  spoken,
                ),
                child: ExcludeSemantics(
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: total),
                        if (settled)
                          TextSpan(
                            text: ' H',
                            style: LoopType.figureSm.copyWith(
                              color: LoopColors.text3,
                            ),
                          ),
                      ],
                    ),
                    key: const ValueKey<String>('mining-network-total'),
                    maxLines: 1,
                    style: LoopType.figure.copyWith(
                      color: settled ? LoopColors.chalk : LoopColors.text3,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (nft != null && token != null) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              key: const ValueKey<String>('mining-network-split'),
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                for (final (slug, name, value) in <(String, String, String)>[
                  ('network-nft', 'NFT', nft!),
                  ('network-token', LoopL10n.current.common_token, token!),
                ]) ...<Widget>[
                  if (slug != 'network-nft') const SizedBox(width: 16),
                  Flexible(
                    child: Semantics(
                      container: true,
                      label:
                          '$name${LoopL10n.current.common_listSeparator}$value',
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: label,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              value,
                              key: ValueKey<String>(
                                'mining-summary-hero-$slug',
                              ),
                              maxLines: 1,
                              style: small,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One `.mining-summary-metrics` row of cells divided by hairlines. The
/// first strip carries the rule above it; a strip under it shares that rule.
class _MiningHeroStrip extends StatelessWidget {
  const _MiningHeroStrip({required this.metrics, required this.top, super.key});

  final List<MiningHeroMetric> metrics;
  final bool top;

  @override
  Widget build(BuildContext context) {
    // S350b · decision 0275: the cells are the hero's supporting readings —
    // a hairline above them, no grid of rules between them, the figure over
    // its grey label.
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: LoopColors.line) : BorderSide.none,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var index = 0; index < metrics.length; index += 1)
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(index == 0 ? 0 : 8, 12, 0, 0),
                child: Semantics(
                  container: true,
                  label:
                      '${metrics[index].label}${LoopL10n.current.common_listSeparator}${metrics[index].spoken}',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          metrics[index].value,
                          key: ValueKey<String>(
                            'mining-summary-hero-${metrics[index].slug}',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopType.figure.copyWith(
                            color: LoopColors.chalk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          metrics[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopType.caption.copyWith(
                            color: LoopColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 算力构成's group heading (decision 0253): 代币 or NFT, with the group's
/// subtotal on the same row.
class MiningCompositionGroupHeading extends StatelessWidget {
  const MiningCompositionGroupHeading({
    required this.slug,
    required this.title,
    required this.subtotal,
    required this.spoken,
    super.key,
  });

  final String slug;
  final String title;
  final String subtotal;
  final String spoken;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey<String>('mining-composition-$slug-heading'),
    // S350b · decision 0275: the subtotal is a supporting reading under the
    // tabs — grey and a step under the rows' own figures.
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      LoopSpacing.tight,
      LoopSpacing.page,
      LoopSpacing.tight,
    ),
    child: Semantics(
      header: true,
      label: '$title${LoopL10n.current.common_listSeparator}$spoken',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.caption.copyWith(color: LoopColors.text3),
              ),
            ),
            Text(
              subtotal,
              key: ValueKey<String>('mining-composition-$slug-subtotal'),
              maxLines: 1,
              style: LoopTypography.withWeight(
                LoopType.figureSm,
                FontWeight.w600,
              ).copyWith(color: LoopColors.text2),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One `.mining-summary-metrics` cell.
@immutable
final class MiningHeroMetric {
  const MiningHeroMetric({
    required this.slug,
    required this.label,
    required this.value,
    required this.spoken,
  });

  /// The figure the server settled, said the way the page says it elsewhere.
  factory MiningHeroMetric.figure({
    required String slug,
    required String label,
    required MiningFigure figure,
  }) => switch (figure) {
    MiningFigureValue(:final value) => MiningHeroMetric(
      slug: slug,
      label: label,
      value: loopGroupedFigure(value),
      spoken: loopGroupedFigure(value),
    ),
    MiningFigureUnavailable(:final reasonCode) => MiningHeroMetric(
      slug: slug,
      label: label,
      value: launchMissingFigure,
      spoken: launchReasonCodeText(reasonCode),
    ),
  };

  final String slug;
  final String label;
  final String value;

  /// What a screen reader hears in place of an em dash.
  final String spoken;
}

/// `.ledger-composite-detail .detail-row`: a label on the left and its reading
/// on the right, or two readings side by side.
class MiningDetailRow extends StatelessWidget {
  const MiningDetailRow({
    required this.label,
    required this.value,
    super.key,
    this.trailingLabel,
    this.trailingValue,
    this.valueStyle,
    this.spoken,
  });

  final String label;
  final String value;
  final String? trailingLabel;
  final String? trailingValue;

  /// The step of the single reading; [LoopType.figureLg] unless a caller
  /// names a smaller figure step (decision 0192).
  final TextStyle? valueStyle;

  /// What a screen reader hears when [value] is an em dash.
  final String? spoken;

  @override
  Widget build(BuildContext context) {
    final left = trailingLabel == null
        ? Text(
            label,
            style: LoopType.captionSm.copyWith(color: LoopColors.text2),
          )
        : _pair(label, value);
    final right = trailingLabel == null
        ? Text(value, style: valueStyle ?? LoopType.figureLg)
        : _pair(trailingLabel!, trailingValue ?? launchMissingFigure);
    return Semantics(
      container: true,
      label: <String>[
        '$label${LoopL10n.current.common_listSeparator}${spoken ?? value}',
        if (trailingLabel != null)
          '$trailingLabel${LoopL10n.current.common_listSeparator}${trailingValue ?? ''}',
      ].join(LoopL10n.current.widgets_sentenceJoin),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Flexible(child: left),
            const SizedBox(width: 18),
            Flexible(child: right),
          ],
        ),
      ),
    );
  }

  static Widget _pair(String label, String value) => Text.rich(
    TextSpan(
      children: <InlineSpan>[
        TextSpan(
          text: '$label ',
          style: LoopType.captionSm.copyWith(color: LoopColors.text2),
        ),
        TextSpan(text: value, style: LoopType.figure),
      ],
    ),
    maxLines: 2,
  );
}

/// `.ledger-rule`: the hairline inside a composite strip.
class MiningDetailRule extends StatelessWidget {
  const MiningDetailRule({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Container(height: 1, color: LoopGround.hairlineOf(context)),
  );
}

/// The prototype's `mining-asset` row: the token, the multiplication that
/// produced its power, and the power itself.
///
/// Decision 0146 (loop-api 0123, client 0143): the asset track is weighted
/// by quantity — `持有量 × 权重`, no price. The row writes the expression the
/// way the prototype does; the labelled reading stays in the semantic label,
/// where a screen reader needs the words rather than the operators. The
/// reference price the legacy snapshot still carries is no longer printed.
LoopRecordRow miningCompositionRow(
  MiningAssetRow row,
  LoopRowPosition position, {
  String keyPrefix = 'mining-assets-row',
  String? power,
}) {
  // Decision 0253: in the 代币 group the row shows `power − nftPower`.
  final shown = power ?? row.power;
  final label = miningAssetTitle(symbol: row.symbol, assetId: row.assetId);
  // A named row still says which asset it is: the id is the identity, the
  // symbol is only how the registry writes it.
  final identity = row.symbol == null ? null : miningAssetLabel(row.assetId);
  return LoopRecordRow(
    key: ValueKey<String>('$keyPrefix-${row.assetId}'),
    leading: LoopTokenLogo(
      assetSymbol: row.symbol ?? label,
      logoUrl: row.logoUrl,
      size: 44,
      semanticLabel: label,
    ),
    title: label,
    subtitle: <String>[miningCompositionExpression(row), ?identity].join('\n'),
    subtitleMaxLines: 2,
    trailing: loopPowerFigure(shown),
    trailingCaption: LoopL10n.current.common_power,
    semanticLabel: <String>[
      label,
      LoopL10n.current.mining_widgetsLoopRecordRow(
        loopAmountFigure(row.holding),
      ),
      LoopL10n.current.intel_rankBoardText5(row.weight),
      LoopL10n.current.intel_rankBoardIf6(loopPowerFigure(shown)),
    ].join(LoopL10n.current.common_listSeparator),
    position: position,
  );
}

/// Decision 0253: one MEME's NFT share in 算力构成's NFT group — the asset's
/// mark and name, and `included[].nftPower`.
LoopRecordRow miningNftCompositionRow(
  MiningAssetRow row,
  String nftPower,
  LoopRowPosition position,
) {
  final label = miningAssetTitle(symbol: row.symbol, assetId: row.assetId);
  final identity = row.symbol == null ? null : miningAssetLabel(row.assetId);
  return LoopRecordRow(
    key: ValueKey<String>('mining-composition-nft-${row.assetId}'),
    leading: LoopTokenLogo(
      assetSymbol: row.symbol ?? label,
      logoUrl: row.logoUrl,
      size: 44,
      semanticLabel: label,
    ),
    title: label,
    subtitle: identity,
    trailing: loopPowerFigure(nftPower),
    trailingCaption: LoopL10n.current.mining_screenCell2,
    semanticLabel: <String>[
      label,
      LoopL10n.current.mining_widgetsLoopRecordRow4(loopPowerFigure(nftPower)),
    ].join(LoopL10n.current.common_listSeparator),
    position: position,
  );
}

/// `持有量 × 权重` for one asset row (decision 0146): quantity times weight,
/// no price.
String miningCompositionExpression(MiningAssetRow row) =>
    // Decision 0149: 「0 × 0.9×」 read as a dangling second ×; the weight
    // is named instead, in the same order as the heading 持有量 × 权重.
    LoopL10n.current.mining_widgetsMiningCompositionExpression(
      loopAmountFigure(row.holding),
      row.weight,
    );
