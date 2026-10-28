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

/// Decision 0253 (S322): 我的挖矿 shows 代币算力 and NFT 算力 apart — two
/// cells in the hero under the three readings, and 算力构成 in two groups,
/// 代币 and NFT, each headed by its pool's subtotal. Both come from the last
/// settled hour's `tracks.asset` / `tracks.nft`.
const _tall = Size(390, 9000);

MiningAssetTrack _asset({String invite = '0'}) => MiningAssetTrack(
  assets: <MiningTrackAsset>[
    MiningTrackAsset(
      assetId: s7CakeAssetId,
      power: Decimal.parse('1234567.89'),
      balanceAtEnd: BigInt.parse('1543209862500000000000000'),
    ),
  ],
  ownPower: Decimal.parse('1234567.89'),
  invitePower: Decimal.parse(invite),
  totalPower: Decimal.parse('1234567.89') + Decimal.parse(invite),
  reward: BigInt.zero,
);

MiningNftTrack _nft({String invite = '0'}) => MiningNftTrack(
  realCount: BigInt.from(3),
  ownPower: Decimal.parse('3000.5'),
  invitePower: Decimal.parse(invite),
  totalPower: Decimal.parse('3000.5') + Decimal.parse(invite),
  reward: BigInt.zero,
);

Future<void> _pump(
  WidgetTester tester, {
  MiningNftTrack? nft,
  MiningAssetTrack? asset,
}) => pumpS7Page(
  tester,
  const MiningScreen(),
  mining: FakeMiningGateway(
    summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
    assets: S7Answer<MiningAssets>(
      value: s7MiningSettledAssets(
        included: <MiningAssetRow>[s7MiningAssetRow(power: '9999999')],
      ),
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

void main() {
  group('S322 · 代币算力 / NFT 算力', () {
    testWidgets('both pools: hero split and two groups with subtotals', (
      tester,
    ) async {
      await _pump(
        tester,
        nft: _nft(invite: '20'),
        asset: _asset(invite: '7'),
      );

      expect(
        find.byKey(const ValueKey<String>('mining-summary-hero-split')),
        findsOneWidget,
      );
      expect(_text(tester, 'mining-summary-hero-token-power'), '1,234,574');
      expect(_text(tester, 'mining-summary-hero-nft-power'), '3,020');
      expect(find.text('代币算力'), findsOneWidget);
      expect(find.text('NFT 算力'), findsOneWidget);
      // The three readings stay.
      for (final slug in <String>[
        'network-power',
        'last-hour-power',
        'active-invites',
      ]) {
        expect(
          find.byKey(ValueKey<String>('mining-summary-hero-$slug')),
          findsOneWidget,
        );
      }
      expect(_text(tester, 'mining-summary-hero-last-hour-power'), '1,237,595');

      expect(find.text('代币'), findsOneWidget);
      expect(find.text('NFT'), findsNWidgets(2));
      expect(_text(tester, 'mining-composition-token-subtotal'), '1,234,574');
      expect(_text(tester, 'mining-composition-nft-subtotal'), '3,020');
      // The asset row takes its symbol from the snapshot, its power from
      // the hour — never the snapshot row's folded figure.
      final cake = find.byKey(
        const ValueKey<String>('mining-composition-token-$s7CakeAssetId'),
      );
      expect(cake, findsOneWidget);
      expect(
        find.descendant(of: cake, matching: find.text('Cake')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cake, matching: find.text('1,234,567')),
        findsOneWidget,
      );
      expect(find.text('9,999,999'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('mining-composition-token-invite')),
        findsOneWidget,
      );
      final held = find.byKey(
        const ValueKey<String>('mining-composition-nft-held'),
      );
      expect(
        find.descendant(of: held, matching: find.text('持有 3 个')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: held, matching: find.text('3,000')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('mining-composition-nft-invite')),
        findsOneWidget,
      );
      expect(find.byType(LoopEmptyState), findsNothing);
    });

    testWidgets('token only: the NFT group is the empty style', (tester) async {
      await _pump(tester, nft: _nft().zero(), asset: _asset());

      expect(_text(tester, 'mining-summary-hero-token-power'), '1,234,567');
      expect(_text(tester, 'mining-summary-hero-nft-power'), '0');
      expect(_text(tester, 'mining-composition-nft-subtotal'), '0');
      expect(
        find.byKey(const ValueKey<String>('mining-composition-token')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('mining-composition-token-invite')),
        findsNothing,
      );
      expect(
        tester.widget(
          find.byKey(const ValueKey<String>('mining-composition-nft-empty')),
        ),
        isA<LoopEmptyState>(),
      );
      expect(find.text('暂无 NFT 算力'), findsOneWidget);
    });

    testWidgets('NFT only: the token group is the empty style', (tester) async {
      await _pump(
        tester,
        nft: _nft(),
        asset: MiningAssetTrack(
          assets: const <MiningTrackAsset>[],
          ownPower: Decimal.zero,
          invitePower: Decimal.zero,
          totalPower: Decimal.zero,
          reward: BigInt.zero,
        ),
      );

      expect(_text(tester, 'mining-summary-hero-token-power'), '0');
      expect(_text(tester, 'mining-summary-hero-nft-power'), '3,000');
      expect(_text(tester, 'mining-composition-token-subtotal'), '0');
      expect(_text(tester, 'mining-composition-nft-subtotal'), '3,000');
      expect(find.text('暂无代币算力'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('mining-composition-nft-held')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('mining-composition-nft-invite')),
        findsNothing,
      );
    });

    testWidgets('no settled hour: dashes and two empty groups', (tester) async {
      await _pump(tester);

      expect(_text(tester, 'mining-summary-hero-token-power'), '—');
      expect(_text(tester, 'mining-summary-hero-nft-power'), '—');
      expect(_text(tester, 'mining-composition-token-subtotal'), '—');
      expect(_text(tester, 'mining-composition-nft-subtotal'), '—');
      expect(find.text('暂无代币算力'), findsOneWidget);
      expect(find.text('暂无 NFT 算力'), findsOneWidget);
    });

    test('the split cells read the two track totals', () {
      expect(miningPoolSplitMetrics(null).map((cell) => cell.value), <String>[
        '—',
        '—',
      ]);
    });
  });
}

extension on MiningNftTrack {
  MiningNftTrack zero() => MiningNftTrack(
    realCount: BigInt.zero,
    ownPower: Decimal.zero,
    invitePower: Decimal.zero,
    totalPower: Decimal.zero,
    reward: BigInt.zero,
  );
}
