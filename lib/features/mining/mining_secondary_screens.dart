import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/text/loop_power_text.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_widgets.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_controllers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// The capability gate copy shared by the five secondary mining pages.
/// The whole-page block a closed mining gate renders. It carries the reason
/// the server published instead of a sentence the client invented, and says so
/// plainly when the capability document was never read at all.
Widget _miningCapabilityBlock(
  String key,
  String subject,
  LoopCapabilityProjection capability,
) => LoopCapabilityPageBlock.of(
  key: ValueKey<String>(key),
  title: '$subject当前不可用',
  capability: capability,
);

/// Every symbol this page was given, by asset id. A proxied row names the
/// token its price came from, and that token is usually a row of its own: the
/// index lets the note use the registry's name instead of an address the
/// reader would have to match by eye.
Map<String, String> _assetSymbols(MiningAssets assets) => <String, String>{
  for (final row in assets.included)
    if (row.symbol != null) row.assetId: row.symbol!,
  for (final row in assets.excluded)
    if (row.symbol != null) row.assetId: row.symbol!,
};

/// `mining-community` · one community's mining panel.
class MiningCommunityScreen extends ConsumerStatefulWidget {
  const MiningCommunityScreen({
    super.key,
    this.communityId,
    this.onBack,
    this.onOpenRank,
  });

  final String? communityId;
  final VoidCallback? onBack;

  /// `#scr-mining-community .topbar .tool-btn`: the board this panel's place
  /// comes from.
  final VoidCallback? onOpenRank;

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
    final provider = miningCommunityControllerProvider(widget.communityId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open());
      });
    }
    final community = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-community-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: community?.community.name ?? '社区挖矿面板',
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('mining-community-rank-action'),
          icon: 'chart',
          label: '查看排行榜',
          onPressed: widget.onOpenRank,
        ),
      ],
      primary: LoopLedgerComposite(
        primary: _communityHero(community, state.phase),
        detail: <Widget>[
          MiningDetailRow(
            key: const ValueKey<String>('mining-community-reading'),
            label: '社区排名',
            value: switch (community?.rank) {
              MiningRankPositionSettled(:final position) => '第 $position 名',
              _ => launchMissingFigure,
            },
            spoken: switch (community?.rank) {
              MiningRankPositionSettled(:final position) => '第 $position 名',
              MiningRankPositionUnavailable(:final reasonCode) =>
                launchReasonCodeText(reasonCode),
              null => '还没有读到',
            },
            trailingLabel: '参与人数',
            trailingValue: switch (community?.participants) {
              MiningParticipantsCount(:final count) => '$count',
              _ => launchMissingFigure,
            },
          ),
        ],
      ),
      block: blocked
          ? _miningCapabilityBlock(
              'mining-community-capability-unavailable',
              '社区挖矿面板',
              capability,
            )
          : null,
      sections: <Widget>[
        if (community == null)
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
          MiningStaleNotice(slug: 'community', snapshot: community.snapshot),
          MiningSnapshotProvenanceLine(
            slug: 'community',
            snapshot: community.snapshot,
          ),
          const LoopLabel('我的贡献'),
          _MyContributionCard(community: community),
          const LoopLabel('社区记录'),
          _CommunityRecords(community: community),
          const LoopLabel('社区权重'),
          _WeightBlock(weight: community.weight),
          const LoopLabel(miningSnapshotSectionLabel),
          _CommunitySnapshotBlock(snapshot: community.snapshot),
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
            body:
                '权重按审核结果给出，评审因子公开、具体分值不公开。未通过审核的社区没有权重，也不会有算力。'
                '持有人须加入该社区，持仓才计入算力。',
            margin: EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
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
      // The version is bound under a neutral name: it is an identifier the
      // 详情 may hold, never a value a sentence names.
      MiningCommunityWeightApproved(
        :final value,
        :final reviewedAt,
        configVersion: final identifier,
      ) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
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
            LoopDisclosure(
              key: const ValueKey<String>('mining-community-weight-details'),
              summary: '详情',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  '已生效的公式版本 $identifier',
                  key: const ValueKey<String>(
                    'mining-community-weight-version',
                  ),
                  style: LoopType.captionSm,
                ),
              ),
            ),
          ],
        ),
      // A review that is happening and a review that will never happen are
      // different facts, and the block says which one this is.
      MiningCommunityWeightPending(
        :final reasonCode,
        reviewStatus: MiningWeightReviewStatus.pendingReview,
      ) =>
        LoopInlineUnavailable(
          key: const ValueKey<String>('mining-community-weight-pending'),
          icon: 'clock',
          message: '权重审核中',
          detail: launchReasonCodeText(reasonCode),
          maxLines: 2,
          detailMaxLines: 4,
        ),
      MiningCommunityWeightPending(:final reasonCode) => LoopInlineUnavailable(
        key: const ValueKey<String>('mining-community-weight-not-applicable'),
        message: '没有可审的权重',
        detail: launchReasonCodeText(reasonCode),
        maxLines: 2,
        detailMaxLines: 4,
      ),
    };
  }
}

/// The hero. A settled community power prints the server's own decimal; the
/// weight that produced it is already in the number.
///
/// When there is no decimal, the reason is the server's: the caption used to
/// name the formula as the thing being waited on, which was printed on the
/// skeleton frame of every cold start and stayed wrong after a formula version
/// took effect — a community with no bound asset has no power for a reason of
/// its own.
LoopFolioPrimary _communityHero(
  MiningCommunity? community,
  LaunchViewPhase phase,
) {
  final (String heading, String caption) = switch (community?.communityPower) {
    MiningFigureValue(:final value) => (
      loopPowerFigure(value),
      '成员在绑定资产上的算力之和，权重已经算在里面。',
    ),
    MiningFigureUnavailable(:final reasonCode) => (
      launchMissingHeading,
      launchReasonCodeText(reasonCode),
    ),
    null when phase == LaunchViewPhase.loading => ('正在读取', '社区总算力读到之后显示在这里。'),
    null => (launchMissingHeading, '这一页还没有读到这个社区的算力。'),
  };
  final reference = community?.community;
  return LoopFolioPrimary(
    variant: LoopFolioVariant.quiet,
    archetype: LoopFolioArchetype.record,
    kicker: '社区算力',
    heading: heading,
    caption: caption,
    // The heading is a figure and the page title is the community's name, so
    // until the face landed the panel showed nothing that told one community's
    // mining page from another's at a glance.
    trailing: reference == null
        ? null
        : CommunityLogo(
            key: const ValueKey<String>('mining-community-logo'),
            identity: reference.communityId,
            name: reference.name,
            size: 56,
            radius: LoopRadius.controlValue,
          ),
    // `.folio-stamp` is `0.35×` — the weight already inside the figure above,
    // printed only once the review granted one.
    stamp: switch (community?.weight) {
      MiningCommunityWeightApproved(:final value) => '$value×',
      _ => null,
    },
    ring: false,
    margin: EdgeInsets.zero,
    squareBottom: true,
  );
}

/// `MY CONTRIBUTION` — the prototype's one Chalk card in this module.
///
/// The App had no Chalk surface on any mining page, so the six pages read as
/// one unbroken dark run (visual audit §I.1). The two cells are the two facts
/// this reader owns here: the power their holding contributes, and the weight
/// that is already inside it. Neither is computed on the device.
class _MyContributionCard extends StatelessWidget {
  const _MyContributionCard({required this.community});

  final MiningCommunity community;

  @override
  Widget build(BuildContext context) {
    final (
      String contribution,
      String spokenContribution,
    ) = switch (community.myContribution) {
      MiningFigureValue(:final value) => (
        loopPowerFigure(value),
        loopPowerFigure(value),
      ),
      MiningFigureUnavailable(:final reasonCode) => (
        launchMissingFigure,
        launchReasonCodeText(reasonCode),
      ),
    };
    final (String weight, String spokenWeight) = switch (community.weight) {
      MiningCommunityWeightApproved(:final value) => ('$value×', '$value×'),
      MiningCommunityWeightPending(:final reasonCode) => (
        launchMissingFigure,
        launchReasonCodeText(reasonCode),
      ),
    };
    // S241b: the flat dark card instead of a Chalk slab on Ink.
    return LoopRecordCard(
      key: const ValueKey<String>('mining-community-contribution'),
      margin: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        0,
      ),
      child: Semantics(
        container: true,
        label: '我的算力，$spokenContribution。社区权重，$spokenWeight',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(child: _cell('我的算力', contribution)),
                  const SizedBox(width: 14),
                  Expanded(child: _cell('社区权重', weight)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Container(height: 1, color: LoopColors.line),
              ),
              Text(
                '权重由平台审核结果授予，已经算在上面的算力里。',
                style: LoopType.captionSm.copyWith(color: LoopColors.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _cell(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: LoopType.figureMd.copyWith(color: LoopColors.yellow),
      ),
      const SizedBox(height: 4),
      Text(label, style: LoopType.kicker.copyWith(color: LoopColors.text3)),
    ],
  );
}

/// `COMMUNITY RECORDS` — the two readings the panel is a record of.
class _CommunityRecords extends StatelessWidget {
  const _CommunityRecords({required this.community});

  final MiningCommunity community;

  @override
  Widget build(BuildContext context) {
    return LoopRecordGroup(
      key: const ValueKey<String>('mining-community-metrics'),
      rows: <LoopRecordRow>[
        LoopRecordRow(
          key: const ValueKey<String>('mining-community-metric-participants'),
          title: '参与挖矿的持有人',
          subtitle: switch (community.participants) {
            MiningParticipantsUnavailable(:final reasonCode) =>
              launchReasonCodeText(reasonCode),
            MiningParticipantsCount() => '最近一次算力快照里算出了算力的成员',
          },
          subtitleMaxLines: 2,
          trailing: switch (community.participants) {
            MiningParticipantsUnavailable() => launchMissingFigure,
            MiningParticipantsCount(:final count) => '$count',
          },
          position: LoopRowPosition.first,
        ),
        LoopRecordRow(
          key: const ValueKey<String>('mining-community-metric-power'),
          title: '社区总算力',
          // The folio heads this same figure and already carries its reason.
          subtitle: switch (community.communityPower) {
            MiningFigureUnavailable() => null,
            MiningFigureValue() => '成员在绑定资产上的算力之和',
          },
          subtitleMaxLines: 2,
          trailing: switch (community.communityPower) {
            MiningFigureUnavailable() => launchMissingFigure,
            MiningFigureValue(:final value) => loopPowerFigure(value),
          },
          position: LoopRowPosition.last,
        ),
      ],
    );
  }
}

/// Which settlement this panel read. The identifiers it carries are backend
/// strings, so only the block height and the time reach the row.
class _CommunitySnapshotBlock extends StatelessWidget {
  const _CommunitySnapshotBlock({required this.snapshot});

  final MiningSnapshotRef snapshot;

  @override
  Widget build(BuildContext context) {
    return switch (snapshot) {
      MiningSnapshotUnavailable(:final reasonCode, :final latestAttempt) =>
        LoopInlineUnavailable(
          key: const ValueKey<String>('mining-community-snapshot-unavailable'),
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
          key: const ValueKey<String>('mining-community-snapshot'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('mining-community-snapshot-row'),
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
    final approved = rules?.approved;
    // 算力明细 is the read that carries a symbol for each asset id, and the
    // rule keys are asset ids. Without it 「资产权重」 can only head its rows
    // with a contract address, so this page asks for it too; the read is
    // shared with 算力明细 and is skipped when it already has a value. A read
    // that does not answer leaves the rows saying the id, never a made-up
    // name.
    final assetsState = ref.watch(miningAssetsControllerProvider);
    if (!blocked && assetsState.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(ref.read(miningAssetsControllerProvider.notifier).load());
        }
      });
    }
    final assets = assetsState.value;
    final symbols = assets == null
        ? const <String, String>{}
        : _assetSymbols(assets);
    // Decision 0184: a version's daily budget is a LOOP amount, printed only
    // once the token is live.
    final live = watchMiningTokenLive(ref, enabled: !blocked);

    return LoopFlat(
      child: LoopDashboardPage(
        key: const ValueKey<String>('mining-rules-screen'),
        onRefresh: controller.reload,
        updating: state.refreshing,
        archetype: LoopPageArchetype.record,
        // The prototype's topbar says 挖矿规则 and its hero names the rule
        // (visual audit §I.7). Decision 0146: the asset track is weighted by
        // quantity, so the hero is 权重与算力规则, not 权重与价格保护.
        title: '挖矿规则',
        onBack: widget.onBack,
        primary: LoopLedgerComposite(
          primary: LoopFolioPrimary(
            variant: LoopFolioVariant.quiet,
            archetype: LoopFolioArchetype.record,
            kicker: '算力规则',
            // The hero used to announce a draft over a page whose first section
            // is 「已批准的版本」 with an 已批准 badge inside it, so one screen
            // said both that the rule was pending and that it was approved. The
            // sentence now follows whether a version has been approved, and the
            // big line shows the rule in force when there is one.
            heading: '权重与算力规则',
            caption: switch ((approved, draft)) {
              (null, null) => '还没有已批准的公式，也没有待批准的草案。',
              (null, _) => '还没有已批准的公式。下面这条是等待批准的草案。',
              (_, null) => '这一版已批准，当前生效；没有待批准的草案。',
              (_, _) => '这一版已批准，当前生效。下面另有等待批准的草案。',
            },
            stamp: switch ((approved, draft)) {
              (_?, _) => '已批准',
              (null, _?) => '待批准',
              (null, null) => null,
            },
            ring: false,
            margin: EdgeInsets.zero,
            squareBottom: true,
          ),
          detail: <Widget>[
            Text('每日产出', style: LoopType.eyebrow),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '每日产出 ',
                    style: LoopTypography.withWeight(
                      LoopType.captionSm.copyWith(color: LoopColors.chalk),
                      FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: switch (approved ?? draft) {
                      final MiningFormulaVersion version => miningRuleKeyText(
                        version.dailyOutputKey,
                      ),
                      null => launchMissingFigure,
                    },
                    style: LoopType.captionSm.copyWith(color: LoopColors.text2),
                  ),
                ],
              ),
              key: const ValueKey<String>('mining-rules-daily-output'),
            ),
          ],
        ),
        block: blocked
            ? _miningCapabilityBlock(
                'mining-rules-capability-unavailable',
                '挖矿规则',
                capability,
              )
            : null,
        sections: <Widget>[
          if (rules == null)
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
            // The version in force, said the way every other mining page says
            // it. Without one, the block keeps the server's own reason.
            switch (rules.baseline) {
              MiningFormulaEffective() => MiningFormulaBlock(
                formula: rules.baseline,
              ),
              MiningFormulaPending(:final reasonCode) => LaunchUnavailableCard(
                label: '已批准的公式版本',
                fact: LaunchUnavailable(reasonCode),
              ),
            },
            if (rules.approved != null)
              _FormulaVersionBlock(
                version: rules.approved!,
                keyPrefix: 'mining-rules-approved',
                symbols: symbols,
                live: live,
              ),
            if (rules.approved?.scope.isBaseline ?? false)
              // Decision 0121: what a baseline means is in the ⓘ, not a
              // banner.
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: LoopProvenanceLine(
                  key: ValueKey<String>('mining-rules-baseline-notice'),
                  prefix: miningBaselineLabel,
                  sources: <String>['LOOP 挖矿规则'],
                  detail: miningBaselineDetail,
                ),
              ),
            const LoopLabel('待批准的版本'),
            if (rules.pendingApproval.isEmpty)
              const LoopEmptyState(
                key: ValueKey<String>('mining-rules-no-pending'),
                illustration: LoopIllustration.history,
                title: '没有待批准的版本',
                message: '目前没有草案版本。',
                compact: true,
              )
            else
              for (final version in rules.pendingApproval)
                _FormulaVersionBlock(
                  version: version,
                  keyPrefix: 'mining-rules-pending-${version.configVersion}',
                  symbols: symbols,
                  live: live,
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
            // Only while nothing is in force. Once a version is approved the
            // page above it prints a pinned range and a budget, and this
            // sentence would be the same screen calling those numbers absent.
            // What the approved version is, the baseline notice already says.
            if (rules.approved == null)
              const LoopNotice(
                key: ValueKey<String>('mining-rules-notice'),
                icon: 'shield',
                title: '草案不是生效规则',
                body: '待批准的版本不会参与任何计算。权重区间只有规则条目，没有数值；批准之后才会公布。',
                margin: EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  14,
                  LoopSpacing.page,
                  0,
                ),
              ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _FormulaVersionBlock extends StatelessWidget {
  const _FormulaVersionBlock({
    required this.version,
    required this.keyPrefix,
    required this.live,
    this.symbols = const <String, String>{},
  });

  /// [miningTokenLive]: the daily budget, a LOOP amount, is printed only then
  /// (decision 0184).
  final bool live;

  final MiningFormulaVersion version;
  final String keyPrefix;

  /// Registry symbols by asset id, when 算力明细 has already been read.
  ///
  /// 「资产权重」 headed three of its four rows with a contract address
  /// (`0x0e09…ce82`) and repeated the whole CAIP id underneath. The rule keys
  /// are asset ids, and the same ids carry a symbol on the 算力明细 read, so
  /// the row is headed by the symbol whenever that read has happened. Without
  /// it the row still says the id rather than inventing a name.
  final Map<String, String> symbols;

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
        // The expression itself is the composite strip's, stated once at the
        // top of the page; this row carries the budget the version pins.
        // The budget is published with its own status, so it is printed with
        // it: a placeholder number never stands on the page by itself. The
        // separators are display only and are dropped whenever they cannot be
        // added without changing what the server said.
        trailing: version.dailyOutput == null || !live
            ? null
            : loopGroupedFigure(version.dailyOutput!.budget),
        trailingCaption: version.dailyOutput == null
            ? null
            : !live
            ? 'LOOP 代币上线后公布'
            : (version.dailyOutput!.isPlaceholder ? '预估产量' : '当日产量'),
        position: LoopRowPosition.middle,
      ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-referral-boost'),
        title: '邀请加成',
        subtitle: '邀请加成只计入算力',
        trailingCaption: miningFormulaStatusLabel(version.referralBoostStatus),
        position: LoopRowPosition.last,
      ),
    ];
    // `WEIGHT RANGE`: the prototype heads each band with its own tile, so the
    // two bands are told apart before they are read (visual audit §I.7).
    final weightRows = <LoopRecordRow>[
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-weight-loop'),
        leading: const LoopRowIcon(
          monogram: 'LOOP',
          tone: LoopRowIconTone.accent,
        ),
        title: 'LOOP',
        subtitle: miningRuleKeyText(version.weightRange.loop.descriptionKey),
        subtitleMaxLines: 2,
        trailing: launchMissingFigure,
        trailingCaption: miningFormulaStatusLabel(
          version.weightRange.loop.status,
        ),
        position: LoopRowPosition.first,
      ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-weight-community'),
        leading: const LoopRowIcon(monogram: 'COMM'),
        title: '经审核的社区币',
        subtitle: miningRuleKeyText(
          version.weightRange.community.descriptionKey,
        ),
        subtitleMaxLines: 2,
        // The bounds print only once the version pinned them; until then the
        // band is a rule with no numbers and keeps the em dash.
        trailing: switch (version.weightRange.community.range) {
          null => launchMissingFigure,
          MiningWeightBounds(:final min, :final max) => '$min–$max',
        },
        trailingCaption: miningFormulaStatusLabel(
          version.weightRange.community.status,
        ),
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
            <String>[
              miningFormulaStatusLabel(version.status),
              // The scope the version declares about itself, wherever the
              // version is printed.
              if (version.scope.isBaseline) miningBaselineLabel,
              if (version.approvedAt != null)
                '批准于 ${launchTimestampLabel(version.approvedAt!)}',
            ].join(' · '),
            key: ValueKey<String>('$keyPrefix-status'),
            style: LoopType.captionSm,
          ),
        ),
        if (version.assetWeights.isNotEmpty) ...<Widget>[
          const LoopLabel('资产权重'),
          LoopRecordGroup(
            key: ValueKey<String>('$keyPrefix-asset-weights'),
            rows: <LoopRecordRow>[
              for (
                var index = 0;
                index < version.assetWeights.length;
                index += 1
              )
                LoopRecordRow(
                  key: ValueKey<String>(
                    '$keyPrefix-asset-weight-'
                    '${version.assetWeights.keys.elementAt(index)}',
                  ),
                  title: miningAssetTitle(
                    symbol: symbols[version.assetWeights.keys.elementAt(index)],
                    assetId: version.assetWeights.keys.elementAt(index),
                  ),
                  subtitle: version.assetWeights.keys.elementAt(index),
                  trailing: version.assetWeights.values.elementAt(index),
                  position: launchRowPosition(
                    index,
                    version.assetWeights.length,
                  ),
                ),
            ],
          ),
        ],
        const LoopLabel('Weight Range'),
        LoopRecordGroup(
          key: ValueKey<String>('$keyPrefix-weight-range'),
          rows: weightRows,
        ),
        const LoopLabel('Review Factors'),
        LoopRecordCard(
          key: ValueKey<String>('$keyPrefix-review-factors'),
          margin: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final factor in version.weightRange.reviewFactorKeys)
                Padding(
                  key: ValueKey<String>('$keyPrefix-factor-$factor'),
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    miningRuleKeyText(factor),
                    style: LoopType.captionSm.copyWith(color: LoopColors.chalk),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Container(height: 1, color: LoopColors.line),
              ),
              Text(
                '具体量化分值不公开，权重以平台综合评定结果为准。',
                style: LoopType.captionSm.copyWith(color: LoopColors.text3),
              ),
            ],
          ),
        ),
        // Decision 0147 (loop-api 0125): power no longer multiplies a
        // reference price, so `priceGuardRules` — still published, marked
        // deprecated — is parsed and not shown as part of the formula.
      ],
    );
  }
}
