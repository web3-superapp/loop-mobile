import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

enum LoopSessionMode {
  restoring,
  signingOut,
  signedOut,
  preview,
  authenticatedUnverified,
  authenticated,
}

enum LoopBackendLogoutResult { notRequired, confirmed, unconfirmed }

typedef LoopBackendLogoutCallback = Future<LoopBackendLogoutResult> Function(
  String principalKey,
);

@immutable
class LoopSessionState {
  const LoopSessionState({required this.mode, this.account, this.errorMessage});

  const LoopSessionState.restoring() : this(mode: LoopSessionMode.restoring);

  const LoopSessionState.signingOut() : this(mode: LoopSessionMode.signingOut);

  const LoopSessionState.signedOut({String? errorMessage})
    : this(mode: LoopSessionMode.signedOut, errorMessage: errorMessage);

  const LoopSessionState.preview() : this(mode: LoopSessionMode.preview);

  final LoopSessionMode mode;
  final PrivyAccountSummary? account;
  final String? errorMessage;

  bool get canEnterProduct {
    return mode == LoopSessionMode.preview ||
        mode == LoopSessionMode.authenticated ||
        mode == LoopSessionMode.authenticatedUnverified;
  }

  bool get isPreview => mode == LoopSessionMode.preview;

  /// Provider-backed wallet, Stream bootstrap, and trading actions require a
  /// fully verified session. Cached unverified sessions remain visible but are
  /// deliberately restricted to offline/read-only product surfaces.
  bool get canUseProviderBackedFeatures =>
      mode == LoopSessionMode.authenticated;

  LoopSessionState copyWith({PrivyAccountSummary? account}) {
    return LoopSessionState(
      mode: mode,
      account: account ?? this.account,
      errorMessage: errorMessage,
    );
  }
}

class LoopSessionController extends Notifier<LoopSessionState> {
  StreamSubscription<PrivySessionSnapshot>? _subscription;
  Future<void>? _exitOperation;
  var _localSignOutBarrier = false;

  @override
  LoopSessionState build() {
    final gateway = ref.watch(privyAuthGatewayProvider);
    _subscription?.cancel();
    _subscription = gateway.watchSession().listen(_receiveSnapshot);
    ref.onDispose(() => _subscription?.cancel());
    Future<void>.microtask(() => _restore(gateway));
    return const LoopSessionState.restoring();
  }

  Future<void> _restore(PrivyAuthGateway gateway) async {
    try {
      final snapshot = await gateway.restoreSession();
      if (!ref.mounted) return;
      // Never let a stale unauthenticated restore overwrite a session that
      // completed while restoration was in flight.
      if (state.mode == LoopSessionMode.restoring ||
          snapshot.kind == PrivySessionKind.authenticated) {
        _receiveSnapshot(snapshot);
      }
    } on PrivyGatewayException catch (error) {
      if (!ref.mounted) return;
      if (state.mode == LoopSessionMode.restoring) {
        state = LoopSessionState.signedOut(errorMessage: error.userMessage);
      }
    }
  }

  void _receiveSnapshot(PrivySessionSnapshot snapshot) {
    if (_localSignOutBarrier) return;
    if (state.mode == LoopSessionMode.preview &&
        snapshot.kind != PrivySessionKind.authenticated) {
      return;
    }
    state = switch (snapshot.kind) {
      PrivySessionKind.notReady => const LoopSessionState.restoring(),
      PrivySessionKind.unauthenticated => const LoopSessionState.signedOut(),
      PrivySessionKind.authenticatedUnverified => const LoopSessionState(
        mode: LoopSessionMode.authenticatedUnverified,
      ),
      PrivySessionKind.authenticated => LoopSessionState(
        mode: LoopSessionMode.authenticated,
        account: snapshot.account,
      ),
    };
  }

  bool enterPreview() {
    if (_localSignOutBarrier || !ref.read(developmentPreviewEnabledProvider)) {
      return false;
    }
    state = const LoopSessionState.preview();
    return true;
  }

  void acceptAuthenticated(PrivyAccountSummary account) {
    if (_exitOperation != null || state.mode == LoopSessionMode.signingOut) {
      throw const PrivyGatewayException('正在退出登录，请完成后再试。');
    }
    _localSignOutBarrier = false;
    state = LoopSessionState(
      mode: LoopSessionMode.authenticated,
      account: account,
    );
  }

  void acceptLinkedAccount(
    PrivyAccountSummary account, {
    required String expectedPrivyUserId,
  }) {
    final current = state;
    final currentAccount = current.account;
    if (!current.canUseProviderBackedFeatures ||
        currentAccount == null ||
        expectedPrivyUserId.isEmpty ||
        currentAccount.privyUserId != expectedPrivyUserId ||
        account.privyUserId != expectedPrivyUserId) {
      throw const PrivyGatewayException('账号已变化，钱包未绑定，请重新尝试。');
    }
    state = LoopSessionState(
      mode: LoopSessionMode.authenticated,
      account: account,
    );
  }

  Future<void> createWallet() async {
    final requestedState = state;
    final requestedAccount = requestedState.account;
    if (!requestedState.canUseProviderBackedFeatures ||
        requestedAccount == null) {
      throw const PrivyGatewayException('开发预览或受限会话不会创建真实钱包。');
    }

    final gateway = ref.read(privyAuthGatewayProvider);
    final requestedPrincipal = requestedAccount.privyUserId;
    final requestedWalletAddress = requestedAccount.wallet?.address;
    final creation = await gateway.createFirstEthereumWallet(
      expectedPrivyUserId: requestedPrincipal,
    );
    if (!ref.mounted) return;

    final currentState = state;
    final currentAccount = currentState.account;
    final currentGateway = ref.read(privyAuthGatewayProvider);
    if (!currentState.canUseProviderBackedFeatures ||
        currentAccount == null ||
        currentAccount.privyUserId != requestedPrincipal ||
        creation.privyUserId != requestedPrincipal ||
        !identical(currentGateway, gateway)) {
      throw const PrivyGatewayException('账号已变化，请重新检查钱包状态。');
    }

    final wallet = creation.wallet;
    final currentWalletAddress = currentAccount.wallet?.address;
    if (currentWalletAddress != requestedWalletAddress) {
      if (currentWalletAddress == wallet.address) return;
      throw const PrivyGatewayException('钱包状态已变化，请重新检查后再继续。');
    }

    state = currentState.copyWith(
      account: currentAccount.copyWith(wallet: wallet),
    );
  }

  Future<void> exit({
    LoopBackendLogoutCallback? revokeBackend,
    Future<void> Function()? retireCommunications,
  }) {
    final activeOperation = _exitOperation;
    if (activeOperation != null) return activeOperation;

    final principalKey = state.account?.privyUserId;
    final gateway = ref.read(privyAuthGatewayProvider);
    final shouldLogout =
        state.mode == LoopSessionMode.authenticated ||
        state.mode == LoopSessionMode.authenticatedUnverified;
    _localSignOutBarrier = true;
    if (!shouldLogout) {
      state = const LoopSessionState.signedOut();
      return Future<void>.value();
    }
    state = const LoopSessionState.signingOut();

    late final Future<void> operation;
    operation =
        _completeExit(
          principalKey: principalKey,
          gateway: gateway,
          revokeBackend: revokeBackend,
          retireCommunications: retireCommunications,
        ).whenComplete(() {
          if (identical(_exitOperation, operation)) _exitOperation = null;
        });
    _exitOperation = operation;
    return operation;
  }

  Future<void> _completeExit({
    required String? principalKey,
    required PrivyAuthGateway gateway,
    required LoopBackendLogoutCallback? revokeBackend,
    required Future<void> Function()? retireCommunications,
  }) async {
    var backendResult = LoopBackendLogoutResult.notRequired;
    if (revokeBackend != null && principalKey != null) {
      try {
        backendResult = await revokeBackend(principalKey);
      } catch (_) {
        backendResult = LoopBackendLogoutResult.unconfirmed;
      }
    }
    if (retireCommunications != null) {
      try {
        await retireCommunications().timeout(const Duration(seconds: 5));
      } catch (_) {
        // Provider authorization was already revoked synchronously. A stuck
        // transport cleanup cannot trap local or Privy logout.
      }
    }

    String? errorMessage;
    try {
      await gateway.logout();
      if (backendResult == LoopBackendLogoutResult.unconfirmed) {
        errorMessage = '本地会话已退出，但 LOOP 后端会话撤销尚未确认。';
      }
    } on PrivyGatewayException catch (error) {
      errorMessage = error.userMessage;
    } catch (_) {
      errorMessage = '本地会话已退出，但 Privy 远端退出尚未确认。';
    }
    if (ref.mounted &&
        _localSignOutBarrier &&
        state.mode == LoopSessionMode.signingOut) {
      state = LoopSessionState.signedOut(errorMessage: errorMessage);
    }
  }
}

final loopSessionProvider =
    NotifierProvider<LoopSessionController, LoopSessionState>(
      LoopSessionController.new,
    );
