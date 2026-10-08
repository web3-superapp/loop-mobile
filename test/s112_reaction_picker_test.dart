// S112 · the long-press reaction bar carries LOOP's five words and no 「+」
// (decision 0117). Stream's default bar pins a 「+」 that opens the Emoji
// catalogue filtered by `supportedReactions`; LOOP's resolver supports none,
// so the 「+」 opened an empty sheet and is not drawn.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart' show loopStreamChatConfiguration;
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/integrations/communication/loop_stream_reaction_icon_resolver.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_connection.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

const String _cid = 'messaging:loop_group_5e1f0f2e5a7b4c3d8e9f0a1b2c3d4e5f';
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

/// One group of three messages in which the member may react.
final class _Group {
  _Group() {
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
            'send-reaction',
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
                10,
                8,
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
    required StreamChatConfigurationData config,
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
          configData: config,
          // The application's own builder (`lib/app.dart`).
          componentBuilders: StreamComponentBuilders(
            messageText: loopStreamMessageTextBuilder,
            reactionPicker: loopStreamReactionPickerBuilder,
            extensions: streamChatComponentBuilders(
              messageItem: loopStreamGroupMessageItemBuilder,
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
  group('the long-press reaction bar', () {
    testWidgets('carries the five words and no 「+」', (tester) async {
      final room = _Group();
      await room.pump(tester, config: loopStreamChatConfiguration);
      await room.openActions(tester, '消息 2');

      expect(find.text('回复'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-reaction-bar')),
        findsOneWidget,
      );
      for (final word in <String>['赞', '哈', '心', '哇', '叹']) {
        expect(find.text(word), findsOneWidget, reason: word);
      }
      expect(find.byKey(const Key('add_reaction')), findsNothing);
      expect(find.byType(DefaultStreamReactionPicker), findsNothing);
      for (final type in <String>['like', 'haha', 'love', 'wow', 'sad']) {
        expect(
          tester.getSize(find.byKey(Key(type))).height,
          greaterThanOrEqualTo(44),
          reason: type,
        );
      }
      await room.dispose(tester);
    });

    testWidgets('a resolver that supports more keeps Stream\'s 「+」', (
      tester,
    ) async {
      // The control: the same page under Stream's default resolver shows the
      // 「+」, so the assertion above is looking at the real bar.
      final room = _Group();
      await room.pump(tester, config: StreamChatConfigurationData());
      await room.openActions(tester, '消息 2');

      expect(find.byKey(const Key('add_reaction')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-reaction-bar')),
        findsNothing,
      );
      await room.dispose(tester);
    });
  });

  test('the application installs the builder', () {
    expect(
      File('lib/app.dart').readAsStringSync(),
      contains('reactionPicker: loopStreamReactionPickerBuilder,'),
    );
  });
}
