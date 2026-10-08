import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_content.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/features/square/live_voice_rooms.dart';
import 'package:loop_mobile/features/square/square_screen.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart'
    show Channel, Level, PagedValue, StreamChatClient;

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s7_page_harness.dart';

const _roomA = '8c7b6a59-4d3e-4f21-8a0b-1c2d3e4f5a6b';
const _roomB = '2b3c4d5e-6f70-4182-9394-a5b6c7d8e9f0';
const _communityB = '4b96a75e-6828-4a6b-8c1d-2e3f4a5b6c7d';

LiveVoiceRoom _room(String id, String communityId, String name) =>
    LiveVoiceRoom(
      voiceRoomId: id,
      communityId: communityId,
      communityName: name,
      communityLogoRef: null,
      title: null,
      host: const LiveVoiceRoomHost(
        publicProfileId: null,
        displayName: 'frog_maxi',
        avatarRef: null,
      ),
      listenerCount: 2,
      speakerCount: 0,
      countsObservedAt: null,
      startedAt: DateTime.utc(2026, 10, 8, 3),
      joinable: true,
    );

LiveVoiceRoomPage _page(List<LiveVoiceRoom> items, {String? nextCursor}) =>
    LiveVoiceRoomPage(
      items: items,
      nextCursor: nextCursor,
      observedAt: DateTime.utc(2026, 10, 8, 4),
    );

/// Answers each read with the next scripted result: a page, a failure kind,
/// or `null` for a read that never answers.
final class _ScriptedLiveGateway implements LiveVoiceRoomGateway {
  _ScriptedLiveGateway(this.script);

  final List<Object?> script;
  final List<String?> cursors = <String?>[];

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<LiveVoiceRoomPage> listLive({String? cursor}) {
    cursors.add(cursor);
    final index = cursors.length - 1;
    final step = script[index < script.length ? index : script.length - 1];
    return switch (step) {
      final LiveVoiceRoomPage page => Future<LiveVoiceRoomPage>.value(page),
      final CommunityFailureKind kind => Future<LiveVoiceRoomPage>.error(
        CommunityGatewayException(kind),
      ),
      _ => Completer<LiveVoiceRoomPage>().future,
    };
  }
}

Future<void> _pumpRooms(
  WidgetTester tester,
  LiveVoiceRoomGateway gateway, {
  VoiceRoomSession? session,
  bool settle = true,
}) => pumpCommunityPage(
  tester,
  LiveVoiceRoomList(
    onOpenCommunity: (_) {},
    onOpenVoiceRoom: (_) {},
    now: () => DateTime.utc(2026, 10, 8, 4),
  ),
  settle: settle,
  voiceRoomSession: session,
  overrides: <Override>[
    liveVoiceRoomGatewayProvider.overrideWithValue(gateway),
  ],
);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

const _session = VoiceRoomSession(
  communityId: testCommunityId,
  communityName: 'Frog Holders',
  voiceRoomId: _roomA,
  callRoomId: null,
  role: VoiceRoomRole.listener,
  joinedCount: 12,
);

void main() {
  loopWatchGround();

  group('chat · filtered empty state', () {
    late StreamChatClient client;
    setUp(() {
      client = StreamChatClient('public-stream-api-key', logLevel: Level.OFF);
    });
    tearDown(() => client.dispose());

    const hex = '0123456789abcdef0123456789abcdef';
    Channel community() => Channel(client, 'messaging', 'loop_community_$hex');
    Channel direct() => Channel(client, 'messaging', 'loop_direct_$hex');

    test('only a finished list with no match is empty', () {
      final onlyCommunities = PagedValue<int, Channel>(
        items: <Channel>[community()],
      );
      expect(
        chatInboxFilterLeftNothing(ChatInboxFilter.friends, onlyCommunities),
        isTrue,
      );
      expect(
        chatInboxFilterLeftNothing(
          ChatInboxFilter.communities,
          onlyCommunities,
        ),
        isFalse,
      );
      expect(
        chatInboxFilterLeftNothing(ChatInboxFilter.all, onlyCommunities),
        isFalse,
      );
      // Another page may still hold a match: the list view reads it first.
      expect(
        chatInboxFilterLeftNothing(
          ChatInboxFilter.friends,
          PagedValue<int, Channel>(
            items: <Channel>[community()],
            nextPageKey: 20,
          ),
        ),
        isFalse,
      );
      // An empty account is Stream's own empty state, not the filter's.
      expect(
        chatInboxFilterLeftNothing(
          ChatInboxFilter.friends,
          const PagedValue<int, Channel>(items: <Channel>[]),
        ),
        isFalse,
      );
      expect(
        chatInboxFilterLeftNothing(
          ChatInboxFilter.friends,
          const PagedValue<int, Channel>.loading(),
        ),
        isFalse,
      );
    });

    testWidgets('社区 and 好友 each say their own empty sentence', (tester) async {
      final value = ValueNotifier<PagedValue<int, Channel>>(
        PagedValue<int, Channel>(items: <Channel>[direct()]),
      );
      addTearDown(value.dispose);
      Widget gate(ChatInboxFilter filter) => MaterialApp(
        theme: LoopTheme.dark,
        home: Scaffold(
          body: ChatInboxFilterEmptyGate(
            controller: value,
            filter: filter,
            child: const Text('channel-list'),
          ),
        ),
      );

      await tester.pumpWidget(gate(ChatInboxFilter.communities));
      expect(find.text('还没有社区会话'), findsOneWidget);
      expect(find.text('channel-list'), findsNothing);

      await tester.pumpWidget(gate(ChatInboxFilter.friends));
      expect(find.text('还没有社区会话'), findsNothing);
      expect(find.text('channel-list'), findsOneWidget);

      value.value = PagedValue<int, Channel>(items: <Channel>[community()]);
      await tester.pump();
      expect(find.text('还没有好友会话'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('chat-inbox-filter-empty-friends')),
        findsOneWidget,
      );

      await tester.pumpWidget(gate(ChatInboxFilter.all));
      expect(find.text('还没有好友会话'), findsNothing);
      expect(find.text('channel-list'), findsOneWidget);
    });
  });

  group('chat · the room this account is in', () {
    testWidgets('the head carries a way back into the room', (tester) async {
      final opened = <String>[];
      await pumpCommunityPage(
        tester,
        StreamChatInboxPage(onOpenVoiceRoom: opened.add),
        streamAuthorization: () async => StreamSessionAuthorization.unavailable,
        voiceRoomSession: _session,
      );
      final entry = find.byKey(
        const ValueKey<String>('chat-voice-room-return-entry'),
      );
      expect(entry, findsOneWidget);
      expect(find.text('正在语音房 · Frog Holders'), findsOneWidget);
      expect(find.text('返回'), findsOneWidget);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(opened, <String>[testCommunityId]);

      _container(tester)
          .read(voiceRoomSessionProvider.notifier)
          .leave(testCommunityId);
      await tester.pumpAndSettle();
      expect(entry, findsNothing);
    });

    testWidgets('no room, no row', (tester) async {
      await pumpCommunityPage(
        tester,
        const StreamChatInboxPage(),
        streamAuthorization: () async => StreamSessionAuthorization.unavailable,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-voice-room-return-entry')),
        findsNothing,
      );
    });

    testWidgets('the plaza marks the room this account is in', (tester) async {
      await _pumpRooms(
        tester,
        _ScriptedLiveGateway(<Object?>[
          _page(<LiveVoiceRoom>[
            _room(_roomA, testCommunityId, 'Frog Holders'),
            _room(_roomB, _communityB, 'Builders Guild'),
          ]),
        ]),
        session: _session,
      );
      final mark = find.byKey(
        const ValueKey<String>('square-voice-room-in-room'),
      );
      expect(mark, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('square-voice-room-$_roomA')),
          matching: mark,
        ),
        findsOneWidget,
      );
      expect(find.text('已在房间'), findsOneWidget);
    });
  });

  group('chat · preview', () {
    testWidgets('the Preview build draws no stranger-request row', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const StreamChatInboxPage(),
        social: FakeSocialGateway(
          requests: MessageRequestPage(
            items: <MessageRequestEntry>[
              MessageRequestEntry(
                messageRequestId: testRequestId,
                profile: testProfile(alias: 'fox_trader'),
                createdAt: DateTime.utc(2026, 9, 7),
                expiresAt: DateTime.utc(2026, 9, 14),
                preview: const LoopUnavailableFact('MESSAGE_PREVIEW_DEFERRED'),
                aiModeration: const LoopUnavailableFact(
                  'AI_MODERATION_DEFERRED',
                ),
              ),
            ],
            nextCursor: null,
          ),
        ),
        overrides: <Override>[
          communicationGatewayProvider.overrideWithValue(
            MemoryCommunicationGateway(),
          ),
        ],
      );
      expect(
        find.byKey(const ValueKey<String>('stream-chat-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('stream-chat-message-requests-entry'),
        ),
        findsNothing,
      );
      expect(find.text('陌生人请求'), findsNothing);
    });
  });

  group('intel · 算力榜 position card', () {
    testWidgets('every board opens on 我的名次, never NETWORK POSITION', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        IntelRankBoard(onNavigate: (_) {}),
        mining: FakeMiningGateway(),
      );
      final card = find.byKey(const ValueKey<String>('intel-rank-me'));
      for (final label in <String>['社区', '用户', '推广']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(card, findsOneWidget, reason: label);
        expect(find.text('NETWORK POSITION'), findsNothing);
      }
    });
  });

  group('square · cursor pages', () {
    testWidgets('the sentinel stays mounted while its page loads', (
      tester,
    ) async {
      final gateway = _ScriptedLiveGateway(<Object?>[
        _page(<LiveVoiceRoom>[
          _room(_roomA, testCommunityId, 'Frog Holders'),
        ], nextCursor: 'abc.def'),
        null,
      ]);
      await _pumpRooms(tester, gateway, settle: false);
      await tester.pump();
      await tester.pump();
      expect(gateway.cursors, <String?>[null, 'abc.def']);
      expect(
        find.byKey(const ValueKey<String>('square-voice-room-load-more')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('square-voice-room-loading-more')),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(gateway.cursors, <String?>[null, 'abc.def']);
    });

    testWidgets('a page answering with the cursor it was asked with ends the '
        'list', (tester) async {
      final gateway = _ScriptedLiveGateway(<Object?>[
        _page(<LiveVoiceRoom>[
          _room(_roomA, testCommunityId, 'Frog Holders'),
        ], nextCursor: 'abc.def'),
        _page(<LiveVoiceRoom>[
          _room(_roomB, _communityB, 'Builders Guild'),
        ], nextCursor: 'abc.def'),
      ]);
      await _pumpRooms(tester, gateway);
      expect(gateway.cursors, <String?>[null, 'abc.def']);
      expect(
        _container(tester).read(liveVoiceRoomsControllerProvider).nextCursor,
        isNull,
      );
      expect(
        find.byKey(const ValueKey<String>('square-voice-room-end')),
        findsOneWidget,
      );
    });
  });

  group('square · a failed refresh is retried as a refresh', () {
    testWidgets('语音房', (tester) async {
      final gateway = _ScriptedLiveGateway(<Object?>[
        _page(<LiveVoiceRoom>[_room(_roomA, testCommunityId, 'Frog Holders')]),
        CommunityFailureKind.offline,
        _page(<LiveVoiceRoom>[_room(_roomB, _communityB, 'Builders Guild')]),
      ]);
      await _pumpRooms(tester, gateway);
      unawaited(
        _container(tester)
            .read(liveVoiceRoomsControllerProvider.notifier)
            .refresh(),
      );
      await tester.pumpAndSettle();
      // The rows stay, the strip says the refresh failed, and there is no
      // next-page retry: nothing was being appended.
      expect(find.text('Frog Holders'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-freshness-failed')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('square-voice-room-retry-more')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-freshness-retry')),
      );
      await tester.pumpAndSettle();
      expect(gateway.cursors, <String?>[null, null, null]);
      expect(find.text('Builders Guild'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-freshness-failed')),
        findsNothing,
      );
    });

    testWidgets('a failed next page is still retried as a next page', (
      tester,
    ) async {
      final gateway = _ScriptedLiveGateway(<Object?>[
        _page(<LiveVoiceRoom>[
          _room(_roomA, testCommunityId, 'Frog Holders'),
        ], nextCursor: 'abc.def'),
        CommunityFailureKind.offline,
        _page(<LiveVoiceRoom>[_room(_roomB, _communityB, 'Builders Guild')]),
      ]);
      await _pumpRooms(tester, gateway);
      final retry = find.byKey(
        const ValueKey<String>('square-voice-room-retry-more'),
      );
      expect(retry, findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-freshness-failed')),
        findsNothing,
      );
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(gateway.cursors, <String?>[null, 'abc.def', 'abc.def']);
      expect(find.text('Builders Guild'), findsOneWidget);
    });

    testWidgets('社区目录', (tester) async {
      final gateway = FakeCommunityGateway(
        directoryPage: CommunityDirectoryPage(
          ordering: const CommunityOrderingApplied(
            sort: CommunityDirectorySort.members,
            basis: CommunityStoredBasis(),
          ),
          items: <CommunitySummary>[testCommunity()],
          nextCursor: null,
          recommendation: const CommunityRecommendation(
            recommendationId: '22222222-2222-4222-8222-222222222222',
            ruleVersion: 'rule:verified-members-v1',
          ),
        ),
      );
      await pumpCommunityPage(
        tester,
        CommunityDiscoverScreen(embedded: true, onOpenCommunity: (_) {}),
        community: gateway,
      );
      expect(find.text('Frog Holders'), findsOneWidget);
      final reads = gateway.commands
          .where((command) => command.startsWith('list:'))
          .length;

      gateway.failure = CommunityFailureKind.offline;
      unawaited(
        _container(tester)
            .read(communityDiscoverControllerProvider.notifier)
            .refresh(),
      );
      await tester.pumpAndSettle();
      expect(find.text('Frog Holders'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('loop-freshness-failed')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('community-discover-retry-more')),
        findsNothing,
      );

      gateway.failure = null;
      await tester.tap(
        find.byKey(const ValueKey<String>('loop-freshness-retry')),
      );
      await tester.pumpAndSettle();
      final lists = gateway.commands
          .where((command) => command.startsWith('list:'))
          .toList(growable: false);
      expect(lists.length, reads + 2);
      // Both re-reads asked for page one.
      expect(lists.last.endsWith(':null'), isTrue);
      expect(
        find.byKey(const ValueKey<String>('loop-freshness-failed')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(minutes: 30));
    });
  });

  group('segmented tab pages keep the bar\'s tools', () {
    testWidgets('the segment row carries 更新中', (tester) async {
      Widget page(bool updating) => ProviderScope(
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: LoopSegmentedTabPage(
            tabKey: 'probe',
            title: 'Probe',
            segments: const <String>['一', '二'],
            updating: (ref, index) => updating && index == 0,
            builder: (context, index) => LoopStreamPage(
              archetype: LoopPageArchetype.listing,
              title: '$index',
              embedded: true,
              tabPage: true,
              collection: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpWidget(page(false));
      expect(
        find.byKey(const ValueKey<String>('loop-updating-badge')),
        findsNothing,
      );
      await tester.pumpWidget(page(true));
      expect(
        find.byKey(const ValueKey<String>('probe-segment-updating')),
        findsOneWidget,
      );
      expect(find.text('更新中'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('probe-segment-1')));
      await tester.pumpAndSettle();
      expect(find.text('更新中'), findsNothing);
    });

    testWidgets('the square segment row says 更新中 while the rooms refresh', (
      tester,
    ) async {
      final gateway = _ScriptedLiveGateway(<Object?>[
        _page(<LiveVoiceRoom>[_room(_roomA, testCommunityId, 'Frog Holders')]),
        null,
      ]);
      await pumpCommunityPage(
        tester,
        SquareScreen(onOpenCommunity: (_) {}, onOpenVoiceRoom: (_) {}),
        overrides: <Override>[
          liveVoiceRoomGatewayProvider.overrideWithValue(gateway),
        ],
      );
      await tester.tap(find.byKey(const ValueKey<String>('square-segment-1')));
      await tester.pumpAndSettle();
      expect(find.text('Frog Holders'), findsOneWidget);
      expect(find.text('更新中'), findsNothing);
      unawaited(
        _container(tester)
            .read(liveVoiceRoomsControllerProvider.notifier)
            .refresh(),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('square-segment-updating')),
        findsOneWidget,
      );
    });

    testWidgets('MEME 发射台 carries the Launch tools when the switch is on', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const MemeScreen(),
        launch: FakeLaunchGateway(),
        overrides: <Override>[
          loopFeatureSwitchesProvider.overrideWithValue(
            const LoopFeatureSwitchValues(idoLaunchVisible: true),
          ),
        ],
      );
      expect(find.byKey(const ValueKey<String>('launch-screen')), findsOne);
      expect(
        find.byKey(const ValueKey<String>('launch-stake-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('launch-rules-action')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('meme-segment-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('launch-stake-action')),
        findsNothing,
      );
    });

    testWidgets('MEME 发射台 has no Launch tools while the switch is off', (
      tester,
    ) async {
      await pumpS7Page(tester, const MemeScreen(), launch: FakeLaunchGateway());
      expect(
        find.byKey(const ValueKey<String>('launch-stake-action')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('launch-rules-action')),
        findsNothing,
      );
    });
  });
}
