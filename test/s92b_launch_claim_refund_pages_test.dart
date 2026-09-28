import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_settlement.dart';
import 'package:loop_mobile/features/launch/launch_signing.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s83c_fixtures.dart';

/// Decision 0103 · claim and refund on `launch-detail`, the END step's
/// badge, and 我的参与记录 with `settlements`.
///
/// Every value is 测试专用 (`support/s83c_fixtures.dart` and the helpers
/// below, written from `frontend-v2-launch-api.md` §S92a).

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

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const _claimable = '2500000000000000000000';
const _refundable = '100000000000000000000';

LaunchPosition _position({
  String cumulative = '100000000000000000000',
  String purchased = '10000000000000000000000',
  String entitled = '10000000000000000000000',
  String claimable = '0',
  String claimed = '0',
  String refundable = '0',
  String refunded = '0',
  String block = '45000000',
}) => LaunchPosition(
  walletId: s7WalletId,
  cumulativeUsd1: cumulative,
  purchasedTokens: purchased,
  entitledTokens: entitled,
  claimableTokens: claimable,
  claimedTokens: claimed,
  refundableUsd1: refundable,
  refundedUsd1: refunded,
  snapshotBlockNumber: block,
  snapshotBlockHash: s83cBlockHash,
);

LaunchHolders _holders(LaunchPosition position) {
  final base = s83cHolders();
  return LaunchHolders(
    launchId: base.launchId,
    holders: base.holders,
    myPosition: LaunchReadingAvailable<LaunchPosition>(position),
    walletCap: base.walletCap,
  );
}

LaunchOnChainAvailable _vesting({
  LaunchEntitlementState entitlement = LaunchEntitlementState.vesting,
  LaunchOperationalState operational = LaunchOperationalState.active,
}) => s83cOnChain(
  sale: LaunchSaleState.succeeded,
  entitlement: entitlement,
  liquidity: LaunchLiquidityState.lpLocked,
  operational: operational,
);

LaunchOnChainAvailable _refunding({
  LaunchSaleState sale = LaunchSaleState.failed,
  LaunchEntitlementState entitlement = LaunchEntitlementState.refunding,
  LaunchOperationalState operational = LaunchOperationalState.active,
}) =>
    s83cOnChain(sale: sale, entitlement: entitlement, operational: operational);

String _data(String selector) =>
    '$selector${7.toRadixString(16).padLeft(64, '0')}';

LaunchPurchaseIntent _settlementIntent(
  LaunchIntentKind kind, {
  LaunchIntentState state = LaunchIntentState.awaitingSignature,
  String? transactionHash,
}) => LaunchPurchaseIntent(
  launchIntentId: s83cIntentId,
  kind: kind,
  state: state,
  launchId: s7LaunchId,
  projectId: s7ProjectId,
  walletId: s7WalletId,
  roundId: null,
  roundIndex: null,
  chainId: 'eip155:56',
  contractAddress: s83cContract,
  quoteAssetId: 'eip155:56:$s83cUsd1',
  usd1Amount: '0',
  expectedTokenAmount: kind == LaunchIntentKind.claim ? _claimable : '0',
  minTokenAmount: '0',
  walletCumulativeUsd1: '100000000000000000000',
  deadline: DateTime.utc(2026, 9, 22, 14, 5),
  eligibilityProof: const <String>[],
  configVersion: s83cConfigVersion,
  stateTupleDigest: s83cDigest,
  snapshotBlockNumber: '45000000',
  snapshotBlockHash: s83cBlockHash,
  payloadDigest: 'ab' * 32,
  unsignedTransaction: LaunchUnsignedTransaction(
    chainId: 56,
    to: s83cContract,
    data: _data(kind.selector),
    value: '0x0',
  ),
  expiresAt: DateTime.utc(2026, 9, 22, 14, 5),
  createdAt: DateTime.utc(2026, 9, 22, 14),
  saleId: '7',
  claimableTokens: kind == LaunchIntentKind.claim ? _claimable : null,
  refundableUsd1: kind == LaunchIntentKind.claimRefund ? _refundable : null,
  transactionHash: transactionHash,
  signing: LaunchIntentSigning(
    mode: 'device_eth_send_transaction',
    allowed: state == LaunchIntentState.awaitingSignature,
    reasonCode: null,
  ),
);

Future<void> _pumpDetail(
  WidgetTester tester, {
  required FakeLaunchGateway gateway,
  _RecordingWallet? wallet,
  bool evidencePending = false,
}) => pumpS7Page(
  tester,
  LaunchDetailScreen(launchId: s7LaunchId, clock: s83cNow),
  launch: gateway,
  wallet: FakeWalletDirectory(
    activeWalletId: s7WalletId,
    wallets: [s83cWallet()],
  ),
  meta: s7MetaSnapshot(launchEvidencePending: evidencePending),
  overrides: [
    if (wallet != null) walletSigningGatewayProvider.overrideWithValue(wallet),
    launchSettlementPollIntervalProvider.overrideWithValue(
      const Duration(seconds: 1),
    ),
  ],
);

FakeLaunchGateway _gateway({
  required LaunchOnChainAvailable onChain,
  required LaunchPosition position,
  Map<LaunchIntentKind, LaunchPurchasePrepared>? prepared,
  LaunchPurchaseIntent? reported,
  List<LaunchPurchaseIntent>? reads,
  String? refusal,
  S7Answer<LaunchHolders>? holders,
}) => FakeLaunchGateway(
  detail: S7Answer<LaunchDetail>(value: s83cDetail(onChain: onChain)),
  holders: holders ?? S7Answer<LaunchHolders>(value: _holders(position)),
  history: S7Answer<LaunchHistory>(value: s83cHistory()),
  eligibility: S7Answer<LaunchEligibility>(value: s83cEligibility()),
  settlementPrepared: prepared,
  settlementFailure: LaunchFailureKind.stale,
  settlementReasonCode: refusal,
  reported: reported,
  intentReads: reads,
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    scrollToS7Section(tester, finder);

void main() {
  group('the button decision table (0103)', () {
    LaunchSettlementView? view(
      LaunchOnChainAvailable onChain, [
      LaunchPosition? position,
    ]) => launchSettlementView(
      onChain: onChain,
      position: position == null
          ? null
          : LaunchReadingAvailable<LaunchPosition>(position),
    );

    test('scheduled and live belong to the purchase', () {
      expect(
        view(s83cOnChain(sale: LaunchSaleState.live), _position()),
        isNull,
      );
      expect(
        view(s83cOnChain(sale: LaunchSaleState.scheduled), _position()),
        isNull,
      );
    });

    test('unreadable axes draw nothing', () {
      expect(
        launchSettlementView(
          onChain: const LaunchOnChainUnavailable('LAUNCH_SALE_NOT_REGISTERED'),
          position: null,
        ),
        isNull,
      );
    });

    test('ENDED waits for finalize whatever the position', () {
      final ended = s83cOnChain(sale: LaunchSaleState.ended);
      expect(view(ended)!.stage, LaunchSettlementStage.awaitingFinalize);
      expect(
        view(ended, _position())!.stage,
        LaunchSettlementStage.awaitingFinalize,
      );
      expect(view(ended)!.kind, isNull);
    });

    test('SUCCEEDED + FROZEN waits for TGE', () {
      expect(
        view(
          _vesting(entitlement: LaunchEntitlementState.frozen),
          _position(),
        )!.stage,
        LaunchSettlementStage.awaitingTge,
      );
    });

    test('VESTING with claimable is a claim', () {
      final result = view(_vesting(), _position(claimable: _claimable))!;
      expect(result.stage, LaunchSettlementStage.claim);
      expect(result.kind, LaunchIntentKind.claim);
      expect(result.amount, _claimable);
      expect(launchSettlementActionLabel(result), '领取 2,500 代币');
    });

    test('COMPLETED can still claim what is left', () {
      final result = view(
        _vesting(entitlement: LaunchEntitlementState.completed),
        _position(claimable: _claimable, claimed: '1000000000000000000'),
      )!;
      expect(result.stage, LaunchSettlementStage.claim);
      expect(result.kind, LaunchIntentKind.claim);
    });

    test('nothing claimable: not yet, partly claimed, all claimed', () {
      expect(
        view(_vesting(), _position())!.stage,
        LaunchSettlementStage.claimNothingYet,
      );
      expect(
        view(_vesting(), _position(claimed: _claimable))!.stage,
        LaunchSettlementStage.claimedSoFar,
      );
      expect(
        view(
          _vesting(entitlement: LaunchEntitlementState.completed),
          _position(claimed: _claimable),
        )!.stage,
        LaunchSettlementStage.claimedAll,
      );
    });

    test('FAILED / CANCELLED + REFUNDING with refundable is a refund', () {
      for (final sale in <LaunchSaleState>[
        LaunchSaleState.failed,
        LaunchSaleState.cancelled,
      ]) {
        final result = view(
          _refunding(sale: sale),
          _position(refundable: _refundable),
        )!;
        expect(result.stage, LaunchSettlementStage.refund);
        expect(result.kind, LaunchIntentKind.claimRefund);
        expect(launchSettlementActionLabel(result), '申请退款 100 USD1');
      }
    });

    test('refunded all, window closed, liability not frozen yet', () {
      expect(
        view(_refunding(), _position(refunded: _refundable))!.stage,
        LaunchSettlementStage.refundedAll,
      );
      expect(
        view(
          _refunding(entitlement: LaunchEntitlementState.refunded),
          _position(refundable: _refundable),
        )!.stage,
        LaunchSettlementStage.refundClosed,
      );
      expect(
        view(
          _refunding(entitlement: LaunchEntitlementState.none),
          _position(),
        )!.stage,
        LaunchSettlementStage.refundPending,
      );
    });

    test('a pause keeps the stage and marks it', () {
      final claim = view(
        _vesting(operational: LaunchOperationalState.paused),
        _position(claimable: _claimable),
      )!;
      expect(claim.stage, LaunchSettlementStage.claim);
      expect(claim.paused, isTrue);
      final refund = view(
        _refunding(operational: LaunchOperationalState.paused),
        _position(refundable: _refundable),
      )!;
      expect(refund.stage, LaunchSettlementStage.refund);
      expect(refund.paused, isTrue);
    });

    test('a wallet that never took part sees nothing', () {
      final none = _position(cumulative: '0', purchased: '0', entitled: '0');
      expect(view(_vesting(), none), isNull);
      expect(view(_refunding(), none), isNull);
    });

    test('an unreadable position is said, never guessed', () {
      expect(view(_vesting())!.stage, LaunchSettlementStage.positionReading);
      expect(
        launchSettlementView(
          onChain: _vesting(),
          position: const LaunchReadingUnavailable<LaunchPosition>(
            LaunchUnavailable('LAUNCH_WALLET_NOT_FOUND'),
          ),
        )!.stage,
        LaunchSettlementStage.positionUnread,
      );
      expect(
        launchSettlementView(
          onChain: _vesting(),
          position: null,
          positionFailed: true,
        )!.stage,
        LaunchSettlementStage.positionUnread,
      );
    });
  });

  group('launch-detail · claim', () {
    testWidgets('prepare → sign → report → confirmed', (tester) async {
      final wallet = _RecordingWallet(
        WalletHandoffResult(
          accepted: true,
          code: 'wallet_accepted',
          value: s83cTxHash,
        ),
      );
      final prepared = LaunchPurchasePrepared(
        intent: _settlementIntent(LaunchIntentKind.claim),
      );
      final submitted = _settlementIntent(
        LaunchIntentKind.claim,
        state: LaunchIntentState.submitted,
        transactionHash: s83cTxHash,
      );
      final gateway = _gateway(
        onChain: _vesting(),
        position: _position(claimable: _claimable),
        prepared: {LaunchIntentKind.claim: prepared},
        reported: submitted,
        reads: [
          submitted,
          _settlementIntent(
            LaunchIntentKind.claim,
            state: LaunchIntentState.confirmed,
            transactionHash: s83cTxHash,
          ),
        ],
      );
      await _pumpDetail(tester, gateway: gateway, wallet: wallet);

      await _scrollTo(tester, _key('launch-settlement-claim'));
      final button = tester.widget<LoopButton>(_key('launch-settlement-claim'));
      expect(button.label, '领取 2,500 代币');
      expect(button.onPressed, isNotNull);
      expect(_key('launch-settlement-claimable'), findsOneWidget);

      await tester.tap(_key('launch-settlement-claim'));
      await tester.pumpAndSettle();
      expect(gateway.settlementIntents, <String>[
        'claim:$s7LaunchId:$s7WalletId',
      ]);
      expect(_key('launch-sign-sheet'), findsOneWidget);
      final sheet = tester.widget<LoopSignSheet>(_key('launch-sign-sheet'));
      expect(sheet.title, '确认领取');
      final facts = {for (final fact in sheet.facts) fact.label: fact.value};
      expect(facts['操作'], '领取 2,500 代币到当前钱包');
      expect(facts['资金'], '合约执行，LOOP 不经手资金');
      expect(facts['本次可领取'], '2,500 MCAT');

      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      final handed = wallet.handed.single;
      expect(handed.kind, IntentKind.launchPurchase);
      expect(handed.title, '确认领取');
      final payload = handed.payload! as DeviceTransactionPayload;
      expect(payload.transaction['data'], _data('0x379607f5'));
      expect(gateway.reports, <String>['$s83cIntentId:$s83cTxHash']);

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await _scrollTo(tester, _key('launch-settlement-state-submitted'));
      expect(_key('launch-settlement-state-submitted'), findsOneWidget);
      expect(find.text('已广播，等待链上确认'), findsOneWidget);
      // Locked while the server has not settled it.
      expect(
        tester.widget<LoopButton>(_key('launch-settlement-claim')).onPressed,
        isNull,
      );

      final holderReads = gateway.requestedLaunchIds.length;
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(gateway.intentReadCount, 2);
      expect(_key('launch-settlement-state-confirmed'), findsOneWidget);
      expect(find.text('已领取'), findsWidgets);
      // A confirmed claim re-reads the detail, the position and the records.
      expect(gateway.requestedLaunchIds.length, greaterThan(holderReads));
    });

    testWidgets('a paused contract keeps the button closed and says so', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        gateway: _gateway(
          onChain: _vesting(operational: LaunchOperationalState.paused),
          position: _position(claimable: _claimable),
        ),
      );
      await _scrollTo(tester, _key('launch-settlement-paused'));
      expect(
        tester.widget<LoopButton>(_key('launch-settlement-claim')).onPressed,
        isNull,
      );
      expect(find.text('合约已暂停'), findsOneWidget);
    });

    testWidgets('pending evidence keeps the button closed', (tester) async {
      await _pumpDetail(
        tester,
        evidencePending: true,
        gateway: _gateway(
          onChain: _vesting(),
          position: _position(claimable: _claimable),
        ),
      );
      await _scrollTo(tester, _key('launch-settlement-evidence'));
      expect(
        tester.widget<LoopButton>(_key('launch-settlement-claim')).onPressed,
        isNull,
      );
    });

    testWidgets('all claimed is a finished record row', (tester) async {
      await _pumpDetail(
        tester,
        gateway: _gateway(
          onChain: _vesting(entitlement: LaunchEntitlementState.completed),
          position: _position(claimed: _claimable),
        ),
      );
      await _scrollTo(tester, _key('launch-settlement-claimed-all'));
      expect(find.text('已全部领取'), findsOneWidget);
      expect(_key('launch-settlement-claim'), findsNothing);
    });
  });

  group('launch-detail · refund', () {
    testWidgets('prepare → sign → report → confirmed', (tester) async {
      final wallet = _RecordingWallet(
        WalletHandoffResult(
          accepted: true,
          code: 'wallet_accepted',
          value: s83cTxHash,
        ),
      );
      final submitted = _settlementIntent(
        LaunchIntentKind.claimRefund,
        state: LaunchIntentState.submitted,
        transactionHash: s83cTxHash,
      );
      final gateway = _gateway(
        onChain: _refunding(sale: LaunchSaleState.cancelled),
        position: _position(refundable: _refundable),
        prepared: {
          LaunchIntentKind.claimRefund: LaunchPurchasePrepared(
            intent: _settlementIntent(LaunchIntentKind.claimRefund),
          ),
        },
        reported: submitted,
        reads: [
          _settlementIntent(
            LaunchIntentKind.claimRefund,
            state: LaunchIntentState.confirmed,
            transactionHash: s83cTxHash,
          ),
        ],
      );
      await _pumpDetail(tester, gateway: gateway, wallet: wallet);

      await _scrollTo(tester, _key('launch-settlement-refund'));
      expect(
        tester.widget<LoopButton>(_key('launch-settlement-refund')).label,
        '申请退款 100 USD1',
      );
      await tester.tap(_key('launch-settlement-refund'));
      await tester.pumpAndSettle();
      expect(gateway.settlementIntents, <String>[
        'claimRefund:$s7LaunchId:$s7WalletId',
      ]);
      final sheet = tester.widget<LoopSignSheet>(_key('launch-sign-sheet'));
      expect(sheet.title, '确认退款');
      final facts = {for (final fact in sheet.facts) fact.label: fact.value};
      expect(facts['操作'], '退回 100 USD1 到当前钱包');
      expect(facts['资金'], '合约执行，LOOP 不经手资金');

      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      final payload = wallet.handed.single.payload! as DeviceTransactionPayload;
      expect(payload.transaction['data'], _data('0x5b7baf64'));
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await _scrollTo(tester, _key('launch-settlement-state-confirmed'));
      expect(find.text('已退款'), findsWidgets);
    });

    testWidgets('a reverted refund says gas only and opens a new attempt', (
      tester,
    ) async {
      final wallet = _RecordingWallet(
        WalletHandoffResult(
          accepted: true,
          code: 'wallet_accepted',
          value: s83cTxHash,
        ),
      );
      final submitted = _settlementIntent(
        LaunchIntentKind.claimRefund,
        state: LaunchIntentState.submitted,
        transactionHash: s83cTxHash,
      );
      await _pumpDetail(
        tester,
        wallet: wallet,
        gateway: _gateway(
          onChain: _refunding(),
          position: _position(refundable: _refundable),
          prepared: {
            LaunchIntentKind.claimRefund: LaunchPurchasePrepared(
              intent: _settlementIntent(LaunchIntentKind.claimRefund),
            ),
          },
          reported: submitted,
          reads: [
            _settlementIntent(
              LaunchIntentKind.claimRefund,
              state: LaunchIntentState.reverted,
              transactionHash: s83cTxHash,
            ),
          ],
        ),
      );
      await _scrollTo(tester, _key('launch-settlement-refund'));
      await tester.tap(_key('launch-settlement-refund'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await _scrollTo(tester, _key('launch-settlement-state-reverted'));
      expect(find.text('交易失败（仅消耗 gas）'), findsOneWidget);
      expect(
        tester.widget<LoopButton>(_key('launch-settlement-refund')).onPressed,
        isNotNull,
      );
    });
  });

  group('the six refusals: copy and button state', () {
    final cases =
        <
          ({
            String code,
            LaunchIntentKind kind,
            String title,
            String fragment,
            bool hidden,
          })
        >[
          (
            code: 'LAUNCH_CLAIM_NOT_OPEN',
            kind: LaunchIntentKind.claim,
            title: '尚未开放领取',
            fragment: '开放后这里会出现领取按钮',
            hidden: false,
          ),
          (
            code: 'LAUNCH_REFUND_NOT_OPEN',
            kind: LaunchIntentKind.claimRefund,
            title: '当前不可退款',
            fragment: '退款窗口开放时才能退款',
            hidden: false,
          ),
          (
            code: 'LAUNCH_SALE_PAUSED',
            kind: LaunchIntentKind.claim,
            title: '合约已暂停',
            fragment: '请稍后再试',
            hidden: false,
          ),
          (
            code: 'LAUNCH_NOT_PARTICIPANT',
            kind: LaunchIntentKind.claimRefund,
            title: '这个钱包没有参与',
            fragment: '请在钱包中切换后再来',
            hidden: true,
          ),
          (
            code: 'LAUNCH_NOTHING_TO_CLAIM',
            kind: LaunchIntentKind.claim,
            title: '暂无可领取',
            fragment: '下一次释放后再来',
            hidden: false,
          ),
          (
            code: 'LAUNCH_NOTHING_TO_REFUND',
            kind: LaunchIntentKind.claimRefund,
            title: '已退款',
            fragment: '已经全部退回',
            hidden: false,
          ),
        ];
    for (final item in cases) {
      testWidgets(item.code, (tester) async {
        final claim = item.kind == LaunchIntentKind.claim;
        final gateway = _gateway(
          onChain: claim ? _vesting() : _refunding(),
          position: claim
              ? _position(claimable: _claimable)
              : _position(refundable: _refundable),
          refusal: item.code,
        );
        await _pumpDetail(tester, gateway: gateway);
        final buttonKey = claim
            ? 'launch-settlement-claim'
            : 'launch-settlement-refund';
        await _scrollTo(tester, _key(buttonKey));
        final before = gateway.requestedLaunchIds.length;
        await tester.tap(_key(buttonKey));
        await tester.pumpAndSettle();

        // Nothing was prepared, so no sheet and no wallet.
        expect(_key('launch-sign-sheet'), findsNothing);
        final notice = _key('launch-settlement-refusal-${item.code}');
        await _scrollTo(tester, notice);
        expect(
          find.descendant(of: notice, matching: find.text(item.title)),
          findsOneWidget,
        );
        expect(find.textContaining(item.fragment), findsOneWidget);
        // The page re-read the detail, the position and the records.
        expect(gateway.requestedLaunchIds.length, greaterThan(before));
        // The server's answer stands over the same blocks.
        if (item.hidden) {
          expect(_key(buttonKey), findsNothing);
        } else {
          expect(tester.widget<LoopButton>(_key(buttonKey)).onPressed, isNull);
        }
      });
    }

    testWidgets('a newer position block re-opens the action', (tester) async {
      final gateway = FakeLaunchGateway(
        detail: S7Answer<LaunchDetail>(value: s83cDetail(onChain: _vesting())),
        holdersSequence: <LaunchHolders>[
          _holders(_position(claimable: _claimable)),
          _holders(_position(claimable: _claimable, block: '45000009')),
        ],
        history: S7Answer<LaunchHistory>(value: s83cHistory()),
        eligibility: S7Answer<LaunchEligibility>(value: s83cEligibility()),
        settlementFailure: LaunchFailureKind.stale,
        settlementReasonCode: 'LAUNCH_SALE_PAUSED',
      );
      await _pumpDetail(tester, gateway: gateway);
      await _scrollTo(tester, _key('launch-settlement-claim'));
      await tester.tap(_key('launch-settlement-claim'));
      await tester.pumpAndSettle();
      // The refusal is still stated, but the page now reads a newer block
      // than the one the server refused against.
      expect(gateway.holdersReadCount, greaterThan(1));
      expect(
        _key('launch-settlement-refusal-LAUNCH_SALE_PAUSED'),
        findsOneWidget,
      );
      expect(
        tester.widget<LoopButton>(_key('launch-settlement-claim')).onPressed,
        isNotNull,
      );
    });
  });

  group('launch-detail · stages without an action', () {
    testWidgets('ENDED says it waits for finalize', (tester) async {
      await _pumpDetail(
        tester,
        gateway: _gateway(
          onChain: s83cOnChain(sale: LaunchSaleState.ended),
          position: _position(),
        ),
      );
      await _scrollTo(tester, _key('launch-settlement-awaiting-finalize'));
      expect(find.text('等待最终化'), findsOneWidget);
      expect(_key('launch-settlement-claim'), findsNothing);
      expect(_key('launch-settlement-refund'), findsNothing);
    });

    testWidgets('FROZEN says it waits for TGE', (tester) async {
      await _pumpDetail(
        tester,
        gateway: _gateway(
          onChain: _vesting(entitlement: LaunchEntitlementState.frozen),
          position: _position(),
        ),
      );
      await _scrollTo(tester, _key('launch-settlement-awaiting-tge'));
      expect(find.text('等待 TGE'), findsOneWidget);
    });

    testWidgets('a live sale draws no block', (tester) async {
      await _pumpDetail(
        tester,
        gateway: _gateway(onChain: s83cOnChain(), position: _position()),
      );
      expect(_key('launch-settlement'), findsNothing);
    });

    testWidgets('the position is loading, unavailable, or failed', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        LaunchDetailScreen(launchId: s7LaunchId, clock: s83cNow),
        launch: _gateway(
          onChain: _vesting(),
          position: _position(),
          holders: S7Answer<LaunchHolders>(pending: true),
        ),
        meta: s7MetaSnapshot(launchEvidencePending: false),
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await _scrollTo(tester, _key('launch-settlement-reading'));
      expect(_key('launch-settlement-claim'), findsNothing);
    });

    for (final failure in <LaunchFailureKind>[
      LaunchFailureKind.offline,
      LaunchFailureKind.permissionDenied,
      LaunchFailureKind.unexpected,
    ]) {
      testWidgets('holders ${failure.name} is an unread position', (
        tester,
      ) async {
        await _pumpDetail(
          tester,
          gateway: _gateway(
            onChain: _vesting(),
            position: _position(),
            holders: S7Answer<LaunchHolders>(failure: failure),
          ),
        );
        await _scrollTo(tester, _key('launch-settlement-unread'));
        expect(find.text('我的份额暂时读不到'), findsOneWidget);
        expect(_key('launch-settlement-claim'), findsNothing);
      });
    }

    testWidgets('an unavailable position keeps the server reason', (
      tester,
    ) async {
      final base = s83cHolders();
      await _pumpDetail(
        tester,
        gateway: _gateway(
          onChain: _refunding(),
          position: _position(),
          holders: S7Answer<LaunchHolders>(
            value: LaunchHolders(
              launchId: base.launchId,
              holders: base.holders,
              myPosition: const LaunchReadingUnavailable<LaunchPosition>(
                LaunchUnavailable('LAUNCH_CONTRACT_READ_FAILED'),
              ),
              walletCap: base.walletCap,
            ),
          ),
        ),
      );
      await _scrollTo(tester, _key('launch-settlement-unread'));
      expect(find.textContaining('读取 Launch 合约失败'), findsOneWidget);
    });
  });

  group('发射轨道 END', () {
    test('badge and line follow the entitlement axis', () {
      expect(launchTrackEndBadge(null), '待触发');
      expect(launchTrackEndBadge(s83cOnChain()), '待触发');
      expect(launchTrackEndBadge(_vesting()), '领取中');
      expect(
        launchTrackEndBadge(
          _vesting(entitlement: LaunchEntitlementState.completed),
        ),
        '已完成',
      );
      expect(launchTrackEndBadge(_refunding()), '退款中');
      expect(
        launchTrackEndBadge(
          _vesting(entitlement: LaunchEntitlementState.frozen),
        ),
        '已毕业',
      );
      expect(launchTrackEndDetail(_vesting()), contains('已开放领取'));
      expect(launchTrackEndDetail(_refunding()), contains('申请退款'));
      expect(launchTrackEndDetail(null), '达到毕业条件后由服务端权威状态推进');
    });

    testWidgets('the END strip says 领取中 on a vesting sale', (tester) async {
      await _pumpDetail(
        tester,
        gateway: _gateway(
          onChain: _vesting(),
          position: _position(claimable: _claimable),
        ),
      );
      await _scrollTo(tester, _key('launch-track-strip-end'));
      await tester.tap(_key('launch-track-strip-end'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _key('launch-track-strip-end'),
          matching: find.text('领取中'),
        ),
        findsOneWidget,
      );
      expect(find.text('待触发'), findsNothing);
      expect(
        tester.widget<Text>(_key('launch-track-end-line')).data,
        contains('已开放领取'),
      );
    });
  });

  group('我的参与记录 · settlements', () {
    LaunchSettlementRecord settlement(
      String id,
      LaunchSettlementKind kind,
      String block, {
      LaunchConfirmationState state = LaunchConfirmationState.confirmed,
    }) => LaunchSettlementRecord(
      settlementRecordId: id,
      kind: kind,
      walletId: s7WalletId,
      assetId: 'eip155:56:$s83cProjectToken',
      amount: kind == LaunchSettlementKind.claimed ? _claimable : _refundable,
      cumulativeAmount: kind == LaunchSettlementKind.claimed
          ? _claimable
          : _refundable,
      transactionHash: s83cTxHash,
      logIndex: 0,
      blockNumber: block,
      blockHash: s83cBlockHash,
      confirmationState: state,
      observedAt: DateTime.utc(2026, 9, 25, 1),
    );

    LaunchHistory history(List<LaunchSettlementRecord>? rows) {
      final base = s83cHistory();
      return LaunchHistory(
        launchId: base.launchId,
        source: base.source,
        purchaseRecords: base.purchaseRecords,
        settlements: rows,
      );
    }

    test('purchases and settlements merge newest block first', () {
      final merged = launchHistoryTimeline(
        history(<LaunchSettlementRecord>[
          settlement(
            'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
            LaunchSettlementKind.refunded,
            '44999999',
          ),
          settlement(
            'b1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
            LaunchSettlementKind.claimed,
            '45000090',
          ),
        ]),
      );
      // Purchase at 45000050 sits between the two settlements.
      expect(
        merged.map((entry) => entry.purchase != null ? 'P' : 'S'),
        <String>['S', 'P', 'S'],
      );
      expect(merged.first.settlement!.blockNumber, '45000090');
      expect(merged.last.settlement!.blockNumber, '44999999');
    });

    testWidgets('one group with 已领取 / 已退款 badges', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchHistoryScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          history: S7Answer<LaunchHistory>(
            value: history(<LaunchSettlementRecord>[
              settlement(
                'b1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
                LaunchSettlementKind.claimed,
                '45000090',
              ),
              settlement(
                'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
                LaunchSettlementKind.refunded,
                '44999999',
                state: LaunchConfirmationState.reorged,
              ),
            ]),
          ),
        ),
        meta: s7MetaSnapshot(launchEvidencePending: false),
      );
      expect(_key('launch-history-records'), findsOneWidget);
      expect(_key('launch-history-purchases'), findsNothing);
      final claimed = _key(
        'launch-history-settlement-b1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
      );
      expect(
        find.descendant(of: claimed, matching: find.text('已领取')),
        findsOneWidget,
      );
      final reorged = _key(
        'launch-history-settlement-a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
      );
      expect(
        find.descendant(of: reorged, matching: find.text('已失效')),
        findsOneWidget,
      );
    });

    testWidgets('absent settlements keep the old 认购 group', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchHistoryScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          history: S7Answer<LaunchHistory>(value: history(null)),
        ),
        meta: s7MetaSnapshot(launchEvidencePending: false),
      );
      expect(_key('launch-history-purchases'), findsOneWidget);
      expect(_key('launch-history-records'), findsNothing);
    });

    test('the detail row counts claims and refunds', () {
      final text = launchHistoryRowText(
        LaunchResourceState<LaunchHistory>(
          mode: LaunchGatewayMode.production,
          phase: LaunchViewPhase.ready,
          value: history(<LaunchSettlementRecord>[
            settlement(
              'b1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
              LaunchSettlementKind.claimed,
              '45000090',
            ),
          ]),
        ),
      );
      expect(text, startsWith('1 笔认购 · 1 笔领取 · 最近'));
    });
  });

  test('sheet copy names the kind', () {
    expect(launchIntentTitle(LaunchIntentKind.claim), '确认领取');
    expect(launchIntentTitle(LaunchIntentKind.claimRefund), '确认退款');
    expect(launchIntentTitle(LaunchIntentKind.buy), '确认认购');
    expect(
      launchSignReasonTextFor(LaunchIntentKind.claim, 'INTENT_EXPIRED'),
      isNot(contains('报价')),
    );
    expect(
      launchReportReasonTextFor(
        LaunchIntentKind.claimRefund,
        'LAUNCH_INTENT_EXPIRED',
      ),
      contains('这笔退款已过期'),
    );
  });
}
