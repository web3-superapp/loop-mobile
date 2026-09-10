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
  LaunchFailureKind.offline => '设备已离线，这一页没有读到数据，也没有提交任何操作。',
  LaunchFailureKind.cancelled => '请求已被取消，结果未知。请查看最新状态后再决定是否重试。',
  LaunchFailureKind.outcomeUnknown => '返回的数据不完整，结果未确认。请刷新查看最新状态，不要重复提交。',
  LaunchFailureKind.unavailable => '该能力当前不可用，没有执行任何操作，也没有回退到演示数据。',
  LaunchFailureKind.permissionDenied => '当前账号没有执行这个操作的权限。',
  LaunchFailureKind.policyBlocked => '这次操作没有通过，可能是绑定窗口已经关闭。',
  LaunchFailureKind.notFound => '目标不存在、已被移除，或对当前账号不可见。',
  LaunchFailureKind.stale => '当前状态不允许这个操作，请刷新后按最新状态重新决定。',
  LaunchFailureKind.versionConflict => '资料已被其他设备修改。请重新加载后再提交，本次没有覆盖任何内容。',
  LaunchFailureKind.activationRequired => '需要先完成 LOOP ID 激活才能执行此操作。',
  LaunchFailureKind.bootstrapRequired => '账号尚未完成初始化，请稍后重试。',
  LaunchFailureKind.validationFailed => '输入内容不符合要求，请修改后重试。',
  LaunchFailureKind.idempotencyConflict => '同一操作已被提交过且内容不同，请检查最新状态后再试。',
  LaunchFailureKind.invalidData => '返回的数据不完整，这一页没有采用任何内容。',
  LaunchFailureKind.unexpected => '操作没有完成，请稍后再试。',
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
/// zh-CN sentence for one `reviewReasonCode` on a returned Launch application.
///
/// The code is an internal identifier; it never reaches the screen. An
/// unrecognised code keeps a neutral sentence rather than inventing a cause.
String launchReviewReasonText(String reasonCode) => switch (reasonCode) {
  'narrative_too_short' => '项目简介太短，请补充后重新提交。',
  'narrative_missing' => '缺少项目简介，请补充后重新提交。',
  'links_unreachable' => '官方链接打不开，请检查后重新提交。',
  'ticker_conflict' => '代号已被占用，请换一个再提交。',
  'duplicate_submission' => '这个项目已经提交过，请勿重复申请。',
  _ => '申请被退回，请补充材料后重新提交。',
};

String launchReasonCodeText(String? reasonCode) => switch (reasonCode) {
  // launch · contract baseline
  'LAUNCH_CONTRACT_BASELINE_PENDING' => 'Launch 合约还没有上线，链上状态、购买、退款与领取都暂时不可用。',
  'LAUNCH_CONFIG_PENDING_CONFIRMATION' => '这一项还没有确认的配置，数值待定。',
  'LAUNCH_POOL_EVIDENCE_UNAVAILABLE' => '还读不到流动性池信息，毕业步骤保持待触发。',
  'LAUNCH_ECONOMY_CONTRACT_PENDING' => '总量、发行与生态税要等合约上线，这里只显示 LOOP 能核对的数量。',
  'LAUNCH_RUNTIME_UNAVAILABLE' => 'Launch 暂时不可用，稍后再试。',
  'TIER_MODE_PENDING' => '这次发射的资格规则还没有配置。资格不依赖质押。',
  'STAKING_CONTRACT_PENDING' => '质押还没有开放，这一页暂时不能操作。',
  'KYB_PROVIDER_NOT_SELECTED' => '开放后会在这里显示审核状态。',
  'ATTACHMENT_STORAGE_NOT_SELECTED' => '暂时不能上传附件。',
  // mining · formula baseline
  'MINING_FORMULA_BASELINE_PENDING' => '挖矿公式还没有批准，算力、产量、排行与邀请加成都暂时不可用。',
  'MINING_SNAPSHOT_NOT_AVAILABLE' => '还没有任何一次算力结算。',
  'MINING_RUNTIME_UNAVAILABLE' => '挖矿暂时不可用，稍后再试。',
  'REWARD_AUTHORITY_PENDING' => '奖励发放还没有开启，暂时不能领取。',
  'COMMUNITY_WEIGHT_PENDING_REVIEW' => '这个社区的挖矿权重还在审核中。',
  // referral
  'REFERRAL_RUNTIME_UNAVAILABLE' => '邀请暂时不可用，稍后再试。',
  'PROFILE_ACTIVATION_REQUIRED' => '需要先完成 LOOP ID 激活，才会有绑定窗口。',
  null => '这一项暂时读不到。',
  _ => '这一项暂时读不到。',
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
