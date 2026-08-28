import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
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

  test(
    'a newer unverified stream snapshot wins over stale authenticated restore',
    () async {
      final gatedGateway = _GatedRestoreGateway();
      final gatedContainer = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(gatedGateway)],
      );
      addTearDown(gatedContainer.dispose);
      addTearDown(gatedGateway.dispose);

      expect(
        gatedContainer.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await gatedGateway.restoreStarted.future;

      gatedGateway.emit(
        const PrivySessionSnapshot(PrivySessionKind.authenticatedUnverified),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        gatedContainer.read(loopSessionProvider).mode,
        LoopSessionMode.authenticatedUnverified,
      );

      gatedGateway.completeRestore(
        const PrivySessionSnapshot(
          PrivySessionKind.authenticated,
          account: PrivyAccountSummary(privyUserId: 'did:privy:stale'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final session = gatedContainer.read(loopSessionProvider);
      expect(session.mode, LoopSessionMode.authenticatedUnverified);
      expect(session.account, isNull);
    },
  );

  test(
    'an old gateway restore cannot publish into a rebuilt controller',
    () async {
      final oldGateway = _GatedRestoreGateway();
      final newGateway = _GatedRestoreGateway();
      final gatedContainer = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(oldGateway)],
      );
      addTearDown(gatedContainer.dispose);
      addTearDown(oldGateway.dispose);
      addTearDown(newGateway.dispose);

      expect(
        gatedContainer.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await oldGateway.restoreStarted.future;

      gatedContainer.updateOverrides([
        privyAuthGatewayProvider.overrideWithValue(newGateway),
      ]);
      expect(
        gatedContainer.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await newGateway.restoreStarted.future;

      oldGateway.completeRestore(
        const PrivySessionSnapshot(
          PrivySessionKind.authenticated,
          account: PrivyAccountSummary(privyUserId: 'did:privy:old-gateway'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        gatedContainer.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );

      newGateway.completeRestore(
        const PrivySessionSnapshot(PrivySessionKind.authenticatedUnverified),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        gatedContainer.read(loopSessionProvider).mode,
        LoopSessionMode.authenticatedUnverified,
      );
    },
  );

  test('a newer authenticated principal wins over stale restore', () async {
    final gatedGateway = _GatedRestoreGateway();
    final gatedContainer = ProviderContainer(
      overrides: [privyAuthGatewayProvider.overrideWithValue(gatedGateway)],
    );
    addTearDown(gatedContainer.dispose);
    addTearDown(gatedGateway.dispose);

    gatedContainer.read(loopSessionProvider);
    await gatedGateway.restoreStarted.future;
    gatedGateway.emit(
      const PrivySessionSnapshot(
        PrivySessionKind.authenticated,
        account: PrivyAccountSummary(privyUserId: 'did:privy:current'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    gatedGateway.completeRestore(
      const PrivySessionSnapshot(
        PrivySessionKind.authenticated,
        account: PrivyAccountSummary(privyUserId: 'did:privy:stale'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      gatedContainer.read(loopSessionProvider).account?.privyUserId,
      'did:privy:current',
    );
  });

  test(
    'a newer signed-out snapshot wins over stale authenticated restore',
    () async {
      final gatedGateway = _GatedRestoreGateway();
      final gatedContainer = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(gatedGateway)],
      );
      addTearDown(gatedContainer.dispose);
      addTearDown(gatedGateway.dispose);

      gatedContainer.read(loopSessionProvider);
      await gatedGateway.restoreStarted.future;
      gatedGateway.emit(
        const PrivySessionSnapshot(PrivySessionKind.unauthenticated),
      );
      await Future<void>.delayed(Duration.zero);

      gatedGateway.completeRestore(
        const PrivySessionSnapshot(
          PrivySessionKind.authenticated,
          account: PrivyAccountSummary(privyUserId: 'did:privy:stale'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        gatedContainer.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
    },
  );

  test(
    'a newer NotReady snapshot blocks stale restore success and error',
    () async {
      final staleSuccess = _GatedRestoreGateway();
      final successContainer = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(staleSuccess)],
      );
      addTearDown(successContainer.dispose);
      addTearDown(staleSuccess.dispose);

      successContainer.read(loopSessionProvider);
      await staleSuccess.restoreStarted.future;
      staleSuccess.emit(const PrivySessionSnapshot(PrivySessionKind.notReady));
      await Future<void>.delayed(Duration.zero);
      staleSuccess.completeRestore(
        const PrivySessionSnapshot(
          PrivySessionKind.authenticated,
          account: PrivyAccountSummary(privyUserId: 'did:privy:stale'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        successContainer.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );

      final staleError = _GatedRestoreGateway();
      final errorContainer = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(staleError)],
      );
      addTearDown(errorContainer.dispose);
      addTearDown(staleError.dispose);

      errorContainer.read(loopSessionProvider);
      await staleError.restoreStarted.future;
      staleError.emit(const PrivySessionSnapshot(PrivySessionKind.notReady));
      await Future<void>.delayed(Duration.zero);
      staleError.completeRestoreError(
        const PrivyGatewayException('stale restore failure'),
      );
      await Future<void>.delayed(Duration.zero);
      final session = errorContainer.read(loopSessionProvider);
      expect(session.mode, LoopSessionMode.restoring);
      expect(session.errorMessage, isNull);
    },
  );

  test('a synchronous initial NotReady stream is safe during build', () async {
    final gatedGateway = _GatedRestoreGateway(
      initialSnapshot: const PrivySessionSnapshot(PrivySessionKind.notReady),
    );
    final gatedContainer = ProviderContainer(
      overrides: [privyAuthGatewayProvider.overrideWithValue(gatedGateway)],
    );
    addTearDown(gatedContainer.dispose);
    addTearDown(gatedGateway.dispose);

    expect(() => gatedContainer.read(loopSessionProvider), returnsNormally);
    expect(
      gatedContainer.read(loopSessionProvider).mode,
      LoopSessionMode.restoring,
    );

    await gatedGateway.restoreStarted.future;
    gatedGateway.completeRestore(
      const PrivySessionSnapshot(PrivySessionKind.unauthenticated),
    );
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'local authentication cancels an older queued NotReady snapshot',
    () async {
      final gatedGateway = _GatedRestoreGateway(
        initialSnapshot: const PrivySessionSnapshot(PrivySessionKind.notReady),
      );
      final gatedContainer = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(gatedGateway)],
      );
      addTearDown(gatedContainer.dispose);
      addTearDown(gatedGateway.dispose);

      final controller = gatedContainer.read(loopSessionProvider.notifier);
      controller.acceptAuthenticated(
        const PrivyAccountSummary(privyUserId: 'did:privy:current'),
      );
      await Future<void>.delayed(Duration.zero);

      final session = gatedContainer.read(loopSessionProvider);
      expect(session.mode, LoopSessionMode.authenticated);
      expect(session.account?.privyUserId, 'did:privy:current');

      await gatedGateway.restoreStarted.future;
      gatedGateway.completeRestore(
        const PrivySessionSnapshot(PrivySessionKind.unauthenticated),
      );
      await Future<void>.delayed(Duration.zero);
    },
  );

  test('Preview entry cancels an older queued NotReady snapshot', () async {
    final gatedGateway = _GatedRestoreGateway(
      initialSnapshot: const PrivySessionSnapshot(PrivySessionKind.notReady),
    );
    final gatedContainer = ProviderContainer(
      overrides: [
        privyAuthGatewayProvider.overrideWithValue(gatedGateway),
        developmentPreviewEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(gatedContainer.dispose);
    addTearDown(gatedGateway.dispose);

    final controller = gatedContainer.read(loopSessionProvider.notifier);
    expect(controller.enterPreview(), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(
      gatedContainer.read(loopSessionProvider).mode,
      LoopSessionMode.preview,
    );

    await gatedGateway.restoreStarted.future;
    gatedGateway.completeRestore(
      const PrivySessionSnapshot(PrivySessionKind.unauthenticated),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      gatedContainer.read(loopSessionProvider).mode,
      LoopSessionMode.preview,
    );
  });

  test('local exit cancels an older queued authenticated snapshot', () async {
    final gatedGateway = _GatedRestoreGateway(
      initialSnapshot: const PrivySessionSnapshot(
        PrivySessionKind.authenticated,
        account: PrivyAccountSummary(privyUserId: 'did:privy:stale'),
      ),
    );
    final gatedContainer = ProviderContainer(
      overrides: [privyAuthGatewayProvider.overrideWithValue(gatedGateway)],
    );
    addTearDown(gatedContainer.dispose);
    addTearDown(gatedGateway.dispose);

    final controller = gatedContainer.read(loopSessionProvider.notifier);
    await controller.exit();
    await Future<void>.delayed(Duration.zero);

    var session = gatedContainer.read(loopSessionProvider);
    expect(session.mode, LoopSessionMode.signedOut);
    expect(session.account, isNull);

    await gatedGateway.restoreStarted.future;
    gatedGateway.completeRestore(
      const PrivySessionSnapshot(
        PrivySessionKind.authenticated,
        account: PrivyAccountSummary(privyUserId: 'did:privy:stale'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    session = gatedContainer.read(loopSessionProvider);
    expect(session.mode, LoopSessionMode.signedOut);
    expect(session.account, isNull);
  });
}

final class _GatedRestoreGateway implements PrivyAuthGateway {
  _GatedRestoreGateway({PrivySessionSnapshot? initialSnapshot}) {
    _snapshots = StreamController<PrivySessionSnapshot>.broadcast(
      sync: true,
      onListen: initialSnapshot == null
          ? null
          : () => _snapshots.add(initialSnapshot),
    );
  }

  late final StreamController<PrivySessionSnapshot> _snapshots;
  final _restore = Completer<PrivySessionSnapshot>();
  final restoreStarted = Completer<void>();

  void emit(PrivySessionSnapshot snapshot) => _snapshots.add(snapshot);

  void completeRestore(PrivySessionSnapshot snapshot) =>
      _restore.complete(snapshot);

  void completeRestoreError(Object error) => _restore.completeError(error);

  Future<void> dispose() => _snapshots.close();

  @override
  Future<PrivySessionSnapshot> restoreSession() {
    if (!restoreStarted.isCompleted) restoreStarted.complete();
    return _restore.future;
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() => _snapshots.stream;

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) {
    throw UnsupportedError('Not used by this test.');
  }

  @override
  Future<String> getCurrentAccessToken() {
    throw UnsupportedError('Not used by this test.');
  }

  @override
  Future<void> logout() {
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

final class _LogoutGateway implements PrivyAuthGateway {
  final _snapshots = StreamController<PrivySessionSnapshot>.broadcast();

  Future<void> logoutOperation = Future<void>.value();
  Future<PrivyWalletCreationResult>? walletCreationOperation;
  final walletCreationPrincipals = <String>[];
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
