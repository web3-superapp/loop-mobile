// S350a · decision 0274: 聊天 and 广场 polish round (需求方 11-04 截图回看).
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/attachments/stream_token_card_message_preview_formatter.dart';
import 'package:loop_mobile/features/chat/chat_inbox_row_actions.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/square/square_community_list.dart';
import 'package:loop_mobile/features/square/square_feed.dart';
import 'package:loop_mobile/features/square/square_feed_view.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/loop_shots.dart';

Finder _key(String value) => find.byKey(ValueKey<String>(value));

final DateTime _now = DateTime.utc(2026, 11, 4, 12);

SquareFeedPost _post({String? text = 'Bottom in', SquareFeedToken? token}) =>
    SquareFeedPost(
      postId: '00000000-0000-4000-8000-000000000001',
      kind: SquareFeedPostKind.opinion,
      author: const SquareFeedAuthor(
        publicProfileId: 'pp_author01',
        loopId: 'LOOP-AUTHOR01',
        alias: 'pollak',
      ),
      text: text,
      token: token,
      likeCount: 0,
      likedByViewer: false,
      pinned: false,
      createdAt: _now.subtract(const Duration(minutes: 3)),
    );

Future<void> _pumpPost(
  WidgetTester tester,
  SquareFeedPost post, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SquareFeedPostRow(
                post: post,
                now: _now,
                onLike: () {},
                onOpen: (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  loopWatchGround();

  group('聊天 · inbox rows', () {
    test('the sender prefix keeps the preview weight; mentions stay', () {
      const span = TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '成员: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: '@pollak',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      );
      final quiet = loopQuietSenderPrefix(span);
      final prefix = quiet.children!.first as TextSpan;
      expect(prefix.text, '成员: ');
      // S353a: the prefix takes the preview line's own weight.
      expect(prefix.style?.fontWeight, isNull);
      final mention =
          (quiet.children![1] as TextSpan).children!.single as TextSpan;
      expect(mention.style?.fontWeight, FontWeight.bold);

      // A span with no sender prefix is returned as it is.
      const plain = TextSpan(text: '好的，收到');
      expect(identical(loopQuietSenderPrefix(plain), plain), isTrue);
    });

    test('pin and mute marks sit at the end of the preview line', () {
      expect(
        loopStreamChatThemeData().channelListItemTheme.attributePosition,
        AttributePosition.trailingBottom,
      );
    });

    testWidgets('a pinned row is one step lighter on the board', (
      tester,
    ) async {
      Widget row({required bool pinned}) => LoopBackdropScope(
        backdrop: const SizedBox.shrink(),
        child: ChatInboxSwipeRow(
          pinned: pinned,
          actions: () => const <ChatInboxRowAction>[],
          onAction: (_) {},
          child: const SizedBox(height: 80, width: 300),
        ),
      );
      final ground = find.byKey(
        const ValueKey<String>('chat-inbox-row-ground'),
      );

      // S353a · decision 0278: a row at rest sits on the page itself.
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: row(pinned: false))),
      );
      expect(ground, findsNothing);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: row(pinned: true))),
      );
      expect(tester.widget<ColoredBox>(ground).color, loopChatBoardPinnedFill);
      expect(loopChatBoardPinnedFill.withValues(alpha: 1), LoopColors.card);
    });
  });

  group('广场 · 动态', () {
    testWidgets('a post sits on the page with a hairline under it (S353a)', (
      tester,
    ) async {
      await _pumpPost(tester, _post());
      final card = _key('square-post-card');
      final box = tester.widget<Container>(card);
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, isNull);
      expect(
        decoration.border,
        const Border(bottom: BorderSide(color: LoopColors.divider)),
      );
      expect(box.margin, const EdgeInsets.symmetric(horizontal: 20));
      // The text starts on the avatar's left edge, on the page gutter.
      final text = tester.getRect(_key('square-post-text'));
      expect(text.left, 20);
    });

    testWidgets('the market cap is whole or not drawn', (tester) async {
      final token = SquareFeedToken(
        kind: SquareFeedTokenKind.meme,
        memeTokenId: '00000000-0000-4000-8000-000000000077',
        symbol: 'MOON',
        priceUsd1: Decimal.parse('0.0123'),
        change1hPct: Decimal.parse('-3.2'),
        marketCapUsd1: Decimal.parse('1250000'),
      );
      // Widths are measured in the App's own faces, not the test font.
      await tester.runAsync(loopLoadShotFonts);
      await _pumpPost(tester, _post(token: token));
      expect(_key('square-post-cap'), findsOneWidget);
      final cap = tester.widget<Text>(_key('square-post-cap'));
      expect(cap.overflow, isNot(TextOverflow.ellipsis));

      await _pumpPost(tester, _post(token: token), width: 240);
      // Too narrow for 「Mcap $1.3M」 whole: the cap is left off, the
      // ticker and the price stay.
      expect(_key('square-post-cap'), findsNothing);
      expect(_key('square-post-symbol'), findsOneWidget);
      expect(_key('square-post-price'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('广场 · 社区', () {
    testWidgets('search and 全部 / 我加入的 share one pinned line', (tester) async {
      for (final width in <double>[390, 360]) {
        await pumpCommunityPage(
          tester,
          SquareCommunityList(onOpenCommunity: (_) {}, onOpenSearch: () {}),
          community: FakeCommunityGateway(
            directoryPage: CommunityDirectoryPage(
              items: <CommunitySummary>[testCommunity()],
              nextCursor: null,
              recommendation: const CommunityRecommendation(
                recommendationId: '22222222-2222-4222-8222-222222222222',
                ruleVersion: 'rule:verified-members-v1',
              ),
              ordering: const CommunityOrderingApplied(
                sort: CommunityDirectorySort.members,
                basis: CommunityStoredBasis(),
              ),
            ),
          ),
          size: Size(width, 900),
        );
        final search = tester.getRect(_key('square-community-search'));
        final chips = tester.getRect(_key('square-community-chips'));
        expect(search.height, squareCommunityControlHeight);
        expect(chips.height, squareCommunityControlHeight);
        expect(search.top, chips.top, reason: '$width');
        expect(search.left, squareCommunityCardInset);
        expect(chips.right, width - squareCommunityCardInset);
        // 「我加入的」 is drawn whole.
        final joined = find.descendant(
          of: _key('square-filter-joined'),
          matching: find.text('Joined'),
        );
        expect(joined, findsOneWidget);
        expect(tester.getRect(joined).right, lessThanOrEqualTo(chips.right));
        // The first card starts under the line and the sort word only.
        final card = tester.getRect(
          _key('square-community-card-$testCommunityId'),
        );
        expect(card.top - chips.bottom, lessThan(64), reason: '$width');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(minutes: 30));
      }
    });
  });
}
