import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';

void main() {
  test('build-time identifiers default closed when not supplied', () {
    final config = AppConfig.fromEnvironment();

    expect(config.privyAppId, 'cmt2t8k4n00780cjsxjqk0dkq');
    expect(config.hasPrivyAppId, isTrue);
    expect(config.privyAppClientId, isEmpty);
    expect(config.hasPrivyAppClientId, isFalse);
    expect(config.reownProjectId, isEmpty);
    expect(config.hasReownProjectId, isFalse);
    expect(config.canInitializePrivy, isFalse);
    expect(config.canConnectExternalWallet, isFalse);
    expect(config.streamApiKey, 'qpwjdy8zjbdu');
    expect(config.hasStreamApiKey, isTrue);
    expect(config.hasBackend, isFalse);
    expect(config.canConnectStream, isFalse);
    expect(config.firebaseConfigured, isFalse);
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
