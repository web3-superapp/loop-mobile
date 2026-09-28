// S99 · device feedback round 1 (decision 0105).
//
// Six reports from the review iPhone in the 「DeFi 早读会」 community room:
// the reply state lost the message list, a quote in the reader's own bubble
// was Lime on Lime, every member could pin, the voice room could not be
// shared, one tap switched a notification category off, and nothing said a
// conversation had unread messages.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/loop_channel_message_policy.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_screens.dart';
import 'package:loop_mobile/features/chat/v2/voice_room_share.dart';
import 'package:loop_mobile/features/community/community_home_widgets.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/notifications/notification_models.dart';
import 'package:loop_mobile/features/profile/notification_preferences/notification_preferences_screen.dart';
import 'package:loop_mobile/features/social/loop_id_share.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_unread.dart';
import 'package:loop_mobile/integrations/communication/stream_connection.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/sharing/system_text_share.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_unread_badge.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_page_harness.dart';

const String _cid = 'messaging:loop_community_99565a0c000000000000000000000000';
const String _me = 'me';
const Key _list = ValueKey<String>('loop-stream-message-list');
const Key _composer = ValueKey<String>('loop-stream-message-composer');

class _Connected implements LoopStreamConnection {
  @override
  bool get isConnected => true;
  @override
  Future<void> open() async {}
}

/// A client whose read receipts stay on the device: reading to the bottom
/// marks the channel read locally and asks no server.
class _OfflineReadClient extends StreamChatClient {
  _OfflineReadClient() : super('key', logLevel: Level.OFF);

  int markReadCalls = 0;

  @override
  Future<EmptyResponse> markChannelRead(
    String channelId,
    String channelType, {
    String? messageId,
  }) async {
    markReadCalls += 1;
    return EmptyResponse();
  }
}

/// One community channel with forty messages, the newest at the bottom.
final class _Room {
  _Room({this.unread = false, this.quoteOwn = false}) {
    // ignore: invalid_use_of_internal_member
    client.state.currentUser = OwnUser(id: _me, name: '我');
    channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: _cid.split(':').last,
          type: 'messaging',
          ownCapabilities: const <String>[
            'quote-message',
            'send-message',
            'send-reply',
            'pin-message',
            'read-events',
          ],
        ),
        membership: Member(userId: _me),
        members: <Member>[
          Member(
            userId: _me,
            user: User(id: _me),
          ),
        ],
        messages: history,
        read: unread
            ? <Read>[
                Read(
                  user: User(id: _me),
                  lastRead: history[15].createdAt,
                  lastReadMessageId: history[15].id,
                  unreadMessages: 24,
                ),
              ]
            : const <Read>[],
      ),
    );
  }

  final bool unread;
  final bool quoteOwn;
  final _OfflineReadClient client = _OfflineReadClient();
  late final Channel channel;
  static final DateTime now = DateTime.utc(2026, 9, 28, 12);

  late final List<Message> history = <Message>[
    for (var i = 40; i >= 1; i--)
      Message(
        id: 'h$i',
        text: '历史 $i',
        user: User(id: i.isEven ? _me : 'other', name: '成员'),
        createdAt: now.subtract(Duration(minutes: i)),
        state: MessageState.sent,
        quotedMessage: quoteOwn && i == 2
            ? Message(
                id: 'h3',
                text: '历史 3',
                user: User(id: 'other', name: '成员'),
                createdAt: now.subtract(const Duration(minutes: 3)),
              )
            : quoteOwn && i == 1
            ? Message(
                id: 'h2',
                text: '历史 2',
                user: User(id: _me, name: '我'),
                createdAt: now.subtract(const Duration(minutes: 2)),
              )
            : null,
      ),
  ];

  Future<void> pump(WidgetTester tester, {bool? mayPin}) async {
    // The official composer builds a voice recorder whether or not recording
    // is offered, and its dispose waits on the plugin's `create`. Answering
    // the plugin channel lets the recorder shut its amplitude timer.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.llfbandit.record/messages'),
        null,
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        // As in `lib/app.dart` (decision 0065): the Lime Ledger palette is a
        // StreamTheme extension on the ambient theme.
        theme: LoopTheme.dark.copyWith(
          extensions: [...LoopTheme.dark.extensions.values, loopStreamTheme()],
        ),
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          LoopStreamChatLocalizationsDelegate(),
        ],
        // As in `lib/app.dart`: above the navigator, so the long-press sheet
        // (an overlay route) is under StreamChat too.
        builder: (context, child) => StreamChat(
          client: client,
          themeData: loopStreamChatThemeData(),
          componentBuilders: StreamComponentBuilders(
            messageText: loopStreamMessageTextBuilder,
            extensions: streamChatComponentBuilders(
              messageItem: loopStreamGroupMessageItemBuilder,
              quotedMessage: loopStreamQuotedMessageBuilder,
            ),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 72),
                Expanded(
                  child: LoopStreamMemberChannelBody(
                    client: client,
                    cid: _cid,
                    userId: _me,
                    composerHint: loopChatComposerHint,
                    unresolvedMessage: null,
                    header: null,
                    banner: null,
                    footer: null,
                    keyPrefix: 'community-chat-channel',
                    connection: _Connected(),
                    query: () async => <Channel>[channel],
                    mayPinMessages: mayPin,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openActions(WidgetTester tester, String text) async {
    // The bubble, not the text span: a press on the text selects it.
    await tester.longPressAt(
      tester.getRect(find.text(text)).centerLeft - const Offset(8, 0),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Stream's typing and read debounces run out.
    await tester.pump(const Duration(seconds: 5));
    channel.dispose();
  }
}

/// Raises a 300 pt keyboard over ten frames, the way a device animates it.
Future<void> _raiseKeyboard(WidgetTester tester) async {
  for (var step = 1; step <= 10; step += 1) {
    tester.view.viewInsets = FakeViewPadding(bottom: 30.0 * step);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

void main() {
  loopWatchGround();

  group('1 · replying keeps the conversation on screen', () {
    for (final unread in <bool>[false, true]) {
      testWidgets(
        'reply + keyboard: the list fills what is left and the newest '
        'message sits on the reply strip (unread: $unread)',
        (tester) async {
          final room = _Room(unread: unread);
          await room.pump(tester);
          // A room entered at its unread divider is anchored mid-screen;
          // the reader has scrolled down to the newest message.
          await tester.fling(find.byKey(_list), const Offset(0, -4000), 4000);
          await tester.pumpAndSettle();

          await room.openActions(tester, '历史 2');
          await tester.tap(find.text('回复'));
          await tester.pumpAndSettle();
          await _raiseKeyboard(tester);

          final body = tester.getRect(find.byType(LoopStreamMemberChannelBody));
          final list = tester.getRect(find.byKey(_list));
          final composer = tester.getRect(find.byKey(_composer));
          // The composer carries the reply strip, so the list is the visible
          // body minus the composer-with-strip, and nothing else.
          final strip = find.descendant(
            of: find.byKey(_composer),
            matching: find.byWidgetPredicate(
              (w) =>
                  w.runtimeType.toString() ==
                  'StreamMessageComposerReplyAttachment',
            ),
          );
          expect(strip, findsOneWidget);
          expect(tester.getSize(strip).height, greaterThan(0));
          expect(list.top, body.top);
          expect(list.bottom, composer.top);
          expect(list.height, closeTo(body.height - composer.height, 0.5));
          expect(composer.bottom, closeTo(844 - 300, 0.5));

          // The newest message is visible and directly above the strip.
          final newest = find.text('历史 1');
          expect(newest, findsOneWidget);
          final newestRect = tester.getRect(newest);
          expect(newestRect.top, greaterThanOrEqualTo(list.top));
          expect(newestRect.bottom, lessThanOrEqualTo(list.bottom));
          expect(list.bottom - newestRect.bottom, lessThan(64));

          tester.view.resetViewInsets();
          await room.dispose(tester);
        },
      );
    }
  });

  group('2 · a quote inside the reader\'s own bubble', () {
    testWidgets('is Ink on Ink 12 % with a 3 dp Ink bar; incoming keeps '
        'Stream\'s card', (tester) async {
      final room = _Room(quoteOwn: true);
      await room.pump(tester);

      // h1 is an incoming message quoting the reader; h2 is the reader's own
      // message quoting somebody else.
      final outgoing = find.byType(LoopOutgoingQuotedMessage);
      expect(outgoing, findsOneWidget);
      final card = tester.widget<Material>(
        find.byKey(const ValueKey<String>('loop-quoted-outgoing')),
      );
      expect(card.color, LoopColors.ink.withValues(alpha: 0.12));
      expect(card.color, isNot(LoopColors.lime));

      final bar = tester.widget<Container>(
        find.byKey(const ValueKey<String>('loop-quoted-outgoing-bar')),
      );
      expect((bar.decoration! as BoxDecoration).color, LoopColors.ink);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey<String>('loop-quoted-outgoing-bar')),
            )
            .width,
        3,
      );

      // Every word in the card is Ink: the resolved name when there is one,
      // and the preview.
      for (final text in tester.widgetList<Text>(
        find.descendant(of: outgoing, matching: find.byType(Text)),
      )) {
        final color = text.style?.color;
        if (color != null) expect(color, LoopColors.ink);
      }
      final preview = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.descendant(of: outgoing, matching: find.text('历史 3')),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(preview.style.color, LoopColors.ink);

      // The incoming bubble keeps Stream's own card on the global theme.
      expect(find.byType(DefaultStreamQuotedMessage), findsOneWidget);
      await room.dispose(tester);
    });
  });

  group('3 · pinning is the owner\'s and the admins\'', () {
    test('only owner and admin may pin; no membership may not', () {
      expect(testViewer(role: CommunityRole.owner).mayPinMessages, isTrue);
      expect(testViewer(role: CommunityRole.admin).mayPinMessages, isTrue);
      expect(testViewer(role: CommunityRole.member).mayPinMessages, isFalse);
      expect(testViewer(role: null).mayPinMessages, isFalse);
    });

    testWidgets('a member sees no pin action', (tester) async {
      final room = _Room();
      await room.pump(tester, mayPin: false);
      await room.openActions(tester, '历史 2');
      expect(find.text('回复'), findsOneWidget);
      expect(find.text('置顶到会话'), findsNothing);
      expect(find.text('取消置顶'), findsNothing);
      await room.dispose(tester);
    });

    testWidgets('an owner or admin keeps it', (tester) async {
      final room = _Room();
      await room.pump(tester, mayPin: true);
      await room.openActions(tester, '历史 2');
      expect(find.text('置顶到会话'), findsOneWidget);
      await room.dispose(tester);
    });

    test('the filter only removes, and removes both directions', () {
      final message = Message(id: 'm');
      final actions = <StreamContextMenuAction<MessageAction>>[
        StreamContextMenuAction(
          value: QuotedReply(message: message),
          label: const Text('回复'),
        ),
        StreamContextMenuAction(
          value: PinMessage(message: message),
          label: const Text('置顶到会话'),
        ),
        StreamContextMenuAction(
          value: UnpinMessage(message: message),
          label: const Text('取消置顶'),
        ),
      ];
      final kept = loopWithoutPinActions(actions);
      expect(kept, hasLength(1));
      expect(kept.single.props.value, isA<QuotedReply>());
    });
  });

  group('4 · sharing a voice room', () {
    test('the share text and link', () {
      final link = voiceRoomShareLink(
        'https://api-dev.quant-dinger.cc',
        'd17b34a6-c3cc-4a24-87dd-dc165c80bd85',
      );
      expect(
        link,
        'https://api-dev.quant-dinger.cc/c/d17b34a6-c3cc-4a24-87dd-dc165c80bd85/room',
      );
      expect(
        voiceRoomShareText(
          communityName: 'DeFi 早读会',
          roomTitle: voiceRoomTitle('DeFi 早读会'),
          link: link,
        ),
        '来 LOOP 的『DeFi 早读会』语音房：DeFi 早读会 语音房\n$link',
      );
      expect(voiceRoomShareLink('', 'x'), isNull);
    });

    test('the link path names the community and nothing else', () {
      expect(communityIdFromRoomLinkPath('/c/abc-123/room'), 'abc-123');
      expect(communityIdFromRoomLinkPath('/c/abc-123/room/'), 'abc-123');
      expect(communityIdFromRoomLinkPath('/c/abc/room/x'), isNull);
      expect(communityIdFromRoomLinkPath('/c//room'), isNull);
      expect(communityIdFromRoomLinkPath('/u/LOOP-FE3EMCPE'), isNull);
      expect(
        voiceRoomLinkLocation('abc-123'),
        '/community/profile?id=abc-123&room=live',
      );
    });

    group('the /c/{id}/room link', () {
      Future<void> pumpApp(WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: <Override>[
              privyAuthGatewayProvider.overrideWithValue(
                const UnconfiguredPrivyAuthGateway(),
              ),
              developmentPreviewEnabledProvider.overrideWithValue(true),
            ],
            child: const LoopApp(),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> enterPreview(WidgetTester tester) async {
        final button = find.byKey(
          const ValueKey<String>('enter-development-preview-button'),
        );
        await tester.ensureVisible(button);
        await tester.pump();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      Future<void> pushRoute(WidgetTester tester, String location) async {
        final message = const JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', <String, Object?>{
            'location': location,
            'state': null,
          }),
        );
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          SystemChannels.navigation.name,
          message,
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      void expectRecordFor(WidgetTester tester, String communityId) {
        final screen = tester.widget<CommunityProfileScreen>(
          find.byType(CommunityProfileScreen),
        );
        expect(screen.communityId, communityId);
        expect(screen.openLiveRoomOnArrival, isTrue);
      }

      testWidgets('opens the community record asked to open its room', (
        tester,
      ) async {
        await pumpApp(tester);
        await enterPreview(tester);
        await pushRoute(tester, '/c/community-alpha/room');
        expectRecordFor(tester, 'community-alpha');
      });

      testWidgets('before sign-in it is held until the account lands', (
        tester,
      ) async {
        await pumpApp(tester);
        await pushRoute(tester, '/c/community-alpha/room');
        expect(find.byType(CommunityProfileScreen), findsNothing);
        await enterPreview(tester);
        expectRecordFor(tester, 'community-alpha');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('community-screen')),
          findsOneWidget,
        );
      });

      testWidgets('a malformed one is an unknown route', (tester) async {
        await pumpApp(tester);
        await enterPreview(tester);
        await pushRoute(tester, '/c/community-alpha/room/extra');
        expect(find.byType(CommunityProfileScreen), findsNothing);
        expect(
          find.byKey(const ValueKey<String>('community-screen')),
          findsOneWidget,
        );
      });
    });

    testWidgets('the room page shares a live room', (tester) async {
      final shared = <String>[];
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot()),
        overrides: <Override>[
          loopIdLinkBaseUrlProvider.overrideWithValue(
            'https://api-staging.quant-dinger.cc',
          ),
          loopTextShareProvider.overrideWithValue((text, {subject}) async {
            shared.add(text);
            return true;
          }),
        ],
      );
      final button = find.byKey(const ValueKey<String>('voiceroom-share'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(shared, <String>[
        '来 LOOP 的『$testVoiceRoomCommunityName』语音房：'
            '$testVoiceRoomCommunityName 语音房\n'
            'https://api-staging.quant-dinger.cc/c/$testCommunityId/room',
      ]);
    });

    testWidgets('an ended room offers no share', (tester) async {
      await pumpCommunityPage(
        tester,
        const VoiceRoomScreen(communityId: testCommunityId),
        voiceRoom: FakeVoiceRoomGateway(
          snapshot: testVoiceRoomSnapshot(state: VoiceRoomState.ended),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('voiceroom-share')),
        findsNothing,
      );
    });

    testWidgets('a link to a live room opens it over the record', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpCommunityPage(
        tester,
        CommunityProfileScreen(
          communityId: testCommunityId,
          openLiveRoomOnArrival: true,
          onOpenVoiceRoom: opened.add,
        ),
        community: FakeCommunityGateway(
          detail: testDetail(
            viewer: testViewer(role: CommunityRole.member),
            voice: testVoiceLive,
          ),
        ),
        voiceRoom: FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot()),
      );
      expect(opened, <String>[testCommunityId]);
      expect(find.text('语音房已结束'), findsNothing);
    });

    testWidgets('a link to a room that ended says so on the record', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpCommunityPage(
        tester,
        CommunityProfileScreen(
          communityId: testCommunityId,
          openLiveRoomOnArrival: true,
          onOpenVoiceRoom: opened.add,
        ),
        community: FakeCommunityGateway(
          detail: testDetail(viewer: testViewer(role: CommunityRole.member)),
        ),
        voiceRoom: FakeVoiceRoomGateway(),
      );
      expect(opened, isEmpty);
      expect(find.text('语音房已结束'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('community-profile-screen')),
        findsOneWidget,
      );
    });

    testWidgets('an ordinary visit never opens the room by itself', (
      tester,
    ) async {
      final opened = <String>[];
      await pumpCommunityPage(
        tester,
        CommunityProfileScreen(
          communityId: testCommunityId,
          onOpenVoiceRoom: opened.add,
        ),
        community: FakeCommunityGateway(
          detail: testDetail(voice: testVoiceLive),
        ),
        voiceRoom: FakeVoiceRoomGateway(snapshot: testVoiceRoomSnapshot()),
      );
      expect(opened, isEmpty);
    });
  });

  group('5 · switching a notification category off asks first', () {
    Finder row(String wire) =>
        find.byKey(ValueKey<String>('notification-category-$wire'));

    testWidgets('turning off opens the sheet; 取消 changes nothing', (
      tester,
    ) async {
      final notifications = FakeNotificationsGateway();
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: notifications,
      );
      await scrollToS5Section(tester, row('mining.weight'));
      await tester.tap(row('mining.weight'));
      await tester.pumpAndSettle();

      expect(find.text('关闭『权重变化』通知？'), findsOneWidget);
      expect(find.text('持有币的 Mining Weight 调整时'), findsWidgets);
      expect(find.text('关闭'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(notifications.written, isEmpty);
      expect(
        find.descendant(of: row('mining.weight'), matching: find.text('已开启')),
        findsOneWidget,
      );
    });

    testWidgets('关闭 writes false under the version', (tester) async {
      final notifications = FakeNotificationsGateway();
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: notifications,
      );
      await scrollToS5Section(tester, row('mining.weight'));
      await tester.tap(row('mining.weight'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      expect(
        notifications.written.single[LoopNotificationCategory.miningWeight],
        isFalse,
      );
      expect(
        notifications.written.single[LoopNotificationCategory.securityEvent],
        isTrue,
      );
    });

    testWidgets('turning on needs no confirmation', (tester) async {
      // community.all is the one category the fixture has off.
      final notifications = FakeNotificationsGateway();
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: notifications,
      );
      await scrollToS5Section(tester, row('community.all'));
      await tester.tap(row('community.all'));
      await tester.pumpAndSettle();

      expect(find.textContaining('通知？'), findsNothing);
      expect(
        notifications.written.single[LoopNotificationCategory.communityAll],
        isTrue,
      );
    });

    testWidgets('安全事件 stays locked', (tester) async {
      await pumpS5Page(
        tester,
        const NotificationPreferencesScreen(),
        notifications: FakeNotificationsGateway(),
      );
      await scrollToS5Section(tester, row('security.event'));
      expect(tester.widget<LoopRecordRow>(row('security.event')).onTap, isNull);
    });

    testWidgets('with reduced motion the sheet appears in one frame', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const NotificationPreferencesScreen(),
        ),
        notifications: FakeNotificationsGateway(),
      );
      await scrollToS5Section(tester, row('mining.weight'));
      await tester.tap(row('mining.weight'));
      // Two frames and no time: an animated sheet would still be sliding in
      // below the screen, a reduced-motion one is already in place.
      await tester.pump();
      await tester.pump();
      final title = find.text('关闭『权重变化』通知？');
      expect(title, findsOneWidget);
      final sheet = tester.getRect(
        find.byKey(const ValueKey<String>('loop-sheet')),
      );
      expect(sheet.bottom, closeTo(tester.view.physicalSize.height, 1));
    });

    test('titles and bodies come from the category', () {
      expect(
        notificationDisableTitle(LoopNotificationCategory.communityAll),
        '关闭『全部消息』通知？',
      );
      expect(
        notificationDisableBody(LoopNotificationCategory.communityAll),
        '大群建议关闭',
      );
      expect(
        notificationDisableBody(LoopNotificationCategory.launchRound),
        '关闭后不会再收到这一类通知。',
      );
    });
  });

  group('6 · unread counts', () {
    test('mapping: none, zero, a count, 99+', () {
      expect(loopUnreadBadgeLabel(null), isNull);
      expect(loopUnreadBadgeLabel(0), isNull);
      expect(loopUnreadBadgeLabel(-1), isNull);
      expect(loopUnreadBadgeLabel(7), '7');
      expect(loopUnreadBadgeLabel(99), '99');
      expect(loopUnreadBadgeLabel(100), '99+');
    });

    test('the total is Stream\'s own while connected, and nothing '
        'otherwise', () async {
      final status = StreamController<ConnectionStatus>();
      final total = StreamController<int>();
      final seen = <int?>[];
      final sub = loopStreamUnreadTotal(
        initialStatus: ConnectionStatus.disconnected,
        status: status.stream,
        initialTotal: 3,
        total: total.stream,
      ).listen(seen.add);
      await pumpEventQueue();
      expect(seen, <int?>[null], reason: 'not connected: no count');

      status.add(ConnectionStatus.connected);
      await pumpEventQueue();
      total.add(120);
      await pumpEventQueue();
      // Read to the bottom: Stream's own markRead brings it to zero.
      total.add(0);
      await pumpEventQueue();
      status.add(ConnectionStatus.connecting);
      await pumpEventQueue();
      expect(seen, <int?>[null, 3, 120, 0, null]);
      expect(seen.map(loopUnreadBadgeLabel).toList(), <String?>[
        null,
        '3',
        '99+',
        null,
        null,
      ]);
      await sub.cancel();
      await status.close();
      await total.close();
    });

    test('no chat session is no count', () async {
      final container = ProviderContainer(
        overrides: <Override>[
          streamChatSdkSessionProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(streamChatUnreadTotalProvider, (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();
      final value = container.read(streamChatUnreadTotalProvider);
      expect(value.hasValue, isTrue);
      expect(value.value, isNull);
    });

    testWidgets('the message tool draws a 16 dp pill, and nothing for none', (
      tester,
    ) async {
      Future<void> pump(int? count) => tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Center(
              child: CommunityToolButton(
                icon: 'bell',
                label: '打开消息面板',
                unreadCount: count,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await pump(150);
      expect(find.text('99+'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('loop-unread-pill')))
            .height,
        LoopUnreadBadge.pillHeight,
      );
      final pill = tester.widget<Container>(
        find.byKey(const ValueKey<String>('loop-unread-pill')),
      );
      expect((pill.decoration! as BoxDecoration).color, LoopColors.danger);
      expect(find.bySemanticsLabel('打开消息面板，99+ 条未读'), findsOneWidget);

      await pump(0);
      expect(
        find.byKey(const ValueKey<String>('loop-unread-pill')),
        findsNothing,
      );
      await pump(null);
      expect(
        find.byKey(const ValueKey<String>('community-unread-badge')),
        findsNothing,
      );
    });

    testWidgets('the dot is 8 dp', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: LoopUnreadBadge(count: 3, dot: true)),
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey<String>('loop-unread-dot'))),
        const Size(8, 8),
      );
    });

    testWidgets('an inbox row carries its own count beside the time', (
      tester,
    ) async {
      final room = _Room(unread: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: StreamChat(
            client: room.client,
            child: Scaffold(
              body: Builder(
                builder: (context) => loopStreamChannelListTrailing(
                  loopStreamChannelListTimestamp(room.channel),
                  room.channel.state!.unreadCount,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('24'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: StreamChat(
            client: room.client,
            child: Scaffold(
              body: loopStreamChannelListTrailing(
                loopStreamChannelListTimestamp(room.channel),
                0,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('loop-channel-unread-badge')),
        findsNothing,
      );
      await room.dispose(tester);
    });
  });
}
