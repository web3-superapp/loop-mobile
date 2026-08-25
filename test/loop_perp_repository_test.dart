import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_perp_repository.dart';

const _requestId = '7a7448be-64e2-4f9f-a9f1-891f1beec7fd';
const _otherRequestId = '6d12a86e-4134-47e6-9312-c5ef75a30f55';
const _cursor = 'aaaaaaaaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbb';
const _transactionHash =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _clientOrderId = '0x22222222222222222222222222222222';
final _now = DateTime.parse('2026-08-25T05:00:01.000Z');

void main() {
  group('PerpPrivateGateway', () {
    test('defaults to a fail-closed unavailable port', () async {
      const gateway = UnavailablePerpPrivateGateway();

      expect(gateway.mode, PerpGatewayMode.unavailable);
      await expectLater(
        gateway.getWalletBinding(),
        throwsA(
          isA<PerpGatewayException>().having(
            (failure) => failure.kind,
            'kind',
            PerpGatewayFailureKind.unavailable,
          ),
        ),
      );
    });
  });

  group('DioLoopPerpRepository', () {
    test('sends exact GET, PUT, and DELETE wallet-binding requests', () async {
      final requests = <RequestOptions>[];
      final repository = _repository((options, handler) {
        requests.add(options);
        handler.resolve(
          _response(options, switch (options.method) {
            'PUT' => _boundBinding(),
            'DELETE' => <String, Object?>{
              ..._unboundBinding(),
              'binding_version': '9223372036854775807',
            },
            _ => _unboundBinding(),
          }),
        );
      });

      final loaded = await repository.getWalletBinding(
        accessToken: 'current-access-token',
      );
      final bound = await repository.bindWallet(
        accessToken: 'current-access-token',
        expectedBindingVersion: '0',
      );
      final unbound = await repository.unbindWallet(
        accessToken: 'current-access-token',
        expectedBindingVersion: '9223372036854775807',
      );

      expect(requests.map((request) => request.method), <String>[
        'GET',
        'PUT',
        'DELETE',
      ]);
      expect(requests.map((request) => request.uri.path).toSet(), <String>{
        '/v1/perp/wallet-binding',
      });
      expect(requests[0].queryParameters, isEmpty);
      expect(requests[0].data, isNull);
      expect(requests[1].queryParameters, isEmpty);
      expect(requests[1].data, <String, String>{
        'expected_binding_version': '0',
      });
      expect(requests[2].queryParameters, <String, String>{
        'expected_binding_version': '9223372036854775807',
      });
      expect(requests[2].data, isNull);
      for (final request in requests) {
        expect(request.followRedirects, isFalse);
        expect(
          _header(request, 'authorization'),
          'Bearer current-access-token',
        );
        expect(_header(request, 'accept'), Headers.jsonContentType);
      }
      expect(loaded.isBound, isFalse);
      expect(loaded.bindingVersion, '0');
      expect(bound.isBound, isTrue);
      expect(bound.accountKind, PerpAccountKind.master);
      expect(bound.lastVerifiedAt?.isUtc, isTrue);
      expect(unbound.isBound, isFalse);
      expect(unbound.bindingVersion, '9223372036854775807');
    });

    test('calls all six read paths and parses every model category', () async {
      final requests = <RequestOptions>[];
      final repository = _repository((options, handler) {
        requests.add(options);
        final payload = switch (options.uri.path) {
          '/v1/perp/config' => _config(),
          '/v1/perp/account' => _account(),
          '/v1/perp/positions' => _positions(),
          '/v1/perp/orders' => _orders(),
          '/v1/perp/fills' => _fills(),
          '/v1/perp/funding' => _funding(),
          _ => fail('Unexpected request ${options.uri.path}'),
        };
        handler.resolve(_response(options, payload));
      });

      final config = await repository.getConfig(accessToken: 'token');
      final account = await repository.getAccount(accessToken: 'token');
      final positions = await repository.listPositions(
        accessToken: 'token',
        limit: 3,
      );
      final orders = await repository.listOrders(
        accessToken: 'token',
        cursor: _cursor,
      );
      final fills = await repository.listFills(accessToken: 'token', limit: 2);
      final funding = await repository.listFunding(accessToken: 'token');

      expect(requests.map((request) => request.uri.path), <String>[
        '/v1/perp/config',
        '/v1/perp/account',
        '/v1/perp/positions',
        '/v1/perp/orders',
        '/v1/perp/fills',
        '/v1/perp/funding',
      ]);
      expect(requests.every((request) => request.method == 'GET'), isTrue);
      expect(requests[0].queryParameters, isEmpty);
      expect(requests[1].queryParameters, isEmpty);
      expect(requests[2].queryParameters, <String, Object?>{'limit': 3});
      expect(requests[3].queryParameters, <String, Object?>{'cursor': _cursor});
      expect(requests[4].queryParameters, <String, Object?>{'limit': 2});
      expect(requests[5].queryParameters, isEmpty);
      expect(requests.every((request) => request.data == null), isTrue);

      expect(config.scope.coins, PerpCoin.values);
      expect(config.assets.map((asset) => asset.coin), PerpCoin.values);
      expect(config.assets.first.sizeIncrement, Decimal.parse('0.001'));
      expect(config.assets.first.maxLeverage, Decimal.parse('50'));
      expect(
        config.assets.first.minimumOrderNotionalUsdc.value,
        Decimal.parse('10'),
      );
      expect(config.fees.makerRate.isAvailable, isFalse);
      expect(config.capabilities.privateReadsAvailable, isTrue);
      expect(config.capabilities.tradingMutationsEnabled, isFalse);
      expect(config.source.dataset, PerpSourceDataset.config);
      expect(config.source.fetchedAt.isUtc, isTrue);

      expect(account.marginSummary.accountValue, Decimal.parse('100.25'));
      expect(account.crossMaintenanceMarginUsed, isNull);
      expect(account.source.dataset, PerpSourceDataset.account);

      expect(positions.items.single.coin, PerpCoin.btc);
      expect(positions.items.single.side, PerpPositionSide.long);
      expect(positions.items.single.size, Decimal.parse('0.5'));
      expect(positions.nextCursor, isNull);
      expect(
        () => positions.items.add(positions.items.single),
        throwsUnsupportedError,
      );

      expect(orders.items.single.orderId, '18446744073709551615');
      expect(orders.items.single.clientOrderId, _clientOrderId);
      expect(orders.items.single.createdAt.isUtc, isTrue);
      expect(fills.items.single.tradeId, '42');
      expect(fills.items.single.feeAsset, PerpFeeAsset.usdc);
      expect(fills.coverage?.kind, PerpCoverageKind.recentWindow);
      expect(funding.items.single.paymentUsdc, Decimal.parse('-0.25'));
      expect(funding.items.single.settledAt.isUtc, isTrue);
      expect(funding.coverage?.truncated, isFalse);
    });

    test(
      'requires strict success headers and rejects contract drift',
      () async {
        final cases = <({Object? payload, bool noStore, String? requestId})>[
          (payload: _account(), noStore: false, requestId: _requestId),
          (payload: _account(), noStore: true, requestId: null),
          (
            payload: <String, Object?>{..._account(), 'extra': 'drift'},
            noStore: true,
            requestId: _requestId,
          ),
          (
            payload: <String, Object?>{..._account(), 'withdrawable': 99},
            noStore: true,
            requestId: _requestId,
          ),
        ];

        for (final testCase in cases) {
          final repository = _repository(
            (options, handler) => handler.resolve(
              _response(
                options,
                testCase.payload,
                noStore: testCase.noStore,
                requestId: testCase.requestId,
              ),
            ),
          );

          await expectLater(
            repository.getAccount(accessToken: 'token'),
            throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
          );
        }
      },
    );

    test(
      'validates wallet-binding mutation state and epoch transitions',
      () async {
        final cases =
            <({String method, String expected, Map<String, Object?> payload})>[
              (method: 'PUT', expected: '0', payload: _unboundBinding()),
              (
                method: 'PUT',
                expected: '1',
                payload: <String, Object?>{
                  ..._boundBinding(),
                  'binding_version': '3',
                },
              ),
              (method: 'DELETE', expected: '1', payload: _boundBinding()),
              (method: 'DELETE', expected: '2', payload: _unboundBinding()),
            ];

        for (final testCase in cases) {
          final repository = _repository(
            (options, handler) =>
                handler.resolve(_response(options, testCase.payload)),
          );
          final operation = testCase.method == 'PUT'
              ? repository.bindWallet(
                  accessToken: 'token',
                  expectedBindingVersion: testCase.expected,
                )
              : repository.unbindWallet(
                  accessToken: 'token',
                  expectedBindingVersion: testCase.expected,
                );

          await expectLater(
            operation,
            throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
          );
        }
      },
    );

    test(
      'rejects semantically invalid timestamps and oversized integers',
      () async {
        final invalidDate = _boundBinding()
          ..['last_verified_at'] = '2026-02-30T05:00:00.000Z';
        final invalidOffset = _boundBinding()
          ..['last_verified_at'] = '2026-08-25T05:00:00+24:00';
        final oversizedInteger = _config();
        ((oversizedInteger['assets']! as List<Object?>).first
                as Map<String, Object?>)['max_leverage'] =
            '12345678901234567890';

        for (final payload in <Map<String, Object?>>[
          invalidDate,
          invalidOffset,
          oversizedInteger,
        ]) {
          final repository = _repository(
            (options, handler) => handler.resolve(_response(options, payload)),
          );
          await expectLater(
            identical(payload, oversizedInteger)
                ? repository.getConfig(accessToken: 'token')
                : repository.getWalletBinding(accessToken: 'token'),
            throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
          );
        }
      },
    );

    test(
      'rejects wrong scope, coin order, stale data, and excessive TTL',
      () async {
        final wrongScope = _config();
        (wrongScope['scope']! as Map<String, Object?>)['network'] = 'mainnet';
        final wrongCoinOrder = _config();
        (wrongCoinOrder['assets']! as List<Object?>).setAll(0, <Object?>[
          (_config()['assets']! as List<Object?>)[1],
          (_config()['assets']! as List<Object?>)[0],
          (_config()['assets']! as List<Object?>)[2],
        ]);
        final stale = _account();
        (stale['source']! as Map<String, Object?>)['expires_at'] =
            '2026-08-25T05:00:01.000Z';
        final excessiveTtl = _account();
        (excessiveTtl['source']! as Map<String, Object?>)['expires_at'] =
            '2026-08-25T05:00:03.000Z';

        for (final payload in <Object?>[
          wrongScope,
          wrongCoinOrder,
          stale,
          excessiveTtl,
        ]) {
          final path =
              identical(payload, wrongScope) ||
                  identical(payload, wrongCoinOrder)
              ? DioLoopPerpRepository.configPath
              : DioLoopPerpRepository.accountPath;
          final repository = _repository(
            (options, handler) => handler.resolve(_response(options, payload)),
          );

          await expectLater(
            path == DioLoopPerpRepository.configPath
                ? repository.getConfig(accessToken: 'token')
                : repository.getAccount(accessToken: 'token'),
            throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
          );
        }
      },
    );

    test('validates list limit XOR cursor before sending a request', () async {
      var requests = 0;
      final repository = _repository((options, handler) {
        requests += 1;
        handler.resolve(_response(options, _positions()));
      });

      await expectLater(
        repository.listPositions(
          accessToken: 'token',
          limit: 3,
          cursor: _cursor,
        ),
        throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
      );
      await expectLater(
        repository.listPositions(accessToken: 'token', limit: 4),
        throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
      );
      await expectLater(
        repository.listOrders(accessToken: 'token', cursor: 'not-a-cursor'),
        throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
      );
      expect(requests, 0);
    });

    test(
      'preserves only a strict stable error code and matching UUID',
      () async {
        var requests = 0;
        final repository = _repository((options, handler) {
          requests += 1;
          handler.reject(
            _badResponse(
              options,
              statusCode: 409,
              code: 'wallet_binding_required',
              message: 'private provider and wallet details',
            ),
          );
        });

        await expectLater(
          repository.getAccount(accessToken: 'token'),
          throwsA(
            _failure(LoopBackendFailureKind.invalidRequest)
                .having(
                  (failure) => failure.code,
                  'stable code',
                  'wallet_binding_required',
                )
                .having(
                  (failure) => failure.requestId,
                  'request id',
                  _requestId,
                )
                .having(
                  (failure) => failure.toString(),
                  'sanitized',
                  isNot(contains('private provider')),
                ),
          ),
        );
        expect(requests, 1);
      },
    );

    test('enforces conflict-code allowlists per route and method', () async {
      LoopPerpRepository repositoryFor(String code) => _repository(
        (options, handler) =>
            handler.reject(_badResponse(options, statusCode: 409, code: code)),
      );

      await expectLater(
        repositoryFor('wallet_binding_required')
            .getWalletBinding(accessToken: 'token'),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
      await expectLater(
        repositoryFor('version_conflict').getAccount(accessToken: 'token'),
        throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
      );
      await expectLater(
        repositoryFor('version_conflict')
            .bindWallet(accessToken: 'token', expectedBindingVersion: '0'),
        throwsA(
          _failure(LoopBackendFailureKind.invalidRequest)
              .having((failure) => failure.code, 'code', 'version_conflict'),
        ),
      );
    });

    test(
      'fails closed on a malformed error envelope and never retries 401',
      () async {
        var malformedRequests = 0;
        final malformed = _repository((options, handler) {
          malformedRequests += 1;
          handler.reject(
            _badResponse(
              options,
              statusCode: 503,
              code: 'perp_unavailable',
              headerRequestId: _otherRequestId,
            ),
          );
        });
        await expectLater(
          malformed.getAccount(accessToken: 'token'),
          throwsA(
            _failure(LoopBackendFailureKind.invalidPayload)
                .having((failure) => failure.code, 'code', isNull)
                .having((failure) => failure.requestId, 'request id', isNull),
          ),
        );
        expect(malformedRequests, 1);

        var unauthorizedRequests = 0;
        final unauthorized = _repository((options, handler) {
          unauthorizedRequests += 1;
          handler.reject(
            _badResponse(
              options,
              statusCode: 401,
              code: 'invalid_access_token',
            ),
          );
        });
        await expectLater(
          unauthorized.getConfig(accessToken: 'expired-token'),
          throwsA(_failure(LoopBackendFailureKind.authentication)),
        );
        expect(unauthorizedRequests, 1);
      },
    );

    test('maps transport failures without retaining Dio details', () async {
      final repository = _repository(
        (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
            message: 'private token and provider details',
          ),
        ),
      );

      await expectLater(
        repository.getConfig(accessToken: 'token'),
        throwsA(
          _failure(LoopBackendFailureKind.timeout)
              .having((failure) => failure.code, 'code', isNull)
              .having(
                (failure) => failure.toString(),
                'sanitized',
                isNot(contains('private token')),
              ),
        ),
      );
    });
  });
}

DioLoopPerpRepository _repository(
  void Function(RequestOptions, RequestInterceptorHandler) onRequest,
) => DioLoopPerpRepository(
  Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'))
    ..interceptors.add(InterceptorsWrapper(onRequest: onRequest)),
  now: () => _now,
);

Response<Object?> _response(
  RequestOptions options,
  Object? data, {
  bool noStore = true,
  String? requestId = _requestId,
}) => Response<Object?>(
  requestOptions: options,
  statusCode: 200,
  data: data,
  headers: Headers.fromMap(<String, List<String>>{
    if (noStore) 'cache-control': <String>['private', 'no-store'],
    if (requestId != null) 'x-request-id': <String>[requestId],
  }),
);

DioException _badResponse(
  RequestOptions options, {
  required int statusCode,
  required String code,
  String message = 'safe message',
  String bodyRequestId = _requestId,
  String headerRequestId = _requestId,
}) => DioException(
  requestOptions: options,
  type: DioExceptionType.badResponse,
  response: Response<Object?>(
    requestOptions: options,
    statusCode: statusCode,
    data: <String, Object?>{
      'code': code,
      'message': message,
      'request_id': bodyRequestId,
    },
    headers: Headers.fromMap(<String, List<String>>{
      'cache-control': <String>['no-store'],
      'x-request-id': <String>[headerRequestId],
    }),
  ),
);

Object? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name) return entry.value;
  }
  return null;
}

Map<String, Object?> _unboundBinding() => <String, Object?>{
  'state': 'unbound',
  'binding_version': '0',
  'account_kind': null,
  'last_verified_at': null,
};

Map<String, Object?> _boundBinding() => <String, Object?>{
  'state': 'bound',
  'binding_version': '1',
  'account_kind': 'master',
  'last_verified_at': '2026-08-25T05:00:00.000Z',
};

Map<String, Object?> _config() => <String, Object?>{
  'scope': <String, Object?>{
    'network': 'testnet',
    'market': 'core_perps',
    'dex': '',
    'coins': <Object?>['BTC', 'ETH', 'SOL'],
  },
  'assets': <Object?>[
    _asset('BTC', sizeDecimals: 3, sizeIncrement: '0.001', maxLeverage: '50'),
    _asset('ETH', sizeDecimals: 4, sizeIncrement: '0.0001', maxLeverage: '50'),
    _asset('SOL', sizeDecimals: 2, sizeIncrement: '0.01', maxLeverage: '20'),
  ],
  'fees': <String, Object?>{
    'maker_rate': <String, Object?>{'state': 'unavailable'},
    'taker_rate': <String, Object?>{'state': 'available', 'value': '0.00035'},
  },
  'capabilities': <String, Object?>{
    'private_reads': 'available',
    'trading_mutations': 'disabled',
  },
  'source': _source('config', expiresAt: '2026-08-25T05:01:00.000Z'),
};

Map<String, Object?> _asset(
  String coin, {
  required int sizeDecimals,
  required String sizeIncrement,
  required String maxLeverage,
}) => <String, Object?>{
  'coin': coin,
  'size_decimals': sizeDecimals,
  'size_increment': sizeIncrement,
  'max_leverage': maxLeverage,
  'margin_mode': 'cross_and_isolated',
  'minimum_order_notional_usdc': <String, Object?>{
    'state': 'available',
    'value': '10',
  },
};

Map<String, Object?> _account() => <String, Object?>{
  'margin_summary': _marginSummary(),
  'cross_margin_summary': _marginSummary(),
  'withdrawable': '75.5',
  'cross_maintenance_margin_used': null,
  'source': _source('account'),
};

Map<String, Object?> _marginSummary() => <String, Object?>{
  'account_value': '100.25',
  'total_margin_used': '10',
  'total_notional_position': '50',
  'total_raw_usd': '-2.5',
};

Map<String, Object?> _positions() => <String, Object?>{
  'items': <Object?>[
    <String, Object?>{
      'coin': 'BTC',
      'side': 'long',
      'size': '0.5',
      'entry_price': '64000',
      'leverage': <String, Object?>{
        'mode': 'cross',
        'value': '10',
        'raw_usd': null,
      },
      'liquidation_price': '58000',
      'margin_used': '3200',
      'position_value': '32000',
      'return_on_equity': '0.125',
      'unrealized_pnl': '400',
      'position_mode': 'one_way',
    },
  ],
  'source': _source('positions'),
  'next_cursor': null,
};

Map<String, Object?> _orders() => <String, Object?>{
  'items': <Object?>[
    <String, Object?>{
      'order_id': '18446744073709551615',
      'client_order_id': _clientOrderId,
      'coin': 'ETH',
      'side': 'buy',
      'order_type': 'limit',
      'time_in_force': 'gtc',
      'limit_price': '3500.25',
      'original_size': '1.5',
      'remaining_size': '1.25',
      'reduce_only': false,
      'status': 'open',
      'created_at': '2026-08-25T04:59:59.000Z',
      'status_at': '2026-08-25T05:00:00.000Z',
    },
  ],
  'source': _source('orders'),
  'next_cursor': null,
};

Map<String, Object?> _fills() => <String, Object?>{
  'items': <Object?>[
    <String, Object?>{
      'trade_id': '42',
      'order_id': '41',
      'transaction_hash': _transactionHash,
      'coin': 'SOL',
      'side': 'sell',
      'price': '155.25',
      'size': '2',
      'start_position': '5',
      'closed_pnl': '3.75',
      'fee': '-0.02',
      'fee_asset': 'USDC',
      'crossed': true,
      'filled_at': '2026-08-25T04:59:59.000Z',
    },
  ],
  'coverage': _coverage(),
  'source': _source('fills'),
  'next_cursor': null,
};

Map<String, Object?> _funding() => <String, Object?>{
  'items': <Object?>[
    <String, Object?>{
      'transaction_hash': _transactionHash,
      'coin': 'BTC',
      'funding_rate': '0.0000125',
      'position_size': '0.5',
      'payment_usdc': '-0.25',
      'settled_at': '2026-08-25T04:59:58.000Z',
    },
  ],
  'coverage': _coverage(),
  'source': _source('funding'),
  'next_cursor': null,
};

Map<String, Object?> _coverage() => <String, Object?>{
  'kind': 'recent_window',
  'started_at': '2026-08-18T05:00:00.000Z',
  'ended_at': '2026-08-25T05:00:00.000Z',
  'truncated': false,
};

Map<String, Object?> _source(
  String dataset, {
  String expiresAt = '2026-08-25T05:00:02.000Z',
}) => <String, Object?>{
  'provider': 'hyperliquid',
  'network': 'testnet',
  'market': 'core_perps',
  'dex': '',
  'dataset': dataset,
  'fetched_at': '2026-08-25T05:00:00.000Z',
  'expires_at': expiresAt,
};

TypeMatcher<LoopBackendFailure> _failure(LoopBackendFailureKind kind) =>
    isA<LoopBackendFailure>().having((failure) => failure.kind, 'kind', kind);
