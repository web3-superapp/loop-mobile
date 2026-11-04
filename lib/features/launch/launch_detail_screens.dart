import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_settlement_section.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_accordion_strip.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// The 内盘持有人 row on `launch-detail`, following the holders resource
/// branch by branch (decision 0091).
///
/// Only `LAUNCH_CONTRACT_BASELINE_PENDING` may say the contract is not live;
/// an index that has not caught up says so, and any other reason is a plain
/// "cannot read". A count is distinct buyers (decision 0089), never holders.
///
/// Decision 0097: once the `launch` capability's evidence is confirmed
/// ([contractLive]) the contract is live, and the baseline code only means
/// the count is not open for reading yet.
String launchHoldersRowText(
  LaunchResourceState<LaunchHolders> state, {
  bool contractLive = false,
}) {
  final holders = state.value;
  if (holders == null) {
    return state.phase == LaunchViewPhase.loading
        ? LoopL10n.current.launch_detailScreensIf
        : LoopL10n.current.launch_detailScreensS;
  }
  return switch (holders.holders) {
    LaunchReadingAvailable<LaunchHolderCount>(:final value) =>
      LoopL10n.current.launch_detailScreensSwitch(
        loopGroupedFigure(value.holderCount.toString()),
      ),
    LaunchReadingUnavailable<LaunchHolderCount>(:final reasonCode) =>
      switch (reasonCode) {
        'LAUNCH_CONTRACT_BASELINE_PENDING' =>
          contractLive
              ? LoopL10n.current.launch_detailScreensSwitch2
              : LoopL10n.current.launch_detailScreensS2,
        'LAUNCH_ONCHAIN_STATE_NOT_INDEXED' ||
        'LAUNCH_ONCHAIN_STATE_NOT_PROJECTED' =>
          LoopL10n.current.launch_detailScreensSwitch3,
        _ => LoopL10n.current.launch_detailScreensS,
      },
  };
}

/// The `launch-detail` folio heading (decision 0097): the semantic label of
/// the skeleton while the record is read, the project's name once it is,
/// [launchMissingName] only for a read record without one, and a plain
/// "not read" once the read has ended without a record.
String launchDetailHeading(LaunchDetail? detail, {required bool loading}) {
  if (detail == null) {
    return loading
        ? LoopL10n.current.launch_detailScreensLaunchDetailHeading
        : LoopL10n.current.launch_detailScreensS3;
  }
  final name = detail.launch.name.trim();
  return name.isEmpty ? launchMissingName : name;
}

/// The `launch-detail` folio caption (decision 0097). While the record is
/// being read it says so; the "cannot read" sentence is kept for a finished
/// read whose on-chain block really is empty.
String launchDetailCaption(
  LaunchOnChainAvailable? onChain, {
  required bool loading,
}) {
  if (loading) return LoopL10n.current.launch_detailScreensLaunchDetailCaption;
  if (onChain == null) {
    return LoopL10n.current.launch_detailScreensIf2;
  }
  return LoopL10n.current.launch_detailScreensIf3(
    loopGroupedFigure(onChain.snapshotBlockNumber),
    launchStateProjection(onChain),
  );
}

/// The 我的资格 row on `launch-detail`, from the eligibility resource the
/// `launch-tier` page reads (decision 0094).
///
/// An open round is only what the server says it is: `status: available` with
/// an all-zero `allowlistRoot` (OpenAPI · eligibility `result`). Every other
/// answer keeps its own words; nothing is inferred from the mode.
String launchEligibilityRowText(LaunchResourceState<LaunchEligibility> state) {
  final evaluated = state.value?.evaluated;
  if (evaluated == null) {
    return LoopL10n.current.launch_detailScreensIf4(
      launchPendingConfirmationLabel,
    );
  }
  if (evaluated.rootIsZero) return LoopL10n.current.launch_detailScreensIf5;
  final tier = state.value!.tier;
  return LoopL10n.current.launch_roundComma(evaluated.roundIndex) +
      (tier == null
          ? LoopL10n.current.launch_detailScreensHeading4
          : launchTierLabel(tier));
}

/// The 我的参与记录 row on `launch-detail`, from the history resource the
/// `launch-history` page reads (decision 0094). Only an indexed source may
/// say "none"; anything else keeps the reminder that an empty list proves
/// nothing.
String launchHistoryRowText(LaunchResourceState<LaunchHistory> state) {
  final unread = LoopL10n.current.launch_detailScreensUnread;
  final history = state.value;
  if (history == null) return unread;
  final indexed = switch (history.source) {
    LaunchReadingAvailable<LaunchIndexedSource>(:final value) => value,
    _ => null,
  };
  if (indexed == null) return unread;
  final purchases = history.purchaseRecords;
  final settlements = (history.settlements ?? const <LaunchSettlementRecord>[])
      .where((row) => row.confirmationState != LaunchConfirmationState.reorged)
      .toList();
  if (purchases.isNotEmpty || settlements.isNotEmpty) {
    DateTime? latest;
    for (final at in <DateTime>[
      for (final record in purchases) record.observedAt,
      for (final record in settlements) record.observedAt,
    ]) {
      if (latest == null || at.isAfter(latest)) latest = at;
    }
    final claimed = settlements
        .where((row) => row.kind == LaunchSettlementKind.claimed)
        .length;
    final refunded = settlements.length - claimed;
    final parts = <String>[
      if (purchases.isNotEmpty)
        LoopL10n.current.launch_detailScreensIf6(purchases.length),
      if (claimed > 0) LoopL10n.current.launch_detailScreensIf7(claimed),
      if (refunded > 0) LoopL10n.current.launch_detailScreensIf8(refunded),
    ];
    return LoopL10n.current.launch_detailScreensIf9(
      launchTimestampLabel(latest!),
      parts.join(LoopL10n.current.common_listSeparator),
    );
  }
  final block = loopGroupedFigure(indexed.indexedBlockNumber);
  if (history.isEmpty) return LoopL10n.current.launch_detailScreensIf10(block);
  return LoopL10n.current.launch_detailScreensIf11(block);
}

/// One row of 我的参与记录: a purchase or a claim / refund (decision 0103).
typedef LaunchHistoryEntry = ({
  LaunchPurchaseRecord? purchase,
  LaunchSettlementRecord? settlement,
});

/// Purchases and settlements on one timeline, newest first by chain
/// position (block, then log index), then by when LOOP observed them. The
/// settlements join only when the server sent them.
List<LaunchHistoryEntry> launchHistoryTimeline(LaunchHistory history) {
  final entries = <LaunchHistoryEntry>[
    for (final record in history.purchaseRecords)
      (purchase: record, settlement: null),
    for (final record
        in history.settlements ?? const <LaunchSettlementRecord>[])
      (purchase: null, settlement: record),
  ];
  BigInt block(LaunchHistoryEntry entry) => BigInt.parse(
    entry.purchase?.blockNumber ?? entry.settlement!.blockNumber,
  );
  int log(LaunchHistoryEntry entry) =>
      entry.purchase?.logIndex ?? entry.settlement!.logIndex;
  DateTime seen(LaunchHistoryEntry entry) =>
      entry.purchase?.observedAt ?? entry.settlement!.observedAt;
  entries.sort((a, b) {
    final byBlock = block(b).compareTo(block(a));
    if (byBlock != 0) return byBlock;
    final byLog = log(b).compareTo(log(a));
    if (byLog != 0) return byLog;
    return seen(b).compareTo(seen(a));
  });
  return entries;
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
    this.clock,
  });

  /// The time the 发射轨道 reads a round against (which one is 进行中);
  /// tests pass a fixed one.
  final DateTime Function()? clock;

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
    final loading =
        !blocked && detail == null && state.phase == LaunchViewPhase.loading;
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
    // Decision 0094: the 我的资格 and 我的参与记录 rows read the same
    // resources their pages read, instead of fixed placeholder sentences.
    final eligibilityState = ref.watch(launchEligibilityControllerProvider);
    if (!blocked &&
        detail != null &&
        eligibilityState.phase == LaunchViewPhase.loading &&
        eligibilityState.value == null) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(launchEligibilityControllerProvider.notifier)
                .open(widget.launchId),
          );
        }
      });
    }
    final historyState = ref.watch(launchHistoryControllerProvider);
    if (!blocked &&
        detail != null &&
        historyState.phase == LaunchViewPhase.loading &&
        historyState.value == null) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref
                .read(launchHistoryControllerProvider.notifier)
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
        if (!blocked)
          eligibilityState.isReady
              ? ref.read(launchEligibilityControllerProvider.notifier).reload()
              : ref
                    .read(launchEligibilityControllerProvider.notifier)
                    .open(widget.launchId),
        if (!blocked)
          historyState.isReady
              ? ref.read(launchHistoryControllerProvider.notifier).reload()
              : ref
                    .read(launchHistoryControllerProvider.notifier)
                    .open(widget.launchId),
      ]),
      updating: state.refreshing,
      archetype: LoopPageArchetype.record,
      title:
          detail?.launch.ticker ??
          context.l10n.launch_detailScreensLaunchDetailScreenTitle,
      onBack: widget.onBack,
      framedTools: true,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('launch-detail-rounds-action'),
          icon: 'info',
          label: context.l10n.launch_detailScreensLaunchDetailRoundsActionLabel,
          framed: true,
          onPressed: widget.onOpenRounds,
        ),
      ],
      // `.launch-detail-composite`: the record's folio and the project's own
      // Chalk identity card are one surface, the way the prototype welds
      // them. The identity card is what the audit found missing entirely.
      primary: LoopLedgerComposite(
        ground: LoopCompositeGround.chalk,
        margin: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          16,
        ),
        detailPadding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: context.l10n.launch_detailScreensKicker,
          heading: launchDetailHeading(detail, loading: loading),
          // Decision 0095/0097: while the record is being read the heading is
          // a skeleton of its own height and the caption says it is reading;
          // neither borrows the "cannot read" sentence of a finished read.
          headingLoading: loading,
          // No countdown, no round label, no progress: all three are contract
          // facts. The caption states what the record can and cannot prove.
          caption: launchDetailCaption(onChain, loading: loading),
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
              title: context
                  .l10n
                  .launch_detailScreensLaunchDetailCapabilityUnavailableTitle,
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
            emptyMessage: context.l10n.launch_detailScreensEmptyMessage,
            emptyReason: context.l10n.launch_detailScreensEmptyReason,
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
          LoopLabel(context.l10n.launch_detailScreensLoopLabel),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('launch-detail-open-tier'),
                leading: const LoopRowIcon(
                  icon: 'ticket',
                  tone: LoopRowIconTone.accent,
                ),
                title: context.l10n.launch_detailScreensLoopLabel,
                // Decision 0053: the mode is read, never assumed. Decision
                // 0094: the row states the eligibility resource's answer,
                // and an open round is the server's open branch only.
                subtitle: launchEligibilityRowText(eligibilityState),
                subtitleMaxLines: 2,
                onTap: widget.onOpenTier,
              ),
            ],
          ),
          // Decision 0103: claim and refund. The block draws nothing while
          // the sale is scheduled or live, or the wallet never took part.
          if (!blocked)
            LaunchSettlementSection(
              key: const ValueKey<String>('launch-detail-settlement'),
              launchId: widget.launchId,
              detail: detail,
              clock: widget.clock,
            ),
          LoopLabel(context.l10n.launch_detailScreensLoopLabel2),
          _TrackBlock(
            rounds: detail.rounds,
            chainRounds: detail.chainRounds,
            onChain: detail.onChain,
            config: config,
            onOpenGraduation: widget.onOpenGraduation,
            now: (widget.clock ?? DateTime.now)().toUtc(),
          ),
          _LinksBlock(links: detail.project.officialLinks),
          LoopLabel(context.l10n.launch_detailScreensLoopLabel3),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('launch-detail-open-holders'),
                leading: const LoopRowIcon(icon: 'users'),
                title: context
                    .l10n
                    .launch_detailScreensLaunchDetailOpenHoldersTitle,
                subtitle: launchHoldersRowText(
                  holdersState,
                  contractLive: capability.evidenceConfirmed,
                ),
                subtitleMaxLines: 2,
                onTap: widget.onOpenHolders,
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('launch-detail-open-history'),
                leading: const LoopRowIcon(icon: 'book'),
                title: context
                    .l10n
                    .launch_detailScreensLaunchDetailOpenHistoryTitle,
                subtitle: launchHistoryRowText(historyState),
                subtitleMaxLines: 2,
                onTap: widget.onOpenHistory,
                position: LoopRowPosition.last,
              ),
            ],
          ),
          LoopButtonPair(
            children: <Widget>[
              // Off, with the reason as its label, whenever the chain says
              // no round is live (launchTradeButtonSpec).
              LoopButton(
                key: const ValueKey<String>('launch-detail-open-trade'),
                label: launchTradeButtonSpec(detail.launch.onChainState).label,
                primary: true,
                onPressed:
                    launchTradeButtonSpec(detail.launch.onChainState).enabled
                    ? widget.onOpenTrade
                    : null,
              ),
            ],
          ),
          // The twelve key-value rows that used to fill two screens keep
          // every fact they carried, behind the prototype's own disclosure
          // control (`details.focus-disclosure`).
          LoopDisclosure(
            key: const ValueKey<String>('launch-detail-facts'),
            summary: context.l10n.launch_detailScreensLaunchDetailFactsSummary,
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
                  LoopLabel(
                    context.l10n.launch_detailScreensLoopLabel4,
                    tight: true,
                  ),
                  LaunchAxisBlock(state: detail.launch.onChainState),
                  LoopLabel(context.l10n.launch_detailScreensLoopLabel5),
                  if (detail.saleConfig != null)
                    LaunchSaleConfigGroup(
                      key: const ValueKey<String>('launch-detail-sale-config'),
                      config: detail.saleConfig!,
                    )
                  else if (config == null)
                    LoopEmptyState(
                      key: ValueKey<String>('launch-detail-no-config'),
                      illustration: LoopIllustration.launchpad,
                      title: context
                          .l10n
                          .launch_detailScreensLaunchDetailNoConfigTitle,
                      message: context
                          .l10n
                          .launch_detailScreensLaunchDetailNoConfigMessage,
                      compact: true,
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
                      id: 'confirmed-config',
                      label: context.l10n.launch_detailScreensLabel,
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
            title: onChain == null
                ? context
                      .l10n
                      .launch_detailScreensLaunchDetailBaselineNoticeTitle
                : context
                      .l10n
                      .launch_detailScreensLaunchDetailBaselineNoticeTitle2,
            body: context.l10n
                .launch_detailScreensLaunchDetailBaselineNoticeBody(
                  launchTimestampLabel(detail.launch.createdAt),
                  detail.project.materialVersion,
                  onChain == null
                      ? launchReasonCodeText(
                          detail.launch.onChainState.reasonCode,
                        )
                      : context.l10n.launch_detailScreensBaselineOnChain(
                          loopGroupedFigure(onChain.snapshotBlockNumber),
                          launchShortHex(onChain.stateTupleDigest),
                        ),
                ),
            margin: const EdgeInsets.fromLTRB(
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
                            ? context.l10n.launch_detailScreensIf12
                            : current == null
                            ? context.l10n.launch_detailScreensIf13(index)
                            : context.l10n.launch_detailScreensS4(index),
                        style: LoopType.captionSm,
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
              semanticLabel: progress == null
                  ? context.l10n.launch_detailScreensSemanticLabel
                  : context.l10n.launch_detailScreensSemanticLabel2,
            ),
            const SizedBox(height: 8),
            Text(
              raised == null || config == null
                  ? context.l10n.launch_detailScreensIf14(
                      launchMissingFigure,
                      launchMissingFigure,
                    )
                  : context.l10n.launch_detailScreensS5(
                      launchUsd1Label(raised.toString()),
                      launchUsd1Label(config.hardCapUsd1),
                    ),
              style: LoopType.captionSm.copyWith(color: LoopColors.text2),
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
///
/// Read on chain, the track is a horizontal accordion (decision 0096): one
/// strip per round and one for END, the current step open on arrival
/// ([launchTrackInitialIndex], decision 0097).
/// Large type, a narrow screen or too many rounds for the row fall back to
/// the vertical list, which states the same facts.
class _TrackBlock extends StatelessWidget {
  const _TrackBlock({
    required this.rounds,
    required this.chainRounds,
    required this.onChain,
    required this.config,
    required this.now,
    this.onOpenGraduation,
  });

  final List<LaunchRound> rounds;
  final List<LaunchChainRound> chainRounds;
  final LaunchOnChainAvailable? onChain;
  final LaunchConfig? config;
  final DateTime now;
  final VoidCallback? onOpenGraduation;

  /// The strip row's least height at text scale 1. The row is otherwise as
  /// tall as the open strip's own content (decision 0100).
  static const double accordionMinHeight = 160;

  @override
  Widget build(BuildContext context) {
    if (chainRounds.isNotEmpty) {
      final length = chainRounds.length + 1;
      final list = LoopRecordGroup(
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
      final badge = _graduationBadge;
      final pending = launchTrackEndPending(onChain);
      final block = onChain?.snapshotBlockNumber;
      return LoopAccordionStrip(
        keyPrefix: 'launch-track',
        margin: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          0,
          LoopSpacing.page,
          14,
        ),
        rowKey: const ValueKey<String>('launch-track'),
        minHeight: accordionMinHeight,
        initialIndex: launchTrackInitialIndex(chainRounds, now),
        // The list draws its own page margin; [margin] is the row's only.
        fallback: list,
        items: <LoopAccordionItem>[
          for (final round in chainRounds) _roundItem(round),
          LoopAccordionItem(
            id: 'end',
            shortTitle: context.l10n.launch_detailScreensShortTitle,
            dot: pending ? LoopAccordionDot.idle : LoopAccordionDot.live,
            tone: pending ? LoopAccordionTone.upcoming : LoopAccordionTone.live,
            stateLabel: context.l10n.common_graduate,
            semanticLabel: context.l10n.launch_detailScreensSemanticLabel3(
              badge,
            ),
            badge: LoopBadge(
              badge,
              kind: pending ? LoopBadgeKind.mute : LoopBadgeKind.launch,
            ),
            detail: _TrackGraduationDetail(
              onOpenGraduation: onOpenGraduation,
              line: launchTrackEndDetail(onChain),
            ),
            footer: block == null
                ? null
                : _TrackFooter(
                    context.l10n.launch_detailScreensTrackFooter(
                      loopGroupedFigure(block),
                    ),
                  ),
          ),
        ],
      );
    }
    if (rounds.isEmpty) {
      return LoopEmptyState(
        showMessage: true,
        key: ValueKey<String>('launch-track-empty'),
        illustration: LoopIllustration.launchpad,
        title: context.l10n.launch_detailScreensLaunchTrackEmptyTitle,
        message: context.l10n.launch_detailScreensLaunchTrackEmptyMessage,
        compact: true,
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

  /// One contract round as a strip (decision 0100): its phase along the
  /// narrow strip with the raised bar at the foot; open, the sale's own word
  /// as the badge while the round runs.
  LoopAccordionItem _roundItem(LaunchChainRound round) {
    final phase = launchChainRoundPhaseLabel(round, now);
    final live = round.isOpenAt(now);
    final upcoming = !live && now.isBefore(round.startAt);
    final state = onChain;
    final paused =
        state != null &&
        state.operationalState == LaunchOperationalState.paused;
    final badgeText = live
        ? (state == null ? phase : launchSaleStateLabel(state))
        : phase;
    final tone = live
        ? LoopAccordionTone.live
        : upcoming
        ? LoopAccordionTone.upcoming
        : LoopAccordionTone.ended;
    return LoopAccordionItem(
      id: '${round.roundIndex}',
      shortTitle: 'R${round.roundIndex}',
      dot: live
          ? LoopAccordionDot.live
          : upcoming
          ? LoopAccordionDot.upcoming
          : LoopAccordionDot.idle,
      tone: tone,
      stateLabel: phase,
      progress: launchRoundRaisedFraction(round),
      semanticLabel:
          '${LoopL10n.current.launch_roundComma(round.roundIndex)}'
          '${round.hasAllowlist ? LoopL10n.current.launch_detailScreensBuild : LoopL10n.current.launch_detailScreensS6}'
          '${LoopL10n.current.common_listSeparator}$phase',
      badge: LoopBadge(
        badgeText,
        kind: live && !paused ? LoopBadgeKind.launch : LoopBadgeKind.mute,
      ),
      detail: LaunchTrackRoundDetail(round: round, tone: tone),
      footer: _TrackFooter(
        LoopL10n.current.launch_detailScreensTrackFooter2(
          launchUsd1Label(round.walletRoundCapUsd1),
        ),
      ),
    );
  }

  String get _graduationBadge => launchTrackEndBadge(onChain);

  LoopRecordRow _graduationRow(int length) {
    final badge = _graduationBadge;
    return LoopRecordRow(
      key: const ValueKey<String>('launch-track-graduation'),
      leading: LoopMonoTile(
        label: LoopL10n.current.launch_detailScreensShortTitle,
      ),
      title: LoopL10n.current.launch_detailScreensLaunchTrackGraduationTitle,
      subtitle: launchTrackEndDetail(onChain),
      trailingBadge: LoopBadge(
        badge,
        kind: launchTrackEndPending(onChain)
            ? LoopBadgeKind.mute
            : LoopBadgeKind.launch,
      ),
      onTap: onOpenGraduation,
      position: launchRowPosition(length - 1, length),
      semanticLabel: LoopL10n.current.launch_detailScreensSemanticLabel3(badge),
    );
  }
}

/// Whether [launchTrackEndBadge] says 待触发 — read from the state, not the
/// copy (decision 0281).
bool launchTrackEndPending(LaunchOnChainAvailable? state) {
  if (state == null) return true;
  return switch (state.entitlementState) {
    LaunchEntitlementState.vesting ||
    LaunchEntitlementState.completed ||
    LaunchEntitlementState.refunding => false,
    _ => launchGraduationProjection(state) == null,
  };
}

/// The END step's badge on `launch-detail`'s 发射轨道.
///
/// Decision 0103: once the entitlement axis opens a claim or a refund the
/// badge says so — 领取中 (VESTING), 已完成 (COMPLETED), 退款中 (REFUNDING) —
/// instead of 待触发. Otherwise the graduation projection of 03 §8.3, or
/// 待触发 when there is none.
String launchTrackEndBadge(LaunchOnChainAvailable? state) {
  if (state == null) return LoopL10n.current.launch_chainModelsPending;
  return switch (state.entitlementState) {
    LaunchEntitlementState.vesting =>
      LoopL10n.current.launch_detailScreensVesting,
    LaunchEntitlementState.completed => LoopL10n.current.launch_chainModelsDone,
    LaunchEntitlementState.refunding =>
      LoopL10n.current.launch_detailScreensRefunding,
    _ =>
      launchGraduationProjection(state) ??
          LoopL10n.current.launch_chainModelsPending,
  };
}

/// The END step's one line, following [launchTrackEndBadge].
String launchTrackEndDetail(LaunchOnChainAvailable? state) =>
    switch (state?.entitlementState) {
      LaunchEntitlementState.vesting =>
        LoopL10n.current.launch_detailScreensVesting2,
      LaunchEntitlementState.completed =>
        LoopL10n.current.launch_detailScreensCompleted,
      LaunchEntitlementState.refunding =>
        LoopL10n.current.launch_detailScreensRefunding2,
      _ => LoopL10n.current.launch_detailScreensSwitch4,
    };

/// The strip `launch-detail`'s 发射轨道 opens on arrival (decision 0097):
/// the "current" step of the track, so the row never starts as equal empty
/// shells.
///
/// - a round is in progress at [now] → that round;
/// - every round has ended (now is at or after the last `endAt`) → END,
///   which is index `rounds.length`;
/// - otherwise → the next round to open, which before the sale is the first
///   round;
/// - no rounds → `null`.
int? launchTrackInitialIndex(List<LaunchChainRound> rounds, DateTime now) {
  if (rounds.isEmpty) return null;
  final live = rounds.indexWhere((round) => round.isOpenAt(now));
  if (live >= 0) return live;
  var lastEnd = rounds.first.endAt;
  for (final round in rounds) {
    if (round.endAt.isAfter(lastEnd)) lastEnd = round.endAt;
  }
  if (!now.isBefore(lastEnd)) return rounds.length;
  int? next;
  for (var index = 0; index < rounds.length; index += 1) {
    final round = rounds[index];
    if (!now.isBefore(round.startAt)) continue;
    if (next == null || round.startAt.isBefore(rounds[next].startAt)) {
      next = index;
    }
  }
  return next ?? 0;
}

/// Where [round] stands at [now], in the words the track strip reads out.
String launchChainRoundPhaseLabel(LaunchChainRound round, DateTime now) {
  if (round.isOpenAt(now)) return LoopL10n.current.common_inProgress;
  if (now.isBefore(round.startAt)) {
    return LoopL10n.current.launch_detailScreensLaunchChainRoundPhaseLabel;
  }
  return LoopL10n.current.common_ended;
}

/// Raised against the round cap, in pixel space only: `null` when the cap
/// is zero, never above 1. The figures stay exact strings.
double? launchRoundRaisedFraction(LaunchChainRound round) {
  final cap = BigInt.parse(round.roundCapUsd1);
  if (cap <= BigInt.zero) return null;
  final raised = BigInt.parse(round.raisedUsd1);
  final value = (raised * BigInt.from(10000) ~/ cap).toInt() / 10000;
  return value > 1 ? 1 : value;
}

/// The open strip of one contract round on `launch-detail`'s track
/// (decision 0100): the round's access, two small cards — the window, then
/// the price and the round cap — and what it has raised over the bar of
/// raised against the round cap. The wallet cap is the strip's footer. Every
/// figure is the same exact string the vertical row prints; only the time
/// drops its year, since the window is one round's, and the cards name the
/// unit once in their labels.
class LaunchTrackRoundDetail extends StatelessWidget {
  const LaunchTrackRoundDetail({
    required this.round,
    super.key,
    this.tone = LoopAccordionTone.neutral,
  });

  final LaunchChainRound round;

  /// The strip's tone: a round that is over draws its bar in greyscale.
  final LoopAccordionTone tone;

  static String _time(DateTime value) {
    final utc = value.toUtc();
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = launchRoundRaisedFraction(round);
    final access = round.hasAllowlist
        ? context.l10n.launch_detailScreensBuild
        : context.l10n.launch_detailScreensS6;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'Round ${round.roundIndex}${LoopL10n.current.common_listSeparator}$access',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LoopTypography.withWeight(
            LoopType.label,
            FontWeight.w700,
          ).copyWith(color: LoopGround.inkOf(context)),
        ),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                child: _TrackCard(
                  key: const ValueKey<String>('launch-track-card-window'),
                  entries: <(String, String)>[
                    (
                      context.l10n.launch_detailScreensEntries,
                      _time(round.startAt),
                    ),
                    (
                      context.l10n.launch_detailScreensEntries2,
                      _time(round.endAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _TrackCard(
                  key: const ValueKey<String>('launch-track-card-price'),
                  entries: <(String, String)>[
                    (
                      context.l10n.launch_detailScreensEntries3,
                      launchUnitsFigure(round.priceUsd1PerToken),
                    ),
                    (
                      context.l10n.launch_detailScreensEntries4,
                      launchUnitsFigure(round.roundCapUsd1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Text(
              context.l10n.launch_detailScreensBuild2,
              maxLines: 1,
              style: LoopType.captionSm.copyWith(
                color: LoopGround.auxiliaryOf(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    launchUsd1Label(round.raisedUsd1),
                    maxLines: 1,
                    style: LoopType.figureXs.copyWith(
                      color: LoopGround.inkOf(context),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LoopProgressBar(
          value: progress,
          fillColor: switch (tone) {
            LoopAccordionTone.ended => LoopGround.auxiliaryOf(context),
            LoopAccordionTone.upcoming => LoopGround.secondaryOf(context),
            LoopAccordionTone.live ||
            LoopAccordionTone.neutral => LoopColors.yellow,
          },
          semanticLabel: progress == null
              ? context.l10n.launch_detailScreensSemanticLabel4
              : context.l10n.launch_detailScreensSemanticLabel5,
        ),
        if (round.roundId == null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            context.l10n.launch_detailScreensSwitch5,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: LoopType.captionSm.copyWith(
              color: LoopGround.auxiliaryOf(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// A small card of two label / figure pairs inside an open track strip. A
/// figure never truncates: it scales down to the card.
class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.entries, super.key});

  final List<(String, String)> entries;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: LoopGround.tintOf(context),
        borderRadius: LoopRadius.inner,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (var index = 0; index < entries.length; index += 1) ...<Widget>[
              if (index > 0) const SizedBox(height: 6),
              Text(
                entries[index].$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.captionSm.copyWith(
                  color: LoopGround.auxiliaryOf(context),
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  entries[index].$2,
                  maxLines: 1,
                  style: LoopTypography.withWeight(
                    LoopType.figureSm,
                    FontWeight.w600,
                  ).copyWith(color: LoopGround.inkOf(context)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The thin line at the foot of an open track strip.
class _TrackFooter extends StatelessWidget {
  const _TrackFooter(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: LoopGround.hairlineOf(context))),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LoopType.figureXs.copyWith(
            color: LoopGround.auxiliaryOf(context),
          ),
        ),
      ),
    );
  }
}

/// The open END strip: the graduation step and the way into
/// `launch-graduation`. Its projection is the strip's badge.
class _TrackGraduationDetail extends StatelessWidget {
  const _TrackGraduationDetail({required this.line, this.onOpenGraduation});

  final VoidCallback? onOpenGraduation;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          context.l10n.launch_detailScreensLaunchTrackGraduationTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LoopTypography.withWeight(
            LoopType.label,
            FontWeight.w700,
          ).copyWith(color: LoopGround.inkOf(context)),
        ),
        const SizedBox(height: 6),
        Text(
          line,
          key: const ValueKey<String>('launch-track-end-line'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: LoopType.captionSm.copyWith(
            color: LoopGround.secondaryOf(context),
          ),
        ),
        if (onOpenGraduation != null) ...<Widget>[
          const SizedBox(height: 10),
          LoopButton(
            key: const ValueKey<String>('launch-track-open-graduation'),
            label:
                context.l10n.launch_detailScreensLaunchTrackOpenGraduationLabel,
            onPressed: onOpenGraduation,
          ),
        ],
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
      return LoopEmptyState(
        showMessage: true,
        key: ValueKey<String>('launch-rounds-empty'),
        illustration: LoopIllustration.launchpad,
        title: context.l10n.launch_detailScreensLaunchTrackEmptyTitle,
        message: context.l10n.launch_detailScreensLaunchTrackEmptyMessage,
        compact: true,
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
        LoopLabel(context.l10n.common_link),
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
      title: context.l10n.launch_detailScreensLaunchRoundsScreenTitle,
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: context.l10n.launch_detailScreensKicker2,
          // The number of rounds comes from the configuration, never from a
          // fixed three-round story.
          heading: detail == null
              ? launchMissingHeading
              : chainRounds.isNotEmpty
              ? context.l10n.launch_detailScreensHeading(chainRounds.length)
              : context.l10n.launch_detailScreensHeading(detail.rounds.length),
          caption: chainRounds.isNotEmpty
              ? context.l10n.launch_detailScreensCaption(
                  loopGroupedFigure(detail!.onChain!.snapshotBlockNumber),
                )
              : context.l10n.launch_detailScreensCaption2,
          stamp: detail == null
              ? null
              : chainRounds.isNotEmpty
              ? context.l10n.launch_detailScreensStamp
              : launchPendingConfirmationLabel,
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        // `.ledger-composite-detail`: the sentence the prototype welds under
        // this folio, with the two caps the contract fixes, or the em dash
        // while no contract configuration was read.
        detail: <Widget>[
          LoopCompositeDetailNote(
            context.l10n.launch_detailScreensLoopCompositeDetailNote,
          ),
          const LoopHairline(),
          if (saleConfig == null)
            LoopCompositeDetailRow(
              label: context.l10n.common_totalSupply,
              value: loopFigureDash,
              valueSize: 18,
              trailingLabel: context.l10n.launch_detailScreensTrailingLabel,
              trailingValue: loopFigureDash,
              spoken: launchPendingConfirmationLabel,
            )
          else
            LoopCompositeDetailRow(
              key: const ValueKey<String>('launch-rounds-caps-chain'),
              label: context.l10n.launch_chainModelsEntries2,
              value: launchUsd1Label(saleConfig.hardCapUsd1),
              valueSize: 15,
              trailingLabel: context.l10n.launch_chainModelsEntries,
              trailingValue: launchUsd1Label(saleConfig.softCapUsd1),
            ),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-rounds-capability-unavailable',
              ),
              title: context
                  .l10n
                  .launch_detailScreensLaunchRoundsCapabilityUnavailableTitle,
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (subject == null)
          LoopEmptyState(
            key: ValueKey<String>('launch-rounds-no-subject'),
            illustration: LoopIllustration.launchpad,
            title: context.l10n.launch_detailScreensLaunchRoundsNoSubjectTitle,
            message:
                context.l10n.launch_detailScreensLaunchRoundsNoSubjectMessage,
            compact: true,
          )
        else if (detail == null)
          LaunchStateBlock(
            prefix: 'launch-rounds',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: context.l10n.launch_detailScreensEmptyMessage2,
            emptyReason: context.l10n.launch_detailScreensEmptyReason,
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          LoopLabel(context.l10n.launch_detailScreensLoopLabel6),
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
          LoopLabel(context.l10n.launch_detailScreensLoopLabel7),
          if (saleConfig != null) ...<Widget>[
            LaunchChainCapCard(config: saleConfig, rounds: chainRounds),
            LoopDisclosure(
              key: const ValueKey<String>('launch-rounds-facts'),
              summary:
                  context.l10n.launch_detailScreensLaunchRoundsFactsSummary,
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
            LoopEmptyState(
              key: ValueKey<String>('launch-rounds-no-config'),
              illustration: LoopIllustration.launchpad,
              title: context.l10n.launch_detailScreensLaunchDetailNoConfigTitle,
              message:
                  context.l10n.launch_detailScreensLaunchRoundsNoConfigMessage,
              compact: true,
            )
          else ...<Widget>[
            LaunchCapCard(config: config),
            // The six remaining slots keep the same row and the same 待确认
            // wording, behind the disclosure the prototype uses for the parts
            // of a rule page that are not the rule itself.
            LoopDisclosure(
              key: const ValueKey<String>('launch-rounds-facts'),
              summary:
                  context.l10n.launch_detailScreensLaunchRoundsFactsSummary,
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
              id: 'confirmed-config',
              label: context.l10n.launch_detailScreensLabel,
              fact: detail.configPending!,
            ),
          LoopNotice(
            key: const ValueKey<String>('launch-rounds-notice'),
            icon: 'shield',
            tone: LoopNoticeTone.warn,
            title: saleConfig == null
                ? context.l10n.launch_detailScreensLaunchRoundsNoticeTitle
                : context.l10n.launch_detailScreensLaunchRoundsNoticeTitle2,
            body: saleConfig == null
                ? context.l10n.launch_detailScreensLaunchRoundsNoticeBody(
                    launchReasonCodeText('LAUNCH_CONFIG_PENDING_CONFIRMATION'),
                  )
                : context.l10n.launch_detailScreensLaunchRoundsNoticeBody2,
            margin: const EdgeInsets.fromLTRB(
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
      title: context.l10n.launch_detailScreensLaunchTrackGraduationTitle,
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: context.l10n.launch_detailScreensKicker3,
          // Never a percentage: progress is a count of steps the liquidity
          // and entitlement axes prove, and nothing without them.
          heading: onChain == null
              ? launchMissingHeading
              : launchGraduationProjection(onChain) ??
                    context.l10n.launch_detailScreensHeading3(done),
          caption: onChain == null
              ? context.l10n.launch_detailScreensCaption3
              : context.l10n.launch_detailScreensCaption4(
                  launchStateProjection(onChain),
                ),
          stamp: onChain == null
              ? launchPendingConfirmationLabel
              : context.l10n.launch_detailScreensStamp,
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
                ? context.l10n.launch_detailScreensSemanticLabel
                : context.l10n
                      .launch_detailScreensLaunchGraduationBarSemanticLabel(
                        done,
                        steps.length,
                      ),
          ),
          const LoopHairline(),
          LoopCompositeDetailNote(
            onChain == null
                ? context.l10n.launch_detailScreensLoopCompositeDetailNote2(
                    launchMissingFigure,
                    launchMissingFigure,
                  )
                : context.l10n.launch_detailScreensS7(
                    loopGroupedFigure(onChain.snapshotBlockNumber),
                    onChain.liquidityState.wireName,
                    onChain.entitlementState.wireName,
                  ),
          ),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-graduation-capability-unavailable',
              ),
              title: context
                  .l10n
                  .launch_detailScreensLaunchGraduationCapabilityUnavailableTitle,
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
            emptyMessage: context.l10n.launch_detailScreensEmptyMessage3,
            emptyReason: context.l10n.launch_detailScreensEmptyReason,
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          LoopLabel(context.l10n.launch_detailScreensLoopLabel8),
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
                      '${launchGraduationStepLabel(steps[index].step)}${LoopL10n.current.common_listSeparator}'
                      '${launchGraduationStepDetail(steps[index].step)}${LoopL10n.current.common_listSeparator}'
                      '${progress[index].label}',
                ),
            ],
          ),
          LoopLabel(context.l10n.launch_detailScreensLoopLabel9),
          LaunchUnavailableCard(
            id: 'pool-evidence',
            label: context.l10n.launch_detailScreensLabel2,
            fact: detail.graduation.poolEvidence,
          ),
          LoopNotice(
            key: const ValueKey<String>('launch-graduation-notice'),
            icon: 'shield',
            tone: LoopNoticeTone.warn,
            title: context.l10n.launch_detailScreensLaunchGraduationNoticeTitle,
            body: onChain == null
                ? context.l10n.launch_detailScreensLaunchGraduationNoticeBody
                : context.l10n.launch_detailScreensLaunchGraduationNoticeBody2,
            margin: const EdgeInsets.fromLTRB(
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
      title: context.l10n.launch_detailScreensLoopLabel,
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: context.l10n.launch_detailScreensKicker4,
          // No evaluator: the heading says there is no value, never a guessed
          // "Public". An evaluator that answered `null` is "not listed".
          // Decision 0094: the server's open branch (an all-zero root) is a
          // public round, never 「待确认」 and never a tier.
          heading: evaluated == null
              ? launchMissingResult
              : evaluated.rootIsZero
              ? context.l10n.launch_detailScreensS6
              : tier == null
              ? context.l10n.launch_detailScreensHeading4
              : launchTierLabel(tier),
          caption: evaluated != null && evaluated.rootIsZero
              ? context.l10n.launch_detailScreensCaption5
              : context.l10n.launch_detailScreensCaption6,
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
              label: context.l10n.launch_detailScreensLaunchTierConditionsLabel,
              value: launchEligibilityModeLabel(eligibility.mode),
              valueSize: 18,
              trailingLabel: context.l10n.common_snapshotBlock,
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
              title: context
                  .l10n
                  .launch_detailScreensLaunchTierCapabilityUnavailableTitle,
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
            emptyMessage: context.l10n.launch_detailScreensEmptyMessage4,
            emptyReason: context.l10n.launch_detailScreensEmptyReason,
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
                  label:
                      context.l10n.launch_detailScreensLaunchTierOpenStakeLabel,
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
                context.l10n.launch_detailScreensText,
                style: LoopType.caption.copyWith(color: LoopColors.text2),
              ),
            ),
          if (evaluated != null) ...<Widget>[
            LoopLabel(context.l10n.launch_detailScreensLoopLabel10),
            LoopRecordGroup(
              key: const ValueKey<String>('launch-tier-result-rows'),
              rows: <LoopRecordRow>[
                LoopRecordRow(
                  key: const ValueKey<String>('launch-tier-round'),
                  title: context.l10n.launch_detailScreensLaunchTierRoundTitle,
                  trailing: 'Round ${evaluated.roundIndex}',
                  position: LoopRowPosition.first,
                  chevron: false,
                ),
                LoopRecordRow(
                  key: const ValueKey<String>('launch-tier-root'),
                  title: context.l10n.launch_detailScreensLaunchTierRootTitle,
                  subtitle: evaluated.rootIsZero
                      ? context.l10n.launch_detailScreensLaunchTierRootSubtitle
                      : context
                            .l10n
                            .launch_detailScreensLaunchTierRootSubtitle2,
                  trailing: evaluated.rootIsZero
                      ? context.l10n.launch_detailScreensLaunchTierRootTrailing
                      : launchShortHex(evaluated.allowlistRoot),
                  position: LoopRowPosition.middle,
                  chevron: false,
                ),
                LoopRecordRow(
                  key: const ValueKey<String>('launch-tier-proof'),
                  title: context.l10n.launch_detailScreensLaunchTierProofTitle,
                  subtitle:
                      context.l10n.launch_detailScreensLaunchTierProofSubtitle,
                  trailing: context.l10n
                      .launch_detailScreensLaunchTierProofTrailing(
                        evaluated.eligibilityProof.length,
                      ),
                  position: LoopRowPosition.last,
                  chevron: false,
                ),
              ],
            ),
          ],
          LoopLabel(context.l10n.launch_detailScreensLaunchTierConditionsLabel),
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
                      ? context.l10n.common_notConfigured
                      : context.l10n.launch_detailScreensS8,
                  kind: eligibility.mode == LaunchEligibilityMode.unavailable
                      ? LoopBadgeKind.mute
                      : LoopBadgeKind.launch,
                ),
                position: LoopRowPosition.first,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('launch-tier-config-version'),
                title: context
                    .l10n
                    .launch_detailScreensLaunchTierConfigVersionTitle,
                // The version that carries the rule is a backend identifier;
                // when it takes effect is the part a reader can use.
                subtitle: eligibility.effectiveAt == null
                    ? context
                          .l10n
                          .launch_detailScreensLaunchTierConfigVersionSubtitle
                    : context.l10n
                          .launch_detailScreensLaunchTierConfigVersionSubtitle2(
                            launchTimestampLabel(eligibility.effectiveAt!),
                          ),
                position: LoopRowPosition.middle,
              ),
              LoopRecordRow(
                key: const ValueKey<String>('launch-tier-depends-on-staking'),
                title: context
                    .l10n
                    .launch_detailScreensLaunchTierDependsOnStakingTitle,
                // Decision 0053: the mode decides. The row reports what this
                // launch's approved mode answered, and claims nothing about
                // the next one.
                subtitle: context
                    .l10n
                    .launch_detailScreensLaunchTierDependsOnStakingSubtitle,
                trailing: eligibility.dependsOnStaking
                    ? context
                          .l10n
                          .launch_detailScreensLaunchTierDependsOnStakingTrailing
                    : context
                          .l10n
                          .launch_detailScreensLaunchTierDependsOnStakingTrailing2,
                position: LoopRowPosition.last,
              ),
            ],
          ),
          LoopNotice(
            key: const ValueKey<String>('launch-tier-result'),
            icon: 'ticket',
            title: context.l10n.launch_detailScreensLaunchTierResultTitle,
            body: context.l10n.launch_detailScreensLaunchTierResultBody(
              eligibility.reasonCode == null
                  ? ''
                  : launchReasonCodeText(eligibility.reasonCode),
            ),
            margin: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              22,
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
      title: context.l10n.launch_detailScreensLaunchDetailOpenHoldersTitle,
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: context.l10n.launch_detailScreensKicker5,
          heading: count == null
              ? launchMissingHeading
              // Decision 0077 ruling 7 / 0089: `holderCount` counts distinct
              // buyers, not the wallets holding the token today.
              : context.l10n.launch_detailScreensSwitch(
                  loopGroupedFigure(count.holderCount.toString()),
                ),
          caption: count == null
              ? context.l10n.launch_detailScreensCaption7
              : context.l10n.launch_detailScreensCaption8(
                  loopGroupedFigure(count.indexedBlockNumber),
                ),
          stamp: count == null
              ? context.l10n.common_unavailable
              : context.l10n.launch_detailScreensStamp2,
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        // `.launch-holders-summary`: concentration and the cap, side by side.
        // Concentration has no source in any schema, so it keeps the em dash.
        detail: <Widget>[
          LoopCompositeDetailRow(
            label: context.l10n.launch_detailScreensLabel3,
            value: loopFigureDash,
            valueSize: 18,
            trailingLabel: context.l10n.launch_detailScreensTrailingLabel2,
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
          LoopCompositeDetailNote(
            context.l10n.launch_detailScreensLoopCompositeDetailNote3,
          ),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-holders-capability-unavailable',
              ),
              title: context
                  .l10n
                  .launch_detailScreensLaunchHoldersCapabilityUnavailableTitle,
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (holders == null)
          LaunchStateBlock(
            prefix: 'launch-holders',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: context.l10n.launch_detailScreensEmptyMessage5,
            emptyReason: context.l10n.launch_detailScreensEmptyReason,
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          LoopLabel(context.l10n.launch_detailScreensLoopLabel11),
          // The ranking has no source, so no address is invented. The one row
          // the reader owns keeps its place, with the Lime `YOU` tile.
          LoopRecordGroup(
            key: const ValueKey<String>('launch-holders-list'),
            rows: <LoopRecordRow>[
              if (position == null)
                LoopRecordRow(
                  key: const ValueKey<String>('launch-holders-me'),
                  leading: LoopMonoTile(label: context.l10n.common_me),
                  selected: true,
                  title: context.l10n.launch_detailScreensLaunchHoldersMeTitle,
                  subtitle: context.l10n
                      .launch_detailScreensLaunchHoldersMeSubtitle(
                        launchMissingFigure,
                        launchMissingFigure,
                      ),
                  trailing: launchMissingFigure,
                  semanticLabel: context.l10n
                      .launch_detailScreensLaunchHoldersMeSemanticLabel(
                        launchReasonCodeText(holders.myPosition.reasonCode),
                      ),
                )
              else
                LoopRecordRow(
                  key: const ValueKey<String>('launch-holders-me'),
                  leading: LoopMonoTile(label: context.l10n.common_me),
                  selected: true,
                  title: context.l10n.launch_detailScreensLaunchHoldersMeTitle,
                  subtitle: context.l10n
                      .launch_detailScreensLaunchHoldersMeSubtitle2(
                        launchUnitsFigure(position.purchasedTokens),
                        launchUnitsFigure(position.claimableTokens),
                        launchUnitsFigure(position.claimedTokens),
                        launchUsd1Label(position.cumulativeUsd1),
                        launchUsd1Label(position.refundableUsd1),
                      ),
                  subtitleMaxLines: 3,
                  trailing: launchUnitsFigure(position.entitledTokens),
                  trailingCaption: context
                      .l10n
                      .launch_detailScreensLaunchHoldersMeTrailingCaption,
                  semanticLabel: context.l10n
                      .launch_detailScreensLaunchHoldersMeSemanticLabel2(
                        position.snapshotBlockNumber,
                      ),
                ),
            ],
          ),
          if (cap != null) ...<Widget>[
            LoopLabel(context.l10n.launch_detailScreensLoopLabel12),
            LoopRecordGroup(
              key: const ValueKey<String>('launch-holders-cap'),
              rows: <LoopRecordRow>[
                for (var index = 0; index < cap.rounds.length; index += 1)
                  LoopRecordRow(
                    key: ValueKey<String>(
                      'launch-holders-cap-${cap.rounds[index].roundIndex}',
                    ),
                    title: 'Round ${cap.rounds[index].roundIndex}',
                    subtitle: context.l10n.launch_detailScreensSubtitle(
                      launchUsd1Label(cap.rounds[index].cumulativeUsd1),
                    ),
                    trailing: launchUsd1Label(
                      cap.rounds[index].walletRoundCapUsd1,
                    ),
                    trailingCaption:
                        context.l10n.launch_detailScreensTrailingCaption,
                    position: launchRowPosition(index, cap.rounds.length),
                    chevron: false,
                  ),
              ],
            ),
          ],
          switch (holders.holders) {
            LaunchReadingUnavailable<LaunchHolderCount>(:final fact) =>
              LaunchUnavailableCard(
                id: 'holder-distribution',
                label: context.l10n.launch_detailScreensLabel4,
                fact: fact,
              ),
            LaunchReadingAvailable<LaunchHolderCount>() =>
              const SizedBox.shrink(),
          },
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
      title: context.l10n.launch_detailScreensLaunchDetailOpenHistoryTitle,
      onBack: widget.onBack,
      primary: LoopLedgerComposite(
        primary: LoopFolioPrimary(
          variant: LoopFolioVariant.quiet,
          archetype: LoopFolioArchetype.record,
          kicker: context.l10n.launch_detailScreensKicker6,
          heading: indexed == null
              ? launchMissingHeading
              : context.l10n.launch_detailScreensIf6(purchases.length),
          caption: indexed == null
              ? context.l10n.launch_detailScreensCaption9
              : context.l10n.launch_detailScreensCaption10(
                  loopGroupedFigure(indexed.indexedBlockNumber),
                ),
          stamp: indexed == null
              ? context.l10n.common_unavailable
              : context.l10n.launch_detailScreensStamp2,
          margin: EdgeInsets.zero,
          squareBottom: true,
        ),
        detail: <Widget>[
          LoopCompositeDetailRow(
            label: context.l10n.launch_detailScreensLabel5,
            value: indexed == null
                ? loopFigureDash
                : purchases.length.toString(),
            valueSize: 18,
            // No schema carries a result or a profit, so it stays the dash.
            trailingLabel: context.l10n.launch_detailScreensTrailingLabel3,
            trailingValue: loopFigureDash,
            spoken: indexed == null ? launchPendingConfirmationLabel : null,
          ),
          const LoopHairline(),
          LoopCompositeDetailNote(
            context.l10n.launch_detailScreensLoopCompositeDetailNote4,
          ),
        ],
      ),
      block: blocked
          ? LoopCapabilityPageBlock.of(
              key: const ValueKey<String>(
                'launch-history-capability-unavailable',
              ),
              title: context
                  .l10n
                  .launch_detailScreensLaunchHistoryCapabilityUnavailableTitle,
              capability: capability,
            )
          : null,
      sections: <Widget>[
        if (history == null)
          LaunchStateBlock(
            prefix: 'launch-history',
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: context.l10n.launch_detailScreensEmptyMessage6,
            emptyReason: context.l10n.launch_detailScreensEmptyReason,
            onRetry: () => unawaited(controller.reload()),
          )
        else if (indexed == null) ...<Widget>[
          LoopLabel(context.l10n.launch_detailScreensLoopLabel13),
          switch (history.source) {
            LaunchReadingUnavailable<LaunchIndexedSource>(:final fact) =>
              LaunchUnavailableCard(
                id: 'history-records',
                label: context.l10n.launch_detailScreensLabel6,
                fact: fact,
              ),
            LaunchReadingAvailable<LaunchIndexedSource>() =>
              const SizedBox.shrink(),
          },
          const SizedBox(height: 20),
        ] else if (history.isEmpty) ...<Widget>[
          LoopEmptyState(
            key: const ValueKey<String>('launch-history-indexed-empty'),
            illustration: LoopIllustration.history,
            title:
                context.l10n.launch_detailScreensLaunchHistoryIndexedEmptyTitle,
            message: context.l10n
                .launch_detailScreensLaunchHistoryIndexedEmptyMessage(
                  loopGroupedFigure(indexed.indexedBlockNumber),
                ),
            compact: true,
          ),
          const SizedBox(height: 20),
        ] else ...<Widget>[
          // Decision 0103: once the server lists claims and refunds they sit
          // on one timeline with the purchases.
          if (history.settlements?.isNotEmpty ?? false) ...<Widget>[
            LoopLabel(context.l10n.launch_detailScreensLoopLabel14),
            _HistoryTimeline(
              entries: launchHistoryTimeline(history),
              ticker: ref
                  .watch(launchDetailControllerProvider)
                  .value
                  ?.launch
                  .ticker,
            ),
          ] else if (purchases.isNotEmpty) ...<Widget>[
            LoopLabel(context.l10n.launch_detailScreensLoopLabel15),
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
                    title: context.l10n.launch_detailScreensTitle(
                      launchUsd1Label(purchases[index].usd1Amount),
                    ),
                    subtitle: context.l10n.launch_detailScreensSubtitle2(
                      loopGroupedFigure(purchases[index].blockNumber),
                      launchShortHex(purchases[index].transactionHash),
                      launchTimestampLabel(purchases[index].observedAt),
                      launchUnitsFigure(purchases[index].tokenAmount),
                    ),
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
            LoopLabel(context.l10n.launch_detailScreensLoopLabel16),
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
                    title: context.l10n
                        .launch_detailScreensLaunchHistoryEntitlementTitle(
                          launchUnitsFigure(
                            history.entitlements[index].entitledTokens,
                          ),
                        ),
                    subtitle: context.l10n
                        .launch_detailScreensLaunchHistoryEntitlementSubtitle(
                          launchUnitsFigure(
                            history.entitlements[index].claimedTokens,
                          ),
                        ),
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
            LoopLabel(context.l10n.launch_detailScreensLoopLabel17),
            LoopRecordGroup(
              key: const ValueKey<String>('launch-history-refunds'),
              rows: <LoopRecordRow>[
                for (var index = 0; index < history.refunds.length; index += 1)
                  LoopRecordRow(
                    key: ValueKey<String>(
                      'launch-history-refund-'
                      '${history.refunds[index].refundLiabilityId}',
                    ),
                    title: context.l10n
                        .launch_detailScreensLaunchHistoryRefundTitle(
                          launchUsd1Label(
                            history.refunds[index].refundableUsd1,
                          ),
                        ),
                    subtitle: context.l10n
                        .launch_detailScreensLaunchHistoryRefundSubtitle(
                          launchUsd1Label(history.refunds[index].refundedUsd1),
                        ),
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

/// Purchases and settlements as one group (decision 0103). A purchase row is
/// the one the 认购 group draws; a settlement row carries 已领取 / 已退款.
class _HistoryTimeline extends StatelessWidget {
  const _HistoryTimeline({required this.entries, this.ticker});

  final List<LaunchHistoryEntry> entries;
  final String? ticker;

  @override
  Widget build(BuildContext context) {
    return LoopRecordGroup(
      key: const ValueKey<String>('launch-history-records'),
      rows: <LoopRecordRow>[
        for (var index = 0; index < entries.length; index += 1)
          _row(entries[index], launchRowPosition(index, entries.length)),
      ],
    );
  }

  LoopRecordRow _row(LaunchHistoryEntry entry, LoopRowPosition position) {
    final purchase = entry.purchase;
    if (purchase != null) {
      return LoopRecordRow(
        key: ValueKey<String>(
          'launch-history-purchase-${purchase.purchaseRecordId}',
        ),
        leading: LoopMonoTile(label: 'R${purchase.roundIndex}'),
        title: LoopL10n.current.launch_detailScreensTitle(
          launchUsd1Label(purchase.usd1Amount),
        ),
        subtitle: LoopL10n.current.launch_detailScreensSubtitle2(
          loopGroupedFigure(purchase.blockNumber),
          launchShortHex(purchase.transactionHash),
          launchTimestampLabel(purchase.observedAt),
          launchUnitsFigure(purchase.tokenAmount),
        ),
        subtitleMaxLines: 2,
        trailingBadge: LoopBadge(
          purchase.confirmationState.label,
          kind: purchase.confirmationState == LaunchConfirmationState.confirmed
              ? LoopBadgeKind.launch
              : LoopBadgeKind.mute,
        ),
        position: position,
        chevron: false,
      );
    }
    final settlement = entry.settlement!;
    final claimed = settlement.kind == LaunchSettlementKind.claimed;
    final amount = claimed
        ? '${launchUnitsFigure(settlement.amount)} ${ticker ?? LoopL10n.current.launch_tokensUnit}'
        : launchUsd1Label(settlement.amount);
    final total = claimed
        ? LoopL10n.current.launch_detailScreensIf15(
            launchUnitsFigure(settlement.cumulativeAmount),
          )
        : LoopL10n.current.launch_detailScreensS9(
            launchUsd1Label(settlement.cumulativeAmount),
          );
    final reorged =
        settlement.confirmationState == LaunchConfirmationState.reorged;
    return LoopRecordRow(
      key: ValueKey<String>(
        'launch-history-settlement-${settlement.settlementRecordId}',
      ),
      leading: LoopMonoTile(
        label: claimed
            ? LoopL10n.current.launch_detailScreensLabel7
            : LoopL10n.current.launch_detailScreensLabel8,
      ),
      title: claimed
          ? LoopL10n.current.launch_detailScreensClaimAmount(amount)
          : LoopL10n.current.launch_detailScreensRefundAmount(amount),
      subtitle: LoopL10n.current.launch_detailScreensSubtitle3(
        loopGroupedFigure(settlement.blockNumber),
        settlement.confirmationState.label,
        launchShortHex(settlement.transactionHash),
        launchTimestampLabel(settlement.observedAt),
        total,
      ),
      subtitleMaxLines: 2,
      trailingBadge: LoopBadge(
        reorged
            ? LoopL10n.current.launch_detailScreensLoopBadge
            : settlement.kind.label,
        kind: settlement.confirmationState == LaunchConfirmationState.confirmed
            ? LoopBadgeKind.launch
            : LoopBadgeKind.mute,
      ),
      position: position,
      chevron: false,
    );
  }
}
