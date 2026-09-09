import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/approval_screens.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/swap_screens.dart';
import 'package:loop_mobile/features/wallet/tx_result_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet_intents/loop_v2_intent_codec.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';

const _draft = SendDraft(
  walletId: s5WalletId,
  assetId: s5NativeAssetId,
  symbol: 'BNB',
  recipientAddress: s6RecipientChecksum,
  amount: '0.01',
);

const _guardRequest = ApprovalGuardRequest(
  walletId: s5WalletId,
  assetId: s5UsdtAssetId,
  symbol: 'USDT',
  spenderAddress: s6SpenderChecksum,
  suggestedAmount: '5',
);

DateTime _fresh() => DateTime.utc(2026, 9, 9, 13, 35, 45);
DateTime _late() => DateTime.utc(2026, 9, 9, 14);

void main() {
  group('send', () {
    testWidgets('a closed write switch states the server reason', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        sendApprovals: LoopV2CapabilityAvailability.unavailable,
      );

      expect(
        find.byKey(const ValueKey<String>('send-capability-block')),
        findsOneWidget,
      );
      expect(find.textContaining('链上写入开关当前关闭'), findsOneWidget);
    });

    testWidgets('loading shows a skeleton and no balance', (tester) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(pending: true),
        ),
        intents: FakeWalletIntentsGateway(),
        settle: false,
      );

      expect(find.byType(LoopSkeleton), findsOneWidget);
    });

    testWidgets('a registry with no readable asset is empty, not zero', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(rows: const <LoopAssetBalanceRow>[]),
          ),
        ),
        intents: FakeWalletIntentsGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('send-assets-empty')),
        findsOneWidget,
      );
    });

    testWidgets('an offline balance read pauses the funds actions', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            failure: LoopChainFailureKind.offline,
          ),
        ),
        intents: FakeWalletIntentsGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('send-balances-state-offline')),
        findsOneWidget,
      );
    });

    testWidgets('an unreadable row cannot be selected and never shows zero', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              rows: <LoopAssetBalanceRow>[
                s5Row(
                  balance: const LoopBalanceUnavailable('BSC_RPC_UNREACHABLE'),
                ),
              ],
            ),
          ),
        ),
        intents: FakeWalletIntentsGateway(),
      );

      expect(find.text('读不到'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('the power impact is stated without inventing a number', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendAssetScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      expect(find.textContaining('具体数值没有服务端来源'), findsOneWidget);
    });
  });

  group('send-to', () {
    testWidgets('the preflight findings are shown separately', (tester) async {
      await pumpS6Page(
        tester,
        const SendRecipientScreen(draft: _draft),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          preflight: s6Preflight(
            warnings: const <String>[
              'send.recipient.firstTime',
              'send.recipient.isContract',
              'send.recipient.screeningUnavailable',
            ],
            isContract: true,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('send-recipient-check')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('send-recipient-first-time')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('send-recipient-contract')),
        findsOneWidget,
      );
      expect(find.textContaining('未配置 GoPlus 密钥'), findsOneWidget);
    });

    testWidgets('an unchecked recipient cannot continue', (tester) async {
      await pumpS6Page(
        tester,
        const SendRecipientScreen(draft: _draft),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      final next = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('send-recipient-next')),
      );
      expect(next.onPressed, isNull);
    });

    testWidgets('a failed preflight is an error, not an approval', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendRecipientScreen(draft: _draft),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          failure: LoopChainFailureKind.validationFailed,
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('send-recipient-check')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('send-recipient-preflight-error')),
        findsOneWidget,
      );
      final next = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('send-recipient-next')),
      );
      expect(next.onPressed, isNull);
    });

    testWidgets('an amount above the spendable balance is rejected', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendRecipientScreen(draft: _draft),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('send-recipient-check')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('send-amount-field')),
        '9999',
      );
      await tester.pumpAndSettle();

      expect(find.text('超过可动用余额'), findsOneWidget);
      final next = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('send-recipient-next')),
      );
      expect(next.onPressed, isNull);
    });
  });

  group('send-confirm', () {
    testWidgets('the review renders the server facts and can sign', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(prepared: s6Intent()),
      );

      expect(
        find.byKey(const ValueKey<String>('money-intent-review')),
        findsOneWidget,
      );
      expect(find.textContaining('0.0000020775 BNB'), findsOneWidget);
      final sign = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('send-confirm-sign')),
      );
      expect(sign.onPressed, isNotNull);
    });

    testWidgets('expired facts disable the confirmation', (tester) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _late),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(prepared: s6Intent()),
      );

      expect(
        find.byKey(const ValueKey<String>('send-confirm-expired')),
        findsOneWidget,
      );
      expect(find.textContaining('事实已过期'), findsWidgets);
    });

    testWidgets('a failed pre-execution can never be signed', (tester) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          prepared: s6Intent(
            state: 'prepared',
            simulationStatus: 'reverted',
            signingAllowed: false,
            signingReason: 'BSC_CALL_REVERTED',
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('send-confirm-simulation-failed')),
        findsOneWidget,
      );
      final sign = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('send-confirm-sign')),
      );
      expect(sign.onPressed, isNull);
    });

    testWidgets('an unsigned intent on the same wallet is surfaced first', (
      tester,
    ) async {
      final intents = FakeWalletIntentsGateway(
        pageItems: <LoopWalletIntent>[s6Intent(intentId: s6OtherIntentId)],
      );
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: intents,
      );

      expect(
        find.byKey(const ValueKey<String>('money-pending-intent')),
        findsOneWidget,
      );
      // Preparing a second intent would expire the first one, so nothing is
      // prepared until the owner resolves it.
      expect(intents.prepareCalls, 0);
    });

    testWidgets('an unavailable prepare fails closed with its reason', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          prepareFailure: LoopChainFailureKind.unavailable,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('send-confirm-state-unavailable')),
        findsOneWidget,
      );
    });
  });

  group('swap', () {
    testWidgets('a closed capability states the server reason', (tester) async {
      await pumpS6Page(
        tester,
        const SwapScreen(),
        wallet: FakeWalletReadGateway(),
        quotes: FakeSwapQuoteGateway(),
        privySwap: LoopV2CapabilityAvailability.unavailable,
      );

      expect(
        find.byKey(const ValueKey<String>('swap-capability-block')),
        findsOneWidget,
      );
    });

    testWidgets('pending device evidence blocks the confirmation only', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: FakeWalletReadGateway(),
        quotes: FakeSwapQuoteGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('swap-evidence-pending')),
        findsOneWidget,
      );
      expect(find.textContaining('真机证据'), findsWidgets);
    });

    testWidgets('a quote is only requested once both assets are chosen', (
      tester,
    ) async {
      final quotes = FakeSwapQuoteGateway();
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: FakeWalletReadGateway(),
        quotes: quotes,
        intents: FakeWalletIntentsGateway(),
      );

      final quoteAction = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('swap-quote-action')),
      );
      expect(quoteAction.onPressed, isNull);
      expect(quotes.quoteCalls, 0);
    });

    testWidgets('a blocked price impact is never confirmable', (tester) async {
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: _twoAssetWallet(),
        quotes: FakeSwapQuoteGateway(
          quote: s6QuoteView(
            priceImpact: s6PriceImpact(
              status: 'unavailable',
              value: null,
              decision: 'blocked',
              reasonCode: 'PRICE_IMPACT_UNAVAILABLE',
            ),
          ),
        ),
        intents: FakeWalletIntentsGateway(),
      );

      await _quote(tester);

      expect(
        find.byKey(const ValueKey<String>('swap-impact-blocked')),
        findsOneWidget,
      );
      final confirm = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('swap-confirm-action')),
      );
      expect(confirm.onPressed, isNull);
    });

    testWidgets('slippage and price impact are shown apart', (tester) async {
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: _twoAssetWallet(),
        quotes: FakeSwapQuoteGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      await _quote(tester);

      expect(find.text('滑点上限'), findsWidgets);
      expect(find.text('价格影响'), findsOneWidget);
      expect(find.textContaining('未配置（LOOP_SWAP_FEE_BPS 待决策）'), findsOneWidget);
    });

    testWidgets('an unreachable provider is an error, not an empty quote', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: _twoAssetWallet(),
        quotes: FakeSwapQuoteGateway(failure: LoopChainFailureKind.unavailable),
        intents: FakeWalletIntentsGateway(),
      );

      await _quote(tester);

      expect(
        find.byKey(const ValueKey<String>('swap-quote-error')),
        findsOneWidget,
      );
    });
  });

  group('swap-route', () {
    testWidgets('every fee line names its own source', (tester) async {
      await pumpS6Page(
        tester,
        SwapRouteScreen(quote: s6QuoteView()),
        wallet: FakeWalletReadGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('swap-route-amounts')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('swap-route-fees')),
        findsOneWidget,
      );
      expect(find.textContaining('报价来源 privy'), findsOneWidget);
      expect(find.textContaining('逐跳明细'), findsOneWidget);
    });
  });

  group('approval-guard', () {
    testWidgets('the exact allowance is the default path', (tester) async {
      final intents = FakeWalletIntentsGateway(prepared: s6ApprovalIntent());
      await pumpS6Page(
        tester,
        ApprovalGuardScreen(request: _guardRequest, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: intents,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('approval-guard-exact')),
      );
      await tester.pumpAndSettle();

      expect(intents.allowances.single, isA<LoopExactAllowanceRequest>());
      expect(
        (intents.allowances.single as LoopExactAllowanceRequest).amount,
        '5',
      );
    });

    testWidgets('the decoded call is shown before the signature', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        ApprovalGuardScreen(request: _guardRequest, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(prepared: s6ApprovalIntent()),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('approval-guard-exact')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('approval-decoded-call')),
        findsOneWidget,
      );
      expect(find.text('approve()'), findsOneWidget);
      expect(find.text('0x095ea7b3'), findsOneWidget);
    });

    testWidgets('unlimited needs its own second confirmation', (tester) async {
      final intents = FakeWalletIntentsGateway(
        prepared: s6ApprovalIntent(isUnlimited: true),
      );
      await pumpS6Page(
        tester,
        ApprovalGuardScreen(request: _guardRequest, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: intents,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('approval-guard-unlimited')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('approval-unlimited-sheet')),
        findsOneWidget,
      );
      expect(intents.allowances, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('approval-unlimited-accept')),
      );
      await tester.pumpAndSettle();

      expect(intents.allowances.single, isA<LoopUnlimitedAllowanceRequest>());
      expect(
        find.byKey(
          const ValueKey<String>('approval-guard-unlimited-confirmed'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a rejected policy states the rule, not a failure', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        ApprovalGuardScreen(request: _guardRequest, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          prepareFailure: LoopChainFailureKind.permissionDenied,
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('approval-guard-exact')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('money-policy-blocked')),
        findsOneWidget,
      );
      // A blocked action names the rule and says the limit is not adjustable
      // yet; it never offers a setting that does not exist.
      expect(find.textContaining('本步暂不可调'), findsOneWidget);
    });

    testWidgets('a closed write switch stops the guard', (tester) async {
      await pumpS6Page(
        tester,
        ApprovalGuardScreen(request: _guardRequest, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        sendApprovals: LoopV2CapabilityAvailability.unavailable,
      );

      expect(
        find.byKey(const ValueKey<String>('approval-guard-capability-block')),
        findsOneWidget,
      );
    });
  });

  group('approvals', () {
    testWidgets('a live allowance row carries its block and spender', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const ApprovalsScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(),
      );

      expect(find.text('USDT'), findsOneWidget);
      expect(find.textContaining(s6SpenderChecksum), findsOneWidget);
      expect(find.textContaining('区块 120695250'), findsOneWidget);
    });

    testWidgets('a missing indexer checkpoint is unknown, not zero', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const ApprovalsScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(
          failure: LoopChainFailureKind.indexingDelayed,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('approvals-state-unavailable')),
        findsOneWidget,
      );
      expect(find.textContaining('0 个有效授权'), findsNothing);
    });

    testWidgets('an unreadable allowance never renders as a limit', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const ApprovalsScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(
          inventory: s6Approvals(
            items: <Map<String, Object?>>[s6ApprovalRowBody(readable: false)],
          ),
        ),
      );

      expect(find.text('读不到'), findsOneWidget);
      expect(find.textContaining('额度 0'), findsNothing);
    });

    testWidgets('an unlimited row is marked and offers recovery', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const ApprovalsScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(
          inventory: s6Approvals(
            items: <Map<String, Object?>>[s6ApprovalRowBody(unlimited: true)],
            unlimitedCount: 1,
          ),
        ),
      );

      expect(find.text('无限'), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey<String>('approval-$s5UsdtAssetId-$s6Spender')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('approval-action-revoke')),
        findsOneWidget,
      );
    });

    testWidgets('an empty inventory says why a zero row is absent', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const ApprovalsScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(
          inventory: s6Approvals(
            items: const <Map<String, Object?>>[],
            activeCount: 0,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('approvals-empty')),
        findsOneWidget,
      );
      expect(find.textContaining('当前额度为 0 的授权不会列出'), findsWidgets);
    });
  });

  group('tx-result', () {
    testWidgets('a submitted intent never claims completion', (tester) async {
      await pumpS6Page(
        tester,
        const TransactionResultScreen(intentId: s6IntentId),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          reported: s6Intent(state: 'submitted'),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('tx-result-pending')),
        findsOneWidget,
      );
      expect(find.textContaining('提交成功不代表链上已完成'), findsOneWidget);
      expect(find.byType(LoopToastView), findsNothing);
    });

    testWidgets('a confirmed intent announces once', (tester) async {
      await pumpS6Page(
        tester,
        const TransactionResultScreen(intentId: s6IntentId),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          reported: LoopV2IntentCodec.intent(
            s6IntentBody(
              state: 'confirmed',
              result: <String, Object?>{
                'transactionHash': s6TxHash,
                'providerActionId': null,
                'reasonCode': null,
                'receipt': <String, Object?>{
                  'status': 'success',
                  'blockNumber': '120695300',
                  'blockHash': s5BlockHash,
                  'gasUsed': '41550',
                  'effectiveGasPrice': '50000000',
                  'confirmations': 18,
                  'observedAt': '2026-09-09T13:40:00.000Z',
                },
              },
            ),
          ),
        ),
      );

      expect(find.text('交易已确认'), findsOneWidget);
      expect(find.textContaining('0x4f2a'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
    });

    testWidgets('an unknown result is locked and only polled', (tester) async {
      final intents = FakeWalletIntentsGateway(
        reported: s6Intent(
          state: 'unknown',
          result: <String, Object?>{
            'transactionHash': null,
            'providerActionId': null,
            'reasonCode': 'PROVIDER_RESULT_AMBIGUOUS',
            'receipt': null,
          },
        ),
      );
      await pumpS6Page(
        tester,
        const TransactionResultScreen(
          intentId: s6IntentId,
          pollInterval: Duration(milliseconds: 40),
        ),
        wallet: FakeWalletReadGateway(),
        intents: intents,
        settle: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(
        find.byKey(const ValueKey<String>('tx-result-unknown-lock')),
        findsOneWidget,
      );
      expect(find.textContaining('不会重复提交'), findsOneWidget);
      expect(intents.reportCalls, 0);
      expect(intents.executeCalls, 0);
      expect(intents.intentReads, greaterThan(1));
    });

    testWidgets('a reverted intent says the fee was still spent', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const TransactionResultScreen(intentId: s6IntentId),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          reported: s6Intent(
            state: 'reverted',
            result: <String, Object?>{
              'transactionHash': s6TxHash,
              'providerActionId': null,
              'reasonCode': 'TX_REVERTED',
              'receipt': null,
            },
          ),
        ),
      );

      expect(find.textContaining('网络费已消耗'), findsOneWidget);
    });

    testWidgets('a failed read is an error, not a failed transaction', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const TransactionResultScreen(intentId: s6IntentId),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          failure: LoopChainFailureKind.unexpected,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('tx-result-state-error')),
        findsOneWidget,
      );
    });

    testWidgets('without an intent id the page is empty, not a result', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const TransactionResultScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('tx-result-empty')),
        findsOneWidget,
      );
    });
  });
  group('sign sheet', () {
    testWidgets('the sheet renders the facts it hands to the wallet', (
      tester,
    ) async {
      final intent = s6Intent();
      final wallet = RecordingSigningGateway();
      await _pumpSheet(tester, intent, wallet);

      expect(find.text('0.01 WBNB'), findsOneWidget);
      expect(find.text(s6RecipientChecksum), findsOneWidget);
      expect(find.text('预执行通过（eth_call）'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-sign-sheet-pending')),
        findsOneWidget,
      );
    });

    testWidgets('an unsignable intent opens disabled with its reason', (
      tester,
    ) async {
      await _pumpSheet(tester, s6SwapIntent(), RecordingSigningGateway());

      expect(
        find.byKey(const ValueKey<String>('loop-sign-sheet-simulationFailed')),
        findsOneWidget,
      );
      expect(find.textContaining('预执行没有返回可验证结果'), findsOneWidget);
    });

    testWidgets('one confirmation submits once and then completes', (
      tester,
    ) async {
      final intents = FakeWalletIntentsGateway(
        reported: s6Intent(state: 'submitted'),
      );
      final wallet = RecordingSigningGateway();
      await _pumpSheet(tester, s6Intent(), wallet, intents: intents);

      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('loop-sign-sheet-complete')),
        findsOneWidget,
      );
      expect(find.textContaining('成功提示不代表链上已完成'), findsOneWidget);
      expect(wallet.handoffs, hasLength(1));
      expect(intents.reportCalls, 1);
    });

    testWidgets('a locked submission never offers a second signature', (
      tester,
    ) async {
      final intents = FakeWalletIntentsGateway(
        reported: s6Intent(
          state: 'unknown',
          result: <String, Object?>{
            'transactionHash': null,
            'providerActionId': null,
            'reasonCode': 'PROVIDER_RESULT_AMBIGUOUS',
            'receipt': null,
          },
        ),
      );
      await _pumpSheet(
        tester,
        s6Intent(),
        RecordingSigningGateway(),
        intents: intents,
      );

      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();

      expect(find.textContaining('已锁定'), findsOneWidget);
      expect(find.text('确认签名'), findsNothing);
      expect(intents.reportCalls, 1);
    });
  });
  group('review findings', () {
    testWidgets('the approval inventory states its coverage start', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const ApprovalsScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(),
      );

      expect(find.textContaining('授权记录自区块 120600000 起'), findsOneWidget);
      expect(find.textContaining('更早授予的授权不会出现在这里'), findsOneWidget);
    });

    testWidgets('a closed write switch never blocks the two reads', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const ApprovalsScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(),
        sendApprovals: LoopV2CapabilityAvailability.unavailable,
        privySwap: LoopV2CapabilityAvailability.unavailable,
      );

      expect(
        find.byKey(const ValueKey<String>('approvals-capability-block')),
        findsNothing,
      );
      expect(find.text('USDT'), findsOneWidget);
    });

    testWidgets('a swap result never waits on the send capability', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const TransactionResultScreen(intentId: s6IntentId),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          reported: s6SwapIntent(state: 'submitted'),
        ),
        sendApprovals: LoopV2CapabilityAvailability.unavailable,
        privySwap: LoopV2CapabilityAvailability.unavailable,
      );

      expect(
        find.byKey(const ValueKey<String>('tx-result-capability-block')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('tx-result-pending')),
        findsOneWidget,
      );
    });

    testWidgets('the sheet cannot be dismissed while the wallet is open', (
      tester,
    ) async {
      final wallet = RecordingSigningGateway()..holdOpen = true;
      await _pumpSheet(tester, s6Intent(), wallet);

      await tester.tap(find.text('确认签名'));
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('loop-sign-sheet-signing')),
        findsOneWidget,
      );
      // A back gesture must not leave a signature in flight unwatched.
      final popped = await tester.binding.handlePopRoute();
      await tester.pump();
      expect(popped, isTrue);
      expect(
        find.byKey(const ValueKey<String>('loop-sign-sheet-signing')),
        findsOneWidget,
      );

      wallet.gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a refused report never reads as nothing submitted', (
      tester,
    ) async {
      final intents = FakeWalletIntentsGateway(
        reportFailure: LoopChainFailureKind.versionConflict,
      );
      final wallet = RecordingSigningGateway();
      await _pumpSheet(tester, s6Intent(), wallet, intents: intents);

      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('loop-sign-sheet-complete')),
        findsOneWidget,
      );
      expect(find.textContaining('可能已经上链'), findsOneWidget);
      expect(find.textContaining('没有提交任何交易'), findsNothing);
      // The confirmation is gone: signing again would risk a second broadcast.
      expect(find.text('确认签名'), findsNothing);
      expect(wallet.handoffs, hasLength(1));
    });

    testWidgets('a confirmation is announced once, not on every rebuild', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const TransactionResultScreen(
          intentId: s6IntentId,
          pollInterval: Duration(milliseconds: 30),
        ),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(reported: _confirmed()),
        settle: false,
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('交易已确认'), findsOneWidget);

      // The toast expires; further reads of the same state must not fire it
      // again.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('交易已确认'), findsNothing);
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('交易已确认'), findsNothing);
    });

    testWidgets('polling gives up after repeated failures', (tester) async {
      final intents = FakeWalletIntentsGateway(
        failure: LoopChainFailureKind.unexpected,
      );
      await pumpS6Page(
        tester,
        const TransactionResultScreen(
          intentId: s6IntentId,
          pollInterval: Duration(milliseconds: 20),
          maximumPollFailures: 2,
        ),
        wallet: FakeWalletReadGateway(),
        intents: intents,
        settle: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final reads = intents.intentReads;
      expect(reads, lessThanOrEqualTo(2));

      await tester.pump(const Duration(seconds: 5));
      expect(intents.intentReads, reads);
      expect(
        find.byKey(const ValueKey<String>('tx-result-state-error')),
        findsOneWidget,
      );
    });
  });
}

/// A confirmed intent with a receipt the result page can render.
LoopWalletIntent _confirmed() => LoopV2IntentCodec.intent(
  s6IntentBody(
    state: 'confirmed',
    result: <String, Object?>{
      'transactionHash': s6TxHash,
      'providerActionId': null,
      'reasonCode': null,
      'receipt': <String, Object?>{
        'status': 'success',
        'blockNumber': '120695300',
        'blockHash': s5BlockHash,
        'gasUsed': '41550',
        'effectiveGasPrice': '50000000',
        'confirmations': 18,
        'observedAt': '2026-09-09T13:40:00.000Z',
      },
    },
  ),
);

/// Mounts the signing exit alone so its own states can be exercised.
Future<void> _pumpSheet(
  WidgetTester tester,
  LoopWalletIntent intent,
  RecordingSigningGateway wallet, {
  FakeWalletIntentsGateway? intents,
}) async {
  await pumpS6Page(
    tester,
    Scaffold(
      body: MoneySignSheet(
        intent: intent,
        signer: MoneyActionSigner(
          intents: intents ?? FakeWalletIntentsGateway(),
          wallet: wallet,
        ),
        clock: _fresh,
      ),
    ),
    wallet: FakeWalletReadGateway(),
  );
}

/// A wallet whose registry has both a native and an ERC-20 row, so the Swap
/// page has two different assets to pick.
FakeWalletReadGateway _twoAssetWallet() => FakeWalletReadGateway(
  balances: S5Answer<LoopWalletBalances>(
    value: s5Balances(
      rows: <LoopAssetBalanceRow>[
        s5Row(),
        s5Row(assetId: s5WbnbAssetId),
      ],
    ),
  ),
);

/// Chooses both assets, types an amount and asks for the quote.
Future<void> _quote(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('swap-source-pick')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey<String>('swap-pick-$s5NativeAssetId')));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey<String>('swap-destination-pick')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey<String>('swap-pick-$s5WbnbAssetId')));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const ValueKey<String>('swap-source-amount')),
    '0.005',
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('swap-quote-action')));
  await tester.pumpAndSettle();
}
