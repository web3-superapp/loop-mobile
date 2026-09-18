import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';

/// Narrow, feature-facing failure taxonomy shared by the S3 ports
/// (`community`, social graph and `search`).
///
/// It carries no transport detail: the adapters map the V2 error catalogue
/// onto these kinds so `lib/features/` never branches on an HTTP status or a
/// `/v2/` literal.
enum CommunityFailureKind {
  offline,

  /// The request was cancelled in flight. A write may or may not have been
  /// applied, so its idempotency key must survive for an identical retry.
  cancelled,

  /// A 2xx (or an error envelope) the client could not parse. The server may
  /// already have applied the write, so this is an unresolved outcome too.
  outcomeUnknown,
  unavailable,
  permissionDenied,
  notFound,
  stale,
  activationRequired,
  bootstrapRequired,
  resourceConflict,
  validationFailed,
  aliasReserved,
  aliasBlocked,
  rateLimited,
  idempotencyConflict,
  invalidData,
  unexpected,
}

final class CommunityGatewayException implements Exception {
  const CommunityGatewayException(this.kind, {this.reasonCode});

  final CommunityFailureKind kind;

  /// The rule the server named in `detailsSafe.reasonCode`, when it named
  /// one. A kind says what class of refusal it was; this says which refusal,
  /// and it is the only way a page can answer 「为什么」 with the server's own
  /// answer instead of a sentence for the whole class.
  final String? reasonCode;

  @override
  String toString() => 'CommunityGatewayException(${kind.name})';
}

/// Thrown by a model when a value would break the frozen contract. It never
/// carries the offending value.
final class InvalidCommunityContractException implements Exception {
  const InvalidCommunityContractException();

  @override
  String toString() => 'The community payload broke the V2 contract.';
}

/// Delivery mode of one port implementation. `preview` is the only mode that
/// may render the visible `演示数据` label.
enum CommunityGatewayMode { production, preview, unavailable }

/// The `{ "status": "unavailable", "reasonCode": … }` projection.
///
/// A field carrying this object renders an unavailable explanation. It never
/// renders `0`, a placeholder figure, or a fixture.
@immutable
final class LoopUnavailableFact {
  const LoopUnavailableFact(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopUnavailableFact && other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

/// How many of a community's members are connected to Stream right now.
///
/// It is an observation, not a stored fact (Decision 0047): the count is the
/// members of the community's official Stream channel that hold a live
/// connection at the moment the detail page was read. It is not "watching this
/// channel", not "active recently", and not the community's membership. A
/// failed, timed-out or unprovisioned read is unavailable — never a zero, and
/// a real zero is a reading of its own.
@immutable
sealed class CommunityOnlineCount {
  const CommunityOnlineCount();
}

@immutable
final class CommunityOnlineCountUnavailable extends CommunityOnlineCount {
  const CommunityOnlineCountUnavailable(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityOnlineCountUnavailable &&
          other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

@immutable
final class CommunityOnlineCountObserved extends CommunityOnlineCount {
  const CommunityOnlineCountObserved({
    required this.count,
    required this.observedAt,
    required this.source,
  });

  final int count;

  /// When the observation was taken. The page prints it in UTC, because a
  /// reading of "now" that is a minute old is still a reading of that minute.
  final DateTime observedAt;

  /// What was counted. The client reads the meaning off this and never off
  /// the number alone.
  final CommunityPresenceSource source;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityOnlineCountObserved &&
          other.count == count &&
          other.observedAt == observedAt &&
          other.source == source;

  @override
  int get hashCode => Object.hash(count, observedAt, source);
}

/// The only observation the contract publishes: Stream channel members holding
/// a connection. A second source would mean a second sentence, so the client
/// refuses one it does not know.
enum CommunityPresenceSource {
  streamMemberPresence('stream_member_presence');

  const CommunityPresenceSource(this.wireName);

  final String wireName;

  static CommunityPresenceSource? tryParse(String value) {
    for (final source in values) {
      if (source.wireName == value) return source;
    }
    return null;
  }
}

/// A mining power reading on a community, a member row or a connection row.
///
/// Either a settled snapshot computed it under a named formula version, or it
/// did not and only the server's own `reasonCode` exists. A row never falls
/// back to `0`: an account with no balance in the snapshot and an account the
/// snapshot never reached are different facts.
@immutable
sealed class LoopMiningPowerFact {
  const LoopMiningPowerFact();
}

@immutable
final class LoopMiningPowerUnavailable extends LoopMiningPowerFact {
  const LoopMiningPowerUnavailable(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopMiningPowerUnavailable && other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

/// A reading the settlement produced. What it is a reading *of* decides what
/// it can explain: a community's number is the sum over one bound asset, so
/// the weight and the head count behind it exist; a member's number is one
/// person across every asset, and no single community weight explains it.
@immutable
sealed class LoopMiningPowerSettled extends LoopMiningPowerFact {
  const LoopMiningPowerSettled({
    required this.power,
    required this.snapshotId,
    required this.formulaVersion,
    required this.computedAt,
    required this.scope,
  });

  /// The server's own unsigned decimal string, rendered verbatim.
  final String power;
  final String snapshotId;

  /// A backend identifier. It belongs in a LoopDisclosure, never in a
  /// sentence.
  final String formulaVersion;
  final DateTime computedAt;

  /// The version's own declaration about itself. It is the only thing that
  /// may put the development-baseline label on a row — the version string is
  /// never read for meaning.
  final MiningFormulaScope scope;

  bool get isBaseline => scope.isBaseline;
}

/// A community's power: every unbanned member's power on the bound asset.
@immutable
final class LoopCommunityMiningPower extends LoopMiningPowerSettled {
  const LoopCommunityMiningPower({
    required super.power,
    required super.snapshotId,
    required super.formulaVersion,
    required super.computedAt,
    required super.scope,
    required this.weight,
    required this.participants,
  });

  /// The reviewed weight already inside [power], in the same shape the mining
  /// panel reads.
  final MiningCommunityWeight weight;

  /// Members whose power was above zero.
  final MiningParticipants participants;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopCommunityMiningPower &&
          other.power == power &&
          other.snapshotId == snapshotId &&
          other.formulaVersion == formulaVersion &&
          other.computedAt == computedAt &&
          other.scope == scope &&
          other.weight == weight &&
          other.participants == participants;

  @override
  int get hashCode => Object.hash(
    power,
    snapshotId,
    formulaVersion,
    computedAt,
    scope,
    weight,
    participants,
  );
}

/// One account's total power across every asset it holds. It carries no
/// weight and no head count: there is no single community weight that could
/// explain a number summed across assets.
@immutable
final class LoopAccountMiningPower extends LoopMiningPowerSettled {
  const LoopAccountMiningPower({
    required super.power,
    required super.snapshotId,
    required super.formulaVersion,
    required super.computedAt,
    required super.scope,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopAccountMiningPower &&
          other.power == power &&
          other.snapshotId == snapshotId &&
          other.formulaVersion == formulaVersion &&
          other.computedAt == computedAt &&
          other.scope == scope;

  @override
  int get hashCode =>
      Object.hash(power, snapshotId, formulaVersion, computedAt, scope);
}

/// The fixed four-field identity projection. No `profile_code`, wallet
/// address, Privy ID or Stream ID is ever part of it.
@immutable
final class LoopPublicProfile {
  const LoopPublicProfile({
    required this.publicProfileId,
    required this.loopId,
    required this.alias,
    required this.avatarRef,
  });

  /// The only accepted command target. `null` for a directory row that has no
  /// profile row: such a row is listed and counted but can never be the target
  /// of a governance action.
  final String? publicProfileId;
  final String loopId;
  final String? alias;
  final String? avatarRef;

  /// Alias when present, otherwise the LOOP ID. Never an invented value.
  String get displayName => alias ?? loopId;

  bool get isCommandTarget => publicProfileId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopPublicProfile &&
          other.publicProfileId == publicProfileId &&
          other.loopId == loopId &&
          other.alias == alias &&
          other.avatarRef == avatarRef;

  @override
  int get hashCode => Object.hash(publicProfileId, loopId, alias, avatarRef);
}

/// zh-CN copy for a failed community/social/search operation. It states what
/// did not happen; it never claims a result the server did not confirm.
String communityFailureReason(CommunityFailureKind? kind) => switch (kind) {
  CommunityFailureKind.offline => '设备已离线，这一页没有读到数据，也没有提交任何操作。',
  CommunityFailureKind.cancelled => '请求已被取消，结果未知。请查看最新状态后再决定是否重试。',
  CommunityFailureKind.outcomeUnknown => '返回的数据不完整，结果未确认。请刷新查看最新状态，不要重复提交。',
  CommunityFailureKind.unavailable => '社区服务当前不可用，没有执行任何操作。',
  CommunityFailureKind.permissionDenied => '当前账号没有执行这个操作的权限。',
  CommunityFailureKind.notFound => '目标不存在、已被移除，或对当前账号不可见。',
  CommunityFailureKind.stale => '状态已经改变（可能已被他人处理）。请刷新后重新决定。',
  CommunityFailureKind.activationRequired => '需要先完成 LOOP ID 激活才能执行社区与社交操作。',
  CommunityFailureKind.bootstrapRequired => '账号尚未完成初始化，请稍后重试。',
  CommunityFailureKind.resourceConflict => '该短链接已被其他社区占用，请换一个。',
  CommunityFailureKind.validationFailed => '输入内容不符合要求，请修改后重试。',
  CommunityFailureKind.aliasReserved => '该名称属于 LOOP 保留词，请换一个再试。',
  CommunityFailureKind.aliasBlocked => '该名称在运营屏蔽名单内，请换一个再试。',
  CommunityFailureKind.rateLimited => '搜索过于频繁，请稍等片刻再试。',
  CommunityFailureKind.idempotencyConflict => '同一操作已被提交过且内容不同，请检查最新状态后再试。',
  CommunityFailureKind.invalidData => '返回的数据不完整，这一页没有采用任何内容。',
  CommunityFailureKind.unexpected => '操作没有完成，请稍后再试。',
  null => '操作没有完成。',
};

/// Whether the write's outcome is unknown, so its idempotency key must be
/// replayed rather than replaced. A timeout, a lost connection, a cancelled
/// request and an unparsable response all leave the server free to have
/// applied the command already.
bool communityOutcomeIsUnresolved(CommunityFailureKind kind) =>
    kind == CommunityFailureKind.offline ||
    kind == CommunityFailureKind.cancelled ||
    kind == CommunityFailureKind.outcomeUnknown;

/// zh-CN copy for a refused community application.
///
/// The five codes the create endpoint can answer with are mapped one by one:
/// a reserved or blocked name, a taken slug, a length rejection and a missing
/// LOOP ID activation each need a different next step from the applicant.
String communityApplyFailureReason(CommunityFailureKind? kind) =>
    switch (kind) {
      CommunityFailureKind.aliasReserved =>
        '社区名称撞上了 LOOP 保留词（如官方、支持、管理），请换一个名称再提交。',
      CommunityFailureKind.aliasBlocked => '社区名称在当前的运营屏蔽名单内，请换一个名称再提交。',
      CommunityFailureKind.resourceConflict => '这个短链接已经被另一个社区占用，请换一个再提交。',
      CommunityFailureKind.validationFailed =>
        '名称或简介太长（名称 1–40 字，简介不超过 280 字），请修改后再提交。',
      CommunityFailureKind.activationRequired =>
        '需要先完成 LOOP ID 激活才能申请社区。激活后可以重新提交这份申请。',
      _ => communityFailureReason(kind),
    };

/// zh-CN explanation for one server `reasonCode`. An unknown code keeps a
/// neutral sentence rather than inventing a cause.
String communityUnavailableReason(String reasonCode) => switch (reasonCode) {
  'STREAM_UNREAD_NOT_CONNECTED' => '未读数暂时读不到。',
  'STREAM_VOICE_NOT_CONNECTED' => '语音房状态暂时读不到。',
  'STREAM_PRESENCE_NOT_CONNECTED' => '在线人数暂时读不到。',
  // The presence read has its own failure modes (Decision 0047). Each says
  // what was not done, and none of them is a zero.
  'COMMUNITY_CHANNEL_NOT_PROVISIONED' => '这个社区还没有官方频道，没有可以询问的在线人数。',
  'COMMUNITY_CHANNEL_PROVISION_FAILED' => '这个社区的官方频道没有建成，暂时问不到在线人数。',
  'STREAM_PRESENCE_READ_FAILED' => '这次没能问到在线人数，稍后重试。',
  'STREAM_PRESENCE_READ_TIMEOUT' => '这次查询在线人数超时了，没有结果。',
  'STREAM_PRESENCE_MEMBER_BOUND_EXCEEDED' => '这个社区的成员超过 500 人，这一版还数不了在线人数。',
  'STREAM_PRESENCE_NOT_OBSERVED' => '这一步没有观察在线人数，回到社区详情可以重新读。',
  'COMMUNICATION_RUNTIME_UNAVAILABLE' => '通信服务暂时不可用，问不到在线人数。',
  'MINING_FORMULA_BASELINE_PENDING' => '挖矿规则还没有确定，暂时不显示算力。',
  'COMMUNITY_ANNOUNCEMENTS_DEFERRED' => '社区公告还没有开放。',
  'COMMUNITY_LINKS_DEFERRED' => '官方链接还没有开放。',
  'MESSAGE_PREVIEW_DEFERRED' => '消息预览还没有开放。',
  'AI_MODERATION_DEFERRED' => 'AI 巡查还没有开放。',
  'ASSET_REGISTRY_DEFERRED' => '资产搜索还没有开放。',
  'LAUNCH_MODULE_DEFERRED' => 'Launch 搜索还没有开放。',
  'DAPP_DIRECTORY_DEFERRED' => 'DApp 目录还没有开放。',
  'REFERRAL_GRAPH_DEFERRED' => '邀请数据还没有开放。',
  'INVITE_CODE_DEFERRED' => '邀请码还没有开放，暂时不能分享。',
  'COMMUNITY_RUNTIME_UNAVAILABLE' => '社区暂时不可用，稍后再试。',
  'SEARCH_RUNTIME_UNAVAILABLE' => '搜索暂时不可用，稍后再试。',
  _ => '这一项暂时读不到。',
};
