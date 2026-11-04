import 'package:decimal/decimal.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/chain/loop_usd1_asset.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_gateway.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

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
        // Decision 0089: the one approval the server builds off the primary
        // chain is USD1 towards the Launch contract, on the Launch slot. It
        // carries its own kind so the exit can admit that slot for it and for
        // nothing else.
        LoopIntentKind.approve || LoopIntentKind.revoke =>
          intent.chainId == loopPrimaryChainId
              ? IntentKind.approval
              : IntentKind.launchApproval,
        LoopIntentKind.swap => IntentKind.swap,
        // S339 · decision 0267: a project NFT, on the Launch slot.
        LoopIntentKind.sendNft => IntentKind.nftTransfer,
      },
      // The chain is the server's own canonical value. Money actions are
      // locked to the primary chain, and the signing exit refuses anything
      // else rather than trusting a payload that arrived on another chain.
      chainId: intent.chainId,
      payload: payload,
      observedAt: intent.factsObservedAt,
      expiresAt: intent.expiresAt,
      fields: moneyActionFields(intent),
      stepUpUsd1: moneyIntentStepUpUsd1(intent),
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
    // 3. The chain the owner reviewed must be one this kind of action may be
    // signed on. Send and swap are the primary chain only (decision 0038);
    // an approve or revoke may leave it only as the Launch USD1 approval
    // (decision 0089).
    if (!signingIntent.chainIsPermitted) {
      return const MoneySignOutcome(
        status: MoneySignStatus.refused,
        reasonCode: 'INTENT_CHAIN_NOT_PERMITTED',
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
          // The digest the sheet rendered: a review that changed on the
          // server since is refused there before anything is sent.
          reviewSha256: intent.reviewSha256,
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

/// What one wallet intent is worth in USD1, for the large-amount step-up
/// (decision 0152), or `null` when it cannot be said.
///
/// USD1 is recognised by its canonical CAIP `assetId` alone
/// ([loopIsUsd1AssetId]); a token that only calls itself `USD1` is valued
/// like any other token (decision 0158).
///
/// - A USD1 send is its amount; a swap that pays USD1 is that amount.
/// - A swap that receives USD1 is the larger of what it pays
///   (`policy.valueUsd`) and the estimated USD1 it receives: a costly asset
///   swapped for a little USD1 is as large as what leaves the wallet
///   (decision 0158).
/// - Any other send, swap or approval is the server's own valuation of the
///   intent at prepare, `policy.valueUsd` — the market price times the
///   amount (for an approval, times `min(allowance, balance)`). USD is read
///   as USD1 one for one.
/// - A revoke moves nothing. An intent the server could not price is `null`
///   and is not asked for: the gap is recorded in decision 0152.
Decimal? moneyIntentStepUpUsd1(LoopWalletIntent intent) {
  final review = intent.review;
  final valued = intent.policy.exposureBasis == LoopExposureBasis.none
      ? null
      : intent.policy.valueUsd;
  switch (intent.kind) {
    case LoopIntentKind.send:
      if (loopIsUsd1AssetId(review.asset.assetId)) return review.amount.value;
      return valued;
    case LoopIntentKind.swap:
      if (loopIsUsd1AssetId(review.asset.assetId)) return review.amount.value;
      final swap = review.swap;
      if (swap != null && loopIsUsd1AssetId(swap.destinationAsset.assetId)) {
        return _larger(valued, swap.quote.estimatedOutputAmount.value);
      }
      return valued;
    case LoopIntentKind.approve:
      return valued;
    case LoopIntentKind.revoke:
      return null;
    // An NFT has no USD1 amount; the server's own valuation, when it made
    // one, is the only figure.
    case LoopIntentKind.sendNft:
      return valued;
  }
}

/// The larger of two values that may each be unknown; `null` only when both
/// are.
Decimal? _larger(Decimal? a, Decimal? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a >= b ? a : b;
}

/// Sheet title for one intent kind.
String moneyActionTitle(LoopIntentKind kind) => switch (kind) {
  LoopIntentKind.send => LoopL10n.current.wallet_moneyActionsSigningSend,
  LoopIntentKind.approve => LoopL10n.current.wallet_moneyActionsSigningApprove,
  LoopIntentKind.revoke => LoopL10n.current.wallet_moneyActionsSigningRevoke,
  LoopIntentKind.swap => LoopL10n.current.wallet_moneyActionsSigningSwap,
  LoopIntentKind.sendNft => LoopL10n.current.wallet_moneyActionsSigningSendNft,
};

/// The action's own name (「发送」 / Send), for the headlines that say what
/// happened to it — [moneyActionTitle] is the button's 「确认…」 wording.
String moneyActionName(LoopIntentKind kind) => switch (kind) {
  LoopIntentKind.send => LoopL10n.current.wallet_moneyActionNameSend,
  LoopIntentKind.approve => LoopL10n.current.wallet_moneyActionNameApprove,
  LoopIntentKind.revoke => LoopL10n.current.wallet_moneyActionNameRevoke,
  LoopIntentKind.swap => LoopL10n.current.wallet_moneyActionNameSwap,
  LoopIntentKind.sendNft => LoopL10n.current.wallet_moneyActionNameSendNft,
};

/// 「T #id」 for the NFT a `send_nft` intent moves; the project's name when
/// the server named it, else [fallbackName], else 「NFT」.
String moneyNftLabel(LoopWalletIntent intent, {String? fallbackName}) {
  final nft = intent.review.nft;
  if (nft == null) return LoopL10n.current.common_unavailable;
  final name = nft.projectName ?? fallbackName ?? 'NFT';
  return '$name #${nft.tokenId}';
}

/// A stable id for one of [moneyActionFields]' lines (decision 0281: a key
/// never carries copy). [IntentField] holds only the label, so the id is
/// read back from the label the same build just wrote; an unknown label is
/// returned as is.
String moneyFieldId(String label) {
  final l10n = LoopL10n.current;
  final ids = <String, String>{
    l10n.common_actions: 'action',
    l10n.common_assets: 'asset',
    l10n.common_amount: 'amount',
    l10n.wallet_moneyActionsSigningLabel: 'recipient',
    l10n.common_token: 'token',
    'Spender': 'spender',
    l10n.wallet_moneyActionsSigningLabel2: 'allowance',
    'NFT': 'nft',
    l10n.common_contract: 'contract',
    l10n.common_pay: 'pay',
    l10n.common_estimatedReceive: 'estimated-receive',
    l10n.common_minimumReceive: 'minimum-receive',
    l10n.common_slippageLimit: 'slippage',
    l10n.common_network: 'network',
    l10n.wallet_moneyActionsSigningLabel3: 'max-fee',
    l10n.common_simulationResult: 'simulation',
  };
  return ids[label] ?? label;
}

/// The exact facts shown before signing, read from the server's review.
///
/// This is the only place the sheet's lines are built, so what the owner reads
/// and what travels with the payload cannot drift apart.
List<IntentField> moneyActionFields(LoopWalletIntent intent) {
  final review = intent.review;
  final fee = review.fee;
  final fields = <IntentField>[
    IntentField(
      label: LoopL10n.current.common_actions,
      value: moneyActionTitle(intent.kind),
    ),
  ];
  switch (intent.kind) {
    case LoopIntentKind.send:
      fields.addAll(<IntentField>[
        IntentField(
          label: LoopL10n.current.common_assets,
          value: review.asset.symbol,
        ),
        IntentField(
          label: LoopL10n.current.common_amount,
          value: '${review.amount.display} ${review.asset.symbol}',
        ),
        IntentField(
          label: LoopL10n.current.wallet_moneyActionsSigningLabel,
          value:
              review.recipient?.checksumAddress ??
              LoopL10n.current.common_unavailable,
        ),
      ]);
    case LoopIntentKind.approve:
    case LoopIntentKind.revoke:
      fields.addAll(<IntentField>[
        IntentField(
          label: LoopL10n.current.common_token,
          value: review.asset.symbol,
        ),
        IntentField(
          label: 'Spender',
          value:
              review.spender?.checksumAddress ??
              LoopL10n.current.common_unavailable,
        ),
        IntentField(
          label: LoopL10n.current.wallet_moneyActionsSigningLabel2,
          value: review.amount.isUnlimited
              ? LoopL10n.current.wallet_moneyActionsSigningValue
              : '${review.amount.display} ${review.asset.symbol}',
        ),
      ]);
    case LoopIntentKind.sendNft:
      fields.addAll(<IntentField>[
        IntentField(label: 'NFT', value: moneyNftLabel(intent)),
        IntentField(
          label: LoopL10n.current.common_contract,
          value:
              review.nft?.contractAddress ??
              LoopL10n.current.common_unavailable,
        ),
        IntentField(
          label: LoopL10n.current.wallet_moneyActionsSigningLabel,
          value:
              review.recipient?.checksumAddress ??
              LoopL10n.current.common_unavailable,
        ),
      ]);
    case LoopIntentKind.swap:
      final swap = review.swap;
      fields.addAll(<IntentField>[
        IntentField(
          label: LoopL10n.current.common_pay,
          value: '${review.amount.display} ${review.asset.symbol}',
        ),
        IntentField(
          label: LoopL10n.current.common_estimatedReceive,
          value: swap == null
              ? LoopL10n.current.common_unavailable
              : '${swap.quote.estimatedOutputAmount.display} '
                    '${swap.destinationAsset.symbol}',
        ),
        IntentField(
          label: LoopL10n.current.common_minimumReceive,
          value: swap == null
              ? LoopL10n.current.common_unavailable
              : '${swap.quote.minimumOutputAmount.display} '
                    '${swap.destinationAsset.symbol}',
        ),
        IntentField(
          label: LoopL10n.current.common_slippageLimit,
          value: swap == null
              ? LoopL10n.current.common_unavailable
              : moneySlippageLabel(swap.quote.slippageBps),
        ),
      ]);
  }
  // The chain is the intent's own value (decision 0038). Money actions are
  // locked to the primary chain, so this line reads "BNB Smart Chain" in
  // every delivered build — but it is read, never asserted.
  fields.add(
    IntentField(
      label: LoopL10n.current.common_network,
      value: loopChainName(intent.chainId),
    ),
  );
  fields.add(
    IntentField(
      label: LoopL10n.current.wallet_moneyActionsSigningLabel3,
      value: fee == null
          ? LoopL10n.current.common_unavailable
          : '${loopFormatDecimal(fee.maximumFee, maxFractionDigits: 10)} BNB',
    ),
  );
  fields.add(
    IntentField(
      label: LoopL10n.current.common_simulationResult,
      value: moneySimulationLabel(intent.simulation),
    ),
  );
  return fields;
}

/// zh-CN label for the pre-execution result. It never says "safe".
String moneySimulationLabel(LoopIntentSimulation simulation) =>
    switch (simulation.status) {
      LoopSimulationStatus.passed => LoopL10n.current.common_simulationPassed,
      LoopSimulationStatus.reverted =>
        LoopL10n.current.common_simulationRejected,
      LoopSimulationStatus.unavailable =>
        LoopL10n.current.common_simulationUnavailable,
    };
