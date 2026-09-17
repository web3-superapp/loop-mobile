import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/search_controller.dart'
    as loop_search;
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/community_test_harness.dart';

SearchPage _page(SearchDomain domain) => SearchPage(
  domain: domain,
  available: true,
  reasonCode: null,
  results: <SearchResult>[
    const SearchResult(
      resultType: SearchResultType.community,
      stableId: testCommunityId,
      title: 'Alpha Holders',
      subtitle: 'alpha-holders',
      avatarRef: null,
      memberCount: 128,
      verificationStatus: 'verified',
      destination: SearchDestinationKind.communityProfile,
    ),
  ],
  nextCursor: null,
);

/// Typing in the search field used to do nothing at all.
///
/// Five characters left the page on 「输入至少 2 个字符开始搜索」 with no
/// loading state and no result, and only the keyboard's search key sent the
/// query — a control that reads as broken. The field is now debounced the same
/// way the member directory's search is.
void main() {
  group('search · the query field', () {
    testWidgets('the field names every category it searches', (tester) async {
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: FakeSearchGateway(),
      );

      // Five chips, and the label used to name two of them.
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('search-field')),
      );
      for (final domain in loop_search.searchDomainOrder) {
        expect(
          field.decoration?.labelText,
          contains(domain.label),
          reason: domain.wireName,
        );
      }
      expect(field.decoration?.labelText, isNot(contains('搜索社区或用户')));

      // And it sends people to the switch by the name the privacy centre
      // gives it.
      expect(find.textContaining('显示 LOOP ID'), findsOneWidget);
      expect(find.textContaining('可被发现'), findsNothing);
    });

    testWidgets('a keystroke shows the read it started', (tester) async {
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{
          SearchDomain.communities: _page(SearchDomain.communities),
        },
      );
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: gateway,
        settle: false,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('search-seg-communities')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('search-field')),
        'alpha',
      );
      await tester.pump();

      // The field settles first: the read has not gone out yet, but the page
      // already says it is working rather than repeating the minimum length.
      expect(gateway.queries, isEmpty);
      expect(find.byType(LoopSkeleton), findsWidgets);
      expect(find.textContaining('输入至少'), findsNothing);

      await tester.pump(loop_search.SearchController.searchDebounce);
      await tester.pumpAndSettle();

      expect(gateway.queries, <String>['communities:alpha']);
      expect(find.text('Alpha Holders'), findsOneWidget);
    });

    testWidgets('one word is one request, not one per keystroke', (
      tester,
    ) async {
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{
          SearchDomain.communities: _page(SearchDomain.communities),
        },
      );
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: gateway,
        settle: false,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('search-seg-communities')),
      );
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey<String>('search-field'));
      for (final typed in <String>['al', 'alp', 'alph', 'alpha']) {
        await tester.enterText(field, typed);
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pump(loop_search.SearchController.searchDebounce);
      await tester.pumpAndSettle();

      expect(gateway.queries, <String>['communities:alpha']);
    });

    testWidgets('a prefix that is too short still spends no quota', (
      tester,
    ) async {
      final gateway = FakeSearchGateway(
        pages: <SearchDomain, SearchPage>{
          SearchDomain.communities: _page(SearchDomain.communities),
        },
      );
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(),
        search: gateway,
        settle: false,
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('search-seg-communities')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('search-field')),
        'a',
      );
      await tester.pump(loop_search.SearchController.searchDebounce);
      await tester.pumpAndSettle();

      expect(gateway.queries, isEmpty);
      expect(find.textContaining('输入至少'), findsOneWidget);
    });
  });
}
