// S353a · decision 0278: 聊天, 广场·动态 and 广场·社区 at the Figma's measures
// (docs/58 §5.1 / §5.3 / §5.6–§5.8 / §5.20).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/friends/chat_create_menu_button.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/features/square/square_feed.dart';
import 'package:loop_mobile/features/square/square_feed_view.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';
import 'package:loop_mobile/widgets/loop_unread_badge.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

final DateTime _now = DateTime.utc(2026, 11, 4, 12);

SquareFeedPost _post({
  SquareFeedPostKind kind = SquareFeedPostKind.opinion,
  bool liked = false,
  bool pinned = false,
  SquareFeedToken? token,
}) => SquareFeedPost(
  postId: '00000000-0000-4000-8000-000000000001',
  kind: kind,
  author: kind == SquareFeedPostKind.system
      ? null
      : const SquareFeedAuthor(
          publicProfileId: 'pp_author01',
          loopId: 'LOOP-AUTHOR01',
          alias: 'pollak',
        ),
  text: 'Bottom in',
  token: token,
  likeCount: 3,
  likedByViewer: liked,
  pinned: pinned,
  createdAt: _now.subtract(const Duration(minutes: 3)),
);

Future<void> _host(WidgetTester tester, Widget child, {double width = 390}) {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  loopWatchGround();

  group('聊天', () {
    test('a conversation row is 67 with a 48 face', () {
      expect(chatInboxRowHeight, 67);
      expect(
        2 * (ChatInboxRowMetrics.outer + ChatInboxRowMetrics.inner) + 48,
        chatInboxRowHeight,
      );
      expect(ChatInboxRowMetrics.gap, 12);
      expect(
        LoopSpacing.page -
            ChatInboxRowMetrics.outer -
            ChatInboxRowMetrics.inner,
        greaterThan(0),
      );
    });

    testWidgets('the 「＋」 key is a 32 Yellow square at a 4 corner', (
      tester,
    ) async {
      await _host(tester, const Center(child: ChatCreateMenuButton()));
      final target = tester.getSize(_key('chat-create-menu'));
      expect(target.width, greaterThanOrEqualTo(LoopTouch.minimum));
      expect(target.height, greaterThanOrEqualTo(LoopTouch.minimum));
      final face = tester.widget<Container>(_key('chat-create-menu-face'));
      final decoration = face.decoration! as BoxDecoration;
      expect(decoration.color, LoopColors.yellow);
      expect(decoration.borderRadius, LoopRadius.stage);
      expect(tester.getSize(_key('chat-create-menu-face')), const Size(32, 32));
    });

    testWidgets('a group name carries its head count; none, none drawn', (
      tester,
    ) async {
      await _host(
        tester,
        Column(
          children: <Widget>[
            loopGroupChannelListTitle('Airdrop hunters', 10),
            loopGroupChannelListTitle('Quiet', null),
          ],
        ),
      );
      expect(_key('loop-channel-member-count'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(tester.getSize(_key('loop-channel-member-count')).height, 18);
    });

    testWidgets('the unread count is a 20 round', (tester) async {
      await _host(
        tester,
        const Row(
          children: <Widget>[
            LoopUnreadBadge(
              count: 3,
              color: LoopColors.yellow,
              height: loopChannelUnreadBadgeHeight,
            ),
          ],
        ),
      );
      expect(tester.getSize(_key('loop-unread-pill')), const Size(20, 20));
    });
  });

  group('广场 · 分段头', () {
    testWidgets('English segments shrink to fit a 360 line, whole at 390', (
      tester,
    ) async {
      await tester.runAsync(loopLoadShotFonts);
      late double narrow;
      late double wide;
      await _host(
        tester,
        Builder(
          builder: (context) {
            const words = <String>['Feed', 'Community', 'Voice rooms'];
            narrow = loopSegmentFitScale(context, words, 0, 270);
            wide = loopSegmentFitScale(context, words, 0, 2000);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(wide, 1);
      expect(narrow, lessThan(1));
      expect(narrow, greaterThanOrEqualTo(loopSegmentFitFloor));
    });
  });

  group('广场 · 动态', () {
    testWidgets('a 48 face, the age under the name, ♡ at the right', (
      tester,
    ) async {
      await _host(
        tester,
        SquareFeedPostRow(
          post: _post(liked: true),
          now: _now,
          onLike: () {},
          onOpen: (_) {},
        ),
      );
      final name = tester.getRect(_key('square-post-name'));
      final age = tester.getRect(_key('square-post-age'));
      expect(age.top, greaterThanOrEqualTo(name.bottom));
      expect(name.left, 20 + 48 + 12);
      final like = tester.getRect(_key('square-post-like'));
      expect(like.right, greaterThan(390 - 20 - 1));
      final count = tester.widget<Text>(_key('square-post-like-count'));
      expect(count.style?.color, LoopColors.yellow);
      expect(_key('square-post-badge-opinion'), findsOneWidget);
      expect(
        find.descendant(
          of: _key('square-post-badge-opinion'),
          matching: find.byType(Text),
        ),
        findsOneWidget,
      );
      final tag = tester.widget<LoopStatusTag>(
        _key('square-post-badge-opinion'),
      );
      expect(tag.tone, LoopTagTone.purple);
    });

    testWidgets('the quote card is 64 at an 11 corner on the inset ground', (
      tester,
    ) async {
      await tester.runAsync(loopLoadShotFonts);
      final token = SquareFeedToken(
        kind: SquareFeedTokenKind.meme,
        memeTokenId: '00000000-0000-4000-8000-000000000077',
        symbol: 'FROG',
        priceUsd1: Decimal.parse('0.00004173'),
        change1hPct: Decimal.parse('14.4'),
        marketCapUsd1: Decimal.parse('666700'),
      );
      await _host(
        tester,
        SquareFeedPostRow(
          post: _post(token: token),
          now: _now,
          onLike: () {},
          onOpen: (_) {},
        ),
        width: 360,
      );
      expect(tester.getSize(_key('square-post-quote')).height, 64);
      expect(_key('square-post-cap'), findsOneWidget);
      expect(_key('square-post-change'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pinned is the Yellow tag, graduation the Green', (
      tester,
    ) async {
      await _host(
        tester,
        Column(
          children: <Widget>[
            squareFeedBadge(
              _post(kind: SquareFeedPostKind.system, pinned: true),
            )!,
            squareFeedBadge(_post(kind: SquareFeedPostKind.graduation))!,
          ],
        ),
      );
      expect(
        tester.widget<LoopStatusTag>(_key('square-post-badge-pinned')).tone,
        LoopTagTone.yellow,
      );
      expect(
        tester.widget<LoopStatusTag>(_key('square-post-badge-graduation')).tone,
        LoopTagTone.green,
      );
    });
  });

  group('广场 · 社区', () {
    testWidgets('an 86 row, a 56 logo, the 54 × 28 join, the number only', (
      tester,
    ) async {
      await tester.runAsync(loopLoadShotFonts);
      final base = testCommunity(memberCount: 1280);
      final community = CommunitySummary(
        communityId: base.communityId,
        name: base.name,
        slug: base.slug,
        description: 'Home of the frog holders',
        logoRef: null,
        verificationStatus: base.verificationStatus,
        boundAssetKey: null,
        memberCount: base.memberCount,
        createdAt: base.createdAt,
        configVersion: base.configVersion,
        viewerMembership: CommunityDirectoryViewer.none,
      );
      await _host(
        tester,
        ListView(
          children: <Widget>[
            SquareCommunityRow(
              community: community,
              sort: CommunityDirectorySort.members,
              joining: false,
              onOpen: () {},
              onJoin: () {},
            ),
          ],
        ),
        width: 360,
      );
      final row = tester.getSize(
        _key('square-community-card-$testCommunityId'),
      );
      expect(row.height, squareCommunityRowHeight);
      expect(
        tester.getSize(_key('square-community-logo-$testCommunityId')),
        const Size(56, 56),
      );
      expect(
        tester.getSize(_key('square-community-pill-$testCommunityId')),
        const Size(54, 28),
      );
      expect(
        tester
            .widget<Text>(_key('square-community-members-$testCommunityId'))
            .data,
        '1,280',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
