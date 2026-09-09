import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
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
/// so every figure on this page is the em dash plus the server's own reason.
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
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'MINING POWER',
        heading: launchMissingFigure,
        caption: '算力、今日预估、累计与待领取都要等挖矿公式版本被批准后才能计算。',
        stamp: summary?.formula.pendingVersion == null
            ? null
            : '待批准（${summary!.formula.pendingVersion}）',
      ),
      sections: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>('mining-capability-unavailable'),
            icon: 'warn',
            message: '挖矿当前不可用',
            reason: capability.reasonCode == null
                ? '尚未读取到能力清单，本页不请求任何挖矿数据。'
                : '服务端原因：${capability.reasonCode}。',
          )
        else if (summary == null)
          LaunchStateBlock(
            prefix: 'mining',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到挖矿摘要',
            emptyReason: '服务端没有返回任何算力口径。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('算力与产出'),
          LaunchEmptyMetricGrid(
            key: const ValueKey<String>('mining-metrics'),
            metrics: <(String, String)>[
              ('我的算力', summary.power.reasonCode),
              ('全网算力', summary.networkPower.reasonCode),
              ('今日预估', summary.estimatedToday.reasonCode),
              ('累计已挖', summary.accumulated.reasonCode),
              ('待领取', summary.claimable.reasonCode),
              ('邀请加成', summary.referralBoost.reasonCode),
            ],
          ),
          const LoopLabel('公式版本'),
          _FormulaBlock(formula: summary.formula),
          const LoopLabel('结算快照'),
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
          const LoopNotice(
            key: ValueKey<String>('mining-truth-notice'),
            icon: 'shield',
            title: '不做本地估算',
            body:
                '挖矿公式属于后端交付 D19，目前没有任何已批准的版本。'
                '客户端不会累计积分、估算收益或创建领取操作；缺少来源与「算力为零」是两回事。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _FormulaBlock extends StatelessWidget {
  const _FormulaBlock({required this.formula});

  final MiningFormulaGate formula;

  @override
  Widget build(BuildContext context) {
    final pending = formula.pendingVersion;
    return LoopRecordGroup(
      key: const ValueKey<String>('mining-formula'),
      rows: <LoopRecordRow>[
        LoopRecordRow(
          key: const ValueKey<String>('mining-formula-row'),
          title: '挖矿公式',
          subtitle: launchReasonCodeText(formula.reasonCode),
          trailing: pending ?? launchMissingFigure,
          trailingCaption: pending == null ? null : '待批准',
          semanticLabel: pending == null ? '挖矿公式尚未确定' : '挖矿公式待批准，版本 $pending',
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
        message: '还没有结算快照',
        reason: launchReasonCodeText(reasonCode),
      ),
      MiningSnapshotComputed(
        :final blockNumber,
        :final formulaVersion,
        :final computedAt,
      ) =>
        LoopRecordGroup(
          key: const ValueKey<String>('mining-snapshot'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('mining-snapshot-row'),
              title: '最近一次结算快照',
              subtitle:
                  '区块 $blockNumber · 公式 $formulaVersion · '
                  '${launchTimestampLabel(computedAt)}',
            ),
          ],
        ),
    };
  }
}
