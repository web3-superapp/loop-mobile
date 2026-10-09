// S123b (decision 0129): list gestures — pull, swipe, long press, reading on
// at the end, and sideways segment swipes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/chat_inbox_row_actions.dart';
import 'package:loop_mobile/features/chat/v2/chat_search_screen.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_members_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_editor_screen.dart';
import 'package:loop_mobile/features/market/watchlist/watchlist_models.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// Records every platform haptic the code under test asks for.
List<String> _recordHaptics(WidgetTester tester) {
  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add('${call.arguments}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return haptics;
}

Widget _app(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: LoopTheme.dark,
    builder: (context, page) => LoopToastHost(child: page!),
    home: Scaffold(body: child),
  ),
);

// ---------------------------------------------------------------------------
// M7 · the foot of a paged list
// ---------------------------------------------------------------------------

class _Pager extends StatefulWidget {
  const _Pager({required this.answer});

  /// Answers the page a cursor asks for: the next cursor, or throws.
  final Future<String?> Function(String cursor) answer;

  @override
  State<_Pager> createState() => _PagerState();
}

class _PagerState extends State<_Pager> {
  String? cursor = 'c1';
  bool loading = false;
  int rows = 3;
  final List<String> asked = <String>[];

  Future<void> _load() async {
    final current = cursor!;
    asked.add(current);
    setState(() => loading = true);
    try {
      final next = await widget.answer(current);
      if (!mounted) return;
      setState(() {
        cursor = next;
        rows += 3;
      });
    } catch (_) {
      // The cursor stays: that is how the footer learns the page failed.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: <Widget>[
      for (var i = 0; i < rows; i += 1)
        SizedBox(height: 56, child: Text('row $i')),
      LoopLoadMoreFooter(
        keyPrefix: 'demo',
        cursor: cursor,
        canLoadMore: !loading,
        loading: loading,
        onLoadMore: _load,
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// M2 · a Stream channel to read facts from
// ---------------------------------------------------------------------------

class _LocalClient extends StreamChatClient {
  _LocalClient() : super('key', logLevel: Level.OFF);
}

Channel _channel(
  StreamChatClient client, {
  required String cid,
  List<String> capabilities = const <String>[],
  bool member = true,
  int unread = 0,
  DateTime? pinnedAt,
}) {
  // ignore: invalid_use_of_internal_member
  client.state.currentUser = OwnUser(id: 'me');
  return Channel.fromState(
    client,
    ChannelState(
      channel: ChannelModel(
        id: cid.split(':').last,
        type: 'messaging',
        ownCapabilities: capabilities,
      ),
      membership: member ? Member(userId: 'me', pinnedAt: pinnedAt) : null,
      read: <Read>[
        Read(
          user: User(id: 'me'),
          lastRead: DateTime.utc(2026, 10, 9),
          unreadMessages: unread,
        ),
      ],
    ),
  );
}

void main() {
  // This file mounts widgets through its own `pumpWidget`, so it arms the
  // ground probe itself.
  loopWatchGround();

  group('M7 · lists read on at the end', () {
    testWidgets('the footer asks once per cursor and the end draws nothing', (
      tester,
    ) async {
      final pages = <String, String?>{'c1': 'c2', 'c2': null};
      await tester.pumpWidget(
        _app(_Pager(answer: (cursor) async => pages[cursor])),
      );
      await tester.pumpAndSettle();

      final state = tester.state<_PagerState>(find.byType(_Pager));
      expect(state.asked, <String>['c1', 'c2']);
      expect(find.text('row 8'), findsOneWidget);
      // No control, no 「没有更多」: the last page simply ends.
      expect(
        find.byKey(const ValueKey<String>('demo-load-more')),
        findsNothing,
      );
      expect(find.textContaining('载入更多'), findsNothing);
      expect(find.textContaining('没有更多'), findsNothing);
    });

    testWidgets('a failed page waits for 重试 and does not loop', (tester) async {
      var fail = true;
      await tester.pumpWidget(
        _app(
          _Pager(
            answer: (cursor) async {
              if (fail) throw StateError('offline');
              return null;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<_PagerState>(find.byType(_Pager));
      expect(state.asked, <String>['c1']);
      expect(
        find.byKey(const ValueKey<String>('demo-more-failed')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 1));
      expect(state.asked, <String>['c1']);

      fail = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(state.asked, <String>['c1', 'c1']);
      expect(
        find.byKey(const ValueKey<String>('demo-more-failed')),
        findsNothing,
      );
      expect(find.text('row 5'), findsOneWidget);
    });

    testWidgets('the member directory reads its next page without a button', (
      tester,
    ) async {
      final gateway =
          FakeCommunityGateway(members: testDirectory(nextCursor: 'c2'))
            ..membersByCursor = <String, CommunityMemberDirectory>{
              'c2': testDirectory(
                items: <CommunityMemberEntry>[
                  testMember(
                    role: CommunityRole.member,
                    publicProfileId: '7a3d2e4c-5b6c-4d7e-8f90-1a2b3c4d5e61',
                    loopId: 'LOOP-3HJKMNPR',
                    alias: 'toad_member',
                  ),
                ],
              ),
            };
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
      );
      await tester.pumpAndSettle();

      expect(gateway.commands, contains('members:all:null:c2'));
      expect(find.text('frog_member'), findsOneWidget);
      expect(find.text('toad_member'), findsOneWidget);
      expect(find.text('载入更多'), findsNothing);
    });

    testWidgets('a member page that fails offers 重试, which reads it again', (
      tester,
    ) async {
      final gateway =
          FakeCommunityGateway(members: testDirectory(nextCursor: 'c2'))
            ..failingMemberCursors = <String>{'c2'}
            ..membersByCursor = <String, CommunityMemberDirectory>{
              'c2': testDirectory(
                items: <CommunityMemberEntry>[
                  testMember(
                    role: CommunityRole.member,
                    publicProfileId: '7a3d2e4c-5b6c-4d7e-8f90-1a2b3c4d5e61',
                    loopId: 'LOOP-3HJKMNPR',
                    alias: 'toad_member',
                  ),
                ],
              ),
            };
      await pumpCommunityPage(
        tester,
        const CommunityMembersScreen(communityId: testCommunityId),
        community: gateway,
      );
      await tester.pumpAndSettle();

      final failed = find.byKey(
        const ValueKey<String>('community-members-more-failed'),
      );
      expect(failed, findsOneWidget);
      await tester.ensureVisible(failed);
      await tester.tap(find.descendant(of: failed, matching: find.text('重试')));
      await tester.pumpAndSettle();

      expect(find.text('toad_member'), findsOneWidget);
      expect(failed, findsNothing);
    });
  });

  group('M2 · conversation rows', () {
    test('only the actions Stream allows are offered', () {
      expect(chatInboxRowActions(ChatInboxRowFacts.none), isEmpty);
      expect(
        chatInboxRowActions(
          const ChatInboxRowFacts(
            pinned: false,
            canPin: true,
            muted: true,
            canMute: true,
            unread: 2,
            canMarkRead: true,
            canDelete: true,
          ),
        ),
        <ChatInboxRowAction>[
          ChatInboxRowAction.pin,
          ChatInboxRowAction.unmute,
          ChatInboxRowAction.markRead,
          ChatInboxRowAction.delete,
        ],
      );
      // Nothing unread: 标为已读 is not drawn.
      expect(
        chatInboxRowActions(
          const ChatInboxRowFacts(
            pinned: true,
            canPin: true,
            muted: false,
            canMute: false,
            unread: 0,
            canMarkRead: true,
            canDelete: false,
          ),
        ),
        <ChatInboxRowAction>[ChatInboxRowAction.unpin],
      );
    });

    test('facts are read off the Stream channel itself', () async {
      final client = _LocalClient();
      addTearDown(client.dispose);

      final direct = _channel(
        client,
        cid: testDirectCid,
        capabilities: const <String>['mute-channel', 'read-events'],
        unread: 3,
      );
      expect(
        chatInboxRowActions(ChatInboxRowFacts.of(direct)),
        <ChatInboxRowAction>[
          ChatInboxRowAction.pin,
          ChatInboxRowAction.mute,
          ChatInboxRowAction.markRead,
          ChatInboxRowAction.delete,
        ],
      );

      // A community's official channel is never 删除d from the inbox, and a
      // channel without the mute capability draws no 静音.
      final community = _channel(
        client,
        cid: testCommunityCid,
        pinnedAt: DateTime.utc(2026, 10, 9),
      );
      expect(
        chatInboxRowActions(ChatInboxRowFacts.of(community)),
        <ChatInboxRowAction>[ChatInboxRowAction.unpin],
      );
    });

    testWidgets(
      'a swipe reveals the actions and a tap on the open row closes it',
      (tester) async {
        final haptics = _recordHaptics(tester);
        final chosen = <ChatInboxRowAction>[];
        var opened = 0;
        await tester.pumpWidget(
          _app(
            ChatInboxSwipeScope(
              child: ListView(
                children: <Widget>[
                  ChatInboxSwipeRow(
                    actions: () => const <ChatInboxRowAction>[
                      ChatInboxRowAction.pin,
                      ChatInboxRowAction.mute,
                      ChatInboxRowAction.markRead,
                      ChatInboxRowAction.delete,
                    ],
                    onAction: chosen.add,
                    child: ListTile(
                      title: const Text('会话一'),
                      onTap: () => opened += 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // A plain tap still opens the conversation.
        await tester.tap(find.text('会话一'));
        await tester.pumpAndSettle();
        expect(opened, 1);

        await tester.drag(find.text('会话一'), const Offset(-300, 0));
        await tester.pumpAndSettle();
        expect(haptics, contains('HapticFeedbackType.selectionClick'));
        for (final action in <String>['pin', 'mute', 'delete']) {
          expect(
            find.byKey(ValueKey<String>('chat-inbox-swipe-$action')),
            findsOneWidget,
          );
        }
        // 标为已读 lives on the other side.
        expect(
          find.byKey(const ValueKey<String>('chat-inbox-swipe-markRead')),
          findsNothing,
        );

        // The open row's tap closes it; it does not open the conversation.
        await tester.tap(
          find.byKey(const ValueKey<String>('chat-inbox-swipe-close')),
        );
        await tester.pumpAndSettle();
        expect(opened, 1);
        expect(
          find.byKey(const ValueKey<String>('chat-inbox-swipe-pin')),
          findsNothing,
        );

        await tester.drag(find.text('会话一'), const Offset(300, 0));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('chat-inbox-swipe-markRead')),
        );
        await tester.pumpAndSettle();
        expect(chosen, <ChatInboxRowAction>[ChatInboxRowAction.markRead]);
        expect(opened, 1);
      },
    );

    testWidgets('a row with no allowed action does not slide', (tester) async {
      await tester.pumpWidget(
        _app(
          ListView(
            children: <Widget>[
              ChatInboxSwipeRow(
                actions: () => const <ChatInboxRowAction>[],
                onAction: (_) {},
                child: const ListTile(title: Text('社区群')),
              ),
            ],
          ),
        ),
      );
      final before = tester.getTopLeft(find.text('社区群'));
      await tester.drag(find.text('社区群'), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('社区群')), before);
    });

    testWidgets('a long press opens the same actions in a sheet, with a buzz', (
      tester,
    ) async {
      final haptics = _recordHaptics(tester);
      ChatInboxRowAction? chosen;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => ListTile(
              title: const Text('会话二'),
              onLongPress: () async {
                chosen = await showChatInboxRowActionSheet(
                  context,
                  title: '会话操作',
                  actions: const <ChatInboxRowAction>[
                    ChatInboxRowAction.unpin,
                    ChatInboxRowAction.unmute,
                    ChatInboxRowAction.delete,
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.longPress(find.text('会话二'));
      await tester.pumpAndSettle();
      expect(haptics, contains('HapticFeedbackType.mediumImpact'));
      expect(
        find.byKey(const ValueKey<String>('chat-inbox-row-sheet')),
        findsOneWidget,
      );
      expect(find.text('取消置顶'), findsOneWidget);
      expect(find.text('取消静音'), findsOneWidget);
      expect(find.text('标为已读'), findsNothing);

      await tester.tap(find.text('取消静音'));
      await tester.pumpAndSettle();
      expect(chosen, ChatInboxRowAction.unmute);
    });
  });

  group('M3 · Watchlist', () {
    testWidgets('a left swipe removes the row, and 撤销 puts it back', (
      tester,
    ) async {
      final watchlist = FakeWatchlistGateway();
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: watchlist,
      );
      expect(find.textContaining('3 个自选资产'), findsOneWidget);
      expect(find.text('MINING 3 · 拖动排序 · 左滑删除'), findsOneWidget);

      final row = find.byKey(ValueKey<String>('watchlist-item-$s5WbnbAssetId'));
      await tester.ensureVisible(row);
      await tester.drag(row, const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(row, findsNothing);
      expect(find.textContaining('2 个自选资产'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('watchlist-undo-toast')),
        findsOneWidget,
      );
      expect(watchlist.written, isEmpty);

      await tester.tap(find.byKey(const ValueKey<String>('watchlist-undo')));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(find.textContaining('3 个自选资产'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('watchlist-undo-toast')),
        findsNothing,
      );
    });

    testWidgets('the undo offer leaves on its own', (tester) async {
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(),
      );
      await tester.tap(
        find.byKey(ValueKey<String>('watchlist-remove-$s5WbnbAssetId')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('watchlist-undo-toast')),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      expect(
        find.byKey(const ValueKey<String>('watchlist-undo-toast')),
        findsNothing,
      );
      expect(find.textContaining('2 个自选资产'), findsOneWidget);
    });

    testWidgets('the heading counts each asset once across groups', (
      tester,
    ) async {
      final base = s5Watchlist();
      final snapshot = WatchlistSnapshot(
        version: base.version,
        updatedAt: base.updatedAt,
        groups: <WatchlistGroup>[
          ...base.groups,
          WatchlistGroup(
            key: 'defi',
            name: 'DeFi',
            items: <WatchlistItem>[
              WatchlistItem(assetId: s5WbnbAssetId, asset: s5Summary()),
            ],
          ),
        ],
      );
      await pumpS5Page(
        tester,
        const WatchlistEditorScreen(),
        watchlist: FakeWatchlistGateway(
          snapshot: S5Answer<WatchlistSnapshot>(value: snapshot),
        ),
      );
      // Four rows across two groups, three assets: the heading says three,
      // the list's own label says what the list shows.
      expect(find.textContaining('3 个自选资产'), findsOneWidget);
      expect(find.textContaining('4 个自选资产'), findsNothing);
      expect(find.text('MINING 3 · 拖动排序 · 左滑删除'), findsOneWidget);
    });
  });

  group('m7 · segments follow a sideways swipe', () {
    Future<ProviderContainer> pumpSegments(
      WidgetTester tester, {
      required Widget Function(int index) body,
    }) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: LoopSegmentedTabPage(
              tabKey: 'demo',
              title: '演示',
              segments: const <String>['社区', '语音房'],
              builder: (context, index) => body(index),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    int selected(ProviderContainer container) =>
        container.read(loopTabSegmentMemoryProvider)['demo'] ?? 0;

    testWidgets('left moves on, right moves back, edges hold', (tester) async {
      final haptics = _recordHaptics(tester);
      final container = await pumpSegments(
        tester,
        body: (index) => ListView(
          children: <Widget>[
            SizedBox(height: 400, child: Center(child: Text('body $index'))),
          ],
        ),
      );
      await tester.drag(find.text('body 0'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(selected(container), 1);
      expect(find.text('body 1'), findsOneWidget);
      expect(haptics, contains('HapticFeedbackType.selectionClick'));

      await tester.drag(find.text('body 1'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(selected(container), 1);

      await tester.drag(find.text('body 1'), const Offset(200, 0));
      await tester.pumpAndSettle();
      expect(selected(container), 0);

      // A short, slow drag is not a decision.
      await tester.timedDrag(
        find.text('body 0'),
        const Offset(-30, 0),
        const Duration(milliseconds: 600),
      );
      await tester.pumpAndSettle();
      expect(selected(container), 0);
    });

    testWidgets('a horizontal list and a chart keep their own drag', (
      tester,
    ) async {
      final container = await pumpSegments(
        tester,
        body: (index) => ListView(
          children: <Widget>[
            SizedBox(
              height: 120,
              child: ListView(
                key: const ValueKey<String>('cards'),
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  for (var i = 0; i < 8; i += 1)
                    SizedBox(width: 160, child: Text('card $i')),
                ],
              ),
            ),
            const LoopSegmentSwipeBarrier(
              child: SizedBox(height: 160, child: Center(child: Text('chart'))),
            ),
            SizedBox(height: 200, child: Center(child: Text('body $index'))),
          ],
        ),
      );
      await tester.drag(find.text('card 0'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(selected(container), 0);

      await tester.drag(find.text('chart'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(selected(container), 0);

      await tester.drag(find.text('body 0'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(selected(container), 1);
    });

    testWidgets('an inner segmented body passes the swipe on at its edge', (
      tester,
    ) async {
      var inner = 0;
      final container = await pumpSegments(
        tester,
        body: (index) => StatefulBuilder(
          builder: (context, setState) => LoopSegmentSwipe(
            index: inner,
            count: 3,
            onSelect: (next) => setState(() => inner = next),
            child: ListView(
              children: <Widget>[
                SizedBox(
                  height: 400,
                  child: Center(child: Text('board $index/$inner')),
                ),
              ],
            ),
          ),
        ),
      );
      for (var step = 1; step <= 2; step += 1) {
        await tester.drag(find.textContaining('board'), const Offset(-200, 0));
        await tester.pumpAndSettle();
        expect(inner, step);
        expect(selected(container), 0);
      }
      // On the last board, the page's own segment moves.
      await tester.drag(find.textContaining('board'), const Offset(-200, 0));
      await tester.pumpAndSettle();
      expect(selected(container), 1);
    });
  });

  group('m16 · message search answers as it is typed', () {
    testWidgets('results follow the text after 300 ms, without 回车', (
      tester,
    ) async {
      final gateway = _RecordingChatSearch();
      await pumpCommunityPage(
        tester,
        const ChatSearchScreen(),
        chatSearch: gateway,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('chat-search-input')),
        '内',
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(
        find.byKey(const ValueKey<String>('chat-search-input')),
        '内盘',
      );
      await tester.pump(const Duration(milliseconds: 299));
      expect(gateway.queries, isEmpty);
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pumpAndSettle();
      expect(gateway.queries, <String>['内盘']);
      expect(
        find.byKey(const ValueKey<String>('chat-search-hit-m1')),
        findsOneWidget,
      );
      expect(find.textContaining('社区 Tab'), findsNothing);
    });
  });
}

final class _RecordingChatSearch implements ChatSearchGateway {
  final List<String> queries = <String>[];

  @override
  bool get connected => true;

  @override
  Future<List<ChatSearchHit>> search({
    required String query,
    required ChatSearchScope scope,
    required String? originCid,
    required int limit,
  }) async {
    queries.add(query);
    return <ChatSearchHit>[
      ChatSearchHit(
        messageId: 'm1',
        cid: testGroupCid,
        senderLabel: '成员',
        channelLabel: '群聊',
        text: '有人跟 MCAT 内盘吗',
        createdAt: DateTime.utc(2026, 9, 8, 12),
      ),
    ];
  }
}
