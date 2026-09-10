import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

enum LoopSessionMode {
  restoring,

  /// Privy could not be reached, or failed for a reason it did not explain.
  /// The session is undecided: LOOP has no sign-out answer and must never
  /// show the credential form from here (decision 0064).
  restoreUnavailable,
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

  const LoopSessionState.restoreUnavailable({String? errorMessage})
    : this(
        mode: LoopSessionMode.restoreUnavailable,
        errorMessage: errorMessage,
      );

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

  /// The session is still undecided: Privy has not answered yet, or the
  /// answer could not be obtained. Neither variant is a sign-out.
  bool get isRestoring =>
      mode == LoopSessionMode.restoring ||
      mode == LoopSessionMode.restoreUnavailable;

  /// The undecided state that owes the owner an explanation and a retry.
  bool get isRestoreUnavailable => mode == LoopSessionMode.restoreUnavailable;

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
  Future<void>? _restoreOperation;
  var _localSignOutBarrier = false;

  @override
  LoopSessionState build() {
    final gateway = ref.watch(privyAuthGatewayProvider);
    _subscription?.cancel();
    _subscription = gateway.watchSession().listen(_receiveSnapshot);
    ref.onDispose(() => _subscription?.cancel());
    Future<void>.microtask(() => _startRestore(gateway));
    return const LoopSessionState.restoring();
  }

  /// Asks Privy again after a restore that could not be completed. Only the
  /// undecided state may retry, and only one restore runs at a time.
  Future<void> retryRestore() {
    final active = _restoreOperation;
    if (active != null) return active;
    if (!state.isRestoreUnavailable) return Future<void>.value();
    state = const LoopSessionState.restoring();
    return _startRestore(ref.read(privyAuthGatewayProvider));
  }

  Future<void> _startRestore(PrivyAuthGateway gateway) {
    final active = _restoreOperation;
    if (active != null) return active;
    late final Future<void> operation;
    operation = _restore(gateway).whenComplete(() {
      if (identical(_restoreOperation, operation)) _restoreOperation = null;
    });
    _restoreOperation = operation;
    return operation;
  }

  Future<void> _restore(PrivyAuthGateway gateway) async {
    try {
      final snapshot = await gateway.restoreSession();
      if (!ref.mounted) return;
      // Never let a stale unauthenticated restore overwrite a session that
      // completed while restoration was in flight.
      if (state.isRestoring ||
          snapshot.kind == PrivySessionKind.authenticated) {
        _receiveSnapshot(snapshot);
      }
    } on PrivyGatewayException catch (error) {
      _failRestore(error.kind, error.userMessage);
    } catch (_) {
      // An unclassified failure is not Privy answering that the credential is
      // gone. The session stays undecided rather than falling to the form.
      _failRestore(PrivyFailureKind.unknown, '暂时无法确认登录状态，请检查网络后重试。');
    }
  }

  void _failRestore(PrivyFailureKind kind, String message) {
    if (!ref.mounted || !state.isRestoring) return;
    // Only an explicit authentication answer signs the owner out. Network and
    // unclassified failures keep the session undecided so the credential form
    // never claims a sign-out Privy did not report.
    state = kind == PrivyFailureKind.authentication
        ? LoopSessionState.signedOut(errorMessage: message)
        : LoopSessionState.restoreUnavailable(errorMessage: message);
  }

  void _receiveSnapshot(PrivySessionSnapshot snapshot) {
    if (_localSignOutBarrier) return;
    if (state.mode == LoopSessionMode.preview &&
        snapshot.kind != PrivySessionKind.authenticated) {
      return;
    }
    state = switch (snapshot.kind) {
      // `notReady` is Privy still deciding; it must not drop the explanation
      // and the retry the undecided state is already showing.
      PrivySessionKind.notReady =>
        state.isRestoreUnavailable ? state : const LoopSessionState.restoring(),
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
