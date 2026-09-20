import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

/// The two chain slots are a cross-cutting identity, not a chain-module fact:
/// signing, Launch and the wallet page all read them.
export 'package:loop_mobile/core/chain/loop_chain_ids.dart';

/// Canonical CAIP-19 asset identity. The ticker is never an identity: it is
/// display text that two different contracts may share.
final RegExp loopAssetIdPattern = RegExp(
  r'^eip155:[1-9][0-9]{0,9}:(native|0x[0-9a-f]{40})$',
);
final RegExp loopChainIdPattern = RegExp(r'^eip155:[1-9][0-9]{0,9}$');
final RegExp loopAddressPattern = RegExp(r'^0x[0-9a-f]{40}$');
final RegExp loopHashPattern = RegExp(r'^0x[0-9a-f]{64}$');
final RegExp loopEndpointRefPattern = RegExp(r'^rpc-[0-9a-f]{12}$');

/// Truncated address for display. The full value is still the model's truth;
/// only the rendering is shortened, and the address is never a key.
String loopTruncatedAddress(String address) {
  if (address.length <= 13) return address;
  return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
}

/// Short display form of a CAIP asset id. The full id remains the identity.
String loopTruncatedAssetId(String assetId) {
  final separator = assetId.lastIndexOf(':');
  if (separator < 0 || separator + 1 >= assetId.length) return assetId;
  final tail = assetId.substring(separator + 1);
  return tail == 'native' ? 'native' : loopTruncatedAddress(tail);
}

/// Where an asset stands in the LOOP registry.
///
/// [wireName] parses and compares; [label] is the only value that may be
/// printed. They are separate because the wire vocabulary is English and
/// internal — an owner reading 「登记状态 verified」 learns nothing about their
/// own asset.
enum LoopAssetStatus {
  pending('pending', '待核验'),
  verified('verified', '已核验'),
  blocked('blocked', '已屏蔽'),

  /// The registry has no row for this contract, and the facts alongside it
  /// were read from the chain and the market providers for this request
  /// alone. It is how a contract pasted into a conversation can be answered
  /// at all; it is not a lesser kind of verification, and it never means the
  /// asset was checked and found wanting.
  unregistered('unregistered', '未登记'),

  /// The registry has no row for this contract and no provider could
  /// describe it at this moment. Identity is missing, not absent: the address
  /// is all there is to show, and no ticker may be invented to fill the slot.
  ///
  /// The market contract states this one without an identity block at all
  /// (only `status` and `reasonCode`), so `GET /v2/market/assets/{assetId}`
  /// decodes it into `MarketAssetIdentityUnavailable` rather than into an
  /// asset whose every field is null. This value stays for the endpoints that
  /// do report a full block.
  unavailable('unavailable', '暂时读不到');

  const LoopAssetStatus(this.wireName, this.label);

  final String wireName;

  /// zh-CN display name. Registry verification is about the asset's name,
  /// symbol and decimals having been read from the chain — it is not the
  /// endpoint check [LoopChainVerification] reports, and it never means the
  /// asset is safe.
  final String label;

  static LoopAssetStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// The four-field registry projection carried inline by watchlist, alerts and
/// market rows. `null` at the call site means the asset is no longer readable.
@immutable
final class LoopAssetSummary {
  const LoopAssetSummary({
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.status,
  });

  final String symbol;
  final String name;
  final int decimals;
  final LoopAssetStatus status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopAssetSummary &&
          other.symbol == symbol &&
          other.name == name &&
          other.decimals == decimals &&
          other.status == status;

  @override
  int get hashCode => Object.hash(symbol, name, decimals, status);
}

enum LoopAssetSourceKind {
  chainCall('chain_call'),
  chainNative('chain_native'),
  operatorBlock('operator_block'),

  /// Identity read from a market provider for this request alone, because
  /// the registry carries no row for the contract. It is not a chain call and
  /// must never be labelled as one.
  providerLookup('provider_lookup');

  const LoopAssetSourceKind(this.wireName);

  final String wireName;

  static LoopAssetSourceKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

@immutable
final class LoopAssetSource {
  const LoopAssetSource({
    required this.kind,
    required this.blockNumber,
    required this.verifiedAt,
    this.provider,
    this.fetchedAt,
    this.ttlSeconds,
    this.quality,
  });

  final LoopAssetSourceKind kind;
  final BigInt? blockNumber;
  final DateTime? verifiedAt;

  /// Which market provider answered, when [kind] is
  /// [LoopAssetSourceKind.providerLookup]. `null` on every other kind.
  final LoopFactSource? provider;

  /// When that lookup was performed, and how long it is good for.
  final DateTime? fetchedAt;
  final int? ttlSeconds;

  /// `stale` says the provider could not be reached and this identity is the
  /// last one it gave. The surface marks it; it never presents it as current.
  final LoopFactQuality? quality;
}

/// Registry facts for one asset. `symbol`/`name`/`decimals` come only from an
/// on-chain call, so they can never be an operator's free text.
@immutable
final class LoopChainAsset {
  const LoopChainAsset({
    required this.assetId,
    required this.chainId,
    required this.address,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.status,
    required this.source,
    required this.updatedAt,
  });

  final String assetId;
  final String chainId;
  final String? address;

  /// The ticker, when something could report one. A contract no provider
  /// described carries `null` here, and the surface shows the address: a
  /// placeholder ticker would be a name LOOP made up.
  final String? symbol;
  final String? name;

  /// `null` when the answering provider does not report precision. No raw
  /// on-chain quantity may be formatted without it — a wrong exponent is a
  /// wrong number, not a rounding.
  final int? decimals;
  final LoopAssetStatus status;
  final LoopAssetSource source;
  final DateTime updatedAt;

  bool get isNative => assetId.endsWith(':native');

  /// Whether a raw on-chain quantity of this asset may be converted at all.
  bool get hasPrecision => decimals != null;
}

/// The word a surface prints for [asset].
///
/// A provider that reported no ticker leaves the address to speak for itself.
String loopAssetSymbolLabel(LoopChainAsset asset) =>
    asset.symbol ?? loopTruncatedAssetId(asset.assetId);

enum LoopAssetCapabilityValue {
  viewable('viewable'),
  swappable('swappable'),
  temporarilyUnavailable('temporarily_unavailable'),
  blocked('blocked');

  const LoopAssetCapabilityValue(this.wireName);

  final String wireName;

  static LoopAssetCapabilityValue? tryParse(String value) {
    for (final capability in values) {
      if (capability.wireName == value) return capability;
    }
    return null;
  }
}

/// What the product may offer for one asset. `swappable` is the ONLY gate for
/// a Swap entry point, and the backend keeps it `false` until D15.
@immutable
final class LoopAssetCapability {
  const LoopAssetCapability({
    required this.viewable,
    required this.swappable,
    required this.value,
    required this.reasonCode,
  });

  final bool viewable;
  final bool swappable;
  final LoopAssetCapabilityValue value;
  final String? reasonCode;

  bool get blocksEntirePage => value == LoopAssetCapabilityValue.blocked;

  /// Registry facts may still be shown, but no "current" chain figure may be.
  bool get suppressesLiveFigures =>
      value == LoopAssetCapabilityValue.temporarilyUnavailable;
}

/// `GET /v2/assets/{assetId}`.
@immutable
final class LoopChainAssetView {
  const LoopChainAssetView({required this.asset, required this.capability});

  final LoopChainAsset asset;
  final LoopAssetCapability capability;
}

// ---------------------------------------------------------------------------
// chain status
// ---------------------------------------------------------------------------

@immutable
final class LoopChainInfo {
  const LoopChainInfo({
    required this.chainId,
    required this.name,
    required this.reference,
    required this.nativeAssetId,
    required this.confirmations,
    required this.reorgDepthBlocks,
  });

  final String chainId;
  final String name;
  final int reference;
  final String nativeAssetId;
  final int confirmations;
  final int reorgDepthBlocks;
}

/// Whether an RPC endpoint proved it is speaking for the expected chain.
enum LoopChainVerification {
  verified('verified', '通过'),
  mismatched('mismatched', '不一致'),
  unreachable('unreachable', '连不上'),
  unknown('unknown', '未知');

  const LoopChainVerification(this.wireName, this.label);

  final String wireName;

  /// zh-CN display name, read as 「校验…」 on the endpoint row. It reports the
  /// chain check on one endpoint and nothing else: it is not an asset's
  /// registry state, and 通过 says the endpoint answered for the right chain,
  /// never that anything on it was audited.
  final String label;

  static LoopChainVerification? tryParse(String value) {
    for (final verification in values) {
      if (verification.wireName == value) return verification;
    }
    return null;
  }
}

enum LoopEndpointStatus {
  healthy('healthy'),
  degraded('degraded'),
  unreachable('unreachable');

  const LoopEndpointStatus(this.wireName);

  final String wireName;

  static LoopEndpointStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

@immutable
final class LoopChainHead {
  const LoopChainHead({
    required this.blockNumber,
    required this.blockHash,
    required this.observedAt,
  });

  final BigInt blockNumber;
  final String blockHash;
  final DateTime observedAt;
}

/// One RPC endpoint's health.
///
/// [endpointRef] is an irreversible reference and stays off the screen: it is
/// the row's key and nothing a reader can match against. [label] is the host
/// name the server publishes for display (decision 0049) — never the scheme,
/// the port, the path or any key, and the client must not guess the rest.
@immutable
final class LoopRpcEndpointHealth {
  const LoopRpcEndpointHealth({
    required this.endpointRef,
    required this.label,
    required this.status,
    required this.latencyMs,
    required this.blockNumber,
    required this.blockLagBlocks,
    required this.chainVerification,
    required this.observedAt,
  });

  final String endpointRef;
  final String label;
  final LoopEndpointStatus status;
  final int? latencyMs;
  final BigInt? blockNumber;
  final int? blockLagBlocks;
  final LoopChainVerification chainVerification;
  final DateTime observedAt;

  bool get isAbnormal => status != LoopEndpointStatus.healthy;
}

@immutable
final class LoopRpcHealth {
  const LoopRpcHealth({
    required this.available,
    required this.reasonCode,
    required this.verification,
    required this.head,
    required this.endpoints,
  });

  final bool available;
  final String? reasonCode;
  final LoopChainVerification verification;
  final LoopChainHead? head;
  final List<LoopRpcEndpointHealth> endpoints;

  int get healthyCount =>
      endpoints.where((endpoint) => !endpoint.isAbnormal).length;
}

/// The indexer lane enum grows with the backend; it is parsed, never hardcoded
/// as a fixed pair at a call site.
enum LoopIndexerLane {
  erc20Transfer('erc20_transfer'),
  poolEvent('pool_event');

  const LoopIndexerLane(this.wireName);

  final String wireName;

  static LoopIndexerLane? tryParse(String value) {
    for (final lane in values) {
      if (lane.wireName == value) return lane;
    }
    return null;
  }
}

String loopIndexerLaneLabel(LoopIndexerLane lane) => switch (lane) {
  LoopIndexerLane.erc20Transfer => 'ERC-20 转账索引',
  LoopIndexerLane.poolEvent => '池事件索引',
};

@immutable
final class LoopIndexerLaneStatus {
  const LoopIndexerLaneStatus({
    required this.lane,
    required this.available,
    required this.reasonCode,
    required this.lastBlockNumber,
    required this.lastBlockHash,
    required this.lagBlocks,
    required this.reorgCount,
    required this.updatedAt,
  });

  final LoopIndexerLane lane;
  final bool available;
  final String? reasonCode;
  final BigInt? lastBlockNumber;
  final String? lastBlockHash;
  final int? lagBlocks;
  final int? reorgCount;
  final DateTime? updatedAt;
}

@immutable
final class LoopRegistryCounts {
  const LoopRegistryCounts({
    required this.readableAssetCount,
    required this.registeredPoolCount,
  });

  final int readableAssetCount;
  final int registeredPoolCount;
}

/// The Launch chain slot's own health (`launchChain`, decision 0038).
///
/// It carries no endpoint list: testnet endpoint health is not published, so
/// the page states the slot's verification and its own reason code instead.
@immutable
final class LoopLaunchChainStatus {
  const LoopLaunchChainStatus({
    required this.chainId,
    required this.chainReference,
    required this.verification,
    required this.confirmations,
    required this.reorgDepthBlocks,
    required this.head,
    required this.reasonCode,
  });

  final String chainId;
  final int chainReference;
  final LoopChainVerification verification;
  final int confirmations;
  final int reorgDepthBlocks;

  /// Non-null only while [verification] is `verified`.
  final LoopChainHead? head;
  final String? reasonCode;

  bool get isTestnet => loopIsTestnetChainId(chainId);

  bool get isHealthy =>
      verification == LoopChainVerification.verified && reasonCode == null;

  String get name => loopChainName(chainId);
}

/// `GET /v2/chain/status` — the whole `networks` page.
@immutable
final class LoopChainStatus {
  const LoopChainStatus({
    required this.chain,
    required this.rpc,
    required this.indexer,
    required this.registry,
    this.launchChain,
  });

  final LoopChainInfo chain;
  final LoopRpcHealth rpc;
  final List<LoopIndexerLaneStatus> indexer;
  final LoopRegistryCounts registry;

  /// The Launch chain slot (decision 0038). `null` is the ordinary case: the
  /// backend omits the key entirely while the slot equals [chain], so the
  /// `networks` page shows no testnet row at all — not an unavailable one.
  final LoopLaunchChainStatus? launchChain;

  /// A mismatched chain id makes the whole page unusable, whatever else the
  /// endpoints report.
  bool get chainIdMismatched =>
      rpc.verification == LoopChainVerification.mismatched ||
      rpc.reasonCode == 'BSC_CHAIN_ID_MISMATCH' ||
      rpc.endpoints.any(
        (endpoint) =>
            endpoint.chainVerification == LoopChainVerification.mismatched,
      );
}

/// A freshness triple shared by the activity and trades tapes.
@immutable
final class LoopIndexerFreshness {
  const LoopIndexerFreshness({
    required this.indexerBlockNumber,
    required this.headBlockNumber,
    required this.lagBlocks,
    required this.observedAt,
  });

  final BigInt indexerBlockNumber;
  final BigInt? headBlockNumber;
  final int? lagBlocks;
  final DateTime observedAt;

  /// The threshold above which the UI must say "数据落后 N 块".
  static const int notableLagBlocks = 50;

  bool get isNotablyBehind =>
      lagBlocks != null && lagBlocks! >= notableLagBlocks;
}

/// Confirmation state of one indexed row.
enum LoopConfirmationStatus {
  confirmed('confirmed'),
  pending('pending'),
  reorged('reorged');

  const LoopConfirmationStatus(this.wireName);

  final String wireName;

  static LoopConfirmationStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

String loopConfirmationLabel(LoopConfirmationStatus status) => switch (status) {
  LoopConfirmationStatus.confirmed => '已确认',
  LoopConfirmationStatus.pending => '待确认',
  LoopConfirmationStatus.reorged => '已回滚',
};

/// A block observation label: the height plus the wall-clock observation.
String loopObservedAtLabel(DateTime value) {
  final utc = value.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} UTC';
}

/// "来源 X · 观察于 …" — the single sentence every rendered fact carries.
String loopProvenanceLabel({
  required LoopFactSource? source,
  required DateTime? observedAt,
}) {
  final sourceLabel = source == null
      ? '来源未知'
      : '来源 ${loopFactSourceLabel(source)}';
  if (observedAt == null) return sourceLabel;
  return '$sourceLabel · 观察于 ${loopObservedAtLabel(observedAt)}';
}
