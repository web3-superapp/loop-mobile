import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_recommendations_screen.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/features/community/plaza_screen.dart';

import 'support/community_test_harness.dart';

CommunityHome _home() => CommunityHome(
  joined: [
    JoinedCommunity(
      community: testCommunity(communityId: 'joined', name: '我的长期持有社区'),
      membership: testViewer(role: CommunityRole.member).membership!,
    ),
  ],
  joinedTruncated: false,
  discover: [
    for (var i = 0; i < 7; i++)
      testCommunity(communityId: 'recommended-$i', name: '推荐社区 $i'),
  ],
  unread: const LoopUnavailableFact('UNREAD_UNAVAILABLE'),
  liveVoice: const LoopUnavailableFact('VOICE_UNAVAILABLE'),
  recommendation: const CommunityRecommendation(
    recommendationId: 'home',
    ruleVersion: 'rule-1',
  ),
  source: 'home',
  observedAt: DateTime.utc(2026, 10, 3),
);

CommunitySummary _directoryCommunity(String id, String name) {
  final base = testCommunity(communityId: id, name: name);
  return CommunitySummary(
    communityId: base.communityId,
    name: base.name,
    slug: base.slug,
    description: '讨论长期持有与链上观察',
    logoRef: base.logoRef,
    verificationStatus: base.verificationStatus,
    boundAssetKey: base.boundAssetKey,
    memberCount: base.memberCount,
    createdAt: base.createdAt,
    configVersion: base.configVersion,
  );
}

void main() {
  testWidgets('joined content leads discovery on a narrow mobile screen', (
    tester,
  ) async {
    final locations = <String>[];
    await pumpCommunityPage(
      tester,
      CommunityScreen(onNavigate: locations.add),
      community: FakeCommunityGateway(home: _home()),
      size: const Size(320, 700),
    );
    final joined = find.byKey(const ValueKey('community-joined-joined'));
    final discover = find.byKey(const ValueKey('community-discover-hero'));
    expect(
      tester.getTopLeft(joined).dy,
      lessThan(tester.getTopLeft(discover).dy),
    );
    await tester.tap(joined);
    expect(locations, ['/community/profile?id=joined']);
    expect(find.byKey(const ValueKey('community-chat-segment')), findsNothing);
    expect(find.text('我的社区'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plaza shows descriptions and independent touchable cards', (
    tester,
  ) async {
    final gateway = FakeCommunityGateway(
      directoryPage: CommunityDirectoryPage(
        items: [
          _directoryCommunity('first', '一起讨论链上资产的社区'),
          _directoryCommunity('second', '第二个社区'),
        ],
        nextCursor: null,
        ordering: const CommunityOrderingApplied(
          sort: CommunityDirectorySort.members,
          basis: CommunityStoredBasis(),
        ),
        recommendation: const CommunityRecommendation(
          recommendationId: 'directory',
          ruleVersion: 'rule-1',
        ),
      ),
    );
    await pumpCommunityPage(
      tester,
      const PlazaScreen(),
      community: gateway,
      size: const Size(320, 700),
    );
    final first = find.byKey(const ValueKey('plaza-first'));
    final second = find.byKey(const ValueKey('plaza-second'));
    expect(
      tester.getTopLeft(second).dy - tester.getBottomLeft(first).dy,
      greaterThanOrEqualTo(0),
    );
    expect(tester.getSize(first).height, greaterThanOrEqualTo(88));
    expect(find.text('讨论长期持有与链上观察'), findsNWidgets(2));
    final communityTab = find.byKey(const ValueKey('plaza-destination-社区'));
    final voiceTab = find.byKey(const ValueKey('plaza-destination-语音房'));
    expect(tester.getSize(communityTab).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(voiceTab).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(communityTab).width, tester.getSize(voiceTab).width);
    expect(tester.getSize(communityTab).width, greaterThanOrEqualTo(140));
    await tester.tap(voiceTab);
    await tester.pumpAndSettle();
    expect(find.text('部分房间状态暂不可读'), findsOneWidget);
    expect(find.byKey(const ValueKey('plaza-destinations')), findsOneWidget);
    expect(find.text('上一页'), findsNothing);
    expect(find.text('下一页'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recommended selection keeps its next step visible for long lists',
    (tester) async {
      var skipped = 0;
      await pumpCommunityPage(
        tester,
        CommunityRecommendationsScreen(onDone: () => skipped++),
        community: FakeCommunityGateway(home: _home()),
        size: const Size(320, 700),
      );
      final join = find.byKey(const ValueKey('recommendations-join'));
      final skip = find.byKey(const ValueKey('recommendations-skip'));
      expect(tester.getBottomLeft(join).dy, lessThan(700));
      expect(tester.getBottomLeft(skip).dy, lessThan(700));
      expect(find.text('加入 5 个社区'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('recommendations-row-recommended-0')),
      );
      await tester.pumpAndSettle();
      expect(find.text('加入 4 个社区'), findsOneWidget);
      await tester.tap(skip);
      expect(skipped, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
