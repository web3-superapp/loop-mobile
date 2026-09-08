import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';

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

enum LoopAssetStatus {
  pending('pending'),
  verified('verified'),
  blocked('blocked');

  const LoopAssetStatus(this.wireName);

  final String wireName;

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
  operatorBlock('operator_block');

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
  });

  final LoopAssetSourceKind kind;
  final BigInt? blockNumber;
  final DateTime? verifiedAt;
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
  final String symbol;
  final String name;
  final int decimals;
  final LoopAssetStatus status;
  final LoopAssetSource source;
  final DateTime updatedAt;

  bool get isNative => assetId.endsWith(':native');
}

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

enum LoopChainVerification {
  verified('verified'),
  mismatched('mismatched'),
  unreachable('unreachable'),
  unknown('unknown');

  const LoopChainVerification(this.wireName);

  final String wireName;

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

/// One RPC endpoint's health. [endpointRef] is an irreversible reference; the
/// backend never sends the URL and the client must never display or guess it.
@immutable
final class LoopRpcEndpointHealth {
  const LoopRpcEndpointHealth({
    required this.endpointRef,
    required this.status,
    required this.latencyMs,
    required this.blockNumber,
    required this.blockLagBlocks,
    required this.chainVerification,
    required this.observedAt,
  });

  final String endpointRef;
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

/// `GET /v2/chain/status` — the whole `networks` page.
@immutable
final class LoopChainStatus {
  const LoopChainStatus({
    required this.chain,
    required this.rpc,
    required this.indexer,
    required this.registry,
  });

  final LoopChainInfo chain;
  final LoopRpcHealth rpc;
  final List<LoopIndexerLaneStatus> indexer;
  final LoopRegistryCounts registry;

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
