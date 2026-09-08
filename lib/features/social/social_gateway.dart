import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/social/social_models.dart';

/// Feature-facing port for the V2 social graph: follow edges, blocks and
/// stranger message requests.
abstract interface class SocialGateway {
  CommunityGatewayMode get mode;

  Future<ConnectionPage> listConnections({
    ConnectionDirection direction,
    String? cursor,
  });

  Future<FollowOutcome> setFollowing({
    required String publicProfileId,
    required bool following,
  });

  Future<BlockPage> listBlocks({BlockKind kind, String? cursor});

  Future<void> setBlocked({
    required BlockKind kind,
    required String stableId,
    required bool blocked,
  });

  Future<MessageRequestPage> listMessageRequests({String? cursor});

  Future<MessageRequestOutcome> decideMessageRequest({
    required String messageRequestId,
    required MessageRequestDecision decision,
  });
}

final class UnavailableSocialGateway implements SocialGateway {
  const UnavailableSocialGateway();

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const CommunityGatewayException(CommunityFailureKind.unavailable),
  );

  @override
  Future<ConnectionPage> listConnections({
    ConnectionDirection direction = ConnectionDirection.following,
    String? cursor,
  }) => _unavailable();

  @override
  Future<FollowOutcome> setFollowing({
    required String publicProfileId,
    required bool following,
  }) => _unavailable();

  @override
  Future<BlockPage> listBlocks({
    BlockKind kind = BlockKind.user,
    String? cursor,
  }) => _unavailable();

  @override
  Future<void> setBlocked({
    required BlockKind kind,
    required String stableId,
    required bool blocked,
  }) => _unavailable();

  @override
  Future<MessageRequestPage> listMessageRequests({String? cursor}) =>
      _unavailable();

  @override
  Future<MessageRequestOutcome> decideMessageRequest({
    required String messageRequestId,
    required MessageRequestDecision decision,
  }) => _unavailable();
}

final socialGatewayProvider = Provider<SocialGateway>(
  (ref) => const UnavailableSocialGateway(),
);
