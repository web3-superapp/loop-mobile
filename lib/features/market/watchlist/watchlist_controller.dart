import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';

/// Editor state for `watchlist-edit`.
///
/// The committed [snapshot] is the server truth; [draft] is the local edit.
/// A save is a whole-resource compare-and-set on `snapshot.version`, so a
/// conflict never silently overwrites another device's list.
@immutable
final class WatchlistEditorState {
  const WatchlistEditorState({
    required this.mode,
    required this.phase,
    this.snapshot,
    this.draft,
    this.selectedGroupIndex = 0,
    this.failureKind,
    this.busy = false,
    this.requiresReload = false,
  });

  factory WatchlistEditorState.initial(LoopChainGatewayMode mode) {
    final closed = mode == LoopChainGatewayMode.unavailable;
    return WatchlistEditorState(
      mode: mode,
      phase: closed
          ? LoopChainViewPhase.unavailable
          : LoopChainViewPhase.loading,
      failureKind: closed ? LoopChainFailureKind.unavailable : null,
    );
  }

  final LoopChainGatewayMode mode;
  final LoopChainViewPhase phase;
  final WatchlistSnapshot? snapshot;
  final List<WatchlistGroup>? draft;
  final int selectedGroupIndex;
  final LoopChainFailureKind? failureKind;
  final bool busy;

  /// A version conflict happened: the draft is kept, but it may not be applied
  /// again until the latest resource has been reloaded.
  final bool requiresReload;

  bool get isReady => phase == LoopChainViewPhase.ready && snapshot != null;

  List<WatchlistGroup> get groups =>
      draft ?? snapshot?.groups ?? const <WatchlistGroup>[];

  WatchlistGroup? get selectedGroup =>
      selectedGroupIndex >= 0 && selectedGroupIndex < groups.length
      ? groups[selectedGroupIndex]
      : null;

  int get itemCount {
    var total = 0;
    for (final group in groups) {
      total += group.items.length;
    }
    return total;
  }

  bool get isDirty {
    final committed = snapshot?.groups;
    final current = draft;
    if (committed == null || current == null) return false;
    return !listEquals(committed, current);
  }

  bool get canSave => isDirty && !busy && !requiresReload;

  /// A one-line description of what this draft changes, per group.
  ///
  /// It compares the draft against the version the page was rendered from, so
  /// after a conflict the user can see what a reload would discard before
  /// choosing to discard it.
  List<String> get draftChanges {
    final committed = snapshot?.groups;
    final current = draft;
    if (committed == null || current == null) return const <String>[];
    final changes = <String>[];
    final committedByKey = <String, WatchlistGroup>{
      for (final group in committed) group.key: group,
    };
    for (final group in current) {
      final before = committedByKey.remove(group.key);
      if (before == null) {
        changes.add('新增分组 ${group.name}');
        continue;
      }
      final beforeIds = before.items
          .map((item) => item.assetId)
          .toList(growable: false);
      final afterIds = group.items
          .map((item) => item.assetId)
          .toList(growable: false);
      if (listEquals(beforeIds, afterIds)) continue;
      final removed = beforeIds.where((id) => !afterIds.contains(id)).length;
      final added = afterIds.where((id) => !beforeIds.contains(id)).length;
      final reordered = removed == 0 && added == 0;
      changes.add(
        '${group.name}：'
        '${reordered ? '重新排序' : <String>[if (added > 0) '新增 $added 项', if (removed > 0) '移除 $removed 项'].join('，')}',
      );
    }
    for (final group in committedByKey.values) {
      changes.add('移除分组 ${group.name}');
    }
    return List<String>.unmodifiable(changes);
  }

  /// The draft as plain text, so it can survive a reload on the clipboard.
  String get draftAsText {
    final buffer = StringBuffer('LOOP 自选草稿（基于版本 ${snapshot?.version ?? 0}）');
    for (final group in groups) {
      buffer.write('\n${group.name} [${group.key}]');
      for (final item in group.items) {
        buffer.write('\n  ${item.assetId}');
      }
    }
    return buffer.toString();
  }

  WatchlistEditorState copyWith({
    LoopChainViewPhase? phase,
    WatchlistSnapshot? snapshot,
    List<WatchlistGroup>? draft,
    int? selectedGroupIndex,
    LoopChainFailureKind? failureKind,
    bool clearFailure = false,
    bool? busy,
    bool? requiresReload,
  }) => WatchlistEditorState(
    mode: mode,
    phase: phase ?? this.phase,
    snapshot: snapshot ?? this.snapshot,
    draft: draft ?? this.draft,
    selectedGroupIndex: selectedGroupIndex ?? this.selectedGroupIndex,
    failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    busy: busy ?? this.busy,
    requiresReload: requiresReload ?? this.requiresReload,
  );
}

final class WatchlistEditorController extends Notifier<WatchlistEditorState>
    with LoopChainSingleFlight {
  @override
  WatchlistEditorState build() {
    nextGeneration();
    final mode = ref.watch(
      watchlistGatewayProvider.select((gateway) => gateway.mode),
    );
    ref.onDispose(nextGeneration);
    return WatchlistEditorState.initial(mode);
  }

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final generation = nextGeneration();
    state = state.copyWith(
      phase: state.snapshot == null
          ? LoopChainViewPhase.loading
          : LoopChainViewPhase.ready,
      clearFailure: true,
    );
    try {
      final snapshot = await ref.read(watchlistGatewayProvider).load();
      if (!isCurrent(generation)) return;
      state = WatchlistEditorState(
        mode: state.mode,
        phase: LoopChainViewPhase.ready,
        snapshot: snapshot,
        draft: snapshot.groups,
        selectedGroupIndex: state.selectedGroupIndex < snapshot.groups.length
            ? state.selectedGroupIndex
            : 0,
      );
    } on LoopChainException catch (error) {
      if (!isCurrent(generation)) return;
      _fail(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      _fail(LoopChainFailureKind.unexpected);
    }
  });

  void selectGroup(int index) {
    if (index < 0 || index >= state.groups.length) return;
    state = state.copyWith(selectedGroupIndex: index);
  }

  /// Reorders one row inside the selected group.
  ///
  /// [newIndex] is the final destination index (the caller has already
  /// accounted for the removal). Ordering is the whole point of the Watchlist,
  /// so it travels in the compare-and-set payload.
  void reorder(int oldIndex, int newIndex) {
    final group = state.selectedGroup;
    if (group == null) return;
    if (oldIndex < 0 || oldIndex >= group.items.length) return;
    if (newIndex < 0 ||
        newIndex >= group.items.length ||
        newIndex == oldIndex) {
      return;
    }
    final items = List<WatchlistItem>.of(group.items);
    items.insert(newIndex, items.removeAt(oldIndex));
    _replaceSelected(group.copyWith(items: items));
  }

  void removeAt(int index) {
    final group = state.selectedGroup;
    if (group == null || index < 0 || index >= group.items.length) return;
    final items = List<WatchlistItem>.of(group.items)..removeAt(index);
    _replaceSelected(group.copyWith(items: items));
  }

  void discard() {
    final snapshot = state.snapshot;
    if (snapshot == null) return;
    state = state.copyWith(
      draft: snapshot.groups,
      clearFailure: true,
      requiresReload: false,
    );
  }

  Future<bool> save() async {
    final snapshot = state.snapshot;
    final draft = state.draft;
    if (snapshot == null || draft == null || !state.canSave) return false;
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      final next = await ref
          .read(watchlistGatewayProvider)
          .replace(expectedVersion: snapshot.version, groups: draft);
      state = WatchlistEditorState(
        mode: state.mode,
        phase: LoopChainViewPhase.ready,
        snapshot: next,
        draft: next.groups,
        selectedGroupIndex: state.selectedGroupIndex < next.groups.length
            ? state.selectedGroupIndex
            : 0,
      );
      return true;
    } on LoopChainException catch (error) {
      state = state.copyWith(
        busy: false,
        failureKind: error.kind,
        requiresReload: error.kind == LoopChainFailureKind.versionConflict,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        failureKind: LoopChainFailureKind.unexpected,
      );
      return false;
    }
  }

  void _replaceSelected(WatchlistGroup next) {
    final groups = List<WatchlistGroup>.of(state.groups);
    groups[state.selectedGroupIndex] = next;
    state = state.copyWith(draft: groups, clearFailure: true);
  }

  void _fail(LoopChainFailureKind kind) {
    state = state.copyWith(
      phase: state.snapshot == null
          ? loopChainPhaseForFailure(kind)
          : LoopChainViewPhase.ready,
      failureKind: kind,
      busy: false,
    );
  }
}

final watchlistEditorControllerProvider =
    NotifierProvider.autoDispose<
      WatchlistEditorController,
      WatchlistEditorState
    >(WatchlistEditorController.new);
