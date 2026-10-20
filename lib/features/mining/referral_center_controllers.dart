import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/mining/referral_gateway.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';

/// 邀请中心 · 我的邀请 (S239, loop-api decision 0162 §B.1): the direct
/// invitees, newest binding first, read page by page.
@immutable
final class ReferralInviteesState {
  const ReferralInviteesState({
    required this.phase,
    this.items = const <ReferralInvitee>[],
    this.nextCursor,
    this.failureKind,
    this.loadingMore = false,
    this.appendFailed = false,
    this.refreshing = false,
  });

  final LaunchViewPhase phase;
  final List<ReferralInvitee> items;
  final String? nextCursor;
  final LaunchFailureKind? failureKind;
  final bool loadingMore;

  /// A later page failed; the rows already read stay on screen.
  final bool appendFailed;
  final bool refreshing;

  bool get hasRead => phase == LaunchViewPhase.ready;
}

final class ReferralInviteesController extends Notifier<ReferralInviteesState>
    with LaunchSingleFlight {
  @override
  ReferralInviteesState build() {
    nextGeneration();
    final mode = ref.watch(referralGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return mode == LaunchGatewayMode.unavailable
        ? const ReferralInviteesState(
            phase: LaunchViewPhase.unavailable,
            failureKind: LaunchFailureKind.unavailable,
          )
        : const ReferralInviteesState(phase: LaunchViewPhase.loading);
  }

  Future<void> load() {
    if (state.hasRead) return Future<void>.value();
    return reload();
  }

  /// Reads the first page again. Rows already on screen stay until it lands.
  Future<void> reload() => single(() async {
    final gateway = ref.read(referralGatewayProvider);
    final generation = nextGeneration();
    final shown = state.hasRead;
    state = ReferralInviteesState(
      phase: shown ? LaunchViewPhase.ready : LaunchViewPhase.loading,
      items: state.items,
      nextCursor: state.nextCursor,
      refreshing: shown,
    );
    try {
      final page = await gateway.loadInvitees();
      if (!isCurrent(generation)) return;
      state = ReferralInviteesState(
        phase: LaunchViewPhase.ready,
        items: page.items,
        nextCursor: page.nextCursor,
      );
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return;
      state = _failed(error.kind, shown);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = _failed(LaunchFailureKind.unexpected, shown);
    }
  });

  ReferralInviteesState _failed(LaunchFailureKind kind, bool shown) =>
      ReferralInviteesState(
        phase: shown ? LaunchViewPhase.ready : launchPhaseForFailure(kind),
        items: state.items,
        nextCursor: state.nextCursor,
        failureKind: kind,
      );

  /// Appends the next page. A failure keeps every row already read.
  Future<void> loadMore() {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore || !state.hasRead) {
      return Future<void>.value();
    }
    return single(() async {
      final gateway = ref.read(referralGatewayProvider);
      final generation = nextGeneration();
      state = ReferralInviteesState(
        phase: state.phase,
        items: state.items,
        nextCursor: cursor,
        loadingMore: true,
      );
      try {
        final page = await gateway.loadInvitees(cursor: cursor);
        if (!isCurrent(generation)) return;
        state = ReferralInviteesState(
          phase: LaunchViewPhase.ready,
          items: List<ReferralInvitee>.unmodifiable(<ReferralInvitee>[
            ...state.items,
            ...page.items,
          ]),
          nextCursor: page.nextCursor,
        );
      } catch (_) {
        if (!isCurrent(generation)) return;
        state = ReferralInviteesState(
          phase: state.phase,
          items: state.items,
          nextCursor: cursor,
          appendFailed: true,
        );
      }
    });
  }
}

final referralInviteesControllerProvider =
    NotifierProvider.autoDispose<
      ReferralInviteesController,
      ReferralInviteesState
    >(ReferralInviteesController.new);
