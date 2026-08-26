import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';

abstract interface class HyperliquidSpotCandleRepository {
  Future<HyperliquidSpotCandleSnapshot> fetchCandles({
    required String providerCoin,
    required HyperliquidSpotCandleInterval interval,
  });
}

/// Fetches bounded public candle history from Hyperliquid Testnet only.
///
/// It has no identity, account, balance, order, transfer, signing, nonce, key,
/// or execution capability. The provider coin must come from an already
/// accepted `spotMetaAndAssetCtxs` universe row.
final class DioHyperliquidSpotCandleRepository
    implements HyperliquidSpotCandleRepository {
  DioHyperliquidSpotCandleRepository(this._dio, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static final Uri endpoint = Uri.https('api.hyperliquid-testnet.xyz', '/info');

  /// The detail chart intentionally retains only its most recent 120 rows.
  static const maximumCandles = 120;

  final Dio _dio;
  final DateTime Function() _now;

  @override
  Future<HyperliquidSpotCandleSnapshot> fetchCandles({
    required String providerCoin,
    required HyperliquidSpotCandleInterval interval,
  }) async {
    _validateIdentifier(providerCoin);
    final requestedUntilMilliseconds = _now().toUtc().millisecondsSinceEpoch;
    final requestedFromMilliseconds =
        requestedUntilMilliseconds - interval.lookback.inMilliseconds;
    if (requestedFromMilliseconds < 0) throw _invalidPayload();

    final requestedFrom = DateTime.fromMillisecondsSinceEpoch(
      requestedFromMilliseconds,
      isUtc: true,
    );
    final requestedUntil = DateTime.fromMillisecondsSinceEpoch(
      requestedUntilMilliseconds,
      isUtc: true,
    );
    final requestPayload = <String, Object?>{
      'type': 'candleSnapshot',
      'req': <String, Object?>{
        'coin': providerCoin,
        'interval': interval.wireValue,
        'startTime': requestedFromMilliseconds,
        'endTime': requestedUntilMilliseconds,
      },
    };

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
      return _parseSnapshot(
        response.data,
        providerCoin: providerCoin,
        interval: interval,
        requestedFrom: requestedFrom,
        requestedUntil: requestedUntil,
        receivedAt: receivedAt,
      );
    } on DioException catch (error) {
      throw _mapDioFailure(error);
    }
  }

  HyperliquidSpotCandleSnapshot _parseSnapshot(
    Object? payload, {
    required String providerCoin,
    required HyperliquidSpotCandleInterval interval,
    required DateTime requestedFrom,
    required DateTime requestedUntil,
    required DateTime receivedAt,
  }) {
    if (payload is! List<Object?>) throw _invalidPayload();

    final candlesByOpenTime = <int, HyperliquidSpotCandle>{};
    for (final row in payload) {
      final candle = _parseCandle(
        _map(row),
        providerCoin: providerCoin,
        interval: interval,
        requestedFrom: requestedFrom,
        requestedUntil: requestedUntil,
      );
      candlesByOpenTime[candle.openTime.millisecondsSinceEpoch] = candle;
    }
    final ordered = candlesByOpenTime.values.toList(growable: false)
      ..sort((left, right) => left.openTime.compareTo(right.openTime));
    final retained = ordered.length <= maximumCandles
        ? ordered
        : ordered.sublist(ordered.length - maximumCandles);

    return HyperliquidSpotCandleSnapshot(
      providerCoin: providerCoin,
      interval: interval,
      requestedFrom: requestedFrom,
      requestedUntil: requestedUntil,
      receivedAt: receivedAt,
      candles: retained,
    );
  }

  HyperliquidSpotCandle _parseCandle(
    Map<String, Object?> source, {
    required String providerCoin,
    required HyperliquidSpotCandleInterval interval,
    required DateTime requestedFrom,
    required DateTime requestedUntil,
  }) {
    final openTimeMilliseconds = _nonNegativeInt(source['t']);
    final closeTimeMilliseconds = _nonNegativeInt(source['T']);
    final tradeCount = _nonNegativeInt(source['n']);
    final sourceCoin = _identifier(source['s']);
    final sourceInterval = _identifier(source['i']);
    if (sourceCoin != providerCoin || sourceInterval != interval.wireValue) {
      throw _invalidPayload();
    }
    final expectedCloseTimeMilliseconds =
        openTimeMilliseconds + interval.candleDuration.inMilliseconds - 1;
    if (closeTimeMilliseconds != expectedCloseTimeMilliseconds ||
        closeTimeMilliseconds < requestedFrom.millisecondsSinceEpoch ||
        openTimeMilliseconds > requestedUntil.millisecondsSinceEpoch) {
      throw _invalidPayload();
    }

    final open = _positiveDecimal(source, 'o');
    final close = _positiveDecimal(source, 'c');
    final high = _positiveDecimal(source, 'h');
    final low = _positiveDecimal(source, 'l');
    final volume = _nonNegativeDecimal(source, 'v');
    if (high.value < low.value ||
        high.value < open.value ||
        high.value < close.value ||
        low.value > open.value ||
        low.value > close.value) {
      throw _invalidPayload();
    }

    return HyperliquidSpotCandle(
      openTime: _utcTime(openTimeMilliseconds),
      closeTime: _utcTime(closeTimeMilliseconds),
      providerCoin: providerCoin,
      interval: interval,
      open: open,
      close: close,
      high: high,
      low: low,
      volume: volume,
      tradeCount: tradeCount,
    );
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    throw _invalidPayload();
  }

  int _nonNegativeInt(Object? value) {
    if (value is int && value >= 0) return value;
    throw _invalidPayload();
  }

  String _identifier(Object? value) {
    if (value is! String) throw _invalidPayload();
    _validateIdentifier(value);
    return value;
  }

  void _validateIdentifier(String value) {
    if (value.isEmpty || value.length > 128 || value.trim() != value) {
      throw _invalidPayload();
    }
    for (final codePoint in value.runes) {
      if (codePoint < 0x20 || codePoint == 0x7f) throw _invalidPayload();
    }
  }

  HyperliquidSpotDecimal _positiveDecimal(
    Map<String, Object?> source,
    String key,
  ) {
    final decimal = _decimal(source, key);
    if (decimal.value <= Decimal.zero) throw _invalidPayload();
    return decimal;
  }

  HyperliquidSpotDecimal _nonNegativeDecimal(
    Map<String, Object?> source,
    String key,
  ) {
    final decimal = _decimal(source, key);
    if (decimal.value < Decimal.zero) throw _invalidPayload();
    return decimal;
  }

  HyperliquidSpotDecimal _decimal(Map<String, Object?> source, String key) {
    final wireValue = source[key];
    if (wireValue is! String) throw _invalidPayload();
    final value = Decimal.tryParse(wireValue);
    if (value == null) throw _invalidPayload();
    return HyperliquidSpotDecimal(source: wireValue, value: value);
  }

  DateTime _utcTime(int milliseconds) {
    try {
      return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
    } on RangeError {
      throw _invalidPayload();
    }
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
