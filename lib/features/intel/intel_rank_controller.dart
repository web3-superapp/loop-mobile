import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';

/// What 情报 · 算力榜 holds for the board on screen.
@immutable
final class IntelRankBoardState {
  const IntelRankBoardState({
    required this.mode,
    required this.scope,
    required this.phase,
    this.rank,
    this.failureKind,
    this.refreshing = false,
    this.loadingMore = false,
    this.appendFailed = false,
  });

  final LaunchGatewayMode mode;

  /// The board the reader chose. [rank] is always this board's or `null`.
  final MiningRankScope scope;
  final LaunchViewPhase phase;

  /// Every page read so far, merged. `null` until the first page lands.
  final MiningRank? rank;
  final LaunchFailureKind? failureKind;

  /// The first page is being re-read over rows already on screen.
  final bool refreshing;

  /// The page after the rows on screen is being read.
  final bool loadingMore;

  /// The last page request failed; the rows read so far stay.
  final bool appendFailed;

  bool get isReady => phase == LaunchViewPhase.ready && rank != null;

  IntelRankBoardState copyWith({
    MiningRankScope? scope,
    LaunchViewPhase? phase,
    MiningRank? rank,
    bool clearRank = false,
    LaunchFailureKind? failureKind,
    bool clearFailure = false,
    bool? refreshing,
    bool? loadingMore,
    bool? appendFailed,
  }) => IntelRankBoardState(
    mode: mode,
    scope: scope ?? this.scope,
    phase: phase ?? this.phase,
    rank: clearRank ? null : (rank ?? this.rank),
    failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    refreshing: refreshing ?? this.refreshing,
    loadingMore: loadingMore ?? this.loadingMore,
    appendFailed: appendFailed ?? this.appendFailed,
  );
}

/// 情报 · 算力榜 (decision 0118): one board at a time, read a cursor page at
/// a time as the reader scrolls.
///
/// The scope is page state. Switching it discards the previous board rather
/// than relabelling it, and an answer that lands for a board the reader has
/// already left is dropped. The first page carries the reader's own place
/// (`me`) and the snapshot / formula the board was produced under; a later
/// page only adds rows.
final class IntelRankBoardController extends Notifier<IntelRankBoardState> {
  /// The order the chips are drawn in (需求方 2026-10-08: 社区 / 用户 / 推广).
  static const List<MiningRankScope> scopes = <MiningRankScope>[
    MiningRankScope.communities,
    MiningRankScope.users,
    MiningRankScope.referrals,
  ];

  /// Bumped by every first-page read and every scope change; an answer
  /// carrying an older number is stale.
  int _generation = 0;
  bool _reading = false;

  @override
  IntelRankBoardState build() {
    final mode = ref.watch(miningGatewayProvider).mode;
    ref.watch(loopAccountScopeProvider);
    _generation += 1;
    _reading = false;
    ref.onDispose(() => _generation += 1);
    final closed = mode == LaunchGatewayMode.unavailable;
    return IntelRankBoardState(
      mode: mode,
      scope: MiningRankScope.communities,
      phase: closed ? LaunchViewPhase.unavailable : LaunchViewPhase.loading,
      failureKind: closed ? LaunchFailureKind.unavailable : null,
    );
  }

  /// Reads the first page once, for a page that has not read yet.
  Future<void> load() {
    if (state.isReady || _reading) return Future<void>.value();
    return reload();
  }

  Future<void> select(MiningRankScope scope) {
    if (state.scope == scope) return load();
    _generation += 1;
    final closed = state.mode == LaunchGatewayMode.unavailable;
    state = IntelRankBoardState(
      mode: state.mode,
      scope: scope,
      phase: closed ? LaunchViewPhase.unavailable : LaunchViewPhase.loading,
      failureKind: closed ? LaunchFailureKind.unavailable : null,
    );
    if (closed) return Future<void>.value();
    return reload();
  }

  /// Re-reads the first page of the board on screen.
  Future<void> reload() async {
    if (state.mode == LaunchGatewayMode.unavailable) return;
    final generation = ++_generation;
    final scope = state.scope;
    _reading = true;
    state = state.copyWith(
      phase: state.rank == null
          ? LaunchViewPhase.loading
          : LaunchViewPhase.ready,
      refreshing: state.rank != null,
      loadingMore: false,
      appendFailed: false,
      clearFailure: true,
    );
    try {
      final rank = await ref.read(miningGatewayProvider).loadRank(scope);
      if (!ref.mounted || generation != _generation) return;
      if (rank.scope != scope) {
        throw const LaunchException(LaunchFailureKind.invalidData);
      }
      state = state.copyWith(
        phase: LaunchViewPhase.ready,
        rank: rank,
        refreshing: false,
        clearFailure: true,
      );
    } on LaunchException catch (error) {
      if (!ref.mounted || generation != _generation) return;
      _fail(error.kind);
    } catch (_) {
      if (!ref.mounted || generation != _generation) return;
      _fail(LaunchFailureKind.unexpected);
    } finally {
      if (generation == _generation) _reading = false;
    }
  }

  void _fail(LaunchFailureKind kind) {
    state = state.copyWith(
      phase: state.rank == null
          ? launchPhaseForFailure(kind)
          : LaunchViewPhase.ready,
      failureKind: kind,
      refreshing: false,
    );
  }

  /// Reads the page after the rows on screen. A second call while one is in
  /// flight, or with no cursor left, does nothing.
  Future<void> loadMore() async {
    final current = state.rank;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || state.loadingMore) return;
    final generation = _generation;
    state = state.copyWith(loadingMore: true, appendFailed: false);
    try {
      final page = await ref
          .read(miningGatewayProvider)
          .loadRank(current.scope, cursor: cursor);
      if (!ref.mounted || generation != _generation) return;
      if (page.scope != current.scope) {
        throw const LaunchException(LaunchFailureKind.invalidData);
      }
      state = state.copyWith(
        rank: intelRankAppend(current, page),
        loadingMore: false,
      );
    } catch (_) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(loadingMore: false, appendFailed: true);
    }
  }
}

/// [current] followed by [page]'s rows. The reader's place, the snapshot and
/// the formula stay the first page's: they describe the whole board.
MiningRank intelRankAppend(MiningRank current, MiningRank page) {
  final MiningRanking? ranking = switch ((current.ranking, page.ranking)) {
    (
      MiningRankingUsers(items: final held, :final participants),
      MiningRankingUsers(items: final more),
    ) =>
      MiningRankingUsers(
        items: List<MiningRankUserRow>.unmodifiable(<MiningRankUserRow>[
          ...held,
          ...more,
        ]),
        participants: participants,
      ),
    (
      MiningRankingCommunities(items: final held, :final participants),
      MiningRankingCommunities(items: final more),
    ) =>
      MiningRankingCommunities(
        items: List<MiningRankCommunityRow>.unmodifiable(
          <MiningRankCommunityRow>[
            ...held,
            for (final row in more)
              if (!held.any(
                (seen) =>
                    seen.community.communityId == row.community.communityId,
              ))
                row,
          ],
        ),
        participants: participants,
      ),
    (
      MiningRankingReferrals(
        items: final held,
        :final participants,
        :final ruleKey,
      ),
      MiningRankingReferrals(items: final more),
    ) =>
      MiningRankingReferrals(
        items: List<MiningRankReferralRow>.unmodifiable(<MiningRankReferralRow>[
          ...held,
          ...more,
        ]),
        participants: participants,
        ruleKey: ruleKey,
      ),
    // A page that is not the same kind of board ends the list where it is.
    _ => null,
  };
  return MiningRank(
    scope: current.scope,
    ranking: ranking ?? current.ranking,
    myPosition: current.myPosition,
    snapshot: current.snapshot,
    display: current.display,
    formula: current.formula,
    me: current.me,
    nextCursor: ranking == null ? null : page.nextCursor,
  );
}

final intelRankBoardControllerProvider =
    NotifierProvider.autoDispose<IntelRankBoardController, IntelRankBoardState>(
      IntelRankBoardController.new,
    );
