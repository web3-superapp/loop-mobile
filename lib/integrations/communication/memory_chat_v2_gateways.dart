import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

/// Memory-only S4 adapters for the explicit Development Preview entry point.
///
/// Every surface backed by one of these renders the visible `演示数据` label.
/// Nothing here reaches an account, a Stream call or the LOOP backend: the
/// Preview owns no provider connection, so it never reports a joined call, a
/// confirmed provider write or an observed participant count.
final class MemoryChatV2Gateway implements ChatV2Gateway {
  MemoryChatV2Gateway();

  static const _operationId = '6f5e4d3c-2b1a-4098-8765-4321fedcba98';

  final Set<String> _leftGroups = <String>{};

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.preview;

  /// The first observation is deliberately non-terminal so the Preview also
  /// exercises the poll loop.
  var _polls = 0;

  @override
  Future<ChatOperation> openDirectChannel(String targetPublicProfileId) async {
    _polls = 0;
    return const ChatOperation(
      operationId: _operationId,
      kind: ChatOperationKind.directGetOrCreate,
      status: ChatOperationStatus.pending,
      terminal: false,
      retryAfterMs: 250,
      directResult: null,
      groupResult: null,
      errorCode: null,
    );
  }

  @override
  Future<ChatOperation> pollOperation(String operationId) async {
    _polls += 1;
    if (_polls < 2) {
      return const ChatOperation(
        operationId: _operationId,
        kind: ChatOperationKind.directGetOrCreate,
        status: ChatOperationStatus.submitting,
        terminal: false,
        retryAfterMs: 250,
        directResult: null,
        groupResult: null,
        errorCode: null,
      );
    }
    // The Preview stops at a resolved operation. It hands back no Stream CID,
    // because there is no Preview channel to open.
    return const ChatOperation(
      operationId: _operationId,
      kind: ChatOperationKind.directGetOrCreate,
      status: ChatOperationStatus.operatorRequired,
      terminal: true,
      retryAfterMs: null,
      directResult: null,
      groupResult: null,
      errorCode: 'preview_no_provider',
    );
  }

  @override
  Future<void> leaveGroup(String groupId) async => _leftGroups.add(groupId);
}

const _previewHost = LoopPublicProfile(
  publicProfileId: '9c1f0f2e-5a7b-4c3d-8e9f-0a1b2c3d4e5f',
  loopId: 'LOOP-7HJKMNPQ',
  alias: 'demo_owner',
  avatarRef: 'avatar:preset/people-03',
);

const _previewListener = LoopPublicProfile(
  publicProfileId: '8b2e1f3d-4a5b-4c6d-8e7f-9a0b1c2d3e4f',
  loopId: 'LOOP-2ABCDEFG',
  alias: 'demo_admin',
  avatarRef: null,
);

final class MemoryVoiceRoomGateway implements VoiceRoomGateway {
  MemoryVoiceRoomGateway({this.asHost = false});

  /// Lets the Preview show either viewer's surface. Even as host, no provider
  /// command is issued.
  final bool asHost;

  static const _roomId = '5cc85f64-5717-4562-b3fc-2c963f66afc8';
  static const _communityId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';

  bool _joined = false;
  bool _handRaised = false;
  bool _ended = false;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.preview;

  VoiceRoomSnapshot get _snapshot => VoiceRoomSnapshot(
    room: VoiceRoomRecord(
      voiceRoomId: _roomId,
      communityId: _communityId,
      callCid: 'audio_room:loop_voice_0123456789abcdef0123456789abcdef',
      state: _ended ? VoiceRoomState.ended : VoiceRoomState.live,
      provisionState: VoiceRoomProvisionState.provisioned,
      backstage: true,
      createdAt: DateTime.utc(2026, 9, 8, 12),
      endedAt: _ended ? DateTime.utc(2026, 9, 8, 13) : null,
    ),
    viewer: VoiceRoomViewer(
      role: !_joined
          ? null
          : asHost
          ? VoiceRoomRole.host
          : VoiceRoomRole.listener,
      canInviteSpeakers: asHost && _joined,
      canMuteAll: asHost && _joined,
      canEndRoom: asHost && _joined,
      handRaise: _handRaised
          ? VoiceRoomHandRaise(
              handRaiseId: '1d2c3b4a-5e6f-4a7b-8c9d-0e1f2a3b4c5d',
              sequence: '2',
              state: VoiceRoomHandRaiseState.pending,
              createdAt: DateTime.utc(2026, 9, 8, 12, 30),
            )
          : null,
      expiresAt: _joined ? DateTime.utc(2026, 9, 8, 13) : null,
    ),
    participants: const VoiceRoomParticipants(
      speakerCount: 2,
      listenerCount: 3,
      // The Preview has no provider observation and must not publish a number.
      observed: VoiceRoomObservedParticipants.unavailable(
        LoopUnavailableFact('STREAM_PARTICIPANT_COUNT_NOT_OBSERVED'),
      ),
    ),
    // A Preview transition is never a confirmed provider write.
    providerSync: const VoiceRoomProviderSync(
      confirmed: false,
      reason: 'PREVIEW_NO_PROVIDER_WRITE',
    ),
  );

  @override
  Future<VoiceRoomCurrent> loadCurrent(String communityId) async =>
      VoiceRoomCurrent(snapshot: _snapshot, reasonCode: null);

  @override
  Future<VoiceRoomSnapshot> load(String voiceRoomId) async => _snapshot;

  @override
  Future<List<VoiceRoomHandRaiseEntry>> listHandRaises(
    String voiceRoomId,
  ) async => <VoiceRoomHandRaiseEntry>[
    VoiceRoomHandRaiseEntry(
      handRaise: VoiceRoomHandRaise(
        handRaiseId: '3a4b5c6d-7e8f-4a90-8b1c-2d3e4f5a6b7c',
        sequence: '1',
        state: VoiceRoomHandRaiseState.pending,
        createdAt: DateTime.utc(2026, 9, 8, 12, 20),
      ),
      profile: _previewListener,
    ),
    if (_handRaised)
      VoiceRoomHandRaiseEntry(
        handRaise: VoiceRoomHandRaise(
          handRaiseId: '1d2c3b4a-5e6f-4a7b-8c9d-0e1f2a3b4c5d',
          sequence: '2',
          state: VoiceRoomHandRaiseState.pending,
          createdAt: DateTime.utc(2026, 9, 8, 12, 30),
        ),
        profile: _previewHost,
      ),
  ];

  @override
  Future<VoiceRoomSnapshot> join(String voiceRoomId) async {
    _joined = true;
    return _snapshot;
  }

  @override
  Future<VoiceRoomSnapshot> leave(String voiceRoomId) async {
    _joined = false;
    _handRaised = false;
    return _snapshot;
  }

  @override
  Future<VoiceRoomSnapshot> raiseHand(String voiceRoomId) async {
    _handRaised = true;
    return _snapshot;
  }

  @override
  Future<VoiceRoomSnapshot> cancelHandRaise(String voiceRoomId) async {
    _handRaised = false;
    return _snapshot;
  }

  @override
  Future<VoiceRoomSnapshot> inviteSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  }) async => _snapshot;

  @override
  Future<VoiceRoomSnapshot> removeSpeaker({
    required String voiceRoomId,
    required String publicProfileId,
  }) async => _snapshot;

  @override
  Future<VoiceRoomSnapshot> muteAll(String voiceRoomId) async => _snapshot;

  @override
  Future<VoiceRoomSnapshot> endRoom(String voiceRoomId) async {
    _ended = true;
    return _snapshot;
  }
}
