import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_gateway.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/features/security/step_up/step_up_controller.dart';
import 'package:loop_mobile/features/security/step_up/step_up_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

// ---------------------------------------------------------------------------
// S138 · the claim through the one signing exit (decisions 0140, 0141)
// ---------------------------------------------------------------------------
//
// A claim is one server-prepared transaction: `LoopRewardClaim.claim(...)`
// with a voucher the server signed. It reaches the wallet as
// `SigningIntent.backendCanonical` carrying the server's transaction
// verbatim; nothing is assembled on the device and the amount on the sheet is
// the server's, never a figure the page computed. A broadcast is 「已广播」,
// never a result: the result is the claim's own status, read until it is
// `succeeded`, `failed` or `expired`.
//
// The claim contract is deployed on the Launch slot's BSC testnet first. The
// claim travels under its own kind, `IntentKind.miningClaim`, which the
// signing intent and the Privy device signer admit on the published Launch
// slot alongside the two Launch kinds (`launchSlotIntentKinds`, decision
// 0141). The server's `payloadDigest` (loop-api decision 0123) travels with
// the intent only after the codec has recomputed it from the verbatim
// transaction; the signer refuses again if the two ever differ (decision
// 0143).

/// How one trip through the signing exit ended.
@immutable
final class MiningClaimSignOutcome {
  const MiningClaimSignOutcome({
    required this.status,
    required this.reasonCode,
    this.txHash,
    this.reported,
  });

  final MoneySignStatus status;
  final String reasonCode;
  final String? txHash;

  /// The claim as the server read it after the report, when one landed.
  final MiningClaimRecord? reported;
}

/// The reviewed facts. The sheet renders exactly these.
List<IntentField> miningClaimFields(
  MiningClaimIntent intent, {
  required String? walletAddress,
}) => <IntentField>[
  IntentField(
    label: LoopL10n.current.common_actions,
    value: LoopL10n.current.miningRewards_signingValue,
  ),
  IntentField(
    label: LoopL10n.current.miningRewards_signingLabel,
    value: '${miningLoopFigure(intent.amount)} LOOP',
  ),
  IntentField(
    label: LoopL10n.current.miningRewards_signingLabel2,
    value: walletAddress == null
        ? LoopL10n.current.common_loading
        : miningShortHash(walletAddress),
  ),
  IntentField(
    label: LoopL10n.current.common_contract,
    value: miningShortHash(intent.contractAddress),
  ),
  IntentField(
    label: LoopL10n.current.common_network,
    value: loopChainName(intent.chainId),
  ),
  IntentField(
    label: LoopL10n.current.miningRewards_signingLabel3,
    value: LoopL10n.current.miningRewards_signingValue2,
  ),
  IntentField(
    label: LoopL10n.current.miningRewards_signingLabel4,
    value: loopDateTimeLabel(intent.deadline),
  ),
];

/// zh-CN for a refusal before or at the wallet. Every line says nothing was
/// submitted and the balance stays.
String miningClaimSignReasonText(String reasonCode) => switch (reasonCode) {
  // Decision 0152: the large-amount step-up stopped before the wallet.
  loopStepUpCancelledCode => LoopL10n.current.miningRewards_signingSwitch,
  loopStepUpFailedCode => LoopL10n.current.miningRewards_signingSwitch2,
  'INTENT_EXPIRED' => LoopL10n.current.miningRewards_signingSwitch3,
  'REVIEW_PAYLOAD_MISMATCH' => LoopL10n.current.miningRewards_signingSwitch4,
  'MINING_CLAIM_WALLET_UNKNOWN' =>
    LoopL10n.current.miningRewards_signingSwitch5,
  'MINING_CLAIM_WALLET_MISMATCH' =>
    LoopL10n.current.miningRewards_signingSwitch6,
  'INTENT_CHAIN_NOT_PERMITTED' ||
  'intent_chain_not_permitted' => LoopL10n.current.miningRewards_signingSwitch7,
  'privy_chain_switch_unsupported' =>
    LoopL10n.current.miningRewards_signingSwitch8,
  'privy_wallet_mismatch' => LoopL10n.current.miningRewards_signingSwitch9,
  'MINING_CLAIM_SIMULATION_REVERTED' =>
    LoopL10n.current.miningRewards_screenSwitch27,
  _ => LoopL10n.current.miningRewards_signingSwitch10,
};

/// zh-CN after a broadcast whose report did not land. None says nothing
/// happened.
String miningClaimReportReasonText(String reasonCode) => switch (reasonCode) {
  'MINING_CLAIM_TRANSACTION_CONFLICT' =>
    LoopL10n.current.miningRewards_signingSwitch11,
  'MINING_CLAIM_TRANSACTION_MISMATCH' =>
    LoopL10n.current.miningRewards_signingSwitch12,
  _ => LoopL10n.current.miningRewards_signingSwitch13,
};

/// The one path from a claim voucher to the wallet.
final class MiningClaimSigner {
  const MiningClaimSigner({required this.wallet, required this.gateway});

  final WalletSigningGateway wallet;
  final MiningRewardsGateway gateway;

  static SigningIntent signingIntent(
    MiningClaimIntent intent, {
    required String fromAddress,
  }) => SigningIntent.backendCanonical(
    revision: intent.claimId,
    payloadDigest: intent.payloadDigest,
    title: LoopL10n.current.miningRewards_signingTitle,
    kind: IntentKind.miningClaim,
    chainId: intent.chainId,
    payload: DeviceTransactionPayload(
      fromAddress: fromAddress,
      transaction: intent.transaction.wire,
    ),
    observedAt: intent.createdAt,
    expiresAt: intent.deadline,
    fields: miningClaimFields(intent, walletAddress: fromAddress),
  );

  /// Refusals that need only the voucher, the wallet and the clock. The
  /// sheet states them before the wallet ever opens.
  static String? refusalBeforeWallet(
    MiningClaimIntent intent, {
    required String? fromAddress,
    required DateTime now,
  }) {
    if (!intent.canSignAt(now)) {
      if (!intent.signingAllowed && intent.signingReasonCode != null) {
        return intent.signingReasonCode;
      }
      return 'INTENT_EXPIRED';
    }
    if (!intent.payloadMatchesReview || !intent.digestMatches) {
      return 'REVIEW_PAYLOAD_MISMATCH';
    }
    if (fromAddress == null) return 'MINING_CLAIM_WALLET_UNKNOWN';
    if (intent.transaction.from != fromAddress.toLowerCase()) {
      return 'MINING_CLAIM_WALLET_MISMATCH';
    }
    return null;
  }

  Future<MiningClaimSignOutcome> sign(
    MiningClaimIntent intent, {
    required String? fromAddress,
    required DateTime now,
  }) async {
    final refusal = refusalBeforeWallet(
      intent,
      fromAddress: fromAddress,
      now: now,
    );
    if (refusal != null) {
      return MiningClaimSignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: refusal,
      );
    }
    final signing = signingIntent(intent, fromAddress: fromAddress!);
    if (!signing.chainIsPermitted) {
      return const MiningClaimSignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'INTENT_CHAIN_NOT_PERMITTED',
      );
    }
    final handoff = await wallet.handoff(signing, now: now);
    if (!handoff.accepted || handoff.value == null) {
      return MiningClaimSignOutcome(
        status: handoff.code == 'wallet_outcome_unknown'
            ? MoneySignStatus.locked
            : MoneySignStatus.walletRejected,
        reasonCode: handoff.code,
      );
    }
    // Past this line the claim may be on chain. Nothing below may say that
    // nothing was submitted, and nothing may re-open the confirmation.
    return report(intent, txHash: handoff.value!);
  }

  /// Hands one broadcast hash to the server. A lost report is not a failed
  /// claim: the outcome stays locked and carries the hash.
  Future<MiningClaimSignOutcome> report(
    MiningClaimIntent intent, {
    required String txHash,
  }) async {
    try {
      final reported = await gateway.reportClaim(
        claimId: intent.claimId,
        txHash: txHash,
      );
      return MiningClaimSignOutcome(
        status: MoneySignStatus.submitted,
        reasonCode: reported.status.wireName,
        txHash: txHash,
        reported: reported,
      );
    } on LoopChainException catch (failure) {
      return MiningClaimSignOutcome(
        status: MoneySignStatus.reportRefused,
        reasonCode: failure.reasonCode ?? failure.kind.name,
        txHash: txHash,
      );
    } catch (_) {
      return MiningClaimSignOutcome(
        status: MoneySignStatus.reportRefused,
        reasonCode: 'REPORT_OUTCOME_UNKNOWN',
        txHash: txHash,
      );
    }
  }
}

final miningClaimSignerProvider = Provider<MiningClaimSigner>(
  (ref) => MiningClaimSigner(
    wallet: ref.watch(loopGuardedWalletSigningGatewayProvider),
    gateway: ref.watch(miningRewardsGatewayProvider),
  ),
);

/// Opens the signing exit for one prepared claim. `null`: closed before the
/// wallet opened. A sheet torn down afterwards still reports a locked
/// outcome.
Future<MiningClaimSignOutcome?> showMiningClaimSignSheet(
  BuildContext context, {
  required MiningClaimIntent intent,
  required MiningClaimSigner signer,
  required String? fromAddress,
  DateTime Function()? clock,
}) async {
  final latch = MoneySignLatch();
  final outcome = await showLoopSheet<MiningClaimSignOutcome>(
    context,
    isDismissible: false,
    builder: (context) => MiningClaimSignSheet(
      intent: intent,
      signer: signer,
      fromAddress: fromAddress,
      clock: clock,
      latch: latch,
    ),
  );
  if (outcome != null) return outcome;
  if (!latch.enteredSigning) return null;
  return MiningClaimSignOutcome(
    status: MoneySignStatus.locked,
    reasonCode: 'SIGNING_INTERRUPTED',
    txHash: latch.txHash,
  );
}

/// The confirmation: wallet and amount, then the wallet.
class MiningClaimSignSheet extends StatefulWidget {
  const MiningClaimSignSheet({
    required this.intent,
    required this.signer,
    required this.fromAddress,
    super.key,
    this.clock,
    this.latch,
  });

  final MiningClaimIntent intent;
  final MiningClaimSigner signer;
  final String? fromAddress;
  final DateTime Function()? clock;
  final MoneySignLatch? latch;

  @override
  State<MiningClaimSignSheet> createState() => _MiningClaimSignSheetState();
}

class _MiningClaimSignSheetState extends State<MiningClaimSignSheet> {
  LoopSignSheetState _state = LoopSignSheetState.pending;
  String? _reason;
  MiningClaimSignOutcome? _outcome;
  bool _submitted = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    final refusal = MiningClaimSigner.refusalBeforeWallet(
      widget.intent,
      fromAddress: widget.fromAddress,
      now: _now,
    );
    if (refusal != null) {
      _state = LoopSignSheetState.simulationFailed;
      _reason = miningClaimSignReasonText(refusal);
    }
  }

  Future<void> _confirm() async {
    if (_submitted) return;
    setState(() {
      _submitted = true;
      _state = LoopSignSheetState.signing;
      _reason = null;
    });
    widget.latch?.enteredSigning = true;
    final outcome = await widget.signer.sign(
      widget.intent,
      fromAddress: widget.fromAddress,
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
          _reason = miningClaimBroadcastText(outcome);
        case MoneySignStatus.refused:
        case MoneySignStatus.walletRejected:
          _state = LoopSignSheetState.simulationFailed;
          _reason = miningClaimSignReasonText(outcome.reasonCode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fields = miningClaimFields(
      widget.intent,
      walletAddress: widget.fromAddress,
    );
    return PopScope(
      canPop: _state != LoopSignSheetState.signing,
      child: LoopSignSheet(
        key: const ValueKey<String>('mining-claim-sign-sheet'),
        state: _state,
        title: context.l10n.miningRewards_signingTitle,
        networkBadge: loopTestnetBadgeFor(widget.intent.chainId),
        facts: <LoopSignFact>[
          for (final IntentField field in fields)
            LoopSignFact(field.label, field.value),
        ],
        reason: _reason,
        confirmLabel: context.l10n.miningRewards_signingTitle,
        onConfirm: _submitted ? null : _confirm,
        onCancel: () => Navigator.of(context).pop(_outcome),
      ),
    );
  }
}

/// The one sentence after a broadcast.
String miningClaimBroadcastText(MiningClaimSignOutcome outcome) {
  final hash = outcome.txHash;
  if (hash == null) {
    return LoopL10n.current.miningRewards_signingIf;
  }
  final short = miningShortHash(hash);
  if (outcome.reported != null) {
    return LoopL10n.current.miningRewards_signingIf2(short);
  }
  return LoopL10n.current.miningRewards_signingIf3(
    miningClaimReportReasonText(outcome.reasonCode),
    short,
  );
}
