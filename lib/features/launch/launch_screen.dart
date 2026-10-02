import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// The empty card of a segment other than 待排期 (S88d). Since loop-api S83b7
/// the segments follow the on-chain sale state; a launch with no chain reading
/// is filed by its schedule.
const String launchSegmentEmptyBody =
    '这个分段目前没有项目。分段按链上销售状态划分；没有链上读数的项目按排期状态归类。';

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
class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({
    super.key,
    this.onOpenLaunch,
    this.onOpenStake,
    this.onOpenRules,
    this.onOpenEconomy,
    this.onOpenApply,
  });

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
      tabPage: true,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('launch-stake-action'),
          icon: 'lock',
          label: '管理质押',
          framed: true,
          onPressed: widget.onOpenStake,
        ),
        // Round rules belong to one launch, so the control only appears once
        // the directory holds a launch to open. An empty directory used to
        // send this button to a subject-less page that reported the launch as
        // missing, which read as a 404 for a project the user never picked.
        if (overview != null && overview.segments.total > 0)
          LoopIconButton(
            key: const ValueKey<String>('launch-rules-action'),
            icon: 'info',
            label: 'Launch 规则',
            framed: true,
            onPressed: widget.onOpenRules,
          ),
      ],
      primary: LoopFolioPrimary(
        compact: true,
        // A compact directory summary leaves projects in the first viewport.
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.listing,
        kicker: 'LAUNCH DESK',
        // No countdown, no graduation percentage, no "my tier": all three are
        // contract facts and none of them can be proven in this step.
        heading: overview == null
            ? (loading ? '目录读取中' : launchMissingHeading)
            : '${overview.segments.total} 个已登记项目',
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
            ? 'ON-CHAIN'
            : 'OFF-CHAIN',
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('launch-capability-unavailable'),
              title: 'Launch 当前不可用',
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
            emptyMessage: '目录里还没有已批准的项目',
            emptyReason: '通过审核的项目会出现在这里。',
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
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
          const LoopLabel('已毕业'),
          // Graduation is a liquidity fact. It is never derived from a
          // schedule that says "ended".
          LaunchGraduatedBlock(
            graduated: overview.graduated,
            contractLive: capability.evidenceConfirmed,
            onOpenLaunch: widget.onOpenLaunch,
          ),
          const LoopNotice(
            key: ValueKey<String>('launch-curation-notice'),
            icon: 'target',
            title: '精品发射，不是每天几万个',
            body:
                'LOOP 只联合交易所、KOL、社区与 IP 孵化有故事、有传播、有持续运营的 MEME。'
                '每次发射的总量、轮次与上限都以这次发射被批准的配置为准。',
            margin: EdgeInsets.fromLTRB(16, 22, 16, 0),
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
                title: '生态经济面板',
                subtitle: '只显示 LOOP 账本可以证明的计数',
                onTap: widget.onOpenEconomy,
              ),
            ],
          ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('launch-open-apply'),
                label: '申请发射',
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
    return '目录、申请与轮次配置由 LOOP 提供；链上状态读自 '
        '${testnet ? 'BSC 测试网' : 'BSC 主网'}。';
  }
  return '目录、申请与轮次配置由 LOOP 提供；链上状态、价格与毕业进度暂时读不到。';
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
      title: '目录可用，合约未就绪',
      body: launchReasonCodeText(capability.evidenceReasonCode),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
          label: '已毕业项目',
          fact: fact,
          reason: launchGraduatedReasonText(
            fact.reasonCode,
            contractLive: contractLive,
          ),
        );
      case LaunchGraduatedAvailable(:final launches) when launches.isEmpty:
        return const LoopEmpty(
          key: ValueKey<String>('launch-graduated-empty'),
          message: '还没有已毕业的项目',
          reason: '流动性锁定后的项目会出现在这里。',
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
                saleSegmentLabel: '已毕业',
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
        title: '${launchSegmentLabel(segment)}：暂无项目',
        body: segment == LaunchSegment.awaitingSchedule
            ? '通过审核但还没有排期的项目会出现在这里。'
            : launchSegmentEmptyBody,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
