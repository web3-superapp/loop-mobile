import 'dart:async';
import 'dart:typed_data';

import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/features/chat/v2/chat_merge_export.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

import 'community_test_harness.dart';

const testChannelHex = '0123456789abcdef0123456789abcdef';
const testGroupCid = 'messaging:loop_group_$testChannelHex';
const testDirectCid = 'messaging:loop_direct_$testChannelHex';
const testCommunityCid = 'messaging:loop_community_$testChannelHex';
const testVoiceRoomId = '5cc85f64-5717-4562-b3fc-2c963f66afc8';
const testResolvedGroupId = '4bb85f64-5717-4562-b3fc-2c963f66afb7';
const testOperationId = '6f5e4d3c-2b1a-4098-8765-4321fedcba98';

VoiceRoomSnapshot testVoiceRoomSnapshot({
  VoiceRoomRole? role = VoiceRoomRole.listener,
  bool host = false,
  bool observedAvailable = true,
  VoiceRoomState state = VoiceRoomState.live,
  VoiceRoomHandRaise? handRaise,
  bool providerConfirmed = true,
}) => VoiceRoomSnapshot(
  room: VoiceRoomRecord(
    voiceRoomId: testVoiceRoomId,
    communityId: testCommunityId,
    callCid: 'audio_room:loop_voice_$testChannelHex',
    state: state,
    provisionState: VoiceRoomProvisionState.provisioned,
    backstage: true,
    createdAt: DateTime.utc(2026, 9, 8, 12),
    endedAt: state == VoiceRoomState.ended
        ? DateTime.utc(2026, 9, 8, 13)
        : null,
  ),
  viewer: VoiceRoomViewer(
    role: role,
    canInviteSpeakers: host,
    canMuteAll: host,
    canEndRoom: host,
    handRaise: handRaise,
    expiresAt: role == null ? null : DateTime.utc(2026, 9, 8, 13),
  ),
  participants: VoiceRoomParticipants(
    speakerCount: 3,
    listenerCount: 42,
    observed: observedAvailable
        ? VoiceRoomObservedParticipants.observed(
            memberCount: 45,
            observedAt: DateTime.utc(2026, 9, 8, 12, 30),
          )
        : const VoiceRoomObservedParticipants.unavailable(
            LoopUnavailableFact('STREAM_PARTICIPANT_COUNT_NOT_OBSERVED'),
          ),
  ),
  providerSync: VoiceRoomProviderSync(
    confirmed: providerConfirmed,
    reason: providerConfirmed ? null : 'STREAM_CALL_MUTE_UNCONFIRMED',
  ),
);

VoiceRoomHandRaiseEntry testHandRaiseEntry({String sequence = '1'}) =>
    VoiceRoomHandRaiseEntry(
      handRaise: VoiceRoomHandRaise(
        handRaiseId: testRequestId,
        sequence: sequence,
        state: VoiceRoomHandRaiseState.pending,
        createdAt: DateTime.utc(2026, 9, 8, 12, 20),
      ),
      profile: testProfile(publicProfileId: testMemberId),
    );

/// A chat port that records every command and answers with the state the test
/// asked for. It never touches Stream.
final class FakeChatV2Gateway implements ChatV2Gateway {
  FakeChatV2Gateway({
    this.mode = CommunityGatewayMode.production,
    this.failure,
    this.operatorRequired = false,
    this.streamCid = testDirectCid,
  });

  @override
  CommunityGatewayMode mode;

  CommunityFailureKind? failure;
  bool operatorRequired;
  String streamCid;

  final List<String> commands = <String>[];

  ChatOperation _operation() => operatorRequired
      ? const ChatOperation(
          operationId: testOperationId,
          kind: ChatOperationKind.directGetOrCreate,
          status: ChatOperationStatus.operatorRequired,
          terminal: true,
          retryAfterMs: null,
          directResult: null,
          groupResult: null,
          errorCode: 'operator_required',
        )
      : ChatOperation(
          operationId: testOperationId,
          kind: ChatOperationKind.directGetOrCreate,
          status: ChatOperationStatus.succeeded,
          terminal: true,
          retryAfterMs: null,
          directResult: ChatDirectChannelResult(
            targetPublicProfileId: testMemberId,
            streamCid: streamCid,
          ),
          groupResult: null,
          errorCode: null,
        );

  @override
  Future<ChatOperation> openDirectChannel(String targetPublicProfileId) {
    commands.add('direct:$targetPublicProfileId');
    final kind = failure;
    if (kind != null) {
      return Future<ChatOperation>.error(CommunityGatewayException(kind));
    }
    return Future<ChatOperation>.value(_operation());
  }

  @override
  Future<ChatOperation> pollOperation(String operationId) {
    commands.add('poll:$operationId');
    return Future<ChatOperation>.value(_operation());
  }

  @override
  Future<void> leaveGroup(String groupId) {
    commands.add('leave-group:$groupId');
    final kind = failure;
    if (kind != null) {
      return Future<void>.error(CommunityGatewayException(kind));
    }
    return Future<void>.value();
  }
}

final class FakeVoiceRoomGateway implements VoiceRoomGateway {
  FakeVoiceRoomGateway({
    this.mode = CommunityGatewayMode.production,
    this.snapshot,
    this.handRaises = const <VoiceRoomHandRaiseEntry>[],
    this.failure,
    this.notLiveReasonCode,
  });

  @override
  CommunityGatewayMode mode;

  VoiceRoomSnapshot? snapshot;
  List<VoiceRoomHandRaiseEntry> handRaises;
  CommunityFailureKind? failure;
  String? notLiveReasonCode;

  final List<String> commands = <String>[];

  Future<VoiceRoomSnapshot> _answer(String command) {
    commands.add(command);
    final kind = failure;
    if (kind != null) {
      return Future<VoiceRoomSnapshot>.error(CommunityGatewayException(kind));
    }
    final value = snapshot;
    if (value == null) {
      return Future<VoiceRoomSnapshot>.error(
        const CommunityGatewayException(CommunityFailureKind.notFound),
      );
    }
    return Future<VoiceRoomSnapshot>.value(value);
  }

  @override
  Future<VoiceRoomCurrent> loadCurrent(String communityId) {
    commands.add('current:$communityId');
    final kind = failure;
    if (kind != null) {
      return Future<VoiceRoomCurrent>.error(CommunityGatewayException(kind));
    }
    return Future<VoiceRoomCurrent>.value(
      VoiceRoomCurrent(
        snapshot: snapshot,
        reasonCode: snapshot == null ? notLiveReasonCode : null,
      ),
    );
  }

  @override
  Future<VoiceRoomSnapshot> load(String voiceRoomId) => _answer('load');

  @override
  Future<List<VoiceRoomHandRaiseEntry>> listHandRaises(String voiceRoomId) {
    commands.add('hand-raises');
    return Future<List<VoiceRoomHandRaiseEntry>>.value(handRaises);
  }

  @override
  Future<VoiceRoomSnapshot> join(String voiceRoomId) => _answer('join');

  @override
  Future<VoiceRoomSnapshot> leave(String voiceRoomId) => _answer('leave');

  @override
  Future<VoiceRoomSnapshot> raiseHand(String voiceRoomId) =>
      _answer('raise-hand');

  @override
  Future<VoiceRoomSnapshot> cancelHandRaise(String voiceRoomId) =>
      _answer('cancel-hand-raise');

  @override
  Future<VoiceRoomSnapshot> inviteSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  }) => _answer('invite:$publicProfileId');

  @override
  Future<VoiceRoomSnapshot> removeSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  }) => _answer('remove:$publicProfileId');

  @override
  Future<VoiceRoomSnapshot> muteAll(String voiceRoomId) => _answer('mute-all');

  @override
  Future<VoiceRoomSnapshot> endRoom(String voiceRoomId) => _answer('end');
}

/// Resolves the one LOOP group `group-info` needs to offer an exit.
///
/// [failure] drives the offline / empty / unavailable / error blocks from one
/// place; [pending] keeps the resolve in flight so the loading skeleton stays.
final class FakeGroupAliasResolverGateway implements GroupAliasResolverGateway {
  FakeGroupAliasResolverGateway({
    this.groupId = testResolvedGroupId,
    this.failure,
    this.pending = false,
  });

  final String groupId;
  final GroupAliasGatewayFailureKind? failure;
  final bool pending;
  final List<GroupAliasStreamChannelId> calls = <GroupAliasStreamChannelId>[];

  @override
  GroupAliasGatewayMode get mode => GroupAliasGatewayMode.production;

  @override
  Future<GroupId> resolveGroup(GroupAliasStreamChannelId channelId) {
    calls.add(channelId);
    if (pending) return Completer<GroupId>().future;
    final kind = failure;
    if (kind != null) {
      return Future<GroupId>.error(GroupAliasGatewayException(kind));
    }
    return Future<GroupId>.value(GroupId.fromWire(groupId));
  }
}

/// Records every merged image the page would have shared, without touching a
/// platform channel.
final class RecordingChatMergeExportSink implements ChatMergeExportSink {
  RecordingChatMergeExportSink({this.outcome = ChatMergeExportOutcome.shared});

  ChatMergeExportOutcome outcome;
  final List<Uint8List> shared = <Uint8List>[];
  final List<String> fileNames = <String>[];

  @override
  Future<ChatMergeExportOutcome> shareImage({
    required Uint8List pngBytes,
    required String fileName,
  }) async {
    shared.add(pngBytes);
    fileNames.add(fileName);
    return outcome;
  }
}

/// Seeds `chat-forward` / `chat-merge-preview` with an exact selection, so a
/// page test never has to drive a Stream query to reach the merged card.
final class SeededChatForwardController extends ChatForwardController {
  SeededChatForwardController(this._messages);

  final List<ChatForwardMessage> _messages;

  @override
  ChatForwardState build() => ChatForwardState(
    sourceCid: testGroupCid,
    messages: List<ChatForwardMessage>.unmodifiable(_messages),
    selected: <String>{for (final message in _messages) message.messageId},
  );
}
