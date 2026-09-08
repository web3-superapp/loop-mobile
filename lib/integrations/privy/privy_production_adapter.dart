import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

/// Anything that can produce the current device signer for the live Privy
/// session. Implemented by the SDK auth gateway, which already owns the user.
abstract interface class PrivyDeviceSigningHost {
  PrivyDeviceSigner get deviceSigner;
}

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
  });

  final PrivyDeviceSigningHost? host;
  final bool credentialsConfigured;

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
