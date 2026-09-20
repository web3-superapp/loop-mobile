import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_display_identity.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Real-device report 2026-09-19 · F5.
///
/// LOOP publishes no profile facts to Stream, so every account arrives with an
/// empty `name` and the SDK answers `User.name` with `User.id` — `loop_` plus
/// the LOOP row key, the same string in all twenty of an account's rooms. The
/// name above a bubble is the label the channel resolved for that member and
/// nothing else; a member with no label is not named, and neither id nor
/// account name is ever a fallback.
const String _internalId = 'loop_3bb585972e3145e7b5f0957803a824ed';
const String _persona = '夜航员';

Member _member({Map<String, Object?> extraData = const <String, Object?>{}}) =>
    Member(
      userId: _internalId,
      // What Stream really carries: an id and nothing else.
      user: User(id: _internalId),
      extraData: extraData,
    );

Map<String, Object?> _projection(String alias) => <String, Object?>{
  'loop_group_alias_id': 'bb5e12c2-40e2-4577-9951-57fac0b5ce5e',
  'loop_group_alias': alias,
  'loop_group_alias_version': 1,
};

final class _Harness {
  _Harness._({required this.client, required this.channel, required this.user});

  /// A community's official group. Its channel id is assigned by the backend;
  /// the member projection is what the community's persona lands in.
  factory _Harness.community({
    Map<String, Object?> memberExtraData = const <String, Object?>{},
    User? sender,
  }) => _Harness._create(
    channelId: 'loop_community_99565a0c2e3145e7b5f0957803a824ed',
    memberExtraData: memberExtraData,
    sender: sender,
  );

  factory _Harness.direct() =>
      _Harness._create(channelId: 'loop_direct_99565a0c2e3145e7b5f0957803a8');

  factory _Harness._create({
    required String channelId,
    Map<String, Object?> memberExtraData = const <String, Object?>{},
    User? sender,
  }) {
    final client = StreamChatClient('public-key', logLevel: Level.OFF);
    final user = sender ?? User(id: _internalId);
    final message = Message(
      id: 'message-1',
      text: '今晚的盘面',
      user: user,
      createdAt: DateTime.utc(2026, 9, 19, 12),
      state: MessageState.sent,
    );
    final channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: channelId,
          type: 'messaging',
          memberCount: 25,
        ),
        members: <Member>[_member(extraData: memberExtraData)],
        messages: <Message>[message],
      ),
    );
    return _Harness._(client: client, channel: channel, user: user);
  }

  final StreamChatClient client;
  final Channel channel;
  final User user;

  Message get message => channel.state!.channelState.messages!.single;
}

/// The builder set `lib/app.dart` installs, restated for a single row.
StreamComponentBuilders _builders() => StreamComponentBuilders(
  messageText: loopStreamMessageTextBuilder,
  extensions: streamChatComponentBuilders(
    messageItem: loopStreamGroupMessageItemBuilder,
    mentionItem: loopStreamGroupMentionItemBuilder,
    messageFooter: loopStreamMessageFooterBuilder,
    messageHeader: loopStreamMessageHeaderBuilder,
  ),
);

Future<void> _pump(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark.copyWith(
        extensions: <ThemeExtension<Object?>>[
          ...LoopTheme.dark.extensions.values,
          loopStreamTheme(platform: LoopTheme.dark.platform),
        ],
      ),
      home: StreamChat(
        client: harness.client,
        themeData: loopStreamChatThemeData(),
        componentBuilders: _builders(),
        child: StreamChannel.value(
          channel: harness.channel,
          child: Scaffold(
            body: SingleChildScrollView(
              child: StreamMessageItem(message: harness.message),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(const SizedBox.shrink());
  harness.channel.dispose();
}

void main() {
  group('the name over a bubble is the one this channel resolved', () {
    testWidgets('a projected persona is what the room reads', (tester) async {
      final harness = _Harness.community(
        memberExtraData: _projection(_persona),
      );
      await _pump(tester, harness);

      expect(find.text(_persona), findsOneWidget);
      expect(find.textContaining(_internalId), findsNothing);
      expect(find.textContaining('loop_3bb58597'), findsNothing);
      await _unmount(tester, harness);
    });

    testWidgets('no projection yet reads as the neutral member label', (
      tester,
    ) async {
      final harness = _Harness.community();
      await _pump(tester, harness);

      expect(find.text(loopGroupMemberNeutralLabel), findsOneWidget);
      expect(find.textContaining(_internalId), findsNothing);
      expect(find.textContaining('loop_3bb58597'), findsNothing);
      await _unmount(tester, harness);
    });

    testWidgets('a Stream account name is not a fallback either', (
      tester,
    ) async {
      // Should Stream ever carry an account-level name, it is still an
      // account fact and still the same string in every room.
      final harness = _Harness.community(
        sender: User(id: _internalId, name: 'Leaked Account Name'),
      );
      await _pump(tester, harness);

      expect(find.text('Leaked Account Name'), findsNothing);
      expect(find.text(loopGroupMemberNeutralLabel), findsOneWidget);
      await _unmount(tester, harness);
    });

    testWidgets('a direct bubble carries no sender name at all', (
      tester,
    ) async {
      // A direct channel has no group namespace to resolve a label in, and
      // the page's own header already says who the conversation is with. What
      // it must not do is print the internal id in its place.
      final harness = _Harness.direct();
      await _pump(tester, harness);

      expect(find.text('今晚的盘面'), findsOneWidget);
      expect(find.textContaining(_internalId), findsNothing);
      expect(find.textContaining('loop_3bb58597'), findsNothing);
      expect(find.text(loopGroupMemberNeutralLabel), findsNothing);
      await _unmount(tester, harness);
    });
  });

  group('a display label is written by LOOP and read back by LOOP', () {
    test('an unlabelled user has no name to print', () {
      expect(loopStreamDisplayLabelOf(User(id: _internalId)), isNull);
      expect(
        loopStreamDisplayLabelOf(User(id: _internalId, name: 'Account Name')),
        isNull,
      );
      expect(loopStreamDisplayLabelOf(null), isNull);
    });

    test('a labelled user answers with the label, not the id', () {
      final user = loopStreamDisplayUser(id: _internalId, label: _persona);
      expect(loopStreamDisplayLabelOf(user), _persona);
      expect(user.id, _internalId, reason: 'Stream still routes on the id');
    });

    test('an empty or blank label is no label', () {
      expect(
        loopStreamDisplayLabelOf(
          User(
            id: _internalId,
            extraData: const <String, Object?>{loopStreamDisplayLabelField: ''},
          ),
        ),
        isNull,
      );
      expect(
        loopStreamDisplayLabelOf(
          User(
            id: _internalId,
            extraData: const <String, Object?>{
              loopStreamDisplayLabelField: '   ',
            },
          ),
        ),
        isNull,
      );
    });
  });
}
