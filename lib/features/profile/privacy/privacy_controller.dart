import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';

enum PrivacyPhase {
  initial,
  loading,
  ready,
  saving,
  conflict,
  unavailable,
  failure,
}

@immutable
final class PrivacyState {
  factory PrivacyState._({
    required PrivacyMode mode,
    required PrivacyPhase phase,
    PrivacyResource? resource,
    PrivacyValues? draft,
    PrivacyGatewayFailureKind? failureKind,
    bool requiresReload = false,
  }) {
    final copiedResource = resource == null
        ? null
        : PrivacyResource.copyOf(resource);
    final copiedDraft = PrivacyValues.copyOf(
      draft ?? copiedResource?.values ?? const PrivacyValues.defaults(),
    );
    if (copiedResource == null &&
        copiedDraft != const PrivacyValues.defaults()) {
      throw const InvalidPrivacyContractException();
    }
    return PrivacyState._raw(
      mode: mode,
      phase: phase,
      resource: copiedResource,
      draft: copiedDraft,
      failureKind: failureKind,
      requiresReload: requiresReload,
    );
  }

  const PrivacyState._raw({
    required this.mode,
    required this.phase,
    required this.resource,
    required this.draft,
    required this.failureKind,
    required this.requiresReload,
  });

  factory PrivacyState.initial(PrivacyMode mode) => PrivacyState._(
    mode: mode,
    phase: mode == PrivacyMode.unavailable
        ? PrivacyPhase.unavailable
        : PrivacyPhase.initial,
    failureKind: mode == PrivacyMode.unavailable
        ? PrivacyGatewayFailureKind.unavailable
        : null,
  );

  final PrivacyMode mode;
  final PrivacyPhase phase;
  final PrivacyResource? resource;
  final PrivacyValues draft;
  final PrivacyGatewayFailureKind? failureKind;

  /// A stale different write was rejected. Only a successful reload can make
  /// the draft editable and saveable again.
  final bool requiresReload;

  bool get isBusy =>
      phase == PrivacyPhase.loading || phase == PrivacyPhase.saving;

  bool get isDirty => resource != null && resource!.values != draft;

  bool get canEdit => resource != null && !isBusy && !requiresReload;

  bool get canSave => canEdit && isDirty;

  int? get expectedVersion => resource?.version;

  String? get failureCode =>
      failureKind == null ? null : PrivacyGatewayException(failureKind!).code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrivacyState &&
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

final class PrivacyController extends Notifier<PrivacyState> {
  Future<void>? _loadOperation;
  Future<void>? _saveOperation;
  var _generation = 0;

  @override
  PrivacyState build() {
    _generation += 1;
    _loadOperation = null;
    _saveOperation = null;
    final mode = ref.watch(privacyGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return PrivacyState.initial(mode);
  }

  /// Loads only an uninitialized controller. Explicit reload owns replacement
  /// of an existing resource or edited draft.
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

    final gateway = ref.read(privacyGatewayProvider);
    if (gateway.mode == PrivacyMode.unavailable) {
      _publishFailure(
        mode: gateway.mode,
        previous: state,
        kind: PrivacyGatewayFailureKind.unavailable,
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

  Future<void> _performLoad(PrivacyGateway gateway, int generation) async {
    final previous = state;
    state = PrivacyState._(
      mode: gateway.mode,
      phase: PrivacyPhase.loading,
      resource: previous.resource,
      draft: previous.draft,
      requiresReload: previous.requiresReload,
    );
    try {
      final loaded = PrivacyResource.copyOf(await gateway.load());
      if (!_isCurrent(generation)) return;
      state = PrivacyState._(
        mode: gateway.mode,
        phase: PrivacyPhase.ready,
        resource: loaded,
        draft: loaded.values,
      );
    } on PrivacyGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(mode: gateway.mode, previous: previous, kind: error.kind);
    } on InvalidPrivacyContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: PrivacyGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: PrivacyGatewayFailureKind.unexpected,
      );
    }
  }

  void editDiscoverable(bool value) {
    if (!state.canEdit) throw StateError('Privacy is not editable');
    state = PrivacyState._(
      mode: state.mode,
      phase: PrivacyPhase.ready,
      resource: state.resource,
      draft: state.draft.withDiscoverable(value),
    );
  }

  void editCopyTradeVisibility(CopyTradeVisibility value) {
    if (!state.canEdit) throw StateError('Privacy is not editable');
    state = PrivacyState._(
      mode: state.mode,
      phase: PrivacyPhase.ready,
      resource: state.resource,
      draft: state.draft.withCopyTradeVisibility(value),
    );
  }

  void discard() {
    final resource = state.resource;
    if (resource == null || state.isBusy || state.requiresReload) return;
    state = PrivacyState._(
      mode: state.mode,
      phase: PrivacyPhase.ready,
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

    final gateway = ref.read(privacyGatewayProvider);
    if (gateway.mode == PrivacyMode.unavailable) {
      _publishFailure(
        mode: gateway.mode,
        previous: state,
        kind: PrivacyGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    final expectedVersion = state.resource!.version;
    final candidate = PrivacyValues.copyOf(state.draft);
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
    required PrivacyGateway gateway,
    required int generation,
    required int expectedVersion,
    required PrivacyValues candidate,
  }) async {
    final previous = state;
    state = PrivacyState._(
      mode: gateway.mode,
      phase: PrivacyPhase.saving,
      resource: previous.resource,
      draft: candidate,
    );
    try {
      final saved = PrivacyResource.copyOf(
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
          kind: PrivacyGatewayFailureKind.invalidData,
        );
        return;
      }
      state = PrivacyState._(
        mode: gateway.mode,
        phase: PrivacyPhase.ready,
        resource: saved,
        draft: saved.values,
      );
    } on PrivacyGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      if (error.kind == PrivacyGatewayFailureKind.versionConflict) {
        state = PrivacyState._(
          mode: gateway.mode,
          phase: PrivacyPhase.conflict,
          resource: previous.resource,
          draft: candidate,
          failureKind: error.kind,
          requiresReload: true,
        );
        return;
      }
      _publishFailure(
        mode: gateway.mode,
        previous: PrivacyState._(
          mode: previous.mode,
          phase: previous.phase,
          resource: previous.resource,
          draft: candidate,
        ),
        kind: error.kind,
      );
    } on InvalidPrivacyContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: PrivacyGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: PrivacyGatewayFailureKind.unexpected,
      );
    }
  }

  void _publishFailure({
    required PrivacyMode mode,
    required PrivacyState previous,
    required PrivacyGatewayFailureKind kind,
  }) {
    final unresolvedConflict = previous.requiresReload;
    state = PrivacyState._(
      mode: mode,
      phase: unresolvedConflict
          ? PrivacyPhase.conflict
          : previous.resource == null &&
                kind == PrivacyGatewayFailureKind.unavailable
          ? PrivacyPhase.unavailable
          : PrivacyPhase.failure,
      resource: previous.resource,
      draft: previous.draft,
      failureKind: kind,
      requiresReload: unresolvedConflict,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final privacyControllerProvider =
    NotifierProvider<PrivacyController, PrivacyState>(PrivacyController.new);
