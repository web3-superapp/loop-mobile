import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';

/// Narrow, feature-facing failure taxonomy shared by the S5 ports
/// (`chain`, `wallet`, `market`, `watchlist`, `alerts`, `notifications`).
///
/// It carries no transport detail: the adapters map the frozen V2 error
/// catalogue onto these kinds, so `lib/features/` never branches on an HTTP
/// status or a `/v2/` literal.
enum LoopChainFailureKind {
  offline,

  /// The request was cancelled in flight. A write may or may not have been
  /// applied, so its idempotency key must survive an identical retry.
  cancelled,

  /// A response the client could not parse. The server may already have
  /// applied a write, so this is an unresolved outcome too.
  outcomeUnknown,

  /// The capability, the provider or the runtime is not assembled.
  unavailable,

  /// The indexer has never run. The list is not empty — it is unknown.
  indexingDelayed,
  permissionDenied,

  /// `403 REGION_BLOCKED`: refused by jurisdiction, not by account. Switching
  /// account or asset cannot change it, so the copy must not suggest either.
  regionBlocked,
  notFound,

  /// The server requires a second verification factor for this command. Step
  /// up is not delivered, so the command can never succeed in this build.
  stepUpRequired,

  /// Optimistic-concurrency rejection: reload and merge before retrying.
  versionConflict,
  bootstrapRequired,
  validationFailed,
  chainMismatch,
  rateLimited,
  idempotencyConflict,

  /// The wallet cannot cover the amount, the maximum fee or the gas reserve.
  insufficientBalance,

  /// The exact payload could not be pre-executed, so it may never be signed.
  simulationFailed,

  /// The 30 s quote is gone. A new quote is required; nothing was submitted.
  quoteExpired,

  /// The operation was already submitted once and its outcome is unresolved.
  /// It is locked: poll it, never resubmit.
  submissionUnknown,
  invalidData,
  unexpected,
}

final class LoopChainException implements Exception {
  const LoopChainException(
    this.kind, {
    this.reasonCode,
    this.exposureUsd,
    this.ceilingUsd,
  });

  final LoopChainFailureKind kind;

  /// The server's own rule name when it named one (`detailsSafe.reasonCode`).
  /// A refusal that carries a rule is explained by that rule, never by a
  /// generic sentence the client invented.
  final String? reasonCode;

  /// The two exact decimal figures a ceiling rule compared. They are present
  /// together or not at all, and only the ceiling rules carry them.
  final String? exposureUsd;
  final String? ceilingUsd;

  bool get hasCeilingFigures => exposureUsd != null && ceilingUsd != null;

  @override
  String toString() => 'LoopChainException(${kind.name})';
}

/// Thrown by a model when a value would break the frozen contract. It never
/// carries the offending value.
final class InvalidLoopChainContractException implements Exception {
  const InvalidLoopChainContractException();

  @override
  String toString() => 'The S5 payload broke the V2 contract.';
}

/// Delivery mode of one port implementation. `preview` is the only mode that
/// may render the visible `演示数据` label.
enum LoopChainGatewayMode { production, preview, unavailable }

/// The `{ "status": "unavailable", "reasonCode": … }` projection.
///
/// A field carrying this object renders an unavailable explanation. It never
/// renders `0`, `—`, a placeholder figure or a fixture.
@immutable
final class LoopUnavailable {
  const LoopUnavailable(this.reasonCode);

  final String reasonCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopUnavailable && other.reasonCode == reasonCode;

  @override
  int get hashCode => reasonCode.hashCode;
}

/// Provenance of one market fact. `source` is an enum on the wire, so an
/// unknown value is an invalid payload rather than a guessed provider.
enum LoopFactSource {
  dexscreener('dexscreener'),
  goplus('goplus'),
  geckoterminal('geckoterminal'),
  loopIndexer('loop_indexer');

  const LoopFactSource(this.wireName);

  final String wireName;

  static LoopFactSource? tryParse(String value) {
    for (final source in values) {
      if (source.wireName == value) return source;
    }
    return null;
  }
}

/// Human label for a provider. It is shown next to every rendered fact.
String loopFactSourceLabel(LoopFactSource source) => switch (source) {
  LoopFactSource.dexscreener => 'DexScreener',
  LoopFactSource.goplus => 'GoPlus',
  LoopFactSource.geckoterminal => 'GeckoTerminal',
  LoopFactSource.loopIndexer => 'LOOP 链上索引',
};

/// How much a rendered number can be trusted right now.
enum LoopFactQuality {
  fresh('fresh'),
  stale('stale'),
  derived('derived'),
  proxied('proxied'),
  unavailable('unavailable');

  const LoopFactQuality(this.wireName);

  final String wireName;

  static LoopFactQuality? tryParse(String value) {
    for (final quality in values) {
      if (quality.wireName == value) return quality;
    }
    return null;
  }
}

/// The single fixed shape of every market number.
///
/// [value] is `null` exactly when [quality] is `unavailable`; the UI then
/// renders the [reasonCode] explanation instead of a figure.
@immutable
final class LoopFact {
  const LoopFact({
    required this.value,
    required this.source,
    required this.fetchedAt,
    required this.ttlSeconds,
    required this.quality,
    required this.reasonCode,
  });

  const LoopFact.unavailable(this.reasonCode)
    : value = null,
      source = null,
      fetchedAt = null,
      ttlSeconds = null,
      quality = LoopFactQuality.unavailable;

  final Decimal? value;
  final LoopFactSource? source;
  final DateTime? fetchedAt;
  final int? ttlSeconds;
  final LoopFactQuality quality;
  final String? reasonCode;

  bool get isAvailable =>
      value != null && quality != LoopFactQuality.unavailable;

  /// True when the figure may be shown but must carry a warning marker.
  bool get needsMarker =>
      quality == LoopFactQuality.stale ||
      quality == LoopFactQuality.derived ||
      quality == LoopFactQuality.proxied;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopFact &&
          other.value == value &&
          other.source == source &&
          other.fetchedAt == fetchedAt &&
          other.ttlSeconds == ttlSeconds &&
          other.quality == quality &&
          other.reasonCode == reasonCode;

  @override
  int get hashCode =>
      Object.hash(value, source, fetchedAt, ttlSeconds, quality, reasonCode);
}

/// zh-CN marker for a fact's quality. `fresh` needs no marker.
String? loopFactQualityMarker(LoopFactQuality quality) => switch (quality) {
  LoopFactQuality.fresh => null,
  LoopFactQuality.stale => '数据可能过期',
  LoopFactQuality.derived => '按成交价折算',
  LoopFactQuality.proxied => '以 WBNB 计价',
  LoopFactQuality.unavailable => null,
};

/// zh-CN copy for a failed S5 operation. It states what did not happen; it
/// never claims a result the server did not confirm.
String loopChainFailureReason(LoopChainFailureKind? kind) => switch (kind) {
  LoopChainFailureKind.offline => '设备已离线，这一页没有读到数据，也没有提交任何操作。',
  LoopChainFailureKind.cancelled => '请求已被取消，结果未知。请查看最新状态后再决定是否重试。',
  LoopChainFailureKind.outcomeUnknown => '返回的数据不完整，结果未确认。请刷新查看最新状态，不要重复提交。',
  LoopChainFailureKind.unavailable => '需要的链上数据暂时读不到，没有执行任何操作。',
  LoopChainFailureKind.indexingDelayed => '链上记录还在同步，这里是暂时读不到，不是没有记录。',
  LoopChainFailureKind.permissionDenied => '当前账号没有执行这个操作的权限。',
  LoopChainFailureKind.regionBlocked =>
    '你所在的地区暂时不支持这个操作，没有发生任何变化。'
        '这与账号或资产无关，换一个也不会改变结果。',
  LoopChainFailureKind.stepUpRequired => '这一步需要二次验证，二次验证还没有开放，没有发生任何变化。',
  LoopChainFailureKind.notFound => '目标不存在、未登记，或对当前账号不可见。',
  LoopChainFailureKind.versionConflict => '数据已被其他设备修改。请重新加载后再提交，本次没有覆盖任何内容。',
  LoopChainFailureKind.bootstrapRequired => '账号尚未完成初始化，请稍后重试。',
  LoopChainFailureKind.validationFailed => '输入内容不符合要求（例如资产未登记或阈值非法），请修改后重试。',
  LoopChainFailureKind.chainMismatch =>
    '这条链现在不支持：钱包、行情、兑换与授权都在 BNB Smart Chain 上，'
        'Launch 在 LOOP 发布的 Launch 链上。',
  LoopChainFailureKind.rateLimited => '请求过于频繁，请稍等片刻再试。',
  LoopChainFailureKind.idempotencyConflict => '同一操作已被提交过且内容不同，请检查最新状态后再试。',
  LoopChainFailureKind.insufficientBalance =>
    '余额不足以覆盖这笔金额、最高网络费或手续费保留，没有提交任何交易。',
  LoopChainFailureKind.simulationFailed => '这笔交易试算没有通过，不能签名。请返回确认页重新准备一次。',
  LoopChainFailureKind.quoteExpired => '报价已过期，没有提交任何兑换。请重新报价后再确认。',
  LoopChainFailureKind.submissionUnknown =>
    '这笔操作已经提交过一次且结果未知，已锁定。请只查看最新状态，不要重复提交。',
  LoopChainFailureKind.invalidData => '返回的数据不完整，这一页没有采用任何内容。',
  LoopChainFailureKind.unexpected => '操作没有完成，请稍后再试。',
  null => '操作没有完成。',
};

/// Whether a write's outcome is unknown, so its idempotency key must be
/// replayed rather than replaced.
bool loopChainOutcomeIsUnresolved(LoopChainFailureKind kind) =>
    kind == LoopChainFailureKind.offline ||
    kind == LoopChainFailureKind.cancelled ||
    kind == LoopChainFailureKind.outcomeUnknown ||
    kind == LoopChainFailureKind.submissionUnknown;

/// zh-CN explanation for one server `reasonCode`.
///
/// An unknown code keeps a neutral sentence rather than inventing a cause.
String loopReasonCodeText(String? reasonCode) => switch (reasonCode) {
  // chain / RPC
  'BSC_RPC_NOT_CONFIGURED' => '链上数据暂时读不到。',
  'BSC_CHAIN_RUNTIME_UNAVAILABLE' => '链上数据暂时不可用，稍后再试。',
  'BSC_CHAIN_VERIFICATION_PENDING' => '正在校验链上连接，暂时不显示链上数字。',
  'BSC_RPC_UNREACHABLE' => '链上节点当前连不上。',
  'BSC_CHAIN_ID_MISMATCH' => '连接到的不是 BNB Smart Chain，这一页不可用。',
  // launch chain slot (decision 0038) — only ever about the testnet slot
  'LAUNCH_CHAIN_RPC_NOT_CONFIGURED' => 'Launch 运行在 BSC 测试网，测试网数据暂时读不到。',
  'LAUNCH_CHAIN_VERIFICATION_PENDING' => '正在校验测试网连接，暂时不显示测试网数字。',
  'LAUNCH_CHAIN_RPC_UNREACHABLE' => '测试网节点当前连不上。',
  'LAUNCH_CHAIN_ID_MISMATCH' => '连接到的不是 BSC 测试网，Launch 相关内容不可用。',
  'BSC_BALANCE_CALL_FAILED' => '这次余额没有读到，因此不显示数字。',
  'BSC_INDEXER_NOT_STARTED' => '转账记录暂时读不到。',
  'BSC_POOL_INDEXER_NOT_STARTED' => '成交与 K 线暂时读不到。',
  'NATIVE_TRANSFER_SCAN_NOT_SUPPORTED' => 'BNB 转账记录暂时读不到。',
  'CROSS_CHAIN_ACTIVITY_NOT_SUPPORTED' => '跨链与挖矿领取记录暂时读不到。',
  'PRIVY_ASSET_MAPPING_UNAVAILABLE' => '这个资产无法与钱包记录核对。',
  'PRIVY_WALLET_ID_UNAVAILABLE' => '外部钱包无法与钱包记录核对。',
  'PRIVY_BALANCE_CROSS_CHECK_FAILED' => '余额核对没有成功，链上数字不受影响。',
  // asset capability
  'SWAP_MODULE_NOT_DELIVERED' => '兑换还没有开放，这一页没有买卖入口。',
  'ASSET_NOT_READABLE' => '这个资产已经读不到，保留这一行方便你移除。',
  'ASSET_BLOCKED' => '这个资产已被屏蔽。',
  // market providers
  'MARKET_RUNTIME_UNAVAILABLE' => '行情暂时不可用，稍后再试。',
  'MARKET_PRICE_PROVIDER_NOT_CONFIGURED' => '暂时读不到价格，不显示估值。',
  'MARKET_PROVIDER_DEXSCREENER_DISABLED' => 'DexScreener 数据当前已关闭。',
  'MARKET_PROVIDER_GOPLUS_NOT_CONFIGURED' => '安全信息与持有人数暂时读不到。',
  'MARKET_PROVIDER_GECKOTERMINAL_DISABLED' => '新币发现与相关行情暂时读不到。',
  'MARKET_PROVIDER_RATE_LIMITED' => '数据服务限流中，暂时没有新数值。',
  'MARKET_PROVIDER_UNREACHABLE' => '网络失败或超时。',
  'MARKET_PROVIDER_RESPONSE_MALFORMED' => '返回的数据不完整，已整体丢弃。',
  'MARKET_PAIR_NOT_FOUND' => '没有找到这个资产的交易对。',
  'MARKET_FACT_NOT_REPORTED' => '这一项没有数值。',
  'MARKET_NATIVE_ASSET_NOT_SUPPORTED' => '原生 BNB 没有合约地址，这一项不适用。',
  'MARKET_POOL_NOT_REGISTERED' => '这个资产还没有 PancakeSwap V3 交易池。',
  'MARKET_NO_SWAPS_IN_RANGE' => '所选区间内没有成交。',
  'BALANCE_UNAVAILABLE' => '这一行余额读不到，无法估值。',
  // deferred product areas
  'HOLDER_DISTRIBUTION_NOT_SUPPORTED' => '持有人分布暂时读不到。',
  'SMART_MONEY_RUNTIME_DEFERRED' => '聪明钱追踪还没有开放。',
  'PUSH_RUNTIME_DEFERRED' => '推送还没有开放，提醒只出现在应用内的通知列表里。',
  'COMMUNITY_NOT_BOUND' => '还没有社区绑定这个资产。',
  'MINING_RUNTIME_DEFERRED' => '挖矿数据还没有开放。',
  'MARKET_CHART_TOOLS_DEFERRED' => '指标与画线工具还没有开放。',
  'WALLET_NETWORTH_TREND_DEFERRED' => '净值走势与 24h 涨跌暂时读不到。',
  'WALLET_CUSTOM_RPC_DEFERRED' => '自定义网络还没有开放，这里只显示 LOOP 支持的网络。',
  'WALLET_SECURITY_FACTS_DEFERRED' => '安全中心与 DApp 状态还没有开放。',
  // S6 · money actions (write switch, canary, intent lifecycle)
  'WALLET_INTENT_RUNTIME_UNAVAILABLE' => '资金操作暂时不可用，稍后再试。',
  'BSC_WRITES_DISABLED' => '链上操作当前已关闭，现在只能查看。',
  'PRIVY_NOT_CONFIGURED' => '兑换暂时不可用，稍后再试。',
  'PRIVY_BSC_SWAP_DEVICE_EVIDENCE_PENDING' => '兑换还在验证中，可以查看报价，但不能执行。',
  'SWAP_SIMULATION_PROVIDER_PENDING' => '兑换暂时无法试算，因此不能执行。',
  'GOPLUS_ADDRESS_SCREENING_NOT_CONFIGURED' => '暂时无法核对这个地址是否在已知诈骗名单里。这不代表它安全。',
  'GOPLUS_APPROVAL_FACTS_NOT_CONFIGURED' => '授权风险信息暂时读不到。',
  'ALLOWANCE_READ_FAILED' => '这一行的授权额度读不到，因此不显示数字。',
  'BSC_CALL_REVERTED' => '这笔交易试算时被链上拒绝，不能签名。',
  'SIMULATION_UNAVAILABLE' => '试算没有返回可核对的结果，不能签名。',
  'GAS_ESTIMATE_UNAVAILABLE' => '无法估算网络费，因此不能构造可签名的交易。',
  'INTENT_EXPIRED' => '这次操作已过期，请重新准备一次。',
  'INTENT_SUPERSEDED' => '这个钱包已经准备了新的操作，这一笔被取代，没有提交。',
  'USER_CANCELLED' => '这次操作已由你取消，没有提交任何交易。',
  'TX_PENDING_VERIFICATION' => '交易已提交，链上还没有查到，LOOP 会继续核对。',
  'TX_PAYLOAD_MISMATCH' => '提交的交易与准备好的内容不一致，已拒绝。',
  'TX_REVERTED' => '交易已上链但执行失败，网络费已消耗。',
  'RECEIPT_LOST' => '交易回执暂时读不到，结果待确认。',
  'PRIVY_SWAP_REJECTED' => '钱包拒绝了这次兑换，没有提交到链上。',
  'PROVIDER_RESULT_AMBIGUOUS' => '这次操作的结果还不确定，请等待确认，不要重复提交。',
  'PRICE_IMPACT_ABOVE_HARD_LIMIT' => '价格影响超过 5%，已阻止这笔兑换。',
  'PRICE_IMPACT_UNAVAILABLE' => '无法计算这笔兑换的价格影响，已阻止。',
  'SIGNING_PAYLOAD_UNAVAILABLE' => '这笔操作暂时无法进入钱包签名。',
  'INTENT_CHAIN_NOT_PERMITTED' => '这条链不支持这个操作：发送、授权、回收与兑换只能在主网进行。',
  // D20 security / settings / support (decision 0037)
  'V2_SECURITY_RUNTIME_DEFERRED' => '安全设置还没有开放。',
  'SECURITY_RUNTIME_UNAVAILABLE' => '安全设置暂时不可用，稍后再试。',
  'V2_SETTINGS_RUNTIME_DEFERRED' => '账号设置还没有开放。',
  'SETTINGS_RUNTIME_UNAVAILABLE' => '设置暂时不可用，稍后再试。',
  'V2_SUPPORT_RUNTIME_DEFERRED' => '客服还没有开放。',
  'SUPPORT_RUNTIME_UNAVAILABLE' => '客服暂时不可用，稍后再试。',
  'ACCOUNT_SESSION_RUNTIME_UNAVAILABLE' => '设备列表暂时读不到。',
  'NOTIFICATIONS_RUNTIME_UNAVAILABLE' => '最近的安全事件暂时读不到。',
  'AUTH_STEP_UP_REQUIRED' => '需要二次验证，二次验证还没有开放。',
  'SUPPORT_ATTACHMENTS_UNAVAILABLE' => '工单暂时不能上传附件。',
  'TERMS_POLICY_UNAVAILABLE' => '法律文件链接暂时打不开。',
  'POLICY_NOT_YET_EFFECTIVE' => '新版协议还没有生效。',
  'CLIENT_BUILD_IS_DEVICE_LOCAL' => '版本与构建号来自这台设备。',
  'WALLET_NOT_SELECTED' => '还没有选择钱包。',
  'WALLET_RUNTIME_UNAVAILABLE' => '授权列表暂时读不到。',
  'SEND_APPROVALS_RUNTIME_DEFERRED' => '授权列表还没有开放。',
  'INDEXING_DELAYED' => '链上记录还在同步，授权列表暂时读不到。',
  'CAPABILITY_UNAVAILABLE' => '这个功能当前不可用。',
  // Privy security methods: six permanently pending evidence items (§5.2)
  'PRIVY_MFA_EVIDENCE_PENDING' => '多因素验证还没有开放。',
  'PRIVY_PASSKEY_EVIDENCE_PENDING' => 'Passkey 还没有开放。',
  'PRIVY_RECOVERY_PASSWORD_EVIDENCE_PENDING' => '恢复密码还没有开放。',
  'PRIVY_AUTO_RECOVERY_EVIDENCE_PENDING' => '自动恢复还没有开放。',
  'PRIVY_SOCIAL_RECOVERY_EVIDENCE_PENDING' => '社交恢复还没有开放。',
  'PRIVY_KEY_EXPORT_EVIDENCE_PENDING' => '私钥导出还没有开放。',
  // D21 surfaces that exist as entry points only
  'PAY_RUNTIME_DEFERRED' => '扫码支付还没有开放，这里不会打开相机或生成收款码。',
  'BRIDGE_RUNTIME_DEFERRED' => '跨链还没有开放，这里不会发起任何跨链操作。',
  'DAPP_EXECUTION_RUNTIME_DEFERRED' => 'DApp 连接与签名还没有开放，这一页只做本地检查。',
  'COMMUNITY_AI_RUNTIME_DEFERRED' => 'Community AI 还没有开放。',
  null => '这一项暂时读不到。',
  _ => '这一项暂时读不到。',
};

/// The badge every Launch surface and every sign sheet shows while the Launch
/// chain slot is the BSC testnet. It is a statement of fact, never a blocker.
const String loopTestnetBadgeLabel = 'BSC 测试网';

/// Title of the one-time explanation that accompanies the badge.
const String loopTestnetNoticeTitle = 'Launch 当前运行在 BSC 测试网';

/// The one-time explanation. It never says anything is broken: the Launch
/// module points at `eip155:97` on purpose, and everything else stays on the
/// main chain.
const String loopTestnetNoticeBody =
    'Launch 目录、详情与签名单当前指向 BSC 测试网（$loopLaunchTestnetChainId），'
    '测试网上的代币没有真实价值。钱包余额、行情、兑换与授权仍然只走 BNB Smart Chain 主网，'
    '不受影响。这条说明可以关闭，不会阻断任何操作。';

/// The reviewed page states for an S5 surface.
enum LoopChainViewPhase {
  loading,
  ready,
  empty,
  error,
  offline,
  unavailable,
  permission,
}

LoopChainViewPhase loopChainPhaseForFailure(LoopChainFailureKind? kind) =>
    switch (kind) {
      LoopChainFailureKind.offline => LoopChainViewPhase.offline,
      LoopChainFailureKind.unavailable ||
      LoopChainFailureKind.indexingDelayed => LoopChainViewPhase.unavailable,
      LoopChainFailureKind.permissionDenied ||
      LoopChainFailureKind.regionBlocked ||
      LoopChainFailureKind.stepUpRequired => LoopChainViewPhase.permission,
      null => LoopChainViewPhase.empty,
      _ => LoopChainViewPhase.error,
    };

/// One loaded resource plus the honest phase for the block that renders it.
///
/// Every S5 page composes several of these so a failing block never blanks a
/// block that did load.
@immutable
final class LoopChainResourceState<T> {
  const LoopChainResourceState({
    required this.mode,
    required this.phase,
    this.value,
    this.failureKind,
    this.busy = false,
    this.refreshing = false,
  });

  factory LoopChainResourceState.initial(LoopChainGatewayMode mode) {
    final closed = mode == LoopChainGatewayMode.unavailable;
    return LoopChainResourceState<T>(
      mode: mode,
      phase: closed
          ? LoopChainViewPhase.unavailable
          : LoopChainViewPhase.loading,
      failureKind: closed ? LoopChainFailureKind.unavailable : null,
    );
  }

  final LoopChainGatewayMode mode;
  final LoopChainViewPhase phase;
  final T? value;
  final LoopChainFailureKind? failureKind;

  /// A write is in flight. The page keeps rendering the last server truth and
  /// only disables its actions.
  final bool busy;

  /// A read is in flight over a value this block already holds.
  ///
  /// The page keeps showing what it read last time and marks it 更新中; it does
  /// not fall back to a skeleton, because replacing readable data with a grey
  /// placeholder loses information the user already had. Only a block with no
  /// value at all loads as a skeleton.
  final bool refreshing;

  bool get isPreview => mode == LoopChainGatewayMode.preview;

  bool get isReady => phase == LoopChainViewPhase.ready && value != null;

  LoopChainResourceState<T> loading() => LoopChainResourceState<T>(
    mode: mode,
    phase: value == null
        ? LoopChainViewPhase.loading
        : LoopChainViewPhase.ready,
    value: value,
    busy: busy,
    refreshing: value != null,
  );

  LoopChainResourceState<T> ready(T next) => LoopChainResourceState<T>(
    mode: mode,
    phase: LoopChainViewPhase.ready,
    value: next,
  );

  LoopChainResourceState<T> failed(LoopChainFailureKind kind) =>
      LoopChainResourceState<T>(
        mode: mode,
        phase: value == null
            ? loopChainPhaseForFailure(kind)
            : LoopChainViewPhase.ready,
        value: value,
        failureKind: kind,
      );

  LoopChainResourceState<T> working(bool next) => LoopChainResourceState<T>(
    mode: mode,
    phase: phase,
    value: value,
    failureKind: next ? null : failureKind,
    busy: next,
    refreshing: refreshing,
  );
}
