import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chat/v2/community_chat_screen.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_screen.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/features/launch/launch_action_screens.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_detail_screens.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/market/alerts/alert_models.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/market_secondary_screens.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/features/mining/referral_gateway.dart';
import 'package:loop_mobile/features/mining/referral_models.dart';
import 'package:loop_mobile/features/mining/referral_screen.dart';
import 'package:loop_mobile/features/social/blocklist_screen.dart';
import 'package:loop_mobile/features/social/connections_screen.dart';
import 'package:loop_mobile/features/social/dm_requests_screen.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

/// Offline and Permission were the two thinnest columns of the 93-page
/// acceptance matrix (O 33/93, P 23/93). This file closes them page by page.
///
/// Every case mounts **one** page, drives **one** failure kind through that
/// page's own port, and names the block that must appear. A shared state block
/// is never the evidence: the page has to route the observation to it.
///
/// Two invariants are asserted everywhere:
/// * offline and error never collapse into each other, and
/// * a paused page never renders a zero, an empty list or a success.

// ---------------------------------------------------------------------------
// COMMUNITY / SOCIAL / CHAT — CommunityStateBlock pages
// ---------------------------------------------------------------------------

final class _CommunityCase {
  const _CommunityCase({required this.slug, required this.page});

  final String slug;
  final Widget page;
}

/// Mounts [page] with every community port answering the same [failure], so
/// the page's own routing — not a port that happened to succeed — is what the
/// assertion observes.
Future<void> _pumpWithCommunityFailure(
  WidgetTester tester,
  Widget page,
  CommunityFailureKind failure,
) => pumpCommunityPage(
  tester,
  page,
  community: FakeCommunityGateway(failure: failure),
  social: FakeSocialGateway(failure: failure),
  search: FakeSearchGateway(failure: failure),
  chat: FakeChatV2Gateway(failure: failure),
);

final List<_CommunityCase> _communityCases = <_CommunityCase>[
  const _CommunityCase(
    slug: 'search',
    page: GlobalSearchScreen(initialQuery: 'loop'),
  ),
  const _CommunityCase(
    slug: 'community-discover',
    page: CommunityDiscoverScreen(),
  ),
  const _CommunityCase(
    slug: 'community-profile',
    page: CommunityProfileScreen(communityId: testCommunityId),
  ),
  const _CommunityCase(
    slug: 'community-members',
    page: CommunityMembersScreen(communityId: testCommunityId),
  ),
  const _CommunityCase(
    slug: 'community-chat',
    page: CommunityChatScreen(communityId: testCommunityId),
  ),
  const _CommunityCase(
    slug: 'dm',
    page: DirectMessageScreen(
      target: DirectMessageTarget(publicProfileId: testMemberId),
    ),
  ),
  const _CommunityCase(slug: 'dm-requests', page: MessageRequestsScreen()),
  const _CommunityCase(slug: 'connections', page: ConnectionsScreen()),
  const _CommunityCase(slug: 'blocklist', page: BlocklistScreen()),
];

// ---------------------------------------------------------------------------
// LAUNCH / MINING / REFERRAL — LaunchStateBlock pages
// ---------------------------------------------------------------------------

typedef _S7Ports = ({
  LaunchGateway? launch,
  MiningGateway? mining,
  ReferralGateway? referral,
});

final class _S7Case {
  const _S7Case({required this.slug, required this.page, required this.ports});

  final String slug;
  final Widget page;
  final _S7Ports Function(LaunchFailureKind failure) ports;
}

_S7Ports _launchOnly(FakeLaunchGateway gateway) =>
    (launch: gateway, mining: null, referral: null);

_S7Ports _miningOnly(FakeMiningGateway gateway) =>
    (launch: null, mining: gateway, referral: null);

final List<_S7Case> _s7Cases = <_S7Case>[
  _S7Case(
    slug: 'launch',
    page: const LaunchScreen(),
    ports: (failure) => _launchOnly(
      FakeLaunchGateway(overview: S7Answer<LaunchOverview>(failure: failure)),
    ),
  ),
  _S7Case(
    slug: 'launch-rounds',
    page: const LaunchRoundsScreen(launchId: s7LaunchId),
    ports: (failure) => _launchOnly(
      FakeLaunchGateway(detail: S7Answer<LaunchDetail>(failure: failure)),
    ),
  ),
  _S7Case(
    slug: 'launch-history',
    page: const LaunchHistoryScreen(launchId: s7LaunchId),
    ports: (failure) => _launchOnly(
      FakeLaunchGateway(history: S7Answer<LaunchHistory>(failure: failure)),
    ),
  ),
  _S7Case(
    slug: 'launch-apply',
    page: const LaunchApplyScreen(),
    ports: (failure) => _launchOnly(
      FakeLaunchGateway(
        projects: S7Answer<LaunchProjectPage>(failure: failure),
      ),
    ),
  ),
  _S7Case(
    slug: 'mining',
    page: const MiningScreen(),
    ports: (failure) => _miningOnly(
      FakeMiningGateway(summary: S7Answer<MiningSummary>(failure: failure)),
    ),
  ),
  _S7Case(
    slug: 'mining-assets',
    page: const MiningAssetsScreen(),
    ports: (failure) => _miningOnly(
      FakeMiningGateway(assets: S7Answer<MiningAssets>(failure: failure)),
    ),
  ),
  _S7Case(
    slug: 'mining-rewards',
    page: const MiningRewardsScreen(),
    ports: (failure) => _miningOnly(
      FakeMiningGateway(rewards: S7Answer<MiningRewards>(failure: failure)),
    ),
  ),
  _S7Case(
    slug: 'mining-community',
    page: const MiningCommunityScreen(communityId: s7CommunityId),
    ports: (failure) => _miningOnly(
      FakeMiningGateway(community: S7Answer<MiningCommunity>(failure: failure)),
    ),
  ),
  _S7Case(
    slug: 'referral',
    page: const ReferralScreen(),
    ports: (failure) => (
      launch: null,
      mining: null,
      referral: FakeReferralGateway(
        overview: S7Answer<ReferralOverview>(failure: failure),
      ),
    ),
  ),
];

// ---------------------------------------------------------------------------
// MARKET — LoopChainStateBlock pages
// ---------------------------------------------------------------------------

final class _MarketCase {
  const _MarketCase({
    required this.slug,
    required this.page,
    required this.pump,
    this.prefixOverride,
  });

  final String slug;

  /// The page's state-block key prefix, when it differs from the slug.
  final String? prefixOverride;
  String get prefix => prefixOverride ?? slug;
  final Widget page;
  final Future<void> Function(
    WidgetTester tester,
    Widget page,
    LoopChainFailureKind failure,
  )
  pump;
}

final List<_MarketCase> _marketCases = <_MarketCase>[
  _MarketCase(
    slug: 'market',
    page: const MarketScreen(),
    pump: (tester, page, failure) => pumpS5Page(
      tester,
      page,
      market: FakeMarketReadGateway(
        overview: S5Answer<MarketOverview>(failure: failure),
      ),
    ),
  ),
  _MarketCase(
    slug: 'token',
    page: const TokenDetailScreen(assetId: s5WbnbAssetId),
    pump: (tester, page, failure) => pumpS5Page(
      tester,
      page,
      market: FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(failure: failure),
      ),
    ),
  ),
  _MarketCase(
    slug: 'token-trades',
    page: const TradingActivityScreen(assetId: s5WbnbAssetId),
    pump: (tester, page, failure) => pumpS5Page(
      tester,
      page,
      market: FakeMarketReadGateway(
        trades: S5Answer<MarketTradesPage>(failure: failure),
      ),
    ),
  ),
  _MarketCase(
    slug: 'watchlist-edit',
    prefixOverride: 'watchlist',
    page: const WatchlistEditorScreen(),
    pump: (tester, page, failure) => pumpS5Page(
      tester,
      page,
      watchlist: FakeWatchlistGateway(
        snapshot: S5Answer<WatchlistSnapshot>(failure: failure),
      ),
    ),
  ),
  _MarketCase(
    slug: 'alerts',
    page: const PriceAlertsScreen(),
    pump: (tester, page, failure) => pumpS5Page(
      tester,
      page,
      alerts: FakeAlertsGateway(
        page: S5Answer<LoopAlertPage>(failure: failure),
      ),
    ),
  ),
];

void main() {
  group('community · offline and permission', () {
    for (final testCase in _communityCases) {
      testWidgets('${testCase.slug} pauses offline instead of erroring', (
        tester,
      ) async {
        await _pumpWithCommunityFailure(
          tester,
          testCase.page,
          CommunityFailureKind.offline,
        );

        expect(
          find.byKey(const ValueKey<String>('community-state-offline')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('community-state-error')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('community-state-empty')),
          findsNothing,
          reason: 'an offline read is not "there is nothing"',
        );
      });

      testWidgets(
        '${testCase.slug} renders a refusal as the permission state',
        (tester) async {
          await _pumpWithCommunityFailure(
            tester,
            testCase.page,
            CommunityFailureKind.permissionDenied,
          );

          expect(
            find.byKey(const ValueKey<String>('community-state-permission')),
            findsOneWidget,
          );
          expect(find.textContaining('当前账号没有执行这个操作的权限'), findsWidgets);
          expect(
            find.byKey(const ValueKey<String>('community-state-empty')),
            findsNothing,
          );
        },
      );
    }
  });

  group('launch and mining · offline and permission', () {
    for (final testCase in _s7Cases) {
      testWidgets('${testCase.slug} pauses offline instead of erroring', (
        tester,
      ) async {
        final ports = testCase.ports(LaunchFailureKind.offline);
        await pumpS7Page(
          tester,
          testCase.page,
          launch: ports.launch,
          mining: ports.mining,
          referral: ports.referral,
        );

        expect(
          find.byKey(ValueKey<String>('${testCase.slug}-state-offline')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey<String>('${testCase.slug}-state-error')),
          findsNothing,
        );
        expect(
          find.byKey(ValueKey<String>('${testCase.slug}-state-empty')),
          findsNothing,
        );
      });

      testWidgets(
        '${testCase.slug} renders a refusal as the permission state',
        (tester) async {
          final ports = testCase.ports(LaunchFailureKind.permissionDenied);
          await pumpS7Page(
            tester,
            testCase.page,
            launch: ports.launch,
            mining: ports.mining,
            referral: ports.referral,
          );

          expect(
            find.byKey(ValueKey<String>('${testCase.slug}-state-permission')),
            findsOneWidget,
          );
          expect(find.textContaining('当前账号没有执行这个操作的权限'), findsWidgets);
        },
      );
    }
  });

  group('market · offline and permission', () {
    for (final testCase in _marketCases) {
      testWidgets('${testCase.slug} pauses offline instead of erroring', (
        tester,
      ) async {
        await testCase.pump(
          tester,
          testCase.page,
          LoopChainFailureKind.offline,
        );

        expect(
          find.byKey(ValueKey<String>('${testCase.prefix}-state-offline')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey<String>('${testCase.prefix}-state-error')),
          findsNothing,
        );
        expect(
          find.byKey(ValueKey<String>('${testCase.prefix}-state-empty')),
          findsNothing,
        );
      });

      testWidgets(
        '${testCase.slug} renders a refusal as the permission state',
        (tester) async {
          await testCase.pump(
            tester,
            testCase.page,
            LoopChainFailureKind.permissionDenied,
          );

          expect(
            find.byKey(ValueKey<String>('${testCase.prefix}-state-permission')),
            findsOneWidget,
          );
          expect(
            find.byKey(ValueKey<String>('${testCase.prefix}-state-empty')),
            findsNothing,
          );
        },
      );
    }
  });
}
