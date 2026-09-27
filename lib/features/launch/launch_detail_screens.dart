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

/// The 内盘持有人 row on `launch-detail`, following the holders resource
/// branch by branch (decision 0091).
///
/// Only `LAUNCH_CONTRACT_BASELINE_PENDING` may say the contract is not live;
/// an index that has not caught up says so, and any other reason is a plain
/// "cannot read". A count is distinct buyers (decision 0089), never holders.
String launchHoldersRowText(LaunchResourceState<LaunchHolders> state) {
  final holders = state.value;
  if (holders == null) {
    return state.phase == LaunchViewPhase.loading ? '正在读取参与人数' : '参与人数暂时读不到';
  }
  return switch (holders.holders) {
    LaunchReadingAvailable<LaunchHolderCount>(:final value) =>
      '${loopGroupedFigure(value.holderCount.toString())} 位参与者',
    LaunchReadingUnavailable<LaunchHolderCount>(:final reasonCode) =>
      switch (reasonCode) {
        'LAUNCH_CONTRACT_BASELINE_PENDING' => 'Launch 合约还没有上线，参与人数暂时不可用。',
        'LAUNCH_ONCHAIN_STATE_NOT_INDEXED' ||
        'LAUNCH_ONCHAIN_STATE_NOT_PROJECTED' => '链上记录索引中，参与人数稍后可见。',
        _ => '参与人数暂时读不到',
      },
  };
}

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
    final onChain = detail?.onChain;
    // Decision 0091: the detail payload's own `holders` slot is a fixed
    // placeholder, so the row reads the holders resource the 内盘持有人 page
    // reads, and follows its branch.
    final holdersState = ref.watch(launchHoldersControllerProvider);
    if (!blocked &&
        detail != null &&
        holdersState.phase == LaunchViewPhase.loading &&
        holdersState.value == null) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(launchHoldersControllerProvider.notifier)
                .open(widget.launchId),
          );
        }
      });
    }

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-detail-screen'),
      onRefresh: () => Future.wait(<Future<void>>[
        controller.reload(),
        // `reload` needs the launch the resource was opened for; before
        // that, opening it is the read.
        if (!blocked)
          holdersState.isReady
              ? ref.read(launchHoldersControllerProvider.notifier).reload()
              : ref
                    .read(launchHoldersControllerProvider.notifier)
                    .open(widget.launchId),
      ]),
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
          framed: true,
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
          caption: onChain == null
              ? '项目资料与轮次配置由 LOOP 提供；链上状态、价格与毕业进度暂时读不到。'
              : '${launchStateProjection(onChain)}。四轴、轮次与参数读自区块 '
                    '${loopGroupedFigure(onChain.snapshotBlockNumber)}。',
          stamp: detail == null
              ? null
              : onChain == null
              ? launchPendingConfirmationLabel
              : launchAxesBadge(onChain),
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
          _LaunchRoundProgressCard(detail: detail),
          LoopStatGrid(
            key: const ValueKey<String>('launch-detail-stats'),
            stats: launchRecordStats(price: launchCurrentPriceLabel(detail)),
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
            chainRounds: detail.chainRounds,
            onChain: detail.onChain,
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
                subtitle: launchHoldersRowText(holdersState),
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
                  if (detail.saleConfig != null)
                    LaunchSaleConfigGroup(
                      key: const ValueKey<String>('launch-detail-sale-config'),
                      config: detail.saleConfig!,
                    )
                  else if (config == null)
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
            tone: onChain == null ? LoopNoticeTone.warn : LoopNoticeTone.normal,
            title: onChain == null ? '不显示未经证明的数字' : '链上读数来自同一区块',
            body:
                '${onChain == null ? launchReasonCodeText(detail.launch.onChainState.reasonCode) : '四轴、轮次与合约参数都读自区块 ${loopGroupedFigure(onChain.snapshotBlockNumber)}，状态摘要 ${launchShortHex(onChain.stateTupleDigest)}。'}'
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

/// `.record-card.launch-round-card`: the round, its window and what the
/// sale has raised against its hard cap.
///
/// Read on chain, the card names the first round that has not closed, when it
/// closes, and raised / hard cap at the snapshot block. Unreadable, it is the
/// shape of answers that do not exist yet: the em dash, an empty track, and
/// the reason stated once under the card.
class _LaunchRoundProgressCard extends StatelessWidget {
  const _LaunchRoundProgressCard({required this.detail});

  final LaunchDetail detail;

  @override
  Widget build(BuildContext context) {
    final chain = detail.chainRounds;
    final config = detail.saleConfig;
    final LaunchChainRound? current = chain.isEmpty ? null : chain.first;
    final first = detail.rounds.isEmpty ? null : detail.rounds.first;
    final index = current?.roundIndex ?? first?.roundIndex;
    BigInt? raised;
    for (final round in chain) {
      raised = (raised ?? BigInt.zero) + BigInt.parse(round.raisedUsd1);
    }
    double? progress;
    if (raised != null && config != null) {
      final cap = BigInt.parse(config.hardCapUsd1);
      if (cap > BigInt.zero) {
        // Pixel space only; the figures on screen stay exact strings.
        progress = (raised * BigInt.from(10000) ~/ cap).toInt() / 10000;
        if (progress > 1) progress = 1;
      }
    }
    final onChain = detail.onChain;
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
                        index == null
                            ? '本轮截止'
                            : current == null
                            ? 'Round $index 剩余'
                            : 'Round $index 截止',
                        style: LoopTypography.caption(
                          11,
                          color: LoopColors.text3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // Lime at 28px turns the em dash into a stray green
                        // rule: the clock keeps the neutral weight.
                        current == null
                            ? launchMissingFigure
                            : launchTimestampLabel(current.endAt),
                        style: LoopTypography.figure(
                          current == null ? 24 : 16,
                          height: 1.05,
                          color: LoopColors.chalk,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                LoopBadge(
                  onChain == null
                      ? launchPendingConfirmationLabel
                      : launchAxesBadge(onChain),
                  kind: onChain == null
                      ? LoopBadgeKind.mute
                      : LoopBadgeKind.launch,
                ),
              ],
            ),
            const SizedBox(height: 10),
            LoopProgressBar(
              value: progress,
              semanticLabel: progress == null ? '毕业进度暂时读不到' : '已募集占硬顶的比例',
            ),
            const SizedBox(height: 8),
            Text(
              raised == null || config == null
                  ? '市值 $launchMissingFigure / 毕业线 $launchMissingFigure'
                  : '已募集 ${launchUsd1Label(raised.toString())} / '
                        '硬顶 ${launchUsd1Label(config.hardCapUsd1)}',
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
    required this.chainRounds,
    required this.onChain,
    required this.config,
    this.onOpenGraduation,
  });

  final List<LaunchRound> rounds;
  final List<LaunchChainRound> chainRounds;
  final LaunchOnChainAvailable? onChain;
  final LaunchConfig? config;
  final VoidCallback? onOpenGraduation;

  @override
  Widget build(BuildContext context) {
    if (chainRounds.isNotEmpty) {
      final length = chainRounds.length + 1;
      return LoopRecordGroup(
        key: const ValueKey<String>('launch-track'),
        rows: <LoopRecordRow>[
          for (var index = 0; index < chainRounds.length; index += 1)
            launchChainRoundRow(
              round: chainRounds[index],
              keyPrefix: 'launch-track',
              position: launchRowPosition(index, length),
            ),
          _graduationRow(length),
        ],
      );
    }
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
        _graduationRow(length),
      ],
    );
  }

  LoopRecordRow _graduationRow(int length) {
    final state = onChain;
    final badge = state == null
        ? '待触发'
        : launchGraduationProjection(state) ?? '待触发';
    return LoopRecordRow(
      key: const ValueKey<String>('launch-track-graduation'),
      leading: const LoopMonoTile(label: 'END'),
      title: '毕业与迁移',
      subtitle: '达到毕业条件后由服务端权威状态推进',
      trailingBadge: LoopBadge(
        badge,
        kind: badge == '待触发' ? LoopBadgeKind.mute : LoopBadgeKind.launch,
      ),
      onTap: onOpenGraduation,
      position: launchRowPosition(length - 1, length),
      semanticLabel: '毕业与迁移，$badge',
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
    final saleConfig = detail?.saleConfig;
    final chainRounds = detail?.chainRounds ?? const <LaunchChainRound>[];

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-rounds-screen'),
      onRefresh: subject == null ? null : controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '销售轮次规则',
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
              : chainRounds.isNotEmpty
              ? '${chainRounds.length} 个轮次'
              : '${detail.rounds.length} 个轮次',
          caption: chainRounds.isNotEmpty
              ? '轮次、时间窗、价格与上限读自合约，区块 '
                    '${loopGroupedFigure(detail!.onChain!.snapshotBlockNumber)}。'
              : '轮数、时间、价格、资格与上限都由这次发射的配置决定；还没确认的显示为待确认。',
          stamp: detail == null
              ? null
              : chainRounds.isNotEmpty
              ? 'ON CHAIN'
              : launchPendingConfirmationLabel,
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        // `.ledger-composite-detail`: the sentence the prototype welds under
        // this folio, with the two caps the contract fixes, or the em dash
        // while no contract configuration was read.
        detail: <Widget>[
          const LoopCompositeDetailNote('准入逐步开放，合约规则不因用户改变'),
          const LoopHairline(),
          if (saleConfig == null)
            const LoopCompositeDetailRow(
              label: '总量',
              value: loopFigureDash,
              valueSize: 18,
              trailingLabel: '毕业线',
              trailingValue: loopFigureDash,
              spoken: launchPendingConfirmationLabel,
            )
          else
            LoopCompositeDetailRow(
              key: const ValueKey<String>('launch-rounds-caps-chain'),
              label: '硬顶',
              value: launchUsd1Label(saleConfig.hardCapUsd1),
              valueSize: 15,
              trailingLabel: '软顶',
              trailingValue: launchUsd1Label(saleConfig.softCapUsd1),
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
          if (chainRounds.isNotEmpty)
            LoopRecordGroup(
              key: const ValueKey<String>('launch-rounds-list'),
              rows: <LoopRecordRow>[
                for (var index = 0; index < chainRounds.length; index += 1)
                  launchChainRoundRow(
                    round: chainRounds[index],
                    position: launchRowPosition(index, chainRounds.length),
                  ),
              ],
            )
          else
            _AccessTimeline(rounds: detail.rounds, config: config),
          const LoopLabel('Contract Limits'),
          if (saleConfig != null) ...<Widget>[
            LaunchChainCapCard(config: saleConfig, rounds: chainRounds),
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
                    LaunchSaleConfigGroup(
                      key: const ValueKey<String>('launch-rounds-sale-config'),
                      config: saleConfig,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (config == null)
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
            title: saleConfig == null ? '以最终确认的规则为准' : '以签名前的合约读数为准',
            body: saleConfig == null
                ? '本页不写入任何固定的轮数、手续费率、持仓上限或毕业市值。'
                      '${launchReasonCodeText('LAUNCH_CONFIG_PENDING_CONFIRMATION')}'
                : '本页的数字是合约在快照区块的读数，不是 LOOP 写下的规则。'
                      '认购时以签名前复核的读数为准。',
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
    final onChain = detail?.onChain;
    // Each step's progress is derived from the liquidity and entitlement
    // axes alone; the wire `status` stays `pending` in every schema.
    final progress = <LaunchGraduationProgress>[
      for (final step in steps)
        onChain == null
            ? LaunchGraduationProgress.pending
            : launchGraduationStepProgress(step.step, onChain),
    ];
    final done = progress
        .where((value) => value == LaunchGraduationProgress.done)
        .length;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-graduation-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '毕业与迁移',
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'GRADUATION PROGRESS',
          // Never a percentage: progress is a count of steps the liquidity
          // and entitlement axes prove, and nothing without them.
          heading: onChain == null
              ? launchMissingHeading
              : launchGraduationProjection(onChain) ?? '$done / 4 步',
          caption: onChain == null
              ? '毕业进度看的是流动性。合约上线前还没有可核对的进度。'
              : '${launchStateProjection(onChain)}。步骤只由流动性与权益两条轴推导。',
          stamp: onChain == null ? 'PENDING' : 'ON CHAIN',
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        // The prototype's progress rail. Unreadable, it is drawn empty rather
        // than at zero: a zero-width bar would be a figure nobody measured.
        detail: <Widget>[
          LoopProgressBar(
            key: const ValueKey<String>('launch-graduation-bar'),
            value: onChain == null || steps.isEmpty
                ? null
                : done / steps.length,
            semanticLabel: onChain == null
                ? '毕业进度暂时读不到'
                : '已完成 $done 步，共 ${steps.length} 步',
          ),
          const LoopHairline(),
          LoopCompositeDetailNote(
            onChain == null
                ? '市值 $launchMissingFigure / 毕业线 $launchMissingFigure · 达线后立即触发迁移'
                : '快照区块 ${loopGroupedFigure(onChain.snapshotBlockNumber)} · '
                      '流动性 ${onChain.liquidityState.wireName} · '
                      '权益 ${onChain.entitlementState.wireName}',
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
                  trailingBadge: LoopBadge(
                    progress[index].label,
                    kind:
                        progress[index] == LaunchGraduationProgress.done ||
                            progress[index] == LaunchGraduationProgress.active
                        ? LoopBadgeKind.launch
                        : LoopBadgeKind.mute,
                  ),
                  position: launchRowPosition(index, steps.length),
                  semanticLabel:
                      '${launchGraduationStepLabel(steps[index].step)}，'
                      '${launchGraduationStepDetail(steps[index].step)}，'
                      '${progress[index].label}',
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
            body: onChain == null
                ? '「已结束」只表示排期结束，不等于已毕业。'
                      '是否毕业要看流动性和交易池，两项目前都读不到。'
                      '迁移由服务端权威状态推进，每一步完成后才进入下一步。'
                : '「已结束」只表示排期结束，不等于已毕业。'
                      'V3 池上线不代表 LP 已锁定；只有 LP_LOCKED 或 COMPLETED '
                      '才算已毕业。每一步完成后才进入下一步。',
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
    final evaluated = eligibility?.evaluated;
    final tier = eligibility?.tier;

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-tier-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '我的资格',
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'ELIGIBILITY',
          // No evaluator: the heading says there is no value, never a guessed
          // "Public". An evaluator that answered `null` is "not listed".
          heading: evaluated == null
              ? launchMissingResult
              : tier == null
              ? '不在名单'
              : launchTierLabel(tier),
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
              trailingValue: eligibility.snapshotBlock == null
                  ? loopFigureDash
                  : loopGroupedFigure(eligibility.snapshotBlock!),
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
          // Decision 0091: the staking entry is offered only when this
          // launch's approved mode says eligibility depends on it. Otherwise
          // a primary 「查看 LOOP 质押」 would suggest a link that is not there.
          if (eligibility.dependsOnStaking)
            LoopButtonPair(
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('launch-tier-open-stake'),
                  label: '查看 LOOP 质押',
                  primary: true,
                  onPressed: widget.onOpenStake,
                ),
              ],
            )
          else
            Padding(
              key: const ValueKey<String>('launch-tier-staking-independent'),
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                LoopSpacing.tight,
                LoopSpacing.page,
                0,
              ),
              child: Text(
                '本次发射的资格不依赖 LOOP 质押',
                style: LoopTypography.caption(12, color: LoopColors.text2),
              ),
            ),
          if (evaluated != null) ...<Widget>[
            const LoopLabel('资格结果'),
            LoopRecordGroup(
              key: const ValueKey<String>('launch-tier-result-rows'),
              rows: <LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('launch-tier-round'),
                  title: '适用轮次',
                  trailing: 'Round ${evaluated.roundIndex}',
                  position: LoopRowPosition.first,
                  chevron: false,
                ),
                LoopRecordRow(
                  key: const ValueKey<String>('launch-tier-root'),
                  title: '名单根',
                  subtitle: evaluated.rootIsZero ? '该轮不设资格' : '按快照区块算出的名单',
                  trailing: evaluated.rootIsZero
                      ? '无'
                      : launchShortHex(evaluated.allowlistRoot),
                  position: LoopRowPosition.middle,
                  chevron: false,
                ),
                LoopRecordRow(
                  key: const ValueKey<String>('launch-tier-proof'),
                  title: '资格证明',
                  subtitle: '认购时原样交给合约校验',
                  trailing: '${evaluated.eligibilityProof.length} 条',
                  position: LoopRowPosition.last,
                  chevron: false,
                ),
              ],
            ),
          ],
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
                '${eligibility.reasonCode == null ? '' : launchReasonCodeText(eligibility.reasonCode)}'
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
    final count = switch (holders?.holders) {
      LaunchReadingAvailable<LaunchHolderCount>(:final value) => value,
      _ => null,
    };
    final position = switch (holders?.myPosition) {
      LaunchReadingAvailable<LaunchPosition>(:final value) => value,
      _ => null,
    };
    final cap = switch (holders?.walletCap) {
      LaunchReadingAvailable<LaunchWalletCap>(:final value) => value,
      _ => null,
    };

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-holders-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '内盘持有人',
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'HOLDER DISTRIBUTION',
          heading: count == null
              ? launchMissingHeading
              // Decision 0077 ruling 7 / 0089: `holderCount` counts distinct
              // buyers, not the wallets holding the token today.
              : '${loopGroupedFigure(count.holderCount.toString())} 位参与者',
          caption: count == null
              ? '参与人数、集中度、我的仓位与单地址上限都需要合约读数，当前全部不可得。'
              : '参与人数是在内盘买过的不同地址数，不是当前持币人数；'
                    '来自链上索引，索引到区块 '
                    '${loopGroupedFigure(count.indexedBlockNumber)}。',
          stamp: count == null ? 'UNAVAILABLE' : 'INDEXED',
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        // `.launch-holders-summary`: concentration and the cap, side by side.
        // Concentration has no source in any schema, so it keeps the em dash.
        detail: <Widget>[
          LoopCompositeDetailRow(
            label: 'Top 10 合计',
            value: loopFigureDash,
            valueSize: 18,
            trailingLabel: '单地址持仓上限',
            trailingValue: cap == null
                ? loopFigureDash
                : launchUsd1Label(cap.walletProjectCapUsd1),
            spoken: holders == null
                ? launchPendingConfirmationLabel
                : cap == null
                ? launchReasonCodeText(holders.walletCap.reasonCode)
                : null,
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
          // the reader owns keeps its place, with the Lime `YOU` tile.
          LoopRecordGroup(
            key: const ValueKey<String>('launch-holders-list'),
            rows: <LoopRecordRow>[
              if (position == null)
                LoopRecordRow(
                  key: const ValueKey<String>('launch-holders-me'),
                  leading: const LoopMonoTile(label: 'YOU', accent: true),
                  selected: true,
                  title: '我的仓位',
                  subtitle:
                      '持仓 $launchMissingFigure · 还可买 $launchMissingFigure',
                  trailing: launchMissingFigure,
                  semanticLabel:
                      '我的仓位，'
                      '${launchReasonCodeText(holders.myPosition.reasonCode)}',
                )
              else
                LoopRecordRow(
                  key: const ValueKey<String>('launch-holders-me'),
                  leading: const LoopMonoTile(label: 'YOU', accent: true),
                  selected: true,
                  title: '我的仓位',
                  subtitle:
                      '已认购 ${launchUnitsFigure(position.purchasedTokens)} 枚 · '
                      '累计支付 ${launchUsd1Label(position.cumulativeUsd1)}\n'
                      '可领取 ${launchUnitsFigure(position.claimableTokens)} 枚 · '
                      '已领取 ${launchUnitsFigure(position.claimedTokens)} 枚 · '
                      '可退款 ${launchUsd1Label(position.refundableUsd1)}',
                  subtitleMaxLines: 3,
                  trailing: launchUnitsFigure(position.entitledTokens),
                  trailingCaption: '已冻结权益',
                  semanticLabel: '我的仓位，快照区块 ${position.snapshotBlockNumber}',
                ),
            ],
          ),
          if (cap != null) ...<Widget>[
            const LoopLabel('我的额度'),
            LoopRecordGroup(
              key: const ValueKey<String>('launch-holders-cap'),
              rows: <LoopRecordRow>[
                for (var index = 0; index < cap.rounds.length; index += 1)
                  LoopRecordRow(
                    key: ValueKey<String>(
                      'launch-holders-cap-${cap.rounds[index].roundIndex}',
                    ),
                    title: 'Round ${cap.rounds[index].roundIndex}',
                    subtitle:
                        '已用 ${launchUsd1Label(cap.rounds[index].cumulativeUsd1)}',
                    trailing: launchUsd1Label(
                      cap.rounds[index].walletRoundCapUsd1,
                    ),
                    trailingCaption: '本轮上限',
                    position: launchRowPosition(index, cap.rounds.length),
                    chevron: false,
                  ),
              ],
            ),
          ],
          switch (holders.holders) {
            LaunchReadingUnavailable<LaunchHolderCount>(:final fact) =>
              LaunchUnavailableCard(label: '持有人分布', fact: fact),
            LaunchReadingAvailable<LaunchHolderCount>() =>
              const SizedBox.shrink(),
          },
          LoopNotice(
            key: const ValueKey<String>('launch-holders-notice'),
            icon: 'chart',
            title: '空白不是「没有持有人」',
            body: count == null
                ? '暂时读不到合约信息，因此不显示地址、比例或上限。读不到不等于「分布为零」。'
                : '参与人数来自链上索引；地址排名与集中度还没有来源，因此不显示。',
            margin: const EdgeInsets.fromLTRB(16, 22, 16, 0),
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
    final indexed = switch (history?.source) {
      LaunchReadingAvailable<LaunchIndexedSource>(:final value) => value,
      _ => null,
    };
    final purchases =
        history?.purchaseRecords ?? const <LaunchPurchaseRecord>[];

    return LoopDashboardPage(
      key: const ValueKey<String>('launch-history-screen'),
      onRefresh: controller.reload,
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title: '我的参与记录',
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: 'PARTICIPATION LOG',
          heading: indexed == null
              ? launchMissingHeading
              : '${purchases.length} 笔认购',
          caption: indexed == null
              ? '购买、权益与退款记录都要看链上数据，目前读不到，因此不显示笔数或盈亏。'
              : '记录来自链上索引，索引到区块 '
                    '${loopGroupedFigure(indexed.indexedBlockNumber)}；不显示盈亏。',
          stamp: indexed == null ? 'UNAVAILABLE' : 'INDEXED',
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        detail: <Widget>[
          LoopCompositeDetailRow(
            label: '参与次数',
            value: indexed == null
                ? loopFigureDash
                : purchases.length.toString(),
            valueSize: 18,
            // No schema carries a result or a profit, so it stays the dash.
            trailingLabel: '累计结果',
            trailingValue: loopFigureDash,
            spoken: indexed == null ? launchPendingConfirmationLabel : null,
          ),
          const LoopHairline(),
          const LoopCompositeDetailNote('内盘与毕业后记录统一归档'),
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
        else if (indexed == null) ...<Widget>[
          const LoopLabel('Records'),
          switch (history.source) {
            LaunchReadingUnavailable<LaunchIndexedSource>(:final fact) =>
              LaunchUnavailableCard(label: '购买、权益与退款记录', fact: fact),
            LaunchReadingAvailable<LaunchIndexedSource>() =>
              const SizedBox.shrink(),
          },
          const LoopNotice(
            key: ValueKey<String>('launch-history-notice'),
            icon: 'info',
            title: '空列表不代表没有参与',
            body: '这里是「暂时读不到」，不是「没有记录」。合约上线后才会出现可核对的购买、权益与退款。',
            margin: EdgeInsets.fromLTRB(16, 22, 16, 0),
          ),
          const SizedBox(height: 20),
        ] else if (history.isEmpty) ...<Widget>[
          LoopEmpty(
            key: const ValueKey<String>('launch-history-indexed-empty'),
            message: '这个钱包在本次发射没有记录',
            reason:
                '链上索引到区块 ${loopGroupedFigure(indexed.indexedBlockNumber)}，'
                '其中没有这个钱包的认购、权益或退款。',
          ),
          const SizedBox(height: 20),
        ] else ...<Widget>[
          if (purchases.isNotEmpty) ...<Widget>[
            const LoopLabel('认购'),
            LoopRecordGroup(
              key: const ValueKey<String>('launch-history-purchases'),
              rows: <LoopRecordRow>[
                for (var index = 0; index < purchases.length; index += 1)
                  LoopRecordRow(
                    key: ValueKey<String>(
                      'launch-history-purchase-${purchases[index].purchaseRecordId}',
                    ),
                    leading: LoopMonoTile(
                      label: 'R${purchases[index].roundIndex}',
                    ),
                    title: '支付 ${launchUsd1Label(purchases[index].usd1Amount)}',
                    subtitle:
                        '获得 ${launchUnitsFigure(purchases[index].tokenAmount)} 枚 · '
                        '区块 ${loopGroupedFigure(purchases[index].blockNumber)}\n'
                        '交易 ${launchShortHex(purchases[index].transactionHash)} · '
                        '观察于 ${launchTimestampLabel(purchases[index].observedAt)}',
                    subtitleMaxLines: 2,
                    trailingBadge: LoopBadge(
                      purchases[index].confirmationState.label,
                      kind:
                          purchases[index].confirmationState ==
                              LaunchConfirmationState.confirmed
                          ? LoopBadgeKind.launch
                          : LoopBadgeKind.mute,
                    ),
                    position: launchRowPosition(index, purchases.length),
                    chevron: false,
                  ),
              ],
            ),
          ],
          if (history.entitlements.isNotEmpty) ...<Widget>[
            const LoopLabel('权益'),
            LoopRecordGroup(
              key: const ValueKey<String>('launch-history-entitlements'),
              rows: <LoopRecordRow>[
                for (
                  var index = 0;
                  index < history.entitlements.length;
                  index += 1
                )
                  LoopRecordRow(
                    key: ValueKey<String>(
                      'launch-history-entitlement-'
                      '${history.entitlements[index].entitlementId}',
                    ),
                    title:
                        '权益 ${launchUnitsFigure(history.entitlements[index].entitledTokens)} 枚',
                    subtitle:
                        '已领取 ${launchUnitsFigure(history.entitlements[index].claimedTokens)} 枚',
                    trailingBadge: LoopBadge(
                      history.entitlements[index].state.label,
                      kind: LoopBadgeKind.mute,
                    ),
                    position: launchRowPosition(
                      index,
                      history.entitlements.length,
                    ),
                    chevron: false,
                  ),
              ],
            ),
          ],
          if (history.refunds.isNotEmpty) ...<Widget>[
            const LoopLabel('退款'),
            LoopRecordGroup(
              key: const ValueKey<String>('launch-history-refunds'),
              rows: <LoopRecordRow>[
                for (var index = 0; index < history.refunds.length; index += 1)
                  LoopRecordRow(
                    key: ValueKey<String>(
                      'launch-history-refund-'
                      '${history.refunds[index].refundLiabilityId}',
                    ),
                    title:
                        '可退款 ${launchUsd1Label(history.refunds[index].refundableUsd1)}',
                    subtitle:
                        '已退款 ${launchUsd1Label(history.refunds[index].refundedUsd1)}',
                    trailingBadge: LoopBadge(
                      history.refunds[index].state.label,
                      kind: LoopBadgeKind.mute,
                    ),
                    position: launchRowPosition(index, history.refunds.length),
                    chevron: false,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
