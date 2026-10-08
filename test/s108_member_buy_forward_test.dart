// S108 · member-buy feed card, long-press forward and multi-select
// (decision 0114).
//
// The backend's feed bot posts 「群友买入」 into a community's official group
// with the facts on the message's custom fields; the room draws a card, not a
// bubble, and names the buyer live. A message's long-press sheet gains 「转发」
// and 「多选」 and loses Stream's flag / mute / block; 多选 turns the room into
// a selection with its own top bar and action bar.
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/attachments/stream_token_card_message_preview_formatter.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/member_buy/loop_member_buy_card.dart';
import 'package:loop_mobile/features/chat/member_buy/member_buy_event.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/features/chat/v2/forward_target_sheet.dart';
import 'package:loop_mobile/features/chat/v2/loop_message_selection.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_gateway.dart';
import 'package:loop_mobile/features/social/public_profile/public_profile_models.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_connection.dart';
import 'package:loop_mobile/integrations/communication/stream_display_identity.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

const String _cid = 'messaging:loop_community_99565a0c000000000000000000000000';
const String _target = 'messaging:loop_group_9c1f0f2e5a7b4c3d8e9f0a1b2c3d4e5f';
const String _me = 'me';
const String _buyerId = '0f3a2b1c-4d5e-4f60-8a7b-9c0d1e2f3a4b';
const String _tx =
    '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890ababcd';
const Key _composer = ValueKey<String>('loop-stream-message-composer');

Map<String, Object?> _buyFields({
  Map<String, Object?> overrides = const <String, Object?>{},
  Set<String> drop = const <String>{},
}) {
  final fields = <String, Object?>{
    'loop_schema': 'member_buy.v1',
    'loop_event_kind': 'memberBuy',
    'publicProfileId': _buyerId,
    'assetId': 'bsc:0xabc',
    'symbol': 'PEPE',
    'decimals': 18,
    // 12,345.678 PEPE
    'amountRaw': '12345678000000000000000',
    'quoteAssetId': 'bsc:usdt',
    // 12.34 USDT
    'quoteAmountRaw': '12340000000000000000',
    'quoteIsStable': true,
    'txHash': _tx,
    'logIndex': 7,
    'chainId': '56',
    'blockNumber': '48000000',
    'blockTimestamp': '2026-10-08T04:05:00Z',
    ...overrides,
  };
  for (final key in drop) {
    fields.remove(key);
  }
  return fields;
}

Message _buyMessage({
  Map<String, Object?> overrides = const <String, Object?>{},
  Set<String> drop = const <String>{},
}) => Message(
  id: 'loop_buy_1',
  text: '群友买入 · PEPE',
  user: User(id: loopFeedBotUserId, name: 'LOOP'),
  createdAt: DateTime.utc(2026, 10, 8, 4, 6),
  state: MessageState.sent,
  extraData: _buyFields(overrides: overrides, drop: drop),
);

PublicProfileRecord _profile() => PublicProfileRecord(
  publicProfileId: _buyerId,
  loopId: 'LOOP-4D5E6F',
  alias: 'NightOwl',
  avatarRef: null,
  bio: null,
  joinedAt: DateTime.utc(2026, 9),
  counts: const PublicProfileCounts(followers: 1, following: 1, communities: 1),
  relationship: const PublicProfileRelationship(
    following: false,
    followedBy: false,
    friendship: ProfileFriendship.none,
    blocked: false,
    blockedBy: false,
  ),
  visibility: const PublicProfileVisibility(holdings: true, trades: true),
);

final class _Profiles implements PublicProfileGateway {
  _Profiles({this.fail = false});

  final bool fail;
  int loads = 0;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<PublicProfileRecord> load(PublicProfileTarget target) async {
    loads += 1;
    if (fail) {
      throw const CommunityGatewayException(CommunityFailureKind.notFound);
    }
    return _profile();
  }

  @override
  Future<ProfileHoldings> holdings(String publicProfileId) =>
      throw UnimplementedError();

  @override
  Future<ProfileTradesPage> trades(String publicProfileId, {String? cursor}) =>
      throw UnimplementedError();

  @override
  Future<void> removeFriend(String publicProfileId) =>
      throw UnimplementedError();
}

Future<void> _pumpCard(
  WidgetTester tester,
  Message message, {
  required _Profiles profiles,
  void Function(String id)? onOpenProfile,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [publicProfileGatewayProvider.overrideWithValue(profiles)],
      child: MaterialApp(
        theme: LoopTheme.dark,
        builder: (context, child) => LoopToastHost(child: child!),
        home: Scaffold(
          body: LoopChatAvatarTapScope(
            onOpenProfile: onOpenProfile ?? (_) {},
            child: LoopMemberBuyCard(message: message),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Connected implements LoopStreamConnection {
  @override
  bool get isConnected => true;
  @override
  Future<void> open() async {}
}

class _LocalClient extends StreamChatClient {
  _LocalClient() : super('key', logLevel: Level.OFF);

  @override
  Future<EmptyResponse> markChannelRead(
    String channelId,
    String channelType, {
    String? messageId,
  }) async => EmptyResponse();
}

final class _Port implements ChatForwardPort {
  final List<(String, String, String)> sent = <(String, String, String)>[];

  @override
  Future<List<ChatForwardTarget>> recentTargets({
    required String excludeCid,
  }) async => const <ChatForwardTarget>[
    ChatForwardTarget(cid: _target, label: '周末爬山群', detail: '群聊 · 3 人'),
  ];

  @override
  Future<void> send({
    required String sourceCid,
    required String targetCid,
    required ChatForwardMessage message,
  }) async {
    sent.add((sourceCid, targetCid, message.text));
  }
}

/// One community room of twelve text messages — odd ones the reader's own —
/// and, optionally, a member-buy card as the newest row.
final class _Room {
  _Room({this.withBuy = false}) {
    // ignore: invalid_use_of_internal_member
    client.state.currentUser = OwnUser(id: _me, name: '我');
    channel = Channel.fromState(
      client,
      ChannelState(
        channel: ChannelModel(
          id: _cid.split(':').last,
          type: 'messaging',
          ownCapabilities: const <String>[
            'quote-message',
            'send-message',
            'send-reply',
            'read-events',
            'delete-own-message',
            'flag-message',
            'mute-channel',
          ],
        ),
        membership: Member(userId: _me),
        members: <Member>[
          Member(
            userId: _me,
            user: User(id: _me),
          ),
        ],
        messages: <Message>[...history, if (withBuy) _buyMessage()],
      ),
    );
  }

  final bool withBuy;
  final _LocalClient client = _LocalClient();
  final _Port port = _Port();
  final _Profiles profiles = _Profiles();
  late final Channel channel;
  static final DateTime now = DateTime.utc(2026, 10, 8, 12);

  late final List<Message> history = <Message>[
    for (var i = 12; i >= 1; i--)
      Message(
        id: 'h$i',
        text: '消息 $i',
        user: User(id: i.isOdd ? _me : 'other', name: '成员'),
        createdAt: now.subtract(Duration(minutes: i)),
        state: MessageState.sent,
      ),
  ];

  Future<void> pump(WidgetTester tester) async {
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
      ProviderScope(
        overrides: [
          chatForwardPortProvider.overrideWithValue(port),
          publicProfileGatewayProvider.overrideWithValue(profiles),
        ],
        child: MaterialApp(
          theme: LoopTheme.dark.copyWith(
            extensions: [
              ...LoopTheme.dark.extensions.values,
              loopStreamTheme(),
            ],
          ),
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            LoopStreamChatLocalizationsDelegate(),
          ],
          builder: (context, child) => StreamChat(
            client: client,
            themeData: loopStreamChatThemeData(),
            componentBuilders: StreamComponentBuilders(
              messageText: loopStreamMessageTextBuilder,
              extensions: streamChatComponentBuilders(
                messageItem: loopStreamGroupMessageItemBuilder,
              ),
            ),
            child: LoopToastHost(child: child!),
          ),
          home: LoopMessageSelectionHost(
            child: Scaffold(
              body: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const LoopSelectionAwareTopbar(
                      child: LoopTopbar(title: '测试社区', minHeight: 72),
                    ),
                    Expanded(
                      child: LoopStreamMemberChannelBody(
                        client: client,
                        cid: _cid,
                        userId: _me,
                        composerHint: loopChatComposerHint,
                        unresolvedMessage: null,
                        header: null,
                        banner: null,
                        footer: null,
                        keyPrefix: 'community-chat-channel',
                        connection: _Connected(),
                        query: () async => <Channel>[channel],
                        mayPinMessages: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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

  Future<void> startSelection(WidgetTester tester, String text) async {
    await openActions(tester, text);
    await tester.tap(find.text('多选'));
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
    channel.dispose();
  }
}

LoopButton _button(WidgetTester tester, String key) =>
    tester.widget<LoopButton>(find.byKey(ValueKey<String>(key)));

void main() {
  group('member-buy card', () {
    testWidgets('a complete payload names the buyer and states the facts', (
      tester,
    ) async {
      final profiles = _Profiles();
      String? opened;
      await _pumpCard(
        tester,
        _buyMessage(),
        profiles: profiles,
        onOpenProfile: (id) => opened = id,
      );

      expect(find.byKey(LoopMemberBuyCard.cardKey), findsOneWidget);
      expect(find.text('NightOwl'), findsOneWidget);
      expect(
        find.textContaining('买入 1.23万 PEPE', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('≈ \$12.34'), findsOneWidget);
      expect(find.text('0x1234…abcd'), findsOneWidget);
      expect(profiles.loads, 1);

      await tester.tap(find.byKey(LoopMemberBuyCard.avatarKey));
      expect(opened, _buyerId);
    });

    testWidgets('a non-stable quote reads in WBNB', (tester) async {
      await _pumpCard(
        tester,
        _buyMessage(
          overrides: <String, Object?>{
            'quoteIsStable': false,
            'quoteAmountRaw': '50000000000000000',
          },
        ),
        profiles: _Profiles(),
      );
      expect(find.text('0.05 WBNB'), findsOneWidget);
    });

    testWidgets('a missing field is 「动态数据不完整」, never a zero', (tester) async {
      for (final field in <String>[
        'amountRaw',
        'decimals',
        'publicProfileId',
        'txHash',
        'quoteIsStable',
        'symbol',
      ]) {
        await _pumpCard(
          tester,
          _buyMessage(drop: <String>{field}),
          profiles: _Profiles(),
        );
        expect(
          find.byKey(LoopMemberBuyCard.incompleteKey),
          findsOneWidget,
          reason: field,
        );
        expect(find.text('群友买入 · 动态数据不完整'), findsOneWidget);
        expect(find.byKey(LoopMemberBuyCard.cardKey), findsNothing);
        expect(find.textContaining('0', findRichText: true), findsNothing);
      }
    });

    testWidgets('a buyer LOOP cannot resolve reads as 「群友」', (tester) async {
      final profiles = _Profiles(fail: true);
      await _pumpCard(tester, _buyMessage(), profiles: profiles);
      expect(find.text(loopMemberBuyNeutralBuyer), findsOneWidget);
      expect(
        find.textContaining('买入 1.23万 PEPE', findRichText: true),
        findsOneWidget,
      );
      expect(profiles.loads, 1);
    });

    test('amounts: compact from 1 万, never 0 for a positive figure', () {
      expect(loopFormatMemberBuyAmount(Decimal.parse('9999.5')), '9,999.5');
      expect(loopFormatMemberBuyAmount(Decimal.parse('12345.678')), '1.23万');
      expect(loopFormatMemberBuyAmount(Decimal.parse('450000000')), '4.5亿');
      expect(
        loopFormatMemberBuyAmount(Decimal.parse('0.0000001')),
        '<0.000001',
      );
      expect(loopFormatMemberBuyAmount(Decimal.parse('0.25')), '0.25');
    });

    testWidgets('the conversation preview is 「群友买入 · SYMBOL」', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox.shrink();
          },
        ),
      );
      const formatter = LoopStreamTokenCardMessagePreviewFormatter();
      expect(
        formatter.formatMessage(context, _buyMessage()).toPlainText(),
        '群友买入 · PEPE',
      );
      expect(
        formatter.formatMessageSemanticsLabel(context, _buyMessage()),
        '群友买入 · PEPE',
      );
      // A broken payload still previews with its token; no token, no symbol.
      final noSymbol = _buyMessage(drop: <String>{'symbol'});
      expect(formatter.formatMessage(context, noSymbol).toPlainText(), '群友买入');
      // The formatter restates the card's schema tag; they stay in step.
      expect(
        LoopStreamTokenCardMessagePreviewFormatter.memberBuySchema,
        loopMemberBuySchema,
      );
      for (final message in <Message>[_buyMessage(), noSymbol]) {
        expect(
          LoopStreamTokenCardMessagePreviewFormatter.memberBuyPreview(message),
          loopMemberBuyPreviewText(message),
        );
      }
    });

    testWidgets('in a room the card replaces the bubble', (tester) async {
      final room = _Room(withBuy: true);
      await room.pump(tester);
      expect(find.byKey(LoopMemberBuyCard.cardKey), findsOneWidget);
      // The fallback text is for old clients and notifications, not the room.
      expect(find.text('群友买入 · PEPE'), findsNothing);
      await room.dispose(tester);
    });
  });

  group('long-press sheet', () {
    testWidgets('offers 转发 and 多选, keeps reply and copy, drops flag, mute '
        'and block', (tester) async {
      final room = _Room();
      await room.pump(tester);
      await room.openActions(tester, '消息 2');

      expect(find.text('转发'), findsOneWidget);
      expect(find.text('多选'), findsOneWidget);
      expect(find.text('回复'), findsOneWidget);
      expect(find.text('复制消息'), findsOneWidget);
      expect(find.text('举报消息'), findsNothing);
      expect(find.text('静音该用户'), findsNothing);
      expect(find.text('屏蔽该用户'), findsNothing);
      await room.dispose(tester);
    });

    testWidgets('the reader\'s own message keeps delete', (tester) async {
      final room = _Room();
      await room.pump(tester);
      await room.openActions(tester, '消息 1');
      expect(find.text('删除消息'), findsOneWidget);
      expect(find.text('转发'), findsOneWidget);
      await room.dispose(tester);
    });

    testWidgets('转发 opens the sheet and one pick sends once', (tester) async {
      final room = _Room();
      await room.pump(tester);
      await room.openActions(tester, '消息 2');
      await tester.tap(find.text('转发'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('forward-target-sheet')),
        findsOneWidget,
      );
      await tester.tap(find.text('周末爬山群'));
      await tester.pumpAndSettle();

      expect(room.port.sent, <(String, String, String)>[
        (_cid, _target, '消息 2'),
      ]);
      expect(
        find.byKey(const ValueKey<String>('forward-target-sheet')),
        findsNothing,
      );
      expect(find.text('已转发'), findsOneWidget);
      await room.dispose(tester);
    });
  });

  group('multi-select', () {
    testWidgets('多选 swaps the top bar and the composer, and 取消 restores '
        'both', (tester) async {
      final room = _Room();
      await room.pump(tester);
      await room.startSelection(tester, '消息 2');

      expect(find.text('已选 1 条'), findsOneWidget);
      expect(find.byKey(_composer), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('loop-selection-bar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('loop-selection-check-on')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-selectable-h3')),
      );
      await tester.pump();
      expect(find.text('已选 2 条'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-selection-cancel')),
      );
      await tester.pumpAndSettle();
      expect(find.text('测试社区'), findsOneWidget);
      expect(find.byKey(_composer), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-selection-bar')),
        findsNothing,
      );
      await room.dispose(tester);
    });

    testWidgets('the bar: forward and merge need a forwardable message; '
        'delete needs every message to be the reader\'s own', (tester) async {
      final room = _Room();
      await room.pump(tester);
      // 消息 1 is the reader's own.
      await room.startSelection(tester, '消息 1');
      expect(
        _button(tester, 'loop-selection-forward-each').onPressed,
        isNotNull,
      );
      expect(_button(tester, 'loop-selection-merge').onPressed, isNotNull);
      expect(_button(tester, 'loop-selection-delete').onPressed, isNotNull);

      // 消息 2 is somebody else's: delete closes.
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-selectable-h2')),
      );
      await tester.pump();
      expect(_button(tester, 'loop-selection-delete').onPressed, isNull);
      expect(_button(tester, 'loop-selection-merge').onPressed, isNotNull);

      // Nothing ticked: nothing to do.
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-selectable-h1')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-selectable-h2')),
      );
      await tester.pump();
      expect(find.text('已选 0 条'), findsOneWidget);
      expect(_button(tester, 'loop-selection-forward-each').onPressed, isNull);
      expect(_button(tester, 'loop-selection-merge').onPressed, isNull);
      expect(_button(tester, 'loop-selection-delete').onPressed, isNull);
      await room.dispose(tester);
    });

    testWidgets('合并转发 opens the merge preview with exactly the ticked '
        'messages, oldest first', (tester) async {
      final room = _Room();
      await room.pump(tester);
      await room.startSelection(tester, '消息 2');
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-selectable-h4')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-selection-merge')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChatMergePreviewScreen), findsOneWidget);
      final rows = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'chat-merge-row-',
            ),
      );
      expect(
        tester
            .widgetList(rows)
            .map((widget) => (widget.key! as ValueKey<String>).value)
            .toList(),
        <String>['chat-merge-row-h4', 'chat-merge-row-h2'],
      );
      await room.dispose(tester);
    });

    testWidgets('逐条转发 sends each ticked message once', (tester) async {
      final room = _Room();
      await room.pump(tester);
      await room.startSelection(tester, '消息 2');
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-selectable-h3')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-selection-forward-each')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('周末爬山群'));
      await tester.pumpAndSettle();

      expect(room.port.sent, <(String, String, String)>[
        (_cid, _target, '消息 3'),
        (_cid, _target, '消息 2'),
      ]);
      expect(find.text('已转发 2 条'), findsOneWidget);
      // A forward that landed ends the selection.
      expect(find.byKey(_composer), findsOneWidget);
      await room.dispose(tester);
    });

    test('at most 20 messages', () {
      final controller = LoopMessageSelectionController();
      Message message(int i) => Message(
        id: 'm$i',
        text: '$i',
        createdAt: DateTime.utc(2026, 10, 8, 0, i),
        state: MessageState.sent,
      );
      controller.start(message(0));
      for (var i = 1; i < loopMessageSelectionLimit; i += 1) {
        expect(controller.toggle(message(i)), LoopMessageSelectionChange.added);
      }
      expect(controller.count, 20);
      expect(
        controller.toggle(message(20)),
        LoopMessageSelectionChange.refusedAtLimit,
      );
      expect(controller.count, 20);
      // Unticking makes room again.
      expect(controller.toggle(message(3)), LoopMessageSelectionChange.removed);
      expect(controller.toggle(message(20)), LoopMessageSelectionChange.added);
      // Oldest first.
      expect(controller.selected.first.id, 'm0');
      expect(controller.selected.last.id, 'm20');
      controller.cancel();
      expect(controller.active, isFalse);
      expect(controller.count, 0);
      controller.dispose();
    });

    test('a member-buy card and a deleted message are never ticked', () {
      expect(loopMessageSelectable(_buyMessage()), isFalse);
      expect(
        loopMessageSelectable(
          Message(id: 'd', text: 'x', state: MessageState.softDeleted),
        ),
        isFalse,
      );
      expect(
        loopMessageSelectable(
          Message(
            id: 't',
            text: 'x',
            type: MessageType.deleted,
            state: MessageState.sent,
          ),
        ),
        isFalse,
      );
      expect(
        loopMessageSelectable(
          Message(id: 's', text: 'x', state: MessageState.sent),
        ),
        isTrue,
      );
    });
  });
}
