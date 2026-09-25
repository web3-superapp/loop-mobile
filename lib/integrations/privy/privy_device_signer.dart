import 'dart:convert';

import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:privy_flutter/privy_flutter.dart';

/// Narrow device-signing surface of the Privy embedded wallet.
///
/// It is deliberately separate from [PrivyAuthGateway]: identity test doubles
/// must not gain the ability to broadcast a transaction, and the two SDK calls
/// this exposes are the only wallet authority the app has.
abstract interface class PrivyDeviceSigner {
  /// True only when a verified Privy session with an embedded Ethereum wallet
  /// is present. It never proves that a broadcast will succeed.
  bool get isReady;

  /// Broadcasts one transaction through the embedded wallet whose address is
  /// [fromAddress] and returns the transaction hash.
  ///
  /// [kind] and [chainId] are the intent's own. [launchChainId] is the Launch
  /// slot the session's `GET /v2/chain/status` published (`launchChain`), or
  /// `null` when the server omitted it — which means the Launch slot is the
  /// primary chain — or when it could not be read. Only a Launch intent on
  /// exactly that published slot may leave the primary chain (decision 0090,
  /// [privyChainRefusal]). [chainId] is never used to rewrite the payload.
  ///
  /// [transaction] is the server's object. It reaches the SDK through
  /// [privyTransactionJson], which only spells the same fields the way the
  /// native Privy SDKs read them; it never adds, drops or changes a value.
  Future<String> sendTransaction({
    required IntentKind kind,
    required String chainId,
    required String? launchChainId,
    required String fromAddress,
    required Map<String, Object?> transaction,
  });

  /// Signs the server's canonical wallet-API payload and returns the opaque
  /// signature for the `privy-authorization-signature` header.
  Future<String> authorizationSignature({
    required int version,
    required String method,
    required String url,
    required Map<String, String> headers,
    required Map<String, Object?> body,
  });
}

/// Raised when the device cannot sign. It carries no provider detail.
final class PrivySigningException implements Exception {
  const PrivySigningException(this.code);

  /// A stable, non-provider reason string.
  final String code;

  @override
  String toString() => 'PrivySigningException($code)';
}

/// The fail-closed default: no session, no wallet, no signature.
final class UnavailablePrivyDeviceSigner implements PrivyDeviceSigner {
  const UnavailablePrivyDeviceSigner();

  @override
  bool get isReady => false;

  @override
  Future<String> sendTransaction({
    required IntentKind kind,
    required String chainId,
    required String? launchChainId,
    required String fromAddress,
    required Map<String, Object?> transaction,
  }) => throw const PrivySigningException('privy_wallet_unavailable');

  @override
  Future<String> authorizationSignature({
    required int version,
    required String method,
    required String url,
    required Map<String, String> headers,
    required Map<String, Object?> body,
  }) => throw const PrivySigningException('privy_wallet_unavailable');
}

/// Binds one live [PrivyUser] to the two SDK signing calls.
final class SdkPrivyDeviceSigner implements PrivyDeviceSigner {
  const SdkPrivyDeviceSigner(this._user);

  final PrivyUser? _user;

  @override
  bool get isReady => _wallet(_user) != null;

  static EmbeddedEthereumWallet? _wallet(PrivyUser? user) {
    final wallets = user?.embeddedEthereumWallets;
    if (wallets == null || wallets.isEmpty) return null;
    return wallets.first;
  }

  @override
  Future<String> sendTransaction({
    required IntentKind kind,
    required String chainId,
    required String? launchChainId,
    required String fromAddress,
    required Map<String, Object?> transaction,
  }) async {
    // The chain rules come first, before the session is even looked at, so a
    // refusal never depends on being signed in (decisions 0062, 0090).
    final refusal = privyChainRefusal(
      kind: kind,
      chainId: chainId,
      launchChainId: launchChainId,
      transaction: transaction,
    );
    if (refusal != null) throw PrivySigningException(refusal);
    // Encoded before the wallet is touched: a payload the SDK cannot read is
    // refused here, where it provably reached nothing.
    final transactionJson = privyTransactionJson(transaction);
    final user = _user;
    if (user == null) {
      throw const PrivySigningException('privy_session_required');
    }
    // The server built this payload for one specific embedded wallet. Signing
    // it with another wallet would broadcast a transaction the owner never
    // reviewed, so the address must match exactly.
    EmbeddedEthereumWallet? match;
    for (final wallet in user.embeddedEthereumWallets) {
      if (wallet.address.toLowerCase() == fromAddress.toLowerCase()) {
        match = wallet;
        break;
      }
    }
    if (match == null) {
      throw const PrivySigningException('privy_wallet_mismatch');
    }
    // privy_flutter 0.10.1 selects no chain: `EmbeddedEthereumWalletProvider`
    // has `request` and nothing else. The native SDKs broadcast through the
    // Privy wallet API with `caip2 = eip155:<transaction.chainId>`, so the
    // payload's own `chainId` — already proven equal to the intent's — is
    // the chain. There is no wallet-level chain to switch, and therefore none
    // to switch back: nothing here changes state a later send could inherit.
    // The single parameter is the transaction as a JSON string, exactly as
    // the SDK's own `EthereumRpcRequest.ethSendTransaction(String)` builds
    // it; the native channels read `params` as a list of strings.
    final result = await match.provider.request(
      EthereumRpcRequest(
        method: 'eth_sendTransaction',
        params: <String>[transactionJson],
      ),
    );
    switch (result) {
      case Success<EthereumRpcResponse>(value: final response):
        final hash = response.data.trim();
        if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(hash)) {
          // A response the client cannot read leaves the outcome unresolved:
          // the transaction may already be on chain.
          throw const PrivySigningException('privy_broadcast_unreadable');
        }
        return hash;
      case Failure<EthereumRpcResponse>(error: final error):
        // Only a message the client can recognise as the owner declining
        // proves nothing was broadcast. Every other failure — a channel
        // error, a timeout, an unmapped provider string — may have reached
        // the network, so it locks rather than inviting a second signature.
        throw PrivySigningException(privyWalletFailureCode(error.message));
    }
  }

  @override
  Future<String> authorizationSignature({
    required int version,
    required String method,
    required String url,
    required Map<String, String> headers,
    required Map<String, Object?> body,
  }) async {
    final user = _user;
    if (user == null) {
      throw const PrivySigningException('privy_session_required');
    }
    final result = await user.generateAuthorizationSignature(
      WalletApiPayload(
        version: version,
        url: url,
        method: method,
        headers: headers,
        body: body,
      ),
    );
    switch (result) {
      case Success<String>(value: final signature):
        final trimmed = signature.trim();
        if (trimmed.isEmpty || trimmed.length > 4096) {
          throw const PrivySigningException('privy_signature_unreadable');
        }
        return trimmed;
      case Failure<String>(error: final error):
        // An authorization signature never leaves the device, but an unmapped
        // failure still cannot prove that: it stays unknown.
        final code = privyWalletFailureCode(error.message);
        throw PrivySigningException(
          code == 'privy_broadcast_rejected'
              ? 'privy_signature_rejected'
              : code,
        );
    }
  }
}

/// The chain admission of one device broadcast (decision 0090), or `null`.
///
/// | kind                               | primary | published Launch slot | other |
/// | ---------------------------------- | ------- | --------------------- | ----- |
/// | launchApproval, launchPurchase     | sign    | sign                  | refuse |
/// | transfer, approval, swap, perpOrder | sign    | refuse                | refuse |
///
/// "Published Launch slot" is [launchChainId] when it is non-null and not the
/// primary chain; a `null` slot (omitted by the server, or unreadable) admits
/// the primary chain only. A chain the client does not know, or a payload
/// whose own `chainId` disagrees with the intent, is `privy_chain_mismatch`
/// whatever the kind.
String? privyChainRefusal({
  required IntentKind kind,
  required String chainId,
  required String? launchChainId,
  required Map<String, Object?> transaction,
}) {
  // The membership check is its own statement: `loopChainReference` throws on
  // an unknown chain rather than answering with the primary one.
  if (!loopKnownChainIds.contains(chainId)) return 'privy_chain_mismatch';
  // The payload has to agree with the intent it came from. A transaction
  // whose own `chainId` differs from the reviewed chain would be broadcast
  // somewhere nobody reviewed — and one without a `chainId` would be sent to
  // the SDK's default (Ethereum mainnet).
  if (transaction['chainId'] != loopChainReference(chainId)) {
    return 'privy_chain_mismatch';
  }
  if (chainId == loopPrimaryChainId) return null;
  final isLaunchKind =
      kind == IntentKind.launchApproval || kind == IntentKind.launchPurchase;
  if (isLaunchKind && launchChainId != null && launchChainId == chainId) {
    return null;
  }
  return 'privy_chain_switch_unsupported';
}

/// The one `eth_sendTransaction` parameter, spelled the way the native Privy
/// SDKs decode it.
///
/// The server's payload (loop-api `UnsignedTransaction`) uses the viem
/// spelling; Privy's `UnsignedEthereumTransaction` (Android `privy-core`
/// 0.12.1, iOS `PrivySDK` 2.12.0) reads `gasLimit` rather than `gas`, an
/// integer EIP-2718 `type` rather than a name, and silently ignores unknown
/// keys. Sent verbatim, `gas` would be dropped and `"eip1559"` would fail to
/// decode. So exactly three spellings change, and no value does:
///
/// - `gas` is written as `gasLimit`, same quantity;
/// - `type` `eip1559` is written as `2` and `legacy` as `0`;
/// - a key whose value is `null` is omitted, which JSON-RPC reads the same.
///
/// Anything else — an unknown `type`, both `gas` and `gasLimit` — throws
/// `privy_payload_unencodable` before any wallet is opened.
String privyTransactionJson(Map<String, Object?> transaction) {
  final encoded = <String, Object?>{};
  for (final entry in transaction.entries) {
    final value = entry.value;
    if (value == null) continue;
    switch (entry.key) {
      case 'gas':
        if (transaction['gasLimit'] != null) {
          throw const PrivySigningException('privy_payload_unencodable');
        }
        encoded['gasLimit'] = value;
      case 'type':
        encoded['type'] = switch (value) {
          'eip1559' => 2,
          'legacy' => 0,
          _ => throw const PrivySigningException('privy_payload_unencodable'),
        };
      default:
        encoded[entry.key] = value;
    }
  }
  try {
    return jsonEncode(encoded);
  } on JsonUnsupportedObjectError {
    throw const PrivySigningException('privy_payload_unencodable');
  }
}

/// Classifies one wallet failure message.
///
/// Only a message the client can read as the owner declining proves that
/// nothing was broadcast. Every other failure — a channel error, a timeout, an
/// unmapped provider string — may already have reached the network, so it maps
/// to the unknown outcome and locks rather than inviting a second signature.
String privyWalletFailureCode(String message) {
  const declined = <String>[
    'user rejected',
    'user denied',
    'user cancelled',
    'user canceled',
    'rejected by user',
    'denied by user',
    'cancelled by user',
    'request rejected',
    'user declined',
  ];
  final normalized = message.toLowerCase();
  for (final marker in declined) {
    if (normalized.contains(marker)) return 'privy_broadcast_rejected';
  }
  return 'wallet_outcome_unknown';
}
