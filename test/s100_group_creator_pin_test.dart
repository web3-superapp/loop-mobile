// S99c · a friend group's creator may pin (decision 0105 addendum).
//
// loop-api 0091 makes a friend group's creator its Stream
// `channel_moderator`; no other member may pin, and nobody pins in a direct
// conversation. The long-press sheet follows: the group screen decides from
// the loaded channel's `created_by`, the direct screen always removes pin.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/loop_channel_message_policy.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_connection.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

const String _cid = 'messaging:loop_group_9c1f0f2e5a7b4c3d8e9f0a1b2c3d4e5f';
const String _me = 'me';

class _Connected implements LoopStreamConnection {
  @override
  bool get isConnected => true;
  @override
  Future<void> open() async {}
}

class _LocalClient extends StreamChatClient {
  _LocalClient() : super('key', logLevel: Level.OFF);

  @override
  Future<EmptyResponse> markChannelRead(
    String channelId,
    String channelType, {
    String? messageId,
  }) async => EmptyResponse();
}

/// One friend group of three messages, created by [creator]. Stream grants
/// `pin-message` here: the client rule alone decides what the sheet offers.
final class _Group {
  _Group({required String? creator}) {
    // ignore: invalid_use_of_internal_member
    client.state.currentUser = OwnUser(id: _me, name: '我');
    channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: _cid.split(':').last,
          type: 'messaging',
          createdBy: creator == null ? null : User(id: creator),
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
        messages: <Message>[
          for (var i = 3; i >= 1; i--)
            Message(
              id: 'm$i',
              text: '消息 $i',
              user: User(id: i.isEven ? _me : 'other', name: '成员'),
              createdAt: DateTime.utc(
                2026,
                9,
                29,
                12,
              ).subtract(Duration(minutes: i)),
              state: MessageState.sent,
            ),
        ],
      ),
    );
  }

  final _LocalClient client = _LocalClient();
  late final Channel channel;

  Future<void> pump(
    WidgetTester tester, {
    bool? mayPin,
    bool Function(Channel channel, String userId)? mayPinFor,
  }) async {
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
        theme: LoopTheme.dark.copyWith(
          extensions: [...LoopTheme.dark.extensions.values, loopStreamTheme()],
        ),
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          LoopStreamChatLocalizationsDelegate(),
        ],
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
          body: LoopStreamMemberChannelBody(
            client: client,
            cid: _cid,
            userId: _me,
            composerHint: loopChatComposerHint,
            unresolvedMessage: null,
            header: null,
            banner: null,
            footer: null,
            keyPrefix: 'group-channel',
            connection: _Connected(),
            query: () async => <Channel>[channel],
            mayPinMessages: mayPin,
            mayPinMessagesFor: mayPinFor,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openActions(WidgetTester tester, String text) async {
    await tester.longPressAt(
      tester.getRect(find.text(text)).centerLeft - const Offset(8, 0),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    channel.dispose();
  }
}

void main() {
  group('the creator rule', () {
    Channel group(String? creator) => _Group(creator: creator).channel;

    test('the creator may pin', () {
      expect(loopFriendGroupCreatorMayPin(group(_me), _me), isTrue);
    });

    test('another member may not', () {
      expect(loopFriendGroupCreatorMayPin(group('someone'), _me), isFalse);
    });

    test('an unknown creator pins nothing', () {
      expect(loopFriendGroupCreatorMayPin(group(null), _me), isFalse);
      expect(loopFriendGroupCreatorMayPin(group(''), ''), isFalse);
    });
  });

  group('the long-press sheet', () {
    testWidgets('the group creator sees 置顶到会话', (tester) async {
      final room = _Group(creator: _me);
      await room.pump(tester, mayPinFor: loopFriendGroupCreatorMayPin);
      await room.openActions(tester, '消息 2');
      expect(find.text('回复'), findsOneWidget);
      expect(find.text('置顶到会话'), findsOneWidget);
      await room.dispose(tester);
    });

    testWidgets('an ordinary group member does not', (tester) async {
      final room = _Group(creator: 'someone');
      await room.pump(tester, mayPinFor: loopFriendGroupCreatorMayPin);
      await room.openActions(tester, '消息 2');
      expect(find.text('回复'), findsOneWidget);
      expect(find.text('置顶到会话'), findsNothing);
      expect(find.text('取消置顶'), findsNothing);
      await room.dispose(tester);
    });

    testWidgets('a group whose creator is unknown does not', (tester) async {
      final room = _Group(creator: null);
      await room.pump(tester, mayPinFor: loopFriendGroupCreatorMayPin);
      await room.openActions(tester, '消息 2');
      expect(find.text('置顶到会话'), findsNothing);
      await room.dispose(tester);
    });

    testWidgets('a direct conversation does not, even for its creator', (
      tester,
    ) async {
      // The direct screen passes `mayPinMessages: false`.
      final room = _Group(creator: _me);
      await room.pump(tester, mayPin: false);
      await room.openActions(tester, '消息 2');
      expect(find.text('回复'), findsOneWidget);
      expect(find.text('置顶到会话'), findsNothing);
      await room.dispose(tester);
    });

    testWidgets('an explicit decision wins over the channel rule', (
      tester,
    ) async {
      // Community groups pass `mayPinMessages` from the member's role.
      final room = _Group(creator: _me);
      await room.pump(
        tester,
        mayPin: false,
        mayPinFor: loopFriendGroupCreatorMayPin,
      );
      await room.openActions(tester, '消息 2');
      expect(find.text('置顶到会话'), findsNothing);
      await room.dispose(tester);
    });
  });

  group('each screen states its rule', () {
    String source(String path) => File(path).readAsStringSync();

    test('the group screen asks the creator rule', () {
      expect(
        source('lib/features/chat/v2/group_screens.dart'),
        contains('mayPinMessagesFor: loopFriendGroupCreatorMayPin'),
      );
    });

    test('the direct screen removes pin', () {
      expect(
        source('lib/features/chat/v2/direct_message_screen.dart'),
        contains('mayPinMessages: false'),
      );
    });

    test('the community screen keeps the role rule', () {
      expect(
        source('lib/features/chat/v2/community_chat_screen.dart'),
        contains('mayPinMessages: detail.viewer.mayPinMessages'),
      );
    });
  });
}
