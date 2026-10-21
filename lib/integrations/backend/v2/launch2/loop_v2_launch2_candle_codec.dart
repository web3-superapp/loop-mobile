import 'package:decimal/decimal.dart';
import 'package:loop_mobile/features/launch2/launch2_candle_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_chain_codec.dart';

/// The decoder for `GET /v2/launch2/instances/{id}/candles` (loop-api S267,
/// client decision 0227).
///
/// Unlike the rest of `launch2`, this read is **lenient by contract**: an
/// unknown key is ignored and a missing optional field takes its neutral
/// value, so a server that adds a field (or a bucket that leaves `v` out)
/// never blanks the chart. What it will not do is invent a price: a bucket
/// without a readable `t` or `c` is dropped, and a root that is not an
/// object is an invalid payload.
abstract final class LoopV2Launch2CandleCodec {
  /// A non-negative decimal as the server writes it (`"0.00004167"`).
  static final RegExp _decimalPattern = RegExp(
    r'^(0|[1-9][0-9]{0,40})(\.[0-9]{1,30})?$',
  );

  static Launch2CandleSeries series(
    Object? raw, {
    required String instanceId,
    required Launch2CandleInterval requested,
  }) {
    if (raw is! Map) LoopV2ChainCodec.invalid();
    final root = raw.cast<Object?, Object?>();
    final rawCandles = root['candles'];
    if (rawCandles != null && rawCandles is! List) LoopV2ChainCodec.invalid();
    final byTime = <int, Launch2Candle>{};
    for (final entry in (rawCandles as List?) ?? const <Object?>[]) {
      final candle = _candle(entry);
      if (candle == null) continue;
      // One bucket per start; a repeated start keeps the later one.
      byTime[candle.openTime.millisecondsSinceEpoch] = candle;
    }
    final candles = byTime.values.toList()
      ..sort((a, b) => a.openTime.compareTo(b.openTime));
    final quote = root['quoteAsset'];
    final id = root['instanceId'];
    return Launch2CandleSeries(
      instanceId: id is String && id.isNotEmpty ? id : instanceId,
      interval: Launch2CandleInterval.tryParse(root['interval']) ?? requested,
      quoteAsset: quote is String && quote.isNotEmpty ? quote : 'USD1',
      source: Launch2CandleSource.parse(root['source']),
      candles: List<Launch2Candle>.unmodifiable(candles),
      latest: _latest(root['latest']),
    );
  }

  static Launch2Candle? _candle(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    final openTime = _seconds(map['t']);
    final close = _decimal(map['c']);
    if (openTime == null || close == null) return null;
    final open = _decimal(map['o']) ?? close;
    var high = _decimal(map['h']) ?? close;
    var low = _decimal(map['l']) ?? close;
    // A bucket whose high or low does not bound its own open and close is
    // widened to do so, never drawn upside down.
    for (final value in <Decimal>[open, close]) {
      if (value > high) high = value;
      if (value < low) low = value;
    }
    final count = map['n'];
    return Launch2Candle(
      openTime: openTime,
      open: open,
      high: high,
      low: low,
      close: close,
      volumeMeme: _decimal(map['v']) ?? Decimal.zero,
      quoteUsd1: _decimal(map['q']) ?? Decimal.zero,
      tradeCount: count is int && count >= 0 ? count : 0,
    );
  }

  static Launch2CandleLatest? _latest(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    final price = _decimal(map['price']);
    final at = _seconds(map['at']);
    if (price == null || at == null) return null;
    return Launch2CandleLatest(price: price, at: at);
  }

  static DateTime? _seconds(Object? raw) {
    if (raw is! num || raw < 0 || raw != raw.truncate()) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw.toInt() * 1000, isUtc: true);
  }

  static Decimal? _decimal(Object? raw) {
    if (raw is! String || raw.length > 72) return null;
    if (!_decimalPattern.hasMatch(raw)) return null;
    return Decimal.parse(raw);
  }
}
