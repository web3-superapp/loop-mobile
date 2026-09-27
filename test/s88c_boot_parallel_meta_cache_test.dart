import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_boot_warmup.dart';
import 'package:loop_mobile/app/session/post_auth_profile_redirect_coordinator.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/policy/loop_capability_refresh.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_screens.dart';
import 'package:loop_mobile/features/wallet/wallet_read_widgets.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

import 'support/loop_ground_probe.dart';
import 'support/s5_fixtures.dart';
import 'support/s5_page_harness.dart';

/// S88c · decision 0098: the boot reads that share nothing go out together,
/// and the two D0 documents are served from memory for sixty seconds.
void main() {
  // This file mounts the wallet page through its own `pumpWidget`.
  loopWatchGround();

  group('requests that share nothing start together', () {
    test('policy and capabilities are both on the wire before either '
        'answers', () async {
      final server = _MetaServer()..hold = true;
      final container = _metaContainer(server, _Clock());
      addTearDown(container.dispose);

      final pending = container.read(loopV2MetaSnapshotProvider.future);
      await Future<void>.delayed(Duration.zero);

      // Neither has answered, and both were sent.
      expect(server.log, <String>['policy', 'capabilities']);
      expect(server.policyHeld.isCompleted, isFalse);
      expect(server.capabilitiesHeld.isCompleted, isFalse);

      // The second answers first: nothing waits on the order they were sent.
      server.capabilitiesHeld.complete();
      await Future<void>.delayed(Duration.zero);
      server.policyHeld.complete();
      final snapshot = await pending;
      expect(snapshot, isNotNull);
    });

    test('the wallet directory starts on landing, while Community is on '
        'screen, and the balances follow it without the tab being '
        'opened', () async {
      final wallet = _HeldWallet();
      final container = _warmupContainer(wallet);
      addTearDown(container.dispose);
      container.listen(loopBootWarmupProvider, (previous, next) {});
      await container.read(loopV2MetaSnapshotProvider.future);
      await _settle();

      // Not due yet: the account has not been placed.
      expect(wallet.directoryCalls, 0);

      container
          .read(loopProfileLandingProvider.notifier)
          .publish(LoopProfileLanding.community);
      await _settle();
      expect(wallet.directoryCalls, 1);
      expect(wallet.balanceCalls, 0);

      // The balances need the directory's active wallet id, so they are the
      // one read that still follows another.
      wallet.directory.last.complete(s5Directory());
      await _settle();
      expect(wallet.balanceCalls, 1);
      wallet.balances.last.complete(s5Balances());
      await _settle();

      // The page finds the answers already there and asks for nothing more.
      expect(container.read(walletDirectoryControllerProvider).isReady, isTrue);
      expect(
        container.read(walletBalancesControllerProvider(s5WalletId)).isReady,
        isTrue,
      );
      await container.read(walletDirectoryControllerProvider.notifier).load();
      await container
          .read(walletBalancesControllerProvider(s5WalletId).notifier)
          .load();
      expect(wallet.directoryCalls, 1);
      expect(wallet.balanceCalls, 1);
      expect(container.read(loopBootWarmupProvider).walletStarted, isTrue);
    });

    test('Community first read goes out while the profile read is still '
        'running, not after the landing is decided', () async {
      final community = _HeldCommunity();
      final container = ProviderContainer(
        overrides: [
          communityGatewayProvider.overrideWithValue(community),
          loopV2MetaSnapshotProvider.overrideWith(
            (ref) async => _withCommunity(s5MetaSnapshot()),
          ),
          loopBootstrapPrincipalKeyProvider.overrideWithValue('did:privy:s88c'),
        ],
      );
      addTearDown(container.dispose);
      container.listen(loopBootWarmupProvider, (previous, next) {});
      await container.read(loopV2MetaSnapshotProvider.future);
      await _settle();

      // The landing is still unknown: `GET /v2/profile` has not answered.
      expect(container.read(loopProfileLandingProvider).isUnknown, isTrue);
      expect(community.homeCalls, 1);
      expect(container.read(loopBootWarmupProvider).communityStarted, isTrue);
      // The wallet waits for the landing; it is not the launch page's read.
      expect(container.read(loopBootWarmupProvider).walletStarted, isFalse);
    });

    test('an account already placed in its opening sequence, or a closed '
        'community gate, does not warm Community', () async {
      final pendingCommunity = _HeldCommunity();
      final pending = ProviderContainer(
        overrides: [
          communityGatewayProvider.overrideWithValue(pendingCommunity),
          loopV2MetaSnapshotProvider.overrideWith(
            (ref) async => _withCommunity(s5MetaSnapshot()),
          ),
          loopBootstrapPrincipalKeyProvider.overrideWithValue('did:privy:s88c'),
        ],
      );
      addTearDown(pending.dispose);
      pending
          .read(loopProfileLandingProvider.notifier)
          .publish(LoopProfileLanding.loopIdSetup);
      pending.listen(loopBootWarmupProvider, (previous, next) {});
      await pending.read(loopV2MetaSnapshotProvider.future);
      await _settle();
      expect(pendingCommunity.homeCalls, 0);

      final closedCommunity = _HeldCommunity();
      final closed = ProviderContainer(
        overrides: [
          communityGatewayProvider.overrideWithValue(closedCommunity),
          // The S5 fixture keeps `community` unavailable.
          loopV2MetaSnapshotProvider.overrideWith(
            (ref) async => s5MetaSnapshot(),
          ),
          loopBootstrapPrincipalKeyProvider.overrideWithValue('did:privy:s88c'),
        ],
      );
      addTearDown(closed.dispose);
      closed.listen(loopBootWarmupProvider, (previous, next) {});
      await closed.read(loopV2MetaSnapshotProvider.future);
      await _settle();
      expect(closedCommunity.homeCalls, 0);
    });

    test('a closed wallet gate, a pending account and the Preview adapter '
        'warm nothing', () async {
      final closed = _HeldWallet();
      final closedContainer = _warmupContainer(
        closed,
        meta: s5MetaSnapshot(
          walletRead: LoopV2CapabilityAvailability.unavailable,
        ),
      );
      addTearDown(closedContainer.dispose);
      closedContainer.listen(loopBootWarmupProvider, (previous, next) {});
      await closedContainer.read(loopV2MetaSnapshotProvider.future);
      closedContainer
          .read(loopProfileLandingProvider.notifier)
          .publish(LoopProfileLanding.community);
      await _settle();
      expect(closed.directoryCalls, 0);

      final pending = _HeldWallet();
      final pendingContainer = _warmupContainer(pending);
      addTearDown(pendingContainer.dispose);
      pendingContainer.listen(loopBootWarmupProvider, (previous, next) {});
      await pendingContainer.read(loopV2MetaSnapshotProvider.future);
      pendingContainer
          .read(loopProfileLandingProvider.notifier)
          .publish(LoopProfileLanding.loopIdSetup);
      await _settle();
      expect(pending.directoryCalls, 0);

      final preview = _HeldWallet(mode: LoopChainGatewayMode.preview);
      final previewContainer = _warmupContainer(preview);
      addTearDown(previewContainer.dispose);
      previewContainer.listen(loopBootWarmupProvider, (previous, next) {});
      await previewContainer.read(loopV2MetaSnapshotProvider.future);
      previewContainer
          .read(loopProfileLandingProvider.notifier)
          .publish(LoopProfileLanding.community);
      await _settle();
      expect(preview.directoryCalls, 0);
    });

    test('a warm-up whose directory read failed leaves nothing behind for '
        'the page', () async {
      final wallet = _HeldWallet()..failDirectory = true;
      final container = _warmupContainer(wallet);
      addTearDown(container.dispose);
      container.listen(loopBootWarmupProvider, (previous, next) {});
      await container.read(loopV2MetaSnapshotProvider.future);
      container
          .read(loopProfileLandingProvider.notifier)
          .publish(LoopProfileLanding.community);
      await _settle();
      expect(wallet.directoryCalls, greaterThanOrEqualTo(1));
      final state = container.read(walletDirectoryControllerProvider);
      expect(state.phase, LoopChainViewPhase.loading);
      expect(state.failureKind, isNull);
      expect(wallet.balanceCalls, 0);
    });

    testWidgets('one pull sends the directory and the balances together', (
      tester,
    ) async {
      final wallet = _HeldWallet(answerFirst: true);
      await pumpS5Page(tester, const WalletScreen(), wallet: wallet);
      expect(wallet.directoryCalls, 1);
      expect(wallet.balanceCalls, 1);

      // The page's own pull callback, called the way the indicator calls it.
      final pull = tester
          .widget<RefreshIndicator>(
            find.byKey(const ValueKey<String>('loop-page-refresh')),
          )
          .onRefresh();
      await tester.pump();
      await tester.pump();

      // Both reads are on the wire and neither has answered.
      expect(wallet.directoryCalls, 2);
      expect(wallet.balanceCalls, 2);
      expect(wallet.directory.last.isCompleted, isFalse);
      expect(wallet.balances.last.isCompleted, isFalse);

      wallet.balances.last.complete(s5Balances());
      wallet.directory.last.complete(s5Directory());
      await tester.pumpAndSettle();
      await pull;
      expect(
        find.byKey(const ValueKey<String>('wallet-balance-$s5NativeAssetId')),
        findsOneWidget,
      );
    });
  });

  group('the D0 documents are held for sixty seconds', () {
    test('a second read inside sixty seconds sends nothing; one after '
        'sixty-one seconds sends the pair again', () async {
      final clock = _Clock();
      final server = _MetaServer();
      final container = _metaContainer(server, clock);
      addTearDown(container.dispose);
      container.listen(loopV2MetaSnapshotProvider, (previous, next) {});
      final observer = container.read(loopV2MetaObserverProvider);
      await container.read(loopV2MetaSnapshotProvider.future);
      expect(server.log, <String>['policy', 'capabilities']);

      // A page change inside the window: the trigger and a rebuilt
      // provider both answer from memory.
      clock.advance(const Duration(seconds: 30));
      observer.observe(LoopV2MetaObservationTrigger.navigation);
      container.invalidate(loopV2MetaSnapshotProvider);
      await container.read(loopV2MetaSnapshotProvider.future);
      clock.advance(const Duration(seconds: 29));
      observer.observe(LoopV2MetaObservationTrigger.appResumed);
      await _settle();
      expect(server.log, hasLength(2));

      // Sixty-one seconds after the answer: the next trigger re-reads.
      clock.advance(const Duration(seconds: 2));
      server.hold = true;
      observer.observe(LoopV2MetaObservationTrigger.navigation);
      await _settle();
      expect(server.log, hasLength(4));
      expect(server.log.sublist(2), <String>['policy', 'capabilities']);

      // Stale-while-revalidate: the old answer is still observable while
      // the new one is read.
      final during = container.read(loopV2MetaSnapshotProvider);
      expect(during.isLoading, isTrue);
      expect(during.value, isNotNull);
      expect(
        container
            .read(loopCapabilityProvider(LoopV2CapabilityId.walletRead))
            .isAvailable,
        isTrue,
      );

      // Triggers while it runs do not double it.
      observer.observe(LoopV2MetaObservationTrigger.navigation);
      await _settle();
      expect(server.log, hasLength(4));

      server.release();
      await _settle();
      expect(container.read(loopV2MetaSnapshotProvider).isLoading, isFalse);
      // …and the new answer starts a new window.
      clock.advance(const Duration(seconds: 59));
      observer.observe(LoopV2MetaObservationTrigger.navigation);
      await _settle();
      expect(server.log, hasLength(4));
    });

    test('a forced refresh reads now, inside the window, and joins a read '
        'already running', () async {
      final clock = _Clock();
      final server = _MetaServer();
      final container = _metaContainer(server, clock);
      addTearDown(container.dispose);
      container.listen(loopV2MetaSnapshotProvider, (previous, next) {});
      container.read(loopV2MetaObserverProvider);
      await container.read(loopV2MetaSnapshotProvider.future);
      expect(server.log, hasLength(2));

      clock.advance(const Duration(seconds: 5));
      final refresh = container.read(loopCapabilityRefreshProvider);
      await Future.wait<void>(<Future<void>>[refresh(), refresh()]);
      expect(server.log, hasLength(4));
    });

    test('a failed re-read keeps the previous answer, never opens a gate, '
        'and is retried rather than served as fresh', () async {
      final clock = _Clock();
      final server = _MetaServer();
      final container = _metaContainer(server, clock);
      addTearDown(container.dispose);
      container.listen(loopV2MetaSnapshotProvider, (previous, next) {});
      final observer = container.read(loopV2MetaObserverProvider);
      await container.read(loopV2MetaSnapshotProvider.future);

      clock.advance(const Duration(seconds: 61));
      server.fail = true;
      observer.observe(LoopV2MetaObservationTrigger.navigation);
      await _settle();
      final failed = container.read(loopV2MetaSnapshotProvider);
      expect(failed.hasError, isTrue);
      expect(failed.value, isNotNull);
      expect(observer.isRetryScheduled, isTrue);
      expect(
        container
            .read(loopCapabilityProvider(LoopV2CapabilityId.walletRead))
            .isAvailable,
        isTrue,
      );
      observer.dispose();
    });
  });

  group('a capability the server closes is applied on the next read', () {
    test('available → unavailable closes the wallet gate after the '
        'refresh', () async {
      final clock = _Clock();
      final server = _MetaServer();
      final container = _metaContainer(server, clock);
      addTearDown(container.dispose);
      container.listen(loopV2MetaSnapshotProvider, (previous, next) {});
      final observer = container.read(loopV2MetaObserverProvider);
      await container.read(loopV2MetaSnapshotProvider.future);

      bool blocked() => walletCapabilityBlocks(
        LoopChainGatewayMode.production,
        container.read(loopCapabilityProvider(LoopV2CapabilityId.walletRead)),
        container.read(loopCapabilityProvider(LoopV2CapabilityId.bscRead)),
      );
      expect(blocked(), isFalse);

      server.walletRead = LoopV2CapabilityAvailability.unavailable;
      // Inside the window the server's change is not asked for yet.
      clock.advance(const Duration(seconds: 30));
      observer.observe(LoopV2MetaObservationTrigger.navigation);
      await _settle();
      expect(blocked(), isFalse);

      clock.advance(const Duration(seconds: 31));
      observer.observe(LoopV2MetaObservationTrigger.navigation);
      await _settle();
      expect(blocked(), isTrue);
      final gate = container.read(
        loopCapabilityProvider(LoopV2CapabilityId.walletRead),
      );
      expect(gate.decision, LoopCapabilityDecision.unavailable);
      expect(gate.reasonCode, isNotNull);
    });

    testWidgets('the wallet page takes its whole-page block once the '
        'refreshed document closes it', (tester) async {
      final clock = _Clock();
      final server = _MetaServer();
      final wallet = _HeldWallet(answerFirst: true);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 2400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      loopArmGroundProbe(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopV2MetaRepositoryProvider.overrideWithValue(server),
            loopV2MetaClockProvider.overrideWithValue(clock.now),
            walletReadGatewayProvider.overrideWithValue(wallet),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            builder: (context, child) => LoopToastHost(child: child!),
            home: const WalletScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(WalletScreen)),
      );
      final observer = container.read(loopV2MetaObserverProvider);
      expect(
        find.byKey(const ValueKey<String>('wallet-balance-$s5NativeAssetId')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('wallet-capability-block')),
        findsNothing,
      );

      server.walletRead = LoopV2CapabilityAvailability.unavailable;
      clock.advance(const Duration(seconds: 61));
      observer.observe(LoopV2MetaObservationTrigger.appResumed);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('wallet-capability-block')),
        findsOneWidget,
      );
      expect(server.log, hasLength(4));
    });
  });
}

/// The S5 document with the `community` gate open.
LoopV2MetaSnapshot _withCommunity(LoopV2MetaSnapshot base) {
  final capabilities = base.capabilities;
  return LoopV2MetaSnapshot(
    clientPolicy: base.clientPolicy,
    capabilities: LoopV2Capabilities(
      contractVersion: capabilities.contractVersion,
      configVersion: capabilities.configVersion,
      effectiveAt: capabilities.effectiveAt,
      capabilities: <LoopV2Capability>[
        for (final capability in capabilities.capabilities)
          capability.id == LoopV2CapabilityId.community
              ? LoopV2Capability(
                  id: capability.id,
                  availability: LoopV2CapabilityAvailability.available,
                  reasonCode: null,
                  evidence: capability.evidence,
                )
              : capability,
      ],
    ),
  );
}

/// A community adapter whose home read never answers; only the calls are
/// counted. Nothing else is asked of it by the warm-up.
final class _HeldCommunity implements CommunityGateway {
  int homeCalls = 0;

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.production;

  @override
  Future<CommunityHome> loadHome() {
    homeCalls += 1;
    return Completer<CommunityHome>().future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() async {
  for (var i = 0; i < 12; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _Clock {
  DateTime _now = DateTime.utc(2026, 9, 27, 8);

  DateTime now() => _now;

  void advance(Duration by) => _now = _now.add(by);
}

ProviderContainer _metaContainer(_MetaServer server, _Clock clock) =>
    ProviderContainer(
      overrides: [
        loopV2MetaRepositoryProvider.overrideWithValue(server),
        loopV2MetaClockProvider.overrideWithValue(clock.now),
      ],
    );

ProviderContainer _warmupContainer(
  _HeldWallet wallet, {
  LoopV2MetaSnapshot? meta,
}) => ProviderContainer(
  overrides: [
    walletReadGatewayProvider.overrideWithValue(wallet),
    loopV2MetaSnapshotProvider.overrideWith(
      (ref) async => meta ?? s5MetaSnapshot(),
    ),
    loopBootstrapPrincipalKeyProvider.overrideWithValue('did:privy:s88c'),
  ],
);

/// The two public D0 documents, answered from the S5 fixtures. `walletRead`
/// is the one capability a test changes between reads.
final class _MetaServer implements LoopV2MetaRepository {
  final List<String> log = <String>[];
  LoopV2CapabilityAvailability walletRead =
      LoopV2CapabilityAvailability.available;
  bool hold = false;
  bool fail = false;
  Completer<void> policyHeld = Completer<void>();
  Completer<void> capabilitiesHeld = Completer<void>();

  void release() {
    if (!policyHeld.isCompleted) policyHeld.complete();
    if (!capabilitiesHeld.isCompleted) capabilitiesHeld.complete();
    hold = false;
  }

  LoopV2MetaSnapshot _document() => s5MetaSnapshot(walletRead: walletRead);

  @override
  Future<LoopV2ClientPolicy> getClientPolicy() async {
    log.add('policy');
    if (hold) {
      if (policyHeld.isCompleted) policyHeld = Completer<void>();
      await policyHeld.future;
    }
    if (fail) throw StateError('offline');
    return _document().clientPolicy;
  }

  @override
  Future<LoopV2Capabilities> getCapabilities() async {
    log.add('capabilities');
    if (hold) {
      if (capabilitiesHeld.isCompleted) capabilitiesHeld = Completer<void>();
      await capabilitiesHeld.future;
    }
    if (fail) throw StateError('offline');
    final document = _document().capabilities;
    return document;
  }
}

/// A wallet adapter whose every read is a [Completer] the test answers.
/// With [answerFirst], the first directory and balances reads answer at once.
final class _HeldWallet implements WalletReadGateway {
  _HeldWallet({
    this.mode = LoopChainGatewayMode.production,
    this.answerFirst = false,
  });

  @override
  final LoopChainGatewayMode mode;
  final bool answerFirst;

  final List<Completer<LoopWalletDirectory>> directory =
      <Completer<LoopWalletDirectory>>[];
  final List<Completer<LoopWalletBalances>> balances =
      <Completer<LoopWalletBalances>>[];

  int get directoryCalls => directory.length;
  int get balanceCalls => balances.length;

  @override
  Future<LoopWalletDirectory> loadWallets() {
    final completer = Completer<LoopWalletDirectory>();
    if (answerFirst && directory.isEmpty) completer.complete(s5Directory());
    directory.add(completer);
    if (failDirectory) {
      return Future<LoopWalletDirectory>.error(
        const LoopChainException(LoopChainFailureKind.unavailable),
      );
    }
    return completer.future;
  }

  /// Every directory read fails, as a service that is down would answer.
  bool failDirectory = false;

  @override
  Future<LoopWalletBalances> loadBalances(String walletId) {
    final completer = Completer<LoopWalletBalances>();
    if (answerFirst && balances.isEmpty) completer.complete(s5Balances());
    balances.add(completer);
    return completer.future;
  }

  @override
  Future<LoopWalletDirectory> setActiveWallet({
    required String walletId,
    required String? expectedActiveWalletId,
  }) => Completer<LoopWalletDirectory>().future;

  @override
  Future<LoopWalletActivityPage> loadActivity(
    String walletId, {
    String? cursor,
  }) => Completer<LoopWalletActivityPage>().future;

  @override
  Future<LoopWalletReceive> loadReceive(String walletId) =>
      Completer<LoopWalletReceive>().future;
}
