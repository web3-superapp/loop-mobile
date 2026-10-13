import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';

// ---------------------------------------------------------------------------
// MEME v2 (`launch2`) read and intent models (client decision 0139,
// loop-api decision 0114 / 0117, `docs/frontend-v2-launch2-api.md`)
// ---------------------------------------------------------------------------
//
// Every amount on the wire is a whole-unit decimal string (18 decimals at
// most); it is kept as an exact [Decimal] here and never as a `double`. The
// stage is the server's: the App counts down to `nextChangeAt` and re-reads,
// it never advances a stage on its own.

/// The instance's stage (contract §2). `paused` is an integrity hold, not
/// the buyback pause.
enum Launch2Stage {
  upcoming('upcoming'),
  nftSale('nft_sale'),
  snapshotPending('snapshot_pending'),

  /// The NFT sale ended with no holder on a v2-generation Factory (loop-api
  /// decision 0120; deprecated by 0122, legacy instances only). Terminal: no
  /// list can be published, so neither round ever opens. A v3 instance with
  /// no holder opens the public round instead
  /// ([Launch2Snapshot.openedWithoutHolders]).
  closedNoHolders('closed_no_holders'),
  priority('priority'),
  public('public'),
  graduated('graduated'),
  paused('paused');

  const Launch2Stage(this.wireName);

  final String wireName;

  static Launch2Stage? tryParse(String value) {
    for (final stage in values) {
      if (stage.wireName == value) return stage;
    }
    return null;
  }

  /// The curve takes orders in these two stages and nowhere else.
  bool get tradable => this == priority || this == public;

  /// No later stage follows (the server's `nextChangeAt` is `null` for good).
  bool get terminal => this == closedNoHolders;
}

/// Why a whole instance is held (`holdReason`).
enum Launch2HoldReason {
  deployedEventMismatch('LAUNCH2_DEPLOYED_EVENT_MISMATCH'),
  activationMissing('LAUNCH2_ACTIVATION_MISSING');

  const Launch2HoldReason(this.wireName);

  final String wireName;

  static Launch2HoldReason? tryParse(String value) {
    for (final reason in values) {
      if (reason.wireName == value) return reason;
    }
    return null;
  }
}

enum Launch2Side {
  buy('buy'),
  sell('sell');

  const Launch2Side(this.wireName);

  final String wireName;

  static Launch2Side? tryParse(String value) => switch (value) {
    'buy' => buy,
    'sell' => sell,
    _ => null,
  };
}

/// What bounds the executable MAX (`max.limitedBy`).
enum Launch2LimitedBy {
  quota('quota'),
  inventory('inventory'),
  balance('balance'),
  soldSupply('sold_supply'),
  closed('closed');

  const Launch2LimitedBy(this.wireName);

  final String wireName;

  static Launch2LimitedBy? tryParse(String value) {
    for (final item in values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

/// The two lists the MEME Tab reads.
enum Launch2ListScope {
  /// Every stage, newest activation first (「v2 发射」).
  all,

  /// `stage=graduated` (「已毕业」).
  graduated;

  Launch2Stage? get stage => switch (this) {
    Launch2ListScope.all => null,
    Launch2ListScope.graduated => Launch2Stage.graduated,
  };
}

@immutable
final class Launch2NftSale {
  const Launch2NftSale({
    required this.priceUsd1,
    required this.soldCount,
    required this.startAt,
    required this.endAt,
  });

  final Decimal priceUsd1;
  final BigInt soldCount;
  final DateTime startAt;
  final DateTime endAt;
}

@immutable
final class Launch2Curve {
  const Launch2Curve({
    required this.saleSupply,
    required this.soldSupply,
    required this.soldBps,
    required this.reserveUsd1,
    required this.graduationReserveUsd1,
    required this.reserveBps,
    required this.priceUsd1,
  });

  final Decimal saleSupply;
  final Decimal soldSupply;

  /// 内盘进度：已售 / 8 亿.
  final int soldBps;
  final Decimal reserveUsd1;
  final Decimal graduationReserveUsd1;

  /// 毕业进度：储备 / 133,333.332.
  final int reserveBps;

  /// The curve's current price; after graduation, its last one.
  final Decimal priceUsd1;
}

/// One list row (`GET /v2/launch2/instances`).
@immutable
final class Launch2InstanceRow {
  const Launch2InstanceRow({
    required this.instanceId,
    required this.projectId,
    required this.launchId,
    required this.chainId,
    required this.name,
    required this.ticker,
    required this.memeAddress,
    required this.stage,
    required this.nftSale,
    required this.curve,
    this.logoUrl,
    this.nextChangeAt,
    this.holdReason,
    this.activatedAt,
    this.graduatedAt,
  });

  final String instanceId;
  final String projectId;
  final String launchId;
  final String chainId;
  final String name;
  final String ticker;
  final String? logoUrl;
  final String memeAddress;
  final Launch2Stage stage;

  /// The moment the server's clock moves this stage on, or `null` when the
  /// stage ends on an event rather than a time.
  final DateTime? nextChangeAt;
  final Launch2HoldReason? holdReason;
  final DateTime? activatedAt;
  final Launch2NftSale nftSale;
  final Launch2Curve curve;
  final DateTime? graduatedAt;
}

@immutable
final class Launch2InstancePage {
  const Launch2InstancePage({required this.items, this.nextCursor});

  final List<Launch2InstanceRow> items;
  final String? nextCursor;

  /// The rows read so far followed by the next page; a row the server moved
  /// up between the two reads is kept once.
  Launch2InstancePage append(Launch2InstancePage next) {
    final seen = <String>{for (final row in items) row.instanceId};
    return Launch2InstancePage(
      items: List<Launch2InstanceRow>.unmodifiable(<Launch2InstanceRow>[
        ...items,
        for (final row in next.items)
          if (seen.add(row.instanceId)) row,
      ]),
      nextCursor: next.nextCursor,
    );
  }

  /// A fresh first page [head] over the rows read so far (decision 0148):
  /// the head's rows first, in its order, then every deeper row it does not
  /// repeat, with this page's cursor. A head that is the whole list (no
  /// cursor) replaces everything.
  Launch2InstancePage refreshHead(Launch2InstancePage head) {
    if (head.nextCursor == null) return head;
    final seen = <String>{for (final row in head.items) row.instanceId};
    return Launch2InstancePage(
      items: List<Launch2InstanceRow>.unmodifiable(<Launch2InstanceRow>[
        ...head.items,
        for (final row in items)
          if (seen.add(row.instanceId)) row,
      ]),
      nextCursor: nextCursor,
    );
  }
}

/// The fixed platform template (read-only, contract §3.2).
@immutable
final class Launch2Template {
  const Launch2Template({
    required this.templateVersion,
    required this.memeTotalSupply,
    required this.curveSaleSupply,
    required this.initialLiquiditySupply,
    required this.graduationReserveUsd1,
    required this.curveBuyTaxBps,
    required this.curveSellTaxBps,
    required this.officialPoolTaxBps,
    required this.lpFee,
    required this.tickSpacing,
    required this.perAddressCap,
    required this.perAddressCapBps,
    required this.nftPriceUsd1,
    required this.nftSaleSeconds,
    required this.earlyRoundSeconds,
    required this.buybackOrderUsd1,
    required this.buybackMinIntervalSeconds,
  });

  final String templateVersion;
  final Decimal memeTotalSupply;
  final Decimal curveSaleSupply;
  final Decimal initialLiquiditySupply;
  final Decimal graduationReserveUsd1;
  final int curveBuyTaxBps;
  final int curveSellTaxBps;
  final int officialPoolTaxBps;
  final int lpFee;
  final int tickSpacing;
  final Decimal perAddressCap;
  final int perAddressCapBps;
  final Decimal nftPriceUsd1;
  final int nftSaleSeconds;
  final int earlyRoundSeconds;
  final Decimal buybackOrderUsd1;
  final int buybackMinIntervalSeconds;
}

enum Launch2SnapshotVerification { pending, verified, mismatch }

/// The server-side 2-of-3 publication attempt (loop-api decision 0118).
enum Launch2PublicationStatus {
  pending('pending'),
  broadcast('broadcast'),
  confirmed('confirmed'),
  failed('failed'),
  mismatch('mismatch');

  const Launch2PublicationStatus(this.wireName);

  final String wireName;

  static Launch2PublicationStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

@immutable
final class Launch2SnapshotPublication {
  const Launch2SnapshotPublication({
    required this.status,
    required this.cutoffBlock,
    required this.memberCount,
    this.txHash,
  });

  final Launch2PublicationStatus status;
  final String? txHash;
  final BigInt cutoffBlock;
  final int memberCount;
}

/// Why a sale was closed without a list (`snapshot.closure`, loop-api
/// decision 0120; deprecated by 0122, legacy instances only). Today the only
/// reason is `no_holders`.
@immutable
final class Launch2SnapshotClosure {
  const Launch2SnapshotClosure({
    required this.cutoffBlock,
    required this.closedAt,
  });

  /// The confirmed cutoff block at which the NFT had no holder.
  final BigInt cutoffBlock;
  final DateTime closedAt;
}

/// The public round opened with no NFT holder (`snapshot.openedWithoutHolders`,
/// loop-api decision 0122, requirer answer 10): a v3 Factory sale that ended
/// with nothing minted goes straight to `public`, with no early round.
@immutable
final class Launch2OpenedWithoutHolders {
  const Launch2OpenedWithoutHolders({
    required this.openedAt,
    required this.blockNumber,
    required this.transactionHash,
  });

  final DateTime openedAt;
  final BigInt blockNumber;
  final String transactionHash;
}

@immutable
final class Launch2Snapshot {
  const Launch2Snapshot({
    required this.published,
    this.verification,
    this.root,
    this.cutoffBlockNumber,
    this.publishedAt,
    this.earlyRoundEndsAt,
    this.memberCount,
    this.publication,
    this.closure,
    this.openedWithoutHolders,
  });

  /// `snapshot.status = published`.
  final bool published;
  final Launch2SnapshotVerification? verification;
  final String? root;
  final BigInt? cutoffBlockNumber;
  final DateTime? publishedAt;
  final DateTime? earlyRoundEndsAt;
  final int? memberCount;

  /// The latest publication attempt; `null` until the publisher started one
  /// or from a server before loop-api decision 0118.
  final Launch2SnapshotPublication? publication;

  /// Non-null exactly when the stage is `closed_no_holders`.
  final Launch2SnapshotClosure? closure;

  /// Non-null exactly when `snapshot.status = opened_without_holders`.
  final Launch2OpenedWithoutHolders? openedWithoutHolders;
}

/// Set once the instance graduated. A v4 pool has an id, not an address.
@immutable
final class Launch2Graduation {
  const Launch2Graduation({
    required this.graduatedAt,
    required this.officialPoolId,
    required this.hookAddress,
    required this.lpFee,
    required this.tickSpacing,
    required this.officialPoolTaxBps,
    this.transactionHash,
  });

  final DateTime graduatedAt;
  final String officialPoolId;
  final String hookAddress;
  final int lpFee;
  final int tickSpacing;
  final int officialPoolTaxBps;
  final String? transactionHash;
}

@immutable
final class Launch2BuybackRecord {
  const Launch2BuybackRecord({
    required this.buybackId,
    required this.executed,
    required this.usd1Spent,
    required this.memeDelivered,
    required this.executedAt,
    required this.transactionHash,
    required this.blockNumber,
    this.reasonCode,
    this.minMemeOut,
    this.referencePriceUsd1,
    this.spotPriceUsd1,
  });

  final String buybackId;

  /// `outcome: executed`; `rejected` is reserved for the keeper.
  final bool executed;
  final String? reasonCode;
  final Decimal usd1Spent;
  final Decimal memeDelivered;

  /// The v2 (price-protected) executor's figures; all three `null` for a v3
  /// execution, which has no price protection (loop-api decision 0122).
  final Decimal? minMemeOut;
  final Decimal? referencePriceUsd1;
  final Decimal? spotPriceUsd1;
  final DateTime executedAt;
  final String transactionHash;
  final BigInt blockNumber;
}

/// The server-side keeper's newest attempt (`buyback.keeper`, loop-api
/// decision 0121). Advisory: the ledger stays the source of truth.
enum Launch2KeeperResult {
  rejected('rejected'),
  pending('pending'),
  broadcast('broadcast'),
  confirmed('confirmed'),
  failed('failed');

  const Launch2KeeperResult(this.wireName);

  final String wireName;

  static Launch2KeeperResult? tryParse(Object? value) {
    for (final result in values) {
      if (result.wireName == value) return result;
    }
    return null;
  }
}

@immutable
final class Launch2BuybackKeeper {
  const Launch2BuybackKeeper({
    required this.lastAttemptAt,
    required this.lastResult,
    this.reasonCode,
    this.nextEligibleAt,
  });

  final DateTime lastAttemptAt;
  final Launch2KeeperResult lastResult;
  final String? reasonCode;

  /// The earliest next try; `null` while a transaction is in flight.
  final DateTime? nextEligibleAt;
}

@immutable
final class Launch2BuybackSummary {
  const Launch2BuybackSummary({
    required this.recipient,
    required this.paused,
    required this.executedCount,
    required this.totalUsd1,
    required this.totalMeme,
    required this.escrowRecordedUsd1,
    required this.escrowAvailableUsd1,
    this.lastExecutedAt,
    this.latest,
    this.keeper,
  });

  final String recipient;
  final bool paused;
  final BigInt executedCount;
  final Decimal totalUsd1;
  final Decimal totalMeme;
  final DateTime? lastExecutedAt;
  final Decimal escrowRecordedUsd1;
  final Decimal escrowAvailableUsd1;
  final Launch2BuybackRecord? latest;

  /// `null` before the keeper ever looked at this instance, or from a server
  /// before loop-api decision 0121.
  final Launch2BuybackKeeper? keeper;
}

@immutable
final class Launch2Trade {
  const Launch2Trade({
    required this.tradeId,
    required this.side,
    required this.traderAddress,
    required this.memeAmount,
    required this.usd1Gross,
    required this.usd1Net,
    required this.taxUsd1,
    required this.tradedAt,
    required this.transactionHash,
    required this.blockNumber,
  });

  final String tradeId;
  final Launch2Side side;
  final String traderAddress;
  final Decimal memeAmount;
  final Decimal usd1Gross;
  final Decimal usd1Net;
  final Decimal taxUsd1;
  final DateTime tradedAt;
  final String transactionHash;
  final BigInt blockNumber;
}

/// Whether [Launch2WalletHolding]'s balances were read (loop-api S150).
enum Launch2BalanceStatus {
  /// Both balances read at one block.
  available('available'),

  /// Curve phase: no balances; the curve block is the position.
  notGraduated('not_graduated'),

  /// The chain read failed or the launch slot is not configured.
  unavailable('unavailable');

  const Launch2BalanceStatus(this.wireName);

  final String wireName;

  static Launch2BalanceStatus? tryParse(String value) => switch (value) {
    'available' => available,
    'not_graduated' => notGraduated,
    'unavailable' => unavailable,
    _ => null,
  };
}

/// The wallet's own figures after graduation (decision 0148, loop-api
/// S150): its live MEME / USD1 balances at one block and its own
/// official-pool trades, attributed through the router. Carried by the
/// detail's `viewer` and by every `me/positions` row; `null` when the
/// server predates them.
@immutable
final class Launch2WalletHolding {
  const Launch2WalletHolding({
    required this.status,
    required this.poolTradeCount,
    this.memeBalance,
    this.usd1Balance,
    this.reasonCode,
    this.blockNumber,
    this.lastPoolTradeAt,
  });

  final Launch2BalanceStatus status;

  /// `balanceOf(wallet)` of the MEME at [blockNumber]; `null` unless
  /// [status] is available.
  final Decimal? memeBalance;
  final Decimal? usd1Balance;

  /// Why the balances are unavailable.
  final String? reasonCode;
  final BigInt? blockNumber;

  /// The wallet's attributed official-pool trades — the confirmation
  /// signal after a pool trade, not the pool's own count.
  final BigInt poolTradeCount;
  final DateTime? lastPoolTradeAt;

  bool get balancesRead => status == Launch2BalanceStatus.available;
}

/// A wallet's curve figures; both rounds share the cumulative buy cap and
/// selling does not restore it.
@immutable
final class Launch2CurvePosition {
  const Launch2CurvePosition({
    required this.bought,
    required this.sold,
    required this.net,
    required this.cumulativeBought,
    required this.remainingQuota,
    required this.usd1Spent,
    required this.usd1Received,
    required this.taxUsd1,
  });

  final Decimal bought;
  final Decimal sold;
  final Decimal net;
  final Decimal cumulativeBought;
  final Decimal remainingQuota;
  final Decimal usd1Spent;
  final Decimal usd1Received;
  final Decimal taxUsd1;
}

/// The viewer block. `null` on the detail means no wallet, never zero.
@immutable
final class Launch2Viewer {
  const Launch2Viewer({
    required this.walletId,
    required this.nftHeld,
    required this.snapshotMember,
    required this.eligibleNow,
    required this.curve,
    this.mintedTokenId,
    this.holding,
  });

  final String walletId;
  final BigInt? mintedTokenId;
  final int nftHeld;
  final bool snapshotMember;
  final bool eligibleNow;
  final Launch2CurvePosition curve;

  /// Decision 0148: balances and own pool trades; `null` from an older
  /// server.
  final Launch2WalletHolding? holding;
}

/// `GET /v2/launch2/instances/{id}`.
@immutable
final class Launch2InstanceDetail {
  const Launch2InstanceDetail({
    required this.row,
    required this.viewerIsProjectOwner,
    required this.projectOwnerAddress,
    required this.configVersion,
    required this.configHash,
    required this.buybackRecipient,
    required this.template,
    required this.contracts,
    required this.snapshot,
    required this.buyback,
    required this.recentTrades,
    required this.projectedAt,
    this.graduation,
    this.viewer,
    this.pool,
  });

  final Launch2InstanceRow row;
  final bool viewerIsProjectOwner;
  final String projectOwnerAddress;
  final int configVersion;
  final String configHash;
  final String buybackRecipient;
  final Launch2Template template;

  /// Every module address by its contract name (`meme`, `hook`, `nft`,
  /// `curve`, …).
  final Map<String, String> contracts;
  final Launch2Snapshot snapshot;
  final Launch2Graduation? graduation;
  final Launch2BuybackSummary buyback;
  final List<Launch2Trade> recentTrades;
  final Launch2Viewer? viewer;
  final DateTime projectedAt;

  /// The official pool's indexed figures (decision 0145); `null` before
  /// graduation or from a server before S146.
  final Launch2PoolSummary? pool;

  String get instanceId => row.instanceId;
  Launch2Stage get stage => row.stage;
}

@immutable
final class Launch2Quote {
  const Launch2Quote({
    required this.instanceId,
    required this.walletId,
    required this.side,
    required this.stage,
    required this.requestedAmount,
    required this.exceedsMax,
    required this.amountIn,
    required this.maxIn,
    required this.expectedOut,
    required this.minOut,
    required this.slippageBps,
    required this.taxUsd1,
    required this.taxBps,
    required this.refundUsd1,
    required this.priceBeforeUsd1,
    required this.priceAfterUsd1,
    required this.maxAmountIn,
    required this.maxAmountOut,
    required this.limitedBy,
    required this.quotaCap,
    required this.quotaUsed,
    required this.quotaRemaining,
    required this.inventoryRemaining,
    required this.eligibilityRequired,
    required this.deadline,
    required this.quotedAt,
    required this.basisBlockNumber,
    this.eligible,
    this.eligibilityReasonCode,
  });

  final String instanceId;
  final String walletId;
  final Launch2Side side;
  final Launch2Stage stage;
  final Decimal requestedAmount;

  /// The requested amount is above MAX; every figure below is for MAX.
  final bool exceedsMax;
  final Decimal amountIn;
  final Decimal maxIn;
  final Decimal expectedOut;
  final Decimal minOut;
  final int slippageBps;
  final Decimal taxUsd1;
  final int taxBps;
  final Decimal refundUsd1;
  final Decimal priceBeforeUsd1;
  final Decimal priceAfterUsd1;

  /// The server's executable MAX: what the MAX key puts in the field.
  final Decimal maxAmountIn;
  final Decimal maxAmountOut;
  final Launch2LimitedBy limitedBy;
  final Decimal quotaCap;
  final Decimal quotaUsed;
  final Decimal quotaRemaining;
  final Decimal inventoryRemaining;
  final bool eligibilityRequired;
  final bool? eligible;
  final String? eligibilityReasonCode;
  final DateTime deadline;
  final DateTime quotedAt;
  final BigInt basisBlockNumber;
}

enum Launch2IntentKind {
  nftMint('nft_mint'),
  buy('buy'),
  sell('sell'),

  /// A LoopDynamic round's reward claim (decision 0157). Only the
  /// `dynamic-pool/claim/prepare` route answers it.
  rewardClaim('dynamic_claim');

  const Launch2IntentKind(this.wireName);

  final String wireName;

  static Launch2IntentKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// Where a buy or a sell executes (decision 0145): the bonding curve before
/// graduation, the official pool's router after it.
enum Launch2Venue {
  curve('curve'),
  officialPool('official_pool'),

  /// A LoopDynamic Hook's reward pot (decision 0157): a claim, not a trade.
  loopDynamicRewards('loop_dynamic_rewards');

  const Launch2Venue(this.wireName);

  final String wireName;

  static Launch2Venue? tryParse(String value) {
    for (final venue in values) {
      if (venue.wireName == value) return venue;
    }
    return null;
  }
}

/// The server's unsigned transaction. The wallet gets [wire] verbatim.
@immutable
final class Launch2UnsignedTransaction {
  const Launch2UnsignedTransaction({
    required this.chainId,
    required this.to,
    required this.data,
    required this.from,
    required this.wire,
  });

  final int chainId;
  final String to;
  final String data;
  final String from;
  final Map<String, Object?> wire;
}

@immutable
final class Launch2Approval {
  const Launch2Approval({
    required this.token,
    required this.spender,
    required this.amount,
    required this.unsignedTransaction,
  });

  final String token;
  final String spender;
  final Decimal amount;
  final Launch2UnsignedTransaction unsignedTransaction;
}

/// `POST …/nft/prepare` and `POST …/trade/prepare` (contract §3.4–3.5).
/// There is no broadcast report: the lane shows the result after indexing.
@immutable
final class Launch2Intent {
  const Launch2Intent({
    required this.intentId,
    required this.kind,
    required this.expired,
    required this.instanceId,
    required this.walletId,
    required this.chainId,
    required this.contractAddress,
    required this.amountIn,
    required this.expectedOut,
    required this.minOut,
    required this.taxUsd1,
    required this.refundUsd1,
    required this.deadline,
    required this.expiresAt,
    required this.createdAt,
    required this.unsignedTransaction,
    required this.payloadDigest,
    required this.snapshotBlockNumber,
    required this.simulationStatus,
    required this.valueUsd,
    required this.signingAllowed,
    required this.payloadMatchesReview,
    this.approval,
    this.simulationReasonCode,
    this.signingReasonCode,
    this.venue = Launch2Venue.curve,
    this.taxBps,
    this.taxMeme,
    this.dynamicTaxBps,
  });

  final String intentId;
  final Launch2IntentKind kind;

  /// The curve, or the official pool's router (decision 0145).
  final Launch2Venue venue;

  /// The tax the trade pays, when the intent's own quote names it; the
  /// curve's is the template's 10%.
  final int? taxBps;

  /// An official-pool buy pays its tax in MEME (taken from the output), not
  /// in USD1; the pool prepare's quote names it.
  final Decimal? taxMeme;

  /// Decision 0159 · a LoopDynamic sell: the dynamic tax its quote priced on
  /// top of [taxBps] (`quote.dynamic.dynamicTaxBps`); [taxUsd1] is then the
  /// base and the dynamic tax together. `null` everywhere else.
  final int? dynamicTaxBps;
  final bool expired;
  final String instanceId;
  final String walletId;
  final String chainId;
  final String contractAddress;
  final Decimal amountIn;
  final Decimal expectedOut;
  final Decimal minOut;
  final Decimal taxUsd1;
  final Decimal refundUsd1;
  final DateTime deadline;
  final DateTime expiresAt;
  final DateTime createdAt;
  final Launch2UnsignedTransaction unsignedTransaction;
  final Launch2Approval? approval;
  final String payloadDigest;
  final BigInt snapshotBlockNumber;

  /// `passed`, `reverted` or `unavailable`.
  final String simulationStatus;
  final String? simulationReasonCode;
  final String valueUsd;
  final bool signingAllowed;
  final String? signingReasonCode;

  /// The transactions the wallet would get say what the reviewed fields say:
  /// the main call goes to [contractAddress] with the published calldata and
  /// any approval names this token and this spender.
  final bool payloadMatchesReview;

  bool canSignAt(DateTime now) =>
      !expired && signingAllowed && expiresAt.isAfter(now);
}

@immutable
final class Launch2BuybackLive {
  const Launch2BuybackLive({
    required this.paused,
    required this.escrowRecordedUsd1,
    required this.escrowSpentUsd1,
    required this.escrowAvailableUsd1,
    this.lastSuccessfulAt,
    this.nextOrderUsd1,
    this.nextOrderBlockedReason,
  });

  final bool paused;
  final DateTime? lastSuccessfulAt;
  final Decimal escrowRecordedUsd1;
  final Decimal escrowSpentUsd1;
  final Decimal escrowAvailableUsd1;
  final Decimal? nextOrderUsd1;

  /// Why the next 100 USD1 order would not go through now, or `null`.
  final String? nextOrderBlockedReason;
}

/// `GET /v2/launch2/instances/{id}/buybacks`.
@immutable
final class Launch2BuybackPage {
  const Launch2BuybackPage({
    required this.instanceId,
    required this.summary,
    required this.buybacks,
    this.live,
    this.liveUnavailableReason,
    this.nextCursor,
  });

  final String instanceId;
  final Launch2BuybackSummary summary;
  final Launch2BuybackLive? live;
  final String? liveUnavailableReason;
  final List<Launch2BuybackRecord> buybacks;
  final String? nextCursor;
}

/// One instance the account touched (`GET /v2/launch2/me/positions`).
@immutable
final class Launch2Position {
  const Launch2Position({
    required this.instanceId,
    required this.name,
    required this.ticker,
    required this.memeAddress,
    required this.stage,
    required this.walletId,
    required this.nftHeld,
    required this.snapshotMember,
    required this.curve,
    this.logoUrl,
    this.mintedTokenId,
    this.lastActivityAt,
    this.holding,
  });

  final String instanceId;
  final String name;
  final String ticker;
  final String? logoUrl;
  final String memeAddress;
  final Launch2Stage stage;
  final String walletId;
  final BigInt? mintedTokenId;
  final int nftHeld;
  final bool snapshotMember;
  final Launch2CurvePosition curve;
  final DateTime? lastActivityAt;

  /// Decision 0148: balances and own pool trades; `null` from an older
  /// server.
  final Launch2WalletHolding? holding;
}

@immutable
final class Launch2Positions {
  const Launch2Positions({required this.items});

  final List<Launch2Position> items;
}
