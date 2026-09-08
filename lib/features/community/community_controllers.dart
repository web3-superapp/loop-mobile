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
    state = state.loading();
    try {
      final home = await gateway.loadHome();
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
    this.failureKind,
    this.loadingMore = false,
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
  final CommunityFailureKind? failureKind;
  final bool loadingMore;

  bool get canLoadMore => nextCursor != null && !loadingMore;

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
        loadingMore: true,
      );
    }
    try {
      final page = await gateway.listCommunities(
        sort: previous.sort,
        // The joined view must include a caller's own unverified communities.
        verification: _membership == CommunityMembershipFilter.joined
            ? CommunityVerificationFilter.all
            : CommunityVerificationFilter.verified,
        membership: _membership,
        cursor: append ? previous.nextCursor : null,
      );
      if (!isCurrent(generation)) return;
      final merged = append
          ? <CommunitySummary>[...previous.items, ...page.items]
          : page.items;
      state = CommunityDiscoverState(
        mode: previous.mode,
        phase: merged.isEmpty
            ? CommunityViewPhase.empty
            : CommunityViewPhase.ready,
        sort: previous.sort,
        membership: _membership,
        items: List<CommunitySummary>.unmodifiable(merged),
        nextCursor: page.nextCursor,
        recommendation: page.recommendation,
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
    state = state.loading();
    try {
      final detail = await gateway.loadCommunity(id);
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

@immutable
final class CommunityMembersState {
  const CommunityMembersState({
    required this.mode,
    required this.phase,
    required this.filter,
    this.community,
    this.viewer,
    this.counts,
    this.items = const <CommunityMemberEntry>[],
    this.nextCursor,
    this.failureKind,
    this.busy = false,
    this.loadingMore = false,
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
  final CommunitySummary? community;
  final CommunityViewer? viewer;
  final CommunityMemberCounts? counts;
  final List<CommunityMemberEntry> items;
  final String? nextCursor;
  final CommunityFailureKind? failureKind;
  final bool busy;
  final bool loadingMore;

  bool get canLoadMore => nextCursor != null && !loadingMore && !busy;

  bool get isPreview => mode == CommunityGatewayMode.preview;

  /// Governance visibility comes only from the server's `viewer` flags.
  bool get canGovern => viewer?.canGovern ?? false;
}

final class CommunityMembersController extends Notifier<CommunityMembersState>
    with CommunitySingleFlight {
  String? _communityId;

  @override
  CommunityMembersState build() {
    nextGeneration();
    final mode = ref.watch(communityGatewayProvider).mode;
    ref.onDispose(nextGeneration);
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
  }) => single(() async {
    final id = _communityId;
    final previous = state;
    if (id == null) {
      state = CommunityMembersState(
        mode: previous.mode,
        phase: CommunityViewPhase.error,
        filter: filter,
        failureKind: CommunityFailureKind.notFound,
      );
      return;
    }
    final gateway = ref.read(communityGatewayProvider);
    final generation = nextGeneration();
    state = CommunityMembersState(
      mode: previous.mode,
      phase: append ? previous.phase : CommunityViewPhase.loading,
      filter: filter,
      community: previous.community,
      viewer: previous.viewer,
      counts: previous.counts,
      items: append ? previous.items : const <CommunityMemberEntry>[],
      nextCursor: append ? previous.nextCursor : null,
      loadingMore: append,
    );
    try {
      final directory = await gateway.listMembers(
        id,
        role: filter,
        cursor: append ? previous.nextCursor : null,
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
        await _fetch(filter: previous.filter, append: false);
      }
      return null;
    } on CommunityGatewayException catch (error) {
      if (isCurrent(generation)) {
        state = CommunityMembersState(
          mode: previous.mode,
          phase: previous.phase,
          filter: previous.filter,
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
