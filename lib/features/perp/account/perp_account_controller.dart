import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';

enum PerpAccountPhase {
  initial,
  loadingBinding,
  bindingRequired,
  binding,
  loadingFacts,
  ready,
  stale,
  conflict,
  mutationUnknown,
  unavailable,
  failure,
}

@immutable
final class PerpAccountState {
  const PerpAccountState._({
    required this.mode,
    required this.phase,
    this.binding,
    this.config,
    this.account,
    this.failureKind,
    this.requestId,
  });

  factory PerpAccountState.initial(PerpGatewayMode mode) => PerpAccountState._(
    mode: mode,
    phase: mode == PerpGatewayMode.unavailable
        ? PerpAccountPhase.unavailable
        : PerpAccountPhase.initial,
    failureKind: mode == PerpGatewayMode.unavailable
        ? PerpGatewayFailureKind.unavailable
        : null,
  );

  final PerpGatewayMode mode;
  final PerpAccountPhase phase;
  final PerpWalletBinding? binding;
  final PerpConfig? config;
  final PerpAccount? account;
  final PerpGatewayFailureKind? failureKind;

  /// Safe correlation identifier returned by the Loop backend.
  ///
  /// Transport messages and provider payloads never enter application state.
  final String? requestId;

  bool get isBusy =>
      phase == PerpAccountPhase.loadingBinding ||
      phase == PerpAccountPhase.binding ||
      phase == PerpAccountPhase.loadingFacts;

  DateTime? get factsExpireAt {
    final configValue = config;
    final accountValue = account;
    if (phase != PerpAccountPhase.ready ||
        configValue == null ||
        accountValue == null) {
      return null;
    }
    final configExpiry = configValue.source.expiresAt;
    final accountExpiry = accountValue.source.expiresAt;
    return configExpiry.isBefore(accountExpiry) ? configExpiry : accountExpiry;
  }

  bool hasFreshFactsAt(DateTime now) {
    final expiresAt = factsExpireAt;
    return expiresAt != null && expiresAt.isAfter(now.toUtc());
  }

  bool get requiresBindingConfirmation =>
      phase == PerpAccountPhase.bindingRequired ||
      phase == PerpAccountPhase.conflict ||
      phase == PerpAccountPhase.mutationUnknown;

  bool get canBind =>
      mode == PerpGatewayMode.production &&
      !isBusy &&
      requiresBindingConfirmation &&
      binding != null &&
      (!binding!.isBound ||
          (phase == PerpAccountPhase.bindingRequired &&
              failureKind == PerpGatewayFailureKind.walletBindingRequired));

  String? get failureCode => failureKind == null
      ? null
      : PerpGatewayException(failureKind!, requestId: requestId).code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PerpAccountState &&
          other.mode == mode &&
          other.phase == phase &&
          other.binding == binding &&
          other.config == config &&
          other.account == account &&
          other.failureKind == failureKind &&
          other.requestId == requestId;

  @override
  int get hashCode => Object.hash(
    mode,
    phase,
    binding,
    config,
    account,
    failureKind,
    requestId,
  );
}

typedef PerpAccountClock = DateTime Function();

abstract interface class PerpAccountExpiryHandle {
  void cancel();
}

typedef PerpAccountExpiryScheduler = PerpAccountExpiryHandle Function(
  Duration delay,
  void Function() callback,
);

final perpAccountClockProvider = Provider<PerpAccountClock>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

final perpAccountExpirySchedulerProvider = Provider<PerpAccountExpiryScheduler>(
  (ref) =>
      (delay, callback) => _TimerExpiryHandle(Timer(delay, callback)),
);

final class _TimerExpiryHandle implements PerpAccountExpiryHandle {
  const _TimerExpiryHandle(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

/// Owns the D8 account projection and its explicit wallet-binding boundary.
///
/// It deliberately exposes no trading mutation. The only write is the
/// user-confirmed wallet binding required before backend-mediated reads.
final class PerpAccountController extends Notifier<PerpAccountState> {
  Future<void>? _operation;
  PerpAccountExpiryHandle? _expiry;
  var _generation = 0;

  @override
  PerpAccountState build() {
    _generation += 1;
    _operation = null;
    _cancelExpiry();
    final mode = ref.watch(perpPrivateGatewayProvider).mode;
    ref.onDispose(() {
      _generation += 1;
      _operation = null;
      _cancelExpiry();
    });
    return PerpAccountState.initial(mode);
  }

  /// Performs the initial read once. Later lifecycle calls cannot silently
  /// repeat a binding decision or replace a fresh projection.
  Future<void> load() {
    final active = _operation;
    if (active != null) return active;
    if (state.phase != PerpAccountPhase.initial &&
        state.phase != PerpAccountPhase.failure &&
        state.phase != PerpAccountPhase.stale) {
      return Future<void>.value();
    }
    return _startLoad();
  }

  /// Explicitly re-runs binding -> config -> account in that exact order.
  Future<void> refresh() => _startLoad();

  /// Alias kept for consistency with other feature controllers.
  Future<void> reload() => refresh();

  /// Synchronously clears a projection whose backend deadline has elapsed.
  ///
  /// Mobile lifecycle suspension may pause Dart timers, so UI and resume
  /// boundaries call this before they are allowed to render account facts.
  void expireIfNeeded() {
    if (state.phase != PerpAccountPhase.ready ||
        state.hasFreshFactsAt(ref.read(perpAccountClockProvider)())) {
      return;
    }
    _generation += 1;
    _cancelExpiry();
    state = PerpAccountState._(
      mode: state.mode,
      phase: PerpAccountPhase.stale,
      binding: state.binding,
    );
  }

  Future<void> _startLoad() {
    final active = _operation;
    if (active != null) return active;
    final gateway = ref.read(perpPrivateGatewayProvider);
    if (gateway.mode == PerpGatewayMode.unavailable) {
      _cancelExpiry();
      state = const PerpAccountState._(
        mode: PerpGatewayMode.unavailable,
        phase: PerpAccountPhase.unavailable,
        failureKind: PerpGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    _cancelExpiry();
    late final Future<void> operation;
    operation = _performLoad(gateway, generation).whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<void> _performLoad(PerpPrivateGateway gateway, int generation) async {
    state = PerpAccountState._(
      mode: gateway.mode,
      phase: PerpAccountPhase.loadingBinding,
      binding: state.binding,
    );
    try {
      final binding = await gateway.getWalletBinding();
      if (!_isCurrent(generation)) return;
      if (!binding.isBound) {
        state = PerpAccountState._(
          mode: gateway.mode,
          phase: PerpAccountPhase.bindingRequired,
          binding: binding,
        );
        return;
      }
      await _loadFacts(gateway, generation, binding);
    } on PerpGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(gateway.mode, error, binding: null);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        const PerpGatewayException(PerpGatewayFailureKind.unexpected),
        binding: null,
      );
    }
  }

  /// Attempts one user-confirmed bind with the last observed version.
  ///
  /// Timeout and connection failures are reconciled with GET. This method
  /// never replays the mutation; a later attempt is another explicit action.
  Future<void> bind() {
    final active = _operation;
    if (active != null) return active;
    if (!state.canBind) return Future<void>.value();

    final gateway = ref.read(perpPrivateGatewayProvider);
    if (gateway.mode == PerpGatewayMode.unavailable) {
      _publishFailure(
        gateway.mode,
        const PerpGatewayException(PerpGatewayFailureKind.unavailable),
        binding: state.binding,
      );
      return Future<void>.value();
    }

    final previousBinding = state.binding!;
    final generation = ++_generation;
    _cancelExpiry();
    late final Future<void> operation;
    operation = _performBind(gateway, generation, previousBinding).whenComplete(
      () {
        if (identical(_operation, operation)) _operation = null;
      },
    );
    _operation = operation;
    return operation;
  }

  Future<void> _performBind(
    PerpPrivateGateway gateway,
    int generation,
    PerpWalletBinding previousBinding,
  ) async {
    state = PerpAccountState._(
      mode: gateway.mode,
      phase: PerpAccountPhase.binding,
      binding: previousBinding,
    );
    try {
      final binding = await gateway.bindWallet(
        expectedBindingVersion: previousBinding.bindingVersion,
      );
      if (!_isCurrent(generation)) return;
      if (!_isAcceptedBindResult(previousBinding, binding)) {
        _publishFailure(
          gateway.mode,
          const PerpGatewayException(PerpGatewayFailureKind.invalidData),
          binding: binding,
        );
        return;
      }
      await _loadFacts(gateway, generation, binding);
    } on PerpGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      switch (error.kind) {
        case PerpGatewayFailureKind.timeout:
        case PerpGatewayFailureKind.connection:
          await _reconcileAmbiguousBind(
            gateway,
            generation,
            previousBinding,
            error,
          );
          return;
        case PerpGatewayFailureKind.versionConflict:
          await _reconcileBindingConflict(gateway, generation, error);
          return;
        case PerpGatewayFailureKind.walletBindingRequired:
          await _refreshBindingAfterPrivateReadRejection(
            gateway,
            generation,
            error,
          );
          return;
        case PerpGatewayFailureKind.authentication:
        case PerpGatewayFailureKind.bootstrapRequired:
        case PerpGatewayFailureKind.invalidRequest:
        case PerpGatewayFailureKind.unavailable:
        case PerpGatewayFailureKind.cancelled:
        case PerpGatewayFailureKind.invalidData:
        case PerpGatewayFailureKind.unexpected:
          _publishFailure(gateway.mode, error, binding: previousBinding);
          return;
      }
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        const PerpGatewayException(PerpGatewayFailureKind.unexpected),
        binding: previousBinding,
      );
    }
  }

  Future<void> _reconcileAmbiguousBind(
    PerpPrivateGateway gateway,
    int generation,
    PerpWalletBinding previousBinding,
    PerpGatewayException mutationError,
  ) async {
    try {
      final binding = await gateway.getWalletBinding();
      if (!_isCurrent(generation)) return;
      if (_isAcceptedBindResult(previousBinding, binding)) {
        await _loadFacts(gateway, generation, binding);
        return;
      }
      if (binding.isBound) {
        state = PerpAccountState._(
          mode: gateway.mode,
          phase: PerpAccountPhase.conflict,
          binding: binding,
          failureKind: mutationError.kind,
          requestId: mutationError.requestId,
        );
        return;
      }
      state = PerpAccountState._(
        mode: gateway.mode,
        phase: PerpAccountPhase.mutationUnknown,
        binding: binding,
        failureKind: mutationError.kind,
        requestId: mutationError.requestId,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      state = PerpAccountState._(
        mode: gateway.mode,
        phase: PerpAccountPhase.mutationUnknown,
        failureKind: mutationError.kind,
        requestId: mutationError.requestId,
      );
    }
  }

  Future<void> _reconcileBindingConflict(
    PerpPrivateGateway gateway,
    int generation,
    PerpGatewayException conflict,
  ) async {
    PerpWalletBinding? latest;
    try {
      latest = await gateway.getWalletBinding();
    } catch (_) {
      // The rejected optimistic version is unsafe to reuse. A later explicit
      // refresh must obtain a current version before binding can be attempted.
    }
    if (!_isCurrent(generation)) return;
    state = PerpAccountState._(
      mode: gateway.mode,
      phase: PerpAccountPhase.conflict,
      binding: latest,
      failureKind: conflict.kind,
      requestId: conflict.requestId,
    );
  }

  Future<void> _loadFacts(
    PerpPrivateGateway gateway,
    int generation,
    PerpWalletBinding binding,
  ) async {
    if (!_isCurrent(generation)) return;
    state = PerpAccountState._(
      mode: gateway.mode,
      phase: PerpAccountPhase.loadingFacts,
      binding: binding,
    );
    try {
      final config = await gateway.getConfig();
      if (!_isCurrent(generation)) return;
      final account = await gateway.getAccount();
      if (!_isCurrent(generation)) return;
      _publishReady(gateway.mode, generation, binding, config, account);
    } on PerpGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      if (error.kind == PerpGatewayFailureKind.walletBindingRequired) {
        await _refreshBindingAfterPrivateReadRejection(
          gateway,
          generation,
          error,
        );
        return;
      }
      _publishFailure(gateway.mode, error, binding: binding);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        const PerpGatewayException(PerpGatewayFailureKind.unexpected),
        binding: binding,
      );
    }
  }

  Future<void> _refreshBindingAfterPrivateReadRejection(
    PerpPrivateGateway gateway,
    int generation,
    PerpGatewayException privateReadError,
  ) async {
    state = PerpAccountState._(
      mode: gateway.mode,
      phase: PerpAccountPhase.loadingBinding,
    );
    try {
      final binding = await gateway.getWalletBinding();
      if (!_isCurrent(generation)) return;
      state = PerpAccountState._(
        mode: gateway.mode,
        phase: PerpAccountPhase.bindingRequired,
        binding: binding,
        failureKind: privateReadError.kind,
        requestId: privateReadError.requestId,
      );
    } on PerpGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(gateway.mode, error, binding: null);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        const PerpGatewayException(PerpGatewayFailureKind.unexpected),
        binding: null,
      );
    }
  }

  void _publishReady(
    PerpGatewayMode mode,
    int generation,
    PerpWalletBinding binding,
    PerpConfig config,
    PerpAccount account,
  ) {
    _cancelExpiry();
    final expiresAt = config.source.expiresAt.isBefore(account.source.expiresAt)
        ? config.source.expiresAt
        : account.source.expiresAt;
    final now = ref.read(perpAccountClockProvider)().toUtc();
    if (!expiresAt.isAfter(now)) {
      state = PerpAccountState._(
        mode: mode,
        phase: PerpAccountPhase.stale,
        binding: binding,
      );
      return;
    }

    state = PerpAccountState._(
      mode: mode,
      phase: PerpAccountPhase.ready,
      binding: binding,
      config: config,
      account: account,
    );
    final handle = ref.read(perpAccountExpirySchedulerProvider)(
      expiresAt.difference(now),
      () => _expireFacts(generation),
    );
    if (_isCurrent(generation) && state.phase == PerpAccountPhase.ready) {
      _expiry = handle;
    } else {
      handle.cancel();
    }
  }

  void _expireFacts(int generation) {
    if (!_isCurrent(generation) || state.phase != PerpAccountPhase.ready) {
      return;
    }
    _expiry = null;
    state = PerpAccountState._(
      mode: state.mode,
      phase: PerpAccountPhase.stale,
      binding: state.binding,
    );
  }

  void _publishFailure(
    PerpGatewayMode mode,
    PerpGatewayException error, {
    required PerpWalletBinding? binding,
  }) {
    _cancelExpiry();
    state = PerpAccountState._(
      mode: mode,
      phase: error.kind == PerpGatewayFailureKind.unavailable
          ? PerpAccountPhase.unavailable
          : PerpAccountPhase.failure,
      binding: binding,
      failureKind: error.kind,
      requestId: error.requestId,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  bool _isAcceptedBindResult(
    PerpWalletBinding previous,
    PerpWalletBinding observed,
  ) {
    if (!observed.isBound) return false;
    final previousVersion = BigInt.tryParse(previous.bindingVersion);
    final observedVersion = BigInt.tryParse(observed.bindingVersion);
    if (previousVersion == null || observedVersion == null) return false;
    if (previous.isBound) {
      return observedVersion == previousVersion ||
          observedVersion == previousVersion + BigInt.one;
    }
    return observedVersion == previousVersion + BigInt.one;
  }

  void _cancelExpiry() {
    _expiry?.cancel();
    _expiry = null;
  }
}

final perpAccountControllerProvider =
    NotifierProvider<PerpAccountController, PerpAccountState>(
      PerpAccountController.new,
    );
