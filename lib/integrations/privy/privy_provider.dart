import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/privy_production_adapter.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

/// The current device signer of the live Privy session, or the fail-closed
/// default when Privy is not configured or the session has no embedded wallet.
final privyDeviceSignerProvider = Provider<PrivyDeviceSigner>((ref) {
  final host = ref.watch(privyDeviceSigningHostProvider);
  return host?.deviceSigner ?? const UnavailablePrivyDeviceSigner();
});

final privyDeviceSigningHostProvider = Provider<PrivyDeviceSigningHost?>((ref) {
  // Without both Privy credentials there is no SDK to construct: asking the
  // auth gateway for one would throw rather than fail closed.
  if (!ref.watch(appConfigProvider).canInitializePrivy) return null;
  final gateway = ref.watch(privyAuthGatewayProvider);
  return gateway is PrivyDeviceSigningHost
      ? gateway as PrivyDeviceSigningHost
      : null;
});

/// The single signing exit. Every money action goes through this provider.
final walletSigningGatewayProvider = Provider<WalletSigningGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  return PrivyWalletSigningGateway(
    host: ref.watch(privyDeviceSigningHostProvider),
    credentialsConfigured: config.canInitializePrivy,
  );
});
