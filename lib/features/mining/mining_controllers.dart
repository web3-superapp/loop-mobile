import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/referral_gateway.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';

/// One read-only `mining` resource, wired to the same five reviewed states the
/// launch controllers use.
abstract base class MiningReadController<T>
    extends Notifier<LaunchResourceState<T>>
    with LaunchSingleFlight {
  @override
  LaunchResourceState<T> build() {
    nextGeneration();
    final mode = ref.watch(miningGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return LaunchResourceState<T>.initial(mode);
  }

  Future<T> fetch(MiningGateway gateway);

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final gateway = ref.read(miningGatewayProvider);
    final generation = nextGeneration();
    state = state.loading();
    try {
      final value = await fetch(gateway);
      if (!isCurrent(generation)) return;
      state = state.ready(value);
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return;
      state = state.failed(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = state.failed(LaunchFailureKind.unexpected);
    }
  });
}

final class MiningSummaryController
    extends MiningReadController<MiningSummary> {
  @override
  Future<MiningSummary> fetch(MiningGateway gateway) => gateway.loadSummary();
}

final miningSummaryControllerProvider =
    NotifierProvider.autoDispose<
      MiningSummaryController,
      LaunchResourceState<MiningSummary>
    >(MiningSummaryController.new);

final class MiningAssetsController extends MiningReadController<MiningAssets> {
  @override
  Future<MiningAssets> fetch(MiningGateway gateway) => gateway.loadAssets();
}

final miningAssetsControllerProvider =
    NotifierProvider.autoDispose<
      MiningAssetsController,
      LaunchResourceState<MiningAssets>
    >(MiningAssetsController.new);

final class MiningRewardsController
    extends MiningReadController<MiningRewards> {
  @override
  Future<MiningRewards> fetch(MiningGateway gateway) => gateway.loadRewards();
}

final miningRewardsControllerProvider =
    NotifierProvider.autoDispose<
      MiningRewardsController,
      LaunchResourceState<MiningRewards>
    >(MiningRewardsController.new);

final class MiningRulesController extends MiningReadController<MiningRules> {
  @override
  Future<MiningRules> fetch(MiningGateway gateway) => gateway.loadRules();
}

final miningRulesControllerProvider =
    NotifierProvider.autoDispose<
      MiningRulesController,
      LaunchResourceState<MiningRules>
    >(MiningRulesController.new);

/// The ranking. Its scope is page state; switching scope discards the previous
/// answer instead of relabelling it.
final class MiningRankController extends MiningReadController<MiningRank> {
  @override
  LaunchResourceState<MiningRank> build() {
    _scope = MiningRankScope.communities;
    return super.build();
  }

  MiningRankScope _scope = MiningRankScope.communities;

  MiningRankScope get scope => _scope;

  Future<void> select(MiningRankScope scope) {
    if (_scope == scope && state.isReady) return Future<void>.value();
    _scope = scope;
    return reload();
  }

  @override
  Future<MiningRank> fetch(MiningGateway gateway) => gateway.loadRank(_scope);
}

final miningRankControllerProvider =
    NotifierProvider.autoDispose<
      MiningRankController,
      LaunchResourceState<MiningRank>
    >(MiningRankController.new);

final class MiningCommunityController
    extends MiningReadController<MiningCommunity> {
  @override
  LaunchResourceState<MiningCommunity> build() {
    _communityId = null;
    return super.build();
  }

  String? _communityId;

  Future<void> open(String? communityId) {
    if (communityId == null) {
      state = state.failed(LaunchFailureKind.notFound);
      return Future<void>.value();
    }
    if (_communityId == communityId && state.isReady) {
      return Future<void>.value();
    }
    _communityId = communityId;
    return reload();
  }

  @override
  Future<MiningCommunity> fetch(MiningGateway gateway) {
    final communityId = _communityId;
    if (communityId == null) {
      throw const LaunchException(LaunchFailureKind.notFound);
    }
    return gateway.loadCommunity(communityId);
  }
}

final miningCommunityControllerProvider =
    NotifierProvider.autoDispose<
      MiningCommunityController,
      LaunchResourceState<MiningCommunity>
    >(MiningCommunityController.new);

// ---------------------------------------------------------------------------
// referral
// ---------------------------------------------------------------------------

/// The referral page state: the loaded overview, plus the outcome of the last
/// claim attempt kept apart from the read so a refused claim never blanks the
/// invite code that did load.
@immutable
final class ReferralState {
  const ReferralState({
    required this.mode,
    required this.phase,
    this.value,
    this.failureKind,
    this.claimFailureKind,
    this.claimShapeInvalid = false,
    this.busy = false,
    this.claimed = false,
  });

  factory ReferralState.initial(LaunchGatewayMode mode) {
    final closed = mode == LaunchGatewayMode.unavailable;
    return ReferralState(
      mode: mode,
      phase: closed ? LaunchViewPhase.unavailable : LaunchViewPhase.loading,
      failureKind: closed ? LaunchFailureKind.unavailable : null,
    );
  }

  final LaunchGatewayMode mode;
  final LaunchViewPhase phase;
  final ReferralOverview? value;
  final LaunchFailureKind? failureKind;
  final LaunchFailureKind? claimFailureKind;

  /// The typed code could not be a valid invite code, so no attempt was spent.
  final bool claimShapeInvalid;
  final bool busy;

  /// A binding was confirmed by the server in this session.
  final bool claimed;

  bool get isReady => phase == LaunchViewPhase.ready && value != null;
}

final class ReferralController extends Notifier<ReferralState>
    with LaunchSingleFlight {
  @override
  ReferralState build() {
    nextGeneration();
    final mode = ref.watch(referralGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return ReferralState.initial(mode);
  }

  Future<void> load() {
    if (state.isReady) return Future<void>.value();
    return reload();
  }

  Future<void> reload() => single(() async {
    final gateway = ref.read(referralGatewayProvider);
    final generation = nextGeneration();
    state = ReferralState(
      mode: state.mode,
      phase: state.value == null
          ? LaunchViewPhase.loading
          : LaunchViewPhase.ready,
      value: state.value,
    );
    try {
      final overview = await gateway.loadOverview();
      if (!isCurrent(generation)) return;
      state = ReferralState(
        mode: state.mode,
        phase: LaunchViewPhase.ready,
        value: overview,
      );
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return;
      state = _failed(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = _failed(LaunchFailureKind.unexpected);
    }
  });

  ReferralState _failed(LaunchFailureKind kind) => ReferralState(
    mode: state.mode,
    phase: state.value == null
        ? launchPhaseForFailure(kind)
        : LaunchViewPhase.ready,
    value: state.value,
    failureKind: kind,
  );

  /// Binds one invite code. The server owns every refusal: a self-invite, a
  /// cycle, a closed window, a missing LOOP ID and an existing binding are all
  /// its decisions, and each is rendered with its own next step.
  Future<void> claim(String rawCode) => single(() async {
    if (!isReferralInviteCodeShaped(rawCode)) {
      state = ReferralState(
        mode: state.mode,
        phase: state.phase,
        value: state.value,
        failureKind: state.failureKind,
        claimShapeInvalid: true,
      );
      return;
    }
    final gateway = ref.read(referralGatewayProvider);
    final generation = nextGeneration();
    state = ReferralState(
      mode: state.mode,
      phase: state.phase,
      value: state.value,
      failureKind: state.failureKind,
      busy: true,
    );
    try {
      final binding = await gateway.claim(rawCode);
      if (!isCurrent(generation)) return;
      final current = state.value;
      state = ReferralState(
        mode: state.mode,
        phase: state.phase,
        value: current == null
            ? null
            : ReferralOverview(
                inviteCode: current.inviteCode,
                binding: binding,
                levels: current.levels,
                boost: current.boost,
                rules: current.rules,
              ),
        claimed: true,
      );
    } on LaunchException catch (error) {
      if (!isCurrent(generation)) return;
      state = _claimFailed(error.kind);
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = _claimFailed(LaunchFailureKind.unexpected);
    }
  });

  ReferralState _claimFailed(LaunchFailureKind kind) => ReferralState(
    mode: state.mode,
    phase: state.phase,
    value: state.value,
    failureKind: state.failureKind,
    claimFailureKind: kind,
  );
}

final referralControllerProvider =
    NotifierProvider.autoDispose<ReferralController, ReferralState>(
      ReferralController.new,
    );

/// zh-CN copy for a refused `POST /v2/referral/claim`.
///
/// The five documented codes each need a different next step, so none of them
/// falls back to the generic sentence.
String referralClaimFailureReason(LaunchFailureKind? kind) => switch (kind) {
  LaunchFailureKind.activationRequired =>
    '需要先完成 LOOP ID 激活才能绑定邀请码。激活后 7 天内可以再来绑定。',
  LaunchFailureKind.policyBlocked => '绑定窗口已经关闭：邀请码只能在账号激活后 7 天内绑定一次。',
  LaunchFailureKind.notFound => '这个邀请码不存在。请向邀请人确认后再试；邀请码不可枚举，多次尝试不会提高成功率。',
  LaunchFailureKind.validationFailed => '这个邀请码不能绑定：不能邀请自己，也不能绑定自己下级的邀请码。',
  LaunchFailureKind.stale => '这个账号已经绑定过邀请人。关系一旦锁定就不能更换，只能由服务端作废。',
  LaunchFailureKind.idempotencyConflict => '同一次绑定已经用不同的邀请码提交过，请刷新查看最新状态。',
  _ => launchFailureReason(kind),
};
