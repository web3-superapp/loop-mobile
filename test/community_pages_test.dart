import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

import 'support/community_test_harness.dart';

CommunityHome _home({
  int joined = 1,
  bool truncated = false,
  int discover = 1,
}) => CommunityHome(
  joined: <JoinedCommunity>[
    for (var index = 0; index < joined; index += 1)
      JoinedCommunity(
        community: testCommunity(
          communityId: '3fa85f64-5717-4562-b3fc-2c963f66af$index$index',
          name: 'Joined $index',
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
      // The hero says the gap in words. An em dash at 25–30px in Lime reads
      // as a rule floating over the card, not as a missing number.
      expect(find.text(communityMissingHeading), findsOneWidget);
      expect(find.text(communityMissingFigure), findsNothing);
      expect(find.textContaining('个已加入的社区'), findsNothing);
    });

    testWidgets('ready renders only server figures', (tester) async {
      final gateway = FakeCommunityGateway(home: _home(joined: 2, discover: 3));
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
      );

      expect(find.text('2 个已加入的社区'), findsOneWidget);
      // `discover` is a preview the server cut to a handful. Its length was
      // printed as the number of verified communities, which read 5 while the
      // directory held 36, so the page now states only what it is showing.
      expect(find.textContaining('个已验证社区'), findsNothing);
      expect(find.textContaining('这里先给 3 个'), findsOneWidget);
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
        expect(find.text('1 个已加入的社区'), findsOneWidget);
      },
    );

    testWidgets('an empty aggregate never renders a zero', (tester) async {
      final gateway = FakeCommunityGateway(home: _home(joined: 0, discover: 0));
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
      );

      expect(find.text('0 个已加入的社区'), findsOneWidget);
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
      expect(find.text('1 个已加入的社区'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-capability-unavailable')),
        findsNothing,
      );
    });

    testWidgets('the message panel states its missing sources', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: FakeCommunityGateway(home: _home()),
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
      expect(find.textContaining('3 NEW'), findsNothing);
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
    testWidgets('only the two server-backed segments are selectable', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway(
        directoryPage: CommunityDirectoryPage(
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
      expect(seg('members').onSelected, isNotNull);
      expect(seg('newest').onSelected, isNotNull);
      expect(seg('power').onSelected, isNull);
      expect(seg('discussion').onSelected, isNull);
      expect(find.textContaining('算力排序暂时不可用'), findsOneWidget);
      expect(find.textContaining('讨论量排序暂时不可用'), findsOneWidget);
      // Neither reason may promise a date, and neither may point at a module
      // that is already live: both Mining and group chat are.
      expect(find.textContaining('开放后'), findsNothing);
    });

    testWidgets('the heading counts what is loaded, never a total it lacks', (
      tester,
    ) async {
      // The directory answers one cursor page and carries no total. The
      // heading read "20 个社区" over a directory of 36.
      final gateway = FakeCommunityGateway(
        directoryPage: CommunityDirectoryPage(
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

      final row = find.byKey(
        const ValueKey<String>('community-online-count-row'),
      );
      await tester.scrollUntilVisible(
        row,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1 人'), findsOneWidget);
      // The observation carries its own time, in UTC, as the server gave it.
      expect(find.text('观察于 2026-09-16 06:44 UTC'), findsOneWidget);
      // 「在线 1 人」 alone would be read as "active recently" or as the
      // membership, so the page says what was counted.
      expect(find.textContaining('与 Stream 保持连接'), findsOneWidget);
      expect(find.textContaining('最近活跃'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>(
            'community-unavailable-STREAM_PRESENCE_NOT_CONNECTED',
          ),
        ),
        findsNothing,
      );
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

      final row = find.byKey(
        const ValueKey<String>('community-online-count-row'),
      );
      await tester.scrollUntilVisible(
        row,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      // Stream answered zero: the page prints it instead of hiding behind the
      // unavailable card it uses when nobody asked.
      expect(find.text('0 人'), findsOneWidget);
      expect(find.text('观察于 2026-09-16 06:44 UTC'), findsOneWidget);
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

      final card = find.byKey(
        const ValueKey<String>(
          'community-unavailable-STREAM_PRESENCE_READ_TIMEOUT',
        ),
      );
      await tester.scrollUntilVisible(
        card,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(card, findsOneWidget);
      expect(find.textContaining('超时'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-online-count-row')),
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

      final row = find.byKey(
        const ValueKey<String>('community-mining-power-weight'),
      );
      await tester.scrollUntilVisible(
        row,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      // A community's number is a sum over one bound asset, so the weight and
      // the head count that produced it are on the card with it.
      expect(find.text('0.8'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('community-mining-power-participants'),
        ),
        findsOneWidget,
      );
      expect(find.text('开发基线'), findsOneWidget);
      // The version that settled it stays a backend identifier.
      expect(find.textContaining('miningFormula-devBaseline'), findsNothing);
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

      final row = find.byKey(
        const ValueKey<String>('community-mining-power-weight'),
      );
      await tester.scrollUntilVisible(
        row,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('权重还在审核中'), findsOneWidget);
      // The settled power stays the server's own 0: a pending weight is why
      // it is zero, not a reason to hide it.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('community-mining-power-row')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
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

      final row = find.byKey(
        const ValueKey<String>('community-mining-power-weight'),
      );
      await tester.scrollUntilVisible(
        row,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      // The row states the fact it was given. A review nobody is performing
      // is not a state this card may announce (Decision 0046).
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
      expect(find.text('未绑定资产'), findsOneWidget);
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
      expect(find.textContaining('还没有解析'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
      // No series is readable in this harness, so the card carries no chart
      // slot: an empty 106px box under 「下面的走势线来自行情页」 pointed at a
      // line that was not there.
      expect(find.textContaining('暂无走势'), findsOneWidget);
      expect(find.textContaining('下面的走势线来自行情页'), findsNothing);
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

      // Page order: presence, mining, announcements, official links.
      for (final reason in <String>[
        'STREAM_PRESENCE_NOT_CONNECTED',
        'MINING_FORMULA_BASELINE_PENDING',
        'COMMUNITY_ANNOUNCEMENTS_DEFERRED',
        'COMMUNITY_LINKS_DEFERRED',
      ]) {
        final finder = find.byKey(
          ValueKey<String>('community-unavailable-$reason'),
        );
        await scrollToCommunitySection(tester, finder);
        expect(finder, findsOneWidget, reason: reason);
      }
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

      final chat = find.byKey(
        const ValueKey<String>('community-profile-open-chat'),
      );
      await scrollToCommunitySection(tester, chat);
      expect(
        find.descendant(of: chat, matching: find.text('该社区还没有官方群频道。')),
        findsOneWidget,
      );
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
      expect(notice, findsOneWidget);
      // The transfer demotes the previous owner to Admin, which is what the
      // members page's confirmation says. This notice says the same thing.
      expect(
        find.descendant(of: notice, matching: find.textContaining('降为 Admin')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: notice, matching: find.textContaining('普通成员')),
        findsNothing,
      );
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
