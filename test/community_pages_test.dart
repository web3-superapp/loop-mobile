import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_screen.dart';
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
      expect(find.text('—'), findsWidgets);
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
      expect(find.textContaining('发现 3 个已验证社区'), findsOneWidget);
      expect(find.text('Joined 0'), findsOneWidget);
      // The discover list moved to its own page; the hero states the count.
      expect(find.text('Discover 0'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('community-discover-hero')),
        findsOneWidget,
      );
      // The rule version is cited; the page never calls it a recommendation.
      expect(find.textContaining('rule:verified-members-v1'), findsOneWidget);
    });

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
      expect(find.textContaining('挖矿口径（D19）'), findsOneWidget);
      expect(find.textContaining('Stream 接通（D7）'), findsOneWidget);
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
      expect(find.textContaining('尚未解析'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
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
      expect(find.textContaining('无权执行此操作'), findsWidgets);
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
      expect(
        find.byKey(const ValueKey<String>('community-owner-cannot-leave')),
        findsOneWidget,
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
      expect(
        find.byKey(
          const ValueKey<String>(
            'community-unavailable-STREAM_PRESENCE_NOT_CONNECTED',
          ),
        ),
        findsOneWidget,
      );
    });

    test('the viewer flags alone decide which commands a row offers', () {
      final member = testMember(role: CommunityRole.member);
      final admin = testMember(
        role: CommunityRole.admin,
        publicProfileId: testAdminId,
      );
      final owner = testMember(
        role: CommunityRole.owner,
        publicProfileId: testOwnerId,
      );
      final self = testMember(role: CommunityRole.member, isSelf: true);
      final anonymous = testMember(
        role: CommunityRole.member,
        publicProfileId: null,
      );

      List<String> actions(
        CommunityViewer viewer,
        CommunityMemberEntry entry,
      ) => communityGovernanceActions(
        viewer,
        entry,
      ).map((action) => action.name).toList(growable: false);

      final ownerViewer = testViewer();
      expect(actions(ownerViewer, member), <String>[
        'promote',
        'transfer',
        'mute',
        'ban',
      ]);
      expect(actions(ownerViewer, admin), <String>[
        'demote',
        'transfer',
        'mute',
        'ban',
      ]);
      // A banned row offers exactly one command: restore it.
      expect(
        actions(
          ownerViewer,
          testMember(
            role: CommunityRole.member,
            status: CommunityMemberStatus.banned,
          ),
        ),
        <String>['unban'],
      );
      // The owner is never a target, and neither is the viewer's own row.
      expect(actions(ownerViewer, owner), isEmpty);
      expect(actions(ownerViewer, self), isEmpty);
      // A member without a profile row can never be a command target.
      expect(actions(ownerViewer, anonymous), isEmpty);

      final adminViewer = testViewer(canInviteAdmin: false);
      expect(actions(adminViewer, member), <String>['mute', 'ban']);

      final memberViewer = testViewer(
        role: CommunityRole.member,
        canInviteAdmin: false,
        canMute: false,
        canBan: false,
      );
      expect(actions(memberViewer, member), isEmpty);
      expect(actions(memberViewer, admin), isEmpty);
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
      expect(gateway.commands, contains('members:banned:null'));
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
        gateway.commands.where((c) => c == 'members:banned:null'),
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
}
