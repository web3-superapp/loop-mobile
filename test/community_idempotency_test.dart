import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/v2/community/dio_loop_v2_community_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/community/loop_v2_community_api.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/dio_loop_v2_communication_gateway.dart';
import 'package:loop_mobile/integrations/backend/v2/communication/loop_v2_communication_api.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_command_keyring.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_contract.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_session.dart';

import 'support/communication_test_harness.dart';
import 'support/community_test_harness.dart';

void main() {
  test('a logical operation reserves exactly one canonical UUIDv4', () {
    final keyring = LoopV2CommandKeyring();
    final first = keyring.reserve('join:a');
    final second = keyring.reserve('join:a');

    expect(first, second);
    expect(LoopV2Contract.uuidV4Pattern.hasMatch(first), isTrue);
    expect(first, first.toLowerCase());

    // A different logical operation is never given the recorded key.
    expect(keyring.reserve('leave:a'), isNot(first));

    keyring.release('join:a');
    expect(keyring.peek('join:a'), isNull);
    expect(keyring.reserve('join:a'), isNot(first));
  });

  test(
    'an unresolved outcome replays the same key, a resolved one does not',
    () async {
      final api = _RecordingCommunityApi();
      final keyring = LoopV2CommandKeyring();
      final gateway = DioLoopV2CommunityGateway(
        api: api,
        clientMetadata: _metadata,
        session: _immediateSession(),
        keyring: keyring,
      );

      // A timeout leaves the outcome unknown: the retry must replay the key.
      api.failure = const LoopBackendFailure(LoopBackendFailureKind.timeout);
      await expectLater(
        gateway.join(testCommunityId),
        throwsA(isA<CommunityGatewayException>()),
      );
      final firstKey = api.keys.single;
      expect(keyring.peek('join:$testCommunityId'), firstKey);

      await expectLater(
        gateway.join(testCommunityId),
        throwsA(isA<CommunityGatewayException>()),
      );
      expect(api.keys, <String>[firstKey, firstKey]);

      // A terminal rejection resolves the operation: the key is released.
      api.failure = const LoopBackendFailure(
        LoopBackendFailureKind.invalidRequest,
        statusCode: 403,
        code: 'PERMISSION_DENIED',
      );
      await expectLater(
        gateway.join(testCommunityId),
        throwsA(isA<CommunityGatewayException>()),
      );
      expect(api.keys.last, firstKey);
      expect(keyring.peek('join:$testCommunityId'), isNull);

      // The next attempt is a new logical operation with a new key.
      api.failure = null;
      api.detail = testDetail();
      await gateway.join(testCommunityId);
      expect(api.keys.last, isNot(firstKey));
      expect(keyring.peek('join:$testCommunityId'), isNull);
    },
  );

  test('a cancelled or unparsable write keeps its key', () async {
    for (final unresolved in <LoopBackendFailure>[
      LoopBackendFailure(LoopBackendFailureKind.cancelled),
      LoopBackendFailure(LoopBackendFailureKind.invalidPayload),
    ]) {
      final api = _RecordingCommunityApi()..failure = unresolved;
      final keyring = LoopV2CommandKeyring();
      final gateway = DioLoopV2CommunityGateway(
        api: api,
        clientMetadata: _metadata,
        session: _immediateSession(),
        keyring: keyring,
      );

      await expectLater(
        gateway.join(testCommunityId),
        throwsA(isA<CommunityGatewayException>()),
      );
      // The server may already have applied the command, so the retry must
      // replay the recorded key rather than start a new operation.
      expect(
        keyring.peek('join:$testCommunityId'),
        api.keys.single,
        reason: '${unresolved.kind}',
      );
    }
  });

  test('a successful write releases its key', () async {
    final api = _RecordingCommunityApi()..detail = testDetail();
    final keyring = LoopV2CommandKeyring();
    final gateway = DioLoopV2CommunityGateway(
      api: api,
      clientMetadata: _metadata,
      session: _immediateSession(),
      keyring: keyring,
    );

    await gateway.setMuted(
      communityId: testCommunityId,
      publicProfileId: testMemberId,
      muted: true,
    );

    expect(keyring.peek('mute:$testCommunityId:$testMemberId:true'), isNull);
    expect(api.keys, hasLength(1));
    expect(LoopV2Contract.uuidV4Pattern.hasMatch(api.keys.single), isTrue);
  });

  test('a room that cannot be entered keeps the key that opened it', () async {
    // The room row commits before the provider calls, so a 201 can describe a
    // room nobody can be let into. The one recovery is the same key again:
    // the server repeats the provider half. A fresh key is refused, because
    // the room that cannot be entered is still the community's one live room.
    final api = _RecordingCommunicationApi();
    final keyring = LoopV2CommandKeyring();
    final gateway = DioLoopV2CommunicationGateway(
      api: api,
      clientMetadata: _metadata,
      session: _immediateSession(),
      keyring: keyring,
    );

    api.room = testVoiceRoomSnapshot(
      role: VoiceRoomRole.host,
      host: true,
      backstage: true,
      providerConfirmed: false,
      providerReason: 'STREAM_CALL_GO_LIVE_UNCONFIRMED',
    );
    await gateway.createRoom(testCommunityId);
    final key = api.keys.single;
    expect(keyring.peek('voice-room-open:$testCommunityId'), key);

    // The second attempt is the same command, not a second room.
    await gateway.createRoom(testCommunityId);
    expect(api.keys, <String>[key, key]);

    // A room the community can enter finishes the command.
    api.room = testVoiceRoomSnapshot(role: VoiceRoomRole.host, host: true);
    await gateway.createRoom(testCommunityId);
    expect(api.keys.last, key);
    expect(keyring.peek('voice-room-open:$testCommunityId'), isNull);
  });

  test('reads never reserve a key', () async {
    final api = _RecordingCommunityApi()..detail = testDetail();
    final keyring = LoopV2CommandKeyring();
    final gateway = DioLoopV2CommunityGateway(
      api: api,
      clientMetadata: _metadata,
      session: _immediateSession(),
      keyring: keyring,
    );

    await gateway.loadCommunity(testCommunityId);
    expect(api.keys, isEmpty);
  });
}

/// Records the key of every voice-room create without issuing a request.
final class _RecordingCommunicationApi implements LoopV2CommunicationApi {
  final List<String> keys = <String>[];
  VoiceRoomSnapshot? room;

  @override
  Future<VoiceRoomSnapshot> createVoiceRoom({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
  }) {
    keys.add(idempotencyKey);
    return Future<VoiceRoomSnapshot>.value(room!);
  }

  /// Every other endpoint of the module is out of this test's way.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _metadata = LoopV2ClientMetadata(
  clientVersion: '0.1.0+1',
  platform: LoopV2Platform.android,
);

LoopAuthenticatedSession _immediateSession() {
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

/// Records the idempotency key of every write without issuing a request.
final class _RecordingCommunityApi implements LoopV2CommunityApi {
  final List<String> keys = <String>[];
  LoopBackendFailure? failure;
  CommunityDetail? detail;
  CommunityMemberDirectory? directory;

  Future<T> _write<T>(String key, T? value) {
    keys.add(key);
    final error = failure;
    if (error != null) return Future<T>.error(error);
    if (value == null) {
      return Future<T>.error(
        const LoopBackendFailure(LoopBackendFailureKind.invalidPayload),
      );
    }
    return Future<T>.value(value);
  }

  Future<T> _read<T>(T? value) {
    final error = failure;
    if (error != null) return Future<T>.error(error);
    if (value == null) {
      return Future<T>.error(
        const LoopBackendFailure(LoopBackendFailureKind.invalidPayload),
      );
    }
    return Future<T>.value(value);
  }

  @override
  Future<CommunityHome> getHome({
    required String accessToken,
    required String clientVersion,
  }) => Future<CommunityHome>.error(
    const LoopBackendFailure(LoopBackendFailureKind.unavailable),
  );

  @override
  Future<CommunityDirectoryPage> listCommunities({
    required String accessToken,
    required String clientVersion,
    required CommunityDirectorySort sort,
    required CommunityVerificationFilter verification,
    required CommunityMembershipFilter membership,
    String? cursor,
  }) => Future<CommunityDirectoryPage>.error(
    const LoopBackendFailure(LoopBackendFailureKind.unavailable),
  );

  @override
  Future<CommunityDetail> createCommunity({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required CommunityApplication application,
  }) => _write(idempotencyKey, detail);

  @override
  Future<CommunityDetail> getCommunity({
    required String accessToken,
    required String clientVersion,
    required String communityId,
  }) => _read(detail);

  @override
  Future<CommunityDetail> patchCommunity({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required Map<String, Object?> body,
  }) => _write(idempotencyKey, detail);

  @override
  Future<CommunityDetail> join({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
  }) => _write(idempotencyKey, detail);

  @override
  Future<CommunityDetail> leave({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
  }) => _write(idempotencyKey, detail);

  @override
  Future<CommunityMemberDirectory> listMembers({
    required String accessToken,
    required String clientVersion,
    required String communityId,
    required CommunityMemberFilter role,
    String? q,
    String? cursor,
  }) => _read(directory);

  @override
  Future<CommunityMemberDirectory> changeMemberRole({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String publicProfileId,
    required CommunityRole role,
  }) => _write(idempotencyKey, directory ?? testDirectory());

  @override
  Future<CommunityMemberDirectory> setMuted({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String publicProfileId,
    required bool muted,
  }) => _write(idempotencyKey, directory ?? testDirectory());

  @override
  Future<CommunityMemberDirectory> setBanned({
    required String accessToken,
    required String clientVersion,
    required String idempotencyKey,
    required String communityId,
    required String publicProfileId,
    required bool banned,
  }) => _write(idempotencyKey, directory ?? testDirectory());

  @override
  Future<ReferralRules> getReferralRules({
    required String accessToken,
    required String clientVersion,
  }) => Future<ReferralRules>.error(
    const LoopBackendFailure(LoopBackendFailureKind.unavailable),
  );
}
