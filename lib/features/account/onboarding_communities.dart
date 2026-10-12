import 'dart:async';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
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
/// page test has none. Since S135 (decision 0136) it is the manual mute of a
/// channel the reader is already in; a join never calls it — the join asks
/// the server to mute (`notifications: muted`), because right after a join
/// the reader is not yet a channel member and Stream refuses the mute.
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
enum OnboardingJoinResult {
  /// Joined, and the server confirmed the chat is muted.
  joined,

  /// Joined; the server mutes the chat as soon as it has put the reader into
  /// it (decision 0136). Not a failure.
  joinedMutePending,
  failed;

  bool get isJoined => this != failed;
}

/// How often, and how many times, the page asks whether the server finished
/// muting the chats it just joined (decision 0136): about ten seconds.
const onboardingMuteSyncInterval = Duration(seconds: 1);
const onboardingMuteSyncRounds = 10;

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
    this.settling = false,
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

  /// Joins are done; the page is waiting (at most ~10 s) for the server to
  /// confirm the mutes. The reader may leave at any time.
  final bool settling;

  /// Filled in by [OnboardingCommunitiesController.enter], one per ticked row.
  final Map<String, OnboardingJoinResult> results;
  final Map<String, String> failureReasons;

  bool get hasFailures =>
      results.values.any((result) => result == OnboardingJoinResult.failed);

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
    bool? settling,
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
    settling: settling ?? this.settling,
    results: results ?? this.results,
    failureReasons: failureReasons ?? this.failureReasons,
  );
}

/// Reads the recommendation, then the directory behind it, and joins what the
/// reader ticked — every join asking the server to mute the chat, one
/// community at a time, a failure on one never stopping the next.
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

  /// Joins every ticked community in list order, each with
  /// `notifications: muted` (decision 0136). The server mutes the chat once
  /// it has added the reader to it; the page does not touch Stream.
  ///
  /// Returns true when every one of them joined, so the page can go on;
  /// otherwise the page stays and says, row by row, what did not happen.
  Future<bool> enter() async {
    if (state.submitting) return false;
    final targets = <String>[
      for (final item in state.items)
        if (state.selected.contains(item.communityId) &&
            !(state.results[item.communityId]?.isJoined ?? false))
          item.communityId,
    ];
    state = state.copyWith(submitting: true);
    final results = Map<String, OnboardingJoinResult>.of(state.results);
    final reasons = Map<String, String>.of(state.failureReasons);
    final communities = ref.read(communityGatewayProvider);
    for (final id in targets) {
      try {
        await communities.join(
          id,
          notifications: CommunityNotificationPreference.muted,
        );
        results[id] = OnboardingJoinResult.joinedMutePending;
        reasons.remove(id);
      } on CommunityGatewayException catch (error) {
        results[id] = OnboardingJoinResult.failed;
        reasons[id] = communityFailureReason(error.kind);
      } catch (_) {
        results[id] = OnboardingJoinResult.failed;
        reasons[id] = communityFailureReason(CommunityFailureKind.unexpected);
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

  /// Asks the server, about once a second for at most
  /// [onboardingMuteSyncRounds] rounds, whether the chats just joined are
  /// in place and muted, and turns each row to 已免打扰 when they are. A row
  /// the server has not confirmed in time keeps 免打扰生效中: the server still
  /// mutes it, the page just stops waiting. A read that fails ends the wait
  /// for that row (an older server without the read answers 404).
  Future<void> settleMutes() async {
    var pending = <String>[
      for (final entry in state.results.entries)
        if (entry.value == OnboardingJoinResult.joinedMutePending) entry.key,
    ];
    if (pending.isEmpty || state.settling) return;
    final generation = _generation;
    final gateway = ref.read(communityGatewayProvider);
    state = state.copyWith(settling: true);
    for (
      var round = 0;
      round < onboardingMuteSyncRounds && pending.isNotEmpty;
      round += 1
    ) {
      await Future<void>.delayed(onboardingMuteSyncInterval);
      if (!_current(generation)) return;
      final answers = await Future.wait<bool?>(<Future<bool?>>[
        for (final id in pending) _channelSynced(gateway, id),
      ]);
      if (!_current(generation)) return;
      final results = Map<String, OnboardingJoinResult>.of(state.results);
      final still = <String>[];
      for (var index = 0; index < pending.length; index += 1) {
        final answer = answers[index];
        if (answer == true) {
          results[pending[index]] = OnboardingJoinResult.joined;
        } else if (answer == false) {
          still.add(pending[index]);
        }
      }
      pending = still;
      state = state.copyWith(results: results);
    }
    if (!_current(generation)) return;
    state = state.copyWith(settling: false);
  }

  /// `true` / `false` from the server; `null` when the read failed.
  static Future<bool?> _channelSynced(
    CommunityGateway gateway,
    String communityId,
  ) async {
    try {
      return (await gateway.loadMembershipSync(communityId)).channelSynced;
    } catch (_) {
      return null;
    }
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

  /// Leaves for 聊天. Called by 跳过, by 继续进入 LOOP after a failed join,
  /// and at the end of the 正在进入 LOOP page once every join succeeded
  /// (decision 0151).
  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingCommunitiesScreen> createState() =>
      _OnboardingCommunitiesScreenState();
}

class _OnboardingCommunitiesScreenState
    extends ConsumerState<OnboardingCommunitiesScreen> {
  var _left = false;

  /// Every ticked community joined: the list gives way to the full-page
  /// 正在进入 LOOP while the mutes settle, then the page leaves by itself
  /// (decision 0151). Set in the same turn [OnboardingCommunitiesController.enter]
  /// answers, so the list never draws a frame of the clean result.
  var _entering = false;

  /// The communities the entering page gathers in, fixed when it opens.
  var _joined = const <CommunitySummary>[];

  /// Leaves for 聊天 exactly once, whichever of 跳过, the button, or the end
  /// of the mute wait gets there first.
  void _leave() {
    if (_left) return;
    _left = true;
    widget.onDone();
  }

  Future<void> _enter(OnboardingCommunitiesController controller) async {
    final state = ref.read(onboardingCommunitiesControllerProvider);
    if (state.selected.isEmpty) {
      _leave();
      return;
    }
    final clean = await controller.enter();
    if (!mounted) return;
    if (!clean) {
      // The page stays to say what failed; the joined rows still turn to
      // 已免打扰 as the server confirms them.
      unawaited(controller.settleMutes());
      return;
    }
    // Decision 0136 waits (about ten seconds at most) for the server to
    // confirm the mutes. Decision 0151: that wait is the 正在进入 LOOP page,
    // not the list with a renamed button; it offers no way out, ends by
    // itself at the ceiling, and stays at least long enough for its
    // gathering to play out, so it never just flashes.
    final joined = ref.read(onboardingCommunitiesControllerProvider);
    setState(() {
      _entering = true;
      _joined = <CommunitySummary>[
        for (final item in joined.items)
          if (joined.results[item.communityId]?.isJoined ?? false) item,
      ];
    });
    await Future.wait<void>(<Future<void>>[
      controller.settleMutes(),
      Future<void>.delayed(onboardingEnteringMinimumStay),
    ]);
    if (!mounted) return;
    _leave();
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
    if (_entering) return OnboardingCommunitiesEntering(communities: _joined);
    final count = state.selected.length;
    // Decision 0151: the list is only ever on screen while submitting, after a
    // failed join, or before the button is pressed; a clean result is the
    // entering page above, so there is no 「进入 LOOP while settling」 label.
    final enterLabel = state.submitting
        ? '正在加入…'
        : state.hasFailures
        ? '继续进入 LOOP'
        : count == 0
        ? '进入 LOOP'
        : '加入 $count 个社区并进入';
    // Decision 0126: the last step of the opening, flat — Logo 36, name and
    // members, a Lime tick circle on the right.
    return LoopFlat(
      step: true,
      child: LoopStreamPage(
        key: const ValueKey<String>('onboarding-communities-screen'),
        archetype: LoopPageArchetype.action,
        title: '加入社区',
        kicker: communityPreviewKicker(state.mode),
        actions: <Widget>[
          LoopIconButton(
            key: const ValueKey<String>('onboarding-communities-skip'),
            icon: 'close',
            label: '跳过',
            onPressed: state.submitting ? null : _leave,
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
                    ? _leave
                    : () => unawaited(_enter(controller)),
              ),
              const SizedBox(height: 6),
              TextButton(
                key: const ValueKey<String>('onboarding-communities-skip-text'),
                onPressed: state.submitting ? null : _leave,
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
                  key: const ValueKey<String>(
                    'onboarding-communities-load-more',
                  ),
                  cursor: state.directoryCursor ?? 'recommended',
                  onLoadMore: () => unawaited(controller.loadMore()),
                ),
                if (state.loadingMore)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: LoopSkeleton(type: LoopSkeletonType.record, rows: 1),
                  ),
              ] else
                // Decision 0126 (S121 §1.1.1 #10): the end draws nothing.
                const SizedBox(
                  key: ValueKey<String>('onboarding-communities-end'),
                  height: 12,
                ),
            ],
          ],
        ),
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
        size: 36,
        radius: 18,
      ),
      title: community.name,
      subtitle: switch (result) {
        OnboardingJoinResult.joined => '已加入 · 已免打扰',
        OnboardingJoinResult.joinedMutePending => '已加入 · 免打扰生效中',
        OnboardingJoinResult.failed => reason ?? '没有加入成功',
        null => members,
      },
      subtitleMaxLines: 1,
      trailingBadge: _OnboardingTick(
        key: ValueKey<String>('onboarding-community-badge-$id'),
        state: result?.isJoined ?? false
            ? '已加入'
            : selected
            ? '已选'
            : '未选',
        on: selected || (result?.isJoined ?? false),
      ),
      selected: selected,
      chevron: false,
      position: position,
      onTap: state.submitting || (result?.isJoined ?? false)
          ? null
          : () => controller.toggle(id),
      semanticLabel: '${community.name}，$members，${selected ? '已选' : '未选'}',
    );
  }
}

/// The shortest the 正在进入 LOOP page stays, so the gathering, the ring
/// (1.8–2.4 s) and the wordmark's arrival (from 2.0 s) all play out even when
/// the server confirms every mute at once (decision 0151).
const onboardingEnteringMinimumStay = Duration(milliseconds: 2600);

/// How many joined communities the entering page gathers in.
const onboardingEnteringLogoLimit = 5;

/// `onboarding-communities` · state / focus: 正在进入 LOOP (decision 0151).
///
/// What the page becomes once every ticked community joined, for as long as
/// [OnboardingCommunitiesController.settleMutes] waits on the server (about
/// ten seconds at most, never less than [onboardingEnteringMinimumStay]).
///
/// The communities just joined circle the centre, spiral in and fade; a Lime
/// point opens into a soft ring where they met, and the LOOP wordmark stays,
/// breathing on a low Lime glow, until the page leaves. Only transforms and
/// opacities move; nothing is laid out again while it plays. With reduced
/// motion the page draws that last frame and holds still.
///
/// The ground and safe area are the launch page's (`SplashScreen`). Waiting
/// is not a choice, so it offers no button and no way back.
class OnboardingCommunitiesEntering extends StatefulWidget {
  const OnboardingCommunitiesEntering({required this.communities, super.key});

  /// The communities that joined, in list order; the first
  /// [onboardingEnteringLogoLimit] are drawn.
  final List<CommunitySummary> communities;

  static const String title = '正在进入 LOOP';
  static const String detail = '正在为你把刚加入的社区设为免打扰…';

  /// Orbit until here, then gather (1.2 s – 1.8 s), then the ring (0.6 s).
  static const Duration orbitEnd = Duration(milliseconds: 1200);
  static const Duration gatherEnd = Duration(milliseconds: 1800);
  static const Duration ringEnd = Duration(milliseconds: 2400);

  /// One turn of the orbit.
  static const Duration turn = Duration(milliseconds: 2400);

  /// One full breath of the glow under the wordmark.
  static const Duration breath = Duration(milliseconds: 1600);

  static const double orbitRadius = 96;
  static const double logoSize = 40;
  static const double pointSize = 12;
  static const double ringRadius = 72;

  @override
  State<OnboardingCommunitiesEntering> createState() =>
      _OnboardingCommunitiesEnteringState();
}

class _OnboardingCommunitiesEnteringState
    extends State<OnboardingCommunitiesEntering>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: OnboardingCommunitiesEntering.ringEnd,
  );
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: OnboardingCommunitiesEntering.breath ~/ 2,
  );
  var _still = false;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_still) {
        _breath.repeat(reverse: true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.disableAnimationsOf(context);
    if (still == _still && (_intro.isAnimating || _intro.isCompleted)) return;
    _still = still;
    if (still) {
      _intro.stop();
      _breath.stop();
      _intro.value = 1;
      _breath.value = 0.5;
    } else if (!_intro.isCompleted) {
      unawaited(_intro.forward());
    } else if (!_breath.isAnimating) {
      unawaited(_breath.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _breath.dispose();
    super.dispose();
  }

  /// [_intro] between [from] and [to] on the timeline, through [curve].
  Animation<double> _phase(
    Duration from,
    Duration to, [
    Curve curve = Curves.linear,
  ]) {
    final total = OnboardingCommunitiesEntering.ringEnd.inMicroseconds;
    return CurvedAnimation(
      parent: _intro,
      curve: Interval(
        from.inMicroseconds / total,
        to.inMicroseconds / total,
        curve: curve,
      ),
    );
  }

  late final Animation<double> _gather = _phase(
    OnboardingCommunitiesEntering.orbitEnd,
    OnboardingCommunitiesEntering.gatherEnd,
    Curves.easeInCubic,
  );
  late final Animation<double> _pop = _phase(
    const Duration(milliseconds: 1650),
    OnboardingCommunitiesEntering.gatherEnd,
    Curves.easeOutBack,
  );
  late final Animation<double> _ring = _phase(
    OnboardingCommunitiesEntering.gatherEnd,
    OnboardingCommunitiesEntering.ringEnd,
    Curves.easeOutCubic,
  );
  late final Animation<double> _pointFade = _phase(
    OnboardingCommunitiesEntering.gatherEnd,
    const Duration(milliseconds: 2000),
    Curves.easeOut,
  );
  late final Animation<double> _arrive = _phase(
    const Duration(milliseconds: 2000),
    OnboardingCommunitiesEntering.ringEnd,
    Curves.easeOut,
  );
  late final Animation<double> _copy = _phase(
    OnboardingCommunitiesEntering.gatherEnd,
    const Duration(milliseconds: 2200),
    Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final logos = widget.communities
        .take(onboardingEnteringLogoLimit)
        .toList(growable: false);
    const stage =
        OnboardingCommunitiesEntering.orbitRadius * 2 +
        OnboardingCommunitiesEntering.logoSize +
        16;
    return PopScope(
      canPop: false,
      child: Scaffold(
        key: const ValueKey<String>('onboarding-communities-entering'),
        body: SafeArea(
          child: SizedBox.expand(
            child: Column(
              children: <Widget>[
                const Spacer(),
                SizedBox.square(
                  dimension: stage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      _glow(),
                      _ringLayer(),
                      _point(),
                      for (var index = 0; index < logos.length; index += 1)
                        _logo(logos[index], index, logos.length),
                      _wordmark(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FadeTransition(
                  opacity: _copy,
                  child: Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: <Widget>[
                          Text(
                            OnboardingCommunitiesEntering.title,
                            key: const ValueKey<String>(
                              'onboarding-entering-title',
                            ),
                            textAlign: TextAlign.center,
                            style: LoopTypography.title(16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            OnboardingCommunitiesEntering.detail,
                            textAlign: TextAlign.center,
                            style: LoopTypography.caption(
                              12,
                              color: LoopColors.text3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One joined community: on the orbit, then spiralling in, shrinking to
  /// 0.4 and fading out. Gone from the tree once gathered.
  Widget _logo(CommunitySummary community, int index, int count) {
    final key = ValueKey<String>(
      'onboarding-entering-logo-${community.communityId}',
    );
    final tile = FadeTransition(
      opacity: ReverseAnimation(_gather),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 0.4).animate(_gather),
        child: CommunityLogo(
          identity: community.communityId,
          name: community.name,
          logoRef: community.logoRef,
          size: OnboardingCommunitiesEntering.logoSize,
          radius: OnboardingCommunitiesEntering.logoSize / 2,
        ),
      ),
    );
    return AnimatedBuilder(
      key: key,
      animation: _intro,
      child: tile,
      builder: (context, child) {
        final gather = _gather.value;
        if (_gather.isCompleted || gather >= 1) {
          return const SizedBox.shrink();
        }
        final elapsed =
            _intro.value * OnboardingCommunitiesEntering.ringEnd.inMicroseconds;
        final travel = OnboardingCommunitiesEntering.gatherEnd.inMicroseconds;
        // easeInOut start: the orbit picks up speed, the spiral carries it.
        final turns =
            Curves.easeInOut.transform((elapsed / travel).clamp(0.0, 1.0)) *
            travel /
            OnboardingCommunitiesEntering.turn.inMicroseconds;
        final angle =
            -math.pi / 2 +
            index * 2 * math.pi / count +
            turns * 2 * math.pi +
            gather * math.pi;
        final radius = OnboardingCommunitiesEntering.orbitRadius * (1 - gather);
        return Transform.translate(
          offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius),
          child: child,
        );
      },
    );
  }

  /// Draws [child] only while [_intro] is inside [from]..[to], so nothing
  /// stays painted at nothing before or after its moment.
  Widget _during(Duration from, Duration to, Widget child) {
    final total = OnboardingCommunitiesEntering.ringEnd.inMicroseconds;
    final start = from.inMicroseconds / total;
    final end = to.inMicroseconds / total;
    return AnimatedBuilder(
      animation: _intro,
      child: child,
      builder: (context, child) =>
          !_still && _intro.value > start && _intro.value < end
          ? child!
          : const SizedBox.shrink(),
    );
  }

  /// The Lime point where they meet: it pops in as the logos arrive, then
  /// gives way to [_ringLayer].
  Widget _point() => _during(
    const Duration(milliseconds: 1650),
    const Duration(milliseconds: 2000),
    FadeTransition(
      opacity: ReverseAnimation(_pointFade),
      child: ScaleTransition(
        scale: _pop,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: LoopColors.lime,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: OnboardingCommunitiesEntering.pointSize,
          ),
        ),
      ),
    ),
  );

  /// The soft ring: radius 12 → 72, opacity 0.8 → 0, easeOutCubic, 600 ms.
  Widget _ringLayer() {
    const from =
        OnboardingCommunitiesEntering.pointSize /
        2 /
        OnboardingCommunitiesEntering.ringRadius;
    return _during(
      OnboardingCommunitiesEntering.gatherEnd,
      OnboardingCommunitiesEntering.ringEnd,
      FadeTransition(
        opacity: Tween<double>(begin: 0.8, end: 0).animate(_ring),
        child: ScaleTransition(
          scale: Tween<double>(begin: from, end: 1).animate(_ring),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  LoopColors.lime.withValues(alpha: 0.05),
                  LoopColors.lime.withValues(alpha: 0.55),
                  LoopColors.lime.withValues(alpha: 0),
                ],
                stops: const <double>[0.55, 0.85, 1],
              ),
            ),
            child: const SizedBox.square(
              dimension: OnboardingCommunitiesEntering.ringRadius * 2,
            ),
          ),
        ),
      ),
    );
  }

  /// The low Lime glow under the wordmark, breathing 0.35 ↔ 0.6 every
  /// [OnboardingCommunitiesEntering.breath].
  Widget _glow() => FadeTransition(
    opacity: _arrive,
    child: FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 0.6,
      ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              LoopColors.lime.withValues(alpha: 0.45),
              LoopColors.lime.withValues(alpha: 0),
            ],
          ),
        ),
        child: const SizedBox(width: 168, height: 168),
      ),
    ),
  );

  /// LOOP, after the ring.
  Widget _wordmark() => FadeTransition(
    opacity: _arrive,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1).animate(_arrive),
      child: const LoopBrandMark(
        key: ValueKey<String>('onboarding-entering-wordmark'),
        kind: LoopBrandMarkKind.wordmark,
        height: 40,
        semanticLabel: 'LOOP',
      ),
    ),
  );
}

/// The Lime tick circle of a chosen community (decision 0126): a filled Lime
/// disc with an Ink tick, or an empty ring. The state word stays its name.
class _OnboardingTick extends StatelessWidget {
  const _OnboardingTick({required this.state, required this.on, super.key});

  final String state;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: state,
      excludeSemantics: true,
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? LoopColors.lime : Colors.transparent,
          shape: BoxShape.circle,
          border: on ? null : Border.all(color: LoopColors.line2, width: 1.5),
        ),
        child: on
            ? const LoopIcon('check', size: 15, color: LoopColors.ink)
            : null,
      ),
    );
  }
}
