import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';

// ---------------------------------------------------------------------------
// MEME curve launchpad models (client decision 0120, loop-api decision 0101)
// ---------------------------------------------------------------------------
//
// Number discipline (AGENTS rule 25, contract §2):
//
// * raw amounts — balances, `curve.*`, `out`, `fee`, `minOut`, allowances — are
//   18-decimal smallest-unit integer strings. They stay [BigInt] here and are
//   turned into a [Decimal] only to be printed.
// * prices and market caps are already-divided USD1 decimal strings and are
//   [Decimal] here.
// * basis points are integers.
//
// No `double` appears in this file.

/// Both USD1 and every MEME token carry 18 decimals (docs/10 §1).
const int memeDecimals = 18;

/// The exact value of one raw 18-decimal integer.
Decimal memeUnits(BigInt raw) => Decimal.fromBigInt(raw).shift(-memeDecimals);

/// The whole-unit decimal string the server accepts for one raw amount:
/// no exponent, no trailing zeros, at most 18 decimals.
String memeDecimalString(BigInt raw) {
  final negative = raw.isNegative;
  final digits = raw.abs().toString().padLeft(memeDecimals + 1, '0');
  final whole = digits.substring(0, digits.length - memeDecimals);
  final fraction = digits
      .substring(digits.length - memeDecimals)
      .replaceFirst(RegExp(r'0+$'), '');
  final body = fraction.isEmpty ? whole : '$whole.$fraction';
  return negative ? '-$body' : body;
}

final RegExp _memeAmountPattern = RegExp(
  r'^(0|[1-9][0-9]{0,40})(\.[0-9]{1,18})?$',
);

/// The raw value of an amount typed in whole units, or `null` when the text
/// is not a positive amount the server accepts (`^(0|[1-9]\d{0,40})(\.\d{1,18})?$`).
BigInt? memeRawFromInput(String? text) {
  final value = text?.trim();
  if (value == null || !_memeAmountPattern.hasMatch(value)) return null;
  final parts = value.split('.');
  final fraction = parts.length == 2 ? parts[1] : '';
  final raw = BigInt.parse(
    '${parts[0]}${fraction.padRight(memeDecimals, '0')}',
  );
  return raw > BigInt.zero ? raw : null;
}

/// The four chips of the launchpad list (contract §3).
enum MemeListTab {
  fresh('new', '新发'),
  hot('hot', '热门'),
  graduating('graduating', '快打满'),
  graduated('graduated', '已毕业');

  const MemeListTab(this.wireName, this.label);

  final String wireName;
  final String label;

  static MemeListTab? tryParse(String value) {
    for (final tab in values) {
      if (tab.wireName == value) return tab;
    }
    return null;
  }
}

/// Where a token stands (contract §10).
enum MemeTokenStatus {
  draft('draft'),
  pendingChain('pending_chain'),
  trading('trading'),
  full('full'),
  graduated('graduated'),
  paused('paused');

  const MemeTokenStatus(this.wireName);

  final String wireName;

  static MemeTokenStatus? tryParse(String value) {
    for (final status in values) {
      if (status.wireName == value) return status;
    }
    return null;
  }
}

/// Where a row's price came from.
enum MemePriceSource {
  loopCurve('loop_curve', 'LOOP 曲线'),
  dexscreener('dexscreener', 'DexScreener'),

  /// A graduated token's PancakeSwap pool price, read from `slot0` when no
  /// market provider prices it (loop-api S116b).
  poolSlot0('pool_slot0', '池子推算');

  const MemePriceSource(this.wireName, this.label);

  final String wireName;
  final String label;

  static MemePriceSource? tryParse(String value) {
    for (final source in values) {
      if (source.wireName == value) return source;
    }
    return null;
  }
}

/// A public profile the server attached to a token, a trade or a holder.
@immutable
final class MemeAccountRef {
  const MemeAccountRef({
    required this.publicProfileId,
    this.displayName,
    this.avatarRef,
  });

  final String publicProfileId;
  final String? displayName;
  final String? avatarRef;
}

@immutable
final class MemePriceProvenance {
  const MemePriceProvenance({required this.source, required this.observedAt});

  final MemePriceSource source;
  final DateTime observedAt;
}

/// One launchpad row (contract §3).
@immutable
final class MemeTokenRow {
  const MemeTokenRow({
    required this.memeTokenId,
    required this.name,
    required this.symbol,
    required this.status,
    required this.progressBps,
    required this.volume24hUsd1,
    required this.holderCount,
    required this.tradeCount,
    required this.createdAt,
    this.tokenAddress,
    this.imageUrl,
    this.creator,
    this.priceUsd1,
    this.marketCapUsd1,
    this.change1hPct,
    this.graduatedAt,
    this.pool,
    this.priceSource,
    this.quoteUnavailableReason,
  });

  final String memeTokenId;
  final String? tokenAddress;
  final String name;
  final String symbol;
  final String? imageUrl;
  final MemeAccountRef? creator;
  final MemeTokenStatus status;

  /// Sold / 800,000,000, 0–10000.
  final int progressBps;

  /// `null` exactly when [quoteUnavailableReason] says why.
  final Decimal? priceUsd1;
  final Decimal? marketCapUsd1;

  /// The one-hour move in percent points; `null` = not applicable.
  final Decimal? change1hPct;
  final Decimal volume24hUsd1;
  final int holderCount;
  final int tradeCount;
  final DateTime createdAt;
  final DateTime? graduatedAt;
  final String? pool;
  final MemePriceProvenance? priceSource;
  final String? quoteUnavailableReason;

  bool get isGraduated => status == MemeTokenStatus.graduated;
}

@immutable
final class MemeTokenPage {
  const MemeTokenPage({
    required this.tab,
    required this.items,
    required this.nextCursor,
    required this.observedAt,
  });

  final MemeListTab tab;
  final List<MemeTokenRow> items;
  final String? nextCursor;
  final DateTime observedAt;

  /// The rows read so far followed by [next]; a row the next page repeats
  /// (the list moved under the cursor) is kept once.
  MemeTokenPage append(MemeTokenPage next) {
    final seen = <String>{for (final row in items) row.memeTokenId};
    return MemeTokenPage(
      tab: tab,
      items: List<MemeTokenRow>.unmodifiable(<MemeTokenRow>[
        ...items,
        for (final row in next.items)
          if (seen.add(row.memeTokenId)) row,
      ]),
      nextCursor: next.nextCursor,
      observedAt: next.observedAt,
    );
  }
}

/// The curve's raw state (contract §4). Every amount is 18-decimal raw.
@immutable
final class MemeCurve {
  const MemeCurve({
    required this.vUsd1,
    required this.vToken,
    required this.realUsd1,
    required this.sold,
    required this.saleSupply,
    required this.poolSupply,
    required this.totalSupply,
    required this.graduationUsd1Estimate,
    required this.tradeFeeBps,
    required this.walletCapTokens,
    required this.minBuyUsd1,
  });

  final BigInt vUsd1;
  final BigInt vToken;
  final BigInt realUsd1;
  final BigInt sold;
  final BigInt saleSupply;
  final BigInt poolSupply;
  final BigInt totalSupply;
  final BigInt graduationUsd1Estimate;
  final int tradeFeeBps;
  final BigInt walletCapTokens;
  final BigInt minBuyUsd1;

  /// What the curve raises when it fills: `realUsd1` at `sold = saleSupply`,
  /// which is `V0·S/(T0−S)` (docs/10 §2), read from the invariant the
  /// snapshot carries rather than from a constant. `null` when the snapshot
  /// cannot define it.
  BigInt? get fillTargetUsd1 {
    final k = vUsd1 * vToken;
    // Virtual reserves at the start: vToken0 = vToken + sold.
    final startToken = vToken + sold;
    final tokenAtFull = startToken - saleSupply;
    if (tokenAtFull <= BigInt.zero || startToken <= BigInt.zero) return null;
    final startUsd1 = k ~/ startToken;
    final usd1AtFull = k ~/ tokenAtFull;
    final raised = usd1AtFull - startUsd1;
    return raised > BigInt.zero ? raised : null;
  }

  /// What [usd1In] (fee included) would buy on this snapshot, by the curve's
  /// own formula (docs/10 §2): `net = in − in·fee`, `out = vToken − k /
  /// (vUsd1 + net)`, rounded down, capped at what is left to sell.
  ///
  /// It is an estimate for a draft that has no on-chain quote yet; the
  /// signing sheet shows the server's own `expectedOut` and `minOut`.
  ({BigInt out, BigInt fee}) estimateBuy(BigInt usd1In) {
    if (usd1In <= BigInt.zero || vUsd1 <= BigInt.zero) {
      return (out: BigInt.zero, fee: BigInt.zero);
    }
    final fee = usd1In * BigInt.from(tradeFeeBps) ~/ BigInt.from(10000);
    final net = usd1In - fee;
    final k = vUsd1 * vToken;
    var out = vToken - (k ~/ (vUsd1 + net));
    final left = saleSupply - sold;
    if (out > left) out = left;
    if (out < BigInt.zero) out = BigInt.zero;
    return (out: out, fee: fee);
  }
}

@immutable
final class MemeLinks {
  const MemeLinks({this.twitter, this.telegram, this.website});

  final String? twitter;
  final String? telegram;
  final String? website;

  bool get isEmpty => twitter == null && telegram == null && website == null;
}

@immutable
final class MemeContractFacts {
  const MemeContractFacts({
    required this.address,
    required this.version,
    required this.chainId,
    required this.chainReference,
    this.explorerUrl,
  });

  final String address;
  final String version;
  final String chainId;
  final int chainReference;
  final String? explorerUrl;
}

/// The caller's active wallet read on chain (contract §4 `viewer`).
@immutable
final class MemeViewer {
  const MemeViewer({
    required this.walletId,
    required this.balance,
    required this.usd1Balance,
    required this.allowanceUsd1,
    required this.allowanceToken,
    this.walletCapRemaining,
  });

  final String walletId;
  final BigInt balance;
  final BigInt usd1Balance;

  /// `null` after graduation: there is no cap any more.
  final BigInt? walletCapRemaining;
  final BigInt allowanceUsd1;
  final BigInt allowanceToken;
}

@immutable
final class MemeGraduation {
  const MemeGraduation({
    required this.at,
    this.pool,
    this.lpBurnTx,
    this.lpTokenId,
    this.usd1ToPool,
    this.tokensToPool,
    this.feeUsd1,
    this.residualUsd1,
    this.residualTokens,
  });

  final DateTime at;
  final String? pool;
  final String? lpBurnTx;
  final String? lpTokenId;
  final BigInt? usd1ToPool;
  final BigInt? tokensToPool;
  final BigInt? feeUsd1;
  final BigInt? residualUsd1;
  final BigInt? residualTokens;

  bool get hasResidual => residualUsd1 != null || residualTokens != null;
}

/// One token as `GET /v2/meme/tokens/{id}` describes it (contract §4).
/// Operator listing decision (loop-api decision 0102): `hidden` removes the
/// token from the launchpad lists and `category=meme`; the detail stays
/// readable and carries the operator's user-facing sentence.
enum MemeListing {
  listed('listed'),
  hidden('hidden');

  const MemeListing(this.wireName);

  final String wireName;

  static MemeListing? tryParse(String value) {
    for (final listing in values) {
      if (listing.wireName == value) return listing;
    }
    return null;
  }
}

@immutable
final class MemeListingReason {
  const MemeListingReason({this.reasonCode, this.reasonText});

  final String? reasonCode;
  final String? reasonText;
}

@immutable
final class MemeTokenDetail {
  const MemeTokenDetail({
    required this.row,
    required this.description,
    required this.links,
    required this.metadataHash,
    required this.vanity,
    required this.curve,
    required this.contract,
    required this.observedAt,
    this.salt,
    this.predictedAddress,
    this.viewer,
    this.viewerUnavailableReason,
    this.graduation,
    this.listing = MemeListing.listed,
    this.listingReason,
  });

  final MemeTokenRow row;
  final String description;
  final MemeLinks links;
  final String metadataHash;
  final String? salt;
  final String? predictedAddress;
  final bool vanity;
  final MemeCurve curve;
  final MemeContractFacts contract;
  final MemeViewer? viewer;

  /// Why [viewer] is absent, when the server said. A draft carries neither.
  final String? viewerUnavailableReason;
  final MemeGraduation? graduation;

  /// Decision 0102. `hidden` exactly when [listingReason] is present.
  final MemeListing listing;
  final MemeListingReason? listingReason;

  /// `source.observedAt` (`loop_indexer`).
  final DateTime observedAt;

  String get memeTokenId => row.memeTokenId;
  MemeTokenStatus get status => row.status;
  bool get isHidden => listing == MemeListing.hidden;
}

@immutable
final class MemeTrade {
  const MemeTrade({
    required this.txHash,
    required this.logIndex,
    required this.blockNumber,
    required this.wallet,
    required this.isBuy,
    required this.usd1Amount,
    required this.tokenAmount,
    required this.feeUsd1,
    required this.priceAfter,
    required this.at,
    this.account,
  });

  final String txHash;
  final int logIndex;
  final String blockNumber;
  final String wallet;
  final MemeAccountRef? account;
  final bool isBuy;

  /// Wallet side: a buy is what was paid (fee in, refund out); a sell is
  /// what arrived (fee out).
  final BigInt usd1Amount;
  final BigInt tokenAmount;
  final BigInt feeUsd1;
  final Decimal priceAfter;
  final DateTime at;

  String get key => '$txHash:$logIndex';
}

@immutable
final class MemeTradePage {
  const MemeTradePage({
    required this.items,
    required this.nextCursor,
    required this.observedAt,
  });

  final List<MemeTrade> items;
  final String? nextCursor;
  final DateTime observedAt;

  MemeTradePage append(MemeTradePage next) {
    final seen = <String>{for (final trade in items) trade.key};
    return MemeTradePage(
      items: List<MemeTrade>.unmodifiable(<MemeTrade>[
        ...items,
        for (final trade in next.items)
          if (seen.add(trade.key)) trade,
      ]),
      nextCursor: next.nextCursor,
      observedAt: next.observedAt,
    );
  }
}

@immutable
final class MemeHolder {
  const MemeHolder({
    required this.wallet,
    required this.balance,
    required this.shareBps,
    required this.isCreator,
    required this.isViewer,
    this.account,
  });

  final String wallet;
  final MemeAccountRef? account;
  final BigInt balance;

  /// Of the 1,000,000,000 total supply.
  final int shareBps;
  final bool isCreator;
  final bool isViewer;
}

@immutable
final class MemeHolderPage {
  const MemeHolderPage({
    required this.holderCount,
    required this.items,
    required this.nextCursor,
    required this.observedAt,
    this.frozenAt,
  });

  final int holderCount;

  /// Non-null after graduation: 「分布冻结于毕业时」.
  final DateTime? frozenAt;
  final List<MemeHolder> items;
  final String? nextCursor;
  final DateTime observedAt;

  MemeHolderPage append(MemeHolderPage next) {
    final seen = <String>{for (final holder in items) holder.wallet};
    return MemeHolderPage(
      holderCount: next.holderCount,
      frozenAt: next.frozenAt,
      items: List<MemeHolder>.unmodifiable(<MemeHolder>[
        ...items,
        for (final holder in next.items)
          if (seen.add(holder.wallet)) holder,
      ]),
      nextCursor: next.nextCursor,
      observedAt: next.observedAt,
    );
  }
}

/// The six chart intervals of the curve (contract §5.2).
enum MemeCandleInterval {
  oneMinute('1m', '1分', LoopCandleInterval.fifteenMinutes),
  fiveMinutes('5m', '5分', LoopCandleInterval.fifteenMinutes),
  fifteenMinutes('15m', '15分', LoopCandleInterval.fifteenMinutes),
  oneHour('1h', '1时', LoopCandleInterval.oneHour),
  fourHours('4h', '4时', LoopCandleInterval.fourHours),
  oneDay('1d', '1日', LoopCandleInterval.oneDay);

  const MemeCandleInterval(this.wireName, this.label, this.axis);

  final String wireName;
  final String label;

  /// The shared chart's interval whose time labels fit this bucket: the
  /// three intraday widths all read as a clock.
  final LoopCandleInterval axis;

  Duration get width => switch (this) {
    MemeCandleInterval.oneMinute => const Duration(minutes: 1),
    MemeCandleInterval.fiveMinutes => const Duration(minutes: 5),
    MemeCandleInterval.fifteenMinutes => const Duration(minutes: 15),
    MemeCandleInterval.oneHour => const Duration(hours: 1),
    MemeCandleInterval.fourHours => const Duration(hours: 4),
    MemeCandleInterval.oneDay => const Duration(days: 1),
  };

  static MemeCandleInterval? tryParse(String value) {
    for (final interval in values) {
      if (interval.wireName == value) return interval;
    }
    return null;
  }
}

@immutable
final class MemeCandleSeries {
  const MemeCandleSeries({
    required this.interval,
    required this.candles,
    required this.observedAt,
    this.frozenAt,
  });

  final MemeCandleInterval interval;

  /// Buckets with trades, oldest first; empty buckets are not filled.
  final List<LoopCandle> candles;
  final DateTime? frozenAt;
  final DateTime observedAt;
}

enum MemeTradeSide {
  buy('buy'),
  sell('sell');

  const MemeTradeSide(this.wireName);

  final String wireName;
}

/// `GET /v2/meme/quote` (contract §6).
@immutable
final class MemeQuote {
  const MemeQuote({
    required this.memeTokenId,
    required this.side,
    required this.amountIn,
    required this.out,
    required this.fee,
    required this.priceImpactBps,
    required this.priceBefore,
    required this.priceAfter,
    required this.minOutAtDefaultSlippage,
    required this.walletCapHit,
    required this.belowMinBuy,
    required this.basisFromChain,
    required this.observedAt,
    this.refund,
    this.walletCapRemaining,
  });

  final String memeTokenId;
  final MemeTradeSide side;
  final BigInt amountIn;
  final BigInt out;
  final BigInt fee;

  /// A buy that fills the curve returns this much USD1.
  final BigInt? refund;
  final int priceImpactBps;
  final Decimal priceBefore;
  final Decimal priceAfter;
  final BigInt minOutAtDefaultSlippage;
  final bool walletCapHit;
  final BigInt? walletCapRemaining;
  final bool belowMinBuy;

  /// `basis.source == chain`; otherwise the index snapshot, which may trail.
  final bool basisFromChain;
  final DateTime observedAt;

  bool get fillsCurve => refund != null && refund! > BigInt.zero;
}

enum MemeIntentKind {
  create('create'),
  buy('buy'),
  sell('sell');

  const MemeIntentKind(this.wireName);

  final String wireName;

  static MemeIntentKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.wireName == value) return kind;
    }
    return null;
  }
}

/// The intent's server state (contract §8.4).
enum MemeIntentState {
  prepared('prepared', '待签名'),
  broadcastReported('broadcast_reported', '已广播，等待确认'),
  confirmed('confirmed', '已确认'),
  failed('failed', '未成功'),
  expired('expired', '已过期');

  const MemeIntentState(this.wireName, this.label);

  final String wireName;
  final String label;

  bool get isTerminal =>
      this == MemeIntentState.confirmed ||
      this == MemeIntentState.failed ||
      this == MemeIntentState.expired;

  static MemeIntentState? tryParse(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    return null;
  }
}

/// One `eth_sendTransaction` parameter exactly as the server sent it.
@immutable
final class MemeUnsignedTransaction {
  const MemeUnsignedTransaction({
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

  /// The verbatim object; the wallet receives this and nothing else.
  final Map<String, Object?> wire;
}

/// The exact-amount approval in front of a buy, a sell or a first buy.
@immutable
final class MemeApproval {
  const MemeApproval({
    required this.token,
    required this.spender,
    required this.amount,
    required this.unsignedTransaction,
  });

  final String token;
  final String spender;
  final BigInt amount;
  final MemeUnsignedTransaction unsignedTransaction;
}

@immutable
final class MemeIntentPolicy {
  const MemeIntentPolicy({required this.canaryMaxUsd, required this.valueUsd});

  final String canaryMaxUsd;
  final String valueUsd;
}

/// One create / buy / sell intent (contract §8.1).
@immutable
final class MemeIntent {
  const MemeIntent({
    required this.memeIntentId,
    required this.kind,
    required this.state,
    required this.memeTokenId,
    required this.walletId,
    required this.chainId,
    required this.contractAddress,
    required this.usd1Amount,
    required this.tokenAmount,
    required this.expectedOut,
    required this.minOut,
    required this.fee,
    required this.refund,
    required this.deadline,
    required this.expiresAt,
    required this.createdAt,
    required this.unsignedTransaction,
    required this.payloadDigest,
    required this.snapshotBlockNumber,
    required this.simulationStatus,
    required this.policy,
    required this.signingAllowed,
    required this.payloadMatchesReview,
    this.tokenAddress,
    this.predictedAddress,
    this.approval,
    this.transactionHash,
    this.reasonCode,
    this.simulationReasonCode,
    this.signingReasonCode,
  });

  final String memeIntentId;
  final MemeIntentKind kind;
  final MemeIntentState state;
  final String memeTokenId;
  final String walletId;
  final String chainId;
  final String contractAddress;
  final String? tokenAddress;
  final String? predictedAddress;
  final BigInt usd1Amount;
  final BigInt tokenAmount;
  final BigInt expectedOut;
  final BigInt minOut;
  final BigInt fee;
  final BigInt refund;
  final DateTime deadline;
  final DateTime expiresAt;
  final DateTime createdAt;
  final MemeUnsignedTransaction unsignedTransaction;
  final MemeApproval? approval;
  final String payloadDigest;
  final String snapshotBlockNumber;
  final String? transactionHash;
  final String? reasonCode;

  /// `passed` / `reverted` / `unavailable`.
  final String simulationStatus;
  final String? simulationReasonCode;
  final MemeIntentPolicy policy;
  final bool signingAllowed;
  final String? signingReasonCode;

  /// The transactions describe the reviewed calls: the main one goes to the
  /// curve with the reviewed calldata on the reviewed chain, and the approval
  /// (when present) goes to its token with its own calldata. Read by the
  /// signer; a mismatch is refused before any wallet opens.
  final bool payloadMatchesReview;

  /// The server permits a signature and the window is still open. Only the
  /// expiry is evaluated on the device; permission is the server's.
  bool canSignAt(DateTime now) =>
      state == MemeIntentState.prepared &&
      signingAllowed &&
      expiresAt.isAfter(now);
}

/// What the creation form submits (contract §7).
@immutable
final class MemeCreateDraft {
  const MemeCreateDraft({
    required this.name,
    required this.symbol,
    this.description = '',
    this.imageMediaId,
    this.links = const MemeLinks(),
  });

  final String name;
  final String symbol;
  final String description;
  final String? imageMediaId;
  final MemeLinks links;

  /// Two drafts that would produce the same server draft.
  String get signature => <String?>[
    name,
    symbol,
    description,
    imageMediaId,
    links.twitter,
    links.telegram,
    links.website,
  ].join('\u0000');
}

/// `POST /v2/media/community-logos`: the picture's id and its address.
@immutable
final class MemeUploadedImage {
  const MemeUploadedImage({required this.mediaId, required this.url});

  final String mediaId;
  final String url;
}
