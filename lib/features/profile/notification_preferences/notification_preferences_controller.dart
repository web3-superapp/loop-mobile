import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_gateway.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_models.dart';

enum NotificationPreferencesPhase {
  initial,
  loading,
  ready,
  saving,
  conflict,
  unavailable,
  failure,
}

@immutable
final class NotificationPreferencesState {
  factory NotificationPreferencesState._({
    required NotificationPreferencesMode mode,
    required NotificationPreferencesPhase phase,
    NotificationPreferencesResource? resource,
    NotificationPreferenceValues? draft,
    NotificationPreferencesGatewayFailureKind? failureKind,
    bool requiresReload = false,
  }) {
    final copiedResource = resource == null
        ? null
        : NotificationPreferencesResource.copyOf(resource);
    final copiedDraft = NotificationPreferenceValues.copyOf(
      draft ??
          copiedResource?.values ??
          const NotificationPreferenceValues.disabled(),
    );
    if (copiedResource == null &&
        copiedDraft != const NotificationPreferenceValues.disabled()) {
      throw const InvalidNotificationPreferencesContractException();
    }
    return NotificationPreferencesState._raw(
      mode: mode,
      phase: phase,
      resource: copiedResource,
      draft: copiedDraft,
      failureKind: failureKind,
      requiresReload: requiresReload,
    );
  }

  const NotificationPreferencesState._raw({
    required this.mode,
    required this.phase,
    required this.resource,
    required this.draft,
    required this.failureKind,
    required this.requiresReload,
  });

  factory NotificationPreferencesState.initial(
    NotificationPreferencesMode mode,
  ) => NotificationPreferencesState._(
    mode: mode,
    phase: mode == NotificationPreferencesMode.unavailable
        ? NotificationPreferencesPhase.unavailable
        : NotificationPreferencesPhase.initial,
    failureKind: mode == NotificationPreferencesMode.unavailable
        ? NotificationPreferencesGatewayFailureKind.unavailable
        : null,
  );

  final NotificationPreferencesMode mode;
  final NotificationPreferencesPhase phase;
  final NotificationPreferencesResource? resource;
  final NotificationPreferenceValues draft;
  final NotificationPreferencesGatewayFailureKind? failureKind;
  final bool requiresReload;

  bool get isBusy =>
      phase == NotificationPreferencesPhase.loading ||
      phase == NotificationPreferencesPhase.saving;

  bool get isDirty => resource != null && resource!.values != draft;

  bool get canEdit => resource != null && !isBusy && !requiresReload;

  bool get canSave => canEdit && isDirty;

  int? get expectedVersion => resource?.version;

  String? get failureCode => failureKind == null
      ? null
      : NotificationPreferencesGatewayException(failureKind!).code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferencesState &&
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

final class NotificationPreferencesController
    extends Notifier<NotificationPreferencesState> {
  Future<void>? _loadOperation;
  Future<void>? _saveOperation;
  var _generation = 0;

  @override
  NotificationPreferencesState build() {
    _generation += 1;
    _loadOperation = null;
    _saveOperation = null;
    final mode = ref.watch(notificationPreferencesGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return NotificationPreferencesState.initial(mode);
  }

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

    final gateway = ref.read(notificationPreferencesGatewayProvider);
    if (gateway.mode == NotificationPreferencesMode.unavailable) {
      _publishFailure(
        mode: gateway.mode,
        previous: state,
        kind: NotificationPreferencesGatewayFailureKind.unavailable,
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

  Future<void> _performLoad(
    NotificationPreferencesGateway gateway,
    int generation,
  ) async {
    final previous = state;
    state = NotificationPreferencesState._(
      mode: gateway.mode,
      phase: NotificationPreferencesPhase.loading,
      resource: previous.resource,
      draft: previous.draft,
      requiresReload: previous.requiresReload,
    );
    try {
      final loaded = NotificationPreferencesResource.copyOf(
        await gateway.load(),
      );
      if (!_isCurrent(generation)) return;
      state = NotificationPreferencesState._(
        mode: gateway.mode,
        phase: NotificationPreferencesPhase.ready,
        resource: loaded,
        draft: loaded.values,
      );
    } on NotificationPreferencesGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(mode: gateway.mode, previous: previous, kind: error.kind);
    } on InvalidNotificationPreferencesContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: NotificationPreferencesGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: NotificationPreferencesGatewayFailureKind.unexpected,
      );
    }
  }

  void edit(NotificationPreferenceEvent event, bool enabled) {
    if (!state.canEdit) {
      throw StateError('Notification preferences are not editable');
    }
    state = NotificationPreferencesState._(
      mode: state.mode,
      phase: NotificationPreferencesPhase.ready,
      resource: state.resource,
      draft: state.draft.withEvent(event, enabled),
    );
  }

  void discard() {
    final resource = state.resource;
    if (resource == null || state.isBusy || state.requiresReload) return;
    state = NotificationPreferencesState._(
      mode: state.mode,
      phase: NotificationPreferencesPhase.ready,
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

    final gateway = ref.read(notificationPreferencesGatewayProvider);
    if (gateway.mode == NotificationPreferencesMode.unavailable) {
      _publishFailure(
        mode: gateway.mode,
        previous: state,
        kind: NotificationPreferencesGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    final expectedVersion = state.resource!.version;
    final candidate = NotificationPreferenceValues.copyOf(state.draft);
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
    required NotificationPreferencesGateway gateway,
    required int generation,
    required int expectedVersion,
    required NotificationPreferenceValues candidate,
  }) async {
    final previous = state;
    state = NotificationPreferencesState._(
      mode: gateway.mode,
      phase: NotificationPreferencesPhase.saving,
      resource: previous.resource,
      draft: candidate,
    );
    try {
      final saved = NotificationPreferencesResource.copyOf(
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
          kind: NotificationPreferencesGatewayFailureKind.invalidData,
        );
        return;
      }
      state = NotificationPreferencesState._(
        mode: gateway.mode,
        phase: NotificationPreferencesPhase.ready,
        resource: saved,
        draft: saved.values,
      );
    } on NotificationPreferencesGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      if (error.kind ==
          NotificationPreferencesGatewayFailureKind.versionConflict) {
        state = NotificationPreferencesState._(
          mode: gateway.mode,
          phase: NotificationPreferencesPhase.conflict,
          resource: previous.resource,
          draft: candidate,
          failureKind: error.kind,
          requiresReload: true,
        );
        return;
      }
      _publishFailure(
        mode: gateway.mode,
        previous: NotificationPreferencesState._(
          mode: previous.mode,
          phase: previous.phase,
          resource: previous.resource,
          draft: candidate,
        ),
        kind: error.kind,
      );
    } on InvalidNotificationPreferencesContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: NotificationPreferencesGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: NotificationPreferencesGatewayFailureKind.unexpected,
      );
    }
  }

  void _publishFailure({
    required NotificationPreferencesMode mode,
    required NotificationPreferencesState previous,
    required NotificationPreferencesGatewayFailureKind kind,
  }) {
    final unresolvedConflict = previous.requiresReload;
    state = NotificationPreferencesState._(
      mode: mode,
      phase: unresolvedConflict
          ? NotificationPreferencesPhase.conflict
          : previous.resource == null &&
                mode == NotificationPreferencesMode.unavailable &&
                kind == NotificationPreferencesGatewayFailureKind.unavailable
          ? NotificationPreferencesPhase.unavailable
          : NotificationPreferencesPhase.failure,
      resource: previous.resource,
      draft: previous.draft,
      failureKind: kind,
      requiresReload: unresolvedConflict,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final notificationPreferencesControllerProvider =
    NotifierProvider<
      NotificationPreferencesController,
      NotificationPreferencesState
    >(NotificationPreferencesController.new);
