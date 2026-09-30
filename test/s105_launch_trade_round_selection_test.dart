import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/chain/loop_chain_ids.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_trade_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/loop_ground_probe.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/s83c_fixtures.dart';

/// Decision 0109 · S105 (= S83c4): `launch-trade` stands on the round inside
/// its window, re-reckons it when the detail is read again or a round
/// boundary passes, refuses a round outside its window, and highlights the
/// very round it submits. The rounds replay sale 8 on the testnet
/// (2026-09-30): Round 1 09:25:13–09:28:13Z, Round 2 09:28:13–09:31:13Z.
/// Every value is 测试专用.

Finder _key(String value) => find.byKey(ValueKey<String>(value));

const _roundTwoId = '1c2d3e4f-5a6b-4c7d-8e9f-0a1b2c3d4e5f';

final _r1Start = DateTime.utc(2026, 9, 30, 9, 25, 13);
final _r1End = DateTime.utc(2026, 9, 30, 9, 28, 13);
final _r2End = DateTime.utc(2026, 9, 30, 9, 31, 13);

LaunchChainRound _round(int index, String id, DateTime start, DateTime end) =>
    LaunchChainRound(
      roundId: id,
      roundIndex: index,
      startAt: start,
      endAt: end,
      priceUsd1PerToken: '10000000000000000',
      roundCapUsd1: '40000000000000000000000',
      walletRoundCapUsd1: '500000000000000000000',
      allowlistRoot: LaunchChainRound.zeroRoot,
      raisedUsd1: '0',
    );

final _rounds = <LaunchChainRound>[
  _round(1, s7RoundId, _r1Start, _r1End),
  _round(2, _roundTwoId, _r1End, _r2End),
];

/// A clock the test moves by hand.
final class _Clock {
  _Clock(this.now);
  DateTime now;
  DateTime call() => now;
}

Future<FakeLaunchGateway> _pumpTrade(WidgetTester tester, _Clock clock) async {
  final gateway = FakeLaunchGateway(
    detail: S7Answer<LaunchDetail>(
      value: s83cDetail(chainId: loopLaunchTestnetChainId, rounds: _rounds),
    ),
    prepared: LaunchPurchasePrepared(
      intent: s83cIntent(chainId: loopLaunchTestnetChainId),
    ),
  );
  await pumpS7Page(
    tester,
    LaunchTradeScreen(launchId: s7LaunchId, clock: clock.call),
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

bool _selected(WidgetTester tester, String key) =>
    tester.widget<LoopRecordRow>(_key(key)).selected;

String? _caption(WidgetTester tester, String key) =>
    tester.widget<LoopRecordRow>(_key(key)).trailingCaption;

/// The round rows that read 已选择 — there is never more than one.
List<int> _highlighted(WidgetTester tester) => <int>[
  for (final index in <int>[1, 2])
    if (_selected(tester, 'launch-round-$index')) index,
];

VoidCallback? _submit(WidgetTester tester) =>
    tester.widget<LoopButton>(_key('launch-trade-submit')).onPressed;

String? _refusal(WidgetTester tester) =>
    tester.widget<LoopNotice>(_key('launch-trade-refusal')).body;

Future<void> _typeAmount(WidgetTester tester) async {
  await scrollToS7Section(tester, _key('launch-trade-amount'));
  await tester.enterText(_key('launch-trade-amount'), '500');
  await tester.pumpAndSettle();
}

Future<void> _tapRound(WidgetTester tester, String key) async {
  await scrollToS7Section(tester, _key(key));
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

Future<void> _pressSubmit(WidgetTester tester) async {
  await scrollToS7Section(tester, _key('launch-trade-submit'));
  await tester.tap(_key('launch-trade-submit'));
  await tester.pumpAndSettle();
}

Future<void> _reloadDetail(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LaunchTradeScreen)),
  );
  await container.read(launchDetailControllerProvider.notifier).reload();
  await tester.pumpAndSettle();
}

void main() {
  loopWatchGround();

  group('launchTradeDefaultRound', () {
    test('the round inside its window', () {
      final round = launchTradeDefaultRound(
        _rounds,
        DateTime.utc(2026, 9, 30, 9, 29, 56),
      );
      expect(round?.roundIndex, 2);
    });

    test('the next round to open before the sale, never an ended one', () {
      expect(
        launchTradeDefaultRound(
          _rounds,
          DateTime.utc(2026, 9, 30, 9, 20),
        )?.roundIndex,
        1,
      );
      expect(launchTradeDefaultRound(_rounds, _r2End), isNull);
    });

    test('a round LOOP has no record of is never chosen', () {
      final rounds = <LaunchChainRound>[
        LaunchChainRound(
          roundId: null,
          roundIndex: 1,
          startAt: _r1Start,
          endAt: _r1End,
          priceUsd1PerToken: '1',
          roundCapUsd1: '1',
          walletRoundCapUsd1: '1',
          allowlistRoot: LaunchChainRound.zeroRoot,
          raisedUsd1: '0',
        ),
        _rounds[1],
      ];
      expect(
        launchTradeDefaultRound(
          rounds,
          DateTime.utc(2026, 9, 30, 9, 26),
        )?.roundIndex,
        2,
      );
    });
  });

  group('launch-trade · the round follows the window', () {
    testWidgets('the round in its window is chosen without a tap', (
      tester,
    ) async {
      final clock = _Clock(DateTime.utc(2026, 9, 30, 9, 26));
      final gateway = await _pumpTrade(tester, clock);

      expect(_highlighted(tester), <int>[1]);
      expect(_caption(tester, 'launch-round-1'), '已选择');
      await _typeAmount(tester);
      expect(_submit(tester), isNotNull);
      await _pressSubmit(tester);
      expect(gateway.intents, <String>['$s7LaunchId:$s7RoundId:500']);
    });

    testWidgets('a re-read after Round 1 ended moves the selection on', (
      tester,
    ) async {
      // The device case: chosen while Round 1 ran, bought after it ended.
      final clock = _Clock(DateTime.utc(2026, 9, 30, 9, 27));
      final gateway = await _pumpTrade(tester, clock);
      expect(_highlighted(tester), <int>[1]);

      clock.now = DateTime.utc(2026, 9, 30, 9, 29, 56);
      await _reloadDetail(tester);

      expect(_highlighted(tester), <int>[2]);
      await _typeAmount(tester);
      await _pressSubmit(tester);
      // The row that reads 已选择 is the round that went to the server.
      expect(gateway.intents, <String>['$s7LaunchId:$_roundTwoId:500']);
    });

    testWidgets('the page re-reckons at the boundary without a network read', (
      tester,
    ) async {
      final clock = _Clock(DateTime.utc(2026, 9, 30, 9, 26));
      final gateway = await _pumpTrade(tester, clock);
      await _typeAmount(tester);
      expect(_highlighted(tester), <int>[1]);
      final reads = gateway.requestedLaunchIds.length;

      clock.now = _r1End;
      await tester.pump(_r1End.difference(DateTime.utc(2026, 9, 30, 9, 26)));
      await tester.pumpAndSettle();

      expect(_highlighted(tester), <int>[2]);
      expect(_submit(tester), isNotNull);
      expect(gateway.requestedLaunchIds.length, reads);
    });

    testWidgets('a round chosen before it opens is shown, never submitted', (
      tester,
    ) async {
      final clock = _Clock(DateTime.utc(2026, 9, 30, 9, 26));
      final gateway = await _pumpTrade(tester, clock);
      await _typeAmount(tester);
      await _tapRound(tester, 'launch-round-2');

      expect(_highlighted(tester), <int>[2]);
      expect(_submit(tester), isNull);
      expect(_refusal(tester), 'Round 2 尚未开始，2026-09-30 09:28 UTC 开放后才能认购。');
      await _pressSubmit(tester);
      expect(gateway.intents, isEmpty);

      // Once it opens, the same round is the one that goes out.
      clock.now = _r1End;
      await tester.pump(const Duration(minutes: 3));
      await tester.pumpAndSettle();
      expect(_highlighted(tester), <int>[2]);
      expect(_submit(tester), isNotNull);
      await _pressSubmit(tester);
      expect(gateway.intents, <String>['$s7LaunchId:$_roundTwoId:500']);
    });

    testWidgets('an ended round chosen by hand keeps 买入 closed', (
      tester,
    ) async {
      final clock = _Clock(DateTime.utc(2026, 9, 30, 9, 29));
      final gateway = await _pumpTrade(tester, clock);
      expect(_highlighted(tester), <int>[2]);
      await _typeAmount(tester);
      await _tapRound(tester, 'launch-round-1');

      expect(_highlighted(tester), <int>[1]);
      expect(_submit(tester), isNull);
      expect(_refusal(tester), 'Round 1 已于 2026-09-30 09:28 UTC 结束，请选择进行中的轮次。');
      await _pressSubmit(tester);
      expect(gateway.intents, isEmpty);
    });

    testWidgets('before the sale the first round is shown but closed', (
      tester,
    ) async {
      final clock = _Clock(DateTime.utc(2026, 9, 30, 9, 20));
      await _pumpTrade(tester, clock);
      await _typeAmount(tester);

      expect(_highlighted(tester), <int>[1]);
      expect(_submit(tester), isNull);
      expect(_refusal(tester), 'Round 1 尚未开始，2026-09-30 09:25 UTC 开放后才能认购。');
    });
  });
}
