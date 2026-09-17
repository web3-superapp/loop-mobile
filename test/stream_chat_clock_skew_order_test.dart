// A message the device has just sent, on a device whose clock is wrong.
//
// C-31 on the device: 「消息排在最上边这个还是有，你要防止用户修改时间的问题」. The
// list is ordered by `Message.createdAt`, which for a message the server has
// not confirmed yet is `localCreatedAt` — and `Channel.sendMessage` stamps
// that with `DateTime.now()` itself
// (`stream_chat-10.3.0/lib/src/client/channel.dart:776`), with no way for the
// caller to pass one in. A phone an hour behind therefore files its own new
// message an hour into the past, which is exactly where the list draws it.
//
// These tests run the send on a device clock that is an hour fast, an hour
// slow and a day slow. In every case the message the member just sent has to
// be the last one in the channel, stay there when the server confirms it, and
// keep its order against the next one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/time/loop_server_clock.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_outgoing_message_order.dart';
import 'package:loop_mobile/integrations/communication/stream_server_clock_source.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The instant the servers agree on for the whole file.
final DateTime serverNow = DateTime.utc(2026, 9, 17, 12);

void main() {
  final skews = <String, Duration>{
    '设备快 1 小时': const Duration(hours: 1),
    '设备慢 1 小时': const Duration(hours: -1),
    '设备慢 1 天': const Duration(days: -1),
  };

  for (final entry in skews.entries) {
    group(entry.key, () {
      final skew = entry.value;

      testWidgets('the message just sent is the newest one in the room', (
        tester,
      ) async {
        final harness = _SkewHarness(skew: skew);
        await harness.pump(tester);

        harness.send('m1', '刚发出的一条');
        await tester.pumpAndSettle();

        expect(harness.idsInState.last, 'm1');
        expect(harness.renderedTopToBottom(tester).last, 'm1');
        // The device clock is what the SDK stamped; the list must not be
        // reading it.
        expect(
          harness.messageIn('m1').localCreatedAt,
          harness.deviceNow,
          reason: 'the SDK still stamps the device clock',
        );

        await harness.dispose(tester);
      });

      testWidgets('the server confirmation does not move it', (tester) async {
        final harness = _SkewHarness(skew: skew);
        await harness.pump(tester);

        harness.send('m1', '刚发出的一条');
        await tester.pumpAndSettle();
        final before = harness.offsetOf(tester, 'm1');

        harness.confirm('m1', serverNow.add(const Duration(milliseconds: 40)));
        await tester.pumpAndSettle();

        expect(harness.idsInState.last, 'm1');
        expect(harness.renderedTopToBottom(tester).last, 'm1');
        expect(harness.offsetOf(tester, 'm1'), before);
        expect(
          harness.messageIn('m1').remoteCreatedAt,
          serverNow.add(const Duration(milliseconds: 40)),
          reason: 'the server states the real time once it has one',
        );

        await harness.dispose(tester);
      });

      testWidgets('two sends keep the order they were sent in', (tester) async {
        final harness = _SkewHarness(skew: skew);
        await harness.pump(tester);

        harness.send('m1', '第一条');
        await tester.pumpAndSettle();
        harness.send('m2', '第二条');
        await tester.pumpAndSettle();

        expect(harness.idsInState.sublist(25), <String>['m1', 'm2']);

        // The first one comes back from the server; the second is still in
        // flight and still belongs after it.
        harness.confirm('m1', serverNow.add(const Duration(milliseconds: 40)));
        await tester.pumpAndSettle();

        expect(harness.idsInState.sublist(25), <String>['m1', 'm2']);
        final rendered = harness.renderedTopToBottom(tester);
        expect(rendered.sublist(rendered.length - 2), <String>['m1', 'm2']);

        await harness.dispose(tester);
      });
    });
  }

  testWidgets('a send in the first 500ms inside the room is not lost', (
    tester,
  ) async {
    // The window C-30 (2) named: the page has just mounted the channel and the
    // member is already typing. `loopStreamChannelScope` uses
    // `StreamChannel.value`, so nothing truncates the loaded window while the
    // send is in flight and nothing arriving into it is dropped.
    final harness = _SkewHarness(skew: const Duration(days: -1));
    await tester.pumpWidget(harness.app());
    await tester.pump(const Duration(milliseconds: 200));

    harness.send('m1', '刚进来就发');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(harness.channel.state!.isUpToDate, isTrue);
    expect(harness.idsInState.length, 26);
    expect(harness.idsInState.last, 'm1');
    expect(harness.renderedTopToBottom(tester).last, 'm1');

    await harness.dispose(tester);
  });

  testWidgets('an unread room is not repositioned on mount', (tester) async {
    // The default `StreamChannel` constructor answers an unread count by
    // re-querying around the last-read message, which calls `state.truncate()`
    // and holds `isUpToDate = false` for the length of that query — emptying
    // the list and dropping every `message.new` while a member may already be
    // typing. `loopStreamChannelScope` never enters that path.
    final harness = _SkewHarness(skew: const Duration(hours: -1), unread: true);
    await tester.pumpWidget(harness.app());
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.channel.state!.isUpToDate, isTrue);
    expect(harness.idsInState.length, 25);

    harness.send('m1', '刚进来就发');
    await tester.pumpAndSettle();

    expect(harness.idsInState.length, 26);
    expect(harness.idsInState.last, 'm1');

    await harness.dispose(tester);
  });

  testWidgets('history that lands after the send still lands above it', (
    tester,
  ) async {
    final harness = _SkewHarness(
      skew: const Duration(hours: -1),
      seedHistory: false,
    );
    await harness.pump(tester);

    harness.send('m1', '刚发出的一条');
    await tester.pumpAndSettle();
    harness.deliverHistory();
    await tester.pumpAndSettle();

    expect(harness.idsInState.last, 'm1');
    expect(harness.renderedTopToBottom(tester).last, 'm1');

    await harness.dispose(tester);
  });

  group('LoopOutgoingMessageOrder', () {
    test('a settled channel is left exactly as it is', () async {
      final bench = _OrderBench(skew: const Duration(hours: -1));
      await bench.send('m1');
      final settled = bench.snapshot();

      // A second pass over an already-correct channel must write nothing,
      // otherwise every channel change would walk the message forward.
      bench.order.reconcile(bench.channel.state!.messages);

      expect(bench.snapshot(), settled);
      bench.dispose();
    });

    test('a send that failed still belongs at the end', () async {
      final bench = _OrderBench(skew: const Duration(days: -1));
      await bench.send('m1');
      final placed = bench.stampOf('m1');

      await bench.fail('m1');

      expect(bench.channel.state!.messages.last.id, 'm1');
      expect(bench.stampOf('m1'), placed);
      bench.dispose();
    });

    test('an edit of an old message is not dragged to the end', () async {
      final bench = _OrderBench(skew: const Duration(hours: -1));
      final old = bench.channel.state!.messages.first;

      bench.channel.state!.updateMessage(
        old.copyWith(text: '改过了', state: MessageState.updating),
      );
      await bench.settle();

      expect(bench.channel.state!.messages.first.id, old.id);
      expect(
        bench.channel.state!.messages.first.remoteCreatedAt,
        old.remoteCreatedAt,
      );
      bench.dispose();
    });

    test('with no server reading it falls back to the device clock', () async {
      // A cold start with no network yet: the offset is zero, so the stamp is
      // the device's own time — but the invariant still holds, because it is
      // clamped past everything the channel already knows.
      LoopServerClock.instance = LoopServerClock(
        deviceNow: () => serverNow.subtract(const Duration(days: 1)).toLocal(),
      );
      final bench = _OrderBench.withCurrentClock();
      await bench.send('m1');

      expect(bench.channel.state!.messages.last.id, 'm1');
      expect(
        bench
            .stampOf('m1')!
            .isAfter(serverNow.subtract(const Duration(minutes: 1))),
        isTrue,
      );
      bench.dispose();
    });
  });

  group('loopWatchStreamServerClock', () {
    test('an arriving message names the servers\' clock', () async {
      final device = serverNow.subtract(const Duration(days: 1));
      final clock = LoopServerClock(deviceNow: () => device);
      final client = StreamChatClient('key', logLevel: Level.OFF);
      final subscription = loopWatchStreamServerClock(client, clock: clock);
      addTearDown(() async {
        await subscription.cancel();
        await client.dispose();
      });

      client.handleEvent(
        Event(
          type: EventType.messageNew,
          message: Message(
            id: 'x',
            user: User(id: 'other'),
            createdAt: serverNow,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(clock.offset, const Duration(days: 1));
      expect(clock.nowUtc(), serverNow);
    });

    test('an event without a server time leaves the clock alone', () async {
      final device = serverNow.subtract(const Duration(days: 1));
      final clock = LoopServerClock(deviceNow: () => device);
      final client = StreamChatClient('key', logLevel: Level.OFF);
      final subscription = loopWatchStreamServerClock(client, clock: clock);
      addTearDown(() async {
        await subscription.cancel();
        await client.dispose();
      });

      client.handleEvent(Event(type: EventType.messageNew));
      await Future<void>.delayed(Duration.zero);

      expect(clock.hasServerObservation, isFalse);
    });
  });

  test('LOOP registers no ordering or content override on the list', () {
    final builders = loopStreamMessageListViewBuilders();
    expect(builders.content, isNull);
    expect(builders.dateDivider, isNotNull);
    expect(builders.floatingDateDivider, isNotNull);
  });
}

final class _SkewHarness {
  _SkewHarness({
    required this.skew,
    this.seedHistory = true,
    this.unread = false,
  }) {
    LoopServerClock.instance = LoopServerClock(deviceNow: () => deviceNow);
    // One backend answer has already told LOOP what time it is, which is what
    // `LoopServerClockInterceptor` does on every `/v2` response.
    LoopServerClock.instance.observe(
      serverTime: serverNow,
      sentAt: deviceNow,
      receivedAt: deviceNow.add(const Duration(milliseconds: 80)),
    );
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
        read: unread
            ? <Read>[
                Read(
                  user: User(id: 'me', name: '我'),
                  lastRead: history.first.createdAt,
                  lastReadMessageId: history.first.id,
                  unreadMessages: 24,
                ),
              ]
            : const <Read>[],
      ),
    );
    order = LoopOutgoingMessageOrder(channel: channel)..attach();
  }

  final Duration skew;
  final bool seedHistory;
  final bool unread;
  final StreamChatClient client = StreamChatClient('key', logLevel: Level.OFF);
  late final Channel channel;
  late final LoopOutgoingMessageOrder order;

  /// What `DateTime.now()` answers on this device: the real instant plus the
  /// clock the member set. Local-flavoured, exactly like the SDK's own stamp.
  DateTime get deviceNow => serverNow.add(skew).toLocal();

  /// 25 messages, oldest first, each carrying the server's own clock.
  late final List<Message> history = <Message>[
    for (var i = 25; i >= 1; i--)
      Message(
        id: 'h$i',
        text: '历史 $i',
        user: User(id: 'other', name: '别人'),
        createdAt: serverNow.subtract(Duration(minutes: i)),
        state: MessageState.sent,
      ),
  ];

  final Map<String, Message> _optimistic = <String, Message>{};

  List<String> get idsInState =>
      channel.state!.messages.map((it) => it.id).toList();

  Message messageIn(String id) =>
      channel.state!.messages.firstWhere((it) => it.id == id);

  /// Exactly what `Channel.sendMessage` writes into the channel state before
  /// it reaches the network: the device clock in `localCreatedAt`, no
  /// `remoteCreatedAt`, state `sending`.
  void send(String id, String text) {
    final message = Message(
      id: id,
      text: text,
      user: User(id: 'me', name: '我'),
      localCreatedAt: deviceNow,
      state: MessageState.sending,
    );
    _optimistic[id] = message;
    channel.state!.updateMessage(message);
  }

  /// What `Channel.sendMessage` writes when the server answers: the server's
  /// own `created_at`, merged onto the message it sent — not onto whatever the
  /// channel state holds now.
  void confirm(String id, DateTime serverTime) {
    final echo = Message(
      id: id,
      text: _optimistic[id]!.text,
      user: User(id: 'me', name: '我'),
      createdAt: serverTime,
      state: MessageState.sent,
    );
    channel.state!.updateMessage(_optimistic[id]!.updateWith(echo));
  }

  void deliverHistory() => channel.state!.updateChannelState(
    channel.state!.channelState.copyWith(messages: history),
  );

  Widget app() => MaterialApp(
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
      child: loopStreamChannelScope(
        channel: channel,
        child: Scaffold(
          body: StreamMessageListView(
            builders: loopStreamMessageListViewBuilders(),
          ),
        ),
      ),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  double offsetOf(WidgetTester tester, String id) =>
      tester.getTopLeft(_finderFor(id)).dy;

  List<String> renderedTopToBottom(WidgetTester tester) {
    final rendered = <String, double>{};
    for (final id in <String>[
      ...history.map((it) => it.id),
      ..._optimistic.keys,
    ]) {
      final finder = _allFor(id);
      if (finder.evaluate().isEmpty) continue;
      rendered[id] = tester.getTopLeft(finder.first).dy;
    }
    final ids = rendered.keys.toList()
      ..sort((a, b) => rendered[a]!.compareTo(rendered[b]!));
    return ids;
  }

  Finder _finderFor(String id) => _allFor(id).first;

  Finder _allFor(String id) => find.byWidgetPredicate(
    (widget) =>
        widget is DefaultStreamMessageItem && widget.props.message.id == id,
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    order.dispose();
    channel.dispose();
    LoopServerClock.instance = LoopServerClock();
  }
}

/// A channel plus the order keeper, without any widgets.
final class _OrderBench {
  _OrderBench({required Duration skew}) {
    LoopServerClock.instance = LoopServerClock(
      deviceNow: () => serverNow.add(skew).toLocal(),
    );
    LoopServerClock.instance.observe(
      serverTime: serverNow,
      sentAt: serverNow.add(skew).toLocal(),
      receivedAt: serverNow.add(skew).toLocal(),
    );
    _build();
  }

  _OrderBench.withCurrentClock() {
    _build();
  }

  final StreamChatClient client = StreamChatClient('key', logLevel: Level.OFF);
  late final Channel channel;
  late final LoopOutgoingMessageOrder order;
  final Map<String, Message> _sent = <String, Message>{};

  void _build() {
    // ignore: invalid_use_of_internal_member
    client.state.currentUser = OwnUser(id: 'me', name: '我');
    channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(id: 'room', type: 'messaging'),
        messages: <Message>[
          for (var i = 3; i >= 1; i--)
            Message(
              id: 'h$i',
              text: '历史 $i',
              user: User(id: 'other', name: '别人'),
              createdAt: serverNow.subtract(Duration(minutes: i)),
              state: MessageState.sent,
            ),
        ],
      ),
    );
    order = LoopOutgoingMessageOrder(channel: channel)..attach();
  }

  /// Lets the keeper's subscription run: the channel state stream delivers
  /// asynchronously, so a correction lands one microtask after the write —
  /// still before any frame is painted.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> send(String id) async {
    final message = Message(
      id: id,
      text: '一条',
      user: User(id: 'me', name: '我'),
      localCreatedAt: LoopServerClock.instance.deviceNow(),
      state: MessageState.sending,
    );
    _sent[id] = message;
    channel.state!.updateMessage(message);
    await settle();
  }

  Future<void> fail(String id) async {
    channel.state!.updateMessage(
      channel.state!.messages
          .firstWhere((it) => it.id == id)
          .copyWith(
            state: MessageState.sendingFailed(
              skipPush: false,
              skipEnrichUrl: false,
            ),
          ),
    );
    await settle();
  }

  DateTime? stampOf(String id) =>
      channel.state!.messages.firstWhere((it) => it.id == id).remoteCreatedAt;

  List<String> snapshot() => channel.state!.messages
      .map((it) => '${it.id}@${it.createdAt.toUtc()}')
      .toList();

  void dispose() {
    order.dispose();
    channel.dispose();
    LoopServerClock.instance = LoopServerClock();
  }
}
