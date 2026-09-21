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
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/loop_ground_probe.dart';

void main() {
  // `stream_chat_appearance.dart` is a probe blind spot in
  // `ground-inventory.md`: the Stream widgets it themes are mounted by the
  // SDK, not by a LOOP page, so no page test ever walked their paint. This
  // file mounts a real message row, so it can carry the watch.
  loopWatchGround();

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

  group('C-15 (3) the avatar stands at the top of the row', () {
    testWidgets('the avatar is level with the name, above the bubble', (
      tester,
    ) async {
      final harness = _ChannelHarness.group(
        messageText: '在跟，但单地址上限 0.5%，扫不了货，等下一轮',
      );
      await _pumpMessage(tester, harness: harness);

      final avatar = find.byKey(LoopStreamMessageRow.avatarKey);
      expect(avatar, findsOneWidget);

      final name = find.text('星航员');
      final bubble = find.byType(StreamMessageBubble);
      // `.msg-av` has no vertical offset of its own: it starts where the
      // message column starts, which is the name's line.
      expect(
        tester.getTopLeft(avatar).dy,
        closeTo(tester.getTopLeft(name).dy, 2),
      );
      expect(
        tester.getTopLeft(avatar).dy,
        lessThan(tester.getTopLeft(bubble).dy),
      );
      // …and not on the bubble's floor, which is where Stream's hardcoded
      // `crossAxisAlignment: .end` put it.
      expect(
        tester.getBottomLeft(avatar).dy,
        lessThan(tester.getBottomLeft(bubble).dy),
      );
      // The avatar stands in its own column, clear of the bubble.
      expect(
        tester.getTopRight(avatar).dx,
        lessThanOrEqualTo(tester.getTopLeft(bubble).dx),
      );

      await _disposeHarness(tester, harness);
    });

    testWidgets('the row keeps the prototype gutter, once', (tester) async {
      final harness = _ChannelHarness.group(messageText: 'gm');
      await _pumpMessage(tester, harness: harness);

      // 16px page inset, then the reserved avatar column.
      final avatar = find.byKey(LoopStreamMessageRow.avatarKey);
      expect(tester.getTopLeft(avatar).dx, LoopSpacing.page);
      expect(tester.getTopLeft(avatar).dy, LoopSpacing.tight);

      // Stream's own leading is reserved, not drawn twice: the gutter it holds
      // open is exactly as wide as the avatar LOOP paints into it.
      final gutter = find.byType(StreamMessageLeading);
      expect(gutter, findsNWidgets(2));
      expect(
        tester.getSize(gutter.at(0)).width,
        tester.getSize(gutter.at(1)).width,
      );

      await _disposeHarness(tester, harness);
    });

    testWidgets('an item that overrides the padding keeps its avatar on it', (
      tester,
    ) async {
      // The long-press preview rebuilds the row with `padding: EdgeInsets.zero`
      // over the scrim.
      final harness = _ChannelHarness.group(messageText: 'gm');
      await _pumpMessage(tester, harness: harness, padding: EdgeInsets.zero);

      final avatar = find.byKey(LoopStreamMessageRow.avatarKey);
      expect(tester.getTopLeft(avatar), Offset.zero);

      await _disposeHarness(tester, harness);
    });

    testWidgets('the incoming tile draws the Alias, not a provider avatar', (
      tester,
    ) async {
      final harness = _ChannelHarness.group(messageText: 'gm');
      await _pumpMessage(tester, harness: harness);

      // The painted one, in the gutter LOOP reserved. (Stream's own leading
      // holds the same tile open, unpainted, to keep the column's width.)
      final tile = find.descendant(
        of: find.byKey(LoopStreamMessageRow.avatarKey),
        matching: find.byType(LoopInitialsAvatar),
      );
      expect(tile, findsOneWidget);
      expect(tester.widget<LoopInitialsAvatar>(tile).label, '星航员');

      await _disposeHarness(tester, harness);
    });
  });

  // Device report 2026-09-21: a circled 「成员」 stood beside every message the
  // member had sent themself, across the row from their own bubble. LOOP
  // publishes no name for an account into a room, so the own tile resolved
  // the neutral label and drew it; and the gutter it was painted into is the
  // one on the row's start side, while an own row reserves its own on the
  // end. The own message is its bubble, and nothing else.
  group('S65 the reader\'s own message is a bubble alone', () {
    testWidgets('no avatar, no reserved gutter, no name', (tester) async {
      final harness = _ChannelHarness.group(
        messageText: '刚买了，算力涨到 4,347 了',
        ownMessage: true,
      );
      await _pumpMessage(
        tester,
        harness: harness,
        layout: const StreamMessageLayoutData(
          alignment: StreamMessageAlignment.end,
        ),
      );

      // Neither LOOP's tile nor Stream's own leading is in the row: the
      // column is `gone`, not merely empty.
      expect(find.byKey(LoopStreamMessageRow.avatarKey), findsNothing);
      expect(find.byType(StreamMessageLeading), findsNothing);
      expect(find.byType(LoopInitialsAvatar), findsNothing);
      // The monogram the device drew, and the label it came from.
      expect(find.text(loopGroupMemberNeutralLabel), findsNothing);

      await _disposeHarness(tester, harness);
    });

    testWidgets('the bubble is Lime, Ink text, against the end margin', (
      tester,
    ) async {
      final harness = _ChannelHarness.group(
        messageText: 'gm',
        ownMessage: true,
      );
      await _pumpMessage(
        tester,
        harness: harness,
        layout: const StreamMessageLayoutData(
          alignment: StreamMessageAlignment.end,
        ),
      );

      final bubble = find.byType(StreamMessageBubble);
      final pageWidth = tester.getSize(find.byType(Scaffold)).width;
      // `.msg{padding:8px 16px}` — and no avatar column between the bubble
      // and that inset.
      expect(
        tester.getTopRight(bubble).dx,
        closeTo(pageWidth - LoopSpacing.page, 1),
      );
      expect(tester.widget<Text>(find.text('gm')).style!.color, LoopColors.ink);

      await _disposeHarness(tester, harness);
    });

    // `#scr-dm` is the same markup: the peer keeps a column, the reader does
    // not, and neither bubble is captioned with a name.
    testWidgets('a direct conversation answers the same way', (tester) async {
      final own = _ChannelHarness.direct(
        messageText: '好，我先小仓试试',
        ownMessage: true,
      );
      await _pumpMessage(
        tester,
        harness: own,
        layout: const StreamMessageLayoutData(
          alignment: StreamMessageAlignment.end,
        ),
      );
      expect(find.byKey(LoopStreamMessageRow.avatarKey), findsNothing);
      expect(find.byType(StreamMessageLeading), findsNothing);
      await _disposeHarness(tester, own);

      final peer = _ChannelHarness.direct(messageText: '那个 CA 我查过了');
      await _pumpMessage(tester, harness: peer);
      expect(find.byKey(LoopStreamMessageRow.avatarKey), findsOneWidget);
      // The peer is named once, in the page header above the conversation:
      // no name is drawn over the bubble here.
      expect(find.text('NightOwl'), findsNothing);
      await _disposeHarness(tester, peer);
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
  StreamMessageLayoutData layout = const StreamMessageLayoutData(),
  EdgeInsetsGeometry? padding,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // The ground the chat page actually stands on: `LoopTheme.dark` with the
      // Stream extension injected above it, exactly as `lib/app.dart` does.
      theme: LoopTheme.dark.copyWith(
        extensions: [
          ...LoopTheme.dark.extensions.values,
          loopStreamTheme(platform: LoopTheme.dark.platform),
        ],
      ),
      home: StreamChat(
        client: harness.client,
        themeData: loopStreamChatThemeData(),
        componentBuilders: loopStreamComponentBuildersForTest(),
        child: StreamChannel.value(
          channel: harness.channel,
          child: Scaffold(
            // The official list gives every row its intrinsic height; a
            // stretched box would let Stream's own `Align` centre the row.
            body: SingleChildScrollView(
              child: StreamMessageLayout(
                data: layout,
                child: StreamMessageItem(
                  message: harness.message,
                  padding: padding,
                ),
              ),
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
        // As `lib/app.dart` registers it: the gutter is drawn from the label
        // LOOP resolved, never from Stream's id-keyed gradient (S58c).
        messageLeading: loopStreamMessageLeadingBuilder,
        mentionItem: loopStreamGroupMentionItemBuilder,
        messageFooter: loopStreamMessageFooterBuilder,
        messageHeader: loopStreamMessageHeaderBuilder,
      ),
    );

const String _senderId = 'stream-sender';
const String _readerId = 'stream-reader';

final class _ChannelHarness {
  _ChannelHarness._({
    required this.client,
    required this.channel,
    required this.message,
  });

  /// A community / group room.
  ///
  /// `ownMessage: true` is the device's own case: the message is the reader's
  /// and their member row carries no Alias projection, so every LOOP label
  /// for them resolves to 「成员」.
  factory _ChannelHarness.group({
    required String messageText,
    bool ownMessage = false,
  }) {
    final client = _client();
    final user = ownMessage
        ? User(id: _readerId, name: 'reader')
        : User(id: _senderId, name: 'voyager');
    final message = _message(messageText, user);
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
            user: User(id: _senderId, name: 'voyager'),
            extraData: const <String, Object?>{
              'loop_group_alias_id': 'bb5e12c2-40e2-4577-9951-57fac0b5ce5e',
              'loop_group_alias': '星航员',
              'loop_group_alias_version': 1,
            },
          ),
          Member(
            userId: _readerId,
            user: User(id: _readerId, name: 'reader'),
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

  /// A 1:1 conversation — `loop_direct_…`, so no Alias namespace.
  factory _ChannelHarness.direct({
    required String messageText,
    bool ownMessage = false,
  }) {
    final client = _client();
    final user = ownMessage
        ? User(id: _readerId, name: 'reader')
        : User(id: _senderId, name: 'NightOwl');
    final message = _message(messageText, user);
    final channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: 'loop_direct_8e7d73c5',
          type: 'messaging',
          memberCount: 2,
        ),
        members: <Member>[
          Member(
            userId: _senderId,
            user: User(id: _senderId),
          ),
          Member(
            userId: _readerId,
            user: User(id: _readerId),
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

  /// A client that knows who the reader is: `alignment == end` is the SDK's
  /// own reading of `message.user.id == currentUser.id`.
  static StreamChatClient _client() {
    final client = StreamChatClient(
      'public-stream-api-key',
      logLevel: Level.OFF,
    );
    // ignore: invalid_use_of_internal_member
    client.state.currentUser = OwnUser(id: _readerId);
    return client;
  }

  static Message _message(String text, User user) => Message(
    id: 'message-1',
    text: text,
    user: user,
    createdAt: DateTime.utc(2026, 9, 16, 12),
    state: MessageState.sent,
  );

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
