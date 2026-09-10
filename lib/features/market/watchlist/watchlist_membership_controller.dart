import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';

/// What one star press did.
///
/// [added] and [removed] are committed facts, because the server answered with
/// the resource that now exists. The two limit outcomes are refusals this
/// client made *before* writing, so they name the limit rather than borrowing
/// the server's `VALIDATION_FAILED` sentence — which says the asset is not
/// registered, and would be a lie here. [failed] is the only outcome that
/// carries a server reason.
enum WatchlistToggleOutcome {
  added,
  removed,

  /// The document already holds `watchlistMaxItems` assets.
  itemLimitReached,

  /// There is no default group and no room to create one.
  groupLimitReached,
  failed,
}

/// A refusal composed on device: no request was made.
final class _WatchlistLimitReached implements Exception {
  const _WatchlistLimitReached(this.outcome);

  final WatchlistToggleOutcome outcome;
}

@immutable
final class WatchlistToggleResult {
  const WatchlistToggleResult(this.outcome, {this.failureKind});

  final WatchlistToggleOutcome outcome;
  final LoopChainFailureKind? failureKind;
}

/// Whether one asset is watched, and the single write that changes it.
///
/// `PUT /v2/watchlist` replaces the whole document under `expectedVersion`, so
/// membership cannot be toggled without first reading the list. This state is
/// therefore three answers, not two: watched, not watched, and not read yet —
/// and the star must never render the third as the second.
@immutable
final class WatchlistMembershipState {
  const WatchlistMembershipState({
    required this.mode,
    required this.phase,
    required this.assetId,
    this.snapshot,
    this.failureKind,
    this.busy = false,
  });

  factory WatchlistMembershipState.initial(
    LoopChainGatewayMode mode,
    String assetId,
  ) {
    final closed = mode == LoopChainGatewayMode.unavailable;
    return WatchlistMembershipState(
      mode: mode,
      phase: closed
          ? LoopChainViewPhase.unavailable
          : LoopChainViewPhase.loading,
      assetId: assetId,
      failureKind: closed ? LoopChainFailureKind.unavailable : null,
    );
  }

  final LoopChainGatewayMode mode;
  final LoopChainViewPhase phase;
  final String assetId;
  final WatchlistSnapshot? snapshot;
  final LoopChainFailureKind? failureKind;
  final bool busy;

  /// The list has been read, so the star states a fact rather than a guess.
  bool get isKnown => snapshot != null;

  bool get isWatched => snapshot?.containsAsset(assetId) ?? false;

  /// The accessible name of the star. An unread list keeps the "add" name —
  /// pressing it reads the list first and then adds — and never claims the
  /// asset is already watched.
  String get actionLabel => isWatched ? '移出自选' : '加入自选';

  WatchlistMembershipState copyWith({
    LoopChainViewPhase? phase,
    WatchlistSnapshot? snapshot,
    LoopChainFailureKind? failureKind,
    bool clearFailure = false,
    bool? busy,
  }) => WatchlistMembershipState(
    mode: mode,
    phase: phase ?? this.phase,
    assetId: assetId,
    snapshot: snapshot ?? this.snapshot,
    failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    busy: busy ?? this.busy,
  );
}

final class WatchlistMembershipController
    extends Notifier<WatchlistMembershipState>
    with LoopChainSingleFlight {
  WatchlistMembershipController(this.assetId);

  final String assetId;

  @override
  WatchlistMembershipState build() {
    nextGeneration();
    final mode = ref.watch(
      watchlistGatewayProvider.select((gateway) => gateway.mode),
    );
    ref.onDispose(nextGeneration);
    return WatchlistMembershipState.initial(mode, assetId);
  }

  Future<void> load() {
    if (state.isKnown) return Future<void>.value();
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
      state = state.copyWith(
        phase: LoopChainViewPhase.ready,
        snapshot: snapshot,
        clearFailure: true,
      );
    } on LoopChainException catch (error) {
      if (!isCurrent(generation)) return;
      _fail(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      _fail(LoopChainFailureKind.unexpected);
    }
  });

  /// Adds the asset to the default group, or removes it from every group.
  ///
  /// A [LoopChainFailureKind.versionConflict] means another device replaced
  /// the document while this one was composing its replacement. The intent —
  /// add or remove — is still the owner's, so it is re-applied to the freshly
  /// read document exactly once. A second conflict is reported rather than
  /// retried, because a list that keeps moving is not one this press can
  /// safely rewrite.
  Future<WatchlistToggleResult> toggle() async {
    if (state.busy) {
      return const WatchlistToggleResult(WatchlistToggleOutcome.failed);
    }
    state = state.copyWith(busy: true, clearFailure: true);
    try {
      final current = state.snapshot ?? await _read();
      if (!current.containsAsset(assetId)) _refuseIfFull(current);
      final adding = !current.containsAsset(assetId);
      try {
        return _commit(await _write(current, adding: adding), adding: adding);
      } on LoopChainException catch (error) {
        if (error.kind != LoopChainFailureKind.versionConflict) rethrow;
        final fresh = await _read();
        // The other device may already have done what this press intended.
        // Writing again would say the same thing twice, so the reload itself
        // is the outcome.
        if (fresh.containsAsset(assetId) == adding) {
          return _commit(fresh, adding: adding);
        }
        if (adding) _refuseIfFull(fresh);
        return _commit(await _write(fresh, adding: adding), adding: adding);
      }
    } on _WatchlistLimitReached catch (refusal) {
      // Nothing was sent, so nothing failed: the list on screen is still the
      // committed one and keeps its read state.
      state = state.copyWith(busy: false, clearFailure: true);
      return WatchlistToggleResult(refusal.outcome);
    } on LoopChainException catch (error) {
      _fail(error.kind);
      return WatchlistToggleResult(
        WatchlistToggleOutcome.failed,
        failureKind: error.kind,
      );
    } catch (_) {
      _fail(LoopChainFailureKind.unexpected);
      return const WatchlistToggleResult(
        WatchlistToggleOutcome.failed,
        failureKind: LoopChainFailureKind.unexpected,
      );
    }
  }

  Future<WatchlistSnapshot> _read() =>
      ref.read(watchlistGatewayProvider).load();

  Future<WatchlistSnapshot> _write(
    WatchlistSnapshot snapshot, {
    required bool adding,
  }) => ref
      .read(watchlistGatewayProvider)
      .replace(
        expectedVersion: snapshot.version,
        groups: adding ? _withAsset(snapshot) : _withoutAsset(snapshot),
      );

  WatchlistToggleResult _commit(
    WatchlistSnapshot snapshot, {
    required bool adding,
  }) {
    nextGeneration();
    state = state.copyWith(
      phase: LoopChainViewPhase.ready,
      snapshot: snapshot,
      clearFailure: true,
      busy: false,
    );
    // The market overview projects the same resource, so a list read before
    // this write is stale.
    ref.invalidate(marketOverviewControllerProvider);
    return WatchlistToggleResult(
      adding ? WatchlistToggleOutcome.added : WatchlistToggleOutcome.removed,
    );
  }

  /// Refuses an add the server would reject, before any request is made.
  ///
  /// The server answers both of these with `VALIDATION_FAILED`, whose sentence
  /// is about an unregistered asset. Naming the limit here is the only way the
  /// owner learns what is actually in the way.
  void _refuseIfFull(WatchlistSnapshot snapshot) {
    if (snapshot.itemCount >= watchlistMaxItems) {
      throw const _WatchlistLimitReached(
        WatchlistToggleOutcome.itemLimitReached,
      );
    }
    final hasDefaultGroup = snapshot.groups.any(
      (group) => group.key == watchlistDefaultGroupKey,
    );
    if (!hasDefaultGroup && snapshot.groups.length >= watchlistMaxGroups) {
      throw const _WatchlistLimitReached(
        WatchlistToggleOutcome.groupLimitReached,
      );
    }
  }

  /// Appends the asset to the default group, creating that group in the same
  /// replacement when the owner has none. [_refuseIfFull] has already proved
  /// there is room for both.
  List<WatchlistGroup> _withAsset(WatchlistSnapshot snapshot) {
    final groups = List<WatchlistGroup>.of(snapshot.groups);
    final item = WatchlistItem(assetId: assetId);
    final index = groups.indexWhere(
      (group) => group.key == watchlistDefaultGroupKey,
    );
    if (index >= 0) {
      final group = groups[index];
      groups[index] = group.copyWith(
        items: <WatchlistItem>[...group.items, item],
      );
      return groups;
    }
    groups.add(
      WatchlistGroup(
        key: watchlistDefaultGroupKey,
        name: watchlistDefaultGroupName,
        items: <WatchlistItem>[item],
      ),
    );
    return groups;
  }

  /// Removes the asset from every group. An emptied group is kept: the owner
  /// named it, and this press was about one asset.
  List<WatchlistGroup> _withoutAsset(WatchlistSnapshot snapshot) =>
      <WatchlistGroup>[
        for (final group in snapshot.groups)
          group.items.any((item) => item.assetId == assetId)
              ? group.copyWith(
                  items: group.items.where((item) => item.assetId != assetId),
                )
              : group,
      ];

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

final watchlistMembershipControllerProvider = NotifierProvider.autoDispose
    .family<WatchlistMembershipController, WatchlistMembershipState, String>(
      WatchlistMembershipController.new,
    );
