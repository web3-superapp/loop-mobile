import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// Decision 0213 (loop-api 0167 / S251): the activity page may merge the
/// wallet's Launch-chain MEME v2 facts behind `WALLET_ACTIVITY_LAUNCH2_EMIT`.

const _accessToken = 'privy-access-token';
const _instanceA = '2f6a1c3e-5b7d-4e9f-8a1b-3c5d7e9f1a2b';
const _instanceB = '3a7b2d4f-6c8e-4f0a-9b2c-4d6e8f0a2b3c';
const _launchTx =
    '0x1111111111111111111111111111111111111111111111111111111111111111';
const _launchTx2 =
    '0x2222222222222222222222222222222222222222222222222222222222222222';

Map<String, Object?> _launch2Row({
  String kind = 'launch2_curve_buy',
  String instanceId = _instanceA,
  String transactionHash = _launchTx,
  int logIndex = 1,
  Object? amountMeme = '1000',
  Object? amountUsd1 = '10.2',
  Object? taxUsd1 = '0.2',
  Object? confirmations = 1124,
  String occurredAt = '2026-10-19T08:00:00.000Z',
}) => <String, Object?>{
  'kind': kind,
  'chainId': 'eip155:97',
  'instanceId': instanceId,
  'ticker': '星夜',
  'name': 'Evening Wind',
  'logoUrl': null,
  'amountMeme': amountMeme,
  'amountUsd1': amountUsd1,
  'taxUsd1': taxUsd1,
  'transactionHash': transactionHash,
  'logIndex': logIndex,
  'blockNumber': '51999000',
  'occurredAt': occurredAt,
  'confirmations': confirmations,
};

/// The §7.1 body: a claim, a transfer and a buy, in that merged order.
Map<String, Object?> _mergedBody({Object? launch2}) {
  final body = s5ActivityBody();
  final transfer = (body['items']! as List<Object?>).single;
  body['items'] = <Object?>[
    _launch2Row(
      kind: 'launch2_reward_claim',
      instanceId: _instanceB,
      transactionHash: _launchTx2,
      logIndex: 0,
      amountMeme: null,
      amountUsd1: '1.25',
      taxUsd1: null,
      confirmations: 41,
    ),
    transfer,
    _launch2Row(),
  ];
  body['launch2'] =
      launch2 ??
      <String, Object?>{
        'status': 'available',
        'chainId': 'eip155:97',
        'indexerBlockNumber': '52000160',
        'headBlockNumber': '52000163',
      };
  return body;
}

Future<LoopWalletActivityPage> _decode(Map<String, Object?> body) {
  final api = DioLoopV2WalletApi(
    s5Dio((options, handler) => handler.resolve(s5Response(options, body))),
  );
  return api.getActivity(
    accessToken: _accessToken,
    clientVersion: s5ClientVersion,
    walletId: s5WalletId,
  );
}

Matcher get _invalidPayload => throwsA(
  isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

LoopWalletLaunch2ActivityEntry _entry({
  required LoopWalletLaunch2ActivityKind kind,
  required String hash,
  String? amountMeme,
  String? amountUsd1,
  int? confirmations = 12,
  DateTime? at,
}) => LoopWalletLaunch2ActivityEntry(
  kind: kind,
  chainId: 'eip155:97',
  instanceId: _instanceA,
  ticker: '星夜',
  name: 'Evening Wind',
  logoUrl: null,
  amountMeme: amountMeme == null ? null : Decimal.parse(amountMeme),
  amountUsd1: amountUsd1 == null ? null : Decimal.parse(amountUsd1),
  taxUsd1: null,
  transactionHash: hash,
  logIndex: 0,
  blockNumber: BigInt.from(51999000),
  occurredAt: at ?? DateTime.utc(2026, 9, 8, 1),
  confirmations: confirmations,
);

LoopWalletActivityPage _mixedPage({LoopWalletLaunch2Leg? launch2}) {
  final transfer = s5Activity().items.single;
  return LoopWalletActivityPage(
    walletId: s5WalletId,
    rows: <LoopWalletActivityRecord>[
      _entry(
        kind: LoopWalletLaunch2ActivityKind.curveBuy,
        hash: _launchTx,
        amountMeme: '1000',
        amountUsd1: '20',
        at: DateTime.utc(2026, 9, 8, 3),
      ),
      transfer,
      _entry(
        kind: LoopWalletLaunch2ActivityKind.poolSell,
        hash: _launchTx2,
        amountMeme: '500',
        amountUsd1: '7.01',
        confirmations: null,
        at: DateTime.utc(2026, 9, 7, 23),
      ),
      _entry(
        kind: LoopWalletLaunch2ActivityKind.nftMint,
        hash: '0x3333333333333333333333333333333333333333333333333333333333333333',
        amountUsd1: '5',
        at: DateTime.utc(2026, 9, 7, 22),
      ),
    ],
    nextCursor: null,
    freshness: s5Activity().freshness,
    nativeTransfers: const LoopUnavailable(
      'NATIVE_TRANSFER_SCAN_NOT_SUPPORTED',
    ),
    crossChain: const LoopUnavailable('CROSS_CHAIN_ACTIVITY_NOT_SUPPORTED'),
    launch2:
        launch2 ??
        LoopWalletLaunch2Leg.available(
          chainId: 'eip155:97',
          indexerBlockNumber: BigInt.from(52000160),
          headBlockNumber: BigInt.from(52000163),
        ),
  );
}

void main() {
  group('codec', () {
    test('without the launch2 key the page reads as it always did', () async {
      final page = await _decode(s5ActivityBody());

      expect(page.launch2, isNull);
      expect(page.rows, hasLength(1));
      expect(page.items, hasLength(1));
      expect(page.launch2Items, isEmpty);
      expect(page.items.single.entryId, '$s5TxHash:3');
      expect(page.items.single.displayValue, Decimal.parse('1.5'));
    });

    test('merged rows decode in server order with the available leg', () async {
      final page = await _decode(_mergedBody());

      final leg = page.launch2!;
      expect(leg.isAvailable, isTrue);
      expect(leg.chainId, 'eip155:97');
      expect(leg.indexerBlockNumber, BigInt.from(52000160));
      expect(leg.headBlockNumber, BigInt.from(52000163));

      expect(page.rows, hasLength(3));
      expect(page.rows[0], isA<LoopWalletLaunch2ActivityEntry>());
      expect(page.rows[1], isA<LoopWalletActivityEntry>());
      expect(page.rows[2], isA<LoopWalletLaunch2ActivityEntry>());
      expect(page.items, hasLength(1));
      expect(page.launch2Items, hasLength(2));

      final claim = page.rows[0] as LoopWalletLaunch2ActivityEntry;
      expect(claim.kind, LoopWalletLaunch2ActivityKind.rewardClaim);
      expect(claim.instanceId, _instanceB);
      expect(claim.amountMeme, isNull);
      expect(claim.amountUsd1, Decimal.parse('1.25'));
      expect(claim.taxUsd1, isNull);
      expect(claim.confirmations, 41);

      final buy = page.rows[2] as LoopWalletLaunch2ActivityEntry;
      expect(buy.kind, LoopWalletLaunch2ActivityKind.curveBuy);
      expect(buy.ticker, '星夜');
      expect(buy.name, 'Evening Wind');
      expect(buy.logoUrl, isNull);
      expect(buy.amountMeme, Decimal.parse('1000'));
      expect(buy.amountUsd1, Decimal.parse('10.2'));
      expect(buy.taxUsd1, Decimal.parse('0.2'));
      expect(buy.blockNumber, BigInt.from(51999000));
      expect(buy.occurredAt, DateTime.utc(2026, 10, 19, 8));
      expect(buy.entryId, 'launch2:eip155:97:$_launchTx:1:launch2_curve_buy');
    });

    test(
      'a head the server could not read leaves null confirmations',
      () async {
        final body = _mergedBody(
          launch2: <String, Object?>{
            'status': 'available',
            'chainId': 'eip155:97',
            'indexerBlockNumber': '52000160',
            'headBlockNumber': null,
          },
        );
        (body['items']! as List<Object?>)[2] = _launch2Row(confirmations: null);

        final page = await _decode(body);

        expect(page.launch2!.headBlockNumber, isNull);
        expect(
          (page.rows[2] as LoopWalletLaunch2ActivityEntry).confirmations,
          isNull,
        );
      },
    );

    test(
      'an unavailable leg keeps the transfers and states its reason',
      () async {
        final body = s5ActivityBody();
        body['launch2'] = <String, Object?>{
          'status': 'unavailable',
          'reasonCode': 'LAUNCH2_INDEXER_NOT_STARTED',
        };

        final page = await _decode(body);

        expect(page.launch2!.isAvailable, isFalse);
        expect(
          page.launch2!.unavailable!.reasonCode,
          'LAUNCH2_INDEXER_NOT_STARTED',
        );
        expect(page.launch2!.chainId, isNull);
        expect(page.items, hasLength(1));
        expect(page.launch2Items, isEmpty);
      },
    );

    test('a kind this build does not know is skipped, not fatal', () async {
      final body = _mergedBody();
      (body['items']! as List<Object?>).add(<String, Object?>{
        'kind': 'launch2_future_kind',
        'someNewKey': true,
      });

      final page = await _decode(body);

      expect(page.rows, hasLength(3));
    });

    test('a non-string kind is an invalid payload', () async {
      final body = _mergedBody();
      (body['items']! as List<Object?>).add(<String, Object?>{'kind': 7});

      await expectLater(_decode(body), _invalidPayload);
    });

    test('an unknown root key is still an invalid payload', () async {
      final body = s5ActivityBody();
      body['launch3'] = null;

      await expectLater(_decode(body), _invalidPayload);
    });

    test('an unknown key on a transfer row is still refused', () async {
      final body = s5ActivityBody();
      final row =
          (body['items']! as List<Object?>).single as Map<String, Object?>;
      row['chainId'] = 'eip155:56';

      await expectLater(_decode(body), _invalidPayload);
    });

    test('a launch2 row with an extra or a missing key is refused', () async {
      final extra = _mergedBody();
      ((extra['items']! as List<Object?>)[2]! as Map<String, Object?>)['x'] = 1;
      await expectLater(_decode(extra), _invalidPayload);

      final missing = _mergedBody();
      ((missing['items']! as List<Object?>)[2]! as Map<String, Object?>).remove(
        'taxUsd1',
      );
      await expectLater(_decode(missing), _invalidPayload);
    });

    test('a launch2 leg of either shape with a stray key is refused', () async {
      await expectLater(
        _decode(
          _mergedBody(
            launch2: <String, Object?>{
              'status': 'available',
              'chainId': 'eip155:97',
              'indexerBlockNumber': '1',
              'headBlockNumber': '2',
              'reasonCode': 'X',
            },
          ),
        ),
        _invalidPayload,
      );
      await expectLater(
        _decode(
          _mergedBody(
            launch2: <String, Object?>{
              'status': 'unavailable',
              'reasonCode': 'LAUNCH2_ACTIVITY_READ_FAILED',
              'chainId': 'eip155:97',
            },
          ),
        ),
        _invalidPayload,
      );
      await expectLater(
        _decode(_mergedBody(launch2: <String, Object?>{'status': 'gone'})),
        _invalidPayload,
      );
    });

    test('a malformed amount is refused', () async {
      final body = _mergedBody();
      (body['items']! as List<Object?>)[2] = _launch2Row(amountUsd1: '1e5');

      await expectLater(_decode(body), _invalidPayload);
    });
  });

  group('tx-history page', () {
    testWidgets('transfers and MEME v2 rows render as one tape', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpS5Page(
        tester,
        TransactionHistoryScreen(walletId: s5WalletId, onNavigate: opened.add),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(value: _mixedPage()),
        ),
      );

      // The transfer row is unchanged.
      expect(find.text('收到 WBNB'), findsOneWidget);
      expect(find.text('+1.5'), findsOneWidget);

      // A buy: paid USD1 in rise, MEME received under it.
      expect(find.text('买入 星夜'), findsOneWidget);
      final buyValue = tester.widget<Text>(find.text('-20 USD1'));
      expect(buyValue.style?.color, LoopColors.rise);
      expect(find.text('+1,000 星夜'), findsOneWidget);

      // A sell: received USD1 in fall; its head was unreadable.
      expect(find.text('卖出 星夜'), findsOneWidget);
      final sellValue = tester.widget<Text>(find.text('+7.01 USD1'));
      expect(sellValue.style?.color, LoopColors.fall);
      expect(find.text('-500 星夜'), findsOneWidget);
      expect(find.textContaining('确认中'), findsOneWidget);
      expect(find.textContaining('Launch 链'), findsNWidgets(3));

      expect(find.text('铸造勋章 · 星夜'), findsOneWidget);
      expect(find.text('-5 USD1'), findsOneWidget);

      // Server order is kept: buy, transfer, sell, mint.
      final buyY = tester.getTopLeft(find.text('买入 星夜')).dy;
      final transferY = tester.getTopLeft(find.text('收到 WBNB')).dy;
      final sellY = tester.getTopLeft(find.text('卖出 星夜')).dy;
      expect(buyY, lessThan(transferY));
      expect(transferY, lessThan(sellY));

      // docs/42 附C: a list row is at least 64 high.
      final row = find.byKey(
        const ValueKey<String>(
          'tx-entry-launch2:eip155:97:$_launchTx:0:launch2_curve_buy',
        ),
      );
      expect(row, findsOneWidget);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(64));
      expect(tester.widget(row), isA<LoopRecordRow>());

      // No unavailable line when the leg was merged.
      expect(
        find.byKey(const ValueKey<String>('tx-history-launch2-unavailable')),
        findsNothing,
      );

      // A MEME row opens its project.
      await tester.tap(find.text('买入 星夜'));
      await tester.pumpAndSettle();
      expect(opened, <String>[Launch2Route.instance(_instanceA)]);

      // 收到 lists transfers only.
      await tester.tap(find.byKey(const ValueKey<String>('tx-history-seg-1')));
      await tester.pumpAndSettle();
      expect(find.text('收到 WBNB'), findsOneWidget);
      expect(find.text('买入 星夜'), findsNothing);
    });

    testWidgets('an unmerged leg is a stated gap, not an empty list', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(
            value: LoopWalletActivityPage(
              walletId: s5WalletId,
              items: s5Activity().items,
              nextCursor: null,
              freshness: s5Activity().freshness,
              nativeTransfers: const LoopUnavailable(
                'NATIVE_TRANSFER_SCAN_NOT_SUPPORTED',
              ),
              crossChain: const LoopUnavailable(
                'CROSS_CHAIN_ACTIVITY_NOT_SUPPORTED',
              ),
              launch2: const LoopWalletLaunch2Leg.unavailable(
                LoopUnavailable('LAUNCH2_ACTIVITY_READ_FAILED'),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('tx-history-launch2-unavailable')),
        findsOneWidget,
      );
      expect(find.text('MEME 记录暂不可用'), findsOneWidget);
      expect(find.textContaining('MEME 记录这次没有读到'), findsOneWidget);
      expect(find.text('收到 WBNB'), findsOneWidget);
      final lineY = tester.getTopLeft(find.text('MEME 记录暂不可用')).dy;
      expect(lineY, lessThan(tester.getTopLeft(find.text('收到 WBNB')).dy));
    });

    for (final (failure, key) in <(LoopChainFailureKind, String)>[
      (LoopChainFailureKind.offline, 'tx-history-state-offline'),
      (LoopChainFailureKind.permissionDenied, 'tx-history-state-permission'),
      (LoopChainFailureKind.indexingDelayed, 'tx-history-state-unavailable'),
      (LoopChainFailureKind.readFailed, 'tx-history-state-error'),
    ]) {
      testWidgets('a failed first read is ${failure.name}, not a tape', (
        tester,
      ) async {
        await pumpS5Page(
          tester,
          const TransactionHistoryScreen(walletId: s5WalletId),
          wallet: FakeWalletReadGateway(
            activity: S5Answer<LoopWalletActivityPage>(failure: failure),
          ),
        );
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
        expect(find.text('买入 星夜'), findsNothing);
      });
    }

    testWidgets('loading is the skeleton tape', (tester) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(pending: true),
        ),
        settle: false,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('tx-history-state-loading')),
        findsOneWidget,
      );
    });

    testWidgets('a merged page with no rows is empty, not unavailable', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(walletId: s5WalletId),
        wallet: FakeWalletReadGateway(
          activity: S5Answer<LoopWalletActivityPage>(
            value: LoopWalletActivityPage(
              walletId: s5WalletId,
              nextCursor: null,
              freshness: s5Activity().freshness,
              nativeTransfers: const LoopUnavailable(
                'NATIVE_TRANSFER_SCAN_NOT_SUPPORTED',
              ),
              crossChain: const LoopUnavailable(
                'CROSS_CHAIN_ACTIVITY_NOT_SUPPORTED',
              ),
              launch2: LoopWalletLaunch2Leg.available(
                chainId: 'eip155:97',
                indexerBlockNumber: BigInt.one,
                headBlockNumber: null,
              ),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('tx-history-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tx-history-launch2-unavailable')),
        findsNothing,
      );
    });
  });
}
