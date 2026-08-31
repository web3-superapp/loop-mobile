import 'dart:async';

import 'package:loop_mobile/features/chat/friends/friend_gateway.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/social/loop_social_repository.dart';
import 'package:loop_mobile/integrations/social/loop_social_transport_models.dart';

typedef LoopSocialDelay = Future<void> Function(Duration duration);
typedef LoopSocialMonotonicNow = Duration Function();

/// Principal-bound production implementation of the friend and Chat command
/// port. Every uncertain command is reconciled by its original UUID before an
/// exact replay is considered; no code path allocates a replacement channel.
final class DioLoopSocialFriendGateway implements LoopSocialFriendGateway {
  DioLoopSocialFriendGateway(
    this._session,
    this._repository, {
    LoopSocialDelay? delay,
    LoopSocialMonotonicNow? monotonicNow,
  }) : _delay = delay ?? Future<void>.delayed,
       _monotonicNow = monotonicNow ?? _readMonotonicClock;

  static const _maximumChatPollingDuration = Duration(minutes: 5);
  static const _maximumChatPollingAttempts = 600;
  static final Stopwatch _monotonicClock = Stopwatch()..start();

  static Duration _readMonotonicClock() => _monotonicClock.elapsed;

  final LoopAuthenticatedSession _session;
  final DioLoopSocialRepository _repository;
  final LoopSocialDelay _delay;
  final LoopSocialMonotonicNow _monotonicNow;
  final Completer<void> _invalidated = Completer<void>();
  final Map<String, String> _operationIntents = <String, String>{};
  final Map<FriendProfileRef, FriendIdentity> _searchIdentityCache =
      <FriendProfileRef, FriendIdentity>{};
  var _disposed = false;

  @override
  FriendGatewayMode get mode => FriendGatewayMode.production;

  @override
  Future<FriendDirectoryPage> loadFriendPage({String? cursor}) async {
    try {
      return await _session.execute(
        (token) =>
            _repository.loadFriendPage(accessToken: token, cursor: cursor),
      );
    } catch (error) {
      throw _mapReadFailure(error, cursorRead: cursor != null);
    }
  }

  @override
  Future<List<FriendIdentity>> loadFriends() async {
    final result = <FriendIdentity>[];
    final seen = <FriendProfileRef>{};
    String? cursor;
    do {
      final page = await loadFriendPage(cursor: cursor);
      for (final item in page.items) {
        if (!seen.add(item.profileRef)) {
          throw const FriendGatewayException(
            FriendGatewayFailureKind.invalidData,
          );
        }
        result.add(item);
      }
      cursor = page.nextCursor;
      if (result.length > friendDirectoryMaximumItems) {
        throw const FriendGatewayException(
          FriendGatewayFailureKind.invalidData,
        );
      }
    } while (cursor != null);
    return validateFriendDirectory(result);
  }

  @override
  Future<FriendSearchPage> searchByAliasPage(String normalizedQuery) async {
    try {
      final page = await _session.execute(
        (token) => _repository.searchFriends(
          accessToken: token,
          normalizedQuery: normalizedQuery,
        ),
      );
      for (final result in page.items) {
        _searchIdentityCache[result.identity.profileRef] = result.identity;
      }
      return page;
    } catch (error) {
      throw _mapReadFailure(error);
    }
  }

  @override
  Future<List<FriendSearchResult>> searchByAlias(
    String normalizedQuery,
  ) async => (await searchByAliasPage(normalizedQuery)).items;

  @override
  Future<FriendRequestPage> loadFriendRequests({
    required FriendRequestDirection direction,
    String? cursor,
  }) async {
    try {
      return await _session.execute(
        (token) => _repository.loadFriendRequests(
          accessToken: token,
          direction: direction,
          cursor: cursor,
        ),
      );
    } catch (error) {
      throw _mapReadFailure(error, cursorRead: cursor != null);
    }
  }

  @override
  Future<FriendRequestSendReceipt> sendFriendRequestCommand({
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) async {
    final operation = await _runSocialCommand(
      operationId: operationId,
      intent: 'friend_request_send:${targetProfileRef.wireValue}',
      kind: LoopSocialOperationKind.friendRequestSend,
      post: (token) => _repository.sendFriendRequest(
        accessToken: token,
        operationId: operationId,
        targetProfileRef: targetProfileRef,
      ),
    );
    if (operation.status == LoopSocialOperationStatus.failed) {
      throw _mapOperationError(operation.errorCode, operationId);
    }
    final result = operation.result;
    if (result == null || result.status != LoopSocialResultStatus.pending) {
      throw FriendGatewayException(
        FriendGatewayFailureKind.outcomeUnknown,
        operationId: operationId,
      );
    }
    return FriendRequestSendReceipt(
      operationId: operationId,
      targetProfileRef: targetProfileRef,
      friendRequestId: result.friendRequestId,
    );
  }

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) async {
    final receipt = await sendFriendRequestCommand(
      operationId: requestId,
      targetProfileRef: profileRef,
    );
    final identity = _searchIdentityCache[profileRef];
    if (identity == null) {
      throw FriendGatewayException(
        FriendGatewayFailureKind.outcomeUnknown,
        operationId: requestId,
      );
    }
    return FriendSearchResult(
      identity: identity,
      relationship: FriendRelationship.outgoingPending,
      friendRequestId: receipt.friendRequestId,
    );
  }

  @override
  Future<FriendRequestDecisionReceipt> decideFriendRequest({
    required String operationId,
    required String friendRequestId,
    required FriendRequestDecision decision,
  }) async {
    final operation = await _runSocialCommand(
      operationId: operationId,
      intent: 'friend_request_decide:$friendRequestId:${decision.name}',
      kind: LoopSocialOperationKind.friendRequestDecide,
      post: (token) => _repository.decideFriendRequest(
        accessToken: token,
        operationId: operationId,
        friendRequestId: friendRequestId,
        decision: decision,
      ),
    );
    if (operation.status == LoopSocialOperationStatus.failed) {
      throw _mapOperationError(operation.errorCode, operationId);
    }
    final result = operation.result;
    final expectedStatus = switch (decision) {
      FriendRequestDecision.accept => LoopSocialResultStatus.accepted,
      FriendRequestDecision.reject => LoopSocialResultStatus.rejected,
    };
    if (result == null ||
        result.friendRequestId != friendRequestId ||
        result.status != expectedStatus) {
      throw FriendGatewayException(
        FriendGatewayFailureKind.outcomeUnknown,
        operationId: operationId,
      );
    }
    return FriendRequestDecisionReceipt(
      operationId: operationId,
      friendRequestId: friendRequestId,
      decision: decision,
    );
  }

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) async {
    final name = normalizeFriendGroupName(normalizedName);
    final selected = validateSelectedFriendRefs(friendRefs);
    final canonicalMembers =
        selected.map((item) => item.wireValue).toList(growable: false)..sort();
    final operation = await _runChatCommand(
      operationId: requestId,
      intent: 'group_create:$name:${canonicalMembers.join(',')}',
      kind: LoopChatOperationKind.groupCreate,
      post: (token) => _repository.createGroup(
        accessToken: token,
        operationId: requestId,
        normalizedName: name,
        friendRefs: selected,
      ),
    );
    final rawResult = _requireSucceededChat(operation);
    if (rawResult is! LoopChatGroupResult ||
        rawResult.name != name ||
        !_sameMembers(rawResult.friendProfileRefs, selected)) {
      throw FriendGatewayException(
        FriendGatewayFailureKind.outcomeUnknown,
        operationId: requestId,
      );
    }
    return CreatedFriendGroup(
      requestId: requestId,
      groupId: rawResult.groupId,
      name: rawResult.name,
      friendRefs: rawResult.friendProfileRefs,
      streamCid: rawResult.streamCid,
    );
  }

  @override
  Future<CreatedDirectFriendChannel> createDirectChannel({
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) async {
    final operation = await _runChatCommand(
      operationId: operationId,
      intent: 'direct_get_or_create:${targetProfileRef.wireValue}',
      kind: LoopChatOperationKind.directGetOrCreate,
      post: (token) => _repository.createDirectChannel(
        accessToken: token,
        operationId: operationId,
        targetProfileRef: targetProfileRef,
      ),
    );
    final rawResult = _requireSucceededChat(operation);
    if (rawResult is! LoopChatDirectResult ||
        rawResult.targetProfileRef != targetProfileRef) {
      throw FriendGatewayException(
        FriendGatewayFailureKind.outcomeUnknown,
        operationId: operationId,
      );
    }
    return CreatedDirectFriendChannel(
      operationId: operationId,
      targetProfileRef: targetProfileRef,
      streamCid: rawResult.streamCid,
    );
  }

  Future<LoopSocialOperation> _runSocialCommand({
    required String operationId,
    required String intent,
    required LoopSocialOperationKind kind,
    required Future<LoopSocialOperation> Function(String token) post,
  }) async {
    _registerIntent(operationId, intent);
    final wasAttempted =
        _operationIntents[operationId] == intent &&
        _attemptedOperationIds.contains(operationId);
    _attemptedOperationIds.add(operationId);

    if (wasAttempted) {
      final existing = await _querySocialOrNull(operationId, kind);
      if (existing != null) return existing;
    }
    try {
      return await _session.execute(post);
    } catch (error) {
      if (!_isAmbiguousCommandFailure(error)) throw _mapCommandFailure(error);
      final reconciled = await _querySocialOrNull(operationId, kind);
      if (reconciled != null) return reconciled;
      try {
        return await _session.execute(post);
      } catch (replayError) {
        if (!_isAmbiguousCommandFailure(replayError)) {
          throw _mapCommandFailure(replayError);
        }
        final finalResult = await _querySocialOrNull(operationId, kind);
        if (finalResult != null) return finalResult;
        throw FriendGatewayException(
          FriendGatewayFailureKind.outcomeUnknown,
          operationId: operationId,
        );
      }
    }
  }

  final Set<String> _attemptedOperationIds = <String>{};

  Future<LoopSocialOperation?> _querySocialOrNull(
    String operationId,
    LoopSocialOperationKind kind,
  ) async {
    try {
      return await _session.execute(
        (token) => _repository.getSocialOperation(
          accessToken: token,
          operationId: operationId,
          expectedKind: kind,
        ),
      );
    } on LoopSocialHttpFailure catch (error) {
      if (error.statusCode == 404 &&
          error.code == 'social_operation_not_found') {
        return null;
      }
      throw _outcomeUnknown(operationId);
    } catch (_) {
      throw _outcomeUnknown(operationId);
    }
  }

  Future<LoopChatOperation> _runChatCommand({
    required String operationId,
    required String intent,
    required LoopChatOperationKind kind,
    required Future<LoopChatOperation> Function(String token) post,
  }) async {
    _registerIntent(operationId, intent);
    final wasAttempted = _attemptedOperationIds.contains(operationId);
    _attemptedOperationIds.add(operationId);

    LoopChatOperation? operation;
    if (wasAttempted) {
      operation = await _queryChatOrNull(operationId, kind);
    }
    if (operation == null) {
      try {
        operation = await _session.execute(post);
      } catch (error) {
        if (!_isAmbiguousCommandFailure(error)) throw _mapCommandFailure(error);
        operation = await _queryChatOrNull(operationId, kind);
        if (operation == null) {
          try {
            operation = await _session.execute(post);
          } catch (replayError) {
            if (!_isAmbiguousCommandFailure(replayError)) {
              throw _mapCommandFailure(replayError);
            }
            operation = await _queryChatOrNull(operationId, kind);
            if (operation == null) {
              throw FriendGatewayException(
                FriendGatewayFailureKind.outcomeUnknown,
                operationId: operationId,
              );
            }
          }
        }
      }
    }
    return _pollChat(operation!, kind);
  }

  Future<LoopChatOperation?> _queryChatOrNull(
    String operationId,
    LoopChatOperationKind kind,
  ) async {
    try {
      return await _session.execute(
        (token) => _repository.getChatOperation(
          accessToken: token,
          operationId: operationId,
          expectedKind: kind,
        ),
      );
    } on LoopSocialHttpFailure catch (error) {
      if (error.statusCode == 404 && error.code == 'chat_operation_not_found') {
        return null;
      }
      throw _outcomeUnknown(operationId);
    } catch (_) {
      throw _outcomeUnknown(operationId);
    }
  }

  Future<LoopChatOperation> _pollChat(
    LoopChatOperation initial,
    LoopChatOperationKind kind,
  ) async {
    var operation = initial;
    final startedAt = _monotonicNow();
    var attempts = 0;
    while (!operation.terminal) {
      final wait = operation.retryDelay;
      final beforeWait = _monotonicNow();
      final elapsed = beforeWait - startedAt;
      if (wait == null ||
          elapsed.isNegative ||
          elapsed >= _maximumChatPollingDuration ||
          wait > _maximumChatPollingDuration - elapsed ||
          attempts >= _maximumChatPollingAttempts) {
        throw FriendGatewayException(
          FriendGatewayFailureKind.outcomeUnknown,
          operationId: operation.operationId,
        );
      }
      await _wait(wait);
      if (_monotonicNow() - startedAt >= _maximumChatPollingDuration) {
        throw FriendGatewayException(
          FriendGatewayFailureKind.outcomeUnknown,
          operationId: operation.operationId,
        );
      }
      attempts += 1;
      final next = await _queryChatOrNull(operation.operationId, kind);
      if (_monotonicNow() - startedAt >= _maximumChatPollingDuration) {
        throw FriendGatewayException(
          FriendGatewayFailureKind.outcomeUnknown,
          operationId: operation.operationId,
        );
      }
      if (next == null) {
        throw FriendGatewayException(
          FriendGatewayFailureKind.outcomeUnknown,
          operationId: operation.operationId,
        );
      }
      operation = next;
    }
    return operation;
  }

  LoopChatOperationResult _requireSucceededChat(LoopChatOperation operation) {
    if (operation.status == LoopChatOperationStatus.operatorRequired) {
      throw FriendGatewayException(
        FriendGatewayFailureKind.operatorRequired,
        operationId: operation.operationId,
      );
    }
    if (operation.status == LoopChatOperationStatus.failed) {
      throw _mapOperationError(operation.errorCode, operation.operationId);
    }
    if (operation.status != LoopChatOperationStatus.succeeded ||
        operation.result == null) {
      throw FriendGatewayException(
        FriendGatewayFailureKind.outcomeUnknown,
        operationId: operation.operationId,
      );
    }
    return operation.result!;
  }

  void _registerIntent(String operationId, String intent) {
    validateFriendOperationId(operationId);
    final previous = _operationIntents[operationId];
    if (previous != null && previous != intent) {
      throw const FriendGatewayException(FriendGatewayFailureKind.conflict);
    }
    _operationIntents[operationId] = intent;
  }

  Future<void> _wait(Duration duration) {
    if (_disposed) {
      return Future<void>.error(
        const FriendGatewayException(FriendGatewayFailureKind.unavailable),
      );
    }
    return Future.any(<Future<void>>[
      _delay(duration),
      _invalidated.future.then<void>(
        (_) => throw const FriendGatewayException(
          FriendGatewayFailureKind.unavailable,
        ),
      ),
    ]);
  }

  FriendGatewayException _mapReadFailure(
    Object error, {
    bool cursorRead = false,
  }) {
    if (error is FriendGatewayException) return error;
    if (error is LoopSocialHttpFailure) {
      if (cursorRead && error.statusCode == 400) {
        return const FriendGatewayException(
          FriendGatewayFailureKind.cursorInvalid,
        );
      }
      return _mapHttpFailure(error);
    }
    if (error is LoopBackendFailure &&
        error.kind == LoopBackendFailureKind.invalidPayload) {
      return const FriendGatewayException(FriendGatewayFailureKind.invalidData);
    }
    return const FriendGatewayException(FriendGatewayFailureKind.unavailable);
  }

  FriendGatewayException _mapCommandFailure(Object error) {
    if (error is FriendGatewayException) return error;
    if (error is LoopSocialHttpFailure) return _mapHttpFailure(error);
    if (_isAmbiguousCommandFailure(error)) {
      return const FriendGatewayException(
        FriendGatewayFailureKind.outcomeUnknown,
      );
    }
    return const FriendGatewayException(FriendGatewayFailureKind.unexpected);
  }

  FriendGatewayException _outcomeUnknown(String operationId) =>
      FriendGatewayException(
        FriendGatewayFailureKind.outcomeUnknown,
        operationId: operationId,
      );

  FriendGatewayException _mapHttpFailure(LoopSocialHttpFailure error) {
    final kind = switch (error.code) {
      'target_unavailable' ||
      'friend_request_not_found' ||
      'social_operation_not_found' ||
      'chat_operation_not_found' => FriendGatewayFailureKind.notFound,
      'search_rate_limited' ||
      'social_rate_limited' => FriendGatewayFailureKind.rateLimited,
      'profile_required' => FriendGatewayFailureKind.profileRequired,
      'incoming_request_pending' =>
        FriendGatewayFailureKind.incomingRequestPending,
      'outgoing_request_pending' =>
        FriendGatewayFailureKind.outgoingRequestPending,
      'already_friends' => FriendGatewayFailureKind.alreadyFriends,
      'friend_request_cooldown' => FriendGatewayFailureKind.cooldown,
      'friend_request_already_decided' =>
        FriendGatewayFailureKind.alreadyDecided,
      'idempotency_conflict' => FriendGatewayFailureKind.conflict,
      'invalid_request' => FriendGatewayFailureKind.invalidData,
      _ when error.statusCode == 403 =>
        FriendGatewayFailureKind.permissionDenied,
      _ when error.statusCode == 429 => FriendGatewayFailureKind.rateLimited,
      _ => FriendGatewayFailureKind.unexpected,
    };
    return FriendGatewayException(kind, retryAfter: error.retryAfter);
  }

  FriendGatewayException _mapOperationError(String? code, String operationId) {
    final kind = switch (code) {
      'target_unavailable' ||
      'friend_request_not_found' => FriendGatewayFailureKind.notFound,
      'profile_required' => FriendGatewayFailureKind.profileRequired,
      'incoming_request_pending' =>
        FriendGatewayFailureKind.incomingRequestPending,
      'outgoing_request_pending' =>
        FriendGatewayFailureKind.outgoingRequestPending,
      'already_friends' => FriendGatewayFailureKind.alreadyFriends,
      'friend_request_cooldown' => FriendGatewayFailureKind.cooldown,
      'friend_request_already_decided' =>
        FriendGatewayFailureKind.alreadyDecided,
      'submission_not_started' => FriendGatewayFailureKind.unavailable,
      'direct_channel_unavailable' => FriendGatewayFailureKind.operatorRequired,
      'stream_channel_not_created' ||
      'stream_channel_projection_mismatch' ||
      'stream_reconciliation_unavailable' =>
        FriendGatewayFailureKind.operatorRequired,
      _ => FriendGatewayFailureKind.unexpected,
    };
    return FriendGatewayException(kind, operationId: operationId);
  }

  bool _isAmbiguousCommandFailure(Object error) {
    if (error is FriendGatewayException) {
      return error.kind == FriendGatewayFailureKind.outcomeUnknown;
    }
    if (error is! LoopBackendFailure) return false;
    return error.kind == LoopBackendFailureKind.timeout ||
        error.kind == LoopBackendFailureKind.connection ||
        error.kind == LoopBackendFailureKind.cancelled ||
        error.kind == LoopBackendFailureKind.unavailable ||
        error.kind == LoopBackendFailureKind.invalidPayload ||
        error.kind == LoopBackendFailureKind.unexpected;
  }

  bool _sameMembers(
    List<FriendProfileRef> left,
    List<FriendProfileRef> right,
  ) => left.length == right.length && left.toSet().containsAll(right);

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _searchIdentityCache.clear();
    _operationIntents.clear();
    _attemptedOperationIds.clear();
    if (!_invalidated.isCompleted) _invalidated.complete();
  }
}
