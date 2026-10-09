import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/network/loop_connectivity_signal.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/chain/chain_controllers.dart';
import 'package:loop_mobile/features/wallet/wallet_screens.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

import 'support/s5_page_harness.dart';

/// Decision 0123: a network failure never turns a signed-in session into
/// 「不可用」. It is 离线, and the session recovers on its own when the network
/// comes back.
void main() {
  const identity = LoopBootstrapIdentity(
    loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
    streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
  );

  group('bootstrap read times out, then the network returns', () {
    test(
      'the session stays and its request says offline, then succeeds',
      () async {
        var online = false;
        final bootstrap = LoopBootstrapSession(
          principalKey: 'did:privy:cy',
          accessTokens: _Tokens(),
          repository: _Repository((_) async {
            if (!online) {
              throw const LoopBackendFailure(LoopBackendFailureKind.timeout);
            }
            return identity;
          }),
        );
        final session = LoopAuthenticatedSession(
          principalKey: 'did:privy:cy',
          bootstrapSession: bootstrap,
          accessTokens: _Tokens(),
        );
        addTearDown(session.dispose);
        addTearDown(bootstrap.dispose);

        // Offline: the bootstrap read timed out. The request reports the
        // timeout itself — not 「不可用」 — and nothing was torn down.
        await expectLater(
          session.execute((token) async => 'wallets'),
          throwsA(
            isA<LoopBackendFailure>().having(
              (failure) => failure.kind,
              'kind',
              LoopBackendFailureKind.timeout,
            ),
          ),
        );
        expect(
          bootstrap.lastTransportFailure?.kind,
          LoopBackendFailureKind.timeout,
        );
        expect(bootstrap.identity, isNull);

        // The network comes back: the same session object authorizes again.
        online = true;
        expect(
          await bootstrap.authorize(),
          LoopBootstrapAuthorization.authorized,
        );
        expect(bootstrap.lastTransportFailure, isNull);
        expect(await session.execute((token) async => 'wallets'), 'wallets');
      },
    );

    test('a refused bootstrap is still 不可用, never offline', () async {
      final bootstrap = LoopBootstrapSession(
        principalKey: 'did:privy:cy',
        accessTokens: _Tokens(),
        repository: _Repository((_) async {
          throw const LoopBackendFailure(
            LoopBackendFailureKind.unavailable,
            statusCode: 503,
          );
        }),
      );
      addTearDown(bootstrap.dispose);

      expect(
        await bootstrap.authorize(),
        LoopBootstrapAuthorization.unavailable,
      );
      expect(bootstrap.lastTransportFailure, isNull);
    });

    test('a block that failed offline re-reads on the recovery tick', () async {
      final answers = <Object>[
        const LoopChainException(LoopChainFailureKind.offline),
        const LoopChainException(LoopChainFailureKind.offline),
        42,
      ];
      final container = ProviderContainer(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(_Privy()),
          _answersProvider.overrideWithValue(answers),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(_probeProvider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(_probeProvider.notifier).reload();
      expect(container.read(_probeProvider).phase, LoopChainViewPhase.offline);

      container.read(loopNetworkRecoveryTickProvider.notifier).bump();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final state = container.read(_probeProvider);
      expect(state.phase, LoopChainViewPhase.ready);
      expect(state.value, 42);

      // A block that has its answer ignores the next tick.
      container.read(loopNetworkRecoveryTickProvider.notifier).bump();
      await Future<void>.delayed(Duration.zero);
      expect(answers, isEmpty);
      expect(container.read(_probeProvider).value, 42);
    });
  });

  group('Privy restored the session with no network', () {
    test('the absent adapter reads as offline, not 不可用', () async {
      final container = ProviderContainer(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(_Privy()),
          _answersProvider.overrideWithValue(<Object>[]),
          _modeProvider.overrideWithValue(LoopChainGatewayMode.unavailable),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(_probeProvider, (_, _) {});
      addTearDown(subscription.close);

      expect(
        container.read(_probeProvider).phase,
        LoopChainViewPhase.unavailable,
      );
      container.read(loopSessionAwaitingNetworkProvider.notifier).set(true);
      expect(container.read(_probeProvider).phase, LoopChainViewPhase.offline);
      expect(
        container.read(_probeProvider).failureKind,
        LoopChainFailureKind.offline,
      );
    });

    test(
      'the recheck takes Privy\'s confirmation and never signs out',
      () async {
        final privy = _Privy()
          ..restoreAnswer = const PrivySessionSnapshot(
            PrivySessionKind.authenticatedUnverified,
          );
        final container = ProviderContainer(
          overrides: [privyAuthGatewayProvider.overrideWithValue(privy)],
        );
        addTearDown(container.dispose);
        addTearDown(privy.dispose);
        final subscription = container.listen(loopSessionProvider, (_, _) {});
        addTearDown(subscription.close);
        await Future<void>.delayed(Duration.zero);
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.authenticatedUnverified,
        );

        // Still offline: Privy has no newer answer, nothing moves.
        privy.restoreAnswer = const PrivySessionSnapshot(
          PrivySessionKind.unauthenticated,
        );
        await container
            .read(loopSessionProvider.notifier)
            .recheckAfterNetwork();
        expect(
          container.read(loopSessionProvider).mode,
          LoopSessionMode.authenticatedUnverified,
        );

        // The network is back and Privy confirmed the stored session.
        privy.restoreAnswer = const PrivySessionSnapshot(
          PrivySessionKind.authenticated,
          account: PrivyAccountSummary(privyUserId: 'did:privy:cy'),
        );
        await container
            .read(loopSessionProvider.notifier)
            .recheckAfterNetwork();
        final session = container.read(loopSessionProvider);
        expect(session.mode, LoopSessionMode.authenticated);
        expect(session.account?.privyUserId, 'did:privy:cy');
        expect(session.canUseProviderBackedFeatures, isTrue);
      },
    );

    test('an undecided restore is never retried on its own', () async {
      final privy = _Privy()..restoreError = true;
      final container = ProviderContainer(
        overrides: [
          privyAuthGatewayProvider.overrideWithValue(privy),
          loopSessionRestoreWindowProvider.overrideWithValue(
            const Duration(hours: 1),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(privy.dispose);
      final subscription = container.listen(loopSessionProvider, (_, _) {});
      addTearDown(subscription.close);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(loopSessionProvider).isRestoreUnavailable, isTrue);
      final calls = privy.restoreCalls;

      // The network came back: the undecided state keeps its own 重试 and is
      // not re-asked here (an automatic retry spends the cold-start grace).
      privy
        ..restoreError = false
        ..restoreAnswer = const PrivySessionSnapshot(
          PrivySessionKind.unauthenticated,
        );
      await container.read(loopSessionProvider.notifier).recheckAfterNetwork();
      expect(privy.restoreCalls, calls);
      expect(container.read(loopSessionProvider).isRestoreUnavailable, isTrue);
    });

    testWidgets('the wallet page says offline while it waits', (tester) async {
      await pumpS5Page(
        tester,
        const WalletScreen(),
        wallet: const UnavailableWalletReadGateway(),
        overrides: <Override>[
          loopSessionAwaitingNetworkProvider.overrideWith(_AwaitingNetwork.new),
        ],
      );

      expect(find.textContaining('该内容当前不可用'), findsNothing);
      expect(find.text('暂不可用'), findsNothing);
      expect(find.text('离线'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.endsWith(
                '-state-offline',
              ),
        ),
        findsOneWidget,
      );
    });
  });
}

final _answersProvider = Provider<List<Object>>((ref) => <Object>[]);
final _modeProvider = Provider<LoopChainGatewayMode>(
  (ref) => LoopChainGatewayMode.production,
);

final class _Probe extends LoopChainReadController<int> {
  @override
  LoopChainGatewayMode watchMode() => ref.watch(_modeProvider);

  @override
  bool get retainsAnswer => false;

  @override
  Future<int> fetch() async {
    final next = ref.read(_answersProvider).removeAt(0);
    if (next is int) return next;
    throw next;
  }
}

final _probeProvider = NotifierProvider<_Probe, LoopChainResourceState<int>>(
  _Probe.new,
);

class _AwaitingNetwork extends LoopSessionAwaitingNetwork {
  @override
  bool build() => true;
}

final class _Tokens implements LoopBackendAccessTokenSource {
  @override
  Future<String> loadAccessToken() async => 'token';
}

final class _Repository implements LoopBootstrapRepository {
  _Repository(this._handler);

  final Future<LoopBootstrapIdentity> Function(String token) _handler;

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) =>
      _handler(accessToken);
}

final class _Privy implements PrivyAuthGateway {
  final _snapshots = StreamController<PrivySessionSnapshot>.broadcast();

  PrivySessionSnapshot restoreAnswer = const PrivySessionSnapshot(
    PrivySessionKind.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:cy'),
  );

  Future<void> dispose() => _snapshots.close();

  bool restoreError = false;
  int restoreCalls = 0;

  @override
  Future<PrivySessionSnapshot> restoreSession() async {
    restoreCalls += 1;
    if (restoreError) {
      throw const PrivyGatewayException(
        '暂时无法确认登录状态，请检查网络后重试。',
        kind: PrivyFailureKind.network,
      );
    }
    return restoreAnswer;
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() => _snapshots.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
