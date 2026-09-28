import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/launch/launch_trade_screen.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/launch/loop_v2_launch_api.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s83c_fixtures.dart';

/// S100 · decision 0103 addenda.
///
/// 1. S83b7c: `overview.graduated` is a union on `status` (loop-api S83b7b):
///    the old `unavailable` shape, or `available` with at most 50
///    `LaunchSummary` rows and `indexedBlockNumber`.
/// 2. S92b2: a purchase broadcast is read back with the same loop the claim
///    and the refund use, until it settles, and then the position and the
///    records are re-read.
///
/// Every body is 测试专用, written by hand from loop-api
/// `docs/frontend-v2-launch-api.md` §S83b7b (branch `feat/S83b7b-graduated`).

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Matcher _invalid() => throwsA(
  isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.invalidPayload,
  ),
);

Map<String, Object?> _baseline(String name) => jsonDecode(
  File('test/fixtures/s83a-baseline/$name.json').readAsStringSync(),
) as Map<String, Object?>;

String _uuid(int index) =>
    '9c1f0f2e-5a7b-4c3d-8e9f-${index.toRadixString(16).padLeft(12, '0')}';

Map<String, Object?> _graduatedRow(
  int index, {
  String liquidity = 'LP_LOCKED',
  String source = 'chain',
}) => <String, Object?>{
  'launchId': _uuid(index),
  'projectId': '3fa85f64-5717-4562-b3fc-2c963f66afa6',
  'name': 'MoonCat $index',
  'ticker': 'MCAT',
  'chainId': 'eip155:97',
  'contractAddress': '0x1111111111111111111111111111111111111111',
  'configDigest': null,
  'scheduleStatus': 'unscheduled',
  'onChainState': source == 'chain'
      ? <String, Object?>{
          'saleState': 'SUCCEEDED',
          'entitlementState': 'VESTING',
          'liquidityState': liquidity,
          'operationalState': 'ACTIVE',
          'stateTupleDigest': '0x${'cd' * 32}',
          'snapshotBlockNumber': '950',
          'snapshotBlockHash': '0x${'bb' * 32}',
          'configVersion': '0x${'ab' * 32}',
          'source': 'chain',
          'reasonCode': null,
        }
      : <String, Object?>{
          'saleState': 'unavailable',
          'entitlementState': 'unavailable',
          'liquidityState': 'unavailable',
          'operationalState': 'unavailable',
          'stateTupleDigest': null,
          'snapshotBlockNumber': null,
          'snapshotBlockHash': null,
          'source': 'unavailable',
          'reasonCode': 'LAUNCH_ONCHAIN_STATE_NOT_INDEXED',
        },
  'configVersion': 'launchMoonCatV1',
  'createdAt': '2026-09-08T01:00:00.000Z',
};

Map<String, Object?> _overviewWith(Object? graduated) =>
    _baseline('overview-confirmed')..['graduated'] = graduated;

Map<String, Object?> _available(List<Map<String, Object?>> rows) =>
    <String, Object?>{
      'status': 'available',
      'launches': rows,
      'indexedBlockNumber': '950',
    };

LaunchSummary _summary(int index) => s7LaunchSummary(
  launchId: _uuid(index),
  name: 'MoonCat $index',
  chainId: loopLaunchTestnetChainId,
  onChainState: s83cOnChain(
    sale: LaunchSaleState.succeeded,
    entitlement: LaunchEntitlementState.vesting,
    liquidity: LaunchLiquidityState.lpLocked,
  ),
);

Future<void> _pumpLaunch(
  WidgetTester tester,
  LaunchGraduated graduated, {
  bool evidenceConfirmed = false,
  void Function(String launchId)? onOpenLaunch,
}) => pumpS7Page(
  tester,
  LaunchScreen(onOpenLaunch: onOpenLaunch),
  meta: s7MetaSnapshot(launchEvidenceConfirmed: evidenceConfirmed),
  launch: FakeLaunchGateway(
    overview: S7Answer<LaunchOverview>(value: s7Overview(graduated: graduated)),
  ),
);

// ---------------------------------------------------------------------------
// purchase read-back doubles
// ---------------------------------------------------------------------------

final class _RecordingWallet implements WalletSigningGateway {
  _RecordingWallet(this.result);

  final WalletHandoffResult result;
  final List<SigningIntent> handed = <SigningIntent>[];

  @override
  WalletGatewayAvailability get availability =>
      WalletGatewayAvailability.available;

  @override
  String get label => 'test';

  @override
  Future<WalletHandoffResult> handoff(
    SigningIntent intent, {
    required DateTime now,
  }) async {
    handed.add(intent);
    final refusal = walletHandoffRefusal(intent, now: now);
    if (refusal != null) return WalletHandoffResult.rejected(refusal);
    return result;
  }
}

const _fiveHundred = '500000000000000000000';

LaunchPurchaseIntent _read(LaunchIntentState state) => s83cIntent(
  chainId: loopLaunchTestnetChainId,
  state: state,
  transactionHash: s83cTxHash,
);

/// Opens `launch-trade`, prepares the 500 USD1 purchase, signs it and closes
/// the sheet. The broadcast report answers `submitted`; the read-backs
/// answer [reads] in order.
Future<FakeLaunchGateway> _signPurchase(
  WidgetTester tester, {
  required List<LaunchPurchaseIntent> reads,
}) async {
  final gateway = FakeLaunchGateway(
    detail: S7Answer<LaunchDetail>(
      value: s83cDetail(chainId: loopLaunchTestnetChainId),
    ),
    holders: S7Answer<LaunchHolders>(value: s83cHolders()),
    history: S7Answer<LaunchHistory>(value: s83cHistory()),
    prepared: LaunchPurchasePrepared(
      intent: s83cIntent(
        chainId: loopLaunchTestnetChainId,
        walletRoundCapUsd1: _fiveHundred,
      ),
    ),
    reported: _read(LaunchIntentState.submitted),
    intentReads: reads,
  );
  final wallet = _RecordingWallet(
    WalletHandoffResult(accepted: true, code: 'ok', value: s83cTxHash),
  );
  await pumpS7Page(
    tester,
    LaunchTradeScreen(launchId: s7LaunchId, clock: s83cNow),
    launch: gateway,
    wallet: FakeWalletDirectory(
      activeWalletId: s7WalletId,
      wallets: [s83cWallet()],
      balances: [
        s83cBalances(
          chainId: loopLaunchTestnetChainId,
          allowance: _fiveHundred,
        ),
      ],
    ),
    meta: s7MetaSnapshot(launchEvidencePending: false),
    overrides: [
      walletSigningGatewayProvider.overrideWithValue(wallet),
      launchIntentPollIntervalProvider.overrideWithValue(
        const Duration(seconds: 1),
      ),
    ],
  );
  // `launch-detail` sits below the purchase page in the app and holds the
  // position and the records; here the test holds them.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LaunchTradeScreen)),
  );
  container.listen(launchHoldersControllerProvider, (_, _) {});
  container.listen(launchHistoryControllerProvider, (_, _) {});
  await container
      .read(launchHoldersControllerProvider.notifier)
      .open(s7LaunchId);
  await container
      .read(launchHistoryControllerProvider.notifier)
      .open(s7LaunchId);
  await tester.pumpAndSettle();

  await tester.tap(_key('launch-round-1'));
  await tester.pumpAndSettle();
  await tester.enterText(_key('launch-trade-amount'), '500');
  await tester.pumpAndSettle();
  await scrollToS7Section(tester, _key('launch-trade-submit'));
  await tester.tap(_key('launch-trade-submit'));
  await tester.pumpAndSettle();
  await scrollToS7Section(tester, _key('launch-trade-sign'));
  await tester.tap(_key('launch-trade-sign'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('确认签名'));
  await tester.pumpAndSettle();
  expect(gateway.reports, <String>['$s83cIntentId:$s83cTxHash']);
  await tester.tap(find.text('关闭'));
  await tester.pumpAndSettle();
  return gateway;
}

Future<void> _tick(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  group('S83b7c · the graduated decoder', () {
    test('the old unavailable response still decodes (both baselines)', () {
      for (final name in <String>['overview-pending', 'overview-confirmed']) {
        final overview = DioLoopV2LaunchApi.decodeOverview(_baseline(name));
        final graduated = overview.graduated;
        expect(graduated, isA<LaunchGraduatedUnavailable>());
        expect(
          (graduated as LaunchGraduatedUnavailable).fact.reasonCode,
          'LAUNCH_CONTRACT_BASELINE_PENDING',
        );
      }
    });

    test('unavailable carries any reason code, including the new one', () {
      for (final code in <String>[
        'LAUNCH_ONCHAIN_STATE_READ_FAILED',
        'LAUNCH_ONCHAIN_STATE_NOT_INDEXED',
        'LAUNCH_CONTRACT_CODE_MISSING',
        'LAUNCH_SOMETHING_NEW_LATER',
      ]) {
        final overview = DioLoopV2LaunchApi.decodeOverview(
          _overviewWith(<String, Object?>{
            'status': 'unavailable',
            'reasonCode': code,
          }),
        );
        expect(
          (overview.graduated as LaunchGraduatedUnavailable).fact.reasonCode,
          code,
        );
      }
    });

    test('available with rows decodes them as LaunchSummary', () {
      final overview = DioLoopV2LaunchApi.decodeOverview(
        _overviewWith(
          _available(<Map<String, Object?>>[
            _graduatedRow(1),
            _graduatedRow(2, liquidity: 'COMPLETED'),
          ]),
        ),
      );
      final graduated = overview.graduated as LaunchGraduatedAvailable;
      expect(graduated.indexedBlockNumber, '950');
      expect(graduated.launches.map((launch) => launch.launchId), <String>[
        _uuid(1),
        _uuid(2),
      ]);
      final chain = graduated.launches.first.onChainState;
      expect(chain, isA<LaunchOnChainAvailable>());
      expect(
        (chain as LaunchOnChainAvailable).liquidityState,
        LaunchLiquidityState.lpLocked,
      );
    });

    test('available and empty is a real empty list', () {
      final overview = DioLoopV2LaunchApi.decodeOverview(
        _overviewWith(_available(const <Map<String, Object?>>[])),
      );
      final graduated = overview.graduated as LaunchGraduatedAvailable;
      expect(graduated.launches, isEmpty);
    });

    test('50 rows decode; 51 refuse the overview', () {
      final fifty = DioLoopV2LaunchApi.decodeOverview(
        _overviewWith(
          _available(<Map<String, Object?>>[
            for (var i = 1; i <= 50; i += 1) _graduatedRow(i),
          ]),
        ),
      );
      expect(
        (fifty.graduated as LaunchGraduatedAvailable).launches,
        hasLength(LaunchGraduatedAvailable.maximum),
      );
      expect(
        () => DioLoopV2LaunchApi.decodeOverview(
          _overviewWith(
            _available(<Map<String, Object?>>[
              for (var i = 1; i <= 51; i += 1) _graduatedRow(i),
            ]),
          ),
        ),
        _invalid(),
      );
    });

    test('malformed available shapes refuse the overview', () {
      final bodies = <Object?>[
        // no indexedBlockNumber
        <String, Object?>{'status': 'available', 'launches': <Object?>[]},
        // unknown key
        <String, Object?>{
          ..._available(const <Map<String, Object?>>[]),
          'reasonCode': null,
        },
        // block number is not a decimal string
        <String, Object?>{
          ..._available(const <Map<String, Object?>>[]),
          'indexedBlockNumber': 950,
        },
        // duplicate launch
        _available(<Map<String, Object?>>[_graduatedRow(1), _graduatedRow(1)]),
        // V3_LIVE is not graduated (03 §8.3)
        _available(<Map<String, Object?>>[
          _graduatedRow(1, liquidity: 'V3_LIVE'),
        ]),
        // no chain reading
        _available(<Map<String, Object?>>[
          _graduatedRow(1, source: 'unavailable'),
        ]),
        // a third status
        <String, Object?>{'status': 'pending', 'reasonCode': 'X'},
        null,
      ];
      for (final body in bodies) {
        expect(
          () => DioLoopV2LaunchApi.decodeOverview(_overviewWith(body)),
          _invalid(),
          reason: '$body',
        );
      }
    });
  });

  group('S83b7c · the 已毕业 card', () {
    testWidgets('available with rows lists them and opens launch-detail', (
      tester,
    ) async {
      final opened = <String>[];
      await _pumpLaunch(
        tester,
        LaunchGraduatedAvailable(
          launches: <LaunchSummary>[_summary(1), _summary(2)],
          indexedBlockNumber: '950',
        ),
        onOpenLaunch: opened.add,
      );
      final list = _key('launch-graduated-list');
      await scrollToS7Section(tester, list);
      expect(list, findsOneWidget);
      expect(_key('launch-unavailable-已毕业项目'), findsNothing);
      expect(_key('launch-graduated-empty'), findsNothing);
      final first = _key('launch-graduated-row-${_uuid(1)}');
      expect(first, findsOneWidget);
      expect(_key('launch-graduated-row-${_uuid(2)}'), findsOneWidget);
      // Same row as the catalogue: the chain's own sale-state sentence.
      expect(
        tester.widget<LoopRecordRow>(first).subtitle,
        contains('MCAT · 销售成功'),
      );
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(opened, <String>[_uuid(1)]);
    });

    testWidgets('available and empty says nothing has graduated yet', (
      tester,
    ) async {
      await _pumpLaunch(
        tester,
        const LaunchGraduatedAvailable(
          launches: <LaunchSummary>[],
          indexedBlockNumber: '950',
        ),
      );
      final empty = _key('launch-graduated-empty');
      await scrollToS7Section(tester, empty);
      expect(
        find.descendant(of: empty, matching: find.text('还没有已毕业的项目')),
        findsOneWidget,
      );
      expect(_key('launch-unavailable-已毕业项目'), findsNothing);
      expect(
        find.descendant(of: empty, matching: find.textContaining('读不到')),
        findsNothing,
      );
    });

    testWidgets('READ_FAILED says the list cannot be read right now', (
      tester,
    ) async {
      await _pumpLaunch(
        tester,
        const LaunchGraduatedUnavailable(
          LaunchUnavailable('LAUNCH_ONCHAIN_STATE_READ_FAILED'),
        ),
        evidenceConfirmed: true,
      );
      final card = _key('launch-unavailable-已毕业项目');
      await scrollToS7Section(tester, card);
      expect(
        find.descendant(of: card, matching: find.text('已毕业名单暂时读不到')),
        findsOneWidget,
      );
      expect(_key('launch-graduated-list'), findsNothing);
    });

    testWidgets('BASELINE_PENDING keeps the 0097 evidence override', (
      tester,
    ) async {
      await _pumpLaunch(
        tester,
        const LaunchGraduatedUnavailable(
          LaunchUnavailable('LAUNCH_CONTRACT_BASELINE_PENDING'),
        ),
        evidenceConfirmed: true,
      );
      final card = _key('launch-unavailable-已毕业项目');
      await scrollToS7Section(tester, card);
      expect(
        find.descendant(of: card, matching: find.text('已毕业名单还没有开放读取')),
        findsOneWidget,
      );
    });

    test('the reason table', () {
      expect(
        launchGraduatedReasonText(
          'LAUNCH_ONCHAIN_STATE_READ_FAILED',
          contractLive: false,
        ),
        '已毕业名单暂时读不到',
      );
      expect(
        launchGraduatedReasonText(
          'LAUNCH_CONTRACT_BASELINE_PENDING',
          contractLive: false,
        ),
        launchReasonCodeText('LAUNCH_CONTRACT_BASELINE_PENDING'),
      );
      expect(
        launchGraduatedReasonText(
          'LAUNCH_ONCHAIN_STATE_NOT_INDEXED',
          contractLive: true,
        ),
        contains('已毕业名单暂时读不到'),
      );
      expect(
        launchGraduatedReasonText(
          'LAUNCH_CONTRACT_CODE_MISSING',
          contractLive: true,
        ),
        launchReasonCodeText('LAUNCH_CONTRACT_CODE_MISSING'),
      );
    });
  });

  group('S92b2 · a purchase is read back until it settles', () {
    testWidgets('submitted → confirmed: result, re-read, a new purchase', (
      tester,
    ) async {
      final gateway = await _signPurchase(
        tester,
        reads: <LaunchPurchaseIntent>[
          _read(LaunchIntentState.submitted),
          _read(LaunchIntentState.confirmed),
        ],
      );
      final holdersBefore = gateway.holdersReadCount;
      final idsBefore = gateway.requestedLaunchIds.length;
      expect(
        tester.widget<LoopNotice>(_key('launch-trade-locked')).title,
        '已广播 · 已提交，等待链上索引',
      );

      await _tick(tester);
      expect(gateway.intentReadCount, 1);
      expect(_key('launch-trade-locked'), findsOneWidget);
      await _tick(tester);
      expect(gateway.intentReadCount, 2);

      final state = _key('launch-trade-state-confirmed');
      await scrollToS7Section(tester, state);
      expect(tester.widget<LoopNotice>(state).title, '认购已确认');
      expect(_key('launch-trade-locked'), findsNothing);
      // Settled: detail, position and records are re-read.
      expect(gateway.holdersReadCount, greaterThan(holdersBefore));
      expect(gateway.requestedLaunchIds.length, greaterThan(idsBefore + 1));
      // Nothing is read again after a settled state.
      await _tick(tester);
      await _tick(tester);
      expect(gateway.intentReadCount, 2);

      // The settled attempt can be dismissed so a new purchase starts.
      final done = _key('launch-trade-settled-done');
      await scrollToS7Section(tester, done);
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(_key('launch-trade-review'), findsNothing);
      expect(_key('launch-trade-in-flight'), findsNothing);
    });

    testWidgets('submitted → expired: says so and still re-reads', (
      tester,
    ) async {
      final gateway = await _signPurchase(
        tester,
        reads: <LaunchPurchaseIntent>[_read(LaunchIntentState.expired)],
      );
      final holdersBefore = gateway.holdersReadCount;
      await _tick(tester);
      expect(gateway.intentReadCount, 1);
      final state = _key('launch-trade-state-expired');
      await scrollToS7Section(tester, state);
      final notice = tester.widget<LoopNotice>(state);
      expect(notice.title, '未上链，可重新发起');
      expect(notice.body, contains('晚到的交易仍可能成功'));
      expect(find.textContaining('认购已确认'), findsNothing);
      // An expired intent may have landed late (S92a.6).
      expect(gateway.holdersReadCount, greaterThan(holdersBefore));
      await _tick(tester);
      expect(gateway.intentReadCount, 1);
    });

    testWidgets('72 reads without an answer stop and offer a re-read', (
      tester,
    ) async {
      final gateway = await _signPurchase(
        tester,
        reads: <LaunchPurchaseIntent>[_read(LaunchIntentState.submitted)],
      );
      for (var i = 0; i < launchIntentMaxPolls; i += 1) {
        await tester.pump(const Duration(seconds: 1));
      }
      await tester.pumpAndSettle();
      expect(gateway.intentReadCount, launchIntentMaxPolls);
      await _tick(tester);
      expect(gateway.intentReadCount, launchIntentMaxPolls);
      final resume = _key('launch-trade-poll-resume');
      await scrollToS7Section(tester, resume);
      expect(
        tester.widget<LoopNotice>(_key('launch-trade-locked')).body,
        contains('可以稍后重新查询'),
      );
      await tester.tap(resume);
      await tester.pumpAndSettle();
      await _tick(tester);
      expect(gateway.intentReadCount, launchIntentMaxPolls + 1);
    });
  });
}
