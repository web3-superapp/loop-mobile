// S130 / decision 0134: the 「↑ N 条未读 ×」 pill no longer covers the list.
//
// Stream drew the pill in a `Stack` over the channel list. On the S123f
// device run the list opened anchored on the first unread message and the
// row under the pill was the oldest day's chip: 「9月28日」 sat under
// 「4 条未读」. A LOOP channel list now turns Stream's overlay off and docks the
// same pill in its own strip above the list.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_unread_pill_band.dart';
import 'package:stream_chat_flutter/scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

void main() {
  testWidgets('the pill sits above the list, not over any row', (tester) async {
    final harness = _PillHarness(unread: 4);
    await harness.pump(tester);

    // One pill: LOOP's band (decision 0135 draws it itself). Stream's own
    // overlay is off.
    expect(find.byType(UnreadIndicatorButton), findsNothing);
    expect(find.byType(StreamJumpToUnreadButton), findsNothing);
    expect(find.byType(LoopUnreadJumpPill), findsOneWidget);
    expect(find.text('4 条未读'), findsOneWidget);

    final pill = tester.getRect(find.byType(LoopUnreadJumpPill));
    final list = tester.getRect(find.byType(StreamMessageListView));
    expect(list.top, greaterThanOrEqualTo(pill.bottom));

    // The first-frame case of S123f: the day chip of the oldest message is
    // on screen and nothing of it is under the pill.
    final chip = harness.oldestChip;
    expect(chip, findsOneWidget);
    expect(tester.getRect(chip).top, greaterThanOrEqualTo(list.top));
    expect(tester.getRect(chip).overlaps(pill), isFalse);
    for (final element in find.byType(DefaultStreamMessageItem).evaluate()) {
      final box = element.renderObject! as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      expect(rect.overlaps(pill), isFalse);
    }

    await harness.dispose(tester);
  });

  testWidgets('the strip collapses once the unread is read', (tester) async {
    final harness = _PillHarness(unread: 4);
    await harness.pump(tester);
    expect(tester.getRect(find.byType(StreamMessageListView)).top, isNot(0));

    harness.markReadOnServer();
    await tester.pumpAndSettle();

    expect(find.byType(LoopUnreadJumpPill), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('loop-unread-pill-band')),
      findsNothing,
    );
    expect(tester.getRect(find.byType(StreamMessageListView)).top, 0);

    await harness.dispose(tester);
  });

  testWidgets('with nothing unread there is no strip', (tester) async {
    final harness = _PillHarness(unread: 0);
    await harness.pump(tester);

    expect(find.byType(LoopUnreadJumpPill), findsNothing);
    expect(tester.getRect(find.byType(StreamMessageListView)).top, 0);

    await harness.dispose(tester);
  });

  testWidgets('a refused dismiss leaves the pill in place', (tester) async {
    final harness = _PillHarness(unread: 4);
    await harness.pump(tester);

    // The test channel has no read events, so `markRead` is refused. The
    // dismiss button is the pill's trailing square.
    await tester.tap(
      find.byKey(const ValueKey<String>('loop-unread-pill-dismiss')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('4 条未读'), findsOneWidget);

    await harness.dispose(tester);
  });

  testWidgets('the arrow brings the first unread message back', (tester) async {
    final harness = _PillHarness(unread: 4, history: 30);
    await harness.pump(tester);

    // Read back to the oldest history, far above the first unread (m30).
    harness.scroll.jumpTo(index: harness.messages.length + 1);
    await tester.pumpAndSettle();
    expect(harness.messageItem('m30'), findsNothing);

    await tester.tap(find.text('4 条未读'));
    await tester.pumpAndSettle();

    expect(harness.messageItem('m30'), findsOneWidget);

    await harness.dispose(tester);
  });

  testWidgets('reduced motion collapses the strip without animating', (
    tester,
  ) async {
    final harness = _PillHarness(unread: 4, disableAnimations: true);
    await harness.pump(tester);
    final size = tester.widget<AnimatedSize>(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('loop-unread-pill-band')),
        matching: find.byType(AnimatedSize),
      ),
    );
    expect(size.duration, Duration.zero);
    await harness.dispose(tester);
  });
}

final class _PillHarness {
  _PillHarness({
    required this.unread,
    this.history = 1,
    this.disableAnimations = false,
  }) {
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
        messages: messages,
        read: <Read>[_read(unread)],
      ),
    );
  }

  final int unread;
  final int history;
  final bool disableAnimations;
  final StreamChatClient client = StreamChatClient('key', logLevel: Level.OFF);
  final ItemScrollController scroll = ItemScrollController();
  late final Channel channel;

  static final DateTime _now = DateTime.now();
  static final DateTime _oldestDay = _now.subtract(const Duration(days: 12));

  /// [history] read messages, the oldest on a day of its own, then four
  /// unread ones on the day before today — the S123f conversation.
  late final List<Message> messages = <Message>[
    for (var i = 0; i < history; i++)
      Message(
        id: 'm$i',
        text: '历史 $i',
        user: User(id: 'other', name: '别人'),
        createdAt: _oldestDay.add(Duration(minutes: i)).toUtc(),
        state: MessageState.sent,
      ),
    for (var i = history; i < history + 4; i++)
      Message(
        id: 'm$i',
        text: '消息 $i',
        user: User(id: 'other', name: '别人'),
        createdAt: _now
            .subtract(const Duration(days: 1))
            .add(Duration(minutes: i))
            .toUtc(),
        state: MessageState.sent,
      ),
  ];

  Finder get oldestChip => find.text(loopStreamDayLabel(_oldestDay));

  Finder messageItem(String id) => find.byWidgetPredicate(
    (widget) =>
        widget is DefaultStreamMessageItem && widget.props.message.id == id,
  );

  Read _read(int unreadMessages) => Read(
    user: User(id: 'me', name: '我'),
    lastRead: unreadMessages > 0
        ? messages[history - 1].createdAt
        : _now.toUtc(),
    lastReadMessageId: unreadMessages > 0
        ? 'm${history - 1}'
        : messages.last.id,
    unreadMessages: unreadMessages,
  );

  void markReadOnServer() => channel.state!.updateChannelState(
    channel.state!.channelState.copyWith(read: <Read>[_read(0)]),
  );

  Future<void> pump(WidgetTester tester) async {
    // A phone-sized list the conversation overfills, so it opens anchored on
    // the first unread message as the S123f channel did.
    tester.view
      ..physicalSize = const Size(400, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: MaterialApp(
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            LoopStreamChatLocalizationsDelegate(),
          ],
          home: StreamChat(
            client: client,
            // LOOP's own list configuration (`lib/app.dart`): no floating day
            // pill. The test channel has no read events, so reaching the
            // bottom must not ask the server to mark it read.
            configData: StreamChatConfigurationData(
              messageListViewConfiguration:
                  const StreamMessageListViewConfiguration(
                    showFloatingDateDivider: false,
                    markReadWhenAtTheBottom: false,
                  ),
            ),
            child: StreamChannel.value(
              channel: channel,
              child: Scaffold(
                body: Builder(
                  builder: (context) => LoopStreamUnreadDockedList(
                    scrollController: scroll,
                    list: StreamMessageListView(
                      builders: loopStreamMessageListViewBuilders(),
                      config: loopChannelListConfiguration(context),
                      scrollController: scroll,
                      enableSafeArea: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    channel.dispose();
  }
}
