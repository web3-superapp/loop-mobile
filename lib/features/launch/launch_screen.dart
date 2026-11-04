import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// The empty card of a segment other than 待排期 (S88d). Since loop-api S83b7
/// the segments follow the on-chain sale state; a launch with no chain reading
/// is filed by its schedule.
String get launchSegmentEmptyBody =>
    LoopL10n.current.launch_screenLaunchSegmentEmptyBody;

/// `launch` · the Launch destination.
///
/// The catalogue is an off-chain directory. Its segments are the server's:
/// since loop-api S83b7 they follow the on-chain sale state, and a launch with
/// no chain reading is filed by `scheduleStatus`. "已毕业" is a liquidity-axis
/// list the server reads separately (S83b7b), so it is a separate block
/// rather than a fourth tab of the same list.
///
/// The order of the first screen is the prototype's: the folio states the
/// count, the segment bar follows it, and the projects follow the bar. The
/// chain statement and the capability's own evidence moved to the foot of the
/// page, where they explain an empty list rather than hide it (audit
/// 2026-09-21 §H.2).
/// The Launch bar's two framed tools: 管理质押, and Launch 规则 once the
/// directory holds a launch. Shared with MEME's 发射台 segment, whose
/// embedded page draws no bar of its own (S106b).
List<Widget> launchTopbarActions({
  required LaunchOverview? overview,
  VoidCallback? onOpenStake,
  VoidCallback? onOpenRules,
}) => <Widget>[
  LoopIconButton(
    key: const ValueKey<String>('launch-stake-action'),
    icon: 'lock',
    label: LoopL10n.current.launch_screenLaunchStakeActionLabel,
    framed: true,
    onPressed: onOpenStake,
  ),
  // Round rules belong to one launch, so the control only appears once the
  // directory holds a launch to open. An empty directory used to send this
  // button to a subject-less page that reported the launch as missing, which
  // read as a 404 for a project the user never picked.
  if (overview != null && overview.segments.total > 0)
    LoopIconButton(
      key: const ValueKey<String>('launch-rules-action'),
      icon: 'info',
      label: LoopL10n.current.launch_screenLaunchRulesActionLabel,
      framed: true,
      onPressed: onOpenRules,
    ),
];

class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({
    super.key,
    this.onOpenLaunch,
    this.onOpenStake,
    this.onOpenRules,
    this.onOpenEconomy,
    this.onOpenApply,
    this.onBack,
    this.embedded = false,
  });

  /// Set when Launch is opened as a page of its own rather than as a tab.
  final VoidCallback? onBack;

  /// The 发射台 segment of MEME (decision 0110): no bar of its own.
  final bool embedded;

  final void Function(String launchId)? onOpenLaunch;
  final VoidCallback? onOpenStake;
  final VoidCallback? onOpenRules;
  final VoidCallback? onOpenEconomy;
  final VoidCallback? onOpenApply;

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen> {
  /// Whether this page drew the catalogue as a skeleton. Only then does the
  /// list fade in when it lands (decision 0095).
  bool _sawSkeleton = false;

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchOverviewControllerProvider);
    final controller = ref.read(launchOverviewControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final segment = ref.watch(launchSegmentControllerProvider);
    final overview = state.value;
    final loading =
        !blocked && overview == null && state.phase == LaunchViewPhase.loading;
    if (loading) _sawSkeleton = true;
    final testnet = launchSurfaceIsTestnet(capability: capability);

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.listing,
      // The prototype's bar is one line: `Launch` plus two framed round tools.
      title: 'Launch',
      framedTools: true,
      onBack: widget.onBack,
      tabPage: widget.onBack == null,
      embedded: widget.embedded,
      actions: launchTopbarActions(
        overview: overview,
        onOpenStake: widget.onOpenStake,
        onOpenRules: widget.onOpenRules,
      ),
      primary: LoopFolioPrimary(
        // `.lime-page .folio-primary` — the catalogue and the trade page are
        // the two saturated Lime heroes in the module.
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.listing,
        kicker: context.l10n.common_launchpad,
        // No countdown, no graduation percentage, no "my tier": all three are
        // contract facts and none of them can be proven in this step.
        heading: overview == null
            ? (loading
                  ? context.l10n.launch_screenHeading
                  : launchMissingHeading)
            : context.l10n.launch_screenHeading2(overview.segments.total),
        // Decision 0095: the count is a skeleton of its own height until the
        // catalogue is read, never a stand-in sentence.
        headingLoading: loading,
        // Decision 0097: the caption and the stamp follow the catalogue's own
        // rows. Only a row whose axes were read on chain lets the hero say
        // the chain is being read.
        caption: launchOverviewCaption(overview, testnet: testnet),
        stamp: overview == null
            ? null
            : launchOverviewReadsChain(overview)
            ? context.l10n.launch_detailScreensStamp
            : context.l10n.launch_screenStamp,
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('launch-capability-unavailable'),
              title: context.l10n.launch_screenLaunchCapabilityUnavailableTitle,
              capability: capability,
            )
          : null,
      sections: <Widget>[
        LoopFreshnessStrip(
          key: const ValueKey<String>('launch-freshness'),
          restoredAt: controller.restoredObservedAt,
          readAt: controller.valueObservedAt,
          refreshing: state.refreshing,
          refreshFailed: overview != null && state.failureKind != null,
          onRetry: () => unawaited(controller.reload()),
        ),
        if (overview == null)
          LaunchStateBlock(
            // Rows of the catalogue's own height (decision 0095).
            skeleton: LoopSkeletonType.record,
            rows: 4,
            prefix: 'launch',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: context.l10n.launch_screenEmptyMessage,
            emptyReason: context.l10n.launch_screenEmptyReason,
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          LoopSegBar(
            key: const ValueKey<String>('launch-segments'),
            labels: <String>[
              '${launchSegmentLabel(LaunchSegment.live)} '
                  '${overview.segments.live.length}',
              '${launchSegmentLabel(LaunchSegment.upcoming)} '
                  '${overview.segments.upcoming.length}',
              '${launchSegmentLabel(LaunchSegment.awaitingSchedule)} '
                  '${overview.segments.awaitingSchedule.length}',
              '${launchSegmentLabel(LaunchSegment.ended)} '
                  '${overview.segments.ended.length}',
            ],
            selectedIndex: LaunchSegment.values.indexOf(segment),
            onSelected: (index) => ref
                .read(launchSegmentControllerProvider.notifier)
                .select(LaunchSegment.values[index]),
          ),
          // One line, closeable, directly under the bar. The four-sentence
          // form of the same explanation stays on the surfaces a signature is
          // prepared on.
          LoopTestnetNotice(
            visible: testnet,
            margin: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              0,
              LoopSpacing.page,
              14,
            ),
            compact: true,
          ),
          LoopContentArrival(
            animate: _sawSkeleton,
            child: _SegmentList(
              segment: segment,
              overview: overview,
              onOpenLaunch: widget.onOpenLaunch,
            ),
          ),
          LoopLabel(context.l10n.common_graduated),
          // Graduation is a liquidity fact. It is never derived from a
          // schedule that says "ended".
          LaunchGraduatedBlock(
            graduated: overview.graduated,
            contractLive: capability.evidenceConfirmed,
            onOpenLaunch: widget.onOpenLaunch,
          ),
          // Decision 0038: the catalogue has no single launch, so the chain
          // statement comes from the capability the server published. It is a
          // footnote to the list, not a gate in front of it.
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: LaunchChainBlock(testnet: testnet, notice: false),
          ),
          _EvidenceNotice(capability: capability),
          LaunchSourceFooter(
            source: overview.catalog.source,
            kind: LaunchSourceKind.catalog,
            observedAt: overview.catalog.observedAt,
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('launch-open-economy'),
                leading: const LoopRowIcon(icon: 'droplet'),
                title: context.l10n.launch_screenLaunchOpenEconomyTitle,
                subtitle: context.l10n.launch_screenLaunchOpenEconomySubtitle,
                onTap: widget.onOpenEconomy,
              ),
            ],
          ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('launch-open-apply'),
                label: context.l10n.launch_actionScreensLaunchApplyScreenTitle,
                primary: true,
                onPressed: widget.onOpenApply,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// Whether any row of the catalogue carries axes read on chain
/// (`onChainState.source == "chain"`), decision 0097.
bool launchOverviewReadsChain(LaunchOverview overview) {
  final segments = overview.segments;
  return <LaunchSummary>[
    ...segments.live,
    ...segments.upcoming,
    ...segments.awaitingSchedule,
    ...segments.ended,
  ].any((launch) => launch.onChainState is LaunchOnChainAvailable);
}

/// The Launch hero's caption (decision 0097): the chain is named only when the
/// catalogue itself carries a chain reading.
String launchOverviewCaption(
  LaunchOverview? overview, {
  required bool testnet,
}) {
  if (overview != null && launchOverviewReadsChain(overview)) {
    return LoopL10n.current.launch_screenLaunchOverviewCaption(
      testnet
          ? loopTestnetChainLabel
          : LoopL10n.current.launch_screenBscMainnet,
    );
  }
  return LoopL10n.current.launch_screenLaunchOverviewCaption2;
}

/// The permanent Launch notice: the capability reads `available` because the
/// catalogue works, while its evidence says the contract baseline is missing.
class _EvidenceNotice extends StatelessWidget {
  const _EvidenceNotice({required this.capability});

  final LoopCapabilityProjection capability;

  @override
  Widget build(BuildContext context) {
    if (!capability.evidencePending) return const SizedBox.shrink();
    return LoopNotice(
      key: const ValueKey<String>('launch-evidence-notice'),
      icon: 'warn',
      tone: LoopNoticeTone.warn,
      title: context.l10n.launch_screenLaunchEvidenceNoticeTitle,
      body: launchReasonCodeText(capability.evidenceReasonCode),
      margin: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        14,
        LoopSpacing.page,
        0,
      ),
    );
  }
}

/// The 已毕业 block (loop-api S83b7b): the server's liquidity-axis list when
/// it was read, a true empty state when it was read and is empty, and the
/// server's reason when it could not be read. Rows are the catalogue's own
/// rows and open `launch-detail`.
class LaunchGraduatedBlock extends StatelessWidget {
  const LaunchGraduatedBlock({
    required this.graduated,
    required this.contractLive,
    required this.onOpenLaunch,
    super.key,
  });

  final LaunchGraduated graduated;
  final bool contractLive;
  final void Function(String launchId)? onOpenLaunch;

  @override
  Widget build(BuildContext context) {
    switch (graduated) {
      case LaunchGraduatedUnavailable(:final fact):
        return LaunchUnavailableCard(
          id: 'graduated-projects',
          label: context.l10n.launch_screenLabel,
          fact: fact,
          reason: launchGraduatedReasonText(
            fact.reasonCode,
            contractLive: contractLive,
          ),
        );
      case LaunchGraduatedAvailable(:final launches) when launches.isEmpty:
        return LoopEmptyState(
          key: ValueKey<String>('launch-graduated-empty'),
          illustration: LoopIllustration.launchpad,
          title: context.l10n.launch_screenLaunchGraduatedEmptyTitle,
          message: context.l10n.launch_screenLaunchGraduatedEmptyMessage,
          compact: true,
        );
      case LaunchGraduatedAvailable(:final launches):
        return LoopRecordGroup(
          key: const ValueKey<String>('launch-graduated-list'),
          rows: <LoopRecordRow>[
            for (var index = 0; index < launches.length; index += 1)
              launchCatalogRow(
                launch: launches[index],
                onTap: onOpenLaunch == null
                    ? null
                    : () => onOpenLaunch!(launches[index].launchId),
                position: launchRowPosition(index, launches.length),
                saleSegmentLabel: context.l10n.common_graduated,
                keyPrefix: 'launch-graduated-row',
              ),
          ],
        );
    }
  }
}

class _SegmentList extends StatelessWidget {
  const _SegmentList({
    required this.segment,
    required this.overview,
    required this.onOpenLaunch,
  });

  final LaunchSegment segment;
  final LaunchOverview overview;
  final void Function(String launchId)? onOpenLaunch;

  @override
  Widget build(BuildContext context) {
    final items = switch (segment) {
      LaunchSegment.live => overview.segments.live,
      LaunchSegment.upcoming => overview.segments.upcoming,
      LaunchSegment.awaitingSchedule => overview.segments.awaitingSchedule,
      LaunchSegment.ended => overview.segments.ended,
    };
    if (items.isEmpty) {
      // An empty segment keeps the page's own card shape. The centred grey
      // disc it used to draw belongs to a page with nothing on it; this page
      // has a bar, a catalogue and a statement of why the bar reads zero
      // (audit 2026-09-21 §H.2).
      return LoopNotice(
        key: ValueKey<String>('launch-segment-empty-${segment.name}'),
        icon: 'target',
        title: context.l10n.launch_screenTitle(launchSegmentLabel(segment)),
        body: segment == LaunchSegment.awaitingSchedule
            ? context.l10n.launch_screenBody
            : launchSegmentEmptyBody,
        margin: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          0,
        ),
      );
    }
    return LoopRecordGroup(
      key: ValueKey<String>('launch-segment-${segment.name}'),
      rows: <LoopRecordRow>[
        for (var index = 0; index < items.length; index += 1)
          launchCatalogRow(
            launch: items[index],
            onTap: onOpenLaunch == null
                ? null
                : () => onOpenLaunch!(items[index].launchId),
            position: launchRowPosition(index, items.length),
            saleSegmentLabel:
                segment == LaunchSegment.live || segment == LaunchSegment.ended
                ? launchSegmentLabel(segment)
                : null,
          ),
      ],
    );
  }
}
