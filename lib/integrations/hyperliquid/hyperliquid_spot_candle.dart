import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';

/// The five public candle periods mounted on the Spot detail surface.
///
/// Every request is deliberately bounded to roughly 120 candles. Hyperliquid
/// applies additional public rate-limit weight per 60 returned candles, so the
/// mobile client does not request the provider's full retained history.
enum HyperliquidSpotCandleInterval {
  oneHour(
    wireValue: '1h',
    displayLabel: '1H',
    candleDuration: Duration(hours: 1),
    lookback: Duration(hours: 120),
  ),
  fourHours(
    wireValue: '4h',
    displayLabel: '4H',
    candleDuration: Duration(hours: 4),
    lookback: Duration(hours: 480),
  ),
  oneDay(
    wireValue: '1d',
    displayLabel: '1D',
    candleDuration: Duration(days: 1),
    lookback: Duration(days: 120),
  ),
  oneWeek(
    wireValue: '1w',
    displayLabel: '1W',
    candleDuration: Duration(days: 7),
    lookback: Duration(days: 840),
  ),
  oneMonth(
    wireValue: '1M',
    displayLabel: '1M',
    candleDuration: Duration(days: 30),
    lookback: Duration(days: 3600),
  );

  const HyperliquidSpotCandleInterval({
    required this.wireValue,
    required this.displayLabel,
    required this.candleDuration,
    required this.lookback,
  });

  final String wireValue;
  final String displayLabel;
  final Duration candleDuration;
  final Duration lookback;
}

/// Stable family key for one provider coin and one public candle period.
final class HyperliquidSpotCandleRequest {
  const HyperliquidSpotCandleRequest({
    required this.providerCoin,
    required this.interval,
  });

  final String providerCoin;
  final HyperliquidSpotCandleInterval interval;

  @override
  bool operator ==(Object other) {
    return other is HyperliquidSpotCandleRequest &&
        other.providerCoin == providerCoin &&
        other.interval == interval;
  }

  @override
  int get hashCode => Object.hash(providerCoin, interval);
}

/// One exact OHLCV row returned by Hyperliquid Testnet `candleSnapshot`.
final class HyperliquidSpotCandle {
  HyperliquidSpotCandle({
    required DateTime openTime,
    required DateTime closeTime,
    required this.providerCoin,
    required this.interval,
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.volume,
    required this.tradeCount,
  }) : openTime = openTime.toUtc(),
       closeTime = closeTime.toUtc();

  final DateTime openTime;
  final DateTime closeTime;
  final String providerCoin;
  final HyperliquidSpotCandleInterval interval;
  final HyperliquidSpotDecimal open;
  final HyperliquidSpotDecimal close;
  final HyperliquidSpotDecimal high;
  final HyperliquidSpotDecimal low;
  final HyperliquidSpotDecimal volume;
  final int tradeCount;
}

/// One bounded, attributable public candle response received by the client.
final class HyperliquidSpotCandleSnapshot {
  HyperliquidSpotCandleSnapshot({
    required this.providerCoin,
    required this.interval,
    required DateTime requestedFrom,
    required DateTime requestedUntil,
    required DateTime receivedAt,
    required List<HyperliquidSpotCandle> candles,
  }) : requestedFrom = requestedFrom.toUtc(),
       requestedUntil = requestedUntil.toUtc(),
       receivedAt = receivedAt.toUtc(),
       candles = List<HyperliquidSpotCandle>.unmodifiable(candles);

  static const sourceLabel = 'Hyperliquid Testnet public candleSnapshot';

  final String providerCoin;
  final HyperliquidSpotCandleInterval interval;
  final DateTime requestedFrom;
  final DateTime requestedUntil;

  /// Local receive time, not an exchange event or candle timestamp.
  final DateTime receivedAt;
  final List<HyperliquidSpotCandle> candles;
}
