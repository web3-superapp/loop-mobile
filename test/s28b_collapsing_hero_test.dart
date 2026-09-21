import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_stream_scroll.dart';

/// The device the walkthrough ran on: the hero and the chip row took 41–47%
/// of it and never gave it back, so a directory of hundreds had four rows.
const _device = Size(390, 2280);

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _device;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(theme: LoopTheme.dark, home: page));
  await tester.pumpAndSettle();
}

/// The rows themselves, not the header the coordinator scrolls first: a drag
/// on the collection is what the reader does.
Finder _rows(String key) => find.descendant(
  of: find.byKey(ValueKey<String>(key)),
  matching: find.byType(Scrollable),
);

bool _onScreen(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return false;
  final rect = tester.getRect(finder);
  return rect.bottom > 0 && rect.top < _device.height;
}

void main() {
  // The primitive is mounted here without a page harness: a layout change is
  // exactly the kind that leaves paint on a ground it no longer has.
  loopWatchGround();

  group('S28-b · the hero scrolls, the chips stay', () {
    testWidgets('a stream page carries its folio past the topbar', (
      tester,
    ) async {
      var picked = -1;
      await _pump(
        tester,
        LoopStreamPage(
          archetype: LoopPageArchetype.listing,
          title: '成员',
          onBack: () {},
          folio: const LoopFolioPrimary(
            heading: '311 名成员',
            archetype: LoopFolioArchetype.listing,
            kicker: 'MEMBER DIRECTORY',
            caption: 'Owner、Admin 和成员保持清晰层级。',
          ),
          filters: LoopSegBar(
            labels: const <String>['全部', 'Owner'],
            selectedIndex: 0,
            onSelected: (index) => picked = index,
          ),
          collection: ListView(
            key: const ValueKey<String>('s28b-rows'),
            children: <Widget>[
              for (var index = 0; index < 50; index += 1)
                SizedBox(height: 64, child: Text('row $index')),
            ],
          ),
        ),
      );

      final folio = find.byType(LoopFolioPrimary);
      final chips = find.byType(LoopSegBar);
      final topbarBottom = tester.getRect(find.byType(LoopTopbar)).bottom;
      final restingFolio = tester.getRect(folio);
      expect(restingFolio.top, topbarBottom);
      expect(tester.getRect(chips).top, restingFolio.bottom);
      expect(tester.getRect(find.text('row 0')).top, greaterThan(0));

      // Reading down to row 30 takes the heading with it: it answered the
      // page once and has no claim on the viewport after that.
      await tester.scrollUntilVisible(
        find.text('row 30'),
        400,
        scrollable: _rows('s28b-rows'),
      );
      await tester.pumpAndSettle();
      expect(_onScreen(tester, folio), isFalse);

      // The one control that changes what is being listed stays reachable,
      // directly under the topbar, and still answers a tap.
      expect(_onScreen(tester, chips), isTrue);
      expect(tester.getRect(chips).top, topbarBottom);
      await tester.tap(find.text('Owner'));
      await tester.pumpAndSettle();
      expect(picked, 1);

      // And the heading comes back whole at the top of the list.
      await loopStreamScrollToTop(tester);
      expect(tester.getRect(folio), restingFolio);
    });

    testWidgets('the folio page still answers a pull at the top', (
      tester,
    ) async {
      var reads = 0;
      await _pump(
        tester,
        LoopStreamPage(
          archetype: LoopPageArchetype.listing,
          title: '成员',
          onRefresh: () async => reads += 1,
          folio: const LoopFolioPrimary(
            heading: '311 名成员',
            archetype: LoopFolioArchetype.listing,
          ),
          collection: ListView(
            key: const ValueKey<String>('s28b-rows'),
            children: <Widget>[
              for (var index = 0; index < 50; index += 1)
                SizedBox(height: 64, child: Text('row $index')),
            ],
          ),
        ),
      );

      // The header and the rows are one coordinated view now, and the drag
      // that reaches the indicator is reported a level below the one it used
      // to hear: a folio page had kept a gesture that did nothing.
      await tester.fling(find.text('row 1'), const Offset(0, 900), 1000);
      await tester.pumpAndSettle();
      expect(reads, 1);
    });

    testWidgets('a page with no folio keeps its chrome fixed', (tester) async {
      await _pump(
        tester,
        LoopStreamPage(
          archetype: LoopPageArchetype.record,
          title: '搜索',
          filters: LoopSegBar(
            labels: const <String>['全部'],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
          collection: ListView(
            key: const ValueKey<String>('s28b-rows'),
            children: <Widget>[
              for (var index = 0; index < 50; index += 1)
                SizedBox(height: 64, child: Text('row $index')),
            ],
          ),
        ),
      );

      final chips = tester.getRect(find.byType(LoopSegBar));
      await tester.scrollUntilVisible(
        find.text('row 30'),
        400,
        scrollable: _rows('s28b-rows'),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(LoopSegBar)), chips);
    });
  });

  group('S28-b · the two directories that ran out of room', () {
    testWidgets('the member directory gives the rows the screen', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        size: _device,
        community: FakeCommunityGateway(
          members: testDirectory(
            items: <CommunityMemberEntry>[
              for (var index = 0; index < 50; index += 1)
                testMember(
                  role: CommunityRole.member,
                  publicProfileId:
                      '7a3d2e4c-5b6c-4d7e-8f90-1a2b3c4d5${index.toString().padLeft(3, '0')}',
                  alias: 'member_$index',
                  loopId: 'LOOP-3HJKMNP$index',
                ),
            ],
          ),
        ),
      );

      final folio = find.byType(LoopFolioPrimary);
      expect(_onScreen(tester, folio), isTrue);
      await tester.scrollUntilVisible(
        find.text('member_30'),
        400,
        scrollable: _rows('community-members-list'),
      );
      await tester.pumpAndSettle();
      expect(_onScreen(tester, folio), isFalse);
      // 全部 / Owner / Admin stay: at row 30 the reader can still change
      // which directory is being read.
      expect(
        _onScreen(
          tester,
          find.byKey(const ValueKey<String>('members-seg-all')),
        ),
        isTrue,
      );

      await loopStreamScrollToTop(tester);
      expect(_onScreen(tester, folio), isTrue);
    });

    testWidgets('the discovery desk gives the rows the screen', (tester) async {
      await pumpCommunityPage(
        tester,
        const CommunityDiscoverScreen(),
        size: _device,
        community: FakeCommunityGateway(
          directoryPage: CommunityDirectoryPage(
            ordering: const CommunityOrderingApplied(
              sort: CommunityDirectorySort.members,
              basis: CommunityStoredBasis(),
            ),

            items: <CommunitySummary>[
              for (var index = 0; index < 50; index += 1)
                testCommunity(
                  communityId:
                      '3fa85f64-5717-4562-b3fc-2c963f66a${index.toString().padLeft(3, '0')}',
                  name: 'Frog Holders $index',
                ),
            ],
            nextCursor: null,
            recommendation: const CommunityRecommendation(
              recommendationId: '22222222-2222-4222-8222-222222222222',
              ruleVersion: 'rule:verified-members-v1',
            ),
          ),
        ),
      );

      final folio = find.byType(LoopFolioPrimary);
      expect(_onScreen(tester, folio), isTrue);
      await tester.scrollUntilVisible(
        find.text('Frog Holders 30'),
        400,
        scrollable: _rows('community-discover-list'),
      );
      await tester.pumpAndSettle();
      expect(_onScreen(tester, folio), isFalse);
      expect(
        _onScreen(
          tester,
          find.byKey(const ValueKey<String>('discover-seg-members')),
        ),
        isTrue,
      );

      await loopStreamScrollToTop(tester);
      expect(_onScreen(tester, folio), isTrue);
    });
  });
}
