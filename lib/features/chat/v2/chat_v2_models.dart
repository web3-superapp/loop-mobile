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
    required this.communityName,
    required this.callCid,
    required this.state,
    required this.provisionState,
    required this.backstage,
    required this.createdAt,
    required this.endedAt,
  });

  final String voiceRoomId;
  final String communityId;

  /// The community's own name, read from the community row on every response
  /// (decision 0052). It is a display value: the banner and the room title say
  /// which community this is without a second read, and nothing is ever keyed
  /// by it — [communityId] stays the relation.
  final String communityName;

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

/// Which roster view `GET /v2/voice-rooms/{id}/members` answers for.
///
/// The host is in neither view: both list the LOOP `joined` members by role
/// intent, so a room with only a host has two empty rosters and that is the
/// truth, not a missing read.
enum VoiceRoomRosterView {
  speaker('speaker'),
  listener('listener');

  const VoiceRoomRosterView(this.wireName);

  final String wireName;

  String get label => switch (this) {
    VoiceRoomRosterView.speaker => '发言人',
    VoiceRoomRosterView.listener => '听众',
  };

  static VoiceRoomRosterView? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// Who a roster row's alias is published to (decision 0049, the mining board's
/// rule). It is the row owner's own setting, reported verbatim.
enum VoiceRoomMemberAudience {
  everyone('everyone'),
  self('self');

  const VoiceRoomMemberAudience(this.wireName);

  final String wireName;

  static VoiceRoomMemberAudience? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// How one roster row may be named.
///
/// Anonymous mode alone decides what other readers see: a member with it on is
/// [VoiceRoomMemberAnonymousName] to everyone else and always its own alias to
/// itself, with [VoiceRoomMemberAlias.audience] saying which of the two this
/// row is.
@immutable
sealed class VoiceRoomMemberName {
  const VoiceRoomMemberName();
}

@immutable
final class VoiceRoomMemberAlias extends VoiceRoomMemberName {
  const VoiceRoomMemberAlias({
    required this.alias,
    required this.publicProfileId,
    required this.audience,
  });

  final String alias;
  final String publicProfileId;
  final VoiceRoomMemberAudience audience;
}

@immutable
final class VoiceRoomMemberAnonymousName extends VoiceRoomMemberName {
  const VoiceRoomMemberAnonymousName(this.labelKey);

  /// The server's own i18n key. The client prints the sentence it is given a
  /// key for and invents no name of its own.
  final String labelKey;
}

/// The two server-owned keys a roster page is displayed under (decision 0052):
/// the anonymous label and the rule that only anonymous mode decides it.
@immutable
final class VoiceRoomMemberDisplayRule {
  const VoiceRoomMemberDisplayRule({
    required this.anonymousMemberKey,
    required this.ruleKey,
  });

  final String anonymousMemberKey;
  final String ruleKey;
}

/// One command the server says this viewer may run against one roster row.
///
/// The list on the row is exhaustive and authoritative (the S17 member
/// directory pattern): the client renders exactly these and derives none of
/// its own from the viewer's role.
enum VoiceRoomMemberCommand {
  inviteSpeaker('invite_speaker'),
  removeSpeaker('remove_speaker'),
  mute('mute');

  const VoiceRoomMemberCommand(this.wireName);

  final String wireName;

  String get label => switch (this) {
    VoiceRoomMemberCommand.inviteSpeaker => '邀请上麦',
    VoiceRoomMemberCommand.removeSpeaker => '移出发言',
    VoiceRoomMemberCommand.mute => '静音',
  };

  static VoiceRoomMemberCommand? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// One row of the speaker or listener roster.
@immutable
final class VoiceRoomMember {
  const VoiceRoomMember({
    required this.publicProfileId,
    required this.name,
    required this.view,
    required this.joinedAt,
    required this.handRaised,
    required this.muted,
    required this.isSelf,
    required this.commands,
  });

  /// The command target. Null when the row is anonymous to a viewer that is
  /// not the host: there is nothing to address and nothing to open.
  final String? publicProfileId;
  final VoiceRoomMemberName name;
  final VoiceRoomRosterView view;
  final DateTime joinedAt;

  /// The member has a pending LOOP hand raise. Meaningful on the listener
  /// view; a speaker is always false.
  final bool handRaised;

  /// The host's LOOP-side mute intent, not Stream media state: it does not say
  /// whether the microphone is open now, and every role change clears it.
  final bool muted;
  final bool isSelf;
  final List<VoiceRoomMemberCommand> commands;
}

/// One page of `GET /v2/voice-rooms/{id}/members`.
@immutable
final class VoiceRoomMemberPage {
  VoiceRoomMemberPage({
    required this.view,
    required List<VoiceRoomMember> items,
    required this.nextCursor,
    required this.display,
  }) : items = List<VoiceRoomMember>.unmodifiable(items);

  final VoiceRoomRosterView view;
  final List<VoiceRoomMember> items;

  /// Non-null only when another page exists. The cursor carries the page size
  /// and is bound to this view, so it is never sent with a limit or under the
  /// other role.
  final String? nextCursor;
  final VoiceRoomMemberDisplayRule display;
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
    this.participantCount,
  }) : unavailable = null;

  const VoiceRoomObservedParticipants.unavailable(
    LoopUnavailableFact this.unavailable,
  ) : memberCount = null,
      participantCount = null,
      observedAt = null;

  /// Devices connected to the live call right now. This is the only figure
  /// that means "people in the room"; a LOOP join grant alone does not raise
  /// it. Null while the server still answers with the shape that had no such
  /// field.
  final int? participantCount;

  /// Accounts the provider lets into the call, connected or not. It is
  /// authorization, not presence.
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
    this.joinedCount,
  });

  /// LOOP-side role intent, not a Stream presence count. The host is neither
  /// a speaker nor a listener, so it is in neither figure.
  final int speakerCount;
  final int listenerCount;

  /// Every LOOP member currently joined, the host included. Null while the
  /// server still answers with the shape that had no such field.
  final int? joinedCount;
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

/// zh-CN copy for one server-owned voice-room display key. An unknown key
/// keeps a neutral word rather than inventing a name.
String voiceRoomDisplayKeyText(String key) => switch (key) {
  'voiceRoom.member.anonymousMember' => '匿名成员',
  'voiceRoom.member.display.anonymousModeOnly' =>
    '只有开启匿名模式的成员显示为匿名；是否可被发现不影响这一行。',
  _ => '这一项暂时读不到。',
};

/// zh-CN copy for one communication `reasonCode`. An unknown code keeps a
/// neutral sentence rather than inventing a cause.
String communicationUnavailableReason(String? reasonCode) =>
    switch (reasonCode) {
      // One code covers two states — a community with no channel row at all,
      // and one whose row was allocated but whose channel is not created yet
      // — so the sentence states the fact both share and claims no cause. It
      // used to blame a verification the reader could see was already done.
      'COMMUNITY_CHANNEL_NOT_PROVISIONED' => '该社区还没有官方群频道。',
      'COMMUNITY_CHANNEL_MEMBER_SYNCING' => '你的频道成员身份正在同步，稍后即可进入。',
      'COMMUNITY_CHANNEL_CAPACITY_PENDING' =>
        '官方群已达到服务商的成员上限，暂时无法进入。你的 LOOP 社区成员资格不受影响。',
      'COMMUNITY_CHANNEL_PROVISION_FAILED' => '官方群创建或同步失败，需要运维介入后才能进入。',
      'COMMUNITY_MEMBERSHIP_REQUIRED' => '需要先加入该社区，才能进入官方群。',
      'VOICE_ROOM_RUNTIME_UNAVAILABLE' => '聊天暂时不可用，稍后再试。',
      'COMMUNITY_VOICE_ROOM_NOT_LIVE' => '该社区当前没有进行中的语音房。',
      'COMMUNICATION_RUNTIME_UNAVAILABLE' => '聊天暂时不可用，稍后再试。',
      'V2_COMMUNICATION_RUNTIME_DEFERRED' => '聊天在当前环境还没有开放。',
      'AUDIO_ROOM_USER_ROLE_EVIDENCE_PENDING' =>
        '语音房还在验证中，'
            '验证通过前这一页不会发起任何语音连接。',
      'STREAM_PARTICIPANT_COUNT_NOT_OBSERVED' => '在线人数暂时读不到，因此不显示数字。',
      'COMMUNITY_AI_RUNTIME_DEFERRED' => 'Community AI 还没有开放，这一页暂时不可用。',
      null => '这一项暂时读不到。',
      _ => '这一项暂时读不到。',
    };
