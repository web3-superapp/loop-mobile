import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/v2/community/dio_loop_v2_community_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/social/loop_v2_social_api.dart';

/// Authenticated V2 adapter for the social graph.
///
/// `contract` and `domain` blocks have no backend in this step: the adapter
/// refuses them locally with `unavailable` instead of spending a request that
/// the server would answer with `CAPABILITY_UNAVAILABLE`.
final class DioLoopV2SocialGateway implements SocialGateway {
  DioLoopV2SocialGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final LoopV2SocialApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2CommandKeyring _keyring;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  String get _clientVersion => _clientMetadata.clientVersion;

  Future<T> _write<T>(
    String signature,
    Future<T> Function(String accessToken, String idempotencyKey) request,
  ) async {
    final key = _keyring.reserve(signature);
    try {
      final result = await executeCommunityRequest(
        _session,
        (accessToken) => request(accessToken, key),
      );
      _keyring.release(signature);
      return result;
    } on CommunityGatewayException catch (failure) {
      if (!communityOutcomeIsUnresolved(failure.kind)) {
        _keyring.release(signature);
      }
      rethrow;
    } catch (_) {
      _keyring.release(signature);
      rethrow;
    }
  }

  @override
  Future<ConnectionPage> listConnections({
    ConnectionDirection direction = ConnectionDirection.following,
    String? cursor,
  }) => executeCommunityRequest(
    _session,
    (accessToken) => _api.listConnections(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      direction: direction,
      cursor: cursor,
    ),
  );

  @override
  Future<FollowOutcome> setFollowing({
    required String publicProfileId,
    required bool following,
  }) => _write(
    'follow:$publicProfileId:$following',
    (accessToken, key) => _api.setFollowing(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      publicProfileId: publicProfileId,
      following: following,
    ),
  );

  @override
  Future<BlockPage> listBlocks({
    BlockKind kind = BlockKind.user,
    String? cursor,
  }) {
    if (!kind.isSupported) {
      return Future<BlockPage>.error(
        const CommunityGatewayException(CommunityFailureKind.unavailable),
      );
    }
    return executeCommunityRequest(
      _session,
      (accessToken) => _api.listBlocks(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        kind: kind,
        cursor: cursor,
      ),
    );
  }

  @override
  Future<void> setBlocked({
    required BlockKind kind,
    required String stableId,
    required bool blocked,
  }) {
    if (!kind.isSupported) {
      return Future<void>.error(
        const CommunityGatewayException(CommunityFailureKind.unavailable),
      );
    }
    return _write(
      'block:${kind.wireName}:$stableId:$blocked',
      (accessToken, key) => _api.setBlocked(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        idempotencyKey: key,
        kind: kind,
        stableId: stableId,
        blocked: blocked,
      ),
    );
  }

  @override
  Future<MessageRequestPage> listMessageRequests({String? cursor}) =>
      executeCommunityRequest(
        _session,
        (accessToken) => _api.listMessageRequests(
          accessToken: accessToken,
          clientVersion: _clientVersion,
          cursor: cursor,
        ),
      );

  @override
  Future<MessageRequestEntry> sendMessageRequest(String publicProfileId) =>
      _write(
        'message-request:$publicProfileId',
        (accessToken, key) => _api.sendMessageRequest(
          accessToken: accessToken,
          clientVersion: _clientVersion,
          idempotencyKey: key,
          publicProfileId: publicProfileId,
        ),
      );

  @override
  Future<MessageRequestOutcome> decideMessageRequest({
    required String messageRequestId,
    required MessageRequestDecision decision,
  }) => _write(
    'decision:$messageRequestId:${decision.wireName}',
    (accessToken, key) => _api.decideMessageRequest(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      messageRequestId: messageRequestId,
      decision: decision,
    ),
  );
}
