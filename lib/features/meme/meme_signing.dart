import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/core/text/loop_token_text.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/meme/meme_controllers.dart';
import 'package:loop_mobile/features/meme/meme_format.dart';
import 'package:loop_mobile/features/meme/meme_gateway.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/security/step_up/step_up_controller.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';
import 'package:loop_mobile/features/security/step_up/step_up_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

// ---------------------------------------------------------------------------
// The MEME signing exit (client decision 0120, contract §8)
// ---------------------------------------------------------------------------
//
// A create, a buy and a sell are one server intent each. When the intent
// carries an `approval`, the approval's transaction is signed first (nonce N)
// and the main transaction straight after (nonce N+1); only the main hash is
// reported. Both go through the shared `LoopSignSheet`, both reach the wallet
// as `SigningIntent.backendCanonical` carrying the server's transaction
// verbatim and the intent's `payloadDigest`, and neither is ever assembled
// on the device. A broadcast is 「已广播」, never a result: the result is the
// intent's own `state`, read until it reaches `confirmed`, `failed` or
// `expired`.
//
// The curve lives on the Launch chain slot (contract §12, decision 0038), so
// the two halves travel under the two Launch-slot intent kinds — the only
// kinds the wallet boundary admits off the primary chain.

/// How one trip through the MEME signing exit ended.
@immutable
final class MemeSignOutcome {
  const MemeSignOutcome({
    required this.status,
    required this.reasonCode,
    this.txHash,
    this.approvalTxHash,
    this.reported,
  });

  final MoneySignStatus status;
  final String reasonCode;

  /// The main transaction's hash, when the wallet produced one.
  final String? txHash;

  /// The approval's hash, when the wallet broadcast one. It is never
  /// reported; the server reads the allowance itself.
  final String? approvalTxHash;

  /// The server's intent after the report, when one landed.
  final MemeIntent? reported;

  /// Once the wallet may have broadcast the main transaction, the attempt is
  /// over: no second signature is offered for it.
  bool get isLocked =>
      status == MoneySignStatus.locked ||
      status == MoneySignStatus.reportRefused ||
      status == MoneySignStatus.submitted;
}

String memeIntentTitle(MemeIntentKind kind) => switch (kind) {
  MemeIntentKind.create => LoopL10n.current.meme_signingCreate,
  MemeIntentKind.buy => LoopL10n.current.meme_signingBuy,
  MemeIntentKind.sell => LoopL10n.current.meme_signingSell,
};

String memeIntentNoun(MemeIntentKind kind) => switch (kind) {
  MemeIntentKind.create => LoopL10n.current.meme_createLoopButton,
  MemeIntentKind.buy => LoopL10n.current.common_buy,
  MemeIntentKind.sell => LoopL10n.current.common_sell,
};

/// The reviewed facts for one intent. The sheet renders exactly these, and
/// they are read from the same object whose transactions the wallet gets.
List<IntentField> memeIntentFields(
  MemeIntent intent, {
  required String symbol,
}) {
  final ticker = loopTickerLabel(symbol);
  final approval = intent.approval;
  return <IntentField>[
    IntentField(
      label: LoopL10n.current.common_actions,
      value: '${memeIntentNoun(intent.kind)} $ticker',
    ),
    if (intent.kind == MemeIntentKind.create && intent.predictedAddress != null)
      IntentField(
        label: LoopL10n.current.meme_createLoopLabel,
        value: memeShortAddress(intent.predictedAddress!),
      ),
    if (intent.kind == MemeIntentKind.sell) ...<IntentField>[
      IntentField(
        label: LoopL10n.current.common_sell,
        value: memeTokenLabel(intent.tokenAmount, ticker),
      ),
      IntentField(
        label: LoopL10n.current.meme_signingLabel,
        value: memeUsd1Label(intent.expectedOut),
      ),
      IntentField(
        label: LoopL10n.current.meme_signingLabel2,
        value: memeUsd1Label(intent.minOut),
      ),
    ] else if (intent.usd1Amount > BigInt.zero) ...<IntentField>[
      IntentField(
        label: intent.kind == MemeIntentKind.create
            ? LoopL10n.current.meme_signingLabel3
            : LoopL10n.current.common_pay,
        value: memeUsd1Label(intent.usd1Amount),
      ),
      IntentField(
        label: LoopL10n.current.common_estimatedReceive,
        value: memeTokenLabel(intent.expectedOut, ticker),
      ),
      IntentField(
        label: LoopL10n.current.common_minimumReceive,
        value: memeTokenLabel(intent.minOut, ticker),
      ),
      if (intent.refund > BigInt.zero)
        IntentField(
          label: LoopL10n.current.meme_signingLabel4,
          value: memeUsd1Label(intent.refund),
        ),
    ],
    if (intent.fee > BigInt.zero)
      IntentField(
        label: LoopL10n.current.meme_signingLabel5,
        value: memeUsd1Label(intent.fee, maxFractionDigits: 4),
      ),
    if (approval != null)
      IntentField(
        label: LoopL10n.current.meme_signingLabel6,
        value: intent.kind == MemeIntentKind.sell
            ? LoopL10n.current.meme_signingValue(
                memeTokenLabel(approval.amount, ticker),
              )
            : LoopL10n.current.meme_signingValue(
                memeUsd1Label(approval.amount),
              ),
      ),
    IntentField(
      label: LoopL10n.current.common_simulationResult,
      value: switch (intent.simulationStatus) {
        'passed' => LoopL10n.current.common_simulationPassed,
        'reverted' => LoopL10n.current.common_simulationRejected,
        _ =>
          approval != null
              ? LoopL10n.current.meme_signingIntentField
              : LoopL10n.current.common_simulationUnavailable,
      },
    ),
    IntentField(
      label: LoopL10n.current.common_validUntil,
      value: loopDateTimeLabel(intent.expiresAt),
    ),
    IntentField(
      label: LoopL10n.current.common_snapshotBlock,
      value: loopGroupedFigure(intent.snapshotBlockNumber),
    ),
    IntentField(
      label: LoopL10n.current.common_contract,
      value: memeShortAddress(intent.contractAddress),
    ),
    IntentField(
      label: LoopL10n.current.common_network,
      value: loopChainName(intent.chainId),
    ),
  ];
}

/// zh-CN for a refusal before or at the wallet. Every line states that
/// nothing was submitted.
///
/// [approvalSent]: an approval of the same operation was already broadcast,
/// so a step-up cancel or failure says the approval went out and the trade
/// did not (decision 0158) instead of "nothing changed".
String memeSignReasonText(String reasonCode, {bool approvalSent = false}) =>
    switch (reasonCode) {
      // Decision 0152: the large-amount step-up stopped before the wallet.
      loopStepUpCancelledCode ||
      loopStepUpFailedCode when approvalSent => loopStepUpAfterApprovalText,
      loopStepUpCancelledCode => LoopL10n.current.meme_signingSwitch,
      loopStepUpFailedCode => LoopL10n.current.meme_signingSwitch2,
      'INTENT_EXPIRED' => LoopL10n.current.meme_signingSwitch3,
      'REVIEW_PAYLOAD_MISMATCH' => LoopL10n.current.meme_signingSwitch4,
      'MEME_WALLET_ADDRESS_UNKNOWN' => LoopL10n.current.meme_signingSwitch5,
      'MEME_WALLET_ADDRESS_MISMATCH' => LoopL10n.current.meme_signingSwitch6,
      'INTENT_CHAIN_NOT_PERMITTED' ||
      'intent_chain_not_permitted' => LoopL10n.current.meme_signingSwitch7,
      'privy_chain_switch_unsupported' => LoopL10n.current.meme_signingSwitch8,
      'privy_wallet_mismatch' => LoopL10n.current.meme_signingSwitch9,
      'MEME_SIMULATION_REVERTED' => LoopL10n.current.meme_signingSwitch10,
      'MEME_INTENT_EXPIRED' => LoopL10n.current.meme_signingSwitch3,
      _ => LoopL10n.current.meme_signingSwitch11,
    };

/// zh-CN for a refused broadcast report. The wallet already broadcast, so
/// none of these says nothing happened.
String memeReportReasonText(String reasonCode) => switch (reasonCode) {
  'MEME_INTENT_ALREADY_REPORTED' => LoopL10n.current.meme_signingSwitch12,
  'MEME_INTENT_NOT_SIGNABLE' => LoopL10n.current.meme_signingSwitch13,
  'MEME_INTENT_EXPIRED' => LoopL10n.current.meme_signingSwitch14,
  'MEME_TX_PAYLOAD_MISMATCH' => LoopL10n.current.meme_signingSwitch15,
  _ => LoopL10n.current.meme_signingSwitch16,
};

/// Whether a refused report is worth sending again with the same hash.
bool memeReportRetryable(String reasonCode) => !const <String>{
  'MEME_INTENT_ALREADY_REPORTED',
  'MEME_INTENT_NOT_SIGNABLE',
  'MEME_INTENT_EXPIRED',
  'MEME_TX_PAYLOAD_MISMATCH',
}.contains(reasonCode);

/// The one sentence after a broadcast.
String memeBroadcastText(MemeSignOutcome outcome, MemeIntentKind kind) {
  final hash = outcome.txHash;
  final noun = memeIntentNoun(kind);
  if (hash == null) {
    if (outcome.approvalTxHash != null) {
      return LoopL10n.current.meme_signingIf(
        memeShortAddress(outcome.approvalTxHash!),
        noun,
      );
    }
    return LoopL10n.current.meme_signingIf2(noun);
  }
  final short = memeShortAddress(hash);
  if (outcome.reported != null) {
    return LoopL10n.current.meme_signingIf3(short);
  }
  return LoopL10n.current.meme_signingIf4(
    memeReportReasonText(outcome.reasonCode),
    short,
  );
}

/// What one MEME intent is worth in USD1, for the large-amount step-up
/// (decision 0152): what a buy or a create's first buy pays, what a sell
/// expects to receive. A create without a first buy moves no USD1 and is
/// `null`.
Decimal? memeIntentStepUpUsd1(MemeIntent intent) => switch (intent.kind) {
  MemeIntentKind.sell => loopStepUpUsd1FromAtomic(intent.expectedOut),
  MemeIntentKind.buy || MemeIntentKind.create =>
    intent.usd1Amount > BigInt.zero
        ? loopStepUpUsd1FromAtomic(intent.usd1Amount)
        : null,
};

/// The one path from a MEME intent to the wallet.
final class MemeIntentSigner {
  const MemeIntentSigner({required this.wallet, required this.gateway});

  final WalletSigningGateway wallet;
  final MemeGateway gateway;

  static SigningIntent _signingIntent(
    MemeIntent intent, {
    required String revision,
    required IntentKind kind,
    required String title,
    required MemeUnsignedTransaction transaction,
    required String fromAddress,
    required String symbol,
  }) => SigningIntent.backendCanonical(
    revision: revision,
    payloadDigest: intent.payloadDigest,
    title: title,
    kind: kind,
    chainId: intent.chainId,
    payload: DeviceTransactionPayload(
      fromAddress: fromAddress,
      transaction: transaction.wire,
    ),
    observedAt: intent.createdAt,
    expiresAt: intent.expiresAt,
    fields: memeIntentFields(intent, symbol: symbol),
    stepUpUsd1: memeIntentStepUpUsd1(intent),
  );

  /// The approval half, or `null` when the intent carries none.
  static SigningIntent? approvalSigningIntent(
    MemeIntent intent, {
    required String fromAddress,
    required String symbol,
  }) {
    final approval = intent.approval;
    if (approval == null) return null;
    return _signingIntent(
      intent,
      revision: '${intent.memeIntentId}:approval',
      kind: IntentKind.launchApproval,
      title: LoopL10n.current.meme_signingTitle,
      transaction: approval.unsignedTransaction,
      fromAddress: fromAddress,
      symbol: symbol,
    );
  }

  static SigningIntent mainSigningIntent(
    MemeIntent intent, {
    required String fromAddress,
    required String symbol,
  }) => _signingIntent(
    intent,
    revision: intent.memeIntentId,
    kind: IntentKind.launchPurchase,
    title: memeIntentTitle(intent.kind),
    transaction: intent.unsignedTransaction,
    fromAddress: fromAddress,
    symbol: symbol,
  );

  /// Refusals that need nothing but the intent, the wallet address and the
  /// clock. The sheet states them before the wallet is ever opened.
  static String? refusalBeforeWallet(
    MemeIntent intent, {
    required String? fromAddress,
    required DateTime now,
  }) {
    if (!intent.canSignAt(now)) {
      if (!intent.signingAllowed && intent.signingReasonCode != null) {
        return intent.signingReasonCode;
      }
      return 'INTENT_EXPIRED';
    }
    if (!intent.payloadMatchesReview) return 'REVIEW_PAYLOAD_MISMATCH';
    if (fromAddress == null) return 'MEME_WALLET_ADDRESS_UNKNOWN';
    final from = fromAddress.toLowerCase();
    if (intent.unsignedTransaction.from != from ||
        (intent.approval != null &&
            intent.approval!.unsignedTransaction.from != from)) {
      return 'MEME_WALLET_ADDRESS_MISMATCH';
    }
    return null;
  }

  Future<MemeSignOutcome> sign(
    MemeIntent intent, {
    required String? fromAddress,
    required String symbol,
    required DateTime now,
  }) async {
    final refusal = refusalBeforeWallet(
      intent,
      fromAddress: fromAddress,
      now: now,
    );
    if (refusal != null) {
      return MemeSignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: refusal,
      );
    }
    final from = fromAddress!;
    final main = mainSigningIntent(intent, fromAddress: from, symbol: symbol);
    final approval = approvalSigningIntent(
      intent,
      fromAddress: from,
      symbol: symbol,
    );
    if (!main.chainIsPermitted ||
        (approval != null && !approval.chainIsPermitted)) {
      return const MemeSignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'INTENT_CHAIN_NOT_PERMITTED',
      );
    }
    String? approvalHash;
    if (approval != null) {
      final handoff = await wallet.handoff(approval, now: now);
      if (!handoff.accepted || handoff.value == null) {
        // An unknown approval outcome may already be on chain; the main
        // transaction was never offered, so nothing else is.
        return MemeSignOutcome(
          status: handoff.code == 'wallet_outcome_unknown'
              ? MoneySignStatus.locked
              : MoneySignStatus.walletRejected,
          reasonCode: handoff.code,
        );
      }
      approvalHash = handoff.value;
    }
    final handoff = await wallet.handoff(main, now: now);
    if (!handoff.accepted || handoff.value == null) {
      return MemeSignOutcome(
        status: handoff.code == 'wallet_outcome_unknown'
            ? MoneySignStatus.locked
            : MoneySignStatus.walletRejected,
        reasonCode: handoff.code,
        approvalTxHash: approvalHash,
      );
    }
    // Past this line something may be on chain. Nothing below may say that
    // nothing was submitted, and nothing may re-open the confirmation.
    return report(intent, txHash: handoff.value!, approvalTxHash: approvalHash);
  }

  /// Hands one broadcast hash to the server. A refused or lost report is not
  /// a refused transaction: the outcome stays locked and carries the hash.
  Future<MemeSignOutcome> report(
    MemeIntent intent, {
    required String txHash,
    String? approvalTxHash,
  }) async {
    try {
      final reported = await gateway.reportBroadcast(
        memeTokenId: intent.memeTokenId,
        memeIntentId: intent.memeIntentId,
        txHash: txHash,
      );
      return MemeSignOutcome(
        status: MoneySignStatus.submitted,
        reasonCode: reported.state.wireName,
        txHash: txHash,
        approvalTxHash: approvalTxHash,
        reported: reported,
      );
    } on LoopChainException catch (failure) {
      return MemeSignOutcome(
        status: MoneySignStatus.reportRefused,
        reasonCode: failure.reasonCode ?? failure.kind.name,
        txHash: txHash,
        approvalTxHash: approvalTxHash,
      );
    } catch (_) {
      return MemeSignOutcome(
        status: MoneySignStatus.reportRefused,
        reasonCode: 'REPORT_OUTCOME_UNKNOWN',
        txHash: txHash,
        approvalTxHash: approvalTxHash,
      );
    }
  }
}

final memeIntentSignerProvider = Provider<MemeIntentSigner>(
  (ref) => MemeIntentSigner(
    wallet: ref.watch(loopGuardedWalletSigningGatewayProvider),
    gateway: ref.watch(memeGatewayProvider),
  ),
);

/// Opens the signing exit for one prepared intent. `null` means the sheet
/// was closed before the wallet opened; a sheet torn down afterwards still
/// reports a locked outcome.
Future<MemeSignOutcome?> showMemeSignSheet(
  BuildContext context, {
  required MemeIntent intent,
  required MemeIntentSigner signer,
  required String? fromAddress,
  required String symbol,
  DateTime Function()? clock,
}) async {
  final latch = MoneySignLatch();
  final outcome = await showLoopSheet<MemeSignOutcome>(
    context,
    isDismissible: false,
    builder: (context) => MemeSignSheet(
      intent: intent,
      signer: signer,
      fromAddress: fromAddress,
      symbol: symbol,
      clock: clock,
      latch: latch,
    ),
  );
  if (outcome != null) return outcome;
  if (!latch.enteredSigning) return null;
  return MemeSignOutcome(
    status: MoneySignStatus.locked,
    reasonCode: 'SIGNING_INTERRUPTED',
    txHash: latch.txHash,
  );
}

class MemeSignSheet extends StatefulWidget {
  const MemeSignSheet({
    required this.intent,
    required this.signer,
    required this.fromAddress,
    required this.symbol,
    super.key,
    this.clock,
    this.latch,
  });

  final MemeIntent intent;
  final MemeIntentSigner signer;
  final String? fromAddress;
  final String symbol;
  final DateTime Function()? clock;
  final MoneySignLatch? latch;

  @override
  State<MemeSignSheet> createState() => _MemeSignSheetState();
}

class _MemeSignSheetState extends State<MemeSignSheet>
    with LoopStepUpSheetMixin<MemeSignSheet> {
  LoopSignSheetState _state = LoopSignSheetState.pending;
  String? _reason;
  MemeSignOutcome? _outcome;
  bool _submitted = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  @override
  WalletSigningGateway get stepUpWallet => widget.signer.wallet;

  @override
  Decimal? get stepUpUsd1 => memeIntentStepUpUsd1(widget.intent);

  @override
  void initState() {
    super.initState();
    final refusal = MemeIntentSigner.refusalBeforeWallet(
      widget.intent,
      fromAddress: widget.fromAddress,
      now: _now,
    );
    if (refusal != null) {
      _state = LoopSignSheetState.simulationFailed;
      _reason = memeSignReasonText(refusal);
    } else if (widget.intent.approval != null) {
      _reason = LoopL10n.current.meme_signingReason(
        memeIntentNoun(widget.intent.kind),
      );
    }
    if (refusal == null) planStepUp();
  }

  Future<void> _confirm() async {
    if (_submitted) return;
    setState(() {
      _submitted = true;
      _state = LoopSignSheetState.signing;
      _reason = null;
    });
    // Decision 0152: the large-amount step-up runs before the first wallet
    // prompt and covers the approval and the trade.
    final stopped = await runStepUp();
    if (!mounted) return;
    if (stopped != null) {
      setState(() {
        _state = LoopSignSheetState.pending;
        _reason = loopStepUpReasonText(stopped);
        _submitted = false;
      });
      return;
    }
    widget.latch?.enteredSigning = true;
    final outcome = await widget.signer.sign(
      widget.intent,
      fromAddress: widget.fromAddress,
      symbol: widget.symbol,
      now: _now,
    );
    widget.latch?.txHash = outcome.txHash;
    if (!mounted) return;
    setState(() {
      _outcome = outcome;
      switch (outcome.status) {
        case MoneySignStatus.locked:
        case MoneySignStatus.reportRefused:
        case MoneySignStatus.submitted:
          _state = LoopSignSheetState.complete;
          _reason = memeBroadcastText(outcome, widget.intent.kind);
        case MoneySignStatus.refused:
        case MoneySignStatus.walletRejected:
          _state = LoopSignSheetState.simulationFailed;
          _reason = outcome.approvalTxHash != null
              ? (loopStepUpStopped(outcome.reasonCode)
                    ? memeSignReasonText(outcome.reasonCode, approvalSent: true)
                    : LoopL10n.current.meme_signingSetState(
                        memeIntentNoun(widget.intent.kind),
                        memeIntentNoun(widget.intent.kind),
                      ))
              : memeSignReasonText(outcome.reasonCode);
          // An approval that went out makes this intent's nonce plan stale:
          // the page prepares a new one instead of re-opening this sheet.
          _submitted = outcome.approvalTxHash != null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fields = memeIntentFields(widget.intent, symbol: widget.symbol);
    return PopScope(
      canPop: _state != LoopSignSheetState.signing,
      child: withStepUpStrip(
        signLabel: memeIntentNoun(widget.intent.kind),
        signStatus: stepUpSignStatus(
          _state,
          locked: _outcome != null && _outcome!.txHash == null,
        ),
        LoopSignSheet(
          key: const ValueKey<String>('meme-sign-sheet'),
          state: _state,
          signingTitle: stepUpSigningTitle,
          title: memeIntentTitle(widget.intent.kind),
          networkBadge: loopTestnetBadgeFor(widget.intent.chainId),
          facts: <LoopSignFact>[
            for (final IntentField field in fields)
              LoopSignFact(field.label, field.value),
          ],
          reason: _reason,
          onConfirm: _submitted ? null : _confirm,
          onCancel: () => Navigator.of(context).pop(_outcome),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One submission: prepare → sign → report → read until it settles
// ---------------------------------------------------------------------------

enum MemeSubmissionPhase {
  idle,

  /// `POST …/intents` is in flight; no wallet has been opened.
  preparing,

  /// The server refused to prepare. Nothing was signed.
  prepareFailed,

  /// The exit or the wallet refused. Nothing was submitted.
  signRefused,

  /// Broadcast and recorded; the intent is read every few seconds.
  waiting,

  /// Broadcast, but the report did not land or the wallet's outcome is
  /// unknown. Locked: no second signature.
  locked,

  /// The intent was read until the window closed without a final state.
  pollTimedOut,

  confirmed,
  failed,
  expired,
}

@immutable
final class MemeSubmissionState {
  const MemeSubmissionState({
    this.phase = MemeSubmissionPhase.idle,
    this.intent,
    this.failure,
    this.outcome,
    this.attempts = 0,
  });

  final MemeSubmissionPhase phase;
  final MemeIntent? intent;
  final LoopChainException? failure;
  final MemeSignOutcome? outcome;
  final int attempts;

  bool get busy =>
      phase == MemeSubmissionPhase.preparing ||
      phase == MemeSubmissionPhase.waiting;

  /// The attempt is past the wallet: nothing may offer another signature.
  bool get locked =>
      phase == MemeSubmissionPhase.waiting ||
      phase == MemeSubmissionPhase.locked ||
      phase == MemeSubmissionPhase.pollTimedOut;

  MemeSubmissionState copyWith({
    MemeSubmissionPhase? phase,
    MemeIntent? intent,
    int? attempts,
  }) => MemeSubmissionState(
    phase: phase ?? this.phase,
    intent: intent ?? this.intent,
    failure: failure,
    outcome: outcome,
    attempts: attempts ?? this.attempts,
  );
}

/// Owns one create / buy / sell attempt, keyed by what it is about
/// (`create`, or a token id and side).
final class MemeSubmissionController extends Notifier<MemeSubmissionState> {
  MemeSubmissionController(this.scope);

  final String scope;
  Timer? _timer;
  int _generation = 0;

  @override
  MemeSubmissionState build() {
    ref.onDispose(_stop);
    return const MemeSubmissionState();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _generation += 1;
  }

  /// Prepares one intent. Returns it for the signing exit, or `null` when
  /// the server refused (the refusal is kept in state).
  Future<MemeIntent?> prepare({
    required String memeTokenId,
    required MemeIntentKind kind,
    required String walletId,
    String? usd1Amount,
    String? tokenAmount,
    int? slippageBps,
  }) async {
    if (state.busy || state.locked) return null;
    _stop();
    state = const MemeSubmissionState(phase: MemeSubmissionPhase.preparing);
    try {
      final intent = await ref
          .read(memeGatewayProvider)
          .prepareIntent(
            memeTokenId: memeTokenId,
            kind: kind,
            walletId: walletId,
            usd1Amount: usd1Amount,
            tokenAmount: tokenAmount,
            slippageBps: slippageBps,
          );
      if (!ref.mounted) return null;
      state = MemeSubmissionState(intent: intent);
      return intent;
    } on LoopChainException catch (failure) {
      if (!ref.mounted) return null;
      state = MemeSubmissionState(
        phase: MemeSubmissionPhase.prepareFailed,
        failure: failure,
      );
    } catch (_) {
      if (!ref.mounted) return null;
      state = const MemeSubmissionState(
        phase: MemeSubmissionPhase.prepareFailed,
        failure: LoopChainException(LoopChainFailureKind.unexpected),
      );
    }
    return null;
  }

  /// Records what the signing exit reported.
  void recordOutcome(MemeSignOutcome? outcome) {
    final intent = state.intent;
    if (outcome == null) {
      state = const MemeSubmissionState();
      return;
    }
    switch (outcome.status) {
      case MoneySignStatus.refused:
      case MoneySignStatus.walletRejected:
        state = MemeSubmissionState(
          phase: MemeSubmissionPhase.signRefused,
          intent: intent,
          outcome: outcome,
        );
      case MoneySignStatus.submitted:
        state = MemeSubmissionState(
          phase: MemeSubmissionPhase.waiting,
          intent: outcome.reported ?? intent,
          outcome: outcome,
        );
        _settleOrPoll();
      case MoneySignStatus.locked:
      case MoneySignStatus.reportRefused:
        state = MemeSubmissionState(
          phase: MemeSubmissionPhase.locked,
          intent: intent,
          outcome: outcome,
        );
        // The server may still learn of it through its own reconciliation;
        // reading the intent is how the page finds out.
        if (intent != null) unawaited(_poll(_generation));
    }
  }

  /// Sends the same hash again after a report that did not land.
  Future<void> retryReport() async {
    final intent = state.intent;
    final outcome = state.outcome;
    final hash = outcome?.txHash;
    if (intent == null ||
        hash == null ||
        state.phase != MemeSubmissionPhase.locked ||
        outcome?.status != MoneySignStatus.reportRefused) {
      return;
    }
    final next = await ref
        .read(memeIntentSignerProvider)
        .report(intent, txHash: hash, approvalTxHash: outcome?.approvalTxHash);
    if (!ref.mounted) return;
    recordOutcome(next);
  }

  void resumePolling() {
    if (state.phase != MemeSubmissionPhase.pollTimedOut) return;
    state = state.copyWith(phase: MemeSubmissionPhase.waiting, attempts: 0);
    _settleOrPoll();
  }

  /// Back to the plain form after a refusal or a settled attempt.
  void reset() {
    _stop();
    state = const MemeSubmissionState();
  }

  void _settleOrPoll() {
    final intent = state.intent;
    if (intent != null && intent.state.isTerminal) {
      _settle(intent);
      return;
    }
    _stop();
    unawaited(_poll(_generation));
  }

  void _settle(MemeIntent intent) {
    _stop();
    state = MemeSubmissionState(
      phase: switch (intent.state) {
        MemeIntentState.confirmed => MemeSubmissionPhase.confirmed,
        MemeIntentState.failed => MemeSubmissionPhase.failed,
        _ => MemeSubmissionPhase.expired,
      },
      intent: intent,
      outcome: state.outcome,
      attempts: state.attempts,
    );
  }

  Future<void> _poll(int generation) async {
    final polling = ref.read(memePollingProvider);
    final current = state.intent;
    if (current == null) return;
    _timer?.cancel();
    final completer = Completer<void>();
    _timer = Timer(polling.intentInterval, completer.complete);
    await completer.future;
    if (generation != _generation || !ref.mounted) return;
    try {
      final latest = await ref
          .read(memeGatewayProvider)
          .loadIntent(current.memeIntentId);
      if (generation != _generation || !ref.mounted) return;
      if (latest.state.isTerminal) {
        state = state.copyWith(intent: latest);
        _settle(latest);
        return;
      }
      state = state.copyWith(intent: latest, attempts: state.attempts + 1);
    } catch (_) {
      if (generation != _generation || !ref.mounted) return;
      // An unreadable intent does not end the wait.
      state = state.copyWith(attempts: state.attempts + 1);
    }
    if (state.attempts >= polling.intentMaxAttempts) {
      if (state.phase == MemeSubmissionPhase.waiting) {
        state = state.copyWith(phase: MemeSubmissionPhase.pollTimedOut);
      }
      return;
    }
    unawaited(_poll(generation));
  }
}

final memeSubmissionControllerProvider = NotifierProvider.autoDispose
    .family<MemeSubmissionController, MemeSubmissionState, String>(
      MemeSubmissionController.new,
    );

/// The sentence for one submission state, or `null` when there is nothing
/// to say. None of them claims a result before the intent says so.
String? memeSubmissionText(MemeSubmissionState state, MemeIntentKind kind) {
  final noun = memeIntentNoun(kind);
  return switch (state.phase) {
    MemeSubmissionPhase.idle => null,
    MemeSubmissionPhase.preparing => LoopL10n.current.meme_signingPreparing(
      noun,
    ),
    MemeSubmissionPhase.prepareFailed =>
      state.failure == null ? null : memeFailureText(state.failure!),
    MemeSubmissionPhase.signRefused =>
      state.outcome?.approvalTxHash != null
          ? (loopStepUpStopped(state.outcome!.reasonCode)
                ? memeSignReasonText(
                    state.outcome!.reasonCode,
                    approvalSent: true,
                  )
                : LoopL10n.current.meme_signingSwitch17(noun))
          : memeSignReasonText(state.outcome?.reasonCode ?? ''),
    MemeSubmissionPhase.waiting => LoopL10n.current.meme_signingWaiting(
      state.attempts,
      noun,
    ),
    MemeSubmissionPhase.locked =>
      state.outcome == null
          ? LoopL10n.current.meme_signingSwitch18(noun)
          : memeBroadcastText(state.outcome!, kind),
    MemeSubmissionPhase.pollTimedOut =>
      LoopL10n.current.meme_signingPollTimedOut(noun),
    MemeSubmissionPhase.confirmed => LoopL10n.current.meme_signingConfirmed(
      noun,
    ),
    MemeSubmissionPhase.failed => LoopL10n.current.meme_signingFailed(
      memeReasonText(state.intent?.reasonCode),
      noun,
    ),
    MemeSubmissionPhase.expired => LoopL10n.current.meme_signingExpired(
      memeReasonText(state.intent?.reasonCode ?? 'MEME_INTENT_EXPIRED'),
      noun,
    ),
  };
}
