// S269 · 字体与间距规范 v3 (client decision 0229): the priority pages
// mounted with readable fixture data, shared by the type-scale check and the
// self-review shots.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/intel/intel_screen.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch2/launch2_campaigns.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart';
import 'package:loop_mobile/features/launch2/launch2_gateway.dart';
import 'package:loop_mobile/features/launch2/launch2_instance_screen.dart';
import 'package:loop_mobile/features/launch2/launch2_list.dart';
import 'package:loop_mobile/features/launch2/launch2_models.dart';
import 'package:loop_mobile/features/launch2/launch2_overview.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/square/square_screen.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/launch2/loop_v2_launch2_overview_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';

import 'community_test_harness.dart';
import 'launch2_fixtures.dart';
import 's5_fixtures.dart';
import 's5_page_harness.dart';
import 's7_fixtures.dart';
import 's7_page_harness.dart';

/// A 390-wide phone, tall enough for the first screens of a page.
const Size s269Phone = Size(390, 1688);

String _id(int n) => '8b9f3c1e-2d4a-4f6b-9c8d-${n.toString().padLeft(12, '0')}';

String _iso(DateTime value) => value.toUtc().toIso8601String();

LoopV2MetaSnapshot _meta() {
  final base = s7MetaSnapshot();
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: '2.0',
      configVersion: base.capabilities.configVersion,
      effectiveAt: base.capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in base.capabilities.capabilities)
          if (capability.id == LoopV2CapabilityId.launch2)
            const LoopV2Capability(
              id: LoopV2CapabilityId.launch2,
              availability: LoopV2CapabilityAvailability.available,
              reasonCode: null,
              evidence: LoopV2CapabilityEvidence(
                status: LoopV2CapabilityEvidenceStatus.notApplicable,
                reasonCode: null,
              ),
            )
          else
            capability,
      ],
    ),
  );
}

final class _Launch2 implements Launch2Gateway {
  _Launch2({required this.page, this.detail});

  final Launch2InstancePage page;
  final Launch2InstanceDetail? detail;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2InstancePage> listInstances({
    Launch2Stage? stage,
    String? cursor,
  }) => Future<Launch2InstancePage>.value(page);

  @override
  Future<Launch2InstanceDetail> loadInstance(String instanceId) {
    final value = detail;
    if (value == null) {
      return Future<Launch2InstanceDetail>.error(
        const LoopChainException(LoopChainFailureKind.unavailable),
      );
    }
    return Future<Launch2InstanceDetail>.value(value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<Never>.error(
    const LoopChainException(LoopChainFailureKind.unavailable),
  );
}

final class _Campaigns implements Launch2CampaignsGateway {
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Campaigns> loadCampaigns() => Future<Launch2Campaigns>.value(
    Launch2Campaigns(
      items: <Launch2DeskCampaign>[
        Launch2DeskCampaign(
          campaignId: 'c1',
          title: '外盘奖励周',
          subtitle: '跌超 10% 开轮，买入按权重分奖',
          coverUrl: null,
          startsAt: l2Now.subtract(const Duration(days: 1)),
          endsAt: l2Now.add(const Duration(days: 6)),
          link: const Launch2CampaignLink.route('/launch2'),
          pinned: true,
          state: Launch2CampaignState.live,
        ),
      ],
    ),
  );
}

Map<String, Object?> _activity(
  String kind, {
  required String hash,
  String ticker = 'DOGE',
  String? amount = '20',
  Duration ago = const Duration(seconds: 10),
}) => <String, Object?>{
  'kind': kind,
  'instanceId': _id(1),
  'ticker': ticker,
  'name': 'Doge on LOOP',
  'logoUrl': null,
  'actor': '0x1d2f000000000000000000000000000000009b9b',
  'amountUsd1': amount,
  'at': _iso(l2Now.subtract(ago)),
  'transactionHash': '0x${hash * 64}',
};

final class _Overview implements Launch2OverviewGateway {
  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<Launch2Overview> loadOverview() => Future<Launch2Overview>.value(
    LoopV2Launch2OverviewCodec.overview(<String, Object?>{
      'activity': <Object?>[
        _activity('curve_buy', hash: 'a'),
        _activity('curve_sell', hash: 'b', ticker: 'FROG', amount: '135.5'),
        _activity('curve_buy', hash: 'c', ticker: 'TC', amount: '8'),
      ],
      'stats': <String, Object?>{
        'liveCount': 9,
        'mintingCount': 2,
        'priorityCount': 1,
        'curveCount': 5,
        'upcomingCount': 0,
        'graduatedTotal': 12,
        'graduatedThisWeek': 3,
        'buybackUsd1Total': '4200.5',
        'nftMintedTotal': 318,
      },
      'observedAt': _iso(l2Now),
      'contractVersion': '2.0',
    }, mediaUrl: (_) => null),
  );
}

List<Override> _launch2Overrides(Launch2Gateway gateway) => <Override>[
  launch2GatewayProvider.overrideWithValue(gateway),
  launch2ClockProvider.overrideWithValue(() => l2Now),
  launch2PollingProvider.overrideWithValue(
    const Launch2Polling(
      detailInterval: Duration(hours: 1),
      tradingInterval: Duration(hours: 1),
      listInterval: Duration(hours: 1),
    ),
  ),
  loopFeatureSwitchesProvider.overrideWithValue(
    const LoopFeatureSwitchValues(launch2Visible: true),
  ),
  launch2CampaignsGatewayProvider.overrideWithValue(_Campaigns()),
  launch2OverviewGatewayProvider.overrideWithValue(_Overview()),
];

Map<String, Object?> _row(
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

const _powers = <String>['12960', '8420', '6115', '4870', '3210', '2045'];

MiningRank _boards(MiningRankScope scope) => s7MiningRank(
  scope: scope,
  ranking: MiningRankingCommunities(
    items: <MiningRankCommunityRow>[
      for (var index = 0; index < 12; index += 1)
        MiningRankCommunityRow(
          position: index + 1,
          power: _powers[index % _powers.length],
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
  me: const MiningRankMe(rank: 12, value: '1240', communityId: 'mine'),
  snapshot: s7MiningSnapshot(),
);

final class _BoardMining implements MiningGateway {
  final FakeMiningGateway _inner = FakeMiningGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningRank> loadRank(MiningRankScope scope, {String? cursor}) =>
      Future<MiningRank>.value(_boards(scope));

  @override
  Future<MiningSummary> loadSummary() => _inner.loadSummary();

  @override
  Future<MiningAssets> loadAssets() => _inner.loadAssets();

  @override
  Future<MiningCommunity> loadCommunity(String communityId) =>
      _inner.loadCommunity(communityId);

  @override
  Future<MiningRules> loadRules() => _inner.loadRules();
}

/// Unmounts a page and lets its timers run out.
Future<void> drainS269(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(hours: 2));
}

/// MEME home with S269's fixture data at 390 wide.
Future<void> pumpS269MemeHome(WidgetTester tester) async {
  await pumpS7Page(
    tester,
    Scaffold(
      body: Launch2ListSegment(
        scope: Launch2ListScope.all,
        tabTitle: 'MEME',
        onNavigate: (_) {},
      ),
    ),
    size: s269Phone,
    meta: _meta(),
    overrides: _launch2Overrides(
      _Launch2(
        page: l2Page(<Map<String, Object?>>[
          _row(1, 'public', soldBps: 6200, name: '天才少年', ticker: 'TC'),
          _row(2, 'public', soldBps: 2500, name: 'Frog Launch'),
          _row(3, 'public', soldBps: 900, name: 'S234W', ticker: 'S234W'),
          _row(4, 'graduated', soldBps: 10000, name: 'Doge on LOOP'),
          _row(5, 'graduated', soldBps: 10000, name: '月亮狗', ticker: 'MOON'),
        ]),
      ),
    ),
  );
}

/// MEME project page with S269's fixture data at 390 wide.
Future<void> pumpS269Project(WidgetTester tester) async {
  await pumpS7Page(
    tester,
    const Launch2InstanceScreen(instanceId: l2InstanceA),
    size: const Size(390, 2532),
    meta: _meta(),
    wallet: FakeWalletDirectory(
      activeWalletId: l2WalletId,
      wallets: <LoopWalletAccount>[
        LoopWalletAccount(
          walletId: l2WalletId,
          address: l2WalletAddress,
          kind: LoopWalletKind.embedded,
          status: LoopWalletStatus.active,
          isActive: true,
          firstSeenAt: DateTime.utc(2026, 9),
          lastSeenAt: DateTime.utc(2026, 10, 8),
        ),
      ],
    ),
    overrides: _launch2Overrides(
      _Launch2(
        page: l2Page(const <Map<String, Object?>>[]),
        detail: l2Detail(
          stage: 'public',
          viewer: l2ViewerJson(member: true, eligibleNow: true),
        ),
      ),
    ),
  );
}

/// 情报 with S269's fixture data at 390 wide.
Future<void> pumpS269Intel(WidgetTester tester) async {
  await pumpS7Page(
    tester,
    IntelScreen(onNavigate: (_) {}),
    mining: _BoardMining(),
    size: s269Phone,
  );
}

/// 广场 · 社区 with S269's fixture data at 390 wide.
Future<void> pumpS269Square(WidgetTester tester) async {
  await pumpCommunityPage(
    tester,
    SquareScreen(onOpenCommunity: (_) {}, onOpenVoiceRoom: (_) {}),
    size: s269Phone,
    community: FakeCommunityGateway(
      directoryPage: CommunityDirectoryPage(
        items: <CommunitySummary>[
          for (var index = 0; index < 10; index += 1)
            testCommunity(
              communityId:
                  '4b96a75e-6828-4a6b-8c1d-${index.toString().padLeft(12, '0')}',
              name: index.isEven ? 'DeFi 早读会 $index' : 'Frog 社区 $index',
            ),
        ],
        nextCursor: null,
        recommendation: const CommunityRecommendation(
          recommendationId: '22222222-2222-4222-8222-222222222222',
          ruleVersion: 'rule:verified-members-v1',
        ),
        ordering: const CommunityOrderingApplied(
          sort: CommunityDirectorySort.members,
          basis: CommunityStoredBasis(),
        ),
      ),
    ),
  );
}

/// 钱包 with S269's fixture data at 390 wide.
Future<void> pumpS269Wallet(WidgetTester tester) async {
  await pumpS5Page(
    tester,
    const WalletScreen(),
    wallet: FakeWalletReadGateway(),
    size: s269Phone,
  );
}

/// 代币页 with S269's fixture data at 390 wide.
Future<void> pumpS269Token(WidgetTester tester) async {
  await pumpS5Page(
    tester,
    const TokenDetailScreen(assetId: s5WbnbAssetId),
    market: FakeMarketReadGateway(),
    size: s269Phone,
  );
}
