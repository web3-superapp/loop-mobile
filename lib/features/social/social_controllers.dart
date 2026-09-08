import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';

// ---------------------------------------------------------------------------
// connections · following / followers
// ---------------------------------------------------------------------------

@immutable
final class ConnectionsState {
  const ConnectionsState({
    required this.mode,
    required this.phase,
    required this.direction,
    this.items = const <ConnectionEntry>[],
    this.counts,
    this.nextCursor,
    this.failureKind,
    this.busy = false,
    this.loadingMore = false,
  });

  factory ConnectionsState.initial(CommunityGatewayMode mode) {
    final closed = mode == CommunityGatewayMode.unavailable;
    return ConnectionsState(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      direction: ConnectionDirection.following,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final ConnectionDirection direction;
  final List<ConnectionEntry> items;
  final ConnectionCounts? counts;
  final String? nextCursor;
  final CommunityFailureKind? failureKind;
  final bool busy;
  final bool loadingMore;

  bool get canLoadMore => nextCursor != null && !loadingMore && !busy;

  bool get isPreview => mode == CommunityGatewayMode.preview;
}

final class ConnectionsController extends Notifier<ConnectionsState>
    with CommunitySingleFlight {
  @override
  ConnectionsState build() {
    nextGeneration();
    final mode = ref.watch(socialGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return ConnectionsState.initial(mode);
  }

  Future<void> load() {
    if (state.phase == CommunityViewPhase.ready) return Future<void>.value();
    return _fetch(direction: state.direction, append: false);
  }

  Future<void> reload() => _fetch(direction: state.direction, append: false);

  Future<void> selectDirection(ConnectionDirection direction) {
    if (direction == state.direction &&
        state.phase == CommunityViewPhase.ready) {
      return Future<void>.value();
    }
    return _fetch(direction: direction, append: false);
  }

  Future<void> loadMore() {
    if (!state.canLoadMore) return Future<void>.value();
    return _fetch(direction: state.direction, append: true);
  }

  Future<void> _fetch({
    required ConnectionDirection direction,
    required bool append,
  }) => single(() async {
    final gateway = ref.read(socialGatewayProvider);
    final previous = state;
    final generation = nextGeneration();
    state = ConnectionsState(
      mode: previous.mode,
      phase: append ? previous.phase : CommunityViewPhase.loading,
      direction: direction,
      items: append ? previous.items : const <ConnectionEntry>[],
      counts: previous.counts,
      nextCursor: append ? previous.nextCursor : null,
      loadingMore: append,
    );
    try {
      final page = await gateway.listConnections(
        direction: direction,
        cursor: append ? previous.nextCursor : null,
      );
      if (!isCurrent(generation)) return;
      final merged = append
          ? <ConnectionEntry>[...previous.items, ...page.items]
          : page.items;
      state = ConnectionsState(
        mode: previous.mode,
        phase: merged.isEmpty
            ? CommunityViewPhase.empty
            : CommunityViewPhase.ready,
        direction: direction,
        items: List<ConnectionEntry>.unmodifiable(merged),
        counts: page.counts,
        nextCursor: page.nextCursor,
      );
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      state = ConnectionsState(
        mode: previous.mode,
        phase: communityPhaseForFailure(error.kind),
        direction: direction,
        counts: previous.counts,
        failureKind: error.kind,
      );
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = ConnectionsState(
        mode: previous.mode,
        phase: CommunityViewPhase.error,
        direction: direction,
        failureKind: CommunityFailureKind.unexpected,
      );
    }
  });

  /// Returns null when the server confirmed the change. The row's badge only
  /// ever repeats the server's `viewerFollows`.
  Future<CommunityFailureKind?> setFollowing({
    required String publicProfileId,
    required bool following,
  }) async {
    if (state.busy) return CommunityFailureKind.stale;
    final gateway = ref.read(socialGatewayProvider);
    final previous = state;
    final generation = nextGeneration();
    state = ConnectionsState(
      mode: previous.mode,
      phase: previous.phase,
      direction: previous.direction,
      items: previous.items,
      counts: previous.counts,
      nextCursor: previous.nextCursor,
      busy: true,
    );
    try {
      final outcome = await gateway.setFollowing(
        publicProfileId: publicProfileId,
        following: following,
      );
      if (!isCurrent(generation)) return null;
      final updated = <ConnectionEntry>[
        for (final item in previous.items)
          if (item.profile.publicProfileId == publicProfileId)
            ConnectionEntry(
              profile: item.profile,
              createdAt: item.createdAt,
              viewerFollows: outcome.viewerFollows,
              miningPower: item.miningPower,
            )
          else
            item,
      ];
      state = ConnectionsState(
        mode: previous.mode,
        phase: previous.phase,
        direction: previous.direction,
        items: List<ConnectionEntry>.unmodifiable(updated),
        counts: previous.counts,
        nextCursor: previous.nextCursor,
      );
      return null;
    } on CommunityGatewayException catch (error) {
      if (isCurrent(generation)) {
        state = ConnectionsState(
          mode: previous.mode,
          phase: previous.phase,
          direction: previous.direction,
          items: previous.items,
          counts: previous.counts,
          nextCursor: previous.nextCursor,
          failureKind: error.kind,
        );
      }
      return error.kind;
    } catch (_) {
      if (isCurrent(generation)) {
        state = ConnectionsState(
          mode: previous.mode,
          phase: previous.phase,
          direction: previous.direction,
          items: previous.items,
          counts: previous.counts,
          nextCursor: previous.nextCursor,
          failureKind: CommunityFailureKind.unexpected,
        );
      }
      return CommunityFailureKind.unexpected;
    }
  }
}

final connectionsControllerProvider =
    NotifierProvider.autoDispose<ConnectionsController, ConnectionsState>(
      ConnectionsController.new,
    );

// ---------------------------------------------------------------------------
// blocklist
// ---------------------------------------------------------------------------

@immutable
final class BlocklistState {
  const BlocklistState({
    required this.mode,
    required this.phase,
    required this.kind,
    this.items = const <BlockEntry>[],
    this.userCount,
    this.nextCursor,
    this.failureKind,
    this.busy = false,
    this.loadingMore = false,
  });

  factory BlocklistState.initial(CommunityGatewayMode mode) {
    final closed = mode == CommunityGatewayMode.unavailable;
    return BlocklistState(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      kind: BlockKind.user,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final BlockKind kind;
  final List<BlockEntry> items;
  final int? userCount;
  final String? nextCursor;
  final CommunityFailureKind? failureKind;
  final bool busy;
  final bool loadingMore;

  bool get canLoadMore => nextCursor != null && !loadingMore && !busy;

  bool get isPreview => mode == CommunityGatewayMode.preview;
}

final class BlocklistController extends Notifier<BlocklistState>
    with CommunitySingleFlight {
  @override
  BlocklistState build() {
    nextGeneration();
    final mode = ref.watch(socialGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return BlocklistState.initial(mode);
  }

  Future<void> load() {
    if (state.phase == CommunityViewPhase.ready) return Future<void>.value();
    return _fetch(kind: state.kind, append: false);
  }

  Future<void> reload() => _fetch(kind: state.kind, append: false);

  /// `contract` and `domain` have no backend: the segment can be selected but
  /// the page shows the unavailable explanation and issues no request.
  void selectKind(BlockKind kind) {
    if (kind == state.kind) return;
    if (!kind.isSupported) {
      state = BlocklistState(
        mode: state.mode,
        phase: CommunityViewPhase.unavailable,
        kind: kind,
        userCount: state.userCount,
        failureKind: CommunityFailureKind.unavailable,
      );
      return;
    }
    unawaited(_fetch(kind: kind, append: false));
  }

  Future<void> loadMore() {
    if (!state.canLoadMore || !state.kind.isSupported) {
      return Future<void>.value();
    }
    return _fetch(kind: state.kind, append: true);
  }

  Future<void> _fetch({required BlockKind kind, required bool append}) =>
      single(() async {
        final gateway = ref.read(socialGatewayProvider);
        final previous = state;
        final generation = nextGeneration();
        state = BlocklistState(
          mode: previous.mode,
          phase: append ? previous.phase : CommunityViewPhase.loading,
          kind: kind,
          items: append ? previous.items : const <BlockEntry>[],
          userCount: previous.userCount,
          nextCursor: append ? previous.nextCursor : null,
          loadingMore: append,
        );
        try {
          final page = await gateway.listBlocks(
            kind: kind,
            cursor: append ? previous.nextCursor : null,
          );
          if (!isCurrent(generation)) return;
          final merged = append
              ? <BlockEntry>[...previous.items, ...page.items]
              : page.items;
          state = BlocklistState(
            mode: previous.mode,
            phase: merged.isEmpty
                ? CommunityViewPhase.empty
                : CommunityViewPhase.ready,
            kind: kind,
            items: List<BlockEntry>.unmodifiable(merged),
            userCount: page.userCount,
            nextCursor: page.nextCursor,
          );
        } on CommunityGatewayException catch (error) {
          if (!isCurrent(generation)) return;
          state = BlocklistState(
            mode: previous.mode,
            phase: communityPhaseForFailure(error.kind),
            kind: kind,
            userCount: previous.userCount,
            failureKind: error.kind,
          );
        } catch (_) {
          if (!isCurrent(generation)) return;
          state = BlocklistState(
            mode: previous.mode,
            phase: CommunityViewPhase.error,
            kind: kind,
            failureKind: CommunityFailureKind.unexpected,
          );
        }
      });

  /// Lifting a block never restores a follow edge; the copy says so and the
  /// list is reloaded from the server rather than patched locally.
  Future<CommunityFailureKind?> unblock(BlockEntry entry) async {
    if (state.busy) return CommunityFailureKind.stale;
    final gateway = ref.read(socialGatewayProvider);
    final previous = state;
    final generation = nextGeneration();
    state = BlocklistState(
      mode: previous.mode,
      phase: previous.phase,
      kind: previous.kind,
      items: previous.items,
      userCount: previous.userCount,
      nextCursor: previous.nextCursor,
      busy: true,
    );
    try {
      await gateway.setBlocked(
        kind: entry.kind,
        stableId: entry.stableId,
        blocked: false,
      );
      if (!isCurrent(generation)) return null;
      await _fetch(kind: previous.kind, append: false);
      return null;
    } on CommunityGatewayException catch (error) {
      if (isCurrent(generation)) {
        state = BlocklistState(
          mode: previous.mode,
          phase: previous.phase,
          kind: previous.kind,
          items: previous.items,
          userCount: previous.userCount,
          nextCursor: previous.nextCursor,
          failureKind: error.kind,
        );
      }
      return error.kind;
    } catch (_) {
      if (isCurrent(generation)) {
        state = BlocklistState(
          mode: previous.mode,
          phase: previous.phase,
          kind: previous.kind,
          items: previous.items,
          userCount: previous.userCount,
          nextCursor: previous.nextCursor,
          failureKind: CommunityFailureKind.unexpected,
        );
      }
      return CommunityFailureKind.unexpected;
    }
  }
}

final blocklistControllerProvider =
    NotifierProvider.autoDispose<BlocklistController, BlocklistState>(
      BlocklistController.new,
    );

// ---------------------------------------------------------------------------
// dm-requests
// ---------------------------------------------------------------------------

@immutable
final class MessageRequestsState {
  const MessageRequestsState({
    required this.mode,
    required this.phase,
    this.items = const <MessageRequestEntry>[],
    this.nextCursor,
    this.failureKind,
    this.busy = false,
    this.loadingMore = false,
  });

  factory MessageRequestsState.initial(CommunityGatewayMode mode) {
    final closed = mode == CommunityGatewayMode.unavailable;
    return MessageRequestsState(
      mode: mode,
      phase: closed
          ? CommunityViewPhase.unavailable
          : CommunityViewPhase.loading,
      failureKind: closed ? CommunityFailureKind.unavailable : null,
    );
  }

  final CommunityGatewayMode mode;
  final CommunityViewPhase phase;
  final List<MessageRequestEntry> items;
  final String? nextCursor;
  final CommunityFailureKind? failureKind;
  final bool busy;
  final bool loadingMore;

  bool get canLoadMore => nextCursor != null && !loadingMore && !busy;

  bool get isPreview => mode == CommunityGatewayMode.preview;
}

final class MessageRequestsController extends Notifier<MessageRequestsState>
    with CommunitySingleFlight {
  @override
  MessageRequestsState build() {
    nextGeneration();
    final mode = ref.watch(socialGatewayProvider).mode;
    ref.onDispose(nextGeneration);
    return MessageRequestsState.initial(mode);
  }

  Future<void> load() {
    if (state.phase == CommunityViewPhase.ready) return Future<void>.value();
    return _fetch(append: false);
  }

  Future<void> reload() => _fetch(append: false);

  Future<void> loadMore() {
    if (!state.canLoadMore) return Future<void>.value();
    return _fetch(append: true);
  }

  Future<void> _fetch({required bool append}) => single(() async {
    final gateway = ref.read(socialGatewayProvider);
    final previous = state;
    final generation = nextGeneration();
    state = MessageRequestsState(
      mode: previous.mode,
      phase: append ? previous.phase : CommunityViewPhase.loading,
      items: append ? previous.items : const <MessageRequestEntry>[],
      nextCursor: append ? previous.nextCursor : null,
      loadingMore: append,
    );
    try {
      final page = await gateway.listMessageRequests(
        cursor: append ? previous.nextCursor : null,
      );
      if (!isCurrent(generation)) return;
      final merged = append
          ? <MessageRequestEntry>[...previous.items, ...page.items]
          : page.items;
      state = MessageRequestsState(
        mode: previous.mode,
        phase: merged.isEmpty
            ? CommunityViewPhase.empty
            : CommunityViewPhase.ready,
        items: List<MessageRequestEntry>.unmodifiable(merged),
        nextCursor: page.nextCursor,
      );
    } on CommunityGatewayException catch (error) {
      if (!isCurrent(generation)) return;
      state = MessageRequestsState(
        mode: previous.mode,
        phase: communityPhaseForFailure(error.kind),
        failureKind: error.kind,
      );
    } catch (_) {
      if (!isCurrent(generation)) return;
      state = MessageRequestsState(
        mode: previous.mode,
        phase: CommunityViewPhase.error,
        failureKind: CommunityFailureKind.unexpected,
      );
    }
  });

  /// Returns the server outcome, or null when the decision was refused. Only a
  /// non-null outcome may raise a success Toast, and `blocked` in the copy
  /// comes from the response, never from the requested decision.
  Future<MessageRequestOutcome?> decide({
    required String messageRequestId,
    required MessageRequestDecision decision,
  }) async {
    if (state.busy) return null;
    final gateway = ref.read(socialGatewayProvider);
    final previous = state;
    final generation = nextGeneration();
    state = MessageRequestsState(
      mode: previous.mode,
      phase: previous.phase,
      items: previous.items,
      nextCursor: previous.nextCursor,
      busy: true,
    );
    try {
      final outcome = await gateway.decideMessageRequest(
        messageRequestId: messageRequestId,
        decision: decision,
      );
      if (!isCurrent(generation)) return outcome;
      final remaining = <MessageRequestEntry>[
        for (final item in previous.items)
          if (item.messageRequestId != messageRequestId) item,
      ];
      state = MessageRequestsState(
        mode: previous.mode,
        phase: remaining.isEmpty
            ? CommunityViewPhase.empty
            : CommunityViewPhase.ready,
        items: List<MessageRequestEntry>.unmodifiable(remaining),
        nextCursor: previous.nextCursor,
      );
      return outcome;
    } on CommunityGatewayException catch (error) {
      if (isCurrent(generation)) {
        state = MessageRequestsState(
          mode: previous.mode,
          phase: previous.phase,
          items: previous.items,
          nextCursor: previous.nextCursor,
          failureKind: error.kind,
        );
      }
      return null;
    } catch (_) {
      if (isCurrent(generation)) {
        state = MessageRequestsState(
          mode: previous.mode,
          phase: previous.phase,
          items: previous.items,
          nextCursor: previous.nextCursor,
          failureKind: CommunityFailureKind.unexpected,
        );
      }
      return null;
    }
  }
}

final messageRequestsControllerProvider =
    NotifierProvider.autoDispose<
      MessageRequestsController,
      MessageRequestsState
    >(MessageRequestsController.new);
