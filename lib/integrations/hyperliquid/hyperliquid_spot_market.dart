import 'package:decimal/decimal.dart';

/// A Hyperliquid spot decimal preserved exactly as it appeared on the wire.
final class HyperliquidSpotDecimal {
  const HyperliquidSpotDecimal({required this.source, required this.value});

  final String source;
  final Decimal value;

  @override
  bool operator ==(Object other) {
    return other is HyperliquidSpotDecimal &&
        other.source == source &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(source, value);

  @override
  String toString() => source;
}

/// Public, read-only facts for one Hyperliquid Testnet spot pair.
///
/// [providerCoin] is the protocol identifier used by later public candle/book
/// reads. User-facing identity comes from the indexed token metadata instead
/// of an opaque `@<index>` provider coin.
final class HyperliquidSpotMarket {
  const HyperliquidSpotMarket({
    required this.spotIndex,
    required this.providerCoin,
    required this.baseTokenIndex,
    required this.quoteTokenIndex,
    required this.baseTokenId,
    required this.quoteTokenId,
    required this.baseSymbol,
    required this.quoteSymbol,
    required this.baseSizeDecimals,
    required this.isCanonical,
    required this.markPrice,
    required this.previousDayPrice,
    required this.dayNotionalVolume,
    required this.dayBaseVolume,
    this.midPrice,
  });

  final int spotIndex;
  final String providerCoin;
  final int baseTokenIndex;
  final int quoteTokenIndex;
  final String baseTokenId;
  final String quoteTokenId;
  final String baseSymbol;
  final String quoteSymbol;
  final int baseSizeDecimals;
  final bool isCanonical;
  final HyperliquidSpotDecimal markPrice;
  final HyperliquidSpotDecimal? midPrice;
  final HyperliquidSpotDecimal previousDayPrice;
  final HyperliquidSpotDecimal dayNotionalVolume;
  final HyperliquidSpotDecimal dayBaseVolume;

  String get pair => '$baseSymbol/$quoteSymbol';

  bool get hasDayActivity => dayNotionalVolume.value > Decimal.zero;

  /// Exact display projection; it is not an executable quote.
  Decimal? get dayChangePercent {
    if (previousDayPrice.value <= Decimal.zero) return null;
    final ratio =
        (markPrice.value - previousDayPrice.value) / previousDayPrice.value;
    return ratio.toDecimal(scaleOnInfinitePrecision: 8) * Decimal.fromInt(100);
  }
}

/// One attributable public response received by the mobile client.
final class HyperliquidSpotSnapshot {
  HyperliquidSpotSnapshot({
    required DateTime receivedAt,
    required List<HyperliquidSpotMarket> markets,
  }) : receivedAt = receivedAt.toUtc(),
       markets = List<HyperliquidSpotMarket>.unmodifiable(markets);

  static const sourceLabel = 'Hyperliquid Testnet public spot info';

  /// Local receive time. Hyperliquid does not include a snapshot timestamp in
  /// `spotMetaAndAssetCtxs`, so this must not be presented as exchange time.
  final DateTime receivedAt;
  final List<HyperliquidSpotMarket> markets;
}
