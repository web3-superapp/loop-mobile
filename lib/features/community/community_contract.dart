import 'package:flutter/foundation.dart';

/// Narrow, feature-facing failure taxonomy shared by the S3 ports
/// (`community`, social graph and `search`).
///
/// It carries no transport detail: the adapters map the V2 error catalogue
/// onto these kinds so `lib/features/` never branches on an HTTP status or a
/// `/v2/` literal.
enum CommunityFailureKind {
  offline,
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
  const CommunityGatewayException(this.kind);

  final CommunityFailureKind kind;

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
  CommunityFailureKind.offline => '设备当前离线，本页没有读到任何服务端数据，也没有提交任何操作。',
  CommunityFailureKind.unavailable => '社区服务当前不可用，没有执行任何操作。',
  CommunityFailureKind.permissionDenied => '当前账号无权执行此操作，服务端已拒绝。',
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
  CommunityFailureKind.invalidData => '服务返回的数据不符合约定，本页没有采纳任何内容。',
  CommunityFailureKind.unexpected => '操作没有完成，未暴露供应商细节。',
  null => '操作没有完成。',
};

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
        '名称或简介归一化后超出长度限制（名称 1–40，简介 ≤280），请修改后再提交。',
      CommunityFailureKind.activationRequired =>
        '需要先完成 LOOP ID 激活才能申请社区。激活后可以重新提交这份申请。',
      _ => communityFailureReason(kind),
    };

/// zh-CN explanation for one server `reasonCode`. An unknown code keeps a
/// neutral sentence rather than inventing a cause.
String communityUnavailableReason(String reasonCode) => switch (reasonCode) {
  'STREAM_UNREAD_NOT_CONNECTED' => '未读计数需要 Stream 接通后才有来源。',
  'STREAM_VOICE_NOT_CONNECTED' => '语音房状态需要 Stream 接通后才有来源。',
  'STREAM_PRESENCE_NOT_CONNECTED' => '在线人数需要 Stream 在线状态接通后才有来源。',
  'MINING_FORMULA_BASELINE_PENDING' => '算力口径尚未确定，不展示任何算力数字。',
  'COMMUNITY_ANNOUNCEMENTS_DEFERRED' => '社区公告尚未接入，不展示示例内容。',
  'COMMUNITY_LINKS_DEFERRED' => '官方链接尚未接入，不展示未核验的地址。',
  'MESSAGE_PREVIEW_DEFERRED' => '消息正文预览尚未接入，不展示任何正文。',
  'AI_MODERATION_DEFERRED' => 'AI 巡查标记尚未接入，不展示任何风险结论。',
  'ASSET_REGISTRY_DEFERRED' => '资产检索源尚未接入。',
  'LAUNCH_MODULE_DEFERRED' => 'Launch 检索源尚未接入。',
  'DAPP_DIRECTORY_DEFERRED' => 'DApp 目录尚未接入。',
  'REFERRAL_GRAPH_DEFERRED' => '邀请关系数据尚未接入，不展示任何人数。',
  'INVITE_CODE_DEFERRED' => '邀请码尚未接入，分享入口保持禁用。',
  'COMMUNITY_RUNTIME_UNAVAILABLE' => '社区模块已启用，但服务端依赖尚未配齐。',
  'SEARCH_RUNTIME_UNAVAILABLE' => '搜索模块已启用，但服务端依赖尚未配齐。',
  _ => '该字段当前没有可信来源。',
};
