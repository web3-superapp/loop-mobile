import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/privy_production_adapter.dart';
import 'package:loop_mobile/integrations/privy/privy_mfa_gateway.dart';
import 'package:privy_flutter/privy_flutter.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';

enum PrivySessionKind {
  notReady,
  unauthenticated,
  authenticatedUnverified,
  authenticated,
}

@immutable
class PrivyWalletSummary {
  const PrivyWalletSummary({required this.address});

  final String address;
}

@immutable
class PrivyExternalEvmCredentialSummary {
  const PrivyExternalEvmCredentialSummary({
    required this.address,
    this.chainId,
    this.walletClientType,
  });

  final String address;
  final String? chainId;
  final String? walletClientType;
}

@immutable
class PrivyWalletCreationResult {
  const PrivyWalletCreationResult({
    required this.privyUserId,
    required this.wallet,
  });

  final String privyUserId;
  final PrivyWalletSummary wallet;
}

@immutable
class PrivyAccountSummary {
  const PrivyAccountSummary({
    required this.privyUserId,
    this.email,
    this.wallet,
    this.hasGoogle = false,
    this.hasApple = false,
    this.externalEvmCredentials = const <PrivyExternalEvmCredentialSummary>[],
  });

  final String privyUserId;
  final String? email;
  final PrivyWalletSummary? wallet;
  final bool hasGoogle;
  final bool hasApple;
  final List<PrivyExternalEvmCredentialSummary> externalEvmCredentials;

  PrivyAccountSummary copyWith({PrivyWalletSummary? wallet}) {
    return PrivyAccountSummary(
      privyUserId: privyUserId,
      email: email,
      wallet: wallet ?? this.wallet,
      hasGoogle: hasGoogle,
      hasApple: hasApple,
      externalEvmCredentials: externalEvmCredentials,
    );
  }
}

enum PrivyOAuthLoginProvider { google, apple }

@immutable
class PrivySiweRequest {
  const PrivySiweRequest({
    required this.appDomain,
    required this.appUri,
    required this.chainId,
    required this.walletAddress,
    required this.walletClientType,
  });

  final String appDomain;
  final String appUri;
  final String chainId;
  final String walletAddress;
  final String walletClientType;
}

@immutable
class PrivySessionSnapshot {
  const PrivySessionSnapshot(this.kind, {this.account});

  final PrivySessionKind kind;
  final PrivyAccountSummary? account;
}

/// The copy for "LOOP has no answer about this session yet".
///
/// It deliberately names no cause: the failure may be the radio, the provider,
/// or something neither side explained, and asserting a network problem the
/// device has not observed would be a claim rather than a fact.
String get loopUndecidedSessionMessage =>
    LoopL10n.current.integrations_privyAuthGatewayLoopUndecidedSessionMessage;

/// What LOOP says when Privy refuses to link a wallet that already belongs to
/// another account (S306 ruling 3: accounts are never merged).
String get externalWalletLinkedElsewhereMessage => LoopL10n
    .current
    .integrations_privyAuthGatewayExternalWalletLinkedElsewhereMessage;

/// What Privy told us about a failure.
///
/// privy_flutter 0.10.1 carried no error code across the platform channel:
/// `PrivyException` had a single `message` field. 0.11.0 adds typed
/// subclasses (`PrivyAuthException`, `PrivyWalletException`,
/// `PrivyTimeoutException`) keyed on the native code, but its `flow`/`stage`
/// still say nothing about whether the credential was rejected or the device
/// was offline, and the native `message` is passed through unchanged.
/// Classification therefore stays a message mapping, documented in decisions
/// 0064 and 0134, and it is deliberately biased to [network]: only an explicit
/// authentication answer may be read as "signed out".
enum PrivyFailureKind {
  /// The device could not reach Privy. The session state stays undecided.
  network,

  /// Privy answered about the credential itself: it is absent or rejected.
  authentication,

  /// Privy failed for a reason we cannot classify. Treated exactly like
  /// [network] by every caller, because an unclassified failure is not an
  /// answer about the credential.
  unknown,
}

/// Maps a privy_flutter 0.11.0 `PrivyException.message` onto a
/// [PrivyFailureKind]. Network markers are tested first: when a message
/// mentions both a transport and a credential, the transport explains it and
/// LOOP must not read it as a sign-out.
abstract final class PrivyFailureClassifier {
  static const networkMarkers = <String>[
    'network',
    'internet',
    'offline',
    'connection',
    'connect',
    'timed out',
    'timeout',
    'unreachable',
    'unavailable',
    'socket',
    'hostname',
    'dns',
    'ssl',
    'tls',
    'certificate',
  ];

  /// Credential markers, matched on word boundaries.
  ///
  /// A bare substring test would read `401` out of a request id such as
  /// `14013` and `no user` out of `no users found`, and an accidental match
  /// here signs the owner out. Every marker therefore has to stand as its own
  /// word or phrase.
  static const authenticationMarkers = <String>[
    'unauthenticated',
    'not authenticated',
    'unauthorized',
    'no user',
    'no authenticated user',
    'no active session',
    'not logged in',
    'logged out',
    'session expired',
    'token expired',
    'expired token',
    'invalid token',
    'invalid credential',
    'invalid refresh',
    '401',
    '403',
  ];

  static final _authenticationPatterns = <RegExp>[
    for (final marker in authenticationMarkers)
      RegExp('\\b${RegExp.escape(marker)}\\b'),
  ];

  static PrivyFailureKind of(String message) {
    final normalized = message.toLowerCase();
    for (final marker in networkMarkers) {
      if (normalized.contains(marker)) return PrivyFailureKind.network;
    }
    for (final pattern in _authenticationPatterns) {
      if (pattern.hasMatch(normalized)) return PrivyFailureKind.authentication;
    }
    return PrivyFailureKind.unknown;
  }
}

class PrivyGatewayException implements Exception {
  const PrivyGatewayException(
    this.userMessage, {
    this.kind = PrivyFailureKind.unknown,
  });

  final String userMessage;

  /// Why the call failed. Only [PrivyFailureKind.authentication] is Privy
  /// answering that the credential is gone.
  final PrivyFailureKind kind;

  @override
  String toString() => userMessage;
}

abstract interface class PrivyAuthGateway {
  Future<PrivySessionSnapshot> restoreSession();

  Stream<PrivySessionSnapshot> watchSession();

  Future<void> sendEmailCode(String email);

  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  });

  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  });

  /// Returns the SDK's current short-lived access token for immediate backend
  /// use. The gateway never reads, stores, or refreshes a Privy refresh token.
  Future<String> getCurrentAccessToken();

  Future<void> logout();
}

/// Interactive credential operations that reuse the same [Privy] owner as
/// [PrivyAuthGateway]. Kept separate so provider SDK types and new methods do
/// not spread into existing session and wallet test doubles.
abstract interface class PrivyCredentialGateway {
  Future<PrivyAccountSummary> loginWithOAuth(PrivyOAuthLoginProvider provider);

  Future<String> generateSiweMessage(PrivySiweRequest request);

  Future<PrivyAccountSummary> loginWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
  });

  Future<PrivyAccountSummary> linkWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
    required String expectedPrivyUserId,
  });

  /// Removes one external EVM wallet credential from the current Privy
  /// account (S306, decision 0246). [address] is the wallet's own address;
  /// [expectedPrivyUserId] pins the account the request was made for, so a
  /// session that changed underneath the page unlinks nothing.
  Future<PrivyAccountSummary> unlinkSiwe({
    required String address,
    required String expectedPrivyUserId,
  });
}

final privyAuthGatewayProvider = Provider<PrivyAuthGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.canInitializePrivy) {
    return const UnconfiguredPrivyAuthGateway();
  }
  return PrivySdkAuthGateway.create(config);
});

final privyCredentialGatewayProvider = Provider<PrivyCredentialGateway>((ref) {
  final gateway = ref.watch(privyAuthGatewayProvider);
  if (gateway is PrivyCredentialGateway) {
    return gateway as PrivyCredentialGateway;
  }
  return const UnconfiguredPrivyAuthGateway();
});

class UnconfiguredPrivyAuthGateway
    implements PrivyAuthGateway, PrivyCredentialGateway {
  const UnconfiguredPrivyAuthGateway();

  static String get _message =>
      LoopL10n.current.integrations_privyAuthGatewayMessage;

  @override
  Future<PrivySessionSnapshot> restoreSession() async {
    return const PrivySessionSnapshot(PrivySessionKind.unauthenticated);
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() => const Stream.empty();

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) {
    throw PrivyGatewayException(_message);
  }

  @override
  Future<String> getCurrentAccessToken() {
    throw PrivyGatewayException(_message);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendEmailCode(String email) {
    throw PrivyGatewayException(_message);
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) {
    throw PrivyGatewayException(_message);
  }

  @override
  Future<String> generateSiweMessage(PrivySiweRequest request) {
    throw PrivyGatewayException(_message);
  }

  @override
  Future<PrivyAccountSummary> linkWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
    required String expectedPrivyUserId,
  }) {
    throw PrivyGatewayException(_message);
  }

  @override
  Future<PrivyAccountSummary> loginWithOAuth(PrivyOAuthLoginProvider provider) {
    throw PrivyGatewayException(_message);
  }

  @override
  Future<PrivyAccountSummary> unlinkSiwe({
    required String address,
    required String expectedPrivyUserId,
  }) {
    throw PrivyGatewayException(_message);
  }

  @override
  Future<PrivyAccountSummary> loginWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
  }) {
    throw PrivyGatewayException(_message);
  }
}

class PrivySdkAuthGateway
    with PrivySdkMfaAccount
    implements
        PrivyAuthGateway,
        PrivyCredentialGateway,
        PrivyDeviceSigningHost,
        PrivyMfaAccountGateway {
  PrivySdkAuthGateway._(this._privy);

  /// The account the second factor belongs to. It is the same `PrivyUser` the
  /// session reports, so MFA can never be read for an owner who has been
  /// signed out.
  @override
  PrivyUser? get mfaUser => _currentUser;

  /// Passkey linking is a login-method operation and lives on the SDK
  /// instance rather than on the user, so the MFA mixin is given the same
  /// instance the session was opened with.
  @override
  Privy get mfaPrivy => _privy;

  factory PrivySdkAuthGateway.create(AppConfig config) {
    if (!config.canInitializePrivy) {
      throw StateError('Privy requires both App ID and Mobile App Client ID.');
    }
    final privy = Privy.init(
      config: PrivyConfig(
        appId: config.privyAppId,
        appClientId: config.privyAppClientId,
        // Privy 0.11.0 may expose OTPs or access tokens at verbose levels.
        logLevel: PrivyLogLevel.none,
      ),
    );
    final gateway = PrivySdkAuthGateway._(privy);
    // An account that enrolled MFA can have a wallet operation blocked by it.
    // Without a listener the SDK holds that operation for five minutes and
    // then fails it; with this one it fails at once, with a sentence.
    unawaited(
      privy.mfa.setConfig(MfaConfig(listener: LoopReleasingMfaListener(privy))),
    );
    return gateway;
  }

  final Privy _privy;
  PrivyUser? _currentUser;

  /// The device signer bound to the session Privy currently reports. It is
  /// rebuilt on every read so a logout or a session change can never leave a
  /// stale wallet able to sign.
  @override
  PrivyDeviceSigner get deviceSigner => SdkPrivyDeviceSigner(_currentUser);
  String? _walletCreationOwner;
  Future<PrivyWalletCreationResult>? _walletCreation;

  @override
  Future<PrivySessionSnapshot> restoreSession() async {
    try {
      return _mapAuthState(await _privy.getAuthState());
    } on PrivyException catch (error) {
      final kind = PrivyFailureClassifier.of(error.message);
      throw PrivyGatewayException(switch (kind) {
        PrivyFailureKind.authentication =>
          LoopL10n.current.integrations_privyAuthGatewayAuthentication,
        PrivyFailureKind.network =>
          LoopL10n.current.integrations_privyAuthGatewayNetwork,
        // An unclassified failure names no cause, so the copy claims none.
        PrivyFailureKind.unknown => loopUndecidedSessionMessage,
      }, kind: kind);
    }
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() {
    return _privy.authStateStream.map(_mapAuthState);
  }

  @override
  Future<void> sendEmailCode(String email) async {
    final result = await _privy.email.sendCode(email);
    switch (result) {
      case Success<void>():
        return;
      case Failure<void>():
        throw PrivyGatewayException(
          LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException,
        );
    }
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    final result = await _privy.email.loginWithCode(code: code, email: email);
    switch (result) {
      case Success<PrivyUser>(value: final user):
        _currentUser = user;
        return _summarize(user);
      case Failure<PrivyUser>():
        throw PrivyGatewayException(
          LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException2,
        );
    }
  }

  @override
  Future<PrivyAccountSummary> loginWithOAuth(
    PrivyOAuthLoginProvider provider,
  ) async {
    final sdkProvider = switch (provider) {
      PrivyOAuthLoginProvider.google => OAuthProvider.google,
      PrivyOAuthLoginProvider.apple => OAuthProvider.apple,
    };
    try {
      final result = await _privy.oAuth.login(
        provider: sdkProvider,
        appUrlScheme: AppConfig.privyOAuthScheme,
      );
      switch (result) {
        case Success<PrivyUser>(value: final user):
          _currentUser = user;
          return _summarize(user);
        case Failure<PrivyUser>(error: final error):
          throw PrivyGatewayException(
            _oauthFailureMessage(provider, error.message),
          );
      }
    } on PrivyGatewayException {
      rethrow;
    } catch (_) {
      throw PrivyGatewayException(
        LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException3,
      );
    }
  }

  @override
  Future<String> generateSiweMessage(PrivySiweRequest request) async {
    final params = _siweParams(request);
    try {
      final result = await _privy.siwe.generateMessage(params);
      switch (result) {
        case Success<String>(value: final message)
            when message.trim().isNotEmpty:
          return message;
        case Success<String>():
          throw PrivyGatewayException(
            LoopL10n
                .current
                .integrations_privyAuthGatewayPrivyGatewayException4,
          );
        case Failure<String>():
          throw PrivyGatewayException(
            LoopL10n
                .current
                .integrations_privyAuthGatewayPrivyGatewayException5,
          );
      }
    } on PrivyGatewayException {
      rethrow;
    } catch (_) {
      throw PrivyGatewayException(
        LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException5,
      );
    }
  }

  @override
  Future<PrivyAccountSummary> loginWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
  }) async {
    try {
      final result = await _privy.siwe.login(
        message: message,
        signature: signature,
        params: _siweParams(request),
        metadata: _siweMetadata(request.walletClientType),
      );
      switch (result) {
        case Success<PrivyUser>(value: final user):
          _currentUser = user;
          return _summarize(user);
        case Failure<PrivyUser>(error: final error):
          throw PrivyGatewayException(_siweFailureMessage(error.message));
      }
    } on PrivyGatewayException {
      rethrow;
    } catch (_) {
      throw PrivyGatewayException(
        LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException6,
      );
    }
  }

  @override
  Future<PrivyAccountSummary> linkWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
    required String expectedPrivyUserId,
  }) async {
    final user = _currentUser;
    if (user == null ||
        expectedPrivyUserId.isEmpty ||
        expectedPrivyUserId != expectedPrivyUserId.trim() ||
        user.id != expectedPrivyUserId) {
      throw PrivyGatewayException(
        LoopL10n.current.app_sessionControllerPrivyGatewayException2,
      );
    }
    try {
      final result = await _privy.siwe.link(
        message: message,
        signature: signature,
        params: _siweParams(request),
        metadata: _siweMetadata(request.walletClientType),
      );
      switch (result) {
        case Success<PrivyUser>(value: final linkedUser):
          if (linkedUser.id != expectedPrivyUserId) {
            throw PrivyGatewayException(
              LoopL10n.current.app_sessionControllerPrivyGatewayException2,
            );
          }
          _currentUser = linkedUser;
          return _summarize(linkedUser);
        case Failure<PrivyUser>(error: final error):
          throw PrivyGatewayException(siweLinkFailureMessage(error.message));
      }
    } on PrivyGatewayException {
      rethrow;
    } catch (_) {
      throw PrivyGatewayException(
        LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException8,
      );
    }
  }

  @override
  Future<PrivyAccountSummary> unlinkSiwe({
    required String address,
    required String expectedPrivyUserId,
  }) async {
    final user = _currentUser;
    if (user == null ||
        expectedPrivyUserId.isEmpty ||
        expectedPrivyUserId != expectedPrivyUserId.trim() ||
        user.id != expectedPrivyUserId) {
      throw PrivyGatewayException(
        LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException9,
      );
    }
    if (!_isEthereumAddress(address)) {
      throw PrivyGatewayException(
        LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException10,
      );
    }
    try {
      final result = await _privy.siwe.unlink(address: address);
      switch (result) {
        case Success<PrivyUser>(value: final updatedUser):
          if (updatedUser.id != expectedPrivyUserId) {
            throw PrivyGatewayException(
              LoopL10n
                  .current
                  .integrations_privyAuthGatewayPrivyGatewayException11,
            );
          }
          _currentUser = updatedUser;
          return _summarize(updatedUser);
        case Failure<PrivyUser>(error: final error):
          throw PrivyGatewayException(siweUnlinkFailureMessage(error.message));
      }
    } on PrivyGatewayException {
      rethrow;
    } catch (_) {
      throw PrivyGatewayException(
        LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException12,
      );
    }
  }

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) async {
    final user = _currentUser;
    if (user == null ||
        expectedPrivyUserId.isEmpty ||
        expectedPrivyUserId != expectedPrivyUserId.trim() ||
        user.id != expectedPrivyUserId) {
      throw PrivyGatewayException(
        LoopL10n.current.app_sessionControllerPrivyGatewayException4,
      );
    }

    final existingOperation = _walletCreation;
    if (existingOperation != null) {
      if (_walletCreationOwner != expectedPrivyUserId) {
        throw PrivyGatewayException(
          LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException14,
        );
      }
      return existingOperation;
    }

    final operation = _createFirstEthereumWallet(user);
    _walletCreationOwner = expectedPrivyUserId;
    _walletCreation = operation;
    try {
      return await operation;
    } finally {
      if (identical(_walletCreation, operation)) {
        _walletCreation = null;
        _walletCreationOwner = null;
      }
    }
  }

  Future<PrivyWalletCreationResult> _createFirstEthereumWallet(
    PrivyUser user,
  ) async {
    final existing = user.embeddedEthereumWallets;
    if (existing.isNotEmpty) {
      return _walletCreationResult(user, existing.first.address);
    }

    await user.refresh();
    final refreshed = user.embeddedEthereumWallets;
    if (refreshed.isNotEmpty) {
      return _walletCreationResult(user, refreshed.first.address);
    }

    final result = await user.createEthereumWallet(allowAdditional: false);
    switch (result) {
      case Success<EmbeddedEthereumWallet>(value: final wallet):
        return _walletCreationResult(user, wallet.address);
      case Failure<EmbeddedEthereumWallet>():
        // Creation may have succeeded remotely even when the response was
        // ambiguous. Reconcile once before allowing a future retry.
        await user.refresh();
        final reconciled = user.embeddedEthereumWallets;
        if (reconciled.isNotEmpty) {
          return _walletCreationResult(user, reconciled.first.address);
        }
        throw PrivyGatewayException(
          LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException15,
        );
    }
  }

  PrivyWalletCreationResult _walletCreationResult(
    PrivyUser user,
    String address,
  ) => PrivyWalletCreationResult(
    privyUserId: user.id,
    wallet: PrivyWalletSummary(address: address),
  );

  @override
  Future<String> getCurrentAccessToken() async {
    final user = _currentUser;
    if (user == null) {
      throw PrivyGatewayException(
        LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException16,
      );
    }
    final result = await user.getAccessToken();
    switch (result) {
      case Success<String>(value: final token):
        return token;
      case Failure<String>(error: final error):
        // Decision 0123: a token refresh that could not reach Privy is the
        // network, not a credential answer; the caller says 离线.
        if (PrivyFailureClassifier.of(error.message) ==
            PrivyFailureKind.network) {
          throw PrivyGatewayException(
            LoopL10n
                .current
                .integrations_privyAuthGatewayPrivyGatewayException17,
            kind: PrivyFailureKind.network,
          );
        }
        throw PrivyGatewayException(
          LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException18,
        );
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _privy.logout();
      _currentUser = null;
    } on PrivyException {
      throw PrivyGatewayException(
        LoopL10n.current.integrations_privyAuthGatewayPrivyGatewayException19,
      );
    }
  }

  PrivySessionSnapshot _mapAuthState(AuthState state) {
    return switch (state) {
      NotReady() => const PrivySessionSnapshot(PrivySessionKind.notReady),
      Unauthenticated() => _clearCurrentUser(PrivySessionKind.unauthenticated),
      AuthenticatedUnverified() => _clearCurrentUser(
        PrivySessionKind.authenticatedUnverified,
      ),
      Authenticated(user: final user) => _authenticatedSnapshot(user),
    };
  }

  PrivySessionSnapshot _clearCurrentUser(PrivySessionKind kind) {
    _currentUser = null;
    return PrivySessionSnapshot(kind);
  }

  PrivySessionSnapshot _authenticatedSnapshot(PrivyUser user) {
    _currentUser = user;
    return PrivySessionSnapshot(
      PrivySessionKind.authenticated,
      account: _summarize(user),
    );
  }

  PrivyAccountSummary _summarize(PrivyUser user) {
    String? email;
    var hasGoogle = false;
    var hasApple = false;
    final externalEvmCredentials = <PrivyExternalEvmCredentialSummary>[];
    for (final account in user.linkedAccounts) {
      switch (account) {
        case EmailAccount():
          email ??= account.emailAddress;
        case GoogleOAuthAccount():
          hasGoogle = true;
          email ??= account.email;
        case AppleOAuthAccount():
          hasApple = true;
          email ??= account.email;
        case ExternalWalletAccount()
            when account.chainType.toJson() == 'ethereum' &&
                _isEthereumAddress(account.address):
          externalEvmCredentials.add(
            PrivyExternalEvmCredentialSummary(
              address: account.address,
              chainId: _safeChainId(account.chainId),
              walletClientType: _safeWalletClientType(account.walletClientType),
            ),
          );
        default:
          break;
      }
    }
    final wallets = user.embeddedEthereumWallets;
    return PrivyAccountSummary(
      privyUserId: user.id,
      email: email,
      wallet: wallets.isEmpty
          ? null
          : PrivyWalletSummary(address: wallets.first.address),
      hasGoogle: hasGoogle,
      hasApple: hasApple,
      externalEvmCredentials: List.unmodifiable(externalEvmCredentials),
    );
  }

  SiweMessageParams _siweParams(PrivySiweRequest request) => SiweMessageParams(
    appDomain: request.appDomain,
    appUri: request.appUri,
    chainId: request.chainId,
    walletAddress: request.walletAddress,
  );

  WalletLoginMetadata _siweMetadata(String walletClientType) =>
      WalletLoginMetadata(
        walletClientType: WalletClientType.fromString(walletClientType),
        connectorType: 'wallet_connect',
      );

  String _oauthFailureMessage(
    PrivyOAuthLoginProvider provider,
    String providerMessage,
  ) {
    final label = provider == PrivyOAuthLoginProvider.google
        ? 'Google'
        : 'Apple';
    final normalized = providerMessage.toLowerCase();
    if (normalized.contains('cancel')) {
      return LoopL10n.current.integrations_privyAuthGatewayOauthFailureMessage(
        label,
      );
    }
    if (normalized.contains('network') ||
        normalized.contains('internet') ||
        normalized.contains('timed out') ||
        normalized.contains('timeout')) {
      return LoopL10n.current.integrations_privyAuthGatewayOauthFailureMessage2(
        label,
      );
    }
    if (normalized.contains('redirect') ||
        normalized.contains('callback') ||
        normalized.contains('scheme')) {
      return LoopL10n.current.integrations_privyAuthGatewayOauthFailureMessage3(
        label,
      );
    }
    return LoopL10n.current.integrations_privyAuthGatewayOauthFailureMessage4(
      label,
    );
  }

  String _siweFailureMessage(String providerMessage) {
    final normalized = providerMessage.toLowerCase();
    if ((normalized.contains('already') || normalized.contains('linked')) &&
        (normalized.contains('user') || normalized.contains('account'))) {
      return LoopL10n.current.integrations_privyAuthGatewaySiweFailureMessage;
    }
    if (normalized.contains('network') ||
        normalized.contains('internet') ||
        normalized.contains('timed out') ||
        normalized.contains('timeout')) {
      return LoopL10n.current.integrations_privyAuthGatewaySiweFailureMessage2;
    }
    return LoopL10n.current.integrations_privyAuthGatewaySiweFailureMessage3;
  }

  /// The sentence a refused `siwe.link` becomes (S306, decision 0246).
  ///
  /// privy_flutter 0.11.0 reports it as `PrivyAuthException` with flow
  /// `siwe` / stage `link` (platform code `SIWE_LINK_ERROR`); the native
  /// message is Privy's own and passes through unchanged, so the wallet
  /// already belonging to another account is recognised from that message.
  @visibleForTesting
  static String siweLinkFailureMessage(String providerMessage) {
    if (isLinkedToAnotherAccount(providerMessage)) {
      return externalWalletLinkedElsewhereMessage;
    }
    if (_mentionsNetwork(providerMessage.toLowerCase())) {
      return LoopL10n.current.integrations_privyAuthGatewaySiweFailureMessage2;
    }
    return LoopL10n.current.integrations_privyAuthGatewaySiweLinkFailureMessage;
  }

  /// The sentence a refused `siwe.unlink` becomes (platform code
  /// `UNLINK_ERROR`, flow `unknown` / stage `unlink`).
  @visibleForTesting
  static String siweUnlinkFailureMessage(String providerMessage) {
    final normalized = providerMessage.toLowerCase();
    if (_mentionsNetwork(normalized)) {
      return LoopL10n
          .current
          .integrations_privyAuthGatewayPrivyGatewayException12;
    }
    if (normalized.contains('last') ||
        normalized.contains('at least one') ||
        normalized.contains('only login') ||
        normalized.contains('only linked')) {
      return LoopL10n
          .current
          .integrations_privyAuthGatewaySiweUnlinkFailureMessage;
    }
    return LoopL10n
        .current
        .integrations_privyAuthGatewaySiweUnlinkFailureMessage2;
  }

  /// Whether Privy's message says the wallet already belongs to another
  /// user. Privy's API names this `linked_to_another_user`; its messages read
  /// "… already linked to another user", "… already been linked …" or
  /// "… already exists".
  @visibleForTesting
  static bool isLinkedToAnotherAccount(String providerMessage) {
    final normalized = providerMessage.toLowerCase();
    if (normalized.contains('linked_to_another_user') ||
        normalized.contains('another user') ||
        normalized.contains('another account')) {
      return true;
    }
    return normalized.contains('already') &&
        (normalized.contains('linked') ||
            normalized.contains('exists') ||
            normalized.contains('associated') ||
            normalized.contains('user') ||
            normalized.contains('account'));
  }

  static bool _mentionsNetwork(String normalized) =>
      normalized.contains('network') ||
      normalized.contains('internet') ||
      normalized.contains('timed out') ||
      normalized.contains('timeout');

  bool _isEthereumAddress(String value) =>
      RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(value);

  String? _safeChainId(String? value) {
    if (value == null || !RegExp(r'^[1-9][0-9]*$').hasMatch(value)) return null;
    return value;
  }

  String? _safeWalletClientType(String? value) {
    if (value == null || !RegExp(r'^[a-zA-Z0-9_-]{1,40}$').hasMatch(value)) {
      return null;
    }
    return value;
  }
}
