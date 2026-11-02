// S337 · decision 0266: 我 · 持仓 splits 代币 and NFT into two quiet tabs,
// as 钱包 does; the choice is kept for the run.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_test_hints.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
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

Launch2Positions _positions(List<Map<String, Object?>> rows) =>
    LoopV2Launch2Codec.positions(<String, Object?>{
      'positions': rows,
      'contractVersion': '2.0',
    }, mediaUrl: (_) => null);

LoopWalletBalances _nothingOnMain() =>
    s5Balances(rows: <LoopAssetBalanceRow>[s5Row(balance: _zero())]);

Finder _tabWord(String option) => find.descendant(
  of: _key('profile-holdings-tab-$option'),
  matching: find.byType(Text),
);

String _tabLabel(WidgetTester tester, String option) =>
    tester.widget<Text>(_tabWord(option)).data!;

Future<void> _openNfts(WidgetTester tester) async {
  await tester.ensureVisible(_key('profile-holdings-tab-nfts'));
  await tester.tap(_key('profile-holdings-tab-nfts'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => debugSetLoopTestHintsVisible(null));

  testWidgets('代币 by default, counts on both tabs, 持仓 (total)', (tester) async {
    await _pump(
      tester,
      _profile(<String>[]),
      balances: _testnetOnly(),
      positions: _twoTokensOneNft(),
    );
    expect(find.text('持仓 (4)'), findsOneWidget);
    expect(_key('profile-holdings-tabs'), findsOneWidget);
    expect(_tabLabel(tester, 'tokens'), '代币 3');
    expect(_tabLabel(tester, 'nfts'), 'NFT 1');
    // The chosen word is Chalk 700, the other Text3.
    final tokens = tester.widget<Text>(_tabWord('tokens'));
    final nfts = tester.widget<Text>(_tabWord('nfts'));
    expect(tokens.style?.fontWeight, FontWeight.w700);
    expect(nfts.style?.fontWeight, isNot(FontWeight.w700));
    for (final key in <String>[
      'wallet-launch-chain-usd1-row',
      'launch2-wallet-meme-$l2InstanceA',
      'launch2-wallet-meme-$l2InstanceB',
    ]) {
      expect(_key(key), findsOneWidget, reason: key);
    }
    expect(_key('profile-holdings-nfts'), findsNothing);
    expect(_key('launch2-wallet-nft-$l2InstanceA'), findsNothing);
    // The tabs stand between the title and the rows.
    expect(
      tester.getTopLeft(find.text('持仓 (4)')).dy,
      lessThan(tester.getTopLeft(_key('profile-holdings-tabs')).dy),
    );
    expect(
      tester.getTopLeft(_key('profile-holdings-tabs')).dy,
      lessThan(tester.getTopLeft(_key('wallet-launch-chain-usd1-row')).dy),
    );
  });

  testWidgets('NFT shows the picture cards and nothing of 代币', (tester) async {
    final opened = <String>[];
    await _pump(
      tester,
      _profile(opened),
      balances: _testnetOnly(),
      positions: _twoTokensOneNft(),
    );
    await _openNfts(tester);
    expect(find.text('持仓 (4)'), findsOneWidget);
    expect(_key('profile-holdings-nfts'), findsOneWidget);
    expect(_key('launch2-wallet-nft-$l2InstanceA'), findsOneWidget);
    expect(_key('launch2-wallet-meme-$l2InstanceA'), findsNothing);
    expect(_key('wallet-launch-chain-usd1-row'), findsNothing);
    expect(
      tester.widget<Text>(_tabWord('nfts')).style?.fontWeight,
      FontWeight.w700,
    );
    await tester.ensureVisible(_key('launch2-wallet-nft-$l2InstanceA'));
    await tester.tap(_key('launch2-wallet-nft-$l2InstanceA'));
    expect(opened.single, startsWith('/launch2/nft?'));
  });

  testWidgets('the chosen tab is kept for the run', (tester) async {
    final shown = ValueNotifier<bool>(true);
    await _pump(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (context, show, _) =>
            show ? _profile(<String>[]) : const SizedBox.shrink(),
      ),
      balances: _testnetOnly(),
      positions: _twoTokensOneNft(),
    );
    await _openNfts(tester);
    final container = ProviderScope.containerOf(
      tester.element(_key('profile-holdings-tabs')),
    );
    expect(container.read(profileHoldingsTabProvider), ProfileHoldingsTab.nfts);

    shown.value = false;
    await tester.pumpAndSettle();
    expect(_key('profile-holdings-tabs'), findsNothing);
    shown.value = true;
    await tester.pumpAndSettle();
    expect(_key('launch2-wallet-nft-$l2InstanceA'), findsOneWidget);
    expect(_key('launch2-wallet-meme-$l2InstanceA'), findsNothing);
    expect(
      tester.widget<Text>(_tabWord('nfts')).style?.fontWeight,
      FontWeight.w700,
    );
  });

  testWidgets('no NFT: one Text3 line 暂无 NFT', (tester) async {
    await _pump(
      tester,
      _profile(<String>[]),
      balances: _testnetOnly(),
      positions: _positions(<Map<String, Object?>>[
        _position(
          instanceId: l2InstanceB,
          ticker: 'GENIUS',
          net: '4988148.78',
          nftHeld: 0,
        ),
      ]),
    );
    expect(find.text('持仓 (2)'), findsOneWidget);
    expect(_tabLabel(tester, 'nfts'), 'NFT 0');
    await _openNfts(tester);
    expect(_key('profile-holdings-nfts-empty'), findsOneWidget);
    final line = tester.widget<Text>(find.text('暂无 NFT'));
    expect(line.style?.color, LoopColors.text3);
    expect(_key('profile-first-buy'), findsNothing);
  });

  testWidgets('no token but an NFT: 代币 shows the first-buy card', (
    tester,
  ) async {
    await _pump(
      tester,
      _profile(<String>[]),
      balances: _nothingOnMain(),
      positions: _positions(<Map<String, Object?>>[
        _position(instanceId: l2InstanceA, ticker: 'CAT', net: '0', nftHeld: 1),
      ]),
    );
    expect(_tabLabel(tester, 'tokens'), '代币 0');
    expect(_tabLabel(tester, 'nfts'), 'NFT 1');
    expect(find.text('持仓 (1)'), findsOneWidget);
    expect(_key('profile-first-buy'), findsOneWidget);
    await _openNfts(tester);
    expect(_key('profile-first-buy'), findsNothing);
    expect(_key('launch2-wallet-nft-$l2InstanceA'), findsOneWidget);
  });

  testWidgets('nothing held: 持仓 (0), 暂无持仓, first-buy, 暂无 NFT', (tester) async {
    await _pump(tester, _profile(<String>[]), balances: _nothingOnMain());
    expect(find.text('持仓 (0)'), findsOneWidget);
    expect(find.text('暂无持仓'), findsOneWidget);
    expect(_tabLabel(tester, 'tokens'), '代币 0');
    expect(_tabLabel(tester, 'nfts'), 'NFT 0');
    expect(_key('profile-first-buy'), findsOneWidget);
    await _openNfts(tester);
    expect(find.text('暂无 NFT'), findsOneWidget);
  });

  testWidgets('loading stays as it was', (tester) async {
    await pumpS5Page(
      tester,
      _profile(<String>[]),
      wallet: FakeWalletReadGateway(
        balances: S5Answer<LoopWalletBalances>(pending: true),
      ),
      overrides: <Override>[
        profileGatewayProvider.overrideWithValue(_Profile()),
      ],
      settle: false,
    );
    await tester.pump();
    await tester.pump();
    expect(_key('profile-holdings-loading'), findsOneWidget);
    expect(_key('profile-holdings-tabs'), findsNothing);
  });

  testWidgets('a failed read stays as it was', (tester) async {
    await pumpS5Page(
      tester,
      _profile(<String>[]),
      wallet: FakeWalletReadGateway(
        balances: S5Answer<LoopWalletBalances>(
          failure: LoopChainFailureKind.unavailable,
        ),
      ),
      overrides: <Override>[
        profileGatewayProvider.overrideWithValue(_Profile()),
      ],
      settle: false,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_key('profile-holdings-failed'), findsOneWidget);
    expect(find.text('持仓暂时读不到'), findsOneWidget);
  });
}
