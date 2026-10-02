import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_home_widgets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/community_test_harness.dart';

void main() {
  for (final width in <double>[360, 390]) {
    testWidgets('community content and discovery actionable at $width', (
      tester,
    ) async {
      final opened = <String>[];
      final home = CommunityHome(
        joined: <JoinedCommunity>[
          JoinedCommunity(
            community: testCommunity(name: 'Design community'),
            membership: CommunityMembership(
              role: CommunityRole.member,
              status: CommunityMemberStatus.active,
              joinedAt: DateTime.utc(2026, 7),
            ),
          ),
        ],
        joinedTruncated: false,
        discover: const [],
        unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
        liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
        observedAt: DateTime.utc(2026, 10, 2),
        source: 'database',
        recommendation: const CommunityRecommendation(
          recommendationId: '22222222-2222-4222-8222-222222222222',
          ruleVersion: 'rule:verified-members-v1',
        ),
      );
      await pumpCommunityPage(
        tester,
        CommunityScreen(onNavigate: opened.add),
        community: FakeCommunityGateway(home: home),
        size: Size(width, 780),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LoopFolioPrimary), findsNothing);
      final row = find.text('Design community');
      expect(row.hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(row).dy, lessThan(500));
      final discover = find.byType(CommunityDiscoverHero);
      expect(tester.getSize(discover).height, greaterThanOrEqualTo(44));
      expect(tester.getSize(discover).height, lessThan(80));
      await tester.tap(discover);
      expect(opened, ['/community/discover']);
      await tester.tap(row);
      expect(opened.last, contains(testCommunityId));
    });
  }
}
