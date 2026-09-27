import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';

import 'support/s5_fixtures.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// Decision 0100 · S91. The strict decoders against three optional keys the
/// server already sends (loop-api `openapi/loop-api.v2.json`):
///
/// - `GET /v2/launch/economy` → `onChain` (S83b.10). Its absence in the
///   decoder broke 「LOOP 生态账本」 on every device once the contract was
///   configured: 200 on the wire, 「返回的数据不完整」 on screen.
/// - `GET /v2/wallets/{id}/balances` → root `launchUsd1` (decision 0081).
/// - `launchIntent.revertReason` (decision 0080).
///
/// Bodies are 测试专用, written from the OpenAPI schema.

const _requestId = '11111111-2222-4333-8444-555555555555';
final _blockHash = '0x${'bb' * 32}';

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.statusCode, this.body);

  final int statusCode;
  final Object? body;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      'cache-control': <String>['no-store'],
      'x-request-id': <String>[_requestId],
    },
  );
}

LoopV2LaunchApi _api(int status, Object? body) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _Adapter(status, body);
  return DioLoopV2LaunchApi(dio);
}

Matcher _invalid() => throwsA(
  isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

/// The pre-contract economy document (no `onChain`), byte shape of S83a.
Map<String, Object?> _economyBody() => <String, Object?>{
  'projects': <String, Object?>{
    'draft': 1,
    'submitted': 0,
    'in_review': 0,
    'returned': 0,
    'approved': 3,
    'rejected': 0,
  },
  'launches': <String, Object?>{
    'unscheduled': 1,
    'scheduled': 1,
    'live': 1,
    'ended': 0,
  },
  'confirmedRoundCount': 4,
  'totalSupply': <String, Object?>{
    'status': 'unavailable',
    'reasonCode': 'LAUNCH_ECONOMY_CONTRACT_PENDING',
  },
  'distributed': <String, Object?>{
    'status': 'unavailable',
    'reasonCode': 'LAUNCH_ECONOMY_CONTRACT_PENDING',
  },
  'ecosystemTax': <String, Object?>{
    'status': 'unavailable',
    'reasonCode': 'LAUNCH_ECONOMY_CONTRACT_PENDING',
  },
  'source': 'loop',
  'observedAt': '2026-09-27T08:00:00.000Z',
  'contractVersion': '2.0',
};

Map<String, Object?> _available() => <String, Object?>{
  'status': 'available',
  'registeredSaleCount': 1,
  'totalRaisedUsd1': '170000000000000000000',
  'lockedLpCount': 1,
  'source': 'loop_indexer',
  'indexedBlockNumber': '950',
  'indexedBlockHash': _blockHash,
};

Future<LaunchEconomy> _economy(Map<String, Object?> body) =>
    _api(200, body).getEconomy(accessToken: 'token', clientVersion: '1.0.0');

LaunchEconomy _economyModel(LaunchEconomyOnChain? onChain) {
  final base = s7Economy();
  return LaunchEconomy(
    projects: base.projects,
    launches: base.launches,
    confirmedRoundCount: base.confirmedRoundCount,
    totalSupply: base.totalSupply,
    distributed: base.distributed,
    ecosystemTax: base.ecosystemTax,
    source: base.source,
    observedAt: base.observedAt,
    onChain: onChain,
  );
}

void main() {
  group('economy · onChain', () {
    test('the pre-contract document still decodes, with no onChain', () async {
      final economy = await _economy(_economyBody());
      expect(economy.onChain, isNull);
      expect(economy.confirmedRoundCount, 4);
    });

    test('available: the indexed counts, exact strings kept', () async {
      final economy = await _economy(
        _economyBody()..['onChain'] = _available(),
      );
      final onChain = economy.onChain! as LaunchEconomyOnChainAvailable;
      expect(onChain.registeredSaleCount, 1);
      expect(onChain.totalRaisedUsd1, '170000000000000000000');
      expect(onChain.lockedLpCount, 1);
      expect(onChain.source, 'loop_indexer');
      expect(onChain.indexedBlockNumber, '950');
      expect(onChain.indexedBlockHash, _blockHash);
    });

    test('unavailable: the reason code', () async {
      final economy = await _economy(
        _economyBody()
          ..['onChain'] = <String, Object?>{
            'status': 'unavailable',
            'reasonCode': 'LAUNCH_ONCHAIN_STATE_NOT_INDEXED',
          },
      );
      final onChain = economy.onChain;
      expect(onChain, isA<LaunchEconomyOnChainUnavailable>());
      expect(
        (onChain! as LaunchEconomyOnChainUnavailable).reasonCode,
        'LAUNCH_ONCHAIN_STATE_NOT_INDEXED',
      );
    });

    test('malformed onChain blocks are still refused', () {
      final bad = <Object?>[
        null,
        <String, Object?>{..._available(), 'extra': 1},
        <String, Object?>{..._available(), 'source': 'loop_db'},
        <String, Object?>{..._available(), 'indexedBlockNumber': 950},
        <String, Object?>{..._available(), 'indexedBlockHash': '0xBB'},
        <String, Object?>{..._available(), 'totalRaisedUsd1': '1.5'},
        <String, Object?>{..._available(), 'lockedLpCount': -1},
        <String, Object?>{..._available()}..remove('lockedLpCount'),
        <String, Object?>{'status': 'unavailable'},
        <String, Object?>{
          'status': 'unavailable',
          'reasonCode': 'LAUNCH_ONCHAIN_STATE_NOT_INDEXED',
          'registeredSaleCount': 0,
        },
      ];
      for (final block in bad) {
        expect(
          () => _economy(_economyBody()..['onChain'] = block),
          _invalid(),
          reason: '$block',
        );
      }
    });

    test('an unknown root key is still refused', () {
      expect(
        () => _economy(_economyBody()..['onchain'] = _available()),
        _invalid(),
      );
    });
  });

  group('economy page · 链上账本', () {
    testWidgets('available: raised, sales, locked LP and the block', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LoopEconomyScreen(),
        launch: FakeLaunchGateway(
          economy: S7Answer<LaunchEconomy>(
            value: _economyModel(
              LaunchEconomyOnChainAvailable(
                registeredSaleCount: 2,
                totalRaisedUsd1: '170000000000000000000',
                lockedLpCount: 1,
                source: 'loop_indexer',
                indexedBlockNumber: '67123456',
                indexedBlockHash: _blockHash,
              ),
            ),
          ),
        ),
      );
      final card = find.byKey(const ValueKey<String>('loop-economy-onchain'));
      await scrollToS7Section(tester, card);
      expect(find.text('链上账本'), findsOneWidget);
      expect(find.text('170 USD1'), findsOneWidget);
      expect(find.text('已登记发售'), findsOneWidget);
      expect(find.text('已锁 LP'), findsOneWidget);
      expect(find.text('读自区块 67,123,456 · LOOP 链上事件索引'), findsOneWidget);
      expect(find.textContaining('loop_indexer'), findsNothing);
    });

    testWidgets('unavailable: the ledger reason, never a zero', (tester) async {
      await pumpS7Page(
        tester,
        const LoopEconomyScreen(),
        launch: FakeLaunchGateway(
          economy: S7Answer<LaunchEconomy>(
            value: _economyModel(
              const LaunchEconomyOnChainUnavailable(
                'LAUNCH_ONCHAIN_STATE_NOT_INDEXED',
              ),
            ),
          ),
        ),
      );
      final strip = find.byKey(
        const ValueKey<String>('loop-economy-onchain-unavailable'),
      );
      await scrollToS7Section(tester, strip);
      expect(strip, findsOneWidget);
      expect(find.textContaining('链上事件索引还没有开始'), findsOneWidget);
      // The list-row sentence of the global mapping would be wrong here.
      expect(find.textContaining('列表不逐个读链'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('loop-economy-onchain')),
        findsNothing,
      );
    });

    testWidgets('absent: no on-chain block at all', (tester) async {
      await pumpS7Page(
        tester,
        const LoopEconomyScreen(),
        launch: FakeLaunchGateway(),
      );
      await scrollToS7Section(
        tester,
        find.byKey(const ValueKey<String>('loop-economy-loop-stats')),
      );
      expect(find.text('链上账本'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('loop-economy-onchain')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-economy-onchain-unavailable')),
        findsNothing,
      );
    });
  });

  group('wallet balances · root launchUsd1 (decision 0081)', () {
    const pair = <String, Object?>{
      'balance': '9000000000000000000',
      'allowance': '4000000000000000000',
    };

    test('a shared-slot document decodes and keeps the pair', () {
      final balances = DioLoopV2WalletApi.decodeBalances(
        s5BalancesBody()..['launchUsd1'] = pair,
        walletId: s5WalletId,
      );
      expect(balances.launchChain, isNull);
      expect(balances.launchUsd1?.balance, '9000000000000000000');
      expect(balances.launchUsd1?.allowance, '4000000000000000000');
    });

    test('without the key nothing changes', () {
      final balances = DioLoopV2WalletApi.decodeBalances(
        s5BalancesBody(),
        walletId: s5WalletId,
      );
      expect(balances.launchUsd1, isNull);
    });

    test('a malformed pair, a null, or both halves at once are refused', () {
      for (final value in <Object?>[
        null,
        <String, Object?>{'balance': '1'},
        <String, Object?>{...pair, 'extra': '1'},
        <String, Object?>{'balance': 1, 'allowance': '0'},
      ]) {
        expect(
          () => DioLoopV2WalletApi.decodeBalances(
            s5BalancesBody()..['launchUsd1'] = value,
            walletId: s5WalletId,
          ),
          _invalid(),
          reason: '$value',
        );
      }
      final both = s5BalancesBody()
        ..['launchUsd1'] = pair
        ..['launchChain'] = <String, Object?>{
          'chainId': loopLaunchTestnetChainId,
          'availability': 'unavailable',
          'reasonCode': 'BSC_BALANCE_CALL_FAILED',
          'nativeBalance': null,
          'usd1': pair,
        };
      expect(
        () => DioLoopV2WalletApi.decodeBalances(both, walletId: s5WalletId),
        _invalid(),
      );
    });
  });

  group('launch intent · revertReason (decision 0080)', () {
    const launchId = '9c1f0f2e-5a7b-4c3d-8e9f-0a1b2c3d4e5f';
    const intentId = '7a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
    const contract = '0x1111111111111111111111111111111111111111';
    final digest = '0x${'cd' * 32}';
    final txHash = '0x${'12' * 32}';

    Map<String, Object?> body(Map<String, Object?> extra) => <String, Object?>{
      'launchIntent': <String, Object?>{
        'launchIntentId': intentId,
        'state': 'reverted',
        'launchId': launchId,
        'projectId': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
        'walletId': '4d5e6f70-8a9b-4c1d-8e2f-3a4b5c6d7e8f',
        'roundId': '0b2c1d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e',
        'roundIndex': 1,
        'chainId': loopLaunchTestnetChainId,
        'contractAddress': contract,
        'quoteAssetId': 'usd1',
        'usd1Amount': '500000000000000000000',
        'expectedTokenAmount': '50000000000000000000000',
        'minTokenAmount': '49500000000000000000000',
        'walletCumulativeUsd1': '0',
        'deadline': '2026-09-22T15:00:00.000Z',
        'eligibilityProof': <Object?>[],
        'configVersion': digest,
        'stateTupleDigest': digest,
        'snapshotBlockNumber': '45000000',
        'snapshotBlockHash': digest,
        'payloadDigest': 'ab' * 32,
        'unsignedTransaction': <String, Object?>{
          'chainId': loopChainReference(loopLaunchTestnetChainId),
          'to': contract,
          'data': '0x${'00' * 36}',
          'value': '0x0',
        },
        'expiresAt': '2026-09-22T14:05:00.000Z',
        'createdAt': '2026-09-22T14:00:00.000Z',
        'transactionHash': txHash,
        ...extra,
      },
      'contractVersion': '2.0',
    };

    Future<LaunchPurchaseIntent> report(Map<String, Object?> extra) =>
        _api(200, body(extra)).postPurchaseBroadcastReport(
          accessToken: 'token',
          clientVersion: '1.0.0',
          idempotencyKey: '66666666-7777-4888-8999-aaaaaaaaaaaa',
          launchId: launchId,
          launchIntentId: intentId,
          txHash: txHash,
        );

    test('a reverted intent with revertReason: null decodes', () async {
      final intent = await report(<String, Object?>{'revertReason': null});
      expect(intent.state, LaunchIntentState.reverted);
      expect(intent.revertReason, isNull);
    });

    test('a decoded reason is kept', () async {
      final intent = await report(<String, Object?>{
        'revertReason': 'ROUND_CAP_EXCEEDED',
      });
      expect(intent.revertReason, 'ROUND_CAP_EXCEEDED');
    });

    test('a non-string or over-long reason is refused', () {
      expect(() => report(<String, Object?>{'revertReason': 1}), _invalid());
      expect(
        () => report(<String, Object?>{'revertReason': 'x' * 257}),
        _invalid(),
      );
    });
  });
}
