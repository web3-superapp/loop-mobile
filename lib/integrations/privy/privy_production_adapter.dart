import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

/// Anything that can produce the current device signer for the live Privy
/// session. Implemented by the SDK auth gateway, which already owns the user.
abstract interface class PrivyDeviceSigningHost {
  PrivyDeviceSigner get deviceSigner;
}

/// Reads the Launch slot the session's `GET /v2/chain/status` publishes.
///
/// It answers `launchChain.chainId`, or `null` when the server omitted
/// `launchChain` (the Launch slot is the primary chain). A read that fails
/// may throw; the signing exit then treats the slot as unpublished.
typedef PublishedLaunchChainReader = Future<String?> Function();

/// The production signing exit.
///
/// It performs exactly one wallet call per handoff and returns what the wallet
/// produced. It never reports, polls or interprets an outcome: reporting the
/// hash and reading the resulting state belong to the intent gateway, so a
/// wallet success can never be mistaken for an on-chain result.
final class PrivyWalletSigningGateway implements WalletSigningGateway {
  const PrivyWalletSigningGateway({
    required this.host,
    required this.credentialsConfigured,
    this.readLaunchChain,
  });

  final PrivyDeviceSigningHost? host;
  final bool credentialsConfigured;

  /// Consulted only for an intent off the primary chain, so a primary-chain
  /// send, approval or swap never waits on it. Absent means no Launch slot
  /// was ever published to this exit, which admits the primary chain only.
  final PublishedLaunchChainReader? readLaunchChain;

  Future<String?> _launchChainFor(SigningIntent intent) async {
    if (intent.chainId == loopPrimaryChainId) return null;
    final reader = readLaunchChain;
    if (reader == null) return null;
    try {
      return await reader();
    } catch (_) {
      // An unreadable chain status publishes nothing: the device signer then
      // refuses the testnet before any wallet is opened.
      return null;
    }
  }

  @override
  WalletGatewayAvailability get availability {
    if (!credentialsConfigured) return WalletGatewayAvailability.unavailable;
    final signer = host?.deviceSigner;
    return signer != null && signer.isReady
        ? WalletGatewayAvailability.available
        : WalletGatewayAvailability.unavailable;
  }

  @override
  String get label => 'Privy';

  @override
  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  }) async {
    if (!credentialsConfigured) {
      return const WalletHandoffResult.rejected('privy_credentials_missing');
    }
    final refusal = walletHandoffRefusal(intent, now: now);
    if (refusal != null) return WalletHandoffResult.rejected(refusal);
    final signer = host?.deviceSigner;
    if (signer == null || !signer.isReady) {
      return const WalletHandoffResult.rejected('privy_wallet_unavailable');
    }

    try {
      final payload = intent.payload!;
      final value = switch (payload) {
        DeviceTransactionPayload(
          fromAddress: final from,
          transaction: final transaction,
        ) =>
          await signer.sendTransaction(
            kind: intent.kind,
            chainId: intent.chainId,
            launchChainId: await _launchChainFor(intent),
            fromAddress: from,
            transaction: transaction,
          ),
        AuthorizationSignaturePayload(
          version: final version,
          method: final method,
          url: final url,
          headers: final headers,
          body: final body,
        ) =>
          await signer.authorizationSignature(
            version: version,
            method: method,
            url: url,
            headers: headers,
            body: body,
          ),
      };
      return WalletHandoffResult(
        accepted: true,
        code: 'wallet_accepted',
        value: value,
      );
    } on PrivySigningException catch (failure) {
      return WalletHandoffResult.rejected(failure.code);
    } catch (_) {
      // An unreadable wallet outcome is never a success and never a plain
      // failure: the caller must treat it as unresolved.
      return const WalletHandoffResult.rejected('wallet_outcome_unknown');
    }
  }
}
