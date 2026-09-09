import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/v2/community_chat_screen.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_screen.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/features/profile/about/about_screen.dart';
import 'package:loop_mobile/features/social/blocklist_screen.dart';
import 'package:loop_mobile/features/profile/settings/settings_screen.dart';
import 'package:loop_mobile/features/system/system_surfaces.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';
import 'support/s8_harness.dart';

/// Loading / Empty / Error for the COMMUNITY, PROFILE-settings and module-0
/// gate pages the 93-page matrix still listed as thin.
///
/// Offline for the community family is already pinned page by page in
/// `s8_offline_permission_states_test.dart`; this file closes the columns that
/// file did not cover, and states — with the contract reason — where a state
/// does not exist at all.
///
/// One rule decides every "empty" case here. `CommunityStateBlock`
/// (`community_widgets.dart:52`) does render an empty arm, but only for
/// `CommunityViewPhase.empty`, which a controller publishes **only after a
/// successful read whose collection came back with no rows**. A resource that
/// is a single record — a community profile, an account settings document, the
/// about record — has no such case, so its empty is asserted negatively, with
/// the contract quoted inline.

SearchPage _searchPage({
  SearchDomain domain = SearchDomain.communities,
  List<SearchResult> results = const <SearchResult>[],
}) => SearchPage(
  domain: domain,
  available: true,
  reasonCode: null,
  results: results,
  nextCursor: null,
);

void main() {
  group('search', () {
    testWidgets('a query in flight shows the skeleton and no result count', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(initialQuery: 'loop'),
        search: FakeSearchGateway()..pending = true,
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsNothing,
      );
    });

    testWidgets(
      'a query the server matched nothing for is empty, not an error',
      (tester) async {
        await pumpCommunityPage(
          tester,
          const GlobalSearchScreen(initialQuery: 'loop'),
          search: FakeSearchGateway(
            pages: <SearchDomain, SearchPage>{
              SearchDomain.communities: _searchPage(),
            },
          ),
        );

        expect(
          find.byKey(const ValueKey<String>('community-state-empty')),
          findsOneWidget,
        );
        expect(find.text('没有匹配的结果'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('community-state-error')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('community-state-offline')),
          findsNothing,
        );
      },
    );
  });

  group('community-discover', () {
    testWidgets('a pending directory read shows the skeleton and no count', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        community: FakeCommunityGateway()..pending = true,
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsNothing,
      );
    });
  });

  group('community-profile', () {
    testWidgets('a pending read shows the skeleton and no community name', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(detail: testDetail())..pending = true,
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
      expect(find.text('Frog Holders'), findsNothing);
    });

    testWidgets('empty is a community that is not there, never a blank card', (
      tester,
    ) async {
      // `GET /v2/communities/{id}` answers with one `CommunityDetail` or a
      // refusal. There is no "loaded, but nothing in it" case, so a community
      // the account cannot see is the server's `notFound`, and the page states
      // that rather than rendering an identity card with no facts.
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(failure: CommunityFailureKind.notFound),
      );

      expect(
        find.byKey(const ValueKey<String>('community-identity-card')),
        findsNothing,
      );
      expect(find.text('Frog Holders'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsNothing,
      );
    });
  });

  group('community-members', () {
    testWidgets('a filter that matched no member is empty, not a zero count', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          members: testDirectory(items: const <CommunityMemberEntry>[]),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsOneWidget,
      );
      expect(find.text('这个筛选下没有成员'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsNothing,
      );
    });
  });

  group('community-chat', () {
    testWidgets('a failed community read is an error, not a silent channel', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          failure: CommunityFailureKind.unexpected,
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey<String>('community-chat-channel-not-connected'),
        ),
        findsNothing,
      );
    });

    testWidgets('empty is a community that is not there, not an empty channel', (
      tester,
    ) async {
      // Message history belongs to Stream, so this page owns no collection of
      // its own: the only "nothing to show" it can state is that the route
      // carried no community identifier. It fails closed and renders no error,
      // because nothing failed.
      await pumpCommunityPage(
        tester,
        const CommunityChatScreen(communityId: null),
        community: FakeCommunityGateway(detail: testDetail()),
      );

      expect(
        find.byKey(const ValueKey<String>('community-chat-missing-id')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-offline')),
        findsNothing,
      );
    });
  });

  group('dm', () {
    testWidgets('a pending resolve shows the skeleton and opens no channel', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const DirectMessageScreen(
          target: DirectMessageTarget(publicProfileId: testMemberId),
        ),
        chat: FakeChatV2Gateway(pending: true),
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('dm-channel-not-connected')),
        findsNothing,
      );
    });

    testWidgets('no target at all is empty, never a guessed conversation', (
      tester,
    ) async {
      // `POST /v2/chat/direct-channels` answers about one counterparty, so the
      // page's only "nothing to show" is that the route named nobody. It fails
      // closed and renders no error, because nothing failed.
      await pumpCommunityPage(
        tester,
        const DirectMessageScreen(),
        chat: FakeChatV2Gateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('dm-missing-target')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('dm-channel-not-connected')),
        findsNothing,
      );
    });
  });

  group('voiceroom', () {
    testWidgets('a pending room read shows the skeleton and no participant', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway()..pending = true,
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
      expect(find.textContaining('在麦'), findsNothing);
    });

    testWidgets('voiceroom-full shares the read and so shares its loading', (
      tester,
    ) async {
      // `voiceroom-full` is the same controller with `expanded: true`; it must
      // not render an expanded room while the read that would prove one is
      // still in flight.
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId, expanded: true),
        voiceRoom: FakeVoiceRoomGateway()..pending = true,
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsNothing,
      );
    });
  });

  group('blocklist', () {
    testWidgets('a pending blocklist read shows the skeleton and no count', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const BlocklistScreen(),
        social: FakeSocialGateway()..pending = true,
        settle: false,
      );

      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-state-empty')),
        findsNothing,
      );
      expect(find.textContaining('已屏蔽'), findsNothing);
    });
  });

  group('settings and about', () {
    testWidgets('settings empty does not apply: it is one settings document', (
      tester,
    ) async {
      // `GET /v2/settings` answers with one `LoopAccountSettings` record.
      // `LoopChainResourceState.failed(kind)` takes a non-nullable kind, so
      // `loopChainPhaseForFailure(null) => empty` is unreachable and
      // `settings-state-empty` is a dead key on this page.
      await pumpS8Page(
        tester,
        GeneralSettingsScreen(onNavigate: (_) {}),
        settings: FakeAccountSettingsGateway(),
      );

      expect(
        find.byKey(const ValueKey<String>('settings-state-empty')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-state-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-state-offline')),
        findsNothing,
      );
    });

    testWidgets('about empty does not apply: it is one product record', (
      tester,
    ) async {
      // Same contract as `settings`: `GET /v2/meta/about` returns one `LoopAbout`
      // record or fails, so `about-state-empty` can never be published.
      await pumpS8Page(tester, const AboutScreen(), about: FakeAboutGateway());

      expect(
        find.byKey(const ValueKey<String>('about-state-empty')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('about-state-error')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('about-state-offline')),
        findsNothing,
      );
    });
  });

  group('force-update and region-blocked', () {
    testWidgets('force-update has no read state: it projects one decision', (
      tester,
    ) async {
      // These two are module-0 gates, not readers. `SystemSurfaceScreen` takes
      // the decided requirement as a value; the client-policy read never
      // reaches them, so they have no loading, empty, error or offline state
      // to render. Without a decision the page says the source is not wired
      // and explicitly denies that the version is unsupported.
      await tester.pumpWidget(
        const MaterialApp(home: SystemSurfaceScreen.fromId('force-update')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('update-policy-unavailable')),
        findsOneWidget,
      );
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(find.byType(LoopErrorState), findsNothing);
      expect(find.byType(LoopOfflineState), findsNothing);
      expect(find.text('请更新 LOOP 后继续'), findsNothing);
    });

    testWidgets('region-blocked has no read state either', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SystemSurfaceScreen.fromId('region-restricted'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoopSkeleton), findsNothing);
      expect(find.byType(LoopErrorState), findsNothing);
      expect(find.byType(LoopOfflineState), findsNothing);
    });
  });
}
