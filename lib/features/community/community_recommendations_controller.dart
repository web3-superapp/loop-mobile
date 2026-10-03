import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';

@immutable
final class CommunityRecommendationsState {
  const CommunityRecommendationsState({
    required this.mode,
    required this.phase,
    this.items = const <CommunitySummary>[],
    this.selected = const <String>{},
    this.joined = const <String>{},
    this.failures = const <String, CommunityFailureKind>{},
    this.recommendation,
    this.failureKind,
    this.busy = false,
  });

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final List<CommunitySummary> items;
  final Set<String> selected;
  final Set<String> joined;
  final Map<String, CommunityFailureKind> failures;
  final CommunityRecommendation? recommendation;
  final CommunityFailureKind? failureKind;
  final bool busy;

  /// Ordered exactly as the home aggregate; completed joins never reappear.
  List<String> get pendingIds => <String>[
    for (final item in items)
      if (selected.contains(item.communityId) &&
          !joined.contains(item.communityId))
        item.communityId,
  ];

  CommunityRecommendationsState copyWith({
    Set<String>? selected,
    Set<String>? joined,
    Map<String, CommunityFailureKind>? failures,
    bool? busy,
  }) => CommunityRecommendationsState(
    mode: mode,
    phase: phase,
    items: items,
    selected: Set<String>.unmodifiable(selected ?? this.selected),
    joined: Set<String>.unmodifiable(joined ?? this.joined),
    failures: Map<String, CommunityFailureKind>.unmodifiable(
      failures ?? this.failures,
    ),
    recommendation: recommendation,
    failureKind: failureKind,
    busy: busy ?? this.busy,
  );
}

/// Optional onboarding using only the backend home recommendation and the
/// existing join port. No directory popularity sort or notification write.
final class CommunityRecommendationsController
    extends Notifier<CommunityRecommendationsState> {
  int _generation = 0;
  bool _loading = false;

  @override
  CommunityRecommendationsState build() {
    final mode = ref.watch(communityGatewayProvider).mode;
    ref.watch(loopAccountScopeProvider);
    _generation += 1;
    _loading = false;
    ref.onDispose(() => _generation += 1);
    return CommunityRecommendationsState(
      mode: mode,
      phase: mode == CommunityGatewayMode.unavailable
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      failureKind: mode == CommunityGatewayMode.unavailable
          ? CommunityFailureKind.unavailable
          : null,
    );
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  Future<void> load() async {
    if (_loading ||
        state.busy ||
        state.phase == CommunityViewPhase.ready ||
        state.mode == CommunityGatewayMode.unavailable) {
      return;
    }
    _loading = true;
    final generation = _generation;
    final gateway = ref.read(communityGatewayProvider);
    state = CommunityRecommendationsState(
      mode: state.mode,
      phase: CommunityViewPhase.loading,
    );
    try {
      final home = await communityFirstRead(gateway.loadHome, firstRead: true);
      if (!_current(generation)) return;
      final seen = <String>{
        for (final item in home.joined) item.community.communityId,
        for (final item in home.owned) item.community.communityId,
      };
      final items = <CommunitySummary>[
        for (final item in home.discover)
          if (seen.add(item.communityId)) item,
      ];
      state = CommunityRecommendationsState(
        mode: gateway.mode,
        phase: CommunityViewPhase.ready,
        items: List<CommunitySummary>.unmodifiable(items),
        selected: Set<String>.unmodifiable(
          items.take(5).map((item) => item.communityId),
        ),
        recommendation: home.recommendation,
      );
    } on CommunityGatewayException catch (error) {
      if (!_current(generation)) return;
      state = CommunityRecommendationsState(
        mode: gateway.mode,
        phase: communityPhaseForFailure(error.kind),
        failureKind: error.kind,
      );
    } catch (_) {
      if (!_current(generation)) return;
      state = CommunityRecommendationsState(
        mode: gateway.mode,
        phase: CommunityViewPhase.error,
        failureKind: CommunityFailureKind.unexpected,
      );
    } finally {
      if (_current(generation)) _loading = false;
    }
  }

  void toggle(String communityId) {
    if (state.busy ||
        state.phase != CommunityViewPhase.ready ||
        state.joined.contains(communityId) ||
        !state.items.any((item) => item.communityId == communityId)) {
      return;
    }
    final selected = <String>{...state.selected};
    if (!selected.remove(communityId)) selected.add(communityId);
    state = state.copyWith(selected: selected);
  }

  /// Only matching, non-banned returned memberships count as joined. Failed
  /// selections remain pending; retry asks only those, using the adapter's
  /// existing command-key lifecycle for unresolved responses.
  Future<bool> joinSelected() async {
    if (state.busy || state.phase != CommunityViewPhase.ready) return false;
    final pending = state.pendingIds;
    if (pending.isEmpty) return true;
    final generation = _generation;
    final gateway = ref.read(communityGatewayProvider);
    state = state.copyWith(busy: true);
    var changed = false;
    for (final id in pending) {
      if (!_current(generation)) return false;
      CommunityFailureKind? failure;
      try {
        final detail = await gateway.join(id);
        if (!_current(generation)) return false;
        final membership = detail.viewer.membership;
        if (detail.community.communityId != id || membership == null) {
          failure = CommunityFailureKind.outcomeUnknown;
        } else if (membership.status == CommunityMemberStatus.banned) {
          failure = CommunityFailureKind.permissionDenied;
        }
      } on CommunityGatewayException catch (error) {
        failure = error.kind;
      } catch (_) {
        failure = CommunityFailureKind.unexpected;
      }
      if (!_current(generation)) return false;
      final failures = <String, CommunityFailureKind>{...state.failures};
      final joined = <String>{...state.joined};
      if (failure == null) {
        joined.add(id);
        failures.remove(id);
        changed = true;
      } else {
        failures[id] = failure;
      }
      state = state.copyWith(joined: joined, failures: failures);
    }
    if (!_current(generation)) return false;
    state = state.copyWith(busy: false);
    if (changed) ref.invalidate(communityHomeControllerProvider);
    return state.pendingIds.isEmpty;
  }
}

final communityRecommendationsControllerProvider =
    NotifierProvider.autoDispose<
      CommunityRecommendationsController,
      CommunityRecommendationsState
    >(CommunityRecommendationsController.new);
