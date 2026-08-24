import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Client-safe build-time configuration.
///
/// Server secrets, Privy refresh tokens, Stream user tokens, Firebase service
/// accounts, and Hyperliquid signing keys must never be added here.
@immutable
class AppConfig {
  const AppConfig({
    required this.privyAppId,
    required this.privyAppClientId,
    required this.streamApiKey,
    required this.backendBaseUrl,
    required this.firebaseConfigured,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      privyAppId: String.fromEnvironment(
        'PRIVY_APP_ID',
        defaultValue: 'cmt2t8k4n00780cjsxjqk0dkq',
      ),
      privyAppClientId: String.fromEnvironment('PRIVY_APP_CLIENT_ID'),
      streamApiKey: String.fromEnvironment(
        'STREAM_API_KEY',
        defaultValue: 'qpwjdy8zjbdu',
      ),
      backendBaseUrl: String.fromEnvironment('LOOP_BACKEND_BASE_URL'),
      firebaseConfigured: bool.fromEnvironment('FIREBASE_CONFIGURED'),
    );
  }

  final String privyAppId;
  final String privyAppClientId;
  final String streamApiKey;
  final String backendBaseUrl;
  final bool firebaseConfigured;

  bool get hasPrivyAppId => privyAppId.trim().isNotEmpty;

  bool get hasPrivyAppClientId => privyAppClientId.trim().isNotEmpty;

  bool get canInitializePrivy => hasPrivyAppId && hasPrivyAppClientId;

  bool get hasStreamApiKey => streamApiKey.trim().isNotEmpty;

  bool get hasBackend => backendBaseUrl.trim().isNotEmpty;

  bool get canConnectStream => hasStreamApiKey && hasBackend;
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

/// Explicitly overridden only by the offline `main_preview.dart` entry point
/// and tests. Production composition must remain fail-closed.
final developmentPreviewEnabledProvider = Provider<bool>((ref) => false);
