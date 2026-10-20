import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/intel/intel_rank_controller.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart'
    show LoopProfileAvatar;
import 'package:loop_mobile/features/social/profile_face_link.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';

/// 邀请中心 · 推广榜 (S239): the referrals board, read on its own so the
/// 情报 board's selected chip and pages are never moved by this page.
@immutable
final class ReferralBoardState {
  const ReferralBoardState({
    required this.phase,
    this.rank,
    this.failureKind,
    this.loadingMore = false,
    this.appendFailed = false,
  });

  final LaunchViewPhase phase;
  final MiningRank? rank;
  final LaunchFailureKind? failureKind;
  final bool loadingMore;
  final bool appendFailed;
}

final class ReferralBoardController extends Notifier<ReferralBoardState>
    with LaunchSingleFlight {
  @override
  ReferralBoardState build() {
    nextGeneration();
    final mode = ref.watch(miningGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return mode == LaunchGatewayMode.unavailable
        ? const ReferralBoardState(
            phase: LaunchViewPhase.unavailable,
            failureKind: LaunchFailureKind.unavailable,
          )
        : const ReferralBoardState(phase: LaunchViewPhase.loading);
  }

  Future<void> load() {
    if (state.rank != null) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final gateway = ref.read(miningGatewayProvider);
    final generation = nextGeneration();
    final held = state.rank;
    state = ReferralBoardState(
      phase: held == null ? LaunchViewPhase.loading : LaunchViewPhase.ready,
      rank: held,
    );
    try {
      final rank = await gateway.loadRank(MiningRankScope.referrals);
      if (!isCurrent(generation)) return;
      state = ReferralBoardState(phase: LaunchViewPhase.ready, rank: rank);
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return;
      state = _failed(error.kind, held);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = _failed(LaunchFailureKind.unexpected, held);
    }
  });

  ReferralBoardState _failed(LaunchFailureKind kind, MiningRank? held) =>
      ReferralBoardState(
        phase: held == null
            ? launchPhaseForFailure(kind)
            : LaunchViewPhase.ready,
        rank: held,
        failureKind: kind,
      );

  Future<void> loadMore() {
    final current = state.rank;
    final cursor = current?.nextCursor;
    if (current == null || cursor == null || state.loadingMore) {
      return Future<void>.value();
    }
    return single(() async {
      final gateway = ref.read(miningGatewayProvider);
      final generation = nextGeneration();
      state = ReferralBoardState(
        phase: state.phase,
        rank: current,
        loadingMore: true,
      );
      try {
        final page = await gateway.loadRank(
          MiningRankScope.referrals,
          cursor: cursor,
        );
        if (!isCurrent(generation)) return;
        state = ReferralBoardState(
          phase: LaunchViewPhase.ready,
          rank: intelRankAppend(current, page),
        );
      } catch (_) {
        if (!isCurrent(generation)) return;
        state = ReferralBoardState(
          phase: state.phase,
          rank: current,
          appendFailed: true,
        );
      }
    });
  }
}

final referralBoardControllerProvider =
    NotifierProvider.autoDispose<ReferralBoardController, ReferralBoardState>(
      ReferralBoardController.new,
    );

/// The board's rows: every place the pages read so far hold, each face
/// opening its owner's page (an anonymous inviter opens nothing).
class IntelReferralBoardSection extends ConsumerStatefulWidget {
  const IntelReferralBoardSection({this.onNavigate, super.key});

  /// Pushes a profile location; defaults to the ambient router.
  final ValueChanged<String>? onNavigate;

  @override
  ConsumerState<IntelReferralBoardSection> createState() =>
      _IntelReferralBoardSectionState();
}

class _IntelReferralBoardSectionState
    extends ConsumerState<IntelReferralBoardSection> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(referralBoardControllerProvider);
    final controller = ref.read(referralBoardControllerProvider.notifier);
    if (state.phase == LaunchViewPhase.loading && state.rank == null) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final rank = state.rank;
    if (rank == null) {
      return LaunchStateBlock(
        prefix: 'referral-board',
        phase: state.phase,
        failureKind: state.failureKind,
        skeleton: LoopSkeletonType.record,
        rows: 3,
        emptyMessage: '推广榜暂时读不到',
        emptyReason: '暂时读不到推广榜。',
        onRetry: () => unawaited(controller.reload()),
      );
    }
    final ranking = rank.ranking;
    final children = <Widget>[];
    switch (ranking) {
      case MiningRankingReferrals(:final items) when items.isNotEmpty:
        Decimal? leader;
        for (final row in items) {
          if (row.position == 1 && row.invitedCount > 0) {
            leader = Decimal.fromInt(row.invitedCount);
            break;
          }
        }
        for (var index = 0; index < items.length; index += 1) {
          final row = items[index];
          final display = row.display;
          final (String? id, String name, String? avatar) = switch (display) {
            MiningRankAlias(
              :final publicProfileId,
              :final alias,
              :final avatarRef,
            ) =>
              (publicProfileId, alias, avatarRef),
            MiningRankAnonymous(:final labelKey) => (
              null,
              miningRuleKeyText(labelKey),
              null,
            ),
          };
          final location = loopProfileFaceLocation(id, isSelf: row.isSelf);
          children.add(
            IntelRankRow(
              key: ValueKey<String>('referral-board-row-$index'),
              position: row.position,
              leading: LoopProfileAvatar(
                avatarRef: avatar,
                alias: display is MiningRankAnonymous ? '匿名' : name,
                size: intelRankRowFaceSize,
              ),
              name: name,
              caption: '直接邀请',
              isSelf: row.isSelf,
              figure: '${row.invitedCount}',
              share: intelRankShare(Decimal.fromInt(row.invitedCount), leader),
              spoken: '邀请人数',
              onTap: location == null ? null : () => _open(location),
            ),
          );
        }
      case MiningRankingUnavailable(:final reasonCode):
        children.add(
          LoopInlineUnavailable(
            key: const ValueKey<String>('referral-board-unavailable'),
            message: '推广榜暂时读不到 · ${launchReasonCodeText(reasonCode)}',
            onRetry: () => unawaited(controller.reload()),
          ),
        );
      default:
        children.add(
          const LoopInlineUnavailable(
            key: ValueKey<String>('referral-board-empty'),
            icon: 'users',
            message: '还没有人邀请到好友',
            detail: '邀请到第一位好友后，这里按直接邀请人数排名。',
          ),
        );
    }
    children.add(
      LoopLoadMoreFooter(
        key: const ValueKey<String>('referral-board-footer'),
        keyPrefix: 'referral-board',
        cursor: rank.nextCursor,
        canLoadMore: !state.loadingMore,
        loading: state.loadingMore,
        onLoadMore: controller.loadMore,
      ),
    );
    return Column(
      key: const ValueKey<String>('referral-board'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  void _open(String location) {
    final navigate = widget.onNavigate;
    if (navigate != null) {
      navigate(location);
      return;
    }
    LoopProfileFaceLink.push(context, location);
  }
}
