// S236 · client decision 0203 (S234-8): the wallet's Launch chain block
// draws the slot's USD1 under tBNB, and on a testnet slot says the total
// above counts the main chain only. The `launchChain` block is
// test/fixtures/s236/wallet_balances_launch_chain.json (see its `_derived`).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/loop_balance_visibility.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/test_hints.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Map<String, Object?> _launchChainWire() =>
    (jsonDecode(
          File('test/fixtures/s236/wallet_balances_launch_chain.json')
              .readAsStringSync(),
        ) as Map<String, Object?>)['launchChain']!
        as Map<String, Object?>;

LoopWalletBalances _balances(Map<String, Object?> launchChain) =>
    DioLoopV2WalletApi.decodeBalances(
      s5BalancesBody()..['launchChain'] = launchChain,
      walletId: s5WalletId,
    );

void main() {
  // S237 · decision 0204: these cases pin the testnet / specimen behaviour.
  loopShowTestHints();

  loopWatchGround();

  group('S236 · decision 0203 · Launch 链 tUSD1', () {
    test('the fixture decodes: tBNB and the USD1 pair', () {
      final slot = _balances(_launchChainWire()).launchChain!;
      expect(slot.isTestnet, isTrue);
      expect(slot.nativeBalance!.symbol, 'tBNB');
      expect(slot.usd1!.balance, '4850000000000000000000');
      expect(walletLaunchUsd1Symbol(slot), 'tUSD1');
      expect(walletLaunchUsd1Figure(slot.usd1!.balance).toString(), '4850');
      expect(walletLaunchUsd1Figure('1500000000000000').toString(), '0.0015');
    });

    testWidgets('the card draws tUSD1 under tBNB with the testnet badge and '
        'the main-chain note', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: _balances(_launchChainWire()),
          ),
        ),
      );
      await scrollToS5Section(tester, _key('wallet-launch-chain-total-note'));
      final row = _key('wallet-launch-chain-usd1-row');
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('tUSD1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('4,850')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.byKey(const ValueKey<String>('loop-testnet-badge')),
        ),
        findsOneWidget,
      );
      // tBNB is still there, above it.
      expect(_key('wallet-launch-chain-row'), findsOneWidget);
      expect(
        tester.getTopLeft(_key('wallet-launch-chain-row')).dy,
        lessThan(tester.getTopLeft(row).dy),
      );
      expect(find.text(walletLaunchChainTotalNote), findsOneWidget);
    });

    testWidgets('no usd1 key: no row, the note stays', (tester) async {
      final wire = _launchChainWire()..remove('usd1');
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(value: _balances(wire)),
        ),
      );
      await scrollToS5Section(tester, _key('wallet-launch-chain-total-note'));
      expect(_key('wallet-launch-chain-usd1-row'), findsNothing);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('an unavailable native read still shows the USD1 pair it '
        'carried, never a zero for tBNB', (tester) async {
      final wire = _launchChainWire()
        ..['availability'] = 'unavailable'
        ..['reasonCode'] = 'LAUNCH_CHAIN_RPC_NOT_CONFIGURED'
        ..['nativeBalance'] = null;
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(value: _balances(wire)),
        ),
      );
      await scrollToS5Section(tester, _key('wallet-launch-chain-usd1-row'));
      expect(_key('wallet-launch-chain-unavailable'), findsOneWidget);
      expect(_key('wallet-launch-chain-usd1-row'), findsOneWidget);
    });

    testWidgets('wallet page with 隐藏余额 on: both Launch 链 rows print ****', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          balances: S5Answer<LoopWalletBalances>(
            value: _balances(_launchChainWire()),
          ),
        ),
        overrides: <Override>[
          loopBalanceVisibilityStoreProvider.overrideWithValue(
            const _Hidden(true),
          ),
        ],
      );
      await scrollToS5Section(tester, _key('wallet-launch-chain-total-note'));
      for (final row in <String>[
        'wallet-launch-chain-row',
        'wallet-launch-chain-usd1-row',
      ]) {
        expect(
          find.descendant(
            of: _key(row),
            matching: find.text(walletMaskedFigure),
          ),
          findsOneWidget,
          reason: row,
        );
      }
      expect(find.text('4,850'), findsNothing);
      expect(find.text('2.5'), findsNothing);
    });

    testWidgets('隐藏余额 masks tBNB and tUSD1 together; the note stays', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: WalletLaunchChainCard(
              launchChain: _balances(_launchChainWire()).launchChain!,
              hidden: true,
            ),
          ),
        ),
      );
      expect(find.text('4,850'), findsNothing);
      expect(find.text('2.5'), findsNothing);
      expect(find.textContaining('2.495'), findsNothing);
      expect(
        find.descendant(
          of: _key('wallet-launch-chain-usd1-row'),
          matching: find.text(walletMaskedFigure),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _key('wallet-launch-chain-row'),
          matching: find.text(walletMaskedFigure),
        ),
        findsOneWidget,
      );
      expect(find.text('可动用 $walletMaskedFigure'), findsOneWidget);
      expect(
        find.text('Launch 链是 BSC 测试网余额，不计入总资产；总资产只统计 BNB Smart Chain 主网。'),
        findsOneWidget,
      );
    });

    testWidgets('a main-chain Launch slot: USD1, no note', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: WalletLaunchChainCard(
              launchChain: LoopLaunchChainBalance(
                chainId: 'eip155:56',
                available: false,
                reasonCode: 'LAUNCH_CHAIN_RPC_NOT_CONFIGURED',
                nativeBalance: null,
                usd1: const LoopLaunchUsd1Reading(
                  balance: '2000000000000000000',
                  allowance: '0',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('USD1'), findsOneWidget);
      expect(find.text('tUSD1'), findsNothing);
      expect(_key('wallet-launch-chain-total-note'), findsNothing);
    });
  });
}

final class _Hidden implements LoopBalanceVisibilityStore {
  const _Hidden(this.value);

  final bool? value;

  @override
  Future<bool?> readHideBalance() => Future<bool?>.value(value);

  @override
  Future<void> writeHideBalance(bool value) => Future<void>.value();
}
