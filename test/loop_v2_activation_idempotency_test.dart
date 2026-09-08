import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/presentation/profile_models.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/dio_loop_v2_profile_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/loop_v2_activation_store.dart';
import 'package:loop_mobile/integrations/backend/v2/profile/loop_v2_profile_api.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_models.dart';
import 'package:uuid/uuid.dart';

void main() {
  const principal = 'did:privy:owner-1';
  const clientMetadata = LoopV2ClientMetadata(
    clientVersion: '0.1.0+1',
    platform: LoopV2Platform.android,
  );
  const deviceId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

  ProfileResource activated({
    String alias = 'Alice',
    List<ProfileInterest> interests = const <ProfileInterest>[
      ProfileInterest.meme,
      ProfileInterest.ai,
    ],
  }) => ProfileResource(
    version: 1,
    values: ProfileValues(
      alias: alias,
      avatarRef: 'avatar:preset/people-03',
      interests: interests,
    ),
    updatedAt: DateTime.utc(2026, 9, 7, 1),
    loopId: 'LOOP-7HJKMNPQ',
    profileStatus: ProfileStatus.active,
    activatedAt: DateTime.utc(2026, 9, 7, 1),
  );

  test('a timed-out retry replays the original key and body', () async {
    final api = _RecordingApi(<Object>[
      const LoopBackendFailure(LoopBackendFailureKind.timeout),
      activated(),
    ]);
    final store = _MemoryActivationStore(deviceId);
    final gateway = DioLoopV2ProfileActivationGateway(
      principalKey: principal,
      api: api,
      clientMetadata: clientMetadata,
      store: store,
      session: _session(),
    );

    await expectLater(
      gateway.activate(
        alias: 'Alice',
        avatarRef: 'avatar:preset/people-03',
        interests: const <ProfileInterest>[
          ProfileInterest.meme,
          ProfileInterest.ai,
        ],
      ),
      throwsA(
        isA<ProfileGatewayException>().having(
          (error) => error.kind,
          'kind',
          ProfileGatewayFailureKind.offline,
        ),
      ),
    );
    // The record survives the failure so the retry can reuse it.
    expect(store.record, isNotNull);

    final resource = await gateway.activate(
      alias: 'Alice',
      avatarRef: 'avatar:preset/people-03',
      interests: const <ProfileInterest>[
        ProfileInterest.meme,
        ProfileInterest.ai,
      ],
    );

    expect(resource.profileStatus, ProfileStatus.active);
    expect(api.commands.length, 2);
    expect(api.commands[0].idempotencyKey, api.commands[1].idempotencyKey);
    expect(api.requests[0], api.requests[1]);
    expect(api.requests[1].interests, <ProfileInterest>[
      ProfileInterest.meme,
      ProfileInterest.ai,
    ]);
    // A confirmed activation clears the journal.
    expect(store.record, isNull);
  });

  test(
    'the same interests in a new order stay one logical activation',
    () async {
      final api = _RecordingApi(<Object>[
        const LoopBackendFailure(LoopBackendFailureKind.timeout),
        activated(),
      ]);
      final store = _MemoryActivationStore(deviceId);
      final gateway = DioLoopV2ProfileActivationGateway(
        principalKey: principal,
        api: api,
        clientMetadata: clientMetadata,
        store: store,
        session: _session(),
      );

      await expectLater(
        gateway.activate(
          alias: 'Alice',
          avatarRef: null,
          interests: const <ProfileInterest>[
            ProfileInterest.meme,
            ProfileInterest.ai,
          ],
        ),
        throwsA(isA<ProfileGatewayException>()),
      );
      await gateway.activate(
        alias: 'Alice',
        avatarRef: null,
        interests: const <ProfileInterest>[
          ProfileInterest.ai,
          ProfileInterest.meme,
        ],
      );

      // A reordered list is a different body, so it must not reuse the key that
      // was already dispatched with the original order.
      expect(
        api.commands[0].idempotencyKey,
        isNot(api.commands[1].idempotencyKey),
      );
      expect(api.requests[1].interests, <ProfileInterest>[
        ProfileInterest.ai,
        ProfileInterest.meme,
      ]);
    },
  );

  test(
    'a changed alias becomes a new key, never a conflicting replay',
    () async {
      final api = _RecordingApi(<Object>[
        const LoopBackendFailure(LoopBackendFailureKind.timeout),
        activated(alias: 'Bob'),
      ]);
      final store = _MemoryActivationStore(deviceId);
      final gateway = DioLoopV2ProfileActivationGateway(
        principalKey: principal,
        api: api,
        clientMetadata: clientMetadata,
        store: store,
        session: _session(),
      );

      await expectLater(
        gateway.activate(
          alias: 'Alice',
          avatarRef: null,
          interests: const <ProfileInterest>[],
        ),
        throwsA(isA<ProfileGatewayException>()),
      );
      await gateway.activate(
        alias: 'Bob',
        avatarRef: null,
        interests: const <ProfileInterest>[],
      );

      expect(
        api.commands[0].idempotencyKey,
        isNot(api.commands[1].idempotencyKey),
      );
      expect(api.requests[0].alias, 'Alice');
      expect(api.requests[1].alias, 'Bob');
    },
  );

  test(
    'a rejected alias clears the record so the fix is not replayed',
    () async {
      final api = _RecordingApi(<Object>[
        const LoopBackendFailure(
          LoopBackendFailureKind.invalidRequest,
          statusCode: 422,
          code: 'ALIAS_RESERVED',
        ),
      ]);
      final store = _MemoryActivationStore(deviceId);
      final gateway = DioLoopV2ProfileActivationGateway(
        principalKey: principal,
        api: api,
        clientMetadata: clientMetadata,
        store: store,
        session: _session(),
      );

      await expectLater(
        gateway.activate(
          alias: 'admin',
          avatarRef: null,
          interests: const <ProfileInterest>[],
        ),
        throwsA(
          isA<ProfileGatewayException>().having(
            (error) => error.kind,
            'kind',
            ProfileGatewayFailureKind.aliasReserved,
          ),
        ),
      );
      expect(store.record, isNull);
    },
  );

  test(
    'an idempotency conflict resets the key instead of replaying it',
    () async {
      final api = _RecordingApi(<Object>[
        const LoopBackendFailure(
          LoopBackendFailureKind.invalidRequest,
          statusCode: 409,
          code: 'IDEMPOTENCY_CONFLICT',
        ),
        activated(),
      ]);
      final store = _MemoryActivationStore(deviceId);
      final gateway = DioLoopV2ProfileActivationGateway(
        principalKey: principal,
        api: api,
        clientMetadata: clientMetadata,
        store: store,
        session: _session(),
      );

      await expectLater(
        gateway.activate(
          alias: 'Alice',
          avatarRef: null,
          interests: const <ProfileInterest>[],
        ),
        throwsA(
          isA<ProfileGatewayException>().having(
            (error) => error.kind,
            'kind',
            ProfileGatewayFailureKind.idempotencyConflict,
          ),
        ),
      );
      // The recorded key is already bound to different bytes on the server, so
      // replaying it could only conflict again.
      expect(store.record, isNull);

      await gateway.activate(
        alias: 'Alice',
        avatarRef: null,
        interests: const <ProfileInterest>[],
      );
      expect(
        api.commands[0].idempotencyKey,
        isNot(api.commands[1].idempotencyKey),
      );
    },
  );

  test('a non-preset avatar reference is never submitted', () async {
    final api = _RecordingApi(<Object>[activated()]);
    final store = _MemoryActivationStore(deviceId);
    final gateway = DioLoopV2ProfileActivationGateway(
      principalKey: principal,
      api: api,
      clientMetadata: clientMetadata,
      store: store,
      session: _session(),
    );

    await gateway.activate(
      alias: 'Alice',
      // A value a V1 row could hold. It is readable, never submittable.
      avatarRef: 'avatar:legacy/upload-9f2c',
      interests: const <ProfileInterest>[],
    );

    expect(api.requests.single.avatarRef, isNull);
  });

  test('an alias outside the contract never reaches the transport', () async {
    final api = _RecordingApi(<Object>[activated()]);
    final store = _MemoryActivationStore(deviceId);
    final gateway = DioLoopV2ProfileActivationGateway(
      principalKey: principal,
      api: api,
      clientMetadata: clientMetadata,
      store: store,
      session: _session(),
    );

    await expectLater(
      gateway.activate(
        alias: '   ',
        avatarRef: null,
        interests: const <ProfileInterest>[],
      ),
      throwsA(
        isA<ProfileGatewayException>().having(
          (error) => error.kind,
          'kind',
          ProfileGatewayFailureKind.invalidData,
        ),
      ),
    );
    expect(api.commands, isEmpty);
    expect(store.record, isNull);
  });
}

LoopAuthenticatedSession _session() {
  final bootstrapSession = LoopBootstrapSession(
    principalKey: 'did:privy:owner-1',
    accessTokens: _StaticAccessTokens(),
    repository: _BootstrapRepository(),
  );
  return LoopAuthenticatedSession(
    principalKey: 'did:privy:owner-1',
    bootstrapSession: bootstrapSession,
    accessTokens: _StaticAccessTokens(),
  );
}

final class _StaticAccessTokens implements LoopBackendAccessTokenSource {
  @override
  Future<String> loadAccessToken() async => 'current-token';
}

final class _BootstrapRepository implements LoopBootstrapRepository {
  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    return const LoopBootstrapIdentity(
      loopUserId: '6d12a86e-4134-47e6-9312-c5ef75a30f55',
      streamUserId: 'loop_6d12a86e413447e69312c5ef75a30f55',
    );
  }
}

final class _RecordingApi implements LoopV2ProfileApi {
  _RecordingApi(this._outcomes);

  final List<Object> _outcomes;
  final List<LoopV2CommandMetadata> commands = <LoopV2CommandMetadata>[];
  final List<LoopV2ActivationRequest> requests = <LoopV2ActivationRequest>[];
  var _index = 0;

  @override
  Future<ProfileResource> activateLoopId({
    required String accessToken,
    required LoopV2CommandMetadata command,
    required LoopV2ActivationRequest request,
  }) async {
    commands.add(command);
    requests.add(request);
    final outcome = _outcomes[_index++];
    if (outcome is LoopBackendFailure) throw outcome;
    return outcome as ProfileResource;
  }

  @override
  Future<List<LoopV2AvatarPreset>> getAvatars() async =>
      throw UnimplementedError();

  @override
  Future<ProfileResource> getProfile({
    required String accessToken,
    required String clientVersion,
  }) async => throw UnimplementedError();

  @override
  Future<ProfileResource> replaceProfile({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required ProfileValues values,
  }) async => throw UnimplementedError();

  @override
  Future<PrivacyResource> getPrivacy({
    required String accessToken,
    required String clientVersion,
  }) async => throw UnimplementedError();

  @override
  Future<PrivacyResource> replacePrivacy({
    required String accessToken,
    required String clientVersion,
    required int expectedVersion,
    required PrivacyValues values,
  }) async => throw UnimplementedError();
}

final class _MemoryActivationStore implements LoopV2ActivationJournalStore {
  _MemoryActivationStore(this._deviceId);

  final String _deviceId;
  LoopV2ActivationRecord? record;

  @override
  Future<String> loadOrCreateDeviceId() async => _deviceId;

  @override
  Future<LoopV2ActivationRecord?> readRecord(String ownerPartition) async {
    _requireUuid(ownerPartition);
    return record;
  }

  @override
  Future<void> writeRecord(
    String ownerPartition,
    LoopV2ActivationRecord value,
  ) async {
    _requireUuid(ownerPartition);
    record = value;
  }

  @override
  Future<void> deleteRecord(String ownerPartition) async {
    _requireUuid(ownerPartition);
    record = null;
  }

  void _requireUuid(String value) {
    if (!Uuid.isValidUUID(fromString: value)) {
      throw StateError('owner partition must be an opaque UUID');
    }
  }
}
