import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/app/session/wallet_provisioning_controller.dart';
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
        LoopSessionMode.signingOut,
      );
      expect(container.read(loopBootstrapPrincipalKeyProvider), isNull);
      expect(gateway.logoutCalls, 1);

      gateway.emitAuthenticated('did:privy:stale');
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signingOut,
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

  test(
    'ordered logout keeps the local barrier while backend and Stream retire',
    () async {
      final backendGate = Completer<LoopBackendLogoutResult>();
      final events = <String>[];

      final exit = container
          .read(loopSessionProvider.notifier)
          .exit(
            revokeBackend: (principalKey) {
              expect(principalKey, 'did:privy:old');
              events.add('backend');
              return backendGate.future;
            },
            retireCommunications: () async {
              events.add('stream');
            },
          );

      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signingOut,
      );
      expect(container.read(loopBootstrapPrincipalKeyProvider), isNull);
      expect(events, <String>['backend']);
      expect(gateway.logoutCalls, 0);

      expect(
        () => container
            .read(loopSessionProvider.notifier)
            .acceptAuthenticated(
              const PrivyAccountSummary(privyUserId: 'did:privy:new'),
            ),
        throwsA(isA<PrivyGatewayException>()),
      );
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signingOut,
      );

      backendGate.complete(LoopBackendLogoutResult.confirmed);
      await exit;

      expect(events, <String>['backend', 'stream']);
      expect(gateway.logoutCalls, 1);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );

      container
          .read(loopSessionProvider.notifier)
          .acceptAuthenticated(
            const PrivyAccountSummary(privyUserId: 'did:privy:new'),
          );
      expect(
        container.read(loopSessionProvider).account?.privyUserId,
        'did:privy:new',
      );
    },
  );

  test(
    'unknown backend revocation never traps local or Privy logout',
    () async {
      await container
          .read(loopSessionProvider.notifier)
          .exit(
            revokeBackend: (_) async => LoopBackendLogoutResult.unconfirmed,
            retireCommunications: () async {},
          );

      expect(gateway.logoutCalls, 1);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
      expect(
        container.read(loopSessionProvider).errorMessage,
        '本地会话已退出，但 LOOP 后端会话撤销尚未确认。',
      );
    },
  );

  test('duplicate exit calls share one cleanup operation', () async {
    final backendGate = Completer<LoopBackendLogoutResult>();
    var backendCalls = 0;
    var retirementCalls = 0;
    final controller = container.read(loopSessionProvider.notifier);

    final first = controller.exit(
      revokeBackend: (_) {
        backendCalls += 1;
        return backendGate.future;
      },
      retireCommunications: () async {
        retirementCalls += 1;
      },
    );
    final second = controller.exit(
      revokeBackend: (_) async {
        backendCalls += 1;
        return LoopBackendLogoutResult.confirmed;
      },
      retireCommunications: () async {
        retirementCalls += 1;
      },
    );

    expect(second, same(first));
    expect(
      container.read(loopSessionProvider).mode,
      LoopSessionMode.signingOut,
    );
    expect(backendCalls, 1);
    expect(retirementCalls, 0);
    expect(gateway.logoutCalls, 0);

    backendGate.complete(LoopBackendLogoutResult.confirmed);
    await Future.wait<void>(<Future<void>>[first, second]);

    expect(backendCalls, 1);
    expect(retirementCalls, 1);
    expect(gateway.logoutCalls, 1);
    expect(container.read(loopSessionProvider).mode, LoopSessionMode.signedOut);
  });

  test('late wallet creation cannot attach to a rotated principal', () async {
    final walletGate = Completer<PrivyWalletCreationResult>();
    gateway.walletCreationOperation = walletGate.future;

    final creation = container
        .read(loopSessionProvider.notifier)
        .createWallet();
    gateway.emitAuthenticated('did:privy:new');
    await Future<void>.delayed(Duration.zero);
    walletGate.complete(
      const PrivyWalletCreationResult(
        privyUserId: 'did:privy:old',
        wallet: PrivyWalletSummary(address: '0x123'),
      ),
    );

    await expectLater(creation, throwsA(isA<PrivyGatewayException>()));
    final account = container.read(loopSessionProvider).account;
    expect(account?.privyUserId, 'did:privy:new');
    expect(account?.wallet, isNull);
  });

  test(
    'a prior principal wallet future cannot attach to the current principal',
    () async {
      final walletGate = Completer<PrivyWalletCreationResult>();
      gateway.walletCreationOperation = walletGate.future;

      final oldCreation = container
          .read(loopSessionProvider.notifier)
          .createWallet();
      gateway.emitAuthenticated('did:privy:new');
      await Future<void>.delayed(Duration.zero);
      final newCreation = container
          .read(loopSessionProvider.notifier)
          .createWallet();

      walletGate.complete(
        const PrivyWalletCreationResult(
          privyUserId: 'did:privy:old',
          wallet: PrivyWalletSummary(address: '0xold'),
        ),
      );

      await expectLater(oldCreation, throwsA(isA<PrivyGatewayException>()));
      await expectLater(newCreation, throwsA(isA<PrivyGatewayException>()));
      final account = container.read(loopSessionProvider).account;
      expect(account?.privyUserId, 'did:privy:new');
      expect(account?.wallet, isNull);
      expect(gateway.walletCreationPrincipals, <String>[
        'did:privy:old',
        'did:privy:new',
      ]);
    },
  );

  group('post-login wallet provisioning', () {
    test('a verified session without a wallet gets exactly one', () async {
      final provisioning = container.read(
        loopWalletProvisioningProvider.notifier,
      );

      await provisioning.ensureWallet();

      expect(gateway.walletCreationPrincipals, <String>['did:privy:old']);
      expect(
        container.read(loopSessionProvider).account?.wallet?.address,
        '0x123',
      );
      expect(
        container.read(loopWalletProvisioningProvider).stage,
        LoopWalletProvisioningStage.created,
      );

      // The account now owns a wallet, so a second pass asks for nothing.
      await provisioning.ensureWallet();
      expect(gateway.walletCreationPrincipals, <String>['did:privy:old']);
    });

    test('an account that already owns a wallet is never asked', () async {
      gateway.emitAuthenticated('did:privy:old', walletAddress: '0xabc');
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(loopSessionProvider).account?.wallet?.address,
        '0xabc',
      );

      await container
          .read(loopWalletProvisioningProvider.notifier)
          .ensureWallet();

      expect(gateway.walletCreationPrincipals, isEmpty);
      expect(
        container.read(loopWalletProvisioningProvider).stage,
        LoopWalletProvisioningStage.idle,
      );
    });

    test('a failed creation is a wallet fact, never a login one', () async {
      gateway.walletCreationOperation = Future<PrivyWalletCreationResult>.error(
        const PrivyGatewayException('钱包创建失败，请稍后重试。'),
      );

      await container
          .read(loopWalletProvisioningProvider.notifier)
          .ensureWallet();

      final provisioning = container.read(loopWalletProvisioningProvider);
      expect(provisioning.stage, LoopWalletProvisioningStage.failed);
      expect(provisioning.errorMessage, '钱包创建失败，请稍后重试。');
      final session = container.read(loopSessionProvider);
      expect(session.mode, LoopSessionMode.authenticated);
      expect(session.account?.wallet, isNull);
      expect(session.errorMessage, isNull);
    });

    test(
      'a development preview session never asks Privy for a wallet',
      () async {
        gateway.restoresAuthenticated = false;
        final preview = ProviderContainer(
          overrides: [
            privyAuthGatewayProvider.overrideWithValue(gateway),
            developmentPreviewEnabledProvider.overrideWithValue(true),
          ],
        );
        addTearDown(preview.dispose);
        expect(
          preview.read(loopSessionProvider.notifier).enterPreview(),
          isTrue,
        );
        await Future<void>.delayed(Duration.zero);
        expect(preview.read(loopSessionProvider).mode, LoopSessionMode.preview);

        await preview
            .read(loopWalletProvisioningProvider.notifier)
            .ensureWallet();

        expect(gateway.walletCreationPrincipals, isEmpty);
        expect(
          preview.read(loopWalletProvisioningProvider).stage,
          LoopWalletProvisioningStage.idle,
        );
      },
    );

    test('an unverified session never asks Privy for a wallet', () async {
      gateway.emit(
        const PrivySessionSnapshot(PrivySessionKind.authenticatedUnverified),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.authenticatedUnverified,
      );

      await container
          .read(loopWalletProvisioningProvider.notifier)
          .ensureWallet();

      expect(gateway.walletCreationPrincipals, isEmpty);
    });

    test(
      'a manual retry joins the automatic attempt instead of racing',
      () async {
        final walletGate = Completer<PrivyWalletCreationResult>();
        gateway.walletCreationOperation = walletGate.future;
        final provisioning = container.read(
          loopWalletProvisioningProvider.notifier,
        );

        final automatic = provisioning.ensureWallet();
        expect(
          container.read(loopWalletProvisioningProvider).isCreating,
          isTrue,
        );
        final manual = provisioning.createWallet();

        walletGate.complete(
          const PrivyWalletCreationResult(
            privyUserId: 'did:privy:old',
            wallet: PrivyWalletSummary(address: '0x123'),
          ),
        );
        await automatic;

        expect(await manual, isTrue);
        expect(gateway.walletCreationPrincipals, <String>['did:privy:old']);
      },
    );
  });
}

final class _LogoutGateway implements PrivyAuthGateway {
  final _snapshots = StreamController<PrivySessionSnapshot>.broadcast();

  Future<void> logoutOperation = Future<void>.value();
  Future<PrivyWalletCreationResult>? walletCreationOperation;
  final walletCreationPrincipals = <String>[];
  var logoutCalls = 0;

  Future<void> dispose() => _snapshots.close();

  void emit(PrivySessionSnapshot snapshot) => _snapshots.add(snapshot);

  void emitAuthenticated(String principalKey, {String? walletAddress}) {
    _snapshots.add(
      PrivySessionSnapshot(
        PrivySessionKind.authenticated,
        account: PrivyAccountSummary(
          privyUserId: principalKey,
          wallet: walletAddress == null
              ? null
              : PrivyWalletSummary(address: walletAddress),
        ),
      ),
    );
  }

  /// A restore that answers "signed out", so a test can install a Preview
  /// session without a later authenticated restore replacing it.
  var restoresAuthenticated = true;

  @override
  Future<PrivySessionSnapshot> restoreSession() async {
    if (!restoresAuthenticated) {
      return const PrivySessionSnapshot(PrivySessionKind.unauthenticated);
    }
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
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) {
    walletCreationPrincipals.add(expectedPrivyUserId);
    return walletCreationOperation ??
        Future<PrivyWalletCreationResult>.value(
          PrivyWalletCreationResult(
            privyUserId: expectedPrivyUserId,
            wallet: const PrivyWalletSummary(address: '0x123'),
          ),
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
