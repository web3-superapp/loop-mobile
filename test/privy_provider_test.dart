import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/privy/privy_production_adapter.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';

void main() {
  test('wallet signing adapter reads the centralized matching AppConfig', () {
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
      ],
    );
    addTearDown(container.dispose);

    final gateway =
        container.read(walletSigningGatewayProvider) as PrivyProductionAdapter;

    expect(gateway.appId, 'privy-app');
    expect(gateway.appClientId, 'privy-client');
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

    final gateway =
        container.read(walletSigningGatewayProvider) as PrivyProductionAdapter;

    expect(gateway.appId, isEmpty);
    expect(gateway.appClientId, isEmpty);
  });
}
