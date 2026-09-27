import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_signing.dart';
import 'package:loop_mobile/features/launch/launch_trade_screen.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_signing.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s83c_fixtures.dart';

/// Decision 0094 · three findings from the first device purchase on the
/// Launch testnet (sale 5, 2026-09-27): the round selector drifting after a
/// prepared intent, the open-round eligibility wording, and the 我的参与记录
/// row subtitle. Every value is 测试专用.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const _roundTwoId = '1c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f';

bool _selected(WidgetTester tester, String key) =>
    tester.widget<LoopRecordRow>(_key(key)).selected;

Future<FakeLaunchGateway> _pumpTrade(
  WidgetTester tester, {
  Completer<void>? gate,
}) async {
  final gateway = FakeLaunchGateway(
    detail: S7Answer<LaunchDetail>(
      value: s83cDetail(chainId: loopLaunchTestnetChainId),
    ),
    prepared: LaunchPurchasePrepared(
      intent: s83cIntent(chainId: loopLaunchTestnetChainId),
    ),
    prepareGate: gate,
  );
  await pumpS7Page(
    tester,
    LaunchTradeScreen(launchId: s7LaunchId, clock: s83cNow),
    launch: gateway,
    wallet: FakeWalletDirectory(
      activeWalletId: s7WalletId,
      wallets: [s83cWallet()],
      balances: [s83cBalances(chainId: loopLaunchTestnetChainId)],
    ),
    meta: s7MetaSnapshot(launchEvidencePending: false),
  );
  return gateway;
}

Future<void> _chooseAndSubmit(
  WidgetTester tester, {
  String round = 'launch-round-1',
  bool settle = true,
}) async {
  await tester.tap(_key(round));
  await tester.pumpAndSettle();
  await tester.enterText(_key('launch-trade-amount'), '500');
  await tester.pumpAndSettle();
  await scrollToS7Section(tester, _key('launch-trade-submit'));
  await tester.tap(_key('launch-trade-submit'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _tapRound(WidgetTester tester, String key) async {
  await scrollToS7Section(tester, _key(key));
  await tester.tap(_key(key), warnIfMissed: false);
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(LaunchTradeScreen)));

LaunchEligibility _openEligibility() => LaunchEligibility(
  launchId: s7LaunchId,
  mode: LaunchEligibilityMode.whitelist,
  result: LaunchEligibilityEvaluated(
    tierWireName: 'public',
    reasonCode: null,
    snapshotBlock: '45000000',
    roundIndex: 2,
    allowlistRoot: LaunchChainRound.zeroRoot,
    eligibilityProof: const <String>[],
  ),
  configVersion: 'launchMoonCatV1',
  effectiveAt: DateTime.utc(2026, 9, 8, 1),
  dependsOnStaking: false,
);

Future<void> _pumpDetail(
  WidgetTester tester, {
  S7Answer<LaunchEligibility>? eligibility,
  S7Answer<LaunchHistory>? history,
}) => pumpS7Page(
  tester,
  const LaunchDetailScreen(launchId: s7LaunchId),
  launch: FakeLaunchGateway(
    detail: S7Answer<LaunchDetail>(value: s83cDetail()),
    eligibility: eligibility,
    history: history,
  ),
);

String? _subtitle(WidgetTester tester, String key) =>
    tester.widget<LoopRecordRow>(_key(key)).subtitle;

void main() {
  loopWatchGround();

  group('launch-trade · the round is fixed once an intent exists', () {
    testWidgets('a prepared intent locks the selector; 重新报价 unlocks it', (
      tester,
    ) async {
      await _pumpTrade(tester);
      await _chooseAndSubmit(tester);

      expect(_key('launch-trade-review'), findsOneWidget);
      expect(find.text('本次认购：Round 1'), findsOneWidget);
      expect(
        tester.widget<LoopRecordRow>(_key('launch-round-2')).onTap,
        isNull,
      );

      // A tap on another round does nothing while the intent stands.
      await _tapRound(tester, 'launch-round-2');
      expect(_selected(tester, 'launch-round-1'), isTrue);
      expect(_selected(tester, 'launch-round-2'), isFalse);
      expect(find.text('本次认购：Round 1'), findsOneWidget);

      // 「重新报价」 drops the intent and the selector opens again.
      await scrollToS7Section(tester, _key('launch-trade-discard'));
      await tester.tap(_key('launch-trade-discard'));
      await tester.pumpAndSettle();
      expect(_key('launch-trade-round-locked'), findsNothing);
      await _tapRound(tester, 'launch-round-2');
      expect(_selected(tester, 'launch-round-2'), isTrue);
      expect(_selected(tester, 'launch-round-1'), isFalse);
    });

    testWidgets(
      'a round tapped while the intent is being prepared is ignored',
      (tester) async {
        final gate = Completer<void>();
        final gateway = await _pumpTrade(tester, gate: gate);
        await _chooseAndSubmit(tester, settle: false);
        await tester.pump();

        expect(gateway.intents, <String>['$s7LaunchId:$s7RoundId:500']);
        expect(find.text('本次认购：Round 1'), findsOneWidget);
        await _tapRound(tester, 'launch-round-2');
        expect(_selected(tester, 'launch-round-2'), isFalse);

        gate.complete();
        await tester.pumpAndSettle();
        expect(_selected(tester, 'launch-round-1'), isTrue);
        expect(_selected(tester, 'launch-round-2'), isFalse);
      },
    );

    testWidgets('the highlight follows the intent, never a stale selection', (
      tester,
    ) async {
      // The server's intent names Round 1 even though Round 2 was chosen:
      // the page shows the round the review and the chain will show.
      final gateway = await _pumpTrade(tester);
      await _chooseAndSubmit(tester, round: 'launch-round-2');
      expect(gateway.intents, <String>['$s7LaunchId:$_roundTwoId:500']);
      expect(_selected(tester, 'launch-round-1'), isTrue);
      expect(_selected(tester, 'launch-round-2'), isFalse);
      expect(find.text('本次认购：Round 1'), findsOneWidget);
    });

    testWidgets('a broadcast shows an in-flight line until the state moves', (
      tester,
    ) async {
      await _pumpTrade(tester);
      await _chooseAndSubmit(tester);
      expect(_key('launch-trade-in-flight'), findsNothing);

      final controller = _container(tester)
          .read(launchTradeControllerProvider.notifier);
      controller.recordSignOutcome(
        LaunchSignOutcome(
          status: MoneySignStatus.submitted,
          reasonCode: '',
          txHash: s83cTxHash,
          reported: s83cIntent(
            chainId: loopLaunchTestnetChainId,
            state: LaunchIntentState.submitted,
            transactionHash: s83cTxHash,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final banner = tester.widget<LoopNotice>(_key('launch-trade-in-flight'));
      expect(banner.title, '已广播，等待链上索引');
      expect(banner.body, contains('Round 1'));
      expect(banner.body, contains('广播不代表已成交'));
      expect(find.text('本次认购：Round 1'), findsOneWidget);
      await _tapRound(tester, 'launch-round-2');
      expect(_selected(tester, 'launch-round-2'), isFalse);
      // A broadcast attempt is never discarded.
      controller.discard();
      await tester.pumpAndSettle();
      expect(_key('launch-trade-in-flight'), findsOneWidget);

      controller.recordSignOutcome(
        LaunchSignOutcome(
          status: MoneySignStatus.submitted,
          reasonCode: '',
          txHash: s83cTxHash,
          reported: s83cIntent(
            chainId: loopLaunchTestnetChainId,
            state: LaunchIntentState.confirmed,
            transactionHash: s83cTxHash,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<LoopNotice>(_key('launch-trade-in-flight')).title,
        '已广播 · 已确认',
      );
    });
  });

  group('eligibility · the open branch is a public round', () {
    testWidgets('launch-detail says 公开轮 for the server open branch', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        eligibility: S7Answer<LaunchEligibility>(value: _openEligibility()),
      );
      expect(_subtitle(tester, 'launch-detail-open-tier'), '公开轮 · 无需资格');
    });

    testWidgets('launch-detail keeps 待确认 while no evaluator answered', (
      tester,
    ) async {
      await _pumpDetail(tester);
      expect(
        _subtitle(tester, 'launch-detail-open-tier'),
        '资格结果 $launchPendingConfirmationLabel · 由这次发射的资格模式决定',
      );
    });

    testWidgets('launch-detail states a listed round by its result', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        eligibility: S7Answer<LaunchEligibility>(value: s83cEligibility()),
      );
      expect(
        _subtitle(tester, 'launch-detail-open-tier'),
        'Round 1 · Priority',
      );
    });

    testWidgets('launch-tier says the round is open, never 待确认', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchTierScreen(launchId: s7LaunchId),
        launch: FakeLaunchGateway(
          eligibility: S7Answer<LaunchEligibility>(value: _openEligibility()),
        ),
      );
      expect(find.text('公开轮'), findsOneWidget);
      expect(find.text('本轮公开，任何钱包都可参与。'), findsOneWidget);
      expect(find.textContaining(launchPendingConfirmationLabel), findsNothing);
      expect(find.text('Public'), findsNothing);
    });
  });

  group('launch-detail · 我的参与记录 follows the history resource', () {
    testWidgets('indexed with records: count and latest time', (tester) async {
      await _pumpDetail(
        tester,
        history: S7Answer<LaunchHistory>(value: s83cHistory()),
      );
      expect(
        _subtitle(tester, 'launch-detail-open-history'),
        '1 笔认购 · 最近 ${launchTimestampLabel(DateTime.utc(2026, 9, 22, 14, 2))}',
      );
    });

    testWidgets('indexed and empty: the indexed block', (tester) async {
      await _pumpDetail(
        tester,
        history: S7Answer<LaunchHistory>(value: s83cHistory(empty: true)),
      );
      expect(
        _subtitle(tester, 'launch-detail-open-history'),
        '暂无记录（已索引到区块 45,000,100）',
      );
    });

    testWidgets('unavailable source keeps the reminder', (tester) async {
      await _pumpDetail(tester);
      expect(_subtitle(tester, 'launch-detail-open-history'), '空列表不代表你没有参与');
    });

    testWidgets('a failed history read keeps the reminder', (tester) async {
      await _pumpDetail(
        tester,
        history: S7Answer<LaunchHistory>(failure: LaunchFailureKind.offline),
      );
      expect(_subtitle(tester, 'launch-detail-open-history'), '空列表不代表你没有参与');
      // The sibling rows still render.
      expect(_key('launch-detail-open-tier'), findsOneWidget);
    });
  });
}
