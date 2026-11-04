// S350b · decision 0275: 情报 · 算力, 算力榜 and MEME rows with readable
// data, shared by the polish checks and the self-review shots.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/intel/intel_screen.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_gateway.dart';
import 'package:loop_mobile/features/mining_rewards/mining_rewards_models.dart';

import 'launch2_fixtures.dart';
import 'loop_shots.dart';
import 's7_fixtures.dart';
import 's7_page_harness.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

// ---- 情报 · 算力 -------------------------------------------------------------

MiningNftTrack s350bNftTrack() => MiningNftTrack(
  realCount: BigInt.from(3),
  ownPower: Decimal.parse('3000.5'),
  invitePower: Decimal.zero,
  totalPower: Decimal.parse('3000.5'),
  reward: BigInt.zero,
  networkPower: Decimal.parse('25000.5'),
);

MiningAssetTrack s350bAssetTrack() => MiningAssetTrack(
  assets: const <MiningTrackAsset>[],
  ownPower: Decimal.parse('1234577.39'),
  invitePower: Decimal.zero,
  totalPower: Decimal.parse('1234577.39'),
  reward: BigInt.zero,
  networkPower: Decimal.parse('5000000.6'),
);

List<MiningAssetRow> s350bRows() => <MiningAssetRow>[
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
];

MiningRank s350bBoard(MiningRankScope scope) => s7MiningRank(
  scope: scope,
  snapshot: s7MiningSnapshot(),
  me: const MiningRankMe(rank: 12, value: '1240', communityId: 'mine'),
  myPosition: const MiningRankPositionSettled(position: 12, power: '1240'),
  ranking: switch (scope) {
    MiningRankScope.communities => MiningRankingCommunities(
      items: <MiningRankCommunityRow>[
        for (var index = 0; index < 8; index += 1)
          MiningRankCommunityRow(
            position: index + 1,
            power: '${12960 - index * 900}',
            community: MiningCommunityRef(
              communityId: 'community-${index + 1}',
              name: '社区${index + 1}',
              boundAssetId: s7CakeAssetId,
            ),
            weight: '1.0',
            participants: 30 - index,
          ),
      ],
      participants: 150,
    ),
    MiningRankScope.users => MiningRankingUsers(
      items: <MiningRankUserRow>[
        for (var index = 0; index < 8; index += 1)
          MiningRankUserRow(
            position: index + 1,
            power: '${425277 - index * 41000}',
            powerVisibility: MiningRankAudience.everyone,
            display: MiningRankAlias(
              alias: 'member${index + 1}',
              publicProfileId:
                  '8c2b7a15-4d3e-4f60-9a11-${(index + 1).toString().padLeft(12, '0')}',
              audience: MiningRankAudience.everyone,
            ),
            isSelf: false,
          ),
      ],
      participants: 240,
    ),
    MiningRankScope.referrals => const MiningRankingReferrals(
      items: <MiningRankReferralRow>[
        MiningRankReferralRow(
          position: 1,
          invitedCount: 12,
          display: MiningRankAlias(
            alias: 'inviter',
            publicProfileId: s7PublicProfileId,
            audience: MiningRankAudience.everyone,
          ),
          isSelf: false,
        ),
      ],
      participants: 40,
      ruleKey: 'mining.rank.referrals.directActiveEdges',
    ),
  },
);

/// The power page's reads: the summary and the assets as configured, every
/// board populated.
final class S350bMining implements MiningGateway {
  S350bMining({required this.summary, required this.assets});

  final MiningSummary summary;
  final MiningAssets assets;
  final FakeMiningGateway _inner = FakeMiningGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningSummary> loadSummary() => Future<MiningSummary>.value(summary);

  @override
  Future<MiningAssets> loadAssets() => Future<MiningAssets>.value(assets);

  @override
  Future<MiningRank> loadRank(MiningRankScope scope, {String? cursor}) =>
      Future<MiningRank>.value(s350bBoard(scope));

  @override
  Future<MiningCommunity> loadCommunity(String communityId) =>
      _inner.loadCommunity(communityId);

  @override
  Future<MiningRules> loadRules() => _inner.loadRules();
}

ReferralOverview s350bBoosted() {
  final base = s7Referral();
  return ReferralOverview(
    inviteCode: base.inviteCode,
    binding: base.binding,
    levels: base.levels,
    boost: null,
    boostAvailable: ReferralBoostAvailable(
      referralPower: '1280.5',
      nftReferralPower: '1000',
      assetReferralPower: '280.5',
      levels: <ReferralBoostLevel>[
        const ReferralBoostLevel(
          level: 1,
          effectiveMembers: 4,
          nftPower: '900',
          assetPower: '200',
        ),
        const ReferralBoostLevel(
          level: 3,
          effectiveMembers: 0,
          nftPower: '100',
          assetPower: '80.5',
        ),
      ],
      epochId: '0e358b31-e49f-48b9-89b2-c5c908c3ad5e',
      hourStart: DateTime.utc(2026, 11, 3, 8),
      hourEnd: DateTime.utc(2026, 11, 3, 9),
    ),
    inviteLink: 'https://api-staging.example.com/i/LOOP-7HJKM',
    // S353b: the three counts under the invite card.
    stats: ReferralStats(
      directCount: 4,
      validCount: 3,
      level2to5Count: 12,
      validAsOf: DateTime.utc(2026, 11, 3, 9),
    ),
    rules: base.rules,
  );
}

ReferralInviteePage s350bInvitees() => ReferralInviteePage(
  items: <ReferralInvitee>[
    for (var index = 0; index < 4; index += 1)
      ReferralInvitee(
        publicProfileId: null,
        alias: 'member${index + 1}',
        avatarRef: null,
        boundAt: DateTime.utc(2026, 11, 2 - index, 3),
        status: index == 3
            ? ReferralInviteeStatus.pending
            : ReferralInviteeStatus.valid,
      ),
  ],
  nextCursor: null,
);

/// 情报 · 算力 with the S350b data ([empty]: nothing counted, no hour), or
/// [page] over the same reads.
Future<void> s350bPumpPower(
  WidgetTester tester, {
  String? sub,
  bool empty = false,
  Size size = const Size(390, 1500),
  Widget? page,
}) async {
  await tester.runAsync(loopLoadShotFonts);
  await pumpS7Page(
    tester,
    page ?? IntelScreen(onNavigate: (_) {}, sub: sub),
    mining: S350bMining(
      summary: empty
          ? s7MiningBaselineSummary(power: '0')
          : s7MiningBaselineSummary(
              assetPower: '1234577.39',
              nftPower: '3000.5',
              power: '1237577.89',
              networkPower: '5025001.1',
              snapshot: s7MiningSnapshot(),
            ),
      assets: s7MiningSettledAssets(
        included: empty ? const <MiningAssetRow>[] : s350bRows(),
      ),
    ),
    referral: FakeReferralGateway(
      overview: S7Answer<ReferralOverview>(value: s350bBoosted()),
      invitees: S7Answer<ReferralInviteePage>(value: s350bInvitees()),
    ),
    size: size,
    overrides: <Override>[
      miningRewardsGatewayProvider.overrideWithValue(
        empty
            ? S7TokenStageRewards.preToken()
            : S7TokenStageRewards.preToken(
                nft: s350bNftTrack(),
                asset: s350bAssetTrack(),
              ),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

/// Taps one of 邀请's sub tabs.
Future<void> s350bSubTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: _key('referral-tabs'), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

// ---- 算力榜 -------------------------------------------------------------------

/// 算力榜 as its own page over the S350b boards.
Future<void> s350bPumpRank(
  WidgetTester tester, {
  Size size = const Size(390, 1500),
}) async {
  await tester.runAsync(loopLoadShotFonts);
  await pumpS7Page(
    tester,
    IntelRankBoard(onNavigate: (_) {}, onBack: () {}),
    mining: S350bMining(
      summary: s7MiningBaselineSummary(),
      assets: s7MiningSettledAssets(),
    ),
    size: size,
  );
}

// ---- MEME ---------------------------------------------------------------------

String _id(int n) => '8b9f3c1e-2d4a-4f6b-9c8d-${n.toString().padLeft(12, '0')}';

Map<String, Object?> s350bRow(
  int n,
  String stage, {
  int soldBps = 0,
  String name = 'Frog Launch',
  String ticker = 'FROG',
}) => l2RowJson(
  instanceId: _id(n),
  stage: stage,
  soldBps: soldBps,
  name: name,
  ticker: ticker,
  noNextChange: stage == 'public' || stage == 'graduated',
);
