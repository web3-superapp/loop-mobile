import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';

enum LoopIdSetupPhase {
  initial,
  loading,
  ready,
  submitting,
  activated,
  unavailable,
  failure,
}

@immutable
final class LoopIdSetupState {
  const LoopIdSetupState({
    required this.phase,
    required this.mode,
    this.resource,
    this.alias,
    this.avatarRef,
    this.interests = const <ProfileInterest>[],
    this.pushNotificationsRequested = true,
    this.failureKind,
  });

  factory LoopIdSetupState.initial(ProfileMode mode) => LoopIdSetupState(
    phase: mode == ProfileMode.unavailable
        ? LoopIdSetupPhase.unavailable
        : LoopIdSetupPhase.initial,
    mode: mode,
    failureKind: mode == ProfileMode.unavailable
        ? ProfileGatewayFailureKind.unavailable
        : null,
  );

  final LoopIdSetupPhase phase;
  final ProfileMode mode;
  final ProfileResource? resource;
  final String? alias;
  final String? avatarRef;
  final List<ProfileInterest> interests;

  /// Local-only display preference for this step. It is not sent to the
  /// backend and never claims a granted OS permission (D14 owns delivery).
  final bool pushNotificationsRequested;

  final ProfileGatewayFailureKind? failureKind;

  String? get loopId => resource?.loopId;

  bool get isBusy =>
      phase == LoopIdSetupPhase.loading || phase == LoopIdSetupPhase.submitting;

  bool get canSubmit =>
      resource != null &&
      !isBusy &&
      phase != LoopIdSetupPhase.activated &&
      (alias?.trim().isNotEmpty ?? false);

  LoopIdSetupState copyWith({
    LoopIdSetupPhase? phase,
    ProfileMode? mode,
    ProfileResource? resource,
    String? alias,
    bool clearAlias = false,
    String? avatarRef,
    bool clearAvatarRef = false,
    List<ProfileInterest>? interests,
    bool? pushNotificationsRequested,
    ProfileGatewayFailureKind? failureKind,
    bool clearFailure = false,
  }) {
    return LoopIdSetupState(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      resource: resource ?? this.resource,
      alias: clearAlias ? null : (alias ?? this.alias),
      avatarRef: clearAvatarRef ? null : (avatarRef ?? this.avatarRef),
      interests: interests ?? this.interests,
      pushNotificationsRequested:
          pushNotificationsRequested ?? this.pushNotificationsRequested,
      failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopIdSetupState &&
          other.phase == phase &&
          other.mode == mode &&
          other.resource == resource &&
          other.alias == alias &&
          other.avatarRef == avatarRef &&
          listEquals(other.interests, interests) &&
          other.pushNotificationsRequested == pushNotificationsRequested &&
          other.failureKind == failureKind;

  @override
  int get hashCode => Object.hash(
    phase,
    mode,
    resource,
    alias,
    avatarRef,
    Object.hashAll(interests),
    pushNotificationsRequested,
    failureKind,
  );
}

/// Owns the one-time activation step.
///
/// Retrying after a timeout submits the identical body so the gateway can
/// replay the recorded idempotency key; the interest order is preserved for
/// exactly that reason.
final class LoopIdSetupController extends Notifier<LoopIdSetupState> {
  var _generation = 0;
  Future<void>? _operation;

  @override
  LoopIdSetupState build() {
    _generation += 1;
    _operation = null;
    final mode = ref.watch(profileGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return LoopIdSetupState.initial(mode);
  }

  Future<void> load() {
    if (state.resource != null) return Future<void>.value();
    return reload();
  }

  Future<void> reload() {
    final active = _operation;
    if (active != null) return active;
    final gateway = ref.read(profileGatewayProvider);
    if (gateway.mode == ProfileMode.unavailable) {
      state = state.copyWith(
        phase: LoopIdSetupPhase.unavailable,
        failureKind: ProfileGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }
    final generation = ++_generation;
    late final Future<void> operation;
    operation = _load(gateway, generation).whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<void> _load(ProfileGateway gateway, int generation) async {
    state = state.copyWith(phase: LoopIdSetupPhase.loading, clearFailure: true);
    try {
      final loaded = ProfileResource.copyOf(await gateway.load());
      if (!_isCurrent(generation)) return;
      state = state.copyWith(
        phase: loaded.isActivated
            ? LoopIdSetupPhase.activated
            : LoopIdSetupPhase.ready,
        resource: loaded,
        alias: loaded.values.alias ?? state.alias,
        avatarRef: loaded.values.avatarRef ?? state.avatarRef,
        interests: loaded.values.interests.isEmpty
            ? state.interests
            : loaded.values.interests,
        clearFailure: true,
      );
    } on ProfileGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(error.kind);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(ProfileGatewayFailureKind.unexpected);
    }
  }

  void editAlias(String? alias) {
    final value = alias?.trim();
    state = state.copyWith(
      alias: value == null || value.isEmpty ? null : value,
      clearAlias: value == null || value.isEmpty,
      clearFailure: true,
      phase: state.phase == LoopIdSetupPhase.failure
          ? LoopIdSetupPhase.ready
          : state.phase,
    );
  }

  void editAvatarRef(String? avatarRef) {
    state = state.copyWith(
      avatarRef: avatarRef,
      clearAvatarRef: avatarRef == null,
      clearFailure: true,
      phase: state.phase == LoopIdSetupPhase.failure
          ? LoopIdSetupPhase.ready
          : state.phase,
    );
  }

  void toggleInterest(ProfileInterest interest) {
    final next = List<ProfileInterest>.of(state.interests);
    if (!next.remove(interest)) {
      if (next.length >= profileMaximumInterests) return;
      next.add(interest);
    }
    state = state.copyWith(interests: next, clearFailure: true);
  }

  void setPushNotificationsRequested(bool value) {
    state = state.copyWith(pushNotificationsRequested: value);
  }

  Future<void> submit() {
    final active = _operation;
    if (active != null) return active;
    if (!state.canSubmit) return Future<void>.value();
    final gateway = ref.read(profileActivationGatewayProvider);
    if (gateway.mode == ProfileMode.unavailable) {
      state = state.copyWith(
        phase: LoopIdSetupPhase.unavailable,
        failureKind: ProfileGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }
    final generation = ++_generation;
    late final Future<void> operation;
    operation = _submit(gateway, generation).whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<void> _submit(ProfileActivationGateway gateway, int generation) async {
    final alias = state.alias!.trim();
    final avatarRef = state.avatarRef;
    final interests = List<ProfileInterest>.unmodifiable(state.interests);
    state = state.copyWith(
      phase: LoopIdSetupPhase.submitting,
      clearFailure: true,
    );
    try {
      final activated = ProfileResource.copyOf(
        await gateway.activate(
          alias: alias,
          avatarRef: avatarRef,
          interests: interests,
        ),
      );
      if (!_isCurrent(generation)) return;
      if (!activated.isActivated) {
        _publishFailure(ProfileGatewayFailureKind.invalidData);
        return;
      }
      state = state.copyWith(
        phase: LoopIdSetupPhase.activated,
        resource: activated,
        alias: activated.values.alias ?? alias,
        interests: activated.values.interests,
        clearFailure: true,
      );
    } on ProfileGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(error.kind);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(ProfileGatewayFailureKind.unexpected);
    }
  }

  void _publishFailure(ProfileGatewayFailureKind kind) {
    state = state.copyWith(
      phase:
          state.resource == null &&
              kind == ProfileGatewayFailureKind.unavailable
          ? LoopIdSetupPhase.unavailable
          : LoopIdSetupPhase.failure,
      failureKind: kind,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final loopIdSetupControllerProvider =
    NotifierProvider<LoopIdSetupController, LoopIdSetupState>(
      LoopIdSetupController.new,
    );
