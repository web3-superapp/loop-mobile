import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_gateway.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

// ---------------------------------------------------------------------------
// S138 · the claim through the one signing exit (decision 0140)
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
// The claim contract is deployed on the Launch slot's BSC testnet first, and
// the wallet boundary admits only the Launch-slot kinds off the primary chain
// (decision 0089), so the claim travels under `launchPurchase` exactly as the
// MEME curve does (decision 0120). A dedicated kind is a core change left to
// the reviewer of this decision.

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
  const IntentField(label: '操作', value: '领取挖矿奖励'),
  IntentField(label: '领取数量', value: '${miningLoopFigure(intent.amount)} LOOP'),
  IntentField(
    label: '收款钱包',
    value: walletAddress == null ? '读取中' : miningShortHash(walletAddress),
  ),
  IntentField(label: '合约', value: miningShortHash(intent.contractAddress)),
  IntentField(label: '网络', value: loopChainName(intent.chainId)),
  const IntentField(label: '网络费', value: '钱包内 BNB 支付'),
  IntentField(label: '凭证有效至', value: loopDateTimeLabel(intent.deadline)),
];

/// zh-CN for a refusal before or at the wallet. Every line says nothing was
/// submitted and the balance stays.
String miningClaimSignReasonText(String reasonCode) => switch (reasonCode) {
  'INTENT_EXPIRED' => '领取凭证已过期，没有提交任何交易，可领取余额不变。请重新领取。',
  'REVIEW_PAYLOAD_MISMATCH' => '交易内容与确认内容不一致，已拒绝签名，没有提交任何交易。',
  'MINING_CLAIM_WALLET_UNKNOWN' => '找不到这笔领取的钱包，没有提交任何交易。',
  'MINING_CLAIM_WALLET_MISMATCH' => '领取凭证对应的钱包与当前钱包不一致，已拒绝签名，没有提交任何交易。',
  'INTENT_CHAIN_NOT_PERMITTED' ||
  'intent_chain_not_permitted' => '这条链不允许签名，没有提交任何交易。',
  'privy_chain_switch_unsupported' => '钱包暂时不能在这条链上签名，没有提交任何交易。',
  'privy_wallet_mismatch' => '当前登录的钱包不是这笔领取的钱包，没有提交任何交易。',
  'MINING_CLAIM_SIMULATION_REVERTED' => '试算没有通过，这笔领取在链上会被拒绝。没有提交任何交易。',
  _ => '钱包没有完成签名，没有提交任何交易，可领取余额不变。',
};

/// zh-CN after a broadcast whose report did not land. None says nothing
/// happened.
String miningClaimReportReasonText(String reasonCode) => switch (reasonCode) {
  'MINING_CLAIM_TRANSACTION_CONFLICT' =>
    '这笔领取已经上报过另一笔哈希，本次广播没有被记录。不要重复领取，稍后刷新查看。',
  'MINING_CLAIM_TRANSACTION_MISMATCH' =>
    '链上这笔交易与领取凭证不一致，服务端没有记录它。不要重复领取，并联系支持。',
  _ => '钱包已经广播，但上报没有送达。交易可能已经上链，可以重新上报同一笔哈希；不要重复领取。',
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
    title: '确认领取',
    kind: IntentKind.launchPurchase,
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
    if (!intent.payloadMatchesReview) return 'REVIEW_PAYLOAD_MISMATCH';
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
    wallet: ref.watch(walletSigningGatewayProvider),
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
        title: '确认领取',
        networkBadge: loopIsTestnetChainId(widget.intent.chainId)
            ? loopTestnetBadgeLabel
            : null,
        facts: <LoopSignFact>[
          for (final IntentField field in fields)
            LoopSignFact(field.label, field.value),
        ],
        reason: _reason,
        confirmLabel: '确认领取',
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
    return '钱包的结果未知，这笔领取已锁定。不要重复领取，稍后刷新查看。';
  }
  final short = miningShortHash(hash);
  if (outcome.reported != null) {
    return '已广播（$short），服务端已记录，正在等待链上确认。';
  }
  return '已广播（$short）。${miningClaimReportReasonText(outcome.reasonCode)}';
}
