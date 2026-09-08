import 'package:dio/dio.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_module_request.dart';

/// Strict V2 transport for the `market` module (loop-api decision 0034).
///
/// Provider failures are not HTTP errors: the request succeeds and the
/// affected block arrives `unavailable` or with `quality: stale`. This
/// transport therefore never turns a missing figure into an exception.
abstract interface class LoopV2MarketApi {
  Future<MarketOverview> getOverview({
    required String accessToken,
    required String clientVersion,
  });

  Future<MarketAssetDetail> getAsset({
    required String accessToken,
    required String clientVersion,
    required String assetId,
  });

  Future<MarketCandleSeries> getCandles({
    required String accessToken,
    required String clientVersion,
    required String assetId,
    required LoopCandleInterval interval,
    int? limit,
  });

  Future<MarketTradesPage> getTrades({
    required String accessToken,
    required String clientVersion,
    required String assetId,
    String? cursor,
  });

  Future<MarketHolders> getHolders({
    required String accessToken,
    required String clientVersion,
    required String assetId,
  });

  Future<MarketNewPairsPage> getNewPairs({
    required String accessToken,
    required String clientVersion,
  });

  Future<LoopUnavailable> getSmartMoney({
    required String accessToken,
    required String clientVersion,
  });
}

final class DioLoopV2MarketApi implements LoopV2MarketApi {
  DioLoopV2MarketApi(this._dio);

  static const overviewPath = '/v2/market/overview';
  static const assetsPath = '/v2/market/assets';
  static const newPairsPath = '/v2/market/new-pairs';
  static const smartMoneyPath = '/v2/market/smart-money';

  final Dio _dio;

  static String _requireAssetId(String value) {
    if (!LoopV2ChainCodec.assetIdPattern.hasMatch(value)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    return value;
  }

  static void _requireCursorShape(String cursor) {
    if (cursor.length < 3 ||
        cursor.length > LoopV2ChainCodec.maximumCursorLength ||
        !LoopV2ChainCodec.cursorPattern.hasMatch(cursor)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
  }

  @override
  Future<MarketOverview> getOverview({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        overviewPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'watchlist',
        'trending',
        'newPairs',
        'smartMoney',
        'observedAt',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);

      final newPairs = LoopV2Contract.strictMap(root['newPairs'], <String>{
        'status',
        if (_isUnavailable(root['newPairs'])) 'reasonCode',
      });
      final newPairsAvailable = newPairs['status'] == 'available';
      if (!newPairsAvailable && newPairs['status'] != 'unavailable') {
        LoopV2ChainCodec.invalid();
      }

      return MarketOverview(
        watchlist: _watchlistBlock(root['watchlist']),
        trending: _trendingBlock(root['trending']),
        newPairsAvailable: newPairsAvailable,
        newPairsReasonCode: newPairsAvailable
            ? null
            : LoopV2ChainCodec.requireReasonCode(newPairs, 'reasonCode'),
        smartMoney: LoopV2ChainCodec.unavailable(root['smartMoney']),
        observedAt: LoopV2ChainCodec.requireTimestamp(root, 'observedAt'),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<MarketAssetDetail> getAsset({
    required String accessToken,
    required String clientVersion,
    required String assetId,
  }) async {
    final target = _requireAssetId(assetId);
    try {
      final response = await _dio.get<Object?>(
        '$assetsPath/${Uri.encodeComponent(target)}',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'asset',
        'capability',
        'price',
        'priceChange24h',
        'liquidityUsd',
        'volume24h',
        'marketCap',
        'fdv',
        'primaryPair',
        'community',
        'security',
        'holderCount',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      final asset = LoopV2ChainCodec.chainAsset(root['asset']);
      if (asset.assetId != target) LoopV2ChainCodec.invalid();
      return MarketAssetDetail(
        asset: asset,
        capability: LoopV2ChainCodec.assetCapability(root['capability']),
        price: LoopV2ChainCodec.fact(root['price']),
        priceChange24h: LoopV2ChainCodec.fact(root['priceChange24h']),
        liquidityUsd: LoopV2ChainCodec.fact(root['liquidityUsd']),
        volume24h: LoopV2ChainCodec.fact(root['volume24h']),
        marketCap: LoopV2ChainCodec.fact(root['marketCap']),
        fdv: LoopV2ChainCodec.fact(root['fdv']),
        primaryPair: _primaryPair(root['primaryPair']),
        community: _community(root['community']),
        security: _security(root['security']),
        holderCount: LoopV2ChainCodec.fact(root['holderCount']),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<MarketCandleSeries> getCandles({
    required String accessToken,
    required String clientVersion,
    required String assetId,
    required LoopCandleInterval interval,
    int? limit,
  }) async {
    final target = _requireAssetId(assetId);
    if (limit != null && (limit < 1 || limit > 300)) {
      throw const LoopBackendFailure(LoopBackendFailureKind.invalidRequest);
    }
    try {
      final response = await _dio.get<Object?>(
        '$assetsPath/${Uri.encodeComponent(target)}/candles',
        queryParameters: <String, Object?>{
          'interval': interval.wireName,
          'limit': ?limit,
        },
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'assetId',
        'interval',
        'candles',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      if (root['assetId'] != target) LoopV2ChainCodec.invalid();
      final rawInterval = root['interval'];
      if (rawInterval is! String) LoopV2ChainCodec.invalid();
      final resolved = LoopCandleInterval.tryParse(rawInterval);
      if (resolved != interval) LoopV2ChainCodec.invalid();
      return MarketCandleSeries(
        assetId: target,
        interval: interval,
        candles: _candles(root['candles']),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<MarketTradesPage> getTrades({
    required String accessToken,
    required String clientVersion,
    required String assetId,
    String? cursor,
  }) async {
    final target = _requireAssetId(assetId);
    if (cursor != null) _requireCursorShape(cursor);
    try {
      final response = await _dio.get<Object?>(
        '$assetsPath/${Uri.encodeComponent(target)}/trades',
        queryParameters: cursor == null
            ? null
            : <String, Object?>{'cursor': cursor},
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'assetId',
        'trades',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      if (root['assetId'] != target) LoopV2ChainCodec.invalid();
      return MarketTradesPage(assetId: target, trades: _trades(root['trades']));
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<MarketHolders> getHolders({
    required String accessToken,
    required String clientVersion,
    required String assetId,
  }) async {
    final target = _requireAssetId(assetId);
    try {
      final response = await _dio.get<Object?>(
        '$assetsPath/${Uri.encodeComponent(target)}/holders',
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'assetId',
        'holderCount',
        'distribution',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      if (root['assetId'] != target) LoopV2ChainCodec.invalid();
      return MarketHolders(
        assetId: target,
        holderCount: LoopV2ChainCodec.fact(root['holderCount']),
        distribution: LoopV2ChainCodec.unavailable(root['distribution']),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<MarketNewPairsPage> getNewPairs({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        newPairsPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'newPairs',
        'riskScreening',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      return MarketNewPairsPage(
        newPairs: _newPairs(root['newPairs']),
        riskScreening: LoopV2ChainCodec.unavailable(root['riskScreening']),
      );
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  @override
  Future<LoopUnavailable> getSmartMoney({
    required String accessToken,
    required String clientVersion,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        smartMoneyPath,
        options: LoopV2ModuleRequest.readOptions(accessToken, clientVersion),
      );
      LoopV2Contract.validateSuccess(response, statusCode: 200);
      final root = LoopV2Contract.strictMap(response.data, const <String>{
        'smartMoney',
        'contractVersion',
      });
      LoopV2ChainCodec.requireContractVersion(root);
      return LoopV2ChainCodec.unavailable(root['smartMoney']);
    } on DioException catch (error) {
      throw LoopV2Contract.mapDioFailure(
        error,
        allowedCodes: LoopV2ModuleRequest.chainReadErrors,
      );
    }
  }

  static bool _isUnavailable(Object? raw) =>
      raw is Map && raw['status'] == 'unavailable';

  static MarketAssetRow _assetRow(Object? raw, {required bool trending}) {
    final map = LoopV2Contract.strictMap(raw, <String>{
      'assetId',
      'asset',
      'price',
      'priceChange24h',
      if (trending) 'volume24h',
      if (trending) 'liquidityUsd',
    });
    return MarketAssetRow(
      assetId: LoopV2ChainCodec.requireAssetId(map, 'assetId'),
      asset: LoopV2ChainCodec.assetSummary(map['asset']),
      price: LoopV2ChainCodec.fact(map['price']),
      priceChange24h: LoopV2ChainCodec.fact(map['priceChange24h']),
      volume24h: trending ? LoopV2ChainCodec.fact(map['volume24h']) : null,
      liquidityUsd: trending
          ? LoopV2ChainCodec.fact(map['liquidityUsd'])
          : null,
    );
  }

  static MarketWatchlistBlock _watchlistBlock(Object? raw) {
    if (_isUnavailable(raw)) {
      return MarketWatchlistUnavailable(
        LoopV2ChainCodec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'version',
      'items',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    final items = <MarketAssetRow>[];
    final seen = <String>{};
    for (final entry in LoopV2ChainCodec.requireList(
      map['items'],
      maximum: 100,
    )) {
      final row = _assetRow(entry, trending: false);
      if (!seen.add(row.assetId)) LoopV2ChainCodec.invalid();
      items.add(row);
    }
    return MarketWatchlistAvailable(
      version: LoopV2ChainCodec.requireInt(map, 'version'),
      items: items,
    );
  }

  static MarketTrendingBlock _trendingBlock(Object? raw) {
    if (_isUnavailable(raw)) {
      return MarketTrendingUnavailable(
        LoopV2ChainCodec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'recommendationId',
      'rules',
      'items',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    final rules = LoopV2Contract.strictMap(map['rules'], const <String>{
      'configVersion',
      'effectiveAt',
      'ordering',
    });
    if (rules['configVersion'] != 'marketTrendingV1') {
      LoopV2ChainCodec.invalid();
    }
    final ordering = rules['ordering'];
    if (ordering is! String || ordering.isEmpty || ordering.length > 64) {
      LoopV2ChainCodec.invalid();
    }
    final items = <MarketAssetRow>[];
    final seen = <String>{};
    for (final entry in LoopV2ChainCodec.requireList(
      map['items'],
      maximum: 20,
    )) {
      final row = _assetRow(entry, trending: true);
      if (!seen.add(row.assetId)) LoopV2ChainCodec.invalid();
      items.add(row);
    }
    return MarketTrendingAvailable(
      recommendationId: LoopV2ChainCodec.requireString(
        map,
        'recommendationId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      rules: MarketTrendingRules(
        configVersion: 'marketTrendingV1',
        effectiveAt: LoopV2ChainCodec.requireTimestamp(rules, 'effectiveAt'),
        ordering: ordering,
      ),
      items: items,
    );
  }

  static MarketPrimaryPair? _primaryPair(Object? raw) {
    if (raw == null) return null;
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'pairAddress',
      'dexId',
      'labels',
      'quoteTokenAddress',
      'quoteTokenSymbol',
      'pairCreatedAt',
    });
    final labels = <String>[];
    for (final entry in LoopV2ChainCodec.requireList(
      map['labels'],
      maximum: 16,
    )) {
      if (entry is! String ||
          entry.isEmpty ||
          entry.length > 32 ||
          !LoopV2ChainCodec.displayTextPattern.hasMatch(entry)) {
        LoopV2ChainCodec.invalid();
      }
      labels.add(entry);
    }
    return MarketPrimaryPair(
      pairAddress: LoopV2ChainCodec.requireString(
        map,
        'pairAddress',
        pattern: LoopV2ChainCodec.addressPattern,
        maxLength: 42,
      ),
      dexId: LoopV2ChainCodec.requireText(map, 'dexId', maxLength: 64),
      labels: labels,
      quoteTokenAddress: LoopV2ChainCodec.requireString(
        map,
        'quoteTokenAddress',
        pattern: LoopV2ChainCodec.addressPattern,
        maxLength: 42,
      ),
      quoteTokenSymbol: LoopV2ChainCodec.requireText(
        map,
        'quoteTokenSymbol',
        maxLength: 32,
      ),
      pairCreatedAt: LoopV2ChainCodec.optionalTimestamp(map, 'pairCreatedAt'),
    );
  }

  static MarketCommunityBlock _community(Object? raw) {
    if (_isUnavailable(raw)) {
      return MarketCommunityUnavailable(
        LoopV2ChainCodec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'communityId',
      'name',
      'slug',
      'memberCount',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    return MarketCommunityBound(
      communityId: LoopV2ChainCodec.requireString(
        map,
        'communityId',
        pattern: LoopV2Contract.uuidV4Pattern,
        maxLength: 36,
      ),
      name: LoopV2ChainCodec.requireText(map, 'name', maxLength: 40),
      slug: LoopV2ChainCodec.requireString(
        map,
        'slug',
        pattern: RegExp(r'^[a-z0-9-]{3,32}$'),
        maxLength: 32,
      ),
      memberCount: LoopV2ChainCodec.requireInt(map, 'memberCount'),
    );
  }

  static MarketSecurityBlock _security(Object? raw) {
    if (_isUnavailable(raw)) {
      return MarketSecurityUnavailable(
        LoopV2ChainCodec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'source',
      'fetchedAt',
      'ttlSeconds',
      'quality',
      'reasonCode',
      'facts',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    final rawQuality = map['quality'];
    if (rawQuality is! String) LoopV2ChainCodec.invalid();
    final quality = LoopFactQuality.tryParse(rawQuality);
    if (quality != LoopFactQuality.fresh && quality != LoopFactQuality.stale) {
      LoopV2ChainCodec.invalid();
    }
    final facts = <MarketSecurityFact>[];
    final seen = <String>{};
    for (final entry in LoopV2ChainCodec.requireList(
      map['facts'],
      maximum: 32,
    )) {
      final factMap = LoopV2Contract.strictMap(entry, const <String>{
        'fact',
        'value',
        'source',
        'observedAt',
      });
      final key = LoopV2ChainCodec.requireString(
        factMap,
        'fact',
        pattern: RegExp(r'^[a-z][A-Za-z0-9]{0,63}$'),
        maxLength: 64,
      );
      if (!seen.add(key)) LoopV2ChainCodec.invalid();
      facts.add(
        MarketSecurityFact(
          fact: key,
          value: LoopV2ChainCodec.requireText(factMap, 'value', maxLength: 96),
          source: LoopV2ChainCodec.requireFactSource(factMap, 'source'),
          observedAt: LoopV2ChainCodec.requireTimestamp(factMap, 'observedAt'),
        ),
      );
    }
    return MarketSecurityAvailable(
      source: LoopV2ChainCodec.requireFactSource(map, 'source'),
      fetchedAt: LoopV2ChainCodec.requireTimestamp(map, 'fetchedAt'),
      ttlSeconds: LoopV2ChainCodec.requireInt(map, 'ttlSeconds', minimum: 1),
      quality: quality!,
      reasonCode: LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode'),
      facts: facts,
    );
  }

  static MarketCandleBlock _candles(Object? raw) {
    if (_isUnavailable(raw)) {
      return MarketCandlesUnavailable(
        LoopV2ChainCodec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'quality',
      'source',
      'fetchedAt',
      'labelKey',
      'pool',
      'priceUnit',
      'items',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    final rawQuality = map['quality'];
    if (rawQuality is! String) LoopV2ChainCodec.invalid();
    final quality = LoopFactQuality.tryParse(rawQuality);
    if (quality != LoopFactQuality.fresh &&
        quality != LoopFactQuality.stale &&
        quality != LoopFactQuality.derived) {
      LoopV2ChainCodec.invalid();
    }
    final pool = LoopV2Contract.strictMap(map['pool'], const <String>{
      'address',
      'protocol',
      'quoteAssetId',
      'quoteSymbol',
    });
    if (pool['protocol'] != 'pancakeswap_v3') LoopV2ChainCodec.invalid();

    final items = <LoopCandle>[];
    DateTime? previousOpen;
    for (final entry in LoopV2ChainCodec.requireList(
      map['items'],
      maximum: 300,
    )) {
      final candleMap = LoopV2Contract.strictMap(entry, const <String>{
        'openTime',
        'closeTime',
        'open',
        'high',
        'low',
        'close',
        'volume',
        'swapCount',
        'isOpen',
      });
      final openTime = LoopV2ChainCodec.requireTimestamp(candleMap, 'openTime');
      // Buckets arrive strictly ascending; anything else would let the chart
      // draw a time series that does not exist.
      if (previousOpen != null && !openTime.isAfter(previousOpen)) {
        LoopV2ChainCodec.invalid();
      }
      previousOpen = openTime;
      final closeTime = LoopV2ChainCodec.requireTimestamp(
        candleMap,
        'closeTime',
      );
      if (!closeTime.isAfter(openTime)) LoopV2ChainCodec.invalid();
      final high = LoopV2ChainCodec.requireDecimal(candleMap, 'high');
      final low = LoopV2ChainCodec.requireDecimal(candleMap, 'low');
      final open = LoopV2ChainCodec.requireDecimal(candleMap, 'open');
      final close = LoopV2ChainCodec.requireDecimal(candleMap, 'close');
      if (low > high ||
          open > high ||
          open < low ||
          close > high ||
          close < low) {
        LoopV2ChainCodec.invalid();
      }
      items.add(
        LoopCandle(
          openTime: openTime,
          closeTime: closeTime,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: LoopV2ChainCodec.requireDecimal(candleMap, 'volume'),
          swapCount: LoopV2ChainCodec.optionalInt(
            candleMap,
            'swapCount',
            minimum: 1,
          ),
          isOpen: LoopV2ChainCodec.requireBool(candleMap, 'isOpen'),
        ),
      );
    }
    // Only the last bucket may still be open.
    for (var index = 0; index < items.length - 1; index += 1) {
      if (items[index].isOpen) LoopV2ChainCodec.invalid();
    }

    return MarketCandlesAvailable(
      quality: quality!,
      source: LoopV2ChainCodec.requireFactSource(map, 'source'),
      fetchedAt: LoopV2ChainCodec.requireTimestamp(map, 'fetchedAt'),
      labelKey: LoopV2ChainCodec.optionalString(
        map,
        'labelKey',
        pattern: LoopV2ChainCodec.displayTextPattern,
        maxLength: 64,
      ),
      pool: LoopCandlePool(
        address: LoopV2ChainCodec.requireString(
          pool,
          'address',
          pattern: LoopV2ChainCodec.addressPattern,
          maxLength: 42,
        ),
        protocol: 'pancakeswap_v3',
        quoteAssetId: LoopV2ChainCodec.optionalString(
          pool,
          'quoteAssetId',
          pattern: LoopV2ChainCodec.assetIdPattern,
          maxLength: 64,
        ),
        quoteSymbol: LoopV2ChainCodec.requireText(
          pool,
          'quoteSymbol',
          maxLength: 32,
        ),
      ),
      priceUnit: LoopV2ChainCodec.requireText(map, 'priceUnit', maxLength: 80),
      items: items,
    );
  }

  static MarketTradesBlock _trades(Object? raw) {
    if (_isUnavailable(raw)) {
      return MarketTradesUnavailable(
        LoopV2ChainCodec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'source',
      'items',
      'nextCursor',
      'freshness',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    final items = <MarketTrade>[];
    final seen = <String>{};
    for (final entry in LoopV2ChainCodec.requireList(
      map['items'],
      maximum: 50,
    )) {
      final tradeMap = LoopV2Contract.strictMap(entry, const <String>{
        'transactionHash',
        'logIndex',
        'blockNumber',
        'blockHash',
        'blockTimestamp',
        'confirmations',
        'status',
        'direction',
        'amountAsset',
        'amountQuote',
        'quoteAssetId',
        'quoteSymbol',
        'priceAfter',
        'poolAddress',
        'isOwn',
      });
      final rawDirection = tradeMap['direction'];
      if (rawDirection is! String) LoopV2ChainCodec.invalid();
      final direction = MarketTradeDirection.tryParse(rawDirection);
      if (direction == null) LoopV2ChainCodec.invalid();
      final trade = MarketTrade(
        transactionHash: LoopV2ChainCodec.requireString(
          tradeMap,
          'transactionHash',
          pattern: LoopV2ChainCodec.hashPattern,
          maxLength: 66,
        ),
        logIndex: LoopV2ChainCodec.requireInt(tradeMap, 'logIndex'),
        blockNumber: LoopV2ChainCodec.requireBlockNumber(
          tradeMap,
          'blockNumber',
        ),
        blockHash: LoopV2ChainCodec.requireString(
          tradeMap,
          'blockHash',
          pattern: LoopV2ChainCodec.hashPattern,
          maxLength: 66,
        ),
        blockTimestamp: LoopV2ChainCodec.requireTimestamp(
          tradeMap,
          'blockTimestamp',
        ),
        confirmations: LoopV2ChainCodec.optionalInt(
          tradeMap,
          'confirmations',
          minimum: 0,
        ),
        status: LoopV2ChainCodec.requireConfirmationStatus(tradeMap, 'status'),
        direction: direction,
        amountAsset: LoopV2ChainCodec.requireDecimal(tradeMap, 'amountAsset'),
        amountQuote: LoopV2ChainCodec.requireDecimal(tradeMap, 'amountQuote'),
        quoteAssetId: LoopV2ChainCodec.requireAssetId(tradeMap, 'quoteAssetId'),
        quoteSymbol: LoopV2ChainCodec.requireText(
          tradeMap,
          'quoteSymbol',
          maxLength: 32,
        ),
        priceAfter: LoopV2ChainCodec.optionalDecimal(tradeMap, 'priceAfter'),
        poolAddress: LoopV2ChainCodec.requireString(
          tradeMap,
          'poolAddress',
          pattern: LoopV2ChainCodec.addressPattern,
          maxLength: 42,
        ),
        isOwn: LoopV2ChainCodec.requireBool(tradeMap, 'isOwn'),
      );
      if (!seen.add(trade.tradeId)) LoopV2ChainCodec.invalid();
      items.add(trade);
    }
    return MarketTradesAvailable(
      source: LoopV2ChainCodec.requireFactSource(map, 'source'),
      items: items,
      nextCursor: LoopV2ChainCodec.cursor(map, 'nextCursor'),
      freshness: LoopV2ChainCodec.freshness(map['freshness']),
    );
  }

  static MarketNewPairsBlock _newPairs(Object? raw) {
    if (_isUnavailable(raw)) {
      return MarketNewPairsUnavailable(
        LoopV2ChainCodec.unavailable(raw).reasonCode,
      );
    }
    final map = LoopV2Contract.strictMap(raw, const <String>{
      'status',
      'source',
      'fetchedAt',
      'ttlSeconds',
      'quality',
      'reasonCode',
      'items',
    });
    if (map['status'] != 'available') LoopV2ChainCodec.invalid();
    final rawQuality = map['quality'];
    if (rawQuality is! String) LoopV2ChainCodec.invalid();
    final quality = LoopFactQuality.tryParse(rawQuality);
    if (quality != LoopFactQuality.fresh && quality != LoopFactQuality.stale) {
      LoopV2ChainCodec.invalid();
    }
    final items = <MarketNewPair>[];
    final seen = <String>{};
    for (final entry in LoopV2ChainCodec.requireList(
      map['items'],
      maximum: 100,
    )) {
      final pairMap = LoopV2Contract.strictMap(entry, const <String>{
        'poolAddress',
        'dexId',
        'name',
        'baseTokenAddress',
        'quoteTokenAddress',
        'registryAssetId',
        'createdAt',
        'reserveUsd',
        'volumeH24Usd',
      });
      final poolAddress = LoopV2ChainCodec.requireString(
        pairMap,
        'poolAddress',
        pattern: LoopV2ChainCodec.addressPattern,
        maxLength: 42,
      );
      if (!seen.add(poolAddress)) LoopV2ChainCodec.invalid();
      items.add(
        MarketNewPair(
          poolAddress: poolAddress,
          dexId: LoopV2ChainCodec.requireText(pairMap, 'dexId', maxLength: 64),
          name: LoopV2ChainCodec.requireText(pairMap, 'name'),
          baseTokenAddress: LoopV2ChainCodec.optionalString(
            pairMap,
            'baseTokenAddress',
            pattern: LoopV2ChainCodec.addressPattern,
            maxLength: 42,
          ),
          quoteTokenAddress: LoopV2ChainCodec.optionalString(
            pairMap,
            'quoteTokenAddress',
            pattern: LoopV2ChainCodec.addressPattern,
            maxLength: 42,
          ),
          registryAssetId: LoopV2ChainCodec.optionalString(
            pairMap,
            'registryAssetId',
            pattern: LoopV2ChainCodec.assetIdPattern,
            maxLength: 64,
          ),
          createdAt: LoopV2ChainCodec.optionalTimestamp(pairMap, 'createdAt'),
          reserveUsd: LoopV2ChainCodec.optionalDecimal(
            pairMap,
            'reserveUsd',
            signed: true,
          ),
          volumeH24Usd: LoopV2ChainCodec.optionalDecimal(
            pairMap,
            'volumeH24Usd',
            signed: true,
          ),
        ),
      );
    }
    return MarketNewPairsAvailable(
      source: LoopV2ChainCodec.requireFactSource(map, 'source'),
      fetchedAt: LoopV2ChainCodec.requireTimestamp(map, 'fetchedAt'),
      ttlSeconds: LoopV2ChainCodec.requireInt(map, 'ttlSeconds', minimum: 1),
      quality: quality!,
      reasonCode: LoopV2ChainCodec.optionalReasonCode(map, 'reasonCode'),
      items: items,
    );
  }
}
