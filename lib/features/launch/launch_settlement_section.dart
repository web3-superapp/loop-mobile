import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/policy/loop_capability_refresh.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_settlement.dart';
import 'package:loop_mobile/features/launch/launch_signing.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// `launch-detail` · 我的份额: claim and refund (decision 0103).
///
/// The step comes from [launchSettlementView]; the one action prepares a
/// server intent after the capability was re-read (decision 0099), and the
/// intent goes through the Launch signing exit exactly as a purchase does.
/// After the broadcast the block states the server's intent state as it
/// reads it back, and re-reads the position and the history once it settles.
class LaunchSettlementSection extends ConsumerStatefulWidget {
  const LaunchSettlementSection({
    required this.launchId,
    required this.detail,
    super.key,
    this.clock,
  });

  final String? launchId;
  final LaunchDetail detail;
  final DateTime Function()? clock;

  @override
  ConsumerState<LaunchSettlementSection> createState() =>
      _LaunchSettlementSectionState();
}

class _LaunchSettlementSectionState
    extends ConsumerState<LaunchSettlementSection> {
  bool _checkingCapability = false;

  void _reread({bool detail = true}) {
    final launchId = widget.launchId;
    if (launchId == null) return;
    launchRereadAfterIntent(ref, launchId, detail: detail);
  }

  Future<void> _act(LaunchSettlementView view) async {
    final launchId = widget.launchId;
    final kind = view.kind;
    final walletId = view.position?.walletId;
    if (launchId == null || kind == null || walletId == null) return;
    if (_checkingCapability) return;
    // Decision 0099: the capability is re-read before anything is prepared
    // or signed; a gate that closed meanwhile is drawn by the page itself.
    setState(() => _checkingCapability = true);
    await loopRefreshCapabilitiesBeforeSigning(ref);
    if (!mounted) return;
    setState(() => _checkingCapability = false);
    final capability = ref.read(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    if (launchCapabilityBlocks(capability) || capability.evidencePending) {
      return;
    }
    final controller = ref.read(launchSettlementControllerProvider.notifier);
    final prepared = await controller.prepare(
      launchId: launchId,
      walletId: walletId,
      kind: kind,
      snapshot: view.snapshot,
    );
    if (!mounted) return;
    if (prepared == null) {
      final code = ref
          .read(launchSettlementControllerProvider)
          .refusalReasonCode;
      if (launchSettlementRereadCodes.contains(code)) _reread();
      return;
    }
    String? fromAddress;
    final directory = ref.read(walletDirectoryControllerProvider).value;
    for (final wallet in directory?.wallets ?? const <LoopWalletAccount>[]) {
      if (wallet.walletId == prepared.intent.walletId) {
        fromAddress = wallet.address;
      }
    }
    final outcome = await showLaunchSignSheet(
      context,
      prepared: prepared,
      signer: ref.read(launchPurchaseSignerProvider),
      fromAddress: fromAddress,
      ticker: widget.detail.launch.ticker,
      clock: widget.clock,
    );
    if (!mounted) return;
    if (outcome == null) {
      // Closed before the wallet was opened: nothing was signed.
      controller.reset();
      return;
    }
    controller.recordSignOutcome(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch),
    );
    final holdersState = ref.watch(launchHoldersControllerProvider);
    final holders = holdersState.value;
    final view = launchSettlementView(
      onChain: widget.detail.launch.onChainState,
      position: holders?.myPosition,
      positionFailed:
          holders == null &&
          !holdersState.isReady &&
          holdersState.phase != LaunchViewPhase.loading,
    );
    final settlement = ref.watch(launchSettlementControllerProvider);
    // Once the server settles an intent, the position and the records are
    // re-read: a confirmed claim moves them, an expired one may have landed
    // late (S92a.6).
    ref.listen<LaunchIntentState?>(
      launchSettlementControllerProvider.select((state) => state.intent?.state),
      (previous, next) {
        if (previous == next) return;
        if (launchIntentRereads(next)) _reread();
      },
    );
    if (view == null && settlement.kind == null) return const SizedBox.shrink();

    final kind = view?.kind;
    if (kind != null) {
      // The signing wallet's address is read from the wallet directory.
      final directory = ref.watch(walletDirectoryControllerProvider);
      if (directory.phase == LoopChainViewPhase.loading &&
          directory.value == null) {
        scheduleMicrotask(() {
          if (mounted) {
            unawaited(
              ref.read(walletDirectoryControllerProvider.notifier).load(),
            );
          }
        });
      }
    }
    final evidenceClosed =
        launchCapabilityBlocks(capability) || capability.evidencePending;
    // A named refusal stands over the blocks the page read when it came; a
    // newer reading re-opens the action (decision 0103).
    final refusalStands =
        settlement.refusalReasonCode != null &&
        view != null &&
        settlement.refusalSnapshot == view.snapshot;
    final hideForRefusal =
        refusalStands &&
        settlement.refusalReasonCode == 'LAUNCH_NOT_PARTICIPANT';

    final children = <Widget>[
      LoopLabel(context.l10n.launch_settlementSectionLoopLabel),
    ];
    if (view != null) {
      children.add(_stageBlock(view, hideAction: hideForRefusal));
      if (kind != null && !hideForRefusal) {
        final enabled =
            !view.paused &&
            !evidenceClosed &&
            !_checkingCapability &&
            !settlement.busy &&
            !settlement.locked &&
            !refusalStands &&
            widget.launchId != null;
        final label = launchSettlementActionLabel(view);
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: LoopButton(
              key: ValueKey<String>(
                kind == LaunchIntentKind.claim
                    ? 'launch-settlement-claim'
                    : 'launch-settlement-refund',
              ),
              label: _checkingCapability
                  ? moneyCapabilityCheckingLabel
                  : settlement.busy
                  ? context.l10n.launch_settlementSectionLabel
                  : label,
              primary: true,
              block: true,
              onPressed: enabled ? () => unawaited(_act(view)) : null,
              semanticLabel: enabled
                  ? label
                  : context.l10n.launch_settlementSectionSemanticLabel(label),
            ),
          ),
        );
        if (view.paused) {
          children.add(
            LoopNotice(
              key: ValueKey<String>('launch-settlement-paused'),
              icon: 'shield',
              tone: LoopNoticeTone.warn,
              title: context.l10n.launch_settlementSwitch3,
              body: context
                  .l10n
                  .launch_settlementSectionLaunchSettlementPausedBody,
            ),
          );
        } else if (evidenceClosed) {
          children.add(
            LoopNotice(
              key: const ValueKey<String>('launch-settlement-evidence'),
              icon: 'shield',
              tone: LoopNoticeTone.warn,
              title: context
                  .l10n
                  .launch_settlementSectionLaunchSettlementEvidenceTitle,
              body: context.l10n
                  .launch_settlementSectionLaunchSettlementEvidenceBody(
                    launchReasonCodeText(
                      capability.evidenceReasonCode ?? capability.reasonCode,
                    ),
                  ),
            ),
          );
        }
      }
    }
    final progress = _progressBlock(settlement);
    if (progress != null) children.add(progress);
    return Column(
      key: const ValueKey<String>('launch-settlement'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _stageBlock(LaunchSettlementView view, {required bool hideAction}) {
    final position = view.position;
    final block = position == null
        ? null
        : LoopL10n.current.launch_detailScreensTrackFooter(
            loopGroupedFigure(position.snapshotBlockNumber),
          );
    Widget row({
      required String key,
      required String title,
      required String subtitle,
      String? badge,
      bool done = false,
    }) => LoopRecordGroup(
      key: ValueKey<String>(key),
      rows: <LoopRecordRow>[
        LoopRecordRow(
          title: title,
          subtitle: subtitle,
          subtitleMaxLines: 3,
          trailingBadge: badge == null
              ? null
              : LoopBadge(
                  badge,
                  kind: done ? LoopBadgeKind.launch : LoopBadgeKind.mute,
                ),
          chevron: false,
        ),
      ],
    );
    LoopNotice notice(String key, String title, String body) => LoopNotice(
      key: ValueKey<String>(key),
      icon: 'clock',
      title: title,
      body: body,
    );
    switch (view.stage) {
      case LaunchSettlementStage.awaitingFinalize:
        return notice(
          'launch-settlement-awaiting-finalize',
          LoopL10n.current.launch_settlementSectionNotice,
          LoopL10n.current.launch_settlementSectionNotice2,
        );
      case LaunchSettlementStage.awaitingTge:
        return notice(
          'launch-settlement-awaiting-tge',
          LoopL10n.current.launch_settlementSectionNotice3,
          LoopL10n.current.launch_settlementSectionNotice4(
            position == null || !_positive(position.entitledTokens)
                ? ''
                : LoopL10n.current.launch_settlementSectionPositionTokens(
                    launchUnitsFigure(position.entitledTokens),
                  ),
          ),
        );
      case LaunchSettlementStage.refundPending:
        return notice(
          'launch-settlement-refund-pending',
          LoopL10n.current.launch_settlementSectionNotice5,
          LoopL10n.current.launch_settlementSectionNotice6,
        );
      case LaunchSettlementStage.positionReading:
        return row(
          key: 'launch-settlement-reading',
          title: LoopL10n.current.launch_settlementSectionTitle,
          subtitle: LoopL10n.current.launch_settlementSectionSubtitle,
        );
      case LaunchSettlementStage.positionUnread:
        return LoopNotice(
          key: const ValueKey<String>('launch-settlement-unread'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: LoopL10n
              .current
              .launch_settlementSectionLaunchSettlementUnreadTitle,
          body: LoopL10n.current
              .launch_settlementSectionLaunchSettlementUnreadBody(
                view.reasonCode == null
                    ? LoopL10n.current.launch_settlementSectionUnreadPosition
                    : launchReasonCodeText(view.reasonCode),
              ),
        );
      case LaunchSettlementStage.claim:
        return row(
          key: 'launch-settlement-claimable',
          title: LoopL10n.current.launch_settlementSectionTitle2(
            launchUnitsFigure(position!.claimableTokens),
          ),
          subtitle: LoopL10n.current.launch_settlementSectionSubtitle2(
            block,
            launchUnitsFigure(position.claimedTokens),
          ),
          badge: LoopL10n.current.launch_settlementSectionBadge,
          done: true,
        );
      case LaunchSettlementStage.claimNothingYet:
        return row(
          key: 'launch-settlement-nothing-yet',
          title: LoopL10n.current.launch_settlementSwitch5,
          subtitle: LoopL10n.current.launch_settlementSectionSubtitle3(
            block,
            launchUnitsFigure(position!.entitledTokens),
          ),
        );
      case LaunchSettlementStage.claimedSoFar:
        return row(
          key: 'launch-settlement-claimed-so-far',
          title: LoopL10n.current.launch_settlementSectionTitle3(
            launchUnitsFigure(position!.claimedTokens),
          ),
          subtitle: LoopL10n.current.launch_settlementSectionSubtitle4(block),
          badge: LoopL10n.current.launch_chainModelsClaimed2,
          done: true,
        );
      case LaunchSettlementStage.claimedAll:
        return row(
          key: 'launch-settlement-claimed-all',
          title: LoopL10n.current.launch_chainModelsClaimed,
          subtitle: LoopL10n.current.launch_settlementSectionSubtitle5(
            block,
            launchUnitsFigure(position!.claimedTokens),
          ),
          badge: LoopL10n.current.launch_chainModelsDone,
          done: true,
        );
      case LaunchSettlementStage.refund:
        return row(
          key: 'launch-settlement-refundable',
          title: LoopL10n.current.launch_detailScreensLaunchHistoryRefundTitle(
            launchUsd1Label(position!.refundableUsd1),
          ),
          subtitle: LoopL10n.current.launch_settlementSectionSubtitle6(
            block,
            launchUsd1Label(position.refundedUsd1),
          ),
          badge: LoopL10n.current.launch_settlementSectionBadge2,
          done: true,
        );
      case LaunchSettlementStage.refundedAll:
        return row(
          key: 'launch-settlement-refunded-all',
          title: LoopL10n.current.launch_chainModelsRefunded4,
          subtitle: LoopL10n.current.launch_settlementSectionSubtitle7(
            block,
            launchUsd1Label(position!.refundedUsd1),
          ),
          badge: LoopL10n.current.launch_chainModelsDone,
          done: true,
        );
      case LaunchSettlementStage.refundClosed:
        return LoopNotice(
          key: const ValueKey<String>('launch-settlement-refund-closed'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: LoopL10n
              .current
              .launch_settlementSectionLaunchSettlementRefundClosedTitle,
          body: LoopL10n.current
              .launch_settlementSectionLaunchSettlementRefundClosedBody(
                launchUsd1Label(position!.refundableUsd1),
              ),
        );
    }
  }

  static bool _positive(String raw) => BigInt.parse(raw) > BigInt.zero;

  Widget? _progressBlock(LaunchSettlementState settlement) {
    final kind = settlement.kind;
    if (kind == null) return null;
    final controller = ref.read(launchSettlementControllerProvider.notifier);
    if (settlement.busy) {
      return LoopNotice(
        key: ValueKey<String>('launch-settlement-preparing'),
        icon: 'clock',
        title: LoopL10n.current.launch_settlementSectionLabel,
        body: LoopL10n
            .current
            .launch_settlementSectionLaunchSettlementPreparingBody,
      );
    }
    final refusal = settlement.refusalReasonCode;
    if (settlement.refusalKind != null) {
      return LoopNotice(
        key: ValueKey<String>('launch-settlement-refusal-${refusal ?? 'none'}'),
        icon: 'shield',
        tone: LoopNoticeTone.warn,
        title: launchSettlementRefusalTitle(refusal),
        body: launchSettlementRefusalText(
          kind,
          settlement.refusalKind,
          refusal,
        ),
      );
    }
    final signReason = settlement.signReasonCode;
    if (settlement.txHash == null &&
        settlement.signOutcomeStatus != null &&
        settlement.signOutcomeStatus != 'locked' &&
        signReason != null) {
      return LoopNotice(
        key: const ValueKey<String>('launch-settlement-sign-refused'),
        icon: 'shield',
        tone: LoopNoticeTone.warn,
        title: LoopL10n
            .current
            .launch_settlementSectionLaunchSettlementSignRefusedTitle,
        body: launchSignReasonTextFor(kind, signReason),
      );
    }
    if (settlement.signOutcomeStatus == null) return null;
    final intent = settlement.intent;
    if (intent == null) {
      // Broadcast, but the server has not recorded it (or the wallet's
      // outcome is unknown): never a result, and never a second signature.
      return Column(
        key: const ValueKey<String>('launch-settlement-locked'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LoopNotice(
            icon: 'clock',
            tone: LoopNoticeTone.warn,
            title: settlement.txHash == null
                ? LoopL10n.current.launch_settlementSectionTitle4
                : LoopL10n.current.launch_settlementSectionTitle5,
            body: launchBroadcastText(
              LaunchSignOutcome(
                status: MoneySignStatus.values.byName(
                  settlement.signOutcomeStatus!,
                ),
                reasonCode: signReason ?? '',
                txHash: settlement.txHash,
              ),
              kind: kind,
            ),
          ),
          if (settlement.reportRetryable)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: LoopButton(
                key: const ValueKey<String>('launch-settlement-report-retry'),
                label: settlement.reporting
                    ? LoopL10n
                          .current
                          .launch_settlementSectionLaunchSettlementReportRetryLabel
                    : LoopL10n
                          .current
                          .launch_settlementSectionLaunchSettlementReportRetryLabel2,
                block: true,
                onPressed: settlement.reporting
                    ? null
                    : () => unawaited(controller.retryReport()),
              ),
            ),
        ],
      );
    }
    final text = launchSettlementProgressText(kind, intent);
    final confirmed = intent.state == LaunchIntentState.confirmed;
    return Column(
      key: ValueKey<String>('launch-settlement-state-${intent.state.wireName}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LoopNotice(
          icon: confirmed ? 'check' : 'clock',
          tone: confirmed || settlement.settled
              ? LoopNoticeTone.normal
              : LoopNoticeTone.warn,
          title: text.title,
          body: settlement.pollTimedOut
              ? LoopL10n.current.launch_settlementSectionBody(text.body)
              : text.body,
        ),
        if (settlement.pollTimedOut)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: LoopButton(
              key: const ValueKey<String>('launch-settlement-poll-resume'),
              label: LoopL10n
                  .current
                  .launch_settlementSectionLaunchSettlementPollResumeLabel,
              block: true,
              onPressed: controller.resumePolling,
            ),
          ),
      ],
    );
  }
}
