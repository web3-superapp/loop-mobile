import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';

enum ProfilePhase {
  initial,
  loading,
  ready,
  saving,
  conflict,
  unavailable,
  failure,
}

@immutable
final class ProfileState {
  factory ProfileState._({
    required ProfileMode mode,
    required ProfilePhase phase,
    ProfileResource? resource,
    ProfileValues? draft,
    ProfileGatewayFailureKind? failureKind,
    bool requiresReload = false,
  }) {
    final copiedResource = resource == null
        ? null
        : ProfileResource.copyOf(resource);
    final copiedDraft = ProfileValues.copyOf(
      draft ?? copiedResource?.values ?? ProfileValues.empty(),
    );
    if (copiedResource == null && copiedDraft != ProfileValues.empty()) {
      throw const InvalidProfileContractException();
    }
    return ProfileState._raw(
      mode: mode,
      phase: phase,
      resource: copiedResource,
      draft: copiedDraft,
      failureKind: failureKind,
      requiresReload: requiresReload,
    );
  }

  const ProfileState._raw({
    required this.mode,
    required this.phase,
    required this.resource,
    required this.draft,
    required this.failureKind,
    required this.requiresReload,
  });

  factory ProfileState.initial(ProfileMode mode) => ProfileState._(
    mode: mode,
    phase: mode == ProfileMode.unavailable
        ? ProfilePhase.unavailable
        : ProfilePhase.initial,
    failureKind: mode == ProfileMode.unavailable
        ? ProfileGatewayFailureKind.unavailable
        : null,
  );

  final ProfileMode mode;
  final ProfilePhase phase;
  final ProfileResource? resource;
  final ProfileValues draft;
  final ProfileGatewayFailureKind? failureKind;

  /// A stale different write was rejected. Only a successful reload can make
  /// the draft editable and saveable again.
  final bool requiresReload;

  bool get isBusy =>
      phase == ProfilePhase.loading || phase == ProfilePhase.saving;

  bool get isDirty => resource != null && resource!.values != draft;

  bool get canEdit => resource != null && !isBusy && !requiresReload;

  bool get canSave => canEdit && isDirty;

  int? get expectedVersion => resource?.version;

  String? get failureCode =>
      failureKind == null ? null : ProfileGatewayException(failureKind!).code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileState &&
          other.mode == mode &&
          other.phase == phase &&
          other.resource == resource &&
          other.draft == draft &&
          other.failureKind == failureKind &&
          other.requiresReload == requiresReload;

  @override
  int get hashCode =>
      Object.hash(mode, phase, resource, draft, failureKind, requiresReload);
}

final class ProfileController extends Notifier<ProfileState> {
  Future<void>? _loadOperation;
  Future<void>? _saveOperation;
  var _generation = 0;

  @override
  ProfileState build() {
    // Retire work started against the previous gateway and allow the new
    // gateway to start immediately instead of inheriting obsolete flights.
    _generation += 1;
    _loadOperation = null;
    _saveOperation = null;
    final mode = ref.watch(profileGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return ProfileState.initial(mode);
  }

  /// Loads only an uninitialized controller. Repeated lifecycle calls cannot
  /// replace an edited draft; that requires an explicit [reload].
  Future<void> load() {
    if (state.resource != null) return Future<void>.value();
    return _startLoad();
  }

  Future<void> reload() => _startLoad();

  Future<void> _startLoad() {
    final active = _loadOperation;
    if (active != null) return active;
    final saving = _saveOperation;
    if (saving != null) return saving;

    final gateway = ref.read(profileGatewayProvider);
    if (gateway.mode == ProfileMode.unavailable) {
      _publishFailure(
        mode: gateway.mode,
        previous: state,
        kind: ProfileGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    late final Future<void> operation;
    operation = _performLoad(gateway, generation).whenComplete(() {
      if (identical(_loadOperation, operation)) _loadOperation = null;
    });
    _loadOperation = operation;
    return operation;
  }

  Future<void> _performLoad(ProfileGateway gateway, int generation) async {
    final previous = state;
    state = ProfileState._(
      mode: gateway.mode,
      phase: ProfilePhase.loading,
      resource: previous.resource,
      draft: previous.draft,
      requiresReload: previous.requiresReload,
    );
    try {
      final loaded = ProfileResource.copyOf(await gateway.load());
      if (!_isCurrent(generation)) return;
      state = ProfileState._(
        mode: gateway.mode,
        phase: ProfilePhase.ready,
        resource: loaded,
        draft: loaded.values,
      );
    } on ProfileGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(mode: gateway.mode, previous: previous, kind: error.kind);
    } on InvalidProfileContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: ProfileGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: ProfileGatewayFailureKind.unexpected,
      );
    }
  }

  void editAlias(String? alias) {
    if (!state.canEdit) throw StateError('Profile is not editable');
    final updated = state.draft.withAlias(alias);
    state = ProfileState._(
      mode: state.mode,
      phase: ProfilePhase.ready,
      resource: state.resource,
      draft: updated,
    );
  }

  void discard() {
    final resource = state.resource;
    if (resource == null || state.isBusy || state.requiresReload) return;
    state = ProfileState._(
      mode: state.mode,
      phase: ProfilePhase.ready,
      resource: resource,
      draft: resource.values,
    );
  }

  Future<void> save() {
    final active = _saveOperation;
    if (active != null) return active;
    final loading = _loadOperation;
    if (loading != null) return loading;
    if (!state.canSave) return Future<void>.value();

    final gateway = ref.read(profileGatewayProvider);
    if (gateway.mode == ProfileMode.unavailable) {
      _publishFailure(
        mode: gateway.mode,
        previous: state,
        kind: ProfileGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    final expectedVersion = state.resource!.version;
    final candidate = ProfileValues.copyOf(state.draft);
    late final Future<void> operation;
    operation =
        _performSave(
          gateway: gateway,
          generation: generation,
          expectedVersion: expectedVersion,
          candidate: candidate,
        ).whenComplete(() {
          if (identical(_saveOperation, operation)) _saveOperation = null;
        });
    _saveOperation = operation;
    return operation;
  }

  Future<void> _performSave({
    required ProfileGateway gateway,
    required int generation,
    required int expectedVersion,
    required ProfileValues candidate,
  }) async {
    final previous = state;
    state = ProfileState._(
      mode: gateway.mode,
      phase: ProfilePhase.saving,
      resource: previous.resource,
      draft: candidate,
    );
    try {
      final saved = ProfileResource.copyOf(
        await gateway.replace(
          expectedVersion: expectedVersion,
          values: candidate,
        ),
      );
      if (!_isCurrent(generation)) return;
      if (saved.version <= expectedVersion || saved.values != candidate) {
        _publishFailure(
          mode: gateway.mode,
          previous: previous,
          kind: ProfileGatewayFailureKind.invalidData,
        );
        return;
      }
      state = ProfileState._(
        mode: gateway.mode,
        phase: ProfilePhase.ready,
        resource: saved,
        draft: saved.values,
      );
    } on ProfileGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      if (error.kind == ProfileGatewayFailureKind.versionConflict) {
        state = ProfileState._(
          mode: gateway.mode,
          phase: ProfilePhase.conflict,
          resource: previous.resource,
          draft: candidate,
          failureKind: error.kind,
          requiresReload: true,
        );
        return;
      }
      _publishFailure(
        mode: gateway.mode,
        previous: ProfileState._(
          mode: previous.mode,
          phase: previous.phase,
          resource: previous.resource,
          draft: candidate,
        ),
        kind: error.kind,
      );
    } on InvalidProfileContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: ProfileGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: ProfileGatewayFailureKind.unexpected,
      );
    }
  }

  void _publishFailure({
    required ProfileMode mode,
    required ProfileState previous,
    required ProfileGatewayFailureKind kind,
  }) {
    final unresolvedConflict = previous.requiresReload;
    state = ProfileState._(
      mode: mode,
      phase: unresolvedConflict
          ? ProfilePhase.conflict
          : previous.resource == null &&
                kind == ProfileGatewayFailureKind.unavailable
          ? ProfilePhase.unavailable
          : ProfilePhase.failure,
      resource: previous.resource,
      draft: previous.draft,
      failureKind: kind,
      requiresReload: unresolvedConflict,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);
