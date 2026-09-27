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

  /// A **read** that went out and got no answer in time. The same page phase
  /// as [offline]; only the wording differs (S88d). A write never carries it.
  timedOut,

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

  /// `409 INSUFFICIENT_BALANCE` on a purchase intent (decision 0089): the
  /// USD1 balance, the USD1 allowance or the network fee is short, named by
  /// `detailsSafe.reasonCode`. A known refusal, never an unresolved outcome.
  insufficientBalance,
  invalidData,
  unexpected,
}

final class LaunchException implements Exception {
  const LaunchException(this.kind, {this.reasonCode});

  final LaunchFailureKind kind;

  /// The server's `detailsSafe.reasonCode`, when the refusal named one. It is
  /// a stable identifier the page maps to copy; never provider detail.
  final String? reasonCode;

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

/// The same absence, said in words, where a folio heading would carry the
/// figure.
///
/// [launchMissingFigure] still owns every metric cell, row end and sentence:
/// at 11–20px, next to its own label, an em dash reads as "nothing here". A
/// hero heading prints at 25–30px in Lime, and there the same dash reads as a
/// stray green rule rather than as a placeholder. The heading therefore says
/// it: never `0`, never blank, and still the plain statement that this page
/// has no number to show yet.
const String launchMissingHeading = '暂无数值';

/// The same placeholder for a heading that was never a number. A missing
/// project name is not a missing figure, and neither is a missing eligibility
/// result; saying 暂无数值 there would describe the wrong kind of gap.
const String launchMissingName = '暂无名称';
const String launchMissingResult = '暂无结果';

/// What a configuration slot says while no version of it is confirmed.
///
/// The version that will confirm it is a backend identifier. It says nothing a
/// reader can act on, so the slot states the status alone.
const String launchPendingConfirmationLabel = '待确认';

/// zh-CN copy for a failed S7 operation. It states what did not happen; it
/// never claims a result the server did not confirm.
String launchFailureReason(LaunchFailureKind? kind) => switch (kind) {
  LaunchFailureKind.offline => '设备已离线，这一页没有读到数据，也没有提交任何操作。',
  LaunchFailureKind.timedOut => 'LOOP 响应超时，这一页没有读到数据，也没有提交任何操作。',
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
  LaunchFailureKind.insufficientBalance => '支付钱包的余额、授权额度或网络费不足，没有提交任何交易。',
  LaunchFailureKind.invalidData => '返回的数据不完整，这一页没有采用任何内容。',
  LaunchFailureKind.unexpected => '操作没有完成，请稍后再试。',
  null => '操作没有完成。',
};

/// Whether a write's outcome is unknown, so its idempotency key must be
/// replayed rather than replaced.
bool launchOutcomeIsUnresolved(LaunchFailureKind kind) =>
    kind == LaunchFailureKind.offline ||
    kind == LaunchFailureKind.timedOut ||
    kind == LaunchFailureKind.cancelled ||
    kind == LaunchFailureKind.outcomeUnknown;

/// zh-CN explanation for one server `reasonCode`.
///
/// An unknown code keeps a neutral sentence rather than inventing a cause. No
/// entry restates a rate, a cap, a supply or a tax: those numbers do not exist
/// until the contract and formula baselines are delivered.
String launchReasonCodeText(String? reasonCode) => switch (reasonCode) {
  // launch · contract baseline
  'LAUNCH_CONTRACT_BASELINE_PENDING' => 'Launch 合约还没有上线，链上状态、购买、退款与领取都暂时不可用。',
  // launch · contract adapter (loop-api decision 0076)
  'LAUNCH_CONTRACT_VERIFICATION_PENDING' => 'Launch 合约已配置，还在核对链上代码，请稍后刷新。',
  'LAUNCH_CONTRACT_CODE_MISSING' => '配置的 Launch 合约地址上没有代码，链上状态暂时不可用。',
  'LAUNCH_CONTRACT_VERSION_UNSUPPORTED' => '当前 Launch 合约版本不受支持，链上状态暂时不可用。',
  'LAUNCH_CHAIN_RPC_NOT_CONFIGURED' => 'Launch 链还没有可用的节点，链上状态暂时不可用。',
  'LAUNCH_CHAIN_ID_MISMATCH' => 'Launch 节点返回的不是配置的链，链上状态暂时不可用。',
  'LAUNCH_CHAIN_RPC_UNREACHABLE' => 'Launch 链节点暂时连不上，请稍后刷新。',
  'LAUNCH_SALE_NOT_REGISTERED' => '这次发射还没有登记到链上，等待上链。',
  'LAUNCH_SALE_CONTRACT_MISMATCH' => '这次发射登记的合约与当前配置不一致，链上状态暂时不可用。',
  'LAUNCH_SALE_NOT_FOUND' => '合约上找不到这次发射，链上状态暂时不可用。',
  'LAUNCH_CONFIG_VERSION_MISMATCH' => '链上配置版本与记录不一致，链上状态暂时不可用。',
  'LAUNCH_USD1_ADDRESS_MISMATCH' => '这次发射的结算币不是配置的 USD1，链上状态暂时不可用。',
  'LAUNCH_CONTRACT_READ_FAILED' => '读取 Launch 合约失败，请稍后刷新。',
  // launch · purchase preflight (loop-api decision 0077, client 0089). Each
  // one leads back to its own guidance on the trade page.
  'LAUNCH_USD1_ALLOWANCE_INSUFFICIENT' =>
    'USD1 授权额度不足以支付这次认购，没有提交任何交易。请先授权本次金额，授权到账后再购买。',
  'LAUNCH_USD1_BALANCE_INSUFFICIENT' =>
    '支付钱包在 Launch 链上的 USD1 余额不足，没有提交任何交易。请先向这个钱包转入足够的 USD1，或降低本次金额。',
  'LAUNCH_GAS_INSUFFICIENT' =>
    '支付钱包在 Launch 链上的原生币不足以支付网络费，没有提交任何交易。请先向这个钱包转入少量网络费用币后再试。',
  'LAUNCH_CONTRACT_READ_INVALID' => 'Launch 合约返回了无法解读的值，链上状态暂时不可用。',
  'LAUNCH_SNAPSHOT_REORGED' => '读取期间区块被重组，请稍后刷新。',
  'LAUNCH_ONCHAIN_STATE_NOT_INDEXED' => '列表不逐个读链，进入详情查看链上状态。',
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
  // The boost has a code of its own (Decision 0046): it says that the
  // effective version has not approved the boost, and nothing about the
  // figures beside it. Restating the whole formula here would contradict a
  // page that is printing settled power at the same time.
  'MINING_REFERRAL_BOOST_PENDING' => '生效的公式版本还没有批准邀请加成，这一项暂时没有数值。',
  'MINING_SNAPSHOT_NOT_AVAILABLE' => '还没有任何一次算力快照。',
  'MINING_SNAPSHOT_STALE' => '最近一次算力快照用的是旧的公式版本，等下一次快照后再看。',
  // Decision 0057: a run that cannot value a held asset is not published, so
  // reading nothing is never published as a zero. These three say which of
  // 「还没算完」/「还没轮到这个钱包」/「这个资产没有报价」 it is.
  'MINING_SNAPSHOT_INCOMPLETE' => '最近一次计算里有资产读不到参考价，这次没有发布；也还没有可以回退的完整快照。',
  'MINING_SNAPSHOT_PENDING' => '这个钱包还没有进入任何一次完整的算力快照，下一次算力快照之后显示。',
  'MINING_PRICE_PAIR_NOT_FOUND' => '这个资产暂时没有可用报价，这次没有计入。',
  'MINING_SNAPSHOT_PUBLISHED_INCOMPLETE' => '那一次算力快照的数据不完整，已经作废。',
  'MINING_ACCOUNT_NOT_IN_SNAPSHOT' => '最近一次算力快照里没有这个账号的钱包余额。',
  'MINING_NETWORK_POWER_ZERO' => '全网算力为 0，还算不出份额。',
  'MINING_DAILY_OUTPUT_NOT_CONFIGURED' => '当前公式版本还没有配置每日产量。',
  'MINING_RANK_NOT_RANKED' => '算力为 0，暂时没有名次。',
  'MINING_RANK_NOT_APPLICABLE' => '社区榜不显示个人名次。',
  'MINING_POWER_PRIVATE' => '对方把挖矿算力设为仅自己可见。',
  'MINING_PRICE_NOT_FRESH' => '参考价不够新，这个资产这次没有计入。',
  'MINING_PRICE_PROXY_NOT_DECLARED' => '这个资产的参考价来自未登记的代币，这次没有计入。',
  'MINING_ASSET_WEIGHT_NOT_CONFIGURED' => '当前公式版本没有给这个资产权重。',
  'COMMUNITY_ASSET_NOT_BOUND' => '这个社区还没有绑定代币。',
  'COMMUNITY_WEIGHT_AMBIGUOUS' => '有两个社区都绑定了这个资产，这次没有计入。',
  'MINING_RUNTIME_UNAVAILABLE' => '挖矿暂时不可用，稍后再试。',
  'REWARD_AUTHORITY_PENDING' => '奖励发放还没有开启，暂时不能领取。',
  'COMMUNITY_WEIGHT_PENDING_REVIEW' => '这个社区的挖矿权重还在审核中。',
  // referral
  'REFERRAL_RUNTIME_UNAVAILABLE' => '邀请暂时不可用，稍后再试。',
  'PROFILE_ACTIVATION_REQUIRED' => '需要先完成 LOOP ID 激活，才会有绑定窗口。',
  null => '这一项暂时读不到。',
  _ => '这一项暂时读不到。',
};

/// Decision 0097: `LAUNCH_CONTRACT_BASELINE_PENDING` on a resource the
/// server has not opened for reading yet, said without contradicting the
/// capability document.
///
/// Once the `launch` capability's evidence is `confirmed` the contract is
/// live, so the sentence names the resource that is not readable yet
/// ([whenLive]) instead of claiming the contract is missing. Any other code,
/// or evidence that is not confirmed, keeps [launchReasonCodeText].
String launchBaselineReasonText(
  String? reasonCode, {
  required bool contractLive,
  required String whenLive,
}) => contractLive && reasonCode == 'LAUNCH_CONTRACT_BASELINE_PENDING'
    ? whenLive
    : launchReasonCodeText(reasonCode);

/// The ledger's reason for supply, distribution and ecosystem tax (S91
/// ruling). Once the `launch` evidence is `confirmed` the contract is live,
/// so `LAUNCH_ECONOMY_CONTRACT_PENDING` no longer says to wait for it; before
/// that, and for any other code, [launchReasonCodeText] stands (as 0097).
String launchEconomyReasonText(
  String? reasonCode, {
  required bool contractLive,
}) => contractLive && reasonCode == 'LAUNCH_ECONOMY_CONTRACT_PENDING'
    ? '总量、发行与生态税还没有开放读取，这里只显示 LOOP 能核对的数量。'
    : launchReasonCodeText(reasonCode);

/// Copy for a refused purchase intent (decision 0088).
///
/// A named `reasonCode` wins. A code this build has no sentence for keeps a
/// neutral sentence, and the page shows the code itself in a disclosure
/// ([launchUnexplainedReasonCode]) so the refusal stays reportable without a
/// backend identifier inside the sentence. Without a code the refusal falls
/// back to its kind.
String launchPurchaseRefusalText(LaunchFailureKind? kind, String? reasonCode) {
  if (reasonCode != null) {
    if (launchUnexplainedReasonCode(reasonCode) == null) {
      return launchReasonCodeText(reasonCode);
    }
    return '这次认购没有通过，这个原因还没有对应的说明，没有提交任何交易。'
        '服务端给出的代码在下方「错误代码」里。';
  }
  return launchFailureReason(kind);
}

/// The code itself when this build has no sentence for it, else `null`.
String? launchUnexplainedReasonCode(String? reasonCode) =>
    reasonCode == null ||
        launchReasonCodeText(reasonCode) != launchReasonCodeText(null)
    ? null
    : reasonCode;

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
      LaunchFailureKind.offline ||
      LaunchFailureKind.timedOut => LaunchViewPhase.offline,
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
    this.refreshing = false,
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

  /// A read is in flight over a value this block already holds.
  ///
  /// The page keeps what it read last time and marks it 更新中; it does not
  /// fall back to a skeleton, because replacing readable data with a grey
  /// placeholder loses information the user already had. Only a block with no
  /// value at all loads as a skeleton.
  final bool refreshing;

  bool get isReady => phase == LaunchViewPhase.ready && value != null;

  LaunchResourceState<T> loading() => LaunchResourceState<T>(
    mode: mode,
    phase: value == null ? LaunchViewPhase.loading : LaunchViewPhase.ready,
    value: value,
    busy: busy,
    refreshing: value != null,
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
    refreshing: refreshing,
    failureKind: next ? null : failureKind,
    busy: next,
  );
}
