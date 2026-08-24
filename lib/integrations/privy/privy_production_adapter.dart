import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

final class PrivyProductionAdapter implements WalletSigningGateway {
  const PrivyProductionAdapter({
    required this.appId,
    required this.appClientId,
  });

  final String appId;
  final String appClientId;

  @override
  WalletGatewayAvailability get availability =>
      WalletGatewayAvailability.unavailable;

  @override
  String get label => 'Privy';

  @override
  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  }) async {
    if (appId.trim().isEmpty || appClientId.trim().isEmpty) {
      return const WalletHandoffResult(
        accepted: false,
        code: 'privy_credentials_missing',
      );
    }
    if (intent.requiresLoopBackend) {
      return const WalletHandoffResult(
        accepted: false,
        code: 'loop_backend_required',
      );
    }
    if (intent.isLocalPreview) {
      return const WalletHandoffResult(
        accepted: false,
        code: 'canonical_intent_required',
      );
    }
    final validation = intent.validateAt(now);
    if (validation != null) {
      return WalletHandoffResult(accepted: false, code: validation);
    }
    return const WalletHandoffResult(
      accepted: false,
      code: 'privy_handoff_not_configured',
    );
  }
}
