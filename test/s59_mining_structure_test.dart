import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// The block order of the six Mining pages, pinned against the frozen
/// prototype (`docs/prototype/screens/mining*.html`).
///
/// The audit of 2026-09-21 found the module's order rewritten page by page:
/// the conclusion below the explanation, the expression missing entirely, the
/// two next steps demoted to a menu at the foot of the page. Order is what
/// those findings were about, so order is what this file asserts — a page that
/// silently grows a sixth section or loses its Chalk card fails here.
List<String> _labels(WidgetTester tester) => <String>[
  for (final label in tester.widgetList<LoopLabel>(find.byType(LoopLabel)))
    label.text,
];

/// A viewport tall enough that every section is built, so the order read off
/// the tree is the whole page's and not the first screen's.
const _tall = Size(390, 9000);

void main() {
  group('mining · block order', () {
    testWidgets('the tab opens on the dashboard, then the composition', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningScreen(),
        mining: FakeMiningGateway(
          summary: S7Answer<MiningSummary>(value: s7MiningBaselineSummary()),
          assets: S7Answer<MiningAssets>(
            value: s7MiningSettledAssets(
              included: <MiningAssetRow>[s7MiningAssetRow()],
            ),
          ),
        ),
        size: _tall,
      );

      // One composite primary carrying the power, the rank, three readings and
      // the two next steps — not a hero plus five stacked key-value blocks.
      expect(
        find.byKey(const ValueKey<String>('mining-summary-hero')),
        findsOneWidget,
      );
      for (final key in <String>[
        'mining-summary-hero-power',
        'mining-summary-hero-estimated-today',
        'mining-summary-hero-accumulated',
        'mining-summary-hero-claimable',
        'mining-summary-hero-claim',
        'mining-summary-hero-assets',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget, reason: key);
      }
      expect(_labels(tester), <String>[
        'Power Composition',
        'Increase Power',
        '公式版本',
        '算力快照',
      ]);
    });

    testWidgets('算力明细 leads with the priced list, not with a table', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningAssetsScreen(),
        mining: FakeMiningGateway(
          assets: S7Answer<MiningAssets>(
            value: s7MiningSettledAssets(
              included: <MiningAssetRow>[s7MiningAssetRow()],
              excluded: <MiningExcludedAsset>[
                const MiningExcludedAsset(
                  assetId: s7UsdtAssetId,
                  symbol: 'USDT',
                  reasonCode: 'MINING_PRICE_NOT_FRESH',
                ),
              ],
            ),
          ),
        ),
        size: _tall,
      );

      expect(_labels(tester), <String>[
        'Included Assets',
        'Excluded Assets',
        'Reference Price',
        '公式版本',
        '算力快照',
      ]);
      // 我的总算力 is the strip welded under the primary, above every label.
      expect(
        find.byKey(const ValueKey<String>('mining-assets-total')),
        findsOneWidget,
      );
    });

    testWidgets('奖励与领取 puts the claim above the records', (tester) async {
      await pumpS7Page(
        tester,
        const MiningRewardsScreen(),
        mining: FakeMiningGateway(
          rewards: S7Answer<MiningRewards>(value: s7BaselineMiningRewards()),
        ),
        size: _tall,
      );

      expect(_labels(tester), <String>['Claim Records']);
      for (final key in <String>[
        'mining-rewards-cadence',
        'mining-rewards-readings',
        'mining-rewards-claim',
        'mining-rewards-ledger',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget, reason: key);
      }
    });

    testWidgets('算力排行榜 keeps the board under the scope switch', (tester) async {
      await pumpS7Page(
        tester,
        const MiningRankScreen(),
        mining: FakeMiningGateway(
          rank: S7Answer<MiningRank>(
            value: s7MiningRank(ranking: s7MiningCommunityBoard()),
          ),
        ),
        size: _tall,
      );

      expect(_labels(tester), <String>[
        'Community Ranking',
        // The board's own split: entries the settlement gave no place to.
        '未上榜',
        '公式版本',
        '显示规则',
      ]);
      expect(
        find.byKey(const ValueKey<String>('mining-rank-reading')),
        findsOneWidget,
      );
    });

    testWidgets('社区挖矿面板 carries the module\'s one Chalk card', (tester) async {
      await pumpS7Page(
        tester,
        const MiningCommunityScreen(communityId: s7CommunityId),
        mining: FakeMiningGateway(
          community: S7Answer<MiningCommunity>(
            value: s7MiningSettledCommunity(),
          ),
        ),
        size: _tall,
      );

      expect(_labels(tester), <String>[
        'My Contribution',
        'Community Records',
        '社区权重',
        '算力快照',
        '绑定资产',
      ]);
      expect(
        find.byKey(const ValueKey<String>('mining-community-contribution')),
        findsOneWidget,
      );
      expect(find.byType(LoopChalkCard), findsOneWidget);
    });

    testWidgets('挖矿规则 states the bands, the factors and the guards', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MiningRulesScreen(),
        mining: FakeMiningGateway(
          rules: S7Answer<MiningRules>(value: s7BaselineMiningRules()),
        ),
        size: _tall,
      );

      // The topbar says 挖矿规则 and the hero says 权重与价格保护, the way the
      // prototype has them.
      expect(find.text('挖矿规则'), findsOneWidget);
      expect(find.text('权重与价格保护'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('mining-rules-daily-output')),
        findsOneWidget,
      );
      expect(
        _labels(tester).where((label) => label != '资产权重').toList(),
        containsAllInOrder(<String>[
          '已批准的版本',
          'Weight Range',
          'Review Factors',
          'Reference Price Guard',
          '待批准的版本',
          '邀请关系规则',
        ]),
      );
      expect(find.byType(LoopChalkCard), findsWidgets);
    });
  });
}
