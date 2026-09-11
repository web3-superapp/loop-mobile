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

/// The capability gate copy shared by the five secondary mining pages.
LoopEmpty _miningCapabilityBlock(
  String key,
  String subject,
  LoopCapabilityProjection capability,
) => LoopEmpty(
  key: ValueKey<String>(key),
  icon: 'warn',
  message: '$subject当前不可用',
  reason: '请稍后再试。',
);

/// `mining-assets` · the per-asset power breakdown.
class MiningAssetsScreen extends ConsumerStatefulWidget {
  const MiningAssetsScreen({
    super.key,
    this.onBack,
    this.onOpenRules,
    this.onOpenCommunities,
  });

  final VoidCallback? onBack;
  final VoidCallback? onOpenRules;

  /// The community directory, from which one community's mining panel is
  /// reachable. There is no weighted-community list to link to directly: the
  /// weights themselves are still under review.
  final VoidCallback? onOpenCommunities;

  @override
  ConsumerState<MiningAssetsScreen> createState() => _MiningAssetsScreenState();
}

class _MiningAssetsScreenState extends ConsumerState<MiningAssetsScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningAssetsControllerProvider);
    final controller = ref.read(miningAssetsControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final assets = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-assets-screen'),
      archetype: LoopPageArchetype.record,
      title: '算力明细',
      kicker: 'POWER FORMULA',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('mining-assets-rules-action'),
          icon: 'info',
          label: '查看规则',
          onPressed: widget.onOpenRules,
        ),
      ],
      primary: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'POWER FORMULA',
        heading: launchMissingFigure,
        caption: '每个资产的贡献需要公式、权重与参考价三项齐备，目前都还读不到。',
        stamp: 'UNAVAILABLE',
      ),
      sections: <Widget>[
        if (blocked)
          _miningCapabilityBlock(
            'mining-assets-capability-unavailable',
            '算力明细',
            capability,
          )
        else if (assets == null)
          LaunchStateBlock(
            prefix: 'mining-assets',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '没有读到算力明细',
            emptyReason: '暂时读不到资产数据。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('我的总算力'),
          LaunchEmptyMetric(
            key: const ValueKey<String>('mining-assets-total'),
            label: '我的总算力',
            reasonCode: assets.totalPower.reasonCode,
          ),
          const LoopLabel('计入与排除的资产'),
          LaunchUnavailableCard(label: '资产明细出处', fact: assets.source),
          const LoopNotice(
            key: ValueKey<String>('mining-assets-empty-notice'),
            icon: 'info',
            title: '空列表是正常结果',
            body: '计入与排除列表都是空的。这不代表你的钱包没有持仓，也不代表某个资产被排除。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const LoopLabel('社区权重'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('mining-assets-open-communities'),
                title: '查看社区挖矿面板',
                subtitle: '每个社区的权重按审核结果授予',
                onTap: widget.onOpenCommunities,
              ),
            ],
          ),
          const LoopLabel('参考价'),
          LaunchUnavailableCard(label: '挖矿参考价', fact: assets.referencePrice),
          const LoopNotice(
            key: ValueKey<String>('mining-assets-price-notice'),
            icon: 'shield',
            title: '参考价不是瞬时成交价',
            body: '参考价由多个渠道的价格计算得出，具体规则等公式批准后才公开。这里不显示任何倍率或价格。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `mining-rewards` · settled rewards and the claim entry point.
class MiningRewardsScreen extends ConsumerStatefulWidget {
  const MiningRewardsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<MiningRewardsScreen> createState() =>
      _MiningRewardsScreenState();
}

class _MiningRewardsScreenState extends ConsumerState<MiningRewardsScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningRewardsControllerProvider);
    final controller = ref.read(miningRewardsControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final rewards = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-rewards-screen'),
      archetype: LoopPageArchetype.record,
      title: '奖励与领取',
      kicker: 'CLAIMABLE REWARD',
      onBack: widget.onBack,
      primary: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'CLAIMABLE REWARD',
        heading: launchMissingFigure,
        caption: '还没有发生过结算，因此没有可领取的数量。',
        stamp: 'NOT CLAIMABLE',
      ),
      sections: <Widget>[
        if (blocked)
          _miningCapabilityBlock(
            'mining-rewards-capability-unavailable',
            '奖励与领取',
            capability,
          )
        else if (rewards == null)
          LaunchStateBlock(
            prefix: 'mining-rewards',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '没有读到奖励记录',
            emptyReason: '暂时读不到奖励数据。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('奖励规则'),
          LaunchEmptyMetricGrid(
            key: const ValueKey<String>('mining-rewards-metrics'),
            metrics: <(String, String)>[
              ('待领取', rewards.claimable.reasonCode),
              ('今日预估', rewards.estimatedToday.reasonCode),
              ('累计已挖', rewards.accumulated.reasonCode),
            ],
          ),
          const LoopLabel('领取'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LoopButton(
              key: const ValueKey<String>('mining-rewards-claim'),
              label: '领取到钱包',
              primary: true,
              block: true,
              // Disabled by the server's own `claimExecutable: false`.
              onPressed: rewards.claimExecutable ? () {} : null,
              semanticLabel: '领取到钱包，当前不可执行',
            ),
          ),
          LoopNotice(
            key: const ValueKey<String>('mining-rewards-claim-notice'),
            icon: 'lock',
            tone: LoopNoticeTone.warn,
            title: '领取入口不可执行',
            body: launchReasonCodeText(rewards.claimable.reasonCode),
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const LoopLabel('结算记录'),
          LaunchUnavailableCard(label: '结算与领取记录', fact: rewards.source),
          const LoopNotice(
            key: ValueKey<String>('mining-rewards-ledger-notice'),
            icon: 'info',
            title: '没有记录不等于没有产出',
            body: '还没有发生过结算，所以账本是空的。公式批准并完成第一次结算后，这里才会有可核对的条目。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `mining-rank` · the power leaderboard.
class MiningRankScreen extends ConsumerStatefulWidget {
  const MiningRankScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<MiningRankScreen> createState() => _MiningRankScreenState();
}

class _MiningRankScreenState extends ConsumerState<MiningRankScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningRankControllerProvider);
    final controller = ref.read(miningRankControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final rank = state.value;
    final scope = rank?.scope ?? controller.scope;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-rank-screen'),
      archetype: LoopPageArchetype.record,
      title: '算力排行榜',
      kicker: 'NETWORK POSITION',
      onBack: widget.onBack,
      primary: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'NETWORK POSITION',
        heading: launchMissingFigure,
        caption: '排名要等算力结算之后才有，目前还没有结算过。',
        stamp: 'UNAVAILABLE',
      ),
      sections: <Widget>[
        if (blocked)
          _miningCapabilityBlock(
            'mining-rank-capability-unavailable',
            '排行榜',
            capability,
          )
        else ...<Widget>[
          LoopSegBar(
            key: const ValueKey<String>('mining-rank-scope'),
            labels: <String>[
              miningRankScopeLabel(MiningRankScope.communities),
              miningRankScopeLabel(MiningRankScope.users),
            ],
            selectedIndex: scope == MiningRankScope.communities ? 0 : 1,
            onSelected: (index) => unawaited(
              controller.select(
                index == 0
                    ? MiningRankScope.communities
                    : MiningRankScope.users,
              ),
            ),
          ),
          if (rank == null)
            LaunchStateBlock(
              prefix: 'mining-rank',
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: '没有读到排行榜',
              emptyReason: '暂时读不到排行数据。',
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            const LoopLabel('榜单'),
            LaunchUnavailableCard(label: '排行榜条目', fact: rank.ranking),
            const LoopLabel('我的名次'),
            LaunchUnavailableCard(label: '我的名次', fact: rank.myPosition),
            const LoopLabel('匿名显示规则'),
            LoopNotice(
              key: const ValueKey<String>('mining-rank-anonymity'),
              icon: 'shield',
              title: '排行条目如何显示身份',
              body:
                  '${miningRuleKeyText(rank.display.ruleKey)}'
                  '未满足条件时显示「${miningRuleKeyText(rank.display.anonymousMemberKey)}」。'
                  '这条规则不会因为榜单何时上线而改变。',
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
            const LoopNotice(
              key: ValueKey<String>('mining-rank-notice'),
              icon: 'info',
              title: '排名不是静态权益',
              body: '其他账号或社区的算力变化会改变名次。榜单只来自最近一次结算，不会在这台设备上计算。',
              margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `mining-community` · one community's mining panel.
class MiningCommunityScreen extends ConsumerStatefulWidget {
  const MiningCommunityScreen({super.key, this.communityId, this.onBack});

  final String? communityId;
  final VoidCallback? onBack;

  @override
  ConsumerState<MiningCommunityScreen> createState() =>
      _MiningCommunityScreenState();
}

class _MiningCommunityScreenState extends ConsumerState<MiningCommunityScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningCommunityControllerProvider);
    final controller = ref.read(miningCommunityControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.communityId));
      });
    }
    final community = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-community-screen'),
      archetype: LoopPageArchetype.record,
      title: community?.community.name ?? '社区挖矿面板',
      kicker: 'COMMUNITY POWER',
      onBack: widget.onBack,
      primary: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'COMMUNITY POWER',
        heading: launchMissingFigure,
        caption: '社区总算力、我的贡献与参与人数都要等挖矿公式确定，目前还读不到。',
        stamp: 'UNAVAILABLE',
      ),
      sections: <Widget>[
        if (blocked)
          _miningCapabilityBlock(
            'mining-community-capability-unavailable',
            '社区挖矿面板',
            capability,
          )
        else if (community == null)
          LaunchStateBlock(
            prefix: 'mining-community',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到这个社区',
            emptyReason: '社区可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('社区权重'),
          _WeightBlock(weight: community.weight),
          const LoopLabel('算力规则'),
          LaunchEmptyMetricGrid(
            key: const ValueKey<String>('mining-community-metrics'),
            metrics: <(String, String)>[
              ('社区总算力', community.communityPower.reasonCode),
              ('我的贡献', community.myContribution.reasonCode),
              ('社区排名', community.rank.reasonCode),
              ('参与人数', community.participants.reasonCode),
            ],
          ),
          const LoopLabel('绑定资产'),
          LoopRecordGroup(
            key: const ValueKey<String>('mining-community-asset'),
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('mining-community-asset-row'),
                title: '绑定资产',
                subtitle: community.community.boundAssetId == null
                    ? '这个社区还没有绑定资产'
                    : community.community.boundAssetId!,
                trailing: community.community.boundAssetId == null
                    ? launchMissingFigure
                    : '已绑定',
              ),
            ],
          ),
          const LoopNotice(
            key: ValueKey<String>('mining-community-notice'),
            icon: 'shield',
            title: '权重由平台综合评定',
            body: '权重按审核结果给出，评审因子公开、具体分值不公开。未通过审核的社区没有权重，也不会有算力。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _WeightBlock extends StatelessWidget {
  const _WeightBlock({required this.weight});

  final MiningCommunityWeight weight;

  @override
  Widget build(BuildContext context) {
    return switch (weight) {
      MiningCommunityWeightApproved(:final value, :final reviewedAt) =>
        LoopRecordGroup(
          key: const ValueKey<String>('mining-community-weight-approved'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('mining-community-weight-row'),
              title: '已授予权重',
              subtitle: '审核于 ${launchTimestampLabel(reviewedAt)}',
              trailing: value,
            ),
          ],
        ),
      MiningCommunityWeightPending(:final reasonCode) => LoopEmpty(
        key: const ValueKey<String>('mining-community-weight-pending'),
        icon: 'clock',
        message: '权重审核中',
        reason: launchReasonCodeText(reasonCode),
      ),
    };
  }
}

/// `mining-rules` · the weight and price-guard rules.
///
/// It shows the version that is waiting for approval and labels it as such;
/// it never fills in a ratio, a band or a threshold of its own.
class MiningRulesScreen extends ConsumerStatefulWidget {
  const MiningRulesScreen({super.key, this.onBack, this.onOpenReferral});

  final VoidCallback? onBack;
  final VoidCallback? onOpenReferral;

  @override
  ConsumerState<MiningRulesScreen> createState() => _MiningRulesScreenState();
}

class _MiningRulesScreenState extends ConsumerState<MiningRulesScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.mining),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(miningRulesControllerProvider);
    final controller = ref.read(miningRulesControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final rules = state.value;
    final draft = rules == null || rules.pendingApproval.isEmpty
        ? null
        : rules.pendingApproval.first;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-rules-screen'),
      archetype: LoopPageArchetype.record,
      title: '权重与价格保护',
      kicker: 'POWER RULES',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'POWER RULES',
        heading: draft == null
            ? launchMissingFigure
            : miningRuleKeyText(draft.expressionKey),
        caption: '规则以已批准的公式为准。下面是还没批准的草案。',
        stamp: draft == null ? null : '待批准',
      ),
      sections: <Widget>[
        if (blocked)
          _miningCapabilityBlock(
            'mining-rules-capability-unavailable',
            '挖矿规则',
            capability,
          )
        else if (rules == null)
          LaunchStateBlock(
            prefix: 'mining-rules',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到规则',
            emptyReason: '暂时读不到公式版本。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('已批准的版本'),
          if (rules.approved == null)
            LaunchUnavailableCard(label: '已批准的公式版本', fact: rules.baseline)
          else
            _FormulaVersionBlock(
              version: rules.approved!,
              keyPrefix: 'mining-rules-approved',
            ),
          const LoopLabel('待批准的版本'),
          if (rules.pendingApproval.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('mining-rules-no-pending'),
              icon: 'info',
              message: '没有待批准的版本',
              reason: '目前没有草案版本。',
            )
          else
            for (final version in rules.pendingApproval)
              _FormulaVersionBlock(
                version: version,
                keyPrefix: 'mining-rules-pending-${version.configVersion}',
              ),
          const LoopLabel('邀请关系规则'),
          LoopRecordGroup(
            key: const ValueKey<String>('mining-rules-referral'),
            rows: <LoopRecordRow>[
              for (
                var index = 0;
                index < rules.referral.levels.length;
                index += 1
              )
                LoopRecordRow(
                  key: ValueKey<String>(
                    'mining-rules-referral-l'
                    '${rules.referral.levels[index].level}',
                  ),
                  title: 'L${rules.referral.levels[index].level}',
                  subtitle:
                      '生效于 '
                      '${launchTimestampLabel(rules.referral.effectiveAt)}',
                  trailing: '${rules.referral.levels[index].boostPercent}%',
                  position: launchRowPosition(
                    index,
                    rules.referral.levels.length,
                  ),
                ),
            ],
          ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('mining-rules-open-referral'),
                label: '查看我的邀请关系',
                onPressed: widget.onOpenReferral,
              ),
            ],
          ),
          const LoopNotice(
            key: ValueKey<String>('mining-rules-notice'),
            icon: 'shield',
            title: '草案不是生效规则',
            body: '待批准的版本不会参与任何计算。权重区间与价格保护阈值只有规则条目，没有数值；批准之后才会公布。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _FormulaVersionBlock extends StatelessWidget {
  const _FormulaVersionBlock({required this.version, required this.keyPrefix});

  final MiningFormulaVersion version;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final rows = <LoopRecordRow>[
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-expression'),
        title: '算力公式',
        subtitle: miningRuleKeyText(version.expressionKey),
        trailingBadge: LoopBadge(
          miningFormulaStatusLabel(version.status),
          kind: version.status == MiningFormulaStatus.approved
              ? LoopBadgeKind.mining
              : LoopBadgeKind.mute,
        ),
        position: LoopRowPosition.first,
      ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-daily-output'),
        title: '每日产出',
        subtitle: miningRuleKeyText(version.dailyOutputKey),
        position: LoopRowPosition.middle,
      ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-weight-loop'),
        title: 'LOOP 权重',
        subtitle: miningRuleKeyText(version.weightRange.loop.descriptionKey),
        trailing: launchMissingFigure,
        trailingCaption: miningFormulaStatusLabel(
          version.weightRange.loop.status,
        ),
        position: LoopRowPosition.middle,
      ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-weight-community'),
        title: '社区币权重',
        subtitle: miningRuleKeyText(
          version.weightRange.community.descriptionKey,
        ),
        trailing: launchMissingFigure,
        trailingCaption: miningFormulaStatusLabel(
          version.weightRange.community.status,
        ),
        position: LoopRowPosition.middle,
      ),
      for (final guard in version.priceGuardRules)
        LoopRecordRow(
          key: ValueKey<String>('$keyPrefix-guard-${guard.ruleKey}'),
          title: '价格保护',
          subtitle: miningRuleKeyText(guard.ruleKey),
          trailingCaption: miningFormulaStatusLabel(guard.status),
          position: LoopRowPosition.middle,
        ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-referral-boost'),
        title: '邀请加成',
        subtitle: '加成只计入 Mining Power',
        trailingCaption: miningFormulaStatusLabel(version.referralBoostStatus),
        position: LoopRowPosition.last,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(key: ValueKey<String>('$keyPrefix-rows'), rows: rows),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            '${miningFormulaStatusLabel(version.status)}'
            '${version.approvedAt == null ? '' : ' · 批准于 ${launchTimestampLabel(version.approvedAt!)}'}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const LoopLabel('评审因子'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final factor in version.weightRange.reviewFactorKeys)
                Padding(
                  key: ValueKey<String>('$keyPrefix-factor-$factor'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '· ${miningRuleKeyText(factor)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
