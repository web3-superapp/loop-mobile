import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

/// How one trip through the Launch signing exit ended.
///
/// It reuses [MoneySignStatus] so the vocabulary matches the wallet actions:
/// `submitted` is a broadcast the server recorded (never a purchase),
/// `reportRefused` a broadcast the server did not record, `locked` a wallet
/// whose outcome is unknown. [reported] is the server's intent after the
/// report, when one landed.
@immutable
final class LaunchSignOutcome {
  const LaunchSignOutcome({
    required this.status,
    required this.reasonCode,
    this.txHash,
    this.reported,
  });

  final MoneySignStatus status;
  final String reasonCode;
  final String? txHash;
  final LaunchPurchaseIntent? reported;

  /// Once the wallet was opened and may have broadcast, the attempt is over:
  /// the page never offers a second signature for it.
  bool get isLocked =>
      status == MoneySignStatus.locked ||
      status == MoneySignStatus.reportRefused ||
      status == MoneySignStatus.submitted;
}

/// The Launch purchase through the one signing exit (decisions 0088, 0089).
///
/// It follows `MoneyActionSigner` step for step and reuses its outcome
/// vocabulary: the server's own permission first, then the payload against
/// the review, then the chain, and only then the wallet boundary. The wallet
/// receives `SigningIntent.backendCanonical` carrying the server's
/// `unsignedTransaction` verbatim and its `payloadDigest`.
///
/// A broadcast hash is handed straight back to the server through the
/// Launch broadcast report. The server's answer is `submitted` — pending
/// evidence; the purchase itself is whatever the launch-event index later
/// records, which is what `launch-history` reads.
final class LaunchPurchaseSigner {
  const LaunchPurchaseSigner({required this.wallet, required this.gateway});

  final WalletSigningGateway wallet;
  final LaunchGateway gateway;

  static SigningIntent? toSigningIntent(
    LaunchPurchaseIntent intent, {
    required String? fromAddress,
    required String ticker,
  }) {
    if (fromAddress == null) return null;
    return SigningIntent.backendCanonical(
      revision: intent.launchIntentId,
      payloadDigest: intent.payloadDigest,
      title: launchIntentTitle(intent.kind),
      // Decision 0103: every call on the Launch contract — buy, claim,
      // claimRefund — is admitted under the one Launch-contract kind, so the
      // chain rule of decision 0090 stays one rule.
      kind: IntentKind.launchPurchase,
      chainId: intent.chainId,
      payload: DeviceTransactionPayload(
        fromAddress: fromAddress,
        transaction: intent.unsignedTransaction.toWire(),
      ),
      observedAt: intent.createdAt,
      expiresAt: intent.expiresAt,
      fields: launchIntentFields(intent, ticker: ticker),
    );
  }

  /// Refusals that need nothing but the intent, the wallet address and the
  /// clock. The sheet states them before the wallet is ever opened.
  static String? refusalBeforeWallet(
    LaunchPurchaseIntent intent, {
    required String? fromAddress,
    required DateTime now,
  }) {
    if (!intent.canSignAt(now)) {
      final serverReason = intent.signing?.allowed == false
          ? intent.signing?.reasonCode
          : null;
      if (serverReason != null) return serverReason;
      return intent.state.isSignable
          ? 'INTENT_EXPIRED'
          : 'INTENT_${intent.state.wireName.toUpperCase()}';
    }
    if (!intent.payloadMatchesReview) return 'REVIEW_PAYLOAD_MISMATCH';
    if (fromAddress == null) return 'LAUNCH_WALLET_ADDRESS_UNKNOWN';
    final from = intent.unsignedTransaction.from;
    if (from != null && from != fromAddress.toLowerCase()) {
      return 'LAUNCH_WALLET_ADDRESS_MISMATCH';
    }
    return null;
  }

  Future<LaunchSignOutcome> sign(
    LaunchPurchaseIntent intent, {
    required String? fromAddress,
    required String ticker,
    required DateTime now,
  }) async {
    // 1. The server's own permission and the clock.
    if (!intent.canSignAt(now)) {
      return LaunchSignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: refusalBeforeWallet(
          intent,
          fromAddress: fromAddress,
          now: now,
        )!,
      );
    }
    // 2. The transaction must describe the reviewed call.
    if (!intent.payloadMatchesReview) {
      return const LaunchSignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'REVIEW_PAYLOAD_MISMATCH',
      );
    }
    final refusal = refusalBeforeWallet(
      intent,
      fromAddress: fromAddress,
      now: now,
    );
    if (refusal != null) {
      return LaunchSignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: refusal,
      );
    }
    final signingIntent = toSigningIntent(
      intent,
      fromAddress: fromAddress,
      ticker: ticker,
    );
    if (signingIntent == null) {
      return const LaunchSignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'LAUNCH_WALLET_ADDRESS_UNKNOWN',
      );
    }
    // 3. The chain the owner reviewed must be one a Launch intent may use.
    if (!signingIntent.chainIsPermitted) {
      return const LaunchSignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'INTENT_CHAIN_NOT_PERMITTED',
      );
    }
    final handoff = await wallet.handoff(signingIntent, now: now);
    if (!handoff.accepted || handoff.value == null) {
      return LaunchSignOutcome(
        status: handoff.code == 'wallet_outcome_unknown'
            ? MoneySignStatus.locked
            : MoneySignStatus.walletRejected,
        reasonCode: handoff.code,
      );
    }
    // Past this line something may be on chain. Nothing below may say that
    // nothing was submitted, and nothing may re-open the confirmation.
    final hash = handoff.value!;
    return report(intent, txHash: hash);
  }

  /// Hands one broadcast hash to the server. A refused or lost report is not
  /// a refused transaction: the hash may already be on chain, so the outcome
  /// stays locked and carries the hash for a later report.
  Future<LaunchSignOutcome> report(
    LaunchPurchaseIntent intent, {
    required String txHash,
  }) async {
    try {
      final reported = await gateway.reportPurchaseBroadcast(
        launchId: intent.launchId,
        launchIntentId: intent.launchIntentId,
        txHash: txHash,
      );
      return LaunchSignOutcome(
        status: MoneySignStatus.submitted,
        reasonCode: reported.state.wireName,
        txHash: txHash,
        reported: reported,
      );
    } on LaunchException catch (failure) {
      return LaunchSignOutcome(
        status: MoneySignStatus.reportRefused,
        reasonCode: failure.reasonCode ?? failure.kind.name,
        txHash: txHash,
      );
    } catch (_) {
      return LaunchSignOutcome(
        status: MoneySignStatus.reportRefused,
        reasonCode: 'REPORT_OUTCOME_UNKNOWN',
        txHash: txHash,
      );
    }
  }
}

final launchPurchaseSignerProvider = Provider<LaunchPurchaseSigner>(
  (ref) => LaunchPurchaseSigner(
    wallet: ref.watch(walletSigningGatewayProvider),
    gateway: ref.watch(launchGatewayProvider),
  ),
);

const String launchPurchaseTitle = '确认认购';
const String launchClaimTitle = '确认领取';
const String launchRefundTitle = '确认退款';

/// The sheet's title for one intent kind (decision 0103).
String launchIntentTitle(LaunchIntentKind kind) => switch (kind) {
  LaunchIntentKind.buy => launchPurchaseTitle,
  LaunchIntentKind.claim => launchClaimTitle,
  LaunchIntentKind.claimRefund => launchRefundTitle,
};

/// The noun the copy uses for one intent kind.
String launchIntentNoun(LaunchIntentKind kind) => switch (kind) {
  LaunchIntentKind.buy => '认购',
  LaunchIntentKind.claim => '领取',
  LaunchIntentKind.claimRefund => '退款',
};

/// Said on every claim and refund review: the contract moves the funds.
const String launchSettlementCustodyNote = '合约执行，LOOP 不经手资金';

/// The one sentence a claim or a refund review leads with (decision 0103),
/// read from the server's own position figure at the snapshot block.
String launchSettlementStatement(
  LaunchPurchaseIntent intent,
) => switch (intent.kind) {
  LaunchIntentKind.claim =>
    '领取 ${launchUnitsFigure(intent.claimableTokens ?? intent.expectedTokenAmount)} 代币到当前钱包',
  LaunchIntentKind.claimRefund =>
    '退回 ${launchUnitsFigure(intent.refundableUsd1 ?? '0')} USD1 到当前钱包',
  LaunchIntentKind.buy => launchPurchaseTitle,
};

/// The reviewed facts for any Launch intent: the page and the sheet call
/// this, so what the owner reads is what travels with the payload.
List<IntentField> launchIntentFields(
  LaunchPurchaseIntent intent, {
  required String ticker,
}) => intent.kind.isSettlement
    ? launchSettlementFields(intent, ticker: ticker)
    : launchPurchaseFields(intent, ticker: ticker);

/// A claim or a refund (decision 0087): what moves, to where, and that the
/// contract moves it. Nothing is paid, so no amount, cap or proof is shown.
List<IntentField> launchSettlementFields(
  LaunchPurchaseIntent intent, {
  required String ticker,
}) => <IntentField>[
  IntentField(label: '操作', value: launchSettlementStatement(intent)),
  const IntentField(label: '资金', value: launchSettlementCustodyNote),
  if (intent.kind == LaunchIntentKind.claim) ...<IntentField>[
    IntentField(label: '代币', value: ticker),
    IntentField(
      label: '本次可领取',
      value:
          '${launchUnitsFigure(intent.claimableTokens ?? intent.expectedTokenAmount)} $ticker',
    ),
  ] else
    IntentField(
      label: '本次退回',
      value: launchUsd1Label(intent.refundableUsd1 ?? '0'),
    ),
  IntentField(
    label: '钱包已累计认购',
    value: launchUsd1Label(intent.walletCumulativeUsd1),
  ),
  if (intent.simulation != null)
    IntentField(label: '模拟结果', value: intent.simulation!.status.label),
  IntentField(label: '签名有效至', value: launchTimestampLabel(intent.expiresAt)),
  IntentField(label: '状态摘要', value: launchShortHex(intent.stateTupleDigest)),
  IntentField(
    label: '快照区块',
    value: loopGroupedFigure(intent.snapshotBlockNumber),
  ),
  IntentField(label: '合约', value: launchShortHex(intent.contractAddress)),
  IntentField(label: '网络', value: loopChainName(intent.chainId)),
];

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
  IntentField(label: '轮次', value: 'Round ${intent.roundIndex ?? '—'}'),
  IntentField(
    label: '钱包已累计',
    value: launchUsd1Label(intent.walletCumulativeUsd1),
  ),
  // Decision 0089: the round cap is the server's own reading at the
  // snapshot block, shown beside what the wallet has already paid.
  IntentField(
    label: '本轮钱包上限',
    value: intent.walletRoundCapUsd1 == null
        ? '未提供'
        : launchUsd1Label(intent.walletRoundCapUsd1!),
  ),
  if (intent.walletProjectCapUsd1 != null)
    IntentField(
      label: '项目钱包上限',
      value: launchUsd1Label(intent.walletProjectCapUsd1!),
    ),
  if (intent.simulation != null)
    IntentField(label: '模拟结果', value: intent.simulation!.status.label),
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
  'LAUNCH_WALLET_ADDRESS_MISMATCH' => '服务端构造交易用的钱包与当前支付钱包不一致，已拒绝签名，没有提交任何交易。',
  'LAUNCH_SIMULATION_REVERTED' => '试算没有通过，这笔认购在链上会被拒绝。没有提交任何交易，请调整金额或稍后重新报价。',
  'LAUNCH_SIMULATION_UNAVAILABLE' => '暂时无法试算这笔认购，服务端不允许签名，没有提交任何交易。请稍后重新报价。',
  'INTENT_SUBMITTED' || 'INTENT_CONFIRMED' => '这笔认购已经提交过，不能再次签名。请在「我的参与记录」查看。',
  _ => '钱包没有完成签名，没有提交任何交易。',
};

/// [launchSignReasonText] for a claim or a refund (decision 0103). The codes
/// whose purchase sentence speaks of a quote or a subscription get their own
/// sentence; the rest are the same words with the kind's noun.
String launchSignReasonTextFor(LaunchIntentKind kind, String reasonCode) {
  if (!kind.isSettlement) return launchSignReasonText(reasonCode);
  final noun = launchIntentNoun(kind);
  return switch (reasonCode) {
    'INTENT_EXPIRED' => '这份$noun的签名窗口已过，没有提交任何交易。请重新发起。',
    'LAUNCH_SIMULATION_REVERTED' => '试算没有通过，这笔$noun在链上会被拒绝。没有提交任何交易，请刷新后再试。',
    'LAUNCH_SIMULATION_UNAVAILABLE' =>
      '暂时无法试算这笔$noun，服务端不允许签名，没有提交任何交易。请稍后重新发起。',
    'INTENT_SUBMITTED' ||
    'INTENT_CONFIRMED' => '这笔$noun已经提交过，不能再次签名。请在「我的参与记录」查看。',
    _ => launchSignReasonText(reasonCode).replaceAll('认购', noun),
  };
}

/// [launchReportReasonText] with the kind's noun (decision 0103).
String launchReportReasonTextFor(LaunchIntentKind kind, String reasonCode) =>
    kind.isSettlement
    ? launchReportReasonText(reasonCode)
          .replaceAll('认购', launchIntentNoun(kind))
    : launchReportReasonText(reasonCode);

/// zh-CN for a refused broadcast report (loop-api decision 0077). The wallet
/// has already broadcast, so none of these says that nothing happened.
String launchReportReasonText(String reasonCode) => switch (reasonCode) {
  'LAUNCH_INTENT_ALREADY_REPORTED' =>
    '这笔认购已经上报过另一笔交易，本次广播没有被记录。'
        '交易可能已经上链，请在「我的参与记录」核对，不要重复签名。',
  'LAUNCH_INTENT_NOT_SIGNABLE' =>
    '服务端已不再接受这笔认购的上报，它的状态已经变化。'
        '钱包已经广播，交易可能已经上链，请在「我的参与记录」核对，不要重复签名。',
  'LAUNCH_INTENT_EXPIRED' =>
    '这笔认购已过期，而链上暂时还看不到这笔交易，上报没有被接受。'
        '交易可能仍在传播，请稍后在「我的参与记录」核对，不要重复签名。',
  'LAUNCH_TX_PAYLOAD_MISMATCH' =>
    '链上这笔交易与签名时复核的认购内容不一致，服务端没有记录它。'
        '请在「我的参与记录」核对，不要重复签名，并联系支持。',
  _ =>
    '钱包已经广播，但这次上报没有被服务端接受或没有送达。'
        '交易可能已经上链，可以稍后重新上报；不要重复签名。',
};

/// Whether a refused report is worth sending again with the same hash. The
/// four named refusals are the server's final answer for this intent.
bool launchReportRetryable(String reasonCode) => !const <String>{
  'LAUNCH_INTENT_ALREADY_REPORTED',
  'LAUNCH_INTENT_NOT_SIGNABLE',
  'LAUNCH_INTENT_EXPIRED',
  'LAUNCH_TX_PAYLOAD_MISMATCH',
}.contains(reasonCode);

/// The one sentence after a broadcast, for the sheet and the page alike.
String launchBroadcastText(
  LaunchSignOutcome outcome, {
  LaunchIntentKind kind = LaunchIntentKind.buy,
}) {
  final noun = launchIntentNoun(kind);
  final hash = outcome.txHash;
  if (hash == null) {
    return '钱包的结果未知，这笔$noun已锁定。请在「我的参与记录」查看，不要重复签名。';
  }
  final short = launchShortHex(hash);
  final reported = outcome.reported;
  if (reported != null) {
    return '钱包已广播（$short），服务端已记录，当前状态：${reported.state.label}。'
        '广播不代表${kind.isSettlement ? '已到账' : '已成交'}，结果以链上索引为准，'
        '会出现在「我的参与记录」。不要重复$noun。';
  }
  return '钱包已广播（$short）。广播不代表${kind.isSettlement ? '已到账' : '已成交'}。'
      '${launchReportReasonTextFor(kind, outcome.reasonCode)}';
}

/// Opens the signing exit for one prepared Launch intent.
///
/// It returns `null` only when the sheet was closed before the wallet was
/// opened; a sheet torn down afterwards still reports a locked outcome.
Future<LaunchSignOutcome?> showLaunchSignSheet(
  BuildContext context, {
  required LaunchPurchasePrepared prepared,
  required LaunchPurchaseSigner signer,
  required String? fromAddress,
  required String ticker,
  DateTime Function()? clock,
}) async {
  final latch = MoneySignLatch();
  final outcome = await showLoopSheet<LaunchSignOutcome>(
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
  return LaunchSignOutcome(
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
  LaunchSignOutcome? _outcome;
  bool _submitted = false;

  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();

  LaunchPurchaseIntent get _intent => widget.prepared.intent;

  @override
  void initState() {
    super.initState();
    final refusal = _preflight();
    if (refusal != null) {
      _state = LoopSignSheetState.simulationFailed;
      _reason = launchSignReasonTextFor(_intent.kind, refusal);
    }
  }

  /// Refusals the sheet can state before the wallet is ever opened.
  String? _preflight() => LaunchPurchaseSigner.refusalBeforeWallet(
    _intent,
    fromAddress: widget.fromAddress,
    now: _now,
  );

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
          _reason = launchBroadcastText(outcome, kind: _intent.kind);
        case MoneySignStatus.refused:
        case MoneySignStatus.walletRejected:
          _state = LoopSignSheetState.simulationFailed;
          _reason = launchSignReasonTextFor(_intent.kind, outcome.reasonCode);
          _submitted = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fields = launchIntentFields(_intent, ticker: widget.ticker);
    return PopScope(
      canPop: _state != LoopSignSheetState.signing,
      child: LoopSignSheet(
        key: const ValueKey<String>('launch-sign-sheet'),
        state: _state,
        title: launchIntentTitle(_intent.kind),
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
