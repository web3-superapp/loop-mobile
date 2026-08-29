import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum LoopBuildMode { debug, release }

/// Client-safe build-time configuration.
///
/// Server secrets, Privy refresh tokens, Stream user tokens, Firebase service
/// accounts, and Hyperliquid signing keys must never be added here.
@immutable
class AppConfig {
  const AppConfig({
    required this.privyAppId,
    required this.privyAppClientId,
    this.reownProjectId = '',
    required this.streamApiKey,
    required this.backendBaseUrl,
    required this.firebaseConfigured,
    this.buildMode = LoopBuildMode.debug,
    this.declaredModeMatchesRuntime = true,
  });

  factory AppConfig.fromEnvironment({
    bool? releaseMode,
    String? declaredBuildMode,
  }) {
    final expectedBuildMode = (releaseMode ?? kReleaseMode)
        ? LoopBuildMode.release
        : LoopBuildMode.debug;
    final rawBuildMode =
        declaredBuildMode ?? const String.fromEnvironment('LOOP_BUILD_MODE');
    final configuredBuildMode = _parseBuildMode(rawBuildMode);

    return AppConfig(
      privyAppId: const String.fromEnvironment('PRIVY_APP_ID'),
      privyAppClientId: const String.fromEnvironment('PRIVY_APP_CLIENT_ID'),
      reownProjectId: const String.fromEnvironment('REOWN_PROJECT_ID'),
      streamApiKey: const String.fromEnvironment('STREAM_API_KEY'),
      backendBaseUrl: const String.fromEnvironment('LOOP_BACKEND_BASE_URL'),
      firebaseConfigured: const bool.fromEnvironment('FIREBASE_CONFIGURED'),
      buildMode: expectedBuildMode,
      declaredModeMatchesRuntime: configuredBuildMode == expectedBuildMode,
    );
  }

  final String privyAppId;
  final String privyAppClientId;
  final String reownProjectId;
  final String streamApiKey;
  final String backendBaseUrl;
  final bool firebaseConfigured;
  final LoopBuildMode buildMode;

  /// False when a Debug/Profile binary declares Release, a Release binary
  /// declares Debug, or no configuration profile was supplied.
  ///
  /// Provider-backed capabilities use this as a global fail-closed gate. The
  /// offline Preview composition overrides [AppConfig] explicitly and does not
  /// depend on build-time values.
  final bool declaredModeMatchesRuntime;

  static const String privyOAuthScheme = 'com.cywd.loop.privy';
  static const String reownWalletScheme = 'com.cywd.loop.wallet';
  static const String reownMetadataUrl = 'https://quant-dinger.cc';
  static const String reownIconUrl =
      'https://placehold.co/512x512/111827/FFFFFF.png?text=LOOP';

  bool get hasPrivyAppId => privyAppId.trim().isNotEmpty;

  bool get hasPrivyAppClientId => privyAppClientId.trim().isNotEmpty;

  bool get canInitializePrivy =>
      declaredModeMatchesRuntime && hasPrivyAppId && hasPrivyAppClientId;

  bool get hasReownProjectId => reownProjectId.trim().isNotEmpty;

  bool get hasValidReownProjectId =>
      RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(reownProjectId.trim());

  bool get canConnectExternalWallet =>
      canInitializePrivy && hasValidReownProjectId;

  bool get hasStreamApiKey => streamApiKey.trim().isNotEmpty;

  bool get hasBackend => backendBaseUrl.trim().isNotEmpty;

  bool get canUseBackend => declaredModeMatchesRuntime && hasBackend;

  String get backendBaseUrlForCurrentBuild =>
      declaredModeMatchesRuntime ? backendBaseUrl.trim() : '';

  String get streamApiKeyForCurrentBuild =>
      declaredModeMatchesRuntime ? streamApiKey.trim() : '';

  bool get canConnectStream =>
      declaredModeMatchesRuntime && hasStreamApiKey && hasBackend;

  bool get canInitializeFirebase =>
      declaredModeMatchesRuntime && firebaseConfigured;

  static LoopBuildMode? _parseBuildMode(String value) {
    return switch (value.trim()) {
      'debug' => LoopBuildMode.debug,
      'release' => LoopBuildMode.release,
      _ => null,
    };
  }
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

/// Explicitly overridden only by the offline `main_preview.dart` entry point
/// and tests. Production composition must remain fail-closed.
final developmentPreviewEnabledProvider = Provider<bool>((ref) => false);
