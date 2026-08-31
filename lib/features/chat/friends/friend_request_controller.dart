import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:loop_mobile/features/chat/friends/friend_controllers.dart';
import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:uuid/uuid.dart';

enum FriendRequestsPhase {
  initial,
  loading,
  ready,
  deciding,
  unavailable,
  failure,
}

@immutable
final class FriendRequestsState {
  FriendRequestsState({
    required this.mode,
    required this.phase,
    Iterable<FriendRequestRecord> incoming = const <FriendRequestRecord>[],
    Iterable<FriendRequestRecord> outgoing = const <FriendRequestRecord>[],
    this.incomingCursor,
    this.outgoingCursor,
    this.decidingRequestId,
    this.decisionReceipt,
    this.failureKind,
  }) : incoming = List<FriendRequestRecord>.unmodifiable(incoming),
       outgoing = List<FriendRequestRecord>.unmodifiable(outgoing) {
    _validateCombinedRequests(this.incoming, FriendRequestDirection.incoming);
    _validateCombinedRequests(this.outgoing, FriendRequestDirection.outgoing);
  }

  factory FriendRequestsState.initial(FriendGatewayMode mode) =>
      FriendRequestsState(
        mode: mode,
        phase: mode == FriendGatewayMode.production
            ? FriendRequestsPhase.initial
            : FriendRequestsPhase.unavailable,
        failureKind: mode == FriendGatewayMode.production
            ? null
            : FriendGatewayFailureKind.unavailable,
      );

  final FriendGatewayMode mode;
  final FriendRequestsPhase phase;
  final List<FriendRequestRecord> incoming;
  final List<FriendRequestRecord> outgoing;
  final String? incomingCursor;
  final String? outgoingCursor;
  final String? decidingRequestId;
  final FriendRequestDecisionReceipt? decisionReceipt;
  final FriendGatewayFailureKind? failureKind;

  bool get isBusy =>
      phase == FriendRequestsPhase.loading ||
      phase == FriendRequestsPhase.deciding;

  bool get requiresDecisionReconciliation =>
      failureKind == FriendGatewayFailureKind.outcomeUnknown &&
      decidingRequestId != null;

  bool canLoadMore(FriendRequestDirection direction) =>
      !isBusy &&
      !requiresDecisionReconciliation &&
      switch (direction) {
        FriendRequestDirection.incoming => incomingCursor != null,
        FriendRequestDirection.outgoing => outgoingCursor != null,
      };

  static void _validateCombinedRequests(
    List<FriendRequestRecord> values,
    FriendRequestDirection direction,
  ) {
    if (values.length > friendDirectoryMaximumItems ||
        values.any((item) => item.direction != direction) ||
        values.map((item) => item.friendRequestId).toSet().length !=
            values.length) {
      throw const InvalidFriendContractException();
    }
  }
}

final class FriendRequestsController extends Notifier<FriendRequestsState> {
  Future<void>? _operation;
  KeepAliveLink? _unresolvedWriteKeepAlive;
  final Map<String, _PendingFriendDecision> _pendingDecisions =
      <String, _PendingFriendDecision>{};
  var _generation = 0;

  @override
  FriendRequestsState build() {
    _unresolvedWriteKeepAlive?.close();
    _unresolvedWriteKeepAlive = null;
    _pendingDecisions.clear();
    _operation = null;
    _generation += 1;
    final mode = ref.watch(friendGatewayProvider).mode;
    ref.onDispose(() => _generation += 1);
    return FriendRequestsState.initial(mode);
  }

  Future<void> load() {
    if (state.phase == FriendRequestsPhase.ready) {
      return Future<void>.value();
    }
    return _startLoad();
  }

  Future<void> reload() => _startLoad();

  Future<void> loadMore(FriendRequestDirection direction) =>
      _startLoad(loadMore: direction);

  Future<void> _startLoad({FriendRequestDirection? loadMore}) {
    final active = _operation;
    if (active != null) return active;
    if (_pendingDecisions.isNotEmpty) return Future<void>.value();
    final gateway = ref.read(friendGatewayProvider);
    if (gateway is! LoopSocialFriendGateway ||
        gateway.mode != FriendGatewayMode.production) {
      state = FriendRequestsState.initial(gateway.mode);
      return Future<void>.value();
    }
    if (loadMore != null && !state.canLoadMore(loadMore)) {
      return Future<void>.value();
    }
    final generation = ++_generation;
    late final Future<void> operation;
    operation = _performLoad(gateway, generation, loadMore).whenComplete(() {
      if (identical(_operation, operation)) _operation = null;
    });
    _operation = operation;
    return operation;
  }

  Future<void> _performLoad(
    LoopSocialFriendGateway gateway,
    int generation,
    FriendRequestDirection? loadMore,
  ) async {
    final previous = state;
    state = FriendRequestsState(
      mode: gateway.mode,
      phase: FriendRequestsPhase.loading,
      incoming: previous.incoming,
      outgoing: previous.outgoing,
      incomingCursor: previous.incomingCursor,
      outgoingCursor: previous.outgoingCursor,
    );
    try {
      late final List<FriendRequestRecord> incoming;
      late final List<FriendRequestRecord> outgoing;
      late final String? incomingCursor;
      late final String? outgoingCursor;
      if (loadMore == null) {
        final pages = await Future.wait(<Future<FriendRequestPage>>[
          gateway.loadFriendRequests(
            direction: FriendRequestDirection.incoming,
          ),
          gateway.loadFriendRequests(
            direction: FriendRequestDirection.outgoing,
          ),
        ]);
        incoming = pages[0].items;
        incomingCursor = pages[0].nextCursor;
        outgoing = pages[1].items;
        outgoingCursor = pages[1].nextCursor;
      } else if (loadMore == FriendRequestDirection.incoming) {
        final page = await _loadPageWithCursorRestart(
          gateway,
          direction: loadMore,
          cursor: previous.incomingCursor,
        );
        incoming = page.restarted
            ? page.page.items
            : _mergeRequests(previous.incoming, page.page.items);
        incomingCursor = page.page.nextCursor;
        outgoing = previous.outgoing;
        outgoingCursor = previous.outgoingCursor;
      } else {
        final page = await _loadPageWithCursorRestart(
          gateway,
          direction: loadMore,
          cursor: previous.outgoingCursor,
        );
        outgoing = page.restarted
            ? page.page.items
            : _mergeRequests(previous.outgoing, page.page.items);
        outgoingCursor = page.page.nextCursor;
        incoming = previous.incoming;
        incomingCursor = previous.incomingCursor;
      }
      if (!_isCurrent(generation)) return;
      state = FriendRequestsState(
        mode: gateway.mode,
        phase: FriendRequestsPhase.ready,
        incoming: incoming,
        outgoing: outgoing,
        incomingCursor: incomingCursor,
        outgoingCursor: outgoingCursor,
      );
    } on FriendGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      _publishFailure(previous, gateway.mode, error.kind);
    } on InvalidFriendContractException {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        previous,
        gateway.mode,
        FriendGatewayFailureKind.invalidData,
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        previous,
        gateway.mode,
        FriendGatewayFailureKind.unexpected,
      );
    }
  }

  Future<_RestartableFriendRequestPage> _loadPageWithCursorRestart(
    LoopSocialFriendGateway gateway, {
    required FriendRequestDirection direction,
    required String? cursor,
  }) async {
    try {
      return _RestartableFriendRequestPage(
        page: await gateway.loadFriendRequests(
          direction: direction,
          cursor: cursor,
        ),
        restarted: false,
      );
    } on FriendGatewayException catch (error) {
      if (error.kind != FriendGatewayFailureKind.cursorInvalid) rethrow;
      return _RestartableFriendRequestPage(
        page: await gateway.loadFriendRequests(direction: direction),
        restarted: true,
      );
    }
  }

  Future<void> decide(String friendRequestId, FriendRequestDecision decision) =>
      _startDecision(friendRequestId, decision, reconcileOnly: false);

  Future<void> reconcileDecision(String friendRequestId) {
    final pending = _pendingDecisions[friendRequestId];
    if (pending == null) return Future<void>.value();
    return _startDecision(
      friendRequestId,
      pending.decision,
      reconcileOnly: true,
    );
  }

  Future<void> _startDecision(
    String friendRequestId,
    FriendRequestDecision decision, {
    required bool reconcileOnly,
  }) {
    final active = _operation;
    if (active != null) return active;
    final gateway = ref.read(friendGatewayProvider);
    if (gateway is! LoopSocialFriendGateway ||
        gateway.mode != FriendGatewayMode.production ||
        !state.incoming.any(
          (item) => item.friendRequestId == friendRequestId,
        )) {
      return Future<void>.value();
    }
    final pending = _pendingDecisions[friendRequestId];
    if (reconcileOnly != (pending != null) ||
        (pending != null && pending.decision != decision)) {
      return Future<void>.value();
    }
    final command =
        pending ??
        _PendingFriendDecision(
          operationId: const Uuid().v4(),
          decision: decision,
        );
    _pendingDecisions[friendRequestId] = command;
    _unresolvedWriteKeepAlive ??= ref.keepAlive();
    final generation = ++_generation;
    late final Future<void> operation;
    operation =
        _performDecision(
          gateway: gateway,
          generation: generation,
          friendRequestId: friendRequestId,
          command: command,
        ).whenComplete(() {
          if (identical(_operation, operation)) _operation = null;
        });
    _operation = operation;
    return operation;
  }

  Future<void> _performDecision({
    required LoopSocialFriendGateway gateway,
    required int generation,
    required String friendRequestId,
    required _PendingFriendDecision command,
  }) async {
    final previous = state;
    state = FriendRequestsState(
      mode: gateway.mode,
      phase: FriendRequestsPhase.deciding,
      incoming: previous.incoming,
      outgoing: previous.outgoing,
      incomingCursor: previous.incomingCursor,
      outgoingCursor: previous.outgoingCursor,
      decidingRequestId: friendRequestId,
    );
    try {
      final receipt = await gateway.decideFriendRequest(
        operationId: command.operationId,
        friendRequestId: friendRequestId,
        decision: command.decision,
      );
      if (!_isCurrent(generation)) return;
      _pendingDecisions.remove(friendRequestId);
      state = FriendRequestsState(
        mode: gateway.mode,
        phase: FriendRequestsPhase.ready,
        incoming: previous.incoming.where(
          (item) => item.friendRequestId != friendRequestId,
        ),
        outgoing: previous.outgoing,
        incomingCursor: previous.incomingCursor,
        outgoingCursor: previous.outgoingCursor,
        decisionReceipt: receipt,
      );
      if (command.decision == FriendRequestDecision.accept) {
        ref.invalidate(friendDirectoryControllerProvider);
      }
      _releaseWriteRetentionIfResolved();
    } on FriendGatewayException catch (error) {
      if (!_isCurrent(generation)) return;
      if (error.kind != FriendGatewayFailureKind.outcomeUnknown) {
        _pendingDecisions.remove(friendRequestId);
      }
      _publishFailure(
        previous,
        gateway.mode,
        error.kind,
        decidingRequestId: friendRequestId,
      );
      _releaseWriteRetentionIfResolved();
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _publishFailure(
        previous,
        gateway.mode,
        FriendGatewayFailureKind.outcomeUnknown,
        decidingRequestId: friendRequestId,
      );
    }
  }

  void acknowledgeDecision() {
    if (state.decisionReceipt == null || state.isBusy) return;
    state = FriendRequestsState(
      mode: state.mode,
      phase: FriendRequestsPhase.ready,
      incoming: state.incoming,
      outgoing: state.outgoing,
      incomingCursor: state.incomingCursor,
      outgoingCursor: state.outgoingCursor,
    );
  }

  void _publishFailure(
    FriendRequestsState previous,
    FriendGatewayMode mode,
    FriendGatewayFailureKind kind, {
    String? decidingRequestId,
  }) {
    state = FriendRequestsState(
      mode: mode,
      phase:
          kind == FriendGatewayFailureKind.unavailable &&
              previous.incoming.isEmpty &&
              previous.outgoing.isEmpty
          ? FriendRequestsPhase.unavailable
          : FriendRequestsPhase.failure,
      incoming: previous.incoming,
      outgoing: previous.outgoing,
      incomingCursor: previous.incomingCursor,
      outgoingCursor: previous.outgoingCursor,
      decidingRequestId: decidingRequestId,
      failureKind: kind,
    );
  }

  List<FriendRequestRecord> _mergeRequests(
    List<FriendRequestRecord> previous,
    List<FriendRequestRecord> next,
  ) {
    final byId = <String, FriendRequestRecord>{
      for (final item in previous) item.friendRequestId: item,
    };
    for (final item in next) {
      if (byId.containsKey(item.friendRequestId)) {
        throw const InvalidFriendContractException();
      }
      byId[item.friendRequestId] = item;
    }
    return byId.values.toList(growable: false);
  }

  void _releaseWriteRetentionIfResolved() {
    if (_pendingDecisions.isNotEmpty) return;
    _unresolvedWriteKeepAlive?.close();
    _unresolvedWriteKeepAlive = null;
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}

final friendRequestsControllerProvider =
    NotifierProvider.autoDispose<FriendRequestsController, FriendRequestsState>(
      FriendRequestsController.new,
    );

final class _PendingFriendDecision {
  const _PendingFriendDecision({
    required this.operationId,
    required this.decision,
  });

  final String operationId;
  final FriendRequestDecision decision;
}

final class _RestartableFriendRequestPage {
  const _RestartableFriendRequestPage({
    required this.page,
    required this.restarted,
  });

  final FriendRequestPage page;
  final bool restarted;
}
