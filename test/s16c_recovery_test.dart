import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/post_auth_profile_redirect_coordinator.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/network/loop_connectivity_signal.dart';
import 'package:loop_mobile/features/account/privy_login_screen.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_page_recovery.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// S16-C · a read that failed must leave the owner a way out.
///
/// Four complaints from the same simulator session are pinned here:
///
/// * the unreachable page told the owner to try again and gave them nothing
///   to press, so the page did not heal when the radio came back;
/// * a cold start with no network showed an Ink frame with no copy on it at
///   all, which is indistinguishable from a launch that died;
/// * the refresh indicator took its colour from whatever it was dragged over;
/// * one failed profile read pinned a warning to every page for the rest of
///   the session, with neither a retry nor a way to put it away.
///
/// Every fix here reports what happened and never what it hopes happened: a
/// retry that fails stays on the same page, and nothing announces a read it
/// did not observe.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  LoopPageRetry? retry,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: LoopTheme.dark,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: LoopPageRecoveryScope(
          retry: retry,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

final _retryButton = find.byKey(
  const ValueKey<String>('loop-page-block-retry'),
);
final _retryFailed = find.byKey(
  const ValueKey<String>('loop-page-block-retry-failed'),
);

void main() {
  group('S16-C · the unreachable page can ask again', () {
    testWidgets('a page that never reached LOOP offers the read again', (
      tester,
    ) async {
      var reads = 0;
      await _pump(
        tester,
        const LoopPageBlock.unreachable(),
        retry: () async => reads += 1,
      );

      expect(find.text(LoopPageBlock.unreachableTitle), findsOneWidget);
      expect(_retryButton, findsOneWidget);
      expect(find.text(LoopPageBlock.retryLabel), findsOneWidget);

      await tester.tap(_retryButton);
      await tester.pumpAndSettle();
      expect(reads, 1);
    });

    testWidgets('a gate the server closed is never offered a retry', (
      tester,
    ) async {
      var reads = 0;
      await _pump(
        tester,
        const LoopPageBlock(title: '钱包读取当前不可用', message: '链上节点当前连不上。'),
        retry: () async => reads += 1,
      );

      // Nothing on this device can move a rule the server stated, so the page
      // never offers a button whose only outcome is the same refusal.
      expect(find.text('钱包读取当前不可用'), findsOneWidget);
      expect(_retryButton, findsNothing);
      expect(reads, 0);
    });

    testWidgets('a capability page block keeps the same two answers apart', (
      tester,
    ) async {
      await _pump(
        tester,
        const LoopCapabilityPageBlock(
          title: '钱包读取当前不可用',
          reasonCode: 'BSC_RPC_UNREACHABLE',
          unreachable: true,
        ),
        retry: () async {},
      );
      expect(_retryButton, findsOneWidget);

      await _pump(
        tester,
        const LoopCapabilityPageBlock(
          title: '钱包读取当前不可用',
          reasonCode: 'BSC_RPC_UNREACHABLE',
        ),
        retry: () async {},
      );
      expect(_retryButton, findsNothing);
    });

    testWidgets('a tree with no recovery to offer keeps the plain block', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoopPageBlock.unreachable())),
      );
      await tester.pump();

      expect(find.text(LoopPageBlock.unreachableTitle), findsOneWidget);
      expect(_retryButton, findsNothing);
    });

    testWidgets('a running retry is visible and cannot be started twice', (
      tester,
    ) async {
      final gate = Completer<void>();
      var reads = 0;
      await _pump(
        tester,
        const LoopPageBlock.unreachable(),
        retry: () {
          reads += 1;
          return gate.future;
        },
      );

      await tester.tap(_retryButton);
      await tester.pump();

      // The owner can see that a read is running, and the action that would
      // start a second one is gone while it does.
      expect(find.text(LoopPageBlock.retryingLabel), findsOneWidget);
      expect(find.text(LoopPageBlock.retryLabel), findsNothing);
      expect(tester.widget<LoopButton>(_retryButton).onPressed, isNull);

      await tester.tap(_retryButton, warnIfMissed: false);
      await tester.pump();
      expect(reads, 1);

      gate.complete();
      await tester.pumpAndSettle();
      expect(reads, 1);
    });

    testWidgets('a retry that failed stays on the same page and says so', (
      tester,
    ) async {
      await _pump(
        tester,
        const LoopPageBlock.unreachable(),
        retry: () async => throw StateError('the read did not get through'),
      );

      expect(_retryFailed, findsNothing);
      await tester.tap(_retryButton);
      await tester.pumpAndSettle();

      // The page is exactly where it was: no skeleton, no success, no
      // navigation — and the action is ready again.
      expect(find.text(LoopPageBlock.unreachableTitle), findsOneWidget);
      expect(find.byType(LoopSkeleton), findsNothing);
      expect(_retryFailed, findsOneWidget);
      expect(find.text(LoopPageBlock.retryLabel), findsOneWidget);
      expect(tester.widget<LoopButton>(_retryButton).onPressed, isNotNull);
    });

    testWidgets('the owner retry re-reads a failed observation once', (
      tester,
    ) async {
      final repository = _FlakyRepository()..fail = true;
      final container = ProviderContainer(
        overrides: [loopV2MetaRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );
      final observer = container.read(loopV2MetaObserverProvider);
      await tester.pump();
      expect(repository.reads, 1);
      expect(observer.isRetryScheduled, isTrue);

      // The owner asked now: the scheduled wait is retired rather than added
      // to, and the ladder starts over from the first rung.
      repository.fail = false;
      final pending = observer.retryObservation();
      await tester.pump();
      await tester.pump();
      await pending;
      expect(repository.reads, 2);
      expect(observer.lastTrigger, LoopV2MetaObservationTrigger.ownerRetry);
      expect(observer.isRetryScheduled, isFalse);
      expect(observer.consecutiveFailures, 0);

      // A completed observation is never re-read, however often it is asked.
      await observer.retryObservation();
      await tester.pump();
      expect(repository.reads, 2);
      await tester.pumpAndSettle();
    });

    testWidgets('a second owner retry never doubles the read', (tester) async {
      final repository = _FlakyRepository()..fail = true;
      final container = ProviderContainer(
        overrides: [loopV2MetaRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );
      final observer = container.read(loopV2MetaObserverProvider);
      await tester.pump();
      expect(repository.reads, 1);

      repository.hold = Completer<void>();
      final first = observer.retryObservation();
      await tester.pump();
      final second = observer.retryObservation();
      await tester.pump();
      expect(repository.reads, 2);

      repository.fail = false;
      repository.hold!.complete();
      repository.hold = null;
      await tester.pump();
      await first;
      await second;
      expect(repository.reads, 2);
      await tester.pumpAndSettle();
    });

    testWidgets('the page the owner is on heals without leaving it', (
      tester,
    ) async {
      final repository = _FlakyRepository()..fail = true;
      final signal = _SilentConnectivitySignal();
      addTearDown(signal.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_config),
            loopV2MetaRepositoryProvider.overrideWithValue(repository),
            loopConnectivitySignalProvider.overrideWithValue(signal),
            privyAuthGatewayProvider.overrideWithValue(
              _PendingRestoreGateway(),
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pump();
      await _drainLadder(tester);

      // Every page under the shell can reach the re-read, whether or not it
      // has a scrolling region left to pull.
      final scope = tester.widget<LoopPageRecoveryScope>(
        find.byType(LoopPageRecoveryScope),
      );
      expect(scope.retry, isNotNull);

      final before = repository.reads;
      repository.fail = false;
      await scope.retry!();
      await tester.pumpAndSettle();

      expect(repository.reads, before + 1);
    });
  });

  group('S16-C · a cold start says what it is doing', () {
    testWidgets('the restoring frame carries copy on its first paint', (
      tester,
    ) async {
      final gateway = _PendingRestoreGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
          child: const MaterialApp(home: PrivyLoginScreen()),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('privy-restoring-screen')),
        findsOneWidget,
      );
      // The Ink frame used to be a mark and a bar and nothing else, which is
      // what the native launch screen paints too.
      expect(
        find.text(PrivySessionRestoreScreen.restoringTitle),
        findsOneWidget,
      );
      expect(
        find.text(PrivySessionRestoreScreen.restoringMessage),
        findsOneWidget,
      );
      expect(find.text(PrivySessionRestoreScreen.slowMessage), findsNothing);
      // Saying what it is doing is not saying that it finished: the credential
      // form still belongs to an answer nobody has given yet.
      expect(find.text('欢迎来到 LOOP'), findsNothing);
    });

    testWidgets('a silent wait admits it is slow long before it gives up', (
      tester,
    ) async {
      final gateway = _PendingRestoreGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
          child: const MaterialApp(home: PrivyLoginScreen()),
        ),
      );
      await tester.pump();

      await tester.pump(
        PrivySessionRestoreScreen.slowAfter - const Duration(milliseconds: 1),
      );
      expect(
        find.text(PrivySessionRestoreScreen.restoringMessage),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text(PrivySessionRestoreScreen.slowMessage), findsOneWidget);
      // The hint is presentation only: the session is still undecided and the
      // frame is still the restoring one, not the undecided one.
      expect(
        find.byKey(const ValueKey<String>('privy-restoring-screen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('privy-restore-unavailable-screen')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('privy-email-field')),
        findsNothing,
      );
    });

    testWidgets('the undecided frame drops the hint for its own explanation', (
      tester,
    ) async {
      final gateway = _PendingRestoreGateway();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
          child: const MaterialApp(home: PrivyLoginScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(PrivySessionRestoreScreen.slowAfter);
      expect(find.text(PrivySessionRestoreScreen.slowMessage), findsOneWidget);

      await tester.pump(LoopSessionController.defaultRestoreWindow);
      expect(
        find.byKey(const ValueKey<String>('privy-restore-unavailable-screen')),
        findsOneWidget,
      );
      expect(find.text(PrivySessionRestoreScreen.slowMessage), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('privy-restore-unavailable-retry')),
        findsOneWidget,
      );
    });
  });

  group('S16-C · the refresh indicator does not borrow the page colour', () {
    testWidgets('the chip is opaque on Ink and on Lime alike', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LoopTheme.dark,
          home: loopRefreshable(
            onRefresh: () async {},
            child: ListView(children: const <Widget>[Text('row')]),
          ),
        ),
      );
      await tester.pump();

      final indicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      expect(indicator.backgroundColor, LoopColors.chalk);
      expect(indicator.color, LoopColors.ink);
      // A translucent ground composites with whatever it is dragged over; over
      // the Lime folio the card token read as a dark olive smudge.
      expect(indicator.backgroundColor, isNot(LoopColors.card2));
      expect(indicator.backgroundColor!.a, 1.0);
      expect(indicator.color!.a, 1.0);
    });
  });

  group('S16-C · a short collection can still be pulled', () {
    testWidgets('a collection with its own controller still overscrolls', (
      tester,
    ) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);
      var reads = 0;
      await _pump(
        tester,
        LoopStreamPage(
          archetype: LoopPageArchetype.listing,
          title: '成员',
          onRefresh: () async => reads += 1,
          // A list that owns a controller is not the route's primary scroll
          // view, so nothing hands it always-scrollable physics. With one
          // screen of rows or fewer it could not be dragged at all, and the
          // gesture existed only on lists that happened to be long.
          collection: ListView(
            controller: scrollController,
            children: const <Widget>[Text('one'), Text('two')],
          ),
        ),
      );

      expect(find.text('one'), findsOneWidget);
      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 320),
        1000,
      );
      await tester.pumpAndSettle();

      expect(reads, 1);
      // Re-reading never trades the rows for a skeleton.
      expect(find.text('one'), findsOneWidget);
    });

    testWidgets('a short collection with no controller keeps refreshing', (
      tester,
    ) async {
      var reads = 0;
      await _pump(
        tester,
        LoopStreamPage(
          archetype: LoopPageArchetype.listing,
          title: '成员',
          onRefresh: () async => reads += 1,
          collection: ListView(
            children: const <Widget>[Text('one'), Text('two')],
          ),
        ),
      );

      await tester.fling(
        find.byType(Scrollable).first,
        const Offset(0, 320),
        1000,
      );
      await tester.pumpAndSettle();
      expect(reads, 1);
    });

    testWidgets('the platform physics stay under the always-scrollable one', (
      tester,
    ) async {
      await _pump(
        tester,
        LoopStreamPage(
          archetype: LoopPageArchetype.listing,
          title: '成员',
          onRefresh: () async {},
          collection: ListView(
            controller: ScrollController(),
            children: const <Widget>[Text('one')],
          ),
        ),
      );

      // Making a list draggable must not cost it the platform's own edge
      // behaviour: the configuration composes, it does not replace.
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.physics, isA<AlwaysScrollableScrollPhysics>());
      expect(position.physics.parent, isNotNull);
    });

    testWidgets('a collection that states its own physics keeps them', (
      tester,
    ) async {
      await _pump(
        tester,
        LoopStreamPage(
          archetype: LoopPageArchetype.listing,
          title: '成员',
          onRefresh: () async {},
          collection: ListView(
            physics: const NeverScrollableScrollPhysics(),
            children: const <Widget>[Text('one')],
          ),
        ),
      );

      // The ambient default is a default, never an override.
      expect(
        tester.widget<Scrollable>(find.byType(Scrollable).first).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
    });

    testWidgets('a blocked stream page still takes no gesture', (tester) async {
      var reads = 0;
      await _pump(
        tester,
        LoopStreamPage(
          archetype: LoopPageArchetype.listing,
          title: '成员',
          onRefresh: () async => reads += 1,
          block: const LoopPageBlock.unreachable(),
          collection: ListView(children: const <Widget>[Text('one')]),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('loop-page-refresh')),
        findsNothing,
      );
      expect(find.text('one'), findsNothing);
      expect(reads, 0);
    });
  });

  group('S16-C · the profile warning is not a life sentence', () {
    testWidgets('a retry re-reads the profile and clears a read that works', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var reads = 0;
      container.read(loopProfileLandingProvider.notifier)
        ..bindRecheck(() async {
          reads += 1;
          container
              .read(loopProfileLandingProvider.notifier)
              .publish(LoopProfileLanding.community);
        })
        ..publish(
          LoopProfileLanding.communityUnavailable,
          kind: ProfileGatewayFailureKind.offline,
        );
      await _pumpBanner(tester, container);

      expect(_banner, findsOneWidget);
      await tester.tap(_bannerRetry);
      await tester.pumpAndSettle();

      expect(reads, 1);
      // The warning is gone because the profile was actually read, not because
      // the owner pressed something.
      expect(_banner, findsNothing);
      expect(
        container.read(loopProfileLandingProvider).landing,
        LoopProfileLanding.community,
      );
    });

    testWidgets('a retry that fails leaves the warning exactly as it was', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var reads = 0;
      container.read(loopProfileLandingProvider.notifier)
        ..bindRecheck(() async {
          reads += 1;
          container
              .read(loopProfileLandingProvider.notifier)
              .publish(
                LoopProfileLanding.communityUnavailable,
                kind: ProfileGatewayFailureKind.offline,
              );
        })
        ..publish(
          LoopProfileLanding.communityUnavailable,
          kind: ProfileGatewayFailureKind.offline,
        );
      await _pumpBanner(tester, container);

      await tester.tap(_bannerRetry);
      await tester.pumpAndSettle();

      expect(reads, 1);
      expect(_banner, findsOneWidget);
      expect(container.read(loopProfileLandingProvider).isUnavailable, isTrue);
    });

    testWidgets('a running retry is visible and single-flight', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final gate = Completer<void>();
      var reads = 0;
      container.read(loopProfileLandingProvider.notifier)
        ..bindRecheck(() {
          reads += 1;
          return gate.future;
        })
        ..publish(
          LoopProfileLanding.communityUnavailable,
          kind: ProfileGatewayFailureKind.unavailable,
        );
      await _pumpBanner(tester, container);

      await tester.tap(_bannerRetry);
      await tester.pump();
      expect(find.text('正在重新读取资料状态。'), findsOneWidget);
      expect(tester.widget<LoopButton>(_bannerRetry).onPressed, isNull);

      unawaited(container.read(loopProfileLandingProvider.notifier).recheck());
      await tester.pump();
      expect(reads, 1);

      gate.complete();
      await tester.pumpAndSettle();
      // No answer was published, so the warning stands and the action returns.
      expect(_banner, findsOneWidget);
      expect(tester.widget<LoopButton>(_bannerRetry).onPressed, isNotNull);
    });

    testWidgets('closing the warning hides it without reading anything', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var reads = 0;
      container.read(loopProfileLandingProvider.notifier)
        ..bindRecheck(() async => reads += 1)
        ..publish(
          LoopProfileLanding.communityUnavailable,
          kind: ProfileGatewayFailureKind.offline,
        );
      await _pumpBanner(tester, container);

      await tester.tap(_bannerDismiss);
      await tester.pumpAndSettle();

      expect(_banner, findsNothing);
      expect(reads, 0);
      // Putting the notice away is not an answer: the profile is still unread
      // and every surface that asks still hears so.
      final state = container.read(loopProfileLandingProvider);
      expect(state.isUnavailable, isTrue);
      expect(state.landing, LoopProfileLanding.communityUnavailable);
    });

    testWidgets('a new answer brings a dismissed warning back', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(loopProfileLandingProvider.notifier);
      controller.publish(
        LoopProfileLanding.communityUnavailable,
        kind: ProfileGatewayFailureKind.offline,
      );
      await _pumpBanner(tester, container);
      await tester.tap(_bannerDismiss);
      await tester.pumpAndSettle();
      expect(_banner, findsNothing);

      controller.publish(
        LoopProfileLanding.communityUnavailable,
        kind: ProfileGatewayFailureKind.offline,
      );
      await tester.pumpAndSettle();
      expect(_banner, findsOneWidget);
    });

    testWidgets('a policy refusal keeps the close action and nothing else', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var reads = 0;
      container.read(loopProfileLandingProvider.notifier)
        ..bindRecheck(() async => reads += 1)
        ..publish(
          LoopProfileLanding.communityUnavailable,
          kind: ProfileGatewayFailureKind.permissionDenied,
        );
      await _pumpBanner(tester, container);

      expect(_banner, findsOneWidget);
      expect(_bannerRetry, findsNothing);
      expect(_bannerDismiss, findsOneWidget);

      // Even asked directly, a policy answer is never re-read.
      await container.read(loopProfileLandingProvider.notifier).recheck();
      expect(reads, 0);
    });

    test('only a read that could answer differently may be repeated', () {
      expect(loopProfileRecheckCanHelp(null), isTrue);
      expect(
        loopProfileRecheckCanHelp(ProfileGatewayFailureKind.offline),
        isTrue,
      );
      expect(
        loopProfileRecheckCanHelp(ProfileGatewayFailureKind.unavailable),
        isTrue,
      );
      expect(
        loopProfileRecheckCanHelp(ProfileGatewayFailureKind.permissionDenied),
        isFalse,
      );
      expect(
        loopProfileRecheckCanHelp(ProfileGatewayFailureKind.regionBlocked),
        isFalse,
      );
      expect(
        loopProfileRecheckCanHelp(ProfileGatewayFailureKind.stepUpRequired),
        isFalse,
      );
    });
  });
}

final _banner = find.byKey(
  const ValueKey<String>('profile-availability-banner'),
);
final _bannerRetry = find.byKey(
  const ValueKey<String>('profile-availability-retry'),
);
final _bannerDismiss = find.byKey(
  const ValueKey<String>('profile-availability-dismiss'),
);

Future<void> _pumpBanner(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: ProfileAvailabilityBanner()),
      ),
    ),
  );
  await tester.pump();
}

const _config = AppConfig(
  privyAppId: '',
  privyAppClientId: '',
  streamApiKey: '',
  backendBaseUrl: 'https://api.example.test',
  firebaseConfigured: false,
);

Future<void> _drainLadder(WidgetTester tester) async {
  for (final delay in LoopV2MetaObserver.retryBackoff) {
    await tester.pump(delay);
    await tester.pump();
  }
}

final class _SilentConnectivitySignal implements LoopConnectivitySignal {
  final _controller = StreamController<void>.broadcast();

  void dispose() => unawaited(_controller.close());

  @override
  Stream<void> get onRestored => _controller.stream;
}

final class _PendingRestoreGateway implements PrivyAuthGateway {
  @override
  Future<PrivySessionSnapshot> restoreSession() =>
      Completer<PrivySessionSnapshot>().future;

  @override
  Stream<PrivySessionSnapshot> watchSession() =>
      const Stream<PrivySessionSnapshot>.empty();

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) => throw UnimplementedError();

  @override
  Future<String> getCurrentAccessToken() => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<void> sendEmailCode(String email) async {}

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) => throw UnimplementedError();
}

final class _FlakyRepository implements LoopV2MetaRepository {
  var fail = false;
  var reads = 0;
  Completer<void>? hold;

  @override
  Future<LoopV2ClientPolicy> getClientPolicy() async {
    reads += 1;
    await hold?.future;
    if (fail) throw StateError('policy unavailable');
    return _policy();
  }

  @override
  Future<LoopV2Capabilities> getCapabilities() async {
    await hold?.future;
    if (fail) throw StateError('capabilities unavailable');
    return _capabilities();
  }
}

LoopV2ClientPolicy _policy() {
  return LoopV2ClientPolicy(
    contractVersion: '2.0',
    configVersion: 'productPolicyV2.2026-09-01',
    effectiveAt: DateTime.utc(2026, DateTime.september),
    defaultRoute: LoopV2PrimaryTab.community,
    navigation: LoopV2Navigation(primaryTabs: LoopV2PrimaryTab.values),
    versionGate: const LoopV2VersionGate.unavailable(
      reasonCode: 'CLIENT_VERSION_POLICY_UNAVAILABLE',
    ),
    regionGate: const LoopV2RegionGate(
      status: LoopV2RegionGateStatus.unavailable,
      reasonCode: 'REGION_POLICY_UNAVAILABLE',
      supportUrl: null,
      readOnlyAssetAccess: null,
    ),
    termsGate: const LoopV2TermsGate(
      status: LoopV2TermsGateStatus.unavailable,
      requiredVersion: null,
      reasonCode: 'TERMS_POLICY_UNAVAILABLE',
    ),
  );
}

LoopV2Capabilities _capabilities() {
  return LoopV2Capabilities(
    contractVersion: '2.0',
    configVersion: 'productPolicyV2.2026-09-01',
    effectiveAt: DateTime.utc(2026, DateTime.september),
    capabilities: <LoopV2Capability>[
      for (final id in LoopV2CapabilityId.values)
        LoopV2Capability(
          id: id,
          availability: LoopV2CapabilityAvailability.available,
          reasonCode: null,
          evidence: const LoopV2CapabilityEvidence(
            status: LoopV2CapabilityEvidenceStatus.notApplicable,
            reasonCode: null,
          ),
        ),
    ],
  );
}
