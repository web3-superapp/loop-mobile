import 'package:loop_mobile/features/chat/friends/friend_models.dart';

enum LoopSocialOperationKind { friendRequestSend, friendRequestDecide }

enum LoopSocialOperationStatus { succeeded, failed }

enum LoopSocialResultStatus { pending, accepted, rejected, expired }

final class LoopSocialOperationResult {
  const LoopSocialOperationResult({
    required this.friendRequestId,
    required this.status,
  });

  final String friendRequestId;
  final LoopSocialResultStatus status;
}

final class LoopSocialOperation {
  const LoopSocialOperation({
    required this.operationId,
    required this.kind,
    required this.status,
    required this.result,
    required this.errorCode,
  });

  final String operationId;
  final LoopSocialOperationKind kind;
  final LoopSocialOperationStatus status;
  final LoopSocialOperationResult? result;
  final String? errorCode;
}

enum LoopChatOperationKind { groupCreate, directGetOrCreate }

enum LoopChatOperationStatus {
  pending,
  submitting,
  reconciling,
  succeeded,
  failed,
  operatorRequired,
}

sealed class LoopChatOperationResult {
  const LoopChatOperationResult();
}

final class LoopChatGroupResult extends LoopChatOperationResult {
  const LoopChatGroupResult({
    required this.groupId,
    required this.name,
    required this.friendProfileRefs,
    required this.streamCid,
  });

  final String groupId;
  final String name;
  final List<FriendProfileRef> friendProfileRefs;
  final String streamCid;
}

final class LoopChatDirectResult extends LoopChatOperationResult {
  const LoopChatDirectResult({
    required this.targetProfileRef,
    required this.streamCid,
  });

  final FriendProfileRef targetProfileRef;
  final String streamCid;
}

final class LoopChatOperation {
  const LoopChatOperation({
    required this.operationId,
    required this.kind,
    required this.status,
    required this.terminal,
    required this.retryDelay,
    required this.result,
    required this.errorCode,
  });

  final String operationId;
  final LoopChatOperationKind kind;
  final LoopChatOperationStatus status;
  final bool terminal;
  final Duration? retryDelay;
  final LoopChatOperationResult? result;
  final String? errorCode;
}

final class LoopSocialHttpFailure implements Exception {
  const LoopSocialHttpFailure({
    required this.statusCode,
    required this.code,
    required this.requestId,
    this.retryAfter,
  });

  final int statusCode;
  final String code;
  final String requestId;
  final Duration? retryAfter;

  @override
  String toString() => 'LOOP social request failed (HTTP $statusCode)';
}
