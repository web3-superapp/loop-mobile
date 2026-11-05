import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_controllers.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/nft_send.dart';
import 'package:loop_mobile/features/wallet/wallet_mining_hooks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `tx-result` · the one result page for every money action.
///
/// It reads `GET /v2/wallet-intents/{intentId}` and renders exactly what the
/// server reports. A success toast fires only on `confirmed`; `unknown` is a
/// locked state that is polled and never resubmitted.
class TransactionResultScreen extends ConsumerStatefulWidget {
  const TransactionResultScreen({
    super.key,
    this.intentId,
    this.onBack,
    this.onNavigate,
    this.pollInterval = const Duration(seconds: 4),
    this.maximumPollFailures = 5,
  });

  final String? intentId;
  final VoidCallback? onBack;
  final void Function(String location)? onNavigate;

  /// The base interval. Each consecutive failure doubles the wait, so a server
  /// that is down is not hammered by a page left open.
  final Duration pollInterval;

  /// After this many consecutive failed reads the page stops on its own and
  /// offers a manual retry instead of polling forever.
  final int maximumPollFailures;

  @override
  ConsumerState<TransactionResultScreen> createState() =>
      _TransactionResultScreenState();
}

class _TransactionResultScreenState
    extends ConsumerState<TransactionResultScreen> {
  Timer? _poll;
  int _consecutiveFailures = 0;
  bool _pollingStopped = false;

  /// The `intentId:state` this page has already announced. A toast fires on a
  /// transition into `confirmed`, never on every rebuild or re-read of the
  /// same state.
  String? _announced;

  @override
  void initState() {
    super.initState();
    if (widget.intentId == null) return;
    scheduleMicrotask(() {
      if (mounted) unawaited(_read(initial: true));
    });
    _schedule(widget.pollInterval);
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _schedule(Duration delay) {
    _poll?.cancel();
    _poll = Timer(delay, _tick);
  }

  Future<void> _tick() async {
    if (!mounted || _pollingStopped) return;
    final intentId = widget.intentId;
    if (intentId == null) return;
    final controller = ref.read(
      walletIntentControllerProvider(intentId).notifier,
    );
    if (!controller.keepsPolling) return;
    await _read();
    if (!mounted || _pollingStopped) return;
    if (!controller.keepsPolling) return;
    // Exponential back-off, capped, so a page left open on a failing server
    // settles instead of retrying every few seconds forever.
    final multiplier = 1 << _consecutiveFailures.clamp(0, 4);
    _schedule(widget.pollInterval * multiplier);
  }

  /// Reads once and records whether the read succeeded, so the page can stop
  /// on its own rather than claim it is still watching.
  Future<void> _read({bool initial = false}) async {
    final intentId = widget.intentId;
    if (intentId == null) return;
    final controller = ref.read(
      walletIntentControllerProvider(intentId).notifier,
    );
    await (initial ? controller.load() : controller.reload());
    if (!mounted) return;
    final failed =
        ref.read(walletIntentControllerProvider(intentId)).failureKind != null;
    setState(() {
      _consecutiveFailures = failed ? _consecutiveFailures + 1 : 0;
      if (_consecutiveFailures >= widget.maximumPollFailures) {
        _pollingStopped = true;
        _poll?.cancel();
      }
    });
  }

  /// Restarts polling after the owner asks for it.
  Future<void> _retry() async {
    setState(() {
      _pollingStopped = false;
      _consecutiveFailures = 0;
    });
    await _read();
    if (mounted && !_pollingStopped) _schedule(widget.pollInterval);
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    context.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final intentId = widget.intentId;
    if (intentId == null) {
      return LoopFocusPage(
        key: const ValueKey<String>('tx-result-screen'),
        archetype: LoopPageArchetype.state,
        title: context.l10n.wallet_txResultTxResultScreenTitle,
        onBack: widget.onBack,
        folio: LoopFolioPrimary(
          key: ValueKey<String>('tx-result-folio'),
          // S241b: flat dark card, Chalk heading (no light slab on Ink).
          variant: LoopFolioVariant.quiet,
          headingTone: LoopFolioHeadingTone.neutral,
          ring: false,
          kicker: context.l10n.wallet_txResultTxResultScreenTitle,
          heading: context.l10n.wallet_txResultTxResultFolioHeading,
          caption: context.l10n.wallet_txResultTxResultFolioCaption,
        ),
        body: <Widget>[
          LoopEmptyState(
            key: ValueKey<String>('tx-result-empty'),
            illustration: LoopIllustration.history,
            title: context.l10n.wallet_txResultTxResultEmptyTitle,
            message: context.l10n.wallet_txResultTxResultEmptyMessage,
            compact: true,
          ),
        ],
      );
    }

    // The result page is a read. It must stay readable for every kind — a
    // swap result is not a `sendApprovals` fact — and while the write switch
    // is closed, because a submitted intent still has a state to report.
    final blocked = moneyReadBlocks(
      ref.watch(walletIntentsGatewayProvider).mode,
    );
    final state = ref.watch(walletIntentControllerProvider(intentId));
    final intent = state.value;
    if (intent != null && intent.state == LoopIntentState.confirmed) {
      // The one place a success toast may fire, and only on the transition
      // into `confirmed`: a rebuild or a re-read of the same state is not a
      // new event, and nothing earlier proves on-chain completion.
      final announcement = '${intent.intentId}:${intent.state.wireName}';
      if (_announced != announcement) {
        _announced = announcement;
        scheduleMicrotask(() {
          if (mounted) {
            LoopToast.show(
              context,
              message: context.l10n.wallet_txResultMessage,
            );
          }
        });
        // S339 · decision 0267: a confirmed NFT send moved a Launch holding.
        if (intent.kind == LoopIntentKind.sendNft) {
          scheduleMicrotask(() {
            if (mounted) refreshLaunch2Holdings(ref, null);
          });
        }
      }
    }

    return LoopFocusPage(
      key: const ValueKey<String>('tx-result-screen'),
      archetype: LoopPageArchetype.state,
      title: context.l10n.wallet_txResultTxResultScreenTitle,
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        key: const ValueKey<String>('tx-result-folio'),
        // S241b: flat dark card, Chalk heading (no light slab on Ink).
        variant: LoopFolioVariant.quiet,
        headingTone: LoopFolioHeadingTone.neutral,
        ring: false,
        kicker: context.l10n.wallet_txResultTxResultScreenTitle,
        heading: intent == null
            ? context.l10n.wallet_txResultTxResultFolioHeading2
            : _headline(intent),
        caption: intent == null
            ? context.l10n.wallet_txResultTxResultFolioCaption2
            : _caption(intent),
        stamp: intent == null
            ? null
            : moneyIntentStateLabel(intent.state).toUpperCase(),
      ),
      block: blocked
          ? LoopCapabilityPageBlock(
              key: ValueKey<String>('tx-result-capability-block'),
              title: context.l10n.wallet_txResultTxResultCapabilityBlockTitle,
              reasonCode: 'WALLET_INTENT_RUNTIME_UNAVAILABLE',
            )
          : null,
      body: <Widget>[
        if (intent == null)
          LoopChainStateBlock(
            keyPrefix: 'tx-result',
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: context.l10n.wallet_txResultEmptyMessage,
            onRetry: () => unawaited(_retry()),
          )
        else ...<Widget>[
          _ResultBanner(intent: intent),
          if (intent.state == LoopIntentState.unknown)
            LoopNotice(
              key: const ValueKey<String>('tx-result-unknown-lock'),
              icon: 'warn',
              tone: LoopNoticeTone.danger,
              title: context.l10n.wallet_txResultTxResultUnknownLockTitle,
              body: context.l10n.wallet_txResultTxResultUnknownLockBody(
                loopReasonCodeText(intent.result.reasonCode),
              ),
            ),
          if (intent.state == LoopIntentState.awaitingSignature ||
              intent.state == LoopIntentState.prepared)
            LoopNotice(
              key: ValueKey<String>('tx-result-unreported'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: context.l10n.wallet_txResultTxResultUnreportedTitle,
              body: context.l10n.wallet_txResultTxResultUnreportedBody,
            ),
          if (intent.state == LoopIntentState.submitted)
            LoopNotice(
              key: ValueKey<String>('tx-result-pending'),
              icon: 'clock',
              tone: LoopNoticeTone.warn,
              title: context.l10n.wallet_txResultTxResultPendingTitle,
              body: context.l10n.wallet_txResultTxResultPendingBody,
            ),
          if (_pollingStopped)
            LoopNotice(
              key: const ValueKey<String>('tx-result-polling-stopped'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: context.l10n.wallet_txResultTxResultPollingStoppedTitle,
              body: context.l10n.wallet_txResultTxResultPollingStoppedBody(
                widget.maximumPollFailures,
              ),
              trailing: LoopButton(
                key: const ValueKey<String>('tx-result-poll-retry'),
                label: context.l10n.common_retry,
                onPressed: () => unawaited(_retry()),
              ),
            ),
          // The prototype puts the mining strip right under the result, where
          // it closes the buy → power loop (audit item 8). It reads the
          // Mining module's own snapshot; a snapshot it could not read is a
          // dash, never a zero.
          WalletHoldingsPowerHint(onOpenMining: () => _open('/mining')),
          _ResultFacts(intent: intent),
          LoopLabel(context.l10n.common_share),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('tx-result-forward'),
                label: context.l10n.wallet_txResultTxResultForwardLabel,
                onPressed: intent.state == LoopIntentState.confirmed
                    ? () => _open('/chat/forward')
                    : null,
              ),
              LoopButton(
                key: const ValueKey<String>('tx-result-merge'),
                label: context.l10n.wallet_txResultTxResultMergeLabel,
                onPressed: intent.state == LoopIntentState.confirmed
                    ? () => _open('/chat/merge-preview')
                    : null,
              ),
              LoopButton(
                key: const ValueKey<String>('tx-result-community'),
                label: context.l10n.common_community,
                onPressed: () => _open('/community/chat'),
              ),
            ],
          ),
          MoneyFactsFooter(intent: intent),
        ],
      ],
    );
  }

  String _headline(LoopWalletIntent intent) => switch (intent.state) {
    LoopIntentState.confirmed => LoopL10n.current.wallet_txResultConfirmed(
      _action(intent),
    ),
    LoopIntentState.reverted => LoopL10n.current.wallet_txResultReverted(
      _action(intent),
    ),
    LoopIntentState.failed => LoopL10n.current.wallet_txResultFailed(
      _action(intent),
    ),
    LoopIntentState.unknown => LoopL10n.current.wallet_txResultUnknown(
      _action(intent),
    ),
    LoopIntentState.cancelled => LoopL10n.current.wallet_txResultCancelled(
      _action(intent),
    ),
    LoopIntentState.expired => LoopL10n.current.wallet_txResultExpired(
      _action(intent),
    ),
    _ => LoopL10n.current.wallet_txResultSwitch(_action(intent)),
  };

  String _action(LoopWalletIntent intent) => moneyActionName(intent.kind);

  String _caption(LoopWalletIntent intent) {
    final receipt = intent.result.receipt;
    if (receipt == null) {
      return LoopL10n.current.wallet_txResultIf;
    }
    return LoopL10n.current.wallet_moneyActionsMoneyFactsFooterText(
      loopGroupedFigure(receipt.blockNumber.toString()),
      receipt.confirmations == null
          ? LoopL10n
                .current
                .wallet_txResultWalletMoneyActionsMoneyFactsFooterText
          : LoopL10n.current.wallet_txResultS(
              loopGroupedFigure(receipt.confirmations.toString()),
            ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.intent});

  final LoopWalletIntent intent;

  @override
  Widget build(BuildContext context) {
    final (String label, LoopBadgeKind kind) = switch (intent.state) {
      LoopIntentState.confirmed => (
        context.l10n.common_confirmed,
        LoopBadgeKind.up,
      ),
      LoopIntentState.submitted => (
        context.l10n.wallet_txResultSwitch2,
        LoopBadgeKind.mining,
      ),
      LoopIntentState.reverted || LoopIntentState.failed => (
        context.l10n.common_failed,
        LoopBadgeKind.down,
      ),
      LoopIntentState.unknown => (
        context.l10n.common_unknown,
        LoopBadgeKind.down,
      ),
      _ => (moneyIntentStateLabel(intent.state), LoopBadgeKind.mute),
    };
    return LoopRecordCard(
      key: ValueKey<String>('tx-result-banner-${intent.state.wireName}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  moneyIntentStateLabel(intent.state),
                  style: LoopType.titleLg,
                ),
              ),
              LoopBadge(label, kind: kind),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            intent.result.reasonCode == null
                ? context.l10n.wallet_txResultSwitch3
                : loopReasonCodeText(intent.result.reasonCode),
            style: LoopType.bodySm,
          ),
        ],
      ),
    );
  }
}

class _ResultFacts extends StatelessWidget {
  const _ResultFacts({required this.intent});

  final LoopWalletIntent intent;

  @override
  Widget build(BuildContext context) {
    final receipt = intent.result.receipt;
    final fee = intent.review.fee;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        14,
      ),
      child: LoopSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopKeyValue(
              key: const ValueKey<String>('tx-result-hash'),
              label: context.l10n.wallet_txResultTxResultHashLabel,
              value:
                  intent.result.transactionHash ??
                  context.l10n.wallet_txResultTxResultHashValue,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            if (intent.result.providerActionId != null)
              LoopKeyValue(
                key: const ValueKey<String>('tx-result-action-id'),
                label: context.l10n.wallet_txResultTxResultActionIdLabel,
                value: intent.result.providerActionId!,
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            LoopKeyValue(
              key: const ValueKey<String>('tx-result-confirmations'),
              label: context.l10n.wallet_txResultTxResultConfirmationsLabel,
              value: receipt == null
                  ? context.l10n.wallet_txResultTxResultConfirmationsValue
                  : receipt.confirmations == null
                  ? context.l10n.wallet_txResultTxResultConfirmationsValue2
                  : loopGroupedFigure(receipt.confirmations.toString()),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LoopKeyValue(
              key: const ValueKey<String>('tx-result-gas'),
              label: receipt == null
                  ? context.l10n.wallet_moneyActionsSigningLabel3
                  : context.l10n.wallet_txResultTxResultGasLabel,
              value: receipt == null
                  ? (fee == null
                        ? context.l10n.common_unavailable
                        : '${loopFormatDecimal(fee.maximumFee, maxFractionDigits: 10)} BNB')
                  : '${loopGroupedFigure(receipt.gasUsed)} gas',
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            LoopKeyValue(
              key: const ValueKey<String>('tx-result-updated'),
              label: context.l10n.wallet_txResultTxResultUpdatedLabel,
              value: loopRelativeTime(intent.updatedAt),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ],
        ),
      ),
    );
  }
}
