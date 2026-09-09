import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

/// How one trip through the signing exit ended.
enum MoneySignStatus {
  /// The wallet accepted and the server recorded the submission. The intent
  /// carried back is the server's own state, never a local guess.
  submitted,

  /// Nothing was handed to the wallet: the server did not allow it, the facts
  /// expired, or the payload did not describe the reviewed call.
  refused,

  /// The wallet or the device refused. Nothing was submitted.
  walletRejected,

  /// The submission happened but its outcome is unresolved. The intent is
  /// locked: poll it, never resubmit.
  locked,

  /// The wallet produced a result — a broadcast hash or a signature — and the
  /// server refused or never received the report.
  ///
  /// This is the most dangerous state in the flow: something may already be on
  /// chain while the server has no record of it. It is locked, it must never
  /// read as "nothing was submitted", and it must never re-open the
  /// confirmation. The hash travels with it so the owner can report it later.
  reportRefused,
}

/// The outcome of one signing attempt.
final class MoneySignOutcome {
  const MoneySignOutcome({
    required this.status,
    required this.reasonCode,
    this.intent,
    this.txHash,
  });

  final MoneySignStatus status;

  /// A stable, non-provider reason string or the server's own `reasonCode`.
  final String reasonCode;

  /// The server's state after the report or execute call, when one landed.
  final LoopWalletIntent? intent;

  /// What the wallet produced when the server has not acknowledged it.
  /// Present only for [MoneySignStatus.reportRefused].
  final String? txHash;

  bool get isSubmitted => status == MoneySignStatus.submitted;

  /// True when the operation may already exist and the client must stop
  /// acting: poll the result, never sign again.
  bool get isLocked =>
      status == MoneySignStatus.locked ||
      status == MoneySignStatus.reportRefused;

  /// True when the result page is the only honest next screen.
  bool get opensResult => intent != null || isLocked;
}

/// The one path from a server intent to a wallet signature.
///
/// It never reports success on its own: the value the wallet returns is handed
/// straight back to the server, and the state this returns is the server's.
final class MoneyActionSigner {
  const MoneyActionSigner({required this.intents, required this.wallet});

  final WalletIntentsGateway intents;
  final WalletSigningGateway wallet;

  /// Builds the wallet-bound intent from one server intent.
  ///
  /// The facts the sheet renders and the payload the wallet receives are read
  /// from the same object in the same call, and both are stamped with the
  /// server's `reviewSha256`. Returns `null` when the server did not send a
  /// payload, so a half-formed intent can never reach a wallet.
  static SigningIntent? toSigningIntent(LoopWalletIntent intent) {
    final SigningPayload payload;
    switch (intent.signing.mode) {
      case LoopSigningMode.deviceEthSendTransaction:
        final transaction = intent.unsignedTransaction;
        if (transaction == null) return null;
        payload = DeviceTransactionPayload(
          fromAddress: transaction.from,
          transaction: transaction.toWire(),
        );
      case LoopSigningMode.privyAuthorizationSignature:
        final authorization = intent.authorizationPayload;
        if (authorization == null) return null;
        payload = AuthorizationSignaturePayload(
          version: authorization.version,
          method: authorization.method,
          url: authorization.url,
          headers: authorization.headers,
          body: authorization.body,
        );
    }
    return SigningIntent.backendCanonical(
      revision: intent.intentId,
      payloadDigest: intent.reviewSha256,
      title: moneyActionTitle(intent.kind),
      kind: switch (intent.kind) {
        LoopIntentKind.send => IntentKind.transfer,
        LoopIntentKind.approve || LoopIntentKind.revoke => IntentKind.approval,
        LoopIntentKind.swap => IntentKind.swap,
      },
      payload: payload,
      observedAt: intent.factsObservedAt,
      expiresAt: intent.expiresAt,
      fields: moneyActionFields(intent),
    );
  }

  Future<MoneySignOutcome> sign(
    LoopWalletIntent intent, {
    required DateTime now,
  }) async {
    // 1. The server's own permission. The client never derives it.
    if (!intent.canSignAt(now)) {
      return MoneySignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: intent.blockedReasonAt(now) ?? 'INTENT_NOT_SIGNABLE',
      );
    }
    // 2. The displayed call and the payload must describe the same operation.
    if (!intent.payloadMatchesReview) {
      return const MoneySignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'REVIEW_PAYLOAD_MISMATCH',
      );
    }
    final signingIntent = toSigningIntent(intent);
    if (signingIntent == null) {
      return const MoneySignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'SIGNING_PAYLOAD_UNAVAILABLE',
      );
    }

    final handoff = await wallet.handoff(signingIntent, now: now);
    if (!handoff.accepted || handoff.value == null) {
      // `wallet_outcome_unknown` is the one refusal that may still have
      // broadcast: it locks rather than offering a retry.
      return MoneySignOutcome(
        status: handoff.code == 'wallet_outcome_unknown'
            ? MoneySignStatus.locked
            : MoneySignStatus.walletRejected,
        reasonCode: handoff.code,
      );
    }

    // Past this line the wallet has already produced a result. Whatever
    // happens next, the operation may exist on chain: nothing below may report
    // that nothing was submitted, and nothing below may re-open the
    // confirmation.
    final produced = handoff.value!;
    try {
      final reported = switch (intent.signing.mode) {
        LoopSigningMode.deviceEthSendTransaction =>
          await intents.reportBroadcast(
            intentId: intent.intentId,
            txHash: produced,
          ),
        LoopSigningMode.privyAuthorizationSignature => await intents.execute(
          intentId: intent.intentId,
          authorizationSignature: produced,
        ),
      };
      return MoneySignOutcome(
        status: reported.state.isLocked
            ? MoneySignStatus.locked
            : MoneySignStatus.submitted,
        reasonCode: reported.result.reasonCode ?? reported.state.wireName,
        intent: reported,
      );
    } on LoopChainException catch (failure) {
      // The server refused or never received the report. A rejected report is
      // not a rejected transaction: the hash may already be on chain.
      return MoneySignOutcome(
        status: MoneySignStatus.reportRefused,
        reasonCode: failure.reasonCode ?? failure.kind.name,
        txHash: produced,
      );
    } catch (_) {
      return MoneySignOutcome(
        status: MoneySignStatus.reportRefused,
        reasonCode: 'REPORT_OUTCOME_UNKNOWN',
        txHash: produced,
      );
    }
  }
}

/// Sheet title for one intent kind.
String moneyActionTitle(LoopIntentKind kind) => switch (kind) {
  LoopIntentKind.send => '确认发送',
  LoopIntentKind.approve => '确认授权',
  LoopIntentKind.revoke => '确认回收授权',
  LoopIntentKind.swap => '确认兑换',
};

/// The exact facts shown before signing, read from the server's review.
///
/// This is the only place the sheet's lines are built, so what the owner reads
/// and what travels with the payload cannot drift apart.
List<IntentField> moneyActionFields(LoopWalletIntent intent) {
  final review = intent.review;
  final fee = review.fee;
  final fields = <IntentField>[
    IntentField(label: '操作', value: moneyActionTitle(intent.kind)),
  ];
  switch (intent.kind) {
    case LoopIntentKind.send:
      fields.addAll(<IntentField>[
        IntentField(label: '资产', value: review.asset.symbol),
        IntentField(
          label: '数量',
          value: '${review.amount.display} ${review.asset.symbol}',
        ),
        IntentField(
          label: '收款方',
          value: review.recipient?.checksumAddress ?? '不可用',
        ),
      ]);
    case LoopIntentKind.approve:
    case LoopIntentKind.revoke:
      fields.addAll(<IntentField>[
        IntentField(label: '代币', value: review.asset.symbol),
        IntentField(
          label: 'Spender',
          value: review.spender?.checksumAddress ?? '不可用',
        ),
        IntentField(
          label: '额度',
          value: review.amount.isUnlimited
              ? '无限（MAX_UINT256）'
              : '${review.amount.display} ${review.asset.symbol}',
        ),
      ]);
    case LoopIntentKind.swap:
      final swap = review.swap;
      fields.addAll(<IntentField>[
        IntentField(
          label: '支付',
          value: '${review.amount.display} ${review.asset.symbol}',
        ),
        IntentField(
          label: '预计获得',
          value: swap == null
              ? '不可用'
              : '${swap.quote.estimatedOutputAmount.display} '
                    '${swap.destinationAsset.symbol}',
        ),
        IntentField(
          label: '最少获得',
          value: swap == null
              ? '不可用'
              : '${swap.quote.minimumOutputAmount.display} '
                    '${swap.destinationAsset.symbol}',
        ),
        IntentField(
          label: '滑点上限',
          value: swap == null ? '不可用' : '${swap.quote.slippageBps} bps',
        ),
      ]);
  }
  fields.add(IntentField(label: '网络', value: 'BNB Smart Chain'));
  fields.add(
    IntentField(
      label: '最高网络费',
      value: fee == null
          ? '不可用'
          : '${loopFormatDecimal(fee.maximumFee, maxFractionDigits: 10)} BNB',
    ),
  );
  fields.add(
    IntentField(label: '模拟结果', value: moneySimulationLabel(intent.simulation)),
  );
  return fields;
}

/// zh-CN label for the pre-execution result. It never says "safe".
String moneySimulationLabel(LoopIntentSimulation simulation) =>
    switch (simulation.status) {
      LoopSimulationStatus.passed => '预执行通过（eth_call）',
      LoopSimulationStatus.reverted => '预执行被拒绝',
      LoopSimulationStatus.unavailable => '预执行不可用',
    };
