// S237b · client decision 0208: the S237 acceptance follow-ups.
//
// A. 钱包「Launch 链」 USD1 read the hidden IDO contract's USD1
//    (`launchChain.usd1`, 0 on staging) instead of the MEME v2 USD1 the
//    wallet actually holds. Both fixtures under test/fixtures/s237b/ are
//    the real staging responses for the demo account (see their `_derived`).
// B. Leftover wording and the IDO chain block's screen-reader sentence.
// C. The LoopDynamic buy tax on the signing sheet matches the trade panel.
import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_widgets.dart';
import 'package:loop_mobile/features/launch2/launch2_format.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_models.dart';
import 'package:loop_mobile/features/launch2/launch2_pool_view_model.dart';
import 'package:loop_mobile/features/launch2/launch2_signing.dart';
import 'package:loop_mobile/features/launch2/launch2_wallet_rows.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_pool_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/wallet/loop_v2_wallet_api.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Map<String, Object?> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

/// The staging wallet id both real responses carry.
const String _stagingWalletId = '4b1f36d8-0884-49ca-a2e2-a8519a352cef';

Map<String, Object?> _launchChainWire() =>
    _json(
          'test/fixtures/s237b/wallet_balances_launch_chain_ido_usd1.json',
        )['launchChain']!
        as Map<String, Object?>;

/// The real `me/positions` body, re-keyed to [walletId].
Map<String, Object?> _positionsBody({String walletId = _stagingWalletId}) {
  final body =
      _json('test/fixtures/s237b/launch2_positions_wanfeng.json')['body']!
          as Map<String, Object?>;
  for (final item in body['positions']! as List<Object?>) {
    (item! as Map<String, Object?>)['walletId'] = walletId;
  }
  return body;
}

Launch2Positions _positions({String walletId = _stagingWalletId}) =>
    LoopV2Launch2Codec.positions(
      _positionsBody(walletId: walletId),
      mediaUrl: (_) => null,
    );

LoopChainResourceState<Launch2Positions> _ready(Launch2Positions value) =>
    LoopChainResourceState<Launch2Positions>(
      mode: LoopChainGatewayMode.production,
      phase: LoopChainViewPhase.ready,
      value: value,
    );

LoopChainResourceState<Launch2Positions> _phase(LoopChainViewPhase phase) =>
    LoopChainResourceState<Launch2Positions>(
      mode: LoopChainGatewayMode.production,
      phase: phase,
    );

/// A MEME v2 port that only answers `me/positions`.
final class _PositionsOnly implements Launch2Gateway {
  _PositionsOnly(this.answer);

  final Future<Launch2Positions> Function() answer;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.preview;

  @override
  Future<Launch2Positions> loadPositions() => answer();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

Future<void> _pumpWallet(
  WidgetTester tester,
  Future<Launch2Positions> Function() positions,
) => pumpS5Page(
  tester,
  const WalletScreen(),
  wallet: FakeWalletReadGateway(
    balances: S5Answer<LoopWalletBalances>(
      value: DioLoopV2WalletApi.decodeBalances(
        s5BalancesBody()..['launchChain'] = _launchChainWire(),
        walletId: s5WalletId,
      ),
    ),
  ),
  overrides: <Override>[
    launch2GatewayProvider.overrideWithValue(_PositionsOnly(positions)),
    loopFeatureSwitchesProvider.overrideWithValue(
      const LoopFeatureSwitchValues(launch2Visible: true),
    ),
  ],
);

Widget _card(WalletLaunchUsd1 usd1, {bool hidden = false}) => MaterialApp(
  theme: LoopTheme.dark,
  home: Scaffold(
    body: WalletLaunchChainCard(
      launchChain: DioLoopV2WalletApi.decodeBalances(
        s5BalancesBody()..['launchChain'] = _launchChainWire(),
        walletId: s5WalletId,
      ).launchChain!,
      usd1: usd1,
      hidden: hidden,
    ),
  ),
);

void main() {
  loopWatchGround();

  group('A · Launch 链 USD1 (decision 0208)', () {
    test('codec: the real balances block decodes; its usd1 is the IDO '
        "token's 0", () {
      final slot = DioLoopV2WalletApi.decodeBalances(
        s5BalancesBody()..['launchChain'] = _launchChainWire(),
        walletId: s5WalletId,
      ).launchChain!;
      expect(slot.chainId, 'eip155:97');
      expect(slot.nativeBalance!.displayBalance, Decimal.parse('0.0498699991'));
      expect(slot.usd1!.balance, '0');
    });

    test('codec: the real positions carry the MEME v2 USD1 at one block', () {
      final positions = _positions();
      expect(positions.items, hasLength(3));
      final read = positions.items
          .where((p) => p.holding?.balancesRead ?? false)
          .toList();
      expect(read, hasLength(2));
      for (final position in read) {
        expect(
          position.holding!.usd1Balance,
          Decimal.parse('2892.006687595931906156'),
        );
        expect(position.holding!.blockNumber, BigInt.from(137710132));
      }
    });

    test('resolver: a read holding wins; phases without a value give a '
        'reason, never a zero', () {
      final read = launch2WalletUsd1Of(
        _ready(_positions()),
        walletId: _stagingWalletId,
      );
      expect(read.balance, Decimal.parse('2892.006687595931906156'));
      expect(read.reason, isNull);

      // Another wallet's positions are not this wallet's balance.
      final other = launch2WalletUsd1Of(
        _ready(_positions()),
        walletId: s5WalletId,
      );
      expect(other.balance, isNull);
      expect(other.reason, walletLaunchUsd1NoReading);

      expect(
        launch2WalletUsd1Of(
          _ready(const Launch2Positions(items: <Launch2Position>[])),
          walletId: _stagingWalletId,
        ).reason,
        walletLaunchUsd1NoReading,
      );
      final cases = <LoopChainViewPhase, String>{
        LoopChainViewPhase.loading: walletLaunchUsd1Loading,
        LoopChainViewPhase.empty: walletLaunchUsd1NoReading,
        LoopChainViewPhase.error: walletLaunchUsd1Failed,
        LoopChainViewPhase.offline: walletLaunchUsd1Failed,
        LoopChainViewPhase.permission: walletLaunchUsd1Failed,
        LoopChainViewPhase.unavailable: walletLaunchUsd1Closed,
      };
      cases.forEach((phase, reason) {
        final value = launch2WalletUsd1Of(
          _phase(phase),
          walletId: _stagingWalletId,
        );
        expect(value.balance, isNull, reason: '$phase');
        expect(value.reason, reason, reason: '$phase');
      });
    });

    testWidgets('card: a reading prints the figure, two decimals', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(WalletLaunchUsd1.read(Decimal.parse('2892.0066875959'))),
      );
      final row = _key('wallet-launch-chain-usd1-row');
      expect(
        find.descendant(of: row, matching: find.text('2,892.01')),
        findsOneWidget,
      );
      expect(_key('wallet-launch-chain-usd1-reason'), findsNothing);
    });

    testWidgets('card: no reading prints 「—」 and the reason, never 0', (
      tester,
    ) async {
      for (final reason in <String>[
        walletLaunchUsd1Loading,
        walletLaunchUsd1Failed,
        walletLaunchUsd1Closed,
        walletLaunchUsd1NoReading,
      ]) {
        await tester.pumpWidget(_card(WalletLaunchUsd1.missing(reason)));
        final row = _key('wallet-launch-chain-usd1-row');
        expect(
          find.descendant(
            of: row,
            matching: find.text(walletLaunchUsd1Missing),
          ),
          findsOneWidget,
          reason: reason,
        );
        expect(
          find.descendant(of: row, matching: find.text(reason)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text('0')),
          findsNothing,
        );
      }
    });

    testWidgets('card: 隐藏余额 masks a reading', (tester) async {
      await tester.pumpWidget(
        _card(WalletLaunchUsd1.read(Decimal.fromInt(2892)), hidden: true),
      );
      expect(
        find.descendant(
          of: _key('wallet-launch-chain-usd1-row'),
          matching: find.text(walletMaskedFigure),
        ),
        findsOneWidget,
      );
      expect(find.text('2,892'), findsNothing);
    });

    testWidgets('wallet page (ready): the IDO 0 is gone, the MEME v2 USD1 '
        'from me/positions is drawn', (tester) async {
      await _pumpWallet(tester, () async => _positions(walletId: s5WalletId));
      await scrollToS5Section(tester, _key('wallet-launch-chain-usd1-row'));
      final row = _key('wallet-launch-chain-usd1-row');
      expect(
        find.descendant(of: row, matching: find.text('2,892.01')),
        findsOneWidget,
      );
      expect(find.descendant(of: row, matching: find.text('0')), findsNothing);
    });

    testWidgets('wallet page (error): 「—」 with 读取失败', (tester) async {
      await _pumpWallet(
        tester,
        () async =>
            throw const LoopChainException(LoopChainFailureKind.readFailed),
      );
      await scrollToS5Section(tester, _key('wallet-launch-chain-usd1-row'));
      final row = _key('wallet-launch-chain-usd1-row');
      expect(
        find.descendant(of: row, matching: find.text(walletLaunchUsd1Missing)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text(walletLaunchUsd1Failed)),
        findsOneWidget,
      );
    });

    testWidgets('wallet page (offline): 「—」 with 读取失败', (tester) async {
      await _pumpWallet(
        tester,
        () async =>
            throw const LoopChainException(LoopChainFailureKind.offline),
      );
      await scrollToS5Section(tester, _key('wallet-launch-chain-usd1-row'));
      expect(
        find.descendant(
          of: _key('wallet-launch-chain-usd1-row'),
          matching: find.text(walletLaunchUsd1Failed),
        ),
        findsOneWidget,
      );
    });

    testWidgets('wallet page (empty): no graduated holding, 「—」 with the '
        'reason', (tester) async {
      await _pumpWallet(
        tester,
        () async => const Launch2Positions(items: <Launch2Position>[]),
      );
      await scrollToS5Section(tester, _key('wallet-launch-chain-usd1-row'));
      expect(
        find.descendant(
          of: _key('wallet-launch-chain-usd1-row'),
          matching: find.text(walletLaunchUsd1NoReading),
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
