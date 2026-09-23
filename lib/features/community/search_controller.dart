import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/search_gateway.dart';
import 'package:loop_mobile/features/community/search_models.dart';

/// The five domain segments in prototype order. `launch` and `dapps` are
/// selectable but carry the server's own unavailable reason.
///
/// `assets` searches the asset registry from 2026-09-23 (backend decision
/// 0071); before that it answered `ASSET_REGISTRY_DEFERRED` like the other
/// two. A domain leaves this predicate in the same commit that teaches the
/// page to open its results.
bool searchDomainIsDeferred(SearchDomain domain) =>
    domain == SearchDomain.launch || domain == SearchDomain.dapps;

const List<SearchDomain> searchDomainOrder = <SearchDomain>[
  SearchDomain.assets,
  SearchDomain.communities,
  SearchDomain.users,
  SearchDomain.launch,
  SearchDomain.dapps,
];

/// The domains this build can actually search, in prototype order.
final List<SearchDomain> searchableDomains = List<SearchDomain>.unmodifiable(
  searchDomainOrder.where((domain) => !searchDomainIsDeferred(domain)),
);

/// What the one global search field says it searches.
///
/// It is built from the domains that have a backend, not from all five chips:
/// the label promised 「搜索资产、社区、用户、Launch、DApp」 while three of the
/// five answered 「域暂不可用」, so four words out of five were an offer the
/// page could not keep (device walkthrough 2026-09-23 · a55–a65). A domain
/// that gains a backend leaves [searchDomainIsDeferred] and appears here in
/// the same commit, so the two cannot drift apart.
final String searchFieldLabel =
    '搜索'
    '${searchableDomains.map((domain) => domain.label).join('、')}';

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
  /// One keystroke is not one request: the field settles for this long before
  /// the query is sent. It matches the member directory's own search.
  static const searchDebounce = Duration(milliseconds: 300);

  Timer? _debounce;

  @override
  SearchState build() {
    nextGeneration();
    final mode = ref.watch(searchGatewayProvider).mode;
    ref.onDispose(() {
      _debounce?.cancel();
      _debounce = null;
      nextGeneration();
    });
    return SearchState.initial(mode);
  }

  /// Records a keystroke.
  ///
  /// The field used to do nothing at all until the keyboard's search key was
  /// pressed: five characters typed left the page on 「输入至少 2 个字符开始
  /// 搜索」, which reads as a broken control. The query now enters its loading
  /// phase on the keystroke and is sent once the field settles.
  void type(String raw) {
    final trimmed = raw.trim();
    _debounce?.cancel();
    _debounce = null;
    if (trimmed == state.query &&
        state.phase != CommunityViewPhase.empty &&
        state.phase != CommunityViewPhase.error) {
      return;
    }
    // Too short to send: `submit` states that without spending a request.
    if (!searchQueryIsSubmittable(trimmed)) {
      unawaited(submit(trimmed));
      return;
    }
    state = SearchState(
      mode: state.mode,
      phase: state.mode == CommunityGatewayMode.unavailable
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      domain: state.domain,
      query: trimmed,
      failureKind: state.mode == CommunityGatewayMode.unavailable
          ? CommunityFailureKind.unavailable
          : null,
    );
    if (state.mode == CommunityGatewayMode.unavailable) return;
    _debounce = Timer(searchDebounce, () {
      _debounce = null;
      unawaited(_drain(trimmed));
    });
  }

  /// A keystroke that landed while an earlier read was in flight is answered
  /// by the single-flight guard with that earlier read. One more pass sends
  /// the query the field actually holds, so no keystroke is silently dropped.
  Future<void> _drain(String trimmed) async {
    await submit(trimmed);
    if (state.query != trimmed) await submit(trimmed);
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
      unawaited(submit(state.query, land: false));
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

  /// Sends [query] to the selected domain.
  ///
  /// [land] lets an empty answer move the page to the first domain that has
  /// one. It is true for a query the reader submitted and false for a domain
  /// the reader picked by hand — that choice is an instruction, and an empty
  /// answer to it is the answer.
  Future<void> submit(String query, {bool land = true}) {
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
    // A submitted query is a question about LOOP, not about the chip that
    // happened to be selected: 「voy」 answered 「没有匹配的结果」 under 社区
    // while 用户 held the account being looked for.
    return _fetch(append: false, land: land);
  }

  Future<void> loadMore() {
    if (!state.canLoadMore) return Future<void>.value();
    return _fetch(append: true);
  }

  Future<void> _fetch({required bool append, bool land = false}) => single(
    () async {
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
        var page = await gateway.search(
          domain: previous.domain,
          query: previous.query,
          cursor: append ? previous.nextCursor : null,
        );
        if (!isCurrent(generation)) return;
        // The submitted query lands on the first domain that answered with
        // something. The selected chip is tried first — it is where the reader
        // was looking — and the others only if it has nothing; a domain the
        // reader picked by hand is never overruled, because `selectDomain`
        // does not ask for this.
        if (land && page.available && page.results.isEmpty) {
          for (final domain in searchableDomains) {
            if (domain == previous.domain) continue;
            // Looking somewhere else is an extra, not the query: a domain
            // that refused keeps its refusal to itself, and the empty answer
            // the reader actually asked for still stands.
            final SearchPage candidate;
            try {
              candidate = await gateway.search(
                domain: domain,
                query: previous.query,
              );
            } catch (_) {
              if (!isCurrent(generation)) return;
              continue;
            }
            if (!isCurrent(generation)) return;
            if (candidate.available && candidate.results.isNotEmpty) {
              page = candidate;
              break;
            }
          }
        }
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
    },
  );
}

final searchControllerProvider =
    NotifierProvider.autoDispose<SearchController, SearchState>(
      SearchController.new,
    );
