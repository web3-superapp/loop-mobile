import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';

// ---------------------------------------------------------------------------
// S342 · decision 0270 · 内置 DApp 浏览器 (docs/55)
// ---------------------------------------------------------------------------

/// The EIP-1193 / EIP-1474 error codes the injected provider answers with.
abstract final class DappRpcErrorCode {
  /// The owner declined (connection, transaction or signature).
  static const userRejected = 4001;

  /// Not connected, a different account, or a network where signing is
  /// closed (BSC Mainnet, docs/00 rule 8).
  static const unauthorized = 4100;

  /// A method LOOP does not serve (`eth_sign`, `eth_signTransaction`, …).
  static const unsupportedMethod = 4200;

  /// `wallet_switchEthereumChain` to a chain other than 56 / 97.
  static const unrecognizedChain = 4902;

  static const invalidParams = -32602;
  static const internal = -32603;

  /// The read channel's per-account limit (EIP-1474 `limit exceeded`).
  static const limitExceeded = -32005;
}

/// One EIP-1193 error as it travels back to the page.
@immutable
final class DappRpcError implements Exception {
  const DappRpcError(this.code, this.message);

  final int code;
  final String message;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
  };

  @override
  String toString() => 'DappRpcError($code, $message)';
}

/// The two chains the browser can show (decision 0270): BSC Mainnet (read
/// only) and the Launch chain (read and sign).
abstract final class DappChains {
  static const List<String> supported = <String>[
    loopLaunchTestnetChainId,
    loopPrimaryChainId,
  ];

  /// `0x61` for `eip155:97`.
  static String hexOf(String chainId) =>
      '0x${loopChainReference(chainId).toRadixString(16)}';

  /// The CAIP-2 id of a `0x…` chain id a page asked for, or `null` when it
  /// is not one of the two.
  static String? fromHex(Object? value) {
    if (value is! String) return null;
    final text = value.toLowerCase();
    if (!text.startsWith('0x')) return null;
    final reference = int.tryParse(text.substring(2), radix: 16);
    for (final chainId in supported) {
      if (loopChainReference(chainId) == reference) return chainId;
    }
    return null;
  }

  /// The network name the browser shows. BSC Mainnet is named apart from
  /// the Launch slot, because the owner chooses between them; the testnet
  /// name itself stays a test hint (decision 0204).
  static String label(String chainId) => chainId == loopPrimaryChainId
      ? 'BSC 主网'
      : loopChainName(loopLaunchTestnetChainId);

  /// Signing is closed on BSC Mainnet (docs/00 rule 8).
  static bool canSign(String chainId) => chainId != loopPrimaryChainId;
}

/// The risk facts the server attaches to a DApp intent (docs/55 §二). The
/// strip on the confirmation is drawn only when at least one is present.
enum DappRiskFlag {
  unlimitedApproval('UNLIMITED_APPROVAL', '无限授权'),
  approvalForAll('APPROVAL_FOR_ALL', '授权全部 NFT'),
  permitSignature('PERMIT_SIGNATURE', '签名授权（Permit）'),
  unverifiedContract('UNVERIFIED_CONTRACT', '未验证合约'),
  simulationFailed('SIMULATION_FAILED', '预执行失败');

  const DappRiskFlag(this.wireName, this.label);

  final String wireName;
  final String label;

  static DappRiskFlag? tryParse(Object? value) {
    for (final flag in values) {
      if (flag.wireName == value) return flag;
    }
    return null;
  }
}

enum DappIntentKind {
  transaction('dapp_tx'),
  message('dapp_sign');

  const DappIntentKind(this.wireName);

  final String wireName;

  static DappIntentKind? tryParse(Object? value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// What a page asked `eth_sendTransaction` for, normalised.
@immutable
final class DappTxRequest {
  const DappTxRequest({
    required this.to,
    required this.data,
    required this.value,
  });

  /// Lower-case `0x` address.
  final String to;

  /// Lower-case call data, `0x` when empty.
  final String data;

  /// The value in wei, as an exact integer.
  final BigInt value;

  /// `0x…` quantity, the wire spelling.
  String get valueHex => '0x${value.toRadixString(16)}';

  Map<String, Object?> toWire() => <String, Object?>{
    'to': to,
    'data': data,
    'value': valueHex,
  };
}

/// What a page asked `personal_sign` / `eth_signTypedData_v4` for.
@immutable
final class DappSignRequest {
  const DappSignRequest({required this.method, required this.payload});

  /// `personal_sign` or `eth_signTypedData_v4`.
  final String method;

  /// The message exactly as the page sent it: a hex or UTF-8 string, or the
  /// typed-data JSON text.
  final String payload;
}

/// One decoded call the server named (`decodedCall`).
@immutable
final class DappDecodedCall {
  DappDecodedCall({
    required this.functionName,
    required this.selector,
    required Map<String, String> args,
    required this.dataLength,
  }) : args = Map<String, String>.unmodifiable(args);

  /// `null` when the selector is not one the server knows.
  final String? functionName;
  final String? selector;
  final Map<String, String> args;

  /// Bytes of call data, when the server says.
  final int? dataLength;
}

/// The review of a `dapp_tx` intent.
@immutable
final class DappTxReview {
  const DappTxReview({
    required this.to,
    required this.toIsContract,
    required this.toVerified,
    required this.valueWei,
    required this.decodedCall,
  });

  final String to;
  final bool? toIsContract;
  final bool? toVerified;
  final BigInt valueWei;
  final DappDecodedCall? decodedCall;
}

/// The review of a `dapp_sign` intent.
@immutable
final class DappSignReview {
  const DappSignReview({
    required this.method,
    required this.text,
    required this.hex,
    required this.typedData,
  });

  final String method;

  /// The UTF-8 reading of a `personal_sign` message, when it has one.
  final String? text;

  /// The raw hex of a `personal_sign` message that is not UTF-8.
  final String? hex;

  /// `{domain, primaryType, message}` of an `eth_signTypedData_v4` request.
  final Map<String, Object?>? typedData;
}

/// One DApp intent, `dapp_tx` or `dapp_sign` (docs/55 §二).
///
/// It is decoded leniently on keys the contract did not freeze and strictly
/// on the ones the signature depends on. What the wallet signs is checked
/// against what the page asked for ([matchesTx] / [matchesSign]) before the
/// wallet opens, so a server answer that describes a different call is
/// refused rather than signed.
@immutable
final class DappIntent {
  DappIntent({
    required this.intentId,
    required this.kind,
    required this.state,
    required this.walletId,
    required this.chainId,
    required this.origin,
    required this.reviewSha256,
    required this.expiresAt,
    required this.signingAllowed,
    required this.signingReasonCode,
    required List<DappRiskFlag> riskFlags,
    this.txReview,
    this.signReview,
    this.unsignedTransaction,
    this.signMethod,
    this.signPayload,
    this.transactionHash,
  }) : riskFlags = List<DappRiskFlag>.unmodifiable(riskFlags);

  final String intentId;
  final DappIntentKind kind;
  final LoopIntentState state;
  final String walletId;
  final String chainId;

  /// The page origin the server bound the intent to.
  final String origin;
  final String reviewSha256;
  final DateTime expiresAt;
  final bool signingAllowed;
  final String? signingReasonCode;
  final List<DappRiskFlag> riskFlags;
  final DappTxReview? txReview;
  final DappSignReview? signReview;

  /// `dapp_tx`: the exact `eth_sendTransaction` object, with the nonce, gas
  /// and fees the server bound.
  final LoopUnsignedTransaction? unsignedTransaction;

  /// `dapp_sign`: the method and the exact payload the device signs.
  final String? signMethod;
  final String? signPayload;

  final String? transactionHash;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now.toUtc());

  /// Why the confirmation may not open the wallet, or `null`.
  String? refusalAt(DateTime now) {
    if (!DappChains.canSign(chainId)) return 'CHAIN_SIGNING_DISABLED';
    if (isExpiredAt(now)) return 'INTENT_EXPIRED';
    if (!signingAllowed) return signingReasonCode ?? 'INTENT_NOT_SIGNABLE';
    if (state != LoopIntentState.awaitingSignature &&
        state != LoopIntentState.prepared) {
      return 'INTENT_${state.wireName.toUpperCase()}';
    }
    return null;
  }

  /// The transaction the server bound is the one the page asked for.
  bool matchesTx(DappTxRequest request, {required String fromAddress}) {
    final tx = unsignedTransaction;
    if (kind != DappIntentKind.transaction || tx == null) return false;
    if (tx.chainId != loopChainReference(chainId)) return false;
    if (tx.from.toLowerCase() != fromAddress.toLowerCase()) return false;
    if (tx.to.toLowerCase() != request.to) return false;
    if (tx.data.toLowerCase() != request.data) return false;
    final value = BigInt.tryParse(tx.value.substring(2), radix: 16);
    if (value != request.value) return false;
    final review = txReview;
    if (review == null || review.to.toLowerCase() != request.to) return false;
    return review.valueWei == request.value;
  }

  /// The message the server bound is the one the page asked for.
  ///
  /// A typed-data payload is compared as JSON (key order and spacing are
  /// not part of what is signed); a `personal_sign` message as the exact
  /// string.
  bool matchesSign(DappSignRequest request) {
    if (kind != DappIntentKind.message) return false;
    if (signMethod != request.method) return false;
    if (signReview?.method != request.method) return false;
    final payload = signPayload;
    if (payload == null) return false;
    if (payload == request.payload) return true;
    if (request.method != 'eth_signTypedData_v4') return false;
    try {
      return _jsonEquals(jsonDecode(payload), jsonDecode(request.payload));
    } on FormatException {
      return false;
    }
  }

  static bool _jsonEquals(Object? left, Object? right) {
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final key in left.keys) {
        if (!right.containsKey(key)) return false;
        if (!_jsonEquals(left[key], right[key])) return false;
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!_jsonEquals(left[index], right[index])) return false;
      }
      return true;
    }
    return left == right;
  }
}

/// The device's answer to a DApp intent.
enum DappSignStatus {
  /// The wallet produced [DappSignOutcome.value] (hash or signature).
  produced,

  /// The owner declined in the sheet or in the wallet. Nothing happened.
  rejected,

  /// The exit refused before the wallet opened, or the wallet failed.
  failed,
}

@immutable
final class DappSignOutcome {
  const DappSignOutcome({
    required this.status,
    required this.reasonCode,
    this.value,
    this.reported = false,
  });

  const DappSignOutcome.rejected()
    : status = DappSignStatus.rejected,
      reasonCode = 'USER_REJECTED',
      value = null,
      reported = false;

  final DappSignStatus status;
  final String reasonCode;

  /// The transaction hash or the signature, for [DappSignStatus.produced].
  final String? value;

  /// The server recorded [value].
  final bool reported;
}

/// The wallet the browser connects pages to: an embedded wallet, read
/// through the wallet directory.
@immutable
final class DappWalletIdentity {
  const DappWalletIdentity({required this.walletId, required this.address});

  final String walletId;

  /// Lower-case `0x` address.
  final String address;
}
