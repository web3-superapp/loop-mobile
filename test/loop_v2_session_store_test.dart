import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session_store.dart';

void main() {
  const principal = 'did:privy:sensitive-provider-subject';

  test('creates one canonical device ID and reuses it', () async {
    final secure = _MemorySecureStore();
    final store = FlutterSecureLoopV2SessionJournalStore(secureStorage: secure);

    final first = await store.loadOrCreateDeviceId();
    final second = await store.loadOrCreateDeviceId();

    expect(LoopV2Contract.uuidV4Pattern.hasMatch(first), isTrue);
    expect(second, first);
    expect(secure.writes, 1);
    expect(secure.values.keys, <String>['loop.backend.v2.device_id']);
  });

  test(
    'round trips the exact owner journal without raw principal or tokens',
    () async {
      final secure = _MemorySecureStore();
      final store = FlutterSecureLoopV2SessionJournalStore(
        secureStorage: secure,
      );
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      const command = LoopV2CommandMetadata(
        deviceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        idempotencyKey: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        clientVersion: '0.1.0+1',
        platform: LoopV2Platform.ios,
      );
      const active = LoopV2ActiveSession(
        accountId: '6d12a86e-4134-47e6-9312-c5ef75a30f55',
        sessionId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
        streamUserId: 'loop_an_opaque_server_identity',
        deviceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      const pendingBootstrap = LoopV2OwnerJournal(pendingBootstrap: command);
      const retiringBootstrap = LoopV2OwnerJournal(
        pendingBootstrap: command,
        bootstrapRetirementRequested: true,
      );
      const pendingLogout = LoopV2OwnerJournal(
        activeSession: active,
        pendingLogout: command,
        revocationUnconfirmed: true,
      );

      await store.writeOwnerJournal(partition, pendingBootstrap);
      final restoredBootstrap = await store.readOwnerJournal(partition);
      expect(
        restoredBootstrap?.pendingBootstrap?.idempotencyKey,
        command.idempotencyKey,
      );
      expect(restoredBootstrap?.activeSession, isNull);

      await store.writeOwnerJournal(partition, retiringBootstrap);
      final restoredRetirement = await store.readOwnerJournal(partition);
      expect(restoredRetirement?.bootstrapRetirementRequested, isTrue);
      expect(
        restoredRetirement?.pendingBootstrap?.idempotencyKey,
        command.idempotencyKey,
      );

      await store.writeOwnerJournal(partition, pendingLogout);
      final restoredLogout = await store.readOwnerJournal(partition);

      expect(restoredLogout?.activeSession?.accountId, active.accountId);
      expect(restoredLogout?.pendingBootstrap, isNull);
      expect(restoredLogout?.pendingLogout?.platform, LoopV2Platform.ios);
      expect(restoredLogout?.revocationUnconfirmed, isTrue);
      final persisted = secure.values.entries.single;
      expect(persisted.key, isNot(contains(principal)));
      expect(persisted.value, isNot(contains(principal)));
      expect(persisted.value, isNot(contains('accessToken')));
      expect(persisted.value, isNot(contains('refreshToken')));
      expect(persisted.value, isNot(contains('streamToken')));
    },
  );

  test(
    'write validates the complete journal before touching storage',
    () async {
      final secure = _MemorySecureStore();
      final store = FlutterSecureLoopV2SessionJournalStore(
        secureStorage: secure,
      );
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      const invalid = LoopV2OwnerJournal(
        activeSession: LoopV2ActiveSession(
          accountId: '6d12a86e-4134-47e6-9312-c5ef75a30f55',
          sessionId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          streamUserId: 'not-a-canonical-stream-id',
          deviceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        ),
      );

      await expectLater(
        store.writeOwnerJournal(partition, invalid),
        throwsA(isA<LoopV2SessionStorageException>()),
      );
      expect(secure.writes, 0);
      expect(secure.values, isEmpty);
    },
  );

  test(
    'journal state machine rejects overlapping bootstrap and logout',
    () async {
      final secure = _MemorySecureStore();
      final store = FlutterSecureLoopV2SessionJournalStore(
        secureStorage: secure,
      );
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      const command = LoopV2CommandMetadata(
        deviceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        idempotencyKey: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        clientVersion: '0.1.0+1',
        platform: LoopV2Platform.android,
      );
      const overlapping = LoopV2OwnerJournal(
        pendingBootstrap: command,
        activeSession: LoopV2ActiveSession(
          accountId: '6d12a86e-4134-47e6-9312-c5ef75a30f55',
          sessionId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          streamUserId: 'loop_an_opaque_server_identity',
          deviceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        ),
        pendingLogout: command,
        revocationUnconfirmed: true,
      );

      await expectLater(
        store.writeOwnerJournal(partition, overlapping),
        throwsA(isA<LoopV2SessionStorageException>()),
      );
      expect(secure.writes, 0);
    },
  );

  test(
    'malformed critical state fails closed instead of rotating IDs',
    () async {
      final secure = _MemorySecureStore()
        ..values['loop.backend.v2.device_id'] = 'not-a-device-id';
      final store = FlutterSecureLoopV2SessionJournalStore(
        secureStorage: secure,
      );

      await expectLater(
        store.loadOrCreateDeviceId(),
        throwsA(isA<LoopV2SessionStorageException>()),
      );
      expect(secure.writes, 0);
    },
  );

  test(
    'unknown journal fields and impossible logout state fail closed',
    () async {
      final partition = LoopV2OwnerPartition.fromPrincipal(principal);
      for (final raw in <String>[
        '{"schemaVersion":1,"pendingBootstrap":null,"activeSession":null,"pendingLogout":null,"bootstrapRetirementRequested":false,"revocationUnconfirmed":false,"future":true}',
        '{"schemaVersion":1,"pendingBootstrap":null,"activeSession":null,"pendingLogout":{"deviceId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","idempotencyKey":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","clientVersion":"0.1.0+1","platform":"android","contractVersion":"2.0"},"bootstrapRetirementRequested":false,"revocationUnconfirmed":false}',
        '{"schemaVersion":1,"pendingBootstrap":null,"activeSession":null,"pendingLogout":null,"bootstrapRetirementRequested":true,"revocationUnconfirmed":false}',
      ]) {
        final secure = _MemorySecureStore()
          ..values['loop.backend.v2.owner.$partition'] = raw;
        final store = FlutterSecureLoopV2SessionJournalStore(
          secureStorage: secure,
        );

        await expectLater(
          store.readOwnerJournal(partition),
          throwsA(isA<LoopV2SessionStorageException>()),
        );
      }
    },
  );
}

final class _MemorySecureStore implements LoopV2SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};
  int writes = 0;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    writes += 1;
    values[key] = value;
  }
}
