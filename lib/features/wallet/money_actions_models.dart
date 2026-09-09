import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

// ---------------------------------------------------------------------------
// wallet intents · POST /v2/wallet-intents/{send|approve|revoke|swap}
// ---------------------------------------------------------------------------

/// What one intent asks the wallet to do. The four kinds are separate resources
/// on the wire and are never merged in the UI: an approval and the business
/// transaction it unlocks show their own state.
enum LoopIntentKind {
  send('send'),
  approve('approve'),
  revoke('revoke'),
  swap('swap');

  const LoopIntentKind(this.wireName);

  final String wireName;

  static LoopIntentKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// The server-owned state machine. `unknown` is a locked state: the client only
/// polls it and must never resubmit.
enum LoopIntentState {
  prepared('prepared'),
  awaitingSignature('awaiting_signature'),
  submitted('submitted'),
  confirmed('confirmed'),
  reverted('reverted'),
  failed('failed'),
  unknown('unknown'),
  cancelled('cancelled'),
  expired('expired');

  const LoopIntentState(this.wireName);

  final String wireName;

  static LoopIntentState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }

  bool get isTerminal =>
      this == confirmed ||
      this == reverted ||
      this == failed ||
      this == cancelled ||
      this == expired;

  /// `unknown` is not terminal — reconciliation may still resolve it — but it
  /// is locked: no further submission is allowed from the device.
  bool get isLocked => this == unknown;
}

/// The pre-execution result. There is no provider simulator in this step: a
/// `passed` value means the exact payload was replayed with `eth_call` and
/// `estimateGas`, nothing more. No asset-change analysis, no score.
enum LoopSimulationStatus {
  passed('passed'),
  reverted('reverted'),
  unavailable('unavailable');

  const LoopSimulationStatus(this.wireName);

  final String wireName;

  static LoopSimulationStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

enum LoopSimulationSource {
  rpcCall('rpc_call'),
  providerQuote('provider_quote');

  const LoopSimulationSource(this.wireName);

  final String wireName;

  static LoopSimulationSource? tryParse(String value) {
    for (final source in values) {
      if (source.wireName == value) return source;
    }
    return null;
  }
}

/// Which of the two signing modes the intent uses. They are not
/// interchangeable: the device broadcasts a Send itself, while a Swap only
/// authorizes the server's provider call.
enum LoopSigningMode {
  deviceEthSendTransaction('device_eth_send_transaction'),
  privyAuthorizationSignature('privy_authorization_signature');

  const LoopSigningMode(this.wireName);

  final String wireName;

  static LoopSigningMode? tryParse(String value) {
    for (final mode in values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}

enum LoopExposureBasis {
  amount('amount'),
  balanceAtPrepare('balance_at_prepare'),
  none('none');

  const LoopExposureBasis(this.wireName);

  final String wireName;

  static LoopExposureBasis? tryParse(String value) {
    for (final basis in values) {
      if (basis.wireName == value) return basis;
    }
    return null;
  }
}

enum LoopDecodedFunction {
  transfer('transfer'),
  approve('approve');

  const LoopDecodedFunction(this.wireName);

  final String wireName;

  static LoopDecodedFunction? tryParse(String value) {
    for (final name in values) {
      if (name.wireName == value) return name;
    }
    return null;
  }
}

enum LoopReceiptStatus {
  success('success'),
  reverted('reverted');

  const LoopReceiptStatus(this.wireName);

  final String wireName;

  static LoopReceiptStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

enum LoopPriceImpactDecision {
  allowed('allowed'),
  confirm('confirm'),
  blocked('blocked');

  const LoopPriceImpactDecision(this.wireName);

  final String wireName;

  static LoopPriceImpactDecision? tryParse(String value) {
    for (final decision in values) {
      if (decision.wireName == value) return decision;
    }
    return null;
  }
}

/// The inline asset projection carried by an intent, a quote and an approval.
@immutable
final class LoopIntentAsset {
  const LoopIntentAsset({
    required this.assetId,
    required this.address,
    required this.symbol,
    required this.decimals,
  });

  final String assetId;
  final String? address;
  final String symbol;
  final int decimals;

  bool get isNative => address == null;
}

/// An amount in both of its exact forms. `display` may be the literal
/// `unlimited`, which is a meaning, not a number: it is never formatted.
@immutable
final class LoopIntentAmount {
  const LoopIntentAmount({
    required this.raw,
    required this.display,
    required this.value,
  });

  static const unlimitedDisplay = 'unlimited';

  /// The exact integer minor-unit string that is encoded in the call data.
  final String raw;

  /// The exact display-unit string, or `unlimited`.
  final String display;

  /// `null` exactly when [display] is `unlimited`.
  final Decimal? value;

  bool get isUnlimited => display == unlimitedDisplay;
}

@immutable
final class LoopIntentRecipient {
  const LoopIntentRecipient({
    required this.address,
    required this.checksumAddress,
    required this.isContract,
    required this.isFirstRecipient,
    required this.basis,
    required this.screening,
  });

  final String address;
  final String checksumAddress;
  final bool isContract;

  /// "Not in your own indexed history", stated with [basis]. It is never a
  /// claim about the address itself.
  final bool isFirstRecipient;
  final String basis;

  /// Malicious-address screening. It is `unavailable` in this step and does
  /// not block; it must be shown as an explicit gap.
  final LoopUnavailable screening;
}

@immutable
final class LoopIntentSpender {
  const LoopIntentSpender({
    required this.address,
    required this.checksumAddress,
    required this.isContract,
    required this.isUnlimited,
  });

  final String address;
  final String checksumAddress;
  final bool isContract;
  final bool isUnlimited;
}

/// The decoded ERC-20 call. `approval-guard` renders these fields verbatim.
@immutable
final class LoopDecodedCall {
  LoopDecodedCall({
    required this.functionName,
    required this.selector,
    required Map<String, String> args,
  }) : args = Map<String, String>.unmodifiable(args);

  final LoopDecodedFunction functionName;
  final String selector;
  final Map<String, String> args;
}

@immutable
final class LoopIntentFee {
  const LoopIntentFee({
    required this.gasLimit,
    required this.type,
    required this.maxFeePerGas,
    required this.maxPriorityFeePerGas,
    required this.gasPrice,
    required this.maximumFeeRaw,
    required this.maximumFee,
    required this.observedAt,
  });

  final String gasLimit;
  final String type;
  final String? maxFeePerGas;
  final String? maxPriorityFeePerGas;
  final String? gasPrice;
  final String maximumFeeRaw;

  /// The ceiling, not an estimate: `gasLimit × maxFeePerGas` in BNB.
  final Decimal maximumFee;
  final DateTime observedAt;
}

/// The balance snapshot the intent was prepared against. Every figure here
/// belongs to one block height.
@immutable
final class LoopIntentBalance {
  const LoopIntentBalance({
    required this.blockNumber,
    required this.blockHash,
    required this.observedAt,
    required this.rawBalance,
    required this.displayBalance,
    required this.rawNativeBalance,
    required this.gasReserveRaw,
  });

  final BigInt blockNumber;
  final String blockHash;
  final DateTime observedAt;
  final String rawBalance;
  final Decimal displayBalance;
  final String rawNativeBalance;
  final String gasReserveRaw;
}

@immutable
final class LoopSwapPriceImpact {
  const LoopSwapPriceImpact({
    required this.available,
    required this.value,
    required this.decision,
    required this.reasonCode,
    required this.marketValueUsd,
    required this.estimatedOutputValueUsd,
    required this.priceSource,
  });

  final bool available;

  /// A ratio, not a percentage: `0.0025` is 0.25 %.
  final Decimal? value;
  final LoopPriceImpactDecision decision;
  final String? reasonCode;
  final Decimal? marketValueUsd;
  final Decimal? estimatedOutputValueUsd;
  final String? priceSource;

  bool get requiresConfirmation => decision == LoopPriceImpactDecision.confirm;

  bool get isBlocked => decision == LoopPriceImpactDecision.blocked;
}

/// The server-owned swap policy. Its `status` is `pendingProductConfirmation`
/// and must be shown as such.
@immutable
final class LoopSwapPolicy {
  const LoopSwapPolicy({
    required this.configVersion,
    required this.status,
    required this.defaultSlippageBps,
    required this.maximumSlippageBps,
    required this.hardBlockPriceImpact,
    required this.confirmPriceImpact,
    required this.quoteTtlSeconds,
  });

  final String configVersion;
  final String status;
  final int defaultSlippageBps;
  final int maximumSlippageBps;
  final Decimal hardBlockPriceImpact;
  final Decimal confirmPriceImpact;
  final int quoteTtlSeconds;

  bool get isPendingProductConfirmation =>
      status == 'pendingProductConfirmation';
}

@immutable
final class LoopSwapQuote {
  const LoopSwapQuote({
    required this.quoteId,
    required this.provider,
    required this.amountType,
    required this.inputAmount,
    required this.estimatedOutputAmount,
    required this.minimumOutputAmount,
    required this.slippageBps,
    required this.gasEstimateRaw,
    required this.quotedAt,
    required this.expiresAt,
    required this.priceImpact,
    required this.platformFeeBps,
  });

  final String quoteId;
  final String provider;
  final String amountType;
  final LoopIntentAmount inputAmount;
  final LoopIntentAmount estimatedOutputAmount;
  final LoopIntentAmount minimumOutputAmount;
  final int slippageBps;
  final String gasEstimateRaw;
  final DateTime quotedAt;
  final DateTime expiresAt;
  final LoopSwapPriceImpact priceImpact;

  /// `null` means no platform fee was configured, never "zero was charged by
  /// someone else".
  final int? platformFeeBps;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now.toUtc());

  Duration remainingAt(DateTime now) {
    final left = expiresAt.difference(now.toUtc());
    return left.isNegative ? Duration.zero : left;
  }
}

/// The quote snapshot an intent froze, plus the policy that judged it.
@immutable
final class LoopIntentSwap {
  const LoopIntentSwap({
    required this.destinationAsset,
    required this.quote,
    required this.policy,
  });

  final LoopIntentAsset destinationAsset;
  final LoopSwapQuote quote;
  final LoopSwapPolicy policy;
}

/// Everything the owner is shown before signing. It is one half of the server's
/// canonical payload; [LoopWalletIntent.reviewSha256] binds it to the other.
@immutable
final class LoopIntentReview {
  const LoopIntentReview({
    required this.kind,
    required this.asset,
    required this.amount,
    required this.recipient,
    required this.spender,
    required this.decodedCall,
    required this.fee,
    required this.balance,
    required this.swap,
  });

  final LoopIntentKind kind;
  final LoopIntentAsset asset;
  final LoopIntentAmount amount;
  final LoopIntentRecipient? recipient;
  final LoopIntentSpender? spender;
  final LoopDecodedCall? decodedCall;
  final LoopIntentFee? fee;
  final LoopIntentBalance balance;
  final LoopIntentSwap? swap;
}

@immutable
final class LoopIntentSimulation {
  const LoopIntentSimulation({
    required this.status,
    required this.source,
    required this.observedAt,
    required this.reasonCode,
  });

  final LoopSimulationStatus status;
  final LoopSimulationSource source;
  final DateTime observedAt;
  final String? reasonCode;

  bool get passed => status == LoopSimulationStatus.passed;
}

/// The canary ceiling that judged this intent.
@immutable
final class LoopIntentPolicy {
  const LoopIntentPolicy({
    required this.configVersion,
    required this.canaryMaxUsd,
    required this.exposureBasis,
    required this.exposureRaw,
    required this.exposureBlockNumber,
    required this.valueUsd,
    required this.priceSource,
    required this.priceFetchedAt,
  });

  final String configVersion;
  final Decimal canaryMaxUsd;

  /// `amount` for a send/swap, `balance_at_prepare` for an approval (the real
  /// exposure is `min(allowance, balance)`), `none` for a revoke.
  final LoopExposureBasis exposureBasis;
  final String? exposureRaw;
  final BigInt? exposureBlockNumber;
  final Decimal? valueUsd;
  final String? priceSource;
  final DateTime? priceFetchedAt;
}

@immutable
final class LoopIntentSigning {
  const LoopIntentSigning({
    required this.mode,
    required this.allowed,
    required this.reasonCode,
  });

  final LoopSigningMode mode;

  /// The single server-owned permission to hand this intent to the wallet.
  /// The client never derives it from the state or the simulation.
  final bool allowed;
  final String? reasonCode;
}

/// The exact object handed to `eth_sendTransaction`. No field may be changed,
/// so the raw map is carried verbatim next to the typed projection.
@immutable
final class LoopUnsignedTransaction {
  const LoopUnsignedTransaction({
    required this.chainId,
    required this.from,
    required this.to,
    required this.data,
    required this.value,
    required this.gas,
    required this.nonce,
    required this.type,
    required this.maxFeePerGas,
    required this.maxPriorityFeePerGas,
    required this.gasPrice,
  });

  final int chainId;
  final String from;
  final String to;
  final String data;
  final String value;
  final String gas;
  final String nonce;
  final String type;
  final String? maxFeePerGas;
  final String? maxPriorityFeePerGas;
  final String? gasPrice;

  /// Rebuilt with exactly the contract's keys, in the contract's order.
  Map<String, Object?> toWire() => <String, Object?>{
    'chainId': chainId,
    'from': from,
    'to': to,
    'data': data,
    'value': value,
    'gas': gas,
    'nonce': nonce,
    'type': type,
    'maxFeePerGas': maxFeePerGas,
    'maxPriorityFeePerGas': maxPriorityFeePerGas,
    'gasPrice': gasPrice,
  };
}

/// The object the device signs with `generateAuthorizationSignature`. It is
/// carried verbatim; the client neither builds nor edits it.
@immutable
final class LoopAuthorizationPayload {
  LoopAuthorizationPayload({
    required this.version,
    required this.method,
    required this.url,
    required Map<String, Object?> body,
    required Map<String, String> headers,
  }) : body = Map<String, Object?>.unmodifiable(body),
       headers = Map<String, String>.unmodifiable(headers);

  final int version;
  final String method;
  final String url;
  final Map<String, Object?> body;
  final Map<String, String> headers;
}

@immutable
final class LoopIntentReceipt {
  const LoopIntentReceipt({
    required this.status,
    required this.blockNumber,
    required this.blockHash,
    required this.gasUsed,
    required this.effectiveGasPrice,
    required this.confirmations,
    required this.observedAt,
  });

  final LoopReceiptStatus status;
  final BigInt blockNumber;
  final String blockHash;
  final String gasUsed;
  final String effectiveGasPrice;

  /// `null` means the chain head could not be read at that moment — it is not
  /// zero confirmations.
  final int? confirmations;
  final DateTime observedAt;
}

@immutable
final class LoopIntentResult {
  const LoopIntentResult({
    required this.transactionHash,
    required this.providerActionId,
    required this.reasonCode,
    required this.receipt,
  });

  final String? transactionHash;
  final String? providerActionId;
  final String? reasonCode;
  final LoopIntentReceipt? receipt;
}

/// One wallet intent — the only object that may reach the signing exit.
@immutable
final class LoopWalletIntent {
  const LoopWalletIntent({
    required this.intentId,
    required this.kind,
    required this.state,
    required this.walletId,
    required this.chainId,
    required this.review,
    required this.reviewSha256,
    required this.factsObservedAt,
    required this.expiresAt,
    required this.simulation,
    required this.policy,
    required this.signing,
    required this.unsignedTransaction,
    required this.authorizationPayload,
    required this.result,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String intentId;
  final LoopIntentKind kind;
  final LoopIntentState state;
  final String walletId;
  final String chainId;
  final LoopIntentReview review;

  /// SHA-256 of the server's canonical payload. It binds the fields on screen
  /// to the payload that will be signed.
  final String reviewSha256;
  final DateTime factsObservedAt;
  final DateTime expiresAt;
  final LoopIntentSimulation simulation;
  final LoopIntentPolicy policy;
  final LoopIntentSigning signing;
  final LoopUnsignedTransaction? unsignedTransaction;
  final LoopAuthorizationPayload? authorizationPayload;
  final LoopIntentResult result;
  final String version;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now.toUtc());

  Duration remainingAt(DateTime now) {
    final left = expiresAt.difference(now.toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  /// The only gate the confirm button may read. Every one of these facts is
  /// server-owned; none is derived locally except the expiry clock.
  bool canSignAt(DateTime now) =>
      signing.allowed &&
      state == LoopIntentState.awaitingSignature &&
      !isExpiredAt(now) &&
      _payloadPresent;

  bool get _payloadPresent => switch (signing.mode) {
    LoopSigningMode.deviceEthSendTransaction => unsignedTransaction != null,
    LoopSigningMode.privyAuthorizationSignature => authorizationPayload != null,
  };

  /// Why the confirm button is disabled, in the server's own vocabulary.
  String? blockedReasonAt(DateTime now) {
    if (isExpiredAt(now) && !state.isTerminal) return 'INTENT_EXPIRED';
    if (!_payloadPresent) return 'SIGNING_PAYLOAD_UNAVAILABLE';
    if (signing.reasonCode != null) return signing.reasonCode;
    if (!signing.allowed || state != LoopIntentState.awaitingSignature) {
      return 'INTENT_${state.wireName.toUpperCase()}';
    }
    return null;
  }

  /// Structural cross-check between the fields the owner reads and the call
  /// data that will be broadcast.
  ///
  /// This is not a second source of truth — `reviewSha256` is — but it catches
  /// a review and a payload that do not describe the same call before the
  /// wallet is ever opened.
  /// The numeric chain of [chainId], e.g. `56` for `eip155:56`.
  int? get numericChainId =>
      int.tryParse(chainId.substring(chainId.lastIndexOf(':') + 1));

  bool get payloadMatchesReview {
    final expectedChainId = numericChainId;
    if (expectedChainId == null) return false;
    final transaction = unsignedTransaction;
    if (transaction == null) {
      // A provider-authorized swap carries no call data: the quote snapshot in
      // the review and the authorization body must agree instead.
      final payload = authorizationPayload;
      final swap = review.swap;
      if (payload == null || swap == null) return false;
      // The idempotency key the provider will see is this intent. A payload
      // keyed to another intent would let one confirmation submit a different
      // operation.
      if (payload.headers['privy-idempotency-key'] != intentId) return false;
      final body = payload.body;
      if (body['base_amount'] != swap.quote.inputAmount.raw) return false;
      if (body['slippage_bps'] != swap.quote.slippageBps) return false;
      final source = body['source'];
      final destination = body['destination'];
      if (source is! Map || destination is! Map) return false;
      return _swapEndpointMatches(source, review.asset, chainId) &&
          _swapEndpointMatches(destination, swap.destinationAsset, chainId);
    }

    // The device signs for one chain. A payload built for another chain would
    // spend a different balance than the one reviewed.
    if (transaction.chainId != expectedChainId) return false;

    final decoded = review.decodedCall;
    if (decoded == null) {
      // A native transfer carries no call data at all.
      return review.asset.isNative &&
          transaction.data == '0x' &&
          _hexEquals(transaction.value, review.amount.raw) &&
          transaction.to == review.recipient?.address;
    }
    if (!transaction.data.startsWith(decoded.selector)) return false;
    if (transaction.to != review.asset.address) return false;
    if (transaction.value != '0x0') return false;

    // `transfer` and `approve` take exactly two words. A longer body is a
    // different call than the one that was decoded and shown.
    final words = _dataWords(transaction.data);
    if (words.length != 2) return false;
    final target = switch (decoded.functionName) {
      LoopDecodedFunction.transfer => review.recipient?.address,
      LoopDecodedFunction.approve => review.spender?.address,
    };
    if (target == null) return false;
    if (words[0] != _padAddress(target)) return false;
    return words[1] == _padAmount(review.amount.raw);
  }

  static bool _swapEndpointMatches(
    Map<Object?, Object?> wire,
    LoopIntentAsset asset,
    String chainId,
  ) {
    if (wire['caip2'] != chainId) return false;
    final address = wire['asset_address'];
    if (address is! String) return false;
    return asset.isNative ? address == 'native' : address == asset.address;
  }

  static List<String> _dataWords(String data) {
    final body = data.substring(10);
    if (body.length % 64 != 0) return const <String>[];
    return <String>[
      for (var index = 0; index + 64 <= body.length; index += 64)
        body.substring(index, index + 64),
    ];
  }

  static String _padAddress(String address) =>
      address.substring(2).padLeft(64, '0');

  static String _padAmount(String raw) {
    final value = BigInt.tryParse(raw);
    if (value == null) return '';
    return value.toRadixString(16).padLeft(64, '0');
  }

  static bool _hexEquals(String hex, String decimalRaw) {
    final left = BigInt.tryParse(hex.substring(2), radix: 16);
    final right = BigInt.tryParse(decimalRaw);
    return left != null && right != null && left == right;
  }
}

/// `GET /v2/wallet-intents` — newest first.
@immutable
final class LoopWalletIntentPage {
  LoopWalletIntentPage({
    required List<LoopWalletIntent> items,
    required this.nextCursor,
  }) : items = List<LoopWalletIntent>.unmodifiable(items);

  final List<LoopWalletIntent> items;
  final String? nextCursor;
}

// ---------------------------------------------------------------------------
// send · POST /v2/wallet-intents/send/preflight
// ---------------------------------------------------------------------------

@immutable
final class LoopSendPreflight {
  LoopSendPreflight({
    required this.walletId,
    required this.chainId,
    required this.recipient,
    required this.basis,
    required List<String> warnings,
  }) : warnings = List<String>.unmodifiable(warnings);

  static const firstTimeWarning = 'send.recipient.firstTime';
  static const contractWarning = 'send.recipient.isContract';
  static const screeningWarning = 'send.recipient.screeningUnavailable';

  final String walletId;
  final String chainId;
  final LoopIntentRecipient recipient;
  final String basis;
  final List<String> warnings;
}

// ---------------------------------------------------------------------------
// swap · POST /v2/swap/quote
// ---------------------------------------------------------------------------

/// The canary ceiling as reported next to a quote.
@immutable
final class LoopSwapCanary {
  const LoopSwapCanary({
    required this.configVersion,
    required this.canaryMaxUsd,
    required this.inputValueUsd,
  });

  final String configVersion;
  final Decimal canaryMaxUsd;
  final Decimal inputValueUsd;
}

@immutable
final class LoopSwapQuoteView {
  const LoopSwapQuoteView({
    required this.walletId,
    required this.sourceAsset,
    required this.destinationAsset,
    required this.quote,
    required this.policy,
    required this.canary,
  });

  final String walletId;
  final LoopIntentAsset sourceAsset;
  final LoopIntentAsset destinationAsset;
  final LoopSwapQuote quote;
  final LoopSwapPolicy policy;
  final LoopSwapCanary canary;
}

// ---------------------------------------------------------------------------
// approvals · GET /v2/approvals
// ---------------------------------------------------------------------------

/// One row's current on-chain allowance. "Could not read" and "is zero" are
/// different facts, so the read is a union and a zero row is not listed at all.
sealed class LoopAllowance {
  const LoopAllowance();
}

final class LoopAllowanceAvailable extends LoopAllowance {
  const LoopAllowanceAvailable({
    required this.rawValue,
    required this.displayValue,
    required this.value,
    required this.isUnlimited,
    required this.blockNumber,
    required this.blockHash,
    required this.observedAt,
  });

  final String rawValue;

  /// The exact display string, or `unlimited`.
  final String displayValue;

  /// `null` exactly when the allowance is unlimited.
  final Decimal? value;
  final bool isUnlimited;
  final BigInt blockNumber;
  final String blockHash;
  final DateTime observedAt;
}

final class LoopAllowanceUnavailable extends LoopAllowance {
  const LoopAllowanceUnavailable(this.reasonCode);

  final String reasonCode;
}

/// The `Approval` event the indexer observed. It is history, not the current
/// allowance: the current value always comes from a fresh `allowance()` read.
@immutable
final class LoopApprovalEvent {
  const LoopApprovalEvent({
    required this.transactionHash,
    required this.blockNumber,
    required this.rawValue,
    required this.observedAt,
  });

  final String transactionHash;
  final BigInt blockNumber;
  final String rawValue;
  final DateTime observedAt;
}

@immutable
final class LoopApprovalSpender {
  const LoopApprovalSpender({
    required this.address,
    required this.checksumAddress,
  });

  final String address;
  final String checksumAddress;
}

@immutable
final class LoopApprovalRow {
  const LoopApprovalRow({
    required this.assetId,
    required this.symbol,
    required this.decimals,
    required this.spender,
    required this.allowance,
    required this.lastApproval,
    required this.riskFacts,
  });

  final String assetId;
  final String symbol;
  final int decimals;
  final LoopApprovalSpender spender;
  final LoopAllowance allowance;
  final LoopApprovalEvent? lastApproval;

  /// Provider risk facts. `unavailable` in this step: no score is invented.
  final LoopUnavailable riskFacts;

  bool get isUnlimited =>
      allowance is LoopAllowanceAvailable &&
      (allowance as LoopAllowanceAvailable).isUnlimited;
}

@immutable
final class LoopApprovalSummary {
  const LoopApprovalSummary({
    required this.activeCount,
    required this.unlimitedCount,
  });

  final int activeCount;
  final int unlimitedCount;
}

@immutable
final class LoopApprovalFreshness {
  const LoopApprovalFreshness({
    required this.indexerBlockNumber,
    required this.approvalCoverageFromBlockNumber,
    required this.headBlockNumber,
    required this.observedAt,
  });

  final BigInt indexerBlockNumber;

  /// The first block whose `Approval` events were decoded. The inventory is
  /// only complete from here up: blocks below it were indexed for transfers
  /// only, so an approval granted earlier would be invisible. The page states
  /// it rather than implying the list covers all history.
  final BigInt approvalCoverageFromBlockNumber;
  final BigInt headBlockNumber;
  final DateTime observedAt;
}

@immutable
final class LoopApprovalInventory {
  LoopApprovalInventory({
    required this.walletId,
    required List<LoopApprovalRow> items,
    required this.summary,
    required this.freshness,
  }) : items = List<LoopApprovalRow>.unmodifiable(items);

  final String walletId;
  final List<LoopApprovalRow> items;
  final LoopApprovalSummary summary;
  final LoopApprovalFreshness freshness;
}

// ---------------------------------------------------------------------------
// request objects
// ---------------------------------------------------------------------------

/// The allowance an approval intent asks for. `unlimited` requires the guard's
/// second confirmation, which travels as its own top-level acknowledgement.
sealed class LoopAllowanceRequest {
  const LoopAllowanceRequest();
}

final class LoopExactAllowanceRequest extends LoopAllowanceRequest {
  const LoopExactAllowanceRequest(this.amount);

  /// The exact decimal string the owner typed; never a `double`.
  final String amount;
}

final class LoopUnlimitedAllowanceRequest extends LoopAllowanceRequest {
  const LoopUnlimitedAllowanceRequest();
}
