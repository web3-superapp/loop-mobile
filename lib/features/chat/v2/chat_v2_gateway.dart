import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

/// Feature-facing port for the `communication` module's chat wrappers.
///
/// It exposes no transport type, no `/v2/` literal and no idempotency detail.
/// Message content, history, unread state and presence are **not** here: they
/// belong to the official Stream SDK inside `lib/features/chat/`.
abstract interface class ChatV2Gateway {
  CommunityGatewayMode get mode;

  /// Opens (or reuses) the direct channel with one accepted friend. The result
  /// is a persistent operation; a non-terminal status must be polled with
  /// [pollOperation].
  Future<ChatOperation> openDirectChannel(String targetPublicProfileId);

  Future<ChatOperation> pollOperation(String operationId);

  /// Leaves one small group. A lost response is safe to replay with the same
  /// idempotency key.
  Future<void> leaveGroup(String groupId);
}

final class UnavailableChatV2Gateway implements ChatV2Gateway {
  const UnavailableChatV2Gateway();

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const CommunityGatewayException(CommunityFailureKind.unavailable),
  );

  @override
  Future<ChatOperation> openDirectChannel(String targetPublicProfileId) =>
      _unavailable();

  @override
  Future<ChatOperation> pollOperation(String operationId) => _unavailable();

  @override
  Future<void> leaveGroup(String groupId) => _unavailable();
}

/// Overridden by the composition root (production adapter) and by
/// `main_preview.dart` (labelled memory adapter).
final chatV2GatewayProvider = Provider<ChatV2Gateway>(
  (ref) => const UnavailableChatV2Gateway(),
);

/// Feature-facing port for the pre-created Audio Room resource.
///
/// LOOP owns the room record, the viewer role, the hand-raise queue and the
/// host commands. Stream owns connection, participants, capabilities and
/// microphone state once a call is joined.
abstract interface class VoiceRoomGateway {
  CommunityGatewayMode get mode;

  Future<VoiceRoomCurrent> loadCurrent(String communityId);

  Future<VoiceRoomSnapshot> load(String voiceRoomId);

  Future<List<VoiceRoomHandRaiseEntry>> listHandRaises(String voiceRoomId);

  Future<VoiceRoomSnapshot> join(String voiceRoomId);

  Future<VoiceRoomSnapshot> leave(String voiceRoomId);

  Future<VoiceRoomSnapshot> raiseHand(String voiceRoomId);

  Future<VoiceRoomSnapshot> cancelHandRaise(String voiceRoomId);

  Future<VoiceRoomSnapshot> inviteSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  });

  Future<VoiceRoomSnapshot> removeSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  });

  Future<VoiceRoomSnapshot> muteAll(String voiceRoomId);

  Future<VoiceRoomSnapshot> endRoom(String voiceRoomId);
}

final class UnavailableVoiceRoomGateway implements VoiceRoomGateway {
  const UnavailableVoiceRoomGateway();

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.unavailable;

  Future<Never> _unavailable() => Future<Never>.error(
    const CommunityGatewayException(CommunityFailureKind.unavailable),
  );

  @override
  Future<VoiceRoomCurrent> loadCurrent(String communityId) => _unavailable();

  @override
  Future<VoiceRoomSnapshot> load(String voiceRoomId) => _unavailable();

  @override
  Future<List<VoiceRoomHandRaiseEntry>> listHandRaises(String voiceRoomId) =>
      _unavailable();

  @override
  Future<VoiceRoomSnapshot> join(String voiceRoomId) => _unavailable();

  @override
  Future<VoiceRoomSnapshot> leave(String voiceRoomId) => _unavailable();

  @override
  Future<VoiceRoomSnapshot> raiseHand(String voiceRoomId) => _unavailable();

  @override
  Future<VoiceRoomSnapshot> cancelHandRaise(String voiceRoomId) =>
      _unavailable();

  @override
  Future<VoiceRoomSnapshot> inviteSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  }) => _unavailable();

  @override
  Future<VoiceRoomSnapshot> removeSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  }) => _unavailable();

  @override
  Future<VoiceRoomSnapshot> muteAll(String voiceRoomId) => _unavailable();

  @override
  Future<VoiceRoomSnapshot> endRoom(String voiceRoomId) => _unavailable();
}

final voiceRoomGatewayProvider = Provider<VoiceRoomGateway>(
  (ref) => const UnavailableVoiceRoomGateway(),
);
