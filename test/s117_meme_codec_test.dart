import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/meme/loop_v2_meme_api.dart';
import 'package:loop_mobile/integrations/backend/v2/meme/loop_v2_meme_codec.dart';

import 'support/meme_fixtures.dart';

const String _requestId = '7d0f8c1e-1b2a-4c3d-8e4f-5a6b7c8d9e0f';
const String _token = 'access-token';
const String _version = '1.0.0';
const String _key = '4f1c2d3e-5a6b-4c7d-8e9f-0a1b2c3d4e5f';

/// Answers each request with the next scripted response and records it.
final class _ScriptAdapter implements HttpClientAdapter {
  _ScriptAdapter(this.responses);

  final List<(int, Object?)> responses;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = responses.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
        'cache-control': <String>['no-store'],
        'x-request-id': <String>[_requestId],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _error(String code, {String? reasonCode}) =>
    <String, Object?>{
      'code': code,
      'category': switch (code) {
        'CAPABILITY_UNAVAILABLE' => 'availability',
        'RATE_LIMITED' => 'rateLimit',
        'NOT_FOUND' => 'availability',
        'DATA_STALE' => 'stale',
        _ => 'validation',
      },
      'retryable': false,
      'userMessageKey': 'errors.meme.refused',
      'correlationId': _requestId,
      'detailsSafe': reasonCode == null
          ? null
          : <String, Object?>{'reasonCode': reasonCode},
      'providerReferenceSafe': null,
    };

(DioLoopV2MemeApi, _ScriptAdapter) _api(List<(int, Object?)> responses) {
  final adapter = _ScriptAdapter(responses);
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = adapter;
  return (DioLoopV2MemeApi(dio, mediaUrl: memeTestMediaUrl), adapter);
}

Matcher _failure(int status, String code, {String? reasonCode}) =>
    isA<LoopBackendFailure>()
        .having((f) => f.statusCode, 'statusCode', status)
        .having((f) => f.code, 'code', code)
        .having((f) => f.detailsSafe?.reasonCode, 'reasonCode', reasonCode);

void main() {
  group('GET /v2/meme/tokens', () {
    test(
      'decodes a page and sends tab with limit, never with cursor',
      () async {
        final (api, adapter) = _api(<(int, Object?)>[
          (200, memePageJson(tab: 'hot', nextCursor: 'abc.def')),
          (200, memePageJson(tab: 'hot')),
        ]);
        final page = await api.listTokens(
          accessToken: _token,
          clientVersion: _version,
          tab: MemeListTab.hot,
        );
        expect(page.tab, MemeListTab.hot);
        expect(page.nextCursor, 'abc.def');
        final row = page.items.single;
        expect(row.symbol, 'FROG');
        expect(row.progressBps, 3327);
        expect(row.priceUsd1.toString(), '0.000009891332712022');
        expect(row.priceSource?.source, MemePriceSource.loopCurve);
        // The picture is loaded from this build's own origin.
        expect(row.imageUrl, 'https://api.test/v2/media/$memeMediaId.webp');
        expect(adapter.requests.first.path, '/v2/meme/tokens');
        expect(adapter.requests.first.queryParameters, <String, Object?>{
          'tab': 'hot',
          'limit': 30,
        });
        expect(adapter.requests.first.headers['idempotency-key'], isNull);

        await api.listTokens(
          accessToken: _token,
          clientVersion: _version,
          tab: MemeListTab.hot,
          cursor: 'abc.def',
        );
        expect(adapter.requests.last.queryParameters, <String, Object?>{
          'tab': 'hot',
          'cursor': 'abc.def',
        });
      },
    );

    test('a 503 is unavailable with its reason, never an empty list', () {
      final (api, _) = _api(<(int, Object?)>[
        (
          503,
          _error(
            'CAPABILITY_UNAVAILABLE',
            reasonCode: 'MEME_CONTRACT_NOT_CONFIGURED',
          ),
        ),
      ]);
      expect(
        api.listTokens(
          accessToken: _token,
          clientVersion: _version,
          tab: MemeListTab.fresh,
        ),
        throwsA(
          _failure(
            503,
            'CAPABILITY_UNAVAILABLE',
            reasonCode: 'MEME_CONTRACT_NOT_CONFIGURED',
          ),
        ),
      );
    });

    test('an unknown field is an invalid payload', () {
      final body = memePageJson();
      (body['items']! as List<Object?>)[0] = <String, Object?>{
        ...memeRowJson(),
        'surprise': true,
      };
      final (api, _) = _api(<(int, Object?)>[(200, body)]);
      expect(
        api.listTokens(
          accessToken: _token,
          clientVersion: _version,
          tab: MemeListTab.fresh,
        ),
        throwsA(
          isA<LoopBackendFailure>().having(
            (f) => f.kind,
            'kind',
            LoopBackendFailureKind.invalidPayload,
          ),
        ),
      );
    });

    test('a graduated row priced from its pool says so (S116b)', () {
      final row = LoopV2MemeCodec.row(
        memeRowJson(
          status: 'graduated',
          change: null,
          priceSource: 'pool_slot0',
        ),
        mediaUrl: memeTestMediaUrl,
      );
      expect(row.priceSource?.source, MemePriceSource.poolSlot0);
      expect(row.priceSource?.source.label, '池子推算');
    });

    test('a graduated row without a price carries its reason', () {
      final row = LoopV2MemeCodec.row(
        memeRowJson(
          status: 'graduated',
          price: null,
          cap: null,
          change: null,
          quoteUnavailable: 'MEME_DEX_CHAIN_NOT_PRICED',
        ),
        mediaUrl: memeTestMediaUrl,
      );
      expect(row.priceUsd1, isNull);
      expect(row.quoteUnavailableReason, 'MEME_DEX_CHAIN_NOT_PRICED');
      expect(row.isGraduated, isTrue);
    });
  });

  group('GET /v2/meme/tokens/{id}', () {
    test('decodes curve, viewer, contract and graduation', () async {
      final (api, adapter) = _api(<(int, Object?)>[
        (
          200,
          memeDetailJson(
            status: 'graduated',
            graduation: memeGraduationJson(),
            pool: '0x7777777777777777777777777777777777777777',
            graduatedAt: '2026-10-08T05:00:00.000Z',
            priceSource: 'dexscreener',
          ),
        ),
      ]);
      final detail = await api.getToken(
        accessToken: _token,
        clientVersion: _version,
        memeTokenId: memeTokenIdA,
      );
      expect(adapter.requests.single.path, '/v2/meme/tokens/$memeTokenIdA');
      expect(detail.status, MemeTokenStatus.graduated);
      expect(detail.curve.tradeFeeBps, 100);
      expect(detail.curve.walletCapTokens, BigInt.parse('4${'0' * 25}'));
      expect(detail.viewer?.balance, BigInt.parse('10000000000000000000'));
      expect(detail.contract.chainId, 'eip155:97');
      expect(
        detail.graduation?.pool,
        '0x7777777777777777777777777777777777777777',
      );
      expect(detail.links.twitter, 'https://x.com/frog');
      expect(detail.row.priceSource?.source, MemePriceSource.dexscreener);
    });

    test(
      'listing + listingReason (decision 0102) decode in both states',
      () async {
        Map<String, Object?> withListing(String listing, Object? reason) {
          final doc = memeDetailJson();
          (doc['memeToken']! as Map<String, Object?>)
            ..['listing'] = listing
            ..['listingReason'] = reason;
          return doc;
        }

        final hidden = withListing('hidden', <String, Object?>{
          'reasonCode': 'OPERATOR_USER_REPORTS',
          'reasonText': '多位用户举报，已下架',
        });
        final listed = withListing('listed', null);
        final mismatch = withListing('hidden', null);
        final (api, _) = _api(<(int, Object?)>[
          (200, hidden),
          (200, listed),
          (200, mismatch),
        ]);
        final a = await api.getToken(
          accessToken: _token,
          clientVersion: _version,
          memeTokenId: memeTokenIdA,
        );
        expect(a.isHidden, isTrue);
        expect(a.listingReason?.reasonCode, 'OPERATOR_USER_REPORTS');
        expect(a.listingReason?.reasonText, '多位用户举报，已下架');
        final b = await api.getToken(
          accessToken: _token,
          clientVersion: _version,
          memeTokenId: memeTokenIdA,
        );
        expect(b.isHidden, isFalse);
        expect(b.listingReason, isNull);
        await expectLater(
          api.getToken(
            accessToken: _token,
            clientVersion: _version,
            memeTokenId: memeTokenIdA,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
      },
    );

    test('the fill target comes from the snapshot, ≈17,582 USD1', () {
      final detail = memeDetail();
      final target = detail.curve.fillTargetUsd1!;
      expect(memeUnits(target).floor().toString(), '17582');
    });

    test('viewerUnavailable is read and never paired with a viewer', () {
      final detail = memeDetail(
        viewerUnavailable: 'MEME_VIEWER_WALLET_MISSING',
      );
      expect(detail.viewer, isNull);
      expect(detail.viewerUnavailableReason, 'MEME_VIEWER_WALLET_MISSING');
    });

    test('a 404 is the server refusing, with its reason', () {
      final (api, _) = _api(<(int, Object?)>[
        (404, _error('NOT_FOUND', reasonCode: 'MEME_TOKEN_NOT_FOUND')),
      ]);
      expect(
        api.getToken(
          accessToken: _token,
          clientVersion: _version,
          memeTokenId: memeTokenIdA,
        ),
        throwsA(_failure(404, 'NOT_FOUND', reasonCode: 'MEME_TOKEN_NOT_FOUND')),
      );
    });

    test('a malformed id never leaves the device', () {
      final (api, adapter) = _api(<(int, Object?)>[]);
      expect(
        api.getToken(
          accessToken: _token,
          clientVersion: _version,
          memeTokenId: 'not-an-id',
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(adapter.requests, isEmpty);
    });
  });

  group('trades, holders, candles', () {
    test('trades decode and continue on a cursor', () async {
      final (api, adapter) = _api(<(int, Object?)>[
        (200, memeTradesJson(nextCursor: 'next.page')),
      ]);
      final page = await api.getTrades(
        accessToken: _token,
        clientVersion: _version,
        memeTokenId: memeTokenIdA,
      );
      expect(page.items.single.isBuy, isTrue);
      expect(page.items.single.usd1Amount, BigInt.parse('5000000000000000000'));
      expect(page.nextCursor, 'next.page');
      expect(
        adapter.requests.single.path,
        '/v2/meme/tokens/$memeTokenIdA/trades',
      );
    });

    test('trades for another token are an invalid payload', () {
      final (api, _) = _api(<(int, Object?)>[
        (200, memeTradesJson(id: memeTokenIdB)),
      ]);
      expect(
        api.getTrades(
          accessToken: _token,
          clientVersion: _version,
          memeTokenId: memeTokenIdA,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('holders decode the frozen distribution', () async {
      final (api, _) = _api(<(int, Object?)>[
        (200, memeHoldersJson(frozenAt: '2026-10-08T05:00:00.000Z')),
      ]);
      final page = await api.getHolders(
        accessToken: _token,
        clientVersion: _version,
        memeTokenId: memeTokenIdA,
      );
      expect(page.frozenAt, isNotNull);
      expect(page.items.single.isCreator, isTrue);
      expect(page.items.single.shareBps, 1000);
    });

    test('holders: 503 is unavailable', () {
      final (api, _) = _api(<(int, Object?)>[
        (
          503,
          _error(
            'CAPABILITY_UNAVAILABLE',
            reasonCode: 'MEME_RUNTIME_UNAVAILABLE',
          ),
        ),
      ]);
      expect(
        api.getHolders(
          accessToken: _token,
          clientVersion: _version,
          memeTokenId: memeTokenIdA,
        ),
        throwsA(
          _failure(
            503,
            'CAPABILITY_UNAVAILABLE',
            reasonCode: 'MEME_RUNTIME_UNAVAILABLE',
          ),
        ),
      );
    });

    test('candles decode in order and send the interval', () async {
      final (api, adapter) = _api(<(int, Object?)>[
        (200, memeCandlesJson(interval: '5m')),
      ]);
      final series = await api.getCandles(
        accessToken: _token,
        clientVersion: _version,
        memeTokenId: memeTokenIdA,
        interval: MemeCandleInterval.fiveMinutes,
      );
      expect(series.candles, hasLength(3));
      expect(
        series.candles.first.closeTime.difference(
          series.candles.first.openTime,
        ),
        const Duration(minutes: 5),
      );
      expect(adapter.requests.single.queryParameters['interval'], '5m');
    });

    test('candles whose high is under the low are an invalid payload', () {
      final body = memeCandlesJson();
      final first =
          (body['items']! as List<Object?>).first! as Map<String, Object?>;
      first['high'] = '0.0000001';
      final (api, _) = _api(<(int, Object?)>[(200, body)]);
      expect(
        api.getCandles(
          accessToken: _token,
          clientVersion: _version,
          memeTokenId: memeTokenIdA,
          interval: MemeCandleInterval.fifteenMinutes,
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('GET /v2/meme/quote', () {
    test('decodes a buy quote and sends a whole-unit amount', () async {
      final (api, adapter) = _api(<(int, Object?)>[
        (200, memeQuoteJson(walletCapHit: true)),
      ]);
      final quote = await api.getQuote(
        accessToken: _token,
        clientVersion: _version,
        memeTokenId: memeTokenIdA,
        side: MemeTradeSide.buy,
        amount: '10',
        walletId: memeWalletId,
      );
      expect(quote.walletCapHit, isTrue);
      expect(quote.priceImpactBps, 24);
      expect(quote.basisFromChain, isTrue);
      expect(adapter.requests.single.queryParameters, <String, Object?>{
        'tokenId': memeTokenIdA,
        'side': 'buy',
        'amount': '10',
        'walletId': memeWalletId,
      });
    });

    test('a full curve is a 409 with its reason', () {
      final (api, _) = _api(<(int, Object?)>[
        (409, _error('DATA_STALE', reasonCode: 'MEME_CURVE_FULL')),
      ]);
      expect(
        api.getQuote(
          accessToken: _token,
          clientVersion: _version,
          memeTokenId: memeTokenIdA,
          side: MemeTradeSide.buy,
          amount: '10',
        ),
        throwsA(_failure(409, 'DATA_STALE', reasonCode: 'MEME_CURVE_FULL')),
      );
    });
  });

  group('POST /v2/meme/tokens', () {
    test(
      'sends the draft with its key and decodes the predicted address',
      () async {
        final (api, adapter) = _api(<(int, Object?)>[
          (
            201,
            memeDetailJson(
              status: 'draft',
              tokenAddress: null,
              price: null,
              cap: null,
              change: null,
              quoteUnavailable: 'MEME_TOKEN_NOT_ON_CHAIN',
              vanity: false,
              viewerNull: true,
              curve: memeFreshCurveJson(),
            ),
          ),
        ]);
        final detail = await api.postToken(
          accessToken: _token,
          clientVersion: _version,
          idempotencyKey: _key,
          draft: const MemeCreateDraft(
            name: 'Frog',
            symbol: 'FROG',
            links: MemeLinks(twitter: 'https://x.com/frog'),
          ),
        );
        final request = adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.headers['idempotency-key'], _key);
        expect(request.data, <String, Object?>{
          'name': 'Frog',
          'symbol': 'FROG',
          'links': <String, Object?>{'twitter': 'https://x.com/frog'},
        });
        expect(detail.status, MemeTokenStatus.draft);
        expect(detail.vanity, isFalse);
        expect(detail.predictedAddress, endsWith('6666'));
        expect(detail.row.quoteUnavailableReason, 'MEME_TOKEN_NOT_ON_CHAIN');
      },
    );

    test('the daily limit is a 429 with MEME_CREATE_RATE_LIMITED', () {
      final (api, _) = _api(<(int, Object?)>[
        (429, _error('RATE_LIMITED', reasonCode: 'MEME_CREATE_RATE_LIMITED')),
      ]);
      expect(
        api.postToken(
          accessToken: _token,
          clientVersion: _version,
          idempotencyKey: _key,
          draft: const MemeCreateDraft(name: 'Frog', symbol: 'FROG'),
        ),
        throwsA(
          _failure(429, 'RATE_LIMITED', reasonCode: 'MEME_CREATE_RATE_LIMITED'),
        ),
      );
    });
  });

  group('intents', () {
    test('prepare decodes the approval and both transactions', () async {
      final (api, adapter) = _api(<(int, Object?)>[
        (201, memeIntentJson(approval: true)),
      ]);
      final intent = await api.postIntent(
        accessToken: _token,
        clientVersion: _version,
        idempotencyKey: _key,
        memeTokenId: memeTokenIdA,
        kind: MemeIntentKind.buy,
        walletId: memeWalletId,
        usd1Amount: '10',
        slippageBps: 100,
      );
      expect(adapter.requests.single.data, <String, Object?>{
        'kind': 'buy',
        'walletId': memeWalletId,
        'usd1Amount': '10',
        'slippageBps': 100,
      });
      expect(intent.approval?.token, memeUsd1Address);
      expect(intent.approval?.unsignedTransaction.wire['nonce'], '0x7');
      expect(intent.unsignedTransaction.wire['nonce'], '0x8');
      expect(intent.payloadMatchesReview, isTrue);
      expect(intent.canSignAt(DateTime.utc(2026, 10, 8)), isTrue);
    });

    test('a transaction that is not the reviewed call is flagged', () {
      final intent = LoopV2MemeCodec.intent(
        memeIntentJson(mainData: '0xdeadbeef', calldataData: '0xce9eb517'),
      );
      expect(intent.payloadMatchesReview, isFalse);
    });

    test('prepare refusals carry their rule', () {
      final (api, _) = _api(<(int, Object?)>[
        (
          422,
          _error('VALIDATION_FAILED', reasonCode: 'MEME_WALLET_CAP_EXCEEDED'),
        ),
      ]);
      expect(
        api.postIntent(
          accessToken: _token,
          clientVersion: _version,
          idempotencyKey: _key,
          memeTokenId: memeTokenIdA,
          kind: MemeIntentKind.buy,
          walletId: memeWalletId,
          usd1Amount: '10',
        ),
        throwsA(
          _failure(
            422,
            'VALIDATION_FAILED',
            reasonCode: 'MEME_WALLET_CAP_EXCEEDED',
          ),
        ),
      );
    });

    test('broadcast-report sends the hash and reads the reported state', () async {
      final (api, adapter) = _api(<(int, Object?)>[
        (200, memeIntentJson(state: 'broadcast_reported')),
      ]);
      final hash =
          '0x3000000000000000000000000000000000000000000000000000000000000003';
      final intent = await api.postBroadcastReport(
        accessToken: _token,
        clientVersion: _version,
        idempotencyKey: _key,
        memeTokenId: memeTokenIdA,
        memeIntentId: memeIntentIdA,
        txHash: hash,
      );
      expect(
        adapter.requests.single.path,
        '/v2/meme/tokens/$memeTokenIdA/intents/$memeIntentIdA/broadcast-report',
      );
      expect(adapter.requests.single.data, <String, Object?>{'txHash': hash});
      expect(intent.state, MemeIntentState.broadcastReported);
      expect(intent.signingAllowed, isFalse);
    });

    test('broadcast-report: another hash is a 409', () {
      final (api, _) = _api(<(int, Object?)>[
        (409, _error('DATA_STALE', reasonCode: 'MEME_INTENT_ALREADY_REPORTED')),
      ]);
      expect(
        api.postBroadcastReport(
          accessToken: _token,
          clientVersion: _version,
          idempotencyKey: _key,
          memeTokenId: memeTokenIdA,
          memeIntentId: memeIntentIdA,
          txHash: '0x3000000000000000000000000000000000000000000000000000000000000003',
        ),
        throwsA(
          _failure(
            409,
            'DATA_STALE',
            reasonCode: 'MEME_INTENT_ALREADY_REPORTED',
          ),
        ),
      );
    });

    test('GET intent reads a confirmed state', () async {
      final (api, adapter) = _api(<(int, Object?)>[
        (200, memeIntentJson(state: 'confirmed')),
      ]);
      final intent = await api.getIntent(
        accessToken: _token,
        clientVersion: _version,
        memeIntentId: memeIntentIdA,
      );
      expect(adapter.requests.single.path, '/v2/meme/intents/$memeIntentIdA');
      expect(intent.state, MemeIntentState.confirmed);
      expect(intent.state.isTerminal, isTrue);
    });

    test('GET intent of another account is a 404', () {
      final (api, _) = _api(<(int, Object?)>[(404, _error('NOT_FOUND'))]);
      expect(
        api.getIntent(
          accessToken: _token,
          clientVersion: _version,
          memeIntentId: memeIntentIdA,
        ),
        throwsA(_failure(404, 'NOT_FOUND')),
      );
    });
  });

  group('POST /v2/media/community-logos', () {
    test('uploads the square and reads a logo reference', () async {
      final (api, adapter) = _api(<(int, Object?)>[
        (
          201,
          <String, Object?>{
            'mediaId': memeMediaId,
            'ref': 'logo:media/$memeMediaId',
            'url': '/v2/media/$memeMediaId.webp',
            'width': 512,
            'height': 512,
            'contractVersion': '2.0',
          },
        ),
      ]);
      final image = await api.uploadLogo(
        accessToken: _token,
        clientVersion: _version,
        idempotencyKey: _key,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        contentType: 'image/png',
      );
      expect(adapter.requests.single.path, '/v2/media/community-logos');
      expect(image.mediaId, memeMediaId);
      expect(image.url, 'https://api.test/v2/media/$memeMediaId.webp');
    });

    test('an avatar reference is not a logo', () {
      final (api, _) = _api(<(int, Object?)>[
        (
          201,
          <String, Object?>{
            'mediaId': memeMediaId,
            'ref': 'avatar:media/$memeMediaId',
            'url': '/v2/media/$memeMediaId.webp',
            'width': 512,
            'height': 512,
            'contractVersion': '2.0',
          },
        ),
      ]);
      expect(
        api.uploadLogo(
          accessToken: _token,
          clientVersion: _version,
          idempotencyKey: _key,
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          contentType: 'image/png',
        ),
        throwsA(isA<LoopBackendFailure>()),
      );
    });
  });

  group('number helpers', () {
    test('whole-unit strings round-trip raw amounts exactly', () {
      expect(memeRawFromInput('10'), BigInt.parse('10000000000000000000'));
      expect(memeRawFromInput('0.5'), BigInt.parse('500000000000000000'));
      expect(memeRawFromInput('0'), isNull);
      expect(memeRawFromInput('1e3'), isNull);
      expect(memeRawFromInput('01'), isNull);
      expect(memeDecimalString(BigInt.parse('500000000000000000')), '0.5');
      expect(memeDecimalString(BigInt.parse('10000000000000000000')), '10');
    });

    test('the buy estimate follows the curve formula and the fee', () {
      final curve = memeDetail(curve: memeFreshCurveJson()).curve;
      final estimate = curve.estimateBuy(BigInt.parse('10000000000000000000'));
      expect(estimate.fee, BigInt.parse('100000000000000000'));
      // net 9.9 USD1 at 6,000 / 1,073,000,000 buys about 1.77M tokens.
      expect(memeUnits(estimate.out).floor().toString(), '1767533');
    });
  });
}
