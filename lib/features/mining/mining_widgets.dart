import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

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
              ? '开发基线已生效，数字只用于开发验证。'
              : '已生效 · ${launchTimestampLabel(effectiveAt)}',
          trailing: scope.isBaseline ? miningBaselineLabel : '已生效',
          semanticLabel: scope.isBaseline ? '挖矿公式为开发基线' : '挖矿公式已生效',
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
                style: LoopTypography.caption(11, color: LoopColors.text3),
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
              Text(
                label,
                style: LoopTypography.figure(11, color: LoopColors.text3),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: LoopTypography.figure(
                  20,
                  height: 1.15,
                  color: LoopColors.chalk,
                ),
              ),
              if (caption.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: LoopTypography.caption(11, color: LoopColors.text2),
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
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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

  /// `.mining-summary-actions button:first-child`: Ink-filled on Lime, the
  /// strongest contrast in the app. Null while the server keeps the claim
  /// closed; the reason for that stays with the block that owns it.
  final VoidCallback? onClaim;
  final String? claimSemanticLabel;
  final VoidCallback? onOpenAssets;

  @override
  Widget build(BuildContext context) {
    const ink = LoopColors.ink;
    final muted = ink.withValues(alpha: 0.58);
    final rule = ink.withValues(alpha: 0.16);
    return LoopLedgerCard(
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
                  'MINING POWER',
                  style: LoopTypography.eyebrow(9, color: muted),
                ),
              ),
              if (rank != null)
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: 'RANK ',
                        style: LoopTypography.eyebrow(9, color: muted),
                      ),
                      TextSpan(
                        text: rank,
                        style: LoopTypography.figure(
                          11,
                          weight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                    ],
                  ),
                  key: const ValueKey<String>('mining-summary-hero-rank'),
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
                    style: LoopTypography.figure(
                      16,
                      weight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
              ],
            ),
            key: const ValueKey<String>('mining-summary-hero-power'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: LoopTypography.display(
              // `.mining-power-value` is 44px for a figure; words in that slot
              // would wrap to three lines and push the metrics off the card.
              unit == null ? 29 : 44,
              color: ink,
            ).copyWith(height: 0.98, letterSpacing: -2),
          ),
          const SizedBox(height: 9),
          Text(
            caption,
            key: const ValueKey<String>('mining-summary-hero-caption'),
            style: LoopTypography.caption(
              11,
              color: ink.withValues(alpha: 0.67),
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          if (stamp != null) ...<Widget>[
            const SizedBox(height: 9),
            _HeroStamp(label: stamp!),
          ],
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: rule),
                bottom: BorderSide(color: rule),
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
                            : Border(
                                right: BorderSide(
                                  color: ink.withValues(alpha: 0.14),
                                ),
                              ),
                      ),
                      child: Semantics(
                        container: true,
                        label:
                            '${metrics[index].label}，${metrics[index].spoken}',
                        child: ExcludeSemantics(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                metrics[index].value,
                                key: ValueKey<String>(
                                  'mining-summary-hero-'
                                  '${metrics[index].slug}',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LoopTypography.figure(
                                  11,
                                  height: 1.2,
                                  weight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                metrics[index].label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LoopTypography.caption(
                                  10,
                                  color: muted,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _HeroAction(
                  key: const ValueKey<String>('mining-summary-hero-claim'),
                  label: '领取奖励',
                  filled: true,
                  onPressed: onClaim,
                  semanticLabel: claimSemanticLabel,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _HeroAction(
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

/// `.mining-summary-actions button`. The filled one is Ink on Lime.
class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.label,
    this.filled = false,
    this.onPressed,
    this.semanticLabel,
    super.key,
  });

  final String label;
  final bool filled;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final background = filled && enabled ? LoopColors.ink : Colors.transparent;
    final foreground = filled && enabled
        ? LoopColors.chalk
        : LoopColors.ink.withValues(alpha: enabled ? 1 : 0.38);
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: filled && enabled
                    ? LoopColors.ink
                    : LoopColors.ink.withValues(alpha: 0.22),
              ),
            ),
            child: Text(
              label,
              style: LoopTypography.label(
                12,
                weight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.folio-stamp` drawn in the flow of the Lime hero rather than over it.
class _HeroStamp extends StatelessWidget {
  const _HeroStamp({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey<String>('mining-summary-hero-stamp'),
        padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: LoopColors.ink.withValues(alpha: 0.68)),
        ),
        child: Text(
          label.toUpperCase(),
          style: LoopTypography.eyebrow(
            11,
            color: LoopColors.ink.withValues(alpha: 0.68),
          ),
        ),
      ),
    );
  }
}

/// `.ledger-composite` — a folio with a detail strip welded under it.
///
/// The prototype gives five of the six mining pages this shape: the primary
/// states the page's one conclusion, and the strip beneath carries the one or
/// two readings that belong to it (`我的总算力 50,000`, `社区排名 #7 · 7D
/// +12.8%`). The App had turned each strip into a separate key-value section
/// further down the page (visual audit §I.3–I.7).
class MiningCompositePrimary extends StatelessWidget {
  const MiningCompositePrimary({
    required this.primary,
    required this.detail,
    super.key,
  });

  /// The `.folio-primary` welded to the top of the composite. It must carry
  /// `margin: EdgeInsets.zero` and `squareBottom: true` so the strip below it
  /// shares an edge with it rather than floating under it.
  final Widget primary;

  /// The rows inside `.ledger-composite-detail`.
  final List<Widget> detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ColoredBox(
          color: LoopColors.graphite,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              primary,
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x1AF3F5EF))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: detail,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    this.valueSize = 20,
    this.spoken,
  });

  final String label;
  final String value;
  final String? trailingLabel;
  final String? trailingValue;
  final double valueSize;

  /// What a screen reader hears when [value] is an em dash.
  final String? spoken;

  @override
  Widget build(BuildContext context) {
    final left = trailingLabel == null
        ? Text(
            label,
            style: LoopTypography.caption(11, color: LoopColors.text2),
          )
        : _pair(label, value);
    final right = trailingLabel == null
        ? Text(
            value,
            style: LoopTypography.figure(
              valueSize,
              weight: FontWeight.w700,
              color: LoopColors.chalk,
            ),
          )
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
          style: LoopTypography.caption(11, color: LoopColors.text2),
        ),
        TextSpan(
          text: value,
          style: LoopTypography.figure(
            12,
            weight: FontWeight.w700,
            color: LoopColors.chalk,
          ),
        ),
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
/// `持有量 × 参考价 × 权重` is the module's whole claim, and the App used to
/// print it as three labelled key-value fragments so the expression never
/// appeared (visual audit §I.1). The row now writes it the way the prototype
/// does; the labelled reading stays in the semantic label, where a screen
/// reader needs the words rather than the operators.
LoopRecordRow miningCompositionRow(
  MiningAssetRow row,
  LoopRowPosition position, {
  Map<String, String> symbols = const <String, String>{},
  String keyPrefix = 'mining-assets-row',
}) {
  final label = miningAssetTitle(symbol: row.symbol, assetId: row.assetId);
  final proxy = row.referencePriceProxyAssetId;
  final proxyLabel = proxy == null
      ? ''
      : miningAssetTitle(symbol: symbols[proxy], assetId: proxy);
  final pool = row.referencePricePairAddress;
  // Three ways a price can have been read, and the row says which one it was:
  // the asset's own pair, another token's (Decision 0044), or one pool
  // divided out and checked against the declared band (Decision 0059).
  final priceNote = proxy != null
      ? '代理价，来自 $proxyLabel'
      : row.isDerivedPrice && pool != null
      ? '推导价，来源池 ${miningPricePoolLabel(pool)}'
      : null;
  // A named row still says which asset it is: the id is the identity, the
  // symbol is only how the registry writes it.
  final identity = row.symbol == null ? null : miningAssetLabel(row.assetId);
  final second = <String>[?identity, ?priceNote].join(' · ');
  return LoopRecordRow(
    key: ValueKey<String>('$keyPrefix-${row.assetId}'),
    leading: LoopTokenLogo(
      assetSymbol: row.symbol ?? label,
      size: 44,
      semanticLabel: label,
    ),
    title: label,
    subtitle: <String>[
      '${row.holding} × \$${row.referencePriceUsd} × ${row.weight}×',
      if (second.isNotEmpty) second,
    ].join('\n'),
    subtitleMaxLines: 2,
    trailing: row.power,
    trailingCaption: '算力',
    semanticLabel: <String>[
      label,
      '持有 ${row.holding}',
      '参考价 ${row.referencePriceUsd} 美元',
      '权重 ${row.weight}',
      '算力 ${row.power}',
      if (proxy != null) '参考价来自另一个代币的代理价',
      if (proxy == null && row.isDerivedPrice) '参考价由一个报价对推导得出',
    ].join('，'),
    position: position,
  );
}

/// The reasons behind the em dashes a mining primary prints.
///
/// A composite primary states its readings as figures or as `—`, and a dash
/// on its own is not an answer. This states each distinct reason once, naming
/// the readings it speaks for — never the same sentence three times, and never
/// a sentence the primary's own caption has already said.
class MiningDashReasons extends StatelessWidget {
  const MiningDashReasons({
    required this.slug,
    required this.said,
    required this.entries,
    super.key,
  });

  final String slug;

  /// Sentences the primary already carries. They are not written again.
  final Set<String> said;

  /// `(label, reason)` for every reading that came back without a figure.
  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<String>>{};
    for (final (label, reason) in entries) {
      if (said.contains(reason)) continue;
      grouped.putIfAbsent(reason, () => <String>[]).add(label);
    }
    if (grouped.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: ValueKey<String>('$slug-dash-reasons'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final entry in grouped.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${entry.value.join('、')}：${entry.key}',
                style: LoopTypography.caption(11, color: LoopColors.text2),
              ),
            ),
        ],
      ),
    );
  }
}
