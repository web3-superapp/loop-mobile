import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  late _LogoutGateway gateway;
  late ProviderContainer container;

  setUp(() async {
    gateway = _LogoutGateway();
    container = ProviderContainer(
      overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);
    addTearDown(gateway.dispose);

    expect(container.read(loopSessionProvider).mode, LoopSessionMode.restoring);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(loopSessionProvider).mode,
      LoopSessionMode.authenticated,
    );
  });

  test(
    'sign-out revokes the provider principal before Privy completes',
    () async {
      final logoutGate = Completer<void>();
      gateway.logoutOperation = logoutGate.future;

      expect(
        container.read(loopBootstrapPrincipalKeyProvider),
        'did:privy:old',
      );

      final exit = container.read(loopSessionProvider.notifier).exit();

      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
      expect(container.read(loopBootstrapPrincipalKeyProvider), isNull);
      expect(gateway.logoutCalls, 1);

      gateway.emitAuthenticated('did:privy:stale');
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
      expect(container.read(loopBootstrapPrincipalKeyProvider), isNull);

      logoutGate.complete();
      await exit;
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
    },
  );

  test('a failed remote logout cannot restore local provider access', () async {
    gateway.logoutOperation = Future<void>.error(
      const PrivyGatewayException('退出登录失败，请稍后重试。'),
    );

    await container.read(loopSessionProvider.notifier).exit();

    final session = container.read(loopSessionProvider);
    expect(session.mode, LoopSessionMode.signedOut);
    expect(session.errorMessage, '退出登录失败，请稍后重试。');
    expect(container.read(loopBootstrapPrincipalKeyProvider), isNull);
  });

  test('late wallet creation cannot attach to a rotated principal', () async {
    final walletGate = Completer<PrivyWalletSummary>();
    gateway.walletCreationOperation = walletGate.future;

    final creation = container
        .read(loopSessionProvider.notifier)
        .createWallet();
    gateway.emitAuthenticated('did:privy:new');
    await Future<void>.delayed(Duration.zero);
    walletGate.complete(const PrivyWalletSummary(address: '0x123'));

    await expectLater(creation, throwsA(isA<PrivyGatewayException>()));
    final account = container.read(loopSessionProvider).account;
    expect(account?.privyUserId, 'did:privy:new');
    expect(account?.wallet, isNull);
  });
}

final class _LogoutGateway implements PrivyAuthGateway {
  final _snapshots = StreamController<PrivySessionSnapshot>.broadcast();

  Future<void> logoutOperation = Future<void>.value();
  Future<PrivyWalletSummary>? walletCreationOperation;
  var logoutCalls = 0;

  Future<void> dispose() => _snapshots.close();

  void emitAuthenticated(String principalKey) {
    _snapshots.add(
      PrivySessionSnapshot(
        PrivySessionKind.authenticated,
        account: PrivyAccountSummary(privyUserId: principalKey),
      ),
    );
  }

  @override
  Future<PrivySessionSnapshot> restoreSession() async {
    return const PrivySessionSnapshot(
      PrivySessionKind.authenticated,
      account: PrivyAccountSummary(privyUserId: 'did:privy:old'),
    );
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() => _snapshots.stream;

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    await logoutOperation;
  }

  @override
  Future<PrivyWalletSummary> createFirstEthereumWallet() {
    return walletCreationOperation ??
        Future<PrivyWalletSummary>.value(
          const PrivyWalletSummary(address: '0x123'),
        );
  }

  @override
  Future<String> getCurrentAccessToken() {
    throw UnsupportedError('Not used by this test.');
  }

  @override
  Future<void> sendEmailCode(String email) {
    throw UnsupportedError('Not used by this test.');
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) {
    throw UnsupportedError('Not used by this test.');
  }
}
