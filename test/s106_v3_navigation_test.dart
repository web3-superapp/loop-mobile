import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/intel/intel_screen.dart';
import 'package:loop_mobile/features/meme/meme_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/features/square/live_voice_rooms.dart';
import 'package:loop_mobile/features/square/square_screen.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_live_voice_rooms.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_page_harness.dart';

const _roomA = '8c7b6a59-4d3e-4f21-8a0b-1c2d3e4f5a6b';
const _roomB = '2b3c4d5e-6f70-4182-9394-a5b6c7d8e9f0';
const _communityB = '4b96a75e-6828-4a6b-8c1d-2e3f4a5b6c7d';
const _host = '9c1f0f2e-5a7b-4c3d-8e9f-0a1b2c3d4e5f';

/// The backend's own example from `frontend-v2-communication-api.md`
/// (广场在线语音房), byte for byte in shape.
Map<String, Object?> _wirePage({String? nextCursor}) => <String, Object?>{
  'items': <Object?>[
    <String, Object?>{
      'voiceRoomId': _roomA,
      'communityId': testCommunityId,
      'communityName': 'Builders Guild',
      'communityLogoRef': 'avatar:preset/community-03',
      'title': null,
      'host': <String, Object?>{
        'publicProfileId': _host,
        'displayName': 'frog_maxi',
        'avatarRef': 'avatar:preset/people-03',
      },
      'listenerCount': 4,
      'speakerCount': 1,
      'countsObservedAt': null,
      'startedAt': '2026-10-08T03:00:00.000Z',
      'joinable': true,
    },
    <String, Object?>{
      'voiceRoomId': _roomB,
      'communityId': _communityB,
      'communityName': 'Frog Holders',
      'communityLogoRef': null,
      'title': null,
      'host': <String, Object?>{
        'publicProfileId': null,
        'displayName': null,
        'avatarRef': null,
      },
      'listenerCount': 0,
      'speakerCount': 0,
      'countsObservedAt': null,
      'startedAt': '2026-10-08T01:00:00.000Z',
      'joinable': false,
    },
  ],
  'nextCursor': nextCursor,
  'observedAt': '2026-10-08T04:00:00.000Z',
  'contractVersion': '2.0',
};

LiveVoiceRoomPage _page({String? nextCursor, List<LiveVoiceRoom>? items}) {
  final decoded = LoopV2LiveVoiceRoomCodec.page(
    _wirePage(nextCursor: nextCursor),
  );
  return LiveVoiceRoomPage(
    items: items ?? decoded.items,
    nextCursor: decoded.nextCursor,
    observedAt: decoded.observedAt,
  );
}

final class _FakeLiveGateway implements LiveVoiceRoomGateway {
  _FakeLiveGateway({
    this.pages = const <LiveVoiceRoomPage>[],
    this.failure,
    this.pending = false,
    this.mode = CommunityGatewayMode.production,
  });

  final List<LiveVoiceRoomPage> pages;
  final CommunityFailureKind? failure;
  final bool pending;

  @override
  final CommunityGatewayMode mode;

  final List<String?> cursors = <String?>[];

  @override
  Future<LiveVoiceRoomPage> listLive({String? cursor}) {
    cursors.add(cursor);
    if (pending) return Completer<LiveVoiceRoomPage>().future;
    final kind = failure;
    if (kind != null) {
      return Future<LiveVoiceRoomPage>.error(CommunityGatewayException(kind));
    }
    final index = cursors.length - 1;
    return Future<LiveVoiceRoomPage>.value(
      pages[index < pages.length ? index : pages.length - 1],
    );
  }
}

Future<void> _pumpRooms(
  WidgetTester tester,
  LiveVoiceRoomGateway gateway, {
  ValueChanged<String>? onOpenCommunity,
  ValueChanged<String>? onOpenVoiceRoom,
  bool settle = true,
}) => pumpCommunityPage(
  tester,
  LiveVoiceRoomList(
    onOpenCommunity: onOpenCommunity ?? (_) {},
    onOpenVoiceRoom: onOpenVoiceRoom ?? (_) {},
    now: () => DateTime.utc(2026, 10, 8, 4),
  ),
  settle: settle,
  overrides: <Override>[
    liveVoiceRoomGatewayProvider.overrideWithValue(gateway),
  ],
);

void main() {
  // Two tests mount pages through their own `pumpWidget`.
  loopWatchGround();

  group('GET /v2/voice-rooms/live codec', () {
    test('reads the backend example, anonymous host included', () {
      final page = LoopV2LiveVoiceRoomCodec.page(_wirePage());
      expect(page.items, hasLength(2));
      expect(page.nextCursor, isNull);
      final named = page.items.first;
      expect(named.communityName, 'Builders Guild');
      expect(named.title, isNull);
      expect(named.host.displayName, 'frog_maxi');
      expect(named.listenerCount, 4);
      expect(named.speakerCount, 1);
      expect(named.countsObservedAt, isNull);
      expect(named.joinable, isTrue);
      final anonymous = page.items.last;
      expect(anonymous.host.displayName, isNull);
      expect(anonymous.host.publicProfileId, isNull);
      expect(anonymous.communityLogoRef, isNull);
      expect(anonymous.joinable, isFalse);
    });

    test('refuses an unknown key, a missing version and a half-named host', () {
      final extra = _wirePage()..['total'] = 2;
      expect(
        () => LoopV2LiveVoiceRoomCodec.page(extra),
        throwsA(isA<LoopBackendFailure>()),
      );
      final noVersion = _wirePage()..remove('contractVersion');
      expect(
        () => LoopV2LiveVoiceRoomCodec.page(noVersion),
        throwsA(isA<LoopBackendFailure>()),
      );
      expect(
        () => LoopV2LiveVoiceRoomCodec.host(<String, Object?>{
          'publicProfileId': _host,
          'displayName': null,
          'avatarRef': null,
        }),
        throwsA(isA<LoopBackendFailure>()),
      );
      final logoUrl = _wirePage();
      ((logoUrl['items']! as List<Object?>).first!
              as Map<String, Object?>)['communityLogoRef'] =
          'https://example.com/logo.png';
      expect(
        () => LoopV2LiveVoiceRoomCodec.page(logoUrl),
        throwsA(isA<LoopBackendFailure>()),
      );
    });

    test('a route the server does not serve and a closed capability are '
        'both unavailable', () {
      expect(
        liveVoiceRoomFailureKind(
          const LoopBackendFailure(
            LoopBackendFailureKind.invalidPayload,
            statusCode: 404,
          ),
        ),
        CommunityFailureKind.unavailable,
      );
      expect(
        liveVoiceRoomFailureKind(
          const LoopBackendFailure(
            LoopBackendFailureKind.unavailable,
            statusCode: 503,
            code: 'CAPABILITY_UNAVAILABLE',
          ),
        ),
        CommunityFailureKind.unavailable,
      );
      expect(
        liveVoiceRoomFailureKind(
          const LoopBackendFailure(LoopBackendFailureKind.connection),
        ),
        CommunityFailureKind.offline,
      );
    });

    test('a 404 from the transport becomes the unavailable state', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = _StatusAdapter(404);
      final api = DioLoopV2LiveVoiceRoomApi(dio);
      await expectLater(
        api.listLive(accessToken: 'token', clientVersion: '1.0.0'),
        throwsA(
          isA<LoopBackendFailure>().having(
            (failure) => liveVoiceRoomFailureKind(failure),
            'kind',
            CommunityFailureKind.unavailable,
          ),
        ),
      );
    });
  });

  group('square · 语音房 segment', () {
    testWidgets('loading draws the skeleton', (tester) async {
      await _pumpRooms(tester, _FakeLiveGateway(pending: true), settle: false);
      expect(
        find.byKey(const ValueKey<String>('community-state-loading')),
        findsOneWidget,
      );
    });

    testWidgets('an empty list says no room is live', (tester) async {
      await _pumpRooms(
        tester,
        _FakeLiveGateway(
          pages: <LiveVoiceRoomPage>[_page(items: const <LiveVoiceRoom>[])],
        ),
      );
      expect(find.text('现在没有正在直播的语音房'), findsOneWidget);
    });

    for (final (kind, key) in <(CommunityFailureKind, String)>[
      (CommunityFailureKind.unexpected, 'community-state-error'),
      (CommunityFailureKind.offline, 'community-state-offline'),
      (CommunityFailureKind.unavailable, 'community-state-unavailable'),
      (CommunityFailureKind.permissionDenied, 'community-state-permission'),
    ]) {
      testWidgets('${kind.name} renders its own state and no row', (
        tester,
      ) async {
        await _pumpRooms(tester, _FakeLiveGateway(failure: kind));
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget);
        expect(find.text('Builders Guild'), findsNothing);
      });
    }

    testWidgets('a production build without inputs reads nothing', (
      tester,
    ) async {
      await _pumpRooms(tester, const UnavailableLiveVoiceRoomGateway());
      expect(
        find.byKey(const ValueKey<String>('community-state-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('rows state the host, the room total and the time live', (
      tester,
    ) async {
      final opened = <String>[];
      await _pumpRooms(
        tester,
        _FakeLiveGateway(pages: <LiveVoiceRoomPage>[_page()]),
        onOpenVoiceRoom: opened.add,
      );
      expect(find.text('Builders Guild'), findsOneWidget);
      // Decision 0115: the card is the room's title, its community, the host
      // and the room's own total (host + speakers + listeners).
      expect(find.text('Builders Guild 语音房'), findsOneWidget);
      expect(find.text('主持 frog_maxi'), findsOneWidget);
      expect(find.text('6 在听 · 开播 1 小时'), findsOneWidget);
      expect(find.text('主持 匿名成员'), findsOneWidget);
      expect(find.text('1 在听 · 开播 3 小时'), findsOneWidget);
      expect(find.textContaining('在线'), findsNothing);
      expect(find.textContaining('演示数据'), findsNothing);

      await tester.tap(find.text('Builders Guild'));
      await tester.pumpAndSettle();
      expect(opened, <String>[testCommunityId]);
    });

    testWidgets('a room of a community the reader is not in opens the '
        'community and says why', (tester) async {
      final communities = <String>[];
      final rooms = <String>[];
      await _pumpRooms(
        tester,
        _FakeLiveGateway(pages: <LiveVoiceRoomPage>[_page()]),
        onOpenCommunity: communities.add,
        onOpenVoiceRoom: rooms.add,
      );
      await tester.tap(find.text('Frog Holders'));
      await tester.pump();
      expect(rooms, isEmpty);
      expect(communities, <String>[_communityB]);
      expect(find.text('加入「Frog Holders」后才能进入语音房'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('the next cursor page is read without a button', (
      tester,
    ) async {
      final gateway = _FakeLiveGateway(
        pages: <LiveVoiceRoomPage>[
          _page(nextCursor: 'abc.def'),
          _page(nextCursor: null),
        ],
      );
      await _pumpRooms(tester, gateway);
      expect(gateway.cursors, <String?>[null, 'abc.def']);
      expect(find.text('载入更多'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('square-voice-room-end')),
        findsOneWidget,
      );
    });

    testWidgets('a Preview list carries the 演示数据 notice', (tester) async {
      await _pumpRooms(
        tester,
        _FakeLiveGateway(
          pages: <LiveVoiceRoomPage>[_page()],
          mode: CommunityGatewayMode.preview,
        ),
      );
      expect(find.text('演示数据'), findsOneWidget);
    });
  });

  group('square · page segments', () {
    testWidgets('社区 lists the directory; the segment survives leaving the '
        'tab', (tester) async {
      final container = ProviderContainer(
        overrides: <Override>[
          communityGatewayProvider.overrideWithValue(
            FakeCommunityGateway(
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
            ),
          ),
          liveVoiceRoomGatewayProvider.overrideWithValue(
            _FakeLiveGateway(pages: <LiveVoiceRoomPage>[_page()]),
          ),
        ],
      );
      addTearDown(container.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1400);
      addTearDown(tester.view.reset);
      Widget app(Widget home) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LoopTheme.dark,
          home: LoopToastHost(child: home),
        ),
      );
      final square = SquareScreen(
        onOpenCommunity: (_) {},
        onOpenVoiceRoom: (_) {},
      );

      await tester.pumpWidget(app(square));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('community-discover-screen')),
        findsOneWidget,
      );
      // The segment is the page heading; there is no bar title above it.
      expect(find.text('发现社区'), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('square-segment-1')));
      await tester.pumpAndSettle();
      expect(find.text('Builders Guild'), findsOneWidget);

      await tester.pumpWidget(app(const SizedBox.shrink()));
      await tester.pumpWidget(app(square));
      await tester.pumpAndSettle();
      expect(container.read(loopTabSegmentMemoryProvider)['square'], 1);
      expect(
        find.byKey(const ValueKey<String>('square-voice-rooms')),
        findsOneWidget,
      );
      // Let the retained reads' release timers run out before teardown.
      await tester.pumpWidget(app(const SizedBox.shrink()));
      await tester.pump(const Duration(minutes: 30));
    });
  });

  group('meme', () {
    testWidgets('IDO hidden by default: 发射台 is coming, 行情 has no source', (
      tester,
    ) async {
      final launch = FakeLaunchGateway();
      await pumpS7Page(tester, const MemeScreen(), launch: launch);
      expect(find.text('发射台即将开放'), findsWidgets);
      expect(find.byKey(const ValueKey<String>('launch-screen')), findsNothing);

      await tester.tap(find.byKey(const ValueKey<String>('meme-segment-1')));
      await tester.pumpAndSettle();
      expect(find.text('平台 MEME 资产上线后在这里显示'), findsWidgets);
    });

    testWidgets('the switch brings the Launch catalogue back', (tester) async {
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
      expect(find.text('发射台即将开放'), findsNothing);
      // The embedded catalogue draws no bar, so its two tools stand on the
      // segment row (S106b).
      expect(
        find.byKey(const ValueKey<String>('launch-stake-action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('launch-rules-action')),
        findsOneWidget,
      );
    });
  });

  group('intel', () {
    testWidgets('算力榜 adds a 推广 board that says it is not open', (tester) async {
      await pumpS7Page(
        tester,
        const MiningRankScreen(embedded: true, includeReferralScope: true),
        mining: FakeMiningGateway(),
      );
      // Embedded: the tab page owns the bar.
      expect(find.text('算力排行榜'), findsNothing);
      await tester.tap(find.text('推广榜'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('mining-rank-referral-unavailable')),
        findsOneWidget,
      );
    });

    testWidgets('行情 drops 新币 and 聪明钱', (tester) async {
      await pumpS5Page(
        tester,
        IntelScreen(onNavigate: (_) {}),
        market: FakeMarketReadGateway(),
      );
      await tester.tap(find.byKey(const ValueKey<String>('intel-segment-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('market-screen')), findsOne);
      expect(find.byKey(const ValueKey<String>('market-tabs')), findsOne);
      expect(find.byKey(const ValueKey<String>('market-tab-新币')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('market-smart-money-entry')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('intel-alerts-action')),
        findsOne,
      );
    });
  });

  group('chat tab', () {
    test('the filters read the server-assigned channel prefix', () {
      const hex = '0123456789abcdef0123456789abcdef';
      const community = 'messaging:loop_community_$hex';
      const direct = 'messaging:loop_direct_$hex';
      const group = 'messaging:loop_group_$hex';
      const unknown = 'messaging:loop-room-42';
      expect(ChatInboxFilter.values.map((filter) => filter.label), <String>[
        '全部',
        '社区',
        '好友',
      ]);
      for (final cid in <String>[community, direct, group, unknown]) {
        expect(ChatInboxFilter.all.includes(cid), isTrue, reason: cid);
      }
      expect(ChatInboxFilter.communities.includes(community), isTrue);
      expect(ChatInboxFilter.communities.includes(direct), isFalse);
      expect(ChatInboxFilter.friends.includes(direct), isTrue);
      expect(ChatInboxFilter.friends.includes(group), isTrue);
      expect(ChatInboxFilter.friends.includes(community), isFalse);
      expect(ChatInboxFilter.friends.includes(unknown), isFalse);
      expect(ChatInboxFilter.communities.includes(null), isFalse);
    });

    testWidgets('connecting, then not connected: the head stays usable', (
      tester,
    ) async {
      final authorization = Completer<StreamSessionAuthorization>();
      var profileOpened = 0;
      await pumpCommunityPage(
        tester,
        StreamChatInboxPage(onOpenProfile: () => profileOpened++),
        settle: false,
        streamAuthorization: () => authorization.future,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('stream-chat-connecting')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('chat-inbox-filters')),
        findsOneWidget,
      );
      expect(find.text('聊天'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey<String>('chat-open-profile')));
      expect(profileOpened, 1);

      authorization.complete(StreamSessionAuthorization.unavailable);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('stream-chat-unavailable')),
        findsOneWidget,
      );
      // No stranger request was read, so no request row stands here.
      expect(
        find.byKey(
          const ValueKey<String>('stream-chat-message-requests-entry'),
        ),
        findsNothing,
      );
    });

    testWidgets('「＋」 holds search, community, group and scan', (tester) async {
      await pumpCommunityPage(
        tester,
        const StreamChatInboxPage(),
        streamAuthorization: () async => StreamSessionAuthorization.unavailable,
      );
      await tester.tap(find.byKey(const ValueKey<String>('chat-create-menu')));
      await tester.pumpAndSettle();
      for (final key in <String>[
        'chat-add-friend-menu-item',
        'chat-create-community-menu-item',
        'chat-create-group-menu-item',
        'chat-scan-menu-item',
      ]) {
        expect(find.byKey(ValueKey<String>(key)), findsOneWidget, reason: key);
      }
      await tester.tap(
        find.byKey(const ValueKey<String>('chat-scan-menu-item')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('扫一扫暂未开放'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a stream error closes the list and offers a retry', (
      tester,
    ) async {
      await pumpCommunityPage(
        tester,
        const StreamChatInboxPage(),
        streamAuthorization: () =>
            Future<StreamSessionAuthorization>.error(StateError('offline')),
      );
      expect(
        find.byKey(const ValueKey<String>('stream-chat-unavailable')),
        findsOneWidget,
      );
      expect(find.text('重试'), findsOneWidget);
    });

    test('the provider default stays closed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        container.read(liveVoiceRoomGatewayProvider).mode,
        CommunityGatewayMode.unavailable,
      );
      expect(
        container.read(loopFeatureSwitchesProvider).idoLaunchVisible,
        LoopFeatureSwitches.idoLaunchVisible,
      );
      expect(LoopFeatureSwitches.idoLaunchVisible, isFalse);
      expect(LoopFeatureSwitches.groupAliasVisible, isFalse);
      expect(streamChatAuthorizationProvider, isNotNull);
    });
  });
}

/// Answers every request with [status] and no LOOP error body, the way a
/// server that does not mount the route answers.
final class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"message":"Route GET:/v2/voice-rooms/live not found"}',
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}
