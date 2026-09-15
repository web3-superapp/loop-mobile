import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `mining` · the Mining destination.
///
/// The mining formula is backend delivery D19 and no version is approved yet,
/// so every figure on this page is the em dash plus the server's own reason,
/// and the hero says the absence in words rather than printing a 29px dash.
/// The client never estimates power, output, accumulation or a claim.
class MiningScreen extends ConsumerStatefulWidget {
  const MiningScreen({
    super.key,
    this.onOpenAssets,
    this.onOpenRewards,
    this.onOpenRank,
    this.onOpenRules,
    this.onOpenReferral,
  });

  final VoidCallback? onOpenAssets;
  final VoidCallback? onOpenRewards;
  final VoidCallback? onOpenRank;
  final VoidCallback? onOpenRules;
  final VoidCallback? onOpenReferral;

  @override
  ConsumerState<MiningScreen> createState() => _MiningScreenState();
}

class _MiningScreenState extends ConsumerState<MiningScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningSummaryControllerProvider);
    final controller = ref.read(miningSummaryControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final summary = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '我的挖矿',
      kicker: 'MINING POWER',
      tabPage: true,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('mining-rules-action'),
          icon: 'info',
          label: '挖矿规则',
          onPressed: widget.onOpenRules,
        ),
      ],
      primary: _hero(summary),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('mining-capability-unavailable'),
              title: '挖矿当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (summary == null)
          LaunchStateBlock(
            prefix: 'mining',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到挖矿摘要',
            emptyReason: '暂时读不到算力数据。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('算力与产出'),
          _MetricsBlock(summary: summary),
          const LoopLabel('公式版本'),
          _FormulaBlock(formula: summary.formula),
          const LoopLabel('结算记录'),
          _SnapshotBlock(snapshot: summary.snapshot),
          const LoopLabel('相关页面'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('mining-open-assets'),
                title: '算力明细',
                subtitle: '每个资产的贡献与排除状态',
                onTap: widget.onOpenAssets,
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('mining-open-rewards'),
                title: '奖励与领取',
                subtitle: '领取入口当前不可执行',
                onTap: widget.onOpenRewards,
                position: LoopRowPosition.middle,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('mining-open-rank'),
                title: '算力排行榜',
                subtitle: '用户榜与社区榜',
                onTap: widget.onOpenRank,
                position: LoopRowPosition.middle,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('mining-open-referral'),
                title: '邀请关系加成',
                subtitle: '只计入 Mining Power，不是收入或佣金',
                onTap: widget.onOpenReferral,
                position: LoopRowPosition.last,
              ),
            ],
          ),
          LoopNotice(
            key: const ValueKey<String>('mining-truth-notice'),
            icon: 'shield',
            title: '不做本地估算',
            body: switch (summary.formula) {
              MiningFormulaPending() =>
                '挖矿公式还没有批准的版本。'
                    'LOOP 不会在这台设备上累计积分或估算收益。读不到不等于「算力为零」。',
              MiningFormulaEffective(:final scope) when scope.isBaseline =>
                '当前生效的是开发基线，算出来的数字只用于开发验证，'
                    '不是收益，也不构成承诺。LOOP 不会在这台设备上累计积分。',
              MiningFormulaEffective() =>
                'LOOP 不会在这台设备上累计积分或估算收益，页面上的数字都来自最近一次结算。',
            },
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// The hero. It says in words what the page can and cannot state: no approved
/// version means no figure at all; a development baseline means there are
/// figures and they are not a product measure.
LoopFolioPrimary _hero(MiningSummary? summary) {
  final gate = summary?.formula;
  return switch (gate) {
    null || MiningFormulaPending() => LoopFolioPrimary(
      variant: LoopFolioVariant.quiet,
      archetype: LoopFolioArchetype.record,
      kicker: 'MINING POWER',
      heading: launchMissingHeading,
      caption: '算力、今日预估、累计与待领取都要等挖矿公式版本被批准后才能计算。',
      stamp: gate is MiningFormulaPending && gate.pendingVersion != null
          ? '待批准'
          : null,
    ),
    MiningFormulaEffective(:final scope) => LoopFolioPrimary(
      variant: LoopFolioVariant.quiet,
      archetype: LoopFolioArchetype.record,
      kicker: 'MINING POWER',
      heading: switch (summary!.power) {
        MiningFigureValue(:final value) => value,
        MiningFigureUnavailable() => launchMissingHeading,
      },
      caption: scope.isBaseline
          ? '这些数字来自开发基线，只用于开发验证，不是收益。'
          : '数字来自最近一次结算，不是收益承诺。',
      stamp: scope.isBaseline ? miningBaselineLabel : null,
    ),
  };
}

/// The label a development-baseline figure always carries. The version string
/// itself is a backend identifier and stays inside 详情.
const String miningBaselineLabel = '开发基线';

/// 算力与产出. A figure prints only when the server settled it; everything
/// else keeps the em dash plus the server's own reason. A placeholder budget
/// never prints as a bare number.
class _MetricsBlock extends StatelessWidget {
  const _MetricsBlock({required this.summary});

  final MiningSummary summary;

  @override
  Widget build(BuildContext context) {
    final baseline = switch (summary.formula) {
      MiningFormulaEffective(:final scope) => scope.isBaseline,
      MiningFormulaPending() => false,
    };
    final output = summary.estimatedToday;
    if (summary.power is MiningFigureUnavailable &&
        summary.networkPower is MiningFigureUnavailable &&
        output is MiningDailyOutputUnavailable) {
      // Nothing was settled, and one missing baseline is usually why. The
      // grid states that sentence once for the whole block.
      return LaunchEmptyMetricGrid(
        key: const ValueKey<String>('mining-metrics'),
        metrics: <(String, String)>[
          ('我的算力', (summary.power as MiningFigureUnavailable).reasonCode),
          (
            '全网算力',
            (summary.networkPower as MiningFigureUnavailable).reasonCode,
          ),
          ('今日预估', output.reasonCode),
          ('累计已挖', summary.accumulated.reasonCode),
          ('待领取', summary.claimable.reasonCode),
          ('邀请加成', summary.referralBoost.reasonCode),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _MetricRow(
          slug: 'power',
          label: '我的算力',
          figure: summary.power,
          baseline: baseline,
        ),
        _MetricRow(
          slug: 'network-power',
          label: '全网算力',
          figure: summary.networkPower,
          baseline: baseline,
        ),
        _MetricRow(
          slug: 'estimated-today',
          label: '今日预估',
          figure: switch (output) {
            MiningDailyOutputEstimate(:final value) => MiningFigureValue(value),
            MiningDailyOutputUnavailable(:final reasonCode) =>
              MiningFigureUnavailable(reasonCode),
          },
          baseline: baseline,
          note:
              output is MiningDailyOutputEstimate && output.isPlaceholderBudget
              ? '按占位产量估算，奖励代币还没有确定。'
              : null,
        ),
        LaunchEmptyMetricGrid(
          key: const ValueKey<String>('mining-metrics'),
          metrics: <(String, String)>[
            ('累计已挖', summary.accumulated.reasonCode),
            ('待领取', summary.claimable.reasonCode),
            ('邀请加成', summary.referralBoost.reasonCode),
          ],
        ),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.slug,
    required this.label,
    required this.figure,
    required this.baseline,
    this.note,
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
    final value = (figure as MiningFigureValue).value;
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

/// The formula gate. The row says whether a version is in effect and whether
/// it is the development baseline; the version string is a backend identifier
/// and stays inside the collapsed 详情.
class _FormulaBlock extends StatelessWidget {
  const _FormulaBlock({required this.formula});

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

class _SnapshotBlock extends StatelessWidget {
  const _SnapshotBlock({required this.snapshot});

  final MiningSnapshotRef snapshot;

  @override
  Widget build(BuildContext context) {
    return switch (snapshot) {
      MiningSnapshotUnavailable(:final reasonCode) => LoopEmpty(
        key: const ValueKey<String>('mining-snapshot-unavailable'),
        icon: 'clock',
        message: '还没有结算记录',
        reason: launchReasonCodeText(reasonCode),
      ),
      MiningSnapshotComputed(:final blockNumber, :final computedAt) =>
        LoopRecordGroup(
          key: const ValueKey<String>('mining-snapshot'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('mining-snapshot-row'),
              title: '最近一次结算',
              subtitle: '区块 $blockNumber · ${launchTimestampLabel(computedAt)}',
            ),
          ],
        ),
    };
  }
}
