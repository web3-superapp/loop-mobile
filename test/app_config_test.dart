import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/app_environment.dart';

void main() {
  test('missing build profile and identifiers fail closed', () {
    final config = AppConfig.fromEnvironment();

    expect(config.buildMode, LoopBuildMode.debug);
    expect(config.declaredModeMatchesRuntime, isFalse);
    expect(config.privyAppId, isEmpty);
    expect(config.hasPrivyAppId, isFalse);
    expect(config.privyAppClientId, isEmpty);
    expect(config.hasPrivyAppClientId, isFalse);
    expect(config.reownProjectId, isEmpty);
    expect(config.hasReownProjectId, isFalse);
    expect(config.canInitializePrivy, isFalse);
    expect(config.canConnectExternalWallet, isFalse);
    expect(config.streamApiKey, isEmpty);
    expect(config.hasStreamApiKey, isFalse);
    expect(config.hasBackend, isFalse);
    expect(config.canConnectStream, isFalse);
    expect(config.firebaseConfigured, isFalse);
    expect(config.canInitializeFirebase, isFalse);
  });

  test('declared build profile must match Debug or Release runtime', () {
    final debug = AppConfig.fromEnvironment(
      releaseMode: false,
      declaredBuildMode: 'debug',
    );
    final release = AppConfig.fromEnvironment(
      releaseMode: true,
      declaredBuildMode: 'release',
    );
    final debugWithReleaseValues = AppConfig.fromEnvironment(
      releaseMode: false,
      declaredBuildMode: 'release',
    );
    final releaseWithDebugValues = AppConfig.fromEnvironment(
      releaseMode: true,
      declaredBuildMode: 'debug',
    );

    expect(debug.buildMode, LoopBuildMode.debug);
    expect(debug.declaredModeMatchesRuntime, isTrue);
    expect(release.buildMode, LoopBuildMode.release);
    expect(release.declaredModeMatchesRuntime, isTrue);
    expect(debugWithReleaseValues.declaredModeMatchesRuntime, isFalse);
    expect(releaseWithDebugValues.declaredModeMatchesRuntime, isFalse);
  });

  test('a profile mismatch gates every provider-backed capability', () {
    const config = AppConfig(
      privyAppId: 'privy-app',
      privyAppClientId: 'privy-client',
      reownProjectId: '26a5cc1adad234fcdf7762b8d2a2b28d',
      streamApiKey: 'stream-key',
      backendBaseUrl: 'https://api-dev.quant-dinger.cc',
      firebaseConfigured: true,
      buildMode: LoopBuildMode.release,
      declaredModeMatchesRuntime: false,
    );

    expect(config.hasPrivyAppId, isTrue);
    expect(config.hasStreamApiKey, isTrue);
    expect(config.hasBackend, isTrue);
    expect(config.canInitializePrivy, isFalse);
    expect(config.canConnectExternalWallet, isFalse);
    expect(config.canUseBackend, isFalse);
    expect(config.backendBaseUrlForCurrentBuild, isEmpty);
    expect(config.streamApiKeyForCurrentBuild, isEmpty);
    expect(config.canConnectStream, isFalse);
    expect(config.canInitializeFirebase, isFalse);
  });

  test('build profile never widens the locked product security policy', () {
    expect(BuildPolicy.appEnvironment, AppEnvironment.development);
    expect(BuildPolicy.hyperliquidEnvironment, HyperliquidEnvironment.testnet);
    expect(BuildPolicy.mainnetEnabled, isFalse);
    expect(BuildPolicy.withdrawalsEnabled, isFalse);
    expect(BuildPolicy.automatedTradingEnabled, isFalse);
    expect(BuildPolicy.spotExecutionEnabled, isFalse);
  });

  test('Privy cannot initialize with only one identifier', () {
    const missingAppId = AppConfig(
      privyAppId: '',
      privyAppClientId: 'client-id',
      streamApiKey: '',
      backendBaseUrl: '',
      firebaseConfigured: false,
    );
    const missingClientId = AppConfig(
      privyAppId: 'app-id',
      privyAppClientId: '',
      streamApiKey: '',
      backendBaseUrl: '',
      firebaseConfigured: false,
    );

    expect(missingAppId.canInitializePrivy, isFalse);
    expect(missingClientId.canInitializePrivy, isFalse);
  });

  test('external wallet requires an exact public Reown project ID', () {
    const configured = AppConfig(
      privyAppId: 'app-id',
      privyAppClientId: 'client-id',
      reownProjectId: '26a5cc1adad234fcdf7762b8d2a2b28d',
      streamApiKey: '',
      backendBaseUrl: '',
      firebaseConfigured: false,
    );
    const malformed = AppConfig(
      privyAppId: 'app-id',
      privyAppClientId: 'client-id',
      reownProjectId: 'not-a-project-id',
      streamApiKey: '',
      backendBaseUrl: '',
      firebaseConfigured: false,
    );

    expect(configured.canConnectExternalWallet, isTrue);
    expect(malformed.hasReownProjectId, isTrue);
    expect(malformed.hasValidReownProjectId, isFalse);
    expect(malformed.canConnectExternalWallet, isFalse);
    expect(AppConfig.privyOAuthScheme, 'com.cywd.loop.privy');
    expect(AppConfig.reownWalletScheme, 'com.cywd.loop.wallet');
    expect(AppConfig.reownMetadataUrl, 'https://quant-dinger.cc');
    expect(Uri.parse(AppConfig.reownIconUrl).isScheme('https'), isTrue);
  });
}
