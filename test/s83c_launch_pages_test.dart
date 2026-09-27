import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/core/intent/signing_intent.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_signing.dart';
import 'package:loop_mobile/features/launch/launch_trade_screen.dart';
import 'package:loop_mobile/features/wallet/money_actions_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/privy/privy_provider.dart';
import 'package:loop_mobile/integrations/privy/wallet_signing_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sign_sheet.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s83c_fixtures.dart';
import 'support/s88d_meta_server.dart';

/// Decision 0088 · the Launch pages against the `available` branches.
///
/// Every value here comes from `support/s83c_fixtures.dart` (测试专用, written
/// from the OpenAPI document). The five states of each changed page are
/// driven through the same port double the step-7 tests use.

/// A wallet boundary that records what it was handed and answers with a
/// fixed result. It never reaches Privy.
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

typedef _Page = ({
  String prefix,
  Widget page,
  FakeLaunchGateway Function(S7Answer<Object?>) gateway,
});

/// The four detail-backed pages read one resource.
FakeLaunchGateway _detailGateway(S7Answer<Object?> answer) => FakeLaunchGateway(
  detail: S7Answer<LaunchDetail>(
    value: answer.value as LaunchDetail?,
    failure: answer.failure,
    pending: answer.pending,
  ),
);

final List<_Page> _pages = <_Page>[
  (
    prefix: 'launch-detail',
    page: const LaunchDetailScreen(launchId: s7LaunchId),
    gateway: _detailGateway,
  ),
  (
    prefix: 'launch-rounds',
    page: const LaunchRoundsScreen(launchId: s7LaunchId),
    gateway: _detailGateway,
  ),
  (
    prefix: 'launch-graduation',
    page: const LaunchGraduationScreen(launchId: s7LaunchId),
    gateway: _detailGateway,
  ),
  (
    prefix: 'launch-trade',
    page: const LaunchTradeScreen(launchId: s7LaunchId),
    gateway: _detailGateway,
  ),
  (
    prefix: 'launch-tier',
    page: const LaunchTierScreen(launchId: s7LaunchId),
    gateway: (answer) => FakeLaunchGateway(
      eligibility: S7Answer<LaunchEligibility>(
        value: answer.value as LaunchEligibility?,
        failure: answer.failure,
        pending: answer.pending,
      ),
    ),
  ),
  (
    prefix: 'launch-holders',
    page: const LaunchHoldersScreen(launchId: s7LaunchId),
    gateway: (answer) => FakeLaunchGateway(
      holders: S7Answer<LaunchHolders>(
        value: answer.value as LaunchHolders?,
        failure: answer.failure,
        pending: answer.pending,
      ),
    ),
  ),
  (
    prefix: 'launch-history',
    page: const LaunchHistoryScreen(launchId: s7LaunchId),
    gateway: (answer) => FakeLaunchGateway(
      history: S7Answer<LaunchHistory>(
        value: answer.value as LaunchHistory?,
        failure: answer.failure,
        pending: answer.pending,
      ),
    ),
  ),
];

Future<void> _pumpTrade(
  WidgetTester tester, {
  required FakeLaunchGateway gateway,
  _RecordingWallet? wallet,
  bool evidencePending = false,
  String balancesChainId = loopPrimaryChainId,
  S88dMetaServer? metaServer,
}) => pumpS7Page(
  tester,
  LaunchTradeScreen(launchId: s7LaunchId, clock: s83cNow),
  launch: gateway,
  // Decision 0089: the allowance is read from the wallet balances. It covers
  // the 500 USD1 these tests type, so the main action stays 「买入」.
  wallet: FakeWalletDirectory(
    activeWalletId: s7WalletId,
    wallets: [s83cWallet()],
    balances: [s83cBalances(chainId: balancesChainId)],
  ),
  meta: s7MetaSnapshot(launchEvidencePending: evidencePending),
  metaRepository: metaServer,
  overrides: [
    if (wallet != null) walletSigningGatewayProvider.overrideWithValue(wallet),
  ],
);

Future<void> _fillAndSubmit(WidgetTester tester) async {
  await tester.tap(_key('launch-round-1'));
  await tester.pumpAndSettle();
  await tester.enterText(_key('launch-trade-amount'), '500');
  await tester.pumpAndSettle();
  await scrollToS7Section(tester, _key('launch-trade-submit'));
  await tester.tap(_key('launch-trade-submit'));
  await tester.pumpAndSettle();
}

void main() {
  group('S88d · the purchase sheet opens on the server\'s current '
      'capability', () {
    testWidgets('a request pair goes out before the sheet, and the sign '
        'action is pending meanwhile', (tester) async {
      final server = S88dMetaServer(
        s7MetaSnapshot(launchEvidencePending: false),
      );
      await _pumpTrade(
        tester,
        gateway: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(value: s83cDetail()),
          prepared: LaunchPurchasePrepared(intent: s83cIntent()),
        ),
        metaServer: server,
      );
      await _fillAndSubmit(tester);
      expect(server.log, <String>['policy', 'capabilities']);

      server.hold = true;
      await scrollToS7Section(tester, _key('launch-trade-sign'));
      await tester.tap(_key('launch-trade-sign'));
      await tester.pump();
      await tester.pump();
      expect(server.log, hasLength(4));
      expect(server.log.sublist(2), <String>['policy', 'capabilities']);
      final pending = tester.widget<LoopButton>(_key('launch-trade-sign'));
      expect(pending.label, moneyCapabilityCheckingLabel);
      expect(pending.onPressed, isNull);
      expect(_key('launch-sign-sheet'), findsNothing);

      server.release();
      await tester.pumpAndSettle();
      expect(_key('launch-sign-sheet'), findsOneWidget);
    });

    testWidgets('a capability closed since the page opened keeps the sheet '
        'shut and takes the page block', (tester) async {
      final server = S88dMetaServer(
        s7MetaSnapshot(launchEvidencePending: false),
      );
      await _pumpTrade(
        tester,
        gateway: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(value: s83cDetail()),
          prepared: LaunchPurchasePrepared(intent: s83cIntent()),
        ),
        metaServer: server,
      );
      await _fillAndSubmit(tester);

      server.document = s7MetaSnapshot(
        launch: LoopV2CapabilityAvailability.unavailable,
      );
      await scrollToS7Section(tester, _key('launch-trade-sign'));
      await tester.tap(_key('launch-trade-sign'));
      await tester.pumpAndSettle();
      expect(server.log, hasLength(4));
      expect(_key('launch-sign-sheet'), findsNothing);
      expect(_key('launch-trade-capability-unavailable'), findsOneWidget);
    });
  });

  group('loading / unavailable / error on every changed page', () {
    for (final page in _pages) {
      testWidgets('${page.prefix} · loading', (tester) async {
        await pumpS7Page(
          tester,
          page.page,
          launch: page.gateway(S7Answer<Object?>(pending: true)),
          settle: false,
        );
        expect(_key('${page.prefix}-state-loading'), findsOneWidget);
      });
      for (final (kind, suffix) in <(LaunchFailureKind, String)>[
        (LaunchFailureKind.unavailable, 'unavailable'),
        (LaunchFailureKind.unexpected, 'error'),
      ]) {
        testWidgets('${page.prefix} · $suffix', (tester) async {
          await pumpS7Page(
            tester,
            page.page,
            launch: page.gateway(S7Answer<Object?>(failure: kind)),
          );
          expect(_key('${page.prefix}-state-$suffix'), findsOneWidget);
        });
      }
    }
  });

  group('launch-detail · available', () {
    testWidgets('four axes each on their own row, projection from them', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchDetailScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s83cDetail(
              onChain: s83cOnChain(
                sale: LaunchSaleState.succeeded,
                entitlement: LaunchEntitlementState.frozen,
                liquidity: LaunchLiquidityState.preparing,
              ),
            ),
          ),
        ),
      );

      // The identity card now names the registered contract's tail.
      expect(find.textContaining('合约 …11111111'), findsOneWidget);
      expect(find.textContaining('销售成功，流动性准备中'), findsWidgets);
      expect(find.text('链上读数来自同一区块'), findsOneWidget);
      // The first round's fixed price is the one grid figure a round proves.
      expect(find.text('0.01 USD1'), findsWidgets);

      await openS7Disclosure(
        tester,
        const ValueKey<String>('launch-detail-facts'),
      );
      for (final (label, value) in <(String, String)>[
        ('销售状态', 'SUCCEEDED'),
        ('权益状态', 'FROZEN'),
        ('流动性状态', 'PREPARING'),
        ('运营状态', 'ACTIVE'),
      ]) {
        final row = tester.widget<LoopRecordRow>(_key('launch-axis-$label'));
        expect(row.trailing, value, reason: label);
      }
      expect(find.textContaining('快照区块 45,000,000'), findsWidgets);
      expect(_key('launch-detail-sale-config'), findsOneWidget);
    });

    testWidgets('unreadable axes keep the server reason, not a fixed one', (
      tester,
    ) async {
      final unavailable = s7Detail();
      await pumpS7Page(
        tester,
        const LaunchDetailScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: LaunchDetail(
              launch: LaunchSummary(
                launchId: s7LaunchId,
                projectId: s7ProjectId,
                name: 'MoonCat',
                ticker: 'MCAT',
                chainId: loopPrimaryChainId,
                contractAddress: null,
                configDigest: null,
                scheduleStatus: LaunchScheduleStatus.scheduled,
                onChainState: const LaunchOnChainUnavailable(
                  'LAUNCH_SALE_NOT_REGISTERED',
                ),
                configVersion: null,
                createdAt: DateTime.utc(2026, 9, 8),
              ),
              project: unavailable.project,
              config: unavailable.config,
              configPending: unavailable.configPending,
              rounds: unavailable.rounds,
              graduation: unavailable.graduation,
              market: unavailable.market,
              holders: unavailable.holders,
            ),
          ),
        ),
      );
      final notice = tester.widget<LoopNotice>(
        _key('launch-detail-baseline-notice'),
      );
      expect(notice.body, contains('还没有登记到链上'));
      expect(notice.body, isNot(contains('Launch 合约还没有上线')));
    });
  });

  group('launch-rounds · available', () {
    testWidgets('rounds render index, window, price, caps and raised', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchRoundsScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(value: s83cDetail()),
        ),
      );
      expect(find.text('2 个轮次'), findsOneWidget);
      final first = tester.widget<LoopRecordRow>(_key('launch-round-1'));
      expect(first.title, 'Round 1 · 名单轮');
      expect(first.trailing, '0.01 USD1');
      expect(first.subtitle, contains('2026-09-21 14:13 UTC'));
      expect(first.subtitle, contains('轮次上限 40,000 USD1'));
      expect(first.subtitle, contains('钱包上限 500 USD1'));
      expect(first.subtitle, contains('已募集 1,234 USD1'));
      final second = tester.widget<LoopRecordRow>(_key('launch-round-2'));
      expect(second.title, 'Round 2 · 公开轮');
      expect(find.text('Round 1 单钱包上限'), findsOneWidget);
      await openS7Disclosure(
        tester,
        const ValueKey<String>('launch-rounds-facts'),
      );
      expect(
        tester.widget<LoopRecordRow>(_key('launch-sale-config-协议费')).trailing,
        '3%',
      );
      expect(
        tester.widget<LoopRecordRow>(_key('launch-sale-config-池费率档位')).trailing,
        '0.25%',
      );
    });

    testWidgets('a chain read with no rounds is the page-local empty', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchRoundsScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s83cDetail(rounds: const <LaunchChainRound>[]),
          ),
        ),
      );
      expect(_key('launch-rounds-empty'), findsOneWidget);
    });
  });

  group('launch-graduation · available', () {
    testWidgets('steps are derived from liquidity and entitlement', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchGraduationScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s83cDetail(
              onChain: s83cOnChain(
                sale: LaunchSaleState.succeeded,
                entitlement: LaunchEntitlementState.frozen,
                liquidity: LaunchLiquidityState.v3Live,
              ),
            ),
          ),
        ),
      );
      expect(find.text('毕业中'), findsOneWidget);
      String badge(String step) =>
          (tester
                      .widget<LoopRecordRow>(
                        _key('launch-graduation-step-$step'),
                      )
                      .trailingBadge!
                  as LoopBadge)
              .text;
      expect(badge('stop_internal_trading'), '已完成');
      expect(badge('prepare_pool'), '已完成');
      expect(badge('add_and_lock_liquidity'), '进行中');
      expect(badge('open_external_trading'), '待触发');
    });

    testWidgets('only a locked pool says graduated', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchGraduationScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s83cDetail(
              onChain: s83cOnChain(
                sale: LaunchSaleState.succeeded,
                entitlement: LaunchEntitlementState.vesting,
                liquidity: LaunchLiquidityState.lpLocked,
              ),
            ),
          ),
        ),
      );
      expect(find.text('已毕业'), findsOneWidget);
    });
  });

  group('launch-tier / holders / history · available and empty', () {
    testWidgets('tier shows the evaluated tier, block and proof', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchTierScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          eligibility: S7Answer<LaunchEligibility>(value: s83cEligibility()),
        ),
      );
      expect(find.text('Priority'), findsWidgets);
      expect(find.text('44,999,000'), findsOneWidget);
      expect(
        tester.widget<LoopRecordRow>(_key('launch-tier-proof')).trailing,
        '2 条',
      );
    });

    testWidgets('an evaluated null tier reads as not listed', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchTierScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          eligibility: S7Answer<LaunchEligibility>(
            value: s83cEligibility(tier: null),
          ),
        ),
      );
      expect(find.text('不在名单'), findsOneWidget);
    });

    testWidgets('holders render count, my position and my caps', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchHoldersScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          holders: S7Answer<LaunchHolders>(value: s83cHolders()),
        ),
      );
      expect(find.text('1,842 位参与者'), findsOneWidget);
      final me = tester.widget<LoopRecordRow>(_key('launch-holders-me'));
      expect(me.subtitle, contains('已认购 20,000 枚'));
      expect(me.subtitle, contains('累计支付 200 USD1'));
      expect(_key('launch-holders-cap-1'), findsOneWidget);
      // Concentration has no source in any schema: still the dash.
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('history lists indexed purchases', (tester) async {
      await pumpS7Page(
        tester,
        const LaunchHistoryScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          history: S7Answer<LaunchHistory>(value: s83cHistory()),
        ),
      );
      expect(find.text('1 笔认购'), findsOneWidget);
      expect(_key('launch-history-purchases'), findsOneWidget);
      expect(find.text('已确认'), findsOneWidget);
    });

    testWidgets('an indexed empty history is a real empty, with its block', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchHistoryScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          history: S7Answer<LaunchHistory>(value: s83cHistory(empty: true)),
        ),
      );
      expect(_key('launch-history-indexed-empty'), findsOneWidget);
      expect(find.textContaining('45,000,100'), findsWidgets);
    });
  });

  group('launch-trade · the signing exit', () {
    testWidgets('pending evidence keeps a live sale closed', (tester) async {
      await _pumpTrade(
        tester,
        gateway: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(value: s83cDetail()),
        ),
        evidencePending: true,
      );
      await tester.tap(_key('launch-round-1'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LoopButton>(_key('launch-trade-submit')).onPressed,
        isNull,
      );
    });

    testWidgets('a paused sale keeps the action closed and says why', (
      tester,
    ) async {
      await _pumpTrade(
        tester,
        gateway: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s83cDetail(
              onChain: s83cOnChain(operational: LaunchOperationalState.paused),
            ),
          ),
        ),
      );
      expect(
        tester.widget<LoopButton>(_key('launch-trade-submit')).onPressed,
        isNull,
      );
      expect(find.textContaining('已暂停 · 销售进行中'), findsOneWidget);
    });

    testWidgets('a round LOOP has no id for cannot be chosen', (tester) async {
      await _pumpTrade(
        tester,
        gateway: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s83cDetail(rounds: [s83cRound(roundId: null)]),
          ),
        ),
      );
      final row = tester.widget<LoopRecordRow>(_key('launch-round-1'));
      expect(row.onTap, isNull);
      expect(row.subtitle, contains('不能在这里认购'));
    });

    testWidgets('a named refusal is stated; an unknown code is quoted', (
      tester,
    ) async {
      final gateway = FakeLaunchGateway(
        detail: S7Answer<LaunchDetail>(value: s83cDetail()),
        intentReasonCode: 'LAUNCH_SALE_NOT_REGISTERED',
      );
      await _pumpTrade(tester, gateway: gateway);
      await _fillAndSubmit(tester);
      expect(gateway.intents, <String>['$s7LaunchId:$s7RoundId:500']);
      expect(find.text('这次认购没有通过'), findsOneWidget);
      expect(find.textContaining('还没有登记到链上'), findsOneWidget);

      final unknown = FakeLaunchGateway(
        detail: S7Answer<LaunchDetail>(value: s83cDetail()),
        intentFailure: LaunchFailureKind.validationFailed,
        intentReasonCode: 'LAUNCH_ROUND_CAP_EXCEEDED',
      );
      await _pumpTrade(tester, gateway: unknown);
      await _fillAndSubmit(tester);
      // The code is reportable, but it lives in the disclosure, not in the
      // sentence.
      final notice = tester.widget<LoopNotice>(_key('launch-trade-refusal'));
      expect(notice.body, isNot(contains('LAUNCH_ROUND_CAP_EXCEEDED')));
      await openS7Disclosure(
        tester,
        const ValueKey<String>('launch-trade-refusal-code'),
      );
      expect(find.text('LAUNCH_ROUND_CAP_EXCEEDED'), findsOneWidget);
    });

    testWidgets(
      'a prepared intent is reviewed, signed verbatim and then locked',
      (tester) async {
        final wallet = _RecordingWallet(
          WalletHandoffResult(
            accepted: true,
            code: 'wallet_accepted',
            value: s83cTxHash,
          ),
        );
        final prepared = LaunchPurchasePrepared(intent: s83cIntent());
        await _pumpTrade(
          tester,
          gateway: FakeLaunchGateway(
            detail: S7Answer<LaunchDetail>(value: s83cDetail()),
            prepared: prepared,
          ),
          wallet: wallet,
        );
        await _fillAndSubmit(tester);

        // The review is the intent's own fields; the balance line reads the
        // wallet balances' `launchChain.usd1` (decision 0089).
        expect(_key('launch-trade-review'), findsOneWidget);
        expect(
          tester.widget<LoopRecordRow>(_key('launch-review-支付')).trailing,
          '500 USD1',
        );
        expect(
          tester.widget<LoopRecordRow>(_key('launch-review-预计获得')).trailing,
          '50,000 MCAT',
        );
        expect(find.textContaining('USD1 余额 900 USD1'), findsOneWidget);
        expect(find.textContaining('授权额度 500 USD1'), findsOneWidget);

        await scrollToS7Section(tester, _key('launch-trade-sign'));
        await tester.tap(_key('launch-trade-sign'));
        await tester.pumpAndSettle();
        expect(_key('launch-sign-sheet'), findsOneWidget);
        // The sheet shows the same lines the review did.
        final sheet = tester.widget<LoopSignSheet>(_key('launch-sign-sheet'));
        final expected = launchPurchaseFields(prepared.intent, ticker: 'MCAT');
        expect(
          sheet.facts.map((fact) => '${fact.label}=${fact.value}').toList(),
          expected.map((field) => '${field.label}=${field.value}').toList(),
        );

        await tester.tap(find.text('确认签名'));
        await tester.pumpAndSettle();

        // The wallet got the server's transaction verbatim and its digest.
        final handed = wallet.handed.single;
        expect(handed.kind, IntentKind.launchPurchase);
        expect(handed.payloadDigest, prepared.intent.payloadDigest);
        final payload = handed.payload! as DeviceTransactionPayload;
        expect(payload.fromAddress, s83cWalletAddress);
        expect(
          payload.transaction,
          prepared.intent.unsignedTransaction.toWire(),
        );
        // A broadcast is not a result: it says so and never says success.
        expect(find.textContaining('广播不代表已成交'), findsWidgets);
        expect(find.textContaining('成功'), findsNothing);

        await tester.tap(find.text('关闭'));
        await tester.pumpAndSettle();
        expect(_key('launch-trade-locked'), findsOneWidget);
        expect(_key('launch-trade-sign'), findsNothing);
      },
    );

    testWidgets('a wallet refusal on the Launch testnet submits nothing', (
      tester,
    ) async {
      final wallet = _RecordingWallet(
        const WalletHandoffResult.rejected('privy_chain_switch_unsupported'),
      );
      await _pumpTrade(
        tester,
        gateway: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(
            value: s83cDetail(chainId: loopLaunchTestnetChainId),
          ),
          prepared: LaunchPurchasePrepared(
            intent: s83cIntent(chainId: loopLaunchTestnetChainId),
          ),
        ),
        wallet: wallet,
        balancesChainId: loopLaunchTestnetChainId,
      );
      await _fillAndSubmit(tester);
      await scrollToS7Section(tester, _key('launch-trade-sign'));
      await tester.tap(_key('launch-trade-sign'));
      await tester.pumpAndSettle();
      expect(find.text(loopTestnetBadgeLabel), findsWidgets);
      await tester.tap(find.text('确认签名'));
      await tester.pumpAndSettle();
      expect(find.textContaining('没有提交任何交易'), findsWidgets);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      // Nothing was broadcast, so the form is not locked.
      expect(_key('launch-trade-locked'), findsNothing);
      expect(_key('launch-trade-sign'), findsOneWidget);
    });

    testWidgets('an expired intent never reaches the wallet', (tester) async {
      final wallet = _RecordingWallet(
        WalletHandoffResult(accepted: true, code: 'x', value: s83cTxHash),
      );
      await _pumpTrade(
        tester,
        gateway: FakeLaunchGateway(
          detail: S7Answer<LaunchDetail>(value: s83cDetail()),
          prepared: LaunchPurchasePrepared(
            intent: s83cIntent(expiresAt: DateTime.utc(2026, 9, 22, 14)),
          ),
        ),
        wallet: wallet,
      );
      await _fillAndSubmit(tester);
      await scrollToS7Section(tester, _key('launch-trade-sign'));
      await tester.tap(_key('launch-trade-sign'));
      await tester.pumpAndSettle();
      expect(find.textContaining('已过期'), findsOneWidget);
      expect(
        tester.widget<LoopSignSheet>(_key('launch-sign-sheet')).confirmEnabled,
        isFalse,
      );
      expect(wallet.handed, isEmpty);
    });
  });
}
