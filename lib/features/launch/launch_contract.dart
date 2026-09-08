import 'package:flutter/foundation.dart';

/// Narrow, feature-facing failure taxonomy shared by the three S7 ports
/// (`launch`, `mining` and `referral`).
///
/// It carries no transport detail: the adapters map the frozen V2 error
/// catalogue onto these kinds, so `lib/features/` never branches on an HTTP
/// status or a `/v2/` literal. It lives with `launch` for the same reason the
/// S5 taxonomy lives with `chain`: the first module of the step owns it.
enum LaunchFailureKind {
  offline,

  /// The request was cancelled in flight. A write may or may not have been
  /// applied, so its idempotency key must survive an identical retry.
  cancelled,

  /// A response the client could not parse. The server may already have
  /// applied a write, so this is an unresolved outcome too.
  outcomeUnknown,

  /// The capability, the module or the runtime is not assembled. For the
  /// step-7 write paths this is also how `503 CAPABILITY_UNAVAILABLE` — the
  /// permanent answer of `POST …/intents` — reaches the page.
  unavailable,

  /// `403 PERMISSION_DENIED`.
  permissionDenied,

  /// `403 POLICY_BLOCKED`: the account is known but the policy window has
  /// closed. Kept apart from [permissionDenied] because the next step differs.
  policyBlocked,
  notFound,

  /// `409 DATA_STALE`: the resource is no longer in a state that accepts this
  /// command (an already-submitted application, an already-bound invite).
  stale,

  /// `409 VERSION_CONFLICT`: reload and merge before retrying.
  versionConflict,

  /// `409 PROFILE_ACTIVATION_REQUIRED`: the account has no LOOP ID yet.
  activationRequired,
  bootstrapRequired,
  validationFailed,
  idempotencyConflict,
  invalidData,
  unexpected,
}

final class LaunchException implements Exception {
  const LaunchException(this.kind);

  final LaunchFailureKind kind;

  @override
  String toString() => 'LaunchException(${kind.name})';
}

/// Delivery mode of one port implementation. There is no `preview` mode in
/// step 7: no Launch, Mining or Referral fixture may ever be rendered.
enum LaunchGatewayMode { production, unavailable }

/// The `{ "status": "unavailable", "reasonCode": … }` projection.
///
/// A field carrying this object renders an unavailable explanation. It never
/// renders `0` or a fixture. An [launchMissingFigure] em dash may accompany
/// the explanation as the empty metric, never replace it.
@immutable
final class LaunchUnavailable {
  const LaunchUnavailable(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LaunchUnavailable && other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

/// The em dash used wherever an S7 figure has no source. Never `0`.
///
/// Step 7 has neither a Launch contract baseline nor an approved Mining
/// formula, so every on-chain and every formula-derived number renders as this
/// placeholder next to the server's own `reasonCode`.
const String launchMissingFigure = '—';

/// "待确认（configVersion）" for a configuration slot that has no confirmed
/// version yet. A `null` version keeps the sentence without inventing a name.
String launchPendingConfirmationLabel(String? configVersion) =>
    configVersion == null ? '待确认（版本未指派）' : '待确认（$configVersion）';

/// zh-CN copy for a failed S7 operation. It states what did not happen; it
/// never claims a result the server did not confirm.
String launchFailureReason(LaunchFailureKind? kind) => switch (kind) {
  LaunchFailureKind.offline => '设备当前离线，本页没有读到任何服务端数据，也没有提交任何操作。',
  LaunchFailureKind.cancelled => '请求已被取消，结果未知。请查看最新状态后再决定是否重试。',
  LaunchFailureKind.outcomeUnknown => '服务返回的数据不符合约定，结果未确认。请刷新查看最新状态，不要重复提交。',
  LaunchFailureKind.unavailable => '该能力当前不可用，没有执行任何操作，也没有回退到演示数据。',
  LaunchFailureKind.permissionDenied => '当前账号无权执行此操作，服务端已拒绝。',
  LaunchFailureKind.policyBlocked => '服务端策略拒绝了本次操作（例如绑定窗口已经关闭）。',
  LaunchFailureKind.notFound => '目标不存在、已被移除，或对当前账号不可见。',
  LaunchFailureKind.stale => '当前状态不允许这个操作，请刷新后按最新状态重新决定。',
  LaunchFailureKind.versionConflict => '资料已被其他设备修改。请重新加载后再提交，本次没有覆盖任何内容。',
  LaunchFailureKind.activationRequired => '需要先完成 LOOP ID 激活才能执行此操作。',
  LaunchFailureKind.bootstrapRequired => '账号尚未完成初始化，请稍后重试。',
  LaunchFailureKind.validationFailed => '输入内容不符合要求，请修改后重试。',
  LaunchFailureKind.idempotencyConflict => '同一操作已被提交过且内容不同，请检查最新状态后再试。',
  LaunchFailureKind.invalidData => '服务返回的数据不符合约定，本页没有采纳任何内容。',
  LaunchFailureKind.unexpected => '操作没有完成，未暴露供应商细节。',
  null => '操作没有完成。',
};

/// Whether a write's outcome is unknown, so its idempotency key must be
/// replayed rather than replaced.
bool launchOutcomeIsUnresolved(LaunchFailureKind kind) =>
    kind == LaunchFailureKind.offline ||
    kind == LaunchFailureKind.cancelled ||
    kind == LaunchFailureKind.outcomeUnknown;

/// zh-CN explanation for one server `reasonCode`.
///
/// An unknown code keeps a neutral sentence rather than inventing a cause. No
/// entry restates a rate, a cap, a supply or a tax: those numbers do not exist
/// until the contract and formula baselines are delivered.
String launchReasonCodeText(String? reasonCode) => switch (reasonCode) {
  // launch · contract baseline
  'LAUNCH_CONTRACT_BASELINE_PENDING' =>
    'Launch 合约基线尚未交付，链上状态、购买、退款、领取与建池全部无法证明，本页不构造任何交易。',
  'LAUNCH_CONFIG_PENDING_CONFIRMATION' => '该配置槽位还没有已确认的版本，数值待确认。',
  'LAUNCH_POOL_EVIDENCE_UNAVAILABLE' => '没有可引用的流动性池证据，毕业步骤保持待触发。',
  'LAUNCH_ECONOMY_CONTRACT_PENDING' => '总量、发行与生态税需要合约基线，本页只展示可从库中证明的计数。',
  'LAUNCH_RUNTIME_UNAVAILABLE' => 'Launch 模块已启用，但服务端依赖尚未配齐。',
  'TIER_MODE_PENDING' => '资格模式尚未配置，当前没有资格结论；资格不依赖质押。',
  'STAKING_CONTRACT_PENDING' => '质押合约尚未交付，本页整页不可执行。',
  'KYB_PROVIDER_NOT_SELECTED' => 'KYB 服务商尚未选定，主体审核状态待接入。',
  'ATTACHMENT_STORAGE_NOT_SELECTED' => '附件存储尚未选定，本页不提供上传。',
  // mining · formula baseline
  'MINING_FORMULA_BASELINE_PENDING' => '没有已批准的挖矿公式版本，算力、产量、排行与邀请加成全部无法计算。',
  'MINING_SNAPSHOT_NOT_AVAILABLE' => '还没有任何已结算的算力快照。',
  'MINING_RUNTIME_UNAVAILABLE' => 'Mining 模块已启用，但服务端依赖尚未配齐。',
  'REWARD_AUTHORITY_PENDING' => '奖励发放权限尚未确定，待领取数量无法证明，领取入口保持禁用。',
  'COMMUNITY_WEIGHT_PENDING_REVIEW' => '该社区的挖矿权重仍在审核中，尚未授予数值。',
  // referral
  'REFERRAL_RUNTIME_UNAVAILABLE' => 'Referral 模块已启用，但服务端依赖尚未配齐。',
  'PROFILE_ACTIVATION_REQUIRED' => '需要先完成 LOOP ID 激活，才会有绑定窗口。',
  null => '该字段当前没有可信来源。',
  _ => '该字段当前没有可信来源。',
};

/// The reviewed page states for an S7 surface.
enum LaunchViewPhase {
  loading,
  ready,
  empty,
  error,
  offline,
  unavailable,
  permission,
}

LaunchViewPhase launchPhaseForFailure(LaunchFailureKind? kind) =>
    switch (kind) {
      LaunchFailureKind.offline => LaunchViewPhase.offline,
      LaunchFailureKind.unavailable => LaunchViewPhase.unavailable,
      LaunchFailureKind.permissionDenied ||
      LaunchFailureKind.policyBlocked ||
      LaunchFailureKind.activationRequired => LaunchViewPhase.permission,
      null => LaunchViewPhase.empty,
      _ => LaunchViewPhase.error,
    };

/// One loaded resource plus the honest phase for the block that renders it.
@immutable
final class LaunchResourceState<T> {
  const LaunchResourceState({
    required this.mode,
    required this.phase,
    this.value,
    this.failureKind,
    this.busy = false,
  });

  factory LaunchResourceState.initial(LaunchGatewayMode mode) {
    final closed = mode == LaunchGatewayMode.unavailable;
    return LaunchResourceState<T>(
      mode: mode,
      phase: closed ? LaunchViewPhase.unavailable : LaunchViewPhase.loading,
      failureKind: closed ? LaunchFailureKind.unavailable : null,
    );
  }

  final LaunchGatewayMode mode;
  final LaunchViewPhase phase;
  final T? value;
  final LaunchFailureKind? failureKind;

  /// A write is in flight. The page keeps rendering the last server truth and
  /// only disables its actions.
  final bool busy;

  bool get isReady => phase == LaunchViewPhase.ready && value != null;

  LaunchResourceState<T> loading() => LaunchResourceState<T>(
    mode: mode,
    phase: value == null ? LaunchViewPhase.loading : LaunchViewPhase.ready,
    value: value,
    busy: busy,
  );

  LaunchResourceState<T> ready(T next) => LaunchResourceState<T>(
    mode: mode,
    phase: LaunchViewPhase.ready,
    value: next,
  );

  LaunchResourceState<T> failed(LaunchFailureKind kind) =>
      LaunchResourceState<T>(
        mode: mode,
        phase: value == null
            ? launchPhaseForFailure(kind)
            : LaunchViewPhase.ready,
        value: value,
        failureKind: kind,
      );

  LaunchResourceState<T> working(bool next) => LaunchResourceState<T>(
    mode: mode,
    phase: phase,
    value: value,
    failureKind: next ? null : failureKind,
    busy: next,
  );
}
