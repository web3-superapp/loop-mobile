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
  var _gatewayGeneration = 0;
  var _streamRevision = 0;
  int? _readyGeneration;
  var _localSignOutBarrier = false;

  @override
  LoopSessionState build() {
    final gateway = ref.watch(privyAuthGatewayProvider);
    final generation = ++_gatewayGeneration;
    _subscription?.cancel();
    _subscription = gateway.watchSession().listen(
      (snapshot) => _queueStreamSnapshot(snapshot, generation),
    );
    final restoreStreamRevision = _streamRevision;
    ref.onDispose(() => _subscription?.cancel());
    unawaited(
      Future<void>.microtask(() async {
        if (!ref.mounted || generation != _gatewayGeneration) return;
        _readyGeneration = generation;
        await _restore(gateway, generation, restoreStreamRevision);
      }),
    );
    return const LoopSessionState.restoring();
  }

  void _queueStreamSnapshot(PrivySessionSnapshot snapshot, int generation) {
    if (!ref.mounted || generation != _gatewayGeneration) return;
    final streamRevision = ++_streamRevision;
    if (_readyGeneration == generation) {
      _receiveSnapshot(snapshot);
      return;
    }
    unawaited(
      Future<void>.microtask(() {
        if (!ref.mounted ||
            generation != _gatewayGeneration ||
            streamRevision != _streamRevision) {
          return;
        }
        _receiveSnapshot(snapshot);
      }),
    );
  }

  Future<void> _restore(
    PrivyAuthGateway gateway,
    int generation,
    int streamRevision,
  ) async {
    try {
      final snapshot = await gateway.restoreSession();
      if (!ref.mounted ||
          generation != _gatewayGeneration ||
          streamRevision != _streamRevision ||
          state.mode != LoopSessionMode.restoring) {
        return;
      }
      _receiveSnapshot(snapshot);
    } on PrivyGatewayException catch (error) {
      if (ref.mounted &&
          generation == _gatewayGeneration &&
          streamRevision == _streamRevision &&
          state.mode == LoopSessionMode.restoring) {
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
    _streamRevision += 1;
    state = const LoopSessionState.preview();
    return true;
  }

  void acceptAuthenticated(PrivyAccountSummary account) {
    _streamRevision += 1;
    _localSignOutBarrier = false;
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

    _streamRevision += 1;
    state = currentState.copyWith(
      account: currentAccount.copyWith(wallet: wallet),
    );
  }

  Future<void> exit() async {
    final shouldLogout =
        state.mode == LoopSessionMode.authenticated ||
        state.mode == LoopSessionMode.authenticatedUnverified;
    _streamRevision += 1;
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
