import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_failure.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_market_repository.dart';

void main() {
  group('DioHyperliquidMarketRepository', () {
    test(
      'posts the public Testnet request and merges active assets by index',
      () async {
        RequestOptions? capturedRequest;
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
                        'universe': <Object?>[
                          <String, Object?>{
                            'name': 'BTC',
                            'szDecimals': 5,
                            'maxLeverage': 50,
                          },
                          <String, Object?>{
                            'name': 'OLD',
                            'szDecimals': 1,
                            'maxLeverage': 3,
                            'isDelisted': true,
                          },
                          <String, Object?>{
                            'name': 'ETH',
                            'szDecimals': 4,
                            'maxLeverage': 50,
                          },
                        ],
                      },
                      <Object?>[
                        _context(
                          markPrice: '64231.125',
                          dayNotionalVolume: '123456789.00000001',
                          fundingRate: '0.0000125',
                        ),
                        _context(
                          markPrice: '1.0',
                          dayNotionalVolume: '0.0',
                          fundingRate: '0.0',
                        ),
                        _context(
                          markPrice: '3456.75',
                          dayNotionalVolume: '98765432.10',
                          fundingRate: '-0.0000042',
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        final repository = DioHyperliquidMarketRepository(dio);

        final markets = await repository.fetchMarkets();

        expect(capturedRequest?.method, 'POST');
        expect(
          capturedRequest?.uri,
          Uri.parse('https://api.hyperliquid-testnet.xyz/info'),
        );
        expect(capturedRequest?.data, const <String, String>{
          'type': 'metaAndAssetCtxs',
        });
        expect(markets, hasLength(2));
        expect(markets.map((market) => market.symbol), <String>['BTC', 'ETH']);
        expect(markets.first.sizeDecimals, 5);
        expect(markets.first.maxLeverage, 50);
        expect(markets.first.markPrice.source, '64231.125');
        expect(markets.first.markPrice.value, Decimal.parse('64231.125'));
        expect(markets.first.dayNotionalVolume.source, '123456789.00000001');
        expect(
          markets.first.dayNotionalVolume.value,
          Decimal.parse('123456789.00000001'),
        );
        expect(markets.last.fundingRate.source, '-0.0000042');
        expect(markets.last.fundingRate.value, Decimal.parse('-0.0000042'));
        expect(() => markets.add(markets.first), throwsUnsupportedError);
      },
    );

    test(
      'rejects a payload whose index-aligned lists have different lengths',
      () {
        final repository = DioHyperliquidMarketRepository(
          _respondingDio(<Object?>[
            <String, Object?>{
              'universe': <Object?>[
                <String, Object?>{
                  'name': 'BTC',
                  'szDecimals': 5,
                  'maxLeverage': 50,
                },
              ],
            },
            <Object?>[],
          ]),
        );

        expect(
          repository.fetchMarkets(),
          throwsA(_failure(HyperliquidMarketFailureKind.invalidPayload)),
        );
      },
    );

    test('rejects numeric JSON fields instead of converting through num', () {
      final repository = DioHyperliquidMarketRepository(
        _respondingDio(<Object?>[
          <String, Object?>{
            'universe': <Object?>[
              <String, Object?>{
                'name': 'BTC',
                'szDecimals': 5,
                'maxLeverage': 50,
              },
            ],
          },
          <Object?>[
            <String, Object?>{
              'markPx': 64231,
              'dayNtlVlm': '123456789.0',
              'funding': '0.0000125',
            },
          ],
        ]),
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
          (
            DioExceptionType.unknown,
            HyperliquidMarketFailureKind.unexpected,
            null,
          ),
        ];

        for (final (dioKind, expectedKind, statusCode) in cases) {
          final repository = DioHyperliquidMarketRepository(
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
                    isNot(contains('private')),
                  ),
            ),
            reason: 'Dio $dioKind should map to $expectedKind',
          );
        }
      },
    );
  });
}

Map<String, Object?> _context({
  required String markPrice,
  required String dayNotionalVolume,
  required String fundingRate,
}) {
  return <String, Object?>{
    'markPx': markPrice,
    'dayNtlVlm': dayNotionalVolume,
    'funding': fundingRate,
  };
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
                  data: const <String, String>{'private': 'not surfaced'},
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
