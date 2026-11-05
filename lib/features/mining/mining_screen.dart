import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/navigation/intel_power_route.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/text/loop_power_text.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_copy.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_widgets.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_controllers.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_filter_chips.dart';
import 'package:loop_mobile/widgets/loop_info_sheet.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_provenance_scope.dart';

/// 情报 · 算力 (decision 0272, S344; formerly the `mining` page).
///
/// The `mining` and `mining-assets` routes forward here. Top to bottom:
/// 全网总算力 split into NFT and 代币, with the way into 算力榜; 我的总算力
/// (the claim, the account's own split); then the tabs NFT / 代币 / 邀请 —
/// the assets that carry power by kind (S348: only those above zero), and
/// 邀请中心 with its list and its boost.
///
/// The mining formula is backend delivery D19; every figure is the server's
/// own or the em dash with its reason. The client never estimates power,
/// output, accumulation or a claim.
class MiningScreen extends ConsumerStatefulWidget {
  const MiningScreen({
    super.key,
    this.onOpenRewards,
    this.onOpenRank,
    this.onOpenRules,
    this.onNavigate,
    this.onBack,
    this.embedded = false,
  });

  /// Set when the page is pushed on its own rather than drawn in 情报.
  final VoidCallback? onBack;

  /// Drawn as 情报's 算力 segment: no bar, the (i) on the segment row.
  final bool embedded;

  final VoidCallback? onOpenRewards;

  /// 算力榜, from the network card's top right.
  final VoidCallback? onOpenRank;
  final VoidCallback? onOpenRules;

  /// Pushes a location from the 邀请 tab.
  final ValueChanged<String>? onNavigate;

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

    // The composition behind the figure and the place it earned: the reads
    // 算力明细 and 算力榜 make, shared through their providers.
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
    // to say. It also carries the last settled hour's two network pools.
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
    final tab = ref.watch(intelPowerTabProvider);

    return LoopDashboardPage(
      key: const ValueKey<String>('mining-screen'),
      onRefresh: () => _reload(tab),
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: context.l10n.common_power,
      onBack: widget.onBack,
      embedded: widget.embedded,
      tabPage: widget.embedded || widget.onBack == null,
      actions: <Widget>[
        miningInfoAction(summary: summary, onOpenRules: widget.onOpenRules),
      ],
      // A closed mining gate keeps the page's shape: the gate is said where
      // the cards would be, and 邀请 — its own capability — still opens.
      // S350b · decision 0275: once 我的总算力 is read, 全网总算力 is the
      // hero's supporting line; before that it stands as its own card.
      primary: blocked || summary != null
          ? null
          : _networkCard(summary, rewards),
      sections: <Widget>[
        if (blocked)
          LoopCapabilityBlockCard(
            key: const ValueKey<String>('mining-capability-unavailable'),
            label: context.l10n.mining_screenMiningCapabilityUnavailableLabel,
            capability: capability,
          )
        else if (summary == null) ...<Widget>[
          _hero(summary, state.phase),
          LaunchStateBlock(
            prefix: 'mining',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: context.l10n.mining_screenEmptyMessage,
            onRetry: () => unawaited(controller.reload()),
          ),
        ] else ...<Widget>[
          MiningSummaryHero(
            heading: _heroHeading(summary),
            unit: _heroUnit(summary),
            caption: _heroCaption(summary),
            // S344 review: the scope chip and the split cells are gone — the
            // formula is the (i)'s, the split is the tabs'.
            rank: _rankBadge(rankState.value),
            rankPosition: switch (rankState.value?.myPosition) {
              MiningRankPositionSettled(:final position) => position,
              _ => null,
            },
            metrics: live
                ? <MiningHeroMetric>[
                    _dailyMetric(summary.estimatedToday),
                    MiningHeroMetric(
                      slug: 'accumulated',
                      label: context.l10n.mining_screenLabel,
                      value: launchMissingFigure,
                      spoken: launchReasonCodeText(
                        summary.accumulated.reasonCode,
                      ),
                    ),
                    MiningHeroMetric(
                      slug: 'claimable',
                      label: context.l10n.mining_screenLabel2,
                      value: launchMissingFigure,
                      spoken: launchReasonCodeText(
                        summary.claimable.reasonCode,
                      ),
                    ),
                  ]
                : _powerMetrics(rewards),
            // The claim itself lives on 奖励与领取, which states whether it
            // can be executed; this button is how the reader gets there.
            onClaim: widget.onOpenRewards,
            claimSemanticLabel: context.l10n.mining_screenClaimSemanticLabel,
            powerOnly: !live,
            network: _networkCard(summary, rewards, inline: true),
            onOpenRank: widget.onOpenRank,
          ),
          MiningSnapshotProvenanceLine(
            slug: 'summary',
            snapshot: summary.snapshot,
            formula: summary.formula,
            markStale: true,
          ),
        ],
        // S353b · decision 0279 (docs/58 §5.3, §9.4): the second-level
        // 54 × 32 filter chips — the Purple capsule is gone.
        LoopFilterChips(
          key: const ValueKey<String>('mining-power-tabs'),
          labels: <String>[for (final tab in IntelPowerTab.values) tab.label],
          selectedIndex: IntelPowerTab.values.indexOf(tab),
          onSelected: (index) => ref
              .read(intelPowerTabProvider.notifier)
              .select(IntelPowerTab.values[index]),
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            LoopSpacing.rowGap,
            LoopSpacing.page,
            LoopSpacing.chipGap - 6,
          ),
        ),
        KeyedSubtree(
          key: ValueKey<String>('mining-power-tab-${tab.wireName}'),
          child: switch (tab) {
            IntelPowerTab.invite => ReferralCenterSections(
              initialInviteCode: ref.watch(intelPendingInviteCodeProvider),
              onNavigate: widget.onNavigate,
              info: LoopInfoButton(
                key: const ValueKey<String>('mining-invite-info'),
                title: context.l10n.mining_screenMiningInviteInfoTitle,
                label: context.l10n.mining_screenMiningInviteInfoTitle,
                notes: referralInfoNotes(
                  ref.watch(referralControllerProvider).value,
                ),
                sheetKey: 'mining-invite-info-sheet',
              ),
              onOfferedInviteCode: () =>
                  ref.read(intelPendingInviteCodeProvider.notifier).clear(),
            ),
            _ when blocked || summary == null => const SizedBox.shrink(),
            _ => _CompositionBlock(
              summary: summary,
              assets: assetsState.value,
              phase: assetsState.phase,
              failureKind: assetsState.failureKind,
              tab: tab,
            ),
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _reload(IntelPowerTab tab) async {
    await Future.wait(<Future<void>>[
      ref.read(miningSummaryControllerProvider.notifier).reload(),
      ref.read(miningAssetsControllerProvider.notifier).reload(),
      if (tab == IntelPowerTab.invite) reloadReferralCenter(ref),
    ]);
  }

  Widget _networkCard(
    MiningSummary? summary,
    MiningRewardsView? rewards, {
    bool inline = false,
  }) {
    final nft = rewards?.nft?.networkPower;
    final token = rewards?.asset?.networkPower;
    if (nft != null && token != null) {
      final total = miningPowerFigure(nft + token);
      return MiningNetworkPowerCard(
        total: total,
        spoken: total,
        nft: miningPowerFigure(nft),
        token: miningPowerFigure(token),
        lastHour: true,
        onOpenRank: widget.onOpenRank,
        inline: inline,
      );
    }
    return switch (summary?.networkPower) {
      MiningFigureValue(:final value) => MiningNetworkPowerCard(
        total: loopPowerFigure(value),
        spoken: loopPowerFigure(value),
        onOpenRank: widget.onOpenRank,
        inline: inline,
      ),
      MiningFigureUnavailable(:final reasonCode) => MiningNetworkPowerCard(
        total: launchMissingFigure,
        spoken: launchReasonCodeText(reasonCode),
        onOpenRank: widget.onOpenRank,
        inline: inline,
      ),
      null => MiningNetworkPowerCard(
        total: launchMissingFigure,
        spoken: LoopL10n.current.mining_screenSpoken,
        onOpenRank: widget.onOpenRank,
        inline: inline,
      ),
    };
  }
}

/// 挖矿说明, the (i) of 情报 · 算力 (decision 0243 / 0255): the formula
/// version, the snapshot, the no-local-estimate rule and the conditions,
/// and the way on to 挖矿规则.
LoopPageInfoAction miningInfoAction({
  required MiningSummary? summary,
  VoidCallback? onOpenRules,
}) => LoopPageInfoAction(
  key: const ValueKey<String>('mining-rules-action'),
  title: LoopL10n.current.mining_screenMiningRulesActionTitle,
  label: LoopL10n.current.mining_screenMiningRulesActionTitle,
  notes: miningInfoNotes(summary),
  sheetKey: 'mining-info-sheet',
  footer: onOpenRules == null
      ? null
      : (sheetContext) => LoopButton(
          key: const ValueKey<String>('mining-info-open-rules'),
          label: LoopL10n.current.mining_screenMiningInfoOpenRulesLabel,
          block: true,
          onPressed: () {
            Navigator.of(sheetContext).pop();
            onOpenRules();
          },
        ),
);

/// 公式版本 in the (i): the state in words, then — on its own line, the way
/// the 详情 disclosure it replaces printed it — the version identifier, which
/// is only ever shown behind a tap.
String _formulaInfoBody(MiningFormulaGate? formula) {
  final (
    String sentence,
    String? label,
    String? identifier,
  ) = switch (formula) {
    null => (LoopL10n.current.mining_screenSwitch, null, null),
    MiningFormulaPending(:final reasonCode, pendingVersion: null) => (
      LoopL10n.current.mining_screenSwitch2(launchReasonCodeText(reasonCode)),
      null,
      null,
    ),
    MiningFormulaPending(:final pendingVersion) => (
      LoopL10n.current.mining_screenSwitch3,
      LoopL10n.current.mining_screenSwitch4,
      pendingVersion,
    ),
    MiningFormulaEffective(
      :final effectiveAt,
      :final scope,
      :final configVersion,
    ) =>
      (
        LoopL10n.current.mining_screenSwitch5(
          launchTimestampLabel(effectiveAt),
          scope.isBaseline
              ? LoopL10n.current.mining_screenParenthetical(miningBaselineLabel)
              : '',
        ),
        LoopL10n.current.mining_screenSwitch6,
        configVersion,
      ),
  };
  return label == null || identifier == null
      ? sentence
      : '$sentence\n$label $identifier';
}

/// What 我的挖矿's (i) says (decision 0243). It reads the same summary the
/// page draws; without one it says the figures have not been read, never a
/// version or a block it does not have.
List<LoopInfoNote> miningInfoNotes(MiningSummary? summary) {
  final formula = summary?.formula;
  final snapshot = summary?.snapshot;
  return <LoopInfoNote>[
    LoopInfoNote(
      key: const ValueKey<String>('mining-info-formula'),
      title: LoopL10n.current.mining_screenMiningInfoFormulaTitle,
      body: _formulaInfoBody(formula),
    ),
    LoopInfoNote(
      key: const ValueKey<String>('mining-info-snapshot'),
      title: miningSnapshotRowTitle,
      body: switch (snapshot) {
        null => LoopL10n.current.mining_screenLoopInfoNote,
        MiningSnapshotUnavailable(:final reasonCode, :final latestAttempt) =>
          '${miningSnapshotAbsenceMessage(reasonCode)}${LoopL10n.current.widgets_sentenceJoin}'
              '${miningSnapshotAbsenceReason(reasonCode, attempt: latestAttempt)}',
        // S378 · decision 0302: the block, not the time.
        MiningSnapshotComputed(:final blockNumber) =>
          LoopL10n.current.mining_screenMiningSnapshotComputed(
            loopGroupedFigure(blockNumber),
          ),
      },
    ),
    LoopInfoNote(
      key: const ValueKey<String>('mining-info-truth'),
      title: LoopL10n.current.mining_screenMiningInfoTruthTitle,
      body: switch (formula) {
        MiningFormulaEffective() =>
          LoopL10n.current.mining_screenMiningFormulaEffective,
        _ => LoopL10n.current.mining_screenLoopInfoNote2,
      },
    ),
    // Decision 0183 (需求方 2026-10-25): what a holding needs before it
    // counts, one condition per line.
    LoopInfoNote(
      key: ValueKey<String>('mining-info-conditions'),
      title: LoopL10n.current.mining_screenMiningInfoConditionsTitle,
      body: LoopL10n.current.mining_screenMiningInfoConditionsBody(
        miningConditionEmbedded,
        miningConditionMember,
        miningConditionVerified,
      ),
    ),
  ];
}

/// The hero heading: the power itself, or the words for its absence.
String _heroHeading(MiningSummary summary) => switch (summary.formula) {
  MiningFormulaPending() => launchMissingHeading,
  MiningFormulaEffective() => switch (summary.power) {
    MiningFigureValue(:final value) => loopPowerFigure(value),
    MiningFigureUnavailable() => launchMissingHeading,
  },
};

/// `.mining-power-value small` — the unit only a settled figure carries.
String? _heroUnit(MiningSummary summary) =>
    _heroHeading(summary) == launchMissingHeading ? null : 'H';

/// The hero's one line at its top right. S378 · decision 0302 (需求方
/// 2026-11-05): the snapshot's time is gone; only 未更新 stays when a later run
/// overtook the snapshot (decision 0057, AGENTS rule 25 visible marker).
String? _heroCaption(MiningSummary summary) => switch (summary.snapshot) {
  MiningSnapshotComputed(stale: true) => LoopL10n.current.mining_widgetsMarker,
  _ => null,
};

/// The cells while the LOOP token is not live (decision 0184): the
/// account's last settled hour (S378: no longer its invites). None is a
/// LOOP amount. Decision 0272: 全网算力 is the network card's above, so it
/// is not repeated here.
List<MiningHeroMetric> _powerMetrics(MiningRewardsView? rewards) {
  // S378 · decision 0302 (需求方 2026-11-05): 有效邀请 left the hero — the
  // 邀请 tab under it already carries the invite figures.
  final hour = miningLastHourPower(rewards);
  return <MiningHeroMetric>[
    MiningHeroMetric(
      slug: 'last-hour-power',
      label: LoopL10n.current.mining_screenLabel3,
      value: hour == null ? launchMissingFigure : miningPowerFigure(hour),
      spoken: hour == null
          ? LoopL10n.current.mining_screenSpoken2
          : miningPowerFigure(hour),
    ),
  ];
}

MiningHeroMetric _dailyMetric(MiningDailyOutput output) => switch (output) {
  MiningDailyOutputEstimate(:final value) => MiningHeroMetric(
    slug: 'estimated-today',
    label: LoopL10n.current.mining_screenLabel5,
    value: loopGroupedFigure(value),
    spoken: loopGroupedFigure(value),
  ),
  MiningDailyOutputUnavailable(:final reasonCode) => MiningHeroMetric(
    slug: 'estimated-today',
    label: LoopL10n.current.mining_screenLabel5,
    value: launchMissingFigure,
    spoken: launchReasonCodeText(reasonCode),
  ),
};

/// 第 1,284 名. It prints only a place the server settled; a board this
/// reader is not on, and a board that did not load, both leave it out.
String? _rankBadge(MiningRank? rank) => switch (rank?.myPosition) {
  MiningRankPositionSettled(:final position) =>
    LoopL10n.current.intel_rankBoardText4(position),
  _ => null,
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
    kicker: LoopL10n.current.mining_screenKicker,
    heading: loading
        ? LoopL10n.current.mining_screenHeading
        : launchMissingHeading,
  );
}

/// 代币算力 and NFT 算力 (decision 0253). The snapshot's own split
/// (`summary.assetPower` / `summary.nftPower`) when the server sends it, so the
/// two move with 总算力; otherwise the last settled hour's two pools
/// (`tracks.asset.totalPower` / `tracks.nft.totalPower`), labelled 上一小时.
List<MiningHeroMetric> miningPoolSplitMetrics(
  MiningSummary? summary,
  MiningRewardsView? rewards,
) {
  if (summary != null && summary.hasPoolSplit) {
    MiningHeroMetric cell(String slug, String label, String value) =>
        MiningHeroMetric(
          slug: slug,
          label: label,
          value: loopPowerFigure(value),
          spoken: loopPowerFigure(value),
        );
    return <MiningHeroMetric>[
      cell(
        'token-power',
        LoopL10n.current.mining_screenCell,
        summary.assetPower!,
      ),
      cell('nft-power', LoopL10n.current.mining_screenCell2, summary.nftPower!),
    ];
  }
  MiningHeroMetric cell(String slug, String label, Decimal? value) =>
      MiningHeroMetric(
        slug: slug,
        label: label,
        value: value == null ? launchMissingFigure : miningPowerFigure(value),
        spoken: value == null
            ? LoopL10n.current.mining_screenSpoken2
            : miningPowerFigure(value),
      );
  return <MiningHeroMetric>[
    cell(
      'token-power',
      LoopL10n.current.mining_screenCell3,
      rewards?.asset?.totalPower,
    ),
    cell(
      'nft-power',
      LoopL10n.current.mining_screenCell4,
      rewards?.nft?.totalPower,
    ),
  ];
}

Decimal _decimalOrZero(String? value) =>
    value == null ? Decimal.zero : Decimal.parse(value);

/// 算力构成, one tab at a time (decision 0272): NFT or 代币, one row per
/// weighted asset of the snapshot, so it moves with 总算力. With the
/// summary's `assetPower` / `nftPower` (decision 0253) each tab is headed
/// by its subtotal; a row's NFT share is `included[].nftPower` and its 代币
/// part `power − nftPower`. Without the split, 代币 keeps the single list
/// and NFT says its share was not sent. S348: a row whose power is zero is
/// not drawn, and neither are the assets the snapshot did not count; a tab
/// with nothing above zero is one line.
class _CompositionBlock extends ConsumerWidget {
  const _CompositionBlock({
    required this.summary,
    required this.assets,
    required this.phase,
    required this.failureKind,
    required this.tab,
  });

  final MiningSummary summary;
  final MiningAssets? assets;
  final LaunchViewPhase phase;
  final LaunchFailureKind? failureKind;
  final IntelPowerTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = assets;
    if (value == null) {
      return LaunchStateBlock(
        prefix: 'mining-composition',
        phase: phase,
        failureKind: failureKind,
        rows: 2,
        emptyMessage: context.l10n.mining_screenEmptyMessage2,
        onRetry: () => unawaited(
          ref.read(miningAssetsControllerProvider.notifier).reload(),
        ),
      );
    }
    final nftTab = tab == IntelPowerTab.nft;
    if (!summary.hasPoolSplit) {
      if (nftTab) {
        return LoopInlineUnavailable(
          key: ValueKey<String>('mining-composition-nft-unavailable'),
          icon: 'clock',
          message:
              context.l10n.mining_screenMiningCompositionNftUnavailableMessage,
        );
      }
      final counted = <MiningAssetRow>[
        for (final row in value.included)
          if (_decimalOrZero(row.power) > Decimal.zero) row,
      ];
      return counted.isEmpty
          ? _emptyLine(
              'mining-composition-empty',
              value.isUnsettled
                  ? context.l10n.mining_screenEmptyLine
                  : context.l10n.mining_screenS,
            )
          : LoopRecordGroup(
              key: const ValueKey<String>('mining-composition'),
              // S371 · decision 0297: holdings are not ruled (§9.4).
              divided: false,
              rows: <LoopRecordRow>[
                for (var index = 0; index < counted.length; index += 1)
                  miningCompositionRow(
                    counted[index],
                    launchRowPosition(index, counted.length),
                  ),
              ],
            );
    }
    if (nftTab) {
      final nftRows = <(MiningAssetRow, String)>[
        for (final row in value.included)
          if (_decimalOrZero(row.nftPower) > Decimal.zero) (row, row.nftPower!),
      ];
      return Column(
        key: const ValueKey<String>('mining-composition'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: _group(
          slug: 'nft',
          title: 'NFT',
          subtotal: summary.nftPower!,
          emptyTitle: context.l10n.mining_screenEmptyTitle,
          rows: <LoopRecordRow>[
            for (var index = 0; index < nftRows.length; index += 1)
              miningNftCompositionRow(
                nftRows[index].$1,
                nftRows[index].$2,
                launchRowPosition(index, nftRows.length),
              ),
          ],
        ),
      );
    }
    final tokenRows = <(MiningAssetRow, String)>[];
    for (final row in value.included) {
      final nft = _decimalOrZero(row.nftPower);
      final token = Decimal.parse(row.power) - nft;
      if (token > Decimal.zero) tokenRows.add((row, token.toString()));
    }
    return Column(
      key: const ValueKey<String>('mining-composition'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: _group(
        slug: 'token',
        title: context.l10n.common_token,
        subtotal: summary.assetPower!,
        emptyTitle: context.l10n.mining_screenS,
        rows: <LoopRecordRow>[
          for (var index = 0; index < tokenRows.length; index += 1)
            miningCompositionRow(
              tokenRows[index].$1,
              launchRowPosition(index, tokenRows.length),
              keyPrefix: 'mining-composition-token',
              power: tokenRows[index].$2,
            ),
        ],
      ),
    );
  }

  /// A tab with nothing above zero: one line.
  static Widget _emptyLine(String key, String message) => LoopInlineUnavailable(
    key: ValueKey<String>(key),
    icon: 'mine',
    message: message,
  );

  static List<Widget> _group({
    required String slug,
    required String title,
    required String subtotal,
    required List<LoopRecordRow> rows,
    required String emptyTitle,
  }) => <Widget>[
    MiningCompositionGroupHeading(
      slug: slug,
      title: title,
      subtotal: loopPowerFigure(subtotal),
      spoken: loopPowerFigure(subtotal),
    ),
    if (rows.isEmpty)
      _emptyLine('mining-composition-$slug-empty', emptyTitle)
    else
      LoopRecordGroup(
        key: ValueKey<String>('mining-composition-$slug'),
        divided: false,
        rows: rows,
      ),
  ];
}
