import 'package:flutter/material.dart';
import 'package:loop_mobile/core/text/loop_power_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';

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
          title: '挖矿公式',
          // A pending draft already carries the block's own sentence in
          // 算力与产出 above; repeating it here would be the same screen
          // saying one thing twice.
          subtitle: pendingVersion == null
              ? launchReasonCodeText(reasonCode)
              : '批准后，上面的数字才会有来源。',
          trailing: pendingVersion == null ? launchMissingFigure : '待批准',
          semanticLabel: pendingVersion == null ? '挖矿公式尚未确定' : '挖矿公式待批准',
        ),
        pendingVersion == null ? null : '待批准的公式版本',
      ),
      MiningFormulaEffective(:final scope, :final effectiveAt) => (
        LoopRecordRow(
          key: const ValueKey<String>('mining-formula-row'),
          title: '挖矿公式',
          subtitle: scope.isBaseline
              ? miningBaselineLabel
              : '已生效 · ${launchTimestampLabel(effectiveAt)}',
          trailing: '已生效',
          semanticLabel: '挖矿公式已生效',
        ),
        '已生效的公式版本',
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
            summary: '详情',
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
        label: caption.isEmpty ? '$label，$value' : '$label，$value。$caption',
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
const String miningDemoHoldingsDetail = '这次算力里含演示持仓：它们不在链上，没有人真的持有，数字只用来体验。';

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
          sources: const <String>['LOOP 挖矿规则'],
          detail: detail.isEmpty ? null : detail,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: LoopProvenanceLine(
        key: ValueKey<String>('mining-provenance-$slug'),
        sources: const <String>['LOOP 算力快照'],
        observedAt: source.computedAt,
        detail: detail.isEmpty ? null : detail,
        marker: stale ? '未更新' : null,
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
    required this.caption,
    required this.metrics,
    super.key,
    this.unit,
    this.rank,
    this.stamp,
    this.onClaim,
    this.claimSemanticLabel,
    this.onOpenAssets,
    this.powerOnly = false,
    this.split = const <MiningHeroMetric>[],
  });

  /// The power itself, or the words for its absence. Never a 44px dash.
  final String heading;

  /// `.mining-power-value small`: the unit that follows a settled figure.
  final String? unit;
  final String caption;

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
    // Decision 0210 / S241b: the hero is the flat `#111114` card behind a
    // 1px `#38333E` edge, not a yellow slab. Yellow is kept for the kicker,
    // the power figure and the claim button.
    const ink = LoopColors.chalk;
    const muted = LoopColors.text3;
    return LoopRecordCard(
      key: const ValueKey<String>('mining-summary-hero'),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '总算力',
                  style: LoopType.kicker.copyWith(color: LoopColors.yellow),
                ),
              ),
              if (rank != null)
                Text(
                  rank!,
                  key: const ValueKey<String>('mining-summary-hero-rank'),
                  style: LoopTypography.withWeight(
                    LoopType.figureXs,
                    FontWeight.w600,
                  ).copyWith(color: ink),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: heading),
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: LoopType.figureMd.copyWith(color: muted),
                  ),
              ],
            ),
            key: const ValueKey<String>('mining-summary-hero-power'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            // Decision 0192: the prototype's 44px `.mining-power-value` is the
            // page's hero figure (R22 `figureXl`); words in that slot are a
            // folio heading (R9 `displayXl`). Both are 28 on the ladder.
            // S241b: a settled figure takes the Anton `statFigure` step in
            // yellow; words stay a Chalk folio heading.
            style: unit == null
                ? LoopType.displayXl.copyWith(color: ink)
                : LoopType.statFigure.copyWith(color: LoopColors.yellow),
          ),
          const SizedBox(height: 9),
          Text(
            caption,
            key: const ValueKey<String>('mining-summary-hero-caption'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LoopTypography.withWeight(
              LoopType.captionSm.copyWith(color: LoopColors.text2),
              FontWeight.w700,
            ),
          ),
          if (stamp != null) ...<Widget>[
            const SizedBox(height: 9),
            // `.folio-stamp` in the flow of the Lime card rather than over
            // its corner: the same pill the folio draws (decision 0167).
            Align(
              alignment: Alignment.centerLeft,
              child: LoopFolioStamp(
                stamp!,
                key: const ValueKey<String>('mining-summary-hero-stamp'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _MiningHeroStrip(metrics: metrics, top: true),
          if (split.isNotEmpty)
            _MiningHeroStrip(
              key: const ValueKey<String>('mining-summary-hero-split'),
              metrics: split,
              top: false,
            ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                // `.mining-summary-actions button:first-child`: the yellow CTA.
                child: LoopButton(
                  key: const ValueKey<String>('mining-summary-hero-claim'),
                  // Decision 0184: before the token is live the page it
                  // opens counts power, so the button says so.
                  label: powerOnly ? '小时算力' : '领取奖励',
                  primary: true,
                  onPressed: onClaim,
                  semanticLabel: powerOnly
                      ? '小时算力，打开挖矿奖励页'
                      : claimSemanticLabel,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: LoopButton(
                  key: const ValueKey<String>('mining-summary-hero-assets'),
                  label: '算力明细',
                  onPressed: onOpenAssets,
                ),
              ),
            ],
          ),
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
    const ink = LoopColors.chalk;
    const muted = LoopColors.text3;
    const rule = LoopColors.line;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: rule) : BorderSide.none,
          bottom: const BorderSide(color: rule),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var index = 0; index < metrics.length; index += 1)
            Expanded(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  index == 0 ? 0 : 8,
                  12,
                  index == metrics.length - 1 ? 0 : 8,
                  11,
                ),
                decoration: BoxDecoration(
                  border: index == metrics.length - 1
                      ? null
                      : const Border(right: BorderSide(color: rule)),
                ),
                child: Semantics(
                  container: true,
                  label: '${metrics[index].label}，${metrics[index].spoken}',
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
                          style: LoopType.figure.copyWith(color: ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metrics[index].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopType.kicker.copyWith(color: muted),
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
    padding: const EdgeInsets.fromLTRB(
      LoopSpacing.page,
      12,
      LoopSpacing.page,
      6,
    ),
    child: Semantics(
      header: true,
      label: '$title，$spoken',
      child: ExcludeSemantics(
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.kicker.copyWith(color: LoopColors.text2),
              ),
            ),
            Text(
              subtotal,
              key: ValueKey<String>('mining-composition-$slug-subtotal'),
              maxLines: 1,
              style: LoopType.figure.copyWith(color: LoopColors.chalk),
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
        '$label，${spoken ?? value}',
        if (trailingLabel != null) '$trailingLabel，${trailingValue ?? ''}',
      ].join('。'),
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
    trailingCaption: '算力',
    semanticLabel: <String>[
      label,
      '持有 ${loopAmountFigure(row.holding)}',
      '权重 ${row.weight}',
      '算力 ${loopPowerFigure(shown)}',
    ].join('，'),
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
    trailingCaption: 'NFT 算力',
    semanticLabel: <String>[
      label,
      'NFT 算力 ${loopPowerFigure(nftPower)}',
    ].join('，'),
    position: position,
  );
}

/// `持有量 × 权重` for one asset row (decision 0146): quantity times weight,
/// no price.
String miningCompositionExpression(MiningAssetRow row) =>
    // Decision 0149: 「0 × 0.9×」 read as a dangling second ×; the weight
    // is named instead, in the same order as the heading 持有量 × 权重.
    '${loopAmountFigure(row.holding)} × 权重 ${row.weight}';
