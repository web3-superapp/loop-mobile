import 'package:flutter/material.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// Whether an S7 page must stop at the capability gate instead of reading.
///
/// One boolean and nothing else: `launch`, `mining` and `referral` all read
/// `available` while their evidence stays pending, and the evidence is what
/// each page renders as its unavailable explanation.
bool launchCapabilityBlocks(LoopCapabilityProjection capability) =>
    !capability.isAvailable;

/// The one place the five reviewed states are rendered for an S7 page.
class LaunchStateBlock extends StatelessWidget {
  const LaunchStateBlock({
    required this.prefix,
    required this.phase,
    required this.failureKind,
    super.key,
    this.onRetry,
    this.emptyMessage = '这里还没有内容',
    this.emptyReason,
    this.permissionTitle = '当前账号没有权限',
    this.skeleton = LoopSkeletonType.list,
    this.rows = 3,
  });

  /// Page-scoped key prefix, e.g. `launch` → `launch-state-loading`.
  final String prefix;
  final LaunchViewPhase phase;
  final LaunchFailureKind? failureKind;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final String? emptyReason;
  final String permissionTitle;
  final LoopSkeletonType skeleton;
  final int rows;

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case LaunchViewPhase.loading:
        return LoopSkeleton(
          key: ValueKey<String>('$prefix-state-loading'),
          type: skeleton,
          rows: rows,
        );
      case LaunchViewPhase.empty:
        return LoopEmpty(
          key: ValueKey<String>('$prefix-state-empty'),
          message: emptyMessage,
          reason: emptyReason,
        );
      case LaunchViewPhase.offline:
        return LoopOfflineState(
          key: ValueKey<String>('$prefix-state-offline'),
          onRetry: onRetry,
          pausedActions: const <String>['申请', '提交', '认购', '领取', '绑定'],
        );
      case LaunchViewPhase.unavailable:
        return LoopEmpty(
          key: ValueKey<String>('$prefix-state-unavailable'),
          icon: 'warn',
          message: '该功能当前不可用',
          reason: launchFailureReason(failureKind),
        );
      case LaunchViewPhase.permission:
        return LoopPermissionState(
          key: ValueKey<String>('$prefix-state-permission'),
          icon: 'shield',
          title: permissionTitle,
          purpose: launchFailureReason(failureKind),
        );
      case LaunchViewPhase.error:
        return LoopErrorState(
          key: ValueKey<String>('$prefix-state-error'),
          reason: launchFailureReason(failureKind),
          onRetry: onRetry,
        );
      case LaunchViewPhase.ready:
        return const SizedBox.shrink();
    }
  }
}

/// Renders one `{status: unavailable, reasonCode}` field. It never renders a
/// figure, a zero, or a fixture in place of the missing fact.
class LaunchUnavailableCard extends StatelessWidget {
  const LaunchUnavailableCard({
    required this.label,
    required this.fact,
    super.key,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String label;
  final LaunchUnavailable fact;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return LoopEmpty(
      key: ValueKey<String>('launch-unavailable-$label'),
      message: label,
      reason: launchReasonCodeText(fact.reasonCode),
      margin: margin,
    );
  }
}

/// One metric whose figure has no source: the em dash plus the server's own
/// explanation. It is the S7 replacement for a "0" or a fixture.
class LaunchEmptyMetric extends StatelessWidget {
  const LaunchEmptyMetric({
    required this.label,
    required this.reasonCode,
    super.key,
    this.note,
    this.showReason = true,
  });

  final String label;
  final String reasonCode;

  /// An extra sentence the page owns, such as "待确认".
  final String? note;

  /// Whether this metric prints the reason under its own figure.
  ///
  /// [LaunchEmptyMetricGrid] turns it off when every metric in the grid would
  /// print the same sentence and states it once for the whole block instead.
  /// The reason stays in the metric's semantic label either way, so a screen
  /// reader still hears it on each figure.
  final bool showReason;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey<String>('launch-metric-$label'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Semantics(
        container: true,
        label:
            '$label，暂无数值。'
            '${launchMetricReasonLine(reasonCode: reasonCode, note: note)}',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: LoopTypography.figure(11, color: LoopColors.text3),
              ),
              const SizedBox(height: 4),
              Text(
                launchMissingFigure,
                style: LoopTypography.figure(
                  20,
                  height: 1.15,
                  color: LoopColors.chalk,
                ),
              ),
              if (showReason) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  launchMetricReasonLine(reasonCode: reasonCode, note: note),
                  style: LoopTypography.caption(11, color: LoopColors.text2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The one sentence a figure-less metric prints under its em dash.
String launchMetricReasonLine({required String reasonCode, String? note}) =>
    note == null
    ? launchReasonCodeText(reasonCode)
    : '$note · ${launchReasonCodeText(reasonCode)}';

/// A grid of [LaunchEmptyMetric]s. Every S7 dashboard block uses it so no page
/// can accidentally render one figure and one placeholder side by side.
///
/// One missing baseline is what empties most of these figures at once, so the
/// same sentence would otherwise print under every one of them. The sentence
/// shared by the most metrics is stated once for the block; a metric whose
/// reason differs — "待领取" under a reward authority that is separately closed
/// — keeps its own line, because that one is not the block's story.
class LaunchEmptyMetricGrid extends StatelessWidget {
  const LaunchEmptyMetricGrid({required this.metrics, super.key, this.note});

  /// `(label, reasonCode)` pairs in render order.
  final List<(String, String)> metrics;
  final String? note;

  /// The reason line carried by more metrics than any other, or `null` when no
  /// line repeats and every metric speaks for itself.
  String? get _sharedReason {
    final counts = <String, int>{};
    for (final metric in metrics) {
      final line = launchMetricReasonLine(reasonCode: metric.$2, note: note);
      counts[line] = (counts[line] ?? 0) + 1;
    }
    String? shared;
    var best = 1;
    for (final entry in counts.entries) {
      if (entry.value > best) {
        shared = entry.key;
        best = entry.value;
      }
    }
    return shared;
  }

  @override
  Widget build(BuildContext context) {
    final shared = _sharedReason;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (shared != null)
          Padding(
            key: const ValueKey<String>('launch-metric-grid-reason'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            child: Text(
              shared,
              style: LoopTypography.caption(11, color: LoopColors.text2),
            ),
          ),
        for (final metric in metrics)
          LaunchEmptyMetric(
            label: metric.$1,
            reasonCode: metric.$2,
            note: note,
            showReason:
                shared !=
                launchMetricReasonLine(reasonCode: metric.$2, note: note),
          ),
      ],
    );
  }
}

/// One configuration slot row: the confirmed value, or "待确认" with the
/// server's own reason. Nothing here is ever a client default, and the
/// version that confirmed the slot stays off the row.
LoopRecordRow launchConfigSlotRow({
  required String label,
  required LaunchConfigSlot slot,
  LoopRowPosition position = LoopRowPosition.single,
}) {
  return switch (slot) {
    LaunchConfigSlotConfirmed(:final value) => LoopRecordRow(
      key: ValueKey<String>('launch-slot-$label'),
      title: label,
      subtitle: '已确认',
      trailing: value,
      position: position,
      semanticLabel: '$label，$value',
    ),
    LaunchConfigSlotPending(:final reasonCode) => LoopRecordRow(
      key: ValueKey<String>('launch-slot-$label'),
      title: label,
      subtitle:
          '$launchPendingConfirmationLabel · ${launchReasonCodeText(reasonCode)}',
      trailing: launchMissingFigure,
      position: position,
      semanticLabel: '$label，$launchPendingConfirmationLabel',
    ),
  };
}

/// One round slot row. A `null` field is "待确认", never `0` and never "无".
LoopRecordRow launchRoundRow({
  required LaunchRound round,
  LoopRowPosition position = LoopRowPosition.single,
  VoidCallback? onTap,
  bool selected = false,
}) {
  const pendingLabel = launchPendingConfirmationLabel;
  final tier = round.eligibilityTier;
  final parts = <String>[
    tier == null ? '资格 $pendingLabel' : '资格 ${launchTierLabel(tier)}',
    round.startsAt == null
        ? '时间 $pendingLabel'
        : '开始 ${launchTimestampLabel(round.startsAt!)}',
    round.priceUsd1 == null ? '价格 $pendingLabel' : '价格 ${round.priceUsd1} USD1',
    round.walletRoundCapRaw == null
        ? '上限 $pendingLabel'
        : '上限 ${round.walletRoundCapRaw}',
  ];
  return LoopRecordRow(
    key: ValueKey<String>('launch-round-${round.roundIndex}'),
    leading: _RoundIndexTile(index: round.roundIndex),
    title: 'Round ${round.roundIndex}',
    subtitle: parts.join(' · '),
    trailingBadge: LoopBadge(
      selected ? '已选择' : (round.isConfirmed ? '已确认' : '待确认'),
      kind: selected || round.isConfirmed
          ? LoopBadgeKind.launch
          : LoopBadgeKind.mute,
    ),
    onTap: onTap,
    position: position,
    semanticLabel:
        'Round ${round.roundIndex}，${parts.join('，')}'
        '${selected ? '，已选择' : ''}',
  );
}

class _RoundIndexTile extends StatelessWidget {
  const _RoundIndexTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoopColors.card2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$index',
        style: LoopTypography.figure(13, color: LoopColors.chalk),
      ),
    );
  }
}

/// Row position inside a group of [length] rows.
LoopRowPosition launchRowPosition(int index, int length) {
  if (length <= 1) return LoopRowPosition.single;
  if (index == 0) return LoopRowPosition.first;
  if (index == length - 1) return LoopRowPosition.last;
  return LoopRowPosition.middle;
}

/// Server observation time in UTC. The client never restates it as a local
/// wall clock or as a relative "just now".
String launchTimestampLabel(DateTime observedAt) {
  final value = observedAt.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)} UTC';
}

/// The provenance footer every S7 catalogue block carries: the source and the
/// observation time. The configuration version behind the block is a backend
/// identifier and stays off the footer.
class LaunchSourceFooter extends StatelessWidget {
  const LaunchSourceFooter({
    required this.source,
    required this.observedAt,
    super.key,
  });

  final String source;
  final DateTime observedAt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('launch-source-footer'),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      child: Text(
        '来源 $source · 观察于 ${launchTimestampLabel(observedAt)}',
        style: LoopTypography.caption(11, color: LoopColors.text3),
      ),
    );
  }
}

/// A launch catalogue row. It carries only off-chain facts: the schedule
/// status and the configuration version. No progress bar, market cap, holder
/// count, countdown or fee appears, because none of them can be proven.
LoopRecordRow launchCatalogRow({
  required LaunchSummary launch,
  required VoidCallback? onTap,
  LoopRowPosition position = LoopRowPosition.single,
}) {
  final schedule = switch (launch.scheduleStatus) {
    LaunchScheduleStatus.unscheduled => '已批准 · 待排期',
    LaunchScheduleStatus.scheduled => '已排期',
    LaunchScheduleStatus.live => '发射中',
    LaunchScheduleStatus.ended => '已结束',
  };
  final config = launch.configVersion == null
      ? launchPendingConfirmationLabel
      : '配置已确认';
  // The chain is the launch's own published value. It is stated, never
  // inferred from the segment or from the catalogue's own chain.
  final testnet = launch.isTestnetChain;
  return LoopRecordRow(
    key: ValueKey<String>('launch-row-${launch.launchId}'),
    leading: LaunchTickerTile(ticker: launch.ticker),
    title: launch.name,
    subtitle: '${launch.ticker} · $schedule · $config',
    // The trailing column is a state, never a figure: the four on-chain axes
    // are unavailable, so a number there would be an invention.
    trailingBadge: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (testnet) ...<Widget>[
          const LoopTestnetBadge(),
          const SizedBox(height: 4),
        ],
        const LoopBadge('链上待确认', kind: LoopBadgeKind.mute),
      ],
    ),
    onTap: onTap,
    position: position,
    semanticLabel:
        '${launch.name}，${launch.ticker}，$schedule，'
        '${testnet ? '$loopTestnetBadgeLabel，' : ''}链上状态待确认',
  );
}

/// Square monogram tile for a launch. The frozen local atlas carries no
/// project artwork, so the tile shows the ticker rather than an unrelated
/// preset image.
class LaunchTickerTile extends StatelessWidget {
  const LaunchTickerTile({required this.ticker, super.key, this.size = 44});

  final String ticker;
  final double size;

  @override
  Widget build(BuildContext context) {
    final runes = ticker.runes.take(4).toList(growable: false);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: LoopColors.card2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        String.fromCharCodes(runes),
        style: LoopTypography.figure(
          size / 4.4,
          weight: FontWeight.w700,
          color: LoopColors.chalk,
        ),
      ),
    );
  }
}

/// The four on-chain axes, each rendered as an em dash with the server's own
/// reason. They are never collapsed into a single "unknown" line: a page that
/// merged them could later imply one axis from another.
class LaunchAxisBlock extends StatelessWidget {
  const LaunchAxisBlock({required this.state, super.key});

  final LaunchOnChainState state;

  @override
  Widget build(BuildContext context) {
    final axes = state.axes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            for (var index = 0; index < axes.length; index += 1)
              LoopRecordRow(
                key: ValueKey<String>('launch-axis-${axes[index].$1}'),
                title: axes[index].$1,
                subtitle: launchReasonCodeText(state.reasonCode),
                trailing: launchMissingFigure,
                position: launchRowPosition(index, axes.length),
                semanticLabel: '${axes[index].$1}，暂无可证明的链上状态',
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            '链上信息暂时读不到，因此这一页不显示合约地址、总量、税率或上限。',
            style: LoopTypography.caption(11, color: LoopColors.text3),
          ),
        ),
      ],
    );
  }
}

/// One exchange-listing track. `LISTED` and `FEATURED` are the only states
/// that carry reviewed evidence, and the two evidence timestamps are shown
/// separately: `recordedAt` is the server clock when a reviewer filed it,
/// `observedAt` is when the operator says it became verifiable on the venue.
/// Neither is ever derived from the other.
LoopRecordRow launchMilestoneRow({
  required LaunchMilestone milestone,
  LoopRowPosition position = LoopRowPosition.single,
}) {
  final track =
      '${launchVenueLabel(milestone.venue)} · '
      '${launchMarketTypeLabel(milestone.marketType)}';
  final lines = <String>[];
  if (milestone.isImplicit) {
    // The track is always listed; nothing has been recorded against it.
    lines.add('尚无记录');
  } else {
    lines.add('更新于 ${launchTimestampLabel(milestone.updatedAt!)}');
  }
  final evidence = milestone.evidence;
  if (milestone.state.carriesEvidence) {
    lines.add(
      evidence.recordedAt == null
          ? '复核记录时间 $launchMissingFigure'
          : '复核记录于 ${launchTimestampLabel(evidence.recordedAt!)}',
    );
    lines.add(
      evidence.observedAt == null
          ? '平台可核验时间 $launchMissingFigure（操作员未提供）'
          : '平台可核验于 ${launchTimestampLabel(evidence.observedAt!)}',
    );
    if (evidence.reviewer != null) lines.add('复核人 ${evidence.reviewer}');
  } else {
    lines.add('这一状态没有可查材料');
  }
  return LoopRecordRow(
    key: ValueKey<String>('launch-milestone-${milestone.trackKey}'),
    title: track,
    subtitle: lines.join('\n'),
    trailingBadge: LoopBadge(
      launchMilestoneStateLabel(milestone.state),
      kind: milestone.state.carriesEvidence
          ? LoopBadgeKind.launch
          : LoopBadgeKind.mute,
    ),
    position: position,
    semanticLabel:
        '$track，${launchMilestoneStateLabel(milestone.state)}，'
        '${lines.join('，')}',
  );
}

/// Whether one Launch surface is bound to the Launch testnet slot.
///
/// A surface that has a launch record reads that record's own chain; a surface
/// that has none — the catalogue, `loop-stake` — reads the chain the server
/// published on the `launch` capability. Neither is ever inferred from the
/// other, and neither is ever guessed by the client.
bool launchSurfaceIsTestnet({
  required LoopCapabilityProjection capability,
  LaunchSummary? launch,
}) => launch?.isTestnetChain ?? capability.isTestnetLaunchChain;

/// The chain statement a Launch surface renders while it is on the testnet.
///
/// Two facts and no controls: the chain the server published for this surface
/// with the "BSC 测试网" badge, and the one-time explanation shared by every
/// Launch surface. On the primary chain it renders nothing at all, so a build
/// whose Launch slot is `eip155:56` looks exactly as it did before.
class LaunchChainBlock extends StatelessWidget {
  const LaunchChainBlock({required this.testnet, super.key});

  final bool testnet;

  @override
  Widget build(BuildContext context) {
    if (!testnet) return const SizedBox.shrink();
    return Column(
      key: const ValueKey<String>('launch-chain-block'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('launch-chain-row'),
              title: loopChainName(loopLaunchTestnetChainId),
              subtitle:
                  '$loopLaunchTestnetChainId · Launch 链；'
                  '钱包余额、行情、兑换与授权仍在主网',
              trailingBadge: const LoopTestnetBadge(),
              semanticLabel:
                  'Launch 运行在 $loopTestnetBadgeLabel，'
                  '$loopLaunchTestnetChainId，主网功能不受影响',
            ),
          ],
        ),
        const LoopTestnetNotice(visible: true),
      ],
    );
  }
}
