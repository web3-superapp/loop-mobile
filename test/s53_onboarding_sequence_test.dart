import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/session/onboarding_sequence.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/wallet_creation_facts.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/features/wallet/wallet_read_gateway.dart';
import 'package:loop_mobile/features/wallet/wallet_read_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';
import 'package:loop_mobile/integrations/personalization/shared_preferences_onboarding_store.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

import 'support/authenticated_test_privy_gateway.dart';
import 'support/loop_ground_probe.dart';

/// The principal the authenticated widget-test gateway signs in as.
const _principal = 'did:privy:test-widget';

void main() {
  // This file mounts pages through its own `pumpWidget`, so it arms the
  // ground probe itself; the page harnesses arm it for everybody else.
  loopWatchGround();

  final partition = LoopV2OwnerPartition.fromPrincipal(_principal);

  group('step positions', () {
    test('the four steps carry the prototype numbers 02 … 05 of 05', () {
      expect(LoopOnboardingStep.total, 5);
      expect(LoopOnboardingStep.values.map((step) => step.number), <int>[
        2,
        3,
        4,
        5,
      ]);
      expect(LoopOnboardingStep.values.map((step) => step.slug), <String>[
        'wallet-create',
        'wallet-recovery',
        'security-setup',
        'loop-id-setup',
      ]);
    });

    test('02 has nothing behind it; every later step steps back one', () {
      expect(LoopOnboardingStep.walletCreate.previous, isNull);
      expect(
        LoopOnboardingStep.walletBackup.previous,
        LoopOnboardingStep.walletCreate,
      );
      expect(
        LoopOnboardingStep.security.previous,
        LoopOnboardingStep.walletBackup,
      );
      expect(LoopOnboardingStep.loopId.previous, LoopOnboardingStep.security);
      expect(LoopOnboardingStep.loopId.next, isNull);
    });

    test('an unknown stored name is read as no position, never as step 02', () {
      expect(LoopOnboardingStep.tryParse('walletCreate'), isNotNull);
      expect(LoopOnboardingStep.tryParse('someLaterStep'), isNull);
      expect(LoopOnboardingStep.tryParse(null), isNull);
    });
  });

  group('sequence controller', () {
    test('a first entry starts at 02 and records it', () async {
      final store = InMemoryLoopOnboardingProgressStore();
      final container = _container(store);

      final step = await container
          .read(loopOnboardingSequenceProvider.notifier)
          .begin(_principal);

      expect(step, LoopOnboardingStep.walletCreate);
      expect(
        container.read(loopOnboardingSequenceProvider).step,
        LoopOnboardingStep.walletCreate,
      );
      expect(await store.read(partition), LoopOnboardingStep.walletCreate);
    });

    test('a recorded position is resumed, not restarted', () async {
      final store = InMemoryLoopOnboardingProgressStore();
      await store.write(partition, LoopOnboardingStep.security);
      final container = _container(store);

      expect(
        await container
            .read(loopOnboardingSequenceProvider.notifier)
            .begin(_principal),
        LoopOnboardingStep.security,
      );
    });

    test("another account never resumes this one's position", () async {
      final store = InMemoryLoopOnboardingProgressStore();
      await store.write(partition, LoopOnboardingStep.loopId);
      final container = _container(store);

      expect(
        await container
            .read(loopOnboardingSequenceProvider.notifier)
            .begin('did:privy:somebody-else'),
        LoopOnboardingStep.walletCreate,
      );
    });

    test('moving forward and back both record the new position', () async {
      final store = InMemoryLoopOnboardingProgressStore();
      final container = _container(store);
      final controller = container.read(
        loopOnboardingSequenceProvider.notifier,
      );
      await controller.begin(_principal);

      controller.moveTo(LoopOnboardingStep.security);
      await _settle();
      expect(await store.read(partition), LoopOnboardingStep.security);

      controller.moveTo(LoopOnboardingStep.walletBackup);
      await _settle();
      expect(await store.read(partition), LoopOnboardingStep.walletBackup);
    });

    test('activation ends the sequence and drops the position', () async {
      final store = InMemoryLoopOnboardingProgressStore();
      final container = _container(store);
      final controller = container.read(
        loopOnboardingSequenceProvider.notifier,
      );
      await controller.begin(_principal);

      await controller.complete();

      expect(container.read(loopOnboardingSequenceProvider).isActive, isFalse);
      expect(await store.read(partition), isNull);
    });

    test(
      'signing out keeps the position so the next sign-in resumes',
      () async {
        final store = InMemoryLoopOnboardingProgressStore();
        final container = _container(store);
        final controller = container.read(
          loopOnboardingSequenceProvider.notifier,
        );
        await controller.begin(_principal);
        controller.moveTo(LoopOnboardingStep.security);
        await _settle();

        controller.leave();

        expect(
          container.read(loopOnboardingSequenceProvider).isActive,
          isFalse,
        );
        expect(await store.read(partition), LoopOnboardingStep.security);
        expect(await controller.begin(_principal), LoopOnboardingStep.security);
      },
    );

    test('a skipped recovery step is not recorded as an enrolment', () async {
      final container = _container(InMemoryLoopOnboardingProgressStore());
      final controller = container.read(
        loopOnboardingSequenceProvider.notifier,
      );
      await controller.begin(_principal);

      controller.recordRecoveryDecision(null);
      expect(
        container.read(loopOnboardingSequenceProvider).enrolledRecoveryMethod,
        isNull,
      );

      controller.recordRecoveryDecision('passkey');
      expect(
        container.read(loopOnboardingSequenceProvider).enrolledRecoveryMethod,
        'passkey',
      );
    });
  });

  group('device-local progress store', () {
    test('the key is namespaced and partitioned by account', () async {
      final written = <String, String>{};
      final removed = <String>[];
      final store = SharedPreferencesLoopOnboardingProgressStore.forTesting(
        (key) async => written[key],
        (key, value) async => written[key] = value,
        (key) async => removed.add(key),
      );

      await store.write(partition, LoopOnboardingStep.security);
      expect(written.keys.single, 'loop.onboarding.v1.step.$partition');
      // Only a step name is stored. No principal, no credential, no alias.
      expect(written.values.single, 'security');
      expect(written.values.single, isNot(contains(_principal)));
      expect(written.keys.single, isNot(contains(_principal)));

      expect(await store.read(partition), LoopOnboardingStep.security);
      expect(await store.read('another-partition'), isNull);

      await store.clear(partition);
      expect(removed, <String>['loop.onboarding.v1.step.$partition']);
    });

    test('a value this build cannot read is no position at all', () async {
      final store = SharedPreferencesLoopOnboardingProgressStore.forTesting(
        (key) async => 'somethingElse',
        (key, value) async {},
        (key) async {},
      );

      expect(await store.read(partition), isNull);
    });

    test('a refusing device never invents a position', () async {
      final store = SharedPreferencesLoopOnboardingProgressStore.forTesting(
        (key) async => throw StateError('no storage'),
        (key, value) async => throw StateError('no storage'),
        (key) async => throw StateError('no storage'),
      );

      expect(await store.read(partition), isNull);
      await store.write(partition, LoopOnboardingStep.loopId);
      await store.clear(partition);
    });

    test('the unavailable store keeps nothing and claims nothing', () async {
      const store = UnavailableLoopOnboardingProgressStore();
      await store.write(partition, LoopOnboardingStep.security);
      expect(await store.read(partition), isNull);
    });
  });

  group('embedded wallet watch', () {
    testWidgets('a wallet seen on a later poll is reported as seen', (
      tester,
    ) async {
      final gateway = _FakeWalletReadGateway(walletFromAttempt: 3);
      final container = ProviderContainer(
        overrides: [walletReadGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      unawaited(
        container.read(loopEmbeddedWalletWatchProvider.notifier).start(),
      );
      await tester.pump();
      expect(container.read(loopEmbeddedWalletWatchProvider).observed, isFalse);
      expect(container.read(loopEmbeddedWalletWatchProvider).running, isTrue);

      for (var tick = 0; tick < 3; tick++) {
        await tester.pump(LoopEmbeddedWalletWatchController.pollInterval);
      }

      final state = container.read(loopEmbeddedWalletWatchProvider);
      expect(state.observed, isTrue);
      expect(state.running, isFalse);
      expect(state.attempts, 3);
      expect(gateway.reads, 3);
    });

    testWidgets('60 seconds without a wallet times out and never fails', (
      tester,
    ) async {
      final gateway = _FakeWalletReadGateway();
      final container = ProviderContainer(
        overrides: [walletReadGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      unawaited(
        container.read(loopEmbeddedWalletWatchProvider.notifier).start(),
      );
      await tester.pump();
      for (
        var tick = 0;
        tick < LoopEmbeddedWalletWatchController.maximumAttempts;
        tick++
      ) {
        await tester.pump(LoopEmbeddedWalletWatchController.pollInterval);
      }

      final state = container.read(loopEmbeddedWalletWatchProvider);
      expect(state.timedOut, isTrue);
      expect(state.observed, isFalse);
      expect(state.attempts, LoopEmbeddedWalletWatchController.maximumAttempts);
      expect(gateway.reads, LoopEmbeddedWalletWatchController.maximumAttempts);
      expect(
        LoopEmbeddedWalletWatchController.pollInterval.inSeconds *
            LoopEmbeddedWalletWatchController.maximumAttempts,
        60,
      );
    });

    testWidgets('a refused read is never read as "you have no wallet"', (
      tester,
    ) async {
      final gateway = _FakeWalletReadGateway(failing: true);
      final container = ProviderContainer(
        overrides: [walletReadGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      unawaited(
        container.read(loopEmbeddedWalletWatchProvider.notifier).start(),
      );
      await tester.pump();
      await tester.pump(LoopEmbeddedWalletWatchController.pollInterval);

      final state = container.read(loopEmbeddedWalletWatchProvider);
      expect(state.observed, isFalse);
      expect(state.timedOut, isFalse);
      expect(state.running, isTrue);

      // Drain the remaining ticks so no timer outlives the test.
      for (
        var tick = 0;
        tick < LoopEmbeddedWalletWatchController.maximumAttempts;
        tick++
      ) {
        await tester.pump(LoopEmbeddedWalletWatchController.pollInterval);
      }
    });

    testWidgets('no wallet directory at all is stated, not guessed', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(loopEmbeddedWalletWatchProvider.notifier).start();
      await tester.pump();

      final state = container.read(loopEmbeddedWalletWatchProvider);
      expect(state.unavailable, isTrue);
      expect(state.observed, isFalse);
      expect(state.timedOut, isFalse);
    });
  });

  group('wallet-create page', () {
    testWidgets('an unseen wallet leaves every step unfinished', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId(
          'wallet-create',
          walletCreation: LoopWalletCreationFacts(
            phase: LoopWalletCreationPhase.working,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('wallet-create-progress')),
        findsOneWidget,
      );
      expect(find.text('已完成'), findsNothing);
      expect(find.text('未完成'), findsNWidgets(4));
      expect(find.text('02 / 05'), findsNothing);
      expect(_stepCounter(tester), '02 / 05');
      // Waiting never blocks the sequence.
      expect(_enabled(tester, 'wallet-create-continue'), isTrue);
    });

    testWidgets('a seen wallet ticks the two steps it actually proves', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId(
          'wallet-create',
          walletCreation: LoopWalletCreationFacts(
            phase: LoopWalletCreationPhase.observed,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('wallet-create-observed')),
        findsOneWidget,
      );
      // Key pair and secure element, and nothing a later step owns.
      expect(find.text('已完成'), findsNWidgets(2));
      expect(find.text('未完成'), findsNWidgets(2));
      expect(find.textContaining('第 3 步选择后才算完成'), findsOneWidget);
      expect(find.textContaining('第 5 步完成后才算完成'), findsOneWidget);
    });

    testWidgets('running out of time says so and still lets the owner on', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId(
          'wallet-create',
          walletCreation: LoopWalletCreationFacts(
            phase: LoopWalletCreationPhase.timedOut,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('wallet-create-timeout')),
        findsOneWidget,
      );
      expect(find.text('钱包还在创建中，可以先继续'), findsOneWidget);
      expect(find.text('已完成'), findsNothing);
      expect(_enabled(tester, 'wallet-create-continue'), isTrue);
    });

    testWidgets('a step 03 choice ticks the recovery row and nothing else', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId(
          'wallet-create',
          walletCreation: LoopWalletCreationFacts(
            phase: LoopWalletCreationPhase.observed,
            recoveryEnrolled: true,
          ),
        ),
      );

      expect(find.text('已完成'), findsNWidgets(3));
      expect(find.text('未完成'), findsOneWidget);
    });

    testWidgets('a failed creation shows the provider sentence, not ours', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId(
          'wallet-create',
          walletCreation: LoopWalletCreationFacts(
            phase: LoopWalletCreationPhase.working,
            providerMessage: 'провайдер отказал',
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('wallet-create-provider-message')),
        findsOneWidget,
      );
      expect(find.text('провайдер отказал'), findsOneWidget);
    });
  });

  group('the sequence on the router', () {
    testWidgets('a pending account lands on 02, not straight on 05', (
      tester,
    ) async {
      final store = InMemoryLoopOnboardingProgressStore();
      final router = await _pumpLoopApp(tester, store: store);

      expect(router.state.matchedLocation, '/auth/wallet/create');
      expect(
        find.byKey(const ValueKey<String>('wallet-create-continue')),
        findsOneWidget,
      );
      // 02 follows an accepted credential, so it offers no way back to login.
      expect(
        find.byKey(const ValueKey<String>('loop-topbar-back')),
        findsNothing,
      );
      expect(await store.read(partition), LoopOnboardingStep.walletCreate);
    });

    testWidgets('02 → 03 → 04 → 05 and back again, one step at a time', (
      tester,
    ) async {
      final store = InMemoryLoopOnboardingProgressStore();
      final router = await _pumpLoopApp(tester, store: store);

      await _tap(tester, const ValueKey<String>('wallet-create-continue'));
      expect(router.state.matchedLocation, '/auth/wallet/backup');
      expect(_stepCounter(tester), '03 / 05');
      expect(await store.read(partition), LoopOnboardingStep.walletBackup);

      await _tap(tester, const ValueKey<String>('wallet-recovery-later'));
      expect(router.state.matchedLocation, '/auth/security');
      expect(_stepCounter(tester), '04 / 05');
      expect(await store.read(partition), LoopOnboardingStep.security);

      await _tap(tester, const ValueKey<String>('security-setup-continue'));
      expect(router.state.matchedLocation, '/auth/loop-id');
      expect(_stepCounter(tester), '05 / 05');
      expect(await store.read(partition), LoopOnboardingStep.loopId);

      await _tapBack(tester);
      expect(router.state.matchedLocation, '/auth/security');
      expect(await store.read(partition), LoopOnboardingStep.security);

      await _tapBack(tester);
      expect(router.state.matchedLocation, '/auth/wallet/backup');

      await _tapBack(tester);
      expect(router.state.matchedLocation, '/auth/wallet/create');
      expect(await store.read(partition), LoopOnboardingStep.walletCreate);
    });

    testWidgets('a killed process reopens on the step it stopped on', (
      tester,
    ) async {
      final store = InMemoryLoopOnboardingProgressStore();
      await store.write(partition, LoopOnboardingStep.security);

      final router = await _pumpLoopApp(tester, store: store);

      expect(router.state.matchedLocation, '/auth/security');
      expect(_stepCounter(tester), '04 / 05');
      // The step resumed with no page under it, so back still reaches 03.
      await _tapBack(tester);
      expect(router.state.matchedLocation, '/auth/wallet/backup');
    });

    testWidgets('an active account never enters the sequence', (tester) async {
      final store = InMemoryLoopOnboardingProgressStore();
      await store.write(partition, LoopOnboardingStep.security);

      final router = await _pumpLoopApp(
        tester,
        store: store,
        status: ProfileStatus.active,
      );

      expect(router.state.matchedLocation, '/community');
      expect(await store.read(partition), isNull);
    });

    testWidgets('an unreadable profile lands in Community, never in a step', (
      tester,
    ) async {
      final store = InMemoryLoopOnboardingProgressStore();
      final router = await _pumpLoopApp(tester, store: store, profile: null);

      expect(router.state.matchedLocation, '/community');
      expect(await store.read(partition), isNull);
    });
  });

  group('steps 03 and 04 state their unavailable reasons', () {
    testWidgets('03 offers no method it cannot enrol and still lets go on', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId('wallet-recovery'),
      );

      expect(_stepCounter(tester), '03 / 05');
      expect(
        find.byKey(const ValueKey<String>('wallet-recovery-unavailable')),
        findsOneWidget,
      );
      expect(find.text('不可用'), findsNWidgets(3));
      expect(_enabled(tester, 'wallet-recovery-confirm'), isFalse);
      expect(_enabled(tester, 'wallet-recovery-later'), isTrue);
    });

    testWidgets('03 reports what was decided, including nothing at all', (
      tester,
    ) async {
      final decisions = <WalletRecoveryMethod?>[];
      await _pumpPhone(
        tester,
        AccountSurfaceScreen.fromId(
          'wallet-recovery',
          capabilities: const PrivyWalletCapabilities(canUsePasskey: true),
          onRecoveryDecision: decisions.add,
          onNavigate: (_) {},
        ),
      );

      await _tap(tester, const ValueKey<String>('wallet-recovery-later'));
      expect(decisions, <WalletRecoveryMethod?>[null]);

      await _tap(tester, const ValueKey<String>('recovery-passkey'));
      await _tap(tester, const ValueKey<String>('wallet-recovery-confirm'));
      expect(decisions, <WalletRecoveryMethod?>[
        null,
        WalletRecoveryMethod.passkey,
      ]);
    });

    testWidgets('04 says the app lock is not open yet and saves nothing', (
      tester,
    ) async {
      await _pumpPhone(
        tester,
        const AccountSurfaceScreen.fromId('security-setup'),
      );

      expect(_stepCounter(tester), '04 / 05');
      expect(
        find.byKey(const ValueKey<String>('protection-setup-unavailable')),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNothing);
      expect(find.text('已开启'), findsNothing);
      expect(find.text('不可用'), findsNWidgets(4));
      expect(_enabled(tester, 'security-setup-continue'), isTrue);
    });
  });
}

// ---------------------------------------------------------------------------

ProviderContainer _container(LoopOnboardingProgressStore store) {
  final container = ProviderContainer(
    overrides: [loopOnboardingProgressStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

Future<void> _pumpPhone(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MaterialApp(theme: LoopTheme.dark, home: home));
  await tester.pumpAndSettle();
}

/// Mounts the whole application with a signed-in owner.
///
/// [status] is what `GET /v2/profile` answers; `profile: null` is a profile
/// that could not be read at all.
Future<GoRouter> _pumpLoopApp(
  WidgetTester tester, {
  required LoopOnboardingProgressStore store,
  ProfileStatus status = ProfileStatus.pending,
  Object? profile = _unset,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(
          const AuthenticatedTestPrivyGateway(),
        ),
        loopOnboardingProgressStoreProvider.overrideWithValue(store),
        if (!identical(profile, _unset) && profile == null)
          profileGatewayProvider.overrideWithValue(
            const UnavailableProfileGateway(),
          )
        else
          profileGatewayProvider.overrideWithValue(_FakeProfileGateway(status)),
        // The wallet is already in the directory, so step 02 observes it on
        // its first read and leaves no poll running behind the test.
        walletReadGatewayProvider.overrideWithValue(
          _FakeWalletReadGateway(walletFromAttempt: 1),
        ),
      ],
      child: const LoopApp(),
    ),
  );
  await tester.pumpAndSettle();

  return GoRouter.of(tester.element(find.byType(Navigator).first));
}

const Object _unset = Object();

/// Reads the `NN / NN` counter the step page prints in its top right.
String _stepCounter(WidgetTester tester) {
  final progress = tester.widget<IdentityProgress>(
    find.byType(IdentityProgress),
  );
  return '${progress.step.toString().padLeft(2, '0')} / '
      '${progress.total.toString().padLeft(2, '0')}';
}

bool _enabled(WidgetTester tester, String key) {
  final button = tester.widget<LoopButton>(find.byKey(ValueKey<String>(key)));
  return button.onPressed != null;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapBack(WidgetTester tester) async {
  final finder = find.byKey(const ValueKey<String>('loop-topbar-back'));
  expect(finder, findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

final class _FakeProfileGateway implements ProfileGateway {
  const _FakeProfileGateway(this.status);

  final ProfileStatus status;

  @override
  ProfileMode get mode => ProfileMode.production;

  @override
  Future<ProfileResource> load() async {
    final active = status == ProfileStatus.active;
    return ProfileResource(
      version: active ? 1 : 0,
      values: ProfileValues(alias: 'Voyager_7', avatarRef: null),
      updatedAt: active ? DateTime.utc(2026, 9, 20, 6, 32) : null,
      loopId: 'LOOP-7HJKMNPQ',
      profileStatus: status,
      activatedAt: active ? DateTime.utc(2026, 9, 20, 6, 32) : null,
    );
  }

  @override
  Future<ProfileResource> replace({
    required int expectedVersion,
    required ProfileValues values,
  }) => throw UnsupportedError('read-only test gateway');
}

final class _FakeWalletReadGateway implements WalletReadGateway {
  _FakeWalletReadGateway({this.walletFromAttempt, this.failing = false});

  /// The read on which the directory starts reporting an embedded wallet, or
  /// `null` for a directory that never does.
  final int? walletFromAttempt;
  final bool failing;

  int reads = 0;

  @override
  LoopChainGatewayMode get mode => LoopChainGatewayMode.production;

  @override
  Future<LoopWalletDirectory> loadWallets() async {
    reads += 1;
    if (failing) {
      throw const LoopChainException(LoopChainFailureKind.unavailable);
    }
    final from = walletFromAttempt;
    final seen = from != null && reads >= from;
    return LoopWalletDirectory(
      wallets: <LoopWalletAccount>[
        if (seen)
          LoopWalletAccount(
            walletId: 'wal_1',
            address: '0x0000000000000000000000000000000000000001',
            kind: LoopWalletKind.embedded,
            status: LoopWalletStatus.active,
            isActive: true,
            firstSeenAt: DateTime.utc(2026, 9, 20),
            lastSeenAt: DateTime.utc(2026, 9, 20),
          ),
      ],
      activeWalletId: seen ? 'wal_1' : null,
      observedAt: DateTime.utc(2026, 9, 20),
    );
  }

  @override
  Future<LoopWalletDirectory> setActiveWallet({
    required String walletId,
    required String? expectedActiveWalletId,
  }) => throw UnsupportedError('read-only test gateway');

  @override
  Future<LoopWalletBalances> loadBalances(String walletId) =>
      throw UnsupportedError('read-only test gateway');

  @override
  Future<LoopWalletActivityPage> loadActivity(
    String walletId, {
    String? cursor,
  }) => throw UnsupportedError('read-only test gateway');

  @override
  Future<LoopWalletReceive> loadReceive(String walletId) =>
      throw UnsupportedError('read-only test gateway');
}
