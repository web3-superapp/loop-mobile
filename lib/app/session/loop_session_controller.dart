import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

enum LoopSessionMode {
  restoring,
  signedOut,
  preview,
  authenticatedUnverified,
  authenticated,
}

@immutable
class LoopSessionState {
  const LoopSessionState({required this.mode, this.account, this.errorMessage});

  const LoopSessionState.restoring() : this(mode: LoopSessionMode.restoring);

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
    if (_localSignOutBarrier &&
        snapshot.kind != PrivySessionKind.unauthenticated) {
      return;
    }
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
    if (!ref.read(developmentPreviewEnabledProvider)) return false;
    state = const LoopSessionState.preview();
    return true;
  }

  void acceptAuthenticated(PrivyAccountSummary account) {
    _localSignOutBarrier = false;
    state = LoopSessionState(
      mode: LoopSessionMode.authenticated,
      account: account,
    );
  }

  Future<void> createWallet() async {
    if (!state.canUseProviderBackedFeatures) {
      throw const PrivyGatewayException('开发预览或受限会话不会创建真实钱包。');
    }
    final wallet = await ref
        .read(privyAuthGatewayProvider)
        .createFirstEthereumWallet();
    final account = state.account;
    if (account != null) {
      state = state.copyWith(account: account.copyWith(wallet: wallet));
    }
  }

  Future<void> exit() async {
    final shouldLogout =
        state.mode == LoopSessionMode.authenticated ||
        state.mode == LoopSessionMode.authenticatedUnverified;
    _localSignOutBarrier = true;
    state = const LoopSessionState.signedOut();
    if (!shouldLogout) return;

    try {
      await ref.read(privyAuthGatewayProvider).logout();
    } on PrivyGatewayException catch (error) {
      if (ref.mounted && _localSignOutBarrier) {
        state = LoopSessionState.signedOut(errorMessage: error.userMessage);
      }
    } catch (_) {
      if (ref.mounted && _localSignOutBarrier) {
        state = const LoopSessionState.signedOut(
          errorMessage: '本地会话已退出，但 Privy 远端退出尚未确认。',
        );
      }
    }
  }
}

final loopSessionProvider =
    NotifierProvider<LoopSessionController, LoopSessionState>(
      LoopSessionController.new,
    );
