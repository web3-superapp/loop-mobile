import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_screen.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/features/chat/v2/community_chat_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_display_identity.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';

const _senderId = 'loop_0123456789abcdef0123456789abcd01';
const _readerId = 'loop_0123456789abcdef0123456789abcd02';
const _profileId = '7d1c5f64-5717-4562-b3fc-2c963f66a001';
const _image =
    'https://api.test/v2/media/0c6b1f3e-6a51-4a2d-9b7e-3f1c2d4e5a6b.webp';

User _realUser({bool withProfile = true}) => User(
  id: _senderId,
  name: 'frog_maxi',
  image: _image,
  extraData: <String, Object?>{if (withProfile) 'publicProfileId': _profileId},
);

final class _Harness {
  _Harness({required String channelId, required User sender}) {
    client = StreamChatClient('public-stream-api-key', logLevel: Level.OFF);
    message = Message(
      id: 'message-1',
      text: '早上好',
      user: sender,
      createdAt: DateTime.utc(2026, 10, 8, 4),
      state: MessageState.sent,
    );
    channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(id: channelId, type: 'messaging', memberCount: 2),
        members: <Member>[
          Member(userId: sender.id, user: sender),
          Member(
            userId: _readerId,
            user: User(id: _readerId, name: 'reader'),
          ),
        ],
        messages: <Message>[message],
      ),
    );
  }

  late final StreamChatClient client;
  late final Channel channel;
  late final Message message;

  void dispose() => channel.dispose();
}

Future<void> _pump(
  WidgetTester tester,
  _Harness harness, {
  LoopFeatureSwitchValues switches = const LoopFeatureSwitchValues(),
  void Function(String)? onOpenProfile,
}) async {
  Widget body = Scaffold(
    body: SingleChildScrollView(
      child: StreamMessageLayout(
        data: const StreamMessageLayoutData(
          channelKind: StreamMessageChannelKind.group,
        ),
        child: StreamMessageItem(message: harness.message),
      ),
    ),
  );
  if (onOpenProfile != null) {
    body = LoopChatAvatarTapScope(onOpenProfile: onOpenProfile, child: body);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [loopFeatureSwitchesProvider.overrideWithValue(switches)],
      child: MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<Object?>>[
          LoopStreamChatLocalizationsDelegate(),
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        theme: LoopTheme.dark.copyWith(
          extensions: [
            ...LoopTheme.dark.extensions.values,
            loopStreamTheme(platform: LoopTheme.dark.platform),
          ],
        ),
        home: StreamChat(
          client: harness.client,
          themeData: loopStreamChatThemeData(),
          componentBuilders: StreamComponentBuilders(
            messageText: loopStreamMessageTextBuilder,
            extensions: streamChatComponentBuilders(
              messageItem: loopStreamGroupMessageItemBuilder,
              messageLeading: loopStreamMessageLeadingBuilder,
              messageHeader: loopStreamMessageHeaderBuilder,
              messageFooter: loopStreamMessageFooterBuilder,
            ),
          ),
          child: StreamChannel.value(channel: harness.channel, child: body),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  loopWatchGround();
  setUp(() {
    debugLoopRemoteAvatarImageProvider = (url) => MemoryImage(Uint8List(0));
  });
  tearDown(() => debugLoopRemoteAvatarImageProvider = null);

  group('switches (decision 0112)', () {
    test('defaults: real identity in community rooms and small groups', () {
      const values = LoopFeatureSwitchValues();
      expect(LoopFeatureSwitches.communityChatRealIdentity, isTrue);
      expect(LoopFeatureSwitches.groupAliasVisible, isFalse);
      expect(LoopFeatureSwitches.anonymousModeVisible, isFalse);
      expect(values.realIdentityFor(communityChannel: true), isTrue);
      expect(values.realIdentityFor(communityChannel: false), isTrue);
    });

    test('turned back: persona in community rooms, Alias in groups', () {
      const values = LoopFeatureSwitchValues(
        groupAliasVisible: true,
        communityChatRealIdentity: false,
      );
      expect(values.realIdentityFor(communityChannel: true), isFalse);
      expect(values.realIdentityFor(communityChannel: false), isFalse);
    });

    test('the persona line is drawn only when real identity is off', () {
      const persona = CommunityChatPersona(
        alias: 'Harbor-4821',
        projectionState: CommunityChatPersonaProjection.confirmed,
      );
      expect(communityChatHeaderSegments(persona, realIdentity: true), isEmpty);
      expect(
        communityChatHeaderSegments(persona, realIdentity: false),
        <String>['你在这个社区显示为 Harbor-4821'],
      );
    });
  });

  group('Stream real identity', () {
    test('a name equal to the id, or no name, is not a name', () {
      expect(loopStreamRealIdentityOf(User(id: _senderId)), isNull);
      expect(
        loopStreamRealIdentityOf(User(id: _senderId, name: _senderId)),
        isNull,
      );
      final real = loopStreamRealIdentityOf(_realUser())!;
      expect(real.name, 'frog_maxi');
      expect(real.imageUrl, _image);
      expect(real.publicProfileId, _profileId);
    });

    test('an image the client will not fetch is dropped', () {
      final real = loopStreamRealIdentityOf(
        User(id: _senderId, name: 'frog', image: 'http://evil.test/a.png'),
      )!;
      expect(real.imageUrl, isNull);
      final badProfile = loopStreamRealIdentityOf(
        User(
          id: _senderId,
          name: 'frog',
          extraData: const <String, Object?>{'publicProfileId': 'LOOP-1'},
        ),
      )!;
      expect(badProfile.publicProfileId, isNull);
    });

    test('a group with the Alias hidden names members by their account', () {
      final members = <Member>[Member(userId: _senderId, user: _realUser())];
      expect(
        resolveLoopGroupMessageSenderLabel(
          senderUserId: _senderId,
          members: members,
          realIdentity: true,
        ),
        'frog_maxi',
      );
      expect(
        resolveLoopGroupMessageSenderLabel(
          senderUserId: _senderId,
          members: members,
        ),
        loopGroupMemberNeutralLabel,
      );
    });
  });

  group('a community room in real-identity mode', () {
    testWidgets('names the sender, draws their picture and opens their '
        'profile', (tester) async {
      final harness = _Harness(
        channelId: 'loop_community_0123456789abcdef0123456789abcdef',
        sender: _realUser(),
      );
      final opened = <String>[];
      await _pump(tester, harness, onOpenProfile: opened.add);

      expect(find.text('frog_maxi'), findsOneWidget);
      expect(find.byType(LoopRemoteAvatar), findsWidgets);
      // Stream lays its own (hidden) leading out in the reserved gutter; the
      // one LOOP paints over it is the last in paint order.
      await tester.tap(
        find
            .byKey(const ValueKey<String>('loop-message-avatar-open-profile'))
            .last,
      );
      expect(opened, <String>[_profileId]);
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
    });

    testWidgets('an account Stream carries no profile for is not a link', (
      tester,
    ) async {
      final harness = _Harness(
        channelId: 'loop_community_0123456789abcdef0123456789abcdef',
        sender: _realUser(withProfile: false),
      );
      await _pump(tester, harness, onOpenProfile: (_) {});
      expect(find.text('frog_maxi'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-message-avatar-open-profile')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
    });

    testWidgets('with the switch turned back the account name stays hidden', (
      tester,
    ) async {
      final harness = _Harness(
        channelId: 'loop_community_0123456789abcdef0123456789abcdef',
        sender: _realUser(),
      );
      await _pump(
        tester,
        harness,
        switches: const LoopFeatureSwitchValues(
          groupAliasVisible: true,
          communityChatRealIdentity: false,
        ),
        onOpenProfile: (_) {},
      );
      expect(find.text('frog_maxi'), findsNothing);
      expect(find.text(loopGroupMemberNeutralLabel), findsWidgets);
      expect(find.byType(LoopRemoteAvatar), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      harness.dispose();
    });
  });

  group('merged image (decision 0112)', () {
    testWidgets('a real-identity row carries the sender; the rest stay '
        'anonymous', (tester) async {
      await pumpCommunityPage(
        tester,
        const ChatMergePreviewScreen(),
        selectedForward: <ChatForwardMessage>[
          ChatForwardMessage(
            messageId: 'a',
            text: '第一条',
            createdAt: DateTime.utc(2026, 10, 8, 4),
            forwardable: true,
            senderName: 'frog_maxi',
          ),
          ChatForwardMessage(
            messageId: 'b',
            text: '第二条',
            createdAt: DateTime.utc(2026, 10, 8, 4, 1),
            forwardable: true,
          ),
        ],
      );
      expect(find.text('frog_maxi'), findsOneWidget);
      expect(find.text(chatMergeAnonymousLabel), findsOneWidget);
      expect(find.text('显示发送者用户名'), findsOneWidget);
    });
  });

  group('group Alias hidden (groupAliasVisible = false)', () {
    testWidgets('the Alias pages say so and ask nothing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: const GroupAliasRoutePage(
              routeGroupId: '4f1c5f64-5717-4562-b3fc-2c963f66a00a',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('group-alias-paused')),
        findsOneWidget,
      );
    });
  });
}
