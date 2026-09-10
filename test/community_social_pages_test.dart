import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/search_controller.dart';
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

    testWidgets('a failed next page keeps the rows already loaded', (
      tester,
    ) async {
      final gateway = FakeSocialGateway(
        connections: ConnectionPage(
          direction: ConnectionDirection.following,
          items: _connections().items,
          counts: const ConnectionCounts(following: 24, followers: 108),
          nextCursor: 'AbC-1_2.dEf-3_4',
        ),
      );
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: gateway,
      );
      expect(find.text('frog_member'), findsOneWidget);

      gateway.failure = CommunityFailureKind.offline;
      await tester.tap(
        find.byKey(const ValueKey<String>('connections-load-more')),
      );
      await tester.pumpAndSettle();

      // The first page survives: only the appended page failed.
      expect(find.text('frog_member'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('connections-action-failure')),
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
      // The two deferred kinds are disabled segments with their reason stated
      // on the page: they cannot be selected and issue no request.
      for (final kind in <String>['contract', 'domain']) {
        expect(
          tester
              .widget<LoopSeg>(
                find.byKey(ValueKey<String>('blocklist-seg-$kind')),
              )
              .onSelected,
          isNull,
          reason: kind,
        );
      }
      expect(
        find.byKey(const ValueKey<String>('blocklist-deferred-kinds')),
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

    testWidgets('a deferred domain is probed once for its reason', (
      tester,
    ) async {
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{
          SearchDomain.launch: _searchPage(
            SearchDomain.launch,
            available: false,
            reasonCode: 'LAUNCH_MODULE_DEFERRED',
            results: 0,
          ),
        },
      );
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: gateway,
      );

      // No query has been typed, yet the reason is read from the server
      // rather than guessed: the three deferred domains cost no quota.
      await tester.tap(find.byKey(const ValueKey<String>('search-seg-launch')));
      await tester.pumpAndSettle();

      expect(gateway.queries, <String>['launch:$searchUnavailableProbeQuery']);
      expect(
        find.byKey(const ValueKey<String>('search-domain-unavailable-launch')),
        findsOneWidget,
      );
      expect(find.textContaining('Launch 搜索还没有开放'), findsOneWidget);
    });

    testWidgets('a result opens through its destination kind', (tester) async {
      final communities = <String>[];
      final social = FakeSocialGateway();
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
        ),
        search: gateway,
        social: social,
      );

      await tester.tap(find.text('Frog Holders'));
      await tester.pumpAndSettle();
      expect(communities, <String>[testCommunityId]);

      // A `publicProfile` result opens the shared sheet: LOOP has no route
      // for another account before D7, and none is invented.
      await tester.tap(find.byKey(const ValueKey<String>('search-seg-users')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('frog_maxi'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('public-profile-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('public-profile-loop-id')),
        findsOneWidget,
      );
      expect(communities, <String>[testCommunityId]);
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
      expect(find.textContaining('SEARCH_RUNTIME_UNAVAILABLE'), findsNothing);
      expect(find.textContaining('请稍后再试'), findsOneWidget);
    });
  });
}
