// S259 · decision 0217: 需求方走查 — the MEME Tab is the v2 desk alone, and
// the wallet's asset area is 「代币 / NFT」 with no zero rows and no fold.

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_routes.dart';
import 'package:loop_mobile/features/wallet/wallet_home_widgets.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/launch2_fixtures.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

/// Answers `me/positions` only; every other read is not this test's.
final class _Positions implements Launch2Gateway {
  _Positions(this.answer);

  final Future<Launch2Positions> Function() answer;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Positions> loadPositions() => answer();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

LoopV2MetaSnapshot _metaWithLaunch2() {
  final base = s5MetaSnapshot();
  final launch2 = LoopV2Capability(
    id: LoopV2CapabilityId.launch2,
    availability: LoopV2CapabilityAvailability.available,
    reasonCode: null,
    evidence: const LoopV2CapabilityEvidence(
      status: LoopV2CapabilityEvidenceStatus.notApplicable,
      reasonCode: null,
    ),
  );
  final listed = base.capabilities.capabilities.any(
    (capability) => capability.id == LoopV2CapabilityId.launch2,
  );
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: base.capabilities.contractVersion,
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          capability.id == LoopV2CapabilityId.launch2 ? launch2 : capability,
        if (!listed) launch2,
      ],
    ),
  );
}

LoopLaunchChainBalance _launchChain({required String native}) =>
    LoopLaunchChainBalance(
      chainId: 'eip155:97',
      available: true,
      reasonCode: null,
      nativeBalance: LoopLaunchChainNativeBalance(
        assetId: 'eip155:97/slip44:714',
        symbol: 'tBNB',
        decimals: 18,
        rawValue: '0',
        displayBalance: Decimal.parse(native),
        availableBalance: Decimal.parse(native),
        spendableBalance: Decimal.parse(native),
        gasReserve: Decimal.parse('0.005'),
        snapshot: LoopBalanceSnapshot(
          blockNumber: BigInt.from(5000),
          blockHash: s5BlockHash,
          observedAt: DateTime.utc(2026, 9, 8, 5, 12),
          confirmations: 3,
        ),
      ),
      usd1: const LoopLaunchUsd1Reading(
        balance: '120000000000000000000',
        allowance: '0',
      ),
    );

LoopAssetBalanceRow _zeroWbnb() => s5Row(
  assetId: s5WbnbAssetId,
  balance: LoopBalanceAvailable(
    rawValue: '0',
    displayBalance: Decimal.zero,
    availableBalance: Decimal.zero,
    spendableBalance: Decimal.zero,
    gasReserve: Decimal.zero,
  ),
);

Future<void> _pumpWallet(
  WidgetTester tester, {
  LoopWalletBalances? balances,
  Launch2Gateway? launch2,
  void Function(String)? onNavigate,
  bool settle = true,
}) => pumpS5Page(
  tester,
  WalletScreen(onNavigate: onNavigate),
  wallet: FakeWalletReadGateway(
    balances: S5Answer<LoopWalletBalances>(value: balances ?? s5Balances()),
  ),
  meta: launch2 == null ? null : _metaWithLaunch2(),
  settle: settle,
  overrides: <Override>[
    if (launch2 != null) launch2GatewayProvider.overrideWithValue(launch2),
  ],
);

Future<void> _openNft(WidgetTester tester) async {
  await tester.ensureVisible(_key('wallet-asset-tab-nft'));
  await tester.tap(_key('wallet-asset-tab-nft'));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('代币 order', () {
    test('valued rows by value, then the rest by amount; ties keep order', () {
      Widget w(String id) => SizedBox(key: ValueKey<String>(id));
      final sorted = walletSortTokenEntries(<WalletTokenEntry>[
        (valueUsd: null, quantity: Decimal.parse('5'), row: w('a')),
        (valueUsd: Decimal.parse('10'), quantity: Decimal.one, row: w('b')),
        (valueUsd: null, quantity: Decimal.parse('500'), row: w('c')),
        (valueUsd: Decimal.parse('900'), quantity: Decimal.one, row: w('d')),
        (valueUsd: null, quantity: Decimal.parse('5'), row: w('e')),
      ]);
      expect(
        <String>[
          for (final entry in sorted)
            (entry.row.key! as ValueKey<String>).value,
        ],
        <String>['d', 'b', 'c', 'a', 'e'],
      );
    });
  });

  group('wallet 代币', () {
    testWidgets('main and Launch rows are one list, no Launch 链 heading, '
        'no zero rows, no fold', (tester) async {
      await _pumpWallet(
        tester,
        balances: s5Balances(
          rows: <LoopAssetBalanceRow>[s5Row(), _zeroWbnb()],
          launchChain: _launchChain(native: '2.5'),
        ),
      );
      expect(_key('wallet-asset-tabs'), findsOneWidget);
      expect(find.text('余额'), findsNothing);
      expect(_key('wallet-power-tag'), findsOneWidget);
      final list = _key('wallet-asset-list');
      await tester.ensureVisible(_key('wallet-launch-chain-usd1-row'));
      for (final id in <String>[
        'wallet-balance-open-$s5NativeAssetId',
        'wallet-launch-chain-row',
        'wallet-launch-chain-usd1-row',
      ]) {
        expect(find.descendant(of: list, matching: _key(id)), findsOneWidget);
      }
      expect(_key('wallet-balance-open-$s5WbnbAssetId'), findsNothing);
      expect(_key('wallet-launch-chain'), findsNothing);
      expect(find.text('Launch 链'), findsNWidgets(2));
      expect(find.text('手续费保留 0.005'), findsWidgets);
      expect(find.text('可动用 2.5'), findsOneWidget);
      expect(_key('wallet-zero-toggle'), findsNothing);
      expect(find.textContaining('零余额'), findsNothing);
      // The valued main row leads; the unvalued Launch rows follow by amount.
      expect(
        tester.getTopLeft(_key('wallet-balance-open-$s5NativeAssetId')).dy,
        lessThan(tester.getTopLeft(_key('wallet-launch-chain-usd1-row')).dy),
      );
      expect(
        tester.getTopLeft(_key('wallet-launch-chain-usd1-row')).dy,
        lessThan(tester.getTopLeft(_key('wallet-launch-chain-row')).dy),
      );
      // One provenance line, under the list.
      expect(_key('wallet-snapshot-footer'), findsOneWidget);
      expect(_key('wallet-launch-chain-snapshot'), findsNothing);
    });

    testWidgets('a zero Launch native balance is not drawn', (tester) async {
      await _pumpWallet(
        tester,
        balances: s5Balances(launchChain: _launchChain(native: '0')),
      );
      expect(_key('wallet-launch-chain-row'), findsNothing);
      expect(_key('wallet-launch-chain-usd1-row'), findsOneWidget);
    });

    testWidgets('everything zero is one empty state, not a fold line', (
      tester,
    ) async {
      await _pumpWallet(
        tester,
        balances: s5Balances(rows: <LoopAssetBalanceRow>[_zeroWbnb()]),
      );
      expect(_key('wallet-balances-empty'), findsOneWidget);
      expect(find.text('余额都为 0，已收起'), findsNothing);
      expect(_key('wallet-balances-all-zero'), findsNothing);
    });

    testWidgets('a MEME v2 token sits in 代币 with its Launch 链 line; its NFT '
        'does not', (tester) async {
      await _pumpWallet(
        tester,
        launch2: _Positions(() async => l2Positions(stage: 'public')),
      );
      final list = _key('wallet-asset-list');
      expect(
        find.descendant(
          of: list,
          matching: _key('launch2-wallet-meme-$l2InstanceA'),
        ),
        findsOneWidget,
      );
      expect(find.text('Launch 链 · 内盘持仓'), findsOneWidget);
      expect(_key('launch2-wallet-nft-$l2InstanceA'), findsNothing);
    });
  });

  group('wallet NFT', () {
    testWidgets('the project NFT card opens its medal page', (tester) async {
      final opened = <String>[];
      await _pumpWallet(
        tester,
        launch2: _Positions(() async => l2Positions()),
        onNavigate: opened.add,
      );
      await _openNft(tester);
      await tester.pumpAndSettle();
      expect(_key('wallet-nft-list'), findsOneWidget);
      expect(find.text('FROG NFT'), findsOneWidget);
      // S273 · decision 0232: a picture card, the #id on its face, and
      // 「×n · stage」 under the name.
      expect(_key('launch2-nft-grid'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('×1 · 提前购'), findsOneWidget);
      expect(_key('launch2-wallet-meme-$l2InstanceA'), findsNothing);
      expect(_key('wallet-nft-provenance'), findsOneWidget);
      await tester.ensureVisible(_key('launch2-wallet-nft-$l2InstanceA'));
      await tester.tap(_key('launch2-wallet-nft-$l2InstanceA'));
      expect(opened.last, Launch2Route.nft(l2InstanceA));
    });

    testWidgets('loading', (tester) async {
      await _pumpWallet(
        tester,
        launch2: _Positions(() => Completer<Launch2Positions>().future),
        settle: false,
      );
      await tester.pump();
      await _openNft(tester);
      expect(_key('wallet-nft-loading'), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      await _pumpWallet(
        tester,
        launch2: _Positions(
          () async => const Launch2Positions(items: <Launch2Position>[]),
        ),
      );
      await _openNft(tester);
      expect(_key('wallet-nft-empty'), findsOneWidget);
    });

    for (final kind in <LoopChainFailureKind>[
      LoopChainFailureKind.unavailable,
      LoopChainFailureKind.offline,
      LoopChainFailureKind.permissionDenied,
    ]) {
      testWidgets('a ${kind.name} read is one line with a retry', (
        tester,
      ) async {
        await _pumpWallet(
          tester,
          launch2: _Positions(
            () => Future<Launch2Positions>.error(LoopChainException(kind)),
          ),
        );
        await _openNft(tester);
        expect(_key('launch2-wallet-unavailable'), findsOneWidget);
      });
    }

    testWidgets('launch2 closed: one unavailable line', (tester) async {
      await _pumpWallet(tester);
      await _openNft(tester);
      expect(_key('wallet-nft-unavailable'), findsOneWidget);
      expect(_key('wallet-nft-list'), findsNothing);
    });
  });
}
