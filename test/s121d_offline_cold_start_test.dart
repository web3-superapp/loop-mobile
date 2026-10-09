import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/network/loop_connectivity_signal.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/features/account/privy_login_screen.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/loop_ground_probe.dart';

const _grace = Duration(milliseconds: 40);
const _account = PrivyAccountSummary(privyUserId: 'did:privy:cy');
const _unauthenticated = PrivySessionSnapshot(PrivySessionKind.unauthenticated);
const _authenticated = PrivySessionSnapshot(
  PrivySessionKind.authenticated,
  account: _account,
);

/// Decision 0124: a cold start that hears `Unauthenticated` while the device
/// reports no transport waits for the network instead of showing the form.
void main() {
  loopWatchGround();

  group('offline cold start', () {
    test('Unauthenticated waits for the network and never signs out', () async {
      final radio = _Radio(false);
      final privy = _Privy()..restoreAnswer = _unauthenticated;
      final container = _container(privy, radio);

      await _settleGrace();
      final session = container.read(loopSessionProvider);
      expect(session.mode, LoopSessionMode.awaitingNetwork);
      expect(session.isAwaitingNetwork, isTrue);
      expect(session.isRestoring, isTrue);
      expect(session.canEnterProduct, isFalse);
      expect(session.canUseProviderBackedFeatures, isFalse);

      // A further `Unauthenticated` from the stream changes nothing.
      privy.emit(_unauthenticated);
      await pumpEventQueue();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.awaitingNetwork,
      );

      // A recovery tick while the radio still reports nothing asks nobody.
      final calls = privy.restoreCalls;
      await container.read(loopSessionProvider.notifier).recheckAfterNetwork();
      expect(privy.restoreCalls, calls);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.awaitingNetwork,
      );
    });

    test('an authentication failure heard offline also waits', () async {
      final radio = _Radio(false);
      final privy = _Privy()
        ..restoreFailure = const PrivyGatewayException(
          '登录状态已失效，请重新登录。',
          kind: PrivyFailureKind.authentication,
        );
      final container = _container(privy, radio);

      await _settleGrace();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.awaitingNetwork,
      );
    });

    test('network back and Privy confirms: enters the product', () async {
      final radio = _Radio(false);
      final privy = _Privy()..restoreAnswer = _unauthenticated;
      final container = _container(privy, radio);
      await _settleGrace();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.awaitingNetwork,
      );

      radio.value = true;
      privy.restoreAnswer = _authenticated;
      await container.read(loopSessionProvider.notifier).recheckAfterNetwork();

      final session = container.read(loopSessionProvider);
      expect(session.mode, LoopSessionMode.authenticated);
      expect(session.account?.privyUserId, 'did:privy:cy');
      expect(session.canEnterProduct, isTrue);
    });

    test('network back and Privy says unauthenticated: the form', () async {
      final radio = _Radio(false);
      final privy = _Privy()..restoreAnswer = _unauthenticated;
      final container = _container(privy, radio);
      await _settleGrace();

      radio.value = true;
      final calls = privy.restoreCalls;
      await container.read(loopSessionProvider.notifier).recheckAfterNetwork();
      // The first answer after the network returns may still be the one
      // Privy formed offline: it is held once, then asked again.
      expect(privy.restoreCalls, calls + 1);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.awaitingNetwork,
      );
      // Another recovery tick inside the window does not cut it short.
      await container.read(loopSessionProvider.notifier).recheckAfterNetwork();
      expect(privy.restoreCalls, calls + 1);

      await _settleGrace();
      expect(privy.restoreCalls, calls + 2);
      final session = container.read(loopSessionProvider);
      expect(session.mode, LoopSessionMode.signedOut);
      expect(session.isRestoring, isFalse);
    });

    test('Privy confirming during the held window wins', () async {
      final radio = _Radio(false);
      final privy = _Privy()..restoreAnswer = _unauthenticated;
      final container = _container(privy, radio);
      await _settleGrace();

      radio.value = true;
      await container.read(loopSessionProvider.notifier).recheckAfterNetwork();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.awaitingNetwork,
      );
      privy.emit(_authenticated);
      await pumpEventQueue();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.authenticated,
      );

      // The cancelled window cannot fire behind the session it lost to.
      final calls = privy.restoreCalls;
      await _settleGrace();
      expect(privy.restoreCalls, calls);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.authenticated,
      );
    });

    test('a network failure on the recheck keeps waiting', () async {
      final radio = _Radio(false);
      final privy = _Privy()..restoreAnswer = _unauthenticated;
      final container = _container(privy, radio);
      await _settleGrace();

      radio.value = true;
      privy.restoreFailure = const PrivyGatewayException(
        'network unreachable',
        kind: PrivyFailureKind.network,
      );
      await container.read(loopSessionProvider.notifier).recheckAfterNetwork();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.awaitingNetwork,
      );
    });

    test('the owner may leave the wait for the form', () async {
      final radio = _Radio(false);
      final privy = _Privy()..restoreAnswer = _unauthenticated;
      final container = _container(privy, radio);
      await _settleGrace();

      container.read(loopSessionProvider.notifier).useAnotherAccount();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
    });
  });

  group('unchanged behaviour', () {
    test('online cold start Unauthenticated reaches the form', () async {
      final radio = _Radio(true);
      final privy = _Privy()..restoreAnswer = _unauthenticated;
      final container = _container(privy, radio);

      await pumpEventQueue();
      // Decision 0064 §5 still holds the first answer.
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await _settleGrace();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
    });

    test('an unreadable radio changes nothing', () async {
      final radio = _Radio(null);
      final privy = _Privy()..restoreAnswer = _unauthenticated;
      final container = _container(privy, radio);

      await _settleGrace();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
    });

    test('a signed-in session still signs out at once offline', () async {
      final radio = _Radio(false);
      final privy = _Privy()..restoreAnswer = _authenticated;
      final container = _container(privy, radio);
      await pumpEventQueue();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.authenticated,
      );

      privy.emit(_unauthenticated);
      await pumpEventQueue();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
    });

    test('the undecided frame is still never retried on its own', () async {
      final radio = _Radio(true);
      final privy = _Privy()
        ..restoreFailure = const PrivyGatewayException(
          'network unreachable',
          kind: PrivyFailureKind.network,
        );
      final container = _container(privy, radio);
      await pumpEventQueue();
      expect(container.read(loopSessionProvider).isRestoreUnavailable, isTrue);

      final calls = privy.restoreCalls;
      privy
        ..restoreFailure = null
        ..restoreAnswer = _unauthenticated;
      await container.read(loopSessionProvider.notifier).recheckAfterNetwork();
      expect(privy.restoreCalls, calls);
      expect(container.read(loopSessionProvider).isRestoreUnavailable, isTrue);
    });
  });

  group('waiting frame', () {
    testWidgets('says what it waits for and offers another account', (
      tester,
    ) async {
      final radio = _Radio(false);
      final privy = _Privy()..restoreAnswer = _unauthenticated;
      addTearDown(privy.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig(
                privyAppId: 'privy-app',
                privyAppClientId: 'privy-client',
                reownProjectId: '26a5cc1adad234fcdf7762b8d2a2b28d',
                streamApiKey: '',
                backendBaseUrl: '',
                firebaseConfigured: false,
              ),
            ),
            privyAuthGatewayProvider.overrideWithValue(privy),
            loopDeviceTransportProvider.overrideWithValue(radio),
            loopSessionUnauthenticatedGraceProvider.overrideWithValue(_grace),
            isIosIdentityPlatformProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: LoopTheme.dark,
            home: const PrivyLoginScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('privy-restoring-screen')),
        findsOneWidget,
      );
      await tester.pump(_grace * 2);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('privy-awaiting-network-screen')),
        findsOneWidget,
      );
      expect(
        find.text(PrivySessionAwaitingNetworkScreen.title),
        findsOneWidget,
      );
      expect(
        find.text(PrivySessionAwaitingNetworkScreen.message),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('privy-auth-screen')), findsNothing);
      final another = find.byKey(
        const ValueKey('privy-awaiting-network-another-account'),
      );
      expect(another, findsOneWidget);
      expect(tester.getSize(another).height, greaterThanOrEqualTo(44));

      await tester.tap(another);
      await tester.pump();
      expect(find.byKey(const ValueKey('privy-auth-screen')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('privy-awaiting-network-screen')),
        findsNothing,
      );
      // Replace the indeterminate bar before the test ends.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

ProviderContainer _container(_Privy privy, _Radio radio) {
  final container = ProviderContainer(
    overrides: [
      privyAuthGatewayProvider.overrideWithValue(privy),
      loopDeviceTransportProvider.overrideWithValue(radio),
      loopSessionUnauthenticatedGraceProvider.overrideWithValue(_grace),
      loopSessionRestoreWindowProvider.overrideWithValue(
        const Duration(hours: 1),
      ),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(privy.dispose);
  final subscription = container.listen(loopSessionProvider, (_, _) {});
  addTearDown(subscription.close);
  return container;
}

Future<void> _settleGrace() async {
  await Future<void>.delayed(_grace * 3);
  await pumpEventQueue();
}

final class _Radio implements LoopDeviceTransport {
  _Radio(this.value);

  bool? value;

  @override
  Future<bool?> hasTransport() async => value;
}

final class _Privy implements PrivyAuthGateway {
  final _snapshots = StreamController<PrivySessionSnapshot>.broadcast();

  PrivySessionSnapshot restoreAnswer = _authenticated;
  Object? restoreFailure;
  int restoreCalls = 0;

  void emit(PrivySessionSnapshot snapshot) => _snapshots.add(snapshot);

  Future<void> dispose() async {
    if (!_snapshots.isClosed) await _snapshots.close();
  }

  @override
  Future<PrivySessionSnapshot> restoreSession() async {
    restoreCalls += 1;
    final failure = restoreFailure;
    if (failure != null) throw failure;
    return restoreAnswer;
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() => _snapshots.stream;

  @override
  Future<void> logout() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
