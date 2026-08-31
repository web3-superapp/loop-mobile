import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';

enum FriendGatewayMode { unavailable, preview, production }

enum FriendGatewayFailureKind {
  unavailable,
  invalidData,
  notFound,
  permissionDenied,
  conflict,
  rateLimited,
  profileRequired,
  incomingRequestPending,
  outgoingRequestPending,
  alreadyFriends,
  cooldown,
  alreadyDecided,
  cursorInvalid,
  operatorRequired,
  outcomeUnknown,
  unexpected,
}

/// Integration adapters must report [FriendGatewayFailureKind.outcomeUnknown]
/// whenever a write may have reached the backend but no definitive response
/// was validated. The other write failure kinds are reserved for preflight or
/// explicit server rejections (including [FriendGatewayFailureKind.unexpected])
/// that prove no mutation was committed. Adapters must not leak an unclassified
/// transport exception across a write boundary.
final class FriendGatewayException implements Exception {
  const FriendGatewayException(this.kind, {this.retryAfter, this.operationId});

  final FriendGatewayFailureKind kind;
  final Duration? retryAfter;
  final String? operationId;

  String get code => switch (kind) {
    FriendGatewayFailureKind.unavailable => 'friend_service_unavailable',
    FriendGatewayFailureKind.invalidData => 'invalid_friend_data',
    FriendGatewayFailureKind.notFound => 'friend_not_found',
    FriendGatewayFailureKind.permissionDenied => 'friend_action_not_allowed',
    FriendGatewayFailureKind.conflict => 'friend_state_conflict',
    FriendGatewayFailureKind.rateLimited => 'friend_rate_limited',
    FriendGatewayFailureKind.profileRequired => 'friend_profile_required',
    FriendGatewayFailureKind.incomingRequestPending =>
      'incoming_friend_request_pending',
    FriendGatewayFailureKind.outgoingRequestPending =>
      'outgoing_friend_request_pending',
    FriendGatewayFailureKind.alreadyFriends => 'already_friends',
    FriendGatewayFailureKind.cooldown => 'friend_request_cooldown',
    FriendGatewayFailureKind.alreadyDecided => 'friend_request_already_decided',
    FriendGatewayFailureKind.cursorInvalid => 'friend_cursor_invalid',
    FriendGatewayFailureKind.operatorRequired =>
      'friend_operator_attention_required',
    FriendGatewayFailureKind.outcomeUnknown => 'friend_outcome_unknown',
    FriendGatewayFailureKind.unexpected => 'friend_request_failed',
  };

  @override
  String toString() => code;
}

/// Account-level friend discovery and group-creation seam.
///
/// This boundary deliberately exposes no wallet address, group-scoped alias,
/// Stream token, or Stream SDK type. A production adapter returns only
/// backend-authorized discovery results for the current LOOP principal.
abstract interface class FriendGateway {
  FriendGatewayMode get mode;

  Future<List<FriendIdentity>> loadFriends();

  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery);

  /// Sends or converges an outgoing friend request. A validated response is
  /// a pending relationship (`requestPending` in Preview and
  /// `outgoingPending` in production); accepted friendship is a separate
  /// server fact and cannot be produced by this operation.
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  });

  /// Creates a group from accepted friends. Only an official connected adapter
  /// may return a non-null Stream CID.
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  });
}

/// Full authenticated Social/Chat capability implemented by the LOOP backend.
///
/// Keeping this as an additive capability preserves the labelled Preview and
/// narrow test gateways while allowing production UI to expose pagination,
/// incoming requests, decisions, and backend-created direct channels.
abstract interface class LoopSocialFriendGateway implements FriendGateway {
  Future<FriendDirectoryPage> loadFriendPage({String? cursor});

  Future<FriendSearchPage> searchByAliasPage(String normalizedQuery);

  Future<FriendRequestSendReceipt> sendFriendRequestCommand({
    required String operationId,
    required FriendProfileRef targetProfileRef,
  });

  Future<FriendRequestPage> loadFriendRequests({
    required FriendRequestDirection direction,
    String? cursor,
  });

  Future<FriendRequestDecisionReceipt> decideFriendRequest({
    required String operationId,
    required String friendRequestId,
    required FriendRequestDecision decision,
  });

  Future<CreatedDirectFriendChannel> createDirectChannel({
    required String operationId,
    required FriendProfileRef targetProfileRef,
  });
}

/// Production-safe default while the authenticated social transport is absent.
final class UnavailableFriendGateway implements LoopSocialFriendGateway {
  const UnavailableFriendGateway();

  @override
  FriendGatewayMode get mode => FriendGatewayMode.unavailable;

  @override
  Future<CreatedFriendGroup> createGroup({
    required String requestId,
    required String normalizedName,
    required List<FriendProfileRef> friendRefs,
  }) => Future<CreatedFriendGroup>.error(
    const FriendGatewayException(FriendGatewayFailureKind.unavailable),
  );

  @override
  Future<List<FriendIdentity>> loadFriends() =>
      Future<List<FriendIdentity>>.error(
        const FriendGatewayException(FriendGatewayFailureKind.unavailable),
      );

  @override
  Future<FriendDirectoryPage> loadFriendPage({String? cursor}) =>
      Future<FriendDirectoryPage>.error(
        const FriendGatewayException(FriendGatewayFailureKind.unavailable),
      );

  @override
  Future<FriendRequestPage> loadFriendRequests({
    required FriendRequestDirection direction,
    String? cursor,
  }) => Future<FriendRequestPage>.error(
    const FriendGatewayException(FriendGatewayFailureKind.unavailable),
  );

  @override
  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery) =>
      Future<List<FriendSearchResult>>.error(
        const FriendGatewayException(FriendGatewayFailureKind.unavailable),
      );

  @override
  Future<FriendSearchPage> searchByAliasPage(String normalizedQuery) =>
      Future<FriendSearchPage>.error(
        const FriendGatewayException(FriendGatewayFailureKind.unavailable),
      );

  @override
  Future<FriendRequestSendReceipt> sendFriendRequestCommand({
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) => Future<FriendRequestSendReceipt>.error(
    const FriendGatewayException(FriendGatewayFailureKind.unavailable),
  );

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) => Future<FriendSearchResult>.error(
    const FriendGatewayException(FriendGatewayFailureKind.unavailable),
  );

  @override
  Future<FriendRequestDecisionReceipt> decideFriendRequest({
    required String operationId,
    required String friendRequestId,
    required FriendRequestDecision decision,
  }) => Future<FriendRequestDecisionReceipt>.error(
    const FriendGatewayException(FriendGatewayFailureKind.unavailable),
  );

  @override
  Future<CreatedDirectFriendChannel> createDirectChannel({
    required String operationId,
    required FriendProfileRef targetProfileRef,
  }) => Future<CreatedDirectFriendChannel>.error(
    const FriendGatewayException(FriendGatewayFailureKind.unavailable),
  );
}

final friendGatewayProvider = Provider<FriendGateway>(
  (ref) => const UnavailableFriendGateway(),
);
