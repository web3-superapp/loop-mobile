import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

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
  notFound,

  /// Optimistic-concurrency rejection: reload and merge before retrying.
  versionConflict,
  bootstrapRequired,
  validationFailed,
  chainMismatch,
  rateLimited,
  idempotencyConflict,
  invalidData,
  unexpected,
}

final class LoopChainException implements Exception {
  const LoopChainException(this.kind);

  final LoopChainFailureKind kind;

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

/// The em dash used only where a figure is structurally absent. A missing
/// *source* is never an em dash: it is an unavailable explanation.
const String loopMissingFigure = '—';

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
  LoopChainFailureKind.notFound => '目标不存在、未登记，或对当前账号不可见。',
  LoopChainFailureKind.versionConflict => '数据已被其他设备修改。请重新加载后再提交，本次没有覆盖任何内容。',
  LoopChainFailureKind.bootstrapRequired => '账号尚未完成初始化，请稍后重试。',
  LoopChainFailureKind.validationFailed => '输入内容不符合要求（例如资产未登记或阈值非法），请修改后重试。',
  LoopChainFailureKind.chainMismatch =>
    '该资产不属于 BNB Smart Chain，本步只支持 eip155:56。',
  LoopChainFailureKind.rateLimited => '请求过于频繁，请稍等片刻再试。',
  LoopChainFailureKind.idempotencyConflict => '同一操作已被提交过且内容不同，请检查最新状态后再试。',
  LoopChainFailureKind.invalidData => '服务返回的数据不符合约定，本页没有采纳任何内容。',
  LoopChainFailureKind.unexpected => '操作没有完成，未暴露供应商细节。',
  null => '操作没有完成。',
};

/// Whether a write's outcome is unknown, so its idempotency key must be
/// replayed rather than replaced.
bool loopChainOutcomeIsUnresolved(LoopChainFailureKind kind) =>
    kind == LoopChainFailureKind.offline ||
    kind == LoopChainFailureKind.cancelled ||
    kind == LoopChainFailureKind.outcomeUnknown;

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
  'BSC_INDEXER_NOT_STARTED' => '转账索引尚未运行，待确认金额与活动记录暂时读不到。',
  'BSC_POOL_INDEXER_NOT_STARTED' => '池事件索引尚未运行，成交与派生 K 线暂时读不到。',
  'NATIVE_TRANSFER_SCAN_NOT_SUPPORTED' => '原生 BNB 转账历史本步没有来源，不展示空列表。',
  'CROSS_CHAIN_ACTIVITY_NOT_SUPPORTED' => '跨链与挖矿领取记录本步没有来源。',
  'PRIVY_ASSET_MAPPING_UNAVAILABLE' => '该资产无法与 Privy 的口径对齐，交叉核对不可用。',
  'PRIVY_WALLET_ID_UNAVAILABLE' => '外部钱包没有 Privy 钱包 ID，交叉核对不可用。',
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
  'WALLET_CUSTOM_RPC_DEFERRED' => '自定义 RPC 与测试网本步不开放。',
  'WALLET_FUNDS_ACTIONS_DEFERRED' => '发送、兑换、跨链与 Pay 需要统一签名出口，尚未交付。',
  'WALLET_SECURITY_FACTS_DEFERRED' => '安全中心、授权盘点与 DApp 状态尚未接入，不展示任何数量。',
  null => '该字段当前没有可信来源。',
  _ => '该字段当前没有可信来源。',
};

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
      LoopChainFailureKind.permissionDenied => LoopChainViewPhase.permission,
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
