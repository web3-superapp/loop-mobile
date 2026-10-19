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
    this.change24hPct,
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

  /// Decision 0100 (loop-api): the same pair's DexScreener `priceChange.h24`,
  /// in percent points (`-2.5` is -2.5 %). `null` when the Provider did not
  /// report it — that is "not read", never "did not move".
  final Decimal? change24hPct;

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
    this.logoUrl,
  });

  final String assetId;
  final String symbol;
  final String name;

  /// The registry's published artwork for this asset, or `null` when the
  /// server published none (decision 0072). A logo is display only: it never
  /// keys, merges or names a row — `assetId` does that alone.
  final String? logoUrl;
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
    required this.change24h,
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

  /// The 24h movement of the total (loop-api decision 0100). It is either the
  /// server's whole answer or the server's reason for giving none: the backend
  /// never sends a sum over only the rows that had a 24h figure.
  final LoopNetWorthChange change24h;
}

/// `netWorth.change24h` — the two states a valued net worth can carry.
///
/// The third state of the wire, "`netWorth` itself is unavailable", has no
/// change at all and is [LoopNetWorthUnavailable].
sealed class LoopNetWorthChange {
  const LoopNetWorthChange();
}

/// `{ usd, pct }`: the signed USD change (6 places) and the signed change in
/// percent points (4 places), both derived by the server from the same price
/// read as the rows.
final class LoopNetWorthChangeAvailable extends LoopNetWorthChange {
  const LoopNetWorthChangeAvailable({required this.usd, required this.pct});

  final Decimal usd;
  final Decimal pct;
}

/// `change24h: null` with `change24hUnavailable.reasonCode` — some valued row
/// had no 24h figure (`PRICE_CHANGE_PARTIAL`). It is never shown as zero.
final class LoopNetWorthChangeUnavailable extends LoopNetWorthChange {
  const LoopNetWorthChangeUnavailable(this.reasonCode);

  final String reasonCode;
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
    this.logoUrl,
  });

  final String assetId;
  final String symbol;
  final int decimals;

  /// The registry's published artwork, or `null` (decision 0072).
  final String? logoUrl;

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
    this.usd1,
  });

  final String chainId;
  final bool available;
  final String? reasonCode;
  final LoopLaunchChainNativeBalance? nativeBalance;

  /// `launchChain.usd1` (loop-api decision 0077, shape frozen by client
  /// decision 0088). The key is **absent** unless the backend read both the
  /// balance and the allowance at one block, so `null` means "未读取" — never
  /// a zero and never a guess.
  final LoopLaunchUsd1Reading? usd1;

  bool get isTestnet => loopIsTestnetChainId(chainId);

  String get name => loopChainName(chainId);
}

/// The USD1 figure the wallet's Launch chain block draws (decision 0208,
/// S237b-A): the USD1 every MEME v2 / launch2 trade spends — the Hooks
/// Factory's `usd1()`, the one the faucet mints — read by the server with the
/// wallet's MEME holdings (`me/positions`, decision 0148).
///
/// It is deliberately **not** `launchChain.usd1`: that pair is
/// `balanceOf` / `allowance` of `LAUNCH_USD1_ADDRESS`, the (hidden) IDO
/// Launch contract's USD1, which on the testnet slot is a different token
/// (S237 acceptance: the IDO token read 0 while the wallet held ~2,892 of the
/// MEME v2 USD1). That pair still gates the IDO approve step and nothing
/// else.
///
/// Exactly one of [balance] and [reason] is set: a figure the server read,
/// or the short reason no figure exists — the row then prints 「—」, never 0.
@immutable
final class WalletLaunchUsd1 {
  const WalletLaunchUsd1.read(Decimal this.balance) : reason = null;

  const WalletLaunchUsd1.missing(String this.reason) : balance = null;

  final Decimal? balance;
  final String? reason;
}

/// The reasons a [WalletLaunchUsd1] may carry (decision 0208).
const String walletLaunchUsd1Loading = '读取中';
const String walletLaunchUsd1Failed = '读取失败';
const String walletLaunchUsd1Closed = 'MEME 暂未开放';
const String walletLaunchUsd1NoReading = '持有已毕业代币后显示';

/// USD1 on the Launch slot: the balance and the allowance towards the
/// Launch contract, both exact 18-decimal integer strings read at one block.
@immutable
final class LoopLaunchUsd1Reading {
  const LoopLaunchUsd1Reading({required this.balance, required this.allowance});

  final String balance;

  /// `allowance(wallet, LAUNCH_CONTRACT_ADDRESS)`: what `buy()` may pull.
  final String allowance;
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
    this.launchUsd1,
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

  /// loop-api decision 0081: USD1 balance and allowance to the Launch contract
  /// while the Launch slot is the primary chain (so [launchChain] is absent).
  /// Decoded so the document is not refused; not yet wired into the Launch
  /// allowance gate, because approving on the shared (mainnet) slot is still
  /// `422 CHAIN_MISMATCH` server-side and mainnet signing is closed.
  final LoopLaunchUsd1Reading? launchUsd1;

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

// ---------------------------------------------------------------------------
// networth history · the wallet's hourly USD snapshots (decision 0188)
// ---------------------------------------------------------------------------

/// The five windows 钱包 C offers over the net-worth history.
enum LoopNetWorthRange {
  day('1d', '1 天'),
  week('7d', '7 天'),
  month('30d', '30 天'),
  halfYear('180d', '180 天'),
  year('360d', '360 天');

  const LoopNetWorthRange(this.wireName, this.label);

  final String wireName;
  final String label;

  static LoopNetWorthRange? tryParse(String value) {
    for (final range in values) {
      if (range.wireName == value) return range;
    }
    return null;
  }
}

/// One stored snapshot of the wallet's net worth. Display only: like the
/// current net worth it is never a spendable figure.
@immutable
final class LoopNetWorthPoint {
  const LoopNetWorthPoint({
    required this.at,
    required this.netWorthUsd,
    this.quality,
  });

  final DateTime at;
  final Decimal netWorthUsd;

  /// The server's word on the snapshot (`fresh`, `partial`, …), kept as sent.
  final String? quality;
}

/// The fiat restatement the server published (`CNY` only today).
///
/// Decision 0194: the rate carries where it came from ([source]), the day
/// the publisher fixed it ([asOf]), when LOOP read it ([fetchedAt]) and
/// whether it is still current ([quality], `fresh` or `stale` only). The
/// four come as one: a body missing any of them is the pre-0194 shape, and
/// the ¥ figure is still drawn but with no provenance — [hasProvenance] is
/// false and all four are null.
@immutable
final class LoopNetWorthFiat {
  const LoopNetWorthFiat({
    required this.currency,
    required this.rate,
    required this.amount,
    this.source,
    this.asOf,
    this.fetchedAt,
    this.quality,
  }) : assert(
         (source == null) == (asOf == null) &&
             (asOf == null) == (fetchedAt == null) &&
             (fetchedAt == null) == (quality == null),
         'The rate provenance is all four fields or none.',
       ),
       assert(
         quality == null ||
             quality == LoopFactQuality.fresh ||
             quality == LoopFactQuality.stale,
         'A rate is either fresh or stale.',
       );

  final String currency;

  /// 1 USD = [rate] [currency].
  final Decimal rate;
  final Decimal amount;

  /// The publisher's identifier as sent (`ecb`, …); never printed raw.
  final String? source;

  /// The publication day of the rate, a calendar date kept at UTC midnight.
  final DateTime? asOf;

  /// When LOOP read the rate from [source] (UTC).
  final DateTime? fetchedAt;

  /// [LoopFactQuality.fresh] or [LoopFactQuality.stale].
  final LoopFactQuality? quality;

  bool get hasProvenance =>
      source != null && asOf != null && fetchedAt != null && quality != null;

  bool get stale => quality == LoopFactQuality.stale;
}

/// `GET …/networth/history?range=…`.
///
/// Every field but [points] may be absent: a history with no 24h figure says
/// 「暂无」, one without a fiat rate draws no ¥ line, and nothing here is ever
/// derived from the balances read.
@immutable
final class LoopNetWorthHistory {
  const LoopNetWorthHistory({
    required this.range,
    required this.points,
    this.currentUsd,
    this.currentAt,
    this.change24h,
    this.high,
    this.low,
    this.fiat,
    this.source,
    this.observedAt,
  });

  final LoopNetWorthRange range;

  /// Oldest first.
  final List<LoopNetWorthPoint> points;
  final Decimal? currentUsd;
  final DateTime? currentAt;

  /// `null` when the server had no 24h-old snapshot to compare with.
  final LoopNetWorthChangeAvailable? change24h;
  final LoopNetWorthPoint? high;
  final LoopNetWorthPoint? low;
  final LoopNetWorthFiat? fiat;
  final String? source;
  final DateTime? observedAt;

  /// Whether there is a line to draw: two snapshots at least.
  bool get drawable => points.length >= 2;
}
