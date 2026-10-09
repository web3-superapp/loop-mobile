// S112 · the long-press reaction bar carries LOOP's five glyphs (decision
// 0121; words before it) and no 「+」 (decision 0117). Stream's default bar pins a 「+」 that opens the Emoji
// catalogue filtered by `supportedReactions`; LOOP's resolver supports none,
// so the 「+」 opened an empty sheet and is not drawn.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart' show loopStreamChatConfiguration;
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/integrations/communication/loop_reactions.dart';
import 'package:loop_mobile/integrations/communication/loop_stream_reaction_icon_resolver.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_connection.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

const String _cid = 'messaging:loop_group_5e1f0f2e5a7b4c3d8e9f0a1b2c3d4e5f';
const String _directCid =
    'messaging:loop_direct_5e1f0f2e5a7b4c3d8e9f0a1b2c3d4e5f';
const String _me = 'me';

class _Connected implements LoopStreamConnection {
  @override
  bool get isConnected => true;
  @override
  Future<void> open() async {}
}

class _LocalClient extends StreamChatClient {
  _LocalClient() : super('key', logLevel: Level.OFF);

  /// Reactions this client was asked to add or withdraw, as `id:type`.
  final List<String> sent = <String>[];
  final List<String> deleted = <String>[];

  @override
  Future<SendReactionResponse> sendReaction(
    String messageId,
    Reaction reaction, {
    bool skipPush = false,
    bool enforceUnique = false,
  }) async {
    sent.add('$messageId:${reaction.type}');
    return SendReactionResponse();
  }

  @override
  Future<EmptyResponse> deleteReaction(
    String messageId,
    String reactionType,
  ) async {
    deleted.add('$messageId:$reactionType');
    return EmptyResponse();
  }

  @override
  Future<EmptyResponse> markChannelRead(
    String channelId,
    String channelType, {
    String? messageId,
  }) async => EmptyResponse();
}

/// One conversation of three messages in which the member may react; a
/// group unless [cid] names a direct channel. With [reacted], 「消息 2」
/// carries one 「点赞」 from the other member.
final class _Group {
  _Group({
    this.cid = _cid,
    this.reacted = false,
    this.reactedOn = 2,
    this.ownReaction,
  }) {
    // ignore: invalid_use_of_internal_member
    client.state.currentUser = OwnUser(id: _me, name: '我');
    channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: cid.split(':').last,
          type: 'messaging',
          ownCapabilities: const <String>[
            'quote-message',
            'send-message',
            'send-reply',
            'send-reaction',
            'read-events',
          ],
        ),
        membership: Member(userId: _me),
        members: <Member>[
          Member(
            userId: _me,
            user: User(id: _me),
          ),
        ],
        messages: <Message>[
          for (var i = 3; i >= 1; i--)
            Message(
              id: 'm$i',
              text: '消息 $i',
              user: User(id: i.isEven ? _me : 'other', name: '成员'),
              createdAt: DateTime.utc(
                2026,
                10,
                8,
                12,
              ).subtract(Duration(minutes: i)),
              state: MessageState.sent,
              reactionGroups: reacted && i == reactedOn
                  ? <String, ReactionGroup>{
                      'like': ReactionGroup(count: 1, sumScores: 1),
                    }
                  : null,
              latestReactions: reacted && i == reactedOn
                  ? <Reaction>[
                      Reaction(
                        messageId: 'm$i',
                        type: 'like',
                        user: User(id: 'other', name: '成员'),
                      ),
                    ]
                  : null,
              ownReactions: ownReaction != null && i == 2
                  ? <Reaction>[
                      Reaction(
                        messageId: 'm2',
                        type: ownReaction!,
                        userId: _me,
                      ),
                    ]
                  : null,
            ),
        ],
      ),
    );
  }

  final String cid;
  final bool reacted;
  final int reactedOn;
  final String? ownReaction;
  final _LocalClient client = _LocalClient();
  late final Channel channel;

  Future<void> pump(
    WidgetTester tester, {
    required StreamChatConfigurationData config,
    bool loopMessageItems = true,
    bool loopReactions = true,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.record/messages'),
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.llfbandit.record/messages'),
        null,
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark.copyWith(
          extensions: [...LoopTheme.dark.extensions.values, loopStreamTheme()],
        ),
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          LoopStreamChatLocalizationsDelegate(),
        ],
        builder: (context, child) => StreamChat(
          client: client,
          themeData: loopStreamChatThemeData(),
          configData: config,
          // The application's own builder (`lib/app.dart`).
          componentBuilders: StreamComponentBuilders(
            messageText: loopStreamMessageTextBuilder,
            reactionPicker: loopStreamReactionPickerBuilder,
            reactions: loopReactions ? loopStreamReactionsBuilder : null,
            extensions: streamChatComponentBuilders(
              messageItem: loopMessageItems
                  ? loopStreamGroupMessageItemBuilder
                  : null,
            ),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: LoopStreamMemberChannelBody(
            client: client,
            cid: cid,
            userId: _me,
            composerHint: loopChatComposerHint,
            unresolvedMessage: null,
            header: null,
            banner: null,
            footer: null,
            keyPrefix: 'group-channel',
            connection: _Connected(),
            query: () async => <Channel>[channel],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openActions(WidgetTester tester, String text) async {
    await tester.longPressAt(
      tester.getRect(find.text(text)).centerLeft - const Offset(8, 0),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    channel.dispose();
  }
}

void main() {
  group('the long-press reaction bar', () {
    testWidgets('carries the five glyphs and no 「+」', (tester) async {
      final room = _Group();
      await room.pump(tester, config: loopStreamChatConfiguration);
      await room.openActions(tester, '消息 2');

      expect(find.text('回复'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-reaction-bar')),
        findsOneWidget,
      );
      for (final type in <String>['like', 'haha', 'love', 'wow', 'sad']) {
        expect(
          find.byKey(ValueKey<String>('loop-reaction-glyph-$type')),
          findsOneWidget,
          reason: type,
        );
      }
      for (final word in <String>['赞', '哈', '心', '哇', '叹']) {
        expect(find.text(word), findsNothing, reason: word);
      }
      expect(find.byKey(const Key('add_reaction')), findsNothing);
      expect(find.byType(DefaultStreamReactionPicker), findsNothing);
      for (final type in <String>['like', 'haha', 'love', 'wow', 'sad']) {
        expect(
          tester.getSize(find.byKey(Key(type))).height,
          greaterThanOrEqualTo(44),
          reason: type,
        );
      }
      await room.dispose(tester);
    });

    testWidgets('a resolver that supports more keeps Stream\'s 「+」', (
      tester,
    ) async {
      // The control: the same page under Stream's default resolver shows the
      // 「+」, so the assertion above is looking at the real bar.
      final room = _Group();
      await room.pump(tester, config: StreamChatConfigurationData());
      await room.openActions(tester, '消息 2');

      expect(find.byKey(const Key('add_reaction')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-reaction-bar')),
        findsNothing,
      );
      await room.dispose(tester);
    });
  });

  group('a tap on a reaction chip in a direct message', () {
    // Decision 0117: the reaction detail sheet carries a 「+」 onto Stream's
    // Emoji catalogue, which LOOP leaves empty; as in a group, it stays shut.
    testWidgets('opens no detail sheet and no 「+」', (tester) async {
      final room = _Group(cid: _directCid, reacted: true);
      await room.pump(tester, config: loopStreamChatConfiguration);

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-reaction-capsule-like')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ReactionDetailSheet), findsNothing);
      expect(find.byKey(const Key('add_reaction')), findsNothing);
      await room.dispose(tester);
    });

    testWidgets('opens Stream\'s sheet without LOOP\'s message item', (
      tester,
    ) async {
      // The control: Stream's own chip under Stream's own message item opens
      // the sheet, so the sheet is a real thing LOOP keeps shut.
      final room = _Group(cid: _directCid, reacted: true);
      await room.pump(
        tester,
        config: loopStreamChatConfiguration,
        loopMessageItems: false,
        loopReactions: false,
      );

      await tester.tap(find.text('点赞').first);
      await tester.pumpAndSettle();

      expect(find.byType(ReactionDetailSheet), findsOneWidget);
      await room.dispose(tester);
    });
  });

  group('S121a · reactions are glyphs (decision 0121)', () {
    testWidgets('the bar prints no character and lights the own reaction', (
      tester,
    ) async {
      final room = _Group(ownReaction: 'love');
      await room.pump(tester, config: loopStreamChatConfiguration);
      await room.openActions(tester, '消息 2');

      final bar = find.byKey(const ValueKey<String>('loop-reaction-bar'));
      // Not one character is printed inside the bar: no word, no Emoji.
      expect(
        find.descendant(of: bar, matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        find.descendant(of: bar, matching: find.byType(LoopIcon)),
        findsNWidgets(5),
      );
      for (final type in <String>['like', 'haha', 'love', 'wow', 'sad']) {
        final glyph = tester.widget<LoopIcon>(
          find.byKey(ValueKey<String>('loop-reaction-glyph-$type')),
        );
        expect(glyph.size, LoopStreamReactionBar.glyphSize, reason: type);
        expect(glyph.name, loopReactionIconName(type), reason: type);
        expect(
          glyph.color,
          type == 'love' ? LoopColors.lime : LoopColors.chalk,
          reason: type,
        );
        expect(
          File('assets/icons/i-${glyph.name}.svg').existsSync(),
          isTrue,
          reason: type,
        );
      }
      await room.dispose(tester);
    });

    testWidgets('the reader\'s own reaction has a Lime edge and glyph', (
      tester,
    ) async {
      final room = _Group(reacted: true, ownReaction: 'like');
      await room.pump(tester, config: loopStreamChatConfiguration);

      final capsule = find.byKey(
        const ValueKey<String>('loop-reaction-capsule-like'),
      );
      final glyph = tester.widget<LoopIcon>(
        find.descendant(
          of: capsule,
          matching: find.byKey(
            const ValueKey<String>('loop-reaction-glyph-like'),
          ),
        ),
      );
      expect(glyph.color, LoopColors.lime);
      final pill = tester.widget<Container>(
        find.descendant(of: capsule, matching: find.byType(Container)).first,
      );
      final decoration = pill.decoration! as BoxDecoration;
      expect(decoration.color, LoopColors.elevated);
      expect((decoration.border! as Border).top.color, LoopColors.lime);
      final count = tester.widget<Text>(
        find.descendant(of: capsule, matching: find.text('1')),
      );
      expect(count.style?.fontSize, 12);
      await room.dispose(tester);
    });

    testWidgets('a tap on the own capsule withdraws the reaction', (
      tester,
    ) async {
      final room = _Group(reacted: true, ownReaction: 'like');
      await room.pump(tester, config: loopStreamChatConfiguration);

      final target = find.byKey(
        const ValueKey<String>('loop-reaction-capsule-target-like'),
      );
      // 44 to touch, 24 to see.
      expect(tester.getSize(target).height, LoopReactionCapsule.targetHeight);
      final pill = find
          .descendant(
            of: find.byKey(
              const ValueKey<String>('loop-reaction-capsule-like'),
            ),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(pill).height, LoopReactionCapsule.pillHeight);

      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(room.client.deleted, <String>['m2:like']);
      expect(room.client.sent, isEmpty);
      expect(find.byType(ReactionDetailSheet), findsNothing);
      await room.dispose(tester);
    });

    testWidgets('a tap on another member\'s capsule adds the same reaction', (
      tester,
    ) async {
      final room = _Group(reacted: true, reactedOn: 1);
      await room.pump(tester, config: loopStreamChatConfiguration);

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-reaction-capsule-target-like')),
      );
      await tester.pumpAndSettle();
      expect(room.client.sent, <String>['m1:like']);
      expect(room.client.deleted, isEmpty);
      // The channel's own state now carries it: the capsule counts two and
      // lights up as the reader's.
      final capsule = find.byKey(
        const ValueKey<String>('loop-reaction-capsule-like'),
      );
      expect(
        find.descendant(of: capsule, matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<LoopIcon>(
              find.descendant(
                of: capsule,
                matching: find.byKey(
                  const ValueKey<String>('loop-reaction-glyph-like'),
                ),
              ),
            )
            .color,
        LoopColors.lime,
      );
      expect(find.byType(ReactionDetailSheet), findsNothing);
      await room.dispose(tester);
    });

    for (final (label, index) in <(String, int)>[
      ('an incoming bubble', 1),
      ('the member\'s own bubble', 2),
    ]) {
      testWidgets('on $label the capsule sits under it, from its left edge', (
        tester,
      ) async {
        final room = _Group(reacted: true, reactedOn: index);
        await room.pump(tester, config: loopStreamChatConfiguration);

        final capsule = find.byKey(
          const ValueKey<String>('loop-reaction-capsule-like'),
        );
        expect(capsule, findsOneWidget);
        expect(
          find.descendant(of: capsule, matching: find.text('1')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: capsule,
            matching: find.byKey(
              const ValueKey<String>('loop-reaction-glyph-like'),
            ),
          ),
          findsOneWidget,
        );
        final text = tester.getRect(find.text('消息 $index'));
        final chip = tester.getRect(capsule);
        // Below the bubble's text, not over its top corner.
        expect(chip.top, greaterThanOrEqualTo(text.bottom));
        // From the bubble's own leading edge: left of the text, within the
        // bubble's padding, on either side of the conversation.
        expect(chip.left, lessThanOrEqualTo(text.left));
        expect(chip.left, greaterThan(text.left - 24));
        await room.dispose(tester);
      });
    }
  });

  test('the application installs the builders', () {
    final app = File('lib/app.dart').readAsStringSync();
    expect(app, contains('reactionPicker: loopStreamReactionPickerBuilder,'));
    expect(app, contains('reactions: loopStreamReactionsBuilder,'));
  });
}
