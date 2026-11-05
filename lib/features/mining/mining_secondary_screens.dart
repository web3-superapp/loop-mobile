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
import 'package:loop_mobile/l10n/loop_l10n.dart';
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
  title: LoopL10n.current.mining_secondaryScreensTitle(subject),
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
      title:
          community?.community.name ??
          context.l10n.mining_secondaryScreensMiningCommunityScreenTitle,
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('mining-community-rank-action'),
          icon: 'chart',
          label: context
              .l10n
              .mining_secondaryScreensMiningCommunityRankActionLabel,
          onPressed: widget.onOpenRank,
        ),
      ],
      primary: LoopLedgerComposite(
        primary: _communityHero(community, state.phase),
        detail: <Widget>[
          MiningDetailRow(
            key: const ValueKey<String>('mining-community-reading'),
            label:
                context.l10n.mining_secondaryScreensMiningCommunityReadingLabel,
            value: switch (community?.rank) {
              MiningRankPositionSettled(:final position) =>
                context.l10n.intel_rankBoardText4(position),
              _ => launchMissingFigure,
            },
            spoken: switch (community?.rank) {
              MiningRankPositionSettled(:final position) =>
                context.l10n.intel_rankBoardText4(position),
              MiningRankPositionUnavailable(:final reasonCode) =>
                launchReasonCodeText(reasonCode),
              null => context.l10n.mining_screenSpoken,
            },
            trailingLabel: context
                .l10n
                .mining_secondaryScreensMiningCommunityReadingTrailingLabel,
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
              context.l10n.mining_secondaryScreensMiningCommunityScreenTitle,
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
            emptyMessage: context.l10n.mining_secondaryScreensEmptyMessage,
            emptyReason: context.l10n.mining_secondaryScreensEmptyReason,
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          MiningStaleNotice(slug: 'community', snapshot: community.snapshot),
          MiningSnapshotProvenanceLine(
            slug: 'community',
            snapshot: community.snapshot,
          ),
          LoopLabel(context.l10n.mining_secondaryScreensLoopLabel),
          _MyContributionCard(community: community),
          LoopLabel(context.l10n.mining_secondaryScreensLoopLabel2),
          _CommunityRecords(community: community),
          LoopLabel(context.l10n.mining_secondaryScreensLoopLabel3),
          _WeightBlock(weight: community.weight),
          LoopLabel(miningSnapshotSectionLabel),
          _CommunitySnapshotBlock(snapshot: community.snapshot),
          LoopLabel(context.l10n.mining_secondaryScreensLoopLabel4),
          LoopRecordGroup(
            key: const ValueKey<String>('mining-community-asset'),
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('mining-community-asset-row'),
                title: context.l10n.mining_secondaryScreensLoopLabel4,
                subtitle: community.community.boundAssetId == null
                    ? context
                          .l10n
                          .mining_secondaryScreensMiningCommunityAssetRowSubtitle
                    : community.community.boundAssetId!,
                trailing: community.community.boundAssetId == null
                    ? launchMissingFigure
                    : context
                          .l10n
                          .mining_secondaryScreensMiningCommunityAssetRowTrailing,
              ),
            ],
          ),
          LoopNotice(
            key: ValueKey<String>('mining-community-notice'),
            icon: 'shield',
            title:
                context.l10n.mining_secondaryScreensMiningCommunityNoticeTitle,
            body: context.l10n.mining_secondaryScreensMiningCommunityNoticeBody,
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
                  title: context
                      .l10n
                      .mining_secondaryScreensMiningCommunityWeightRowTitle,
                  subtitle: context.l10n
                      .mining_secondaryScreensMiningCommunityWeightRowSubtitle(
                        launchTimestampLabel(reviewedAt),
                      ),
                  trailing: value,
                ),
              ],
            ),
            LoopDisclosure(
              key: const ValueKey<String>('mining-community-weight-details'),
              summary: context.l10n.common_details,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  context.l10n
                      .mining_secondaryScreensMiningCommunityWeightVersion(
                        identifier,
                      ),
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
          message: context
              .l10n
              .mining_secondaryScreensMiningCommunityWeightPendingMessage,
          detail: launchReasonCodeText(reasonCode),
          maxLines: 2,
          detailMaxLines: 4,
        ),
      MiningCommunityWeightPending(:final reasonCode) => LoopInlineUnavailable(
        key: const ValueKey<String>('mining-community-weight-not-applicable'),
        message: context
            .l10n
            .mining_secondaryScreensMiningCommunityWeightNotApplicableMessage,
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
      LoopL10n.current.mining_secondaryScreensSwitch,
    ),
    MiningFigureUnavailable(:final reasonCode) => (
      launchMissingHeading,
      launchReasonCodeText(reasonCode),
    ),
    null when phase == LaunchViewPhase.loading => (
      LoopL10n.current.mining_screenHeading,
      LoopL10n.current.mining_secondaryScreensSwitch2,
    ),
    null => (
      launchMissingHeading,
      LoopL10n.current.mining_secondaryScreensSwitch3,
    ),
  };
  final reference = community?.community;
  return LoopFolioPrimary(
    variant: LoopFolioVariant.quiet,
    archetype: LoopFolioArchetype.record,
    kicker: LoopL10n.current.mining_secondaryScreensMiningCommunityLogoKicker,
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
        label: context.l10n.mining_secondaryScreensLabel(
          spokenContribution,
          spokenWeight,
        ),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _cell(
                      context.l10n.mining_secondaryScreensCell,
                      contribution,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _cell(
                      context.l10n.mining_secondaryScreensLoopLabel3,
                      weight,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Container(height: 1, color: LoopColors.line),
              ),
              Text(
                context.l10n.mining_secondaryScreensSwitch4,
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
          title: context
              .l10n
              .mining_secondaryScreensMiningCommunityMetricParticipantsTitle,
          subtitle: switch (community.participants) {
            MiningParticipantsUnavailable(:final reasonCode) =>
              launchReasonCodeText(reasonCode),
            MiningParticipantsCount() =>
              context.l10n.mining_secondaryScreensMiningParticipantsCount,
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
          title: context
              .l10n
              .mining_secondaryScreensMiningCommunityMetricPowerTitle,
          // The folio heads this same figure and already carries its reason.
          subtitle: switch (community.communityPower) {
            MiningFigureUnavailable() => null,
            MiningFigureValue() =>
              context.l10n.mining_secondaryScreensMiningFigureValue,
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
              subtitle: context.l10n.mining_screenMiningSnapshotComputed(
                loopGroupedFigure(blockNumber),
                launchTimestampLabel(computedAt),
              ),
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
        title: context.l10n.mining_secondaryScreensMiningRulesScreenTitle,
        onBack: widget.onBack,
        primary: LoopLedgerComposite(
          primary: LoopFolioPrimary(
            variant: LoopFolioVariant.quiet,
            archetype: LoopFolioArchetype.record,
            kicker: context.l10n.mining_secondaryScreensKicker,
            // The hero used to announce a draft over a page whose first section
            // is 「已批准的版本」 with an 已批准 badge inside it, so one screen
            // said both that the rule was pending and that it was approved. The
            // sentence now follows whether a version has been approved, and the
            // big line shows the rule in force when there is one.
            heading: context.l10n.mining_secondaryScreensHeading,
            caption: switch ((approved, draft)) {
              (null, null) =>
                context.l10n.mining_secondaryScreensLoopFolioPrimary,
              (null, _) =>
                context.l10n.mining_secondaryScreensLoopFolioPrimary2,
              (_, null) =>
                context.l10n.mining_secondaryScreensLoopFolioPrimary3,
              (_, _) => context.l10n.mining_secondaryScreensLoopFolioPrimary4,
            },
            stamp: switch ((approved, draft)) {
              (_?, _) => context.l10n.mining_modelsApproved,
              (null, _?) => context.l10n.mining_modelsPendingApproval,
              (null, null) => null,
            },
            // S353b: 「Pending approval」 holds one line in English.
            stampWidthFactor: 0.5,
            ring: false,
            margin: EdgeInsets.zero,
            squareBottom: true,
          ),
          detail: <Widget>[
            Text(
              context.l10n.mining_secondaryScreensIf,
              style: LoopType.eyebrow,
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: context.l10n.mining_secondaryScreensText,
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
                context.l10n.mining_secondaryScreensMiningRulesScreenTitle,
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
              emptyMessage: context.l10n.mining_secondaryScreensEmptyMessage2,
              emptyReason: context.l10n.mining_secondaryScreensEmptyReason2,
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            LoopLabel(context.l10n.mining_secondaryScreensLoopLabel5),
            // The version in force, said the way every other mining page says
            // it. Without one, the block keeps the server's own reason.
            switch (rules.baseline) {
              MiningFormulaEffective() => MiningFormulaBlock(
                formula: rules.baseline,
              ),
              MiningFormulaPending(:final reasonCode) => LaunchUnavailableCard(
                label: context.l10n.mining_secondaryScreensLabel2,
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
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: LoopProvenanceLine(
                  key: ValueKey<String>('mining-rules-baseline-notice'),
                  prefix: miningBaselineLabel,
                  sources: <String>[
                    context.l10n.mining_secondaryScreensLoopProvenanceLine,
                  ],
                  detail: miningBaselineDetail,
                ),
              ),
            LoopLabel(context.l10n.mining_secondaryScreensLoopLabel6),
            if (rules.pendingApproval.isEmpty)
              LoopEmptyState(
                key: ValueKey<String>('mining-rules-no-pending'),
                illustration: LoopIllustration.history,
                title: context
                    .l10n
                    .mining_secondaryScreensMiningRulesNoPendingTitle,
                message: context
                    .l10n
                    .mining_secondaryScreensMiningRulesNoPendingMessage,
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
            LoopLabel(context.l10n.mining_secondaryScreensLoopLabel7),
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
                    subtitle: context.l10n
                        .mining_secondaryScreensMiningRulesReferralLSubtitle(
                          launchTimestampLabel(rules.referral.effectiveAt),
                        ),
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
                  label: context
                      .l10n
                      .mining_secondaryScreensMiningRulesOpenReferralLabel,
                  onPressed: widget.onOpenReferral,
                ),
              ],
            ),
            // Only while nothing is in force. Once a version is approved the
            // page above it prints a pinned range and a budget, and this
            // sentence would be the same screen calling those numbers absent.
            // What the approved version is, the baseline notice already says.
            if (rules.approved == null)
              LoopNotice(
                key: ValueKey<String>('mining-rules-notice'),
                icon: 'shield',
                title:
                    context.l10n.mining_secondaryScreensMiningRulesNoticeTitle,
                body: context.l10n.mining_secondaryScreensMiningRulesNoticeBody,
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
        title: context.l10n.mining_secondaryScreensTitle2,
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
        title: context.l10n.mining_secondaryScreensIf,
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
            ? context.l10n.mining_secondaryScreensTrailingCaption
            : (version.dailyOutput!.isPlaceholder
                  ? context.l10n.mining_secondaryScreensTrailingCaption2
                  : context.l10n.mining_secondaryScreensTrailingCaption3),
        position: LoopRowPosition.middle,
      ),
      LoopRecordRow(
        key: ValueKey<String>('$keyPrefix-referral-boost'),
        title: context.l10n.mining_secondaryScreensTitle3,
        subtitle: context.l10n.mining_secondaryScreensSubtitle,
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
        title: context.l10n.mining_secondaryScreensTitle4,
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
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            8,
            LoopSpacing.page,
            0,
          ),
          child: Text(
            <String>[
              miningFormulaStatusLabel(version.status),
              // The scope the version declares about itself, wherever the
              // version is printed.
              if (version.scope.isBaseline) miningBaselineLabel,
              if (version.approvedAt != null)
                context.l10n.mining_secondaryScreensSwitch5(
                  launchTimestampLabel(version.approvedAt!),
                ),
            ].join(' · '),
            key: ValueKey<String>('$keyPrefix-status'),
            style: LoopType.captionSm,
          ),
        ),
        if (version.assetWeights.isNotEmpty) ...<Widget>[
          LoopLabel(context.l10n.mining_secondaryScreensLoopLabel8),
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
                context.l10n.mining_secondaryScreensText2,
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
