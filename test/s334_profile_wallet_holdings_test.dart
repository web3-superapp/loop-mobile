// S334 · decision 0263: 我's 持仓 and net worth are 钱包's — the same rows
// (main chain, Launch chain, MEME v2 tokens and NFTs) and the same caption.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_codec.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'support/launch2_fixtures.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

final class _Profile implements ProfileGateway {
  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() async => ProfileResource(
    version: 1,
    values: ProfileValues(alias: 'Tester', avatarRef: null, bio: null),
    updatedAt: DateTime.utc(2026, 10, 21),
    loopId: 'LOOP-EYMVEN8N',
    profileStatus: ProfileStatus.active,
    activatedAt: DateTime.utc(2026, 10, 21, 8),
  );

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) => load();
}

final class _Positions implements Launch2Gateway {
  _Positions(this.positions);

  final Launch2Positions positions;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Positions> loadPositions() async => positions;

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

Map<String, Object?> _position({
  required String instanceId,
  required String ticker,
  required String net,
  required int nftHeld,
}) => <String, Object?>{
  'instanceId': instanceId,
  'name': '$ticker Launch',
  'ticker': ticker,
  'logoUrl': null,
  'memeAddress': l2Meme,
  'stage': 'public',
  'walletId': l2WalletId,
  'nft': <String, Object?>{
    'mintedTokenId': nftHeld > 0 ? '1' : null,
    'held': nftHeld,
  },
  'snapshotMember': true,
  'curve': <String, Object?>{
    'bought': net,
    'sold': '0',
    'net': net,
    'cumulativeBought': net,
    'remainingQuota': '0',
    'usd1Spent': '100',
    'usd1Received': '0',
    'taxUsd1': '1',
  },
  'lastActivityAt': '2026-10-21T08:10:00.000Z',
};

/// Two MEME v2 tokens, one NFT (the S333 account, decision 0263).
Launch2Positions _twoTokensOneNft() =>
    LoopV2Launch2Codec.positions(<String, Object?>{
      'positions': <Object?>[
        _position(
          instanceId: l2InstanceA,
          ticker: 'CAT',
          net: '5000000',
          nftHeld: 1,
        ),
        _position(
          instanceId: l2InstanceB,
          ticker: 'GENIUS',
          net: '4988148.78',
          nftHeld: 0,
        ),
      ],
      'contractVersion': '2.0',
    }, mediaUrl: (_) => null);

LoopBalanceAvailable _zero() => LoopBalanceAvailable(
  rawValue: '0',
  displayBalance: Decimal.zero,
  availableBalance: Decimal.zero,
  spendableBalance: Decimal.zero,
  gasReserve: Decimal.zero,
);

/// Main chain 0, net worth $0, Launch chain tBNB 0 and tUSD1 4433.43.
LoopWalletBalances _testnetOnly() => s5Balances(
  rows: <LoopAssetBalanceRow>[
    s5Row(balance: _zero()),
    s5Row(assetId: s5WbnbAssetId, balance: _zero()),
  ],
  netWorth: LoopNetWorthValued(
    partial: false,
    valuationCurrency: 'USD',
    valueUsd: Decimal.zero,
    unavailableCount: 0,
    quality: LoopFactQuality.fresh,
    priceSource: LoopFactSource.dexscreener,
    asOf: DateTime.utc(2026, 11, 2, 2),
    isSpendable: false,
    change24h: LoopNetWorthChangeAvailable(
      usd: Decimal.zero,
      pct: Decimal.zero,
    ),
  ),
  launchChain: LoopLaunchChainBalance(
    chainId: 'eip155:97',
    available: true,
    reasonCode: null,
    nativeBalance: LoopLaunchChainNativeBalance(
      assetId: 'eip155:97/slip44:714',
      symbol: 'tBNB',
      decimals: 18,
      rawValue: '0',
      displayBalance: Decimal.zero,
      availableBalance: Decimal.zero,
      spendableBalance: Decimal.zero,
      gasReserve: Decimal.parse('0.005'),
      snapshot: LoopBalanceSnapshot(
        blockNumber: BigInt.from(5000),
        blockHash: s5BlockHash,
        observedAt: DateTime.utc(2026, 11, 2, 2),
        confirmations: 3,
      ),
    ),
    usd1: const LoopLaunchUsd1Reading(
      balance: '4433430000000000000000',
      allowance: '0',
    ),
  ),
);

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required LoopWalletBalances balances,
  Launch2Positions? positions,
}) => pumpS5Page(
  tester,
  page,
  wallet: FakeWalletReadGateway(
    balances: S5Answer<LoopWalletBalances>(value: balances),
  ),
  meta: positions == null ? null : _metaWithLaunch2(),
  overrides: <Override>[
    profileGatewayProvider.overrideWithValue(_Profile()),
    if (positions != null)
      launch2GatewayProvider.overrideWithValue(_Positions(positions)),
  ],
);

Widget _profile(List<String> opened) =>
    ProfileSurfaceScreen.fromId('profile', onNavigate: opened.add);

const List<String> _tokenKeys = <String>[
  'wallet-launch-chain-usd1-row',
  'launch2-wallet-meme-$l2InstanceA',
  'launch2-wallet-meme-$l2InstanceB',
];

String? _text(WidgetTester tester, String key) =>
    tester.widget<Text>(_key(key)).data;

void main() {
  tearDown(() => debugSetLoopTestHintsVisible(null));

  group('testnet-only account (S333)', () {
    for (final hints in <bool>[false, true]) {
      testWidgets('我 lists 钱包\'s rows; test hints $hints', (tester) async {
        debugSetLoopTestHintsVisible(hints);
        final positions = _twoTokensOneNft();

        // 钱包: three token rows in 代币, one card in NFT.
        await _pump(
          tester,
          const WalletScreen(),
          balances: _testnetOnly(),
          positions: positions,
        );
        final list = _key('wallet-asset-list');
        for (final key in _tokenKeys) {
          expect(
            find.descendant(of: list, matching: _key(key)),
            findsOneWidget,
          );
        }
        expect(_key('wallet-balances-empty'), findsNothing);
        final walletFigure = _text(tester, 'wallet-total-figure');
        expect(walletFigure, r'$0');
        expect(_key('wallet-total-caption'), findsNothing);
        final walletNote = find.byKey(
          const ValueKey<String>('wallet-launch-chain-total-note'),
        );
        expect(walletNote, hints ? findsOneWidget : findsNothing);
        final walletNoteText = hints
            ? tester.widget<Text>(walletNote).data
            : null;
        await tester.ensureVisible(_key('wallet-asset-tab-nft'));
        await tester.tap(_key('wallet-asset-tab-nft'));
        await tester.pumpAndSettle();
        expect(_key('launch2-wallet-nft-$l2InstanceA'), findsOneWidget);
        expect(_key('launch2-wallet-nft-$l2InstanceB'), findsNothing);
        const walletRows = 3 + 1;

        // 我: the same four, 持仓 (4), no first-buy card.
        final opened = <String>[];
        await _pump(
          tester,
          _profile(opened),
          balances: _testnetOnly(),
          positions: positions,
        );
        expect(find.text('持仓 ($walletRows)'), findsOneWidget);
        for (final key in <String>[
          ..._tokenKeys,
          'launch2-wallet-nft-$l2InstanceA',
        ]) {
          expect(_key(key), findsOneWidget, reason: key);
        }
        expect(_key('profile-first-buy'), findsNothing);
        expect(find.text('获取你的第一个代币'), findsNothing);
        expect(_key('profile-chart-empty'), findsNothing);
        expect(find.text('暂无持仓'), findsNothing);
        // The net worth line is 钱包's, word for word.
        expect(_text(tester, 'profile-networth-figure'), walletFigure);
        expect(_key('profile-networth-caption'), findsNothing);
        expect(walletNote, hints ? findsOneWidget : findsNothing);
        if (hints) {
          expect(tester.widget<Text>(walletNote).data, walletNoteText);
          expect(
            find.descendant(
              of: _key('profile-networth-panel'),
              matching: walletNote,
            ),
            findsOneWidget,
          );
        }
        // Same order as 钱包: tUSD1 (4,433) ahead of nothing valued; the
        // MEME rows by amount after it.
        expect(
          tester.getTopLeft(_key('launch2-wallet-meme-$l2InstanceA')).dy,
          lessThan(
            tester.getTopLeft(_key('launch2-wallet-meme-$l2InstanceB')).dy,
          ),
        );

        // A MEME row and the NFT card open the same pages as on 钱包.
        await tester.ensureVisible(_key('launch2-wallet-meme-$l2InstanceA'));
        await tester.tap(_key('launch2-wallet-meme-$l2InstanceA'));
        await tester.ensureVisible(_key('launch2-wallet-nft-$l2InstanceA'));
        await tester.tap(_key('launch2-wallet-nft-$l2InstanceA'));
        expect(opened, hasLength(2));
        expect(opened.first, startsWith('/launch2/instance?'));
        expect(opened.last, startsWith('/launch2/nft?'));
      });
    }
  });

  group('main chain only (regression)', () {
    testWidgets('one held main row: 持仓 (1), 钱包\'s figure and caption', (
      tester,
    ) async {
      await _pump(tester, const WalletScreen(), balances: s5Balances());
      final walletFigure = _text(tester, 'wallet-total-figure');
      expect(_key('wallet-balance-open-$s5NativeAssetId'), findsOneWidget);

      final opened = <String>[];
      await _pump(tester, _profile(opened), balances: s5Balances());
      expect(find.text('持仓 (1)'), findsOneWidget);
      expect(_key('wallet-balance-$s5NativeAssetId'), findsOneWidget);
      expect(_text(tester, 'profile-networth-figure'), walletFigure);
      expect(_key('profile-networth-caption'), findsNothing);
      expect(_key('wallet-launch-chain-total-note'), findsNothing);
      expect(_key('profile-first-buy'), findsNothing);
      // 我 does not carry 钱包's 发送 / 兑换 chips.
      expect(_key('wallet-balance-send-$s5NativeAssetId'), findsNothing);
    });

    testWidgets('a partial net worth says the same on both pages', (
      tester,
    ) async {
      final balances = s5Balances(
        netWorth: LoopNetWorthValued(
          partial: true,
          valuationCurrency: 'USD',
          valueUsd: Decimal.parse('12.5'),
          unavailableCount: 2,
          quality: LoopFactQuality.fresh,
          priceSource: LoopFactSource.dexscreener,
          asOf: DateTime.utc(2026, 11, 2, 2),
          isSpendable: false,
          change24h: LoopNetWorthChangeAvailable(
            usd: Decimal.zero,
            pct: Decimal.zero,
          ),
        ),
      );
      await _pump(tester, const WalletScreen(), balances: balances);
      final walletCaption = _text(tester, 'wallet-total-caption');
      expect(walletCaption, '2 项资产暂无价格，未计入');
      await _pump(tester, _profile(<String>[]), balances: balances);
      expect(_text(tester, 'profile-networth-caption'), walletCaption);
    });

    testWidgets('nothing anywhere: 持仓 (0), 暂无持仓, first-buy card', (
      tester,
    ) async {
      await _pump(
        tester,
        _profile(<String>[]),
        balances: s5Balances(
          rows: <LoopAssetBalanceRow>[s5Row(balance: _zero())],
        ),
      );
      expect(find.text('持仓 (0)'), findsOneWidget);
      expect(find.text('暂无持仓'), findsOneWidget);
      expect(_key('profile-first-buy'), findsOneWidget);
    });
  });
}
