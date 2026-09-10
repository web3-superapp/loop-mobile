import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';

// ---------------------------------------------------------------------------
// wallets · GET /v2/wallets, PUT /v2/wallets/active
// ---------------------------------------------------------------------------

enum LoopWalletKind {
  embedded('embedded'),
  external('external');

  const LoopWalletKind(this.wireName);

  final String wireName;

  static LoopWalletKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

enum LoopWalletStatus {
  active('active'),
  archived('archived');

  const LoopWalletStatus(this.wireName);

  final String wireName;

  static LoopWalletStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// One wallet the account owns.
///
/// [walletId] is the ONLY value that may address a wallet in a request. The
/// address is a public chain fact carried for display and for the receive QR;
/// it is never an account identity, a map key or a route parameter.
@immutable
final class LoopWalletAccount {
  const LoopWalletAccount({
    required this.walletId,
    required this.address,
    required this.kind,
    required this.status,
    required this.isActive,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });

  final String walletId;
  final String address;
  final LoopWalletKind kind;
  final LoopWalletStatus status;
  final bool isActive;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;

  String get truncatedAddress => loopTruncatedAddress(address);
}

/// `GET /v2/wallets`. The wallet list always states which provider reported it
/// and when, so a stale list can never read as "you have no wallets".
@immutable
final class LoopWalletDirectory {
  LoopWalletDirectory({
    required List<LoopWalletAccount> wallets,
    required this.activeWalletId,
    required this.observedAt,
  }) : wallets = List<LoopWalletAccount>.unmodifiable(wallets);

  final List<LoopWalletAccount> wallets;
  final String? activeWalletId;
  final DateTime observedAt;

  /// The server answered, and the answer was "this account owns no wallet".
  ///
  /// It is a read result, never the absence of one: a page may render it only
  /// after the directory reached [LoopChainViewPhase.ready], because a failed
  /// or unfinished read produces no directory at all.
  bool get isEmpty => wallets.isEmpty;

  bool get isNotEmpty => wallets.isNotEmpty;

  List<LoopWalletAccount> get embedded => wallets
      .where((wallet) => wallet.kind == LoopWalletKind.embedded)
      .toList(growable: false);

  List<LoopWalletAccount> get externals => wallets
      .where((wallet) => wallet.kind == LoopWalletKind.external)
      .toList(growable: false);

  LoopWalletAccount? get active {
    final id = activeWalletId;
    if (id == null) return null;
    for (final wallet in wallets) {
      if (wallet.walletId == id) return wallet;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// balances · GET /v2/wallets/{walletId}/balances
// ---------------------------------------------------------------------------

/// Every balance in one response is read at the same [blockNumber]. The UI
/// must show that height and its observation time and must never mix figures
/// from two snapshots.
@immutable
final class LoopBalanceSnapshot {
  const LoopBalanceSnapshot({
    required this.blockNumber,
    required this.blockHash,
    required this.observedAt,
    required this.confirmations,
  });

  final BigInt blockNumber;
  final String blockHash;
  final DateTime observedAt;
  final int confirmations;
}

/// The server-owned gas reserve. The client never hardcodes 0.005 BNB.
@immutable
final class LoopGasReservePolicy {
  const LoopGasReservePolicy({
    required this.configVersion,
    required this.nativeReserveRaw,
    required this.nativeReserve,
  });

  final String configVersion;
  final String nativeReserveRaw;
  final Decimal nativeReserve;
}

/// Discriminated union for one row's on-chain amount.
///
/// "The chain read failed" and "this wallet holds none of it" are different
/// facts: the unavailable variant must never be rendered as `0`.
sealed class LoopBalanceAmount {
  const LoopBalanceAmount();
}

final class LoopBalanceAvailable extends LoopBalanceAmount {
  const LoopBalanceAvailable({
    required this.rawValue,
    required this.displayBalance,
    required this.availableBalance,
    required this.spendableBalance,
    required this.gasReserve,
  });

  /// The exact integer minor-unit string. Kept verbatim for auditing.
  final String rawValue;

  /// Five separate meanings; never derive one from another.
  final Decimal displayBalance;
  final Decimal availableBalance;
  final Decimal spendableBalance;
  final Decimal gasReserve;
}

final class LoopBalanceUnavailable extends LoopBalanceAmount {
  const LoopBalanceUnavailable(this.reasonCode);

  final String reasonCode;
}

/// Unconfirmed *incoming* value known to the indexer. It is not spendable.
sealed class LoopPendingAmount {
  const LoopPendingAmount();
}

final class LoopPendingAvailable extends LoopPendingAmount {
  const LoopPendingAvailable({required this.rawValue, required this.value});

  final String rawValue;
  final Decimal value;
}

final class LoopPendingUnavailable extends LoopPendingAmount {
  const LoopPendingUnavailable(this.reasonCode);

  final String reasonCode;
}

/// Per-row USD valuation. `proxied` means the native asset borrows the WBNB
/// price and must be labelled as such.
sealed class LoopValuation {
  const LoopValuation();
}

final class LoopValuationAvailable extends LoopValuation {
  const LoopValuationAvailable({
    required this.priceSource,
    required this.fetchedAt,
    required this.quality,
    required this.reasonCode,
    required this.proxyAsset,
    required this.priceUsd,
    required this.valueUsd,
  });

  final LoopFactSource priceSource;
  final DateTime fetchedAt;

  /// `fresh`, `stale` or `proxied`; never `derived` or `unavailable`.
  final LoopFactQuality quality;
  final String? reasonCode;

  /// The assetId whose price was borrowed. Non-null exactly when [quality] is
  /// `proxied`.
  final String? proxyAsset;
  final Decimal priceUsd;
  final Decimal valueUsd;

  bool get isProxied => quality == LoopFactQuality.proxied;
}

final class LoopValuationUnavailable extends LoopValuation {
  const LoopValuationUnavailable(this.reasonCode);

  final String reasonCode;
}

enum LoopCrossCheckStatus {
  matched('matched'),
  unaligned('unaligned'),
  disputed('disputed'),
  unavailable('unavailable');

  const LoopCrossCheckStatus(this.wireName);

  final String wireName;

  static LoopCrossCheckStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// Reconciliation against Privy. It never changes the RPC figure; at most the
/// UI adds a "数据源尚未对齐" hint.
@immutable
final class LoopBalanceCrossCheck {
  const LoopBalanceCrossCheck({
    required this.status,
    required this.reasonCode,
    required this.blockDelta,
  });

  final LoopCrossCheckStatus status;
  final String? reasonCode;
  final int? blockDelta;

  bool get isMisaligned =>
      status == LoopCrossCheckStatus.unaligned ||
      status == LoopCrossCheckStatus.disputed;
}

/// One readable registry asset. The row always exists, even when its chain
/// read failed.
@immutable
final class LoopAssetBalanceRow {
  const LoopAssetBalanceRow({
    required this.assetId,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.address,
    required this.balance,
    required this.pending,
    required this.valuation,
    required this.crossCheck,
  });

  final String assetId;
  final String symbol;
  final String name;
  final int decimals;
  final String? address;
  final LoopBalanceAmount balance;
  final LoopPendingAmount pending;
  final LoopValuation valuation;
  final LoopBalanceCrossCheck crossCheck;

  bool get isNative => assetId.endsWith(':native');
}

/// Aggregate valuation. It is display information, never a spendable figure —
/// the wire even carries `isSpendable: false` so the client cannot forget.
sealed class LoopNetWorth {
  const LoopNetWorth();
}

final class LoopNetWorthValued extends LoopNetWorth {
  const LoopNetWorthValued({
    required this.partial,
    required this.valuationCurrency,
    required this.valueUsd,
    required this.unavailableCount,
    required this.quality,
    required this.priceSource,
    required this.asOf,
    required this.isSpendable,
  });

  /// `partial` means some rows could not be valued: [valueUsd] is only the sum
  /// of the rows that could, and must never be presented as total assets.
  final bool partial;
  final String valuationCurrency;
  final Decimal valueUsd;
  final int unavailableCount;
  final LoopFactQuality quality;
  final LoopFactSource priceSource;
  final DateTime asOf;

  /// Always false on the wire; retained so the assertion is visible in tests.
  final bool isSpendable;
}

final class LoopNetWorthUnavailable extends LoopNetWorth {
  const LoopNetWorthUnavailable(this.reasonCode);

  final String reasonCode;
}

/// The native balance held on the Launch chain slot (decision 0038).
///
/// One asset and one `eth_getBalance`: there is no registry, no ERC-20 row, no
/// pending amount and no valuation on that slot, so nothing here may be
/// presented as a portfolio figure.
@immutable
final class LoopLaunchChainNativeBalance {
  const LoopLaunchChainNativeBalance({
    required this.assetId,
    required this.symbol,
    required this.decimals,
    required this.rawValue,
    required this.displayBalance,
    required this.availableBalance,
    required this.spendableBalance,
    required this.gasReserve,
    required this.snapshot,
  });

  final String assetId;
  final String symbol;
  final int decimals;

  /// The exact integer minor-unit string, kept verbatim for auditing.
  final String rawValue;
  final Decimal displayBalance;
  final Decimal availableBalance;
  final Decimal spendableBalance;
  final Decimal gasReserve;
  final LoopBalanceSnapshot snapshot;
}

/// The optional `launchChain` block of `GET /v2/wallets/{id}/balances`.
///
/// The key is **absent** while the Launch slot equals the primary chain, so a
/// `null` field on [LoopWalletBalances] means "no Launch block on this page",
/// never "the read failed". A failure is this object with
/// [nativeBalance] `null` and the server's own [reasonCode].
@immutable
final class LoopLaunchChainBalance {
  const LoopLaunchChainBalance({
    required this.chainId,
    required this.available,
    required this.reasonCode,
    required this.nativeBalance,
  });

  final String chainId;
  final bool available;
  final String? reasonCode;
  final LoopLaunchChainNativeBalance? nativeBalance;

  bool get isTestnet => loopIsTestnetChainId(chainId);

  String get name => loopChainName(chainId);
}

@immutable
final class LoopWalletBalances {
  LoopWalletBalances({
    required this.walletId,
    required this.snapshot,
    required this.gasReservePolicy,
    required List<LoopAssetBalanceRow> balances,
    required this.netWorth,
    this.launchChain,
  }) : balances = List<LoopAssetBalanceRow>.unmodifiable(balances);

  final String walletId;
  final LoopBalanceSnapshot snapshot;
  final LoopGasReservePolicy gasReservePolicy;
  final List<LoopAssetBalanceRow> balances;
  final LoopNetWorth netWorth;

  /// Decision 0038. `null` is the ordinary case: the backend omits the key
  /// while the Launch slot equals the primary chain, and the wallet page then
  /// shows no Launch block at all. A testnet slot that failed to read is a
  /// non-null value carrying its own reason, never a missing key.
  final LoopLaunchChainBalance? launchChain;

  LoopAssetBalanceRow? rowFor(String assetId) {
    for (final row in balances) {
      if (row.assetId == assetId) return row;
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// activity · GET /v2/wallets/{walletId}/activity
// ---------------------------------------------------------------------------

enum LoopTransferDirection {
  incoming('in'),
  outgoing('out'),
  self('self');

  const LoopTransferDirection(this.wireName);

  final String wireName;

  static LoopTransferDirection? tryParse(String value) {
    for (final direction in values) {
      if (direction.wireName == value) return direction;
    }
    return null;
  }
}

/// One indexed ERC-20 transfer. Each row carries its own transaction, log
/// index, block and confirmation count so nothing is inferred from position.
@immutable
final class LoopWalletActivityEntry {
  const LoopWalletActivityEntry({
    required this.assetId,
    required this.symbol,
    required this.decimals,
    required this.direction,
    required this.counterpartyAddress,
    required this.rawValue,
    required this.displayValue,
    required this.transactionHash,
    required this.logIndex,
    required this.blockNumber,
    required this.blockHash,
    required this.confirmations,
    required this.status,
    required this.observedAt,
  });

  final String assetId;
  final String symbol;
  final int decimals;
  final LoopTransferDirection direction;
  final String counterpartyAddress;
  final String rawValue;
  final Decimal displayValue;
  final String transactionHash;
  final int logIndex;
  final BigInt blockNumber;
  final String blockHash;
  final int? confirmations;
  final LoopConfirmationStatus status;
  final DateTime observedAt;

  /// Stable identity of one indexed log, used for list keys and de-duplication.
  String get entryId => '$transactionHash:$logIndex';
}

@immutable
final class LoopWalletActivityPage {
  LoopWalletActivityPage({
    required this.walletId,
    required List<LoopWalletActivityEntry> items,
    required this.nextCursor,
    required this.freshness,
    required this.nativeTransfers,
    required this.crossChain,
  }) : items = List<LoopWalletActivityEntry>.unmodifiable(items);

  final String walletId;
  final List<LoopWalletActivityEntry> items;
  final String? nextCursor;
  final LoopIndexerFreshness freshness;

  /// Both are unavailable for the whole of this step; the prototype's 跨链 and
  /// 挖矿领取 segments must render as unavailable, never as empty lists.
  final LoopUnavailable nativeTransfers;
  final LoopUnavailable crossChain;
}

// ---------------------------------------------------------------------------
// receive · GET /v2/wallets/{walletId}/receive
// ---------------------------------------------------------------------------

/// One receivable network. Only BSC is listed; other networks are simply
/// absent, not rendered as unavailable placeholders.
@immutable
final class LoopReceiveNetwork {
  const LoopReceiveNetwork({
    required this.chainId,
    required this.name,
    required this.address,
    required this.uri,
    required this.warningKey,
  });

  final String chainId;
  final String name;
  final String address;

  /// The EIP-681 string the client renders as a QR code. The backend never
  /// sends an image.
  final String uri;
  final String warningKey;
}

@immutable
final class LoopWalletReceive {
  LoopWalletReceive({
    required this.walletId,
    required List<LoopReceiveNetwork> networks,
  }) : networks = List<LoopReceiveNetwork>.unmodifiable(networks);

  final String walletId;
  final List<LoopReceiveNetwork> networks;
}

/// zh-CN copy for a receive warning key. Unknown keys keep a neutral warning.
String loopReceiveWarningText(String warningKey) => switch (warningKey) {
  'wallet.receive.bscOnly' =>
    '只接收 BNB Smart Chain（BSC）网络的资产。把其他网络的资产发到这个地址可能永久丢失。',
  _ => '请先确认发送方使用的网络与这里显示的一致。',
};
