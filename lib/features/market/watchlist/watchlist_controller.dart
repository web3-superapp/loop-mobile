import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';

enum WatchlistPhase {
  initial,
  loading,
  ready,
  saving,
  conflict,
  unavailable,
  failure,
}

@immutable
final class WatchlistState {
  factory WatchlistState._({
    required WatchlistMode mode,
    required WatchlistPhase phase,
    WatchlistSnapshot? snapshot,
    Iterable<WatchlistGroup> draftGroups = const <WatchlistGroup>[],
    WatchlistGatewayFailureKind? failureKind,
    bool requiresReload = false,
  }) {
    final copiedSnapshot = snapshot == null
        ? null
        : WatchlistSnapshot.copyOf(snapshot);
    final copiedDraft = validateWatchlistGroups(draftGroups);
    if (copiedSnapshot == null && copiedDraft.isNotEmpty) {
      throw const InvalidWatchlistContractException();
    }
    return WatchlistState._raw(
      mode: mode,
      phase: phase,
      snapshot: copiedSnapshot,
      draftGroups: copiedDraft,
      failureKind: failureKind,
      requiresReload: requiresReload,
    );
  }

  const WatchlistState._raw({
    required this.mode,
    required this.phase,
    required this.snapshot,
    required this.draftGroups,
    required this.failureKind,
    required this.requiresReload,
  });

  factory WatchlistState.initial(WatchlistMode mode) => WatchlistState._(
    mode: mode,
    phase: mode == WatchlistMode.unavailable
        ? WatchlistPhase.unavailable
        : WatchlistPhase.initial,
    failureKind: mode == WatchlistMode.unavailable
        ? WatchlistGatewayFailureKind.unavailable
        : null,
  );

  final WatchlistMode mode;
  final WatchlistPhase phase;
  final WatchlistSnapshot? snapshot;
  final List<WatchlistGroup> draftGroups;
  final WatchlistGatewayFailureKind? failureKind;

  /// A stale different write was rejected. Only a successful reload can make
  /// the draft editable and saveable again.
  final bool requiresReload;

  bool get isBusy =>
      phase == WatchlistPhase.loading || phase == WatchlistPhase.saving;

  bool get isDirty =>
      snapshot != null && !watchlistGroupsEqual(snapshot!.groups, draftGroups);

  bool get canEdit => snapshot != null && !isBusy && !requiresReload;

  bool get canSave => canEdit && isDirty;

  int? get expectedVersion => snapshot?.version;

  String? get failureCode =>
      failureKind == null ? null : WatchlistGatewayException(failureKind!).code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchlistState &&
          other.mode == mode &&
          other.phase == phase &&
          other.snapshot == snapshot &&
          listEquals(other.draftGroups, draftGroups) &&
          other.failureKind == failureKind &&
          other.requiresReload == requiresReload;

  @override
  int get hashCode => Object.hash(
    mode,
    phase,
    snapshot,
    Object.hashAll(draftGroups),
    failureKind,
    requiresReload,
  );
}

final class WatchlistController extends Notifier<WatchlistState> {
  Future<void>? _loadOperation;
  Future<void>? _saveOperation;
  var _generation = 0;

  @override
  WatchlistState build() {
    // A provider rotation retires every operation started by the previous
    // gateway. Clearing the slots also lets the replacement gateway start
    // immediately instead of being blocked by an obsolete single-flight.
    _generation += 1;
    _loadOperation = null;
    _saveOperation = null;
    final mode = ref.watch(watchlistGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return WatchlistState.initial(mode);
  }

  /// Loads only an uninitialized controller. Repeated lifecycle calls cannot
  /// silently replace an edited draft; that requires an explicit [reload].
  Future<void> load() {
    if (state.snapshot != null) return Future<void>.value();
    return _startLoad();
  }

  Future<void> reload() => _startLoad();

  Future<void> _startLoad() {
    final active = _loadOperation;
    if (active != null) return active;
    final saving = _saveOperation;
    if (saving != null) return saving;

    final gateway = ref.read(watchlistGatewayProvider);
    if (gateway.mode == WatchlistMode.unavailable) {
      state = WatchlistState._(
        mode: gateway.mode,
        phase: state.requiresReload
            ? WatchlistPhase.conflict
            : WatchlistPhase.unavailable,
        snapshot: state.snapshot,
        draftGroups: state.draftGroups,
        failureKind: WatchlistGatewayFailureKind.unavailable,
        requiresReload: state.requiresReload,
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

  Future<void> _performLoad(WatchlistGateway gateway, int generation) async {
    final previous = state;
    state = WatchlistState._(
      mode: gateway.mode,
      phase: WatchlistPhase.loading,
      snapshot: previous.snapshot,
      draftGroups: previous.draftGroups,
      requiresReload: previous.requiresReload,
    );
    try {
      final loaded = WatchlistSnapshot.copyOf(await gateway.load());
      if (!_isCurrent(generation)) return;
      state = WatchlistState._(
        mode: gateway.mode,
        phase: WatchlistPhase.ready,
        snapshot: loaded,
        draftGroups: loaded.groups,
      );
    } on WatchlistGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(mode: gateway.mode, previous: previous, kind: error.kind);
    } on InvalidWatchlistContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: WatchlistGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: WatchlistGatewayFailureKind.unexpected,
      );
    }
  }

  void editGroup({required String groupKey, required String name}) {
    _mutate((groups) {
      final index = groups.indexWhere((group) => group.key == groupKey);
      _requireFound(index);
      groups[index] = groups[index].copyWith(name: name);
      return groups;
    });
  }

  void addGroup(WatchlistGroup group) {
    _mutate((groups) => <WatchlistGroup>[...groups, group]);
  }

  void removeGroup(String groupKey) {
    _mutate((groups) {
      final index = groups.indexWhere((group) => group.key == groupKey);
      _requireFound(index);
      groups.removeAt(index);
      return groups;
    });
  }

  void reorderGroup({required int fromIndex, required int toIndex}) {
    _mutate((groups) {
      _requireIndex(fromIndex, groups.length);
      _requireIndex(toIndex, groups.length);
      final moved = groups.removeAt(fromIndex);
      groups.insert(toIndex, moved);
      return groups;
    });
  }

  void addItem({required String groupKey, required WatchlistItem item}) {
    _mutate((groups) {
      final index = groups.indexWhere((group) => group.key == groupKey);
      _requireFound(index);
      groups[index] = groups[index].copyWith(
        items: <WatchlistItem>[...groups[index].items, item],
      );
      return groups;
    });
  }

  void removeItem({required String groupKey, required String assetKey}) {
    _mutate((groups) {
      final groupIndex = groups.indexWhere((group) => group.key == groupKey);
      _requireFound(groupIndex);
      final items = groups[groupIndex].items.toList(growable: true);
      final itemIndex = items.indexWhere((item) => item.assetKey == assetKey);
      _requireFound(itemIndex);
      items.removeAt(itemIndex);
      groups[groupIndex] = groups[groupIndex].copyWith(items: items);
      return groups;
    });
  }

  void reorderItem({
    required String groupKey,
    required int fromIndex,
    required int toIndex,
  }) {
    _mutate((groups) {
      final groupIndex = groups.indexWhere((group) => group.key == groupKey);
      _requireFound(groupIndex);
      final items = groups[groupIndex].items.toList(growable: true);
      _requireIndex(fromIndex, items.length);
      _requireIndex(toIndex, items.length);
      final moved = items.removeAt(fromIndex);
      items.insert(toIndex, moved);
      groups[groupIndex] = groups[groupIndex].copyWith(items: items);
      return groups;
    });
  }

  void discard() {
    final snapshot = state.snapshot;
    if (snapshot == null || state.isBusy) return;
    state = WatchlistState._(
      mode: state.mode,
      phase: state.requiresReload
          ? WatchlistPhase.conflict
          : WatchlistPhase.ready,
      snapshot: snapshot,
      draftGroups: snapshot.groups,
      failureKind: state.requiresReload
          ? WatchlistGatewayFailureKind.versionConflict
          : null,
      requiresReload: state.requiresReload,
    );
  }

  Future<void> save() {
    final active = _saveOperation;
    if (active != null) return active;
    final loading = _loadOperation;
    if (loading != null) return loading;
    if (!state.canSave) return Future<void>.value();

    final gateway = ref.read(watchlistGatewayProvider);
    if (gateway.mode == WatchlistMode.unavailable) {
      state = WatchlistState._(
        mode: gateway.mode,
        phase: WatchlistPhase.unavailable,
        snapshot: state.snapshot,
        draftGroups: state.draftGroups,
        failureKind: WatchlistGatewayFailureKind.unavailable,
      );
      return Future<void>.value();
    }

    final generation = ++_generation;
    final expectedVersion = state.snapshot!.version;
    final candidate = validateWatchlistGroups(state.draftGroups);
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
    required WatchlistGateway gateway,
    required int generation,
    required int expectedVersion,
    required List<WatchlistGroup> candidate,
  }) async {
    final previous = state;
    state = WatchlistState._(
      mode: gateway.mode,
      phase: WatchlistPhase.saving,
      snapshot: previous.snapshot,
      draftGroups: candidate,
    );
    try {
      final saved = WatchlistSnapshot.copyOf(
        await gateway.replace(
          expectedVersion: expectedVersion,
          groups: candidate,
        ),
      );
      if (!_isCurrent(generation)) return;
      if (saved.version <= expectedVersion ||
          !watchlistGroupsEqual(saved.groups, candidate)) {
        _publishFailure(
          mode: gateway.mode,
          previous: previous,
          kind: WatchlistGatewayFailureKind.invalidData,
        );
        return;
      }
      state = WatchlistState._(
        mode: gateway.mode,
        phase: WatchlistPhase.ready,
        snapshot: saved,
        draftGroups: saved.groups,
      );
    } on WatchlistGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      if (error.kind == WatchlistGatewayFailureKind.versionConflict) {
        state = WatchlistState._(
          mode: gateway.mode,
          phase: WatchlistPhase.conflict,
          snapshot: previous.snapshot,
          draftGroups: candidate,
          failureKind: error.kind,
          requiresReload: true,
        );
        return;
      }
      _publishFailure(
        mode: gateway.mode,
        previous: WatchlistState._(
          mode: previous.mode,
          phase: previous.phase,
          snapshot: previous.snapshot,
          draftGroups: candidate,
        ),
        kind: error.kind,
      );
    } on InvalidWatchlistContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: WatchlistGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        mode: gateway.mode,
        previous: previous,
        kind: WatchlistGatewayFailureKind.unexpected,
      );
    }
  }

  void _mutate(
    List<WatchlistGroup> Function(List<WatchlistGroup> groups) mutation,
  ) {
    if (!state.canEdit) {
      throw StateError('Watchlist is not editable');
    }
    final current = state.draftGroups.toList(growable: true);
    final updated = validateWatchlistGroups(mutation(current));
    state = WatchlistState._(
      mode: state.mode,
      phase: WatchlistPhase.ready,
      snapshot: state.snapshot,
      draftGroups: updated,
    );
  }

  void _publishFailure({
    required WatchlistMode mode,
    required WatchlistState previous,
    required WatchlistGatewayFailureKind kind,
  }) {
    final unresolvedConflict = previous.requiresReload;
    state = WatchlistState._(
      mode: mode,
      phase: unresolvedConflict
          ? WatchlistPhase.conflict
          : previous.snapshot == null &&
                kind == WatchlistGatewayFailureKind.unavailable
          ? WatchlistPhase.unavailable
          : WatchlistPhase.failure,
      snapshot: previous.snapshot,
      draftGroups: previous.draftGroups,
      failureKind: kind,
      requiresReload: unresolvedConflict,
    );
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;

  static void _requireFound(int index) {
    if (index < 0) throw const InvalidWatchlistContractException();
  }

  static void _requireIndex(int index, int length) {
    if (index < 0 || index >= length) {
      throw const InvalidWatchlistContractException();
    }
  }
}

final watchlistControllerProvider =
    NotifierProvider<WatchlistController, WatchlistState>(
      WatchlistController.new,
    );
