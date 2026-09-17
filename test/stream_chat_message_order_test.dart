// Where a message the device has just sent lands in the list.
//
// C-30 (2) on the device: a message sent right after opening a chat appeared
// above the history instead of below it, and settled a moment later. The list
// is `StreamMessageListView` in reverse, fed by `channel.state.messages`,
// which the SDK keeps sorted ascending by `createdAt`. LOOP registers three
// component builders on that row (`messageItem`, `messageText`,
// `messageHeader`) and two date dividers on the list; none of them may touch
// identity, keys or order. These tests hold that line, so a LOOP-side
// reordering regression cannot hide behind the SDK.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

void main() {
  testWidgets('a message still sending sits under the history it follows', (
    tester,
  ) async {
    final harness = _OrderHarness();
    await harness.pump(tester);

    harness.send(_pending(harness.sentAt));
    await tester.pumpAndSettle();

    expect(harness.idsInState, <String>['h3', 'h2', 'h1', 'outgoing']);
    // Top of the screen is the oldest message; the outgoing one is last.
    expect(harness.renderedTopToBottom(tester), <String>[
      'h3',
      'h2',
      'h1',
      'outgoing',
    ]);

    await harness.dispose(tester);
  });

  testWidgets('the server confirmation does not move it', (tester) async {
    final harness = _OrderHarness();
    await harness.pump(tester);

    harness.send(_pending(harness.sentAt));
    await tester.pumpAndSettle();
    final pendingOffset = harness.offsetOf(tester, 'outgoing');

    // The echo carries the server's own clock, a moment after the local one.
    harness.send(
      _pending(harness.sentAt).copyWith(
        createdAt: harness.sentAt.toUtc().add(const Duration(milliseconds: 40)),
        state: MessageState.sent,
      ),
    );
    await tester.pumpAndSettle();

    expect(harness.idsInState, <String>['h3', 'h2', 'h1', 'outgoing']);
    expect(harness.renderedTopToBottom(tester), <String>[
      'h3',
      'h2',
      'h1',
      'outgoing',
    ]);
    expect(harness.offsetOf(tester, 'outgoing'), pendingOffset);

    await harness.dispose(tester);
  });

  testWidgets('history that arrives after the send lands above it', (
    tester,
  ) async {
    // The first seconds inside a channel are the ones C-30 (2) named: the
    // page has queried the channel, the SDK is still filling the window, and
    // the member is already typing.
    final harness = _OrderHarness(seedHistory: false);
    await harness.pump(tester);

    harness.send(_pending(harness.sentAt));
    await tester.pumpAndSettle();
    harness.deliverHistory();
    await tester.pumpAndSettle();

    expect(harness.idsInState, <String>['h3', 'h2', 'h1', 'outgoing']);
    expect(harness.renderedTopToBottom(tester), <String>[
      'h3',
      'h2',
      'h1',
      'outgoing',
    ]);

    await harness.dispose(tester);
  });

  test('LOOP registers no ordering or content override on the list', () {
    final builders = loopStreamMessageListViewBuilders();
    // Only the two day labels. `content` would replace the whole list — and
    // with it the SDK's own ordering — so it has to stay null.
    expect(builders.content, isNull);
    expect(builders.dateDivider, isNotNull);
    expect(builders.floatingDateDivider, isNotNull);
  });
}

Message _pending(DateTime sentAt) => Message(
  id: 'outgoing',
  text: '刚发出的一条',
  user: User(id: 'me', name: '我'),
  localCreatedAt: sentAt,
  state: MessageState.sending,
);

final class _OrderHarness {
  _OrderHarness({this.seedHistory = true}) {
    // The list needs an identity to tell an incoming row from an outgoing
    // one. There is no offline way to connect a Stream user in a test.
    // ignore: invalid_use_of_internal_member
    client.state.currentUser = OwnUser(id: 'me', name: '我');
    channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: 'loop_community_0123456789abcdef',
          type: 'messaging',
          memberCount: 2,
        ),
        members: <Member>[
          Member(
            userId: 'me',
            user: User(id: 'me', name: '我'),
          ),
          Member(
            userId: 'other',
            user: User(id: 'other', name: '别人'),
          ),
        ],
        messages: seedHistory ? history : const <Message>[],
      ),
    );
  }

  final bool seedHistory;
  final StreamChatClient client = StreamChatClient('key', logLevel: Level.OFF);
  late final Channel channel;

  static final DateTime _now = DateTime.now();

  /// Oldest first, exactly as the channel query returns them.
  late final List<Message> history = <Message>[
    for (var i = 3; i >= 1; i--)
      Message(
        id: 'h$i',
        text: '历史 $i',
        user: User(id: 'other', name: '别人'),
        createdAt: _now.toUtc().subtract(Duration(minutes: i * 10)),
        state: MessageState.sent,
      ),
  ];

  DateTime get sentAt => _now;

  List<String> get idsInState =>
      channel.state!.messages.map((it) => it.id).toList();

  void send(Message message) => channel.state!.updateMessage(message);

  void deliverHistory() => channel.state!.updateChannelState(
    channel.state!.channelState.copyWith(messages: history),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          LoopStreamChatLocalizationsDelegate(),
        ],
        home: StreamChat(
          client: client,
          componentBuilders: StreamComponentBuilders(
            messageText: loopStreamMessageTextBuilder,
            extensions: streamChatComponentBuilders(
              messageItem: loopStreamGroupMessageItemBuilder,
              messageFooter: loopStreamMessageFooterBuilder,
              messageHeader: loopStreamMessageHeaderBuilder,
            ),
          ),
          child: StreamChannel.value(
            channel: channel,
            child: Scaffold(
              body: StreamMessageListView(
                builders: loopStreamMessageListViewBuilders(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double offsetOf(WidgetTester tester, String id) =>
      tester.getTopLeft(_finderFor(id)).dy;

  List<String> renderedTopToBottom(WidgetTester tester) {
    final rendered = <String, double>{};
    for (final id in <String>[...history.map((it) => it.id), 'outgoing']) {
      final finder = _finderFor(id);
      if (finder.evaluate().isEmpty) continue;
      rendered[id] = tester.getTopLeft(finder).dy;
    }
    final ids = rendered.keys.toList()
      ..sort((a, b) => rendered[a]!.compareTo(rendered[b]!));
    return ids;
  }

  Finder _finderFor(String id) => find
      .byWidgetPredicate(
        (widget) =>
            widget is DefaultStreamMessageItem && widget.props.message.id == id,
      )
      .first;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    channel.dispose();
  }
}
