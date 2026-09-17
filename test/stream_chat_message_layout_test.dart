// The message row, against the frozen prototype (`#scr-group`, `#scr-
// community-chat`).
//
// `.msg{display:flex;gap:10px}` puts the avatar in its own column, top of the
// row; `.msg-body` stacks `.msg-who` (sender name) above `.msg-txt` (the
// bubble); `.msg-txt` is plain text at `line-height:1.55`. C-15 recorded all
// three read the other way on the device: markdown-inflated line spacing, the
// name under the bubble, the avatar on the bubble's floor.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

void main() {
  group('C-15 (1) a message is plain text, not markdown', () {
    test('the pipe, the asterisk and the underscore survive', () {
      expect(loopStreamPlainMessageText('| 模拟器 | 两个实例 |'), '| 模拟器 | 两个实例 |');
      expect(loopStreamPlainMessageText('*重点* _斜_ #1'), '*重点* _斜_ #1');
    });

    test("Stream's paragraph inflation is reversed", () {
      // `StreamMessageText` sends `text.replaceAll('\n', '\n\n')` down.
      expect(loopStreamPlainMessageText('一\n\n二'), '一\n二');
      expect(loopStreamPlainMessageText('一\n\n\n\n二'), '一\n\n二');
      expect(loopStreamPlainMessageText('一 二'), '一 二');
    });

    test('a mention reads as the name, never as its markdown link', () {
      expect(
        loopStreamPlainMessageText('你好 [@voyager](mention:user-7) 在吗'),
        '你好 @voyager 在吗',
      );
      expect(
        loopStreamPlainMessageText('[@channel](mention-channel:channel) 上线'),
        '@channel 上线',
      );
    });

    testWidgets('the bubble prints the literal text on band 4', (tester) async {
      final harness = _ChannelHarness.group(messageText: '| 模拟器 |\nuuu');
      await _pumpMessage(tester, harness: harness);

      final text = tester.widget<Text>(find.text('| 模拟器 |\nuuu'));
      expect(text.style!.fontSize, 14);
      // Band 4 · body. The prototype's `.msg-txt` is `line-height:1.55`.
      expect(text.style!.height, 1.55);
      expect(text.style!.color, LoopColors.chalk);

      await _disposeHarness(tester, harness);
    });

    testWidgets('two lines sit one body line apart, with no paragraph gap', (
      tester,
    ) async {
      final harness = _ChannelHarness.group(messageText: '一行\n二行');
      await _pumpMessage(tester, harness: harness);

      final box = tester.renderObject<RenderBox>(find.text('一行\n二行'));
      // 2 × 14 × 1.55 = 43.4. A markdown-split message adds the style sheet's
      // 8px block spacing on top of it.
      expect(box.size.height, closeTo(2 * 14 * 1.55, 1));

      await _disposeHarness(tester, harness);
    });
  });

  group('C-15 (2) the sender name sits above the bubble', () {
    testWidgets('the name is the first line of the message column', (
      tester,
    ) async {
      final harness = _ChannelHarness.group(messageText: '在跟，单地址上限 0.5%');
      await _pumpMessage(tester, harness: harness);

      // The group Alias, not the Stream account name.
      final name = find.text('星航员');
      expect(name, findsOneWidget);

      final bubble = find.byType(StreamMessageBubble);
      expect(
        tester.getBottomLeft(name).dy,
        lessThanOrEqualTo(tester.getTopLeft(bubble).dy),
      );
      // …and the metadata row under the bubble keeps the clock and the read
      // receipt, and no longer repeats the name.
      final metadata = find.byType(StreamMessageMetadata);
      expect(
        tester.getTopLeft(metadata).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(bubble).dy),
      );
      expect(
        find.descendant(of: metadata, matching: find.text('星航员')),
        findsNothing,
      );
      // The name shares the bubble's left edge; it is not a centred caption.
      expect(
        tester.getTopLeft(name).dx,
        closeTo(tester.getTopLeft(bubble).dx, 1),
      );

      await _disposeHarness(tester, harness);
    });

    testWidgets('the name carries the metadata username tokens', (
      tester,
    ) async {
      final harness = _ChannelHarness.group(messageText: 'gm');
      await _pumpMessage(tester, harness: harness);

      final style = tester.widget<Text>(find.text('星航员')).style!;
      expect(style.fontSize, 11);
      expect(style.color, LoopColors.text3);

      await _disposeHarness(tester, harness);
    });
  });
}

Future<void> _disposeHarness(
  WidgetTester tester,
  _ChannelHarness harness,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  harness.dispose();
}

Future<void> _pumpMessage(
  WidgetTester tester, {
  required _ChannelHarness harness,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        extensions: <ThemeExtension<dynamic>>[loopStreamTheme()],
      ),
      home: StreamChat(
        client: harness.client,
        themeData: loopStreamChatThemeData(),
        componentBuilders: loopStreamComponentBuildersForTest(),
        child: StreamChannel.value(
          channel: harness.channel,
          child: Scaffold(
            body: StreamMessageLayout(
              data: const StreamMessageLayoutData(),
              child: StreamMessageItem(message: harness.message),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The builder set `lib/app.dart` installs, restated for a single row.
StreamComponentBuilders loopStreamComponentBuildersForTest() =>
    StreamComponentBuilders(
      messageText: loopStreamMessageTextBuilder,
      extensions: streamChatComponentBuilders(
        messageItem: loopStreamGroupMessageItemBuilder,
        mentionItem: loopStreamGroupMentionItemBuilder,
        messageFooter: loopStreamMessageFooterBuilder,
        messageHeader: loopStreamMessageHeaderBuilder,
      ),
    );

const String _senderId = 'stream-sender';

final class _ChannelHarness {
  _ChannelHarness._({
    required this.client,
    required this.channel,
    required this.message,
  });

  factory _ChannelHarness.group({required String messageText}) {
    final client = StreamChatClient(
      'public-stream-api-key',
      logLevel: Level.OFF,
    );
    final user = User(id: _senderId, name: 'voyager');
    final message = Message(
      id: 'message-1',
      text: messageText,
      user: user,
      createdAt: DateTime.utc(2026, 9, 16, 12),
      state: MessageState.sent,
    );
    final channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: 'loop_group_8e7d73c5',
          type: 'messaging',
          memberCount: 2,
        ),
        members: <Member>[
          Member(
            userId: _senderId,
            user: user,
            extraData: const <String, Object?>{
              'loop_group_alias_id': 'bb5e12c2-40e2-4577-9951-57fac0b5ce5e',
              'loop_group_alias': '星航员',
              'loop_group_alias_version': 1,
            },
          ),
        ],
        messages: <Message>[message],
      ),
    );
    return _ChannelHarness._(
      client: client,
      channel: channel,
      message: message,
    );
  }

  final StreamChatClient client;
  final Channel channel;
  final Message message;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    channel.dispose();
  }
}
