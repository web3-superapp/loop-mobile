import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/intel/intel_screen.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/features/mining/mining_gateway.dart';
import 'package:loop_mobile/features/mining/mining_models.dart';
import 'package:loop_mobile/features/profile/profile_destinations.dart';
import 'package:loop_mobile/features/profile/profile_screens.dart';
import 'package:loop_mobile/features/social/profile_face_link.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_providers.dart';
import 'package:loop_mobile/integrations/hyperliquid/hyperliquid_spot_market_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';
import 'support/loop_ground_probe.dart';

// S347 · docs/57 §三: the regressions the page slimming left behind.

// ---------------------------------------------------------------------------
// N1 / N2 · a tab is switched to, never pushed over the shell
// ---------------------------------------------------------------------------

final class _EmptySpot implements HyperliquidSpotMarketRepository {
  const _EmptySpot();

  @override
  Future<HyperliquidSpotSnapshot> fetchMarkets() async =>
      HyperliquidSpotSnapshot(
        receivedAt: DateTime.utc(2026, 11, 3),
        markets: const <HyperliquidSpotMarket>[],
      );
}

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        hyperliquidSpotMarketRepositoryProvider.overrideWithValue(
          const _EmptySpot(),
        ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(MemeScreen)));
}

String _location(GoRouter router) =>
    router.routeInformationProvider.value.uri.toString();

/// One user board whose fifth place is the reader.
final class _SelfBoard implements MiningGateway {
  final FakeMiningGateway _inner = FakeMiningGateway();

  @override
  LaunchGatewayMode get mode => LaunchGatewayMode.production;

  @override
  Future<MiningRank> loadRank(MiningRankScope scope, {String? cursor}) =>
      Future<MiningRank>.value(
        s7MiningRank(
          scope: scope,
          snapshot: s7MiningSnapshot(),
          me: const MiningRankMe(rank: 5, value: '3020'),
          ranking: MiningRankingUsers(
            items: <MiningRankUserRow>[
              for (var index = 0; index < 8; index += 1)
                MiningRankUserRow(
                  position: index + 1,
                  power: '${3420 - index * 100}',
                  powerVisibility: MiningRankAudience.everyone,
                  display: MiningRankAlias(
                    alias: 'member${index + 1}',
                    publicProfileId:
                        '8c2b7a15-4d3e-4f60-9a11-'
                        '${(index + 1).toString().padLeft(12, '0')}',
                    audience: MiningRankAudience.everyone,
                  ),
                  isSelf: index == 4,
                ),
            ],
            participants: 40,
          ),
        ),
      );

  @override
  Future<MiningSummary> loadSummary() => _inner.loadSummary();

  @override
  Future<MiningAssets> loadAssets() => _inner.loadAssets();

  @override
  Future<MiningCommunity> loadCommunity(String communityId) =>
      _inner.loadCommunity(communityId);

  @override
  Future<MiningRules> loadRules() => _inner.loadRules();
}

// ---------------------------------------------------------------------------
// N3 · 聊天 in two parts, each its own Stream query
// ---------------------------------------------------------------------------

const String _me = 'me';
const String _hex = '0123456789abcdef0123456789ab';

/// Answers each part's query from its own scripted rows, page by page.
class _InboxClient extends StreamChatClient {
  _InboxClient() : super('key', logLevel: Level.OFF) {
    // ignore: invalid_use_of_internal_member
    state.currentUser = OwnUser(id: _me);
  }

  final Map<ChatInboxSection, List<Channel>> rows =
      <ChatInboxSection, List<Channel>>{};
  final List<(ChatInboxSection, int, int)> reads =
      <(ChatInboxSection, int, int)>[];

  /// A part whose next read waits for this gate.
  final Map<ChatInboxSection, Completer<void>> gates =
      <ChatInboxSection, Completer<void>>{};

  ChatInboxSection _sectionOf(Filter? filter) => ChatInboxSection.values
      .firstWhere((it) => loopStreamInboxSectionFilter(_me, it) == filter);

  @override
  Stream<QueryChannelsResult> queryChannelsWithResult({
    Filter? filter,
    SortOrder<ChannelState>? channelStateSort,
    String? predefinedFilter,
    Map<String, Object?>? filterValues,
    Map<String, Object?>? sortValues,
    bool state = true,
    bool watch = true,
    bool presence = false,
    int? memberLimit,
    int? messageLimit,
    PaginationParams paginationParams = const PaginationParams(),
    bool waitForConnect = true,
  }) async* {
    final section = _sectionOf(filter);
    final offset = paginationParams.offset ?? 0;
    final limit = paginationParams.limit;
    reads.add((section, offset, limit));
    final gate = gates.remove(section);
    if (gate != null) await gate.future;
    final all = rows[section] ?? const <Channel>[];
    yield QueryChannelsResult(
      channels: all.sublist(
        offset < all.length ? offset : all.length,
        offset + limit < all.length ? offset + limit : all.length,
      ),
    );
  }
}

Channel _row(
  StreamChatClient client,
  String prefix,
  int index, {
  DateTime? pinnedAt,
}) {
  final id = '$prefix$_hex${index.toString().padLeft(4, '0')}';
  return Channel.fromState(
    client,
    ChannelState(
      channel: ChannelModel(
        id: id,
        type: 'messaging',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        // Newest first, as Stream answers.
        lastMessageAt: DateTime.utc(
          2026,
          11,
          3,
        ).subtract(Duration(minutes: index)),
      ),
      membership: Member(userId: _me, pinnedAt: pinnedAt),
    ),
  );
}

List<Channel> _items(StreamChannelListController controller) =>
    controller.value.asSuccess.items;

void main() {
  loopWatchGround();

  group('N1 · 算力榜: the reader\'s own row opens 我的', () {
    testWidgets('the self row switches to the tab instead of pushing it', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/mining/rank',
        routes: <RouteBase>[
          GoRoute(path: '/mining/rank', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/wallet', builder: (_, _) => const SizedBox()),
        ],
      );
      addTearDown(router.dispose);
      final pushed = <String>[];
      await pumpS7Page(
        tester,
        InheritedGoRouter(
          goRouter: router,
          child: IntelRankBoard(onNavigate: pushed.add),
        ),
        mining: _SelfBoard(),
      );
      await tester.tap(find.text('用户'));
      await tester.pumpAndSettle();
      final self = find.byKey(const ValueKey<String>('intel-rank-user-4'));
      await tester.ensureVisible(self);
      await tester.tap(self);
      await tester.pumpAndSettle();
      expect(pushed, isEmpty);
      expect(_location(router), loopOwnProfileLocation);
      // Somebody else's row still opens their page through the host.
      final other = find.byKey(const ValueKey<String>('intel-rank-user-3'));
      await tester.tap(other);
      await tester.pumpAndSettle();
      expect(pushed.single, startsWith('/profile/user'));
    });

    testWidgets('from /mining/rank, 我的 is reached without a crash', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      unawaited(router.push('/mining/rank'));
      await tester.pumpAndSettle();
      tester
          .widget<IntelRankBoard>(find.byType(IntelRankBoard))
          .onNavigate(loopOwnProfileLocation);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_location(router), '/wallet');
      expect(router.canPop(), isFalse);
    });

    testWidgets('from the board a community page opened, the same', (
      tester,
    ) async {
      final router = await _pumpApp(tester);
      unawaited(
        router.push(
          '/mining/community?id=8c2b7a15-4d3e-4f60-9a11-000000000001',
        ),
      );
      await tester.pumpAndSettle();
      unawaited(router.push('/mining/rank'));
      await tester.pumpAndSettle();
      final board = tester.widget<IntelRankBoard>(find.byType(IntelRankBoard));
      board.onNavigate(loopOwnProfileLocation);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_location(router), '/wallet');
      expect(router.canPop(), isFalse);
    });
  });

  group('N2 · a tab with a query is still a tab', () {
    testWidgets('我的 · 邀请好友 lands on 情报 · 算力 · 邀请', (tester) async {
      final router = await _pumpApp(tester);
      unawaited(router.push('/profile/settings'));
      await tester.pumpAndSettle();
      tester
          .widget<ProfileSurfaceScreen>(find.byType(ProfileSurfaceScreen))
          .onNavigate!('invite');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(profileDestinationPath('invite'), loopIntelInviteLocation);
      // 情报 takes the tab it was handed and keeps its own address.
      expect(router.routeInformationProvider.value.uri.path, '/intel');
      expect(router.canPop(), isFalse);
      expect(find.byType(IntelScreen), findsOneWidget);
    });
  });

  group('N3 · 聊天: 社区 whole, 好友 paged', () {
    late _InboxClient client;
    setUp(() => client = _InboxClient());
    tearDown(() => client.dispose());

    test('each part is its own query', () {
      expect(
        loopStreamInboxSectionFilter(_me, ChatInboxSection.communities),
        Filter.and(<Filter>[
          Filter.equal('type', 'messaging'),
          Filter.in_('members', <Object>[_me]),
          Filter.equal('loop_channel_kind', 'community'),
        ]),
      );
      expect(
        loopStreamInboxSectionFilter(_me, ChatInboxSection.friends),
        Filter.and(<Filter>[
          Filter.equal('type', 'messaging'),
          Filter.in_('members', <Object>[_me]),
          Filter.in_('loop_channel_kind', const <Object>['direct', 'group']),
        ]),
      );
    });

    test('with more than 20 conversations 社区 is whole on the first '
        'screen and a 好友 page only adds below it', () async {
      final communities = <Channel>[
        for (var i = 0; i < 44; i += 1) _row(client, 'loop_community_', i),
        // A pinned room the first page does not carry.
        _row(
          client,
          'loop_community_',
          44,
          pinnedAt: DateTime.utc(2026, 11, 1),
        ),
      ];
      final friends = <Channel>[
        for (var i = 0; i < 45; i += 1) _row(client, 'loop_direct_', i),
      ];
      client.rows[ChatInboxSection.communities] = communities;
      client.rows[ChatInboxSection.friends] = friends;
      final controller = createLoopStreamChannelListController(
        client: client,
        userId: _me,
      ) as LoopSectionedChannelListController;
      addTearDown(controller.dispose);
      final seen = <PagedValue<int, Channel>>[];
      controller.addListener(() => seen.add(controller.value));

      await controller.doInitialLoad();

      // 社区 read to its end (30 + 15), 好友 its first read only.
      expect(
        client.reads,
        containsAll(<(ChatInboxSection, int, int)>[
          (ChatInboxSection.communities, 0, 30),
          (ChatInboxSection.communities, 30, 30),
          (ChatInboxSection.friends, 0, 30),
        ]),
      );
      expect(client.reads, hasLength(3));
      // Nothing was drawn with a part of 社区: loading, then the whole.
      for (final value in seen.where((it) => it.isSuccess)) {
        final rooms = value.asSuccess.items
            .where(
              (it) =>
                  ChatInboxSection.of(it.cid) == ChatInboxSection.communities,
            )
            .length;
        expect(rooms, 45);
      }
      final first = List<Channel>.of(_items(controller));
      expect(first, hasLength(75));
      // The pinned room stands first in its own part.
      expect(first.first, same(communities.last));
      expect(
        first
            .take(45)
            .every(
              (it) =>
                  ChatInboxSection.of(it.cid) == ChatInboxSection.communities,
            ),
        isTrue,
      );
      expect(controller.value.asSuccess.nextPageKey, 30);

      // The next 好友 page: every row already drawn keeps its place.
      await controller.loadMore(controller.value.asSuccess.nextPageKey!);
      final paged = _items(controller);
      expect(paged, hasLength(90));
      for (var i = 0; i < first.length; i += 1) {
        expect(paged[i], same(first[i]), reason: 'row $i moved');
      }
      expect(controller.value.asSuccess.nextPageKey, isNull);
    });

    test('a re-read keeps the whole of 社区 until the new whole lands', () async {
      client.rows[ChatInboxSection.communities] = <Channel>[
        for (var i = 0; i < 40; i += 1) _row(client, 'loop_community_', i),
      ];
      client.rows[ChatInboxSection.friends] = <Channel>[
        for (var i = 0; i < 3; i += 1) _row(client, 'loop_group_', i),
      ];
      final controller = createLoopStreamChannelListController(
        client: client,
        userId: _me,
      ) as LoopSectionedChannelListController;
      addTearDown(controller.dispose);
      await controller.doInitialLoad();
      expect(_items(controller), hasLength(43));

      final gate = Completer<void>();
      final seen = <int>[];
      controller.addListener(() {
        if (controller.value.isSuccess) seen.add(_items(controller).length);
      });
      // The second page of the re-read waits.
      final reread = controller.refresh(resetValue: false);
      await Future<void>.delayed(Duration.zero);
      client.gates[ChatInboxSection.communities] = gate;
      await Future<void>.delayed(Duration.zero);
      expect(_items(controller), hasLength(43));
      gate.complete();
      await reread;
      expect(seen.every((it) => it == 43), isTrue, reason: '$seen');
    });

    test('a live event stays in its own part', () async {
      client.rows[ChatInboxSection.communities] = <Channel>[
        _row(client, 'loop_community_', 0),
      ];
      client.rows[ChatInboxSection.friends] = <Channel>[
        _row(client, 'loop_direct_', 0),
      ];
      final controller = createLoopStreamChannelListController(
        client: client,
        userId: _me,
      ) as LoopSectionedChannelListController;
      addTearDown(controller.dispose);
      await controller.doInitialLoad();
      client.reads.clear();

      // A message in a room neither part holds yet: only 社区 reads again.
      client.handleEvent(
        Event(
          type: EventType.messageNew,
          cid: 'messaging:loop_community_${_hex}0099',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(client.reads.map((it) => it.$1).toSet(), <ChatInboxSection>{
        ChatInboxSection.communities,
      });

      client.reads.clear();
      client.handleEvent(
        Event(
          type: EventType.messageNew,
          cid: 'messaging:loop_direct_${_hex}0099',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(client.reads.map((it) => it.$1).toSet(), <ChatInboxSection>{
        ChatInboxSection.friends,
      });
    });

    test('a seed opens each row in its own part', () {
      final dm = _row(client, 'loop_direct_', 0);
      final room = _row(client, 'loop_community_', 0);
      final controller = createLoopStreamChannelListController(
        client: client,
        userId: _me,
        initialChannels: <Channel>[dm, room],
      ) as LoopSectionedChannelListController;
      addTearDown(controller.dispose);
      expect(_items(controller), <Channel>[room, dm]);
      expect(_items(controller.communities), <Channel>[room]);
      expect(_items(controller.friends), <Channel>[dm]);
    });

    testWidgets('a part with nothing says so in one line', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: Column(
              children: <Widget>[
                ChatInboxSectionEmpty(section: ChatInboxSection.communities),
                ChatInboxSectionEmpty(section: ChatInboxSection.friends),
              ],
            ),
          ),
        ),
      );
      expect(find.text('暂无社区会话'), findsOneWidget);
      expect(find.text('暂无好友会话'), findsOneWidget);
    });
  });
}
