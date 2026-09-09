import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/privy_production_adapter.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';

void main() {
  test('the signing exit reads the centralized matching AppConfig', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            privyAppId: 'privy-app',
            privyAppClientId: 'privy-client',
            streamApiKey: '',
            backendBaseUrl: '',
            firebaseConfigured: false,
          ),
        ),
        // The real SDK gateway cannot be constructed off-device; the exit is
        // still expected to stay closed without a verified session.
        privyAuthGatewayProvider.overrideWithValue(
          const UnconfiguredPrivyAuthGateway(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final gateway = container.read(
      walletSigningGatewayProvider,
    ) as PrivyWalletSigningGateway;

    expect(gateway.credentialsConfigured, isTrue);
    // Credentials alone are not a wallet: without a verified Privy session the
    // exit stays closed.
    expect(gateway.availability, WalletGatewayAvailability.unavailable);
  });

  test('a build-profile mismatch strips Privy provider inputs', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            privyAppId: 'must-not-be-used',
            privyAppClientId: 'must-not-be-used',
            streamApiKey: '',
            backendBaseUrl: '',
            firebaseConfigured: false,
            buildMode: LoopBuildMode.release,
            declaredModeMatchesRuntime: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final gateway = container.read(
      walletSigningGatewayProvider,
    ) as PrivyWalletSigningGateway;

    expect(gateway.credentialsConfigured, isFalse);
    expect(gateway.availability, WalletGatewayAvailability.unavailable);
  });

  test('the device signer defaults to the fail-closed implementation', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            privyAppId: '',
            privyAppClientId: '',
            streamApiKey: '',
            backendBaseUrl: '',
            firebaseConfigured: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(privyDeviceSignerProvider),
      isA<UnavailablePrivyDeviceSigner>(),
    );
  });
}
