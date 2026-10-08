import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:loop_mobile/features/community/community_screen.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/launch/launch_contract.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_gateway.dart';
import 'package:loop_mobile/features/launch/launch_models.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_gateway.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/wallet/money_actions_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_snapshot.dart';
import 'package:loop_mobile/integrations/backend/v2/market/loop_v2_market_api.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';

import 'support/community_test_harness.dart';
import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';
import 'support/s7_fixtures.dart';
import 'support/s7_page_harness.dart';

// ---------------------------------------------------------------------------
// Doubles
// ---------------------------------------------------------------------------

/// A restorer that hands each stored value out once, like the real session.
final class _Restorer implements LoopSnapshotRestorer {
  _Restorer(Map<String, LoopRestoredSnapshot> values) : _values = values;

  final Map<String, LoopRestoredSnapshot> _values;
  final List<String> asked = <String>[];

  @override
  LoopRestoredSnapshot? restore(String resource) {
    asked.add(resource);
    return _values.remove(resource);
  }
}

/// A mutable clock the read retention measures ages against.
final class _Clock {
  _Clock(this.now);

  DateTime now;

  DateTime call() => now;
}

/// The overview answers from a script: each read takes the next completer, or
/// answers at once when the script is empty.
final class _ScriptedMarket implements MarketReadGateway {
  _ScriptedMarket(this._inner);

  final FakeMarketReadGateway _inner;
  final List<Completer<MarketOverview>> script = <Completer<MarketOverview>>[];
  int overviewReads = 0;

  @override
  LoopChainGatewayMode get mode => _inner.mode;

  @override
  Future<MarketOverview> loadOverview() {
    overviewReads += 1;
    if (script.isNotEmpty) return script.removeAt(0).future;
    return _inner.loadOverview();
  }

  @override
  Future<MarketAssetDetail> loadAsset(String assetId) =>
      _inner.loadAsset(assetId);

  @override
  Future<MarketCandleSeries> loadCandles(
    String assetId, {
    required LoopCandleInterval interval,
    int? limit,
  }) => _inner.loadCandles(assetId, interval: interval, limit: limit);

  @override
  Future<MarketTradesPage> loadTrades(String assetId, {String? cursor}) =>
      _inner.loadTrades(assetId, cursor: cursor);

  @override
  Future<MarketHolders> loadHolders(String assetId) =>
      _inner.loadHolders(assetId);

  @override
  Future<MarketNewPairsPage> loadNewPairs() => _inner.loadNewPairs();

  @override
  Future<LoopUnavailable> loadSmartMoney() => _inner.loadSmartMoney();
}

/// The balances answer from a completer the test owns.
final class _ScriptedWallet implements WalletReadGateway {
  _ScriptedWallet(this._inner);

  final FakeWalletReadGateway _inner;

  /// Each balances read takes the next completer; an empty script never
  /// answers.
  final List<Completer<LoopWalletBalances>> balanceScript =
      <Completer<LoopWalletBalances>>[];
  int balanceReads = 0;

  @override
  LoopChainGatewayMode get mode => _inner.mode;

  @override
  Future<LoopWalletDirectory> loadWallets() => _inner.loadWallets();

  @override
  Future<LoopWalletDirectory> setActiveWallet({
    required String walletId,
    required String? expectedActiveWalletId,
  }) => _inner.setActiveWallet(
    walletId: walletId,
    expectedActiveWalletId: expectedActiveWalletId,
  );

  @override
  Future<LoopWalletBalances> loadBalances(String walletId) {
    balanceReads += 1;
    if (balanceScript.isEmpty) return Completer<LoopWalletBalances>().future;
    return balanceScript.removeAt(0).future;
  }

  @override
  Future<LoopWalletActivityPage> loadActivity(
    String walletId, {
    String? cursor,
  }) => _inner.loadActivity(walletId, cursor: cursor);

  @override
  Future<LoopWalletReceive> loadReceive(String walletId) =>
      _inner.loadReceive(walletId);
}

final _account = NotifierProvider<_AccountController, String?>(
  _AccountController.new,
);

final class _AccountController extends Notifier<String?> {
  @override
  String? build() => 'account-a';

  void switchTo(String? next) => state = next;
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

LoopSnapshotRecord _record(
  String resource,
  Object? body, {
  String account = 'acct',
  DateTime? observedAt,
}) => LoopSnapshotRecord(
  accountKey: account,
  resource: resource,
  body: body,
  observedAt: observedAt ?? DateTime.utc(2026, 9, 27, 8),
);

/// Pumps a page under reduced motion.
Widget _reduced(Widget page) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: page,
  ),
);

Future<void> _frames(WidgetTester tester, [int count = 4]) async {
  for (var index = 0; index < count; index += 1) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

String _stripText(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey<String>('loop-freshness-text')))
    .data!;

void main() {
  // The freshness strip is mounted on its own below; it is watched like every
  // page the harnesses mount.
  loopWatchGround();

  // -------------------------------------------------------------------------
  // 1. The read controllers keep their last answer
  // -------------------------------------------------------------------------
  group('read retention', () {
    test('a retained answer comes back drawn and re-reads behind it', () async {
      final clock = _Clock(DateTime.utc(2026, 9, 27, 8));
      final wallet = FakeWalletReadGateway();
      final container = _container(<Override>[
        walletReadGatewayProvider.overrideWithValue(wallet),
        loopReadClockProvider.overrideWithValue(clock.call),
      ]);

      final first = container.listen(
        walletDirectoryControllerProvider,
        (_, _) {},
      );
      await container.read(walletDirectoryControllerProvider.notifier).load();
      expect(wallet.directoryReads, 1);
      first.close();
      await _drain();

      // The page went away and came straight back: the answer is still there
      // and nothing is read again inside the revisit floor.
      final states = <LoopChainResourceState<LoopWalletDirectory>>[];
      final second = container.listen(
        walletDirectoryControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      expect(states.first.isReady, isTrue);
      expect(states.first.value, isNotNull);
      await _drain();
      expect(wallet.directoryReads, 1);
      second.close();
      await _drain();

      // Coming back after the floor re-reads — over the answer, never as a
      // skeleton.
      clock.now = clock.now.add(const Duration(seconds: 11));
      states.clear();
      final third = container.listen(
        walletDirectoryControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      await _drain();
      expect(wallet.directoryReads, 2);
      expect(
        states.any((state) => state.refreshing && state.value != null),
        isTrue,
      );
      expect(
        states.every((state) => state.phase == LoopChainViewPhase.ready),
        isTrue,
      );
      third.close();
    });

    testWidgets('the answer is released five minutes after its page left', (
      tester,
    ) async {
      final wallet = FakeWalletReadGateway();
      final container = ProviderContainer(
        overrides: <Override>[
          walletReadGatewayProvider.overrideWithValue(wallet),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        walletDirectoryControllerProvider,
        (_, _) {},
      );
      await container.read(walletDirectoryControllerProvider.notifier).load();
      expect(sub.read().isReady, isTrue);
      sub.close();
      await tester.pump(const Duration(minutes: 4, seconds: 59));
      expect(
        container.exists(walletDirectoryControllerProvider),
        isTrue,
        reason: 'still inside the retention window',
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(container.exists(walletDirectoryControllerProvider), isFalse);
      final fresh = container.read(walletDirectoryControllerProvider);
      expect(fresh.value, isNull);
      expect(fresh.phase, LoopChainViewPhase.loading);
      // Disposing the container cancels the retention timer the last read
      // started, as the app's own scope does.
      container.dispose();
    });

    test('another account never sees the answer', () async {
      final wallet = FakeWalletReadGateway();
      final container = _container(<Override>[
        walletReadGatewayProvider.overrideWithValue(wallet),
        loopAccountScopeProvider.overrideWith((ref) => ref.watch(_account)),
      ]);
      final sub = container.listen(
        walletDirectoryControllerProvider,
        (_, _) {},
      );
      await container.read(walletDirectoryControllerProvider.notifier).load();
      expect(sub.read().value, isNotNull);

      container.read(_account.notifier).switchTo('account-b');
      final after = container.read(walletDirectoryControllerProvider);
      expect(after.value, isNull);
      expect(after.phase, LoopChainViewPhase.loading);
      sub.close();
    });

    test('the approvals inventory is never carried over', () async {
      // `approvals` promises an allowance() read on the spot.
      final container = _container(const <Override>[]);
      final provider = approvalsControllerProvider(s5WalletId);
      final sub = container.listen(provider, (_, _) {});
      sub.close();
      await _drain();
      expect(container.exists(provider), isFalse);

      // Every other read block outlives its page.
      final kept = container.listen(
        walletDirectoryControllerProvider,
        (_, _) {},
      );
      kept.close();
      await _drain();
      expect(container.exists(walletDirectoryControllerProvider), isTrue);
    });

    test('a restored snapshot is drawn at once and replaced live', () async {
      final clock = _Clock(DateTime.utc(2026, 9, 27, 8));
      final observed = DateTime.utc(2026, 9, 27, 7, 55);
      final restorer = _Restorer(<String, LoopRestoredSnapshot>{
        LoopSnapshotResource.marketOverview: LoopRestoredSnapshot(
          value: s5Overview(),
          observedAt: observed,
        ),
      });
      final market = _ScriptedMarket(FakeMarketReadGateway());
      final live = Completer<MarketOverview>();
      market.script.add(live);
      final container = _container(<Override>[
        marketReadGatewayProvider.overrideWithValue(market),
        loopSnapshotRestorerProvider.overrideWithValue(restorer),
        loopReadClockProvider.overrideWithValue(clock.call),
      ]);

      final sub = container.listen(marketOverviewControllerProvider, (_, _) {});
      final controller = container.read(
        marketOverviewControllerProvider.notifier,
      );
      expect(sub.read().isReady, isTrue);
      expect(controller.restoredObservedAt, observed);
      expect(restorer.asked, <String>[LoopSnapshotResource.marketOverview]);

      await _drain();
      // The live read started behind the snapshot, marked 更新中.
      expect(market.overviewReads, 1);
      expect(sub.read().refreshing, isTrue);
      expect(sub.read().value, isNotNull);

      live.complete(s5Overview());
      await _drain();
      expect(sub.read().refreshing, isFalse);
      expect(controller.restoredObservedAt, isNull);
      expect(controller.valueObservedAt, clock.now);
      sub.close();
    });

    test(
      'a failed live read keeps the snapshot and reports the failure',
      () async {
        final restorer = _Restorer(<String, LoopRestoredSnapshot>{
          LoopSnapshotResource.marketOverview: LoopRestoredSnapshot(
            value: s5Overview(),
            observedAt: DateTime.utc(2026, 9, 27, 7, 55),
          ),
        });
        final market = _ScriptedMarket(FakeMarketReadGateway());
        final live = Completer<MarketOverview>();
        market.script.add(live);
        final container = _container(<Override>[
          marketReadGatewayProvider.overrideWithValue(market),
          loopSnapshotRestorerProvider.overrideWithValue(restorer),
        ]);
        final sub = container.listen(
          marketOverviewControllerProvider,
          (_, _) {},
        );
        await _drain();
        live.completeError(
          const LoopChainException(LoopChainFailureKind.offline),
        );
        await _drain();
        final state = sub.read();
        expect(state.value, isNotNull);
        expect(state.phase, LoopChainViewPhase.ready);
        expect(state.failureKind, LoopChainFailureKind.offline);
        expect(
          container
              .read(marketOverviewControllerProvider.notifier)
              .restoredObservedAt,
          isNotNull,
        );
        sub.close();
      },
    );

    test('an unavailable gateway never opens on a snapshot', () {
      final restorer = _Restorer(<String, LoopRestoredSnapshot>{
        LoopSnapshotResource.marketOverview: LoopRestoredSnapshot(
          value: s5Overview(),
          observedAt: DateTime.utc(2026, 9, 27, 7, 55),
        ),
      });
      final container = _container(<Override>[
        loopSnapshotRestorerProvider.overrideWithValue(restorer),
      ]);
      final state = container.read(marketOverviewControllerProvider);
      expect(state.phase, LoopChainViewPhase.unavailable);
      expect(state.value, isNull);
      expect(restorer.asked, isEmpty);
    });

    test('the community index and the Launch catalogue restore too', () async {
      final restorer = _Restorer(<String, LoopRestoredSnapshot>{
        LoopSnapshotResource.communityHome: LoopRestoredSnapshot(
          value: _home(),
          observedAt: DateTime.utc(2026, 9, 27, 7, 55),
        ),
        LoopSnapshotResource.launchOverview: LoopRestoredSnapshot(
          value: s7Overview(),
          observedAt: DateTime.utc(2026, 9, 27, 7, 56),
        ),
      });
      final community = FakeCommunityGateway(home: _home())..pending = true;
      final container = _container(<Override>[
        communityGatewayProvider.overrideWithValue(community),
        launchGatewayProvider.overrideWithValue(
          FakeLaunchGateway(overview: S7Answer<LaunchOverview>(pending: true)),
        ),
        loopSnapshotRestorerProvider.overrideWithValue(restorer),
      ]);
      final home = container.listen(communityHomeControllerProvider, (_, _) {});
      final launch = container.listen(
        launchOverviewControllerProvider,
        (_, _) {},
      );
      expect(home.read().phase, CommunityViewPhase.ready);
      expect(launch.read().phase, LaunchViewPhase.ready);
      await _drain();
      expect(home.read().refreshing, isTrue);
      expect(launch.read().refreshing, isTrue);
      expect(
        container
            .read(launchOverviewControllerProvider.notifier)
            .restoredObservedAt,
        DateTime.utc(2026, 9, 27, 7, 56),
      );
      home.close();
      launch.close();
    });
  });

  // -------------------------------------------------------------------------
  // 2. The snapshot store
  // -------------------------------------------------------------------------
  group('snapshot store', () {
    test('writes are dropped until an account is bound', () {
      final store = MemoryLoopSnapshotStore();
      store.write(
        _record(LoopSnapshotResource.marketOverview, <String, Object?>{}),
      );
      expect(store.read('acct', LoopSnapshotResource.marketOverview), isNull);

      store.bind('acct');
      store.write(
        _record(LoopSnapshotResource.marketOverview, <String, Object?>{'a': 1}),
      );
      expect(
        store.read('acct', LoopSnapshotResource.marketOverview)?.body,
        <String, Object?>{'a': 1},
      );
      // Another account never reads it.
      expect(store.read('other', LoopSnapshotResource.marketOverview), isNull);
      // A late answer for an account that is no longer bound is dropped.
      store.write(
        _record(
          LoopSnapshotResource.communityHome,
          <String, Object?>{},
          account: 'other',
        ),
      );
      expect(store.read('other', LoopSnapshotResource.communityHome), isNull);
    });

    test('binding another account removes the last one', () {
      final store = MemoryLoopSnapshotStore();
      store.bind('a');
      store.write(
        _record(LoopSnapshotResource.marketOverview, 1, account: 'a'),
      );
      store.bind('b');
      expect(store.records, isEmpty);
    });

    test('unknown resources are never stored', () {
      final store = MemoryLoopSnapshotStore()..bind('acct');
      store.write(_record('wallet.intent.abc', <String, Object?>{}));
      expect(store.records, isEmpty);
    });

    test('the file store survives a restart and clears on sign-out', () async {
      final directory = await Directory.systemTemp.createTemp('s88-store');
      addTearDown(() => directory.delete(recursive: true));

      final first = await FileLoopSnapshotStore.open(directory: directory);
      first.bind('acct');
      first.write(
        _record(
          LoopSnapshotResource.walletBalances(s5WalletId),
          s5BalancesBody(),
        ),
      );
      await first.changed();

      final file = File(
        '${directory.path}${Platform.pathSeparator}${FileLoopSnapshotStore.fileName}',
      );
      expect(file.existsSync(), isTrue);
      // The file names the account by its fingerprint only.
      expect(file.readAsStringSync(), isNot(contains('did:privy')));

      final second = await FileLoopSnapshotStore.open(directory: directory);
      final restored = second.read(
        'acct',
        LoopSnapshotResource.walletBalances(s5WalletId),
      );
      expect(restored, isNotNull);
      expect(restored!.observedAt, DateTime.utc(2026, 9, 27, 8));

      await second.clear();
      expect(file.existsSync(), isFalse);
      expect(second.records, isEmpty);
    });

    test('a damaged file opens as an empty store', () async {
      final directory = await Directory.systemTemp.createTemp('s88-bad');
      addTearDown(() => directory.delete(recursive: true));
      File(
        '${directory.path}${Platform.pathSeparator}${FileLoopSnapshotStore.fileName}',
      ).writeAsStringSync('{not json');
      final store = await FileLoopSnapshotStore.open(directory: directory);
      expect(store.records, isEmpty);
    });

    test('the account fingerprint is stable and not the id', () {
      final key = loopSnapshotAccountKey('did:privy:abc');
      expect(key, loopSnapshotAccountKey('did:privy:abc'));
      expect(key, isNot(loopSnapshotAccountKey('did:privy:abd')));
      expect(key, isNot(contains('privy')));
      expect(key.length, 16);
    });
  });

  // -------------------------------------------------------------------------
  // 3. The V2 session: record, re-decode, expire
  // -------------------------------------------------------------------------
  group('snapshot session', () {
    test('a stored body is re-decoded by the live decoder', () {
      final clock = _Clock(DateTime.utc(2026, 9, 27, 8));
      final store = MemoryLoopSnapshotStore();
      final session = LoopV2SnapshotSession(
        store: store,
        principal: 'did:privy:abc',
        clock: clock.call,
      );
      // The body goes through JSON exactly as the file stores it.
      Object? persisted(Object? body) => jsonDecode(jsonEncode(body));
      session.record(
        LoopSnapshotResource.walletDirectory,
        persisted(s5WalletDirectoryBody()),
      );
      session.record(
        LoopSnapshotResource.walletBalances(s5WalletId),
        persisted(s5BalancesBody()),
      );
      session.record(
        LoopSnapshotResource.marketOverview,
        persisted(s5OverviewBody()),
      );

      clock.now = clock.now.add(const Duration(minutes: 3));
      final reopened = LoopV2SnapshotSession(
        store: store,
        principal: 'did:privy:abc',
        clock: clock.call,
      );
      final directory = reopened.restore(LoopSnapshotResource.walletDirectory);
      final balances = reopened.restore(
        LoopSnapshotResource.walletBalances(s5WalletId),
      );
      final overview = reopened.restore(LoopSnapshotResource.marketOverview);
      expect(directory?.value, isA<LoopWalletDirectory>());
      expect(balances?.value, isA<LoopWalletBalances>());
      expect(overview?.value, isA<MarketOverview>());
      expect(overview?.observedAt, DateTime.utc(2026, 9, 27, 8));
    });

    test('a snapshot older than ten minutes is not drawn', () {
      final clock = _Clock(DateTime.utc(2026, 9, 27, 8));
      final store = MemoryLoopSnapshotStore();
      LoopV2SnapshotSession(
        store: store,
        principal: 'p',
        clock: clock.call,
      ).record(LoopSnapshotResource.marketOverview, s5OverviewBody());
      clock.now = clock.now.add(const Duration(minutes: 10, seconds: 1));
      final later = LoopV2SnapshotSession(
        store: store,
        principal: 'p',
        clock: clock.call,
      );
      expect(later.restore(LoopSnapshotResource.marketOverview), isNull);
    });

    test('a resource restores once and never after a live answer', () {
      final clock = _Clock(DateTime.utc(2026, 9, 27, 8));
      final store = MemoryLoopSnapshotStore();
      LoopV2SnapshotSession(
        store: store,
        principal: 'p',
        clock: clock.call,
      ).record(LoopSnapshotResource.marketOverview, s5OverviewBody());

      final session = LoopV2SnapshotSession(
        store: store,
        principal: 'p',
        clock: clock.call,
      );
      expect(session.restore(LoopSnapshotResource.marketOverview), isNotNull);
      expect(session.restore(LoopSnapshotResource.marketOverview), isNull);

      final other = LoopV2SnapshotSession(
        store: store,
        principal: 'p',
        clock: clock.call,
      );
      other.record(LoopSnapshotResource.marketOverview, s5OverviewBody());
      expect(other.restore(LoopSnapshotResource.marketOverview), isNull);
    });

    test('a body today\'s decoder refuses is not a snapshot', () {
      final store = MemoryLoopSnapshotStore();
      final clock = _Clock(DateTime.utc(2026, 9, 27, 8));
      LoopV2SnapshotSession(
        store: store,
        principal: 'p',
        clock: clock.call,
      ).record(LoopSnapshotResource.marketOverview, <String, Object?>{
        'unexpected': true,
      });
      final session = LoopV2SnapshotSession(
        store: store,
        principal: 'p',
        clock: clock.call,
      );
      expect(session.restore(LoopSnapshotResource.marketOverview), isNull);
    });

    test('balances filed under one wallet never decode as another', () {
      final store = MemoryLoopSnapshotStore();
      final clock = _Clock(DateTime.utc(2026, 9, 27, 8));
      LoopV2SnapshotSession(
        store: store,
        principal: 'p',
        clock: clock.call,
      ).record(
        LoopSnapshotResource.walletBalances(s5OtherWalletId),
        s5BalancesBody(),
      );
      final session = LoopV2SnapshotSession(
        store: store,
        principal: 'p',
        clock: clock.call,
      );
      expect(
        session.restore(LoopSnapshotResource.walletBalances(s5OtherWalletId)),
        isNull,
      );
    });

    test('another principal clears what the last one left', () {
      final store = MemoryLoopSnapshotStore();
      final clock = _Clock(DateTime.utc(2026, 9, 27, 8));
      LoopV2SnapshotSession(
        store: store,
        principal: 'first',
        clock: clock.call,
      ).record(LoopSnapshotResource.marketOverview, s5OverviewBody());
      final second = LoopV2SnapshotSession(
        store: store,
        principal: 'second',
        clock: clock.call,
      );
      expect(store.records, isEmpty);
      expect(second.restore(LoopSnapshotResource.marketOverview), isNull);
    });

    test(
      'the transport hands a successful body to the tap, and only that',
      () async {
        final taps = <String>[];
        final api = DioLoopV2MarketApi(
          s5Dio(
            (options, handler) =>
                handler.resolve(s5Response(options, s5OverviewBody())),
          ),
          snapshotTap: (resource, body) => taps.add(resource),
        );
        await api.getOverview(
          accessToken: 'token',
          clientVersion: s5ClientVersion,
        );
        expect(taps, <String>[LoopSnapshotResource.marketOverview]);

        final refusing = DioLoopV2MarketApi(
          s5Dio(
            (options, handler) => handler.resolve(
              s5Response(options, <String, Object?>{'unexpected': true}),
            ),
          ),
          snapshotTap: (resource, body) => taps.add(resource),
        );
        await expectLater(
          refusing.getOverview(
            accessToken: 'token',
            clientVersion: s5ClientVersion,
          ),
          throwsA(isA<LoopBackendFailure>()),
        );
        expect(taps, hasLength(1));
      },
    );
  });

  // -------------------------------------------------------------------------
  // 4. The four pages
  // -------------------------------------------------------------------------
  group('market page', () {
    testWidgets('a cold start with a snapshot draws it, labelled, at once', (
      tester,
    ) async {
      final restorer = _Restorer(<String, LoopRestoredSnapshot>{
        LoopSnapshotResource.marketOverview: LoopRestoredSnapshot(
          value: s5Overview(),
          observedAt: DateTime.now().toUtc().subtract(
            const Duration(seconds: 40),
          ),
        ),
      });
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(pending: true),
        ),
        overrides: <Override>[
          loopSnapshotRestorerProvider.overrideWithValue(restorer),
        ],
        settle: false,
      );
      await _frames(tester);

      expect(find.byType(MarketAssetTile), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('market-state-loading')),
        findsNothing,
      );
      expect(_stripText(tester), contains('数据来自'));
      expect(_stripText(tester), contains('秒前，正在更新'));
    });

    testWidgets('the strip leaves once the live answer lands', (tester) async {
      final restorer = _Restorer(<String, LoopRestoredSnapshot>{
        LoopSnapshotResource.marketOverview: LoopRestoredSnapshot(
          value: s5Overview(),
          observedAt: DateTime.now().toUtc(),
        ),
      });
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(),
        overrides: <Override>[
          loopSnapshotRestorerProvider.overrideWithValue(restorer),
        ],
      );
      expect(
        find.byKey(const ValueKey<String>('loop-freshness-text')),
        findsNothing,
      );
      expect(find.byType(MarketAssetTile), findsWidgets);
    });

    testWidgets('no snapshot loads as rows of the list\'s own height', (
      tester,
    ) async {
      await pumpS5Page(
        tester,
        const MarketScreen(),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(pending: true),
        ),
        settle: false,
      );
      final skeleton = tester.widget<LoopSkeleton>(
        find.byKey(const ValueKey<String>('market-state-loading')),
      );
      expect(skeleton.type, LoopSkeletonType.priceRow);
      expect(skeleton.rowHeight, marketRowHeight);
      final row = find.byKey(const ValueKey<String>('loop-skeleton-price-row'));
      expect(row, findsOneWidget);
      expect(tester.getSize(row).height, marketRowHeight * 6);
      expect(find.byType(MarketAssetTile), findsNothing);
    });

    testWidgets('a refresh keeps the rows and a failed one says so', (
      tester,
    ) async {
      final market = _ScriptedMarket(FakeMarketReadGateway());
      await pumpS5Page(tester, const MarketScreen(), market: market);
      expect(find.byType(MarketAssetTile), findsWidgets);

      final refresh = Completer<MarketOverview>();
      market.script.add(refresh);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MarketScreen)),
      );
      unawaited(
        container.read(marketOverviewControllerProvider.notifier).reload(),
      );
      await _frames(tester);
      // Nothing flashes back to a skeleton while the read runs.
      expect(find.byType(MarketAssetTile), findsWidgets);
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('loop-updating-badge')),
        findsWidgets,
      );

      refresh.completeError(
        const LoopChainException(LoopChainFailureKind.offline),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MarketAssetTile), findsWidgets);
      expect(_stripText(tester), startsWith('更新失败，显示的是'));
      expect(
        find.byKey(const ValueKey<String>('loop-freshness-retry')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey<String>('loop-freshness-retry')))
            .height,
        greaterThanOrEqualTo(44),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('loop-freshness-retry')),
      );
      await tester.pumpAndSettle();
      expect(market.overviewReads, 3);
      expect(
        find.byKey(const ValueKey<String>('loop-freshness-text')),
        findsNothing,
      );
    });

    testWidgets('reduced motion: no pulse, no fade', (tester) async {
      await pumpS5Page(
        tester,
        _reduced(const MarketScreen()),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(pending: true),
        ),
        settle: false,
      );
      expect(
        find.byKey(const ValueKey<String>('market-state-loading')),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion: a snapshot appears without a fade', (
      tester,
    ) async {
      final restorer = _Restorer(<String, LoopRestoredSnapshot>{
        LoopSnapshotResource.marketOverview: LoopRestoredSnapshot(
          value: s5Overview(),
          observedAt: DateTime.now().toUtc(),
        ),
      });
      await pumpS5Page(
        tester,
        _reduced(const MarketScreen()),
        market: FakeMarketReadGateway(
          overview: S5Answer<MarketOverview>(pending: true),
        ),
        overrides: <Override>[
          loopSnapshotRestorerProvider.overrideWithValue(restorer),
        ],
        settle: false,
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('loop-freshness-text')),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('wallet page', () {
    testWidgets('the balances arrive by themselves: actions first, then rows', (
      tester,
    ) async {
      final wallet = _ScriptedWallet(FakeWalletReadGateway());
      final balances = Completer<LoopWalletBalances>();
      wallet.balanceScript.add(balances);
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: wallet,
        settle: false,
      );
      await _frames(tester);

      // The directory answered: the actions are drawn and the asset list is
      // rows of its own height. The net worth is a skeleton, never a zero.
      expect(
        find.byKey(const ValueKey<String>('wallet-send-entry')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-receive-entry')),
        findsOneWidget,
      );
      final skeleton = tester.widget<LoopSkeleton>(
        find.byKey(const ValueKey<String>('wallet-balances-state-loading')),
      );
      expect(skeleton.type, LoopSkeletonType.record);
      expect(
        find.byKey(const ValueKey<String>('wallet-total-loading')),
        findsOneWidget,
      );
      expect(find.textContaining('\$'), findsNothing);
      expect(find.text('0'), findsNothing);

      balances.complete(s5Balances());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      // The rows fade in over the place the skeleton held.
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byKey(
                const ValueKey<String>('wallet-balance-$s5NativeAssetId'),
              ),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('wallet-balances-state-loading')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-total-loading')),
        findsNothing,
      );
      expect(find.textContaining('\$'), findsWidgets);
    });

    testWidgets('a cold start with a snapshot draws the balances labelled', (
      tester,
    ) async {
      final at = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      final restorer = _Restorer(<String, LoopRestoredSnapshot>{
        LoopSnapshotResource.walletDirectory: LoopRestoredSnapshot(
          value: s5Directory(),
          observedAt: at,
        ),
        LoopSnapshotResource.walletBalances(s5WalletId): LoopRestoredSnapshot(
          value: s5Balances(),
          observedAt: at,
        ),
      });
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: FakeWalletReadGateway(
          directory: S5Answer<LoopWalletDirectory>(pending: true),
          balances: S5Answer<LoopWalletBalances>(pending: true),
        ),
        overrides: <Override>[
          loopSnapshotRestorerProvider.overrideWithValue(restorer),
        ],
        settle: false,
      );
      await _frames(tester);
      expect(
        find.byKey(ValueKey<String>('wallet-balance-$s5NativeAssetId')),
        findsOneWidget,
      );
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(_stripText(tester), '数据来自2 分钟前，正在更新');
      // The block the figures were read at is still stated under them.
      expect(find.textContaining('区块 120,628,164'), findsOneWidget);
    });

    testWidgets('a failed pull keeps the balances and says so', (tester) async {
      final wallet = _ScriptedWallet(FakeWalletReadGateway());
      wallet.balanceScript.add(
        Completer<LoopWalletBalances>()..complete(s5Balances()),
      );
      await pumpS5Page(tester, const WalletScreen(), wallet: wallet);
      final row = find.byKey(
        ValueKey<String>('wallet-balance-$s5NativeAssetId'),
      );
      expect(row, findsOneWidget);

      final refresh = Completer<LoopWalletBalances>();
      wallet.balanceScript.add(refresh);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WalletScreen)),
      );
      unawaited(
        container
            .read(walletBalancesControllerProvider(s5WalletId).notifier)
            .reload(),
      );
      await _frames(tester);
      expect(row, findsOneWidget);
      expect(find.byType(LoopSkeleton), findsNothing);

      refresh.completeError(
        const LoopChainException(LoopChainFailureKind.readFailed),
      );
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(_stripText(tester), startsWith('更新失败，显示的是'));
      expect(wallet.balanceReads, 2);
    });
  });

  group('community page', () {
    testWidgets('a cold start with a snapshot draws it, labelled', (
      tester,
    ) async {
      final restorer = _Restorer(<String, LoopRestoredSnapshot>{
        LoopSnapshotResource.communityHome: LoopRestoredSnapshot(
          value: _home(),
          observedAt: DateTime.now().toUtc().subtract(
            const Duration(seconds: 30),
          ),
        ),
      });
      final gateway = FakeCommunityGateway(home: _home())..pending = true;
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
        overrides: <Override>[
          loopSnapshotRestorerProvider.overrideWithValue(restorer),
        ],
        settle: false,
      );
      await _frames(tester);
      expect(find.text('Joined 0'), findsOneWidget);
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(_stripText(tester), contains('正在更新'));
    });

    testWidgets('no snapshot loads as rows of the index\'s own height', (
      tester,
    ) async {
      final gateway = FakeCommunityGateway()..pending = true;
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
        settle: false,
      );
      final skeleton = tester.widget<LoopSkeleton>(
        find.byKey(const ValueKey<String>('community-state-loading')),
      );
      expect(skeleton.type, LoopSkeletonType.record);
      expect(skeleton.rows, 4);
    });

    testWidgets('a pull keeps the index on screen', (tester) async {
      final gateway = FakeCommunityGateway(home: _home());
      await pumpCommunityPage(
        tester,
        const CommunityScreen(),
        community: gateway,
      );
      expect(find.text('Joined 0'), findsOneWidget);
      gateway.pending = true;
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CommunityScreen)),
      );
      unawaited(
        container.read(communityHomeControllerProvider.notifier).reload(),
      );
      await _frames(tester);
      expect(find.text('Joined 0'), findsOneWidget);
      expect(find.byType(LoopSkeleton), findsNothing);
    });

    testWidgets('reduced motion: the skeleton does not pulse', (tester) async {
      final gateway = FakeCommunityGateway()..pending = true;
      await pumpCommunityPage(
        tester,
        _reduced(const CommunityScreen()),
        community: gateway,
        settle: false,
      );
      expect(find.byType(LoopSkeleton), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('launch page', () {
    testWidgets('a cold start with a snapshot draws it, labelled', (
      tester,
    ) async {
      final restorer = _Restorer(<String, LoopRestoredSnapshot>{
        LoopSnapshotResource.launchOverview: LoopRestoredSnapshot(
          value: s7Overview(),
          observedAt: DateTime.now().toUtc().subtract(
            const Duration(seconds: 20),
          ),
        ),
      });
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(pending: true),
        ),
        overrides: <Override>[
          loopSnapshotRestorerProvider.overrideWithValue(restorer),
        ],
        settle: false,
      );
      await _frames(tester);
      expect(find.textContaining('个已登记项目'), findsOneWidget);
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(_stripText(tester), contains('正在更新'));
    });

    testWidgets('no snapshot loads as rows and a heading skeleton', (
      tester,
    ) async {
      await pumpS7Page(
        tester,
        const LaunchScreen(),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(pending: true),
        ),
        settle: false,
      );
      final skeleton = tester.widget<LoopSkeleton>(
        find.byKey(const ValueKey<String>('launch-state-loading')),
      );
      expect(skeleton.type, LoopSkeletonType.record);
      expect(
        find.byKey(const ValueKey<String>('loop-folio-heading-skeleton')),
        findsOneWidget,
      );
      expect(find.textContaining('个已登记项目'), findsNothing);
    });

    testWidgets('reduced motion: no pulse', (tester) async {
      await pumpS7Page(
        tester,
        _reduced(const LaunchScreen()),
        launch: FakeLaunchGateway(
          overview: S7Answer<LaunchOverview>(pending: true),
        ),
        settle: false,
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // 5. The freshness strip on its own
  // -------------------------------------------------------------------------
  group('freshness strip', () {
    final now = DateTime.utc(2026, 9, 27, 8);

    Future<void> pumpStrip(WidgetTester tester, LoopFreshnessStrip strip) =>
        tester.pumpWidget(
          MaterialApp(
            theme: LoopTheme.dark,
            home: Scaffold(body: Column(children: <Widget>[strip])),
          ),
        );

    testWidgets('says nothing over a live answer', (tester) async {
      await pumpStrip(
        tester,
        LoopFreshnessStrip(
          readAt: now,
          refreshing: true,
          refreshFailed: false,
          now: now,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('loop-freshness-text')),
        findsNothing,
      );
    });

    testWidgets('names a snapshot\'s age in the product\'s words', (
      tester,
    ) async {
      await pumpStrip(
        tester,
        LoopFreshnessStrip(
          restoredAt: now.subtract(const Duration(seconds: 12)),
          refreshing: true,
          refreshFailed: false,
          now: now,
        ),
      );
      await tester.pumpAndSettle();
      expect(_stripText(tester), '数据来自12 秒前，正在更新');
    });

    testWidgets('a failed refresh names the age of what stays', (tester) async {
      await pumpStrip(
        tester,
        LoopFreshnessStrip(
          readAt: now.subtract(const Duration(minutes: 3)),
          refreshing: false,
          refreshFailed: true,
          onRetry: () {},
          now: now,
        ),
      );
      await tester.pumpAndSettle();
      expect(_stripText(tester), '更新失败，显示的是3 分钟前读到的数据');
    });

    test('age wording', () {
      expect(loopAgeLabel(now, now: now), '刚刚');
      expect(loopAgeLabel(now.add(const Duration(minutes: 1)), now: now), '刚刚');
      expect(
        loopAgeLabel(now.subtract(const Duration(seconds: 59)), now: now),
        '59 秒前',
      );
      expect(
        loopAgeLabel(now.subtract(const Duration(minutes: 9)), now: now),
        '9 分钟前',
      );
    });
  });
}

CommunityHome _home() => CommunityHome(
  joined: <JoinedCommunity>[
    JoinedCommunity(
      community: testCommunity(
        communityId: '3fa85f64-5717-4562-b3fc-2c963f66af00',
        name: 'Joined 0',
      ),
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
  observedAt: DateTime.utc(2026, 9, 8, 1),
  source: 'database',
  recommendation: const CommunityRecommendation(
    recommendationId: '22222222-2222-4222-8222-222222222222',
    ruleVersion: 'rule:verified-members-v1',
  ),
);
