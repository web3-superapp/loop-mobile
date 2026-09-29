// S102 · 群/社区聊天里别人的名字显示「成员」、头像「成」（决策 0107）。
//
// 服务端每个成员的 member custom 都有 `loop_group_alias`，但频道 state 只带有限的
// 成员（进房查询 memberLimit 原为 30，上限 100），社区频道几百人，本地成员表里找不到
// 的发送者一律回落「成员」。现在按 id 批量 `queryMembers` 补查，查回的 Member 走
// 同一条 fail-closed 校验。这份测试钉住：查到就显示群内昵称；查询失败保持「成员」
// 且重试有上限；非法 projection 仍 fail-closed；查过确实没有与还没查分开。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/group_alias/group_member_directory.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

const String _aliasId = 'bb5e12c2-40e2-4577-9951-57fac0b5ce5e';
const String _groupId = 'loop_group_8e7d73c5';

String _userId(int n) => 'loop_user_${n.toString().padLeft(4, '0')}';

void main() {
  group('directory', () {
    test('a moderator member row still parses its Alias (S99b)', () {
      // What Stream answers for an owner/admin after S99b gave them
      // `channel_moderator`: the role fields are Stream's own top-level keys,
      // so the custom map the projection is read from is unchanged.
      final member = Member.fromJson(<String, dynamic>{
        'user_id': _userId(1),
        'user': <String, dynamic>{'id': _userId(1), 'role': 'user'},
        'channel_role': 'channel_moderator',
        'is_moderator': true,
        'role': 'moderator',
        'notifications_muted': false,
        'created_at': '2026-09-28T00:00:00Z',
        'updated_at': '2026-09-28T00:00:00Z',
        ..._projection('Pelican-4624'),
      });

      expect(member.channelRole, 'channel_moderator');
      expect(
        parseLoopGroupAliasMemberProjection(member.extraData),
        'Pelican-4624',
      );
      expect(
        resolveLoopGroupMessageSenderLabel(
          senderUserId: _userId(1),
          members: <Member>[member],
        ),
        'Pelican-4624',
      );
    });

    testWidgets('ids are deduplicated, debounced and batched', (tester) async {
      final calls = <List<String>>[];
      final directory = LoopGroupMemberDirectory(
        lookup: (ids) async {
          calls.add(ids);
          return <Member>[];
        },
      );
      addTearDown(directory.dispose);

      directory
        ..request(<String>[for (var i = 0; i < 60; i++) _userId(i)])
        ..request(<String>[for (var i = 30; i < 120; i++) _userId(i)])
        ..request(<String>['', ' padded', _userId(5)]);
      expect(calls, isEmpty, reason: 'nothing leaves inside the debounce');
      expect(
        directory.statusOf(_userId(119)),
        LoopGroupMemberLookupStatus.pending,
      );

      await tester.pump(const Duration(milliseconds: 250));

      expect(calls.map((batch) => batch.length), <int>[50, 50, 20]);
      expect(calls.expand((batch) => batch).toSet().length, 120);
      // Answered, and nobody was there: that is not the same as unasked.
      expect(
        directory.statusOf(_userId(0)),
        LoopGroupMemberLookupStatus.absent,
      );
      expect(
        directory.statusOf(_userId(500)),
        LoopGroupMemberLookupStatus.unrequested,
      );

      directory.request(<String>[_userId(0), _userId(119)]);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, hasLength(3), reason: 'an answered id is not asked again');
    });

    testWidgets('offline, nothing is queued and no timer is armed', (
      tester,
    ) async {
      var calls = 0;
      final directory = LoopGroupMemberDirectory(
        lookup: (ids) async {
          calls++;
          return <Member>[];
        },
        canLookup: () => false,
      );
      addTearDown(directory.dispose);

      directory.request(<String>[_userId(1)]);
      await tester.pump(const Duration(seconds: 1));

      expect(calls, 0);
      expect(
        directory.statusOf(_userId(1)),
        LoopGroupMemberLookupStatus.unrequested,
      );
    });

    testWidgets('a member who leaves stops being named at once', (
      tester,
    ) async {
      final directory = LoopGroupMemberDirectory(
        lookup: (ids) async => <Member>[
          for (final id in ids) _member(id, 'Heron-0150'),
        ],
      );
      addTearDown(directory.dispose);
      directory.request(<String>[_userId(150)]);
      await tester.pump(const Duration(milliseconds: 250));
      expect(_labelFrom(directory, _userId(150)), 'Heron-0150');

      directory.observe(
        Event(
          type: EventType.memberRemoved,
          cid: 'messaging:$_groupId',
          member: Member(
            userId: _userId(150),
            user: User(id: _userId(150)),
          ),
        ),
      );

      expect(_labelFrom(directory, _userId(150)), loopGroupMemberNeutralLabel);
      expect(
        directory.statusOf(_userId(150)),
        LoopGroupMemberLookupStatus.absent,
      );
    });
  });

  group('a busy room', () {
    testWidgets(
      'the 150th member reads by their group name once the lookup lands',
      (tester) async {
        final lookups = <List<String>>[];
        final harness = _Harness(
          senderIndex: 150,
          lookup: (ids) async {
            lookups.add(ids);
            return <Member>[
              for (final id in ids)
                if (id == _userId(150)) _member(id, 'Heron-0150'),
            ];
          },
        );
        addTearDown(harness.dispose);

        await harness.pump(tester);
        // Before the answer: the neutral word, never the id or account name.
        expect(_rendered(tester).user?.name, loopGroupMemberNeutralLabel);
        expect(find.text(_userId(150)), findsNothing);
        expect(find.text('Account 150'), findsNothing);

        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump();

        expect(lookups, <List<String>>[
          <String>[_userId(150)],
        ]);
        expect(_rendered(tester).user?.name, 'Heron-0150');
        expect(find.text('Account 150'), findsNothing);

        // The `@` card now offers them, and a mention of them leaves named.
        expect(
          resolveLoopGroupMentionCandidates(
            members: harness.directory.roster(
              harness.channel.state!.channelState.members!,
            ),
            query: 'Her',
          ).map((candidate) => candidate.userId),
          <String>[_userId(150)],
        );
        final prepared = loopPrepareChannelMessageForSend(
          message: Message(
            text: '@Heron-0150 早',
            mentionedUsers: <User>[User(id: _userId(150))],
          ),
          channel: harness.channel,
        );
        expect(prepared.mentionedUsers.single.name, 'Heron-0150');

        await harness.unmount(tester);
      },
    );

    testWidgets('a failing lookup keeps 「成员」 and stops after its retries', (
      tester,
    ) async {
      var calls = 0;
      final harness = _Harness(
        senderIndex: 150,
        lookup: (ids) async {
          calls++;
          throw StateError('provider unavailable');
        },
      );
      addTearDown(harness.dispose);

      await harness.pump(tester);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 5));
      }

      // One attempt plus the two retries, then never again.
      expect(calls, 3);
      expect(
        harness.directory.statusOf(_userId(150)),
        LoopGroupMemberLookupStatus.unavailable,
      );
      expect(_rendered(tester).user?.name, loopGroupMemberNeutralLabel);

      // Rebuilding the room does not start the loop over.
      harness.directory.request(<String>[_userId(150)]);
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 3);

      await harness.unmount(tester);
    });

    testWidgets('a looked-up row with an invalid projection fails closed', (
      tester,
    ) async {
      final harness = _Harness(
        senderIndex: 150,
        lookup: (ids) async => <Member>[
          Member(
            userId: _userId(150),
            user: User(id: _userId(150), name: 'Account 150'),
            extraData: <String, Object?>{
              ..._projection('Heron-0150'),
              'loop_group_alias_version': 2,
            },
          ),
          // A row nobody asked for is not evidence about anybody.
          _member(_userId(999), 'Stray-0999'),
        ],
      );
      addTearDown(harness.dispose);

      await harness.pump(tester);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(
        harness.directory.statusOf(_userId(150)),
        LoopGroupMemberLookupStatus.found,
      );
      expect(
        harness.directory.statusOf(_userId(999)),
        LoopGroupMemberLookupStatus.unrequested,
      );
      expect(_rendered(tester).user?.name, loopGroupMemberNeutralLabel);
      expect(find.text('Account 150'), findsNothing);
      expect(find.text(_userId(150)), findsNothing);

      await harness.unmount(tester);
    });

    testWidgets('a sender inside the loaded slice is not looked up', (
      tester,
    ) async {
      var calls = 0;
      final harness = _Harness(
        senderIndex: 42,
        lookup: (ids) async {
          calls++;
          return <Member>[];
        },
      );
      addTearDown(harness.dispose);

      await harness.pump(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(calls, 0);
      expect(_rendered(tester).user?.name, 'Member-0042');
      await harness.unmount(tester);
    });
  });
}

Map<String, Object?> _projection(String alias) => <String, Object?>{
  'loop_group_alias_id': _aliasId,
  'loop_group_alias': alias,
  'loop_group_alias_version': 1,
};

Member _member(String id, String alias) => Member(
  userId: id,
  user: User(id: id, name: 'Account ${int.parse(id.split('_').last)}'),
  extraData: _projection(alias),
);

String _labelFrom(LoopGroupMemberDirectory directory, String userId) =>
    resolveLoopGroupMessageSenderLabel(
      senderUserId: userId,
      members: directory.roster(const <Member>[]),
    );

Message _rendered(WidgetTester tester) => tester
    .widget<DefaultStreamMessageItem>(find.byType(DefaultStreamMessageItem))
    .props
    .message;

final class _Harness {
  factory _Harness({
    required int senderIndex,
    required LoopGroupMemberLookup lookup,
  }) {
    final client = StreamChatClient(
      'public-stream-api-key',
      logLevel: Level.OFF,
    );
    final sender = _userId(senderIndex);
    final message = Message(
      id: 'message-$senderIndex',
      text: 'gm',
      user: User(id: sender, name: 'Account $senderIndex'),
      createdAt: DateTime.utc(2026, 9, 29, 12),
      state: MessageState.sent,
    );
    // The loaded slice: the first 100 members, exactly what Stream sends.
    final channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: _groupId,
          type: 'messaging',
          memberCount: 317,
        ),
        members: <Member>[
          for (var i = 0; i < 100; i++)
            _member(_userId(i), 'Member-${i.toString().padLeft(4, '0')}'),
        ],
        messages: <Message>[message],
      ),
    );
    final directory = LoopGroupMemberDirectory(lookup: lookup);
    LoopGroupMemberDirectory.debugInstall(channel, directory);
    return _Harness._(client, channel, message, directory);
  }

  _Harness._(this.client, this.channel, this.message, this.directory);

  final StreamChatClient client;
  final Channel channel;
  final Message message;
  final LoopGroupMemberDirectory directory;
  bool _disposed = false;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<Object?>>[
          LoopStreamChatLocalizationsDelegate(),
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: StreamChat(
          client: client,
          componentBuilders: StreamComponentBuilders(
            extensions: streamChatComponentBuilders(
              messageItem: loopStreamGroupMessageItemBuilder,
            ),
          ),
          child: StreamChannel.value(
            channel: channel,
            child: Scaffold(
              body: StreamMessageLayout(
                data: const StreamMessageLayoutData(
                  listKind: StreamMessageListKind.channel,
                ),
                child: StreamMessageItem(
                  message: message,
                  onMessageTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    dispose();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    directory.dispose();
    channel.dispose();
  }
}
