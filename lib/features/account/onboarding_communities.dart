import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `GET /v2/communities/recommended` (S107 §4, decision 0112).
@immutable
final class RecommendedCommunities {
  const RecommendedCommunities({
    required this.items,
    required this.defaultSelectedIds,
  });

  final List<CommunitySummary> items;

  /// The ones ticked when the page opens (the first five of the operator's
  /// list). Always a subset of [items].
  final List<String> defaultSelectedIds;
}

abstract interface class RecommendedCommunitiesGateway {
  CommunityGatewayMode get mode;

  Future<RecommendedCommunities> load();
}

final class UnavailableRecommendedCommunitiesGateway
    implements RecommendedCommunitiesGateway {
  const UnavailableRecommendedCommunitiesGateway();

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.unavailable;

  @override
  Future<RecommendedCommunities> load() => Future<RecommendedCommunities>.error(
    const CommunityGatewayException(CommunityFailureKind.unavailable),
  );
}

final recommendedCommunitiesGatewayProvider =
    Provider<RecommendedCommunitiesGateway>(
      (ref) => const UnavailableRecommendedCommunitiesGateway(),
    );

/// Turns a community's chat off for this account (Stream `mute()`).
///
/// A port, because the client that can mute is the Stream SDK session, and a
/// page test has none.
abstract interface class CommunityChannelMuter {
  Future<void> mute(String channelCid);
}

final class UnavailableCommunityChannelMuter implements CommunityChannelMuter {
  const UnavailableCommunityChannelMuter();

  @override
  Future<void> mute(String channelCid) =>
      Future<void>.error(StateError('stream_unavailable'));
}

final communityChannelMuterProvider = Provider<CommunityChannelMuter>(
  (ref) => const UnavailableCommunityChannelMuter(),
);

/// What happened to one ticked community when the reader pressed 进入 LOOP.
enum OnboardingJoinResult { joined, joinedNotMuted, failed }

@immutable
final class OnboardingCommunitiesState {
  const OnboardingCommunitiesState({
    required this.mode,
    required this.phase,
    this.items = const <CommunitySummary>[],
    this.selected = const <String>{},
    this.failureKind,
    this.directoryStarted = false,
    this.directoryCursor,
    this.directoryEnded = false,
    this.loadingMore = false,
    this.appendFailed = false,
    this.submitting = false,
    this.results = const <String, OnboardingJoinResult>{},
    this.failureReasons = const <String, String>{},
  });

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final List<CommunitySummary> items;
  final Set<String> selected;
  final CommunityFailureKind? failureKind;

  /// The page continues past the recommendation into the whole directory.
  final bool directoryStarted;
  final String? directoryCursor;
  final bool directoryEnded;
  final bool loadingMore;
  final bool appendFailed;
  final bool submitting;

  /// Filled in by [OnboardingCommunitiesController.enter], one per ticked row.
  final Map<String, OnboardingJoinResult> results;
  final Map<String, String> failureReasons;

  bool get hasFailures =>
      results.values.any((result) => result != OnboardingJoinResult.joined);

  bool get canLoadMore => !directoryEnded && !loadingMore && !appendFailed;

  OnboardingCommunitiesState copyWith({
    CommunityViewPhase? phase,
    List<CommunitySummary>? items,
    Set<String>? selected,
    CommunityFailureKind? failureKind,
    bool clearFailure = false,
    bool? directoryStarted,
    String? directoryCursor,
    bool clearCursor = false,
    bool? directoryEnded,
    bool? loadingMore,
    bool? appendFailed,
    bool? submitting,
    Map<String, OnboardingJoinResult>? results,
    Map<String, String>? failureReasons,
  }) => OnboardingCommunitiesState(
    mode: mode,
    phase: phase ?? this.phase,
    items: items ?? this.items,
    selected: selected ?? this.selected,
    failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    directoryStarted: directoryStarted ?? this.directoryStarted,
    directoryCursor: clearCursor
        ? null
        : (directoryCursor ?? this.directoryCursor),
    directoryEnded: directoryEnded ?? this.directoryEnded,
    loadingMore: loadingMore ?? this.loadingMore,
    appendFailed: appendFailed ?? this.appendFailed,
    submitting: submitting ?? this.submitting,
    results: results ?? this.results,
    failureReasons: failureReasons ?? this.failureReasons,
  );
}

/// Reads the recommendation, then the directory behind it, and joins what the
/// reader ticked — every chat muted, one community at a time, a failure on
/// one never stopping the next.
final class OnboardingCommunitiesController
    extends Notifier<OnboardingCommunitiesState> {
  var _generation = 0;

  /// A read is in the air. The page asks for `load()` on every build while
  /// the phase is `loading`, and `reload()` itself publishes a `loading`
  /// state, so without this flag each rebuild cancelled the previous read and
  /// started another (device report 2026-10-09: 1,566 requests in 20 minutes,
  /// a skeleton that never settled).
  var _reading = false;

  @override
  OnboardingCommunitiesState build() {
    _generation += 1;
    _reading = false;
    ref.onDispose(() => _generation += 1);
    final mode = ref.watch(recommendedCommunitiesGatewayProvider).mode;
    final closed = mode == CommunityGatewayMode.unavailable;
    return OnboardingCommunitiesState(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  Future<void> load() {
    if (_reading ||
        state.items.isNotEmpty ||
        state.phase != CommunityViewPhase.loading ||
        state.mode == CommunityGatewayMode.unavailable) {
      return Future<void>.value();
    }
    return reload();
  }

  Future<void> reload() async {
    if (state.mode == CommunityGatewayMode.unavailable) return;
    final generation = ++_generation;
    _reading = true;
    state = OnboardingCommunitiesState(
      mode: state.mode,
      phase: CommunityViewPhase.loading,
    );
    try {
      final answer = await ref
          .read(recommendedCommunitiesGatewayProvider)
          .load();
      if (!_current(generation)) return;
      _reading = false;
      final ids = <String>{for (final item in answer.items) item.communityId};
      state = state.copyWith(
        phase: answer.items.isEmpty
            ? CommunityViewPhase.empty
            : CommunityViewPhase.ready,
        items: List<CommunitySummary>.unmodifiable(answer.items),
        selected: <String>{
          for (final id in answer.defaultSelectedIds)
            if (ids.contains(id)) id,
        },
        clearFailure: true,
      );
      // An empty recommendation still leads into the directory.
      if (answer.items.isEmpty) unawaited(loadMore());
    } on CommunityGatewayException catch (error) {
      if (!_current(generation)) return;
      _reading = false;
      state = state.copyWith(
        phase: communityPhaseForFailure(error.kind),
        failureKind: error.kind,
      );
    } catch (_) {
      if (!_current(generation)) return;
      _reading = false;
      state = state.copyWith(
        phase: CommunityViewPhase.error,
        failureKind: CommunityFailureKind.unexpected,
      );
    }
  }

  /// The next directory page, after the recommendation.
  Future<void> loadMore() async {
    if (!state.canLoadMore) return;
    final gateway = ref.read(communityGatewayProvider);
    if (gateway.mode == CommunityGatewayMode.unavailable) {
      state = state.copyWith(directoryEnded: true);
      return;
    }
    final generation = _generation;
    final cursor = state.directoryCursor;
    state = state.copyWith(loadingMore: true, appendFailed: false);
    try {
      final page = await gateway.listCommunities(cursor: cursor);
      if (!_current(generation)) return;
      final seen = <String>{for (final item in state.items) item.communityId};
      final merged = <CommunitySummary>[
        ...state.items,
        for (final item in page.items)
          if (seen.add(item.communityId)) item,
      ];
      final next = page.nextCursor;
      state = state.copyWith(
        phase: merged.isEmpty
            ? CommunityViewPhase.empty
            : CommunityViewPhase.ready,
        items: List<CommunitySummary>.unmodifiable(merged),
        directoryStarted: true,
        directoryCursor: next,
        clearCursor: next == null,
        directoryEnded: next == null || next == cursor,
        loadingMore: false,
      );
    } catch (_) {
      if (!_current(generation)) return;
      state = state.copyWith(loadingMore: false, appendFailed: true);
    }
  }

  /// Asks for the directory page that failed, once more.
  Future<void> retryMore() {
    state = state.copyWith(appendFailed: false);
    return loadMore();
  }

  void toggle(String communityId) {
    if (state.submitting) return;
    final next = Set<String>.of(state.selected);
    if (!next.remove(communityId)) next.add(communityId);
    state = state.copyWith(selected: next);
  }

  /// Joins every ticked community in list order and mutes its chat.
  ///
  /// Returns true when every one of them joined and muted, so the page can
  /// go straight on; otherwise the page stays and says, row by row, what did
  /// not happen.
  Future<bool> enter() async {
    if (state.submitting) return false;
    final targets = <String>[
      for (final item in state.items)
        if (state.selected.contains(item.communityId) &&
            state.results[item.communityId] != OnboardingJoinResult.joined)
          item.communityId,
    ];
    state = state.copyWith(submitting: true);
    final results = Map<String, OnboardingJoinResult>.of(state.results);
    final reasons = Map<String, String>.of(state.failureReasons);
    final communities = ref.read(communityGatewayProvider);
    final muter = ref.read(communityChannelMuterProvider);
    for (final id in targets) {
      CommunityDetail detail;
      try {
        detail = await communities.join(id);
      } on CommunityGatewayException catch (error) {
        results[id] = OnboardingJoinResult.failed;
        reasons[id] = communityFailureReason(error.kind);
        if (!ref.mounted) return false;
        state = state.copyWith(
          results: Map.of(results),
          failureReasons: Map.of(reasons),
        );
        continue;
      } catch (_) {
        results[id] = OnboardingJoinResult.failed;
        reasons[id] = communityFailureReason(CommunityFailureKind.unexpected);
        if (!ref.mounted) return false;
        state = state.copyWith(
          results: Map.of(results),
          failureReasons: Map.of(reasons),
        );
        continue;
      }
      final cid = detail.chat.channelCid ?? loopCommunityChannelCid(id);
      try {
        if (cid == null) throw StateError('no_channel');
        await muter.mute(cid);
        results[id] = OnboardingJoinResult.joined;
        reasons.remove(id);
      } catch (_) {
        results[id] = OnboardingJoinResult.joinedNotMuted;
        reasons[id] = '已加入，但免打扰没有设置成功，可以在会话里手动设置。';
      }
      if (!ref.mounted) return false;
      state = state.copyWith(
        results: Map.of(results),
        failureReasons: Map.of(reasons),
      );
    }
    if (!ref.mounted) return false;
    state = state.copyWith(submitting: false);
    return !state.hasFailures;
  }
}

final onboardingCommunitiesControllerProvider =
    NotifierProvider.autoDispose<
      OnboardingCommunitiesController,
      OnboardingCommunitiesState
    >(OnboardingCommunitiesController.new);

/// `onboarding-communities` · action / stream (S107 §4, decision 0112).
///
/// The one page after registration (docs/00 §4.1): communities to join, five
/// ticked by default, every joined community's chat muted. 跳过 goes straight
/// to 聊天; nothing on this page is required.
class OnboardingCommunitiesScreen extends ConsumerStatefulWidget {
  const OnboardingCommunitiesScreen({required this.onDone, super.key});

  /// Leaves for 聊天. Called by 跳过, and by 进入 LOOP once every join has
  /// been answered.
  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingCommunitiesScreen> createState() =>
      _OnboardingCommunitiesScreenState();
}

class _OnboardingCommunitiesScreenState
    extends ConsumerState<OnboardingCommunitiesScreen> {
  Future<void> _enter(OnboardingCommunitiesController controller) async {
    final state = ref.read(onboardingCommunitiesControllerProvider);
    if (state.selected.isEmpty) {
      widget.onDone();
      return;
    }
    final clean = await controller.enter();
    if (!mounted) return;
    if (clean) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingCommunitiesControllerProvider);
    final controller = ref.read(
      onboardingCommunitiesControllerProvider.notifier,
    );
    if (state.phase == CommunityViewPhase.loading && state.items.isEmpty) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final count = state.selected.length;
    final enterLabel = state.submitting
        ? '正在加入…'
        : state.hasFailures
        ? '继续进入 LOOP'
        : count == 0
        ? '进入 LOOP'
        : '加入 $count 个社区并进入';
    return LoopStreamPage(
      key: const ValueKey<String>('onboarding-communities-screen'),
      archetype: LoopPageArchetype.action,
      title: '加入社区',
      kicker: communityPreviewKicker(state.mode),
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('onboarding-communities-skip'),
          icon: 'close',
          label: '跳过',
          onPressed: state.submitting ? null : widget.onDone,
        ),
      ],
      footnote: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopButton(
              key: const ValueKey<String>('onboarding-communities-enter'),
              label: enterLabel,
              primary: true,
              block: true,
              onPressed: state.submitting
                  ? null
                  : state.hasFailures
                  ? widget.onDone
                  : () => unawaited(_enter(controller)),
            ),
            const SizedBox(height: 6),
            TextButton(
              key: const ValueKey<String>('onboarding-communities-skip-text'),
              onPressed: state.submitting ? null : widget.onDone,
              child: Text(
                '跳过',
                style: LoopTypography.label(14, color: LoopColors.muted),
              ),
            ),
          ],
        ),
      ),
      collection: ListView(
        key: const ValueKey<String>('onboarding-communities-list'),
        padding: const EdgeInsets.only(bottom: 16),
        children: <Widget>[
          CommunityPreviewNotice(mode: state.mode, resource: '推荐社区'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Text(
              '选几个感兴趣的社区。加入后默认免打扰，随时可以退出。',
              style: LoopTypography.body(14, color: LoopColors.text2),
            ),
          ),
          if (state.phase != CommunityViewPhase.ready)
            CommunityStateBlock(
              key: const ValueKey<String>('onboarding-communities-state'),
              phase: state.phase,
              failureKind: state.failureKind,
              skeleton: LoopSkeletonType.record,
              rows: 5,
              emptyMessage: '还没有可加入的社区',
              emptyReason: '可以先进入 LOOP，之后在广场里找社区。',
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            LoopRecordGroup(
              key: const ValueKey<String>('onboarding-communities-group'),
              rows: <LoopRecordRow>[
                for (var index = 0; index < state.items.length; index += 1)
                  _row(
                    state,
                    controller,
                    state.items[index],
                    communityRowPosition(index, state.items.length),
                  ),
              ],
            ),
            if (state.appendFailed)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LoopButton(
                  key: const ValueKey<String>(
                    'onboarding-communities-retry-more',
                  ),
                  label: '重试',
                  block: true,
                  onPressed: () => unawaited(controller.retryMore()),
                ),
              )
            else if (!state.directoryEnded) ...<Widget>[
              LoopLoadMoreSentinel(
                key: const ValueKey<String>('onboarding-communities-load-more'),
                cursor: state.directoryCursor ?? 'recommended',
                onLoadMore: () => unawaited(controller.loadMore()),
              ),
              if (state.loadingMore)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: LoopSkeleton(type: LoopSkeletonType.record, rows: 1),
                ),
            ] else
              const LoopProvenanceFooter(
                key: ValueKey<String>('onboarding-communities-end'),
                text: '没有更多社区',
              ),
          ],
        ],
      ),
    );
  }

  LoopRecordRow _row(
    OnboardingCommunitiesState state,
    OnboardingCommunitiesController controller,
    CommunitySummary community,
    LoopRowPosition position,
  ) {
    final id = community.communityId;
    final selected = state.selected.contains(id);
    final result = state.results[id];
    final reason = state.failureReasons[id];
    final members =
        '${loopFormatDecimal(Decimal.fromInt(community.memberCount), maxFractionDigits: 0)} 成员';
    return LoopRecordRow(
      key: ValueKey<String>('onboarding-community-$id'),
      leading: CommunityLogo(
        identity: id,
        name: community.name,
        logoRef: community.logoRef,
        size: 40,
        radius: 12,
      ),
      title: community.name,
      subtitle: switch (result) {
        OnboardingJoinResult.joined => '已加入 · 已免打扰',
        OnboardingJoinResult.joinedNotMuted ||
        OnboardingJoinResult.failed => reason ?? '没有加入成功',
        null =>
          community.description == null
              ? members
              : '$members · ${community.description}',
      },
      subtitleMaxLines: 2,
      trailingBadge: LoopBadge(
        result == OnboardingJoinResult.joined
            ? '已加入'
            : selected
            ? '已选'
            : '未选',
        key: ValueKey<String>('onboarding-community-badge-$id'),
        kind: selected ? LoopBadgeKind.mining : LoopBadgeKind.mute,
      ),
      selected: selected,
      chevron: false,
      position: position,
      onTap: state.submitting || result == OnboardingJoinResult.joined
          ? null
          : () => controller.toggle(id),
      semanticLabel: '${community.name}，$members，${selected ? '已选' : '未选'}',
    );
  }
}
