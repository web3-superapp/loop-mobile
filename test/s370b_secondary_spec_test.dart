// S370b · decision 0294: the 社区 / 聊天 / 社交 second-level pages at the
// Figma's row measures (docs/58 §3.2 / §3.3 / §9.4), borrowed from the
// nearest drawn row where the requester drew none.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/widgets/group_mosaic_avatar.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_manage_screen.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/community/community_record_row.dart';
import 'package:loop_mobile/features/community/search_models.dart';
import 'package:loop_mobile/features/community/search_screen.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/connections_screen.dart';
import 'package:loop_mobile/features/social/dm_requests_screen.dart';
import 'package:loop_mobile/features/social/secondary_row_metrics.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

Finder _keyPrefix(String prefix) => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith(prefix),
);

ConnectionPage _connections() => ConnectionPage(
  direction: ConnectionDirection.following,
  items: <ConnectionEntry>[
    ConnectionEntry(
      profile: testProfile(
        publicProfileId: testMemberId,
        loopId: 'LOOP-3HJKMNPQ',
        alias: 'frog_member',
      ),
      createdAt: DateTime.utc(2026, 8),
      viewerFollows: true,
      miningPower: testMiningPower,
    ),
  ],
  counts: const ConnectionCounts(following: 1, followers: 0),
  nextCursor: null,
);

MessageRequestPage _requests() => MessageRequestPage(
  items: <MessageRequestEntry>[
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

const _assetId = 'eip155:56:0x55d398326f99059ff775485246999027b3197955';

SearchPage _searchPage(SearchDomain domain) => SearchPage(
  domain: domain,
  available: true,
  reasonCode: null,
  results: <SearchResult>[
    SearchResult(
      resultType: switch (domain) {
        SearchDomain.users => SearchResultType.user,
        SearchDomain.assets => SearchResultType.asset,
        _ => SearchResultType.community,
      },
      stableId: switch (domain) {
        SearchDomain.users => testMemberId,
        SearchDomain.assets => _assetId,
        _ => testCommunityId,
      },
      title: switch (domain) {
        SearchDomain.users => 'frog_maxi',
        SearchDomain.assets => 'USDT',
        _ => 'Frog Holders',
      },
      subtitle: null,
      avatarRef: null,
      memberCount: domain == SearchDomain.communities ? 128 : null,
      verificationStatus: null,
      destination: switch (domain) {
        SearchDomain.users => const SearchPublicProfileDestination(),
        SearchDomain.assets => const SearchAssetDestination(_assetId),
        _ => const SearchCommunityProfileDestination(),
      },
    ),
  ],
  nextCursor: null,
);

void main() {
  loopWatchGround();

  group('row metrics borrowed from the drawn rows', () {
    test('person / community / function / token rows', () {
      expect(SecondaryRowMetrics.personRow, 67);
      expect(SecondaryRowMetrics.personFace, 48);
      expect(SecondaryRowMetrics.communityRow, 86);
      expect(SecondaryRowMetrics.communityLogo, 56);
      expect(SecondaryRowMetrics.communityLogoRadius, 12);
      expect(SecondaryRowMetrics.functionRow, 56);
      expect(SecondaryRowMetrics.functionGlyph, 34);
      expect(SecondaryRowMetrics.tokenRow, 71);
      expect(SecondaryRowMetrics.tokenLogo, 44);
      expect(chatListAvatarSize, SecondaryRowMetrics.personFace);
    });
  });

  group('社区', () {
    testWidgets('a community record row is 86 with a 56 r12 logo and a line', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: Scaffold(
              body: Column(
                children: <Widget>[
                  CommunityRecordRow(
                    rowKey: const ValueKey<String>('row'),
                    communityId: testCommunityId,
                    name: 'Frog Holders',
                    logoRef: null,
                    subtitle: '128 members',
                    semanticLabel: 'Frog Holders',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.getSize(_key('row')).height, 86);
      final logo = find.descendant(
        of: _key('row'),
        matching: find.byType(CommunityLogo),
      );
      expect(tester.getSize(logo), const Size(56, 56));
      expect(tester.widget<CommunityLogo>(logo).radius, 12);
      expect(
        find.descendant(
          of: _key('row'),
          matching: find.byKey(LoopRecordRow.dividerKey),
        ),
        findsOneWidget,
      );
      // The logo starts on the 20 page margin.
      expect(tester.getTopLeft(logo).dx, LoopSpacing.page);
    });

    testWidgets('members: the owner row is a community row, a member 67 / 48', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(),
          members: testDirectory(),
        ),
        social: FakeSocialGateway(),
      );

      expect(
        tester.getSize(_key('community-members-owner-row')).height,
        SecondaryRowMetrics.communityRow,
      );
      expect(
        tester.getSize(_key('community-members-logo')),
        const Size(56, 56),
      );
      final row = _keyPrefix('member-row-').first;
      expect(tester.getSize(row).height, SecondaryRowMetrics.personRow);
      expect(
        tester.getSize(
          find.descendant(of: row, matching: find.byType(LoopProfileAvatar)),
        ),
        const Size(48, 48),
      );
    });

    testWidgets('manage: header 86 / 56, function rows 56 on a 34 glyph', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const CommunityManageScreen(communityId: testCommunityId),
        size: const Size(390, 2000),
        community: FakeCommunityGateway(
          detail: testDetail(),
          members: testDirectory(),
        ),
      );

      final header = _key('community-manage-header');
      expect(tester.getSize(header).height, SecondaryRowMetrics.communityRow);
      expect(
        tester.getSize(
          find.descendant(of: header, matching: find.byType(CommunityLogo)),
        ),
        const Size(56, 56),
      );
      final share = _key('community-manage-share');
      expect(tester.getSize(share).height, SecondaryRowMetrics.functionRow);
      expect(
        tester.getSize(
          find.descendant(of: share, matching: find.byType(LoopEntryIcon)),
        ),
        const Size(34, 34),
      );
    });

    testWidgets('search: a 44 r12 box, token 71 / 44, community 86 / 56', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const GlobalSearchScreen(initialQuery: 'frog'),
        search: FakeSearchGateway(
          pages: <SearchDomain, SearchPage>{
            for (final domain in SearchDomain.values)
              domain: _searchPage(domain),
          },
        ),
      );

      expect(tester.getSize(_key('search-field')).height, 44);
      final field = tester.widget<TextField>(_key('search-field'));
      expect(field.decoration!.fillColor, LoopColors.searchBg);
      final community = _key('search-result-$testCommunityId');
      expect(
        tester.getSize(community.first).height,
        SecondaryRowMetrics.communityRow,
      );
      expect(
        tester.getSize(
          find
              .descendant(
                of: community.first,
                matching: find.byType(CommunityLogo),
              )
              .first,
        ),
        const Size(56, 56),
      );
      final asset = _key('search-result-$_assetId');
      if (asset.evaluate().isNotEmpty) {
        expect(
          tester.getSize(asset.first).height,
          SecondaryRowMetrics.tokenRow,
        );
        expect(
          tester.getSize(
            find
                .descendant(
                  of: asset.first,
                  matching: find.byType(LoopTokenLogo),
                )
                .first,
          ),
          const Size(44, 44),
        );
      }
      // The segments start on the page margin.
      expect(
        tester.getTopLeft(_key('search-seg-all')).dx,
        greaterThanOrEqualTo(LoopSpacing.page),
      );
    });
  });

  group('社交', () {
    testWidgets('connections: a person row is 67 with a 48 face', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ConnectionsScreen(),
        social: FakeSocialGateway(connections: _connections()),
      );

      final row = _key('connection-row-$testMemberId');
      expect(tester.getSize(row).height, SecondaryRowMetrics.personRow);
      expect(
        tester.getSize(
          find.descendant(of: row, matching: find.byType(LoopProfileAvatar)),
        ),
        const Size(48, 48),
      );
    });

    testWidgets('message requests: 67 / 48', (tester) async {
      await pumpCommunityPage(
        tester,
        const MessageRequestsScreen(),
        social: FakeSocialGateway(requests: _requests()),
      );

      final row = _key('dm-request-row-$testRequestId');
      expect(tester.getSize(row).height, SecondaryRowMetrics.personRow);
      expect(
        tester.getSize(
          find.descendant(of: row, matching: find.byType(LoopProfileAvatar)),
        ),
        const Size(48, 48),
      );
    });
  });

  // Surfaces that need a live Stream session to mount: their measures are
  // pinned at the source, as the shared metrics they now read.
  group('聊天 (source)', () {
    String read(String path) => File(path).readAsStringSync();

    test('forward sheet row is the conversation row', () {
      final sheet = read('lib/features/chat/v2/forward_target_sheet.dart');
      expect(sheet, contains('minHeight: LoopRowHeight.chat'));
      expect(sheet, contains('style: LoopType.rowTitleLg'));
      expect(sheet, contains('style: LoopType.captionMd'));
    });

    test('forward targets and chat search hits wear the 48 face', () {
      for (final path in <String>[
        'lib/features/chat/v2/chat_forward_screens.dart',
        'lib/features/chat/v2/chat_search_screen.dart',
      ]) {
        final source = read(path);
        expect(source, contains('size: chatListAvatarSize'), reason: path);
        expect(source, isNot(contains('radius: 15')), reason: path);
        expect(source, isNot(contains('size: 44,')), reason: path);
      }
    });

    test('voice room, call and sheet edges sit on the 20 page margin', () {
      final edge = RegExp(r'fromLTRB\(16, [0-9]+, 16|horizontal: 16, vertical');
      for (final path in <String>[
        'lib/features/chat/calls/stream_voice_room_page.dart',
        'lib/features/chat/calls/stream_foreground_call_view.dart',
        'lib/features/chat/v2/voice_room_screens.dart',
        'lib/features/chat/v2/voice_room_stage.dart',
        'lib/features/chat/v2/forward_target_sheet.dart',
        'lib/features/chat/voice_room_page.dart',
      ]) {
        expect(edge.hasMatch(read(path)), isFalse, reason: path);
      }
    });

    test('the token card reads type steps, not raw sizes', () {
      final card = read(
        'lib/features/chat/token_card/chat_token_card_view.dart',
      );
      expect(card, isNot(contains('fontSize:')));
    });

    test('friend picker wears the 48 face', () {
      expect(
        read('lib/features/chat/friends/friend_screens.dart'),
        contains('size: SecondaryRowMetrics.personFace'),
      );
    });

    test('community profile: function rows 56 / 34, bound token 71 / 44', () {
      final profile = read(
        'lib/features/community/community_profile_screen.dart',
      );
      expect(
        'height: SecondaryRowMetrics.functionRow'.allMatches(profile).length,
        3,
      );
      expect(profile, contains('height: SecondaryRowMetrics.tokenRow'));
      expect(profile, contains('size: SecondaryRowMetrics.tokenLogo'));
    });

    test('community home and discover rows wear the 56 r12 logo', () {
      for (final path in <String>[
        'lib/features/community/community_screen.dart',
        'lib/features/community/community_widgets.dart',
      ]) {
        expect(
          read(path),
          contains('size: SecondaryRowMetrics.communityLogo'),
          reason: path,
        );
      }
    });
  });
}
