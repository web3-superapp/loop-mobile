import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_coordinator.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';

void main() {
  const principal = 'did:privy:user-a';
  const deviceId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const accountId = '6d12a86e-4134-47e6-9312-c5ef75a30f55';
  const sessionId = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
  const streamUserId = 'loop_external_opaque_identity';
  const metadata = LoopV2ClientMetadata(
    clientVersion: '0.1.0+1',
    platform: LoopV2Platform.android,
  );
  const active = LoopV2ActiveSession(
    accountId: accountId,
    sessionId: sessionId,
    streamUserId: streamUserId,
    deviceId: deviceId,
  );
  const account = LoopV2AccountProjection(
    accountId: accountId,
    streamUserId: streamUserId,
  );

  test(
    'restored account reuses only a matching active local session',
    () async {
      final store = _MemoryStore(deviceId);
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      store.journals[partition] = const LoopV2OwnerJournal(
        activeSession: active,
      );
      final api = _FakeApi(accountResult: account);
      final repository = LoopV2BootstrapRepository(
        principalKey: principal,
        clientMetadata: metadata,
        api: api,
        store: store,
      );

      final identity = await repository.bootstrap(accessToken: 'current-token');

      expect(identity.loopUserId, accountId);
      expect(identity.streamUserId, streamUserId);
      expect(api.accountCalls, 1);
      expect(api.bootstrapCommands, isEmpty);
      expect(store.writeCount, 0);
    },
  );

  test('account/me precedes a write-before-dispatch bootstrap', () async {
    final store = _MemoryStore(deviceId);
    final partition = LoopV2OwnerPartition.fromPrincipal(principal);
    final api = _FakeApi(
      accountResult: account,
      bootstrapHandler: (command) async {
        final persisted = store.journals[partition]?.pendingBootstrap;
        expect(persisted?.idempotencyKey, command.idempotencyKey);
        expect(persisted?.deviceId, deviceId);
        expect(persisted?.clientVersion, '0.1.0+1');
        return _bootstrap(active);
      },
    );
    final repository = LoopV2BootstrapRepository(
      principalKey: principal,
      clientMetadata: metadata,
      api: api,
      store: store,
    );

    final identity = await repository.bootstrap(accessToken: 'current-token');

    expect(api.events, <String>['account', 'bootstrap']);
    expect(
      LoopV2Contract.uuidV4Pattern.hasMatch(
        api.bootstrapCommands.single.idempotencyKey,
      ),
      isTrue,
    );
    expect(identity.streamUserId, streamUserId);
    expect(store.journals[partition]?.activeSession, same(active));
    expect(store.journals[partition]?.pendingBootstrap, isNull);
  });

  test('ACCOUNT_BOOTSTRAP_REQUIRED starts first registration', () async {
    final store = _MemoryStore(deviceId);
    final api = _FakeApi(
      accountResult: const LoopBackendFailure(
        LoopBackendFailureKind.invalidRequest,
        statusCode: 409,
        code: 'ACCOUNT_BOOTSTRAP_REQUIRED',
      ),
      bootstrapHandler: (_) async => _bootstrap(active),
    );
    final repository = LoopV2BootstrapRepository(
      principalKey: principal,
      clientMetadata: metadata,
      api: api,
      store: store,
    );

    expect(
      await repository.bootstrap(accessToken: 'current-token'),
      isA<LoopBootstrapIdentity>(),
    );
    expect(api.events, <String>['account', 'bootstrap']);
  });

  test(
    'ACCOUNT_BOOTSTRAP_REQUIRED replaces a stale local active session',
    () async {
      const replacement = LoopV2ActiveSession(
        accountId: accountId,
        sessionId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
        streamUserId: streamUserId,
        deviceId: deviceId,
      );
      final store = _MemoryStore(deviceId);
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      store.journals[partition] = const LoopV2OwnerJournal(
        activeSession: active,
      );
      final api = _FakeApi(
        accountResult: const LoopBackendFailure(
          LoopBackendFailureKind.invalidRequest,
          statusCode: 409,
          code: 'ACCOUNT_BOOTSTRAP_REQUIRED',
        ),
        bootstrapHandler: (_) async => _bootstrap(replacement),
      );
      final repository = LoopV2BootstrapRepository(
        principalKey: principal,
        clientMetadata: metadata,
        api: api,
        store: store,
      );

      final identity = await repository.bootstrap(accessToken: 'current-token');

      expect(api.events, <String>['account', 'bootstrap']);
      expect(identity.loopUserId, accountId);
      expect(store.journals[partition]?.activeSession, same(replacement));
      expect(api.bootstrapCommands, hasLength(1));
    },
  );

  test(
    'ACCOUNT_BOOTSTRAP_REQUIRED discards stale active logout recovery',
    () async {
      const staleLogout = LoopV2CommandMetadata(
        deviceId: deviceId,
        idempotencyKey: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        clientVersion: '0.1.0+1',
        platform: LoopV2Platform.android,
      );
      const replacement = LoopV2ActiveSession(
        accountId: accountId,
        sessionId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
        streamUserId: streamUserId,
        deviceId: deviceId,
      );
      final store = _MemoryStore(deviceId);
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      store.journals[partition] = const LoopV2OwnerJournal(
        activeSession: active,
        pendingLogout: staleLogout,
        revocationUnconfirmed: true,
      );
      final api = _FakeApi(
        accountResult: const LoopBackendFailure(
          LoopBackendFailureKind.invalidRequest,
          statusCode: 409,
          code: 'ACCOUNT_BOOTSTRAP_REQUIRED',
        ),
        bootstrapHandler: (command) async {
          expect(command.idempotencyKey, isNot(staleLogout.idempotencyKey));
          expect(
            store.journals[partition]?.pendingBootstrap?.idempotencyKey,
            command.idempotencyKey,
          );
          return _bootstrap(replacement);
        },
        logoutHandler: (_, _) async {
          fail(
            'stale logout must not be sent after account bootstrap required',
          );
        },
      );
      final repository = LoopV2BootstrapRepository(
        principalKey: principal,
        clientMetadata: metadata,
        api: api,
        store: store,
      );

      final identity = await repository.bootstrap(accessToken: 'current-token');

      expect(identity.loopUserId, replacement.accountId);
      expect(api.events, <String>['account', 'bootstrap']);
      expect(api.logoutCommands, isEmpty);
      expect(store.journals[partition]?.activeSession, same(replacement));
    },
  );

  test('ambiguous bootstrap reuses its exact persisted command', () async {
    final store = _MemoryStore(deviceId);
    LoopV2CommandMetadata? firstCommand;
    var bootstrapAttempt = 0;
    final api = _FakeApi(
      accountResult: account,
      bootstrapHandler: (command) async {
        bootstrapAttempt += 1;
        firstCommand ??= command;
        if (bootstrapAttempt == 1) {
          throw const LoopBackendFailure(LoopBackendFailureKind.timeout);
        }
        return _bootstrap(active);
      },
    );

    Future<LoopBootstrapIdentity> attempt() {
      return LoopV2BootstrapRepository(
        principalKey: principal,
        clientMetadata: metadata,
        api: api,
        store: store,
      ).bootstrap(accessToken: 'current-token');
    }

    await expectLater(
      attempt(),
      throwsA(_failure(LoopBackendFailureKind.timeout)),
    );
    final persistedAfterTimeout = store
        .journals[LoopV2OwnerPartition.fromPrincipal(principal)]
        ?.pendingBootstrap;
    expect(persistedAfterTimeout?.idempotencyKey, firstCommand?.idempotencyKey);

    final identity = await attempt();

    expect(identity.loopUserId, accountId);
    expect(api.bootstrapCommands, hasLength(2));
    expect(
      api.bootstrapCommands.last.idempotencyKey,
      api.bootstrapCommands.first.idempotencyKey,
    );
    expect(api.bootstrapCommands.last.clientVersion, '0.1.0+1');
  });

  test(
    'logout retires a pending bootstrap before revoking its recovered session',
    () async {
      const pendingBootstrap = LoopV2CommandMetadata(
        deviceId: deviceId,
        idempotencyKey: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        clientVersion: '0.1.0+1',
        platform: LoopV2Platform.android,
      );
      final store = _MemoryStore(deviceId);
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      store.journals[partition] = const LoopV2OwnerJournal(
        pendingBootstrap: pendingBootstrap,
      );
      final api = _FakeApi(
        accountResult: account,
        bootstrapHandler: (command) async {
          expect(command.idempotencyKey, pendingBootstrap.idempotencyKey);
          expect(
            store.journals[partition]?.bootstrapRetirementRequested,
            isTrue,
          );
          return _bootstrap(active);
        },
        logoutHandler: (requestedSessionId, command) async {
          final persisted = store.journals[partition];
          expect(persisted?.activeSession?.sessionId, requestedSessionId);
          expect(persisted?.pendingBootstrap, isNull);
          expect(
            persisted?.pendingLogout?.idempotencyKey,
            command.idempotencyKey,
          );
          expect(
            command.idempotencyKey,
            isNot(pendingBootstrap.idempotencyKey),
          );
          return LoopV2LogoutProjection(
            sessionId: requestedSessionId,
            revokedAt: DateTime.utc(2026, 9, 3),
          );
        },
      );
      final coordinator = LoopV2LogoutCoordinator(
        clientMetadata: metadata,
        api: api,
        store: store,
        accessTokens: _Tokens(<Object>['current-token']),
      );

      expect(
        await coordinator.logout(principal),
        LoopV2LogoutDisposition.confirmed,
      );
      expect(api.events, <String>['bootstrap', 'logout']);
      expect(store.journals[partition], isNull);
    },
  );

  test(
    'failed pending-bootstrap retirement is recovered before a fresh login',
    () async {
      const pendingBootstrap = LoopV2CommandMetadata(
        deviceId: deviceId,
        idempotencyKey: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        clientVersion: '0.1.0+1',
        platform: LoopV2Platform.android,
      );
      const replacement = LoopV2ActiveSession(
        accountId: accountId,
        sessionId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
        streamUserId: streamUserId,
        deviceId: deviceId,
      );
      final store = _MemoryStore(deviceId);
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      store.journals[partition] = const LoopV2OwnerJournal(
        pendingBootstrap: pendingBootstrap,
      );
      final failingApi = _FakeApi(
        accountResult: account,
        bootstrapHandler: (_) async {
          throw const LoopBackendFailure(LoopBackendFailureKind.timeout);
        },
      );
      final coordinator = LoopV2LogoutCoordinator(
        clientMetadata: metadata,
        api: failingApi,
        store: store,
        accessTokens: _Tokens(<Object>['current-token']),
      );

      expect(
        await coordinator.logout(principal),
        LoopV2LogoutDisposition.unconfirmed,
      );
      expect(
        store.journals[partition]?.pendingBootstrap?.idempotencyKey,
        pendingBootstrap.idempotencyKey,
      );
      expect(store.journals[partition]?.bootstrapRetirementRequested, isTrue);

      var bootstrapCall = 0;
      final recoveringApi = _FakeApi(
        accountResult: account,
        bootstrapHandler: (command) async {
          bootstrapCall += 1;
          if (bootstrapCall == 1) {
            expect(command.idempotencyKey, pendingBootstrap.idempotencyKey);
            return _bootstrap(active);
          }
          expect(
            command.idempotencyKey,
            isNot(pendingBootstrap.idempotencyKey),
          );
          return _bootstrap(replacement);
        },
        logoutHandler: (requestedSessionId, _) async {
          expect(requestedSessionId, active.sessionId);
          return LoopV2LogoutProjection(
            sessionId: requestedSessionId,
            revokedAt: DateTime.utc(2026, 9, 3),
          );
        },
      );
      final repository = LoopV2BootstrapRepository(
        principalKey: principal,
        clientMetadata: metadata,
        api: recoveringApi,
        store: store,
      );

      final identity = await repository.bootstrap(accessToken: 'new-token');

      expect(identity.loopUserId, replacement.accountId);
      expect(recoveringApi.events, <String>[
        'account',
        'bootstrap',
        'logout',
        'bootstrap',
      ]);
      expect(
        store.journals[partition]?.activeSession?.sessionId,
        replacement.sessionId,
      );
    },
  );

  test('a local/server identity mismatch fails closed without bootstrap', () {
    final store = _MemoryStore(deviceId);
    store.journals[LoopV2OwnerPartition.fromPrincipal(principal)] =
        const LoopV2OwnerJournal(activeSession: active);
    final api = _FakeApi(
      accountResult: const LoopV2AccountProjection(
        accountId: '77777777-7777-4777-8777-777777777777',
        streamUserId: 'loop_another_opaque_identity',
      ),
    );
    final repository = LoopV2BootstrapRepository(
      principalKey: principal,
      clientMetadata: metadata,
      api: api,
      store: store,
    );

    expect(
      repository.bootstrap(accessToken: 'current-token'),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
    expect(api.bootstrapCommands, isEmpty);
  });

  test(
    'logout persists before dispatch and clears a terminal result',
    () async {
      final store = _MemoryStore(deviceId);
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      store.journals[partition] = const LoopV2OwnerJournal(
        activeSession: active,
      );
      final api = _FakeApi(
        accountResult: account,
        logoutHandler: (requestedSessionId, command) async {
          final persisted = store.journals[partition];
          expect(
            persisted?.pendingLogout?.idempotencyKey,
            command.idempotencyKey,
          );
          expect(persisted?.activeSession?.sessionId, requestedSessionId);
          return LoopV2LogoutProjection(
            sessionId: requestedSessionId,
            revokedAt: DateTime.utc(2026, 9, 3),
          );
        },
      );
      final coordinator = LoopV2LogoutCoordinator(
        clientMetadata: metadata,
        api: api,
        store: store,
        accessTokens: _Tokens(<Object>['current-token']),
      );

      expect(
        await coordinator.logout(principal),
        LoopV2LogoutDisposition.confirmed,
      );
      expect(api.logoutCommands, hasLength(1));
      expect(store.journals[partition], isNull);
    },
  );

  test('unknown logout retains and reuses the same command', () async {
    final store = _MemoryStore(deviceId);
    final partition = LoopV2OwnerPartition.fromPrincipal(principal);
    store.journals[partition] = const LoopV2OwnerJournal(activeSession: active);
    var attempt = 0;
    final api = _FakeApi(
      accountResult: account,
      logoutHandler: (requestedSessionId, command) async {
        attempt += 1;
        if (attempt == 1) {
          throw const LoopBackendFailure(LoopBackendFailureKind.connection);
        }
        return LoopV2LogoutProjection(
          sessionId: requestedSessionId,
          revokedAt: DateTime.utc(2026, 9, 3),
        );
      },
    );
    final coordinator = LoopV2LogoutCoordinator(
      clientMetadata: metadata,
      api: api,
      store: store,
      accessTokens: _Tokens(<Object>['first-token', 'second-token']),
    );

    expect(
      await coordinator.logout(principal),
      LoopV2LogoutDisposition.unconfirmed,
    );
    final pending = store.journals[partition]?.pendingLogout;
    expect(store.journals[partition]?.revocationUnconfirmed, isTrue);
    expect(pending, isNotNull);

    expect(
      await coordinator.logout(principal),
      LoopV2LogoutDisposition.confirmed,
    );
    expect(api.logoutCommands, hasLength(2));
    expect(
      api.logoutCommands.last.idempotencyKey,
      api.logoutCommands.first.idempotencyKey,
    );
  });

  test('SESSION_NOT_FOUND is non-enumerating and terminal', () async {
    final store = _MemoryStore(deviceId);
    final partition = LoopV2OwnerPartition.fromPrincipal(principal);
    store.journals[partition] = const LoopV2OwnerJournal(activeSession: active);
    final api = _FakeApi(
      accountResult: account,
      logoutHandler: (_, _) async {
        throw const LoopBackendFailure(
          LoopBackendFailureKind.invalidRequest,
          statusCode: 404,
          code: 'SESSION_NOT_FOUND',
        );
      },
    );
    final coordinator = LoopV2LogoutCoordinator(
      clientMetadata: metadata,
      api: api,
      store: store,
      accessTokens: _Tokens(<Object>['current-token']),
    );

    expect(
      await coordinator.logout(principal),
      LoopV2LogoutDisposition.confirmed,
    );
    expect(store.journals[partition], isNull);
  });

  test(
    'a later login reconciles an unconfirmed logout before new bootstrap',
    () async {
      const oldLogout = LoopV2CommandMetadata(
        deviceId: deviceId,
        idempotencyKey: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
        clientVersion: '0.1.0+1',
        platform: LoopV2Platform.android,
      );
      const replacement = LoopV2ActiveSession(
        accountId: accountId,
        sessionId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
        streamUserId: streamUserId,
        deviceId: deviceId,
      );
      final store = _MemoryStore(deviceId);
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      store.journals[partition] = const LoopV2OwnerJournal(
        activeSession: active,
        pendingLogout: oldLogout,
        revocationUnconfirmed: true,
      );
      final api = _FakeApi(
        accountResult: account,
        logoutHandler: (requestedSessionId, command) async {
          expect(requestedSessionId, sessionId);
          expect(command.idempotencyKey, oldLogout.idempotencyKey);
          return LoopV2LogoutProjection(
            sessionId: requestedSessionId,
            revokedAt: DateTime.utc(2026, 9, 3),
          );
        },
        bootstrapHandler: (_) async => _bootstrap(replacement),
      );
      final repository = LoopV2BootstrapRepository(
        principalKey: principal,
        clientMetadata: metadata,
        api: api,
        store: store,
      );

      final identity = await repository.bootstrap(accessToken: 'current-token');

      expect(api.events, <String>['account', 'logout', 'bootstrap']);
      expect(identity.loopUserId, accountId);
      expect(api.logoutCommands, hasLength(1));
      expect(api.bootstrapCommands, hasLength(1));
      expect(
        api.bootstrapCommands.single.idempotencyKey,
        isNot(oldLogout.idempotencyKey),
      );
      expect(
        store.journals[partition]?.activeSession?.sessionId,
        replacement.sessionId,
      );
      expect(store.journals[partition]?.pendingLogout, isNull);
    },
  );

  test(
    'logout quiescence waits for a dispatched bootstrap before revocation',
    () async {
      final bootstrapGate = Completer<LoopV2BootstrapProjection>();
      final store = _MemoryStore(deviceId);
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      final api = _FakeApi(
        accountResult: account,
        bootstrapHandler: (_) => bootstrapGate.future,
        logoutHandler: (requestedSessionId, _) async {
          return LoopV2LogoutProjection(
            sessionId: requestedSessionId,
            revokedAt: DateTime.utc(2026, 9, 3),
          );
        },
      );
      final repository = LoopV2BootstrapRepository(
        principalKey: principal,
        clientMetadata: metadata,
        api: api,
        store: store,
      );

      final bootstrap = repository.bootstrap(accessToken: 'current-token');
      while (api.bootstrapCommands.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      var quiesced = false;
      final quiescence = repository.prepareForLogout().then((_) {
        quiesced = true;
      });

      await Future<void>.delayed(Duration.zero);
      expect(quiesced, isFalse);
      expect(store.journals[partition]?.activeSession, isNull);

      bootstrapGate.complete(_bootstrap(active));
      await quiescence;
      expect((await bootstrap).loopUserId, accountId);
      expect(store.journals[partition]?.activeSession?.sessionId, sessionId);

      final logout = LoopV2LogoutCoordinator(
        clientMetadata: metadata,
        api: api,
        store: store,
        accessTokens: _Tokens(<Object>['current-token']),
      );
      expect(await logout.logout(principal), LoopV2LogoutDisposition.confirmed);
      expect(api.logoutCommands, hasLength(1));
      expect(store.journals[partition], isNull);
    },
  );

  test(
    'retirement cancels bootstrap before its write request is sent',
    () async {
      final accountGate = Completer<LoopV2AccountProjection>();
      final store = _MemoryStore(deviceId);
      final api = _FakeApi(
        accountResult: account,
        accountHandler: () => accountGate.future,
        bootstrapHandler: (_) async => _bootstrap(active),
      );
      final repository = LoopV2BootstrapRepository(
        principalKey: principal,
        clientMetadata: metadata,
        api: api,
        store: store,
      );

      final bootstrap = repository.bootstrap(accessToken: 'current-token');
      await Future<void>.delayed(Duration.zero);
      repository.retire();
      accountGate.complete(account);

      await expectLater(
        bootstrap,
        throwsA(_failure(LoopBackendFailureKind.cancelled)),
      );
      expect(api.bootstrapCommands, isEmpty);
      expect(store.writeCount, 0);
    },
  );
}

LoopV2BootstrapProjection _bootstrap(LoopV2ActiveSession active) {
  return LoopV2BootstrapProjection(
    activeSession: active,
    createdAt: DateTime.utc(2026, 9, 2),
    lastSeenAt: DateTime.utc(2026, 9, 2),
  );
}

final class _MemoryStore implements LoopV2SessionJournalStore {
  _MemoryStore(this.deviceId);

  final String deviceId;
  final Map<String, LoopV2OwnerJournal> journals =
      <String, LoopV2OwnerJournal>{};
  int writeCount = 0;

  @override
  Future<void> deleteOwnerJournal(String ownerPartition) async {
    journals.remove(ownerPartition);
  }

  @override
  Future<String> loadOrCreateDeviceId() async => deviceId;

  @override
  Future<LoopV2OwnerJournal?> readOwnerJournal(String ownerPartition) async {
    return journals[ownerPartition];
  }

  @override
  Future<void> writeOwnerJournal(
    String ownerPartition,
    LoopV2OwnerJournal journal,
  ) async {
    writeCount += 1;
    journals[ownerPartition] = journal;
  }
}

final class _FakeApi implements LoopV2SessionApi {
  _FakeApi({
    required this.accountResult,
    this.accountHandler,
    this.bootstrapHandler,
    this.logoutHandler,
  });

  final Object accountResult;
  final Future<LoopV2AccountProjection> Function()? accountHandler;
  final Future<LoopV2BootstrapProjection> Function(LoopV2CommandMetadata)?
  bootstrapHandler;
  final Future<LoopV2LogoutProjection> Function(
    String sessionId,
    LoopV2CommandMetadata command,
  )?
  logoutHandler;
  int accountCalls = 0;
  final List<String> events = <String>[];
  final List<LoopV2CommandMetadata> bootstrapCommands =
      <LoopV2CommandMetadata>[];
  final List<LoopV2CommandMetadata> logoutCommands = <LoopV2CommandMetadata>[];

  @override
  Future<LoopV2AccountProjection> getAccount({
    required String accessToken,
    required String clientVersion,
  }) async {
    accountCalls += 1;
    events.add('account');
    final handler = accountHandler;
    if (handler != null) return handler();
    final value = accountResult;
    if (value is LoopV2AccountProjection) return value;
    throw value;
  }

  @override
  Future<LoopV2BootstrapProjection> bootstrap({
    required String accessToken,
    required LoopV2CommandMetadata command,
  }) {
    events.add('bootstrap');
    bootstrapCommands.add(command);
    return bootstrapHandler!(command);
  }

  @override
  Future<LoopV2LogoutProjection> logout({
    required String accessToken,
    required String sessionId,
    required LoopV2CommandMetadata command,
  }) {
    events.add('logout');
    logoutCommands.add(command);
    return logoutHandler!(sessionId, command);
  }
}

final class _Tokens implements LoopBackendAccessTokenSource {
  _Tokens(this.values);

  final List<Object> values;

  @override
  Future<String> loadAccessToken() async {
    final value = values.removeAt(0);
    if (value is String) return value;
    throw value;
  }
}

TypeMatcher<LoopBackendFailure> _failure(LoopBackendFailureKind kind) {
  return isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    kind,
  );
}
