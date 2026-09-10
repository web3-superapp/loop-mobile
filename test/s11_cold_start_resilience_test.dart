import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/network/loop_connectivity_signal.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/account/privy_login_screen.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  group('S11 · session restore is a three-state answer', () {
    test(
      'a network failure leaves the session undecided, not signed out',
      () async {
        final gateway = _RestoreGateway(
          failure: const PrivyGatewayException(
            '暂时无法确认登录状态，请检查网络后重试。',
            kind: PrivyFailureKind.network,
          ),
        );
        final container = ProviderContainer(
          overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
        );
        addTearDown(container.dispose);

        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.restoring,
        );
        await Future<void>.delayed(Duration.zero);

        final session = container.read(loopSessionProvider);
        expect(session.mode, LoopSessionMode.restoreUnavailable);
        expect(session.isRestoring, isTrue);
        expect(session.isRestoreUnavailable, isTrue);
        expect(session.canEnterProduct, isFalse);
        expect(session.errorMessage, '暂时无法确认登录状态，请检查网络后重试。');
      },
    );

    test('only an authentication answer signs the owner out', () async {
      final gateway = _RestoreGateway(
        failure: const PrivyGatewayException(
          '登录状态已失效，请重新登录。',
          kind: PrivyFailureKind.authentication,
        ),
      );
      final container = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await Future<void>.delayed(Duration.zero);

      final session = container.read(loopSessionProvider);
      expect(session.mode, LoopSessionMode.signedOut);
      expect(session.isRestoring, isFalse);
      expect(session.errorMessage, '登录状态已失效，请重新登录。');
    });

    test('an unclassified failure is also undecided', () async {
      final gateway = _RestoreGateway(failure: StateError('unclassified'));
      final container = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoreUnavailable,
      );
    });

    test('an unknown-kind gateway failure is also undecided', () async {
      final gateway = _RestoreGateway(
        failure: const PrivyGatewayException('Error in getAuthState: null'),
      );
      final container = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoreUnavailable,
      );
    });

    test('retry re-asks Privy and routes once the answer arrives', () async {
      final gateway = _RestoreGateway(
        failure: const PrivyGatewayException(
          '暂时无法确认登录状态，请检查网络后重试。',
          kind: PrivyFailureKind.network,
        ),
      );
      final container = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await Future<void>.delayed(Duration.zero);
      expect(gateway.restoreCalls, 1);

      gateway.failure = null;
      final retry = container.read(loopSessionProvider.notifier).retryRestore();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await retry;

      expect(gateway.restoreCalls, 2);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.authenticated,
      );
    });

    test(
      'retry is single-flight and only the undecided state may use it',
      () async {
        final gate = Completer<PrivySessionSnapshot>();
        final gateway = _RestoreGateway(pending: gate.future);
        final container = ProviderContainer(
          overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
        );
        addTearDown(container.dispose);
        await Future<void>.delayed(Duration.zero);

        // Restoring, not yet undecided: retry is refused and starts nothing.
        await container.read(loopSessionProvider.notifier).retryRestore();
        expect(gateway.restoreCalls, 1);

        gate.complete(
          const PrivySessionSnapshot(
            PrivySessionKind.authenticated,
            account: PrivyAccountSummary(privyUserId: 'did:privy:s11'),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.authenticated,
        );
        await container.read(loopSessionProvider.notifier).retryRestore();
        expect(gateway.restoreCalls, 1);
      },
    );

    testWidgets(
      'a restore that never answers becomes undecided after 12 seconds',
      (tester) async {
        final gate = Completer<PrivySessionSnapshot>();
        final gateway = _RestoreGateway(pending: gate.future);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
            child: const MaterialApp(home: PrivyLoginScreen()),
          ),
        );
        await tester.pump();
        expect(gateway.restoreCalls, 1);
        expect(
          find.byKey(const ValueKey<String>('privy-restoring-screen')),
          findsOneWidget,
        );

        await tester.pump(
          LoopSessionController.defaultRestoreWindow -
              const Duration(milliseconds: 1),
        );
        expect(
          find.byKey(const ValueKey<String>('privy-restoring-screen')),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 1));
        expect(
          find.byKey(
            const ValueKey<String>('privy-restore-unavailable-screen'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('privy-restore-unavailable-retry')),
          findsOneWidget,
        );
        expect(find.text('欢迎来到 LOOP'), findsNothing);
        expect(
          find.textContaining(loopUndecidedSessionMessage),
          findsOneWidget,
        );

        // The abandoned call is still alive; retry must issue a second one.
        gateway.pending = null;
        await tester.tap(
          find.byKey(const ValueKey<String>('privy-restore-unavailable-retry')),
        );
        await tester.pumpAndSettle();
        expect(gateway.restoreCalls, 2);
        expect(
          find.byKey(
            const ValueKey<String>('privy-restore-unavailable-screen'),
          ),
          findsNothing,
        );

        gate.complete(
          const PrivySessionSnapshot(PrivySessionKind.unauthenticated),
        );
        await tester.pumpAndSettle();
      },
    );

    test(
      'the timeout does not cancel the call, and a late answer lands',
      () async {
        final gate = Completer<PrivySessionSnapshot>();
        final gateway = _RestoreGateway(pending: gate.future);
        final container = ProviderContainer(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(gateway),
            loopSessionRestoreWindowProvider.overrideWithValue(
              const Duration(milliseconds: 10),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.restoring,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        final undecided = container.read(loopSessionProvider);
        expect(undecided.mode, LoopSessionMode.restoreUnavailable);
        expect(undecided.errorMessage, loopUndecidedSessionMessage);
        expect(gateway.restoreCalls, 1);

        gate.complete(
          const PrivySessionSnapshot(
            PrivySessionKind.authenticated,
            account: PrivyAccountSummary(privyUserId: 'did:privy:late'),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        final session = container.read(loopSessionProvider);
        expect(session.mode, LoopSessionMode.authenticated);
        expect(session.account?.privyUserId, 'did:privy:late');
      },
    );

    test('a superseded failure cannot overwrite a newer restore', () async {
      final gate = Completer<PrivySessionSnapshot>();
      final gateway = _RestoreGateway(pending: gate.future);
      final container = ProviderContainer(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(gateway),
          loopSessionRestoreWindowProvider.overrideWithValue(
            const Duration(milliseconds: 10),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoreUnavailable,
      );

      // A second attempt is in flight when the abandoned first one fails.
      final second = Completer<PrivySessionSnapshot>();
      gateway.pending = second.future;
      final retry = container.read(loopSessionProvider.notifier).retryRestore();
      expect(gateway.restoreCalls, 2);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );

      gate.completeError(
        const PrivyGatewayException(
          '登录状态已失效，请重新登录。',
          kind: PrivyFailureKind.authentication,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );

      second.complete(
        const PrivySessionSnapshot(PrivySessionKind.unauthenticated),
      );
      await retry;
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
    });

    test('a notReady event never drops the undecided explanation', () async {
      final controller = StreamController<PrivySessionSnapshot>.broadcast();
      addTearDown(controller.close);
      final gateway = _RestoreGateway(
        failure: const PrivyGatewayException(
          '暂时无法确认登录状态，请检查网络后重试。',
          kind: PrivyFailureKind.network,
        ),
        sessions: controller.stream,
      );
      final container = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoreUnavailable,
      );

      controller.add(const PrivySessionSnapshot(PrivySessionKind.notReady));
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoreUnavailable,
      );

      controller.add(
        const PrivySessionSnapshot(PrivySessionKind.unauthenticated),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
    });
  });

  group('S11b · a premature unauthenticated is not a sign-out', () {
    const unauthenticated = PrivySessionSnapshot(
      PrivySessionKind.unauthenticated,
    );
    const authenticated = PrivySessionSnapshot(
      PrivySessionKind.authenticated,
      account: PrivyAccountSummary(privyUserId: 'did:privy:s11b'),
    );

    testWidgets(
      'the stream saying Unauthenticated then Authenticated never shows the '
      'form',
      (tester) async {
        final sessions = StreamController<PrivySessionSnapshot>.broadcast();
        addTearDown(sessions.close);
        // `getAuthState` is still pending: the only word so far is the
        // stream's, and its first word is the premature one.
        final gateway = _RestoreGateway(
          pending: Completer<PrivySessionSnapshot>().future,
          sessions: sessions.stream,
        );
        final container = ProviderContainer(
          overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: PrivyLoginScreen()),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey<String>('privy-restoring-screen')),
          findsOneWidget,
        );

        sessions.add(unauthenticated);
        await tester.pump();
        _expectNoCredentialForm(tester);
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.restoring,
        );

        await tester.pump(
          LoopSessionController.defaultUnauthenticatedGrace -
              const Duration(milliseconds: 1),
        );
        _expectNoCredentialForm(tester);

        sessions.add(authenticated);
        await tester.pump();
        final session = container.read(loopSessionProvider);
        expect(session.mode, LoopSessionMode.authenticated);
        expect(session.account?.privyUserId, 'did:privy:s11b');
      },
    );

    testWidgets(
      'an Unauthenticated that stands becomes the form after 2500ms',
      (tester) async {
        final gateway = _RestoreGateway(answer: unauthenticated);
        final container = ProviderContainer(
          overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: PrivyLoginScreen()),
          ),
        );
        await tester.pump();
        expect(gateway.restoreCalls, 1);
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.restoring,
        );
        _expectNoCredentialForm(tester);

        await tester.pump(
          LoopSessionController.defaultUnauthenticatedGrace -
              const Duration(milliseconds: 1),
        );
        _expectNoCredentialForm(tester);

        await tester.pump(const Duration(milliseconds: 1));
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.signedOut,
        );
        expect(find.text('欢迎来到 LOOP'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('privy-email-field')),
          findsOneWidget,
        );
      },
    );

    test(
      'a restore answering Unauthenticated still loses to the stream',
      () async {
        final sessions = StreamController<PrivySessionSnapshot>.broadcast();
        addTearDown(sessions.close);
        final gateway = _RestoreGateway(
          answer: unauthenticated,
          sessions: sessions.stream,
        );
        final container = ProviderContainer(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(gateway),
            loopSessionUnauthenticatedGraceProvider.overrideWithValue(
              const Duration(milliseconds: 500),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(loopSessionProvider);
        await pumpEventQueue();
        expect(gateway.restoreCalls, 1);
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.restoring,
        );

        sessions.add(authenticated);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.authenticated,
        );

        // The cancelled grace cannot fire behind the session it lost to.
        await Future<void>.delayed(const Duration(milliseconds: 600));
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.authenticated,
        );
      },
    );

    test(
      'a credential revoked after login signs the owner out at once',
      () async {
        final sessions = StreamController<PrivySessionSnapshot>.broadcast();
        addTearDown(sessions.close);
        final gateway = _RestoreGateway(sessions: sessions.stream);
        final container = ProviderContainer(
          overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
        );
        addTearDown(container.dispose);

        container.read(loopSessionProvider);
        await pumpEventQueue();
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.authenticated,
        );

        sessions.add(unauthenticated);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.signedOut,
        );
      },
    );

    test(
      'a sign-out the owner asked for does not wait for the grace',
      () async {
        final gateway = _RestoreGateway(answer: unauthenticated);
        final container = ProviderContainer(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(gateway),
            loopSessionUnauthenticatedGraceProvider.overrideWithValue(
              const Duration(milliseconds: 500),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(loopSessionProvider);
        await pumpEventQueue();
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.restoring,
        );

        await container.read(loopSessionProvider.notifier).exit();
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.signedOut,
        );

        await Future<void>.delayed(const Duration(milliseconds: 600));
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.signedOut,
        );
      },
    );

    testWidgets('the grace timer never outlives the wait it measures', (
      tester,
    ) async {
      final sessions = StreamController<PrivySessionSnapshot>.broadcast();
      addTearDown(sessions.close);
      final gateway = _RestoreGateway(
        answer: unauthenticated,
        sessions: sessions.stream,
      );
      final container = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PrivyLoginScreen()),
        ),
      );
      await tester.pump();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );

      sessions.add(authenticated);
      await tester.pump();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.authenticated,
      );

      // The test ends well inside the 2500ms window and inside the 12s restore
      // deadline. A surviving timer of either kind fails this test.
    });
  });

  group('S11 · privy_flutter 0.10.1 failure mapping', () {
    test('transport messages map to network', () {
      for (final message in const <String>[
        'Error in getAuthState: The Internet connection appears to be offline.',
        'Error in getAuthState: Software caused connection abort',
        'The request timed out.',
        'Unable to resolve hostname api.privy.io',
        'SSL handshake failed',
        'The service is temporarily unavailable',
      ]) {
        expect(
          PrivyFailureClassifier.of(message),
          PrivyFailureKind.network,
          reason: message,
        );
      }
    });

    test('credential messages map to authentication', () {
      for (final message in const <String>[
        'User is unauthenticated',
        'No authenticated user',
        'Session expired, please log in again',
        'invalid token',
        'HTTP 401',
      ]) {
        expect(
          PrivyFailureClassifier.of(message),
          PrivyFailureKind.authentication,
          reason: message,
        );
      }
    });

    test('everything else stays unknown and is never read as a sign-out', () {
      expect(
        PrivyFailureClassifier.of(
          'Error in getAuthState: Auth state data is null',
        ),
        PrivyFailureKind.unknown,
      );
      expect(
        PrivyFailureClassifier.of('Unknown AuthState type: something'),
        PrivyFailureKind.unknown,
      );
    });

    test('credential markers only match on word boundaries', () {
      for (final message in const <String>[
        'Error in getAuthState: request 14013 failed',
        'Error in getAuthState: request 4030 failed',
        'no users found for this query',
        'code 1401',
      ]) {
        expect(
          PrivyFailureClassifier.of(message),
          PrivyFailureKind.unknown,
          reason: message,
        );
      }
    });

    test('a transport word wins over a credential word', () {
      expect(
        PrivyFailureClassifier.of(
          'network error while refreshing invalid token',
        ),
        PrivyFailureKind.network,
      );
    });
  });

  group('S11 · the undecided state never shows the credential form', () {
    testWidgets('the branded frame explains and offers a retry', (
      tester,
    ) async {
      final gateway = _RestoreGateway(
        failure: const PrivyGatewayException(
          '暂时无法确认登录状态，请检查网络后重试。',
          kind: PrivyFailureKind.network,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
          child: const MaterialApp(home: PrivyLoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('privy-restore-unavailable-screen')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('privy-restore-unavailable-notice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('privy-restore-unavailable-retry')),
        findsOneWidget,
      );
      expect(find.text('欢迎来到 LOOP'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('privy-email-field')),
        findsNothing,
      );
      expect(find.textContaining('暂时无法确认登录状态，请检查网络后重试。'), findsOneWidget);

      gateway.failure = null;
      await tester.tap(
        find.byKey(const ValueKey<String>('privy-restore-unavailable-retry')),
      );
      await tester.pumpAndSettle();

      expect(gateway.restoreCalls, 2);
      expect(
        find.byKey(const ValueKey<String>('privy-restore-unavailable-screen')),
        findsNothing,
      );
    });

    testWidgets('an authentication answer does show the form', (tester) async {
      final gateway = _RestoreGateway(
        failure: const PrivyGatewayException(
          '登录状态已失效，请重新登录。',
          kind: PrivyFailureKind.authentication,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
          child: const MaterialApp(home: PrivyLoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('欢迎来到 LOOP'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('privy-email-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('privy-restore-unavailable-screen')),
        findsNothing,
      );
    });
  });

  group('S11 · the D0 observation recovers without a restart', () {
    testWidgets('a failed read retries five times at 1s→2s→4s→8s→16s', (
      tester,
    ) async {
      final repository = _FlakyRepository()..fail = true;
      final container = _container(repository);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );
      final observer = container.read(loopV2MetaObserverProvider);
      await tester.pump();
      expect(repository.reads, 1);

      var expected = 1;
      for (final delay in LoopV2MetaObserver.retryBackoff) {
        await tester.pump(delay - const Duration(milliseconds: 1));
        expect(repository.reads, expected);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expected += 1;
        expect(repository.reads, expected);
      }

      expect(repository.reads, 6);
      expect(observer.consecutiveFailures, LoopV2MetaObserver.maxRetries);
      expect(observer.isExhausted, isTrue);

      // The ladder is spent: no further timer may fire.
      await tester.pump(const Duration(minutes: 5));
      expect(repository.reads, 6);
      expect(
        container
            .read(loopCapabilityProvider(LoopV2CapabilityId.community))
            .decision,
        LoopCapabilityDecision.unknown,
      );
    });

    testWidgets('a retry that succeeds opens the module gates and stops', (
      tester,
    ) async {
      final repository = _FlakyRepository()..fail = true;
      final container = _container(repository);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );
      final observer = container.read(loopV2MetaObserverProvider);
      await tester.pump();
      expect(repository.reads, 1);
      expect(
        container
            .read(loopCapabilityProvider(LoopV2CapabilityId.community))
            .decision,
        LoopCapabilityDecision.unknown,
      );

      repository.fail = false;
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(repository.reads, 2);
      expect(observer.consecutiveFailures, 0);
      expect(observer.isRetryScheduled, isFalse);
      expect(
        container
            .read(loopCapabilityProvider(LoopV2CapabilityId.community))
            .decision,
        LoopCapabilityDecision.available,
      );

      await tester.pump(const Duration(minutes: 5));
      expect(repository.reads, 2);
    });

    testWidgets('a completed observation is never re-read', (tester) async {
      final repository = _FlakyRepository();
      final container = _container(repository);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );
      final observer = container.read(loopV2MetaObserverProvider);
      await tester.pump();
      expect(repository.reads, 1);

      for (final trigger in LoopV2MetaObservationTrigger.values) {
        observer.observe(trigger);
      }
      await tester.pump();
      expect(repository.reads, 1);
    });

    testWidgets('triggers are single-flight while a read is in flight', (
      tester,
    ) async {
      final repository = _FlakyRepository()..hold = Completer<void>();
      final container = _container(repository);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SizedBox.shrink(),
        ),
      );
      final observer = container.read(loopV2MetaObserverProvider);
      await tester.pump();
      expect(repository.reads, 1);
      expect(observer.isObserving, isTrue);

      observer.observe(LoopV2MetaObservationTrigger.connectivityRestored);
      observer.observe(LoopV2MetaObservationTrigger.appResumed);
      observer.observe(LoopV2MetaObservationTrigger.navigation);
      await tester.pump();
      expect(repository.reads, 1);

      repository.hold!.complete();
      repository.hold = null;
      await tester.pump();
      expect(repository.reads, 1);
    });

    testWidgets('a trigger during the backoff wait does not add a request', (
      tester,
    ) async {
      final repository = _FlakyRepository()..fail = true;
      final container = _container(repository);
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

      observer.observe(LoopV2MetaObservationTrigger.connectivityRestored);
      await tester.pump();
      expect(repository.reads, 1);

      // Leave no timer behind: spend the rest of the ladder.
      await _drainLadder(tester);
      expect(observer.isExhausted, isTrue);
    });
  });

  group('S11 · LoopApp re-arms the observation', () {
    testWidgets('the radio coming back starts one new ladder', (tester) async {
      final repository = _FlakyRepository()..fail = true;
      final signal = _TestConnectivitySignal();
      addTearDown(signal.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_config),
            loopV2MetaRepositoryProvider.overrideWithValue(repository),
            loopConnectivitySignalProvider.overrideWithValue(signal),
            privyAuthGatewayProvider.overrideWithValue(
              _RestoreGateway(
                failure: const PrivyGatewayException(
                  '暂时无法确认登录状态，请检查网络后重试。',
                  kind: PrivyFailureKind.network,
                ),
              ),
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pump();
      await _drainLadder(tester);
      final exhausted = repository.reads;
      expect(exhausted, 6);

      repository.fail = false;
      signal.restore();
      await tester.pump();
      await tester.pump();

      expect(repository.reads, exhausted + 1);
      await tester.pumpAndSettle();
    });

    testWidgets('returning to the foreground starts one new ladder', (
      tester,
    ) async {
      final repository = _FlakyRepository()..fail = true;
      final signal = _TestConnectivitySignal();
      addTearDown(signal.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_config),
            loopV2MetaRepositoryProvider.overrideWithValue(repository),
            loopConnectivitySignalProvider.overrideWithValue(signal),
            privyAuthGatewayProvider.overrideWithValue(
              _RestoreGateway(
                failure: const PrivyGatewayException(
                  '暂时无法确认登录状态，请检查网络后重试。',
                  kind: PrivyFailureKind.network,
                ),
              ),
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pump();
      await _drainLadder(tester);
      expect(repository.reads, 6);

      repository.fail = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(repository.reads, 7);
      await tester.pumpAndSettle();
    });

    testWidgets('opening a page while the document is missing re-arms it', (
      tester,
    ) async {
      final repository = _FlakyRepository()..fail = true;
      final signal = _TestConnectivitySignal();
      addTearDown(signal.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(_config),
            loopV2MetaRepositoryProvider.overrideWithValue(repository),
            loopConnectivitySignalProvider.overrideWithValue(signal),
            privyAuthGatewayProvider.overrideWithValue(
              _RestoreGateway(
                failure: const PrivyGatewayException(
                  '暂时无法确认登录状态，请检查网络后重试。',
                  kind: PrivyFailureKind.network,
                ),
              ),
            ),
          ],
          child: const LoopApp(),
        ),
      );
      await tester.pump();
      await _drainLadder(tester);
      expect(repository.reads, 6);

      repository.fail = false;
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      router.go('/market');
      await tester.pump();
      await tester.pump();

      expect(repository.reads, 7);
      await tester.pumpAndSettle();
    });
  });
}

void _expectNoCredentialForm(WidgetTester tester) {
  expect(
    find.byKey(const ValueKey<String>('privy-restoring-screen')),
    findsOneWidget,
  );
  expect(find.text('欢迎来到 LOOP'), findsNothing);
  expect(find.byKey(const ValueKey<String>('privy-email-field')), findsNothing);
}

const _config = AppConfig(
  privyAppId: '',
  privyAppClientId: '',
  streamApiKey: '',
  backendBaseUrl: 'https://api.example.test',
  firebaseConfigured: false,
);

ProviderContainer _container(_FlakyRepository repository) {
  final container = ProviderContainer(
    overrides: [loopV2MetaRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _drainLadder(WidgetTester tester) async {
  for (final delay in LoopV2MetaObserver.retryBackoff) {
    await tester.pump(delay);
    await tester.pump();
  }
}

final class _RestoreGateway implements PrivyAuthGateway {
  _RestoreGateway({
    this.failure,
    this.pending,
    this.answer = const PrivySessionSnapshot(
      PrivySessionKind.authenticated,
      account: PrivyAccountSummary(privyUserId: 'did:privy:s11'),
    ),
    Stream<PrivySessionSnapshot>? sessions,
  }) : _sessions = sessions ?? const Stream<PrivySessionSnapshot>.empty();

  Object? failure;
  Future<PrivySessionSnapshot>? pending;

  /// What `getAuthState` answers once it answers at all.
  PrivySessionSnapshot answer;
  final Stream<PrivySessionSnapshot> _sessions;
  var restoreCalls = 0;

  @override
  Future<PrivySessionSnapshot> restoreSession() {
    restoreCalls += 1;
    final held = pending;
    if (held != null) return held;
    final error = failure;
    if (error != null) return Future<PrivySessionSnapshot>.error(error);
    return Future<PrivySessionSnapshot>.value(answer);
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() => _sessions;

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

final class _TestConnectivitySignal implements LoopConnectivitySignal {
  final _controller = StreamController<void>.broadcast();

  void restore() => _controller.add(null);

  void dispose() => unawaited(_controller.close());

  @override
  Stream<void> get onRestored => _controller.stream;
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
