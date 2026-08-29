import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/privy/privy_production_adapter.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

final walletSigningGatewayProvider = Provider<WalletSigningGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  return PrivyProductionAdapter(
    appId: config.canInitializePrivy ? config.privyAppId : '',
    appClientId: config.canInitializePrivy ? config.privyAppClientId : '',
  );
});
