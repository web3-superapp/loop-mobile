// 群/社区频道的 `@`（决策 0055 · R13-5）。
//
// 第十三轮真机：群里输入 `@` 一行候选都不出，因为 Stream 自己的候选行只会画
// `user.name`（LOOP 账号为空，回落成 `user.id`＝库主键），所以整行被关掉了
// ——安全，但等于群聊没有 @。频道成员的 member custom 上已经有人格
// （`loop_group_alias`），这份测试把「候选＝人格」这条线钉住：显示的是人格、
// 过滤的是人格、插进输入框的是人格，而 Stream 的 mention 链接仍然带走。
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_display_identity.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

const String _aliasId = 'bb5e12c2-40e2-4577-9951-57fac0b5ce5e';
const String _me = 'loop_3bb585972e3145e7b5f0957803a824ed';
const String _tundra = 'loop_7e25420ed7ca4645b4860b1f9e734dad';
const String _harbor = 'loop_40b0d058f0b94d1c9a8e2f6b1d0c3a55';
const String _unprojected = 'loop_9c1a77e0ab2f43d8bf5e6c0d1e2f3a4b';

/// A ground colour no LOOP token uses, so a pixel near it under the `@` card
/// is proof the card let the conversation through.
const Color _groundColor = Color(0xFFFF00FF);

void main() {
  group('candidate resolution', () {
    test('a candidate is the Alias this channel resolved, never Stream', () {
      final candidates = resolveLoopGroupMentionCandidates(
        members: _roster(),
        query: '',
        currentUserId: _me,
      );

      expect(candidates.map((candidate) => candidate.alias), <String>[
        'Harbor-7001',
        'Tundra-3726',
      ]);
      expect(candidates.map((candidate) => candidate.userId), <String>[
        _harbor,
        _tundra,
      ]);
      // The sender label above a bubble and the candidate row are the same
      // resolution, so the same member reads as the same person.
      expect(
        candidates.first.alias,
        resolveLoopGroupMessageSenderLabel(
          senderUserId: _harbor,
          members: _roster(),
        ),
      );
    });

    test('the query is an Alias prefix, matched without case', () {
      for (final query in <String>['T', 't', 'tUnD', 'Tundra-3726']) {
        expect(
          resolveLoopGroupMentionCandidates(
            members: _roster(),
            query: query,
            currentUserId: _me,
          ).map((candidate) => candidate.alias),
          <String>['Tundra-3726'],
          reason: query,
        );
      }
      // A prefix is a prefix: the middle of an Alias does not match, and
      // neither does any spelling of the Stream id.
      for (final query in <String>['undra', '3726', 'loop_', _tundra]) {
        expect(
          resolveLoopGroupMentionCandidates(
            members: _roster(),
            query: query,
            currentUserId: _me,
          ),
          isEmpty,
          reason: query,
        );
      }
    });

    test('a member with no Alias, and the member themselves, are absent', () {
      final candidates = resolveLoopGroupMentionCandidates(
        members: _roster(),
        query: '',
        currentUserId: _me,
      );

      expect(
        candidates.map((candidate) => candidate.userId),
        isNot(contains(_unprojected)),
      );
      expect(
        candidates.map((candidate) => candidate.userId),
        isNot(contains(_me)),
      );

      // Malformed, future, and ambiguous projections are the same answer as
      // no projection at all: nothing to offer, so no row.
      for (final roster in <List<Member>>[
        <Member>[
          _member(_unprojected, <String, Object?>{
            ..._projection('Night-0001'),
            'loop_group_alias_version': 2,
          }),
        ],
        <Member>[
          _member(_unprojected, _projection('Night-0001')),
          _member(_unprojected, _projection('Other-0002')),
        ],
      ]) {
        expect(
          resolveLoopGroupMentionCandidates(members: roster, query: ''),
          isEmpty,
        );
      }
    });
  });

  test('only a group or community composer installs the Alias trigger', () {
    final group = loopChannelAutocompleteTriggers(
      'messaging:loop_community_5a2f766100000000',
    );
    expect(group.single.trigger, '@');
    expect(
      loopChannelAutocompleteTriggers('messaging:loop_group_8e7d73c5')
          .single
          .trigger,
      '@',
    );
    // A direct channel keeps Stream's own overlay, where the row names the
    // peer from their public profile.
    expect(
      loopChannelAutocompleteTriggers('messaging:loop_direct_8e7d73c5'),
      isEmpty,
    );
    expect(loopChannelAutocompleteTriggers(null), isEmpty);
  });

  testWidgets('a group candidate row shows the Alias and its initial', (
    tester,
  ) async {
    final harness = _ComposerHarness();
    addTearDown(harness.dispose);

    await _pumpComposer(tester, harness);
    await _type(tester, '@');

    expect(find.text('Tundra-3726'), findsOneWidget);
    expect(find.text('Harbor-7001'), findsOneWidget);
    expect(find.textContaining('loop_'), findsNothing);
    expect(find.text(loopGroupMemberNeutralLabel), findsNothing);
    // The avatar reads the same projection the title does.
    expect(find.text('T'), findsOneWidget);
    expect(find.text('H'), findsOneWidget);
    expect(find.byType(DefaultStreamMentionItem), findsNWidgets(2));

    await _teardown(tester, harness);
  });

  testWidgets('typing an Alias prefix narrows the group candidates', (
    tester,
  ) async {
    final harness = _ComposerHarness();
    addTearDown(harness.dispose);

    await _pumpComposer(tester, harness);
    await _type(tester, '@tun');

    expect(find.text('Tundra-3726'), findsOneWidget);
    expect(find.text('Harbor-7001'), findsNothing);

    // An Alias nobody carries closes the overlay rather than offering a name
    // LOOP did not resolve.
    await _type(tester, '@zz');
    expect(find.byType(DefaultStreamMentionItem), findsNothing);

    await _teardown(tester, harness);
  });

  testWidgets('tapping a candidate types the Alias and keeps the link', (
    tester,
  ) async {
    final harness = _ComposerHarness();
    addTearDown(harness.dispose);

    await _pumpComposer(tester, harness);
    await _type(tester, '@tun');
    await tester.tap(find.byType(DefaultStreamMentionItem));
    await tester.pumpAndSettle();

    // What the member reads is what the message carries…
    expect(harness.controller.text, '@Tundra-3726 ');
    expect(harness.controller.text, isNot(contains('loop_')));
    // …and the Stream mention link leaves with it.
    expect(harness.controller.mentionedUsers.map((user) => user.id), <String>[
      _tundra,
    ]);
    expect(harness.controller.value.toJson()['mentioned_users'], <String>[
      _tundra,
    ]);

    await _teardown(tester, harness);
  });

  group('the mention link leaves with the message', () {
    // R14-2. Device report 2026-09-20: the group `@` read correctly on screen
    // but the server stored `mentioned_users: []`, so the mention raised no
    // unread, no push and no highlight — it was only text.
    Message mention({String? name}) => Message(
      id: 'message-1',
      text: '@Tundra-3726 看一下',
      mentionedUsers: <User>[User(id: _tundra, name: name)],
    );

    test('Stream drops a mention whose token is the channel Alias', () {
      // The defect itself, pinned: `toJson` filters mentions by `@<user.id>`
      // and `@<user.name>`, and a LOOP account answers the id for both.
      expect(mention().toJson()['mentioned_users'], isEmpty);
    });

    test('naming the mentioned member with the Alias keeps the link', () {
      final prepared = prepareLoopGroupMentionsForSend(
        message: mention(),
        members: _roster(),
      );

      // The body is untouched: no Stream id is ever written into a message.
      expect(prepared.text, '@Tundra-3726 看一下');
      expect(prepared.text, isNot(contains('loop_')));
      expect(prepared.toJson()['mentioned_users'], <String>[_tundra]);
      // Only ids are sent, so the Alias never leaves the device this way.
      expect(prepared.toJson()['text'], '@Tundra-3726 看一下');
    });

    test('an edit is prepared the same way, from the live roster', () {
      // A message read back from the server carries mentioned users with no
      // name at all, so an edit would silently drop the link.
      final reloaded = mention(name: null);
      expect(reloaded.toJson()['mentioned_users'], isEmpty);
      expect(
        prepareLoopGroupMentionsForSend(
          message: reloaded,
          members: _roster(),
        ).toJson()['mentioned_users'],
        <String>[_tundra],
      );
    });

    test(
      'a member this channel cannot name is left exactly as Stream had them',
      () {
        final unknown = Message(
          id: 'message-2',
          text: '@Someone 看一下',
          mentionedUsers: <User>[User(id: _unprojected)],
        );
        final prepared = prepareLoopGroupMentionsForSend(
          message: unknown,
          members: _roster(),
        );

        expect(prepared.mentionedUsers.single.name, _unprojected);
        expect(prepared.toJson()['mentioned_users'], isEmpty);
      },
    );

    test('only a group or community channel is prepared', () {
      final client = StreamChatClient(
        'public-stream-api-key',
        logLevel: Level.OFF,
      );
      Channel channelFor(String id) => Channel.fromState(
        client,
        ChannelState(
          channel: ChannelModel(id: id, type: 'messaging'),
          members: _roster(),
        ),
      );

      final group = channelFor('loop_community_5a2f766100000000');
      addTearDown(group.dispose);
      expect(
        loopPrepareChannelMessageForSend(
          message: mention(),
          channel: group,
        ).toJson()['mentioned_users'],
        <String>[_tundra],
      );

      final direct = channelFor('loop_direct_8e7d73c5');
      addTearDown(direct.dispose);
      expect(
        loopPrepareChannelMessageForSend(
          message: mention(),
          channel: direct,
        ).mentionedUsers.single.name,
        _tundra,
      );
    });
  });

  testWidgets('the candidate card is a surface, not a wash', (tester) async {
    // R14-4. The device showed the roster half-unreadable: message bubbles,
    // the date separator and the delivery ticks all read straight through the
    // card. It was never a paint-order problem — Stream's card defaults to
    // `backgroundElevation1`, which LOOP maps to `LoopColors.card`, the
    // 6%-opaque chalk wash a flat in-page panel uses. A panel drawn over the
    // conversation has to be opaque.
    final harness = _ComposerHarness();
    addTearDown(harness.dispose);
    // Rendering the frame needs real async, and the Stream client's
    // connectivity monitor subscribes to a platform channel the test binding
    // has no implementation for. Answer it instead of letting the plugin's
    // exception land on this test.
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity_status',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(connectivity, (call) async => null);
    addTearDown(() => messenger.setMockMethodCallHandler(connectivity, null));

    await tester.pumpWidget(
      MaterialApp(
        theme: LoopTheme.dark,
        home: RepaintBoundary(
          key: const ValueKey<String>('mention-overlay-ground'),
          // The palette Stream 10.3 reads is the `StreamTheme` extension on
          // the ambient Material theme (decision 0065), so the product's own
          // grounds are the ones under test here.
          child: Builder(
            builder: (context) => Theme(
              data: Theme.of(context).copyWith(
                extensions: [
                  ...Theme.of(context).extensions.values,
                  loopStreamTheme(platform: Theme.of(context).platform),
                ],
              ),
              child: StreamChat(
                client: harness.client,
                themeData: loopStreamChatThemeData(),
                componentBuilders: StreamComponentBuilders(
                  extensions: streamChatComponentBuilders(
                    messageItem: loopStreamGroupMessageItemBuilder,
                    mentionItem: loopStreamGroupMentionItemBuilder,
                  ),
                ),
                child: StreamChannel.value(
                  channel: harness.channel,
                  child: Scaffold(
                    body: Column(
                      children: <Widget>[
                        // Stands in for what a conversation puts behind the card.
                        const Expanded(child: ColoredBox(color: _groundColor)),
                        StreamAutocomplete(
                          focusNode: harness.focusNode,
                          messageComposerController: harness.controller,
                          autocompleteTriggers: <StreamAutocompleteTrigger>[
                            loopGroupMentionAutocompleteTrigger(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await _type(tester, '@');

    final card = find.byType(
      StreamAutocompleteOptions<LoopGroupMentionCandidate>,
    );
    expect(card, findsOneWidget);
    expect(
      tester
          .widget<StreamAutocompleteOptions<LoopGroupMentionCandidate>>(card)
          .color
          ?.a,
      1,
    );

    // …and nothing behind it reaches the reader.
    final bounds = tester.getRect(card);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey<String>('mention-overlay-ground')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      addTearDown(image.dispose);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      var ground = 0;
      for (var y = bounds.top.toInt() + 2; y < bounds.bottom.toInt() - 2; y++) {
        for (
          var x = bounds.left.toInt() + 2;
          x < bounds.right.toInt() - 2;
          x++
        ) {
          final offset = (y * image.width + x) * 4;
          // A wash lets most of the ground through, so the pixel stays within
          // a few percent of it; an opaque surface is nowhere near it.
          if ((pixels!.getUint8(offset) - _groundColor.r * 255).abs() < 40 &&
              (pixels.getUint8(offset + 1) - _groundColor.g * 255).abs() < 40 &&
              (pixels.getUint8(offset + 2) - _groundColor.b * 255).abs() < 40) {
            ground += 1;
          }
        }
      }
      expect(ground, 0);
    });

    await _teardown(tester, harness);
  });

  testWidgets('a bubble draws the Alias for a mention, never the Stream id', (
    tester,
  ) async {
    final harness = _ComposerHarness();
    addTearDown(harness.dispose);

    final display = sanitizeLoopGroupMessageForDisplay(
      message: Message(
        id: 'message-1',
        text: '@$_tundra 看一下',
        user: User(id: _harbor, name: _harbor),
        mentionedUsers: <User>[User(id: _tundra, name: _tundra)],
        createdAt: DateTime.utc(2026, 9, 20, 12),
        state: MessageState.sent,
      ),
      members: _roster(),
    );

    expect(display.text, '@Tundra-3726 看一下');
    expect(display.mentionedUsers.map(loopStreamDisplayLabelOf), <String>[
      'Tundra-3726',
    ]);

    await _pumpInChannel(
      tester,
      harness,
      StreamMessageLayout(
        data: const StreamMessageLayoutData(
          listKind: StreamMessageListKind.channel,
        ),
        child: StreamMessageItem(
          message: display.copyWith(text: '@$_tundra 看一下'),
          onMessageTap: (_) {},
        ),
      ),
    );

    expect(find.textContaining('loop_'), findsNothing);
    expect(find.textContaining('Tundra-3726'), findsWidgets);

    await _teardown(tester, harness);
  });
}

Map<String, Object?> _projection(String alias) => <String, Object?>{
  'loop_group_alias_id': _aliasId,
  'loop_group_alias': alias,
  'loop_group_alias_version': 1,
};

/// A member as Stream hands it over: no account name at all, so `User.name`
/// answers the id.
Member _member(String userId, [Map<String, Object?>? extraData]) => Member(
  userId: userId,
  user: User(id: userId),
  extraData: extraData ?? const <String, Object?>{},
);

List<Member> _roster() => <Member>[
  _member(_me, _projection('Boulder-6879')),
  _member(_tundra, _projection('Tundra-3726')),
  _member(_unprojected),
  _member(_harbor, _projection('Harbor-7001')),
];

/// The composer's autocomplete half, mounted on its own.
///
/// `StreamMessageComposer` cannot be mounted in a widget test: its state
/// constructs `StreamAudioRecorderController` unconditionally
/// (`stream_message_composer.dart:653`), and `record`'s amplitude monitor
/// arms a 100 ms periodic timer the test binding then refuses to end on. The
/// part LOOP changed is the trigger and its overlay, and
/// [StreamAutocomplete] is exactly the widget the composer hands them to —
/// `loopChannelAutocompleteTriggers` pins which composer installs them.
Future<void> _pumpComposer(WidgetTester tester, _ComposerHarness harness) =>
    _pumpInChannel(
      tester,
      harness,
      StreamAutocomplete(
        focusNode: harness.focusNode,
        messageComposerController: harness.controller,
        autocompleteTriggers: <StreamAutocompleteTrigger>[
          loopGroupMentionAutocompleteTrigger(),
        ],
      ),
    );

Future<void> _pumpInChannel(
  WidgetTester tester,
  _ComposerHarness harness,
  Widget child,
) async {
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
          child: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Types into the composer and waits out the autocomplete debounce.
Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _teardown(WidgetTester tester, _ComposerHarness harness) async {
  await tester.pumpWidget(const SizedBox.shrink());
  // Stream's own typing/autocomplete debounce outlives the tree it was armed
  // from; let it run out before the binding checks for pending timers.
  await tester.pump(const Duration(seconds: 2));
  harness.dispose();
}

final class _ComposerHarness {
  _ComposerHarness() {
    // ignore: invalid_use_of_internal_member
    client.state.currentUser = OwnUser(id: _me);
  }

  final StreamChatClient client = StreamChatClient(
    'public-stream-api-key',
    logLevel: Level.OFF,
  );
  late final Channel channel = Channel.fromState(
    client,
    ChannelState(
      channel: ChannelModel(
        id: 'loop_community_5a2f766100000000',
        type: 'messaging',
        memberCount: 4,
        // Without the capability the composer draws its read-only notice
        // instead of a field, and nothing could be typed at all.
        ownCapabilities: <String>['send-message', 'upload-file'],
      ),
      members: _roster(),
    ),
  );
  final FocusNode focusNode = FocusNode();
  final StreamMessageComposerController controller =
      StreamMessageComposerController();
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    focusNode.dispose();
    controller.dispose();
    channel.dispose();
  }
}
