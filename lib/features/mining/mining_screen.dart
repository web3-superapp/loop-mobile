import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
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
  });

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

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '我的挖矿',
      tabPage: true,
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
              caption: _heroCaption(summary),
              stamp: _heroStamp(summary),
              rank: _rankBadge(rankState.value),
              metrics: <MiningHeroMetric>[
                _dailyMetric(summary.estimatedToday),
                MiningHeroMetric(
                  slug: 'accumulated',
                  label: '累计已挖',
                  value: launchMissingFigure,
                  spoken: launchReasonCodeText(summary.accumulated.reasonCode),
                ),
                MiningHeroMetric(
                  slug: 'claimable',
                  label: '待领取',
                  value: launchMissingFigure,
                  spoken: launchReasonCodeText(summary.claimable.reasonCode),
                ),
              ],
              // The claim itself lives on 奖励与领取, which states whether it
              // can be executed; this button is how the reader gets there.
              onClaim: widget.onOpenRewards,
              claimSemanticLabel: '领取奖励，打开奖励与领取',
              onOpenAssets: widget.onOpenAssets,
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
          // Directly under the hero: the figures it just printed are what the
          // demonstration holdings changed.
          MiningDemoHoldingsNotice(slug: 'summary', snapshot: summary.snapshot),
          MiningDashReasons(
            slug: 'mining-hero',
            // The hero caption already speaks for every dash the pending
            // version accounts for — in the caption's own words — so neither
            // its sentence nor the gate's own is written again underneath it.
            said: <String>{
              _heroCaption(summary),
              if (summary.formula case MiningFormulaPending(:final reasonCode))
                launchReasonCodeText(reasonCode),
            },
            entries: <(String, String)>[
              if (summary.estimatedToday case MiningDailyOutputUnavailable(
                :final reasonCode,
              ))
                ('今日预估', launchReasonCodeText(reasonCode)),
              ('累计已挖', launchReasonCodeText(summary.accumulated.reasonCode)),
              ('待领取', launchReasonCodeText(summary.claimable.reasonCode)),
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
                subtitle: '社区币的权重由服务端审核结果授予',
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
              MiningFormulaEffective(:final scope) when scope.isBaseline =>
                '当前生效的是开发基线，算出来的数字只用于开发验证，'
                    '不是收益，也不构成承诺。LOOP 不会在这台设备上累计积分。',
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

String _heroCaption(MiningSummary summary) => switch (summary.formula) {
  MiningFormulaPending() => '算力、今日预估、累计与待领取都要等挖矿公式版本被批准后才能计算。',
  MiningFormulaEffective(:final scope) => switch (summary.power) {
    MiningFigureUnavailable(:final reasonCode) => launchReasonCodeText(
      reasonCode,
    ),
    MiningFigureValue() when scope.isBaseline => '这些数字来自开发基线，只用于开发验证，不是收益。',
    MiningFigureValue() => '持仓与社区权重共同构成当前算力，不是收益承诺。',
  },
};

String? _heroStamp(MiningSummary summary) => switch (summary.formula) {
  MiningFormulaPending(:final pendingVersion) =>
    pendingVersion != null ? '待批准' : null,
  MiningFormulaEffective(:final scope) =>
    scope.isBaseline ? miningBaselineLabel : null,
};

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
    variant: LoopFolioVariant.quiet,
    archetype: LoopFolioArchetype.record,
    kicker: 'MINING POWER',
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
        emptyReason: '每个资产的持有量、参考价与权重读到之后显示在这里。',
        onRetry: () => unawaited(
          ref.read(miningAssetsControllerProvider.notifier).reload(),
        ),
      );
    }
    if (value.included.isEmpty) {
      return LoopEmpty(
        key: const ValueKey<String>('mining-composition-empty'),
        icon: 'info',
        message: value.isUnsettled ? '还没有算过这些资产' : '这次快照没有计入任何资产',
        reason: value.isUnsettled
            ? '下一次算力快照之后，每个资产的算式会显示在这里。'
            : '你的持仓里没有可以计入的资产。',
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
      label: '邀请关系加成，${launchReasonCodeText(boost.reasonCode)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('REFERRAL POWER', style: LoopMono.label),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '邀请关系加成',
                        style: LoopTypography.display(
                          21,
                          color: LoopColors.chalk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '一级至五级关系按服务端公布的比例增加算力，'
                        '当前加成 $launchMissingFigure。',
                        style: LoopTypography.caption(
                          11,
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
        LoopEmpty(
          key: const ValueKey<String>('mining-snapshot-unavailable'),
          icon: 'clock',
          message: miningSnapshotAbsenceMessage(reasonCode),
          reason: miningSnapshotAbsenceReason(
            reasonCode,
            attempt: latestAttempt,
          ),
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
