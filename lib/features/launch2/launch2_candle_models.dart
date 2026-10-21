import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';

/// The bucket widths the project page's K line offers (decision 0227). The
/// server answers exactly these six (`LAUNCH2_CANDLE_INTERVAL_INVALID`
/// otherwise).
enum Launch2CandleInterval {
  oneMinute('1m', '1分', LoopCandleInterval.fifteenMinutes),
  fiveMinutes('5m', '5分', LoopCandleInterval.fifteenMinutes),
  fifteenMinutes('15m', '15分', LoopCandleInterval.fifteenMinutes),
  oneHour('1h', '1时', LoopCandleInterval.oneHour),
  fourHours('4h', '4时', LoopCandleInterval.fourHours),
  oneDay('1d', '1天', LoopCandleInterval.oneDay);

  const Launch2CandleInterval(this.wireName, this.label, this.axis);

  final String wireName;

  /// The capsule's text.
  final String label;

  /// The shared chart's interval whose time labels fit this width: every
  /// intraday width reads as a clock.
  final LoopCandleInterval axis;

  Duration get width => switch (this) {
    Launch2CandleInterval.oneMinute => const Duration(minutes: 1),
    Launch2CandleInterval.fiveMinutes => const Duration(minutes: 5),
    Launch2CandleInterval.fifteenMinutes => const Duration(minutes: 15),
    Launch2CandleInterval.oneHour => const Duration(hours: 1),
    Launch2CandleInterval.fourHours => const Duration(hours: 4),
    Launch2CandleInterval.oneDay => const Duration(days: 1),
  };

  static Launch2CandleInterval? tryParse(Object? value) {
    for (final interval in values) {
      if (interval.wireName == value) return interval;
    }
    return null;
  }
}

/// Which market the buckets were built from: the 内盘 curve, the official
/// pool, or both across the graduation.
enum Launch2CandleSource {
  curve('curve'),
  pool('pool'),
  mixed('mixed'),

  /// A value this build does not know; drawn like [mixed].
  unknown('unknown');

  const Launch2CandleSource(this.wireName);

  final String wireName;

  static Launch2CandleSource parse(Object? value) {
    for (final source in values) {
      if (source != unknown && source.wireName == value) return source;
    }
    return unknown;
  }
}

/// One bucket of `GET …/candles`. Prices are USD1 per MEME; every figure
/// stays a [Decimal].
@immutable
final class Launch2Candle {
  const Launch2Candle({
    required this.openTime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volumeMeme,
    required this.quoteUsd1,
    required this.tradeCount,
  });

  /// The bucket's start (`t`, unix seconds, UTC).
  final DateTime openTime;
  final Decimal open;
  final Decimal high;
  final Decimal low;
  final Decimal close;

  /// MEME traded (`v`).
  final Decimal volumeMeme;

  /// USD1 traded (`q`).
  final Decimal quoteUsd1;

  /// Trades in the bucket (`n`). A bucket the server filled with the last
  /// close has 0.
  final int tradeCount;

  /// The shared chart's bucket. [now] decides whether it is still open.
  LoopCandle toChart(Duration width, DateTime now) {
    final closeTime = openTime.add(width);
    return LoopCandle(
      openTime: openTime,
      closeTime: closeTime,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volumeMeme,
      swapCount: tradeCount,
      isOpen: closeTime.isAfter(now),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Launch2Candle &&
      other.openTime == openTime &&
      other.open == open &&
      other.high == high &&
      other.low == low &&
      other.close == close &&
      other.volumeMeme == volumeMeme &&
      other.quoteUsd1 == quoteUsd1 &&
      other.tradeCount == tradeCount;

  @override
  int get hashCode => Object.hash(
    openTime,
    open,
    high,
    low,
    close,
    volumeMeme,
    quoteUsd1,
    tradeCount,
  );
}

/// `latest`: the last traded price, or the starting price before any trade.
@immutable
final class Launch2CandleLatest {
  const Launch2CandleLatest({required this.price, required this.at});

  final Decimal price;
  final DateTime at;
}

/// One answer of `GET …/candles`: buckets ascending by [Launch2Candle.openTime].
@immutable
final class Launch2CandleSeries {
  const Launch2CandleSeries({
    required this.instanceId,
    required this.interval,
    required this.quoteAsset,
    required this.source,
    required this.candles,
    required this.latest,
  });

  final String instanceId;
  final Launch2CandleInterval interval;
  final String quoteAsset;
  final Launch2CandleSource source;
  final List<Launch2Candle> candles;
  final Launch2CandleLatest? latest;
}

/// The page size the project page asks for, and the server's own bounds.
const int launch2CandlePageSize = 200;
const int launch2CandleMaxLimit = 500;
