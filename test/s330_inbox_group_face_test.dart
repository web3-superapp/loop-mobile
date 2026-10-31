import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/chat/widgets/chat_components.dart';
import 'package:loop_mobile/features/chat/widgets/group_mosaic_avatar.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_faces.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/legacy_chat_identity.dart';

const String _communityHex = '11111111222233334444555555555555';
const String _communityId = '11111111-2222-3333-4444-555555555555';

const Map<String, CommunityFace> _faces = <String, CommunityFace>{
  _communityId: CommunityFace(
    name: 'DeFi 早读会',
    logoRef: 'avatar:preset/community-03',
    description: '每周一起读 DeFi。欢迎新人',
  ),
};

Channel _channel(
  StreamChatClient client,
  String channelId, {
  required List<Member> members,
  String? name,
}) => Channel.fromState(
  client,
  ChannelState(
    channel: ChannelModel(
      id: channelId,
      type: 'messaging',
      memberCount: members.length,
      extraData: name == null
          ? const <String, Object?>{}
          : <String, Object?>{'name': name},
    ),
    members: members,
    messages: <Message>[
      Message(
        id: 'message-$channelId',
        text: '晚点聊',
        user: members.first.user,
        createdAt: DateTime.utc(2026, 10, 31, 12),
        state: MessageState.sent,
      ),
    ],
  ),
);

Member _member(String id, {String? image}) => Member(
  userId: id,
  createdAt: DateTime.utc(2026, 10, 1, 0, id.hashCode % 50),
  user: User(id: id, name: 'Account $id', image: image),
);

Future<void> _pumpRow(
  WidgetTester tester, {
  required StreamChatClient client,
  required Channel channel,
  LoopDirectChannelDirectory? directory,
}) async {
  Widget body = Scaffold(
    body: loopStreamChannelListIdentityItem(
      StreamChannelListItem(channel: channel),
    ),
  );
  body = CommunityFacesScope(faces: _faces, child: body);
  if (directory != null) {
    body = LoopDirectChannelDirectoryScope(directory: directory, child: body);
  }
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
        child: StreamChannel.value(channel: channel, child: body),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _dispose(WidgetTester tester, Channel channel) async {
  await tester.pumpWidget(const SizedBox.shrink());
  channel.dispose();
}

void main() {
  setUp(debugResetGroupMosaicCache);

  test('the list face is 48 with a corner no wider than a quarter', () {
    expect(chatListAvatarSize, 48);
    expect(chatListAvatarRadius, lessThanOrEqualTo(chatListAvatarSize / 4));
  });

  testWidgets(
    'a community row with a logo draws the member mosaic at 48, no logo',
    (tester) async {
      final client = StreamChatClient('public-stream-api-key');
      final channel = _channel(
        client,
        'loop_community_$_communityHex',
        name: 'DeFi 早读会',
        members: <Member>[
          _member('loop_a', image: 'https://media.example/a.png'),
          _member('loop_b', image: 'https://media.example/b.png'),
          _member('loop_c'),
        ],
      );
      addTearDown(channel.dispose);
      await _pumpRow(tester, client: client, channel: channel);

      expect(find.byType(GroupMosaicAvatar), findsOneWidget);
      expect(find.byType(CommunityLogo), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('loop-community-channel-logo')),
        findsNothing,
      );
      expect(
        tester.getSize(find.byType(GroupMosaicAvatar)),
        const Size.square(48),
      );
      // Decision 0112: an alias room's mosaic draws no member picture.
      expect(find.byType(LoopRemoteAvatar), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('group-mosaic-cell-2')),
        findsOneWidget,
      );

      // The face and the two text lines share one centre line.
      final face = tester.getCenter(find.byType(GroupMosaicAvatar)).dy;
      final top = tester.getTopLeft(find.text('DeFi 早读会')).dy;
      final bottom = tester.getBottomLeft(find.textContaining('晚点聊')).dy;
      expect(face, closeTo((top + bottom) / 2, 1.5));
      // 4 + 12 insets around the 48 face: the loading rows' own pitch.
      expect(tester.getSize(find.byType(StreamChannelListTile)).height, 80);
      await _dispose(tester, channel);
    },
  );

  testWidgets('a direct row stays a 48 circle', (tester) async {
    final client = StreamChatClient('public-stream-api-key');
    final channel = _channel(
      client,
      'loop_direct_8e7d73c5',
      members: <Member>[_member('loop_peer')],
    );
    addTearDown(channel.dispose);
    await _pumpRow(
      tester,
      client: client,
      channel: channel,
      directory: LoopDirectChannelDirectory.fromEntries(<DirectChannelEntry>[
        DirectChannelEntry(
          streamCid: channel.cid!,
          peer: const LoopPublicProfile(
            publicProfileId: '7e25420e-d7ca-46b1-9a2f-3c4d5e6f7a8b',
            loopId: 'LOOP-2T6JZTG8',
            alias: 'Voyager_09',
            avatarRef: null,
          ),
          createdAt: DateTime.utc(2026, 9, 20, 6, 45),
        ),
      ]),
    );

    final avatar = find.byKey(
      const ValueKey<String>('loop-direct-channel-avatar'),
    );
    expect(avatar, findsOneWidget);
    expect(tester.widget<LoopInitialsAvatar>(avatar).shape, BoxShape.circle);
    expect(tester.getSize(avatar), const Size.square(48));
    expect(find.byType(GroupMosaicAvatar), findsNothing);
    await _dispose(tester, channel);
  });

  testWidgets('preview rows: direct a 48 ChatAvatar circle, group the mosaic', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              ConversationRow(
                conversation: const ConversationSummary(
                  id: 'd',
                  title: 'Night Owl',
                  preview: 'hi',
                  timeLabel: '10:00',
                  kind: ConversationKind.direct,
                ),
                onTap: () {},
              ),
              ConversationRow(
                conversation: const ConversationSummary(
                  id: 'g',
                  title: 'Glyph Hunters',
                  preview: 'gm',
                  timeLabel: '10:00',
                  kind: ConversationKind.group,
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(ChatAvatar)), const Size.square(48));
    expect(
      tester.getSize(find.byType(GroupMosaicAvatar)),
      const Size.square(48),
    );
    expect(find.byType(CommunityLogo), findsNothing);
  });

  testWidgets('a community forward target with a logo wears the mosaic', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => chatForwardTargetFace(
              context,
              const ChatForwardTarget(
                cid: 'messaging:loop_community_$_communityHex',
                label: 'DeFi 早读会',
                detail: '社区官方群',
              ),
              faces: _faces,
              size: chatListAvatarSize,
              radius: chatListAvatarRadius,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(GroupMosaicAvatar), findsOneWidget);
    expect(find.byType(CommunityLogo), findsNothing);
    expect(
      tester.getSize(find.byType(GroupMosaicAvatar)),
      const Size.square(48),
    );
  });
}
