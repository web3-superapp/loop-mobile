import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';

/// Single-flight guard shared by the S3 controllers: one in-flight operation
/// per controller, and a generation counter so a result that arrives after a
/// rebuild or a filter change is dropped instead of overwriting newer truth.
mixin CommunitySingleFlight {
  Future<void>? _operation;
  int _generation = 0;

  int nextGeneration() => ++_generation;

  /// The generation as it stands, for work that must not retire anything.
  ///
  /// A read refreshes what is already on screen; it owns nothing and it must
  /// never retire a command that is in flight. Taking the current generation
  /// instead of a new one is how such work drops its own stale result without
  /// dropping somebody else's live one.
  int get currentGeneration => _generation;

  bool isCurrent(int generation) => generation == _generation;

  Future<void> single(Future<void> Function() body) {
    final active = _operation;
    if (active != null) return active;
    late final Future<void> operation;
    operation = body().whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }
}

/// One read, carrying the first-read re-attempt S26 introduced.
///
/// A first read has nothing behind it, so the phase it lands in is the whole
/// page, and 「离线 · 显示缓存」 there must mean the device — not a pooled socket
/// the peer closed while the app sat idle. That failure carries no server
/// answer at all: it arrives as `offline`, or as `unexpected` when Dio reports
/// the dropped connection as `unknown`. A first read therefore gets exactly one
/// silent re-attempt. A read that fails twice reports what it failed with, and
/// a read with rows already behind it is untouched.
Future<T> communityFirstRead<T>(
  Future<T> Function() read, {
  required bool firstRead,
}) async {
  var reattempted = false;
  while (true) {
    try {
      return await read();
    } on CommunityGatewayException catch (error) {
      if (!firstRead || reattempted || !_mayBeATransientFirstRead(error.kind)) {
        rethrow;
      }
      reattempted = true;
    } catch (_) {
      if (!firstRead || reattempted) rethrow;
      reattempted = true;
    }
  }
}

bool _mayBeATransientFirstRead(CommunityFailureKind kind) =>
    kind == CommunityFailureKind.offline ||
    kind == CommunityFailureKind.unexpected;

// ---------------------------------------------------------------------------
// community · home aggregate
// ---------------------------------------------------------------------------

final class CommunityHomeController
    extends Notifier<CommunityResourceState<CommunityHome>>
    with CommunitySingleFlight {
  @override
  CommunityResourceState<CommunityHome> build() {
    nextGeneration();
    final mode = ref.watch(communityGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return CommunityResourceState<CommunityHome>.initial(mode);
  }

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final gateway = ref.read(communityGatewayProvider);
    final generation = nextGeneration();
    final firstRead = state.value == null;
    state = state.loading();
    try {
      final home = await communityFirstRead(
        gateway.loadHome,
        firstRead: firstRead,
      );
      if (!isCurrent(generation)) return;
      state = state.ready(home);
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.failed(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.failed(CommunityFailureKind.unexpected);
    }
  });
}

final communityHomeControllerProvider =
    NotifierProvider.autoDispose<
      CommunityHomeController,
      CommunityResourceState<CommunityHome>
    >(CommunityHomeController.new);

// ---------------------------------------------------------------------------
// community-discover · paginated directory
// ---------------------------------------------------------------------------

@immutable
final class CommunityDiscoverState {
  const CommunityDiscoverState({
    required this.mode,
    required this.phase,
    required this.sort,
    required this.membership,
    this.items = const <CommunitySummary>[],
    this.nextCursor,
    this.recommendation,
    this.ordering,
    this.failureKind,
    this.loadingMore = false,
    this.refreshing = false,
  });

  factory CommunityDiscoverState.initial(
    CommunityGatewayMode mode, {
    CommunityMembershipFilter membership = CommunityMembershipFilter.all,
  }) {
    final closed = mode == CommunityGatewayMode.unavailable;
    return CommunityDiscoverState(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      sort: CommunityDirectorySort.members,
      membership: membership,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final CommunityDirectorySort sort;
  final CommunityMembershipFilter membership;
  final List<CommunitySummary> items;
  final String? nextCursor;
  final CommunityRecommendation? recommendation;

  /// What the loaded page was ordered by. Null until a page has answered.
  /// An unavailable ordering is read before [items]: the page is not empty,
  /// the order is missing.
  final CommunityOrdering? ordering;
  final CommunityFailureKind? failureKind;
  final bool loadingMore;

  /// A re-read over rows this page already shows. The directory stays on
  /// screen marked 更新中; only a page with no rows at all loads as a skeleton.
  final bool refreshing;

  bool get canLoadMore => nextCursor != null && !loadingMore;

  /// The reason the chosen order could not be applied, if it could not.
  ///
  /// A failed read answers for itself: the last ordering this page was told
  /// about says nothing about a request that never arrived, so an offline or
  /// broken read keeps its own state instead of this one.
  String? get orderingReasonCode => switch (ordering) {
    CommunityOrderingUnavailable(:final reasonCode) when failureKind == null =>
      reasonCode,
    _ => null,
  };

  bool get isPreview => mode == CommunityGatewayMode.preview;
}

final class CommunityDiscoverController extends Notifier<CommunityDiscoverState>
    with CommunitySingleFlight {
  CommunityMembershipFilter _membership = CommunityMembershipFilter.all;

  @override
  CommunityDiscoverState build() {
    nextGeneration();
    final mode = ref.watch(communityGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return CommunityDiscoverState.initial(mode, membership: _membership);
  }

  /// Narrows the directory to the caller's own communities. Used by the
  /// "view all joined" entry point on the home aggregate.
  Future<void> openJoined() {
    _membership = CommunityMembershipFilter.joined;
    return reload();
  }

  Future<void> load() {
    if (state.phase == CommunityViewPhase.ready) return Future<void>.value();
    return reload();
  }

  Future<void> selectSort(CommunityDirectorySort sort) {
    if (sort == state.sort && state.phase == CommunityViewPhase.ready) {
      return Future<void>.value();
    }
    state = CommunityDiscoverState(
      mode: state.mode,
      phase: CommunityViewPhase.loading,
      sort: sort,
      membership: _membership,
    );
    return _fetch(append: false);
  }

  Future<void> reload() {
    state = CommunityDiscoverState(
      mode: state.mode,
      phase: CommunityViewPhase.loading,
      sort: state.sort,
      membership: _membership,
    );
    return _fetch(append: false);
  }

  Future<void> loadMore() {
    if (!state.canLoadMore) return Future<void>.value();
    return _fetch(append: true);
  }

  /// Pull-to-refresh over the directory.
  ///
  /// It re-reads page one without clearing the rows: they stay on screen
  /// marked 更新中 instead of collapsing into a skeleton, because replacing
  /// readable rows with grey blocks loses what the user already had. A page
  /// that has read nothing yet has nothing to keep and loads normally.
  Future<void> refresh() {
    if (state.items.isEmpty) return reload();
    state = CommunityDiscoverState(
      mode: state.mode,
      phase: CommunityViewPhase.ready,
      sort: state.sort,
      membership: _membership,
      items: state.items,
      recommendation: state.recommendation,
      ordering: state.ordering,
      refreshing: true,
    );
    return _fetch(append: false);
  }

  Future<void> _fetch({required bool append}) => single(() async {
    final gateway = ref.read(communityGatewayProvider);
    final generation = nextGeneration();
    final previous = state;
    if (append) {
      state = CommunityDiscoverState(
        mode: previous.mode,
        phase: previous.phase,
        sort: previous.sort,
        membership: _membership,
        items: previous.items,
        nextCursor: previous.nextCursor,
        recommendation: previous.recommendation,
        ordering: previous.ordering,
        loadingMore: true,
      );
    }
    try {
      final page = await communityFirstRead(
        () => gateway.listCommunities(
          sort: previous.sort,
          // The joined view must include a caller's own unverified communities.
          verification: _membership == CommunityMembershipFilter.joined
              ? CommunityVerificationFilter.all
              : CommunityVerificationFilter.verified,
          membership: _membership,
          cursor: append ? previous.nextCursor : null,
        ),
        firstRead: !append && previous.items.isEmpty,
      );
      if (!isCurrent(generation)) return;
      final merged = append
          ? <CommunitySummary>[...previous.items, ...page.items]
          : page.items;
      state = CommunityDiscoverState(
        mode: previous.mode,
        // An ordering the server could not apply answered the page: the list
        // is not empty of communities, it was never ranked. The screen says
        // which order is missing, so the phase stays out of it.
        phase: page.orderingFailed
            ? CommunityViewPhase.ready
            : merged.isEmpty
            ? CommunityViewPhase.empty
            : CommunityViewPhase.ready,
        sort: previous.sort,
        membership: _membership,
        items: List<CommunitySummary>.unmodifiable(merged),
        nextCursor: page.nextCursor,
        recommendation: page.recommendation,
        ordering: page.ordering,
      );
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      // An expired or foreign cursor is recoverable only from page one.
      if (append && error.kind == CommunityFailureKind.invalidData) {
        state = CommunityDiscoverState(
          mode: previous.mode,
          phase: CommunityViewPhase.loading,
          sort: previous.sort,
          membership: _membership,
        );
        return;
      }
      state = CommunityDiscoverState(
        mode: previous.mode,
        phase: previous.items.isEmpty
            ? communityPhaseForFailure(error.kind)
            : CommunityViewPhase.ready,
        sort: previous.sort,
        membership: _membership,
        items: previous.items,
        nextCursor: previous.nextCursor,
        recommendation: previous.recommendation,
        ordering: previous.ordering,
        failureKind: error.kind,
      );
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = CommunityDiscoverState(
        mode: previous.mode,
        phase: CommunityViewPhase.error,
        sort: previous.sort,
        membership: _membership,
        failureKind: CommunityFailureKind.unexpected,
      );
    }
  });
}

final communityDiscoverControllerProvider =
    NotifierProvider.autoDispose<
      CommunityDiscoverController,
      CommunityDiscoverState
    >(CommunityDiscoverController.new);

// ---------------------------------------------------------------------------
// community application (no dedicated route; opened as a sheet)
// ---------------------------------------------------------------------------

@immutable
final class CommunityApplicationOutcome {
  const CommunityApplicationOutcome({this.detail, this.failureKind});

  /// The created community. Non-null only after a 201.
  final CommunityDetail? detail;
  final CommunityFailureKind? failureKind;

  bool get isAccepted => detail != null;
}

/// Submits one community application. It owns no list state: the caller
/// navigates to the created community on success and shows the mapped copy on
/// a refusal.
final class CommunityApplicationController
    extends Notifier<CommunityResourceState<CommunityDetail>>
    with CommunitySingleFlight {
  @override
  CommunityResourceState<CommunityDetail> build() {
    nextGeneration();
    final mode = ref.watch(communityGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return CommunityResourceState<CommunityDetail>(
      mode: mode,
      phase: CommunityViewPhase.empty,
    );
  }

  Future<CommunityApplicationOutcome> submit(
    CommunityApplication application,
  ) async {
    if (state.busy) {
      return const CommunityApplicationOutcome(
        failureKind: CommunityFailureKind.stale,
      );
    }
    final gateway = ref.read(communityGatewayProvider);
    final generation = nextGeneration();
    state = state.working(true);
    try {
      final detail = await gateway.createCommunity(application);
      if (isCurrent(generation)) state = state.ready(detail);
      return CommunityApplicationOutcome(detail: detail);
    } on CommunityGatewayException catch (error) {
      if (isCurrent(generation)) {
        state = state.working(false).failed(error.kind);
      }
      return CommunityApplicationOutcome(failureKind: error.kind);
    } catch (_) {
      if (isCurrent(generation)) {
        state = state.working(false).failed(CommunityFailureKind.unexpected);
      }
      return const CommunityApplicationOutcome(
        failureKind: CommunityFailureKind.unexpected,
      );
    }
  }
}

final communityApplicationControllerProvider =
    NotifierProvider.autoDispose<
      CommunityApplicationController,
      CommunityResourceState<CommunityDetail>
    >(CommunityApplicationController.new);

// ---------------------------------------------------------------------------
// community-profile · one community record
// ---------------------------------------------------------------------------

final class CommunityProfileController
    extends Notifier<CommunityResourceState<CommunityDetail>>
    with CommunitySingleFlight {
  String? _communityId;

  @override
  CommunityResourceState<CommunityDetail> build() {
    nextGeneration();
    final mode = ref.watch(communityGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return CommunityResourceState<CommunityDetail>.initial(mode);
  }

  String? get communityId => _communityId;

  Future<void> open(String communityId) {
    if (_communityId == communityId && state.isReady) {
      return Future<void>.value();
    }
    _communityId = communityId;
    return _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() => single(() async {
    final id = _communityId;
    if (id == null) {
      state = state.failed(CommunityFailureKind.notFound);
      return;
    }
    final gateway = ref.read(communityGatewayProvider);
    final generation = nextGeneration();
    final firstRead = state.value == null;
    state = state.loading();
    try {
      final detail = await communityFirstRead(
        () => gateway.loadCommunity(id),
        firstRead: firstRead,
      );
      if (!isCurrent(generation)) return;
      state = state.ready(detail);
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.failed(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.failed(CommunityFailureKind.unexpected);
    }
  });

  /// Returns the failure kind when the membership change was refused, and
  /// null when the server confirmed it. The caller shows a Toast only on null.
  Future<CommunityFailureKind?> setMembership({required bool joined}) async {
    final id = _communityId;
    if (id == null) return CommunityFailureKind.notFound;
    if (state.busy) return CommunityFailureKind.stale;
    final gateway = ref.read(communityGatewayProvider);
    final generation = nextGeneration();
    state = state.working(true);
    try {
      final detail = joined ? await gateway.join(id) : await gateway.leave(id);
      if (!isCurrent(generation)) return null;
      state = state.ready(detail);
      return null;
    } on CommunityGatewayException catch (error) {
      if (isCurrent(generation)) {
        state = state.working(false).failed(error.kind);
      }
      return error.kind;
    } catch (_) {
      if (isCurrent(generation)) {
        state = state.working(false).failed(CommunityFailureKind.unexpected);
      }
      return CommunityFailureKind.unexpected;
    }
  }

  /// Owner-only profile edit. Visibility is decided by `viewer`, the result by
  /// the server.
  Future<CommunityFailureKind?> editProfile(CommunityProfileEdit edit) async {
    final id = _communityId;
    if (id == null) return CommunityFailureKind.notFound;
    final gateway = ref.read(communityGatewayProvider);
    final generation = nextGeneration();
    state = state.working(true);
    try {
      final detail = await gateway.editProfile(id, edit);
      if (!isCurrent(generation)) return null;
      state = state.ready(detail);
      return null;
    } on CommunityGatewayException catch (error) {
      if (isCurrent(generation)) {
        state = state.working(false).failed(error.kind);
      }
      return error.kind;
    } catch (_) {
      if (isCurrent(generation)) {
        state = state.working(false).failed(CommunityFailureKind.unexpected);
      }
      return CommunityFailureKind.unexpected;
    }
  }
}

final communityProfileControllerProvider =
    NotifierProvider.autoDispose<
      CommunityProfileController,
      CommunityResourceState<CommunityDetail>
    >(CommunityProfileController.new);

// ---------------------------------------------------------------------------
// community-members · directory and governance
// ---------------------------------------------------------------------------

/// The server's bound for the member-directory alias prefix (`q`), in Unicode
/// code points. The field stops the caller at the bound rather than spending a
/// request the server would reject.
const int memberSearchMaximumRunes = 40;

@immutable
final class CommunityMembersState {
  const CommunityMembersState({
    required this.mode,
    required this.phase,
    required this.filter,
    this.query = '',
    this.community,
    this.viewer,
    this.counts,
    this.items = const <CommunityMemberEntry>[],
    this.nextCursor,
    this.failureKind,
    this.busy = false,
    this.loadingMore = false,
    this.refreshing = false,
  });

  factory CommunityMembersState.initial(CommunityGatewayMode mode) {
    final closed = mode == CommunityGatewayMode.unavailable;
    return CommunityMembersState(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      filter: CommunityMemberFilter.all,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final CommunityMemberFilter filter;

  /// The trimmed member alias prefix the page is currently narrowed by. Empty
  /// means the whole directory; the server owns the normalization.
  final String query;
  final CommunitySummary? community;
  final CommunityViewer? viewer;
  final CommunityMemberCounts? counts;
  final List<CommunityMemberEntry> items;
  final String? nextCursor;
  final CommunityFailureKind? failureKind;
  final bool busy;
  final bool loadingMore;

  /// A search re-read is in flight over results this page already shows
  /// (decision 0071). The rows stay and wear the 更新中 mark instead of being
  /// replaced by a skeleton. Only a narrowing of the same directory qualifies:
  /// opening the page and switching role segment are different directories and
  /// still load as a skeleton.
  final bool refreshing;

  bool get canLoadMore => nextCursor != null && !loadingMore && !busy;

  /// True when the page is narrowed by a search rather than a role filter.
  bool get isSearching => query.isNotEmpty;

  bool get isPreview => mode == CommunityGatewayMode.preview;

  /// Governance visibility comes only from the server's `viewer` flags.
  bool get canGovern => viewer?.canGovern ?? false;
}

final class CommunityMembersController extends Notifier<CommunityMembersState>
    with CommunitySingleFlight {
  /// One keystroke is not one request: the field settles for this long before
  /// the directory is read again.
  static const searchDebounce = Duration(milliseconds: 300);

  String? _communityId;
  Timer? _searchTimer;

  /// The query the last completed request actually asked for. The drain loop
  /// compares it with `state.query` so a keystroke that arrived while a read
  /// was in flight still reaches the server exactly once.
  String _appliedQuery = '';
  String _requestedQuery = '';
  bool _draining = false;

  @override
  CommunityMembersState build() {
    nextGeneration();
    final mode = ref.watch(communityGatewayProvider).mode;
    ref.onDispose(() {
      _searchTimer?.cancel();
      _searchTimer = null;
      nextGeneration();
    });
    return CommunityMembersState.initial(mode);
  }

  String? get communityId => _communityId;

  Future<void> open(String communityId) {
    if (_communityId == communityId &&
        state.phase == CommunityViewPhase.ready) {
      return Future<void>.value();
    }
    _communityId = communityId;
    return _fetch(filter: CommunityMemberFilter.all, append: false);
  }

  Future<void> reload() => _fetch(filter: state.filter, append: false);

  /// Pull-to-refresh over the member list: the rows already read stay on
  /// screen and are marked 更新中, exactly as a search re-read does.
  Future<void> refresh() =>
      _fetch(filter: state.filter, append: false, keepLoadedRows: true);

  Future<void> selectFilter(CommunityMemberFilter filter) {
    if (filter == state.filter && state.phase == CommunityViewPhase.ready) {
      return Future<void>.value();
    }
    return _fetch(filter: filter, append: false);
  }

  Future<void> loadMore() {
    if (!state.canLoadMore) return Future<void>.value();
    return _fetch(filter: state.filter, append: true);
  }

  /// Records a keystroke. The request is debounced; the state's `query`
  /// changes at once so the page can render the field and its clear control.
  void search(String raw) {
    final next = raw.trim();
    if (next == state.query) return;
    _searchTimer?.cancel();
    _searchTimer = null;
    state = _withQuery(next);
    if (next.isEmpty) {
      unawaited(_drainSearch());
      return;
    }
    _searchTimer = Timer(searchDebounce, () {
      _searchTimer = null;
      unawaited(_drainSearch());
    });
  }

  /// Clears the query and reads the whole directory again, without waiting for
  /// the debounce.
  Future<void> clearSearch() {
    _searchTimer?.cancel();
    _searchTimer = null;
    if (state.query.isEmpty) return Future<void>.value();
    state = _withQuery('');
    return _drainSearch();
  }

  CommunityMembersState _withQuery(String query) => CommunityMembersState(
    mode: state.mode,
    phase: state.phase,
    filter: state.filter,
    query: query,
    community: state.community,
    viewer: state.viewer,
    counts: state.counts,
    items: state.items,
    nextCursor: state.nextCursor,
    failureKind: state.failureKind,
    busy: state.busy,
    loadingMore: state.loadingMore,
    refreshing: state.refreshing,
  );

  /// Single flight with coalescing: at most one read is in the air, and when
  /// the query moved on while it was, exactly one more read follows for the
  /// latest text. The bound stops a pathological loop from spinning.
  Future<void> _drainSearch() async {
    if (_draining) return;
    _draining = true;
    try {
      for (var attempt = 0; attempt < 8; attempt += 1) {
        final target = state.query;
        if (target == _appliedQuery) return;
        await _fetch(filter: state.filter, append: false, keepLoadedRows: true);
        if (_requestedQuery == target) _appliedQuery = target;
      }
    } finally {
      _draining = false;
    }
  }

  CommunityMembersState _apply(
    CommunityMembersState previous,
    CommunityMemberDirectory directory, {
    required bool append,
    required CommunityMemberFilter filter,
  }) {
    final merged = append
        ? <CommunityMemberEntry>[...previous.items, ...directory.items]
        : directory.items;
    return CommunityMembersState(
      mode: previous.mode,
      phase: merged.isEmpty
          ? CommunityViewPhase.empty
          : CommunityViewPhase.ready,
      filter: filter,
      // The live query, not the one this read started with: a keystroke that
      // arrived in flight must survive the answer it did not ask for, so the
      // drain loop can still see that the text moved on.
      query: state.query,
      community: directory.community,
      viewer: directory.viewer,
      counts: directory.counts,
      items: List<CommunityMemberEntry>.unmodifiable(merged),
      nextCursor: directory.nextCursor,
    );
  }

  Future<void> _fetch({
    required CommunityMemberFilter filter,
    required bool append,
    bool keepLoadedRows = false,
  }) => single(() async {
    final id = _communityId;
    final previous = state;
    final query = previous.query;
    if (id == null) {
      state = CommunityMembersState(
        mode: previous.mode,
        phase: CommunityViewPhase.error,
        filter: filter,
        query: query,
        failureKind: CommunityFailureKind.notFound,
      );
      return;
    }
    final gateway = ref.read(communityGatewayProvider);
    final generation = nextGeneration();
    _requestedQuery = query;
    // A re-read of the same directory keeps the rows it already read and
    // marks them 更新中 — a search narrowing, a pull, or the read that follows
    // a governance write. A first open or a role switch has nothing comparable
    // to keep and still loads as a skeleton. The cursor is dropped either way,
    // because it is bound to the query that issued it.
    final keepRows = !append && keepLoadedRows && previous.items.isNotEmpty;
    state = CommunityMembersState(
      mode: previous.mode,
      phase: append || keepRows ? previous.phase : CommunityViewPhase.loading,
      filter: filter,
      query: query,
      community: previous.community,
      viewer: previous.viewer,
      counts: previous.counts,
      items: append || keepRows
          ? previous.items
          : const <CommunityMemberEntry>[],
      nextCursor: append ? previous.nextCursor : null,
      loadingMore: append,
      refreshing: keepRows,
    );
    try {
      final directory = await communityFirstRead(
        () => gateway.listMembers(
          id,
          role: filter,
          q: query.isEmpty ? null : query,
          // A cursor is bound to the query it was issued for, so a page is
          // only continued while the query is unchanged.
          cursor: append ? previous.nextCursor : null,
        ),
        firstRead: !append && previous.items.isEmpty,
      );
      if (!isCurrent(generation)) return;
      state = _apply(previous, directory, append: append, filter: filter);
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      state = CommunityMembersState(
        mode: previous.mode,
        phase: previous.items.isEmpty || !append
            ? communityPhaseForFailure(error.kind)
            : CommunityViewPhase.ready,
        filter: filter,
        query: state.query,
        community: previous.community,
        viewer: previous.viewer,
        counts: previous.counts,
        items: append ? previous.items : const <CommunityMemberEntry>[],
        nextCursor: append ? previous.nextCursor : null,
        failureKind: error.kind,
      );
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = CommunityMembersState(
        mode: previous.mode,
        phase: CommunityViewPhase.error,
        filter: filter,
        query: state.query,
        failureKind: CommunityFailureKind.unexpected,
      );
    }
  });

  /// Runs one governance command. Returns null when the server confirmed it;
  /// the caller shows the success Toast only in that case.
  Future<CommunityFailureKind?> _govern(
    Future<CommunityMemberDirectory> Function(String communityId) command,
  ) async {
    final id = _communityId;
    if (id == null) return CommunityFailureKind.notFound;
    if (state.busy) return CommunityFailureKind.stale;
    final previous = state;
    final generation = nextGeneration();
    state = CommunityMembersState(
      mode: previous.mode,
      phase: previous.phase,
      filter: previous.filter,
      query: previous.query,
      community: previous.community,
      viewer: previous.viewer,
      counts: previous.counts,
      items: previous.items,
      nextCursor: previous.nextCursor,
      busy: true,
    );
    try {
      final directory = await command(id);
      if (!isCurrent(generation)) return null;
      if (previous.filter == CommunityMemberFilter.all) {
        // The governance response is the default directory's first page.
        state = _apply(
          previous,
          directory,
          append: false,
          filter: previous.filter,
        );
      } else {
        // A filtered view (owner, admin, banned) is not what the command
        // answered with, so it is read again instead of being mislabelled.
        // The rows it already read stay on screen while it runs: the write
        // the server accepted made one row stale, not the whole directory.
        await _fetch(
          filter: previous.filter,
          append: false,
          keepLoadedRows: true,
        );
      }
      return null;
    } on CommunityGatewayException catch (error) {
      if (isCurrent(generation)) {
        state = CommunityMembersState(
          mode: previous.mode,
          phase: previous.phase,
          filter: previous.filter,
          query: previous.query,
          community: previous.community,
          viewer: previous.viewer,
          counts: previous.counts,
          items: previous.items,
          nextCursor: previous.nextCursor,
          failureKind: error.kind,
        );
      }
      return error.kind;
    } catch (_) {
      if (isCurrent(generation)) {
        state = CommunityMembersState(
          mode: previous.mode,
          phase: previous.phase,
          filter: previous.filter,
          query: previous.query,
          community: previous.community,
          viewer: previous.viewer,
          counts: previous.counts,
          items: previous.items,
          nextCursor: previous.nextCursor,
          failureKind: CommunityFailureKind.unexpected,
        );
      }
      return CommunityFailureKind.unexpected;
    }
  }

  Future<CommunityFailureKind?> changeRole({
    required String publicProfileId,
    required CommunityRole role,
  }) {
    final gateway = ref.read(communityGatewayProvider);
    return _govern(
      (id) => gateway.changeMemberRole(
        communityId: id,
        publicProfileId: publicProfileId,
        role: role,
      ),
    );
  }

  Future<CommunityFailureKind?> setMuted({
    required String publicProfileId,
    required bool muted,
  }) {
    final gateway = ref.read(communityGatewayProvider);
    return _govern(
      (id) => gateway.setMuted(
        communityId: id,
        publicProfileId: publicProfileId,
        muted: muted,
      ),
    );
  }

  Future<CommunityFailureKind?> setBanned({
    required String publicProfileId,
    required bool banned,
  }) {
    final gateway = ref.read(communityGatewayProvider);
    return _govern(
      (id) => gateway.setBanned(
        communityId: id,
        publicProfileId: publicProfileId,
        banned: banned,
      ),
    );
  }
}

final communityMembersControllerProvider =
    NotifierProvider.autoDispose<
      CommunityMembersController,
      CommunityMembersState
    >(CommunityMembersController.new);

// ---------------------------------------------------------------------------
// referral · read-only rules
// ---------------------------------------------------------------------------

final class ReferralRulesController
    extends Notifier<CommunityResourceState<ReferralRules>>
    with CommunitySingleFlight {
  @override
  CommunityResourceState<ReferralRules> build() {
    nextGeneration();
    final mode = ref.watch(communityGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return CommunityResourceState<ReferralRules>.initial(mode);
  }

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final gateway = ref.read(communityGatewayProvider);
    final generation = nextGeneration();
    state = state.loading();
    try {
      final rules = await gateway.loadReferralRules();
      if (!isCurrent(generation)) return;
      state = state.ready(rules);
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.failed(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.failed(CommunityFailureKind.unexpected);
    }
  });
}

final referralRulesControllerProvider =
    NotifierProvider.autoDispose<
      ReferralRulesController,
      CommunityResourceState<ReferralRules>
    >(ReferralRulesController.new);
