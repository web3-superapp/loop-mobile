import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';

enum FriendGatewayMode { unavailable, preview, production }

enum FriendGatewayFailureKind {
  unavailable,
  invalidData,
  notFound,
  permissionDenied,
  conflict,
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
  const FriendGatewayException(this.kind);

  final FriendGatewayFailureKind kind;

  String get code => switch (kind) {
    FriendGatewayFailureKind.unavailable => 'friend_service_unavailable',
    FriendGatewayFailureKind.invalidData => 'invalid_friend_data',
    FriendGatewayFailureKind.notFound => 'friend_not_found',
    FriendGatewayFailureKind.permissionDenied => 'friend_action_not_allowed',
    FriendGatewayFailureKind.conflict => 'friend_state_conflict',
    FriendGatewayFailureKind.outcomeUnknown => 'friend_outcome_unknown',
    FriendGatewayFailureKind.unexpected => 'friend_request_failed',
  };

  @override
  String toString() => code;
}

/// Account-level friend discovery and group-creation seam.
///
/// This boundary deliberately exposes no wallet address, group-scoped alias,
/// Stream token, or Stream SDK type. The future production adapter must return
/// only backend-authorized discovery results for the current LOOP principal.
abstract interface class FriendGateway {
  FriendGatewayMode get mode;

  Future<List<FriendIdentity>> loadFriends();

  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery);

  /// Sends or converges an outgoing friend request. A validated response is
  /// exactly [FriendRelationship.requestPending]; accepted friendship is a
  /// separate server fact and cannot be produced by this operation.
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

/// Production-safe default while the authenticated social transport is absent.
final class UnavailableFriendGateway implements FriendGateway {
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
  Future<List<FriendSearchResult>> searchByAlias(String normalizedQuery) =>
      Future<List<FriendSearchResult>>.error(
        const FriendGatewayException(FriendGatewayFailureKind.unavailable),
      );

  @override
  Future<FriendSearchResult> sendFriendRequest({
    required String requestId,
    required FriendProfileRef profileRef,
  }) => Future<FriendSearchResult>.error(
    const FriendGatewayException(FriendGatewayFailureKind.unavailable),
  );
}

final friendGatewayProvider = Provider<FriendGateway>(
  (ref) => const UnavailableFriendGateway(),
);
