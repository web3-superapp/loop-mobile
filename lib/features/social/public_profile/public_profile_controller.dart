import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_gateway.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:uuid/uuid.dart';

/// The three page segments of `user-profile` (S107 §3).
enum PublicProfileSection { holdings, trades, communities }

/// One lazily read section of the page.
@immutable
final class PublicProfileSectionState<T> {
  const PublicProfileSectionState({
    required this.phase,
    this.value,
    this.failureKind,
  });

  const PublicProfileSectionState.idle()
    : phase = null,
      value = null,
      failureKind = null;

  /// `null` until the section is first opened.
  final CommunityViewPhase? phase;
  final T? value;
  final CommunityFailureKind? failureKind;
}

@immutable
final class PublicProfileTradesState {
  const PublicProfileTradesState({
    this.phase,
    this.status,
    this.items = const <ProfileTrade>[],
    this.nextCursor,
    this.failureKind,
    this.loadingMore = false,
    this.reasonCode,
  });

  final CommunityViewPhase? phase;
  final ProfileSectionStatus? status;

  /// Why an `unavailable` page is unavailable; see [ProfileTradesPage].
  final String? reasonCode;
  final List<ProfileTrade> items;
  final String? nextCursor;
  final CommunityFailureKind? failureKind;
  final bool loadingMore;

  bool get appendFailed =>
      failureKind != null && items.isNotEmpty && nextCursor != null;
}

@immutable
final class PublicProfileState {
  const PublicProfileState({
    required this.mode,
    required this.phase,
    this.record,
    this.failureKind,
    this.busy = false,
    this.holdings = const PublicProfileSectionState<ProfileHoldings>.idle(),
    this.trades = const PublicProfileTradesState(),
  });

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final PublicProfileRecord? record;
  final CommunityFailureKind? failureKind;

  /// A relationship command is in flight; every action control is off.
  final bool busy;
  final PublicProfileSectionState<ProfileHoldings> holdings;
  final PublicProfileTradesState trades;

  PublicProfileState copyWith({
    CommunityViewPhase? phase,
    PublicProfileRecord? record,
    CommunityFailureKind? failureKind,
    bool clearFailure = false,
    bool? busy,
    PublicProfileSectionState<ProfileHoldings>? holdings,
    PublicProfileTradesState? trades,
  }) => PublicProfileState(
    mode: mode,
    phase: phase ?? this.phase,
    record: record ?? this.record,
    failureKind: clearFailure ? null : (failureKind ?? this.failureKind),
    busy: busy ?? this.busy,
    holdings: holdings ?? this.holdings,
    trades: trades ?? this.trades,
  );
}

/// What one relationship command answered, for the page's toast.
@immutable
final class PublicProfileActionOutcome {
  const PublicProfileActionOutcome.done(this.message) : failed = false;

  const PublicProfileActionOutcome.failed(this.message) : failed = true;

  final String message;
  final bool failed;
}

/// Reads one account's profile and runs the relationship commands on it.
///
/// Every command ends in a re-read of the record: the page shows the server's
/// relationship, never the command's assumed effect.
final class PublicProfileController extends Notifier<PublicProfileState> {
  PublicProfileController(this.target);

  final PublicProfileTarget target;
  var _generation = 0;

  @override
  PublicProfileState build() {
    _generation += 1;
    ref.onDispose(() => _generation += 1);
    final mode = ref.watch(publicProfileGatewayProvider).mode;
    final closed = mode == CommunityGatewayMode.unavailable;
    return PublicProfileState(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  bool _current(int generation) => ref.mounted && generation == _generation;

  /// The page schedules [load] on every build it spends in the loading
  /// phase; a read already in flight must not be restarted by that (each
  /// restart re-published the loading state, which rebuilt the page, which
  /// scheduled another load — one request per frame, none ever adopted).
  var _loadInFlight = false;

  Future<void> load() {
    if (_loadInFlight ||
        state.record != null ||
        state.phase != CommunityViewPhase.loading ||
        state.mode == CommunityGatewayMode.unavailable) {
      return Future<void>.value();
    }
    return reload();
  }

  Future<void> reload() async {
    if (state.mode == CommunityGatewayMode.unavailable) return;
    final generation = ++_generation;
    _loadInFlight = true;
    if (state.record == null &&
        (state.phase != CommunityViewPhase.loading ||
            state.failureKind != null)) {
      state = state.copyWith(
        phase: CommunityViewPhase.loading,
        clearFailure: true,
      );
    }
    try {
      final record = await ref.read(publicProfileGatewayProvider).load(target);
      if (!_current(generation)) return;
      state = state.copyWith(
        phase: CommunityViewPhase.ready,
        record: record,
        clearFailure: true,
      );
    } on CommunityGatewayException catch (error) {
      if (!_current(generation)) return;
      _fail(error.kind);
    } catch (_) {
      if (!_current(generation)) return;
      _fail(CommunityFailureKind.unexpected);
    } finally {
      if (generation == _generation) _loadInFlight = false;
    }
  }

  void _fail(CommunityFailureKind kind) {
    // A failed re-read over a record already shown keeps the record.
    if (state.record != null && kind != CommunityFailureKind.notFound) {
      state = state.copyWith(failureKind: kind);
      return;
    }
    state = PublicProfileState(
      mode: state.mode,
      phase: kind == CommunityFailureKind.notFound
          ? CommunityViewPhase.empty
          : communityPhaseForFailure(kind),
      failureKind: kind,
    );
  }

  Future<void> loadHoldings({bool force = false}) async {
    final record = state.record;
    if (record == null) return;
    if (!force && state.holdings.phase != null) return;
    state = state.copyWith(
      holdings: const PublicProfileSectionState<ProfileHoldings>(
        phase: CommunityViewPhase.loading,
      ),
    );
    final generation = _generation;
    try {
      final value = await ref
          .read(publicProfileGatewayProvider)
          .holdings(record.publicProfileId);
      if (!_current(generation)) return;
      state = state.copyWith(
        holdings: PublicProfileSectionState<ProfileHoldings>(
          phase: CommunityViewPhase.ready,
          value: value,
        ),
      );
    } on CommunityGatewayException catch (error) {
      if (!_current(generation)) return;
      state = state.copyWith(
        holdings: PublicProfileSectionState<ProfileHoldings>(
          phase: communityPhaseForFailure(error.kind),
          failureKind: error.kind,
        ),
      );
    } catch (_) {
      if (!_current(generation)) return;
      state = state.copyWith(
        holdings: const PublicProfileSectionState<ProfileHoldings>(
          phase: CommunityViewPhase.error,
          failureKind: CommunityFailureKind.unexpected,
        ),
      );
    }
  }

  Future<void> loadTrades({bool force = false}) async {
    if (!force && state.trades.phase != null) return;
    await _fetchTrades(append: false);
  }

  Future<void> loadMoreTrades() async {
    final trades = state.trades;
    if (trades.nextCursor == null || trades.loadingMore) return;
    await _fetchTrades(append: true);
  }

  Future<void> _fetchTrades({required bool append}) async {
    final record = state.record;
    if (record == null) return;
    final previous = state.trades;
    state = state.copyWith(
      trades: append
          ? PublicProfileTradesState(
              phase: previous.phase,
              status: previous.status,
              items: previous.items,
              nextCursor: previous.nextCursor,
              loadingMore: true,
            )
          : const PublicProfileTradesState(phase: CommunityViewPhase.loading),
    );
    final generation = _generation;
    try {
      final page = await ref
          .read(publicProfileGatewayProvider)
          .trades(
            record.publicProfileId,
            cursor: append ? previous.nextCursor : null,
          );
      if (!_current(generation)) return;
      final seen = <String>{
        if (append)
          for (final item in previous.items) item.eventId,
      };
      final merged = <ProfileTrade>[
        if (append) ...previous.items,
        for (final item in page.items)
          if (seen.add(item.eventId)) item,
      ];
      state = state.copyWith(
        trades: PublicProfileTradesState(
          phase: CommunityViewPhase.ready,
          status: page.status,
          reasonCode: page.reasonCode,
          items: List<ProfileTrade>.unmodifiable(merged),
          // A page that answers with the cursor it was asked with ends here.
          nextCursor: append && page.nextCursor == previous.nextCursor
              ? null
              : page.nextCursor,
        ),
      );
    } on CommunityGatewayException catch (error) {
      if (!_current(generation)) return;
      state = state.copyWith(
        trades: append
            ? PublicProfileTradesState(
                phase: previous.phase,
                status: previous.status,
                items: previous.items,
                nextCursor: previous.nextCursor,
                failureKind: error.kind,
              )
            : PublicProfileTradesState(
                phase: communityPhaseForFailure(error.kind),
                failureKind: error.kind,
              ),
      );
    } catch (_) {
      if (!_current(generation)) return;
      state = state.copyWith(
        trades: const PublicProfileTradesState(
          phase: CommunityViewPhase.error,
          failureKind: CommunityFailureKind.unexpected,
        ),
      );
    }
  }

  Future<PublicProfileActionOutcome?> _command(
    Future<String> Function(PublicProfileRecord record) run,
  ) async {
    final record = state.record;
    if (record == null || state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      final message = await run(record);
      await reload();
      return PublicProfileActionOutcome.done(message);
    } on CommunityGatewayException catch (error) {
      return PublicProfileActionOutcome.failed(
        communityFailureReason(error.kind),
      );
    } on FriendGatewayException catch (error) {
      return PublicProfileActionOutcome.failed(friendCommandReason(error.kind));
    } catch (_) {
      return PublicProfileActionOutcome.failed(
        communityFailureReason(CommunityFailureKind.unexpected),
      );
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  Future<PublicProfileActionOutcome?> setFollowing(bool following) =>
      _command((record) async {
        final outcome = await ref
            .read(socialGatewayProvider)
            .setFollowing(
              publicProfileId: record.publicProfileId,
              following: following,
            );
        return outcome.viewerFollows ? '已关注' : '已取消关注';
      });

  Future<PublicProfileActionOutcome?> requestFriend() => _command((
    record,
  ) async {
    final gateway = ref.read(friendGatewayProvider);
    final target = FriendProfileRef.fromPublicProfileId(record.publicProfileId);
    if (gateway is LoopSocialFriendGateway) {
      // The command form answers with the receipt alone. The search-flow
      // form also wants the target in the search identity cache, which a
      // profile reached from a chat or a link never filled — the request
      // then went out but was reported as 结果未确认 (emulator
      // 2026-10-08).
      await gateway.sendFriendRequestCommand(
        operationId: const Uuid().v4(),
        targetProfileRef: target,
      );
    } else {
      await gateway.sendFriendRequest(
        requestId: const Uuid().v4(),
        profileRef: target,
      );
    }
    return '好友申请已发送';
  });

  Future<PublicProfileActionOutcome?> removeFriend() =>
      _command((record) async {
        await ref
            .read(publicProfileGatewayProvider)
            .removeFriend(record.publicProfileId);
        return '已删除好友';
      });

  Future<PublicProfileActionOutcome?> setBlocked(bool blocked) =>
      _command((record) async {
        await ref
            .read(socialGatewayProvider)
            .setBlocked(
              kind: BlockKind.user,
              stableId: record.publicProfileId,
              blocked: blocked,
            );
        return blocked ? '已拉黑' : '已解除拉黑';
      });
}

/// The page's controller, one per target, released when the page closes.
final publicProfileControllerProvider = NotifierProvider.autoDispose
    .family<PublicProfileController, PublicProfileState, PublicProfileTarget>(
      PublicProfileController.new,
    );

/// zh-CN copy for a friend command the server refused.
String friendCommandReason(FriendGatewayFailureKind kind) => switch (kind) {
  FriendGatewayFailureKind.alreadyFriends => '你们已经是好友了。',
  FriendGatewayFailureKind.outgoingRequestPending => '已经发过申请，等对方处理。',
  FriendGatewayFailureKind.incomingRequestPending => '对方已向你发出申请，去「好友申请」里处理。',
  FriendGatewayFailureKind.cooldown => '刚被拒绝过，过一段时间再试。',
  FriendGatewayFailureKind.permissionDenied => '对方没有开放好友申请。',
  FriendGatewayFailureKind.rateLimited => '操作太频繁，请稍后再试。',
  FriendGatewayFailureKind.profileRequired => '需要先完成 LOOP ID 激活。',
  FriendGatewayFailureKind.notFound => '找不到这个用户。',
  FriendGatewayFailureKind.unavailable => '好友服务暂不可用，没有发出申请。',
  FriendGatewayFailureKind.outcomeUnknown => '结果未确认，请刷新后再看，不要重复提交。',
  _ => '好友申请没有发出，请稍后再试。',
};
