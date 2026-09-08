import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/community/search_models.dart';

/// The five domain segments in prototype order. `assets`, `launch` and
/// `dapps` are selectable but carry the server's unavailable reason.
/// The three domains that have no backend in this step.
bool searchDomainIsDeferred(SearchDomain domain) =>
    domain == SearchDomain.assets ||
    domain == SearchDomain.launch ||
    domain == SearchDomain.dapps;

const List<SearchDomain> searchDomainOrder = <SearchDomain>[
  SearchDomain.assets,
  SearchDomain.communities,
  SearchDomain.users,
  SearchDomain.launch,
  SearchDomain.dapps,
];

/// Prefix bounds enforced by the server. A shorter query is not sent, so the
/// public search quota is never spent on a request that would be rejected.
const int searchMinimumRunes = 2;
const int searchMaximumRunes = 40;

/// The term used to probe a domain that has no backend.
///
/// `q` is required by the contract, and the three deferred domains answer
/// `{status: unavailable, reasonCode}` for any term without spending the
/// public search quota, so the reason can be read without a user query.
const String searchUnavailableProbeQuery = 'loop';

bool searchQueryIsSubmittable(String query) {
  final runes = query.trim().runes.length;
  return runes >= searchMinimumRunes && runes <= searchMaximumRunes;
}

@immutable
final class SearchState {
  const SearchState({
    required this.mode,
    required this.phase,
    required this.domain,
    this.query = '',
    this.results = const <SearchResult>[],
    this.reasonCode,
    this.nextCursor,
    this.failureKind,
    this.loadingMore = false,
  });

  factory SearchState.initial(CommunityGatewayMode mode) {
    final closed = mode == CommunityGatewayMode.unavailable;
    return SearchState(
      mode: mode,
      phase: closed ? CommunityViewPhase.unavailable : CommunityViewPhase.empty,
      domain: SearchDomain.communities,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final SearchDomain domain;
  final String query;
  final List<SearchResult> results;

  /// Server-supplied cause when the selected domain has no backend.
  final String? reasonCode;
  final String? nextCursor;
  final CommunityFailureKind? failureKind;
  final bool loadingMore;

  bool get canLoadMore => nextCursor != null && !loadingMore;

  bool get isPreview => mode == CommunityGatewayMode.preview;

  /// True once the server has answered that this domain has no source.
  bool get domainUnavailable => reasonCode != null;
}

final class SearchController extends Notifier<SearchState>
    with CommunitySingleFlight {
  @override
  SearchState build() {
    nextGeneration();
    final mode = ref.watch(searchGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return SearchState.initial(mode);
  }

  void selectDomain(SearchDomain domain) {
    if (domain == state.domain) return;
    final closed = state.mode == CommunityGatewayMode.unavailable;
    state = SearchState(
      mode: state.mode,
      phase: closed ? CommunityViewPhase.unavailable : CommunityViewPhase.empty,
      domain: domain,
      query: state.query,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
    if (closed) return;
    if (searchQueryIsSubmittable(state.query)) {
      unawaited(submit(state.query));
      return;
    }
    // A domain with no backend is probed once so the page can show the
    // server's own reason instead of a client-side guess.
    if (searchDomainIsDeferred(domain)) {
      state = SearchState(
        mode: state.mode,
        phase: CommunityViewPhase.loading,
        domain: domain,
        query: state.query,
      );
      unawaited(_probe());
    }
  }

  /// Reads the server's `reasonCode` for a domain that has no results to give.
  Future<void> _probe() => single(() async {
    final gateway = ref.read(searchGatewayProvider);
    final previous = state;
    final generation = nextGeneration();
    try {
      final page = await gateway.search(
        domain: previous.domain,
        query: searchUnavailableProbeQuery,
      );
      if (!isCurrent(generation)) return;
      state = SearchState(
        mode: previous.mode,
        // A probe never presents results, only the reason.
        phase: page.available
            ? CommunityViewPhase.empty
            : CommunityViewPhase.unavailable,
        domain: page.domain,
        query: previous.query,
        reasonCode: page.reasonCode,
      );
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      state = SearchState(
        mode: previous.mode,
        phase: communityPhaseForFailure(error.kind),
        domain: previous.domain,
        query: previous.query,
        failureKind: error.kind,
      );
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = SearchState(
        mode: previous.mode,
        phase: CommunityViewPhase.error,
        domain: previous.domain,
        query: previous.query,
        failureKind: CommunityFailureKind.unexpected,
      );
    }
  });

  Future<void> submit(String query) {
    final trimmed = query.trim();
    if (!searchQueryIsSubmittable(trimmed)) {
      state = SearchState(
        mode: state.mode,
        phase: state.mode == CommunityGatewayMode.unavailable
            ? CommunityViewPhase.unavailable
            : CommunityViewPhase.empty,
        domain: state.domain,
        query: trimmed,
        failureKind: state.mode == CommunityGatewayMode.unavailable
            ? CommunityFailureKind.unavailable
            : null,
      );
      return Future<void>.value();
    }
    state = SearchState(
      mode: state.mode,
      phase: CommunityViewPhase.loading,
      domain: state.domain,
      query: trimmed,
    );
    return _fetch(append: false);
  }

  Future<void> loadMore() {
    if (!state.canLoadMore) return Future<void>.value();
    return _fetch(append: true);
  }

  Future<void> _fetch({required bool append}) => single(() async {
    final gateway = ref.read(searchGatewayProvider);
    final previous = state;
    final generation = nextGeneration();
    if (append) {
      state = SearchState(
        mode: previous.mode,
        phase: previous.phase,
        domain: previous.domain,
        query: previous.query,
        results: previous.results,
        reasonCode: previous.reasonCode,
        nextCursor: previous.nextCursor,
        loadingMore: true,
      );
    }
    try {
      final page = await gateway.search(
        domain: previous.domain,
        query: previous.query,
        cursor: append ? previous.nextCursor : null,
      );
      if (!isCurrent(generation)) return;
      final merged = append
          ? <SearchResult>[...previous.results, ...page.results]
          : page.results;
      state = SearchState(
        mode: previous.mode,
        phase: page.available
            ? (merged.isEmpty
                  ? CommunityViewPhase.empty
                  : CommunityViewPhase.ready)
            : CommunityViewPhase.unavailable,
        domain: page.domain,
        query: previous.query,
        results: List<SearchResult>.unmodifiable(merged),
        reasonCode: page.reasonCode,
        nextCursor: page.nextCursor,
      );
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      state = SearchState(
        mode: previous.mode,
        phase: communityPhaseForFailure(error.kind),
        domain: previous.domain,
        query: previous.query,
        failureKind: error.kind,
      );
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = SearchState(
        mode: previous.mode,
        phase: CommunityViewPhase.error,
        domain: previous.domain,
        query: previous.query,
        failureKind: CommunityFailureKind.unexpected,
      );
    }
  });
}

final searchControllerProvider =
    NotifierProvider.autoDispose<SearchController, SearchState>(
      SearchController.new,
    );
