import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';

abstract interface class HyperliquidMarketRepository {
  Future<List<HyperliquidMarket>> fetchMarkets();
}

/// Fetches public perpetual-market data from Hyperliquid Testnet only.
///
/// This adapter has no account, position, order, cancellation, transfer,
/// withdrawal, key, nonce, or signing capability.
final class DioHyperliquidMarketRepository
    implements HyperliquidMarketRepository {
  DioHyperliquidMarketRepository(this._dio);

  static final Uri endpoint = Uri.https('api.hyperliquid-testnet.xyz', '/info');

  static const Map<String, String> requestPayload = <String, String>{
    'type': 'metaAndAssetCtxs',
  };

  final Dio _dio;

  @override
  Future<List<HyperliquidMarket>> fetchMarkets() async {
    try {
      final response = await _dio.post<Object?>(
        endpoint.toString(),
        data: requestPayload,
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
        ),
      );
      return _parseMarkets(response.data);
    } on DioException catch (error) {
      throw _mapDioFailure(error);
    }
  }

  List<HyperliquidMarket> _parseMarkets(Object? payload) {
    if (payload is! List<Object?> || payload.length != 2) {
      throw const HyperliquidMarketFailure(
        HyperliquidMarketFailureKind.invalidPayload,
      );
    }

    final metadata = _map(payload[0]);
    final universe = _list(metadata['universe']);
    final contexts = _list(payload[1]);
    if (universe.length != contexts.length) {
      throw const HyperliquidMarketFailure(
        HyperliquidMarketFailureKind.invalidPayload,
      );
    }

    final markets = <HyperliquidMarket>[];
    final symbols = <String>{};
    for (var index = 0; index < universe.length; index += 1) {
      final asset = _map(universe[index]);
      final isDelisted = asset['isDelisted'];
      if (isDelisted != null && isDelisted is! bool) {
        throw const HyperliquidMarketFailure(
          HyperliquidMarketFailureKind.invalidPayload,
        );
      }
      if (isDelisted == true) {
        continue;
      }

      final symbol = asset['name'];
      final sizeDecimals = asset['szDecimals'];
      final maxLeverage = asset['maxLeverage'];
      if (symbol is! String ||
          symbol.isEmpty ||
          symbol.trim() != symbol ||
          sizeDecimals is! int ||
          sizeDecimals < 0 ||
          maxLeverage is! int ||
          maxLeverage <= 0 ||
          !symbols.add(symbol)) {
        throw const HyperliquidMarketFailure(
          HyperliquidMarketFailureKind.invalidPayload,
        );
      }

      final context = _map(contexts[index]);
      markets.add(
        HyperliquidMarket(
          symbol: symbol,
          sizeDecimals: sizeDecimals,
          maxLeverage: maxLeverage,
          markPrice: _decimal(context, 'markPx'),
          dayNotionalVolume: _decimal(context, 'dayNtlVlm'),
          fundingRate: _decimal(context, 'funding'),
        ),
      );
    }

    return List<HyperliquidMarket>.unmodifiable(markets);
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) {
      return value;
    }
    throw const HyperliquidMarketFailure(
      HyperliquidMarketFailureKind.invalidPayload,
    );
  }

  List<Object?> _list(Object? value) {
    if (value is List<Object?>) {
      return value;
    }
    throw const HyperliquidMarketFailure(
      HyperliquidMarketFailureKind.invalidPayload,
    );
  }

  ExactDecimal _decimal(Map<String, Object?> source, String key) {
    final wireValue = source[key];
    if (wireValue is! String) {
      throw const HyperliquidMarketFailure(
        HyperliquidMarketFailureKind.invalidPayload,
      );
    }
    final decimal = Decimal.tryParse(wireValue);
    if (decimal == null) {
      throw const HyperliquidMarketFailure(
        HyperliquidMarketFailureKind.invalidPayload,
      );
    }
    return ExactDecimal(source: wireValue, value: decimal);
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
