import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/privy/privy_device_signer.dart';
import 'package:loop_mobile/integrations/privy/privy_production_adapter.dart';
import 'package:privy_flutter/privy_flutter.dart';

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
const loopUndecidedSessionMessage = '暂时无法确认登录状态，请稍后重试。';

/// What Privy told us about a failure.
///
/// privy_flutter 0.10.1 carries no error code across the platform channel:
/// `PrivyException` has a single `message` field and
/// `ExceptionConversion.convertToPrivyException` keeps a `PlatformException`
/// code only for the four MFA cases. Classification is therefore a message
/// mapping, documented in decision 0064, and it is deliberately biased to
/// [network]: only an explicit authentication answer may be read as
/// "signed out".
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

/// Maps a privy_flutter 0.10.1 `PrivyException.message` onto a
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

  static const _message = 'Privy App Client ID 尚未配置，真实登录暂不可用。';

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
    throw const PrivyGatewayException(_message);
  }

  @override
  Future<String> getCurrentAccessToken() {
    throw const PrivyGatewayException(_message);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendEmailCode(String email) {
    throw const PrivyGatewayException(_message);
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) {
    throw const PrivyGatewayException(_message);
  }

  @override
  Future<String> generateSiweMessage(PrivySiweRequest request) {
    throw const PrivyGatewayException(_message);
  }

  @override
  Future<PrivyAccountSummary> linkWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
    required String expectedPrivyUserId,
  }) {
    throw const PrivyGatewayException(_message);
  }

  @override
  Future<PrivyAccountSummary> loginWithOAuth(PrivyOAuthLoginProvider provider) {
    throw const PrivyGatewayException(_message);
  }

  @override
  Future<PrivyAccountSummary> loginWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
  }) {
    throw const PrivyGatewayException(_message);
  }
}

class PrivySdkAuthGateway
    implements
        PrivyAuthGateway,
        PrivyCredentialGateway,
        PrivyDeviceSigningHost {
  PrivySdkAuthGateway._(this._privy);

  factory PrivySdkAuthGateway.create(AppConfig config) {
    if (!config.canInitializePrivy) {
      throw StateError('Privy requires both App ID and Mobile App Client ID.');
    }
    final privy = Privy.init(
      config: PrivyConfig(
        appId: config.privyAppId,
        appClientId: config.privyAppClientId,
        // Privy 0.10.1 may expose OTPs or access tokens at verbose levels.
        logLevel: PrivyLogLevel.none,
      ),
    );
    return PrivySdkAuthGateway._(privy);
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
        PrivyFailureKind.authentication => '登录状态已失效，请重新登录。',
        PrivyFailureKind.network => '暂时无法确认登录状态，请检查网络后重试。',
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
        throw const PrivyGatewayException('验证码发送失败，请稍后重试。');
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
        throw const PrivyGatewayException('验证码无效或已过期，请重新检查。');
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
      throw const PrivyGatewayException('登录未完成，请检查网络和回跳配置后重试。');
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
          throw const PrivyGatewayException('Privy 未返回可签名的登录消息，请重试。');
        case Failure<String>():
          throw const PrivyGatewayException('无法生成钱包登录消息，请检查网络后重试。');
      }
    } on PrivyGatewayException {
      rethrow;
    } catch (_) {
      throw const PrivyGatewayException('无法生成钱包登录消息，请检查网络后重试。');
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
      throw const PrivyGatewayException('钱包登录未完成，请检查网络后重试。');
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
      throw const PrivyGatewayException('账号已变化，钱包未绑定，请重新尝试。');
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
            throw const PrivyGatewayException('账号已变化，钱包未绑定，请重新尝试。');
          }
          _currentUser = linkedUser;
          return _summarize(linkedUser);
        case Failure<PrivyUser>(error: final error):
          throw PrivyGatewayException(_siweFailureMessage(error.message));
      }
    } on PrivyGatewayException {
      rethrow;
    } catch (_) {
      throw const PrivyGatewayException('钱包绑定未完成，请检查网络后重试。');
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
      throw const PrivyGatewayException('账号已变化，请重新检查钱包状态。');
    }

    final existingOperation = _walletCreation;
    if (existingOperation != null) {
      if (_walletCreationOwner != expectedPrivyUserId) {
        throw const PrivyGatewayException('上一账号的钱包操作仍在结束，请稍后重试。');
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
        throw const PrivyGatewayException('钱包创建状态未确认，请稍后刷新重试。');
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
      throw const PrivyGatewayException('请先完成 Privy 登录。');
    }
    final result = await user.getAccessToken();
    switch (result) {
      case Success<String>(value: final token):
        return token;
      case Failure<String>():
        throw const PrivyGatewayException('登录凭证已失效，请重新尝试。');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _privy.logout();
      _currentUser = null;
    } on PrivyException {
      throw const PrivyGatewayException('退出登录失败，请稍后重试。');
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
    if (normalized.contains('cancel')) return '已取消 $label 登录。';
    if (normalized.contains('network') ||
        normalized.contains('internet') ||
        normalized.contains('timed out') ||
        normalized.contains('timeout')) {
      return '$label 登录网络不可用，请稍后重试。';
    }
    if (normalized.contains('redirect') ||
        normalized.contains('callback') ||
        normalized.contains('scheme')) {
      return '$label 登录回跳失败，请检查应用配置后重试。';
    }
    return '$label 登录未完成，请重试。';
  }

  String _siweFailureMessage(String providerMessage) {
    final normalized = providerMessage.toLowerCase();
    if ((normalized.contains('already') || normalized.contains('linked')) &&
        (normalized.contains('user') || normalized.contains('account'))) {
      return '该钱包已属于另一个 Privy 账号，LOOP 不会自动转移或删除账号。';
    }
    if (normalized.contains('network') ||
        normalized.contains('internet') ||
        normalized.contains('timed out') ||
        normalized.contains('timeout')) {
      return '钱包凭据提交失败，请检查网络后重试。';
    }
    return 'Privy 未接受该钱包凭据；它可能已绑定其他账号。LOOP 不会自动转移或删除账号。';
  }

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
