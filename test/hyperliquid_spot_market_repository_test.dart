import 'dart:collection';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';

void main() {
  group('DioHyperliquidSpotMarketRepository', () {
    test(
      'posts the public Testnet request and joins sparse tokens and shuffled '
      'contexts by provider coin',
      () async {
        RequestOptions? capturedRequest;
        final receivedAt = DateTime(2026, 8, 25, 12, 34, 56, 789);
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                capturedRequest = options;
                handler.resolve(
                  Response<Object?>(
                    requestOptions: options,
                    statusCode: 200,
                    data: <Object?>[
                      <String, Object?>{
                        // Deliberately shuffled and sparse. Universe token
                        // references are protocol indices, not list offsets.
                        'tokens': <Object?>[
                          _token(
                            index: 905,
                            name: 'PURR',
                            sizeDecimals: 0,
                            tokenId: '0x00000000000000000000000000000905',
                          ),
                          _token(
                            index: 0,
                            name: 'USDC',
                            sizeDecimals: 6,
                            tokenId: '0x00000000000000000000000000000000',
                          ),
                          _token(
                            index: 42,
                            name: 'HYPE ',
                            sizeDecimals: 2,
                            tokenId: '0x00000000000000000000000000000042',
                          ),
                        ],
                        'universe': <Object?>[
                          <String, Object?>{
                            'name': '@1035',
                            'tokens': <Object?>[42, 0],
                            'index': 1035,
                            'isCanonical': true,
                          },
                          <String, Object?>{
                            'name': 'PURR/USDC',
                            'tokens': <Object?>[905, 0],
                            'index': 7,
                            'isCanonical': false,
                          },
                        ],
                      },
                      <Object?>[
                        // Context order is the reverse of universe order.
                        _context(
                          coin: 'PURR/USDC',
                          markPrice: '0.123456789012345678',
                          midPrice: '0.123456789012345679',
                          previousDayPrice: '0.120000000000000000',
                          dayNotionalVolume: '9000000.000000000000000001',
                          dayBaseVolume: '72900000.000000000000000001',
                        ),
                        _context(
                          coin: '@1035',
                          markPrice: '12.500000000000000001',
                          midPrice: null,
                          previousDayPrice: '10.000000000000000001',
                          dayNotionalVolume: '123456789.000000000000000001',
                          dayBaseVolume: '9876543.210000000000000001',
                        ),
                        // Additional contexts are provider-owned and do not
                        // imply an index-aligned relationship with universe.
                        _context(
                          coin: '#outcome',
                          markPrice: '1',
                          midPrice: '1',
                          previousDayPrice: '1',
                          dayNotionalVolume: '0',
                          dayBaseVolume: '0',
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        final repository = DioHyperliquidSpotMarketRepository(
          dio,
          now: () => receivedAt,
        );

        final snapshot = await repository.fetchMarkets();

        expect(capturedRequest?.method, 'POST');
        expect(
          capturedRequest?.uri,
          Uri.parse('https://api.hyperliquid-testnet.xyz/info'),
        );
        expect(capturedRequest?.data, const <String, String>{
          'type': 'spotMetaAndAssetCtxs',
        });
        expect(snapshot.receivedAt, receivedAt.toUtc());
        expect(snapshot.receivedAt.isUtc, isTrue);
        expect(snapshot.markets, hasLength(2));

        final hype = snapshot.markets.first;
        expect(hype.providerCoin, '@1035');
        expect(hype.spotIndex, 1035);
        expect(hype.baseTokenIndex, 42);
        expect(hype.quoteTokenIndex, 0);
        expect(hype.baseSymbol, 'HYPE');
        expect(hype.quoteSymbol, 'USDC');
        expect(hype.pair, 'HYPE/USDC');
        expect(hype.baseSizeDecimals, 2);
        expect(hype.isCanonical, isTrue);
        expect(hype.midPrice, isNull);
        expect(hype.markPrice.source, '12.500000000000000001');
        expect(hype.markPrice.value, Decimal.parse('12.500000000000000001'));
        expect(hype.dayNotionalVolume.source, '123456789.000000000000000001');
        expect(hype.dayChangePercent, Decimal.parse('24.999999'));

        final purr = snapshot.markets.last;
        expect(purr.providerCoin, 'PURR/USDC');
        expect(purr.baseTokenIndex, 905);
        expect(purr.baseSymbol, 'PURR');
        expect(purr.midPrice?.source, '0.123456789012345679');
        expect(
          purr.dayBaseVolume.value,
          Decimal.parse('72900000.000000000000000001'),
        );
        expect(() => snapshot.markets.add(hype), throwsUnsupportedError);
      },
    );

    test(
      'captures client receipt time before parsing the response body',
      () async {
        final receivedAt = DateTime.utc(2026, 8, 25, 12);
        final afterParsingStarted = receivedAt.add(const Duration(seconds: 3));
        var clock = receivedAt;
        final payload = _spotPayload(
          context: <String, Object?>{
            'coin': '@3',
            'markPx': '12.5',
            'midPx': null,
            'prevDayPx': '10.0',
            'dayNtlVlm': '1000.0',
            'dayBaseVlm': '80.0',
          },
        );
        payload[0] = _ReadObservedMap(
          payload[0]! as Map<String, Object?>,
          onRead: () => clock = afterParsingStarted,
        );
        final repository = DioHyperliquidSpotMarketRepository(
          _respondingDio(payload),
          now: () => clock,
        );

        final snapshot = await repository.fetchMarkets();

        expect(snapshot.receivedAt, receivedAt);
        expect(clock, afterParsingStarted);
      },
    );

    test('rejects numeric wire prices instead of converting through num', () {
      final repository = DioHyperliquidSpotMarketRepository(
        _respondingDio(
          _spotPayload(
            context: <String, Object?>{
              'coin': '@3',
              'markPx': 12.5,
              'midPx': null,
              'prevDayPx': '10.0',
              'dayNtlVlm': '1000.0',
              'dayBaseVlm': '80.0',
            },
          ),
        ),
      );

      expect(
        repository.fetchMarkets(),
        throwsA(_failure(HyperliquidMarketFailureKind.invalidPayload)),
      );
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
          final repository = DioHyperliquidSpotMarketRepository(
            _failingDio(dioKind, statusCode: statusCode),
          );

          await expectLater(
            repository.fetchMarkets(),
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
            reason: 'Dio $dioKind should map to $expectedKind',
          );
        }
      },
    );
  });
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

Map<String, Object?> _token({
  required int index,
  required String name,
  required int sizeDecimals,
  required String tokenId,
}) {
  return <String, Object?>{
    'index': index,
    'name': name,
    'szDecimals': sizeDecimals,
    'tokenId': tokenId,
  };
}

Map<String, Object?> _context({
  required String coin,
  required String markPrice,
  required String? midPrice,
  required String previousDayPrice,
  required String dayNotionalVolume,
  required String dayBaseVolume,
}) {
  return <String, Object?>{
    'coin': coin,
    'markPx': markPrice,
    'midPx': midPrice,
    'prevDayPx': previousDayPrice,
    'dayNtlVlm': dayNotionalVolume,
    'dayBaseVlm': dayBaseVolume,
  };
}

List<Object?> _spotPayload({required Map<String, Object?> context}) {
  return <Object?>[
    <String, Object?>{
      'tokens': <Object?>[
        _token(
          index: 0,
          name: 'USDC',
          sizeDecimals: 6,
          tokenId: '0x00000000000000000000000000000000',
        ),
        _token(
          index: 5,
          name: 'HYPE',
          sizeDecimals: 2,
          tokenId: '0x00000000000000000000000000000005',
        ),
      ],
      'universe': <Object?>[
        <String, Object?>{
          'name': '@3',
          'tokens': <Object?>[5, 0],
          'index': 3,
          'isCanonical': true,
        },
      ],
    },
    <Object?>[context],
  ];
}

Dio _respondingDio(Object? payload) {
  return Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
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

TypeMatcher<HyperliquidMarketFailure> _failure(
  HyperliquidMarketFailureKind kind,
) {
  return isA<HyperliquidMarketFailure>().having(
    (failure) => failure.kind,
    'kind',
    kind,
  );
}
