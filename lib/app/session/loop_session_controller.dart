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

/// How long a restore may stay silent before the owner is told that LOOP has
/// no answer yet. Overridable so tests can shorten it.
///
/// The window exists because `Privy.getAuthState()` can simply never complete:
/// on iOS the native SDK awaits readiness and reports no transport failure at
/// all, so a dead link produces a pending Future rather than a
/// `PrivyException`. Without a deadline the owner would watch the launch frame
/// forever with nothing to press.
final loopSessionRestoreWindowProvider = Provider<Duration>(
  (ref) => LoopSessionController.defaultRestoreWindow,
);

/// How long a cold start holds an `unauthenticated` answer before it is
/// allowed to become a sign-out. Overridable so tests can shorten it.
///
/// privy_flutter 0.10.1 restores a session in two steps, and the first step is
/// not the answer: `AuthStateManager.authStateStream` is a
/// `BehaviorSubject.seeded(NotReady())` fed by the native EventChannel, and the
/// native side may publish `Unauthenticated` before it has finished reading the
/// stored credential and publish `Authenticated` a moment later.
/// `Privy.getAuthState()` reads the same manager, so it can return that same
/// premature `Unauthenticated` too. Signing the owner out on the first one is
/// what put the credential form on screen during a cold start that was, in
/// fact, already logged in (decision 0064 §5).
final loopSessionUnauthenticatedGraceProvider = Provider<Duration>(
  (ref) => LoopSessionController.defaultUnauthenticatedGrace,
);

class LoopSessionController extends Notifier<LoopSessionState> {
  static const defaultRestoreWindow = Duration(seconds: 12);
  static const defaultUnauthenticatedGrace = Duration(milliseconds: 2500);

  StreamSubscription<PrivySessionSnapshot>? _subscription;
  Future<void>? _exitOperation;
  Future<void>? _restoreOperation;
  Timer? _restoreDeadline;
  Timer? _unauthenticatedGrace;
  var _restoreGeneration = 0;
  var _localSignOutBarrier = false;

  /// The cold-start grace is offered once. After it is spent, every
  /// `unauthenticated` answer is taken at face value again.
  var _unauthenticatedGraceSpent = false;

  @override
  LoopSessionState build() {
    final gateway = ref.watch(privyAuthGatewayProvider);
    _subscription?.cancel();
    _subscription = gateway.watchSession().listen(_receiveSnapshot);
    // The deadline belongs to `restoring` and to nothing else: the moment the
    // session reaches any other state - including the undecided third one -
    // it is retired, so no timer outlives the wait it was measuring.
    listenSelf((previous, next) {
      if (next.mode == LoopSessionMode.restoring) return;
      _cancelRestoreDeadline();
      _cancelUnauthenticatedGrace();
    });
    ref.onDispose(() {
      _subscription?.cancel();
      _cancelRestoreDeadline();
      _cancelUnauthenticatedGrace();
    });
    Future<void>.microtask(() => _startRestore(gateway));
    return const LoopSessionState.restoring();
  }

  /// Asks Privy again after a restore that could not be completed.
  ///
  /// Only the undecided state may retry. A restore abandoned by the deadline
  /// no longer owns `_restoreOperation`, so this really does issue a second
  /// `getAuthState` instead of handing back the Future that never answered.
  Future<void> retryRestore() {
    if (!state.isRestoreUnavailable) return Future<void>.value();
    // A retry is not a cold start. The owner pressed 重试 and is owed Privy's
    // answer as it stands, so the grace window is not offered a second time.
    _unauthenticatedGraceSpent = true;
    state = const LoopSessionState.restoring();
    return _startRestore(ref.read(privyAuthGatewayProvider));
  }

  Future<void> _startRestore(PrivyAuthGateway gateway) {
    final active = _restoreOperation;
    if (active != null) return active;
    final generation = ++_restoreGeneration;
    late final Future<void> operation;
    operation = _restore(gateway, generation).whenComplete(() {
      if (identical(_restoreOperation, operation)) _restoreOperation = null;
    });
    _restoreOperation = operation;
    _armRestoreDeadline(generation);
    return operation;
  }

  void _armRestoreDeadline(int generation) {
    if (state.mode != LoopSessionMode.restoring) return;
    _cancelRestoreDeadline();
    _restoreDeadline = Timer(
      ref.read(loopSessionRestoreWindowProvider),
      () => _restoreDeadlineExpired(generation),
    );
  }

  void _cancelRestoreDeadline() {
    _restoreDeadline?.cancel();
    _restoreDeadline = null;
  }

  void _restoreDeadlineExpired(int generation) {
    _restoreDeadline = null;
    if (!ref.mounted ||
        generation != _restoreGeneration ||
        state.mode != LoopSessionMode.restoring) {
      return;
    }
    // The call in flight is deliberately not cancelled. It may still answer,
    // and `_restore` publishes that answer because `isRestoring` covers the
    // undecided state as well. Dropping the operation identity is what lets
    // `retryRestore` start a second one in the meantime.
    _restoreOperation = null;
    state = const LoopSessionState.restoreUnavailable(
      errorMessage: loopUndecidedSessionMessage,
    );
  }

  /// Whether this `unauthenticated` snapshot is held instead of published.
  ///
  /// Only the cold-start wait may hold one, and only once. Anything else - a
  /// session that already reached the product, the undecided state that is
  /// already showing its explanation and retry, a preview, a sign-out the owner
  /// asked for - takes the answer immediately, so a credential revoked after
  /// login still signs the owner out on the spot.
  bool _holdUnauthenticated() {
    if (state.mode != LoopSessionMode.restoring) return false;
    // Already waiting: a second premature `Unauthenticated` must not extend the
    // window it is being measured against.
    if (_unauthenticatedGrace != null) return true;
    if (_unauthenticatedGraceSpent) return false;
    _unauthenticatedGraceSpent = true;
    _unauthenticatedGrace = Timer(
      ref.read(loopSessionUnauthenticatedGraceProvider),
      _unauthenticatedGraceExpired,
    );
    return true;
  }

  void _cancelUnauthenticatedGrace() {
    _unauthenticatedGrace?.cancel();
    _unauthenticatedGrace = null;
  }

  void _unauthenticatedGraceExpired() {
    _unauthenticatedGrace = null;
    if (!ref.mounted || state.mode != LoopSessionMode.restoring) return;
    // A cold-start restore still in flight has not answered at all yet. That
    // case belongs to the 12-second deadline and its branded frame, never to
    // the credential form.
    if (_restoreOperation != null) return;
    state = const LoopSessionState.signedOut();
  }

  Future<void> _restore(PrivyAuthGateway gateway, int generation) async {
    try {
      final snapshot = await gateway.restoreSession();
      if (!ref.mounted) return;
      // Never let a stale unauthenticated restore overwrite a session that
      // completed while restoration was in flight. A late answer from a call
      // the deadline already gave up on is still an answer, so it is not
      // filtered by generation.
      if (state.isRestoring ||
          snapshot.kind == PrivySessionKind.authenticated) {
        _receiveSnapshot(snapshot);
      }
    } on PrivyGatewayException catch (error) {
      _failRestore(error.kind, error.userMessage, generation);
    } catch (_) {
      // An unclassified failure is not Privy answering that the credential is
      // gone. The session stays undecided rather than falling to the form.
      _failRestore(
        PrivyFailureKind.unknown,
        loopUndecidedSessionMessage,
        generation,
      );
    }
  }

  void _failRestore(PrivyFailureKind kind, String message, int generation) {
    // A failure from a superseded attempt must not overwrite the state a newer
    // one is already working on; unlike a snapshot, it carries no new fact.
    if (!ref.mounted ||
        generation != _restoreGeneration ||
        !state.isRestoring) {
      return;
    }
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
    // Decision 0064 §5: a cold start may be told "unauthenticated" before Privy
    // has finished restoring. Hold that answer for the grace window; an
    // `authenticated` arriving inside it cancels the wait and wins.
    if (snapshot.kind == PrivySessionKind.unauthenticated &&
        _holdUnauthenticated()) {
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
