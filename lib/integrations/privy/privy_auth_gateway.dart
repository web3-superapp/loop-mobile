import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
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
  });

  final String privyUserId;
  final String? email;
  final PrivyWalletSummary? wallet;

  PrivyAccountSummary copyWith({PrivyWalletSummary? wallet}) {
    return PrivyAccountSummary(
      privyUserId: privyUserId,
      email: email,
      wallet: wallet ?? this.wallet,
    );
  }
}

@immutable
class PrivySessionSnapshot {
  const PrivySessionSnapshot(this.kind, {this.account});

  final PrivySessionKind kind;
  final PrivyAccountSummary? account;
}

class PrivyGatewayException implements Exception {
  const PrivyGatewayException(this.userMessage);

  final String userMessage;

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

final privyAuthGatewayProvider = Provider<PrivyAuthGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.canInitializePrivy) {
    return const UnconfiguredPrivyAuthGateway();
  }
  return PrivySdkAuthGateway.create(config);
});

class UnconfiguredPrivyAuthGateway implements PrivyAuthGateway {
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
}

class PrivySdkAuthGateway implements PrivyAuthGateway {
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
  String? _walletCreationOwner;
  Future<PrivyWalletCreationResult>? _walletCreation;

  @override
  Future<PrivySessionSnapshot> restoreSession() async {
    try {
      return _mapAuthState(await _privy.getAuthState());
    } on PrivyException {
      throw const PrivyGatewayException('无法恢复登录状态，请检查网络后重试。');
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
    for (final account in user.linkedAccounts) {
      if (account is EmailAccount) {
        email = account.emailAddress;
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
    );
  }
}
