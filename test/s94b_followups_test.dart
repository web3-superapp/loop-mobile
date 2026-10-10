import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart' show FakeMarketReadGateway;

// ---------------------------------------------------------------------------
// Token logo seams
// ---------------------------------------------------------------------------

/// A registry image the test answers by hand, one attempt at a time.
final class _HeldLogo extends ImageProvider<_HeldLogo> {
  _HeldLogo(this.url, this.attempts);

  final String url;
  final List<Completer<ImageInfo>> attempts;

  @override
  Future<_HeldLogo> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_HeldLogo>(this);

  @override
  ImageStreamCompleter loadImage(_HeldLogo key, ImageDecoderCallback decode) {
    final attempt = Completer<ImageInfo>();
    attempts.add(attempt);
    return OneFrameImageStreamCompleter(attempt.future);
  }

  @override
  bool operator ==(Object other) => other is _HeldLogo && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

final class _Clock {
  _Clock(this.now);

  DateTime now;

  DateTime call() => now;
}

Widget _logoApp(Key key, String url) => MaterialApp(
  theme: LoopTheme.dark,
  home: Scaffold(
    body: Center(
      child: LoopTokenLogo(key: key, assetSymbol: 'CAKE', logoUrl: url),
    ),
  ),
);

Finder get _remote =>
    find.byKey(const ValueKey<String>('loop-token-logo-remote'));

// ---------------------------------------------------------------------------
// Community detail seams
// ---------------------------------------------------------------------------

/// A community gateway whose record read is held by the test.
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

/// A market gateway that records every read and never answers.
final class _HeldMarket extends Fake implements MarketReadGateway {
  final List<String> assetReads = <String>[];
  final List<(String, LoopCandleInterval)> candleReads =
      <(String, LoopCandleInterval)>[];

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
  }) {
    candleReads.add((assetId, interval));
    return Completer<MarketCandleSeries>().future;
  }
}

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

void main() {
  loopWatchGround();

  // -------------------------------------------------------------------------
  // 1. Token logo · slow is not failed; definite failures kept 10 minutes
  // -------------------------------------------------------------------------
  group('token logo', () {
    late List<Completer<ImageInfo>> attempts;
    late _Clock clock;
    late ui.Image picture;

    setUp(() {
      debugResetLoopTokenLogoFailures();
      attempts = <Completer<ImageInfo>>[];
      clock = _Clock(DateTime.utc(2026, 9, 28, 8));
      debugLoopTokenLogoClock = clock.call;
      debugLoopTokenLogoImageProvider = (url) => _HeldLogo(url, attempts);
    });
    tearDown(() {
      debugResetLoopTokenLogoFailures();
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    });

    test('the first-paint budget is 5 s and a failure is kept 10 min', () {
      expect(LoopTokenLogo.fetchBudget, const Duration(seconds: 5));
      expect(LoopTokenLogo.failureRetryAfter, const Duration(minutes: 10));
    });

    testWidgets('a logo that lands after the budget replaces the monogram', (
      tester,
    ) async {
      picture = (await tester.runAsync(
        () => createTestImage(width: 8, height: 8),
      ))!;
      const url = 'https://raw.githubusercontent.com/slow/cake.png';
      await tester.pumpWidget(_logoApp(const Key('a'), url));
      await tester.pump();
      expect(attempts, hasLength(1));
      expect(find.text('CA'), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('a'))), const Size(36, 36));

      // The budget passes with no frame: the slot stays the monogram and
      // the download is still in the air, not abandoned or remembered.
      await tester.pump(LoopTokenLogo.fetchBudget + const Duration(seconds: 1));
      expect(find.text('CA'), findsOneWidget);
      expect(_remote, findsOneWidget);
      expect(debugLoopTokenLogoFailed(url), isFalse);

      attempts.single.complete(ImageInfo(image: picture.clone()));
      await tester.pump();
      await tester.pump();
      expect(find.text('CA'), findsNothing);
      final raw = tester.widget<RawImage>(
        find.descendant(of: _remote, matching: find.byType(RawImage)),
      );
      expect(raw.image, isNotNull);
      // Same size as the monogram it replaced: nothing moved.
      expect(tester.getSize(find.byKey(const Key('a'))), const Size(36, 36));
      expect(attempts, hasLength(1));
    });

    testWidgets('a 404 is the monogram and not asked again for 10 minutes, '
        'then asked exactly once more', (tester) async {
      const url = 'https://raw.githubusercontent.com/gone/cake.png';
      Future<void> fail(Completer<ImageInfo> attempt) async {
        attempt.completeError(
          NetworkImageLoadException(statusCode: 404, uri: Uri.parse(url)),
        );
        // Error, then the post-frame record, then the rebuild it scheduled.
        await tester.pump();
        await tester.pump();
        await tester.pump();
      }

      await tester.pumpWidget(_logoApp(const Key('a'), url));
      await tester.pump();
      expect(attempts, hasLength(1));
      await fail(attempts.single);
      expect(debugLoopTokenLogoFailed(url), isTrue);
      expect(_remote, findsNothing);
      expect(find.text('CA'), findsOneWidget);

      // Another row, another page, nine minutes later: no request.
      clock.now = clock.now.add(const Duration(minutes: 9, seconds: 59));
      await tester.pumpWidget(_logoApp(const Key('b'), url));
      await tester.pump();
      expect(attempts, hasLength(1));
      expect(_remote, findsNothing);
      expect(find.text('CA'), findsOneWidget);

      // Ten minutes after the failure the address is asked once more.
      clock.now = clock.now.add(const Duration(seconds: 1));
      expect(debugLoopTokenLogoFailed(url), isFalse);
      await tester.pumpWidget(_logoApp(const Key('c'), url));
      await tester.pump();
      expect(attempts, hasLength(2));
      await fail(attempts.last);
      expect(debugLoopTokenLogoFailed(url), isTrue);

      // The retry failed too: that answer is kept for the process.
      clock.now = clock.now.add(const Duration(hours: 1));
      await tester.pumpWidget(_logoApp(const Key('d'), url));
      await tester.pump();
      expect(attempts, hasLength(2));
      expect(find.text('CA'), findsOneWidget);
    });

    testWidgets(
      'a timed-out fetch is not remembered: the next row asks again',
      (tester) async {
        const url = 'https://raw.githubusercontent.com/timeout/cake.png';
        await tester.pumpWidget(_logoApp(const Key('a'), url));
        await tester.pump();
        attempts.single.completeError(
          const SocketException(
            'Connection timed out',
            osError: OSError('Connection timed out', 60),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(debugLoopTokenLogoFailed(url), isFalse);
        expect(find.text('CA'), findsOneWidget);

        await tester.pumpWidget(_logoApp(const Key('b'), url));
        await tester.pump();
        expect(attempts, hasLength(2));
      },
    );

    test('only DNS, refused and HTTP 4xx/5xx are definite', () {
      final uri = Uri.parse('https://raw.githubusercontent.com/x.png');
      expect(
        loopLogoFailureIsDefinite(
          NetworkImageLoadException(statusCode: 404, uri: uri),
        ),
        isTrue,
      );
      expect(
        loopLogoFailureIsDefinite(
          NetworkImageLoadException(statusCode: 503, uri: uri),
        ),
        isTrue,
      );
      expect(
        loopLogoFailureIsDefinite(
          const SocketException(
            "Failed host lookup: 'raw.githubusercontent.com'",
            osError: OSError('nodename nor servname provided', 8),
          ),
        ),
        isTrue,
      );
      expect(
        loopLogoFailureIsDefinite(
          const SocketException(
            'Connection refused',
            osError: OSError('Connection refused', 61),
          ),
        ),
        isTrue,
      );
      expect(
        loopLogoFailureIsDefinite(
          const SocketException('', osError: OSError('', 111)),
        ),
        isTrue,
      );
      expect(
        loopLogoFailureIsDefinite(
          const SocketException(
            'Connection timed out',
            osError: OSError('Connection timed out', 60),
          ),
        ),
        isFalse,
      );
      expect(
        loopLogoFailureIsDefinite(
          const SocketException(
            'Connection reset by peer',
            osError: OSError('Connection reset by peer', 54),
          ),
        ),
        isFalse,
      );
      expect(loopLogoFailureIsDefinite(TimeoutException('slow')), isFalse);
      expect(loopLogoFailureIsDefinite(const HttpException('closed')), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Community detail · the bound asset's 1H line is actually read
  // -------------------------------------------------------------------------
  group('community bound asset line', () {
    testWidgets('arriving from the tab asks for the quote beside the record '
        'read, and no candles', (tester) async {
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
      expect(market.assetReads, <String>[assetKey]);
      // Decision 0127: the bound token is one quote row with no line, so the
      // record asks for no series.
      expect(market.candleReads, isEmpty);
    });

    testWidgets('a deep link reads the quote once the record names the '
        'asset, and draws one row', (tester) async {
      final market = FakeMarketReadGateway();
      await pumpCommunityPage(
        tester,
        const CommunityProfileScreen(communityId: testCommunityId),
        community: FakeCommunityGateway(
          detail: testDetail(
            community: testCommunity(boundAssetKey: s5WbnbAssetId),
          ),
        ),
        overrides: <Override>[
          marketReadGatewayProvider.overrideWithValue(market),
        ],
      );

      final card = find.byKey(const ValueKey<String>('community-bound-asset'));
      await scrollToCommunitySection(tester, card);
      await tester.pumpAndSettle();
      expect(card, findsOneWidget);
      expect(market.intervals, isEmpty);
      expect(
        find.byKey(const ValueKey<String>('community-bound-asset-chart-line')),
        findsNothing,
      );
      expect(find.textContaining('1H K 线读取中'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Snapshot store · directory creation gets 1000 ms
  // -------------------------------------------------------------------------
  group('snapshot directory budget', () {
    LoopSnapshotRecord record() => LoopSnapshotRecord(
      accountKey: 'acct',
      resource: LoopSnapshotResource.marketOverview,
      body: const <String, Object?>{'rows': 1},
      observedAt: DateTime.utc(2026, 9, 28, 8),
    );

    test('a directory that takes 600 ms to create still persists', () async {
      final root = await Directory.systemTemp.createTemp('s94b-store');
      addTearDown(() => root.delete(recursive: true));
      final support = Directory('${root.path}${Platform.pathSeparator}support');
      final store = await FileLoopSnapshotStore.openPersistent(
        locate: () async => support,
        createDirectory: (directory) async {
          await Future<void>.delayed(const Duration(milliseconds: 600));
          await directory.create(recursive: true);
        },
      );
      expect(store, isA<FileLoopSnapshotStore>());
      store
        ..bind('acct')
        ..write(record());
      await (store as FileLoopSnapshotStore).changed();
      expect(
        File(
          '${support.path}${Platform.pathSeparator}'
          '${FileLoopSnapshotStore.fileName}',
        ).existsSync(),
        isTrue,
      );
    });

    test(
      'a directory slower than its bound still falls back to memory',
      () async {
        final root = await Directory.systemTemp.createTemp('s94b-slow');
        addTearDown(() => root.delete(recursive: true));
        final store = await FileLoopSnapshotStore.openPersistent(
          locate: () async => root,
          createDirectory: (directory) =>
              Future<void>.delayed(const Duration(milliseconds: 200)),
          createTimeout: const Duration(milliseconds: 20),
        );
        expect(store, isNot(isA<FileLoopSnapshotStore>()));
      },
    );

    test('locating the directory gets its own 2 s bound (S123f)', () async {
      // A 600 ms platform-channel reply used to lose the whole run's
      // snapshots; it now sits inside the locate bound.
      final root = await Directory.systemTemp.createTemp('s94b-locate');
      addTearDown(() => root.delete(recursive: true));
      final store = await FileLoopSnapshotStore.openPersistent(
        locate: () => Future<Directory>.delayed(
          const Duration(milliseconds: 600),
          () => root,
        ),
      );
      expect(store, isA<FileLoopSnapshotStore>());
    });

    test('the other steps keep the 1.5 s bound', () async {
      final root = await Directory.systemTemp.createTemp('s94b-locate');
      addTearDown(() => root.delete(recursive: true));
      final store = await FileLoopSnapshotStore.openPersistent(
        locate: () => Future<Directory>.delayed(
          const Duration(milliseconds: 2500),
          () => root,
        ),
      );
      expect(store, isNot(isA<FileLoopSnapshotStore>()));
    });
  });
}
