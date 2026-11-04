import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

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
      ? LoopL10n.current.dapp_modelsFor
      : loopChainName(loopLaunchTestnetChainId);

  /// Signing is closed on BSC Mainnet (docs/00 rule 8).
  static bool canSign(String chainId) => chainId != loopPrimaryChainId;
}

/// The risk facts the server attaches to a DApp intent (docs/55 §二). The
/// strip on the confirmation is drawn only when at least one is present.
enum DappRiskFlag {
  unlimitedApproval('UNLIMITED_APPROVAL', forcesStepUp: true),
  approvalForAll('APPROVAL_FOR_ALL', forcesStepUp: true),
  // S346 (api finding A5): an approval whose spender has no code.
  eoaSpender('EOA_SPENDER', forcesStepUp: true),
  permitSignature('PERMIT_SIGNATURE', forcesStepUp: true),
  // S346 (api finding A2): a personal_sign of exactly 32 bytes of hex.
  rawHashSignature('RAW_HASH_SIGNATURE', forcesStepUp: true),
  // S346 (api finding A2): typed data whose primaryType is not recognised.
  unrecognizedTypedData('UNRECOGNIZED_TYPED_DATA', forcesStepUp: true),
  unverifiedContract('UNVERIFIED_CONTRACT'),
  simulationFailed('SIMULATION_FAILED');

  const DappRiskFlag(this.wireName, {this.forcesStepUp = false});

  final String wireName;

  String get label => switch (this) {
    unlimitedApproval => LoopL10n.current.dapp_modelsUnlimitedApproval,
    approvalForAll => LoopL10n.current.dapp_modelsApprovalForAll,
    eoaSpender => LoopL10n.current.dapp_modelsEoaSpender,
    permitSignature => LoopL10n.current.dapp_modelsPermitSignature,
    rawHashSignature => LoopL10n.current.dapp_modelsRawHashSignature,
    unrecognizedTypedData => LoopL10n.current.dapp_modelsUnrecognizedTypedData,
    unverifiedContract => LoopL10n.current.dapp_modelsUnverifiedContract,
    simulationFailed => LoopL10n.current.dapp_modelsSimulationFailed,
  };

  /// The large-amount step-up asks for a request carrying this flag whatever
  /// its amount (S346).
  final bool forcesStepUp;

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
    this.typedLeaves,
    this.typedTruncated = const <String>{},
  });

  final String method;

  /// The UTF-8 reading of a `personal_sign` message, when it has one.
  final String? text;

  /// The raw hex of a `personal_sign` message that is not UTF-8.
  final String? hex;

  /// `{domain, primaryType, message}` of an `eth_signTypedData_v4` request.
  final Map<String, Object?>? typedData;

  /// Every leaf of the typed-data message the sheet shows, by path
  /// (`a.b[0].c`), in the server's text form; checked against the page's
  /// own payload before the wallet opens (S346 · M8).
  final Map<String, String>? typedLeaves;

  /// The leaves whose shown value the server cut short.
  final Set<String> typedTruncated;
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
    this.valueUsd,
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

  /// The server's own USD valuation of the request (`policy.valueUsd`), or
  /// `null` when it made none — the Launch testnet has no price.
  final Decimal? valueUsd;
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

  /// The message the server bound is the one the page asked for, and the
  /// message the sheet shows is that message (S346 · M8).
  ///
  /// A typed-data payload is compared as JSON with every number compared by
  /// its literal text (key order and spacing are not part of what is
  /// signed), and refused outright when it holds an integer literal past
  /// 2^53 (S346 · M7); a `personal_sign` message as the exact string.
  bool matchesSign(DappSignRequest request) {
    if (kind != DappIntentKind.message) return false;
    if (signMethod != request.method) return false;
    final review = signReview;
    if (review == null || review.method != request.method) return false;
    final payload = signPayload;
    if (payload == null) return false;
    if (request.method == 'personal_sign') {
      return payload == request.payload &&
          dappPersonalMessageMatchesReview(request.payload, review);
    }
    if (request.method != 'eth_signTypedData_v4') return false;
    final Object? signed;
    final Object? asked;
    try {
      signed = DappJsonLiteral.parse(payload);
      asked = DappJsonLiteral.parse(request.payload);
    } on FormatException {
      return false;
    }
    if (!DappJsonLiteral.equals(signed, asked)) return false;
    return dappTypedDataMatchesReview(asked, review);
  }
}

/// `0x…` hex is raw bytes, anything else UTF-8 text (MetaMask semantics).
List<int> dappPersonalMessageBytes(String payload) {
  if (RegExp(r'^0x([0-9a-fA-F]{2})*$').hasMatch(payload)) {
    final hex = payload.substring(2);
    return <int>[
      for (var index = 0; index < hex.length; index += 2)
        int.parse(hex.substring(index, index + 2), radix: 16),
    ];
  }
  return utf8.encode(payload);
}

/// The text and hex the review shows are the page's own `personal_sign`
/// message.
bool dappPersonalMessageMatchesReview(String payload, DappSignReview review) {
  final bytes = dappPersonalMessageBytes(payload);
  final hex = review.hex;
  if (hex != null) {
    final local = '0x${_hexOf(bytes)}';
    if (hex.toLowerCase() != local) return false;
  }
  final text = review.text;
  if (text != null) {
    final String decoded;
    try {
      decoded = utf8.decode(bytes);
    } on FormatException {
      return false;
    }
    if (decoded != text) return false;
  }
  return hex != null || text != null;
}

String _hexOf(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

/// The primary type, the domain and every message leaf the review shows are
/// the page's own typed data.
bool dappTypedDataMatchesReview(Object? asked, DappSignReview review) {
  final shown = review.typedData;
  if (shown == null || asked is! Map) return false;
  final primary = shown['primaryType'];
  if (primary != null &&
      dappTypedLeafText(asked['primaryType']) != '$primary') {
    return false;
  }
  final domain = shown['domain'];
  if (domain is Map) {
    final askedDomain = asked['domain'];
    if (askedDomain is! Map) return false;
    for (final entry in domain.entries) {
      if (entry.value == null) continue;
      final value = dappTypedLeafText(entry.value);
      if (value == null || dappTypedLeafText(askedDomain[entry.key]) != value) {
        return false;
      }
    }
  }
  final leaves = review.typedLeaves;
  if (leaves == null) return false;
  final message = asked['message'];
  for (final entry in leaves.entries) {
    final value = dappTypedLeafText(dappTypedPath(message, entry.key));
    if (value == null) return false;
    if (review.typedTruncated.contains(entry.key)) {
      if (!value.startsWith(entry.value)) return false;
    } else if (value != entry.value) {
      return false;
    }
  }
  return true;
}

final RegExp _pathPart = RegExp(r'([^.\[\]]+)|\[(\d+)\]');

/// The node at `a.b[0].c` under [root], or `null`.
Object? dappTypedPath(Object? root, String path) {
  Object? node = root;
  for (final match in _pathPart.allMatches(path)) {
    final key = match.group(1);
    final index = match.group(2);
    if (key != null) {
      if (node is! Map || !node.containsKey(key)) return null;
      node = node[key];
    } else {
      final at = int.parse(index!);
      if (node is! List || at >= node.length) return null;
      node = node[at];
    }
  }
  return node;
}

/// A typed-data leaf as the server writes it: strings as they are, numbers
/// by their literal, booleans as `true` / `false`. `null` for anything that
/// is not a leaf.
String? dappTypedLeafText(Object? value) => switch (value) {
  final String text => text,
  final DappJsonNumber number => number.literal,
  final bool flag => flag ? 'true' : 'false',
  final int number => '$number',
  _ => null,
};

/// One JSON number kept as the literal the page wrote.
@immutable
final class DappJsonNumber {
  const DappJsonNumber(this.literal);

  final String literal;

  @override
  bool operator ==(Object other) =>
      other is DappJsonNumber && other.literal == literal;

  @override
  int get hashCode => literal.hashCode;

  @override
  String toString() => literal;
}

/// A JSON reader that keeps every number as its literal text, so two
/// payloads are compared by what was written rather than by a double, and
/// that refuses an integer past 2^53 (S346 · M7).
abstract final class DappJsonLiteral {
  static final BigInt _safe = BigInt.from(9007199254740992);
  static final RegExp _number = RegExp(
    r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?',
  );

  static Object? parse(String source) {
    final reader = _Reader(source);
    final value = reader.value();
    reader.skip();
    if (reader.at != source.length) throw const FormatException('trailing');
    return value;
  }

  static bool equals(Object? left, Object? right) {
    if (left is Map && right is Map) {
      if (left.length != right.length) return false;
      for (final key in left.keys) {
        if (!right.containsKey(key)) return false;
        if (!equals(left[key], right[key])) return false;
      }
      return true;
    }
    if (left is List && right is List) {
      if (left.length != right.length) return false;
      for (var index = 0; index < left.length; index++) {
        if (!equals(left[index], right[index])) return false;
      }
      return true;
    }
    return left == right;
  }

  static DappJsonNumber _checked(String literal) {
    final plain = !literal.contains('.') && !literal.contains(RegExp('[eE]'));
    if (plain) {
      if (BigInt.parse(literal).abs() > _safe) {
        throw const FormatException('integer past 2^53');
      }
    } else {
      final value = double.tryParse(literal);
      if (value == null || !value.isFinite || value.abs() >= 9007199254740992) {
        throw const FormatException('number past 2^53');
      }
    }
    return DappJsonNumber(literal);
  }
}

final class _Reader {
  _Reader(this.source);

  final String source;
  int at = 0;

  void skip() {
    while (at < source.length) {
      final unit = source.codeUnitAt(at);
      if (unit == 0x20 || unit == 0x0a || unit == 0x0d || unit == 0x09) {
        at += 1;
      } else {
        break;
      }
    }
  }

  Object? value() {
    skip();
    if (at >= source.length) throw const FormatException('end');
    final char = source[at];
    switch (char) {
      case '{':
        at += 1;
        final map = <String, Object?>{};
        skip();
        if (_take('}')) return map;
        while (true) {
          skip();
          final key = _string();
          skip();
          if (!_take(':')) throw const FormatException(':');
          if (map.containsKey(key)) throw const FormatException('dup');
          map[key] = value();
          skip();
          if (_take('}')) return map;
          if (!_take(',')) throw const FormatException(',');
        }
      case '[':
        at += 1;
        final list = <Object?>[];
        skip();
        if (_take(']')) return list;
        while (true) {
          list.add(value());
          skip();
          if (_take(']')) return list;
          if (!_take(',')) throw const FormatException(',');
        }
      case '"':
        return _string();
    }
    for (final (word, meaning) in const <(String, Object?)>[
      ('true', true),
      ('false', false),
      ('null', null),
    ]) {
      if (source.startsWith(word, at)) {
        at += word.length;
        return meaning;
      }
    }
    final match = DappJsonLiteral._number.matchAsPrefix(source, at);
    if (match == null) throw const FormatException('value');
    at = match.end;
    return DappJsonLiteral._checked(match.group(0)!);
  }

  bool _take(String char) {
    if (at < source.length && source[at] == char) {
      at += 1;
      return true;
    }
    return false;
  }

  String _string() {
    if (!_take('"')) throw const FormatException('"');
    final start = at - 1;
    while (at < source.length) {
      final char = source[at];
      if (char == '\\') {
        at += 2;
        continue;
      }
      at += 1;
      if (char == '"') {
        return jsonDecode(source.substring(start, at)) as String;
      }
    }
    throw const FormatException('unterminated');
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
