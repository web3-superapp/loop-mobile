import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/v2/community/dio_loop_v2_community_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_communication_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';

/// Authenticated V2 adapter for the `communication` module.
///
/// The access token is supplied by [LoopAuthenticatedSession] for exactly one
/// immediate request. This adapter owns no credential cache and no generic
/// transport retry; it owns only the idempotency key of each write.
final class DioLoopV2CommunicationGateway
    implements ChatV2Gateway, VoiceRoomGateway {
  /// One keyring per adapter: every write in the module shares one
  /// logical-operation identity space.
  DioLoopV2CommunicationGateway({
    required this._api,
    required this._clientMetadata,
    required this._session,
    LoopV2CommandKeyring? keyring,
  }) : _keyring = keyring ?? LoopV2CommandKeyring();

  final LoopV2CommunicationApi _api;
  final LoopV2ClientMetadata _clientMetadata;
  final LoopAuthenticatedSession _session;
  final LoopV2CommandKeyring _keyring;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  String get _clientVersion => _clientMetadata.clientVersion;

  Future<T> _read<T>(Future<T> Function(String accessToken) request) =>
      executeCommunityRequest(_session, request);

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
      // Only an unresolved outcome keeps the key for an identical retry.
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
  Future<ChatOperation> openDirectChannel(String targetPublicProfileId) =>
      _write(
        'direct:$targetPublicProfileId',
        (accessToken, key) => _api.openDirectChannel(
          accessToken: accessToken,
          clientVersion: _clientVersion,
          idempotencyKey: key,
          targetPublicProfileId: targetPublicProfileId,
        ),
      );

  @override
  Future<ChatOperation> pollOperation(String operationId) => _read(
    (accessToken) => _api.getOperation(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      operationId: operationId,
    ),
  );

  @override
  Future<void> leaveGroup(String groupId) => _write(
    'group-leave:$groupId',
    (accessToken, key) => _api.leaveGroup(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      groupId: groupId,
    ),
  );

  @override
  Future<VoiceRoomCurrent> loadCurrent(String communityId) => _read(
    (accessToken) => _api.getCurrentVoiceRoom(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      communityId: communityId,
    ),
  );

  @override
  Future<VoiceRoomSnapshot> load(String voiceRoomId) => _read(
    (accessToken) => _api.getVoiceRoom(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      voiceRoomId: voiceRoomId,
    ),
  );

  @override
  Future<List<VoiceRoomHandRaiseEntry>> listHandRaises(String voiceRoomId) =>
      _read(
        (accessToken) => _api.listHandRaises(
          accessToken: accessToken,
          clientVersion: _clientVersion,
          voiceRoomId: voiceRoomId,
        ),
      );

  Future<VoiceRoomSnapshot> _command(
    VoiceRoomCommand command,
    String voiceRoomId, {
    String? publicProfileId,
  }) => _write(
    'voice:${command.name}:$voiceRoomId:${publicProfileId ?? ''}',
    (accessToken, key) => _api.command(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      voiceRoomId: voiceRoomId,
      command: command,
      publicProfileId: publicProfileId,
    ),
  );

  @override
  Future<VoiceRoomSnapshot> join(String voiceRoomId) =>
      _command(VoiceRoomCommand.join, voiceRoomId);

  @override
  Future<VoiceRoomSnapshot> leave(String voiceRoomId) =>
      _command(VoiceRoomCommand.leave, voiceRoomId);

  @override
  Future<VoiceRoomSnapshot> raiseHand(String voiceRoomId) =>
      _command(VoiceRoomCommand.raiseHand, voiceRoomId);

  @override
  Future<VoiceRoomSnapshot> cancelHandRaise(String voiceRoomId) =>
      _command(VoiceRoomCommand.cancelHandRaise, voiceRoomId);

  @override
  Future<VoiceRoomSnapshot> inviteSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  }) => _command(
    VoiceRoomCommand.inviteSpeaker,
    voiceRoomId,
    publicProfileId: publicProfileId,
  );

  @override
  Future<VoiceRoomSnapshot> removeSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  }) => _command(
    VoiceRoomCommand.removeSpeaker,
    voiceRoomId,
    publicProfileId: publicProfileId,
  );

  @override
  Future<VoiceRoomSnapshot> muteAll(String voiceRoomId) =>
      _command(VoiceRoomCommand.muteAll, voiceRoomId);

  @override
  Future<VoiceRoomSnapshot> endRoom(String voiceRoomId) =>
      _command(VoiceRoomCommand.endRoom, voiceRoomId);
}
