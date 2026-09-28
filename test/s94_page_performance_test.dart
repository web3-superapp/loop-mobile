import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_recent_answers.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/network/loop_dio_factory.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chat/stream_chat_inbox_page.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_screen.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart' show S5Answer, FakeMarketReadGateway;
import 'support/s5_page_harness.dart' as s5;

final class _Clock {
  _Clock(this.now);

  DateTime now;

  DateTime call() => now;
}

final class _RealSockets extends HttpOverrides {}

final class _Account extends Notifier<String?> {
  @override
  String? build() => 'account-a';

  void switchTo(String next) => state = next;
}

ProviderContainer _container(List<Override> overrides) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

Future<void> _drain() async {
  for (var index = 0; index < 5; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A community gateway whose record read is held by the test, so a page can
/// be observed while that one round trip is still in the air.
final class _HeldRecordGateway extends Fake implements CommunityGateway {
  _HeldRecordGateway({required this.home});

  final CommunityHome home;
  final Completer<CommunityDetail> record = Completer<CommunityDetail>();
  int recordReads = 0;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<CommunityHome> loadHome() async => home;

  @override
  Future<CommunityDetail> loadCommunity(String communityId) {
    recordReads += 1;
    return record.future;
  }
}

/// A market gateway that records which asset quotes were asked for and never
/// answers them.
final class _HeldMarket extends Fake implements MarketReadGateway {
  final List<String> assetReads = <String>[];

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<MarketAssetDetail> loadAsset(String assetId) {
    assetReads.add(assetId);
    return Completer<MarketAssetDetail>().future;
  }

  @override
  Future<MarketCandleSeries> loadCandles(
    String assetId, {
    required LoopCandleInterval interval,
    int? limit,
  }) => Completer<MarketCandleSeries>().future;
}

/// An HTTP client whose every request hangs, like a CDN the device cannot
/// reach.
final class _HangingHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      Completer<HttpClientRequest>().future;
}

CommunityHome _homeListing(CommunitySummary community) => CommunityHome(
  joined: <JoinedCommunity>[
    JoinedCommunity(
      community: community,
      membership: CommunityMembership(
        role: CommunityRole.member,
        status: CommunityMemberStatus.active,
        joinedAt: DateTime.utc(2026, 7),
      ),
    ),
  ],
  joinedTruncated: false,
  discover: const <CommunitySummary>[],
  unread: const LoopUnavailableFact('STREAM_UNREAD_NOT_CONNECTED'),
  liveVoice: const LoopUnavailableFact('STREAM_VOICE_NOT_CONNECTED'),
  observedAt: DateTime.utc(2026, 9, 28, 1),
  source: 'database',
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
);

CommunityDirectoryPage _directory(String name) => CommunityDirectoryPage(
  ordering: const CommunityOrderingApplied(
    sort: CommunityDirectorySort.members,
    basis: CommunityStoredBasis(),
  ),
  items: <CommunitySummary>[testCommunity(name: name)],
  nextCursor: null,
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
);

/// Keeps the 社区 aggregate read and alive, as the tab below a pushed page
/// does.
class _HomeHolder extends ConsumerWidget {
  const _HomeHolder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityHomeControllerProvider);
    if (state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(
        () => ref.read(communityHomeControllerProvider.notifier).load(),
      );
    }
    return const SizedBox.shrink();
  }
}

void main() {
  loopWatchGround();

  // -------------------------------------------------------------------------
  // 1. One keep-alive pool per origin
  // -------------------------------------------------------------------------
  group('connection pool', () {
    test('idle sockets outlive a page visit but not the server', () {
      expect(LoopDioFactory.idleConnectionTimeout, const Duration(seconds: 60));
      // The LOOP API closes idle sockets after 72 s; the client lets go
      // first so it never writes on a socket the server already closed.
      expect(
        LoopDioFactory.idleConnectionTimeout,
        lessThan(const Duration(seconds: 72)),
      );
    });

    test(
      'two clients on one origin share sockets, and closing one keeps the other',
      // The widget binding answers every HttpClient with a 400; this test
      // talks to a real loopback server, so it opts back into real sockets.
      () => HttpOverrides.runWithHttpOverrides(() async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final peers = <int>[];
        server.listen((request) async {
          peers.add(request.connectionInfo!.remotePort);
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"ok":true}');
          await request.response.close();
        });
        final origin = Uri.parse('http://127.0.0.1:${server.port}/');
        final first = LoopDioFactory.createLoopBackend(origin: origin);
        final second = LoopDioFactory.createLoopBackend(origin: origin);
        addTearDown(() => second.close(force: true));

        await first.get<Object?>('/v2/meta/capabilities');
        await second.get<Object?>('/v2/meta/client-policy');
        // The second client's request rode the socket the first one opened.
        expect(peers, hasLength(2));
        expect(peers.toSet(), hasLength(1));

        first.close();
        final response = await second.get<Object?>('/v2/profile');
        expect(response.statusCode, 200);
        expect(peers.toSet(), hasLength(1));
      }, _RealSockets()),
    );

    test('the pool is still a trust boundary per client', () async {
      final client = LoopDioFactory.createLoopBackend(
        origin: Uri.parse('https://api.example.com/'),
      );
      addTearDown(client.close);
      await expectLater(
        client.get<Object?>(
          '/v2/profile',
          options: Options(headers: const <String, String>{'Cookie': 'a=b'}),
        ),
        throwsA(isA<DioException>()),
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2. Token page · the chart is asked for with the quote
  // -------------------------------------------------------------------------
  group('token page', () {
    testWidgets('candles are requested while the quote is still in the air', (
      tester,
    ) async {
      final market = FakeMarketReadGateway(
        asset: S5Answer<MarketAssetDetail>(pending: true),
      );
      await s5.pumpS5Page(
        tester,
        const TokenDetailScreen(assetId: s5WbnbAssetId),
        market: market,
        settle: false,
      );
      await tester.pump();

      expect(market.assetReads, <String>[s5WbnbAssetId]);
      // One round trip, not two: the candle read did not wait for the quote.
      expect(market.intervals, <LoopCandleInterval>[
        LoopCandleInterval.oneHour,
      ]);
      // The page is still a skeleton; nothing about it was drawn early.
      expect(find.byKey(const ValueKey<String>('token-quote')), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Community record · kept per community
  // -------------------------------------------------------------------------
  group('community record retention', () {
    test('LoopRecentAnswers keeps the newest answers for five minutes', () {
      final answers = LoopRecentAnswers<String, int>(capacity: 2);
      final t0 = DateTime.utc(2026, 9, 28, 8);
      answers.remember('a', 1, t0);
      answers.remember('b', 2, t0);
      expect(answers.lookup('a', t0)?.value, 1);
      answers.remember('c', 3, t0);
      // `b` was the least recently used.
      expect(answers.lookup('b', t0), isNull);
      expect(answers.lookup('a', t0)?.value, 1);
      expect(
        answers.lookup(
          'c',
          t0.add(
            LoopSnapshotPolicy.memoryRetention + const Duration(seconds: 1),
          ),
        ),
        isNull,
      );
    });

    test(
      'a return visit draws the record at once and re-reads after 10 s',
      () async {
        final clock = _Clock(DateTime.utc(2026, 9, 28, 8));
        final gateway = FakeCommunityGateway(detail: testDetail());
        final container = _container(<Override>[
          communityGatewayProvider.overrideWithValue(gateway),
          loopReadClockProvider.overrideWithValue(clock.call),
        ]);

        var visit = container.listen(
          communityProfileControllerProvider,
          (_, _) {},
        );
        await container
            .read(communityProfileControllerProvider.notifier)
            .open(testCommunityId);
        expect(gateway.reads, 1);
        visit.close();
        await _drain();

        // Back within the floor: drawn from memory, nothing sent.
        clock.now = clock.now.add(const Duration(seconds: 4));
        visit = container.listen(communityProfileControllerProvider, (_, _) {});
        final opening = container
            .read(communityProfileControllerProvider.notifier)
            .open(testCommunityId);
        var state = container.read(communityProfileControllerProvider);
        expect(state.phase, CommunityViewPhase.ready);
        expect(state.value?.community.communityId, testCommunityId);
        await opening;
        expect(gateway.reads, 1);
        visit.close();
        await _drain();

        // Back after the floor: drawn at once, marked 更新中, re-read behind.
        clock.now = clock.now.add(const Duration(seconds: 11));
        visit = container.listen(communityProfileControllerProvider, (_, _) {});
        final reopening = container
            .read(communityProfileControllerProvider.notifier)
            .open(testCommunityId);
        state = container.read(communityProfileControllerProvider);
        expect(state.phase, CommunityViewPhase.ready);
        expect(state.refreshing, isTrue);
        await reopening;
        expect(gateway.reads, 2);
        expect(
          container.read(communityProfileControllerProvider).refreshing,
          isFalse,
        );
        visit.close();
      },
    );

    test('another community never shows the kept one while it loads', () async {
      final gateway = FakeCommunityGateway(detail: testDetail());
      final container = _container(<Override>[
        communityGatewayProvider.overrideWithValue(gateway),
      ]);
      final visit = container.listen(
        communityProfileControllerProvider,
        (_, _) {},
      );
      addTearDown(visit.close);
      final controller = container.read(
        communityProfileControllerProvider.notifier,
      );
      await controller.open(testCommunityId);
      gateway.pending = true;
      unawaited(controller.open('4bb85f64-5717-4562-b3fc-2c963f66af00'));
      final state = container.read(communityProfileControllerProvider);
      expect(state.value, isNull);
      expect(state.phase, CommunityViewPhase.loading);
    });

    test('a different account starts with nothing kept', () async {
      final gateway = FakeCommunityGateway(detail: testDetail());
      final account = NotifierProvider<_Account, String?>(_Account.new);
      final container = _container(<Override>[
        communityGatewayProvider.overrideWithValue(gateway),
        loopAccountScopeProvider.overrideWith((ref) => ref.watch(account)),
      ]);
      var visit = container.listen(
        communityProfileControllerProvider,
        (_, _) {},
      );
      await container
          .read(communityProfileControllerProvider.notifier)
          .open(testCommunityId);
      visit.close();
      await _drain();
      container.read(account.notifier).switchTo('account-b');

      gateway.pending = true;
      visit = container.listen(communityProfileControllerProvider, (_, _) {});
      addTearDown(visit.close);
      unawaited(
        container
            .read(communityProfileControllerProvider.notifier)
            .open(testCommunityId),
      );
      expect(container.read(communityProfileControllerProvider).value, isNull);
    });

    testWidgets(
      'arriving from the tab starts the bound quote beside the record read',
      (tester) async {
        const assetKey = 'eip155:56:0x00000000000000000000000000000000000000a0';
        final gateway = _HeldRecordGateway(
          home: _homeListing(testCommunity(boundAssetKey: assetKey)),
        );
        final market = _HeldMarket();
        await pumpCommunityPage(
          tester,
          const Stack(
            children: <Widget>[
              _HomeHolder(),
              CommunityProfileScreen(communityId: testCommunityId),
            ],
          ),
          community: gateway,
          overrides: <Override>[
            marketReadGatewayProvider.overrideWithValue(market),
          ],
          settle: false,
        );
        await tester.pump();
        await tester.pump();

        expect(gateway.recordReads, 1);
        expect(gateway.record.isCompleted, isFalse);
        // The quote went out in the same round trip as the record.
        expect(market.assetReads, <String>[assetKey]);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 4. Community directory · kept across visits
  // -------------------------------------------------------------------------
  group('community directory retention', () {
    test('a return visit keeps page one and re-reads after 10 s', () async {
      final clock = _Clock(DateTime.utc(2026, 9, 28, 8));
      final gateway = FakeCommunityGateway(directoryPage: _directory('One'));
      final container = _container(<Override>[
        communityGatewayProvider.overrideWithValue(gateway),
        loopReadClockProvider.overrideWithValue(clock.call),
      ]);
      var visit = container.listen(
        communityDiscoverControllerProvider,
        (_, _) {},
      );
      await container
          .read(communityDiscoverControllerProvider.notifier)
          .openAll();
      expect(
        gateway.commands.where((c) => c.startsWith('list:')),
        hasLength(1),
      );
      visit.close();
      await _drain();

      clock.now = clock.now.add(const Duration(seconds: 3));
      visit = container.listen(communityDiscoverControllerProvider, (_, _) {});
      await _drain();
      expect(
        container.read(communityDiscoverControllerProvider).items.single.name,
        'One',
      );
      await container
          .read(communityDiscoverControllerProvider.notifier)
          .openAll();
      expect(
        gateway.commands.where((c) => c.startsWith('list:')),
        hasLength(1),
      );
      visit.close();
      await _drain();

      clock.now = clock.now.add(const Duration(seconds: 11));
      gateway.directoryPage = _directory('Two');
      visit = container.listen(communityDiscoverControllerProvider, (_, _) {});
      addTearDown(visit.close);
      await _drain();
      final state = container.read(communityDiscoverControllerProvider);
      expect(state.items.single.name, 'Two');
      expect(
        gateway.commands.where((c) => c.startsWith('list:')),
        hasLength(2),
      );
    });

    test(
      'a retained joined filter is not shown to the whole directory',
      () async {
        final gateway = FakeCommunityGateway(directoryPage: _directory('One'));
        final container = _container(<Override>[
          communityGatewayProvider.overrideWithValue(gateway),
        ]);
        final visit = container.listen(
          communityDiscoverControllerProvider,
          (_, _) {},
        );
        addTearDown(visit.close);
        final controller = container.read(
          communityDiscoverControllerProvider.notifier,
        );
        await controller.openJoined();
        expect(
          container.read(communityDiscoverControllerProvider).membership,
          CommunityMembershipFilter.joined,
        );
        await controller.openAll();
        expect(
          container.read(communityDiscoverControllerProvider).membership,
          CommunityMembershipFilter.all,
        );
        expect(gateway.commands.last, 'list:members:all:null');
      },
    );
  });

  // -------------------------------------------------------------------------
  // 5. Chat inbox · the index and the list are kept
  // -------------------------------------------------------------------------
  group('chat inbox retention', () {
    test('the direct-channel index is read once per 10 s floor', () async {
      final clock = _Clock(DateTime.utc(2026, 9, 28, 8));
      final chat = FakeChatV2Gateway();
      final container = _container(<Override>[
        chatV2GatewayProvider.overrideWithValue(chat),
        loopReadClockProvider.overrideWithValue(clock.call),
      ]);
      int reads() =>
          chat.commands.where((c) => c.startsWith('direct-channels')).length;

      var visit = container.listen(directChannelDirectoryProvider, (_, _) {});
      await container.read(directChannelDirectoryProvider.future);
      expect(reads(), 1);
      visit.close();
      await _drain();

      clock.now = clock.now.add(const Duration(seconds: 5));
      visit = container.listen(directChannelDirectoryProvider, (_, _) {});
      await _drain();
      expect(container.read(directChannelDirectoryProvider).hasValue, isTrue);
      expect(reads(), 1);
      visit.close();
      await _drain();

      clock.now = clock.now.add(const Duration(seconds: 11));
      visit = container.listen(directChannelDirectoryProvider, (_, _) {});
      addTearDown(visit.close);
      // The previous index stays readable while the new one is fetched.
      expect(container.read(directChannelDirectoryProvider).value, isNotNull);
      await _drain();
      expect(reads(), 2);
    });

    test('the channel list controller survives a visit', () async {
      final client = StreamChatClient(
        'public-stream-api-key',
        logLevel: Level.OFF,
      );
      addTearDown(client.dispose);
      final container = _container(const <Override>[]);
      final key = (client: client, userId: 'loop-user-42');

      var visit = container.listen(
        loopStreamChannelListControllerProvider(key),
        (_, _) {},
      );
      final first = container.read(
        loopStreamChannelListControllerProvider(key),
      );
      visit.close();
      await _drain();
      visit = container.listen(
        loopStreamChannelListControllerProvider(key),
        (_, _) {},
      );
      addTearDown(visit.close);
      expect(
        container.read(loopStreamChannelListControllerProvider(key)),
        same(first),
      );
      // Another user is another list.
      final other = container.read(
        loopStreamChannelListControllerProvider((
          client: client,
          userId: 'loop-user-43',
        )),
      );
      expect(other, isNot(same(first)));
    });
  });

  // -------------------------------------------------------------------------
  // 6. Token logo · a 3 s budget, remembered for the process
  // -------------------------------------------------------------------------
  group('token logo budget', () {
    setUp(debugResetLoopTokenLogoFailures);
    tearDown(() {
      debugResetLoopTokenLogoFailures();
      PaintingBinding.instance.imageCache.clear();
    });

    testWidgets('a logo with no frame after 3 s is given up for the process', (
      tester,
    ) async {
      painting.debugNetworkImageHttpClientProvider = _HangingHttpClient.new;
      const url = 'https://raw.githubusercontent.com/hang/logo.png';
      Widget logo(Key key) =>
          LoopTokenLogo(key: key, assetSymbol: 'HANG', logoUrl: url);
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Column(children: <Widget>[logo(const Key('a'))]),
          ),
        ),
      );
      await tester.pump();
      // While it hangs the tile is the monogram at its final size.
      expect(find.text('HA'), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('a'))), const Size(36, 36));
      expect(debugLoopTokenLogoFailed(url), isFalse);

      await tester.pump(LoopTokenLogo.fetchBudget);
      await tester.pump();
      expect(debugLoopTokenLogoFailed(url), isTrue);
      expect(
        find.byKey(const ValueKey<String>('loop-token-logo-remote')),
        findsNothing,
      );

      // Every later row with the same artwork skips the fetch entirely.
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: Scaffold(
            body: Column(
              children: <Widget>[logo(const Key('b')), logo(const Key('c'))],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('loop-token-logo-remote')),
        findsNothing,
      );
      expect(find.text('HA'), findsNWidgets(2));
      // The binding checks the hook is unset before tear-down runs.
      painting.debugNetworkImageHttpClientProvider = null;
    });

    testWidgets('a refused logo is remembered too', (tester) async {
      const url = 'https://cdn.example.com/refused.png';
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            body: LoopTokenLogo(assetSymbol: 'REFUSED', logoUrl: url),
          ),
        ),
      );
      // `flutter_test` answers every network image with a 400.
      await tester.pumpAndSettle();
      expect(debugLoopTokenLogoFailed(url), isTrue);
      expect(find.text('RE'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // 7. Folio · faded inks without layers
  // -------------------------------------------------------------------------
  group('folio', () {
    testWidgets('kicker, caption and stamp paint without an Opacity layer', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: const Scaffold(
            backgroundColor: LoopColors.ink,
            body: LoopFolioPrimary(
              heading: '钱包',
              kicker: 'WALLET LEDGER',
              caption: '说明',
              stamp: 'PUBLIC',
              variant: LoopFolioVariant.lime,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(LoopFolioPrimary),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      final kicker = tester.widget<Text>(find.text('WALLET LEDGER'));
      expect(kicker.style!.color!.a, closeTo(0.66, 0.01));
      final stamp = tester.widget<Text>(find.text('PUBLIC'));
      expect(stamp.style!.color!.a, closeTo(0.68, 0.01));
    });
  });
}
