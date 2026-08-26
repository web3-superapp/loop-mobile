import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_candle_repository.dart';

void main() {
  group('DioHyperliquidSpotCandleRepository', () {
    test(
      'posts one bounded public Testnet request and preserves exact OHLCV',
      () async {
        RequestOptions? capturedRequest;
        final requestedUntil = DateTime.utc(2026, 8, 26, 12, 34, 56, 789);
        final receivedAt = requestedUntil.add(
          const Duration(milliseconds: 345),
        );
        final clock = _SequenceClock(<DateTime>[requestedUntil, receivedAt]);
        final firstOpen = requestedUntil
            .subtract(const Duration(hours: 8))
            .millisecondsSinceEpoch;
        final secondOpen = requestedUntil
            .subtract(const Duration(hours: 4))
            .millisecondsSinceEpoch;
        final repository = DioHyperliquidSpotCandleRepository(
          _respondingDio(<Object?>[
            _candle(
              openTime: firstOpen,
              closeTime:
                  firstOpen + const Duration(hours: 4).inMilliseconds - 1,
              interval: '4h',
              open: '12.500000000000000001',
              close: '13.000000000000000001',
              high: '13.250000000000000001',
              low: '12.250000000000000001',
              volume: '9876543.210000000000000001',
              trades: 42,
            ),
            _candle(
              openTime: secondOpen,
              closeTime:
                  secondOpen + const Duration(hours: 4).inMilliseconds - 1,
              interval: '4h',
              open: '13.000000000000000001',
              close: '12.750000000000000001',
              high: '13.100000000000000001',
              low: '12.500000000000000001',
              volume: '100.000000000000000001',
              trades: 7,
            ),
          ], onRequest: (request) => capturedRequest = request),
          now: clock.call,
        );

        final snapshot = await repository.fetchCandles(
          providerCoin: '@1035',
          interval: HyperliquidSpotCandleInterval.fourHours,
        );

        expect(capturedRequest?.method, 'POST');
        expect(
          capturedRequest?.uri,
          Uri.parse('https://api.hyperliquid-testnet.xyz/info'),
        );
        expect(capturedRequest?.data, <String, Object?>{
          'type': 'candleSnapshot',
          'req': <String, Object?>{
            'coin': '@1035',
            'interval': '4h',
            'startTime': requestedUntil
                .subtract(const Duration(hours: 480))
                .millisecondsSinceEpoch,
            'endTime': requestedUntil.millisecondsSinceEpoch,
          },
        });
        expect(snapshot.providerCoin, '@1035');
        expect(snapshot.interval, HyperliquidSpotCandleInterval.fourHours);
        expect(
          snapshot.requestedFrom,
          requestedUntil.subtract(const Duration(hours: 480)),
        );
        expect(snapshot.requestedUntil, requestedUntil);
        expect(snapshot.receivedAt, receivedAt);
        expect(snapshot.candles, hasLength(2));

        final candle = snapshot.candles.first;
        expect(candle.openTime.millisecondsSinceEpoch, firstOpen);
        expect(candle.closeTime.isUtc, isTrue);
        expect(candle.providerCoin, '@1035');
        expect(candle.interval, HyperliquidSpotCandleInterval.fourHours);
        expect(candle.open.source, '12.500000000000000001');
        expect(candle.open.value, Decimal.parse('12.500000000000000001'));
        expect(candle.close.source, '13.000000000000000001');
        expect(candle.high.source, '13.250000000000000001');
        expect(candle.low.source, '12.250000000000000001');
        expect(candle.volume.source, '9876543.210000000000000001');
        expect(candle.tradeCount, 42);
        expect(() => snapshot.candles.add(candle), throwsUnsupportedError);
      },
    );

    test('uses the reviewed bounded window for every mounted period', () async {
      final cases = <HyperliquidSpotCandleInterval, (Duration, Duration)>{
        HyperliquidSpotCandleInterval.oneHour: (
          const Duration(hours: 120),
          const Duration(hours: 1),
        ),
        HyperliquidSpotCandleInterval.fourHours: (
          const Duration(hours: 480),
          const Duration(hours: 4),
        ),
        HyperliquidSpotCandleInterval.oneDay: (
          const Duration(days: 120),
          const Duration(days: 1),
        ),
        HyperliquidSpotCandleInterval.oneWeek: (
          const Duration(days: 840),
          const Duration(days: 7),
        ),
        HyperliquidSpotCandleInterval.oneMonth: (
          const Duration(days: 3600),
          const Duration(days: 30),
        ),
      };
      final requestedUntil = DateTime.utc(2026, 8, 26, 12);

      for (final MapEntry(key: interval, value: expected) in cases.entries) {
        RequestOptions? capturedRequest;
        final repository = DioHyperliquidSpotCandleRepository(
          _respondingDio(
            const <Object?>[],
            onRequest: (request) => capturedRequest = request,
          ),
          now: () => requestedUntil,
        );

        final snapshot = await repository.fetchCandles(
          providerCoin: '@1035',
          interval: interval,
        );

        final data = capturedRequest?.data! as Map<String, Object?>;
        final request = data['req']! as Map<String, Object?>;
        expect(request['interval'], interval.wireValue);
        expect(
          request['startTime'],
          requestedUntil.subtract(expected.$1).millisecondsSinceEpoch,
        );
        expect(interval.candleDuration, expected.$2);
        expect(snapshot.candles, isEmpty);
      }
    });

    test('captures receipt time before parsing response rows', () async {
      final requestedUntil = DateTime.utc(2026, 8, 26, 12);
      final receivedAt = requestedUntil.add(const Duration(seconds: 2));
      final afterParsingStarted = receivedAt.add(const Duration(seconds: 3));
      var clock = requestedUntil;
      var clockReads = 0;
      final row = _ReadObservedMap(
        _candle(
          openTime: requestedUntil
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch,
          closeTime: requestedUntil.millisecondsSinceEpoch - 1,
        ),
        onRead: () => clock = afterParsingStarted,
      );
      final repository = DioHyperliquidSpotCandleRepository(
        _respondingDio(<Object?>[row]),
        now: () {
          clockReads += 1;
          return clockReads == 1 ? requestedUntil : receivedAt;
        },
      );

      final snapshot = await repository.fetchCandles(
        providerCoin: '@1035',
        interval: HyperliquidSpotCandleInterval.oneHour,
      );

      expect(snapshot.receivedAt, receivedAt);
      expect(clock, afterParsingStarted);
    });

    test(
      'accepts an overlapping first candle and gaps without fabrication',
      () async {
        final requestedUntil = DateTime.utc(2026, 8, 26, 12);
        final requestedFrom = requestedUntil.subtract(
          HyperliquidSpotCandleInterval.oneHour.lookback,
        );
        final overlappingOpen = requestedFrom
            .subtract(const Duration(minutes: 30))
            .millisecondsSinceEpoch;
        final lateOpen = requestedUntil
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch;
        final repository = DioHyperliquidSpotCandleRepository(
          _respondingDio(<Object?>[
            _candle(
              openTime: overlappingOpen,
              closeTime:
                  overlappingOpen +
                  HyperliquidSpotCandleInterval
                      .oneHour
                      .candleDuration
                      .inMilliseconds -
                  1,
            ),
            _candle(
              openTime: lateOpen,
              closeTime: requestedUntil.millisecondsSinceEpoch - 1,
            ),
          ]),
          now: () => requestedUntil,
        );

        final snapshot = await repository.fetchCandles(
          providerCoin: '@1035',
          interval: HyperliquidSpotCandleInterval.oneHour,
        );

        expect(snapshot.candles, hasLength(2));
        expect(snapshot.candles.first.openTime.isBefore(requestedFrom), isTrue);
        expect(snapshot.candles.last.openTime.millisecondsSinceEpoch, lateOpen);
      },
    );

    test('rejects short and long durations for every mounted interval', () async {
      final now = DateTime.utc(2026, 8, 26, 12);

      for (final interval in HyperliquidSpotCandleInterval.values) {
        final openTime = now
            .subtract(interval.candleDuration)
            .millisecondsSinceEpoch;
        final expectedClose =
            openTime + interval.candleDuration.inMilliseconds - 1;
        for (final closeTime in <int>[expectedClose - 1, expectedClose + 1]) {
          final repository = DioHyperliquidSpotCandleRepository(
            _respondingDio(<Object?>[
              _candle(
                openTime: openTime,
                closeTime: closeTime,
                interval: interval.wireValue,
              ),
            ]),
            now: () => now,
          );

          await expectLater(
            repository.fetchCandles(providerCoin: '@1035', interval: interval),
            throwsA(_failure(HyperliquidMarketFailureKind.invalidPayload)),
            reason:
                '${interval.wireValue} must reject close $closeTime instead of $expectedClose',
          );
        }
      }
    });

    test('rejects numeric values and inconsistent candle identity', () async {
      final now = DateTime.utc(2026, 8, 26, 12);
      final openTime = now
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      final malformedRows = <Map<String, Object?>>[
        _candle(openTime: openTime, closeTime: now.millisecondsSinceEpoch - 1)
          ..['o'] = 12.5,
        _candle(openTime: openTime, closeTime: now.millisecondsSinceEpoch - 1)
          ..['s'] = '@9',
        _candle(openTime: openTime, closeTime: now.millisecondsSinceEpoch - 1)
          ..['i'] = '4h',
      ];

      for (final row in malformedRows) {
        final repository = DioHyperliquidSpotCandleRepository(
          _respondingDio(<Object?>[row]),
          now: () => now,
        );

        await expectLater(
          repository.fetchCandles(
            providerCoin: '@1035',
            interval: HyperliquidSpotCandleInterval.oneHour,
          ),
          throwsA(_failure(HyperliquidMarketFailureKind.invalidPayload)),
        );
      }
    });

    test('rejects invalid OHLC bounds', () async {
      final now = DateTime.utc(2026, 8, 26, 12);
      final secondOpen = now
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      final invalidOhlc = _candle(
        openTime: secondOpen,
        closeTime: now.millisecondsSinceEpoch - 1,
      )..['h'] = '0.5';
      final repository = DioHyperliquidSpotCandleRepository(
        _respondingDio(<Object?>[invalidOhlc]),
        now: () => now,
      );

      await expectLater(
        repository.fetchCandles(
          providerCoin: '@1035',
          interval: HyperliquidSpotCandleInterval.oneHour,
        ),
        throwsA(_failure(HyperliquidMarketFailureKind.invalidPayload)),
      );
    });

    test(
      'sorts, deduplicates, and retains only the latest bounded rows',
      () async {
        final now = DateTime.utc(2026, 8, 26, 12);
        const interval = HyperliquidSpotCandleInterval.oneHour;
        final candleMilliseconds = interval.candleDuration.inMilliseconds;
        final requestedFrom = now.subtract(interval.lookback);
        final firstOpen =
            requestedFrom.millisecondsSinceEpoch - candleMilliseconds + 1;
        final rows = List<Object?>.generate(
          121,
          (index) => _candle(
            openTime: firstOpen + (index * candleMilliseconds),
            closeTime:
                firstOpen +
                (index * candleMilliseconds) +
                candleMilliseconds -
                1,
          ),
        );
        rows.insert(
          0,
          _candle(
            openTime: firstOpen + (120 * candleMilliseconds),
            closeTime:
                firstOpen + (120 * candleMilliseconds) + candleMilliseconds - 1,
            close: '1.5',
            high: '1.5',
          ),
        );
        rows.insert(0, rows.removeLast());
        final repository = DioHyperliquidSpotCandleRepository(
          _respondingDio(rows),
          now: () => now,
        );

        final snapshot = await repository.fetchCandles(
          providerCoin: '@1035',
          interval: interval,
        );

        expect(snapshot.candles, hasLength(120));
        expect(
          snapshot.candles.first.openTime.millisecondsSinceEpoch,
          firstOpen + candleMilliseconds,
        );
        expect(snapshot.candles.last.close.source, '1.5');
        expect(
          snapshot.candles.map((candle) => candle.openTime).toList(),
          orderedEquals(
            snapshot.candles.map((candle) => candle.openTime).toList()..sort(),
          ),
        );
      },
    );

    test('rejects identifiers before issuing a provider request', () async {
      var requestCount = 0;
      final repository = DioHyperliquidSpotCandleRepository(
        _respondingDio(const <Object?>[], onRequest: (_) => requestCount += 1),
      );

      await expectLater(
        repository.fetchCandles(
          providerCoin: ' @1035',
          interval: HyperliquidSpotCandleInterval.oneHour,
        ),
        throwsA(_failure(HyperliquidMarketFailureKind.invalidPayload)),
      );
      expect(requestCount, 0);
    });

    test(
      'maps Dio failures without exposing provider response bodies',
      () async {
        final cases = <(DioExceptionType, HyperliquidMarketFailureKind, int?)>[
          (
            DioExceptionType.connectionTimeout,
            HyperliquidMarketFailureKind.timeout,
            null,
          ),
          (
            DioExceptionType.connectionError,
            HyperliquidMarketFailureKind.connection,
            null,
          ),
          (
            DioExceptionType.badResponse,
            HyperliquidMarketFailureKind.unavailable,
            503,
          ),
          (
            DioExceptionType.cancel,
            HyperliquidMarketFailureKind.cancelled,
            null,
          ),
        ];

        for (final (dioKind, expectedKind, statusCode) in cases) {
          final repository = DioHyperliquidSpotCandleRepository(
            _failingDio(dioKind, statusCode: statusCode),
          );

          await expectLater(
            repository.fetchCandles(
              providerCoin: '@1035',
              interval: HyperliquidSpotCandleInterval.oneHour,
            ),
            throwsA(
              _failure(expectedKind)
                  .having(
                    (failure) => failure.statusCode,
                    'statusCode',
                    statusCode,
                  )
                  .having(
                    (failure) => failure.toString(),
                    'sanitized description',
                    isNot(contains('server-token')),
                  ),
            ),
          );
        }
      },
    );
  });
}

Map<String, Object?> _candle({
  required int openTime,
  required int closeTime,
  String open = '1',
  String close = '1',
  String high = '1',
  String low = '1',
  String volume = '0',
  int trades = 0,
  String interval = '1h',
}) {
  return <String, Object?>{
    't': openTime,
    'T': closeTime,
    's': '@1035',
    'i': interval,
    'o': open,
    'c': close,
    'h': high,
    'l': low,
    'v': volume,
    'n': trades,
  };
}

Dio _respondingDio(
  Object? payload, {
  void Function(RequestOptions)? onRequest,
}) {
  return Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          onRequest?.call(options);
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: payload,
            ),
          );
        },
      ),
    );
}

Dio _failingDio(DioExceptionType type, {int? statusCode}) {
  return Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final response = statusCode == null
              ? null
              : Response<Object?>(
                  requestOptions: options,
                  statusCode: statusCode,
                  data: const <String, String>{
                    'secret': 'server-token must never surface',
                  },
                );
          handler.reject(
            DioException(
              requestOptions: options,
              response: response,
              type: type,
            ),
          );
        },
      ),
    );
}

final class _SequenceClock {
  _SequenceClock(this._values);

  final List<DateTime> _values;
  int _index = 0;

  DateTime call() {
    final index = _index < _values.length ? _index : _values.length - 1;
    final value = _values[index];
    _index += 1;
    return value;
  }
}

final class _ReadObservedMap extends MapBase<String, Object?> {
  _ReadObservedMap(this._values, {required this.onRead});

  final Map<String, Object?> _values;
  final void Function() onRead;

  @override
  Object? operator [](Object? key) {
    onRead();
    return _values[key];
  }

  @override
  void operator []=(String key, Object? value) => _values[key] = value;

  @override
  void clear() => _values.clear();

  @override
  Iterable<String> get keys => _values.keys;

  @override
  Object? remove(Object? key) => _values.remove(key);
}

TypeMatcher<HyperliquidMarketFailure> _failure(
  HyperliquidMarketFailureKind kind,
) {
  return isA<HyperliquidMarketFailure>().having(
    (failure) => failure.kind,
    'kind',
    kind,
  );
}
