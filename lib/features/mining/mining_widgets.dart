import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
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
