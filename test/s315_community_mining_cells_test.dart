import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';

import 'support/community_test_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// The bound asset of the staging community the requester owns (2026-10-27).
const _boundAssetId = 'eip155:97:0x040ecd2c604cfa86b35f817d845f441b97f46666';

CommunityHome _homeOwning(CommunitySummary community) => CommunityHome(
  joined: const <JoinedCommunity>[],
  joinedTruncated: false,
  owned: <OwnedCommunity>[
    OwnedCommunity(
      community: community,
      membership: CommunityMembership(
        role: CommunityRole.owner,
        status: CommunityMemberStatus.active,
        joinedAt: DateTime.utc(2026, 10),
      ),
    ),
  ],
  discover: const <CommunitySummary>[],
  unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
  liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
  observedAt: DateTime.utc(2026, 10, 27, 12),
  source: 'database',
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
);

FakeMiningGateway _mining() => FakeMiningGateway(
  community: S7Answer<MiningCommunity>(
    value: s7MiningCommunity(
      community: const MiningCommunityRef(
        communityId: testCommunityId,
        name: 'dad',
        boundAssetId: _boundAssetId,
      ),
      communityPower: const MiningFigureValue('2500000'),
      myContribution: const MiningFigureValue('2500000'),
    ),
  ),
  assets: S7Answer<MiningAssets>(
    value: s7MiningSettledAssets(
      included: <MiningAssetRow>[
        s7MiningAssetRow(
          assetId: _boundAssetId,
          symbol: '猫猫',
          holding: '2500000',
          weight: '1',
          power: '2500000',
        ),
      ],
    ),
  ),
);

/// The tab's list is alive under the record, the way the shell holds it when
/// a reader taps a community on 社区.
class _FromCommunityTab extends ConsumerWidget {
  const _FromCommunityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(communityHomeControllerProvider);
    if (home.value == null) {
      Future<void>.microtask(
        () => ref.read(communityHomeControllerProvider.notifier).load(),
      );
      return const SizedBox.shrink();
    }
    return const CommunityProfileScreen(communityId: testCommunityId);
  }
}

String? _cell(WidgetTester tester, String slug) => tester
    .widget<Text>(find.byKey(ValueKey<String>('community-mining-cell-$slug')))
    .data;

void main() {
  testWidgets('arriving from the 社区 tab, the three cells are read', (
    tester,
  ) async {
    final community = testCommunity(boundAssetKey: _boundAssetId);
    final gateway = FakeCommunityGateway(
      home: _homeOwning(community),
      detail: testDetail(
        community: community,
        miningPower: testSettledCommunityMiningPower(power: '2500000'),
      ),
    )..readDelay = const Duration(milliseconds: 300);
    await pumpCommunityPage(
      tester,
      const _FromCommunityTab(),
      community: gateway,
      mining: _mining(),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey<String>('community-mining-summary'));
    await scrollToCommunitySection(tester, card);
    expect(_cell(tester, 'holding'), '2,500,000 猫猫');
    expect(_cell(tester, 'power'), '2,500,000');
    expect(_cell(tester, 'estimated'), '—');
    // The fake network's delayed answers are drained with the page.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the asset key is matched whatever its case', (tester) async {
    final community = testCommunity(boundAssetKey: _boundAssetId);
    final mining = FakeMiningGateway(
      community: S7Answer<MiningCommunity>(
        value: s7MiningCommunity(
          community: MiningCommunityRef(
            communityId: testCommunityId,
            name: 'dad',
            boundAssetId: _boundAssetId.replaceFirst(
              '0x040ecd2c604cfa86b35f817d845f441b97f46666',
              '0x040ECD2C604cfa86b35f817d845f441b97f46666',
            ),
          ),
          myContribution: const MiningFigureValue('2500000'),
        ),
      ),
      assets: S7Answer<MiningAssets>(
        value: s7MiningSettledAssets(
          included: <MiningAssetRow>[
            s7MiningAssetRow(
              assetId: _boundAssetId,
              symbol: null,
              holding: '2500000',
              power: '2500000',
            ),
          ],
        ),
      ),
    );
    await pumpCommunityPage(
      tester,
      const CommunityProfileScreen(communityId: testCommunityId),
      community: FakeCommunityGateway(
        detail: testDetail(
          community: community,
          miningPower: testSettledCommunityMiningPower(power: '2500000'),
        ),
      ),
      mining: mining,
    );
    final card = find.byKey(const ValueKey<String>('community-mining-summary'));
    await scrollToCommunitySection(tester, card);
    expect(_cell(tester, 'holding'), '2,500,000');
  });

  testWidgets('a read in flight shows dashes and no sentence', (tester) async {
    final community = testCommunity(boundAssetKey: _boundAssetId);
    await pumpCommunityPage(
      tester,
      const CommunityProfileScreen(communityId: testCommunityId),
      community: FakeCommunityGateway(
        detail: testDetail(
          community: community,
          miningPower: testSettledCommunityMiningPower(power: '2500000'),
        ),
      ),
      mining: FakeMiningGateway(
        community: S7Answer<MiningCommunity>(pending: true),
        assets: S7Answer<MiningAssets>(pending: true),
      ),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 50));
    final card = find.byKey(const ValueKey<String>('community-mining-summary'));
    await tester.scrollUntilVisible(card, 300);
    expect(_cell(tester, 'holding'), '—');
    expect(_cell(tester, 'power'), '—');
    expect(find.textContaining('正在读取'), findsNothing);
    expect(find.textContaining('最近一次算力快照'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('community-mining-summary-note')),
      findsNothing,
    );
  });

  testWidgets('a failed read shows dashes and no sentence', (tester) async {
    final community = testCommunity(boundAssetKey: _boundAssetId);
    await pumpCommunityPage(
      tester,
      const CommunityProfileScreen(communityId: testCommunityId),
      community: FakeCommunityGateway(
        detail: testDetail(
          community: community,
          miningPower: testSettledCommunityMiningPower(power: '2500000'),
        ),
      ),
      mining: FakeMiningGateway(
        community: S7Answer<MiningCommunity>(
          failure: LaunchFailureKind.unavailable,
        ),
      ),
    );
    final card = find.byKey(const ValueKey<String>('community-mining-summary'));
    await scrollToCommunitySection(tester, card);
    expect(_cell(tester, 'power'), '—');
    expect(find.textContaining('可以进面板重试'), findsNothing);
  });

  testWidgets('社区榜: avatars, the board first, 未上榜 folded at its end', (
    tester,
  ) async {
    final rank = s7MiningRank(
      ranking: s7MiningCommunityBoard(
        items: const <MiningRankCommunityRow>[
          MiningRankCommunityRow(
            position: 1,
            power: '2500000',
            community: MiningCommunityRef(
              communityId: testCommunityId,
              name: 'dad',
              boundAssetId: _boundAssetId,
            ),
            weight: '1',
            participants: 1,
            avatarRef: 'avatar:preset/community-03',
          ),
          MiningRankCommunityRow(
            position: null,
            power: '0',
            community: MiningCommunityRef(
              communityId: s7OtherCommunityId,
              name: 'Builders Guild',
              boundAssetId: s7UsdtAssetId,
            ),
            weight: '1.5',
            participants: 0,
          ),
        ],
        participants: 1,
      ),
    );
    await pumpS7Page(
      tester,
      const MiningRankScreen(),
      mining: FakeMiningGateway(rank: S7Answer<MiningRank>(value: rank)),
    );

    // No card above the board, and no personal place under 社区榜.
    expect(find.text('全网位置'), findsNothing);
    expect(find.text('我的名次'), findsNothing);
    expect(find.textContaining('榜单按'), findsNothing);
    expect(find.text('Community Ranking'), findsNothing);
    expect(find.text('社区榜'), findsWidgets);

    final logo = tester.widget<CommunityLogo>(
      find.byKey(
        const ValueKey<String>('mining-rank-community-logo-$testCommunityId'),
      ),
    );
    expect(logo.logoRef, 'avatar:preset/community-03');
    expect(find.text('2,500,000'), findsOneWidget);

    // The unplaced community is folded until asked for.
    expect(find.text('未上榜 · 1'), findsOneWidget);
    expect(find.text('Builders Guild'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('mining-rank-unranked')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Builders Guild'), findsOneWidget);
    final fallback = tester.widget<CommunityLogo>(
      find.byKey(
        const ValueKey<String>(
          'mining-rank-community-logo-$s7OtherCommunityId',
        ),
      ),
    );
    expect(fallback.logoRef, isNull);
  });
}
