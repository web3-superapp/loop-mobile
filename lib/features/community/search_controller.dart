import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/community/search_models.dart';

/// The five domain segments in prototype order. `assets`, `launch` and
/// `dapps` are selectable but carry the server's unavailable reason.
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
    state = SearchState(
      mode: state.mode,
      phase: state.mode == CommunityGatewayMode.unavailable
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.empty,
      domain: domain,
      query: state.query,
      failureKind: state.mode == CommunityGatewayMode.unavailable
          ? CommunityFailureKind.unavailable
          : null,
    );
    if (searchQueryIsSubmittable(state.query)) {
      submit(state.query);
    }
  }

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
