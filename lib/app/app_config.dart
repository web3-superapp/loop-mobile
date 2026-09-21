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
    this.passkeyRelyingParty = '',
    required this.firebaseConfigured,
    this.loopClientVersion = '0.1.0+1',
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
      passkeyRelyingParty: const String.fromEnvironment(
        'LOOP_PASSKEY_RP_DOMAIN',
      ),
      firebaseConfigured: const bool.fromEnvironment('FIREBASE_CONFIGURED'),
      loopClientVersion: const String.fromEnvironment('LOOP_CLIENT_VERSION'),
      buildMode: expectedBuildMode,
      declaredModeMatchesRuntime: configuredBuildMode == expectedBuildMode,
    );
  }

  final String privyAppId;
  final String privyAppClientId;
  final String reownProjectId;
  final String streamApiKey;
  final String backendBaseUrl;

  /// The domain a passkey created by this build belongs to.
  ///
  /// A passkey is not the App's; it is the domain's. The platform will only
  /// create or use one when that domain publishes a credential that names
  /// this application — `/.well-known/assetlinks.json` on Android, the
  /// Apple App Site Association plus an `webcredentials:` entitlement on iOS
  /// — and when the same domain is registered at Privy as a relying party.
  /// Empty means this build has no such domain, and every passkey call is
  /// refused here rather than at the platform, which would only answer with
  /// an error nobody can act on.
  final String passkeyRelyingParty;

  final bool firebaseConfigured;
  final String loopClientVersion;
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

  /// A syntactically usable relying party: a bare registrable domain, never a
  /// URL, a port or a path. The platform rejects anything else, and a build
  /// that supplied one would fail on the device instead of here.
  bool get hasPasskeyRelyingParty => RegExp(
    r'^(?=.{1,253}$)(?!-)[A-Za-z0-9-]{1,63}(?<!-)'
    r'(?:\.(?!-)[A-Za-z0-9-]{1,63}(?<!-))+$',
  ).hasMatch(passkeyRelyingParty.trim());

  /// The relying party this build may actually use, or an empty string.
  ///
  /// A passkey belongs to the account at Privy, so it is only offered where
  /// the Privy SDK can be initialised at all.
  String get passkeyRelyingPartyForCurrentBuild =>
      canInitializePrivy && hasPasskeyRelyingParty
      ? passkeyRelyingParty.trim()
      : '';

  bool get canUsePasskey => passkeyRelyingPartyForCurrentBuild.isNotEmpty;

  bool get hasBackend => backendBaseUrl.trim().isNotEmpty;

  bool get canUseBackend => declaredModeMatchesRuntime && hasBackend;

  bool get hasValidLoopClientVersion {
    final value = loopClientVersion.trim();
    return value.length >= 5 &&
        value.length <= 64 &&
        RegExp(
          r'^(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
        ).hasMatch(value);
  }

  String get loopClientVersionForCurrentBuild =>
      declaredModeMatchesRuntime && hasValidLoopClientVersion
      ? loopClientVersion.trim()
      : '';

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
