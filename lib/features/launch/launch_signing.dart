import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

/// The Launch purchase through the one signing exit (decision 0088).
///
/// It follows `MoneyActionSigner` step for step and reuses its outcome
/// types: the server's own permission first, then the payload against the
/// review, then the chain, and only then the wallet boundary. The wallet
/// receives `SigningIntent.backendCanonical` carrying the server's
/// `unsignedTransaction` verbatim and its `payloadDigest`.
///
/// There is no report route for a Launch intent yet, so a broadcast hash is
/// never an outcome here: it locks the attempt and the result is left to the
/// launch-event index, which is what `launch-history` reads.
final class LaunchPurchaseSigner {
  const LaunchPurchaseSigner({required this.wallet});

  final WalletSigningGateway wallet;

  /// Status name a broadcast carries into the trade state.
  static const broadcastReason = 'LAUNCH_BROADCAST_AWAITING_INDEX';

  static SigningIntent? toSigningIntent(
    LaunchPurchaseIntent intent, {
    required String? fromAddress,
    required String ticker,
  }) {
    if (fromAddress == null) return null;
    return SigningIntent.backendCanonical(
      revision: intent.launchIntentId,
      payloadDigest: intent.payloadDigest,
      title: launchPurchaseTitle,
      kind: IntentKind.launchPurchase,
      chainId: intent.chainId,
      payload: DeviceTransactionPayload(
        fromAddress: fromAddress,
        transaction: intent.unsignedTransaction.toWire(),
      ),
      observedAt: intent.createdAt,
      expiresAt: intent.expiresAt,
      fields: launchPurchaseFields(intent, ticker: ticker),
    );
  }

  Future<MoneySignOutcome> sign(
    LaunchPurchaseIntent intent, {
    required String? fromAddress,
    required String ticker,
    required DateTime now,
  }) async {
    // 1. The server's own permission and the clock.
    if (!intent.canSignAt(now)) {
      return MoneySignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: intent.state.isSignable
            ? 'INTENT_EXPIRED'
            : 'INTENT_${intent.state.wireName.toUpperCase()}',
      );
    }
    // 2. The transaction must describe the reviewed call.
    if (!intent.payloadMatchesReview) {
      return const MoneySignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'REVIEW_PAYLOAD_MISMATCH',
      );
    }
    final signingIntent = toSigningIntent(
      intent,
      fromAddress: fromAddress,
      ticker: ticker,
    );
    if (signingIntent == null) {
      return const MoneySignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'LAUNCH_WALLET_ADDRESS_UNKNOWN',
      );
    }
    // 3. The chain the owner reviewed must be one a Launch intent may use.
    if (!signingIntent.chainIsPermitted) {
      return const MoneySignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'INTENT_CHAIN_NOT_PERMITTED',
      );
    }
    final handoff = await wallet.handoff(signingIntent, now: now);
    if (!handoff.accepted || handoff.value == null) {
      return MoneySignOutcome(
        status: handoff.code == 'wallet_outcome_unknown'
            ? MoneySignStatus.locked
            : MoneySignStatus.walletRejected,
        reasonCode: handoff.code,
      );
    }
    // Past this line something may be on chain. Nothing below may say that
    // nothing was submitted, and nothing may re-open the confirmation.
    return MoneySignOutcome(
      status: MoneySignStatus.locked,
      reasonCode: broadcastReason,
      txHash: handoff.value,
    );
  }
}

final launchPurchaseSignerProvider = Provider<LaunchPurchaseSigner>(
  (ref) =>
      LaunchPurchaseSigner(wallet: ref.watch(walletSigningGatewayProvider)),
);

const String launchPurchaseTitle = '确认认购';

/// The exact facts shown before signing, read from the server's intent.
///
/// The review card on the page and the signing sheet both call this, so
/// what the owner reads and what travels with the payload cannot drift.
List<IntentField> launchPurchaseFields(
  LaunchPurchaseIntent intent, {
  required String ticker,
}) => <IntentField>[
  const IntentField(label: '操作', value: launchPurchaseTitle),
  IntentField(label: '支付', value: launchUsd1Label(intent.usd1Amount)),
  IntentField(
    label: '预计获得',
    value: '${launchUnitsFigure(intent.expectedTokenAmount)} $ticker',
  ),
  IntentField(
    label: '最少获得',
    value: '${launchUnitsFigure(intent.minTokenAmount)} $ticker',
  ),
  IntentField(label: '轮次', value: 'Round ${intent.roundIndex}'),
  IntentField(
    label: '钱包已累计',
    value: launchUsd1Label(intent.walletCumulativeUsd1),
  ),
  IntentField(label: '有效期至', value: launchTimestampLabel(intent.expiresAt)),
  IntentField(label: '状态摘要', value: launchShortHex(intent.stateTupleDigest)),
  IntentField(
    label: '快照区块',
    value: loopGroupedFigure(intent.snapshotBlockNumber),
  ),
  IntentField(label: '合约', value: launchShortHex(intent.contractAddress)),
  IntentField(label: '网络', value: loopChainName(intent.chainId)),
];

/// zh-CN for a wallet or exit refusal code. Every line states what did not
/// happen; none of them claims a result.
String launchSignReasonText(String reasonCode) => switch (reasonCode) {
  'INTENT_EXPIRED' => '这份认购已过期，没有提交任何交易。请重新获取报价。',
  'REVIEW_PAYLOAD_MISMATCH' => '交易内容与复核内容不一致，已拒绝签名，没有提交任何交易。',
  'LAUNCH_WALLET_ADDRESS_UNKNOWN' => '钱包目录里找不到这笔认购的支付钱包，没有提交任何交易。',
  'INTENT_CHAIN_NOT_PERMITTED' ||
  'intent_chain_not_permitted' => '这条链不允许签名，没有提交任何交易。',
  'privy_chain_switch_unsupported' => '钱包暂时不能在这条链上签名，没有提交任何交易。',
  'privy_wallet_mismatch' => '当前登录的钱包不是这笔认购的支付钱包，没有提交任何交易。',
  'LAUNCH_USD1_ALLOWANCE_INSUFFICIENT' => 'USD1 授权额度不足，没有提交任何交易。请先完成授权。',
  _ => '钱包没有完成签名，没有提交任何交易。',
};

/// Opens the signing exit for one prepared Launch intent.
///
/// It returns `null` only when the sheet was closed before the wallet was
/// opened; a sheet torn down afterwards still reports a locked outcome.
Future<MoneySignOutcome?> showLaunchSignSheet(
  BuildContext context, {
  required LaunchPurchasePrepared prepared,
  required LaunchPurchaseSigner signer,
  required String? fromAddress,
  required String ticker,
  DateTime Function()? clock,
}) async {
  final latch = MoneySignLatch();
  final outcome = await showLoopSheet<MoneySignOutcome>(
    context,
    isDismissible: false,
    builder: (context) => LaunchSignSheet(
      prepared: prepared,
      signer: signer,
      fromAddress: fromAddress,
      ticker: ticker,
      clock: clock,
      latch: latch,
    ),
  );
  if (outcome != null) return outcome;
  if (!latch.enteredSigning) return null;
  return MoneySignOutcome(
    status: MoneySignStatus.locked,
    reasonCode: 'SIGNING_INTERRUPTED',
    txHash: latch.txHash,
  );
}

class LaunchSignSheet extends StatefulWidget {
  const LaunchSignSheet({
    required this.prepared,
    required this.signer,
    required this.fromAddress,
    required this.ticker,
    super.key,
    this.clock,
    this.latch,
  });

  final LaunchPurchasePrepared prepared;
  final LaunchPurchaseSigner signer;
  final String? fromAddress;
  final String ticker;
  final DateTime Function()? clock;
  final MoneySignLatch? latch;

  @override
  State<LaunchSignSheet> createState() => _LaunchSignSheetState();
}

class _LaunchSignSheetState extends State<LaunchSignSheet> {
  LoopSignSheetState _state = LoopSignSheetState.pending;
  String? _reason;
  MoneySignOutcome? _outcome;
  bool _submitted = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  LaunchPurchaseIntent get _intent => widget.prepared.intent;

  @override
  void initState() {
    super.initState();
    final refusal = _preflight();
    if (refusal != null) {
      _state = LoopSignSheetState.simulationFailed;
      _reason = launchSignReasonText(refusal);
    }
  }

  /// Refusals the sheet can state before the wallet is ever opened.
  String? _preflight() {
    if (!_intent.canSignAt(_now)) return 'INTENT_EXPIRED';
    if (!_intent.payloadMatchesReview) return 'REVIEW_PAYLOAD_MISMATCH';
    if (widget.fromAddress == null) return 'LAUNCH_WALLET_ADDRESS_UNKNOWN';
    // A known allowance below the amount would revert on chain. An unread
    // allowance is not a refusal: the contract remains the judge.
    final allowance = widget.prepared.usd1?.allowance;
    if (allowance != null &&
        BigInt.parse(allowance) < BigInt.parse(_intent.usd1Amount)) {
      return 'LAUNCH_USD1_ALLOWANCE_INSUFFICIENT';
    }
    return null;
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
      _intent,
      fromAddress: widget.fromAddress,
      ticker: widget.ticker,
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
          _reason = outcome.txHash == null
              ? '钱包的结果未知，这笔认购已锁定。请在「我的参与记录」查看，不要重复签名。'
              : '钱包已广播（${launchShortHex(outcome.txHash!)}）。'
                    '广播不代表已成交，结果以链上索引为准，'
                    '会出现在「我的参与记录」。不要重复认购。';
        case MoneySignStatus.refused:
        case MoneySignStatus.walletRejected:
          _state = LoopSignSheetState.simulationFailed;
          _reason = launchSignReasonText(outcome.reasonCode);
          _submitted = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fields = launchPurchaseFields(_intent, ticker: widget.ticker);
    return PopScope(
      canPop: _state != LoopSignSheetState.signing,
      child: LoopSignSheet(
        key: const ValueKey<String>('launch-sign-sheet'),
        state: _state,
        title: launchPurchaseTitle,
        networkBadge: loopIsTestnetChainId(_intent.chainId)
            ? loopTestnetBadgeLabel
            : null,
        facts: <LoopSignFact>[
          for (final IntentField field in fields)
            LoopSignFact(field.label, field.value),
        ],
        reason: _reason,
        onConfirm: _confirm,
        onCancel: () => Navigator.of(context).pop(_outcome),
      ),
    );
  }
}
