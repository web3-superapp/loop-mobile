// S58c · the seven chat pages, against the frozen prototype.
//
// Every expectation here cites the prototype section it comes from. They are
// the differences the 2026-09-20 visual audit found in §B and §D, one test
// per difference, so a regression is named rather than measured.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/v2/chat_conversation_label.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/features/chat/v2/chat_search_screen.dart';
import 'package:loop_mobile/features/chat/v2/community_chat_screen.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_screen.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/social/dm_requests_screen.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

final class _FakeChatSearchGateway implements ChatSearchGateway {
  _FakeChatSearchGateway(this.hits);

  final List<ChatSearchHit> hits;

  @override
  bool get connected => true;

  @override
  Future<List<ChatSearchHit>> search({
    required String query,
    required ChatSearchScope scope,
    required String? originCid,
    required int limit,
  }) async => hits;
}

LoopFolioPrimary _folio(WidgetTester tester) =>
    tester.widget<LoopFolioPrimary>(find.byType(LoopFolioPrimary));

void main() {
  loopWatchGround();

  group('B.3 · dm opens on the Chalk hero', () {
    test('the page primary is the Chalk card, without the state ring', () {
      final folio = directMessageFolio(
        testProfile(
          publicProfileId: testMemberId,
          loopId: 'LOOP-3HJKMNPQ',
          alias: 'NightOwl',
        ),
      );
      expect(folio.variant, LoopFolioVariant.chalk);
      expect(folio.ring, isFalse);
      expect(folio.kicker, 'DIRECT MESSAGE');
      expect(folio.stamp, 'PRIVATE');
      // The heading names the conversation; it is not the page's own title.
      expect(folio.heading, '和 NightOwl 的私聊');
      expect(folio.heading, isNot('私聊'));
      // A deep link carries no identity, and the hero then names the kind.
      expect(directMessageFolio(null).heading, '一对一的私聊');
    });

    testWidgets('the LOOP ID is under the name, not above it', (tester) async {
      await pumpCommunityPage(
        tester,
        DirectMessageScreen(
          target: DirectMessageTarget(
            publicProfileId: testMemberId,
            identity: testProfile(
              publicProfileId: testMemberId,
              loopId: 'LOOP-3HJKMNPQ',
              alias: 'NightOwl',
            ),
          ),
        ),
        chat: FakeChatV2Gateway(),
      );

      final bar = tester.widget<LoopTopbar>(find.byType(LoopTopbar));
      expect(bar.title, 'NightOwl');
      expect(bar.subtitle, 'LOOP-3HJKMNPQ');
      expect(bar.kicker, isNull);
      expect(bar.framedTools, isTrue);
    });
  });

  group('B.2 · the community room states what it has', () {
    test('presence is one observation, or no line at all', () {
      expect(communityChatPresenceLine(null), isNull);
    });

    test('a pinned announcement is the first pinned row the server sent', () {
      final pinned = CommunityAnnouncement(
        announcementId: 'a2',
        kind: 'roadmap',
        title: 'Q3 路线图已发布',
        byline: '项目方',
        publishedAt: DateTime.utc(2026, 9, 8, 9),
        pinned: true,
      );
      expect(
        communityChatPinnedAnnouncement(
          CommunityAnnouncementFeedPublished(<CommunityAnnouncement>[
            CommunityAnnouncement(
              announcementId: 'a1',
              kind: 'note',
              title: '早报',
              byline: null,
              publishedAt: DateTime.utc(2026, 9, 8, 8),
              pinned: false,
            ),
            pinned,
          ]),
        ),
        same(pinned),
      );
      // An unavailable feed and a feed with nothing pinned are one answer.
      expect(
        communityChatPinnedAnnouncement(
          const CommunityAnnouncementFeedUnavailable('X'),
        ),
        isNull,
      );
      expect(
        communityChatPinnedAnnouncement(
          const CommunityAnnouncementFeedPublished(<CommunityAnnouncement>[]),
        ),
        isNull,
      );
    });

    testWidgets('the AI row keeps its shape and refuses to answer', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: LoopChatAiUnavailableBubble(
              name: 'PEPE AI',
              reason: 'Community AI 还没有开放。',
              collapsed: false,
            ),
          ),
        ),
      );

      expect(find.text('PEPE AI'), findsOneWidget);
      expect(find.text('Community AI 还没有开放。'), findsOneWidget);
      // It is not a message: nothing about it may read as one.
      expect(find.byType(LoopInitialsAvatar), findsNothing);
    });

    testWidgets('the row folds away while the keyboard is up', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: LoopChatAiUnavailableBubble(
              name: 'PEPE AI',
              reason: 'Community AI 还没有开放。',
              collapsed: true,
            ),
          ),
        ),
      );

      expect(find.text('PEPE AI'), findsNothing);
    });

    test('the composer promises one line of recognition', () {
      expect(loopChatComposerHint, '发消息 · 贴合约地址识别代币');
    });
  });

  group('B.6 / D-10 · a destination row names its conversation', () {
    test('a community channel uses the name the backend wrote on it', () {
      final label = resolveChatConversationLabel(
        surface: LoopChatSurface.communityChat,
        extraData: const <String, Object?>{'name': 'DeFi 早读会'},
        cid: 'messaging:loop_community_1',
        memberCount: 311,
      );
      expect(label.title, 'DeFi 早读会');
      expect(label.subtitle, '社区官方群 · 311 名成员');
    });

    test('a channel with no usable name falls back to its kind', () {
      expect(
        resolveChatConversationLabel(
          surface: LoopChatSurface.communityChat,
          extraData: const <String, Object?>{},
        ).title,
        loopCommunityConversationNeutralLabel,
      );
      // A name that fails the display contract is no name at all.
      expect(
        resolveChatConversationLabel(
          surface: LoopChatSurface.group,
          extraData: <String, Object?>{'name': '  padded  '},
        ).title,
        '群聊',
      );
      expect(
        loopStoredConversationName(<String, Object?>{'name': 'x' * 61}),
        isNull,
      );
    });

    test('a direct row is never named from the provider channel', () {
      expect(
        resolveChatConversationLabel(
          surface: LoopChatSurface.direct,
          extraData: const <String, Object?>{'name': '不可信'},
          cid: 'messaging:loop_direct_1',
        ).title,
        isNot('不可信'),
      );
    });

    testWidgets('the hero is the one solid Lime card in the app', (
      tester,
    ) async {
      await pumpCommunityPage(tester, const ChatForwardScreen(sourceCid: null));

      final folio = _folio(tester);
      expect(folio.variant, LoopFolioVariant.lime);
      expect(folio.archetype, LoopFolioArchetype.state);
    });
  });

  group('B.5 · the search page opens on the search', () {
    testWidgets('the field is the top bar, and the hero is Chalk', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ChatSearchScreen(),
        chatSearch: _FakeChatSearchGateway(const <ChatSearchHit>[]),
      );

      final bar = tester.widget<LoopTopbar>(find.byType(LoopTopbar));
      expect(bar.titleField, isNotNull);
      expect(
        find.descendant(
          of: find.byType(LoopTopbar),
          matching: find.byKey(const ValueKey<String>('chat-search-input')),
        ),
        findsOneWidget,
      );

      final folio = _folio(tester);
      expect(folio.variant, LoopFolioVariant.chalk);
      expect(folio.ring, isFalse);
    });

    testWidgets('a result row carries a tile and the term in Lime', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const ChatSearchScreen(),
        chatSearch: _FakeChatSearchGateway(<ChatSearchHit>[
          ChatSearchHit(
            messageId: 'm1',
            cid: testGroupCid,
            senderLabel: '成员',
            channelLabel: '群聊',
            text: '有人跟 MCAT 内盘吗',
            createdAt: DateTime.utc(2026, 9, 8, 12),
          ),
        ]),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('chat-search-input')),
        '内盘',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      final row = tester.widget<LoopRecordRow>(
        find.byKey(const ValueKey<String>('chat-search-hit-m1')),
      );
      expect(row.leading, isA<LoopInitialsAvatar>());
      expect(row.subtitleSpans, isNotNull);
      final lime = row.subtitleSpans!
          .whereType<TextSpan>()
          .where((span) => span.style?.color == LoopColors.lime)
          .map((span) => span.text)
          .toList(growable: false);
      expect(lime, <String>['内盘']);
    });

    test('a term that does not occur leaves the line alone', () {
      expect(chatSearchHighlightSpans('gm', ''), isNull);
      expect(chatSearchHighlightSpans('gm', '内盘'), isNull);
      // Case does not decide whether a match is a match.
      expect(
        chatSearchHighlightSpans('Loop', 'loop')!
            .whereType<TextSpan>()
            .map((span) => span.text)
            .toList(growable: false),
        <String>['Loop'],
      );
    });
  });

  group('B.4 · the request page states what it counts', () {
    test(
      'the stamp names what it counts, and counts nothing it has not read',
      () {
        expect(messageRequestsStamp(CommunityViewPhase.ready, 1), '1 NEW');
        expect(messageRequestsStamp(CommunityViewPhase.empty, 0), '0 NEW');
        expect(messageRequestsStamp(CommunityViewPhase.loading, 0), isNull);
        expect(messageRequestsStamp(CommunityViewPhase.error, 0), isNull);
      },
    );

    testWidgets('the hero keeps no ring and the fourth card is gone', (
      tester,
    ) async {
      await pumpCommunityPage(tester, const MessageRequestsScreen());

      final folio = _folio(tester);
      expect(folio.variant, LoopFolioVariant.chalk);
      expect(folio.ring, isFalse);
      // One explanation per page is the ceiling (audit · D-5).
      expect(
        find.byKey(const ValueKey<String>('dm-requests-scope-notice')),
        findsNothing,
      );
    });
  });

  group('B.8 / D-1 · the voice room heading is a figure', () {
    test('a live room with a count states the count', () {
      final snapshot = testVoiceRoomSnapshot();
      expect(voiceRoomHeading(snapshot), '46 人在房间里');
      expect(voiceRoomStamp(snapshot), '46 LIVE');
      expect(voiceRoomTopbarLine(snapshot), '进行中 · 发言 3 · 听众 42');
    });

    test('a room whose count the server withheld states the condition', () {
      final snapshot = testVoiceRoomSnapshot(joinedCount: null);
      expect(voiceRoomHeading(snapshot), '进行中');
      expect(voiceRoomStamp(snapshot), 'LIVE');
    });

    test('an ended room is not a figure', () {
      final snapshot = testVoiceRoomSnapshot(state: VoiceRoomState.ended);
      expect(voiceRoomHeading(snapshot), '已结束');
      expect(voiceRoomStamp(snapshot), 'ENDED');
      expect(voiceRoomTopbarLine(snapshot), '已结束');
    });

    test('a page with no snapshot never prints the word for all rooms', () {
      expect(voiceRoomHeading(null), isNot('语音房'));
      expect(voiceRoomStamp(null), isNull);
      expect(voiceRoomTopbarLine(null), isNull);
    });
  });
}
