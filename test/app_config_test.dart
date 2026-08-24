import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';

void main() {
  test('client-safe identifiers and missing services remain distinct', () {
    final config = AppConfig.fromEnvironment();

    expect(config.privyAppId, 'cmt2t8k4n00780cjsxjqk0dkq');
    expect(config.hasPrivyAppId, isTrue);
    expect(config.hasPrivyAppClientId, isFalse);
    expect(config.canInitializePrivy, isFalse);
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
}
