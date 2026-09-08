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
  });

  final String assetId;
  final LoopAssetSummary? asset;
  final LoopFact price;
  final LoopFact priceChange24h;

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

/// `GET /v2/market/overview` — the `market` tab.
@immutable
final class MarketOverview {
  const MarketOverview({
    required this.watchlist,
    required this.trending,
    required this.newPairsAvailable,
    required this.newPairsReasonCode,
    required this.smartMoney,
    required this.observedAt,
  });

  final MarketWatchlistBlock watchlist;
  final MarketTrendingBlock trending;

  /// Only says whether `GET /v2/market/new-pairs` has a provider at all.
  final bool newPairsAvailable;
  final String? newPairsReasonCode;
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

/// `GET /v2/market/assets/{assetId}` — the `token` page.
@immutable
final class MarketAssetDetail {
  const MarketAssetDetail({
    required this.asset,
    required this.capability,
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

  final LoopChainAsset asset;
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

@immutable
final class LoopCandlePool {
  const LoopCandlePool({
    required this.address,
    required this.protocol,
    required this.quoteAssetId,
    required this.quoteSymbol,
  });

  final String address;
  final String protocol;
  final String? quoteAssetId;
  final String quoteSymbol;
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
    required this.pool,
    required this.priceUnit,
    required List<LoopCandle> items,
  }) : items = List<LoopCandle>.unmodifiable(items);

  /// `derived` means LOOP aggregated on-chain swaps; the [labelKey] copy must
  /// then be rendered and the price unit is the pool's other token, not USD.
  final LoopFactQuality quality;
  final LoopFactSource source;
  final DateTime fetchedAt;
  final String? labelKey;
  final LoopCandlePool pool;
  final String priceUnit;
  final List<LoopCandle> items;

  bool get isDerived => quality == LoopFactQuality.derived;
}

final class MarketCandlesUnavailable extends MarketCandleBlock {
  const MarketCandlesUnavailable(this.reasonCode);

  final String reasonCode;
}

/// zh-CN copy for a candle `labelKey`. Unknown keys keep a neutral sentence.
String marketCandleLabelText(String? labelKey) => switch (labelKey) {
  'market.candles.onChainSwapAggregate' => '链上成交聚合',
  null => '',
  _ => '来源标注 $labelKey',
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

@immutable
final class MarketNewPair {
  const MarketNewPair({
    required this.poolAddress,
    required this.dexId,
    required this.name,
    required this.baseTokenAddress,
    required this.quoteTokenAddress,
    required this.registryAssetId,
    required this.createdAt,
    required this.reserveUsd,
    required this.volumeH24Usd,
  });

  final String poolAddress;
  final String dexId;
  final String name;
  final String? baseTokenAddress;
  final String? quoteTokenAddress;

  /// Non-null only when the pool's base token is already in the registry, so
  /// the row may open the token page.
  final String? registryAssetId;
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
    required List<MarketNewPair> items,
  }) : items = List<MarketNewPair>.unmodifiable(items);

  final LoopFactSource source;
  final DateTime fetchedAt;
  final int ttlSeconds;
  final LoopFactQuality quality;
  final String? reasonCode;
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
