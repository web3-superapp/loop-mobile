import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/wallet/approval_screens.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/swap_screens.dart';
import 'package:loop_mobile/features/wallet/tx_result_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';

/// Loading / Empty / Error / Offline for the six funds pages the 93-page
/// matrix still listed as thin (`send-to`, `send-confirm`, `swap`,
/// `approval-guard`, `approvals`, `tx-result`).
///
/// Offline on a funds page has **two** meanings, and 01 §9 keeps them apart:
///
/// * **before the wallet handoff** — a preflight, quote, prepare or read that
///   never reached the server signed nothing, broadcast nothing and reported
///   nothing. The step pauses (`MoneyOfflinePause` / the page's own
///   `-state-offline` block) and no prepare is spent.
/// * **after the wallet handoff** — the wallet already produced a hash or an
///   authorization signature. An offline report is therefore
///   `MoneySignStatus.reportRefused`: a **locked** outcome that keeps the
///   produced value. It is not an offline state, it never reads as "nothing
///   was submitted", and it never re-opens the confirmation.
///
/// Both halves are asserted here, so a future change that renders the second
/// half as a retryable offline pause fails this file. `X2`
/// (`s6_signing_exit_test.dart:230`) pins the same split at the signer level.

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

/// A wallet whose registry has both a native and an ERC-20 row, so Swap has
/// two different assets to pick.
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

/// Types an address into `send-to` and asks the server to check it.
Future<void> _check(WidgetTester tester, {bool settle = true}) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('send-recipient-field')),
    s6Recipient,
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('send-recipient-check')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Chooses both Swap assets and types an amount, without asking for a quote.
Future<void> _swapInputs(WidgetTester tester) async {
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
}

void main() {
  group('send-to', () {
    testWidgets('a check in flight is its own state, not a verdict', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendRecipientScreen(draft: _draft),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(preflightPending: true),
      );
      await _check(tester, settle: false);

      expect(find.text('校验中'), findsOneWidget);
      // Nothing has been decided about the address yet.
      expect(
        find.byKey(const ValueKey<String>('send-recipient-preflight-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('send-recipient-preflight-offline')),
        findsNothing,
      );
      final next = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('send-recipient-next')),
      );
      expect(next.onPressed, isNull);
    });

    testWidgets('empty does not apply: a preflight answers about one address', (
      tester,
    ) async {
      // `POST /v2/wallet-intents/send/preflight` answers about exactly one
      // address: `LoopSendPreflight` carries a `recipient` record and a
      // warning list, never a collection that could come back with no rows.
      // So "read succeeded but there is nothing" is not in this contract; an
      // un-checked address is simply not yet checked.
      await pumpS6Page(
        tester,
        const SendRecipientScreen(draft: _draft),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('send-recipient-preflight-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('send-recipient-preflight-offline')),
        findsNothing,
      );
      expect(find.text('没有匹配的地址'), findsNothing);
    });

    testWidgets('an offline check pauses the step and prepares nothing', (
      tester,
    ) async {
      final intents = FakeWalletIntentsGateway(
        failure: LoopChainFailureKind.offline,
      );
      await pumpS6Page(
        tester,
        const SendRecipientScreen(draft: _draft),
        wallet: FakeWalletReadGateway(),
        intents: intents,
      );
      await _check(tester);

      expect(
        find.byKey(const ValueKey<String>('send-recipient-preflight-offline')),
        findsOneWidget,
      );
      // Offline is not a verdict on the address.
      expect(
        find.byKey(const ValueKey<String>('send-recipient-preflight-error')),
        findsNothing,
      );
      expect(find.text('地址没有校验成功'), findsNothing);
      final next = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('send-recipient-next')),
      );
      expect(next.onPressed, isNull);
      // Nothing was prepared, so no wallet could have been opened.
      expect(intents.prepareCalls, 0);
    });
  });

  group('send-confirm', () {
    testWidgets('a prepare in flight shows the skeleton and no review', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(preparePending: true),
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('send-confirm-state-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('money-intent-review')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('send-confirm-sign')),
        findsNothing,
      );
    });

    testWidgets('empty does not apply: a prepare returns an intent or fails', (
      tester,
    ) async {
      // `POST /v2/wallet-intents/send` answers with one `LoopWalletIntent` or
      // an error; there is no "prepared nothing" case, so the state block's
      // empty arm is unreachable here.
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(prepared: s6Intent()),
      );

      expect(
        find.byKey(const ValueKey<String>('send-confirm-state-empty')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('money-intent-review')),
        findsOneWidget,
      );
    });

    testWidgets('a failed prepare is an error state with a retry', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          prepareFailure: LoopChainFailureKind.unexpected,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('send-confirm-state-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('send-confirm-state-offline')),
        findsNothing,
      );
    });

    testWidgets('an offline prepare pauses before any signature', (
      tester,
    ) async {
      final wallet = RecordingSigningGateway();
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          prepareFailure: LoopChainFailureKind.offline,
        ),
        signing: wallet,
      );

      expect(
        find.byKey(const ValueKey<String>('send-confirm-state-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('send-confirm-state-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('send-confirm-sign')),
        findsNothing,
      );
      expect(wallet.handoffs, isEmpty);
    });

    testWidgets('going offline after the handoff locks, it does not pause', (
      tester,
    ) async {
      // Past the handoff the wallet already produced a hash. An offline report
      // is `reportRefused`: the transaction may exist on chain, so the sheet
      // completes and locks instead of offering the retryable offline pause.
      final wallet = RecordingSigningGateway();
      final intents = FakeWalletIntentsGateway(
        prepared: s6Intent(),
        reportFailure: LoopChainFailureKind.offline,
      );
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: _draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: intents,
        signing: wallet,
      );

      await tester.tap(find.byKey(const ValueKey<String>('send-confirm-sign')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('loop-sign-sheet-complete')),
        findsOneWidget,
      );
      expect(find.textContaining('可能已经上链'), findsOneWidget);
      expect(find.textContaining('没有提交任何交易'), findsNothing);
      // The offline pause belongs to the pre-handoff half only.
      expect(
        find.byKey(const ValueKey<String>('send-confirm-state-offline')),
        findsNothing,
      );
      expect(find.text('确认签名'), findsNothing);
      expect(wallet.handoffs, hasLength(1));
      expect(intents.reportCalls, 1);
    });
  });

  group('swap', () {
    testWidgets('a quote in flight is its own state, not a missing quote', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: _twoAssetWallet(),
        intents: FakeWalletIntentsGateway(),
        quotes: FakeSwapQuoteGateway(pending: true),
      );
      await _swapInputs(tester);
      await tester.tap(find.byKey(const ValueKey<String>('swap-quote-action')));
      await tester.pump();

      expect(find.text('报价中'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('swap-quote-facts')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('swap-quote-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('swap-quote-offline')),
        findsNothing,
      );
    });

    testWidgets('empty does not apply: a quote is one priced route or none', (
      tester,
    ) async {
      // `POST /v2/wallet-intents/swap/quote` answers with one provider quote
      // or an error. There is no "quoted, but nothing to show" case, so the
      // page never renders an empty collection in place of a price.
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: _twoAssetWallet(),
        intents: FakeWalletIntentsGateway(),
        quotes: FakeSwapQuoteGateway(),
      );
      await _swapInputs(tester);
      await tester.tap(find.byKey(const ValueKey<String>('swap-quote-action')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('swap-quote-facts')),
        findsOneWidget,
      );
      expect(find.text('暂无报价'), findsNothing);
    });

    testWidgets('an offline quote pauses and prepares no swap', (tester) async {
      final intents = FakeWalletIntentsGateway();
      await pumpS6Page(
        tester,
        SwapScreen(clock: _fresh),
        wallet: _twoAssetWallet(),
        intents: intents,
        quotes: FakeSwapQuoteGateway(failure: LoopChainFailureKind.offline),
      );
      await _swapInputs(tester);
      await tester.tap(find.byKey(const ValueKey<String>('swap-quote-action')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('swap-quote-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('swap-quote-error')),
        findsNothing,
      );
      expect(find.text('没有取到报价'), findsNothing);
      expect(intents.prepareCalls, 0);
    });
  });

  group('approval-guard', () {
    testWidgets('a prepare in flight closes both allowance actions', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        ApprovalGuardScreen(request: _guardRequest, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(preparePending: true),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('approval-guard-exact')),
      );
      await tester.pump();

      final exact = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('approval-guard-exact')),
      );
      expect(exact.onPressed, isNull);
      expect(
        find.byKey(const ValueKey<String>('approval-guard-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('approval-guard-offline')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('approval-guard-sign')),
        findsNothing,
      );
    });

    testWidgets('empty does not apply: the guard reviews one request', (
      tester,
    ) async {
      // The page's input is the route argument (`ApprovalGuardRequest`), and
      // its output is one prepared intent. Neither side is a collection, so
      // there is no "nothing to approve" state to render.
      await pumpS6Page(
        tester,
        ApprovalGuardScreen(request: _guardRequest, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('approval-guard-request')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('approval-guard-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('approval-guard-offline')),
        findsNothing,
      );
    });

    testWidgets('an offline prepare pauses the guard and opens no wallet', (
      tester,
    ) async {
      final wallet = RecordingSigningGateway();
      await pumpS6Page(
        tester,
        ApprovalGuardScreen(request: _guardRequest, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          prepareFailure: LoopChainFailureKind.offline,
        ),
        signing: wallet,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('approval-guard-exact')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('approval-guard-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('approval-guard-error')),
        findsNothing,
      );
      expect(find.text('授权没有准备成功'), findsNothing);
      expect(wallet.handoffs, isEmpty);
    });
  });

  group('approvals', () {
    testWidgets('a pending inventory read shows the skeleton and no count', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        ApprovalsScreen(clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(pending: true),
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('approvals-state-loading')),
        findsOneWidget,
      );
      expect(find.textContaining('个有效授权'), findsNothing);
    });

    testWidgets('an offline inventory read pauses without an empty list', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        ApprovalsScreen(clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        approvals: FakeApprovalsGateway(failure: LoopChainFailureKind.offline),
      );

      expect(
        find.byKey(const ValueKey<String>('approvals-state-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('approvals-state-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('approvals-empty')),
        findsNothing,
      );
    });

    testWidgets('an offline revoke pauses and keeps the rows it already read', (
      tester,
    ) async {
      final wallet = RecordingSigningGateway();
      await pumpS6Page(
        tester,
        ApprovalsScreen(clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          prepareFailure: LoopChainFailureKind.offline,
        ),
        approvals: FakeApprovalsGateway(),
        signing: wallet,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('approval-$s5UsdtAssetId-$s6Spender')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('approval-action-revoke')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('approvals-revoke-offline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('approvals-revoke-error')),
        findsNothing,
      );
      // The inventory that already loaded is still on screen.
      expect(
        find.byKey(const ValueKey<String>('approvals-freshness')),
        findsOneWidget,
      );
      expect(wallet.handoffs, isEmpty);
    });
  });

  group('tx-result', () {
    testWidgets('a pending read shows the skeleton and claims no outcome', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const TransactionResultScreen(intentId: s6IntentId),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(pending: true),
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('tx-result-state-loading')),
        findsOneWidget,
      );
      expect(find.text('交易已确认'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('tx-result-hash')),
        findsNothing,
      );
    });

    testWidgets(
      'an offline read pauses and never says the transaction failed',
      (tester) async {
        await pumpS6Page(
          tester,
          const TransactionResultScreen(
            intentId: s6IntentId,
            pollInterval: Duration(days: 1),
          ),
          wallet: FakeWalletReadGateway(),
          intents: FakeWalletIntentsGateway(
            failure: LoopChainFailureKind.offline,
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('tx-result-state-offline')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('tx-result-state-error')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('tx-result-state-empty')),
          findsNothing,
        );
        expect(find.text('交易已确认'), findsNothing);
      },
    );

    testWidgets('an unreported submission is the locked story, not offline', (
      tester,
    ) async {
      // This is the page a `reportRefused` outcome opens. The server still has
      // the intent in `awaiting_signature`, and the honest sentence is "the
      // server has not recorded this submission" — never an offline pause and
      // never an invitation to sign again.
      await pumpS6Page(
        tester,
        const TransactionResultScreen(
          intentId: s6IntentId,
          pollInterval: Duration(days: 1),
        ),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(reported: s6Intent()),
      );

      expect(
        find.byKey(const ValueKey<String>('tx-result-unreported')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('tx-result-state-offline')),
        findsNothing,
      );
      expect(find.textContaining('不要重新签名'), findsOneWidget);
    });
  });
}
