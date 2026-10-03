import 'dart:math' as math;

import 'package:loop_mobile/features/market/watchlist/watchlist_gateway.dart';

import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';

import 'package:loop_mobile/preview/chain_catalog.dart';

/// Synthetic read-only data for the explicitly labelled development catalog.
/// No transport, authentication, signing, persistence, or provider calls.
final class MemoryPreviewMarketGateway implements MarketReadGateway {
  MemoryPreviewMarketGateway({this.watchlist});
  final WatchlistGateway? watchlist;
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.preview;
  static final observedAt = DateTime.utc(2026, 10, 2, 8);
  static const assets = <(String, String, String, String, String)>[
    (previewChainNativeAssetId, 'BNB', 'BNB', '747.39', '2.73'),
    (previewChainWbnbAssetId, 'WBNB', 'Wrapped BNB', '747.12', '2.69'),
    (previewChainUsdtAssetId, 'USDT', 'Tether USD', '1.0001', '-0.02'),
    (
      'eip155:56:0x0e09fabb73bd3ade0a17ecc321fd13a19e81ce82',
      'CAKE',
      'PancakeSwap',
      '2.864',
      '8.42',
    ),
    (
      'eip155:56:0x1111111111111111111111111111111111111111',
      'LOOP',
      'LOOP Preview',
      '0.08472',
      '12.86',
    ),
    (
      'eip155:56:0x2222222222222222222222222222222222222222',
      'MCAT',
      'MoonCat Preview',
      '0.00002846',
      '-4.31',
    ),
    (
      'eip155:56:0x3333333333333333333333333333333333333333',
      'NOVA',
      'Nova Preview',
      '0.01287',
      '21.54',
    ),
    (
      'eip155:56:0x4444444444444444444444444444444444444444',
      'PEPE',
      'Pepe Preview',
      '0.000009218',
      '-2.78',
    ),
  ];
  static LoopFact fact(String value) => LoopFact(
    value: Decimal.parse(value),
    source: LoopFactSource.dexscreener,
    fetchedAt: observedAt,
    ttlSeconds: 30,
    quality: LoopFactQuality.fresh,
    reasonCode: null,
  );
  (String, String, String, String, String) _asset(String id) =>
      assets.firstWhere(
        (a) => a.$1 == id,
        orElse: () =>
            throw const LoopChainException(LoopChainFailureKind.unavailable),
      );
  MarketAssetRow row(int i) {
    final a = assets[i];
    final base = double.parse(a.$4);
    return MarketAssetRow(
      assetId: a.$1,
      asset: LoopAssetSummary(
        symbol: a.$2,
        name: a.$3,
        decimals: 18,
        status: LoopAssetStatus.pending,
      ),
      price: fact(a.$4),
      priceChange24h: fact(a.$5),
      volume24h: fact('${12480000 ~/ (i + 1)}'),
      liquidityUsd: fact('${9200000 ~/ (i + 1)}'),
      sparkline: MarketRowSparklineSeries(
        interval: LoopCandleInterval.oneHour,
        observedAt: observedAt,
        closes: List.generate(
          24,
          (n) => Decimal.parse(
            (base * (1 + math.sin(n * .7 + i) * .025 + n * .001))
                .toStringAsPrecision(12),
          ),
        ),
      ),
    );
  }

  @override
  Future<MarketOverview> loadOverview() async {
    final saved = await watchlist?.load();
    final ids = saved?.groups
        .expand((g) => g.items)
        .map((a) => a.assetId)
        .toSet();
    return MarketOverview(
      watchlist: MarketWatchlistAvailable(
        version: saved?.version ?? 1,
        items: [
          for (var i = 0; i < assets.length; i++)
            if (ids?.contains(assets[i].$1) ?? [0, 3, 4].contains(i)) row(i),
        ],
      ),
      trending: MarketTrendingAvailable(
        recommendationId: previewChainRecommendationId,
        rules: MarketTrendingRules(
          configVersion: 'preview-only',
          effectiveAt: observedAt,
          ordering: 'dexscreener_volume_h24_desc',
        ),
        items: List.generate(assets.length, row),
      ),
      newPairs: const MarketOverviewNewPairsUnavailable(
        'PREVIEW_NEW_PAIRS_UNAVAILABLE',
      ),
      smartMoney: const LoopUnavailable('SMART_MONEY_RUNTIME_DEFERRED'),
      observedAt: observedAt,
    );
  }

  @override
  Future<MarketAssetDetail> loadAsset(String assetId) async {
    final a = _asset(assetId);
    final i = assets.indexOf(a);
    return MarketAssetDetail(
      asset: MarketAssetIdentitySettled(
        LoopChainAsset(
          assetId: assetId,
          chainId: 'eip155:56',
          address: assetId == previewChainNativeAssetId
              ? null
              : assetId.split(':').last,
          symbol: a.$2,
          name: a.$3,
          decimals: 18,
          status: LoopAssetStatus.pending,
          source: LoopAssetSource(
            kind: LoopAssetSourceKind.chainCall,
            blockNumber: BigInt.from(123456789),
            verifiedAt: observedAt,
          ),
          updatedAt: observedAt,
        ),
      ),
      capability: const LoopAssetCapability(
        viewable: true,
        swappable: false,
        value: LoopAssetCapabilityValue.viewable,
        reasonCode: 'PREVIEW_EXECUTION_DISABLED',
      ),
      price: fact(a.$4),
      priceChange24h: fact(a.$5),
      liquidityUsd: fact('${9200000 ~/ (i + 1)}'),
      volume24h: fact('${12480000 ~/ (i + 1)}'),
      marketCap: fact('${840000000 ~/ (i + 1)}'),
      fdv: fact('${1000000000 ~/ (i + 1)}'),
      holderCount: fact('${28461 ~/ (i + 1)}'),
      primaryPair: null,
      community: const MarketCommunityBound(
        communityId: '4bb85f64-5717-4562-b3fc-2c963f66afb7',
        name: '演示社区 · Builders',
        slug: 'demo-builders',
        memberCount: 42,
      ),
      security: const MarketSecurityUnavailable(
        'PREVIEW_SECURITY_NOT_VERIFIED',
      ),
    );
  }

  @override
  Future<MarketCandleSeries> loadCandles(
    String assetId, {
    required LoopCandleInterval interval,
    int? limit,
  }) async {
    final a = _asset(assetId);
    final base = double.parse(a.$4);
    final minutes = switch (interval) {
      LoopCandleInterval.fifteenMinutes => 15,
      LoopCandleInterval.oneHour => 60,
      LoopCandleInterval.fourHours => 240,
      LoopCandleInterval.oneDay => 1440,
      LoopCandleInterval.oneWeek => 10080,
    };
    final count = (limit ?? 360).clamp(1, 500);
    Decimal value(double v) => Decimal.parse(v.toStringAsPrecision(12));
    return MarketCandleSeries(
      assetId: assetId,
      interval: interval,
      candles: MarketCandlesAvailable(
        quality: LoopFactQuality.derived,
        source: LoopFactSource.loopIndexer,
        fetchedAt: observedAt,
        labelKey: '开发预览 · 演示数据',
        proxyAsset: null,
        pool: const LoopCandlePool(
          address: previewChainPoolAddress,
          protocol: 'preview',
          origin: LoopCandlePoolOrigin.registry,
          quoteAssetId: previewChainUsdtAssetId,
          quoteSymbol: 'USDT',
        ),
        priceUnit: 'USDT / ${a.$2}',
        items: List.generate(count, (i) {
          final step = i - count + 60;
          final open = base * (.96 + .0007 * step + math.sin(step * .6) * .015);
          final close = open * (1 + math.sin(i * 1.3) * .009);
          return LoopCandle(
            openTime: observedAt.subtract(
              Duration(minutes: (count - i) * minutes),
            ),
            closeTime: observedAt.subtract(
              Duration(minutes: (count - i - 1) * minutes),
            ),
            open: value(open),
            high: value(math.max(open, close) * 1.006),
            low: value(math.min(open, close) * .994),
            close: value(close),
            volume: value(24000 + i * 731.0 + (i % 7) * 3200),
            swapCount: 120 + i * 3,
            isOpen: false,
          );
        }),
      ),
    );
  }

  @override
  Future<MarketHolders> loadHolders(String assetId) async {
    _asset(assetId);
    return MarketHolders(
      assetId: assetId,
      holderCount: fact('28461'),
      distribution: const LoopUnavailable('HOLDER_DISTRIBUTION_NOT_AVAILABLE'),
    );
  }

  @override
  Future<MarketTradesPage> loadTrades(String assetId, {String? cursor}) async {
    final a = _asset(assetId);
    return MarketTradesPage(
      assetId: assetId,
      trades: MarketTradesAvailable(
        source: LoopFactSource.loopIndexer,
        nextCursor: null,
        freshness: LoopIndexerFreshness(
          indexerBlockNumber: BigInt.from(123456789),
          headBlockNumber: BigInt.from(123456789),
          lagBlocks: 0,
          observedAt: observedAt,
        ),
        items: List.generate(
          12,
          (i) => MarketTrade(
            transactionHash: '0x${(i + 1).toRadixString(16).padLeft(64, '0')}',
            logIndex: i,
            blockNumber: BigInt.from(123456789 - i),
            blockHash: previewChainBlockHash,
            blockTimestamp: observedAt.subtract(Duration(minutes: i * 3)),
            confirmations: 30 + i,
            status: LoopConfirmationStatus.confirmed,
            direction: i.isEven
                ? MarketTradeDirection.buy
                : MarketTradeDirection.sell,
            amountAsset: Decimal.fromInt(10 + i),
            amountQuote: Decimal.parse(a.$4) * Decimal.fromInt(10 + i),
            quoteAssetId: previewChainUsdtAssetId,
            quoteSymbol: 'USDT',
            priceAfter: Decimal.parse(a.$4),
            poolAddress: previewChainPoolAddress,
            isOwn: false,
          ),
        ),
      ),
    );
  }

  @override
  Future<MarketNewPairsPage> loadNewPairs() async => const MarketNewPairsPage(
    newPairs: MarketNewPairsUnavailable('PREVIEW_NEW_PAIRS_UNAVAILABLE'),
    riskScreening: LoopUnavailable('PREVIEW_SECURITY_NOT_VERIFIED'),
  );
  @override
  Future<LoopUnavailable> loadSmartMoney() async =>
      const LoopUnavailable('SMART_MONEY_RUNTIME_DEFERRED');
}
