// When LOOP opens the Stream connection.
//
// C-30 (3) on the device: the owner signed in and the community still read
// 「在线 0 人」. Decision 0047 counts the official channel members that are
// connected to Stream at that moment, and LOOP only reached `authorize()`
// from a chat surface — so an owner who had not opened a chat was, correctly,
// counted as offline. The session now opens the connection.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_profile_screen.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_presence.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_sdk_session.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';

import 'support/community_test_harness.dart';

void main() {
  test('an accepted session opens the connection once', () async {
    final client = _FakeClientPort();
    final source = _FakeSessionSource(
      identity: const StreamChatIdentity(userId: 'stream-user-a'),
    );
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: source,
    );

    expect(
      await connectStreamChatForPresence(
        authorizer: authorizer,
        principalKey: 'did:privy:user-a',
      ),
      StreamSessionAuthorization.authorized,
    );

    expect(client.connectCalls, 1);
    expect(client.connectedUserId, 'stream-user-a');
    expect(source.tokenCalls, 1);
  });

  test('a chat page opened afterwards joins the same connection', () async {
    final client = _FakeClientPort();
    final source = _FakeSessionSource(
      identity: const StreamChatIdentity(userId: 'stream-user-a'),
    );
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: source,
    );

    await connectStreamChatForPresence(
      authorizer: authorizer,
      principalKey: 'did:privy:user-a',
    );
    // What `streamChatAuthorizationProvider` does when a chat surface mounts.
    await authorizer.synchronizePrincipal('did:privy:user-a');
    final second = await authorizer.authorize();

    expect(second, StreamSessionAuthorization.authorized);
    // One socket, one token: the per-minute token budget is not doubled by
    // connecting with the session instead of with the first chat page.
    expect(client.connectCalls, 1);
    expect(source.tokenCalls, 1);
  });

  test('no verified principal opens nothing and asks for nothing', () async {
    final client = _FakeClientPort();
    final source = _FakeSessionSource(
      identity: const StreamChatIdentity(userId: 'stream-user-a'),
    );
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: source,
    );

    expect(
      await connectStreamChatForPresence(
        authorizer: authorizer,
        principalKey: null,
      ),
      StreamSessionAuthorization.unavailable,
    );
    expect(
      await connectStreamChatForPresence(
        authorizer: null,
        principalKey: 'did:privy:user-a',
      ),
      StreamSessionAuthorization.unavailable,
    );

    expect(client.connectCalls, 0);
    expect(source.identityCalls, 0);
  });

  test('a refused connection is answered, never thrown', () async {
    final client = _FakeClientPort(failConnect: true);
    final source = _FakeSessionSource(
      identity: const StreamChatIdentity(userId: 'stream-user-a'),
    );
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: source,
    );

    expect(
      await connectStreamChatForPresence(
        authorizer: authorizer,
        principalKey: 'did:privy:user-a',
      ),
      StreamSessionAuthorization.unavailable,
    );
    expect(client.connectCalls, 1);
  });

  test('an identity that never answers is answered too', () async {
    final client = _FakeClientPort();
    final source = _FakeSessionSource(failIdentity: true);
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: source,
    );

    expect(
      await connectStreamChatForPresence(
        authorizer: authorizer,
        principalKey: 'did:privy:user-a',
      ),
      StreamSessionAuthorization.unavailable,
    );
    expect(client.connectCalls, 0);
  });

  testWidgets('a failed connection leaves the community page alone', (
    tester,
  ) async {
    // S11: the background connection reports to nobody. The online count is
    // the server's observation, read by this page's own gateway, so a refused
    // socket cannot turn the page offline or blank the number.
    final client = _FakeClientPort(failConnect: true);
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: _FakeSessionSource(
        identity: const StreamChatIdentity(userId: 'stream-user-a'),
      ),
    );
    unawaited(
      connectStreamChatForPresence(
        authorizer: authorizer,
        principalKey: 'did:privy:user-a',
      ),
    );

    await pumpCommunityPage(
      tester,
      const CommunityProfileScreen(communityId: testCommunityId),
      community: FakeCommunityGateway(
        detail: testDetail(
          onlineCount: CommunityOnlineCountObserved(
            count: 3,
            observedAt: DateTime.utc(2026, 9, 17, 2, 30),
            source: CommunityPresenceSource.streamMemberPresence,
          ),
        ),
      ),
    );

    expect(find.textContaining('3 在线'), findsOneWidget);
    expect(client.connectCalls, 1);
  });
}

final class _FakeSessionSource implements StreamChatSessionSource {
  _FakeSessionSource({this.identity, this.failIdentity = false});

  final StreamChatIdentity? identity;
  final bool failIdentity;
  int identityCalls = 0;
  int tokenCalls = 0;

  @override
  Future<StreamChatIdentity?> loadIdentity() async {
    identityCalls += 1;
    if (failIdentity) throw StateError('bootstrap unreachable');
    return identity;
  }

  @override
  Future<String> loadToken(String userId) async {
    tokenCalls += 1;
    return 'stream-token';
  }
}

final class _FakeClientPort implements StreamChatClientPort {
  _FakeClientPort({this.failConnect = false});

  final bool failConnect;
  int connectCalls = 0;

  @override
  String? connectedUserId;

  @override
  Future<void> connect({
    required StreamChatIdentity identity,
    required Future<String> Function(String userId) tokenProvider,
  }) async {
    connectCalls += 1;
    await tokenProvider(identity.userId);
    if (failConnect) throw StateError('websocket refused');
    connectedUserId = identity.userId;
  }

  @override
  Future<void> disconnect({required bool flushLocalPersistence}) async {
    connectedUserId = null;
  }

  @override
  Future<void> dispose() async => connectedUserId = null;
}
