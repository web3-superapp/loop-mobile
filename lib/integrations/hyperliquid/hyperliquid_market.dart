import 'package:decimal/decimal.dart';

/// A decimal received from Hyperliquid without passing through a binary float.
final class ExactDecimal {
  const ExactDecimal({required this.source, required this.value});

  /// The exact wire representation returned by Hyperliquid.
  final String source;

  /// The parsed value for exact comparisons and calculations.
  final Decimal value;

  @override
  bool operator ==(Object other) {
    return other is ExactDecimal &&
        other.source == source &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(source, value);

  @override
  String toString() => source;
}

/// Public, read-only market data for one active Hyperliquid perpetual asset.
final class HyperliquidMarket {
  const HyperliquidMarket({
    required this.symbol,
    required this.sizeDecimals,
    required this.maxLeverage,
    required this.markPrice,
    required this.dayNotionalVolume,
    required this.fundingRate,
  });

  final String symbol;
  final int sizeDecimals;
  final int maxLeverage;
  final ExactDecimal markPrice;
  final ExactDecimal dayNotionalVolume;
  final ExactDecimal fundingRate;
}
