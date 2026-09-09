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
  LoopFactQuality.derived => '链上成交聚合',
  LoopFactQuality.proxied => '以 WBNB 计价',
  LoopFactQuality.unavailable => null,
};

/// zh-CN copy for a failed S5 operation. It states what did not happen; it
/// never claims a result the server did not confirm.
String loopChainFailureReason(LoopChainFailureKind? kind) => switch (kind) {
  LoopChainFailureKind.offline => '设备当前离线，本页没有读到任何服务端数据，也没有提交任何操作。',
  LoopChainFailureKind.cancelled => '请求已被取消，结果未知。请查看最新状态后再决定是否重试。',
  LoopChainFailureKind.outcomeUnknown => '服务返回的数据不符合约定，结果未确认。请刷新查看最新状态，不要重复提交。',
  LoopChainFailureKind.unavailable => '所需的链上或行情来源当前不可用，没有执行任何操作，也没有回退到演示数据。',
  LoopChainFailureKind.indexingDelayed =>
    '链上索引尚未运行或未追上最新区块，这里不是"没有记录"，而是暂时读不到。',
  LoopChainFailureKind.permissionDenied => '当前账号无权执行此操作，服务端已拒绝。',
  LoopChainFailureKind.regionBlocked =>
    '服务端按当前地区规则拒绝了这次请求，没有发生任何变化。'
        '这与账号或资产无关，换一个也不会改变结果。',
  LoopChainFailureKind.stepUpRequired => '这一步需要二次验证。二次验证尚未开放，服务端已拒绝，没有发生任何变化。',
  LoopChainFailureKind.notFound => '目标不存在、未登记，或对当前账号不可见。',
  LoopChainFailureKind.versionConflict => '数据已被其他设备修改。请重新加载后再提交，本次没有覆盖任何内容。',
  LoopChainFailureKind.bootstrapRequired => '账号尚未完成初始化，请稍后重试。',
  LoopChainFailureKind.validationFailed => '输入内容不符合要求（例如资产未登记或阈值非法），请修改后重试。',
  LoopChainFailureKind.chainMismatch =>
    '该链不在本步支持的范围内：钱包、行情、Swap 与授权只走主链 BNB Smart Chain，'
        'Launch 只走后端发布的 launch 链。',
  LoopChainFailureKind.rateLimited => '请求过于频繁，请稍等片刻再试。',
  LoopChainFailureKind.idempotencyConflict => '同一操作已被提交过且内容不同，请检查最新状态后再试。',
  LoopChainFailureKind.insufficientBalance =>
    '余额不足以覆盖这笔金额、最高网络费或手续费保留，没有提交任何交易。',
  LoopChainFailureKind.simulationFailed => '这笔交易的预执行没有通过，因此不能签名。请返回确认页重新准备一次。',
  LoopChainFailureKind.quoteExpired => '报价已过期，没有提交任何兑换。请重新报价后再确认。',
  LoopChainFailureKind.submissionUnknown =>
    '这笔操作已经提交过一次且结果未知，已锁定。请只查看最新状态，不要重复提交。',
  LoopChainFailureKind.invalidData => '服务返回的数据不符合约定，本页没有采纳任何内容。',
  LoopChainFailureKind.unexpected => '操作没有完成，未暴露供应商细节。',
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
  'BSC_RPC_NOT_CONFIGURED' => '后端没有配置任何 BSC RPC 端点，链上事实全部不可读。',
  'BSC_CHAIN_RUNTIME_UNAVAILABLE' => '端点已配置，但服务端的链上依赖尚未组装完成。',
  'BSC_CHAIN_VERIFICATION_PENDING' => '端点已配置，chainId 校验尚未完成，暂不展示链上数字。',
  'BSC_RPC_UNREACHABLE' => 'RPC 端点当前不可达。',
  'BSC_CHAIN_ID_MISMATCH' => '端点返回的不是 BNB Smart Chain（chainId 56），整页不可用。',
  // launch chain slot (decision 0038) — only ever about the testnet slot
  'LAUNCH_CHAIN_RPC_NOT_CONFIGURED' =>
    '后端把 Launch 指向了 BSC 测试网，但没有配置测试网 RPC，测试网读数不可得。',
  'LAUNCH_CHAIN_VERIFICATION_PENDING' => '测试网端点已配置，chainId 校验尚未完成，暂不展示测试网数字。',
  'LAUNCH_CHAIN_RPC_UNREACHABLE' => '测试网 RPC 端点当前不可达。',
  'LAUNCH_CHAIN_ID_MISMATCH' =>
    '端点返回的不是 BSC 测试网（chainId 97），Launch 链相关内容整块不可用。',
  'BSC_BALANCE_CALL_FAILED' => '链已校验，但这次余额读取本身失败了，因此不显示数字，也不显示 0。',
  'BSC_INDEXER_NOT_STARTED' => '转账索引尚未运行，待确认金额与活动记录暂时读不到。',
  'BSC_POOL_INDEXER_NOT_STARTED' => '池事件索引尚未运行，成交与派生 K 线暂时读不到。',
  'NATIVE_TRANSFER_SCAN_NOT_SUPPORTED' => '原生 BNB 转账历史本步没有来源，不展示空列表。',
  'CROSS_CHAIN_ACTIVITY_NOT_SUPPORTED' => '跨链与挖矿领取记录本步没有来源。',
  'PRIVY_ASSET_MAPPING_UNAVAILABLE' => '该资产无法与 Privy 的口径对齐，交叉核对不可用。',
  'PRIVY_WALLET_ID_UNAVAILABLE' => '外部钱包没有 Privy 钱包 ID，交叉核对不可用。',
  'PRIVY_BALANCE_CROSS_CHECK_FAILED' => '与 Privy 的余额交叉核对失败，链上读数不受影响。',
  // asset capability
  'SWAP_MODULE_NOT_DELIVERED' => 'Swap 尚未交付，本页不渲染任何买卖入口。',
  'ASSET_NOT_READABLE' => '该资产已不可读，只保留这一行以便你把它移除。',
  'ASSET_BLOCKED' => '该资产已被登记为 blocked，不展示任何事实。',
  // market providers
  'MARKET_RUNTIME_UNAVAILABLE' => '行情模块已启用，但服务端依赖尚未配齐。',
  'MARKET_PRICE_PROVIDER_NOT_CONFIGURED' => '价格来源尚未配置，不展示估值。',
  'MARKET_PROVIDER_DEXSCREENER_DISABLED' => '后端关闭了 DexScreener 来源。',
  'MARKET_PROVIDER_GOPLUS_NOT_CONFIGURED' => '未配置 GoPlus 密钥，安全事实与持有人数没有来源。',
  'MARKET_PROVIDER_GECKOTERMINAL_DISABLED' =>
    'GeckoTerminal 未启用，新币发现与其 OHLCV 没有来源。',
  'MARKET_PROVIDER_RATE_LIMITED' => '来源被限速，暂时没有新的观测值。',
  'MARKET_PROVIDER_UNREACHABLE' => '来源网络失败或超时。',
  'MARKET_PROVIDER_RESPONSE_MALFORMED' => '来源响应不符合约定，已整体拒绝。',
  'MARKET_PAIR_NOT_FOUND' => '没有以该资产为 base 的交易对。',
  'MARKET_FACT_NOT_REPORTED' => '来源返回了交易对，但没有报告这个字段。',
  'MARKET_NATIVE_ASSET_NOT_SUPPORTED' => '原生 BNB 没有合约地址，这一项没有来源。',
  'MARKET_POOL_NOT_REGISTERED' => '该资产没有已登记的 PancakeSwap V3 池。',
  'MARKET_NO_SWAPS_IN_RANGE' => '所选区间内没有成交。',
  'BALANCE_UNAVAILABLE' => '这一行的链上余额读不到，因此无法估值。',
  // deferred product areas
  'HOLDER_DISTRIBUTION_NOT_SUPPORTED' => '持有人分布需要全量历史，本步没有来源。',
  'SMART_MONEY_RUNTIME_DEFERRED' => '聪明钱追踪尚未交付，不展示任何地址或胜率。',
  'PUSH_RUNTIME_DEFERRED' => '推送通道尚未接入，提醒只会出现在应用内的通知列表。',
  'COMMUNITY_NOT_BOUND' => '还没有已验证的 LOOP 社区绑定该资产。',
  'MINING_RUNTIME_DEFERRED' => '挖矿数据尚未交付，不展示任何算力或收益数字。',
  'MARKET_CHART_TOOLS_DEFERRED' => '指标与画线工具没有服务端来源，本步不提供。',
  'WALLET_NETWORTH_TREND_DEFERRED' => '净值走势与 24h 涨跌没有后端来源，本步不展示。',
  'WALLET_CUSTOM_RPC_DEFERRED' => '自定义 RPC 与自行添加网络本步不开放；这里只显示服务端发布的网络。',
  'WALLET_SECURITY_FACTS_DEFERRED' => '安全中心与 DApp 状态尚未接入，不展示任何数量。',
  // S6 · money actions (write switch, canary, intent lifecycle)
  'WALLET_INTENT_RUNTIME_UNAVAILABLE' => '资金动作模块已启用，但服务端的 intent 运行时尚未组装完成。',
  'BSC_WRITES_DISABLED' => '链上写入开关当前关闭，本步只能查看，不能签名或广播。',
  'PRIVY_NOT_CONFIGURED' => 'Privy 凭据尚未配置，兑换报价与执行都不可用。',
  'PRIVY_BSC_SWAP_DEVICE_EVIDENCE_PENDING' =>
    'Privy BSC 兑换尚未取得真机证据，可以报价与查看，但不能确认执行。',
  'SWAP_SIMULATION_PROVIDER_PENDING' =>
    '兑换没有可用的预执行来源，本步不可执行；接入 Provider 模拟后才会开放。',
  'GOPLUS_ADDRESS_SCREENING_NOT_CONFIGURED' =>
    '未配置 GoPlus 密钥，无法查询该地址是否命中已知诈骗地址库。这不是"安全"，是没有结论。',
  'GOPLUS_APPROVAL_FACTS_NOT_CONFIGURED' => '未配置 GoPlus 密钥，授权风险事实没有来源。',
  'ALLOWANCE_READ_FAILED' => '这一行的 allowance 读不到，因此不显示额度，也不显示 0。',
  'BSC_CALL_REVERTED' => '按这份精确 payload 预执行时被链上拒绝，因此不能签名。',
  'SIMULATION_UNAVAILABLE' => '预执行没有返回可验证结果，因此不能签名。',
  'GAS_ESTIMATE_UNAVAILABLE' => '无法估算 gas，因此不能构造可签名的交易。',
  'INTENT_EXPIRED' => '这次操作的事实已过期，需要重新准备一次。',
  'INTENT_SUPERSEDED' => '同一钱包已经准备了新的操作，这一笔被取代，未提交。',
  'USER_CANCELLED' => '这次操作已由你取消，没有提交任何交易。',
  'TX_PENDING_VERIFICATION' => '哈希已上报，节点尚未看到这笔交易，服务端会继续对账。',
  'TX_PAYLOAD_MISMATCH' => '上报的交易与本次准备的 payload 不一致，已拒绝并记录审计事件。',
  'TX_REVERTED' => '链上回执为 reverted：交易已上链但执行失败，网络费已消耗。',
  'RECEIPT_LOST' => '曾经读到过回执，现在读不到了，结果重新变为未知，等待对账。',
  'PRIVY_SWAP_REJECTED' => 'Privy 明确拒绝了这次兑换，没有提交到链上。',
  'PROVIDER_RESULT_AMBIGUOUS' => '供应商没有返回可判定的结果，本次已锁定，只能等待对账，不重发。',
  'PRICE_IMPACT_ABOVE_HARD_LIMIT' => '价格影响超过 5%，按策略硬阻断。',
  'PRICE_IMPACT_UNAVAILABLE' => '无法为这笔兑换定价，因此无法判断价格影响，按阻断处理。',
  'SIGNING_PAYLOAD_UNAVAILABLE' => '服务端没有下发可签名的 payload，本次不能进入钱包。',
  'INTENT_CHAIN_NOT_PERMITTED' => '这笔操作的链不在允许范围内：发送、授权、回收与兑换只能在主网签名，本次没有进入钱包。',
  // D20 security / settings / support (decision 0037)
  'V2_SECURITY_RUNTIME_DEFERRED' => '安全模块尚未启用，设备与安全事件都读不到。',
  'SECURITY_RUNTIME_UNAVAILABLE' => '安全模块已启用，但服务端依赖尚未组装完成。',
  'V2_SETTINGS_RUNTIME_DEFERRED' => '设置模块尚未启用，账号级设置读不到。',
  'SETTINGS_RUNTIME_UNAVAILABLE' => '设置模块已启用，但服务端依赖尚未组装完成。',
  'V2_SUPPORT_RUNTIME_DEFERRED' => '客服模块尚未启用，工单无法提交也无法读取。',
  'SUPPORT_RUNTIME_UNAVAILABLE' => '客服模块已启用，但服务端依赖尚未组装完成。',
  'ACCOUNT_SESSION_RUNTIME_UNAVAILABLE' => '会话仓库尚未组装，设备列表读不到。',
  'NOTIFICATIONS_RUNTIME_UNAVAILABLE' => '通知模块尚未组装，最近安全事件读不到。',
  'AUTH_STEP_UP_REQUIRED' => '需要二次验证。二次验证尚未开放，这个动作无法执行。',
  'SUPPORT_ATTACHMENTS_UNAVAILABLE' => '工单附件没有存储通道，本步不开放上传。',
  'TERMS_POLICY_UNAVAILABLE' => '协议版本尚未下发，法律文件链接本步不可用。',
  'POLICY_NOT_YET_EFFECTIVE' => '新的协议版本尚未生效，这里只保留版本槽位。',
  'CLIENT_BUILD_IS_DEVICE_LOCAL' => '版本与构建号由本机读取，服务端不下发也不比较。',
  'WALLET_NOT_SELECTED' => '尚未选中钱包，授权盘点没有可统计的对象。',
  'WALLET_RUNTIME_UNAVAILABLE' => '钱包模块尚未组装，授权盘点读不到。',
  'SEND_APPROVALS_RUNTIME_DEFERRED' => '授权盘点尚未交付，不展示任何授权数量。',
  'INDEXING_DELAYED' => '链上索引尚未追上最新区块，授权盘点暂时读不到。',
  'CAPABILITY_UNAVAILABLE' => '所需能力当前不可用，服务端已明确拒绝。',
  // Privy security methods: six permanently pending evidence items (§5.2)
  'PRIVY_MFA_EVIDENCE_PENDING' => 'Privy 的多因素验证还缺少方案、平台与真机证据，本步不开放。',
  'PRIVY_PASSKEY_EVIDENCE_PENDING' => 'Privy 的 Passkey 还缺少方案、平台与真机证据，本步不开放。',
  'PRIVY_RECOVERY_PASSWORD_EVIDENCE_PENDING' =>
    'Privy 的恢复密码还缺少方案、平台与真机证据，本步不开放。',
  'PRIVY_AUTO_RECOVERY_EVIDENCE_PENDING' => 'Privy 的自动恢复还缺少方案、平台与真机证据，本步不开放。',
  'PRIVY_SOCIAL_RECOVERY_EVIDENCE_PENDING' => 'Privy 的社交恢复还缺少方案、平台与真机证据，本步不开放。',
  'PRIVY_KEY_EXPORT_EVIDENCE_PENDING' => 'Privy 的私钥导出还缺少方案、平台与真机证据，本步不开放。',
  // D21 surfaces that exist as entry points only
  'PAY_RUNTIME_DEFERRED' => '扫码支付涉及合规与支付商准入，本步只保留入口，不启用相机与收款码。',
  'BRIDGE_RUNTIME_DEFERRED' => '跨链路由尚未接入，本步不产生任何跨链请求，也没有进度来源。',
  'DAPP_EXECUTION_RUNTIME_DEFERRED' => 'DApp 连接与签名尚未接入，本页只做本地只读核对。',
  'COMMUNITY_AI_RUNTIME_DEFERRED' => 'Community AI 尚未交付，不展示任何示例回答或统计数字。',
  null => '该字段当前没有可信来源。',
  _ => '该字段当前没有可信来源。',
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

  bool get isPreview => mode == LoopChainGatewayMode.preview;

  bool get isReady => phase == LoopChainViewPhase.ready && value != null;

  LoopChainResourceState<T> loading() => LoopChainResourceState<T>(
    mode: mode,
    phase: value == null
        ? LoopChainViewPhase.loading
        : LoopChainViewPhase.ready,
    value: value,
    busy: busy,
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
  );
}
