import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/referral_screen.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/features/social/blocklist_screen.dart';
import 'package:loop_mobile/features/social/connections_screen.dart';
import 'package:loop_mobile/features/social/dm_requests_screen.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/community_test_harness.dart';

ConnectionPage _connections({
  ConnectionDirection direction = ConnectionDirection.following,
  bool viewerFollows = true,
  int items = 1,
}) => ConnectionPage(
  direction: direction,
  items: <ConnectionEntry>[
    for (var index = 0; index < items; index += 1)
      ConnectionEntry(
        profile: testProfile(
          publicProfileId: testMemberId,
          loopId: 'LOOP-3HJKMNPQ',
          alias: 'frog_member',
        ),
        createdAt: DateTime.utc(2026, 8),
        viewerFollows: viewerFollows,
        miningPower: testMiningPower,
      ),
  ],
  counts: const ConnectionCounts(following: 24, followers: 108),
  nextCursor: null,
);

BlockPage _blocks({int items = 1}) => BlockPage(
  kind: BlockKind.user,
  items: <BlockEntry>[
    for (var index = 0; index < items; index += 1)
      BlockEntry(
        kind: BlockKind.user,
        stableId: testMemberId,
        profile: testProfile(publicProfileId: testMemberId, alias: 'spam_bot'),
        reasonCode: 'message_request_report',
        createdAt: DateTime.utc(2026, 8, 20),
      ),
  ],
  userCount: items,
  nextCursor: null,
);

MessageRequestPage _requests({int items = 1}) => MessageRequestPage(
  items: <MessageRequestEntry>[
    for (var index = 0; index < items; index += 1)
      MessageRequestEntry(
        messageRequestId: testRequestId,
        profile: testProfile(alias: 'fox_trader'),
        createdAt: DateTime.utc(2026, 9, 7),
        expiresAt: DateTime.utc(2026, 9, 14),
        preview: const LoopUnavailableFact('MESSAGE_PREVIEW_DEFERRED'),
        aiModeration: const LoopUnavailableFact('AI_MODERATION_DEFERRED'),
      ),
  ],
  nextCursor: null,
);

SearchPage _searchPage(
  SearchDomain domain, {
  bool available = true,
  String? reasonCode,
  int results = 1,
}) => SearchPage(
  domain: domain,
  available: available,
  reasonCode: reasonCode,
  results: <SearchResult>[
    for (var index = 0; index < results; index += 1)
      SearchResult(
        resultType: domain == SearchDomain.users
            ? SearchResultType.user
            : SearchResultType.community,
        stableId: domain == SearchDomain.users ? testMemberId : testCommunityId,
        title: domain == SearchDomain.users ? 'frog_maxi' : 'Frog Holders',
        subtitle: domain == SearchDomain.users
            ? 'LOOP-7HJKMNPQ'
            : 'frog-holders',
        avatarRef: null,
        memberCount: domain == SearchDomain.users ? null : 128,
        verificationStatus: domain == SearchDomain.users ? null : 'verified',
        destination: domain == SearchDomain.users
            ? SearchDestinationKind.publicProfile
            : SearchDestinationKind.communityProfile,
      ),
  ],
  nextCursor: null,
);

void main() {
  group('connections', () {
    testWidgets('the segment counts come from the server', (tester) async {
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: FakeSocialGateway(connections: _connections()),
      );

      expect(find.text('24 关注 · 108 粉丝'), findsOneWidget);
      expect(find.text('关注 24'), findsOneWidget);
      expect(find.text('粉丝 108'), findsOneWidget);
    });

    testWidgets('loading shows a skeleton and no count', (tester) async {
      final gateway = FakeSocialGateway()..pending = true;
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: gateway,
        settle: false,
      );

      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      expect(find.textContaining('关注 ·'), findsNothing);
    });

    testWidgets('an empty list states the block rule instead of a zero', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: FakeSocialGateway(connections: _connections(items: 0)),
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsOneWidget,
      );
      expect(find.textContaining('被你屏蔽的账号'), findsWidgets);
    });

    testWidgets('offline and error stay distinct states', (tester) async {
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: FakeSocialGateway(failure: CommunityFailureKind.offline),
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsOneWidget,
      );

      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: FakeSocialGateway(failure: CommunityFailureKind.invalidData),
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsOneWidget,
      );
    });

    testWidgets('a deferred community capability issues no request', (
      tester,
    ) async {
      final gateway = FakeSocialGateway(connections: _connections());
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: gateway,
        meta: testMetaSnapshot(
          community: LoopV2CapabilityAvailability.deferred,
        ),
      );

      expect(
        find.byKey(
          const ValueKey<String>('connections-capability-unavailable'),
        ),
        findsOneWidget,
      );
      expect(gateway.commands, isEmpty);
    });

    testWidgets('the row offers dm and a confirmed unfollow', (tester) async {
      final gateway = FakeSocialGateway(connections: _connections());
      final opened = <String>[];
      await pumpCommunityPage(
        tester,
        ConnectionsScreen(onOpenConversation: opened.add),
        social: gateway,
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('connection-action-dm')),
      );
      await tester.pumpAndSettle();
      expect(opened, <String>[testMemberId]);

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('connection-action-follow')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(gateway.commands, contains('follow:$testMemberId:false'));
      expect(find.text('已取消关注'), findsOneWidget);
    });

    testWidgets('a refused follow shows no success toast', (tester) async {
      final gateway = FakeSocialGateway(
        connections: _connections(viewerFollows: false),
        writeFailure: CommunityFailureKind.notFound,
      );
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: gateway,
      );

      await tester.tap(find.text('frog_member'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('connection-action-follow')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(find.text('已关注'), findsNothing);
      expect(find.textContaining('目标不存在'), findsWidgets);
    });
  });

  group('blocklist', () {
    testWidgets('contract and domain segments never issue a request', (
      tester,
    ) async {
      final gateway = FakeSocialGateway(blocks: _blocks());
      await pumpCommunityPage(tester, const BlocklistScreen(), social: gateway);

      expect(find.text('用户 1'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('blocklist-seg-contract')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('blocklist-kind-unavailable-contract'),
        ),
        findsOneWidget,
      );
      expect(gateway.commands, <String>['blocks:user']);

      await tester.tap(
        find.byKey(const ValueKey<String>('blocklist-seg-domain')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('blocklist-kind-unavailable-domain')),
        findsOneWidget,
      );
      expect(gateway.commands, <String>['blocks:user']);
    });

    testWidgets('lifting a block needs a confirmation and reloads', (
      tester,
    ) async {
      final gateway = FakeSocialGateway(blocks: _blocks());
      await pumpCommunityPage(tester, const BlocklistScreen(), social: gateway);

      await tester.tap(find.text('spam_bot'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('blocklist-confirm-sheet')),
        findsOneWidget,
      );
      expect(gateway.commands.where((c) => c.startsWith('block:')), isEmpty);

      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(gateway.commands, contains('block:user:$testMemberId:false'));
      expect(find.text('已解除屏蔽'), findsOneWidget);
      // Lifting a block never restores a follow edge; the page says so.
      expect(find.textContaining('不会自动恢复'), findsWidgets);
    });

    testWidgets('the report reason is shown, never invented', (tester) async {
      await pumpCommunityPage(
        tester,
        const BlocklistScreen(),
        social: FakeSocialGateway(blocks: _blocks()),
      );

      expect(find.text('举报陌生人请求时自动屏蔽'), findsOneWidget);
    });

    testWidgets('an empty list and a failure stay distinct', (tester) async {
      await pumpCommunityPage(
        tester,
        const BlocklistScreen(),
        social: FakeSocialGateway(blocks: _blocks(items: 0)),
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsOneWidget,
      );

      await pumpCommunityPage(
        tester,
        const BlocklistScreen(),
        social: FakeSocialGateway(failure: CommunityFailureKind.unavailable),
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-unavailable')),
        findsOneWidget,
      );
    });
  });

  group('dm-requests', () {
    testWidgets('the preview and the AI verdict stay unavailable', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const MessageRequestsScreen(),
        social: FakeSocialGateway(requests: _requests()),
      );

      expect(
        find.byKey(
          const ValueKey<String>(
            'community-unavailable-MESSAGE_PREVIEW_DEFERRED',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'community-unavailable-AI_MODERATION_DEFERRED',
          ),
        ),
        findsOneWidget,
      );
      // The prototype's sample body and fraud verdict must not appear.
      expect(find.textContaining('AI 巡查标记为诈骗'), findsNothing);
      expect(find.textContaining('看到你在'), findsNothing);
    });

    testWidgets('a report toast repeats the server blocked flag', (
      tester,
    ) async {
      final gateway = FakeSocialGateway(requests: _requests());
      await pumpCommunityPage(
        tester,
        const MessageRequestsScreen(),
        social: gateway,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('dm-request-report-$testRequestId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(gateway.commands, contains('decision:$testRequestId:report'));
      expect(find.text('已举报并屏蔽'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsOneWidget,
      );
    });

    testWidgets('an accept blocked by the server never claims success', (
      tester,
    ) async {
      final gateway = FakeSocialGateway(
        requests: _requests(),
        writeFailure: CommunityFailureKind.stale,
      );
      await pumpCommunityPage(
        tester,
        const MessageRequestsScreen(),
        social: gateway,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('dm-request-accept-$testRequestId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('community-confirm-accept')),
      );
      await tester.pumpAndSettle();

      expect(find.text('已接受'), findsNothing);
      expect(find.textContaining('状态已经改变'), findsWidgets);
    });

    testWidgets('an empty inbox and a loading inbox stay distinct', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const MessageRequestsScreen(),
        social: FakeSocialGateway(requests: _requests(items: 0)),
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsOneWidget,
      );

      final pending = FakeSocialGateway()..pending = true;
      await pumpCommunityPage(
        tester,
        const MessageRequestsScreen(),
        social: pending,
        settle: false,
      );
      expect(find.byType(LoopSkeleton), findsOneWidget);
    });
  });

  group('referral', () {
    testWidgets('the five ratios come from the server as decimal strings', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ReferralScreen(),
        community: FakeCommunityGateway(),
      );

      for (final label in <String>[
        'L1 · 10%',
        'L2 · 5%',
        'L3 · 3%',
        'L4 · 2%',
        'L5 · 1%',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.textContaining('五级关系加成 · referralRulesV1'), findsOne);
    });

    testWidgets('relationship counts and the invite code stay unavailable', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ReferralScreen(),
        community: FakeCommunityGateway(),
      );

      final edges = find.byKey(
        const ValueKey<String>('community-unavailable-REFERRAL_GRAPH_DEFERRED'),
      );
      await scrollToCommunitySection(tester, edges);
      expect(edges, findsOneWidget);

      final invite = find.byKey(
        const ValueKey<String>('community-unavailable-INVITE_CODE_DEFERRED'),
      );
      await scrollToCommunitySection(tester, invite);
      expect(invite, findsOneWidget);

      // The share action has no invite code, so it stays disabled.
      final button = tester.widget<LoopButton>(
        find.byKey(const ValueKey<String>('referral-invite-action')),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('不是收入、佣金或返佣'), findsWidgets);
      // No relationship figure is invented for any level.
      expect(find.text('182'), findsNothing);
    });

    testWidgets('a failed rules read is an error, not an empty page', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ReferralScreen(),
        community: FakeCommunityGateway(
          failure: CommunityFailureKind.unexpected,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsOneWidget,
      );
      expect(find.textContaining('%'), findsNothing);
    });
  });

  group('search', () {
    testWidgets('the three deferred domains show their server reason', (
      tester,
    ) async {
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{
          SearchDomain.communities: _searchPage(SearchDomain.communities),
          SearchDomain.assets: _searchPage(
            SearchDomain.assets,
            available: false,
            reasonCode: 'ASSET_REGISTRY_DEFERRED',
            results: 0,
          ),
          SearchDomain.launch: _searchPage(
            SearchDomain.launch,
            available: false,
            reasonCode: 'LAUNCH_MODULE_DEFERRED',
            results: 0,
          ),
          SearchDomain.dapps: _searchPage(
            SearchDomain.dapps,
            available: false,
            reasonCode: 'DAPP_DIRECTORY_DEFERRED',
            results: 0,
          ),
        },
      );
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(initialQuery: 'frog'),
        search: gateway,
      );

      expect(find.text('Frog Holders'), findsOneWidget);

      for (final domain in <SearchDomain>[
        SearchDomain.assets,
        SearchDomain.launch,
        SearchDomain.dapps,
      ]) {
        await tester.tap(
          find.byKey(ValueKey<String>('search-seg-${domain.wireName}')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            ValueKey<String>('search-domain-unavailable-${domain.wireName}'),
          ),
          findsOneWidget,
          reason: domain.wireName,
        );
        expect(find.text('Frog Holders'), findsNothing);
      }
    });

    testWidgets('a result opens through its destination kind', (tester) async {
      final communities = <String>[];
      final profiles = <String>[];
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{
          SearchDomain.communities: _searchPage(SearchDomain.communities),
          SearchDomain.users: _searchPage(SearchDomain.users),
        },
      );
      await pumpCommunityPage(
        tester,
        GlobalSearchScreen(
          initialQuery: 'frog',
          onOpenCommunity: communities.add,
          onOpenProfile: profiles.add,
        ),
        search: gateway,
      );

      await tester.tap(find.text('Frog Holders'));
      await tester.pumpAndSettle();
      expect(communities, <String>[testCommunityId]);

      await tester.tap(find.byKey(const ValueKey<String>('search-seg-users')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('frog_maxi'));
      await tester.pumpAndSettle();
      expect(profiles, <String>[testMemberId]);
    });

    testWidgets('a short prefix spends no quota', (tester) async {
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{
          SearchDomain.communities: _searchPage(SearchDomain.communities),
        },
      );
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: gateway,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('search-field')),
        'f',
      );
      await tester.tap(find.byKey(const ValueKey<String>('search-submit')));
      await tester.pumpAndSettle();

      expect(gateway.queries, isEmpty);
      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsOneWidget,
      );
    });

    testWidgets('a rate-limited search is an error with a retry', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(initialQuery: 'frog'),
        search: FakeSearchGateway(failure: CommunityFailureKind.rateLimited),
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsOneWidget,
      );
      expect(find.textContaining('搜索过于频繁'), findsOneWidget);
    });

    testWidgets('an unavailable search capability issues no request', (
      tester,
    ) async {
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{
          SearchDomain.communities: _searchPage(SearchDomain.communities),
        },
      );
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(initialQuery: 'frog'),
        search: gateway,
        meta: testMetaSnapshot(
          search: LoopV2CapabilityAvailability.unavailable,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('search-capability-unavailable')),
        findsOneWidget,
      );
      expect(gateway.queries, isEmpty);
      expect(find.textContaining('SEARCH_RUNTIME_UNAVAILABLE'), findsOneWidget);
    });
  });
}
