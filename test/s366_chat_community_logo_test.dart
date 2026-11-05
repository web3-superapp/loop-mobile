import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/chat/widgets/group_mosaic_avatar.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_faces.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/legacy_chat_identity.dart';

// S366 · decision 0290 (需求方 11-05 #4): a community conversation row wears
// its community's own logo as a 48 rounded square (corner 12); a direct row
// stays a circle; a group that is not a community keeps its members' mosaic.

const String _communityHex = '11111111222233334444555555555555';
const String _communityId = '11111111-2222-3333-4444-555555555555';
const String _groupHex = 'aaaaaaaabbbbccccddddeeeeeeeeeeee';

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
        createdAt: DateTime.utc(2026, 11, 5, 12),
        state: MessageState.sent,
      ),
    ],
  ),
);

Member _member(String id) => Member(
  userId: id,
  createdAt: DateTime.utc(2026, 10, 1, 0, id.hashCode % 50),
  user: User(id: id, name: 'Account $id'),
);

List<Member> _three() => <Member>[
  _member('loop_a'),
  _member('loop_b'),
  _member('loop_c'),
];

Future<void> _pumpRow(
  WidgetTester tester, {
  required StreamChatClient client,
  required Channel channel,
  Map<String, CommunityFace> faces = const <String, CommunityFace>{},
  LoopDirectChannelDirectory? directory,
}) async {
  Widget body = Scaffold(
    body: loopStreamChannelListIdentityItem(
      StreamChannelListItem(channel: channel),
    ),
  );
  body = CommunityFacesScope(faces: faces, child: body);
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

BorderRadius? _clipRadius(WidgetTester tester) {
  final clip = tester.widget<ClipRRect>(
    find
        .descendant(
          of: find.byKey(const ValueKey<String>('group-mosaic-logo')),
          matching: find.byType(ClipRRect),
        )
        .first,
  );
  return clip.borderRadius as BorderRadius?;
}

void main() {
  setUp(debugResetGroupMosaicCache);

  testWidgets('a community row with a preset logo: 48 rounded square, 12', (
    tester,
  ) async {
    final client = StreamChatClient('public-stream-api-key');
    final channel = _channel(
      client,
      'loop_community_$_communityHex',
      name: 'DeFi 早读会',
      members: _three(),
    );
    addTearDown(channel.dispose);
    await _pumpRow(
      tester,
      client: client,
      channel: channel,
      faces: const <String, CommunityFace>{
        _communityId: CommunityFace(
          name: 'DeFi 早读会',
          logoRef: 'avatar:preset/community-03',
        ),
      },
    );

    final logo = find.byType(CommunityLogo);
    expect(logo, findsOneWidget);
    final widget = tester.widget<CommunityLogo>(logo);
    expect(widget.identity, _communityId);
    expect(widget.logoRef, 'avatar:preset/community-03');
    expect(widget.size, chatListAvatarSize);
    expect(widget.radius, chatListAvatarRadius);
    expect(chatListAvatarRadius, 12);
    expect(
      find.byKey(
        const ValueKey<String>(
          'community-logo-image-avatar:preset/community-03',
        ),
      ),
      findsOneWidget,
    );
    expect(_clipRadius(tester), BorderRadius.circular(12));
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('loop-community-channel-logo')),
      ),
      const Size.square(48),
    );
    expect(
      find.byKey(const ValueKey<String>('group-mosaic-avatar')),
      findsNothing,
    );
    await _dispose(tester, channel);
  });

  testWidgets('a community row with no logo read: initials, rounded square', (
    tester,
  ) async {
    final client = StreamChatClient('public-stream-api-key');
    final channel = _channel(
      client,
      'loop_community_$_communityHex',
      name: 'DeFi 早读会',
      members: _three(),
    );
    addTearDown(channel.dispose);
    await _pumpRow(tester, client: client, channel: channel);

    expect(find.byType(CommunityLogo), findsOneWidget);
    final tile = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'community-logo-monogram-',
          ),
    );
    expect(tile, findsOneWidget);
    final decoration =
        tester.widget<Container>(tile).decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.rectangle);
    expect(decoration.borderRadius, BorderRadius.circular(12));
    expect(tester.getSize(tile), const Size.square(48));
    expect(
      find.byKey(const ValueKey<String>('group-mosaic-avatar')),
      findsNothing,
    );
    await _dispose(tester, channel);
  });

  testWidgets('a group that is not a community keeps its members mosaic', (
    tester,
  ) async {
    final client = StreamChatClient('public-stream-api-key');
    final channel = _channel(
      client,
      'loop_group_$_groupHex',
      name: 'Glyph Hunters',
      members: _three(),
    );
    addTearDown(channel.dispose);
    await _pumpRow(tester, client: client, channel: channel);

    expect(
      find.byKey(const ValueKey<String>('loop-group-channel-mosaic')),
      findsOneWidget,
    );
    expect(find.byType(CommunityLogo), findsNothing);
    expect(
      tester.getSize(find.byType(GroupMosaicAvatar)),
      const Size.square(48),
    );
    await _dispose(tester, channel);
  });

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
    expect(tester.widget<LoopInitialsAvatar>(avatar).shape, BoxShape.circle);
    expect(tester.getSize(avatar), const Size.square(48));
    expect(find.byType(CommunityLogo), findsNothing);
    expect(find.byType(GroupMosaicAvatar), findsNothing);
    await _dispose(tester, channel);
  });
}
