import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_gateway.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// Decision 0253 (S322): 我的挖矿 shows 代币算力 and NFT 算力 apart. With the
/// snapshot's own split (`summary.assetPower` / `nftPower`,
/// `included[].nftPower`) the hero's second strip and 算力构成's two groups
/// read it; without it the strip falls back to the last settled hour,
/// labelled 上一小时, and 算力构成 stays the single snapshot list.
const _tall = Size(390, 9000);

MiningAssetTrack _assetTrack() => MiningAssetTrack(
  assets: const <MiningTrackAsset>[],
  ownPower: Decimal.parse('500'),
  invitePower: Decimal.parse('7'),
  totalPower: Decimal.parse('507.9'),
  reward: BigInt.zero,
  networkPower: Decimal.parse('1000000.6'),
);

MiningNftTrack _nftTrack() => MiningNftTrack(
  realCount: BigInt.from(3),
  ownPower: Decimal.parse('3000'),
  invitePower: Decimal.parse('20'),
  totalPower: Decimal.parse('3020.5'),
  reward: BigInt.zero,
  networkPower: Decimal.parse('25000.5'),
);

Future<void> _pump(
  WidgetTester tester, {
  required List<MiningAssetRow> rows,
  String? assetPower,
  String? nftPower,
  MiningNftTrack? nft,
  MiningAssetTrack? asset,
}) => pumpS7Page(
  tester,
  const MiningScreen(),
  mining: FakeMiningGateway(
    summary: S7Answer<MiningSummary>(
      value: s7MiningBaselineSummary(
        assetPower: assetPower,
        nftPower: nftPower,
      ),
    ),
    assets: S7Answer<MiningAssets>(
      value: s7MiningSettledAssets(included: rows),
    ),
  ),
  size: _tall,
  overrides: <Override>[
    miningRewardsGatewayProvider.overrideWithValue(
      S7TokenStageRewards.preToken(nft: nft, asset: asset),
    ),
  ],
);

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey<String>(key))).data!;

Finder _key(String key) => find.byKey(ValueKey<String>(key));

void main() {
  group('S322 · snapshot split present', () {
    testWidgets('both: hero from the summary, two groups with subtotals', (
      tester,
    ) async {
      await _pump(
        tester,
        rows: <MiningAssetRow>[
          s7MiningAssetRow(
            holding: '1543209.8625',
            power: '1237567.89',
            nftPower: '3000.5',
          ),
          s7MiningAssetRow(
            assetId: s7UsdtAssetId,
            symbol: 'USDT',
            holding: '10',
            weight: '1',
            power: '10',
          ),
        ],
        assetPower: '1234577.39',
        nftPower: '3000.5',
        nft: _nftTrack(),
        asset: _assetTrack(),
      );

      expect(_key('mining-summary-hero-split'), findsOneWidget);
      expect(_text(tester, 'mining-summary-hero-token-power'), '1,234,577');
      expect(_text(tester, 'mining-summary-hero-nft-power'), '3,000');
      final split = _key('mining-summary-hero-split');
      expect(
        find.descendant(of: split, matching: find.text('代币算力')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: split, matching: find.text('NFT 算力')),
        findsOneWidget,
      );
      expect(find.text('代币算力 · 上一小时'), findsNothing);
      for (final slug in <String>[
        'network-power',
        'last-hour-power',
        'active-invites',
      ]) {
        expect(_key('mining-summary-hero-$slug'), findsOneWidget);
      }

      expect(_text(tester, 'mining-composition-token-subtotal'), '1,234,577');
      expect(_text(tester, 'mining-composition-nft-subtotal'), '3,000');
      // 代币 rows show power − nftPower, in the S321 row with its expression.
      final cake = _key('mining-composition-token-$s7CakeAssetId');
      expect(
        find.descendant(of: cake, matching: find.text('1,234,567')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: cake,
          matching: find.textContaining('1,543,209.8625 × 权重 0.8'),
        ),
        findsOneWidget,
      );
      expect(_key('mining-composition-token-$s7UsdtAssetId'), findsOneWidget);
      // NFT rows are the rows with an NFT share, showing that share.
      final cakeNft = _key('mining-composition-nft-$s7CakeAssetId');
      expect(
        find.descendant(of: cakeNft, matching: find.text('3,000')),
        findsOneWidget,
      );
      expect(_key('mining-composition-nft-$s7UsdtAssetId'), findsNothing);
      // No invite rows in the snapshot composition.
      expect(_key('mining-composition-token-invite'), findsNothing);
      expect(_key('mining-composition-nft-invite'), findsNothing);
      expect(
        find.descendant(
          of: _key('mining-composition'),
          matching: find.text('邀请加成'),
        ),
        findsNothing,
      );
      expect(find.byType(LoopEmptyState), findsNothing);
    });

    testWidgets('token only: the NFT group is the empty style', (tester) async {
      await _pump(
        tester,
        rows: <MiningAssetRow>[s7MiningAssetRow(holding: '10', power: '8')],
        assetPower: '8',
        nftPower: '0',
      );

      expect(_text(tester, 'mining-summary-hero-nft-power'), '0');
      expect(_key('mining-composition-token'), findsOneWidget);
      expect(
        tester.widget(_key('mining-composition-nft-empty')),
        isA<LoopEmptyState>(),
      );
      expect(find.text('暂无 NFT 算力'), findsOneWidget);
    });

    testWidgets('NFT only: the token group is the empty style', (tester) async {
      await _pump(
        tester,
        rows: <MiningAssetRow>[
          s7MiningAssetRow(holding: '0', power: '3000', nftPower: '3000'),
        ],
        assetPower: '0',
        nftPower: '3000',
      );

      expect(_text(tester, 'mining-summary-hero-token-power'), '0');
      expect(_text(tester, 'mining-composition-nft-subtotal'), '3,000');
      expect(find.text('暂无代币算力'), findsOneWidget);
      expect(_key('mining-composition-nft-$s7CakeAssetId'), findsOneWidget);
      expect(_key('mining-composition-token-$s7CakeAssetId'), findsNothing);
    });

    testWidgets('none: two empty groups', (tester) async {
      await _pump(
        tester,
        rows: const <MiningAssetRow>[],
        assetPower: '0',
        nftPower: '0',
      );

      expect(find.text('暂无代币算力'), findsOneWidget);
      expect(find.text('暂无 NFT 算力'), findsOneWidget);
      expect(_text(tester, 'mining-composition-token-subtotal'), '0');
    });
  });

  group('S322 · snapshot split absent (old payload)', () {
    testWidgets('hero falls back to the hour, labelled; one list as before', (
      tester,
    ) async {
      await _pump(
        tester,
        rows: <MiningAssetRow>[s7MiningAssetRow(holding: '10', power: '8')],
        nft: _nftTrack(),
        asset: _assetTrack(),
      );

      expect(find.text('代币算力 · 上一小时'), findsOneWidget);
      expect(find.text('NFT 算力 · 上一小时'), findsOneWidget);
      expect(_text(tester, 'mining-summary-hero-token-power'), '507');
      expect(_text(tester, 'mining-summary-hero-nft-power'), '3,020');
      expect(_key('mining-composition'), findsOneWidget);
      expect(_key('mining-assets-row-$s7CakeAssetId'), findsOneWidget);
      expect(_key('mining-composition-token-subtotal'), findsNothing);
      expect(_key('mining-composition-nft-subtotal'), findsNothing);
    });

    testWidgets('no settled hour either: dashes', (tester) async {
      await _pump(tester, rows: <MiningAssetRow>[s7MiningAssetRow()]);

      expect(_text(tester, 'mining-summary-hero-token-power'), '—');
      expect(_text(tester, 'mining-summary-hero-nft-power'), '—');
    });

    test('the split cells read the summary first', () {
      expect(
        miningPoolSplitMetrics(
          s7MiningBaselineSummary(assetPower: '5.9', nftPower: '2'),
          null,
        ).map((cell) => '${cell.label} ${cell.value}'),
        <String>['代币算力 5', 'NFT 算力 2'],
      );
      expect(
        miningPoolSplitMetrics(null, null).map((cell) => cell.label),
        <String>['代币算力 · 上一小时', 'NFT 算力 · 上一小时'],
      );
    });
  });

  group('S322 · 全网算力 = the 算力榜 total', () {
    testWidgets('a settled hour: the two hourly network totals, summed', (
      tester,
    ) async {
      await _pump(
        tester,
        rows: <MiningAssetRow>[s7MiningAssetRow()],
        nft: _nftTrack(),
        asset: _assetTrack(),
      );
      // 1,000,000.6 + 25,000.5 = 1,025,001.1, not the snapshot's 4,000.
      expect(_text(tester, 'mining-summary-hero-network-power'), '1,025,001');
    });

    testWidgets('no settled hour: the snapshot networkPower', (tester) async {
      await _pump(tester, rows: <MiningAssetRow>[s7MiningAssetRow()]);
      expect(_text(tester, 'mining-summary-hero-network-power'), '4,000');
    });
  });
}
