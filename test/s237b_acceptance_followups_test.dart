// S237b · client decision 0208: the S237 acceptance follow-ups.
//
// A. 钱包「Launch 链」 USD1 keeps `launchChain.usd1` as its source (the 0 on
//    staging is loop-api reading the IDO contract's USD1, fixed server-side);
//    an absent pair prints 「—」 with its reason, never 0. The fixture under
//    test/fixtures/s237b/ is the real staging block (see its `_derived`).
// B. Leftover wording and the IDO chain block's screen-reader sentence.
// C. The LoopDynamic buy tax on the signing sheet matches the trade panel.
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

Map<String, Object?> _launchChainWire() =>
    _json(
          'test/fixtures/s237b/wallet_balances_launch_chain_ido_usd1.json',
        )['launchChain']!
        as Map<String, Object?>;

LoopLaunchChainBalance _slot(Map<String, Object?> wire) =>
    DioLoopV2WalletApi.decodeBalances(
      s5BalancesBody()..['launchChain'] = wire,
      walletId: s5WalletId,
    ).launchChain!;

/// The real block with the USD1 the wallet actually holds (the Hooks
/// Factory `usd1()` balance read on chain at the same time), i.e. what the
/// block says once loop-api reads that token.
Map<String, Object?> _factoryUsd1Wire() => _launchChainWire()
  ..['usd1'] = <String, Object?>{
    'balance': '2892006687595931906156',
    'allowance': '0',
  };

Future<void> _pumpWallet(WidgetTester tester, Map<String, Object?> wire) =>
    pumpS5Page(
      tester,
      const WalletScreen(),
      wallet: FakeWalletReadGateway(
        balances: S5Answer<LoopWalletBalances>(
          value: DioLoopV2WalletApi.decodeBalances(
            s5BalancesBody()..['launchChain'] = wire,
            walletId: s5WalletId,
          ),
        ),
      ),
    );

Widget _card(Map<String, Object?> wire, {bool hidden = false}) => MaterialApp(
  theme: LoopTheme.dark,
  home: Scaffold(
    body: WalletLaunchChainCard(launchChain: _slot(wire), hidden: hidden),
  ),
);

void main() {
  loopWatchGround();

  group('A · Launch 链 USD1 (decision 0208)', () {
    test('codec: the real staging block decodes; its usd1 is the IDO '
        "token's 0", () {
      final slot = _slot(_launchChainWire());
      expect(slot.chainId, 'eip155:97');
      expect(slot.nativeBalance!.displayBalance, Decimal.parse('0.0498699991'));
      expect(slot.usd1!.balance, '0');
      expect(walletLaunchUsd1Reason(slot), isNull);
    });

    test('reason: a pair has none; no pair on a read slot is 暂不可用, on a '
        'failed slot 读取失败', () {
      expect(walletLaunchUsd1Reason(_slot(_factoryUsd1Wire())), isNull);
      expect(
        walletLaunchUsd1Reason(_slot(_launchChainWire()..remove('usd1'))),
        walletLaunchUsd1Unavailable,
      );
      final failed = _launchChainWire()
        ..remove('usd1')
        ..['availability'] = 'unavailable'
        ..['reasonCode'] = 'LAUNCH_CHAIN_RPC_UNREACHABLE'
        ..['nativeBalance'] = null;
      expect(walletLaunchUsd1Reason(_slot(failed)), walletLaunchUsd1Failed);
    });

    testWidgets('card: a pair prints its figure, two decimals', (tester) async {
      await tester.pumpWidget(_card(_factoryUsd1Wire()));
      final row = _key('wallet-launch-chain-usd1-row');
      expect(
        find.descendant(of: row, matching: find.text('2,892.01')),
        findsOneWidget,
      );
      expect(_key('wallet-launch-chain-usd1-reason'), findsNothing);
    });

    testWidgets('card: the verbatim staging pair (balance "0") prints 0 '
        'with no reason line', (tester) async {
      await tester.pumpWidget(_card(_launchChainWire()));
      final row = _key('wallet-launch-chain-usd1-row');
      expect(find.descendant(of: row, matching: find.text('0')), findsOneWidget);
      expect(_key('wallet-launch-chain-usd1-reason'), findsNothing);
      expect(
        find.descendant(of: row, matching: find.text(walletLaunchUsd1Missing)),
        findsNothing,
      );
    });

    testWidgets('card: no pair prints 「—」 and the reason, never 0', (
      tester,
    ) async {
      await tester.pumpWidget(_card(_launchChainWire()..remove('usd1')));
      final row = _key('wallet-launch-chain-usd1-row');
      expect(
        find.descendant(of: row, matching: find.text(walletLaunchUsd1Missing)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text(walletLaunchUsd1Unavailable),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: row, matching: find.text('0')), findsNothing);

      final failed = _launchChainWire()
        ..remove('usd1')
        ..['availability'] = 'unavailable'
        ..['reasonCode'] = 'LAUNCH_CHAIN_RPC_UNREACHABLE'
        ..['nativeBalance'] = null;
      await tester.pumpWidget(_card(failed));
      expect(
        find.descendant(
          of: _key('wallet-launch-chain-usd1-row'),
          matching: find.text(walletLaunchUsd1Failed),
        ),
        findsOneWidget,
      );
    });

    testWidgets('card: 隐藏余额 masks a figure; 「—」 stays 「—」', (tester) async {
      await tester.pumpWidget(_card(_factoryUsd1Wire(), hidden: true));
      final row = _key('wallet-launch-chain-usd1-row');
      expect(
        find.descendant(of: row, matching: find.text(walletMaskedFigure)),
        findsOneWidget,
      );
      expect(find.text('2,892.01'), findsNothing);

      await tester.pumpWidget(
        _card(_launchChainWire()..remove('usd1'), hidden: true),
      );
      expect(
        find.descendant(
          of: _key('wallet-launch-chain-usd1-row'),
          matching: find.text(walletLaunchUsd1Missing),
        ),
        findsOneWidget,
      );
    });

    testWidgets('wallet page: the USD1 row reads launchChain.usd1', (
      tester,
    ) async {
      await _pumpWallet(tester, _factoryUsd1Wire());
      await scrollToS5Section(tester, _key('wallet-launch-chain-usd1-row'));
      expect(
        find.descendant(
          of: _key('wallet-launch-chain-usd1-row'),
          matching: find.text('2,892.01'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('wallet page: no pair, 「—」 暂不可用', (tester) async {
      await _pumpWallet(tester, _launchChainWire()..remove('usd1'));
      await scrollToS5Section(tester, _key('wallet-launch-chain-usd1-row'));
      expect(
        find.descendant(
          of: _key('wallet-launch-chain-usd1-row'),
          matching: find.text(walletLaunchUsd1Unavailable),
        ),
        findsOneWidget,
      );
    });
  });

  group('B · leftover wording (decision 0208)', () {
    test('名单核验中 and a neutral Launch contract sentence', () {
      expect(launch2ReasonText('LAUNCH2_SNAPSHOT_UNVERIFIED'), '名单核验中，提前购暂不可用');
      final text = launchReasonCodeText('LAUNCH_CONTRACT_VERIFICATION_PENDING');
      expect(text, isNot(contains('还在核对')));
      expect(text, contains('Launch 合约'));
    });

    testWidgets('the IDO chain block (and its screen-reader sentence) is '
        'behind the test-hints switch', (tester) async {
      debugSetLoopTestHintsVisible(false);
      addTearDown(() => debugSetLoopTestHintsVisible(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(body: LaunchChainBlock(testnet: true)),
        ),
      );
      expect(_key('launch-chain-block'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('eip155:97')), findsNothing);

      debugSetLoopTestHintsVisible(true);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: LaunchChainBlock(testnet: true, notice: false),
          ),
        ),
      );
      expect(_key('launch-chain-block'), findsOneWidget);
    });
  });

  group('C · outer-pool buy tax, one source (decision 0208)', () {
    /// A pool prepare whose quote is an S209 LoopDynamic buy taking its 2%
    /// out of the 5 USD1 paid in (S237 acceptance: S227W, buy 5 USD1). The
    /// intent is the S146 pool-buy intent (its `taxUsd1` is 0, as loop-api
    /// writes it on every buy); the quote is the S168b dynamic buy quote
    /// with the S209 fields and the intent's router.
    Map<String, Object?> preparedBody() {
      final prepared =
          _json(
                'test/fixtures/s146-launch2-pool/pool_prepare_buy_approval.json',
              )['body']!
              as Map<String, Object?>;
      final quote =
          (_json(
                    'test/fixtures/s168b-launch2-dynamic/pool_quote_buy_dynamic.json',
                  )['body']!
                  as Map<String, Object?>)['quote']!
              as Map<String, Object?>;
      final intent = prepared['launch2Intent']! as Map<String, Object?>;
      quote
        ..['router'] = intent['contractAddress']
        ..['taxAmount'] = '0.1'
        ..['taxToken'] = 'usd1'
        ..['taxUsd1'] = '0.1';
      (quote['dynamic']! as Map<String, Object?>)
        ..['baseTaxAmount'] = '0.1'
        ..['baseTaxToken'] = 'usd1';
      expect(intent['taxUsd1'], '0');
      return <String, Object?>{
        'launch2Intent': intent,
        'quote': quote,
        'contractVersion': prepared['contractVersion'],
      };
    }

    test('the sheet shows the quote figure and the panel label', () {
      final quoteBody = preparedBody()['quote']! as Map<String, Object?>;
      final prepared = LoopV2Launch2PoolCodec.prepared(
        preparedBody(),
        instanceId: quoteBody['instanceId']! as String,
        side: Launch2Side.buy,
        mode: Launch2PoolMode.exactIn,
        walletId: quoteBody['walletId']! as String,
      );
      expect(prepared.intent.taxUsd1, Decimal.parse('0.1'));
      expect(prepared.intent.dynamicBuyTaxToken, Launch2PoolTaxToken.usd1);

      final panel = launch2PoolQuoteLines(
        prepared.quote,
        'S227W',
      ).firstWhere((line) => line.key == 'tax');
      final sheet = launch2IntentFields(
        prepared.intent,
        ticker: 'S227W',
      ).firstWhere((field) => field.label.contains('税'));
      expect(panel.label, '基础税 2%（从付出的 USD1 扣）');
      expect(sheet.label, panel.label);
      expect(sheet.value, panel.value);
      expect(sheet.value, '0.1 USD1');
    });

    test('a plain pool buy keeps 外盘税 in MEME', () {
      final prepared =
          _json(
                'test/fixtures/s146-launch2-pool/pool_prepare_buy_approval.json',
              )['body']!
              as Map<String, Object?>;
      final quote = prepared['quote']! as Map<String, Object?>;
      final plain = LoopV2Launch2PoolCodec.prepared(
        prepared,
        instanceId: quote['instanceId']! as String,
        side: Launch2Side.buy,
        mode: Launch2PoolMode.exactIn,
        walletId: quote['walletId']! as String,
      );
      expect(plain.intent.dynamicBuyTaxToken, isNull);
      final field = launch2IntentFields(
        plain.intent,
        ticker: 'FROG',
      ).firstWhere((field) => field.label.contains('税'));
      expect(field.label, '外盘税 2%');
      expect(field.value, isNot(contains('USD1')));
    });
  });
}
