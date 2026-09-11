import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `launch` · the Launch destination.
///
/// The catalogue is an off-chain directory. Its segments come only from
/// `scheduleStatus`; "已毕业" is a liquidity-axis fact and stays unavailable,
/// so it is a separate block rather than a fourth tab of the same list.
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

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-screen'),
      archetype: LoopPageArchetype.listing,
      title: 'Launch',
      kicker: 'LAUNCH DESK · 链下目录',
      tabPage: true,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('launch-stake-action'),
          icon: 'lock',
          label: '管理质押',
          onPressed: widget.onOpenStake,
        ),
        LoopIconButton(
          key: const ValueKey<String>('launch-rules-action'),
          icon: 'info',
          label: 'Launch 规则',
          onPressed: widget.onOpenRules,
        ),
      ],
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.listing,
        kicker: 'LAUNCH DESK',
        // No countdown, no graduation percentage, no "my tier": all three are
        // contract facts and none of them can be proven in this step.
        heading: overview == null
            ? launchMissingFigure
            : '${overview.segments.total} 个已登记项目',
        caption: '目录、申请与轮次配置由 LOOP 提供；链上状态、价格与毕业进度暂时读不到。',
        stamp: overview == null ? null : 'OFF-CHAIN',
      ),
      sections: <Widget>[
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>('launch-capability-unavailable'),
            icon: 'warn',
            message: 'Launch 当前不可用',
            reason: '请稍后再试。',
          )
        else if (overview == null)
          LaunchStateBlock(
            prefix: 'launch',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '目录里还没有已批准的项目',
            emptyReason: '通过审核的项目会出现在这里。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          _EvidenceNotice(capability: capability),
          // Decision 0038: the catalogue has no single launch, so the chain
          // statement comes from the capability the server published.
          LaunchChainBlock(
            testnet: launchSurfaceIsTestnet(capability: capability),
          ),
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
          _SegmentList(
            segment: segment,
            overview: overview,
            onOpenLaunch: widget.onOpenLaunch,
          ),
          const LoopLabel('已毕业'),
          // Graduation is a liquidity fact. It is never derived from a
          // schedule that says "ended".
          LaunchUnavailableCard(label: '已毕业项目', fact: overview.graduated),
          const LoopLabel('我的资格'),
          LaunchUnavailableCard(
            label: '我的 Launch 资格',
            fact: overview.myEligibility,
          ),
          const LoopLabel('LOOP 质押'),
          LaunchUnavailableCard(label: 'LOOP 质押', fact: overview.staking),
          LaunchSourceFooter(
            source: overview.catalog.source,
            observedAt: overview.catalog.observedAt,
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('launch-open-economy'),
                title: '生态经济面板',
                subtitle: '只显示可从 LOOP 数据库证明的计数',
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
      return LoopEmpty(
        key: ValueKey<String>('launch-segment-empty-${segment.name}'),
        message: '${launchSegmentLabel(segment)}：暂无项目',
        reason: segment == LaunchSegment.awaitingSchedule
            ? '通过审核但还没有排期的项目会出现在这里。'
            : '这个分段目前没有已登记的项目。分段只反映排期状态，不代表链上进度。',
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
          ),
      ],
    );
  }
}
