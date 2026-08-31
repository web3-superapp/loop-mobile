import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_models.dart';

enum SocialPrivacyPhase {
  initial,
  loading,
  ready,
  saving,
  conflict,
  unavailable,
  failure,
}

@immutable
final class SocialPrivacyState {
  factory SocialPrivacyState._({
    required SocialPrivacyMode mode,
    required SocialPrivacyPhase phase,
    SocialPrivacyResource? resource,
    SocialPrivacyValues? draft,
    SocialPrivacyGatewayFailureKind? failureKind,
    bool requiresReload = false,
  }) {
    final copiedResource = resource == null
        ? null
        : SocialPrivacyResource.copyOf(resource);
    final copiedDraft = SocialPrivacyValues.copyOf(
      draft ?? copiedResource?.values ?? const SocialPrivacyValues.defaults(),
    );
    if (copiedResource == null &&
        copiedDraft != const SocialPrivacyValues.defaults()) {
      throw const InvalidSocialPrivacyContractException();
    }
    return SocialPrivacyState._raw(
      mode: mode,
      phase: phase,
      resource: copiedResource,
      draft: copiedDraft,
      failureKind: failureKind,
      requiresReload: requiresReload,
    );
  }

  const SocialPrivacyState._raw({
    required this.mode,
    required this.phase,
    required this.resource,
    required this.draft,
    required this.failureKind,
    required this.requiresReload,
  });

  factory SocialPrivacyState.initial(SocialPrivacyMode mode) =>
      SocialPrivacyState._(
        mode: mode,
        phase: mode == SocialPrivacyMode.unavailable
            ? SocialPrivacyPhase.unavailable
            : SocialPrivacyPhase.initial,
        failureKind: mode == SocialPrivacyMode.unavailable
            ? SocialPrivacyGatewayFailureKind.unavailable
            : null,
      );

  final SocialPrivacyMode mode;
  final SocialPrivacyPhase phase;
  final SocialPrivacyResource? resource;
  final SocialPrivacyValues draft;
  final SocialPrivacyGatewayFailureKind? failureKind;

  /// A stale different write was rejected. Only a successful reload can make
  /// the draft editable and saveable again.
  final bool requiresReload;

  bool get isBusy =>
      phase == SocialPrivacyPhase.loading || phase == SocialPrivacyPhase.saving;

  bool get isDirty => resource != null && resource!.values != draft;

  bool get canEdit => resource != null && !isBusy && !requiresReload;

  bool get canSave => canEdit && isDirty;

  int? get expectedVersion => resource?.version;

  String? get failureCode => failureKind == null
      ? null
      : SocialPrivacyGatewayException(failureKind!).code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SocialPrivacyState &&
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

final class SocialPrivacyController extends Notifier<SocialPrivacyState> {
  Future<void>? _loadOperation;
  Future<void>? _saveOperation;
  var _generation = 0;

  @override
  SocialPrivacyState build() {
    _generation += 1;
    _loadOperation = null;
    _saveOperation = null;
    final mode = ref.watch(socialPrivacyGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return SocialPrivacyState.initial(mode);
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

    final gateway = ref.read(socialPrivacyGatewayProvider);
    if (gateway.mode == SocialPrivacyMode.unavailable) {
      _publishFailure(
        mode: gateway.mode,
        previous: state,
        kind: SocialPrivacyGatewayFailureKind.unavailable,
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
    SocialPrivacyGateway gateway,
    int generation,
  ) async {
    final previous = state;
    state = SocialPrivacyState._(
      mode: gateway.mode,
      phase: SocialPrivacyPhase.loading,
      resource: previous.resource,
      draft: previous.draft,
      requiresReload: previous.requiresReload,
    );
    try {
      final loaded = SocialPrivacyResource.copyOf(await gateway.load());
      if (!_isCurrent(generation)) return;
      state = SocialPrivacyState._(
        mode: gateway.mode,
        phase: SocialPrivacyPhase.ready,
        resource: loaded,
        draft: loaded.values,
      );
    } on SocialPrivacyGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(mode: gateway.mode, previous: previous, kind: error.kind);
    } on InvalidSocialPrivacyContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: SocialPrivacyGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: SocialPrivacyGatewayFailureKind.unexpected,
      );
    }
  }

  void editFriendRequests(FriendRequestsPreference value) {
    if (!state.canEdit) throw StateError('Social Privacy is not editable');
    state = SocialPrivacyState._(
      mode: state.mode,
      phase: SocialPrivacyPhase.ready,
      resource: state.resource,
      draft: state.draft.withFriendRequests(value),
    );
  }

  void editGroupInvites(GroupInvitesPreference value) {
    if (!state.canEdit) throw StateError('Social Privacy is not editable');
    state = SocialPrivacyState._(
      mode: state.mode,
      phase: SocialPrivacyPhase.ready,
      resource: state.resource,
      draft: state.draft.withGroupInvites(value),
    );
  }

  void editDirectMessages(DirectMessagesPreference value) {
    if (!state.canEdit) throw StateError('Social Privacy is not editable');
    state = SocialPrivacyState._(
      mode: state.mode,
      phase: SocialPrivacyPhase.ready,
      resource: state.resource,
      draft: state.draft.withDirectMessages(value),
    );
  }

  void discard() {
    final resource = state.resource;
    if (resource == null || state.isBusy || state.requiresReload) return;
    state = SocialPrivacyState._(
      mode: state.mode,
      phase: SocialPrivacyPhase.ready,
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

    final gateway = ref.read(socialPrivacyGatewayProvider);
    if (gateway.mode == SocialPrivacyMode.unavailable) {
      _publishFailure(
        mode: gateway.mode,
        previous: state,
        kind: SocialPrivacyGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    final expectedVersion = state.resource!.version;
    final candidate = SocialPrivacyValues.copyOf(state.draft);
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
    required SocialPrivacyGateway gateway,
    required int generation,
    required int expectedVersion,
    required SocialPrivacyValues candidate,
  }) async {
    final previous = state;
    state = SocialPrivacyState._(
      mode: gateway.mode,
      phase: SocialPrivacyPhase.saving,
      resource: previous.resource,
      draft: candidate,
    );
    try {
      final saved = SocialPrivacyResource.copyOf(
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
          kind: SocialPrivacyGatewayFailureKind.invalidData,
        );
        return;
      }
      state = SocialPrivacyState._(
        mode: gateway.mode,
        phase: SocialPrivacyPhase.ready,
        resource: saved,
        draft: saved.values,
      );
    } on SocialPrivacyGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      if (error.kind == SocialPrivacyGatewayFailureKind.versionConflict) {
        state = SocialPrivacyState._(
          mode: gateway.mode,
          phase: SocialPrivacyPhase.conflict,
          resource: previous.resource,
          draft: candidate,
          failureKind: error.kind,
          requiresReload: true,
        );
        return;
      }
      _publishFailure(
        mode: gateway.mode,
        previous: SocialPrivacyState._(
          mode: previous.mode,
          phase: previous.phase,
          resource: previous.resource,
          draft: candidate,
        ),
        kind: error.kind,
      );
    } on InvalidSocialPrivacyContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: SocialPrivacyGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: SocialPrivacyGatewayFailureKind.unexpected,
      );
    }
  }

  void _publishFailure({
    required SocialPrivacyMode mode,
    required SocialPrivacyState previous,
    required SocialPrivacyGatewayFailureKind kind,
  }) {
    final unresolvedConflict = previous.requiresReload;
    state = SocialPrivacyState._(
      mode: mode,
      phase: unresolvedConflict
          ? SocialPrivacyPhase.conflict
          : previous.resource == null &&
                kind == SocialPrivacyGatewayFailureKind.unavailable
          ? SocialPrivacyPhase.unavailable
          : SocialPrivacyPhase.failure,
      resource: previous.resource,
      draft: previous.draft,
      failureKind: kind,
      requiresReload: unresolvedConflict,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final socialPrivacyControllerProvider =
    NotifierProvider<SocialPrivacyController, SocialPrivacyState>(
      SocialPrivacyController.new,
    );
