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

  /// [retainKey] keeps the reserved key after a write the server accepted.
  ///
  /// A command that came back 2xx has normally happened, and the next one is a
  /// new command with a new key. Opening a voice room is the exception: the
  /// room row commits before the provider calls, so a 201 can describe a room
  /// that exists and cannot be entered, and the only way to finish it is the
  /// same key again — the server then skips the local write and repeats the
  /// provider half. A fresh key is refused outright, because the room that
  /// cannot be entered is still holding the community's one live slot.
  Future<T> _write<T>(
    String signature,
    Future<T> Function(String accessToken, String idempotencyKey) request, {
    bool Function(T result)? retainKey,
  }) async {
    final key = _keyring.reserve(signature);
    try {
      final result = await executeCommunityRequest(
        _session,
        (accessToken) => request(accessToken, key),
      );
      if (!(retainKey?.call(result) ?? false)) _keyring.release(signature);
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
  Future<DirectChannelPage> listDirectChannels({String? cursor}) => _read(
    (accessToken) => _api.listDirectChannels(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      cursor: cursor,
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
  Future<VoiceRoomCurrent> loadCurrent(String communityId) async {
    final current = await _read(
      (accessToken) => _api.getCurrentVoiceRoom(
        accessToken: accessToken,
        clientVersion: _clientVersion,
        communityId: communityId,
      ),
    );
    // A community with no live room has no unfinished opening either. The key
    // that opened the last one must not outlive it: replaying it answers with
    // the room it opened, whatever became of that room since.
    if (!current.isLive) _releaseOpenKey(communityId);
    return current;
  }

  @override
  Future<VoiceRoomSnapshot> createRoom(String communityId) => _write(
    'voice-room-open:$communityId',
    (accessToken, key) => _api.createVoiceRoom(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      idempotencyKey: key,
      communityId: communityId,
    ),
    // A live room nobody can be let into yet is a command that is not
    // finished, and the same key is what finishes it. A room that is no longer
    // live is a different matter: replaying the key answers with that same
    // ended room for ever, so the key is let go and the next 开启 is a new
    // command that can make a new room.
    retainKey: (snapshot) => snapshot.room.isLive && !snapshot.room.audioOpen,
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

  @override
  Future<VoiceRoomMemberPage> listMembers({
    required String voiceRoomId,
    required VoiceRoomRosterView view,
    String? cursor,
  }) => _read(
    (accessToken) => _api.listMembers(
      accessToken: accessToken,
      clientVersion: _clientVersion,
      voiceRoomId: voiceRoomId,
      role: view,
      cursor: cursor,
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
  Future<VoiceRoomSnapshot> muteSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  }) => _command(
    VoiceRoomCommand.muteSpeaker,
    voiceRoomId,
    publicProfileId: publicProfileId,
  );

  @override
  Future<VoiceRoomSnapshot> unmuteSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  }) => _command(
    VoiceRoomCommand.unmuteSpeaker,
    voiceRoomId,
    publicProfileId: publicProfileId,
  );

  @override
  Future<VoiceRoomSnapshot> muteAll(String voiceRoomId) =>
      _command(VoiceRoomCommand.muteAll, voiceRoomId);

  @override
  Future<VoiceRoomSnapshot> endRoom(String voiceRoomId) async {
    final ended = await _command(VoiceRoomCommand.endRoom, voiceRoomId);
    // The room this key opened is over, so the key has nothing left to
    // finish. Holding it would make the community's next 开启 replay the
    // opening of the room that just ended.
    _releaseOpenKey(ended.room.communityId);
    return ended;
  }

  /// Lets go of the key that opened one community's room.
  void _releaseOpenKey(String communityId) =>
      _keyring.release('voice-room-open:$communityId');
}
