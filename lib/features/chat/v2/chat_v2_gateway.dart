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

  /// Opens a room for one community. The server admits only an owner or an
  /// admin and creates the provider call itself; the client never does.
  Future<VoiceRoomSnapshot> createRoom(String communityId);

  Future<VoiceRoomSnapshot> load(String voiceRoomId);

  Future<List<VoiceRoomHandRaiseEntry>> listHandRaises(String voiceRoomId);

  /// One page of the speaker or the listener roster. [cursor] continues the
  /// same view; the page size rides inside it, so nothing else is passed with
  /// it.
  Future<VoiceRoomMemberPage> listMembers({
    required String voiceRoomId,
    required VoiceRoomRosterView view,
    String? cursor,
  });

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

  /// The host's LOOP-side mute of one speaker. It answers with the room, and
  /// its `providerSync` says whether the one Stream write was confirmed.
  Future<VoiceRoomSnapshot> muteSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  });

  /// Clears the LOOP-side mute intent on one speaker row (decision 0053).
  ///
  /// The host may send it for anyone; this account may send it for itself. It
  /// makes no provider call at all, so it never opens a microphone: the device
  /// opens the microphone and this only takes the intent off the roster row.
  Future<VoiceRoomSnapshot> unmuteSpeaker({
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
  Future<VoiceRoomSnapshot> createRoom(String communityId) => _unavailable();

  @override
  Future<VoiceRoomSnapshot> load(String voiceRoomId) => _unavailable();

  @override
  Future<List<VoiceRoomHandRaiseEntry>> listHandRaises(String voiceRoomId) =>
      _unavailable();

  @override
  Future<VoiceRoomMemberPage> listMembers({
    required String voiceRoomId,
    required VoiceRoomRosterView view,
    String? cursor,
  }) => _unavailable();

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
  Future<VoiceRoomSnapshot> muteSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  }) => _unavailable();

  @override
  Future<VoiceRoomSnapshot> unmuteSpeaker({
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
