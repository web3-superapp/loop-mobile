import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';

// ---------------------------------------------------------------------------
// market · GET /v2/market/overview
// ---------------------------------------------------------------------------

/// One asset row with its price facts. [asset] is `null` when the registry can
/// no longer read it; the row still exists so the user can act on it.
@immutable
final class MarketAssetRow {
  const MarketAssetRow({
    required this.assetId,
    required this.asset,
    required this.price,
    required this.priceChange24h,
    this.volume24h,
    this.liquidityUsd,
    this.logoUrl,
  });

  final String assetId;
  final LoopAssetSummary? asset;
  final LoopFact price;
  final LoopFact priceChange24h;

  /// The registry's published artwork for this asset, when it published one.
  ///
  /// The wiring point for the `logo` field of the asset contract (S78c). It
  /// stays `null` until the adapter reads it, and a `null` is not a failure:
  /// the row falls back to the bundled artwork and then to the monogram, the
  /// way every LOOP identity tile already does. The client validates the
  /// address itself (`loopRemoteLogoUri`) rather than trusting the string.
  final String? logoUrl;

  /// Only the trending rows carry these two.
  final LoopFact? volume24h;
  final LoopFact? liquidityUsd;

  /// Display text for the row. Falls back to the truncated CAIP identity so a
  /// missing registry row never becomes a guessed ticker.
  String get displayName => asset?.symbol ?? loopTruncatedAssetId(assetId);
}

sealed class MarketWatchlistBlock {
  const MarketWatchlistBlock();
}

final class MarketWatchlistAvailable extends MarketWatchlistBlock {
  MarketWatchlistAvailable({
    required this.version,
    required List<MarketAssetRow> items,
  }) : items = List<MarketAssetRow>.unmodifiable(items);

  final int version;
  final List<MarketAssetRow> items;
}

final class MarketWatchlistUnavailable extends MarketWatchlistBlock {
  const MarketWatchlistUnavailable(this.reasonCode);

  final String reasonCode;
}

/// The ordering rule behind a trending list. It is always shown so the list
/// never reads as an editorial recommendation.
@immutable
final class MarketTrendingRules {
  const MarketTrendingRules({
    required this.configVersion,
    required this.effectiveAt,
    required this.ordering,
  });

  final String configVersion;
  final DateTime effectiveAt;
  final String ordering;

  String get orderingLabel => switch (ordering) {
    'dexscreener_volume_h24_desc' => '按 DexScreener 24h 成交量排序',
    _ => '排序规则 $ordering',
  };
}

sealed class MarketTrendingBlock {
  const MarketTrendingBlock();
}

final class MarketTrendingAvailable extends MarketTrendingBlock {
  MarketTrendingAvailable({
    required this.recommendationId,
    required this.rules,
    required List<MarketAssetRow> items,
  }) : items = List<MarketAssetRow>.unmodifiable(items);

  /// Regenerated on every response; reported back when the client tells the
  /// server which ordering the user saw.
  final String recommendationId;
  final MarketTrendingRules rules;
  final List<MarketAssetRow> items;
}

final class MarketTrendingUnavailable extends MarketTrendingBlock {
  const MarketTrendingUnavailable(this.reasonCode);

  final String reasonCode;
}

/// The overview's own word on the new-pairs page (decision 0053).
///
/// `available` now means the new-pairs fact is readable *at this moment*, not
/// that a provider is configured: a provider that is on but unreadable answers
/// unavailable here with the same reason code the new-pairs page reports.
sealed class MarketOverviewNewPairs {
  const MarketOverviewNewPairs();
}

final class MarketOverviewNewPairsAvailable extends MarketOverviewNewPairs {
  const MarketOverviewNewPairsAvailable(this.omittedCount);

  /// Provider rows the new-pairs page cannot list, from the same cached fact
  /// it reads (`newPairs.omittedCount`). Normally 0; when it is not, the card
  /// says so rather than letting a partial list read as the whole answer.
  final int omittedCount;
}

final class MarketOverviewNewPairsUnavailable extends MarketOverviewNewPairs {
  const MarketOverviewNewPairsUnavailable(this.reasonCode);

  final String reasonCode;
}

/// `GET /v2/market/overview` — the `market` tab.
@immutable
final class MarketOverview {
  const MarketOverview({
    required this.watchlist,
    required this.trending,
    required this.newPairs,
    required this.smartMoney,
    required this.observedAt,
  });

  final MarketWatchlistBlock watchlist;
  final MarketTrendingBlock trending;
  final MarketOverviewNewPairs newPairs;
  final LoopUnavailable smartMoney;
  final DateTime observedAt;
}

// ---------------------------------------------------------------------------
// token · GET /v2/market/assets/{assetId}
// ---------------------------------------------------------------------------

/// The deepest DexScreener pair with this asset as base. Every price fact on
/// the page comes from it.
@immutable
final class MarketPrimaryPair {
  MarketPrimaryPair({
    required this.pairAddress,
    required this.dexId,
    required List<String> labels,
    required this.quoteTokenAddress,
    required this.quoteTokenSymbol,
    required this.pairCreatedAt,
  }) : labels = List<String>.unmodifiable(labels);

  final String pairAddress;
  final String dexId;
  final List<String> labels;
  final String quoteTokenAddress;
  final String quoteTokenSymbol;
  final DateTime? pairCreatedAt;
}

sealed class MarketCommunityBlock {
  const MarketCommunityBlock();
}

final class MarketCommunityBound extends MarketCommunityBlock {
  const MarketCommunityBound({
    required this.communityId,
    required this.name,
    required this.slug,
    required this.memberCount,
  });

  final String communityId;
  final String name;
  final String slug;
  final int memberCount;
}

final class MarketCommunityUnavailable extends MarketCommunityBlock {
  const MarketCommunityUnavailable(this.reasonCode);

  final String reasonCode;
}

/// One security fact with its own provenance. The backend gives no score, no
/// rating and no conclusion; the page renders "X —— 来源 Y，观察于 Z".
@immutable
final class MarketSecurityFact {
  const MarketSecurityFact({
    required this.fact,
    required this.value,
    required this.source,
    required this.observedAt,
  });

  final String fact;
  final String value;
  final LoopFactSource source;
  final DateTime observedAt;
}

/// zh-CN sentence for one GoPlus security key. An unknown key is rendered with
/// its raw key rather than an invented meaning.
String marketSecurityFactText(MarketSecurityFact fact) {
  final isTrue = fact.value == 'true';
  final isFalse = fact.value == 'false';
  String yesNo(String whenTrue, String whenFalse) => isTrue
      ? whenTrue
      : (isFalse ? whenFalse : '${fact.fact} = ${fact.value}');
  return switch (fact.fact) {
    'openSource' => yesNo('合约已验证开源', '合约未验证开源'),
    'proxy' => yesNo('是代理合约', '不是代理合约'),
    'mintable' => yesNo('检测到 mint 函数', '未检测到 mint 函数'),
    'ownershipTakeBack' => yesNo('检测到所有权可收回', '未检测到所有权可收回'),
    'ownerChangeBalance' => yesNo('所有者可改动余额', '所有者不可改动余额'),
    'hiddenOwner' => yesNo('检测到隐藏所有者', '未检测到隐藏所有者'),
    'selfDestruct' => yesNo('检测到自毁函数', '未检测到自毁函数'),
    'externalCall' => yesNo('检测到外部调用', '未检测到外部调用'),
    'honeypot' => yesNo('检测到蜜罐特征', '未检测到蜜罐特征'),
    'transferPausable' => yesNo('转账可被暂停', '转账不可被暂停'),
    'blacklist' => yesNo('检测到黑名单函数', '未检测到黑名单函数'),
    'whitelist' => yesNo('检测到白名单函数', '未检测到白名单函数'),
    'antiWhale' => yesNo('检测到持仓上限', '未检测到持仓上限'),
    'tradingCooldown' => yesNo('检测到交易冷却', '未检测到交易冷却'),
    'cannotSellAll' => yesNo('不能一次卖出全部', '可以一次卖出全部'),
    'listedOnDex' => yesNo('已在 DEX 上架', '未在 DEX 上架'),
    'buyTax' => '买入税 ${fact.value}',
    'sellTax' => '卖出税 ${fact.value}',
    _ => '${fact.fact} = ${fact.value}',
  };
}

sealed class MarketSecurityBlock {
  const MarketSecurityBlock();
}

final class MarketSecurityAvailable extends MarketSecurityBlock {
  MarketSecurityAvailable({
    required this.source,
    required this.fetchedAt,
    required this.ttlSeconds,
    required this.quality,
    required this.reasonCode,
    required List<MarketSecurityFact> facts,
  }) : facts = List<MarketSecurityFact>.unmodifiable(facts);

  final LoopFactSource source;
  final DateTime fetchedAt;
  final int ttlSeconds;
  final LoopFactQuality quality;
  final String? reasonCode;
  final List<MarketSecurityFact> facts;
}

final class MarketSecurityUnavailable extends MarketSecurityBlock {
  const MarketSecurityUnavailable(this.reasonCode);

  final String reasonCode;
}

/// The `asset` block of `GET /v2/market/assets/{assetId}`.
///
/// §4a of the market contract answers a contract address in one of two
/// shapes, and they are not the same document with fields missing:
///
/// * something described the contract — the registry, or a provider looked it
///   up for this request alone — so there is a settled identity to print;
/// * nothing could describe it at this moment, and the payload carries only
///   `status` and the server's `reasonCode`. There is no `assetId`, no
///   `address`, no ticker and no precision in it at all.
///
/// Folding the second into a record of nullable fields would let a surface
/// read a `symbol` that was never reported, so the two are separate types and
/// a surface must say which one it is holding.
sealed class MarketAssetIdentity {
  const MarketAssetIdentity();

  /// The CAIP identity this answer is about. On the unavailable branch it is
  /// the id the request was made with, because the payload states none.
  String get assetId;

  /// The identity facts, when something reported them. `null` is the whole
  /// point of the unavailable branch and never a placeholder to fill in.
  LoopChainAsset? get settled;
}

/// The registry's row, or a provider's lookup: either way a named identity.
final class MarketAssetIdentitySettled extends MarketAssetIdentity {
  const MarketAssetIdentitySettled(this.asset);

  final LoopChainAsset asset;

  @override
  String get assetId => asset.assetId;

  @override
  LoopChainAsset get settled => asset;
}

/// No provider could describe this address for this request.
///
/// The address is all there is to show. No ticker may be invented for the
/// slot, and the server's own [reasonCode] is what the surface states.
final class MarketAssetIdentityUnavailable extends MarketAssetIdentity {
  const MarketAssetIdentityUnavailable({
    required this.assetId,
    required this.reasonCode,
  });

  @override
  final String assetId;

  final String reasonCode;

  @override
  LoopChainAsset? get settled => null;
}

/// The heading one surface prints for [identity].
///
/// An identity nobody reported leaves the truncated address to speak for
/// itself, exactly as a provider that reported no ticker does.
String marketAssetIdentityLabel(MarketAssetIdentity identity) =>
    switch (identity) {
      MarketAssetIdentitySettled(:final asset) => loopAssetSymbolLabel(asset),
      MarketAssetIdentityUnavailable(:final assetId) => loopTruncatedAssetId(
        assetId,
      ),
    };

/// The phrase every surface leads with when nothing could describe the
/// contract. It says what happened to the read, not what the address is: an
/// address LOOP cannot read is not an address that was judged.
const String marketAssetUnavailableLead = '这个地址暂时读不到';

/// For a surface whose heading is already the address: the lead, then the
/// server's own reason for having no answer.
String marketAssetUnavailableSentence(
  MarketAssetIdentityUnavailable identity,
) => '$marketAssetUnavailableLead · ${loopReasonCodeText(identity.reasonCode)}';

/// For a surface that renders the reason on a line of its own: the lead, then
/// the address that was asked about.
String marketAssetUnavailableHeading(MarketAssetIdentityUnavailable identity) =>
    '$marketAssetUnavailableLead · ${loopTruncatedAssetId(identity.assetId)}';

/// `GET /v2/market/assets/{assetId}` — the `token` page.
@immutable
final class MarketAssetDetail {
  const MarketAssetDetail({
    required this.asset,
    required this.capability,
    this.logoUrl,
    required this.price,
    required this.priceChange24h,
    required this.liquidityUsd,
    required this.volume24h,
    required this.marketCap,
    required this.fdv,
    required this.primaryPair,
    required this.community,
    required this.security,
    required this.holderCount,
  });

  final MarketAssetIdentity asset;

  /// The registry's published artwork, or `null` when the server said it has
  /// none. See `MarketAssetRow.logoUrl`.
  final String? logoUrl;
  final LoopAssetCapability capability;
  final LoopFact price;
  final LoopFact priceChange24h;
  final LoopFact liquidityUsd;
  final LoopFact volume24h;
  final LoopFact marketCap;
  final LoopFact fdv;
  final MarketPrimaryPair? primaryPair;
  final MarketCommunityBlock community;
  final MarketSecurityBlock security;
  final LoopFact holderCount;

  /// The CAIP identity this document answers for.
  String get assetId => asset.assetId;
}

// ---------------------------------------------------------------------------
// candles · GET /v2/market/assets/{assetId}/candles
// ---------------------------------------------------------------------------

enum LoopCandleInterval {
  fifteenMinutes('15m', '15m'),
  oneHour('1h', '1H'),
  fourHours('4h', '4H'),
  oneDay('1d', '1D'),
  oneWeek('1w', '1W');

  const LoopCandleInterval(this.wireName, this.label);

  final String wireName;
  final String label;

  static LoopCandleInterval? tryParse(String value) {
    for (final interval in values) {
      if (interval.wireName == value) return interval;
    }
    return null;
  }
}

/// One OHLCV bucket. Values stay `Decimal`; the chart normalises to `double`
/// only inside its painter.
@immutable
final class LoopCandle {
  const LoopCandle({
    required this.openTime,
    required this.closeTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.swapCount,
    required this.isOpen,
  });

  final DateTime openTime;
  final DateTime closeTime;
  final Decimal open;
  final Decimal high;
  final Decimal low;
  final Decimal close;
  final Decimal volume;
  final int? swapCount;

  /// The bucket has not closed yet: its close/high/low will still move, so it
  /// is drawn as "进行中" and must never be cached.
  final bool isOpen;

  bool get isUp => close > open;
  bool get isDown => close < open;
}

/// Whether LOOP indexes the pool the chart was drawn from.
///
/// `registry` is a pool LOOP has registered and indexed — the same pool that
/// backs `/trades` and the derived candles. `provider` is the top pool the
/// answering source reported for an asset LOOP has no registered pool for
/// (decision 0064): the chart exists, the trade feed does not, and the page
/// must not let the first imply the second.
enum LoopCandlePoolOrigin {
  registry('registry'),
  provider('provider');

  const LoopCandlePoolOrigin(this.wireName);

  final String wireName;

  static LoopCandlePoolOrigin? tryParse(String value) {
    for (final origin in values) {
      if (origin.wireName == value) return origin;
    }
    return null;
  }
}

@immutable
final class LoopCandlePool {
  const LoopCandlePool({
    required this.address,
    required this.protocol,
    required this.origin,
    required this.quoteAssetId,
    required this.quoteSymbol,
  });

  final String address;
  final String protocol;
  final LoopCandlePoolOrigin origin;
  final String? quoteAssetId;
  final String quoteSymbol;

  /// The pool is the source's top pool, not one LOOP indexes.
  bool get isProviderPool => origin == LoopCandlePoolOrigin.provider;
}

sealed class MarketCandleBlock {
  const MarketCandleBlock();
}

final class MarketCandlesAvailable extends MarketCandleBlock {
  MarketCandlesAvailable({
    required this.quality,
    required this.source,
    required this.fetchedAt,
    required this.labelKey,
    required this.proxyAsset,
    required this.pool,
    required this.priceUnit,
    required List<LoopCandle> items,
  }) : items = List<LoopCandle>.unmodifiable(items);

  /// `derived` means LOOP aggregated on-chain swaps; the [labelKey] copy must
  /// then be rendered and the price unit is the pool's other token, not USD.
  /// `proxied` means the native asset was charted through the wrapped token
  /// named in [proxyAsset]; [labelKey] still says whether those same candles
  /// are provider OHLCV or an on-chain aggregate, so both notes can apply.
  final LoopFactQuality quality;
  final LoopFactSource source;
  final DateTime fetchedAt;
  final String? labelKey;

  /// The asset whose pool produced these candles. Non-null exactly when
  /// [quality] is `proxied`.
  final String? proxyAsset;
  final LoopCandlePool pool;
  final String priceUnit;
  final List<LoopCandle> items;

  bool get isDerived => quality == LoopFactQuality.derived;

  /// The candles belong to a different asset than the one on screen, so the
  /// page must say what it is pricing.
  bool get isProxied => quality == LoopFactQuality.proxied;

  /// The on-chain aggregate note, which a proxied series may also carry.
  bool get hasSourceLabel => labelKey != null;
}

final class MarketCandlesUnavailable extends MarketCandleBlock {
  const MarketCandlesUnavailable(this.reasonCode);

  final String reasonCode;
}

/// zh-CN copy for a candle `labelKey`. Unknown keys keep a neutral sentence.
String marketCandleLabelText(String? labelKey) => switch (labelKey) {
  'market.candles.onChainSwapAggregate' => '按成交价折算',
  null => '',
  _ => '来源标注 $labelKey',
};

/// zh-CN attribution for a candle series: who answered, and which pool was
/// charted. A provider top pool says so in the same breath, because 「来源
/// GeckoTerminal」 alone would read as if LOOP indexed that pool too, and the
/// trades tab of the same asset is then unavailable on purpose.
String marketCandleSourcePoolText(
  LoopFactSource source,
  LoopCandlePool pool,
) => switch (pool.origin) {
  LoopCandlePoolOrigin.registry =>
    '来源 ${loopFactSourceLabel(source)} · 池 ${loopTruncatedAddress(pool.address)}',
  LoopCandlePoolOrigin.provider =>
    '主池来自 ${loopFactSourceLabel(source)} · 未登记池 ${loopTruncatedAddress(pool.address)}',
};

@immutable
final class MarketCandleSeries {
  const MarketCandleSeries({
    required this.assetId,
    required this.interval,
    required this.candles,
  });

  final String assetId;
  final LoopCandleInterval interval;
  final MarketCandleBlock candles;
}

// ---------------------------------------------------------------------------
// trades · GET /v2/market/assets/{assetId}/trades
// ---------------------------------------------------------------------------

enum MarketTradeDirection {
  buy('buy'),
  sell('sell');

  const MarketTradeDirection(this.wireName);

  final String wireName;

  static MarketTradeDirection? tryParse(String value) {
    for (final direction in values) {
      if (direction.wireName == value) return direction;
    }
    return null;
  }
}

/// One indexed pool swap. The backend deliberately sends no counterparty
/// address: [isOwn] is the only identity fact, computed server-side.
@immutable
final class MarketTrade {
  const MarketTrade({
    required this.transactionHash,
    required this.logIndex,
    required this.blockNumber,
    required this.blockHash,
    required this.blockTimestamp,
    required this.confirmations,
    required this.status,
    required this.direction,
    required this.amountAsset,
    required this.amountQuote,
    required this.quoteAssetId,
    required this.quoteSymbol,
    required this.priceAfter,
    required this.poolAddress,
    required this.isOwn,
  });

  final String transactionHash;
  final int logIndex;
  final BigInt blockNumber;
  final String blockHash;
  final DateTime blockTimestamp;
  final int? confirmations;
  final LoopConfirmationStatus status;
  final MarketTradeDirection direction;
  final Decimal amountAsset;
  final Decimal amountQuote;
  final String quoteAssetId;
  final String quoteSymbol;
  final Decimal? priceAfter;
  final String poolAddress;
  final bool isOwn;

  String get tradeId => '$transactionHash:$logIndex';
}

sealed class MarketTradesBlock {
  const MarketTradesBlock();
}

final class MarketTradesAvailable extends MarketTradesBlock {
  MarketTradesAvailable({
    required this.source,
    required List<MarketTrade> items,
    required this.nextCursor,
    required this.freshness,
  }) : items = List<MarketTrade>.unmodifiable(items);

  final LoopFactSource source;
  final List<MarketTrade> items;
  final String? nextCursor;
  final LoopIndexerFreshness freshness;
}

final class MarketTradesUnavailable extends MarketTradesBlock {
  const MarketTradesUnavailable(this.reasonCode);

  final String reasonCode;
}

@immutable
final class MarketTradesPage {
  const MarketTradesPage({required this.assetId, required this.trades});

  final String assetId;
  final MarketTradesBlock trades;
}

// ---------------------------------------------------------------------------
// holders · GET /v2/market/assets/{assetId}/holders
// ---------------------------------------------------------------------------

@immutable
final class MarketHolders {
  const MarketHolders({
    required this.assetId,
    required this.holderCount,
    required this.distribution,
  });

  final String assetId;
  final LoopFact holderCount;

  /// Top holders, concentration and cluster labels all need full history and
  /// are unavailable for the whole of this step.
  final LoopUnavailable distribution;
}

// ---------------------------------------------------------------------------
// new-pairs · GET /v2/market/new-pairs
// ---------------------------------------------------------------------------

/// The EVM zero address, which a provider uses to mean the chain's own coin.
const marketZeroAddress = '0x0000000000000000000000000000000000000000';

/// How the provider identifies one pool (decision 0052).
///
/// The two forms are not interchangeable and the difference is not cosmetic: a
/// contract pool has a page of its own, a Uniswap V4 pool lives inside the
/// singleton and has none. Keeping them apart in the type is what stops a
/// 32-byte pool id from reaching an endpoint that takes an address.
@immutable
sealed class MarketPoolRef {
  const MarketPoolRef();

  /// A stable key for the row. It is display plumbing, never a request value.
  String get rowKey;
}

/// A pool contract (PancakeSwap and other V2/V3-style DEXes).
@immutable
final class MarketPoolAddressRef extends MarketPoolRef {
  const MarketPoolAddressRef(this.address);

  final String address;

  @override
  String get rowKey => 'address:$address';
}

/// A Uniswap V4 pool, identified by its 32-byte pool id inside the singleton.
/// There is no pool contract, so there is no pair page, no chart and no
/// address-keyed read: the row is shown and never opened.
@immutable
final class MarketPoolIdRef extends MarketPoolRef {
  const MarketPoolIdRef(this.poolId);

  final String poolId;

  @override
  String get rowKey => 'poolId:$poolId';
}

@immutable
final class MarketNewPair {
  const MarketNewPair({
    required this.poolRef,
    required this.dexId,
    this.logoUrl,
    required this.name,
    required this.baseTokenAddress,
    required this.quoteTokenAddress,
    required this.registryAssetId,
    required this.createdAt,
    required this.reserveUsd,
    required this.volumeH24Usd,
  });

  final MarketPoolRef poolRef;

  /// The pool's base token's artwork, or `null`.
  final String? logoUrl;
  final String dexId;
  final String name;
  final String? baseTokenAddress;
  final String? quoteTokenAddress;

  /// The pool quotes in native BNB. Some launchpads (four.meme) pair against
  /// the coin itself, and the provider then reports the zero address; it is
  /// not a missing token and must not be printed as one.
  bool get quotesNativeCoin => quoteTokenAddress == marketZeroAddress;

  /// Non-null only when the pool's base token is already in the registry.
  final String? registryAssetId;

  /// Whether this row may be opened. A V4 pool resolves its base token like
  /// any other, but it has no pair page and no address-keyed facts behind it,
  /// so the row stays where it is however the token reads.
  bool get opensDetail =>
      poolRef is MarketPoolAddressRef && registryAssetId != null;
  final DateTime? createdAt;
  final Decimal? reserveUsd;
  final Decimal? volumeH24Usd;
}

sealed class MarketNewPairsBlock {
  const MarketNewPairsBlock();
}

final class MarketNewPairsAvailable extends MarketNewPairsBlock {
  MarketNewPairsAvailable({
    required this.source,
    required this.fetchedAt,
    required this.ttlSeconds,
    required this.quality,
    required this.reasonCode,
    required this.omittedCount,
    required List<MarketNewPair> items,
  }) : items = List<MarketNewPair>.unmodifiable(items);

  final LoopFactSource source;
  final DateTime fetchedAt;
  final int ttlSeconds;
  final LoopFactQuality quality;
  final String? reasonCode;

  /// Provider rows whose pool identifier is neither a contract address nor a
  /// 32-byte pool id (decision 0052). Both known forms are listed under
  /// `poolRef`, so this counts genuinely malformed rows and is normally 0. The
  /// page states it so a list never passes itself off as the whole answer.
  final int omittedCount;
  final List<MarketNewPair> items;
}

final class MarketNewPairsUnavailable extends MarketNewPairsBlock {
  const MarketNewPairsUnavailable(this.reasonCode);

  final String reasonCode;
}

@immutable
final class MarketNewPairsPage {
  const MarketNewPairsPage({
    required this.newPairs,
    required this.riskScreening,
  });

  final MarketNewPairsBlock newPairs;

  /// Always unavailable in this step: the client must not derive a risk
  /// conclusion from any other field.
  final LoopUnavailable riskScreening;
}
