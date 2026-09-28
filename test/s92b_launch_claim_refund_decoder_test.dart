import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';

/// Decision 0103 · the claim / refund intent and the history `settlements`
/// against loop-api decision 0087 (`frontend-v2-launch-api.md` §S92a).
///
/// Bodies are 测试专用, written by hand from the S92a examples.

const _token = 'access-token';
const _clientVersion = '1.4.0';
const _requestId = '11111111-2222-4333-8444-555555555555';
const _key = '66666666-7777-4888-8999-aaaaaaaaaaaa';
const _launchId = '9c1f0f2e-5a7b-4c3d-8e9f-0a1b2c3d4e5f';
const _projectId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';
const _walletId = 'd64786bb-408d-415d-8a69-6277d56c921b';
const _intentId = '7a2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
const _roundId = '0b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e';
const _contract = '0x1111111111111111111111111111111111111111';
final _hash = '0x${'bb' * 32}';
final _digest = '0x${'cd' * 32}';
final _config = '0x${'ab' * 32}';

String _call(String selector, int saleId) =>
    '$selector${saleId.toRadixString(16).padLeft(64, '0')}';

final class _Adapter implements HttpClientAdapter {
  _Adapter({required this.statusCode, required this.body});

  final int statusCode;
  final Object? body;
  RequestOptions? seen;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>[_requestId],
      },
    );
  }
}

(LoopV2LaunchApi, _Adapter) _api(int status, Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  final adapter = _Adapter(statusCode: status, body: body);
  dio.httpClientAdapter = adapter;
  return (DioLoopV2LaunchApi(dio), adapter);
}

Matcher _invalid() => throwsA(
  isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

/// The S92a.3 / S92a.4 body. `kind: null` builds the pre-0087 purchase.
Map<String, Object?> _intent({
  String? kind = 'claim',
  String state = 'awaiting_signature',
}) {
  final claim = kind == 'claim';
  final settlement = kind == 'claim' || kind == 'claimRefund';
  return <String, Object?>{
    'launchIntentId': _intentId,
    'kind': ?kind,
    'state': state,
    'launchId': _launchId,
    'projectId': _projectId,
    'walletId': _walletId,
    'roundId': settlement ? null : _roundId,
    'roundIndex': settlement ? null : 1,
    'chainId': loopLaunchTestnetChainId,
    'contractAddress': _contract,
    'quoteAssetId': 'eip155:97:0x2222222222222222222222222222222222222222',
    'usd1Amount': settlement ? '0' : '10000000000000000000',
    'expectedTokenAmount': claim
        ? '2500000000000000000000'
        : settlement
        ? '0'
        : '1000000000000000000000',
    'minTokenAmount': settlement ? '0' : '1000000000000000000000',
    'walletCumulativeUsd1': '100000000000000000000',
    'deadline': '2026-09-22T00:02:00.000Z',
    'eligibilityProof': <Object?>[],
    'configVersion': _config,
    'stateTupleDigest': _digest,
    'snapshotBlockNumber': '900',
    'snapshotBlockHash': _hash,
    'payloadDigest': 'ef' * 32,
    'unsignedTransaction': <String, Object?>{
      'chainId': 97,
      'to': _contract,
      'data': switch (kind) {
        'claim' => _call('0x379607f5', 7),
        'claimRefund' => _call('0x5b7baf64', 7),
        _ => '0x${'00' * 36}',
      },
      'value': '0x0',
      'from': '0x4444444444444444444444444444444444444444',
      'gas': '0x1d4c0',
      'nonce': '0x3',
      'type': 'legacy',
      'maxFeePerGas': null,
      'maxPriorityFeePerGas': null,
      'gasPrice': '0x3b9aca00',
    },
    'expiresAt': '2026-09-22T00:02:00.000Z',
    'createdAt': '2026-09-22T00:00:00.000Z',
    'projectAssetId': 'eip155:97:0x3333333333333333333333333333333333333333',
    'saleId': '7',
    if (claim) 'claimableTokens': '2500000000000000000000',
    if (kind == 'claimRefund') 'refundableUsd1': '100000000000000000000',
    'transactionHash': null,
    'simulation': <String, Object?>{'status': 'passed', 'reasonCode': null},
    'policy': <String, Object?>{
      'configVersion': 'bscWriteCanaryV1',
      'canaryMaxUsd': '5',
      'valueUsd': '0',
      'priceSource': 'usd1_par',
    },
    'signing': <String, Object?>{
      'mode': 'device_eth_send_transaction',
      'allowed': true,
      'reasonCode': null,
    },
  };
}

Map<String, Object?> _envelope(Map<String, Object?> intent) =>
    <String, Object?>{'launchIntent': intent, 'contractVersion': '2.0'};

Future<LaunchPurchasePrepared> _prepare(
  LoopV2LaunchApi api, [
  LaunchIntentKind kind = LaunchIntentKind.claim,
]) => api.postSettlementIntent(
  accessToken: _token,
  clientVersion: _clientVersion,
  idempotencyKey: _key,
  launchId: _launchId,
  walletId: _walletId,
  kind: kind,
);

Map<String, Object?> _settlement({
  String id = '6b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e',
  String kind = 'claimed',
  String block = '945',
}) => <String, Object?>{
  'settlementRecordId': id,
  'kind': kind,
  'walletId': _walletId,
  'assetId': 'eip155:97:0x3333333333333333333333333333333333333333',
  'amount': '2500000000000000000000',
  'cumulativeAmount': '2500000000000000000000',
  'transactionHash': '0x${'c1' * 32}',
  'logIndex': 1,
  'blockNumber': block,
  'blockHash': _hash,
  'confirmationState': 'confirmed',
  'observedAt': '2026-09-25T01:00:00.000Z',
};

const Object _absent = Object();

Map<String, Object?> _history({
  Object? settlements = _absent,
  bool available = true,
}) => <String, Object?>{
  'launchId': _launchId,
  'purchaseRecords': <Object?>[],
  'entitlements': <Object?>[],
  'refunds': <Object?>[],
  if (!identical(settlements, _absent)) 'settlements': settlements,
  'source': available
      ? <String, Object?>{
          'status': 'available',
          'indexedBlockNumber': '950',
          'indexedBlockHash': _hash,
        }
      : <String, Object?>{
          'status': 'unavailable',
          'reasonCode': 'LAUNCH_ONCHAIN_STATE_NOT_INDEXED',
        },
  'contractVersion': '2.0',
};

Future<LaunchHistory> _readHistory(Map<String, Object?> body) =>
    _api(200, body).$1.getHistory(
      accessToken: _token,
      clientVersion: _clientVersion,
      launchId: _launchId,
    );

void main() {
  group('claim / refund intent · 201', () {
    test('a claim sends exactly {kind, walletId} and decodes the S92a.3 '
        'body', () async {
      final (api, adapter) = _api(201, _envelope(_intent()));
      final prepared = await _prepare(api);
      expect(adapter.seen!.method, 'POST');
      expect(adapter.seen!.path, '/v2/launch/$_launchId/intents');
      expect(adapter.seen!.data, <String, Object?>{
        'kind': 'claim',
        'walletId': _walletId,
      });
      expect(adapter.seen!.headers['Idempotency-Key'], _key);
      final intent = prepared.intent;
      expect(intent.kind, LaunchIntentKind.claim);
      expect(intent.roundId, isNull);
      expect(intent.roundIndex, isNull);
      expect(intent.claimableTokens, '2500000000000000000000');
      expect(intent.refundableUsd1, isNull);
      expect(intent.saleId, '7');
      expect(intent.payloadMatchesReview, isTrue);
    });

    test('a refund decodes the S92a.4 body', () async {
      final (api, adapter) = _api(201, _envelope(_intent(kind: 'claimRefund')));
      final prepared = await _prepare(api, LaunchIntentKind.claimRefund);
      expect(adapter.seen!.data, <String, Object?>{
        'kind': 'claimRefund',
        'walletId': _walletId,
      });
      expect(prepared.intent.kind, LaunchIntentKind.claimRefund);
      expect(prepared.intent.refundableUsd1, '100000000000000000000');
      expect(prepared.intent.claimableTokens, isNull);
      expect(prepared.intent.expectedTokenAmount, '0');
      expect(prepared.intent.payloadMatchesReview, isTrue);
    });

    test('an answer of another kind is not an answer to this request', () {
      final (api, _) = _api(201, _envelope(_intent(kind: 'claimRefund')));
      expect(() => _prepare(api), _invalid());
    });

    test('a buy is never sent through the settlement call', () {
      final (api, _) = _api(201, _envelope(_intent()));
      expect(
        () => _prepare(api, LaunchIntentKind.buy),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => failure.kind,
            'kind',
            LoopBackendFailureKind.invalidRequest,
          ),
        ),
      );
    });

    final malformed = <String, void Function(Map<String, Object?>)>{
      'an unknown key': (map) => map['bonus'] = '1',
      'an unknown kind': (map) => map['kind'] = 'sell',
      'a round on a claim': (map) => map['roundId'] = _roundId,
      'a round index on a claim': (map) => map['roundIndex'] = 1,
      'a claim without claimableTokens': (map) => map.remove('claimableTokens'),
      'a claim with refundableUsd1': (map) => map['refundableUsd1'] = '1',
      'a claim that pays USD1': (map) => map['usd1Amount'] = '1',
      'a claim with a minimum': (map) => map['minTokenAmount'] = '1',
      'a claim with a proof': (map) =>
          map['eligibilityProof'] = <Object?>['0x${'ef' * 32}'],
      'a claim whose expected amount is not the claimable': (map) =>
          map['expectedTokenAmount'] = '1',
      'a claim with a wallet round cap': (map) =>
          map['walletRoundCapUsd1'] = '1',
      'claimableTokens as a number': (map) => map['claimableTokens'] = 2500,
      'a null kind': (map) => map['kind'] = null,
    };
    for (final entry in malformed.entries) {
      test('${entry.key} is refused whole', () {
        final body = _intent();
        entry.value(body);
        final (api, _) = _api(201, _envelope(body));
        expect(() => _prepare(api), _invalid());
      });
    }

    test('a refund with claimableTokens, or without refundableUsd1, is '
        'refused', () {
      for (final mutate in <void Function(Map<String, Object?>)>[
        (map) => map['claimableTokens'] = '1',
        (map) => map.remove('refundableUsd1'),
        (map) => map['expectedTokenAmount'] = '1',
      ]) {
        final body = _intent(kind: 'claimRefund');
        mutate(body);
        final (api, _) = _api(201, _envelope(body));
        expect(() => _prepare(api, LaunchIntentKind.claimRefund), _invalid());
      }
    });

    test('calldata that is not claim(saleId) fails the review, so it is '
        'never signed', () async {
      final wrongSelector = _intent();
      (wrongSelector['unsignedTransaction']! as Map<String, Object?>)['data'] =
          _call('0x5b7baf64', 7);
      final wrongSale = _intent();
      (wrongSale['unsignedTransaction']! as Map<String, Object?>)['data'] =
          _call('0x379607f5', 8);
      final extra = _intent();
      (extra['unsignedTransaction']! as Map<String, Object?>)['data'] =
          '${_call('0x379607f5', 7)}00';
      for (final body in <Map<String, Object?>>[
        wrongSelector,
        wrongSale,
        extra,
      ]) {
        final (api, _) = _api(201, _envelope(body));
        final prepared = await _prepare(api);
        expect(prepared.intent.payloadMatchesReview, isFalse);
      }
    });
  });

  group('the purchase keeps its pre-0087 bytes', () {
    Future<LaunchPurchasePrepared> buy(Map<String, Object?> body) =>
        _api(201, _envelope(body)).$1.postPurchaseIntent(
          accessToken: _token,
          clientVersion: _clientVersion,
          idempotencyKey: _key,
          launchId: _launchId,
          walletId: _walletId,
          roundId: _roundId,
          payAmount: '10',
        );

    test('no kind decodes as a buy, with its round', () async {
      final prepared = await buy(_intent(kind: null));
      expect(prepared.intent.kind, LaunchIntentKind.buy);
      expect(prepared.intent.roundId, _roundId);
      expect(prepared.intent.roundIndex, 1);
      expect(prepared.intent.claimableTokens, isNull);
      expect(prepared.intent.payloadMatchesReview, isTrue);
    });

    test('an explicit kind buy is the same purchase', () async {
      final prepared = await buy(_intent(kind: 'buy'));
      expect(prepared.intent.kind, LaunchIntentKind.buy);
    });

    test('a buy answer carrying a position figure is refused', () {
      final body = _intent(kind: null)
        ..['claimableTokens'] = '2500000000000000000000';
      expect(() => buy(body), _invalid());
    });

    test('a buy answer with a null round is refused', () {
      final body = _intent(kind: null)..['roundId'] = null;
      expect(() => buy(body), _invalid());
    });

    test('a claim answer to a purchase request is refused', () {
      expect(() => buy(_intent()), _invalid());
    });
  });

  group('GET …/intents/{id}', () {
    test('reads the intent back with its kind and state', () async {
      final (api, adapter) = _api(
        200,
        _envelope(
          _intent(state: 'confirmed')
            ..['transactionHash'] = '0x${'9a' * 32}'
            ..['signing'] = <String, Object?>{
              'mode': 'device_eth_send_transaction',
              'allowed': false,
              'reasonCode': 'LAUNCH_INTENT_ALREADY_REPORTED',
            },
        ),
      );
      final intent = await api.getIntent(
        accessToken: _token,
        clientVersion: _clientVersion,
        launchId: _launchId,
        launchIntentId: _intentId,
      );
      expect(adapter.seen!.method, 'GET');
      expect(adapter.seen!.path, '/v2/launch/$_launchId/intents/$_intentId');
      expect(adapter.seen!.headers.containsKey('Idempotency-Key'), isFalse);
      expect(intent.kind, LaunchIntentKind.claim);
      expect(intent.state, LaunchIntentState.confirmed);
    });

    test('a read of another intent is refused', () {
      final (api, _) = _api(
        200,
        _envelope(_intent()..['launchIntentId'] = _roundId),
      );
      expect(
        () => api.getIntent(
          accessToken: _token,
          clientVersion: _clientVersion,
          launchId: _launchId,
          launchIntentId: _intentId,
        ),
        _invalid(),
      );
    });
  });

  group('the six refusals of 0087 reach the page with their reason', () {
    for (final code in <String>[
      'LAUNCH_CLAIM_NOT_OPEN',
      'LAUNCH_REFUND_NOT_OPEN',
      'LAUNCH_SALE_PAUSED',
      'LAUNCH_NOT_PARTICIPANT',
      'LAUNCH_NOTHING_TO_CLAIM',
      'LAUNCH_NOTHING_TO_REFUND',
    ]) {
      test(code, () async {
        final (api, _) = _api(409, <String, Object?>{
          'code': 'DATA_STALE',
          'category': 'stale',
          'retryable': false,
          'userMessageKey': 'errors.data.stale',
          'correlationId': _requestId,
          'detailsSafe': <String, Object?>{
            'reasonCode': code,
            'entitlementState': 'FROZEN',
          },
          'providerReferenceSafe': null,
        });
        await expectLater(
          () => _prepare(api),
          throwsA(
            isA<LoopBackendFailure>()
                .having((failure) => failure.code, 'code', 'DATA_STALE')
                .having(
                  (failure) => failure.detailsSafe?.reasonCode,
                  'reasonCode',
                  code,
                ),
          ),
        );
      });
    }
  });

  group('history · settlements', () {
    test('absent stays absent: unknown, not none', () async {
      final history = await _readHistory(_history());
      expect(history.settlements, isNull);
      expect(history.isEmpty, isTrue);
    });

    test('present rows decode strictly', () async {
      final history = await _readHistory(
        _history(
          settlements: <Object?>[
            _settlement(),
            _settlement(
              id: '7b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e',
              kind: 'refunded',
              block: '944',
            ),
          ],
        ),
      );
      final rows = history.settlements!;
      expect(rows, hasLength(2));
      expect(rows.first.kind, LaunchSettlementKind.claimed);
      expect(rows.last.kind, LaunchSettlementKind.refunded);
      expect(rows.first.confirmationState, LaunchConfirmationState.confirmed);
      expect(history.isEmpty, isFalse);
    });

    test('an empty array is an indexed "none"', () async {
      final history = await _readHistory(_history(settlements: <Object?>[]));
      expect(history.settlements, isEmpty);
    });

    test('an unavailable source never carries settlements', () {
      expect(
        () =>
            _readHistory(_history(available: false, settlements: <Object?>[])),
        _invalid(),
      );
    });

    final malformed = <String, Object? Function()>{
      'null': () => null,
      'an unknown row key': () => <Object?>[_settlement()..['extra'] = 1],
      'an unknown kind': () => <Object?>[_settlement(kind: 'sold')],
      'a duplicate id': () => <Object?>[_settlement(), _settlement()],
      'a numeric amount': () => <Object?>[_settlement()..['amount'] = 1],
      'an upper-case hash': () => <Object?>[
        _settlement()..['transactionHash'] = '0x${'C1' * 32}',
      ],
    };
    for (final entry in malformed.entries) {
      test('${entry.key} is refused whole', () {
        expect(
          () => _readHistory(_history(settlements: entry.value())),
          _invalid(),
        );
      });
    }
  });
}
