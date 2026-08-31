import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';

enum GroupAliasPhase {
  initial,
  loading,
  ready,
  setting,
  unavailable,
  notFound,
  outcomeUnknown,
  failure,
}

@immutable
final class GroupAliasState {
  factory GroupAliasState({
    required GroupId groupId,
    required GroupAliasGatewayMode mode,
    required GroupAliasPhase phase,
    GroupAliasResource? resource,
    String? pendingAlias,
    GroupAliasGatewayFailureKind? failureKind,
  }) => GroupAliasState._(
    GroupId.copyOf(groupId),
    mode,
    phase,
    resource == null ? null : GroupAliasResource.copyOf(resource),
    pendingAlias == null ? null : normalizeGroupAlias(pendingAlias),
    failureKind,
  );

  const GroupAliasState._(
    this.groupId,
    this.mode,
    this.phase,
    this.resource,
    this.pendingAlias,
    this.failureKind,
  );

  factory GroupAliasState.initial(
    GroupId groupId,
    GroupAliasGatewayMode mode,
  ) => GroupAliasState(
    groupId: groupId,
    mode: mode,
    phase: mode == GroupAliasGatewayMode.unavailable
        ? GroupAliasPhase.unavailable
        : GroupAliasPhase.initial,
    failureKind: mode == GroupAliasGatewayMode.unavailable
        ? GroupAliasGatewayFailureKind.unavailable
        : null,
  );

  final GroupId groupId;
  final GroupAliasGatewayMode mode;
  final GroupAliasPhase phase;
  final GroupAliasResource? resource;

  /// Retained only when the PUT may have committed but no valid response was
  /// observed. A different value is unsafe until this exact Alias converges.
  final String? pendingAlias;
  final GroupAliasGatewayFailureKind? failureKind;

  bool get isBusy =>
      phase == GroupAliasPhase.loading || phase == GroupAliasPhase.setting;

  bool get hasImmutableAlias => resource != null;

  bool get canRetryPendingAlias =>
      phase == GroupAliasPhase.outcomeUnknown && pendingAlias != null;

  bool get canReserveNewAlias =>
      !isBusy &&
      mode != GroupAliasGatewayMode.unavailable &&
      resource == null &&
      pendingAlias == null &&
      failureKind != GroupAliasGatewayFailureKind.immutable;

  String? get failureCode => failureKind == null
      ? null
      : GroupAliasGatewayException(failureKind!).code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupAliasState &&
          other.groupId == groupId &&
          other.mode == mode &&
          other.phase == phase &&
          other.resource == resource &&
          other.pendingAlias == pendingAlias &&
          other.failureKind == failureKind;

  @override
  int get hashCode =>
      Object.hash(groupId, mode, phase, resource, pendingAlias, failureKind);
}

final class GroupAliasController extends Notifier<GroupAliasState> {
  GroupAliasController(this.groupId);

  final GroupId groupId;

  Future<void>? _operation;
  KeepAliveLink? _outcomeUnknownKeepAlive;
  var _generation = 0;

  @override
  GroupAliasState build() {
    _outcomeUnknownKeepAlive?.close();
    _outcomeUnknownKeepAlive = null;
    _generation += 1;
    _operation = null;
    final mode = ref.watch(groupAliasGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return GroupAliasState.initial(groupId, mode);
  }

  Future<void> load() {
    if (state.resource != null) return Future<void>.value();
    return _startLoad();
  }

  Future<void> reload() => _startLoad();

  Future<void> _startLoad() {
    final active = _operation;
    if (active != null) return active;
    final gateway = ref.read(groupAliasGatewayProvider);
    if (gateway.mode == GroupAliasGatewayMode.unavailable) {
      _publishLoadFailure(
        gateway.mode,
        state,
        GroupAliasGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    late final Future<void> operation;
    operation = _performLoad(gateway, generation).whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<void> _performLoad(GroupAliasGateway gateway, int generation) async {
    final previous = state;
    state = GroupAliasState(
      groupId: groupId,
      mode: gateway.mode,
      phase: GroupAliasPhase.loading,
      resource: previous.resource,
      pendingAlias: previous.pendingAlias,
    );
    try {
      final loaded = GroupAliasResource.copyOf(
        await gateway.loadCurrentAlias(groupId),
      );
      if (!_isCurrent(generation)) return;
      state = GroupAliasState(
        groupId: groupId,
        mode: gateway.mode,
        phase: GroupAliasPhase.ready,
        resource: loaded,
      );
      _releaseOutcomeUnknownRetention();
    } on GroupAliasGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishLoadFailure(gateway.mode, previous, error.kind);
    } on InvalidGroupAliasContractException {
      if (!_isCurrent(generation)) return;
      _publishLoadFailure(
        gateway.mode,
        previous,
        GroupAliasGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishLoadFailure(
        gateway.mode,
        previous,
        GroupAliasGatewayFailureKind.unexpected,
      );
    }
  }

  Future<void> reserveAlias(String rawAlias) {
    final active = _operation;
    if (active != null) return active;

    final unresolved = state.pendingAlias;
    late final String candidate;
    try {
      candidate = normalizeGroupAlias(rawAlias);
    } on InvalidGroupAliasContractException {
      if (unresolved != null) return Future<void>.value();
      state = GroupAliasState(
        groupId: groupId,
        mode: state.mode,
        phase: GroupAliasPhase.failure,
        resource: state.resource,
        pendingAlias: state.pendingAlias,
        failureKind: GroupAliasGatewayFailureKind.invalidData,
      );
      return Future<void>.value();
    }

    if (unresolved != null) {
      if (candidate != unresolved) return Future<void>.value();
      return _startPut(candidate);
    }

    if (state.failureKind == GroupAliasGatewayFailureKind.immutable &&
        state.resource == null) {
      return Future<void>.value();
    }

    final current = state.resource;
    if (current != null) {
      if (current.alias != candidate) {
        state = GroupAliasState(
          groupId: groupId,
          mode: state.mode,
          phase: GroupAliasPhase.failure,
          resource: current,
          failureKind: GroupAliasGatewayFailureKind.immutable,
        );
        return Future<void>.value();
      }
      if (current.projectionState == GroupAliasProjectionState.confirmed) {
        state = GroupAliasState(
          groupId: groupId,
          mode: state.mode,
          phase: GroupAliasPhase.ready,
          resource: current,
        );
        return Future<void>.value();
      }
    }
    return _startPut(candidate);
  }

  Future<void> retryPendingAlias() {
    final candidate = state.pendingAlias;
    if (candidate == null || state.phase != GroupAliasPhase.outcomeUnknown) {
      return Future<void>.value();
    }
    return _startPut(candidate);
  }

  Future<void> _startPut(String candidate) {
    final active = _operation;
    if (active != null) return active;
    final gateway = ref.read(groupAliasGatewayProvider);
    if (gateway.mode == GroupAliasGatewayMode.unavailable) {
      _publishPutFailure(
        gateway.mode,
        state,
        candidate,
        GroupAliasGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }

    // A PUT can commit after the last route listener disappears. Retain the
    // controller before issuing it so an in-flight result cannot be discarded
    // and followed by a conflicting immutable alias attempt on re-entry.
    _retainOutcomeUnknown();
    final generation = ++_generation;
    late final Future<void> operation;
    operation = _performPut(gateway, generation, candidate).whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<void> _performPut(
    GroupAliasGateway gateway,
    int generation,
    String candidate,
  ) async {
    final previous = state;
    state = GroupAliasState(
      groupId: groupId,
      mode: gateway.mode,
      phase: GroupAliasPhase.setting,
      resource: previous.resource,
      pendingAlias: previous.pendingAlias,
    );
    try {
      final saved = GroupAliasResource.copyOf(
        await gateway.putCurrentAlias(
          groupId: groupId,
          normalizedAlias: candidate,
        ),
      );
      if (!_isCurrent(generation)) return;
      if (saved.alias != candidate ||
          (previous.resource != null &&
              previous.resource!.groupAliasId != saved.groupAliasId)) {
        _publishPutFailure(
          gateway.mode,
          previous,
          candidate,
          GroupAliasGatewayFailureKind.invalidData,
        );
        return;
      }
      state = GroupAliasState(
        groupId: groupId,
        mode: gateway.mode,
        phase: GroupAliasPhase.ready,
        resource: saved,
      );
      _releaseOutcomeUnknownRetention();
    } on GroupAliasGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishPutFailure(gateway.mode, previous, candidate, error.kind);
    } on InvalidGroupAliasContractException {
      if (!_isCurrent(generation)) return;
      _publishPutFailure(
        gateway.mode,
        previous,
        candidate,
        GroupAliasGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishPutFailure(
        gateway.mode,
        previous,
        candidate,
        GroupAliasGatewayFailureKind.unexpected,
      );
    }
  }

  void _publishLoadFailure(
    GroupAliasGatewayMode mode,
    GroupAliasState previous,
    GroupAliasGatewayFailureKind kind,
  ) {
    if (previous.pendingAlias != null) {
      state = GroupAliasState(
        groupId: groupId,
        mode: mode,
        phase: GroupAliasPhase.outcomeUnknown,
        resource: previous.resource,
        pendingAlias: previous.pendingAlias,
        failureKind: GroupAliasGatewayFailureKind.outcomeUnknown,
      );
      _retainOutcomeUnknown();
      return;
    }
    state = GroupAliasState(
      groupId: groupId,
      mode: mode,
      phase: switch (kind) {
        GroupAliasGatewayFailureKind.unavailable => GroupAliasPhase.unavailable,
        GroupAliasGatewayFailureKind.notFound => GroupAliasPhase.notFound,
        _ => GroupAliasPhase.failure,
      },
      resource: previous.resource,
      failureKind: kind,
    );
  }

  void _publishPutFailure(
    GroupAliasGatewayMode mode,
    GroupAliasState previous,
    String candidate,
    GroupAliasGatewayFailureKind kind,
  ) {
    if (kind == GroupAliasGatewayFailureKind.outcomeUnknown) {
      state = GroupAliasState(
        groupId: groupId,
        mode: mode,
        phase: GroupAliasPhase.outcomeUnknown,
        resource: previous.resource,
        pendingAlias: candidate,
        failureKind: kind,
      );
      _retainOutcomeUnknown();
      return;
    }
    state = GroupAliasState(
      groupId: groupId,
      mode: mode,
      phase:
          kind == GroupAliasGatewayFailureKind.unavailable &&
              previous.resource == null
          ? GroupAliasPhase.unavailable
          : kind == GroupAliasGatewayFailureKind.notFound
          ? GroupAliasPhase.notFound
          : GroupAliasPhase.failure,
      resource: previous.resource,
      failureKind: kind,
    );
    _releaseOutcomeUnknownRetention();
  }

  void _retainOutcomeUnknown() {
    _outcomeUnknownKeepAlive ??= ref.keepAlive();
  }

  void _releaseOutcomeUnknownRetention() {
    _outcomeUnknownKeepAlive?.close();
    _outcomeUnknownKeepAlive = null;
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final groupAliasControllerProvider = NotifierProvider.autoDispose
    .family<GroupAliasController, GroupAliasState, GroupId>(
      GroupAliasController.new,
    );

enum GroupAliasResolverPhase {
  initial,
  resolving,
  resolved,
  unavailable,
  notFound,
  failure,
}

@immutable
final class GroupAliasResolverState {
  factory GroupAliasResolverState({
    required GroupAliasStreamChannelId channelId,
    required GroupAliasGatewayMode mode,
    required GroupAliasResolverPhase phase,
    GroupId? groupId,
    GroupAliasGatewayFailureKind? failureKind,
  }) => GroupAliasResolverState._(
    GroupAliasStreamChannelId.copyOf(channelId),
    mode,
    phase,
    groupId == null ? null : GroupId.copyOf(groupId),
    failureKind,
  );

  const GroupAliasResolverState._(
    this.channelId,
    this.mode,
    this.phase,
    this.groupId,
    this.failureKind,
  );

  factory GroupAliasResolverState.initial(
    GroupAliasStreamChannelId channelId,
    GroupAliasGatewayMode mode,
  ) => GroupAliasResolverState(
    channelId: channelId,
    mode: mode,
    phase: mode == GroupAliasGatewayMode.unavailable
        ? GroupAliasResolverPhase.unavailable
        : GroupAliasResolverPhase.initial,
    failureKind: mode == GroupAliasGatewayMode.unavailable
        ? GroupAliasGatewayFailureKind.unavailable
        : null,
  );

  final GroupAliasStreamChannelId channelId;
  final GroupAliasGatewayMode mode;
  final GroupAliasResolverPhase phase;
  final GroupId? groupId;
  final GroupAliasGatewayFailureKind? failureKind;

  bool get isBusy => phase == GroupAliasResolverPhase.resolving;
}

final class GroupAliasResolverController
    extends Notifier<GroupAliasResolverState> {
  GroupAliasResolverController(this.channelId);

  final GroupAliasStreamChannelId channelId;

  Future<void>? _operation;
  var _generation = 0;

  @override
  GroupAliasResolverState build() {
    _generation += 1;
    _operation = null;
    final mode = ref.watch(groupAliasResolverGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return GroupAliasResolverState.initial(channelId, mode);
  }

  Future<void> resolve() {
    final active = _operation;
    if (active != null) return active;
    final gateway = ref.read(groupAliasResolverGatewayProvider);
    if (gateway.mode == GroupAliasGatewayMode.unavailable) {
      state = GroupAliasResolverState.initial(channelId, gateway.mode);
      return Future<void>.value();
    }

    final generation = ++_generation;
    late final Future<void> operation;
    operation = _performResolve(gateway, generation).whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<void> _performResolve(
    GroupAliasResolverGateway gateway,
    int generation,
  ) async {
    state = GroupAliasResolverState(
      channelId: channelId,
      mode: gateway.mode,
      phase: GroupAliasResolverPhase.resolving,
    );
    try {
      final resolved = GroupId.copyOf(await gateway.resolveGroup(channelId));
      if (!_isCurrent(generation)) return;
      state = GroupAliasResolverState(
        channelId: channelId,
        mode: gateway.mode,
        phase: GroupAliasResolverPhase.resolved,
        groupId: resolved,
      );
    } on GroupAliasGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(gateway.mode, error.kind);
    } on InvalidGroupAliasContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(gateway.mode, GroupAliasGatewayFailureKind.invalidData);
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(gateway.mode, GroupAliasGatewayFailureKind.unexpected);
    }
  }

  void _publishFailure(
    GroupAliasGatewayMode mode,
    GroupAliasGatewayFailureKind kind,
  ) {
    state = GroupAliasResolverState(
      channelId: channelId,
      mode: mode,
      phase: switch (kind) {
        GroupAliasGatewayFailureKind.unavailable =>
          GroupAliasResolverPhase.unavailable,
        GroupAliasGatewayFailureKind.notFound =>
          GroupAliasResolverPhase.notFound,
        _ => GroupAliasResolverPhase.failure,
      },
      failureKind: kind,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final groupAliasResolverControllerProvider = NotifierProvider.autoDispose
    .family<
      GroupAliasResolverController,
      GroupAliasResolverState,
      GroupAliasStreamChannelId
    >(GroupAliasResolverController.new);

enum GroupAliasSearchPhase { idle, searching, ready, unavailable, failure }

@immutable
final class GroupAliasSearchState {
  factory GroupAliasSearchState({
    required GroupId groupId,
    required GroupAliasGatewayMode mode,
    required GroupAliasSearchPhase phase,
    String prefix = '',
    int limit = groupAliasSearchMaximumItems,
    GroupAliasSearchPage? page,
    GroupAliasGatewayFailureKind? failureKind,
  }) {
    validateGroupAliasSearchLimit(limit);
    return GroupAliasSearchState._(
      GroupId.copyOf(groupId),
      mode,
      phase,
      prefix,
      limit,
      GroupAliasSearchPage.copyOf(page ?? GroupAliasSearchPage.empty()),
      failureKind,
    );
  }

  const GroupAliasSearchState._(
    this.groupId,
    this.mode,
    this.phase,
    this.prefix,
    this.limit,
    this.page,
    this.failureKind,
  );

  factory GroupAliasSearchState.initial(
    GroupId groupId,
    GroupAliasGatewayMode mode,
  ) => GroupAliasSearchState(
    groupId: groupId,
    mode: mode,
    phase: mode == GroupAliasGatewayMode.unavailable
        ? GroupAliasSearchPhase.unavailable
        : GroupAliasSearchPhase.idle,
    failureKind: mode == GroupAliasGatewayMode.unavailable
        ? GroupAliasGatewayFailureKind.unavailable
        : null,
  );

  final GroupId groupId;
  final GroupAliasGatewayMode mode;
  final GroupAliasSearchPhase phase;
  final String prefix;
  final int limit;
  final GroupAliasSearchPage page;
  final GroupAliasGatewayFailureKind? failureKind;

  bool get isBusy => phase == GroupAliasSearchPhase.searching;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupAliasSearchState &&
          other.groupId == groupId &&
          other.mode == mode &&
          other.phase == phase &&
          other.prefix == prefix &&
          other.limit == limit &&
          other.page == page &&
          other.failureKind == failureKind;

  @override
  int get hashCode =>
      Object.hash(groupId, mode, phase, prefix, limit, page, failureKind);
}

final class GroupAliasSearchController extends Notifier<GroupAliasSearchState> {
  GroupAliasSearchController(this.groupId);

  final GroupId groupId;

  Future<void>? _operation;
  var _generation = 0;

  @override
  GroupAliasSearchState build() {
    _generation += 1;
    _operation = null;
    final mode = ref.watch(groupAliasGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return GroupAliasSearchState.initial(groupId, mode);
  }

  Future<void> search(
    String rawPrefix, {
    int limit = groupAliasSearchMaximumItems,
  }) {
    final active = _operation;
    if (active != null) return active;
    late final String prefix;
    try {
      prefix = normalizeGroupAliasSearchPrefix(rawPrefix);
      validateGroupAliasSearchLimit(limit);
    } on InvalidGroupAliasContractException {
      state = GroupAliasSearchState(
        groupId: groupId,
        mode: state.mode,
        phase: GroupAliasSearchPhase.failure,
        failureKind: GroupAliasGatewayFailureKind.invalidData,
      );
      return Future<void>.value();
    }

    final gateway = ref.read(groupAliasGatewayProvider);
    if (gateway.mode == GroupAliasGatewayMode.unavailable) {
      state = GroupAliasSearchState.initial(groupId, gateway.mode);
      return Future<void>.value();
    }

    final generation = ++_generation;
    late final Future<void> operation;
    operation = _performSearch(gateway, generation, prefix, limit).whenComplete(
      () {
        if (identical(_operation, operation)) _operation = null;
      },
    );
    _operation = operation;
    return operation;
  }

  Future<void> _performSearch(
    GroupAliasGateway gateway,
    int generation,
    String prefix,
    int limit,
  ) async {
    state = GroupAliasSearchState(
      groupId: groupId,
      mode: gateway.mode,
      phase: GroupAliasSearchPhase.searching,
      prefix: prefix,
      limit: limit,
    );
    try {
      final page = GroupAliasSearchPage.copyOf(
        await gateway.searchAliases(
          groupId: groupId,
          normalizedPrefix: prefix,
          limit: limit,
        ),
      );
      if (!_isCurrent(generation)) return;
      if (page.items.length > limit) {
        _publishFailure(
          gateway.mode,
          prefix,
          limit,
          GroupAliasGatewayFailureKind.invalidData,
        );
        return;
      }
      state = GroupAliasSearchState(
        groupId: groupId,
        mode: gateway.mode,
        phase: GroupAliasSearchPhase.ready,
        prefix: prefix,
        limit: limit,
        page: page,
      );
    } on GroupAliasGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(gateway.mode, prefix, limit, error.kind);
    } on InvalidGroupAliasContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        prefix,
        limit,
        GroupAliasGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        gateway.mode,
        prefix,
        limit,
        GroupAliasGatewayFailureKind.unexpected,
      );
    }
  }

  void _publishFailure(
    GroupAliasGatewayMode mode,
    String prefix,
    int limit,
    GroupAliasGatewayFailureKind kind,
  ) {
    state = GroupAliasSearchState(
      groupId: groupId,
      mode: mode,
      phase: kind == GroupAliasGatewayFailureKind.unavailable
          ? GroupAliasSearchPhase.unavailable
          : GroupAliasSearchPhase.failure,
      prefix: prefix,
      limit: limit,
      failureKind: kind,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final groupAliasSearchControllerProvider = NotifierProvider.autoDispose
    .family<GroupAliasSearchController, GroupAliasSearchState, GroupId>(
      GroupAliasSearchController.new,
    );
