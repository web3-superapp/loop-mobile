import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// Shared scaffolding for the six read-only launch record pages.
///
/// Each page owns its own capability gate, its own five states and its own
/// subject; a failing block never blanks a sibling that did load.
abstract class _LaunchRecordScreen extends ConsumerStatefulWidget {
  const _LaunchRecordScreen({super.key, this.launchId, this.onBack});

  final String? launchId;
  final VoidCallback? onBack;
}

/// `launch-detail` · one launch record.
class LaunchDetailScreen extends _LaunchRecordScreen {
  const LaunchDetailScreen({
    super.key,
    super.launchId,
    super.onBack,
    this.onOpenTier,
    this.onOpenRounds,
    this.onOpenTrade,
    this.onOpenHolders,
    this.onOpenGraduation,
    this.onOpenHistory,
  });

  final VoidCallback? onOpenTier;
  final VoidCallback? onOpenRounds;
  final VoidCallback? onOpenTrade;
  final VoidCallback? onOpenHolders;
  final VoidCallback? onOpenGraduation;
  final VoidCallback? onOpenHistory;

  @override
  ConsumerState<LaunchDetailScreen> createState() => _LaunchDetailScreenState();
}

class _LaunchDetailScreenState extends ConsumerState<LaunchDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchDetailControllerProvider);
    final controller = ref.read(launchDetailControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final detail = state.value;
    final config = detail?.config;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-detail-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: detail?.launch.ticker ?? '项目详情',
      onBack: widget.onBack,
      framedTools: true,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('launch-detail-rounds-action'),
          icon: 'info',
          label: '轮次规则',
          onPressed: widget.onOpenRounds,
        ),
      ],
      // `.launch-detail-composite`: the record's folio and the project's own
      // Chalk identity card are one surface, the way the prototype welds
      // them. The identity card is what the audit found missing entirely.
      primary: LoopLedgerComposite(
        ground: LoopCompositeGround.chalk,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        detailPadding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'LAUNCH RECORD',
          heading: detail?.launch.name ?? launchMissingName,
          // No countdown, no round label, no progress: all three are contract
          // facts. The caption states what the record can and cannot prove.
          caption: '项目资料与轮次配置由 LOOP 提供；链上状态、价格与毕业进度暂时读不到。',
          stamp: detail == null ? null : launchPendingConfirmationLabel,
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        detail: <Widget>[
          if (detail != null)
            LaunchIdentityStrip(
              key: const ValueKey<String>('launch-detail-identity'),
              name: detail.project.name,
              ticker: detail.project.ticker,
              narrative: detail.project.narrative,
              contractAddress: detail.launch.contractAddress,
            ),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-detail-capability-unavailable',
              ),
              title: '项目详情当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (detail == null)
          LaunchStateBlock(
            prefix: 'launch-detail',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到这个项目',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          // The record card the prototype anchors this page on: the round's
          // remaining time, the graduation track and the two figures under
          // it. None of the four has a source yet, so each prints its own em
          // dash inside the shape that will hold it.
          _LaunchRoundProgressCard(rounds: detail.rounds),
          LoopStatGrid(
            key: const ValueKey<String>('launch-detail-stats'),
            stats: launchRecordStats(),
          ),
          const LoopLabel('我的资格'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('launch-detail-open-tier'),
                leading: const LoopRowIcon(
                  icon: 'ticket',
                  tone: LoopRowIconTone.accent,
                ),
                title: '我的资格',
                // Decision 0053: the mode is read, never assumed. The row
                // states the value it has — the mode — and says so when the
                // configuration has not chosen one.
                subtitle: '资格结果 $launchPendingConfirmationLabel · 由这次发射的资格模式决定',
                subtitleMaxLines: 2,
                onTap: widget.onOpenTier,
              ),
            ],
          ),
          const LoopLabel('发射轨道'),
          _TrackBlock(
            rounds: detail.rounds,
            config: config,
            onOpenGraduation: widget.onOpenGraduation,
          ),
          _LinksBlock(links: detail.project.officialLinks),
          const LoopLabel('记录'),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('launch-detail-open-holders'),
                leading: const LoopRowIcon(icon: 'users'),
                title: '内盘持有人',
                subtitle: launchReasonCodeText(detail.holders.reasonCode),
                subtitleMaxLines: 2,
                onTap: widget.onOpenHolders,
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('launch-detail-open-history'),
                leading: const LoopRowIcon(icon: 'book'),
                title: '我的参与记录',
                subtitle: '空列表不代表你没有参与',
                onTap: widget.onOpenHistory,
                position: LoopRowPosition.last,
              ),
            ],
          ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('launch-detail-open-trade'),
                label: '进入内盘交易',
                primary: true,
                onPressed: widget.onOpenTrade,
              ),
            ],
          ),
          // The twelve key-value rows that used to fill two screens keep
          // every fact they carried, behind the prototype's own disclosure
          // control (`details.focus-disclosure`).
          LoopDisclosure(
            key: const ValueKey<String>('launch-detail-facts'),
            summary: '链上四轴与配置',
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  LaunchChainBlock(
                    testnet: launchSurfaceIsTestnet(
                      capability: capability,
                      launch: detail.launch,
                    ),
                  ),
                  const LoopLabel('链上四轴', tight: true),
                  LaunchAxisBlock(state: detail.launch.onChainState),
                  const LoopLabel('配置'),
                  if (config == null)
                    const LoopEmpty(
                      key: ValueKey<String>('launch-detail-no-config'),
                      icon: 'warn',
                      message: '还没有任何配置版本',
                      reason: '轮次、上限与费率都要等到配置版本被确认后才有数值。',
                    )
                  else
                    LoopRecordGroup(
                      key: const ValueKey<String>('launch-detail-slots'),
                      rows: <LoopRecordRow>[
                        for (
                          var index = 0;
                          index < config.slots.entries.length;
                          index += 1
                        )
                          launchConfigSlotRow(
                            label: config.slots.entries[index].$1,
                            slot: config.slots.entries[index].$2,
                            position: launchRowPosition(
                              index,
                              config.slots.entries.length,
                            ),
                          ),
                      ],
                    ),
                  if (detail.configPending != null)
                    LaunchUnavailableCard(
                      label: '已确认的配置版本',
                      fact: detail.configPending!,
                    ),
                ],
              ),
            ),
          ),
          LoopNotice(
            key: const ValueKey<String>('launch-detail-baseline-notice'),
            icon: 'shield',
            tone: LoopNoticeTone.warn,
            title: '不显示未经证明的数字',
            body:
                '${launchReasonCodeText('LAUNCH_CONTRACT_BASELINE_PENDING')}'
                '资料版本 ${detail.project.materialVersion}，'
                '登记于 ${launchTimestampLabel(detail.launch.createdAt)}。',
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `.record-card.launch-round-card`: the round clock, the graduation track
/// and the two figures beneath it.
///
/// Every one of them is a contract fact, so the card is the shape of four
/// answers that do not exist yet: the clock prints the em dash, the track is
/// drawn empty rather than at zero, and the reason is stated once, under the
/// card, for all four.
class _LaunchRoundProgressCard extends StatelessWidget {
  const _LaunchRoundProgressCard({required this.rounds});

  final List<LaunchRound> rounds;

  @override
  Widget build(BuildContext context) {
    final first = rounds.isEmpty ? null : rounds.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: LoopRecordCard(
        key: const ValueKey<String>('launch-detail-round-card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        first == null ? '本轮剩余' : 'Round ${first.roundIndex} 剩余',
                        style: LoopTypography.caption(
                          11,
                          color: LoopColors.text3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        launchMissingFigure,
                        style: LoopTypography.figure(
                          28,
                          height: 1.05,
                          color: LoopColors.lime,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const LoopBadge(
                  launchPendingConfirmationLabel,
                  kind: LoopBadgeKind.mute,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const LoopProgressBar(value: null, semanticLabel: '毕业进度暂时读不到'),
            const SizedBox(height: 8),
            Text(
              '市值 $launchMissingFigure / 毕业线 $launchMissingFigure',
              style: LoopTypography.caption(11, color: LoopColors.text2),
            ),
          ],
        ),
      ),
    );
  }
}

/// `launch-detail` 发射轨道 / `launch-rounds` Access Timeline.
///
/// The rounds come from the configuration — `1..N`, never a fixed three — and
/// the graduation step closes the track. The last row is the way into
/// `launch-graduation`, which is where the prototype's 毕业 line leads.
class _TrackBlock extends StatelessWidget {
  const _TrackBlock({
    required this.rounds,
    required this.config,
    this.onOpenGraduation,
  });

  final List<LaunchRound> rounds;
  final LaunchConfig? config;
  final VoidCallback? onOpenGraduation;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('launch-track-empty'),
        icon: 'warn',
        message: '还没有配置任何轮次',
        reason: '轮次数量由每次发射自己决定。',
      );
    }
    final fee = launchFeeLabel(config);
    final length = rounds.length + 1;
    return LoopRecordGroup(
      key: const ValueKey<String>('launch-track'),
      rows: <LoopRecordRow>[
        for (var index = 0; index < rounds.length; index += 1)
          launchTrackRow(
            round: rounds[index],
            feeLabel: fee,
            position: launchRowPosition(index, length),
          ),
        LoopRecordRow(
          key: const ValueKey<String>('launch-track-graduation'),
          leading: const LoopMonoTile(label: 'END'),
          title: '毕业与迁移',
          subtitle: '达到毕业条件后由服务端权威状态推进',
          trailingBadge: const LoopBadge('待触发', kind: LoopBadgeKind.mute),
          onTap: onOpenGraduation,
          position: launchRowPosition(length - 1, length),
          semanticLabel: '毕业与迁移，待触发',
        ),
      ],
    );
  }
}

/// `Access Timeline`: the configured rounds in opening order.
///
/// The leading tile is the round's own opening time — the prototype's
/// `00:00 / 01:00 / 05:00` column — not its ordinal, because the timeline's
/// subject is when access opens. A round whose configuration has not fixed
/// the time keeps the placeholder tile.
class _AccessTimeline extends StatelessWidget {
  const _AccessTimeline({required this.rounds, required this.config});

  final List<LaunchRound> rounds;
  final LaunchConfig? config;

  @override
  Widget build(BuildContext context) {
    if (rounds.isEmpty) {
      return const LoopEmpty(
        key: ValueKey<String>('launch-rounds-empty'),
        icon: 'warn',
        message: '还没有配置任何轮次',
        reason: '轮次数量由每次发射自己决定。',
      );
    }
    final fee = launchFeeLabel(config);
    return LoopRecordGroup(
      key: const ValueKey<String>('launch-rounds-list'),
      rows: <LoopRecordRow>[
        for (var index = 0; index < rounds.length; index += 1)
          launchTrackRow(
            round: rounds[index],
            feeLabel: fee,
            keyPrefix: 'launch-round',
            position: launchRowPosition(index, rounds.length),
          ),
      ],
    );
  }
}

class _LinksBlock extends StatelessWidget {
  const _LinksBlock({required this.links});

  final LaunchOfficialLinks links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();
    // `.segs` of link chips, the way the prototype ends the record. The URL
    // itself was a key-value row nobody could tap; the chip names the venue.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopLabel('链接'),
        LoopChipRow(
          children: <Widget>[
            for (final entry in links.entries)
              LoopSeg(
                key: ValueKey<String>('launch-link-${entry.$1}'),
                label: entry.$1,
                selected: false,
                onSelected: null,
                onBlocked: null,
              ),
          ],
        ),
      ],
    );
  }
}

/// `launch-rounds` · the configured round slots for one launch.
class LaunchRoundsScreen extends _LaunchRecordScreen {
  const LaunchRoundsScreen({super.key, super.launchId, super.onBack});

  @override
  ConsumerState<LaunchRoundsScreen> createState() => _LaunchRoundsScreenState();
}

class _LaunchRoundsScreenState extends ConsumerState<LaunchRoundsScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchDetailControllerProvider);
    final controller = ref.read(launchDetailControllerProvider.notifier);
    // No subject is not a missing launch. Reading the page without a launch id
    // used to report 「目标不存在、已被移除，或对当前账号不可见」 with a retry
    // that could never change the answer; the page says what it needs instead.
    final subject = widget.launchId;
    if (!blocked && subject != null && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(subject));
      });
    }
    final detail = subject == null ? null : state.value;
    final config = detail?.config;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-rounds-screen'),
      onRefresh: subject == null ? null : controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '销售轮次规则',
      kicker: 'ROUND CONFIGURATION',
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'ROUND CONFIGURATION',
          // The number of rounds comes from the configuration, never from a
          // fixed three-round story.
          heading: detail == null
              ? launchMissingHeading
              : '${detail.rounds.length} 个轮次',
          caption: '轮数、时间、价格、资格与上限都由这次发射的配置决定；还没确认的显示为待确认。',
          stamp: detail == null ? null : launchPendingConfirmationLabel,
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        // `.ledger-composite-detail`: the sentence the prototype welds under
        // this folio, with the two figures it quotes. Both are contract facts
        // and both print the em dash.
        detail: const <Widget>[
          LoopCompositeDetailNote('准入逐步开放，合约规则不因用户改变'),
          LoopHairline(),
          LoopCompositeDetailRow(
            label: '总量',
            value: loopFigureDash,
            valueSize: 18,
            trailingLabel: '毕业线',
            trailingValue: loopFigureDash,
            spoken: launchPendingConfirmationLabel,
          ),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-rounds-capability-unavailable',
              ),
              title: '轮次规则当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (subject == null)
          const LoopEmpty(
            key: ValueKey<String>('launch-rounds-no-subject'),
            message: '还没有选定要看哪次发射',
            reason:
                '轮次配置属于某一次具体发射，不是全站统一的规则。'
                '回到 Launch 目录打开一个项目，再看它的轮次配置。',
          )
        else if (detail == null)
          LaunchStateBlock(
            prefix: 'launch-rounds',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到轮次配置',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('Access Timeline'),
          _AccessTimeline(rounds: detail.rounds, config: config),
          const LoopLabel('Contract Limits'),
          if (config == null)
            const LoopEmpty(
              key: ValueKey<String>('launch-rounds-no-config'),
              icon: 'warn',
              message: '还没有任何配置版本',
              reason: '上限与费率要等到配置版本被确认后才有数值。',
            )
          else ...<Widget>[
            LaunchCapCard(config: config),
            // The six remaining slots keep the same row and the same 待确认
            // wording, behind the disclosure the prototype uses for the parts
            // of a rule page that are not the rule itself.
            LoopDisclosure(
              key: const ValueKey<String>('launch-rounds-facts'),
              summary: '其余合约参数',
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    LaunchChainBlock(
                      testnet: launchSurfaceIsTestnet(
                        capability: capability,
                        launch: detail.launch,
                      ),
                    ),
                    LoopRecordGroup(
                      key: const ValueKey<String>('launch-rounds-slots'),
                      rows: <LoopRecordRow>[
                        for (
                          var index = 0;
                          index < config.slots.entries.length;
                          index += 1
                        )
                          launchConfigSlotRow(
                            label: config.slots.entries[index].$1,
                            slot: config.slots.entries[index].$2,
                            position: launchRowPosition(
                              index,
                              config.slots.entries.length,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (detail.configPending != null)
            LaunchUnavailableCard(
              label: '已确认的配置版本',
              fact: detail.configPending!,
            ),
          LoopNotice(
            key: const ValueKey<String>('launch-rounds-notice'),
            icon: 'shield',
            tone: LoopNoticeTone.warn,
            title: '以最终确认的规则为准',
            body:
                '本页不写入任何固定的轮数、手续费率、持仓上限或毕业市值。'
                '${launchReasonCodeText('LAUNCH_CONFIG_PENDING_CONFIRMATION')}',
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `launch-graduation` · the four migration steps.
class LaunchGraduationScreen extends _LaunchRecordScreen {
  const LaunchGraduationScreen({super.key, super.launchId, super.onBack});

  @override
  ConsumerState<LaunchGraduationScreen> createState() =>
      _LaunchGraduationScreenState();
}

class _LaunchGraduationScreenState
    extends ConsumerState<LaunchGraduationScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchDetailControllerProvider);
    final controller = ref.read(launchDetailControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final detail = state.value;
    final steps = detail?.graduation.steps ?? const <LaunchGraduationStep>[];

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-graduation-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '毕业与迁移',
      kicker: 'GRADUATION PROGRESS',
      onBack: widget.onBack,
      primary: const LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'GRADUATION PROGRESS',
          // Never a percentage: progress needs the liquidity axis.
          heading: launchMissingHeading,
          caption: '毕业进度看的是流动性。合约上线前还没有可核对的进度。',
          stamp: 'PENDING',
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        // The prototype's progress rail. It is drawn empty rather than at
        // zero: no liquidity reading exists, and a zero-width bar would be a
        // figure nobody measured.
        detail: <Widget>[
          LoopProgressBar(value: null, semanticLabel: '毕业进度暂时读不到'),
          LoopHairline(),
          LoopCompositeDetailNote(
            '市值 $launchMissingFigure / 毕业线 $launchMissingFigure · 达线后立即触发迁移',
          ),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-graduation-capability-unavailable',
              ),
              title: '毕业进度当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (detail == null)
          LaunchStateBlock(
            prefix: 'launch-graduation',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到毕业记录',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('Migration Rail'),
          LoopRecordGroup(
            key: const ValueKey<String>('launch-graduation-steps'),
            rows: <LoopRecordRow>[
              for (var index = 0; index < steps.length; index += 1)
                LoopRecordRow(
                  key: ValueKey<String>(
                    'launch-graduation-step-${steps[index].step.wireName}',
                  ),
                  leading: LoopMonoTile(
                    label: (index + 1).toString().padLeft(2, '0'),
                  ),
                  title: launchGraduationStepLabel(steps[index].step),
                  // Each step says what it does. The rail's own property —
                  // one step at a time — is stated once, in the notice below.
                  subtitle: launchGraduationStepDetail(steps[index].step),
                  subtitleMaxLines: 2,
                  trailingBadge: const LoopBadge(
                    '待触发',
                    kind: LoopBadgeKind.mute,
                  ),
                  position: launchRowPosition(index, steps.length),
                  semanticLabel:
                      '${launchGraduationStepLabel(steps[index].step)}，'
                      '${launchGraduationStepDetail(steps[index].step)}，待触发',
                ),
            ],
          ),
          const LoopLabel('流动性池'),
          LaunchUnavailableCard(
            label: '池地址与锁定信息',
            fact: detail.graduation.poolEvidence,
          ),
          LoopNotice(
            key: const ValueKey<String>('launch-graduation-notice'),
            icon: 'shield',
            tone: LoopNoticeTone.warn,
            title: '毕业不是排期状态',
            body:
                '「已结束」只表示排期结束，不等于已毕业。'
                '是否毕业要看流动性和交易池，两项目前都读不到。'
                '迁移由服务端权威状态推进，每一步完成后才进入下一步。',
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `launch-tier` · the eligibility result for one launch.
class LaunchTierScreen extends _LaunchRecordScreen {
  const LaunchTierScreen({
    super.key,
    super.launchId,
    super.onBack,
    this.onOpenStake,
  });

  final VoidCallback? onOpenStake;

  @override
  ConsumerState<LaunchTierScreen> createState() => _LaunchTierScreenState();
}

class _LaunchTierScreenState extends ConsumerState<LaunchTierScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchEligibilityControllerProvider);
    final controller = ref.read(launchEligibilityControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final eligibility = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-tier-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '我的资格',
      kicker: 'ELIGIBILITY',
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'ELIGIBILITY',
          // The tier is `null` by contract: the heading says it has no value,
          // never a guessed "Public".
          heading: eligibility?.tier ?? launchMissingResult,
          caption: '这是当前资格结果，不是等级；条件与快照时间同时展示。',
          stamp: eligibility == null
              ? null
              : launchEligibilityModeLabel(eligibility.mode),
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        // The two conditions behind the result. Neither restates it: the
        // heading is the answer, the strip is what produced it.
        detail: <Widget>[
          if (eligibility != null)
            LoopCompositeDetailRow(
              key: const ValueKey<String>('launch-tier-conditions'),
              label: '资格模式',
              value: launchEligibilityModeLabel(eligibility.mode),
              valueSize: 18,
              trailingLabel: '快照区块',
              trailingValue: eligibility.snapshotBlock ?? loopFigureDash,
              spoken: eligibility.snapshotBlock == null
                  ? launchPendingConfirmationLabel
                  : null,
            ),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>('launch-tier-capability-unavailable'),
              title: '资格查询当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (eligibility == null)
          LaunchStateBlock(
            prefix: 'launch-tier',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '没有读到资格结果',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('launch-tier-open-stake'),
                label: '查看 LOOP 质押',
                primary: true,
                onPressed: widget.onOpenStake,
              ),
            ],
          ),
          const LoopLabel('资格模式'),
          LoopRecordGroup(
            key: const ValueKey<String>('launch-tier-mode'),
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: ValueKey<String>(
                  'launch-tier-mode-${eligibility.mode.wireName}',
                ),
                title: launchEligibilityModeLabel(eligibility.mode),
                subtitle: launchEligibilityModeDescription(eligibility.mode),
                trailingBadge: LoopBadge(
                  eligibility.mode == LaunchEligibilityMode.unavailable
                      ? '未配置'
                      : '已配置',
                  kind: eligibility.mode == LaunchEligibilityMode.unavailable
                      ? LoopBadgeKind.mute
                      : LoopBadgeKind.launch,
                ),
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('launch-tier-config-version'),
                title: '资格规则',
                // The version that carries the rule is a backend identifier;
                // when it takes effect is the part a reader can use.
                subtitle: eligibility.effectiveAt == null
                    ? '尚未生效'
                    : '生效于 ${launchTimestampLabel(eligibility.effectiveAt!)}',
                position: LoopRowPosition.middle,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('launch-tier-depends-on-staking'),
                title: '是否依赖质押',
                // Decision 0053: the mode decides. The row reports what this
                // launch's approved mode answered, and claims nothing about
                // the next one.
                subtitle: '由这次发射的资格模式决定',
                trailing: eligibility.dependsOnStaking ? '是' : '否',
                position: LoopRowPosition.last,
              ),
            ],
          ),
          LoopNotice(
            key: const ValueKey<String>('launch-tier-result'),
            icon: 'ticket',
            title: '资格不是等级，也不是权益',
            body:
                '${launchReasonCodeText(eligibility.reasonCode)}'
                '资格是这次发射的准入结果，会随配置和快照变化；'
                '这里不显示任何门槛、费率或时间窗口。',
            margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `launch-holders` · internal-market holder distribution.
class LaunchHoldersScreen extends _LaunchRecordScreen {
  const LaunchHoldersScreen({super.key, super.launchId, super.onBack});

  @override
  ConsumerState<LaunchHoldersScreen> createState() =>
      _LaunchHoldersScreenState();
}

class _LaunchHoldersScreenState extends ConsumerState<LaunchHoldersScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchHoldersControllerProvider);
    final controller = ref.read(launchHoldersControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final holders = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-holders-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '内盘持有人',
      kicker: 'HOLDER DISTRIBUTION',
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: const LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'HOLDER DISTRIBUTION',
          heading: launchMissingHeading,
          caption: '持有人数量、集中度、我的仓位与单地址上限都需要合约读数，当前全部不可得。',
          stamp: 'UNAVAILABLE',
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        // `.launch-holders-summary`: concentration and the cap, side by side,
        // the two readings the prototype welds under this folio.
        detail: <Widget>[
          LoopCompositeDetailRow(
            label: 'Top 10 合计',
            value: loopFigureDash,
            valueSize: 18,
            trailingLabel: '单地址持仓上限',
            trailingValue: loopFigureDash,
            spoken: holders == null
                ? launchPendingConfirmationLabel
                : launchReasonCodeText(holders.walletCap.reasonCode),
          ),
          const LoopHairline(),
          const LoopCompositeDetailNote('上限由 LOOP 内盘合约执行'),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-holders-capability-unavailable',
              ),
              title: '持有人分布当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (holders == null)
          LaunchStateBlock(
            prefix: 'launch-holders',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '没有读到持有人记录',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('Top Holders'),
          // The ranking has no source, so no address is invented. The one row
          // the reader owns keeps its place in the list, with the Lime `YOU`
          // tile the prototype marks it with, and its figures as em dashes.
          LoopRecordGroup(
            key: const ValueKey<String>('launch-holders-list'),
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('launch-holders-me'),
                leading: const LoopMonoTile(label: 'YOU', accent: true),
                title: '我的仓位',
                subtitle: '持仓 $launchMissingFigure · 还可买 $launchMissingFigure',
                trailing: launchMissingFigure,
                semanticLabel:
                    '我的仓位，'
                    '${launchReasonCodeText(holders.myPosition.reasonCode)}',
              ),
            ],
          ),
          LaunchUnavailableCard(label: '持有人分布', fact: holders.holders),
          const LoopNotice(
            key: ValueKey<String>('launch-holders-notice'),
            icon: 'chart',
            title: '空白不是「没有持有人」',
            body: '暂时读不到合约信息，因此不显示地址、比例或上限。读不到不等于「分布为零」。',
            margin: EdgeInsets.fromLTRB(16, 22, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

/// `launch-history` · my participation records for one launch.
class LaunchHistoryScreen extends _LaunchRecordScreen {
  const LaunchHistoryScreen({super.key, super.launchId, super.onBack});

  @override
  ConsumerState<LaunchHistoryScreen> createState() =>
      _LaunchHistoryScreenState();
}

class _LaunchHistoryScreenState extends ConsumerState<LaunchHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final blocked = launchCapabilityBlocks(capability);
    final state = ref.watch(launchHistoryControllerProvider);
    final controller = ref.read(launchHistoryControllerProvider.notifier);
    if (!blocked && state.phase == LaunchViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(widget.launchId));
      });
    }
    final history = state.value;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-history-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '我的参与记录',
      kicker: 'PARTICIPATION LOG',
      onBack: widget.onBack,
      primary: const LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'PARTICIPATION LOG',
          heading: launchMissingHeading,
          caption: '购买、权益与退款记录都要看链上数据，目前读不到，因此不显示笔数或盈亏。',
          stamp: 'UNAVAILABLE',
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        detail: <Widget>[
          LoopCompositeDetailRow(
            label: '参与次数',
            value: loopFigureDash,
            valueSize: 18,
            trailingLabel: '累计结果',
            trailingValue: loopFigureDash,
            spoken: launchPendingConfirmationLabel,
          ),
          LoopHairline(),
          LoopCompositeDetailNote('内盘与毕业后记录统一归档'),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-history-capability-unavailable',
              ),
              title: '参与记录当前不可用',
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (history == null)
          LaunchStateBlock(
            prefix: 'launch-history',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '没有读到参与记录',
            emptyReason: '项目可能不存在，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          const LoopLabel('Records'),
          LaunchUnavailableCard(label: '购买、权益与退款记录', fact: history.source),
          const LoopNotice(
            key: ValueKey<String>('launch-history-notice'),
            icon: 'info',
            title: '空列表不代表没有参与',
            body: '这里是「暂时读不到」，不是「没有记录」。合约上线后才会出现可核对的购买、权益与退款。',
            margin: EdgeInsets.fromLTRB(16, 22, 16, 0),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
