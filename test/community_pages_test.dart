import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';
import 'support/loop_stream_scroll.dart';

CommunityHome _home({
  int joined = 1,
  bool truncated = false,
  int discover = 1,
  int mining = 0,
}) => CommunityHome(
  joined: <JoinedCommunity>[
    for (var index = 0; index < joined; index += 1)
      JoinedCommunity(
        community: testCommunity(
          communityId: '3fa85f64-5717-4562-b3fc-2c963f66af$index$index',
          name: 'Joined $index',
          // The first [mining] rows bound an asset, which is the whole of
          // what 「在挖矿」 means on this page and what splits the two groups.
          boundAssetKey: index < mining
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
  joinedTruncated: truncated,
  discover: <CommunitySummary>[
    for (var index = 0; index < discover; index += 1)
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

CommunityHome _homeWith({
  required LoopUnavailableFact unread,
  required LoopUnavailableFact liveVoice,
}) {
  final home = _home();
  return CommunityHome(
    joined: home.joined,
    joinedTruncated: home.joinedTruncated,
    discover: home.discover,
    unread: unread,
    liveVoice: liveVoice,
    observedAt: home.observedAt,
    source: home.source,
    recommendation: home.recommendation,
  );
}

void main() {
  group('community · home aggregate', () {
    testWidgets('loading shows a skeleton and no figure', (tester) async {
      final gateway = FakeCommunityGateway()..pending = true;
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
        settle: false,
      );

      expect(find.byType(LoopSkeleton), findsOneWidget);
      // A read that is still running says so. 「暂无数值 / 社区数据暂时读不到」
      // is the answer to a read that finished with nothing, and it was the
      // first thing every cold start said for its first seconds.
      expect(find.text('正在读取'), findsOneWidget);
      expect(find.textContaining('读到之后显示在这里'), findsOneWidget);
      expect(find.text(communityMissingHeading), findsNothing);
      expect(find.textContaining('社区数据暂时读不到'), findsNothing);
      expect(find.text(communityMissingFigure), findsNothing);
      expect(find.textContaining('个已加入的社区'), findsNothing);
    });

    testWidgets('a finished read with nothing still says it read nothing', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        failure: CommunityFailureKind.offline,
      );
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
      );

      expect(find.text(communityMissingHeading), findsOneWidget);
      expect(find.textContaining('社区数据暂时读不到'), findsOneWidget);
      expect(find.text('正在读取'), findsNothing);
    });

    testWidgets('ready renders only server figures', (tester) async {
      final gateway = FakeCommunityGateway(
        home: _home(joined: 3, discover: 3, mining: 2),
      );
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
      );

      // The prototype's own heading: how many of the reader's communities
      // bound an asset, not how many were joined.
      expect(find.text('2 个社区在挖矿'), findsOneWidget);
      // `discover` is a preview the server cut to a handful. Its length was
      // printed as the number of verified communities, which read 5 while the
      // directory held 36, and then as 「这里先给 3 个」, which is the same
      // figure wearing a different sentence. The hero states neither.
      expect(find.textContaining('个已验证社区'), findsNothing);
      expect(find.textContaining('这里先给'), findsNothing);
      expect(find.textContaining('VERIFIED'), findsNothing);
      expect(find.text('Joined 0'), findsOneWidget);
      // The discover list moved to its own page; the hero states the count.
      expect(find.text('Discover 0'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('community-discover-hero')),
        findsOneWidget,
      );
      // The rule is described in plain language; its internal id never
      // reaches the screen, and the page never calls it a recommendation.
      expect(find.textContaining('rule:'), findsNothing);
      expect(find.textContaining('推荐只按成员数与创建时间排列'), findsOneWidget);
    });

    testWidgets(
      'a joined row states a community the operator has not verified',
      (tester) async {
        final gateway = FakeCommunityGateway(
          home: CommunityHome(
            joined: <JoinedCommunity>[
              JoinedCommunity(
                community: testCommunity(
                  name: 'Alpha Signals 7',
                  verification: CommunityVerification.pending,
                ),
                membership: CommunityMembership(
                  role: CommunityRole.member,
                  status: CommunityMemberStatus.active,
                  joinedAt: DateTime.utc(2026, 7),
                ),
              ),
            ],
            joinedTruncated: false,
            discover: const <CommunitySummary>[],
            unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
            liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
            observedAt: DateTime.utc(2026, 9, 8, 1),
            source: 'database',
            recommendation: const CommunityRecommendation(
              recommendationId: '22222222-2222-4222-8222-222222222222',
              ruleVersion: 'rule:verified-members-v1',
            ),
          ),
        );
        await pumpCommunityPage(
          tester,
          const CommunityScreen(),
          community: gateway,
        );

        // The membership is a full one — 审核中 is the community's own state,
        // and the row used to read exactly like a verified community's.
        expect(find.textContaining('审核中'), findsOneWidget);
        // It bound no asset, so it is not one of the mining communities.
        expect(find.text('0 个社区在挖矿'), findsOneWidget);
      },
    );

    testWidgets('an empty aggregate never renders a zero', (tester) async {
      final gateway = FakeCommunityGateway(home: _home(joined: 0, discover: 0));
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
      );

      expect(find.text('0 个社区在挖矿'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-joined-empty')),
        findsOneWidget,
      );
    });

    testWidgets('offline pauses the actions and offers a retry', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        failure: CommunityFailureKind.offline,
      );
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsOneWidget,
      );
    });

    testWidgets('an unexpected failure is an error state, not empty', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        failure: CommunityFailureKind.unexpected,
      );
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsOneWidget,
      );
    });

    testWidgets('activation required renders the permission state', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        failure: CommunityFailureKind.activationRequired,
      );
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-permission')),
        findsOneWidget,
      );
      expect(find.textContaining('LOOP ID 激活'), findsOneWidget);
    });

    testWidgets('a deferred module issues no request at all', (tester) async {
      final gateway = FakeCommunityGateway(home: _home());
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
        meta: testMetaSnapshot(
          community: LoopV2CapabilityAvailability.deferred,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-capability-unavailable')),
        findsOneWidget,
      );
      expect(gateway.commands, isEmpty);
      expect(find.textContaining('个已加入的社区'), findsNothing);
    });

    testWidgets('an explicit Preview session is labelled and not gated', (
      tester,
    ) async {
      // A Preview session never observes the public capability document, and
      // its adapter makes no server claim, so the gate does not apply.
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: FakeCommunityGateway(
          mode: CommunityGatewayMode.preview,
          home: _home(),
        ),
        meta: testMetaSnapshot(
          community: LoopV2CapabilityAvailability.unavailable,
        ),
      );

      expect(find.text('演示数据'), findsOneWidget);
      expect(find.text('开发预览'), findsWidgets);
      expect(find.text('0 个社区在挖矿'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-capability-unavailable')),
        findsNothing,
      );
    });

    testWidgets('the message panel states what is true, not two failures', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: FakeCommunityGateway(home: _home()),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('community-message-toggle')),
      );
      await tester.pumpAndSettle();

      // Neither line is a failed read: LOOP publishes no total unread count
      // in this version, and this account is in no room.
      expect(
        find.byKey(const ValueKey<String>('community-unread-deferred')),
        findsOneWidget,
      );
      expect(find.text('你现在不在任何语音房里'), findsOneWidget);
      expect(find.textContaining('暂时读不到'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('community-unread-unavailable')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-live-voice-unavailable')),
        findsNothing,
      );
      expect(find.textContaining('3 NEW'), findsNothing);
    });

    testWidgets('a reason the panel does not recognise stays a failure', (
      tester,
    ) async {
      final home = _homeWith(
        unread: const LoopUnavailableFact('COMMUNICATION_RUNTIME_UNAVAILABLE'),
        liveVoice: const LoopUnavailableFact(
          'COMMUNICATION_RUNTIME_UNAVAILABLE',
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: FakeCommunityGateway(home: home),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('community-message-toggle')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('community-unread-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-live-voice-unavailable')),
        findsOneWidget,
      );
      expect(find.text('你现在不在任何语音房里'), findsNothing);
    });

    testWidgets('the page is laid out in the prototype\'s own order', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: FakeCommunityGateway(
          home: _home(joined: 3, discover: 2, mining: 2),
        ),
      );

      // The order is the prototype's: the discover band, then the index
      // folio, then the mining communities, then everything else, and the
      // reading's timestamp last. It used to be folio, then one flat list.
      final order = <Key>[
        const ValueKey<String>('community-discover-hero'),
        const ValueKey<String>('community-folio'),
        const ValueKey<String>('community-mining-group'),
        const ValueKey<String>('community-other-group'),
        const ValueKey<String>('community-observed-at'),
      ];
      final tops = <double>[
        for (final key in order) tester.getTopLeft(find.byKey(key)).dy,
      ];
      for (var index = 1; index < tops.length; index += 1) {
        expect(
          tops[index],
          greaterThan(tops[index - 1]),
          reason: '${order[index]} must sit below ${order[index - 1]}',
        );
      }
      expect(find.text('带币社区 · 可挖矿'), findsOneWidget);
      expect(find.text('其他社区'), findsOneWidget);
    });

    testWidgets('the index folio carries no report vocabulary', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: FakeCommunityGateway(home: _home(joined: 1, mining: 1)),
      );

      // 「数据观察于 … / DATABASE」 was the page's primary sentence, in the one
      // place a reader looks first. The reading still has to be datable, so
      // the timestamp survives at the foot of the page — and the stamp, which
      // the prototype spends on 「N LIVE」, is not spent on the word DATABASE.
      expect(find.text('DATABASE'), findsNothing);
      final folio = tester.widget<LoopFolioPrimary>(
        find.byKey(const ValueKey<String>('community-folio')),
      );
      expect(folio.stamp, isNull);
      expect(folio.caption, isNot(contains('数据观察于')));
      expect(find.textContaining('数据观察于 2026-09-08 01:00 UTC'), findsOneWidget);
    });

    testWidgets('a row prints the head count and never an unread zero', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: FakeCommunityGateway(
          home: CommunityHome(
            joined: <JoinedCommunity>[
              JoinedCommunity(
                community: testCommunity(
                  name: 'Frog Holders',
                  memberCount: 48120,
                  boundAssetKey:
                      'eip155:56:0x00000000000000000000000000000000000000aa',
                ),
                membership: CommunityMembership(
                  role: CommunityRole.member,
                  status: CommunityMemberStatus.active,
                  joinedAt: DateTime.utc(2026, 7),
                ),
              ),
            ],
            joinedTruncated: false,
            discover: const <CommunitySummary>[],
            unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
            liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
            observedAt: DateTime.utc(2026, 9, 8, 1),
            source: 'database',
            recommendation: const CommunityRecommendation(
              recommendationId: '22222222-2222-4222-8222-222222222222',
              ruleVersion: 'rule:verified-members-v1',
            ),
          ),
        ),
      );

      // 「48120 成员」 is six digits a reader has to count; grouping is
      // display-only and reversible.
      expect(find.textContaining('48,120 成员'), findsOneWidget);
      // The weight belongs to a per-community mining read this page does not
      // issue, so the row carries no 「×」 at all rather than a placeholder.
      expect(find.textContaining('×'), findsNothing);
      // `.badge.badge-up` carries an unread count. There is no unread source,
      // so no row wears one and no row wears a zero.
      expect(find.byType(LoopBadge), findsNothing);
    });

    testWidgets('a preset logo resolves to the community atlas', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: FakeCommunityGateway(
          home: CommunityHome(
            joined: <JoinedCommunity>[
              JoinedCommunity(
                community: testCommunity(
                  communityId: '3fa85f64-5717-4562-b3fc-2c963f66af11',
                  name: 'Alpha One',
                  logoRef: 'avatar:preset/community-01',
                ),
                membership: CommunityMembership(
                  role: CommunityRole.member,
                  status: CommunityMemberStatus.active,
                  joinedAt: DateTime.utc(2026, 7),
                ),
              ),
              JoinedCommunity(
                community: testCommunity(
                  communityId: '3fa85f64-5717-4562-b3fc-2c963f66af22',
                  name: 'Beta Nine',
                  logoRef: 'avatar:preset/community-09',
                ),
                membership: CommunityMembership(
                  role: CommunityRole.member,
                  status: CommunityMemberStatus.active,
                  joinedAt: DateTime.utc(2026, 7),
                ),
              ),
            ],
            joinedTruncated: false,
            discover: const <CommunitySummary>[],
            unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
            liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
            observedAt: DateTime.utc(2026, 9, 8, 1),
            source: 'database',
            recommendation: const CommunityRecommendation(
              recommendationId: '22222222-2222-4222-8222-222222222222',
              ruleVersion: 'rule:verified-members-v1',
            ),
          ),
        ),
      );

      // All twelve published presets are cells of the 4x3 atlas, so both rows
      // draw their own mark and neither falls back to initials.
      expect(
        find.byKey(
          const ValueKey<String>(
            'community-logo-image-avatar:preset/community-01',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'community-logo-image-avatar:preset/community-09',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('BE'), findsNothing);
      expect(find.text('AL'), findsNothing);
    });

    testWidgets('a community the server gave no preset keeps its initials', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: FakeCommunityGateway(home: _home()),
      );

      // Not another community's mark, and not an empty square: the row shows
      // the community's own letters on the ground its id is always given.
      expect(find.text('JO'), findsOneWidget);
    });

    testWidgets('the message panel states a room this account is in', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: FakeCommunityGateway(home: _home()),
        voiceRoomSession: const VoiceRoomSession(
          communityId: testCommunityId,
          communityName: 'Frog Holders',
          voiceRoomId: 'room-1',
          callRoomId: null,
          role: VoiceRoomRole.listener,
          joinedCount: 12,
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('community-message-toggle')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('community-live-voice-row')),
        findsOneWidget,
      );
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('1 NEW'), findsOneWidget);
      // The room is on the panel as a row, so the panel does not also say
      // this account is in no room.
      expect(find.text('你现在不在任何语音房里'), findsNothing);
    });

    testWidgets('a truncated joined list routes to the paginated directory', (
      tester,
    ) async {
      final destinations = <String>[];
      await pumpCommunityPage(
        tester,
        CommunityScreen(onNavigate: destinations.add),
        community: FakeCommunityGateway(home: _home(truncated: true)),
      );

      final finder = find.byKey(
        const ValueKey<String>('community-view-all-joined'),
      );
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      expect(destinations, <String>['/community/discover?membership=joined']);
    });
  });

  group('community-discover', () {
    testWidgets('all four segments carry a server-backed order', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        directoryPage: CommunityDirectoryPage(
          ordering: const CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),

          items: <CommunitySummary>[testCommunity()],
          nextCursor: null,
          recommendation: const CommunityRecommendation(
            recommendationId: '22222222-2222-4222-8222-222222222222',
            ruleVersion: 'rule:verified-members-v1',
          ),
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: gateway,
      );

      LoopSeg seg(String name) => tester.widget<LoopSeg>(
        find.byKey(ValueKey<String>('discover-seg-$name')),
      );
      for (final name in <String>['members', 'newest', 'power', 'discussion']) {
        expect(seg(name).onSelected, isNotNull, reason: name);
      }
      // The two orders decision 0061 added are asked for by name, so a
      // deployment that cannot apply one answers for itself.
      await tester.tap(
        find.byKey(const ValueKey<String>('discover-seg-power')),
      );
      await tester.pumpAndSettle();
      expect(gateway.commands.last, startsWith('list:miningPower:'));
      await tester.tap(
        find.byKey(const ValueKey<String>('discover-seg-discussion')),
      );
      await tester.pumpAndSettle();
      expect(gateway.commands.last, startsWith('list:activity:'));
      // Nothing on the page tells the reader to wait for a module that is
      // already live.
      expect(find.textContaining('开放后'), findsNothing);
    });

    testWidgets('the last page of the desk says it is the last', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        directoryPage: CommunityDirectoryPage(
          ordering: const CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),

          items: <CommunitySummary>[testCommunity()],
          nextCursor: null,
          recommendation: const CommunityRecommendation(
            recommendationId: '22222222-2222-4222-8222-222222222222',
            ruleVersion: 'rule:verified-members-v1',
          ),
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: gateway,
      );

      final end = find.byKey(const ValueKey<String>('community-discover-end'));
      await scrollToCommunitySection(tester, end);
      expect(end, findsOneWidget);
    });

    testWidgets('the heading counts what is loaded, never a total it lacks', (
      tester,
    ) async {
      // The directory answers one cursor page and carries no total. The
      // heading read "20 个社区" over a directory of 36.
      final gateway = FakeCommunityGateway(
        directoryPage: CommunityDirectoryPage(
          ordering: const CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),

          items: <CommunitySummary>[testCommunity()],
          nextCursor: 'cursor-2',
          recommendation: const CommunityRecommendation(
            recommendationId: '22222222-2222-4222-8222-222222222222',
            ruleVersion: 'rule:verified-members-v1',
          ),
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: gateway,
      );

      expect(find.text('已载入 1 个社区'), findsOneWidget);
      expect(find.text('1 个社区'), findsNothing);

      // With the last page in, the loaded rows are the whole answer and the
      // heading may say so.
      gateway.directoryPage = CommunityDirectoryPage(
        ordering: const CommunityOrderingApplied(
          sort: CommunityDirectorySort.members,
          basis: CommunityStoredBasis(),
        ),

        items: <CommunitySummary>[testCommunity()],
        nextCursor: null,
        recommendation: const CommunityRecommendation(
          recommendationId: '22222222-2222-4222-8222-222222222222',
          ruleVersion: 'rule:verified-members-v1',
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('discover-seg-newest')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 个社区'), findsOneWidget);
    });

    testWidgets('choosing 新社区 refetches with the newest sort', (tester) async {
      final gateway = FakeCommunityGateway(
        directoryPage: CommunityDirectoryPage(
          ordering: const CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),

          items: <CommunitySummary>[testCommunity()],
          nextCursor: null,
          recommendation: const CommunityRecommendation(
            recommendationId: '22222222-2222-4222-8222-222222222222',
            ruleVersion: 'rule:verified-members-v1',
          ),
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: gateway,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('discover-seg-newest')),
      );
      await tester.pumpAndSettle();

      expect(gateway.commands.last, 'list:newest:all:null');
    });

    testWidgets('an empty directory states the filter, not a zero', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        directoryPage: const CommunityDirectoryPage(
          ordering: CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),

          items: <CommunitySummary>[],
          nextCursor: null,
          recommendation: CommunityRecommendation(
            recommendationId: '22222222-2222-4222-8222-222222222222',
            ruleVersion: 'rule:verified-members-v1',
          ),
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: gateway,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsOneWidget,
      );
    });

    testWidgets('the joined entry point narrows the membership filter', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        directoryPage: CommunityDirectoryPage(
          ordering: const CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),

          items: <CommunitySummary>[testCommunity()],
          nextCursor: null,
          recommendation: const CommunityRecommendation(
            recommendationId: '22222222-2222-4222-8222-222222222222',
            ruleVersion: 'rule:verified-members-v1',
          ),
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(joinedOnly: true),
        community: gateway,
      );

      expect(gateway.commands.single, 'list:members:joined:null');
    });
  });

  group('community-profile', () {
    testWidgets('成员 is a top-bar icon control, not a section switch', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpCommunityPage(
        tester,
        CommunityProfileScreen(
          communityId: testCommunityId,
          onOpenMembers: opened.add,
        ),
        community: FakeCommunityGateway(detail: testDetail()),
      );

      final action = find.byKey(
        const ValueKey<String>('community-profile-open-members'),
      );
      expect(action, findsOneWidget);
      final button = tester.widget<LoopIconButton>(action);
      expect(button.icon, 'users');
      expect(button.label, '成员');
      expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
      // The word is spoken, not printed: a labelled segment beside the title
      // read as a section the page was already on.
      expect(find.text('成员'), findsNothing);

      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(opened, <String>[testCommunityId]);
    });

    testWidgets('AI opens the AI page rather than answering with a toast', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpCommunityPage(
        tester,
        CommunityProfileScreen(
          communityId: testCommunityId,
          onOpenAi: opened.add,
        ),
        community: FakeCommunityGateway(detail: testDetail()),
      );

      final action = find.byKey(
        const ValueKey<String>('community-profile-open-ai'),
      );
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(opened, <String>[testCommunityId]);
      // The reason stays on the record's own line, once; it is no longer a
      // second copy that appears and takes itself away again.
      expect(
        find.byKey(const ValueKey<String>('community-profile-action-reasons')),
        findsOneWidget,
      );
      expect(find.textContaining('Community AI 还没有开放'), findsOneWidget);
    });

    testWidgets('an open Community AI is not announced as closed', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(detail: testDetail()),
        meta: testMetaSnapshot(
          communityAi: LoopV2CapabilityAvailability.available,
        ),
      );

      // The capability document is the only thing that decides this line: an
      // available AI leaves nothing under the button, and the page no longer
      // contradicts the working page the button opens.
      expect(find.textContaining('Community AI 还没有开放'), findsNothing);
      final reasons = find.byKey(
        const ValueKey<String>('community-profile-action-reasons'),
      );
      await scrollToCommunitySection(tester, reasons);
      // The other two controls keep their own reasons on the same line.
      expect(find.textContaining('该社区还没有官方群频道。'), findsOneWidget);
    });

    testWidgets('the verification state is stated once, in words', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(detail: testDetail()),
      );

      // The folio stamp carried 「VERIFIED」 while the identity card under it
      // carried 「已验证」: one fact, twice, in two languages.
      expect(find.text('VERIFIED'), findsNothing);
      expect(find.text('已验证'), findsOneWidget);
    });

    testWidgets('a community under review says so where verified would be', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: testCommunity(
              verification: CommunityVerification.pending,
            ),
          ),
        ),
      );

      // Dropping the stamp must not drop the two states it was the only
      // carrier of.
      expect(find.text('PENDING'), findsNothing);
      expect(find.text('审核中'), findsOneWidget);
    });

    testWidgets('an observed online count prints the number and the time', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            onlineCount: CommunityOnlineCountObserved(
              count: 1,
              observedAt: DateTime.utc(2026, 9, 16, 6, 44, 39, 224),
              source: CommunityPresenceSource.streamMemberPresence,
            ),
          ),
        ),
      );

      // The reading sits in the identity line, beside the member count, which
      // is where a reader looks for it.
      expect(find.textContaining('128 成员 · 1 在线'), findsOneWidget);
      // 「1 在线」 alone would be read as "active recently" or as the
      // membership, so the explanation is one tap away, on the reading
      // itself — not four permanent lines halfway down the record.
      expect(find.textContaining('与 Stream 保持连接'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey<String>('community-online-count-explain')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('与 Stream 保持连接'), findsOneWidget);
      expect(find.textContaining('最近活跃'), findsOneWidget);
      // The observation carries its own time, in UTC, as the server gave it.
      expect(find.text('观察于 2026-09-16 06:44 UTC'), findsOneWidget);
    });

    testWidgets('a zero observation is a reading, not an absence', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            onlineCount: CommunityOnlineCountObserved(
              count: 0,
              observedAt: DateTime.utc(2026, 9, 16, 6, 44, 39, 224),
              source: CommunityPresenceSource.streamMemberPresence,
            ),
          ),
        ),
      );

      // Stream answered zero: the page prints it instead of hiding behind the
      // silence it keeps when nobody asked.
      expect(find.textContaining('128 成员 · 0 在线'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-online-count-explain')),
        findsOneWidget,
      );
    });

    testWidgets('a presence read that failed never becomes a number', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            onlineCount: const CommunityOnlineCountUnavailable(
              'STREAM_PRESENCE_READ_TIMEOUT',
            ),
          ),
        ),
      );

      // A reading that was not taken has no segment in the identity line and
      // no explanation to offer: the line carries the member count alone.
      expect(find.text('128 成员'), findsOneWidget);
      expect(find.textContaining('在线'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('community-online-count-explain')),
        findsNothing,
      );
      expect(find.textContaining('0 人'), findsNothing);
    });

    testWidgets("a settled community power explains why it is that number", (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(miningPower: testSettledCommunityMiningPower()),
        ),
      );

      final card = find.byKey(
        const ValueKey<String>('community-mining-summary'),
      );
      await scrollToCommunitySection(tester, card);
      // The reviewed weight is the card's own figure, and the community's
      // power is the line under it: both are sums over one bound asset.
      expect(
        find.byKey(const ValueKey<String>('community-mining-weight')),
        findsOneWidget,
      );
      expect(find.text('0.8'), findsOneWidget);
      expect(find.textContaining('社区总算力 0'), findsOneWidget);
      // The reading says which baseline settled it, and when.
      expect(find.textContaining('开发基线'), findsOneWidget);
      expect(find.textContaining('2026-09-15 14:58 UTC'), findsOneWidget);
      // The version that settled it stays a backend identifier.
      expect(find.textContaining('miningFormula-devBaseline'), findsNothing);
      // The three per-account columns have no source in this read, so they
      // print the dash and the card says where they are read instead.
      expect(find.text('我的持仓'), findsOneWidget);
      expect(find.text('我的算力'), findsOneWidget);
      expect(find.text('预估/日'), findsOneWidget);
      expect(find.textContaining('社区挖矿面板里读'), findsOneWidget);
    });

    // Decision 0057: the number stays, and the card says which moment it is
    // from, because the run after it could not value a holding and was never
    // published.
    testWidgets('a community power a later run overtook is dated', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            miningPower: testSettledCommunityMiningPower(stale: true),
          ),
        ),
      );

      final card = find.byKey(
        const ValueKey<String>('community-mining-summary'),
      );
      await scrollToCommunitySection(tester, card);
      expect(
        find.textContaining('显示的是 2026-09-15 14:58 UTC 的算力快照 · 最近一次快照未完成'),
        findsOneWidget,
      );
      // The figure is still the one the last complete snapshot settled.
      expect(find.textContaining('社区总算力 0'), findsOneWidget);
      expect(find.text('0.8'), findsOneWidget);
    });

    testWidgets('a weight still under review says so instead of a value', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            miningPower: testSettledCommunityMiningPower(
              weight: const MiningCommunityWeightPending(
                reasonCode: 'COMMUNITY_WEIGHT_PENDING_REVIEW',
                reviewStatus: MiningWeightReviewStatus.pendingReview,
              ),
            ),
          ),
        ),
      );

      final card = find.byKey(
        const ValueKey<String>('community-mining-summary'),
      );
      await scrollToCommunitySection(tester, card);
      expect(find.textContaining('权重还在审核中'), findsOneWidget);
      // A weight under review has no value to print, and the settled power
      // stays the server's own 0: the pending weight is why it is zero.
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('community-mining-weight')),
            )
            .data,
        '—',
      );
      expect(find.textContaining('社区总算力 0'), findsOneWidget);
    });

    testWidgets('a community with nothing bound has no weight to review', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            miningPower: testSettledCommunityMiningPower(
              weight: const MiningCommunityWeightPending(
                reasonCode: 'COMMUNITY_ASSET_NOT_BOUND',
                reviewStatus: MiningWeightReviewStatus.notApplicable,
              ),
            ),
          ),
        ),
      );

      final card = find.byKey(
        const ValueKey<String>('community-mining-summary'),
      );
      await scrollToCommunitySection(tester, card);
      // The card states the fact it was given. A review nobody is performing
      // is not a state it may announce (Decision 0046).
      expect(find.textContaining('没有绑定代币，没有权重可审'), findsOneWidget);
      expect(find.textContaining('权重还在审核中'), findsNothing);
    });

    testWidgets('an unbound asset renders no token card', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(detail: testDetail()),
      );

      expect(
        find.byKey(const ValueKey<String>('community-profile-no-asset')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-bound-asset')),
        findsNothing,
      );
      // One quiet line, not an information card: an absence must not take
      // more room than the facts around it.
      expect(find.text('未绑定社区币'), findsOneWidget);
    });

    testWidgets('a bound asset shows the key without a market figure', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: testCommunity(
              boundAssetKey:
                  'eip155:56:0x00000000000000000000000000000000000000aa',
            ),
          ),
        ),
      );

      final card = find.byKey(const ValueKey<String>('community-bound-asset'));
      await scrollToCommunitySection(tester, card);
      expect(card, findsOneWidget);
      // The card reads the market module for this key. Nothing answers in
      // this harness, so every figure states its absence and none of them
      // becomes a number.
      expect(find.textContaining('行情暂时读不到'), findsOneWidget);
      expect(find.text('暂无价格'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
      // No series is readable either, so the card carries no chart slot: an
      // empty 106px box under a range label points at a line that is not
      // there.
      expect(find.textContaining('暂无走势'), findsOneWidget);
      expect(find.textContaining('根收盘价'), findsNothing);
    });

    testWidgets('mining, presence, announcements and links stay unavailable', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(detail: testDetail()),
      );

      // Every unavailable field states the server's own reason where it
      // stands, and none of them becomes a figure.
      final mining = find.byKey(
        const ValueKey<String>('community-mining-summary-note'),
      );
      await scrollToCommunitySection(tester, mining);
      expect(find.textContaining('挖矿规则还没有确定'), findsOneWidget);
      final announcements = find.byKey(
        const ValueKey<String>('community-announcements-unavailable'),
      );
      await scrollToCommunitySection(tester, announcements);
      expect(announcements, findsOneWidget);
      expect(find.textContaining('暂无公告'), findsOneWidget);
      final links = find.byKey(
        const ValueKey<String>('community-links-unavailable'),
      );
      await scrollToCommunitySection(tester, links);
      expect(links, findsOneWidget);
      expect(find.textContaining('暂无官方链接'), findsOneWidget);
    });

    testWidgets('a verified community is not told its channel waits on '
        'verification', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        // The default community is verified and has no official channel: the
        // exact pair the old sentence contradicted.
        community: FakeCommunityGateway(detail: testDetail()),
      );

      final reasons = find.byKey(
        const ValueKey<String>('community-profile-action-reasons'),
      );
      await scrollToCommunitySection(tester, reasons);
      expect(find.textContaining('该社区还没有官方群频道。'), findsOneWidget);
      // The one code covers both a missing row and an unfinished one, so the
      // page states the fact and claims no cause for it.
      expect(find.textContaining('通过验证后'), findsNothing);
      expect(find.textContaining('验证后才会创建'), findsNothing);
    });

    testWidgets('a non-member sees join, and the sheet must be confirmed', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        detail: testDetail(viewer: testViewer(role: null)),
      );
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: gateway,
      );

      final join = find.byKey(const ValueKey<String>('community-join-action'));
      await tester.ensureVisible(join);
      await tester.tap(join);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('community-membership-sheet')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-cancel')),
      );
      await tester.pumpAndSettle();
      expect(gateway.commands, isEmpty);

      await tester.tap(join);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();
      expect(gateway.commands, <String>['join:$testCommunityId']);
      expect(find.text('已加入社区'), findsOneWidget);
    });

    testWidgets('a refused join shows no success toast', (tester) async {
      final gateway = FakeCommunityGateway(
        detail: testDetail(viewer: testViewer(role: null)),
        writeFailure: CommunityFailureKind.permissionDenied,
      );
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: gateway,
      );

      final join = find.byKey(const ValueKey<String>('community-join-action'));
      await tester.ensureVisible(join);
      await tester.tap(join);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(find.text('已加入社区'), findsNothing);
      expect(find.textContaining('没有执行这个操作的权限'), findsWidgets);
    });

    testWidgets('only the owner is offered the profile edit action', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(viewer: testViewer(role: CommunityRole.member)),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('community-edit-profile-action')),
        findsNothing,
      );

      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(viewer: testViewer(role: CommunityRole.owner)),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('community-edit-profile-action')),
        findsOneWidget,
      );
      // The owner is never offered a leave control the server would refuse.
      expect(
        find.byKey(const ValueKey<String>('community-leave-action')),
        findsNothing,
      );
      final notice = find.byKey(
        const ValueKey<String>('community-owner-cannot-leave'),
      );
      await scrollToCommunitySection(tester, notice);
      expect(notice, findsOneWidget);
      // The transfer demotes the previous owner to Admin, which is what the
      // members page's confirmation says. This line says the same thing.
      expect(find.textContaining('降为 Admin'), findsOneWidget);
      expect(find.textContaining('普通成员'), findsNothing);
    });

    testWidgets('a banned viewer is told, and cannot leave or act', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            viewer: testViewer(
              role: CommunityRole.member,
              status: CommunityMemberStatus.banned,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-membership-banned')),
        findsOneWidget,
      );
      expect(find.textContaining('无需重新加入'), findsOneWidget);
      // Nothing on a banned membership can act.
      expect(
        find.byKey(const ValueKey<String>('community-leave-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-join-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-edit-profile-action')),
        findsNothing,
      );
    });

    testWidgets('a missing community id issues no request', (tester) async {
      final gateway = FakeCommunityGateway(detail: testDetail());
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: null),
        community: gateway,
      );

      expect(
        find.byKey(const ValueKey<String>('community-profile-missing-id')),
        findsOneWidget,
      );
      expect(gateway.commands, isEmpty);
    });

    testWidgets('the record is laid out in the prototype\'s own order', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        size: const Size(390, 4000),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: testCommunity(
              boundAssetKey:
                  'eip155:56:0x00000000000000000000000000000000000000aa',
            ),
            viewer: testViewer(role: CommunityRole.member),
            onlineCount: CommunityOnlineCountObserved(
              count: 2,
              observedAt: DateTime.utc(2026, 9, 16, 6, 44),
              source: CommunityPresenceSource.streamMemberPresence,
            ),
            announcements: CommunityAnnouncementFeedPublished(
              <CommunityAnnouncement>[
                CommunityAnnouncement(
                  announcementId: 'a-1',
                  kind: 'pinned',
                  title: 'Q3 路线图已发布',
                  byline: '项目方',
                  publishedAt: DateTime.utc(2026, 9, 16, 5),
                  pinned: true,
                ),
              ],
            ),
            officialLinks: const CommunityOfficialLinksPublished(
              <CommunityOfficialLink>[
                CommunityOfficialLink(
                  label: 'Website',
                  url: 'https://example.invalid/loop',
                ),
              ],
            ),
          ),
        ),
      );

      // The frozen order, top to bottom: folio, identity, the three
      // controls, the token card, mining, announcements, official links,
      // membership. A section that moves moves this test.
      final order = <Finder>[
        find.byKey(const ValueKey<String>('loop-page-primary')),
        find.byKey(const ValueKey<String>('community-profile-logo')),
        find.byKey(const ValueKey<String>('community-profile-open-chat')),
        find.byKey(const ValueKey<String>('community-bound-asset')),
        find.byKey(const ValueKey<String>('community-mining-summary')),
        find.byKey(const ValueKey<String>('community-announcements')),
        find.byKey(const ValueKey<String>('community-links')),
        find.byKey(const ValueKey<String>('community-leave-action')),
      ];
      var previous = double.negativeInfinity;
      for (var index = 0; index < order.length; index += 1) {
        final finder = order[index];
        expect(finder, findsOneWidget, reason: 'section $index');
        final offset = tester.getTopLeft(finder).dy;
        expect(
          offset,
          greaterThan(previous),
          reason: 'section $index is out of the prototype order',
        );
        previous = offset;
      }
      // The two blocks the record no longer carries: a second identity card
      // repeating the folio, and a 聊天与语音 row group.
      expect(find.text('社区官方群'), findsNothing);
      expect(find.text('语音房'), findsNothing);
      expect(find.text('在线'), findsNothing);
    });
  });

  group('community-profile · 开启语音房', () {
    Future<void> pumpProfile(
      WidgetTester tester, {
      required CommunityRole role,
      CommunityVoiceSection voice = testVoiceUnavailable,
      FakeVoiceRoomGateway? voiceRoom,
      ValueChanged<String>? onOpenVoiceRoom,
    }) => pumpCommunityPage(
      tester,
      CommunityProfileScreen(
        communityId: testCommunityId,
        onOpenVoiceRoom: onOpenVoiceRoom,
      ),
      community: FakeCommunityGateway(
        detail: testDetail(
          viewer: testViewer(role: role),
          voice: voice,
        ),
      ),
      voiceRoom: voiceRoom ?? FakeVoiceRoomGateway(),
    );

    Future<void> scrollToVoice(WidgetTester tester, Finder target) =>
        tester.scrollUntilVisible(
          target,
          120,
          scrollable: find.byType(Scrollable).first,
        );

    final createButton = find.byKey(
      const ValueKey<String>('community-profile-create-voice-room'),
    );

    testWidgets('an owner is offered the room when none is live', (
      tester,
    ) async {
      await pumpProfile(tester, role: CommunityRole.owner);

      await scrollToVoice(tester, createButton);
      expect(createButton, findsOneWidget);
    });

    testWidgets('an admin is offered the room as well', (tester) async {
      await pumpProfile(tester, role: CommunityRole.admin);

      await scrollToVoice(tester, createButton);
      expect(createButton, findsOneWidget);
    });

    testWidgets('a member is not offered the room at all', (tester) async {
      await pumpProfile(tester, role: CommunityRole.member);

      await scrollToVoice(
        tester,
        find.byKey(const ValueKey<String>('community-profile-open-voice')),
      );
      expect(createButton, findsNothing);
    });

    testWidgets('a live room is entered, not opened again', (tester) async {
      await pumpProfile(
        tester,
        role: CommunityRole.owner,
        voice: testVoiceLive,
      );

      // A live room is entered through the glyph button; the opening control
      // is not on the page at all.
      final enter = find.byKey(
        const ValueKey<String>('community-profile-open-voice'),
      );
      await scrollToVoice(tester, enter);
      expect(createButton, findsNothing);
      expect(tester.widget<LoopButton>(enter).onPressed, isNotNull);
      // S77d: a room that is running is marked on the control itself.
      expect(tester.widget<LoopButton>(enter).semanticLabel, '进入语音房 · 进行中');
      expect(tester.widget<LoopButton>(enter).label, 'LIVE');
    });

    testWidgets('ending the room drops the row the community page had read', (
      tester,
    ) async {
      final community = FakeCommunityGateway(
        detail: testDetail(
          viewer: testViewer(role: CommunityRole.owner),
          voice: testVoiceLive,
        ),
      );
      final voiceRoom = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
      );
      await pumpCommunityPage(
        tester,
        const _VoiceRoomReturnHarness(),
        community: community,
        voiceRoom: voiceRoom,
      );

      // The community page was read while the room was live, so the voice
      // control is an entry rather than an opening.
      expect(
        find.byKey(const ValueKey<String>('community-profile-open-voice')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('community-profile-create-voice-room'),
        ),
        findsNothing,
      );

      // The server's answer changes the moment the room ends; the page under
      // the room still holds the old one until it reads again.
      community.detail = testDetail(
        viewer: testViewer(role: CommunityRole.owner),
        voice: testVoiceUnavailable,
      );
      voiceRoom.loadSnapshot = null;

      await tester.tap(find.byKey(const ValueKey<String>('harness-open-room')));
      await tester.pumpAndSettle();
      final end = find.byKey(const ValueKey<String>('voiceroom-end'));
      await tester.scrollUntilVisible(
        end,
        220,
        scrollable: find
            .descendant(
              of: find.byType(VoiceRoomScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(end);
      await tester.pumpAndSettle();
      await tester.tap(find.text('结束房间').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('harness-open-community')),
      );
      await tester.pumpAndSettle();
      // The room is gone, so the owner is offered the opening again and the
      // entry is not on the page.
      expect(
        find.byKey(const ValueKey<String>('community-profile-open-voice')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('community-profile-create-voice-room'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('opening a room is confirmed first, then entered', (
      tester,
    ) async {
      final voiceRoom = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true),
      );
      final entered = <String>[];
      await pumpProfile(
        tester,
        role: CommunityRole.owner,
        voiceRoom: voiceRoom,
        onOpenVoiceRoom: entered.add,
      );

      await scrollToVoice(tester, createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('community-open-voice-room-sheet')),
        findsOneWidget,
      );
      // The sheet states the consequence before anything is created.
      expect(find.textContaining('任何成员都能进来收听'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-cancel')),
      );
      await tester.pumpAndSettle();
      expect(voiceRoom.commands, isEmpty);

      await tester.tap(createButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(voiceRoom.commands, contains('create:$testCommunityId'));
      expect(find.text('语音房已开启'), findsOneWidget);
      expect(entered, <String>[testCommunityId]);
    });

    testWidgets('a room opened elsewhere lights this page up while it waits', (
      tester,
    ) async {
      // The review devices: the second phone stood on the community page
      // while the room was opened on the first, and its voice control stayed
      // dark for as long as it was looked at.
      final voiceRoom = FakeVoiceRoomGateway();
      await pumpProfile(
        tester,
        role: CommunityRole.member,
        voiceRoom: voiceRoom,
        onOpenVoiceRoom: (_) {},
      );

      final enter = find.byKey(
        const ValueKey<String>('community-profile-open-voice'),
      );
      await scrollToVoice(tester, enter);
      expect(tester.widget<LoopButton>(enter).onPressed, isNull);

      // Somebody opens a room. Nothing on this page was touched.
      voiceRoom.snapshot = testVoiceRoomSnapshot();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(voiceRoom.commands, contains('current:$testCommunityId'));
      expect(tester.widget<LoopButton>(enter).onPressed, isNotNull);
      // S77d: a room that is running is marked on the control itself.
      expect(tester.widget<LoopButton>(enter).semanticLabel, '进入语音房 · 进行中');
      expect(tester.widget<LoopButton>(enter).label, 'LIVE');
    });

    testWidgets('a room that ends takes the entry with it', (tester) async {
      // The watched row replaces the record's own rather than being added to
      // it: an entry left standing over a room that ended is a door into
      // 「房间已结束」, and the owner cannot open the next room while it is
      // there.
      final voiceRoom = FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot());
      await pumpProfile(
        tester,
        role: CommunityRole.owner,
        voice: testVoiceLive,
        voiceRoom: voiceRoom,
        onOpenVoiceRoom: (_) {},
      );

      final enter = find.byKey(
        const ValueKey<String>('community-profile-open-voice'),
      );
      await scrollToVoice(tester, enter);
      // S77d: a room that is running is marked on the control itself.
      expect(tester.widget<LoopButton>(enter).semanticLabel, '进入语音房 · 进行中');
      expect(tester.widget<LoopButton>(enter).label, 'LIVE');

      // The room ends somewhere else.
      voiceRoom.snapshot = null;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(enter, findsNothing);
      expect(createButton, findsOneWidget);
    });

    testWidgets('the community page behind or below reads nothing', (
      tester,
    ) async {
      final voiceRoom = FakeVoiceRoomGateway();
      await pumpProfile(
        tester,
        role: CommunityRole.member,
        voiceRoom: voiceRoom,
        onOpenVoiceRoom: (_) {},
      );

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final onScreen = voiceRoom.commands.length;
      expect(onScreen, greaterThan(0));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 60));
      expect(voiceRoom.commands, hasLength(onScreen));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(
        voiceRoom.commands.length,
        greaterThan(onScreen),
        reason: 'a reader who comes back is not shown the moment they left',
      );
    });

    testWidgets('a room nobody can enter yet is not entered', (tester) async {
      // 201 says the room row committed, not that the call behind it exists.
      // A host walked into a room that could not be heard; the page now says
      // what is missing and keeps the one control that finishes it.
      final voiceRoom = FakeVoiceRoomGateway(
        createdSnapshot: testVoiceRoomSnapshot(
          role: VoiceRoomRole.host,
          host: true,
          backstage: true,
          providerConfirmed: false,
          providerReason: 'STREAM_CALL_GO_LIVE_UNCONFIRMED',
        ),
      );
      final entered = <String>[];
      await pumpProfile(
        tester,
        role: CommunityRole.owner,
        voiceRoom: voiceRoom,
        onOpenVoiceRoom: entered.add,
      );

      await scrollToVoice(tester, createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(voiceRoom.commands, contains('create:$testCommunityId'));
      expect(find.text('语音房已开启'), findsNothing);
      expect(entered, isEmpty);
      // The host's own two sentences: what is missing, and the one control
      // that finishes it.
      expect(find.textContaining('还没有开放收听'), findsOneWidget);
      expect(find.textContaining('再点一次「开启语音房」'), findsOneWidget);
      // The control that repeats the unfinished half is still on the page.
      expect(createButton, findsOneWidget);
    });

    testWidgets('a room that is already live is stated, not claimed', (
      tester,
    ) async {
      final voiceRoom = FakeVoiceRoomGateway(
        snapshot: testVoiceRoomSnapshot(),
        createFailure: CommunityFailureKind.resourceConflict,
      );
      final entered = <String>[];
      await pumpProfile(
        tester,
        role: CommunityRole.admin,
        voiceRoom: voiceRoom,
        onOpenVoiceRoom: entered.add,
      );

      await scrollToVoice(tester, createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(voiceRoom.commands, contains('create:$testCommunityId'));
      expect(find.textContaining('已经有进行中的语音房'), findsOneWidget);
      expect(find.text('语音房已开启'), findsNothing);
      expect(entered, isEmpty);
    });
  });

  group('community-members · permission matrix', () {
    testWidgets('segment counts come from the server and 在线 is disabled', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(members: testDirectory()),
      );

      expect(find.text('全部 128'), findsOneWidget);
      expect(find.text('Owner 1'), findsOneWidget);
      expect(find.text('Admin 3'), findsOneWidget);
      expect(
        tester
            .widget<LoopSeg>(
              find.byKey(const ValueKey<String>('members-seg-online')),
            )
            .onSelected,
        isNull,
      );
      // The directory never observes presence, so this page states that it
      // does not carry the figure rather than that a read failed.
      expect(
        find.byKey(
          const ValueKey<String>('community-members-online-not-observed'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('在线人数暂时读不到'), findsNothing);
    });

    testWidgets('the last page of members says it is the last', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(members: testDirectory()),
      );

      final end = find.byKey(const ValueKey<String>('community-members-end'));
      await scrollToCommunitySection(tester, end);
      // The 载入更多 control simply vanished on the last page, and a list that
      // ends in silence reads as one that stopped loading.
      expect(end, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-members-load-more')),
        findsNothing,
      );
    });

    testWidgets('the disabled 在线 chip answers the tap it cannot honour', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(members: testDirectory()),
      );

      final online = find.byKey(const ValueKey<String>('members-seg-online'));
      await tester.ensureVisible(online);
      await tester.pumpAndSettle();
      await tester.tap(online);
      await tester.pump();

      // It stays unselectable; it just stops swallowing the tap in silence.
      expect(tester.widget<LoopSeg>(online).onSelected, isNull);
      expect(find.text(memberDirectoryPresenceNote), findsWidgets);
    });

    testWidgets('the banned view heads itself, not the whole directory', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          members: testDirectory(),
          membersByFilter: <CommunityMemberFilter, CommunityMemberDirectory>{
            CommunityMemberFilter.banned: testDirectory(
              items: <CommunityMemberEntry>[
                testMember(
                  role: CommunityRole.member,
                  status: CommunityMemberStatus.banned,
                ),
              ],
            ),
          },
        ),
      );

      expect(find.text('128 名成员'), findsOneWidget);

      final bannedSeg = find.byKey(
        const ValueKey<String>('members-seg-banned'),
      );
      await tester.ensureVisible(bannedSeg);
      await tester.pumpAndSettle();
      await tester.tap(bannedSeg);
      await tester.pumpAndSettle();
      // The chip row is reached by scrolling the horizontal strip, and on a
      // short viewport that also carries the hero off the top. The heading is
      // read where it is read: at the top of the list.
      await loopStreamScrollToTop(tester);

      // The server counts roles, never this filter: the directory's 128 is
      // not the number of banned members and is not printed over them.
      expect(find.text('128 名成员'), findsNothing);
      expect(find.text('已封禁的成员'), findsOneWidget);
      // And the directory-wide power card is about a row this page no longer
      // shows, so it says nothing instead of 「这一项暂时读不到」.
      expect(find.text('成员算力'), findsNothing);
    });

    testWidgets('an empty banned view does not call 封禁 a role', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          members: testDirectory(),
          membersByFilter: <CommunityMemberFilter, CommunityMemberDirectory>{
            CommunityMemberFilter.banned: testDirectory(
              items: const <CommunityMemberEntry>[],
            ),
          },
        ),
      );

      final bannedSeg = find.byKey(
        const ValueKey<String>('members-seg-banned'),
      );
      await tester.ensureVisible(bannedSeg);
      await tester.pumpAndSettle();
      await tester.tap(bannedSeg);
      await tester.pumpAndSettle();

      expect(find.text('这个筛选下没有成员'), findsOneWidget);
      expect(find.text('这个社区目前没有被封禁的成员。'), findsOneWidget);
      expect(find.textContaining('这个角色下没有成员'), findsNothing);
    });

    testWidgets('a member with no alias does not say its id twice', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          members: testDirectory(
            items: <CommunityMemberEntry>[
              testMember(role: CommunityRole.member, alias: null),
            ],
          ),
        ),
      );

      final row = find.byKey(
        const ValueKey<String>('member-row-$testMemberId'),
      );
      await tester.scrollUntilVisible(
        row,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      final rendered = tester.widget<LoopRecordRow>(row);
      expect(rendered.title, 'LOOP-3HJKMNPQ');
      expect(rendered.subtitle, isNot('LOOP-3HJKMNPQ'));
      expect(rendered.subtitle, startsWith('加入于 '));
    });

    testWidgets('a row renders exactly the commands the server published', (
      tester,
    ) async {
      // The viewer is an admin. The server's viewer-level flags still say
      // this admin may mute and ban somewhere in this community, but the
      // permission matrix confines an admin to `member` targets, so the row
      // for another admin arrives with no command at all. Deriving the row
      // from the flags is what used to offer a mute and a ban here, and the
      // server answered every one of them with 403.
      final gateway = FakeCommunityGateway(
        members: testDirectory(
          viewer: testViewer(role: CommunityRole.admin, canInviteAdmin: false),
          items: <CommunityMemberEntry>[
            testMember(
              role: CommunityRole.admin,
              publicProfileId: testAdminId,
              loopId: 'LOOP-9HJKMNPQ',
              alias: 'frog_admin',
              actions: const <CommunityGovernanceAction>[],
            ),
            testMember(
              role: CommunityRole.member,
              alias: 'frog_member',
              actions: const <CommunityGovernanceAction>[
                CommunityGovernanceAction.mute,
                CommunityGovernanceAction.ban,
              ],
            ),
          ],
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
        social: FakeSocialGateway(),
      );

      await tester.tap(find.text('frog_admin'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('public-profile-sheet')),
        findsOneWidget,
      );
      for (final action in CommunityGovernanceAction.values) {
        expect(
          find.byKey(ValueKey<String>('public-profile-action-${action.name}')),
          findsNothing,
          reason: 'admin row offered ${action.name}',
        );
      }
      await tester.tap(
        find.byKey(const ValueKey<String>('public-profile-close')),
      );
      await tester.pumpAndSettle();

      // The same page, the same viewer: the member row carries the two
      // commands the server did publish, and nothing else.
      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      for (final action in CommunityGovernanceAction.values) {
        final offered =
            action == CommunityGovernanceAction.mute ||
            action == CommunityGovernanceAction.ban;
        expect(
          find.byKey(ValueKey<String>('public-profile-action-${action.name}')),
          offered ? findsOneWidget : findsNothing,
          reason: 'member row: ${action.name}',
        );
      }
    });

    testWidgets('an owner row renders whatever the server published for it', (
      tester,
    ) async {
      // The owner row is empty because the server said so, not because the
      // client knows the owner is never a target.
      final gateway = FakeCommunityGateway(
        members: testDirectory(
          items: <CommunityMemberEntry>[
            testMember(
              role: CommunityRole.owner,
              publicProfileId: testOwnerId,
              loopId: 'LOOP-1HJKMNPQ',
              alias: 'frog_owner',
              actions: const <CommunityGovernanceAction>[],
            ),
          ],
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
        social: FakeSocialGateway(),
      );

      await tester.tap(find.text('frog_owner'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('public-profile-sheet')),
        findsOneWidget,
      );
      for (final action in CommunityGovernanceAction.values) {
        expect(
          find.byKey(ValueKey<String>('public-profile-action-${action.name}')),
          findsNothing,
          reason: 'owner row offered ${action.name}',
        );
      }
    });

    testWidgets('a muted row renders the restore the server published', (
      tester,
    ) async {
      // The server drops `mute` once the row is already muted and publishes
      // `unmute` instead; the client does not compute that transition.
      final gateway = FakeCommunityGateway(
        members: testDirectory(
          items: <CommunityMemberEntry>[
            testMember(
              role: CommunityRole.member,
              alias: 'frog_member',
              status: CommunityMemberStatus.muted,
              actions: const <CommunityGovernanceAction>[
                CommunityGovernanceAction.promote,
                CommunityGovernanceAction.unmute,
                CommunityGovernanceAction.ban,
              ],
            ),
          ],
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
        social: FakeSocialGateway(),
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('public-profile-action-unmute')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('public-profile-action-mute')),
        findsNothing,
      );
      // No ownership transfer against a non-active member: the server's
      // state precondition removed it, so the row never offers it.
      expect(
        find.byKey(const ValueKey<String>('public-profile-action-transfer')),
        findsNothing,
      );
    });

    testWidgets('a member with no viewer permission has no row action', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        members: testDirectory(
          viewer: testViewer(
            role: CommunityRole.member,
            canInviteAdmin: false,
            canMute: false,
            canBan: false,
          ),
          items: <CommunityMemberEntry>[
            testMember(
              role: CommunityRole.member,
              actions: const <CommunityGovernanceAction>[],
            ),
          ],
        ),
      );
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      // The row still opens the shared public-profile sheet, but it carries
      // no governance command for this viewer.
      expect(
        find.byKey(const ValueKey<String>('public-profile-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('public-profile-action-mute')),
        findsNothing,
      );
    });

    testWidgets('the transfer confirmation names the Admin role it leaves', (
      tester,
    ) async {
      // The server's write path demotes the previous owner to `admin` in the
      // same transaction as the promotion, so the only irreversible action in
      // the app must not describe the outcome as a plain member: an Admin
      // keeps mute and ban over members, and loses the owner-only rights.
      final gateway = FakeCommunityGateway(members: testDirectory());
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
        social: FakeSocialGateway(),
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('public-profile-action-transfer')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('member-confirm-sheet')),
        findsOneWidget,
      );

      // What the previous owner becomes, what they lose, and what they keep.
      expect(find.textContaining('降为 Admin'), findsOneWidget);
      expect(find.textContaining('编辑社区资料'), findsOneWidget);
      expect(find.textContaining('禁言、封禁普通成员'), findsOneWidget);
      expect(find.textContaining('不可撤销'), findsOneWidget);
      // The demotion the server never performs must not be promised back.
      expect(find.textContaining('变成普通成员'), findsNothing);
      expect(find.textContaining('不能再编辑资料或执行治理动作'), findsNothing);
      // Reading the confirmation submits nothing.
      expect(gateway.commands.where((c) => c.startsWith('role:')), isEmpty);
    });

    testWidgets(
      'a governance command runs only after the second confirmation',
      (tester) async {
        final gateway = FakeCommunityGateway(members: testDirectory());
        await pumpCommunityPage(
          tester,
          const CommunityMembersScreen(communityId: testCommunityId),
          community: gateway,
        );

        await tester.tap(find.text('frog_member'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('public-profile-sheet')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('public-profile-action-mute')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('member-confirm-sheet')),
          findsOneWidget,
        );
        expect(gateway.commands.where((c) => c.startsWith('mute:')), isEmpty);

        await tester.tap(
          find.byKey(const ValueKey<String>('community-confirm-accept')),
        );
        await tester.pumpAndSettle();

        expect(gateway.commands, contains('mute:$testMemberId:true'));
        expect(find.text('禁言已生效'), findsOneWidget);
      },
    );

    testWidgets('a stale governance command never claims success', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        members: testDirectory(),
        writeFailure: CommunityFailureKind.stale,
      );
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('public-profile-action-ban')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(find.text('封禁已生效'), findsNothing);
      expect(find.textContaining('状态已经改变'), findsWidgets);
    });

    testWidgets('the banned view is reachable and unban restores the member', (
      tester,
    ) async {
      final active = testDirectory(
        items: <CommunityMemberEntry>[
          testMember(role: CommunityRole.member, alias: 'frog_member'),
        ],
      );
      final banned = testDirectory(
        items: <CommunityMemberEntry>[
          testMember(
            role: CommunityRole.member,
            alias: 'frog_member',
            status: CommunityMemberStatus.banned,
            // The server publishes exactly the restore for a banned row.
            actions: const <CommunityGovernanceAction>[
              CommunityGovernanceAction.unban,
            ],
          ),
        ],
      );
      final gateway = FakeCommunityGateway(
        members: active,
        membersByFilter: <CommunityMemberFilter, CommunityMemberDirectory>{
          CommunityMemberFilter.all: active,
          CommunityMemberFilter.banned: banned,
        },
      );
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
        social: FakeSocialGateway(),
        // Five segments do not fit a 390pt row; the width keeps them all
        // hit-testable without scrolling the filter strip first.
        size: const Size(900, 1400),
      );

      // The governance segment carries no count: `counts` stays the
      // non-banned directory's.
      final seg = find.byKey(const ValueKey<String>('members-seg-banned'));
      expect(seg, findsOneWidget);
      expect(tester.widget<LoopSeg>(seg).label, '已封禁');

      await tester.tap(seg);
      await tester.pumpAndSettle();
      expect(gateway.commands, contains('members:banned:null:null'));
      expect(find.text('已封禁'), findsWidgets);

      // A banned row offers only the restore, and the second confirmation
      // still stands in front of it.
      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('public-profile-action-unban')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('public-profile-action-ban')),
        findsNothing,
      );

      gateway.membersByFilter =
          <CommunityMemberFilter, CommunityMemberDirectory>{
            CommunityMemberFilter.all: active,
            CommunityMemberFilter.banned: testDirectory(
              items: const <CommunityMemberEntry>[],
            ),
          };
      await tester.tap(
        find.byKey(const ValueKey<String>('public-profile-action-unban')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('恢复为活跃成员'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(gateway.commands, contains('ban:$testMemberId:false'));
      // A filtered view is read again rather than mislabelled with the
      // default directory the command answered with.
      expect(
        gateway.commands.where((c) => c == 'members:banned:null:null'),
        hasLength(2),
      );
      expect(find.text('解除封禁已生效'), findsOneWidget);
    });

    testWidgets('a transfer is offered to the owner and states its finality', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(members: testDirectory());
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
        social: FakeSocialGateway(),
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('public-profile-action-transfer')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('这一步不可撤销'), findsOneWidget);
      expect(gateway.commands.where((c) => c.startsWith('role:')), isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();
      expect(gateway.commands, contains('role:$testMemberId:owner'));
    });

    testWidgets('a member viewer is not offered the banned view', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          members: testDirectory(
            viewer: testViewer(
              role: CommunityRole.member,
              canInviteAdmin: false,
              canMute: false,
              canBan: false,
            ),
          ),
        ),
        social: FakeSocialGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('members-seg-banned')),
        findsNothing,
      );
    });

    testWidgets('a refused directory renders the permission state', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          failure: CommunityFailureKind.permissionDenied,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-permission')),
        findsOneWidget,
      );
      expect(find.text('没有权限查看成员目录'), findsOneWidget);
    });

    testWidgets('loading renders the skeleton without a count', (tester) async {
      final gateway = FakeCommunityGateway()..pending = true;
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
        settle: false,
      );

      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(find.textContaining('名成员'), findsNothing);
    });
  });

  group('community-members · alias search', () {
    Finder searchToggle() =>
        find.byKey(const ValueKey<String>('community-members-search'));
    Finder searchField() =>
        find.byKey(const ValueKey<String>('community-members-search-field'));

    /// A pending debounce timer schedules no frame, so `pumpAndSettle` alone
    /// would return before it fires: the clock is advanced explicitly first.
    Future<void> settleSearch(WidgetTester tester) async {
      await tester.pump(CommunityMembersController.searchDebounce);
      await tester.pumpAndSettle();
    }

    Future<FakeCommunityGateway> openSearch(WidgetTester tester) async {
      final gateway = FakeCommunityGateway(members: testDirectory());
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
      );
      expect(searchField(), findsNothing);
      await tester.tap(searchToggle());
      await tester.pumpAndSettle();
      expect(searchField(), findsOneWidget);
      gateway.commands.clear();
      return gateway;
    }

    testWidgets('the placeholder sheet is gone; the control opens a field', (
      tester,
    ) async {
      await openSearch(tester);
      expect(
        find.byKey(const ValueKey<String>('member-search-unavailable-sheet')),
        findsNothing,
      );
      expect(find.text('成员搜索暂不可用'), findsNothing);
    });

    testWidgets('one keystroke is not one request: the field is debounced', (
      tester,
    ) async {
      final gateway = await openSearch(tester);

      await tester.enterText(searchField(), 'f');
      await tester.pump(const Duration(milliseconds: 120));
      expect(gateway.commands, isEmpty);

      await tester.enterText(searchField(), 'fr');
      await tester.pump(const Duration(milliseconds: 120));
      expect(gateway.commands, isEmpty);

      await tester.enterText(searchField(), 'fro');
      await tester.pump(const Duration(milliseconds: 120));
      expect(gateway.commands, isEmpty);

      // Only the settled text is ever asked for, exactly once.
      await settleSearch(tester);
      expect(gateway.commands, <String>['members:all:fro:null']);
    });

    testWidgets('the trimmed query reaches the gateway as q', (tester) async {
      final gateway = await openSearch(tester);

      await tester.enterText(searchField(), '  Frog  ');
      await settleSearch(tester);

      expect(gateway.commands, <String>['members:all:Frog:null']);
    });

    testWidgets('a query with no match states it without a zero count', (
      tester,
    ) async {
      final gateway = await openSearch(tester);
      gateway.membersByQuery = <String?, CommunityMemberDirectory>{
        'zzz': testDirectory(items: const <CommunityMemberEntry>[]),
      };

      await tester.enterText(searchField(), 'zzz');
      await settleSearch(tester);

      expect(find.text('没有匹配的成员'), findsOneWidget);
      // The counts describe the whole directory, never this query, so the
      // page stops printing them while it is narrowed: "128 名成员" and
      // "全部 128" over "没有匹配的成员" contradicted each other on one screen.
      expect(find.text('全部 128'), findsNothing);
      expect(find.text('Owner 1'), findsNothing);
      expect(find.text('128 名成员'), findsNothing);
      // The segments stay selectable, they just carry no figure.
      expect(find.text('全部'), findsOneWidget);
      // And the hero states what the page is now showing instead.
      expect(find.text('搜索成员'), findsOneWidget);
      // The field survives its own empty result, so the query can be edited.
      expect(searchField(), findsOneWidget);
    });

    testWidgets('a matching query counts nothing it cannot count', (
      tester,
    ) async {
      final gateway = await openSearch(tester);
      gateway.membersByQuery = <String?, CommunityMemberDirectory>{
        'fro': testDirectory(
          items: <CommunityMemberEntry>[testMember(role: CommunityRole.member)],
        ),
      };

      await tester.enterText(searchField(), 'fro');
      await settleSearch(tester);

      // One row is on screen and the directory holds 128. Neither number is
      // the other, and the server counts only the directory, so the narrowed
      // page states no figure at all rather than the wrong one.
      expect(find.text('frog_member'), findsOneWidget);
      expect(find.text('128 名成员'), findsNothing);
      expect(find.text('全部 128'), findsNothing);
      expect(find.text('1 名成员'), findsNothing);
      expect(find.text('搜索成员'), findsOneWidget);
    });

    testWidgets('the clear control drops q and reads the directory again', (
      tester,
    ) async {
      final gateway = await openSearch(tester);
      gateway.membersByQuery = <String?, CommunityMemberDirectory>{
        'zzz': testDirectory(items: const <CommunityMemberEntry>[]),
      };

      await tester.enterText(searchField(), 'zzz');
      await settleSearch(tester);
      expect(find.text('没有匹配的成员'), findsOneWidget);

      final clear = find.byKey(
        const ValueKey<String>('community-members-search-clear'),
      );
      expect(clear, findsOneWidget);
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(gateway.commands.last, 'members:all:null:null');
      expect(find.text('没有匹配的成员'), findsNothing);
      expect(find.text('frog_member'), findsOneWidget);
      // The directory is whole again, so its counts come back unchanged.
      expect(find.text('全部 128'), findsOneWidget);
      expect(find.text('128 名成员'), findsOneWidget);
      expect(find.text('搜索成员'), findsNothing);
    });

    // R3-3: on the device the field never took a character. Tapping it opened
    // the keyboard, the page folded its hero away, and the fold rebuilt the
    // field somewhere else in the element tree, which dropped its focus and
    // closed the keyboard again. The fold must not move the field.
    testWidgets('the field keeps focus and identity when the keyboard opens', (
      tester,
    ) async {
      const viewport = Size(390, 823);
      final gateway = FakeCommunityGateway(members: testDirectory());
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
        size: viewport,
      );
      await tester.tap(searchToggle());
      await tester.pumpAndSettle();

      final before = tester.element(searchField());
      final node = tester.widget<TextField>(searchField()).focusNode!;
      expect(node.hasFocus, isTrue);
      expect(find.text('MEMBER DIRECTORY'), findsOneWidget);

      // The soft keyboard arrives one frame after the field takes focus.
      tester.view.viewInsets = const FakeViewPadding(bottom: 289);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      // The hero is folded away — and the field is the same element, still
      // focused, so the keyboard stays up and what is typed arrives.
      expect(find.text('MEMBER DIRECTORY'), findsNothing);
      expect(tester.element(searchField()), same(before));
      expect(node.hasFocus, isTrue);

      await tester.enterText(searchField(), 'voy');
      await settleSearch(tester);
      expect(gateway.commands, contains('members:all:voy:null'));
      expect(tester.element(searchField()), same(before));
      expect(node.hasFocus, isTrue);

      // Dismissing the keyboard brings the hero back, and still does not move
      // the field.
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('MEMBER DIRECTORY'), findsOneWidget);
      expect(tester.element(searchField()), same(before));
      expect(node.hasFocus, isTrue);
    });

    testWidgets('the keyboard never buries the matches: they stay scrollable', (
      tester,
    ) async {
      // The walkthrough device: 1080×2280 at 2.77 is 390×823 logical, and the
      // soft keyboard takes 800 device pixels (289 logical) off the bottom.
      // On that page the pinned hero plus the field plus the chips left the
      // matches under the keyboard with nothing left to scroll.
      const keyboard = 289.0;
      const viewport = Size(390, 823);
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.resetViewInsets);

      final gateway = FakeCommunityGateway(members: testDirectory());
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
        size: viewport,
      );
      await tester.tap(searchToggle());
      await tester.pumpAndSettle();

      gateway.membersByQuery = <String?, CommunityMemberDirectory>{
        'voy': testDirectory(
          items: <CommunityMemberEntry>[
            for (var index = 0; index < 8; index += 1)
              testMember(
                role: CommunityRole.member,
                publicProfileId: '7a3d2e4c-5b6c-4d7e-8f90-1a2b3c4d5e6$index',
                loopId: 'LOOP-VOY0000$index',
                alias: 'Voyanne_$index',
              ),
          ],
        ),
      };
      await tester.enterText(searchField(), 'voy');
      await settleSearch(tester);

      final visibleBottom = viewport.height - keyboard;
      final firstRow = find.byKey(
        const ValueKey<String>(
          'member-row-7a3d2e4c-5b6c-4d7e-8f90-1a2b3c4d5e60',
        ),
      );
      expect(firstRow, findsOneWidget);
      final firstTop = tester.getRect(firstRow).top;
      expect(firstTop, lessThan(visibleBottom));

      // And the list still scrolls under the keyboard, so the rest of the
      // matches can be reached without dismissing it.
      await tester.drag(
        find.byKey(const ValueKey<String>('community-members-list')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(firstRow).top, lessThan(firstTop));
    });

    testWidgets('closing the control clears the query as well', (tester) async {
      final gateway = await openSearch(tester);

      await tester.enterText(searchField(), 'fro');
      await settleSearch(tester);
      expect(gateway.commands, <String>['members:all:fro:null']);

      await tester.tap(searchToggle());
      await tester.pumpAndSettle();

      expect(searchField(), findsNothing);
      expect(gateway.commands.last, 'members:all:null:null');
    });

    testWidgets('a keystroke during a read is coalesced into one more read', (
      tester,
    ) async {
      final gateway = await openSearch(tester);
      gateway.readDelay = const Duration(milliseconds: 500);

      await tester.enterText(searchField(), 'f');
      await tester.pump(CommunityMembersController.searchDebounce);
      // The first read is now in the air.
      expect(gateway.commands, <String>['members:all:f:null']);

      // A keystroke while it is in flight must not start a second read.
      await tester.enterText(searchField(), 'fr');
      await tester.pump(CommunityMembersController.searchDebounce);
      expect(gateway.commands, <String>['members:all:f:null']);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Exactly one follow-up, for the latest text.
      expect(gateway.commands, <String>[
        'members:all:f:null',
        'members:all:fr:null',
      ]);
    });

    testWidgets('a search re-read keeps the rows and marks them 更新中', (
      tester,
    ) async {
      final gateway = await openSearch(tester);
      expect(find.text('frog_member'), findsOneWidget);

      // A first search over a directory that is already on screen.
      gateway.readDelay = const Duration(milliseconds: 500);
      await tester.enterText(searchField(), 'fro');
      await tester.pump(CommunityMembersController.searchDebounce);

      // The rows survive the re-read: no skeleton, no blank list.
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(find.text('frog_member'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-state-updating')),
        findsOneWidget,
      );
      // The old cursor belongs to the old query, so 载入更多 is withdrawn.
      expect(
        find.byKey(const ValueKey<String>('community-members-load-more')),
        findsNothing,
      );

      gateway.readDelay = null;
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('community-state-updating')),
        findsNothing,
      );
      expect(find.text('frog_member'), findsOneWidget);
    });

    testWidgets('a first open and a role switch still load as a skeleton', (
      tester,
    ) async {
      // A held read, not a never-completing one: the skeleton animates, so the
      // frame is advanced explicitly rather than settled while it is up.
      final gateway = FakeCommunityGateway(members: testDirectory())
        ..readDelay = const Duration(milliseconds: 500);
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
        settle: false,
      );

      // A first open has nothing to keep.
      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-state-updating')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 600));
      gateway.readDelay = null;
      await tester.pumpAndSettle();
      expect(find.text('frog_member'), findsOneWidget);

      // A role segment is a different directory, not the same one narrowed.
      gateway.readDelay = const Duration(milliseconds: 500);
      await tester.tap(find.byKey(const ValueKey<String>('members-seg-admin')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(find.text('frog_member'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('community-state-updating')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 600));
      gateway.readDelay = null;
      await tester.pumpAndSettle();
      expect(find.text('frog_member'), findsOneWidget);
    });

    testWidgets('a refused search keeps the five-state contract', (
      tester,
    ) async {
      final gateway = await openSearch(tester);
      gateway.failure = CommunityFailureKind.rateLimited;

      await tester.enterText(searchField(), 'fro');
      await settleSearch(tester);

      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsOneWidget,
      );
      expect(searchField(), findsOneWidget);
    });
  });
}

/// The two pages a reader walks between: the community page stays mounted
/// under the room, exactly as the router leaves it, so the test can ask what
/// it says after the room ends.
class _VoiceRoomReturnHarness extends StatefulWidget {
  const _VoiceRoomReturnHarness();

  @override
  State<_VoiceRoomReturnHarness> createState() =>
      _VoiceRoomReturnHarnessState();
}

class _VoiceRoomReturnHarnessState extends State<_VoiceRoomReturnHarness> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: IndexedStack(
            index: _index,
            children: const <Widget>[
              CommunityProfileScreen(communityId: testCommunityId),
              VoiceRoomScreen(communityId: testCommunityId),
            ],
          ),
        ),
        TextButton(
          key: const ValueKey<String>('harness-open-room'),
          onPressed: () => setState(() => _index = 1),
          child: const Text('room'),
        ),
        TextButton(
          key: const ValueKey<String>('harness-open-community'),
          onPressed: () => setState(() => _index = 0),
          child: const Text('community'),
        ),
      ],
    );
  }
}
