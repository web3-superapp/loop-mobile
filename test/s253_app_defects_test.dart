import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/v2/group_screens.dart';
import 'package:loop_mobile/features/chat/v2/loop_channel_heading.dart';
import 'package:loop_mobile/integrations/communication/stream_deleted_message_reconciler.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

const String _cid = 'messaging:loop_community_d17b34a6c3cc4a2487dddc165c80bd85';
const String _groupCid =
    'messaging:loop_group_95fee4b40a9a405eaca19d7616f49b85';

final DateTime _t0 = DateTime.utc(2026, 9, 28, 4);

Message _message(
  String id, {
  required int minute,
  MessageState? state,
  String? parentId,
  bool? showInChannel,
  MessageType type = MessageType.regular,
}) => Message(
  id: id,
  text: id,
  type: type,
  user: User(id: 'other'),
  createdAt: _t0.add(Duration(minutes: minute)),
  state: state ?? MessageState.sent,
  parentId: parentId,
  showInChannel: showInChannel,
);

void main() {
  group('S253 · 1 · messages the server deleted leave this device', () {
    test('a page that holds the whole room judges every local message', () {
      final stale = loopStaleLocalMessageIds(
        local: <Message>[
          _message('kept-1', minute: 1),
          _message('deleted-old', minute: 2),
          _message('kept-2', minute: 3),
          _message('deleted-new', minute: 4),
          // The 2026-10-19 device held a row with no time at all.
          Message(id: 'stub', state: MessageState.sent),
        ],
        serverPage: <Message>[
          _message('kept-1', minute: 1),
          _message('kept-2', minute: 3),
        ],
        reachesChannelStart: true,
      );
      expect(stale, <String>{'deleted-old', 'deleted-new', 'stub'});
    });

    test('a partial page judges only what it covers', () {
      final stale = loopStaleLocalMessageIds(
        local: <Message>[
          _message('older-than-page', minute: 1),
          _message('page-oldest', minute: 5),
          _message('deleted-in-window', minute: 6),
          _message('page-newest', minute: 7),
        ],
        serverPage: <Message>[
          _message('page-oldest', minute: 5),
          _message('page-newest', minute: 7),
        ],
        reachesChannelStart: false,
      );
      expect(stale, <String>{'deleted-in-window'});
    });

    test('what the server never accepted is never judged', () {
      final stale = loopStaleLocalMessageIds(
        local: <Message>[
          _message('sending', minute: 1, state: MessageState.sending),
          _message(
            'failed',
            minute: 2,
            state: MessageState.sendingFailed(
              skipPush: false,
              skipEnrichUrl: false,
            ),
          ),
          _message('ephemeral', minute: 3, type: MessageType.ephemeral),
          _message('error', minute: 4, type: MessageType.error),
          _message('thread-only', minute: 5, parentId: 'p'),
          _message(
            'thread-shown',
            minute: 6,
            parentId: 'p',
            showInChannel: true,
          ),
        ],
        serverPage: const <Message>[],
        reachesChannelStart: true,
      );
      expect(stale, <String>{'thread-shown'});
    });

    test('an empty partial page judges nothing', () {
      expect(
        loopStaleLocalMessageIds(
          local: <Message>[_message('a', minute: 1)],
          serverPage: const <Message>[],
          reachesChannelStart: false,
        ),
        isEmpty,
      );
    });

    test(
      'the room drops them from memory and from the offline store',
      () async {
        final harness = _ReconcileHarness(
          memory: <Message>[
            _message('kept-1', minute: 1),
            _message('deleted-in-memory', minute: 2),
            _message('kept-2', minute: 3),
          ],
          stored: <Message>[
            _message('deleted-only-on-disk', minute: 0),
            _message('kept-1', minute: 1),
            _message('deleted-in-memory', minute: 2),
            _message('kept-2', minute: 3),
          ],
        );
        final reconciler = LoopStreamDeletedMessageReconciler(
          client: harness.client,
          serverPage: (channel, limit) async {
            harness.reads.add(limit);
            return <Message>[
              _message('kept-1', minute: 1),
              _message('kept-2', minute: 3),
            ];
          },
        );

        final removed = await reconciler.reconcile(harness.channel);

        expect(removed, <String>{'deleted-in-memory', 'deleted-only-on-disk'});
        expect(harness.reads, <int>[loopStreamReconcilePageSize]);
        expect(harness.channel.state!.messages.map((m) => m.id), <String>[
          'kept-1',
          'kept-2',
        ]);
        expect(
          harness.persistence.deleted,
          containsAll(<String>['deleted-in-memory', 'deleted-only-on-disk']),
        );
        expect(harness.persistence.deleted, isNot(contains('kept-1')));
      },
    );

    test(
      'two asks for one room while a read is in flight are one read',
      () async {
        final harness = _ReconcileHarness(
          memory: <Message>[_message('a', minute: 1)],
        );
        final answer = Completer<List<Message>>();
        var reads = 0;
        final reconciler = LoopStreamDeletedMessageReconciler(
          client: harness.client,
          serverPage: (channel, limit) {
            reads += 1;
            return answer.future;
          },
        );
        final first = reconciler.reconcile(harness.channel);
        final second = reconciler.reconcile(harness.channel);
        answer.complete(const <Message>[]);
        expect(await first, <String>{'a'});
        expect(await second, <String>{'a'});
        expect(reads, 1);
      },
    );

    test('a read that fails removes nothing', () async {
      final harness = _ReconcileHarness(
        memory: <Message>[_message('a', minute: 1)],
        stored: <Message>[_message('a', minute: 1)],
      );
      final reconciler = LoopStreamDeletedMessageReconciler(
        client: harness.client,
        serverPage: (channel, limit) async =>
            throw StateError('the network went away'),
      );
      expect(await reconciler.reconcile(harness.channel), isEmpty);
      expect(harness.channel.state!.messages, hasLength(1));
      expect(harness.persistence.deleted, isEmpty);
    });

    test('the production read waits for a live connection', () async {
      final harness = _ReconcileHarness(
        memory: <Message>[_message('a', minute: 1)],
      );
      // No injected page: the client's own socket is not connected.
      final reconciler = LoopStreamDeletedMessageReconciler(
        client: harness.client,
      );
      expect(await reconciler.reconcile(harness.channel), isEmpty);
      expect(harness.channel.state!.messages, hasLength(1));
    });
  });

  group('S253 · 2 · the conversation header names the room', () {
    test('the group header is its name, or 群聊 with none', () {
      expect(
        groupChatTitle(const LoopChannelHeading(name: 'BSC 早期盘互助')),
        'BSC 早期盘互助',
      );
      expect(groupChatTitle(LoopChannelHeading.none), groupChatNeutralTitle);
      expect(loopChannelMemberLine(4), '4 位成员');
      expect(loopChannelMemberLine(0), isNull);
      expect(loopChannelMemberLine(null), isNull);
    });

    test('the heading reads the channel name through the display gate', () {
      expect(
        LoopChannelHeading.of(
          ChannelState(
            channel: ChannelModel(
              id: 'loop_group_1',
              type: 'messaging',
              memberCount: 4,
              extraData: const <String, Object?>{'name': 'BSC 早期盘互助'},
            ),
          ),
        ),
        const LoopChannelHeading(name: 'BSC 早期盘互助', memberCount: 4),
      );
      // A padded name fails the gate, and no count is no line.
      expect(
        LoopChannelHeading.of(
          ChannelState(
            channel: ChannelModel(
              id: 'loop_group_1',
              type: 'messaging',
              extraData: const <String, Object?>{'name': '  padded  '},
            ),
          ),
        ),
        LoopChannelHeading.none,
      );
    });

    testWidgets('the header follows the held channel as it arrives', (
      tester,
    ) async {
      final client = StreamChatClient('key', logLevel: Level.OFF);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LoopStreamChannelHeadingBuilder(
                cid: _groupCid,
                client: client,
                builder: (context, heading) => Column(
                  children: <Widget>[
                    Text(groupChatTitle(heading)),
                    Text(loopChannelMemberLine(heading.memberCount) ?? '-'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('群聊'), findsOneWidget);
      expect(find.text('-'), findsOneWidget);

      final channel = Channel.fromState(
        client,
        ChannelState(
          channel: ChannelModel(
            id: 'loop_group_95fee4b40a9a405eaca19d7616f49b85',
            type: 'messaging',
            memberCount: 4,
            extraData: const <String, Object?>{'name': 'BSC 早期盘互助'},
          ),
        ),
      );
      // ignore: invalid_use_of_internal_member
      client.state.addChannels(<String, Channel>{_groupCid: channel});
      await tester.pump();
      await tester.pump();
      expect(find.text('BSC 早期盘互助'), findsOneWidget);
      expect(find.text('4 位成员'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      channel.dispose();
    });
  });
}

final class _ReconcileHarness {
  _ReconcileHarness({
    required List<Message> memory,
    List<Message> stored = const <Message>[],
  }) : persistence = _Persistence(stored) {
    channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: 'loop_community_d17b34a6c3cc4a2487dddc165c80bd85',
          type: 'messaging',
        ),
        messages: memory,
      ),
    );
    client.chatPersistenceClient = persistence;
  }

  final StreamChatClient client = StreamChatClient('key', logLevel: Level.OFF);
  final _Persistence persistence;
  late final Channel channel;
  final List<int> reads = <int>[];
}

final class _Persistence extends Fake implements ChatPersistenceClient {
  _Persistence(this.stored);

  final List<Message> stored;
  final List<String> deleted = <String>[];

  @override
  bool get isConnected => true;

  @override
  Future<List<Message>> getMessagesByCid(
    String cid, {
    PaginationParams? messagePagination,
  }) async => cid == _cid ? stored : const <Message>[];

  @override
  Future<void> deleteMessageByIds(List<String> messageIds) async {
    deleted.addAll(messageIds);
  }

  @override
  Future<void> deletePinnedMessageByIds(List<String> messageIds) async {}

  @override
  Future<void> updateChannelState(ChannelState channelState) async {}

  @override
  Future<void> updateChannelThreads(
    String cid,
    Map<String, List<Message>> threads,
  ) async {}
}
