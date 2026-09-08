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
  /// [transaction] is forwarded verbatim; this method never edits, reorders or
  /// supplements a field.
  Future<String> sendTransaction({
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
    required String fromAddress,
    required Map<String, Object?> transaction,
  }) async {
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
    final result = await match.provider.request(
      EthereumRpcRequest(
        method: 'eth_sendTransaction',
        params: <Object?>[transaction],
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
      case Failure<EthereumRpcResponse>():
        throw const PrivySigningException('privy_broadcast_rejected');
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
      case Failure<String>():
        throw const PrivySigningException('privy_signature_rejected');
    }
  }
}
