import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

/// Which persistent chat operation a `POST /v2/chat/...` call started.
enum ChatOperationKind {
  groupCreate('groupCreate'),
  directGetOrCreate('directGetOrCreate');

  const ChatOperationKind(this.wireName);

  final String wireName;

  static ChatOperationKind? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// The V1 persistent-operation state machine, camelCased by the V2 wrapper.
///
/// `operatorRequired` is a **terminal unresolved** result: it is not a
/// disguised failure and must never be retried automatically.
enum ChatOperationStatus {
  pending('pending'),
  submitting('submitting'),
  reconciling('reconciling'),
  succeeded('succeeded'),
  failed('failed'),
  operatorRequired('operatorRequired');

  const ChatOperationStatus(this.wireName);

  final String wireName;

  static ChatOperationStatus? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

@immutable
final class ChatDirectChannelResult {
  const ChatDirectChannelResult({
    required this.targetPublicProfileId,
    required this.streamCid,
  });

  final String targetPublicProfileId;
  final String streamCid;
}

@immutable
final class ChatGroupResult {
  const ChatGroupResult({
    required this.groupId,
    required this.name,
    required this.friendPublicProfileIds,
    required this.streamCid,
  });

  final String groupId;
  final String name;
  final List<String> friendPublicProfileIds;
  final String streamCid;
}

/// One observation of a persistent chat operation.
///
/// `operationId` equals the request's `Idempotency-Key`, so a lost first
/// response can still be polled.
@immutable
final class ChatOperation {
  const ChatOperation({
    required this.operationId,
    required this.kind,
    required this.status,
    required this.terminal,
    required this.retryAfterMs,
    required this.directResult,
    required this.groupResult,
    required this.errorCode,
  });

  final String operationId;
  final ChatOperationKind kind;
  final ChatOperationStatus status;
  final bool terminal;

  /// Positive while the operation is not terminal; `null` once it is.
  final int? retryAfterMs;
  final ChatDirectChannelResult? directResult;
  final ChatGroupResult? groupResult;

  /// Opaque server code for a `failed` / `operatorRequired` outcome. It is
  /// never rendered raw as a cause; the page maps it to neutral copy.
  final String? errorCode;

  bool get isSucceeded => status == ChatOperationStatus.succeeded;

  bool get needsOperator => status == ChatOperationStatus.operatorRequired;

  String? get streamCid => directResult?.streamCid ?? groupResult?.streamCid;
}

/// LOOP's own room role. It is **not** a Stream call role: the backend maps
/// `listener → user`, `speaker → speaker`, `host → admin`. The client reads
/// only this value and never infers the provider role.
enum VoiceRoomRole {
  host('host'),
  speaker('speaker'),
  listener('listener');

  const VoiceRoomRole(this.wireName);

  final String wireName;

  String get label => switch (this) {
    VoiceRoomRole.host => '主持人',
    VoiceRoomRole.speaker => '发言人',
    VoiceRoomRole.listener => '听众',
  };

  static VoiceRoomRole? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

enum VoiceRoomState {
  live('live'),
  ended('ended');

  const VoiceRoomState(this.wireName);

  final String wireName;

  static VoiceRoomState? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// Whether the Stream call behind the room is confirmed. Only `provisioned`
/// may be joined.
enum VoiceRoomProvisionState {
  pending('pending'),
  provisioned('provisioned'),
  reconciling('reconciling'),
  failed('failed');

  const VoiceRoomProvisionState(this.wireName);

  final String wireName;

  static VoiceRoomProvisionState? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

enum VoiceRoomHandRaiseState {
  pending('pending'),
  invited('invited'),
  cancelled('cancelled');

  const VoiceRoomHandRaiseState(this.wireName);

  final String wireName;

  static VoiceRoomHandRaiseState? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

@immutable
final class VoiceRoomRecord {
  const VoiceRoomRecord({
    required this.voiceRoomId,
    required this.communityId,
    required this.callCid,
    required this.state,
    required this.provisionState,
    required this.backstage,
    required this.createdAt,
    required this.endedAt,
  });

  final String voiceRoomId;
  final String communityId;

  /// `audio_room:loop_voice_<32 hex>`. The call type is fixed by the client
  /// contract; only the room ID part is ever handed to the Stream SDK.
  final String callCid;
  final VoiceRoomState state;
  final VoiceRoomProvisionState provisionState;
  final bool backstage;
  final DateTime createdAt;
  final DateTime? endedAt;

  bool get isLive => state == VoiceRoomState.live;

  bool get isJoinable =>
      isLive && provisionState == VoiceRoomProvisionState.provisioned;

  /// The bare Stream room ID, without the call type. Returns null when the CID
  /// does not have the frozen shape.
  String? get roomId {
    const prefix = 'audio_room:';
    if (!callCid.startsWith(prefix)) return null;
    final id = callCid.substring(prefix.length);
    return id.isEmpty ? null : id;
  }
}

@immutable
final class VoiceRoomHandRaise {
  const VoiceRoomHandRaise({
    required this.handRaiseId,
    required this.sequence,
    required this.state,
    required this.createdAt,
  });

  final String handRaiseId;

  /// A decimal string allocated under the room row lock. It is never parsed
  /// into a number, so a queue beyond 2^53 still orders correctly.
  final String sequence;
  final VoiceRoomHandRaiseState state;
  final DateTime createdAt;

  bool get isPending => state == VoiceRoomHandRaiseState.pending;
}

@immutable
final class VoiceRoomHandRaiseEntry {
  const VoiceRoomHandRaiseEntry({
    required this.handRaise,
    required this.profile,
  });

  final VoiceRoomHandRaise handRaise;
  final LoopPublicProfile profile;
}

@immutable
final class VoiceRoomViewer {
  const VoiceRoomViewer({
    required this.role,
    required this.canInviteSpeakers,
    required this.canMuteAll,
    required this.canEndRoom,
    required this.handRaise,
    required this.expiresAt,
  });

  /// `null` when the account has not joined the room.
  final VoiceRoomRole? role;
  final bool canInviteSpeakers;
  final bool canMuteAll;
  final bool canEndRoom;
  final VoiceRoomHandRaise? handRaise;

  /// When the current join grant lapses. A new grant needs a fresh video token
  /// and a re-join.
  final DateTime? expiresAt;

  bool get hasJoined => role != null;

  bool get isHost => role == VoiceRoomRole.host;

  /// Host controls are rendered only when the server says so **and** the
  /// viewer's own role is host. The client adds no rule of its own.
  bool get showsHostControls =>
      isHost && (canInviteSpeakers || canMuteAll || canEndRoom);
}

/// The read-only Stream member-count projection. It is either an observed
/// count with its observation time, or an explicit unavailable reason.
@immutable
final class VoiceRoomObservedParticipants {
  const VoiceRoomObservedParticipants.observed({
    required int this.memberCount,
    required DateTime this.observedAt,
  }) : unavailable = null;

  const VoiceRoomObservedParticipants.unavailable(
    LoopUnavailableFact this.unavailable,
  ) : memberCount = null,
      observedAt = null;

  final int? memberCount;
  final DateTime? observedAt;
  final LoopUnavailableFact? unavailable;

  bool get isAvailable => unavailable == null;
}

@immutable
final class VoiceRoomParticipants {
  const VoiceRoomParticipants({
    required this.speakerCount,
    required this.listenerCount,
    required this.observed,
  });

  /// LOOP-side role intent, not a Stream presence count.
  final int speakerCount;
  final int listenerCount;
  final VoiceRoomObservedParticipants observed;
}

/// Whether the one Stream write behind a command was confirmed. A LOOP commit
/// is never presented as a provider fact.
@immutable
final class VoiceRoomProviderSync {
  const VoiceRoomProviderSync({required this.confirmed, required this.reason});

  final bool confirmed;
  final String? reason;
}

@immutable
final class VoiceRoomSnapshot {
  const VoiceRoomSnapshot({
    required this.room,
    required this.viewer,
    required this.participants,
    required this.providerSync,
  });

  final VoiceRoomRecord room;
  final VoiceRoomViewer viewer;
  final VoiceRoomParticipants participants;
  final VoiceRoomProviderSync providerSync;
}

/// `GET /v2/communities/{id}/voice-rooms/current`. `snapshot` is null when no
/// room is live, and the server's own `reasonCode` explains why.
@immutable
final class VoiceRoomCurrent {
  const VoiceRoomCurrent({required this.snapshot, required this.reasonCode});

  final VoiceRoomSnapshot? snapshot;
  final String? reasonCode;

  bool get isLive => snapshot != null;
}

/// zh-CN copy for one communication `reasonCode`. An unknown code keeps a
/// neutral sentence rather than inventing a cause.
String communicationUnavailableReason(String? reasonCode) =>
    switch (reasonCode) {
      'COMMUNITY_CHANNEL_NOT_PROVISIONED' => '该社区还没有官方群频道，社区通过验证后才会创建。',
      'COMMUNITY_CHANNEL_MEMBER_SYNCING' => '你的频道成员身份正在同步，稍后即可进入。',
      'COMMUNITY_CHANNEL_CAPACITY_PENDING' =>
        '官方群已达到服务商的成员上限，暂时无法进入。你的 LOOP 社区成员资格不受影响。',
      'COMMUNITY_CHANNEL_PROVISION_FAILED' => '官方群创建或同步失败，需要运维介入后才能进入。',
      'COMMUNITY_MEMBERSHIP_REQUIRED' => '需要先加入该社区，才能进入官方群。',
      'VOICE_ROOM_RUNTIME_UNAVAILABLE' => '通信模块已启用，但服务端依赖尚未配齐。',
      'COMMUNITY_VOICE_ROOM_NOT_LIVE' => '该社区当前没有进行中的语音房。',
      'COMMUNICATION_RUNTIME_UNAVAILABLE' => '通信模块已启用，但服务端依赖尚未配齐。',
      'V2_COMMUNICATION_RUNTIME_DEFERRED' => '通信模块在当前环境尚未启用。',
      'AUDIO_ROOM_USER_ROLE_EVIDENCE_PENDING' =>
        '语音房入口需要服务商角色权限证据：必须先证明 audio_room 的 user 角色不能创建通话，'
            '客户端才允许连接。证据到位前本页不发起任何语音连接。',
      'STREAM_PARTICIPANT_COUNT_NOT_OBSERVED' => '服务商没有返回可信的在线人数，因此不展示任何数字。',
      'COMMUNITY_AI_RUNTIME_DEFERRED' => 'Community AI 运行时尚未接入，本页所有功能区都不可用。',
      null => '该字段当前没有可信来源。',
      _ => '该字段当前没有可信来源。',
    };
