import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/loop_candle_chart.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/features/wallet/money_actions_models.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/features/wallet/send_screens.dart';
import 'package:loop_mobile/features/wallet/swap_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_activity_export.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s6_fixtures.dart';
import 'support/s6_page_harness.dart';

/// S77a · the wallet, market, alert and chart defects the 2026-09-23
/// walkthrough found on the device.
///
/// Every group below pins one reported behaviour: a control that took a tap
/// and did nothing, a sentence that said a read failed when nothing had been
/// read, a step that could not be completed with the keyboard up, and a
/// refusal that blamed a rule nobody had triggered.
DateTime _fresh() => DateTime.utc(2026, 9, 9, 13, 35, 45);

void main() {
  group('send · step 1 is answered by the asset page', () {
    testWidgets('发送 on one asset opens step 2 with that asset chosen', (
      tester,
    ) async {
      final routes = <String>[];
      final extras = <Object?>[];
      await pumpS5Page(
        tester,
        WalletAssetScreen(
          assetId: s5NativeAssetId,
          onNavigate: (location, {Object? extra}) {
            routes.add(location);
            extras.add(extra);
          },
        ),
        wallet: FakeWalletReadGateway(),
        chain: FakeChainGateway(),
        meta: s5MetaSnapshot(
          sendApprovals: LoopV2CapabilityAvailability.available,
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-asset-send')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('wallet-asset-send')));
      await tester.pumpAndSettle();

      expect(routes, <String>['/wallet/send/to']);
      final draft = extras.single;
      expect(draft, isA<SendDraft>());
      expect((draft! as SendDraft).assetId, s5NativeAssetId);
      expect((draft as SendDraft).symbol, 'BNB');
      expect(draft.walletId, s5WalletId);
    });

    testWidgets('a row whose balance failed still starts at step 1', (
      tester,
    ) async {
      final routes = <String>[];
      await pumpS5Page(
        tester,
        WalletAssetScreen(
          assetId: s5NativeAssetId,
          onNavigate: (location, {Object? extra}) => routes.add(location),
        ),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: s5Balances(
              rows: <LoopAssetBalanceRow>[
                s5Row(
                  balance: const LoopBalanceUnavailable(
                    'BSC_RPC_BALANCE_UNAVAILABLE',
                  ),
                ),
              ],
            ),
          ),
        ),
        chain: FakeChainGateway(),
        meta: s5MetaSnapshot(
          sendApprovals: LoopV2CapabilityAvailability.available,
        ),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('wallet-asset-send')),
      );
      await tester.tap(find.byKey(const ValueKey<String>('wallet-asset-send')));
      await tester.pumpAndSettle();

      // There is no spendable figure to check an amount against, so the flow
      // starts where the asset is chosen rather than pretending.
      expect(routes, <String>['/wallet/send']);
    });
  });

  group('send-to · the step says what it is still waiting for', () {
    const draft = SendDraft(
      walletId: s5WalletId,
      assetId: s5NativeAssetId,
      symbol: 'BNB',
    );

    testWidgets('an empty address names the field, not the button', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendRecipientScreen(draft: draft),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      expect(
        tester
            .widget<LoopButton>(
              find.byKey(const ValueKey<String>('send-recipient-next')),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('填写完整的收款地址'), findsOneWidget);
    });

    testWidgets('a checked address says the amount is what is missing', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendRecipientScreen(draft: draft),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('send-recipient-field')),
        s5Address,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('send-recipient-check')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('send-recipient-missing')),
        findsOneWidget,
      );
      expect(find.textContaining('填写发送数量'), findsOneWidget);
    });

    testWidgets('the checks fold into one line and name no database table', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendRecipientScreen(draft: draft),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('send-recipient-field')),
        s5Address,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('send-recipient-check')),
      );
      await tester.pumpAndSettle();

      // Folded: the warning cards are inside a disclosure whose summary says
      // how many there are, so the amount field is not pushed off screen.
      expect(
        find.byKey(const ValueKey<String>('send-recipient-checks')),
        findsOneWidget,
      );
      expect(find.textContaining('2 项待确认'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('send-recipient-first-time')),
        findsNothing,
      );

      await openLoopDisclosure(
        tester,
        const ValueKey<String>('send-recipient-checks'),
      );
      expect(
        find.byKey(const ValueKey<String>('send-recipient-first-time')),
        findsOneWidget,
      );
      // The basis names the records, never the table they live in.
      expect(find.textContaining('indexed_erc20_transfers'), findsNothing);
      expect(find.textContaining('已索引的 ERC-20 转账记录'), findsOneWidget);
    });

    testWidgets('a contract recipient is never folded away', (tester) async {
      await pumpS6Page(
        tester,
        const SendRecipientScreen(draft: draft),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          preflight: s6Preflight(
            isContract: true,
            warnings: const <String>[
              'send.recipient.isContract',
              'send.recipient.screeningUnavailable',
            ],
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('send-recipient-field')),
        s5Address,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('send-recipient-check')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('send-recipient-contract')),
        findsOneWidget,
      );
    });
  });

  group('send-confirm · the review lists something before it asks', () {
    const draft = SendDraft(
      walletId: s5WalletId,
      assetId: s5NativeAssetId,
      symbol: 'BNB',
      recipientAddress: s5Address,
      amount: '1',
    );

    testWidgets('a refused prepare still shows what was being confirmed', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SendConfirmScreen(draft: draft),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(
          prepareFailure: LoopChainFailureKind.permissionDenied,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('send-confirm-draft-facts')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('send-confirm-draft-recipient')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('send-confirm-draft-amount')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('send-confirm-draft-fee')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('send-confirm-draft-arrival')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('send-confirm-permission')),
        findsOneWidget,
      );
    });

    testWidgets('a prepared intent carries the arrival row too', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        SendConfirmScreen(draft: draft, clock: _fresh),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
      );

      await scrollToS5Section(
        tester,
        find.byKey(const ValueKey<String>('send-confirm-arrival')),
      );
      expect(find.textContaining('不预估'), findsWidgets);
      // The draft card steps aside once the server's own review is in.
      expect(
        find.byKey(const ValueKey<String>('send-confirm-draft-facts')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey<String>('money-review-收款方')), findsOne);
      expect(
        find.byKey(const ValueKey<String>('money-review-最高网络费')),
        findsOne,
      );
    });
  });

  group('policy refusals · each canary rule has its own sentence', () {
    String textFor(
      String rule, {
      String? exposureUsd,
      String? ceilingUsd,
      String? spentUsd,
      String? remainingUsd,
    }) => moneyPolicyRefusalText(
      LoopChainException(
        LoopChainFailureKind.permissionDenied,
        reasonCode: rule,
        exposureUsd: exposureUsd,
        ceilingUsd: ceilingUsd,
        spentUsd: spentUsd,
        remainingUsd: remainingUsd,
      ),
    );

    test('the recipient allowlist is named as a recipient rule', () {
      final text = textFor(MoneyPolicyRule.counterpartyNotInAllowlist);
      expect(text, contains('收款地址'));
      expect(text, contains('没有提交任何交易'));
      expect(text, isNot(contains('自定义上限')));
    });

    test('the per-transaction ceiling names the per-transaction ceiling', () {
      final text = textFor(
        MoneyPolicyRule.canaryCeilingExceeded,
        exposureUsd: '5.99',
        ceilingUsd: '5',
      );
      expect(text, contains('单笔金额上限'));
      expect(text, contains('5.99'));
      expect(text, contains(r'$5'));
    });

    test('the daily ceiling says it is a rolling 24 hours', () {
      final text = textFor(
        MoneyPolicyRule.canaryDailyCeilingExceeded,
        exposureUsd: '27.5',
        ceilingUsd: '25',
      );
      expect(text, contains('24 小时'));
      expect(text, contains('27.5'));
    });

    test('the daily ceiling prints the budget when the server sends it', () {
      final text = textFor(
        MoneyPolicyRule.canaryDailyCeilingExceeded,
        exposureUsd: '27.5',
        ceilingUsd: '25',
        spentUsd: '20',
        remainingUsd: '5',
      );
      expect(text, contains(r'已用 $20'));
      expect(text, contains(r'还剩 $5'));
    });

    test('half a budget is not a budget', () {
      final text = textFor(
        MoneyPolicyRule.canaryDailyCeilingExceeded,
        exposureUsd: '27.5',
        ceilingUsd: '25',
        spentUsd: '20',
      );
      expect(text, isNot(contains('已用')));
      expect(text, isNot(contains('还剩')));
    });

    test('only the daily rule prints a budget', () {
      final text = textFor(
        MoneyPolicyRule.canaryCeilingExceeded,
        exposureUsd: '5.99',
        ceilingUsd: '5',
        spentUsd: '20',
        remainingUsd: '5',
      );
      expect(text, isNot(contains('已用')));
    });

    test('the asset allowlist is about the asset', () {
      expect(
        textFor(MoneyPolicyRule.assetNotInAllowlist),
        contains('可操作的资产范围'),
      );
    });

    test('a rule this build cannot read is answered neutrally', () {
      final text = textFor('SOME_RULE_S77B_HAS_NOT_SHIPPED_YET');
      expect(text, contains('没有提交任何交易'));
      expect(text, contains('这里不猜是哪一条'));
      expect(text, isNot(contains('上限')));
    });

    test('no refusal blames a limit the owner never set', () {
      for (final rule in const <String>[
        MoneyPolicyRule.assetNotInAllowlist,
        MoneyPolicyRule.counterpartyNotInAllowlist,
        MoneyPolicyRule.canaryCeilingExceeded,
        MoneyPolicyRule.canaryDailyCeilingExceeded,
        MoneyPolicyRule.unlimitedExposureExceedsCeiling,
        MoneyPolicyRule.assetBlocked,
        MoneyPolicyRule.priceImpactBlocked,
        MoneyPolicyRule.nativeAssetNotApprovable,
      ]) {
        expect(textFor(rule), isNot(contains('自定义上限')), reason: rule);
      }
    });

    test('only a ceiling rule may print the two figures', () {
      final text = textFor(
        MoneyPolicyRule.counterpartyNotInAllowlist,
        exposureUsd: '27.5',
        ceilingUsd: '25',
      );
      expect(text, isNot(contains('27.5')));
    });
  });

  group('swap · what is read, what is chosen, and what a bps is', () {
    testWidgets('no asset chosen is not a balance that could not be read', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SwapScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        quotes: FakeSwapQuoteGateway(),
      );

      expect(find.textContaining('读不到可用余额'), findsNothing);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('swap-source-balance')),
            )
            .data,
        '先选择要支付的资产，这里会显示它的可动用余额。',
      );
    });

    testWidgets('a chosen asset shows the balance the wallet page shows', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SwapScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        quotes: FakeSwapQuoteGateway(),
      );

      await tester.tap(find.byKey(const ValueKey<String>('swap-source-pick')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('swap-pick-$s5NativeAssetId')),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('swap-source-balance')),
            )
            .data,
        '可动用 6.995 BNB',
      );
    });

    testWidgets('the slippage row reads in percent, in one row', (
      tester,
    ) async {
      await pumpS6Page(
        tester,
        const SwapScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        quotes: FakeSwapQuoteGateway(),
      );

      expect(find.text('0.5%'), findsOneWidget);
      expect(find.text('1%'), findsOneWidget);
      expect(find.text('3%'), findsOneWidget);
      expect(find.textContaining('bps'), findsNothing);

      // One row: the three chips share a baseline.
      final tops = <double>[
        for (final bps in <int>[50, 100, 300])
          tester
              .getTopLeft(find.byKey(ValueKey<String>('swap-slippage-$bps')))
              .dy,
      ];
      expect(tops.toSet(), hasLength(1));
    });

    testWidgets('the pending-evidence notice says it once', (tester) async {
      await pumpS6Page(
        tester,
        const SwapScreen(),
        wallet: FakeWalletReadGateway(),
        intents: FakeWalletIntentsGateway(),
        quotes: FakeSwapQuoteGateway(),
      );

      final notice = tester.widget<LoopNotice>(
        find.byKey(const ValueKey<String>('swap-evidence-pending')),
      );
      expect(notice.title, isNull);
      expect(notice.body, contains('可以查看报价'));
      expect(find.textContaining('兑换还在验证中'), findsOneWidget);
    });

    test('a slippage ceiling converts exactly, with no trailing zeros', () {
      expect(moneySlippageLabel(50), '0.5%');
      expect(moneySlippageLabel(100), '1%');
      expect(moneySlippageLabel(300), '3%');
      expect(moneySlippageLabel(25), '0.25%');
    });
  });

  group('wallet · no control takes a tap and does nothing', () {
    testWidgets('跨链 opens the page that states why there is no route', (
      tester,
    ) async {
      final routes = <String>[];
      await pumpS5Page(
        tester,
        WalletScreen(onNavigate: routes.add),
        wallet: FakeWalletReadGateway(),
        chain: FakeChainGateway(),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('wallet-bridge-entry')),
      );
      await tester.pumpAndSettle();

      expect(routes, <String>['/wallet/bridge']);
    });

    testWidgets('添加 opens an explanation that stays on screen', (tester) async {
      await pumpS5Page(
        tester,
        const WalletManagerScreen(),
        wallet: FakeWalletReadGateway(),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('wallets-add-action')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('wallets-add-sheet')),
        findsOneWidget,
      );
      expect(find.text('暂不支持绑定第二个钱包'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('wallets-add-sheet-reason')),
        findsOneWidget,
      );
    });
  });

  group('tx-history · the export exports and the rows open', () {
    testWidgets('导出 hands the listed rows to the share port', (tester) async {
      final sink = _RecordingExportSink();
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(),
        wallet: FakeWalletReadGateway(),
        exportSink: sink,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('tx-history-export-action')),
      );
      await tester.pumpAndSettle();

      expect(sink.calls, hasLength(1));
      expect(sink.calls.single.csv, contains(s5TxHash));
      expect(sink.calls.single.csv, contains('WBNB'));
      expect(sink.calls.single.fileName, endsWith('.csv'));
      expect(find.text('记录已导出，请在分享面板中选择去处'), findsOneWidget);
    });

    testWidgets('a segment with no rows exports nothing at all', (
      tester,
    ) async {
      final sink = _RecordingExportSink();
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(),
        wallet: FakeWalletReadGateway(),
        exportSink: sink,
      );

      // 发出: the fixture's single row is incoming.
      await tester.tap(find.byKey(const ValueKey<String>('tx-history-seg-2')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('tx-history-export-action')),
      );
      await tester.pumpAndSettle();

      expect(sink.calls, isEmpty);
      expect(find.text('这一段没有记录可以导出'), findsOneWidget);
    });

    testWidgets('a row opens the full hash and the explorer address', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const TransactionHistoryScreen(),
        wallet: FakeWalletReadGateway(),
      );

      await scrollToS5Section(
        tester,
        find.byKey(ValueKey<String>('tx-entry-$s5TxHash:3')),
      );
      await tester.tap(find.byKey(ValueKey<String>('tx-entry-$s5TxHash:3')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('tx-entry-sheet')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const ValueKey<String>('tx-entry-sheet-hash')),
            )
            .data,
        s5TxHash,
      );
      expect(
        tester
            .widget<SelectableText>(
              find.byKey(const ValueKey<String>('tx-entry-sheet-link')),
            )
            .data,
        'https://bscscan.com/tx/$s5TxHash',
      );
      expect(
        find.byKey(const ValueKey<String>('tx-entry-sheet-copy-hash')),
        findsOneWidget,
      );
    });

    test('the CSV quotes anything that could break a row', () {
      final csv = walletActivityCsv(s5Activity().items);
      final lines = csv.trimRight().split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, startsWith('时间(UTC),方向,资产'));
      // Exact wire figures, never a grouped or rounded display form.
      expect(lines[1], contains('1.5'));
      expect(lines[1], contains('1500000000000000000'));
      expect(lines[1], contains('120628064'));
      expect(lines[1], isNot(contains('120,628,064')));
    });
  });

  group('alerts · the editor names the asset and asks before deleting', () {
    testWidgets('the asset row is a name and a symbol, never a CAIP id', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(),
      );

      await tester.tap(find.byKey(const ValueKey<String>('alert-$s5AlertId')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('alert-asset-row')),
        findsOneWidget,
      );
      expect(find.text('WBNB'), findsWidgets);
      expect(find.text('Wrapped BNB'), findsWidgets);
      expect(find.textContaining('eip155:'), findsNothing);
      expect(find.textContaining('CAIP'), findsNothing);
    });

    testWidgets('the four conditions are one row with their meaning spelt', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(),
      );

      await tester.tap(find.byKey(const ValueKey<String>('alert-$s5AlertId')));
      await tester.pumpAndSettle();

      final tops = <double>[
        for (final wire in <String>[
          'above',
          'at_or_above',
          'below',
          'at_or_below',
        ])
          tester
              .getTopLeft(find.byKey(ValueKey<String>('alert-condition-$wire')))
              .dy,
      ];
      expect(tops.toSet(), hasLength(1), reason: '四个条件在同一行');

      // The chosen one explains which comparison it makes.
      expect(find.textContaining('到达：价格达到或高于阈值'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('alert-condition-above')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('突破：价格必须高于阈值'), findsOneWidget);
    });

    testWidgets('删除 is not a peer of 保存 and it asks first', (tester) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(),
      );

      await tester.tap(find.byKey(const ValueKey<String>('alert-$s5AlertId')));
      await tester.pumpAndSettle();

      final save = tester.getTopLeft(
        find.byKey(const ValueKey<String>('alert-editor-submit')),
      );
      final delete = tester.getTopLeft(
        find.byKey(const ValueKey<String>('alert-editor-delete')),
      );
      expect(delete.dy, greaterThan(save.dy), reason: '删除不与保存并列');

      await tester.tap(
        find.byKey(const ValueKey<String>('alert-editor-delete')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('alert-delete-confirm')),
        findsOneWidget,
      );
    });

    testWidgets('one asset\'s bell shows only that asset\'s alerts', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(assetId: s5UsdtAssetId),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(),
      );

      // The fixture's only alert is on WBNB, so a USDT bell has none of its
      // own — and says so rather than listing somebody else's thresholds.
      expect(
        find.byKey(const ValueKey<String>('alert-$s5AlertId')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('alerts-empty')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('alerts-show-every-asset')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('alert-$s5AlertId')),
        findsOneWidget,
      );
    });

    testWidgets('the asset\'s own bell pre-selects it in a new alert', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const PriceAlertsScreen(assetId: s5WbnbAssetId),
        alerts: FakeAlertsGateway(),
        notifications: FakeNotificationsGateway(),
        market: FakeMarketReadGateway(),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('alerts-create-action')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('alert-asset-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('alert-asset-pick')),
        findsNothing,
      );
    });
  });

  group('chart-full · the page is the chart', () {
    testWidgets('the plot takes the height the page has', (tester) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
        size: const Size(390, 844),
      );

      final chart = tester.getSize(find.byType(LoopCandleChart));
      // Two-thirds of a 844pt screen at the very least: the plot used to be a
      // fixed 320 with a third of a screen of black under it.
      expect(chart.height, greaterThan(400));
    });

    testWidgets('no indicator is offered that nothing draws', (tester) async {
      await pumpS5Page(
        tester,
        const FullChartScreen(assetId: s5WbnbAssetId),
        market: FakeMarketReadGateway(),
      );

      expect(find.text('EMA'), findsNothing);
      expect(find.text('MACD'), findsNothing);
      expect(find.text('RSI'), findsNothing);
      expect(find.text('MA'), findsOneWidget);
      expect(find.text('VOL'), findsOneWidget);
    });
  });

  group('candle figures · the scale follows the price', () {
    Decimal d(String value) => Decimal.parse(value);

    test('a four-figure price keeps two decimals and its separators', () {
      expect(loopFormatCandlePrice(d('2759.67162123')), '2,759.67');
      expect(loopFormatCandlePrice(d('123456.789')), '123,456.79');
    });

    test('a dollar-scale price keeps four', () {
      expect(loopFormatCandlePrice(d('747.3912345')), '747.3912');
      expect(loopFormatCandlePrice(d('1.23456789')), '1.2346');
    });

    test('a sub-unit price keeps four significant digits', () {
      expect(loopFormatCandlePrice(d('0.0000078123')), '0.000007812');
      expect(loopFormatCandlePrice(d('0.87412345')), '0.8741');
    });

    test('an exact zero is still a zero', () {
      expect(loopFormatCandlePrice(Decimal.zero), '0');
    });
  });
}

final class _ExportCall {
  const _ExportCall(this.csv, this.fileName);

  final String csv;
  final String fileName;
}

final class _RecordingExportSink implements WalletActivityExportSink {
  final List<_ExportCall> calls = <_ExportCall>[];

  @override
  Future<WalletExportOutcome> shareCsv({
    required String csv,
    required String fileName,
  }) async {
    calls.add(_ExportCall(csv, fileName));
    return WalletExportOutcome.shared;
  }
}
