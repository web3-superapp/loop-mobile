// S355f · decision 0281: 360 x 800 English renders of the community, market
// and MEME pages, to look for truncation and overflow after the copy moved
// to ARB.
//
// Not a check: it writes to `LOOP_SHOTS_DIR` and runs only with
// `--dart-define=LOOP_SHOTS=true`; a plain `flutter test` skips every case.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/features/market/alerts/alerts_screen.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';

import 'support/community_test_harness.dart';
import 'support/loop_shots.dart';
import 'support/s269_pages.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

const bool _shots = bool.fromEnvironment('LOOP_SHOTS');
const String _dir = String.fromEnvironment(
  'LOOP_SHOTS_DIR',
  defaultValue: 'build/S355f/shots',
);
const Size _phone = Size(360, 800);

Future<void> _shot(WidgetTester tester, String name) =>
    loopShot(tester, name, slice: 800, dir: _dir);

CommunityHome _home() => CommunityHome(
  joined: <JoinedCommunity>[
    for (var index = 0; index < 3; index += 1)
      JoinedCommunity(
        community: testCommunity(
          communityId: '3fa85f64-5717-4562-b3fc-2c963f66af$index$index',
          name: 'Joined community $index',
          boundAssetKey: index < 2
              ? 'eip155:56:0x00000000000000000000000000000000000000a$index'
              : null,
        ),
        membership: CommunityMembership(
          role: CommunityRole.member,
          status: CommunityMemberStatus.active,
          joinedAt: DateTime.utc(2026, 7),
        ),
      ),
  ],
  joinedTruncated: false,
  discover: <CommunitySummary>[
    for (var index = 0; index < 3; index += 1)
      testCommunity(
        communityId: '4bb85f64-5717-4562-b3fc-2c963f66af$index$index',
        name: 'Discover $index',
      ),
  ],
  unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
  liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
  observedAt: DateTime.utc(2026, 9, 8, 1),
  source: 'database',
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
);

CommunityDirectoryPage _directory() => CommunityDirectoryPage(
  ordering: const CommunityOrderingApplied(
    sort: CommunityDirectorySort.members,
    basis: CommunityStoredBasis(),
  ),
  items: <CommunitySummary>[
    for (var index = 0; index < 4; index += 1)
      testCommunity(
        communityId: '5cc85f64-5717-4562-b3fc-2c963f66af$index$index',
        name: 'Community $index',
      ),
  ],
  nextCursor: null,
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
);

void main() {
  testWidgets('community home', skip: !_shots, (tester) async {
    await pumpCommunityPage(
      tester,
      const CommunityScreen(),
      community: FakeCommunityGateway(home: _home()),
      size: _phone,
    );
    await _shot(tester, 'S355f-community-home');
  });

  testWidgets('community discover', skip: !_shots, (tester) async {
    await pumpCommunityPage(
      tester,
      const CommunityDiscoverScreen(),
      community: FakeCommunityGateway(directoryPage: _directory()),
      size: _phone,
    );
    await _shot(tester, 'S355f-community-discover');
  });

  testWidgets('community profile', skip: !_shots, (tester) async {
    await pumpCommunityPage(
      tester,
      const CommunityProfileScreen(communityId: testCommunityId),
      community: FakeCommunityGateway(
        detail: testDetail(),
        members: testDirectory(),
      ),
      size: _phone,
    );
    await _shot(tester, 'S355f-community-profile');
  });

  testWidgets('community members', skip: !_shots, (tester) async {
    await pumpCommunityPage(
      tester,
      const CommunityMembersScreen(communityId: testCommunityId),
      community: FakeCommunityGateway(
        detail: testDetail(),
        members: testDirectory(),
      ),
      size: _phone,
    );
    await _shot(tester, 'S355f-community-members');
  });

  testWidgets('global search', skip: !_shots, (tester) async {
    await pumpCommunityPage(tester, const GlobalSearchScreen(), size: _phone);
    await _shot(tester, 'S355f-search');
  });

  testWidgets('market', skip: !_shots, (tester) async {
    await pumpS5Page(
      tester,
      const MarketScreen(),
      market: FakeMarketReadGateway(),
      size: _phone,
    );
    await _shot(tester, 'S355f-market');
  });

  testWidgets('token', skip: !_shots, (tester) async {
    await pumpS5Page(
      tester,
      const TokenDetailScreen(assetId: s5WbnbAssetId),
      market: FakeMarketReadGateway(),
      size: _phone,
    );
    await _shot(tester, 'S355f-token');
  });

  testWidgets('price alerts', skip: !_shots, (tester) async {
    await pumpS5Page(
      tester,
      const PriceAlertsScreen(),
      alerts: FakeAlertsGateway(),
      notifications: FakeNotificationsGateway(),
      size: _phone,
    );
    await _shot(tester, 'S355f-alerts');
  });

  testWidgets('watchlist editor', skip: !_shots, (tester) async {
    await pumpS5Page(
      tester,
      const WatchlistEditorScreen(),
      watchlist: FakeWatchlistGateway(),
      size: _phone,
    );
    await _shot(tester, 'S355f-watchlist-editor');
  });

  testWidgets('MEME home', skip: !_shots, (tester) async {
    await pumpS279MemeHome(tester, size: _phone);
    await _shot(tester, 'S355f-meme-home');
  });
}
