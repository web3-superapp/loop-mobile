import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

const String _aliasId = 'bb5e12c2-40e2-4577-9951-57fac0b5ce5e';

void main() {
  group('member projection parser', () {
    test('accepts only the canonical immutable v1 fields', () {
      expect(
        parseLoopGroupAliasMemberProjection(<String, Object?>{
          ..._validProjection('Night Owl'),
          'unrelated_member_field': true,
        }),
        'Night Owl',
      );
    });

    test('rejects malformed, future, or ambiguous LOOP fields', () {
      final invalid = <Map<String, Object?>>[
        <String, Object?>{
          ..._validProjection('Night Owl'),
          'loop_group_alias_version': 2,
        },
        <String, Object?>{
          ..._validProjection('Night Owl'),
          'loop_group_alias_version': 1.0,
        },
        <String, Object?>{
          ..._validProjection('Night Owl'),
          'loop_group_alias_id': 'not-a-canonical-uuid',
        },
        _validProjection(' Night Owl'),
        _validProjection('Night\u202eOwl'),
        <String, Object?>{
          ..._validProjection('Night Owl'),
          'loop_group_alias_future': 'unsafe',
        },
        <String, Object?>{
          'loop_group_alias_id': _aliasId,
          'loop_group_alias': 'Night Owl',
        },
      ];

      for (final projection in invalid) {
        expect(
          parseLoopGroupAliasMemberProjection(projection),
          isNull,
          reason: '$projection must fail closed',
        );
      }
    });
  });

  group('sender label resolver', () {
    test('uses the unique matching current-channel member projection', () {
      expect(
        resolveLoopGroupMessageSenderLabel(
          senderUserId: 'stream-sender',
          members: <Member>[
            _member(
              userId: 'stream-sender',
              accountName: 'Account Name Must Not Render',
              extraData: _validProjection('Night Owl'),
            ),
          ],
        ),
        'Night Owl',
      );
    });

    test('never falls back to Stream user name or id', () {
      for (final members in <List<Member>>[
        <Member>[
          _member(
            userId: 'stream-secret-id',
            accountName: 'Secret Account Name',
          ),
        ],
        <Member>[
          _member(
            userId: 'stream-secret-id',
            accountName: 'Secret Account Name',
            extraData: <String, Object?>{
              ..._validProjection('Night Owl'),
              'loop_group_alias_version': 2,
            },
          ),
        ],
        <Member>[
          _member(
            userId: 'stream-secret-id',
            accountName: 'Secret Account Name',
            extraData: _validProjection('Night Owl'),
          ),
          _member(
            userId: 'stream-secret-id',
            accountName: 'Duplicate Account Name',
            extraData: _validProjection('Other Owl'),
          ),
        ],
      ]) {
        expect(
          resolveLoopGroupMessageSenderLabel(
            senderUserId: 'stream-secret-id',
            members: members,
          ),
          loopGroupMemberNeutralLabel,
        );
      }
    });

    test('rejects conflicting top-level and nested Stream identities', () {
      final conflicting = Member(
        userId: 'stream-sender',
        user: User(id: 'another-stream-user', name: 'Leaked Name'),
        extraData: _validProjection('Night Owl'),
      );

      expect(
        resolveLoopGroupMessageSenderLabel(
          senderUserId: 'stream-sender',
          members: <Member>[conflicting],
        ),
        loopGroupMemberNeutralLabel,
      );
    });
  });

  test('display sanitizer closes every visible Stream user projection', () {
    User accountUser(String id, String name) => User(
      id: id,
      name: name,
      image: 'https://accounts.example/$id.png',
      extraData: <String, Object?>{'wallet': '0x$id'},
    );

    final source = Message(
      id: 'message-deep-projections',
      text: 'hello @mentioned-user, @Global Mention, and @missing-user',
      user: accountUser('sender-user', 'Global Sender'),
      mentionedUsers: <User>[
        accountUser('mentioned-user', 'Global Mention'),
        accountUser('missing-user', 'Missing Global'),
      ],
      quotedMessage: Message(
        id: 'quoted-message',
        text: 'quoted',
        user: accountUser('quoted-user', 'Global Quote'),
      ),
      latestReactions: <Reaction>[
        Reaction(
          messageId: 'message-deep-projections',
          type: 'love',
          user: accountUser('reaction-user', 'Global Reactor'),
        ),
      ],
      ownReactions: <Reaction>[
        Reaction(
          messageId: 'message-deep-projections',
          type: 'like',
          user: accountUser('sender-user', 'Global Sender'),
        ),
      ],
      threadParticipants: <User>[
        accountUser('thread-user', 'Global Thread User'),
      ],
      pinned: true,
      pinnedBy: accountUser('pinner-user', 'Global Pinner'),
    );
    final members = <Member>[
      _projectedMember('sender-user', 'Global Sender', 'Sender Owl'),
      _projectedMember('mentioned-user', 'Global Mention', 'Mention Owl'),
      _projectedMember('quoted-user', 'Global Quote', 'Quote Owl'),
      _projectedMember('reaction-user', 'Global Reactor', 'Reaction Owl'),
      _projectedMember('thread-user', 'Global Thread User', 'Thread Owl'),
      _projectedMember('pinner-user', 'Global Pinner', 'Pin Owl'),
    ];

    final display = sanitizeLoopGroupMessageForDisplay(
      message: source,
      members: members,
    );

    expect(display.user?.name, 'Sender Owl');
    expect(display.user?.image, isNull);
    expect(display.user?.extraData, <String, Object?>{'name': 'Sender Owl'});
    expect(display.mentionedUsers.map((user) => user.name), <String>[
      'Mention Owl',
      loopGroupMemberNeutralLabel,
    ]);
    expect(display.text, 'hello @Mention Owl, @Mention Owl, and @群成员');
    expect(display.quotedMessage?.user?.name, 'Quote Owl');
    expect(display.latestReactions?.single.user?.name, 'Reaction Owl');
    expect(display.ownReactions?.single.user?.name, 'Sender Owl');
    expect(display.threadParticipants?.single.name, 'Thread Owl');
    expect(display.pinnedBy?.name, 'Pin Owl');

    expect(source.user?.name, 'Global Sender');
    expect(source.mentionedUsers.first.name, 'Global Mention');
    expect(source.quotedMessage?.user?.name, 'Global Quote');
  });

  test('known direct channels do not use group message aliases', () {
    expect(
      loopStreamChannelUsesGroupMessageAlias('messaging:loop_group_8e7d73c5'),
      isTrue,
    );
    expect(
      loopStreamChannelUsesGroupMessageAlias('messaging:legacy_group_8e7d73c5'),
      isTrue,
    );
    expect(
      loopStreamChannelUsesGroupMessageAlias('messaging:loop_direct_8e7d73c5'),
      isFalse,
    );
    expect(loopStreamChannelUsesGroupMessageAlias('livestream:group'), isFalse);
  });

  test('group conversation labels never fall back to member identity', () {
    expect(
      resolveLoopGroupConversationLabel(<String, Object?>{
        'name': 'Night Market',
      }),
      'Night Market',
    );
    for (final data in <Map<String, Object?>>[
      const <String, Object?>{},
      const <String, Object?>{'name': ' Night Market'},
      const <String, Object?>{'name': 'Night\u202eMarket'},
      const <String, Object?>{'name': 7},
    ]) {
      expect(
        resolveLoopGroupConversationLabel(data),
        loopGroupConversationNeutralLabel,
      );
    }
  });

  testWidgets(
    'official default message item shows the group Alias in channel and thread layouts',
    (tester) async {
      final channelHarness = _ChannelHarness.group(
        member: _member(
          userId: 'stream-sender',
          accountName: 'Leaked Account Name',
          extraData: _validProjection('Night Owl'),
        ),
      );
      addTearDown(channelHarness.dispose);

      await _pumpMessage(
        tester,
        harness: channelHarness,
        listKind: StreamMessageListKind.channel,
      );

      expect(find.byType(DefaultStreamMessageItem), findsOneWidget);
      expect(_renderedMessage(tester).user?.name, 'Night Owl');
      expect(find.text('Leaked Account Name'), findsNothing);
      expect(find.text('stream-sender'), findsNothing);

      await _pumpMessage(
        tester,
        harness: channelHarness,
        listKind: StreamMessageListKind.thread,
      );

      expect(find.byType(DefaultStreamMessageItem), findsOneWidget);
      expect(_renderedMessage(tester).user?.name, 'Night Owl');
      expect(find.text('Leaked Account Name'), findsNothing);
      await _disposeHarness(tester, channelHarness);
    },
  );

  testWidgets('missing projection renders the neutral group-member label', (
    tester,
  ) async {
    final channelHarness = _ChannelHarness.group(
      member: _member(
        userId: 'stream-secret-id',
        accountName: 'Secret Account Name',
      ),
      senderId: 'stream-secret-id',
    );
    addTearDown(channelHarness.dispose);

    await _pumpMessage(tester, harness: channelHarness);

    expect(find.text(loopGroupMemberNeutralLabel), findsOneWidget);
    expect(find.text('Secret Account Name'), findsNothing);
    expect(find.text('stream-secret-id'), findsNothing);
    await _disposeHarness(tester, channelHarness);
  });

  testWidgets('current member projection updates the mounted default item', (
    tester,
  ) async {
    final channelHarness = _ChannelHarness.group(
      member: _member(
        userId: 'stream-sender',
        accountName: 'Leaked Account Name',
      ),
    );
    addTearDown(channelHarness.dispose);

    await _pumpMessage(tester, harness: channelHarness);
    expect(find.text(loopGroupMemberNeutralLabel), findsOneWidget);

    channelHarness.channel.state!.updateChannelState(
      channelHarness.channel.state!.channelState.copyWith(
        members: <Member>[
          _member(
            userId: 'stream-sender',
            accountName: 'Leaked Account Name',
            extraData: _validProjection('Projected Owl'),
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(_renderedMessage(tester).user?.name, 'Projected Owl');
    expect(find.text(loopGroupMemberNeutralLabel), findsNothing);
    expect(find.text('Leaked Account Name'), findsNothing);
    await _disposeHarness(tester, channelHarness);
  });

  testWidgets('known direct channel keeps the official Stream sender name', (
    tester,
  ) async {
    final channelHarness = _ChannelHarness.direct(
      member: _member(
        userId: 'direct-sender',
        accountName: 'Direct Friend',
        extraData: _validProjection('Must Not Apply'),
      ),
      senderId: 'direct-sender',
    );
    addTearDown(channelHarness.dispose);

    await _pumpMessage(tester, harness: channelHarness);

    expect(find.byType(DefaultStreamMessageItem), findsOneWidget);
    expect(find.text('Direct Friend'), findsOneWidget);
    expect(find.text('Must Not Apply'), findsNothing);
    expect(find.text(loopGroupMemberNeutralLabel), findsNothing);
    await _disposeHarness(tester, channelHarness);
  });

  testWidgets(
    'group user mention candidates are hidden and cannot be selected',
    (tester) async {
      var selected = false;
      final channelHarness = _ChannelHarness.group(
        member: _projectedMember(
          'stream-sender',
          'Leaked Mention Candidate',
          'Mention Owl',
        ),
      );
      addTearDown(channelHarness.dispose);

      await _pumpInChannel(
        tester,
        harness: channelHarness,
        child: StreamMentionItem.fromProps(
          props: StreamMentionItemProps(
            mention: StreamUserMention(
              user: User(id: 'stream-sender', name: 'Leaked Mention Candidate'),
            ),
            onTap: () => selected = true,
          ),
        ),
      );

      expect(find.text('Leaked Mention Candidate'), findsNothing);
      expect(find.text('Mention Owl'), findsNothing);
      expect(find.byType(DefaultStreamMentionItem), findsNothing);
      expect(selected, isFalse);
      await _disposeHarness(tester, channelHarness);
    },
  );

  testWidgets(
    'direct user mention candidates retain official Stream behavior',
    (tester) async {
      var selected = false;
      final channelHarness = _ChannelHarness.direct(
        member: _member(userId: 'direct-sender', accountName: 'Direct Friend'),
        senderId: 'direct-sender',
      );
      addTearDown(channelHarness.dispose);

      await _pumpInChannel(
        tester,
        harness: channelHarness,
        child: StreamMentionItem.fromProps(
          props: StreamMentionItemProps(
            mention: StreamUserMention(
              user: User(id: 'direct-sender', name: 'Direct Friend'),
            ),
            onTap: () => selected = true,
          ),
        ),
      );

      expect(find.text('Direct Friend'), findsOneWidget);
      await tester.tap(find.byType(DefaultStreamMentionItem));
      expect(selected, isTrue);
      await _disposeHarness(tester, channelHarness);
    },
  );

  testWidgets('group channel chrome hides stock typing and global identities', (
    tester,
  ) async {
    final channelHarness = _ChannelHarness.group(
      member: _projectedMember(
        'stream-sender',
        'Leaked Account Name',
        'Night Owl',
      ),
      channelName: 'Night Market',
    );
    addTearDown(channelHarness.dispose);

    await _pumpInChannel(
      tester,
      harness: channelHarness,
      child: const Scaffold(appBar: LoopStreamGroupChannelHeader()),
    );

    expect(find.text('Night Market'), findsOneWidget);
    expect(find.text('Leaked Account Name'), findsNothing);
    expect(find.text('stream-sender'), findsNothing);
    expect(find.byType(StreamTypingIndicator), findsNothing);
    expect(find.byType(StreamChannelAvatar), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('loop-group-channel-neutral-avatar')),
      findsOneWidget,
    );
    await _disposeHarness(tester, channelHarness);
  });

  testWidgets(
    'group list cell sanitizes preview and avatar while direct keeps default item',
    (tester) async {
      var tapped = false;
      final channelHarness = _ChannelHarness.group(
        member: _projectedMember(
          'stream-sender',
          'Leaked Account Name',
          'Night Owl',
        ),
        channelName: 'Night Market',
        messageText: 'hello @stream-sender',
        mentionedUsers: <User>[
          User(id: 'stream-sender', name: 'Leaked Account Name'),
        ],
      );
      addTearDown(channelHarness.dispose);
      final defaultItem = StreamChannelListItem(
        channel: channelHarness.channel,
        onTap: () => tapped = true,
      );

      await _pumpInChannel(
        tester,
        harness: channelHarness,
        child: loopStreamChannelListIdentityItem(defaultItem),
      );

      expect(find.text('Night Market'), findsOneWidget);
      expect(find.textContaining('@Night Owl'), findsOneWidget);
      expect(find.text('Leaked Account Name'), findsNothing);
      expect(find.textContaining('stream-sender'), findsNothing);
      expect(find.byType(StreamChannelAvatar), findsNothing);
      expect(find.byType(StreamTypingIndicator), findsNothing);
      await tester.tap(find.byType(StreamChannelListTile));
      expect(tapped, isTrue);

      final directHarness = _ChannelHarness.direct(
        member: _member(userId: 'direct-sender', accountName: 'Direct Friend'),
        senderId: 'direct-sender',
      );
      addTearDown(directHarness.dispose);
      final directDefault = StreamChannelListItem(
        channel: directHarness.channel,
      );
      expect(
        identical(
          loopStreamChannelListIdentityItem(directDefault),
          directDefault,
        ),
        isTrue,
      );

      directHarness.dispose();
      await _disposeHarness(tester, channelHarness);
    },
  );
}

Map<String, Object?> _validProjection(String alias) => <String, Object?>{
  'loop_group_alias_id': _aliasId,
  'loop_group_alias': alias,
  'loop_group_alias_version': 1,
};

Member _member({
  required String userId,
  required String accountName,
  Map<String, Object?> extraData = const <String, Object?>{},
}) => Member(
  userId: userId,
  user: User(id: userId, name: accountName),
  extraData: extraData,
);

Member _projectedMember(String userId, String accountName, String alias) =>
    _member(
      userId: userId,
      accountName: accountName,
      extraData: _validProjection(alias),
    );

Future<void> _pumpMessage(
  WidgetTester tester, {
  required _ChannelHarness harness,
  StreamMessageListKind listKind = StreamMessageListKind.channel,
}) async {
  await _pumpInChannel(
    tester,
    harness: harness,
    child: StreamMessageLayout(
      data: StreamMessageLayoutData(listKind: listKind),
      child: StreamMessageItem(message: harness.message, onMessageTap: (_) {}),
    ),
  );
}

Future<void> _pumpInChannel(
  WidgetTester tester, {
  required _ChannelHarness harness,
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StreamChat(
        client: harness.client,
        componentBuilders: StreamComponentBuilders(
          extensions: streamChatComponentBuilders(
            messageItem: loopStreamGroupMessageItemBuilder,
            mentionItem: loopStreamGroupMentionItemBuilder,
          ),
        ),
        child: StreamChannel.value(
          channel: harness.channel,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _disposeHarness(
  WidgetTester tester,
  _ChannelHarness harness,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  harness.dispose();
}

Message _renderedMessage(WidgetTester tester) => tester
    .widget<DefaultStreamMessageItem>(find.byType(DefaultStreamMessageItem))
    .props
    .message;

final class _ChannelHarness {
  _ChannelHarness._({
    required this.client,
    required this.channel,
    required this.message,
  });

  factory _ChannelHarness.group({
    required Member member,
    String senderId = 'stream-sender',
    String? channelName,
    String messageText = 'Hello from LOOP',
    List<User> mentionedUsers = const <User>[],
  }) => _ChannelHarness._create(
    channelId: 'loop_group_8e7d73c5',
    member: member,
    senderId: senderId,
    channelName: channelName,
    messageText: messageText,
    mentionedUsers: mentionedUsers,
  );

  factory _ChannelHarness.direct({
    required Member member,
    required String senderId,
  }) => _ChannelHarness._create(
    channelId: 'loop_direct_8e7d73c5',
    member: member,
    senderId: senderId,
  );

  factory _ChannelHarness._create({
    required String channelId,
    required Member member,
    required String senderId,
    String? channelName,
    String messageText = 'Hello from LOOP',
    List<User> mentionedUsers = const <User>[],
  }) {
    final client = StreamChatClient(
      'public-stream-api-key',
      logLevel: Level.OFF,
    );
    final message = Message(
      id: 'message-1',
      text: messageText,
      user: member.user?.copyWith(id: senderId),
      mentionedUsers: mentionedUsers,
      createdAt: DateTime.utc(2026, 8, 31, 12),
      state: MessageState.sent,
    );
    final channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: channelId,
          type: 'messaging',
          memberCount: 3,
          extraData: channelName == null
              ? const <String, Object?>{}
              : <String, Object?>{'name': channelName},
        ),
        members: <Member>[member],
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
