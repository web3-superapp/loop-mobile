import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';

abstract interface class HyperliquidSpotMarketRepository {
  Future<HyperliquidSpotSnapshot> fetchMarkets();
}

/// Fetches public spot-market data from Hyperliquid Testnet only.
///
/// This adapter has no account, balance, order, cancellation, transfer,
/// withdrawal, key, nonce, or signing capability.
final class DioHyperliquidSpotMarketRepository
    implements HyperliquidSpotMarketRepository {
  DioHyperliquidSpotMarketRepository(this._dio, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static final Uri endpoint = Uri.https('api.hyperliquid-testnet.xyz', '/info');

  static const Map<String, String> requestPayload = <String, String>{
    'type': 'spotMetaAndAssetCtxs',
  };

  static final RegExp _tokenIdPattern = RegExp(r'^0x[0-9a-f]{32}$');

  final Dio _dio;
  final DateTime Function() _now;

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async {
    try {
      final response = await _dio.post<Object?>(
        endpoint.toString(),
        data: requestPayload,
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );
      final receivedAt = _now();
      return _parseSnapshot(response.data, receivedAt: receivedAt);
    } on DioException catch (error) {
      throw _mapDioFailure(error);
    }
  }

  HyperliquidSpotSnapshot _parseSnapshot(
    Object? payload, {
    required DateTime receivedAt,
  }) {
    if (payload is! List<Object?> || payload.length != 2) {
      throw _invalidPayload();
    }

    final metadata = _map(payload[0]);
    final tokenRows = _list(metadata['tokens']);
    final universeRows = _list(metadata['universe']);
    final contextRows = _list(payload[1]);

    final tokensByIndex = <int, _SpotToken>{};
    for (final row in tokenRows) {
      final token = _parseToken(_map(row));
      if (tokensByIndex[token.index] != null) throw _invalidPayload();
      tokensByIndex[token.index] = token;
    }

    final contextsByCoin = <String, Map<String, Object?>>{};
    for (final row in contextRows) {
      final context = _map(row);
      final coin = _identifier(context['coin']);
      if (contextsByCoin[coin] != null) throw _invalidPayload();
      contextsByCoin[coin] = context;
    }

    final spotIndexes = <int>{};
    final providerCoins = <String>{};
    final markets = <HyperliquidSpotMarket>[];
    for (final row in universeRows) {
      final pair = _map(row);
      final providerCoin = _identifier(pair['name']);
      final spotIndex = _nonNegativeInt(pair['index']);
      final tokenIndexes = _list(pair['tokens']);
      final isCanonical = pair['isCanonical'];
      if (tokenIndexes.length != 2 ||
          isCanonical is! bool ||
          !spotIndexes.add(spotIndex) ||
          !providerCoins.add(providerCoin)) {
        throw _invalidPayload();
      }

      final baseTokenIndex = _nonNegativeInt(tokenIndexes[0]);
      final quoteTokenIndex = _nonNegativeInt(tokenIndexes[1]);
      if (baseTokenIndex == quoteTokenIndex) throw _invalidPayload();
      final baseToken = tokensByIndex[baseTokenIndex];
      final quoteToken = tokensByIndex[quoteTokenIndex];
      final context = contextsByCoin[providerCoin];
      if (baseToken == null || quoteToken == null || context == null) {
        throw _invalidPayload();
      }

      markets.add(
        HyperliquidSpotMarket(
          spotIndex: spotIndex,
          providerCoin: providerCoin,
          baseTokenIndex: baseTokenIndex,
          quoteTokenIndex: quoteTokenIndex,
          baseTokenId: baseToken.tokenId,
          quoteTokenId: quoteToken.tokenId,
          baseSymbol: baseToken.symbol,
          quoteSymbol: quoteToken.symbol,
          baseSizeDecimals: baseToken.sizeDecimals,
          isCanonical: isCanonical,
          markPrice: _decimal(context, 'markPx'),
          midPrice: _optionalDecimal(context, 'midPx'),
          previousDayPrice: _decimal(context, 'prevDayPx'),
          dayNotionalVolume: _decimal(context, 'dayNtlVlm'),
          dayBaseVolume: _decimal(context, 'dayBaseVlm'),
        ),
      );
    }

    return HyperliquidSpotSnapshot(receivedAt: receivedAt, markets: markets);
  }

  _SpotToken _parseToken(Map<String, Object?> source) {
    final index = _nonNegativeInt(source['index']);
    final symbol = _identifier(source['name'], allowOuterWhitespace: true);
    final sizeDecimals = _nonNegativeInt(source['szDecimals']);
    final tokenId = source['tokenId'];
    if (sizeDecimals > 8 ||
        tokenId is! String ||
        !_tokenIdPattern.hasMatch(tokenId)) {
      throw _invalidPayload();
    }
    return _SpotToken(
      index: index,
      symbol: symbol,
      sizeDecimals: sizeDecimals,
      tokenId: tokenId,
    );
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    throw _invalidPayload();
  }

  List<Object?> _list(Object? value) {
    if (value is List<Object?>) return value;
    throw _invalidPayload();
  }

  int _nonNegativeInt(Object? value) {
    if (value is int && value >= 0) return value;
    throw _invalidPayload();
  }

  String _identifier(Object? value, {bool allowOuterWhitespace = false}) {
    if (value is! String) throw _invalidPayload();
    final normalized = value.trim();
    if (normalized.isEmpty || (!allowOuterWhitespace && normalized != value)) {
      throw _invalidPayload();
    }
    for (final codePoint in normalized.runes) {
      if (codePoint < 0x20 || codePoint == 0x7f) throw _invalidPayload();
    }
    return normalized;
  }

  HyperliquidSpotDecimal _decimal(Map<String, Object?> source, String key) {
    final wireValue = source[key];
    if (wireValue is! String) throw _invalidPayload();
    final value = Decimal.tryParse(wireValue);
    if (value == null || value < Decimal.zero) throw _invalidPayload();
    return HyperliquidSpotDecimal(source: wireValue, value: value);
  }

  HyperliquidSpotDecimal? _optionalDecimal(
    Map<String, Object?> source,
    String key,
  ) {
    if (source[key] == null) return null;
    return _decimal(source, key);
  }

  HyperliquidMarketFailure _invalidPayload() {
    return const HyperliquidMarketFailure(
      HyperliquidMarketFailureKind.invalidPayload,
    );
  }

  HyperliquidMarketFailure _mapDioFailure(DioException error) {
    final kind = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => HyperliquidMarketFailureKind.timeout,
      DioExceptionType.connectionError || DioExceptionType.badCertificate =>
        HyperliquidMarketFailureKind.connection,
      DioExceptionType.badResponse => HyperliquidMarketFailureKind.unavailable,
      DioExceptionType.cancel => HyperliquidMarketFailureKind.cancelled,
      DioExceptionType.unknown => HyperliquidMarketFailureKind.unexpected,
    };
    return HyperliquidMarketFailure(
      kind,
      statusCode: error.response?.statusCode,
    );
  }
}

final class _SpotToken {
  const _SpotToken({
    required this.index,
    required this.symbol,
    required this.sizeDecimals,
    required this.tokenId,
  });

  final int index;
  final String symbol;
  final int sizeDecimals;
  final String tokenId;
}
