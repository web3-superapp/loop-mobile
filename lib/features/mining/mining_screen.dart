import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_widgets.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_controllers.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `mining` · the Mining destination.
///
/// The mining formula is backend delivery D19 and no version is approved yet,
/// so every figure on this page is the em dash plus the server's own reason,
/// and the hero says the absence in words rather than printing a 29px dash.
/// The client never estimates power, output, accumulation or a claim.
///
/// Its shape is the prototype's composite dashboard: one Lime card carrying
/// the rank, the power, three metrics and the two next steps, then the
/// composition that produced the power. The page used to spread the same
/// facts over five stacked key-value blocks and a menu of four links, which
/// put 领取奖励 three screens below the fold (visual audit 2026-09-21 §I.2).
class MiningScreen extends ConsumerStatefulWidget {
  const MiningScreen({
    super.key,
    this.onOpenAssets,
    this.onOpenRewards,
    this.onOpenRank,
    this.onOpenRules,
    this.onOpenReferral,
    this.onOpenMarket,
    this.onBack,
  });

  /// Set when 挖矿 is opened as a page (from 我) rather than as a tab.
  final VoidCallback? onBack;

  final VoidCallback? onOpenAssets;
  final VoidCallback? onOpenRewards;
  final VoidCallback? onOpenRank;
  final VoidCallback? onOpenRules;
  final VoidCallback? onOpenReferral;

  /// 行情, where the weighted community tokens are discovered.
  final VoidCallback? onOpenMarket;

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

    // The composition that produced the figure in the hero, and the place on
    // the board it earned. Both are reads this module already makes for its
    // own pages — 算力明细 and 算力排行榜 — and the two pages share the
    // provider, so opening either one from here costs no second request.
    final assetsState = ref.watch(miningAssetsControllerProvider);
    if (!blocked && assetsState.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(miningAssetsControllerProvider.notifier).load());
        }
      });
    }
    final rankState = ref.watch(miningRankControllerProvider);
    if (!blocked && rankState.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(miningRankControllerProvider.notifier).load());
        }
      });
    }

    // Decision 0184: whether the LOOP token is live is the rewards resource's
    // to say (`hourly.claim`, the claim contract). It is the same provider
    // 挖矿奖励 reads, so opening that page from here costs no second request.
    // Until it answers — and whenever it does not say — the page counts
    // power only.
    final rewardsState = ref.watch(miningRewardsViewControllerProvider);
    if (!blocked && rewardsState.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(miningRewardsViewControllerProvider.notifier).load(),
          );
        }
      });
    }
    final rewards = rewardsState.value;
    final live = miningTokenLive(rewards);

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '我的挖矿',
      onBack: widget.onBack,
      tabPage: widget.onBack == null,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('mining-rules-action'),
          icon: 'info',
          label: '挖矿规则',
          onPressed: widget.onOpenRules,
        ),
      ],
      primary: summary == null
          ? _hero(summary, state.phase)
          : MiningSummaryHero(
              heading: _heroHeading(summary),
              unit: _heroUnit(summary),
              caption: _heroCaption(summary, live: live),
              stamp: _heroStamp(summary),
              rank: _rankBadge(rankState.value),
              metrics: live
                  ? <MiningHeroMetric>[
                      _dailyMetric(summary.estimatedToday),
                      MiningHeroMetric(
                        slug: 'accumulated',
                        label: '累计已挖',
                        value: launchMissingFigure,
                        spoken: launchReasonCodeText(
                          summary.accumulated.reasonCode,
                        ),
                      ),
                      MiningHeroMetric(
                        slug: 'claimable',
                        label: '待领取',
                        value: launchMissingFigure,
                        spoken: launchReasonCodeText(
                          summary.claimable.reasonCode,
                        ),
                      ),
                    ]
                  : _powerMetrics(summary, rewards),
              // The claim itself lives on 奖励与领取, which states whether it
              // can be executed; this button is how the reader gets there.
              onClaim: widget.onOpenRewards,
              claimSemanticLabel: '领取奖励，打开奖励与领取',
              onOpenAssets: widget.onOpenAssets,
              powerOnly: !live,
            ),
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
          // Directly under the hero: the snapshot the figures came from, with
          // the demonstration-holdings note in its sheet (decision 0121).
          MiningSnapshotProvenanceLine(
            slug: 'summary',
            snapshot: summary.snapshot,
            formula: summary.formula,
          ),
          MiningDashReasons(
            slug: 'mining-hero',
            // The hero caption already speaks for every dash the pending
            // version accounts for — in the caption's own words — so neither
            // its sentence nor the gate's own is written again underneath it.
            said: <String>{
              _heroCaption(summary, live: live),
              if (summary.formula case MiningFormulaPending(:final reasonCode))
                launchReasonCodeText(reasonCode),
            },
            entries: live
                ? <(String, String)>[
                    if (summary.estimatedToday
                        case MiningDailyOutputUnavailable(:final reasonCode))
                      ('今日预估', launchReasonCodeText(reasonCode)),
                    (
                      '累计已挖',
                      launchReasonCodeText(summary.accumulated.reasonCode),
                    ),
                    ('待领取', launchReasonCodeText(summary.claimable.reasonCode)),
                  ]
                : <(String, String)>[
                    if (summary.networkPower case MiningFigureUnavailable(
                      :final reasonCode,
                    ))
                      ('全网算力', launchReasonCodeText(reasonCode)),
                  ],
          ),
          // The numbers above are the last complete snapshot's whenever a
          // later run did not finish, so the page dates them before it
          // prints them.
          MiningStaleNotice(slug: 'summary', snapshot: summary.snapshot),
          const LoopLabel('Power Composition'),
          _CompositionBlock(
            assets: assetsState.value,
            phase: assetsState.phase,
            failureKind: assetsState.failureKind,
          ),
          LoopNotice(
            key: const ValueKey<String>('mining-holding-notice'),
            icon: 'mine',
            tone: LoopNoticeTone.warn,
            title: '持有即算力',
            body: switch (summary.networkPower) {
              MiningFigureValue(:final value) =>
                '按钱包持仓自动计算，不需要质押或授权。全网总算力 '
                    '${loopGroupedFigure(value)}。',
              MiningFigureUnavailable(:final reasonCode) =>
                '按钱包持仓自动计算，不需要质押或授权。全网总算力 '
                    '$launchMissingFigure：${launchReasonCodeText(reasonCode)}',
            },
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: LoopRecordCard(
              onTap: widget.onOpenReferral,
              child: _ReferralCard(boost: summary.referralBoost),
            ),
          ),
          const LoopLabel('Increase Power'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('mining-open-market'),
                leading: const LoopRowIcon(icon: 'search'),
                title: '发现有权重的社区币',
                subtitle: '社区币权重由服务端审核结果授予',
                onTap: widget.onOpenMarket,
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('mining-open-rank'),
                leading: const LoopRowIcon(icon: 'chart'),
                title: '查看算力排行榜',
                subtitle: _rankSubtitle(rankState.value),
                onTap: widget.onOpenRank,
                position: LoopRowPosition.last,
              ),
            ],
          ),
          const LoopLabel('公式版本'),
          MiningFormulaBlock(formula: summary.formula),
          const LoopLabel(miningSnapshotSectionLabel),
          _SnapshotBlock(snapshot: summary.snapshot),
          LoopNotice(
            key: const ValueKey<String>('mining-truth-notice'),
            icon: 'shield',
            title: '不做本地估算',
            body: switch (summary.formula) {
              MiningFormulaPending() =>
                '挖矿公式还没有批准的版本。'
                    'LOOP 不会在这台设备上累计积分或估算收益。读不到不等于「算力为零」。',
              MiningFormulaEffective() =>
                'LOOP 不会在这台设备上累计积分或估算收益，页面上的数字都来自最近一次算力快照。',
            },
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// The hero heading: the power itself, or the words for its absence.
String _heroHeading(MiningSummary summary) => switch (summary.formula) {
  MiningFormulaPending() => launchMissingHeading,
  MiningFormulaEffective() => switch (summary.power) {
    MiningFigureValue(:final value) => loopGroupedFigure(value),
    MiningFigureUnavailable() => launchMissingHeading,
  },
};

/// `.mining-power-value small` — the unit only a settled figure carries.
String? _heroUnit(MiningSummary summary) =>
    _heroHeading(summary) == launchMissingHeading ? null : 'H';

String _heroCaption(MiningSummary summary, {required bool live}) =>
    switch (summary.formula) {
      MiningFormulaPending() =>
        live ? '算力、今日预估、累计与待领取都要等挖矿公式版本被批准后才能计算。' : '算力要等挖矿公式版本被批准后才能计算。',
      MiningFormulaEffective() => switch (summary.power) {
        MiningFigureUnavailable(:final reasonCode) => launchReasonCodeText(
          reasonCode,
        ),
        MiningFigureValue() => '持仓与社区币权重共同构成当前算力，不是收益承诺。',
      },
    };

String? _heroStamp(MiningSummary summary) => switch (summary.formula) {
  MiningFormulaPending(:final pendingVersion) =>
    pendingVersion != null ? '待批准' : null,
  MiningFormulaEffective(:final scope) =>
    scope.isBaseline ? miningBaselineLabel : null,
};

/// The three cells while the LOOP token is not live (decision 0184): the
/// network's power, the account's last settled hour and its counted
/// invites. None of them is a LOOP amount.
List<MiningHeroMetric> _powerMetrics(
  MiningSummary summary,
  MiningRewardsView? rewards,
) {
  final hour = miningLastHourPower(rewards);
  final invites = rewards?.invites?.total.activeMembers;
  return <MiningHeroMetric>[
    switch (summary.networkPower) {
      MiningFigureValue(:final value) => MiningHeroMetric(
        slug: 'network-power',
        label: '全网算力',
        value: loopGroupedFigure(value),
        spoken: loopGroupedFigure(value),
      ),
      MiningFigureUnavailable(:final reasonCode) => MiningHeroMetric(
        slug: 'network-power',
        label: '全网算力',
        value: launchMissingFigure,
        spoken: launchReasonCodeText(reasonCode),
      ),
    },
    MiningHeroMetric(
      slug: 'last-hour-power',
      label: '上一小时算力',
      value: hour == null ? launchMissingFigure : miningPowerFigure(hour),
      spoken: hour == null ? '还没有结算的小时' : miningPowerFigure(hour),
    ),
    MiningHeroMetric(
      slug: 'active-invites',
      label: '有效邀请',
      value: invites == null ? launchMissingFigure : '$invites 人',
      spoken: invites == null ? '还没有读到' : '$invites 人',
    ),
  ];
}

MiningHeroMetric _dailyMetric(MiningDailyOutput output) => switch (output) {
  MiningDailyOutputEstimate(:final value) => MiningHeroMetric(
    slug: 'estimated-today',
    label: '今日预估',
    value: loopGroupedFigure(value),
    spoken: loopGroupedFigure(value),
  ),
  MiningDailyOutputUnavailable(:final reasonCode) => MiningHeroMetric(
    slug: 'estimated-today',
    label: '今日预估',
    value: launchMissingFigure,
    spoken: launchReasonCodeText(reasonCode),
  ),
};

/// `RANK #1,284`. It prints only a place the server settled; a board this
/// reader is not on, and a board that did not load, both leave it out.
String? _rankBadge(MiningRank? rank) => switch (rank?.myPosition) {
  MiningRankPositionSettled(:final position) => '#$position',
  _ => null,
};

String _rankSubtitle(MiningRank? rank) => switch (rank?.myPosition) {
  MiningRankPositionSettled(:final position) => '我的名次 第 $position 名',
  _ => '用户榜与社区榜',
};

/// The hero, before anything was read. A read that has not landed says only
/// that it is reading, and the reason a read failed stays with the state block
/// that owns it.
LoopFolioPrimary _hero(MiningSummary? summary, LaunchViewPhase phase) {
  final loading = phase == LaunchViewPhase.loading;
  return LoopFolioPrimary(
    ring: false,
    variant: LoopFolioVariant.quiet,
    archetype: LoopFolioArchetype.record,
    kicker: '挖矿算力',
    heading: loading ? '正在读取' : launchMissingHeading,
    caption: loading ? '算力与产出读到之后显示在这里。' : '这一页还没有读到算力数据。',
  );
}

/// `Power Composition` — one row per weighted asset, each carrying the
/// multiplication that produced its power.
///
/// This is the module's central expression and the App had none of it: the
/// three inputs were a key-value table on a second page. Nothing is computed
/// here — the holding, the reference price, the weight and the power are four
/// figures the server settled, printed side by side in the order it multiplies
/// them.
class _CompositionBlock extends ConsumerWidget {
  const _CompositionBlock({
    required this.assets,
    required this.phase,
    required this.failureKind,
  });

  final MiningAssets? assets;
  final LaunchViewPhase phase;
  final LaunchFailureKind? failureKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = assets;
    if (value == null) {
      return LaunchStateBlock(
        prefix: 'mining-composition',
        phase: phase,
        failureKind: failureKind,
        rows: 2,
        emptyMessage: '没有读到算力构成',
        emptyReason: '每个资产的持有量与权重读到之后显示在这里。',
        onRetry: () => unawaited(
          ref.read(miningAssetsControllerProvider.notifier).reload(),
        ),
      );
    }
    if (value.included.isEmpty) {
      return LoopEmptyState(
        key: const ValueKey<String>('mining-composition-empty'),
        illustration: LoopIllustration.holders,
        title: value.isUnsettled ? '还没有算过这些资产' : '这次快照没有计入任何资产',
        message: value.isUnsettled
            ? '下一次算力快照之后，每个资产的算式会显示在这里。'
            : '你的持仓里没有可以计入的资产。',
        compact: true,
      );
    }
    return LoopRecordGroup(
      key: const ValueKey<String>('mining-composition'),
      rows: <LoopRecordRow>[
        for (var index = 0; index < value.included.length; index += 1)
          miningCompositionRow(
            value.included[index],
            launchRowPosition(index, value.included.length),
          ),
      ],
    );
  }
}

/// `REFERRAL POWER` — the relationship boost, as its own card.
class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.boost});

  final LaunchUnavailable boost;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '邀请加成，${launchReasonCodeText(boost.reasonCode)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('邀请加成', style: LoopType.eyebrow),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('五级邀请加成', style: LoopType.headingSm),
                      const SizedBox(height: 6),
                      Text(
                        // Decision 0149: the boost is never read on this
                        // page, so it says where it is instead of printing a
                        // dash before a full stop (「当前加成 —。」).
                        '一级至五级关系按服务端公布的比例增加算力，'
                        '你的邀请加成在邀请中心查看。',
                        style: LoopType.captionSm.copyWith(
                          color: LoopColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const LoopIcon('chevron', size: 21, color: LoopColors.text3),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotBlock extends StatelessWidget {
  const _SnapshotBlock({required this.snapshot});

  final MiningSnapshotRef snapshot;

  @override
  Widget build(BuildContext context) {
    return switch (snapshot) {
      MiningSnapshotUnavailable(:final reasonCode, :final latestAttempt) =>
        LoopInlineUnavailable(
          key: const ValueKey<String>('mining-snapshot-unavailable'),
          icon: 'clock',
          message: miningSnapshotAbsenceMessage(reasonCode),
          detail: miningSnapshotAbsenceReason(
            reasonCode,
            attempt: latestAttempt,
          ),
          maxLines: 2,
          detailMaxLines: 4,
        ),
      MiningSnapshotComputed(:final blockNumber, :final computedAt) =>
        LoopRecordGroup(
          key: const ValueKey<String>('mining-snapshot'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('mining-snapshot-row'),
              title: miningSnapshotRowTitle,
              subtitle:
                  '区块 ${loopGroupedFigure(blockNumber)} · '
                  '${launchTimestampLabel(computedAt)} · '
                  '这是算出算力的时间',
              subtitleMaxLines: 2,
            ),
          ],
        ),
    };
  }
}
