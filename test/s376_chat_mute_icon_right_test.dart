import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/community/community_faces.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/legacy_chat_identity.dart';

// S376 · decision 0300 (需求方 11-05 17:5x): a muted conversation's mark sits
// at the row's right end, in the right column under the time (docs/58 §5.6
// "Meta Space"), not straight after the preview text; the preview takes the
// rest of its line and ellipsises.

const String _groupHex = 'aaaaaaaabbbbccccddddeeeeeeeeeeee';
const String _longText =
    '这是一条很长很长的最后消息预览，用来确认它会在静音图标之前被省略号截断，'
    '而不会把图标挤出行外或者换到第二行去显示';

final Finder _muted = find.byKey(
  const ValueKey<String>('loop-channel-muted-mark'),
);
final Finder _pinned = find.byKey(
  const ValueKey<String>('loop-channel-pinned-mark'),
);
final Finder _line = find.byKey(
  const ValueKey<String>('loop-channel-subtitle-line'),
);
final Finder _badge = find.byKey(
  const ValueKey<String>('loop-channel-unread-badge'),
);

Member _member(String id) => Member(
  userId: id,
  createdAt: DateTime.utc(2026, 10, 1),
  user: User(id: id, name: 'Account $id'),
);

({StreamChatClient client, Channel channel}) _setUp({
  required bool muted,
  String text = '晚点聊',
  int unread = 0,
  bool pinned = false,
}) {
  final client = StreamChatClient('public-stream-api-key');
  final model = ChannelModel(
    id: 'loop_group_$_groupHex',
    type: 'messaging',
    memberCount: 3,
    extraData: const <String, Object?>{'name': '周末徒步群'},
  );
  final me = User(id: 'loop_me');
  // ignore: invalid_use_of_internal_member
  client.state.currentUser = OwnUser(
    id: 'loop_me',
    channelMutes: <ChannelMute>[
      if (muted)
        ChannelMute(
          user: me,
          channel: model,
          createdAt: DateTime.utc(2026, 11, 5),
          updatedAt: DateTime.utc(2026, 11, 5),
        ),
    ],
  );
  final members = <Member>[
    _member('loop_a'),
    _member('loop_b'),
    _member('loop_me'),
  ];
  final channel = Channel.fromState(
    client,
    ChannelState(
      channel: model,
      members: members,
      membership: pinned
          ? Member(
              userId: 'loop_me',
              pinnedAt: DateTime.utc(2026, 11, 5),
              user: me,
            )
          : null,
      messages: <Message>[
        Message(
          id: 'message-1',
          text: text,
          user: members.first.user,
          createdAt: DateTime.utc(2026, 11, 5, 12),
          state: MessageState.sent,
        ),
      ],
    ),
  );
  if (unread > 0) channel.state!.unreadCount = unread;
  return (client: client, channel: channel);
}

Future<void> _pump(
  WidgetTester tester, {
  required StreamChatClient client,
  required Channel channel,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpWithLegacyChatIdentity(
    tester,
    MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        LoopStreamChatLocalizationsDelegate(),
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: StreamChat(
        client: client,
        child: StreamChannel.value(
          channel: channel,
          child: CommunityFacesScope(
            faces: const <String, CommunityFace>{},
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: loopStreamChannelListIdentityItem(
                  StreamChannelListItem(channel: channel),
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

Future<void> _dispose(WidgetTester tester, Channel channel) async {
  await tester.pumpWidget(const SizedBox.shrink());
  channel.dispose();
}

Finder _preview(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(text),
);

/// The right edge of the row's words column: the time's right edge.
double _timeRight(WidgetTester tester) =>
    tester.getRect(find.byType(ChannelLastMessageDate)).right;

void main() {
  testWidgets('a muted row: the mark is at the right end, under the time', (
    tester,
  ) async {
    final setup = _setUp(muted: true);
    await _pump(tester, client: setup.client, channel: setup.channel);

    expect(_muted, findsOneWidget);
    expect(tester.getSize(_muted), const Size.square(16));
    final mark = tester.getRect(_muted);
    final time = tester.getRect(find.byType(ChannelLastMessageDate));
    // Right edge on the time's right edge, i.e. the row content's right edge.
    expect(mark.right, moreOrLessEquals(time.right, epsilon: 0.5));
    // Below the time, in the preview line.
    expect(mark.top, greaterThanOrEqualTo(time.bottom - 0.5));
    // Not straight after a short preview: a wide gap is left between them.
    final preview = tester.getRect(_preview('晚点聊'));
    expect(mark.left - preview.left, greaterThan(150));
    // The preview is the line's flexible part; the mark sits outside it, in
    // its own column, not appended to the text's run.
    final previewSlot = find.descendant(
      of: _line,
      matching: find.ancestor(
        of: _preview('晚点聊'),
        matching: find.byType(Expanded),
      ),
    );
    expect(previewSlot, findsOneWidget);
    expect(find.descendant(of: previewSlot, matching: _muted), findsNothing);
    // Within the 360 screen.
    expect(mark.right, lessThanOrEqualTo(360));
    expect(_timeRight(tester), mark.right);
    expect(tester.takeException(), isNull);
    await _dispose(tester, setup.channel);
  });

  testWidgets('a long preview ellipsises before the mark on one line', (
    tester,
  ) async {
    final setup = _setUp(muted: true, text: _longText);
    await _pump(tester, client: setup.client, channel: setup.channel);

    final previewFinder = _preview('这是一条很长');
    final rich = tester.widget<RichText>(previewFinder);
    expect(rich.maxLines, 1);
    expect(rich.overflow, TextOverflow.ellipsis);
    final preview = tester.getRect(previewFinder);
    final mark = tester.getRect(_muted);
    expect(preview.right, lessThanOrEqualTo(mark.left));
    // One line: the preview and the mark share a band.
    expect(preview.center.dy, moreOrLessEquals(mark.center.dy, epsilon: 4));
    expect(tester.takeException(), isNull);
    await _dispose(tester, setup.channel);
  });

  testWidgets('a row that is not muted draws no mark', (tester) async {
    final setup = _setUp(muted: false);
    await _pump(tester, client: setup.client, channel: setup.channel);

    expect(_muted, findsNothing);
    expect(_pinned, findsNothing);
    expect(_line, findsNothing);
    // Stream's own mark is not drawn either.
    expect(find.bySemanticsLabel(RegExp('静音|[Mm]uted')), findsNothing);
    expect(_preview('晚点聊'), findsOneWidget);
    await _dispose(tester, setup.channel);
  });

  testWidgets('muted with unread: badge beside the time, mark under it', (
    tester,
  ) async {
    final setup = _setUp(muted: true, unread: 3);
    await _pump(tester, client: setup.client, channel: setup.channel);

    expect(_badge, findsOneWidget);
    expect(_muted, findsOneWidget);
    final badge = tester.getRect(_badge);
    final mark = tester.getRect(_muted);
    expect(mark.right, moreOrLessEquals(badge.right, epsilon: 0.5));
    expect(mark.top, greaterThanOrEqualTo(badge.bottom - 0.5));
    expect(mark.right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
    await _dispose(tester, setup.channel);
  });

  testWidgets('muted and pinned: both marks at the right end, mute first', (
    tester,
  ) async {
    final setup = _setUp(muted: true, pinned: true);
    await _pump(tester, client: setup.client, channel: setup.channel);

    expect(_muted, findsOneWidget);
    expect(_pinned, findsOneWidget);
    final mute = tester.getRect(_muted);
    final pin = tester.getRect(_pinned);
    expect(pin.right, moreOrLessEquals(_timeRight(tester), epsilon: 0.5));
    expect(mute.right, lessThanOrEqualTo(pin.left));
    expect(tester.takeException(), isNull);
    await _dispose(tester, setup.channel);
  });
}
