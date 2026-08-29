import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/app/session/post_auth_bootstrap_coordinator.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  const signedOut = LoopSessionState.signedOut();
  const first = LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:first'),
  );
  const firstLinked = LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(
      privyUserId: 'did:privy:first',
      externalEvmCredentials: <PrivyExternalEvmCredentialSummary>[
        PrivyExternalEvmCredentialSummary(
          address: '0x1111111111111111111111111111111111111111',
          chainId: '1',
        ),
      ],
    ),
  );
  const second = LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:second'),
  );

  test(
    'requests once per login principal but not for a credential link',
    () async {
      var calls = 0;
      final coordinator = PostAuthBootstrapCoordinator(() async {
        calls += 1;
      });

      coordinator.onSessionChanged(signedOut, first);
      coordinator.onSessionChanged(first, firstLinked);
      coordinator.onSessionChanged(firstLinked, firstLinked);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);

      coordinator.onSessionChanged(firstLinked, second);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
    },
  );

  test(
    'logout permits a later login by the same principal to bootstrap',
    () async {
      var calls = 0;
      final coordinator = PostAuthBootstrapCoordinator(() async {
        calls += 1;
      });

      coordinator.onSessionChanged(signedOut, first);
      coordinator.onSessionChanged(first, signedOut);
      coordinator.onSessionChanged(signedOut, first);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 2);
    },
  );

  test('restricted and preview sessions never request bootstrap', () async {
    var calls = 0;
    final coordinator = PostAuthBootstrapCoordinator(() async {
      calls += 1;
    });
    const unverified = LoopSessionState(
      mode: LoopSessionMode.authenticatedUnverified,
    );
    const preview = LoopSessionState.preview();

    coordinator.onSessionChanged(signedOut, unverified);
    coordinator.onSessionChanged(unverified, preview);
    await Future<void>.delayed(Duration.zero);

    expect(calls, 0);
  });

  test(
    'temporary restoring or unverified state does not duplicate bootstrap',
    () async {
      var calls = 0;
      final coordinator = PostAuthBootstrapCoordinator(() async {
        calls += 1;
      });
      const unverified = LoopSessionState(
        mode: LoopSessionMode.authenticatedUnverified,
      );
      const restoring = LoopSessionState.restoring();

      coordinator.onSessionChanged(signedOut, first);
      coordinator.onSessionChanged(first, unverified);
      coordinator.onSessionChanged(unverified, restoring);
      coordinator.onSessionChanged(restoring, first);
      await Future<void>.delayed(Duration.zero);

      expect(calls, 1);
    },
  );
}
