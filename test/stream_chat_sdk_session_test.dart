import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_sdk_session.dart';
import 'package:loop_mobile/integrations/communication/stream_communication_gateway.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:stream_chat_persistence/stream_chat_persistence.dart';

void main() {
  test('official SDK session is created lazily with persistence attached', () {
    final source = _MutableSessionSource();
    final session = StreamChatSdkSession.create(
      apiKey: 'public-stream-api-key',
      source: source,
    );
    addTearDown(session.dispose);

    expect(session.client, isA<StreamChatClient>());
    expect(
      session.client.chatPersistenceClient,
      isA<StreamChatPersistenceClient>(),
    );
    expect(source.identityCalls, 0);
    expect(source.tokenUserIds, isEmpty);
  });

  test('blank API key is rejected before an SDK client is created', () {
    expect(
      () => StreamChatSdkSession.create(
        apiKey: '  ',
        source: _MutableSessionSource(),
      ),
      throwsArgumentError,
    );
  });

  test(
    'missing server identity stays unavailable without connecting',
    () async {
      final client = _FakeStreamChatClientPort();
      final source = _MutableSessionSource();
      final authorizer = StreamChatSdkSessionAuthorizer(
        client: client,
        source: source,
      );
      await authorizer.synchronizePrincipal('did:privy:test');

      final result = await authorizer.authorize();

      expect(result, StreamSessionAuthorization.unavailable);
      expect(source.identityCalls, 1);
      expect(source.tokenUserIds, isEmpty);
      expect(client.connectCalls, 0);
      expect(client.disconnectCalls, 0);
    },
  );

  test('server-derived user id is used for SDK token refresh', () async {
    final client = _FakeStreamChatClientPort();
    final source = _MutableSessionSource(
      identity: const StreamChatIdentity(
        userId: 'loop-user-42',
        displayName: 'Loop user',
      ),
      token: 'short-lived-stream-token',
    );
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: source,
    );
    await authorizer.synchronizePrincipal('did:privy:test');

    final result = await authorizer.authorize();

    expect(result, StreamSessionAuthorization.authorized);
    expect(client.connectCalls, 1);
    expect(client.connectedUserId, 'loop-user-42');
    expect(client.connectedIdentities.single.userId, 'loop-user-42');
    expect(source.tokenUserIds, <String>['loop-user-42']);
    expect(client.receivedTokens, <String>['short-lived-stream-token']);
  });

  test('concurrent authorization is single-flight', () async {
    final connectGate = Completer<void>();
    final connectStarted = Completer<void>();
    final client = _FakeStreamChatClientPort(
      connectGate: connectGate,
      connectStarted: connectStarted,
    );
    final source = _MutableSessionSource(
      identity: const StreamChatIdentity(userId: 'loop-user-42'),
    );
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: source,
    );
    await authorizer.synchronizePrincipal('did:privy:test');

    final first = authorizer.authorize();
    await connectStarted.future;
    final second = authorizer.authorize();
    connectGate.complete();

    expect(
      await Future.wait(<Future<StreamSessionAuthorization>>[first, second]),
      <StreamSessionAuthorization>[
        StreamSessionAuthorization.authorized,
        StreamSessionAuthorization.authorized,
      ],
    );
    expect(source.identityCalls, 1);
    expect(source.tokenUserIds, <String>['loop-user-42']);
    expect(client.connectCalls, 1);
  });

  test(
    'clear invalidates an in-flight authorization before it can succeed',
    () async {
      final connectGate = Completer<void>();
      final connectStarted = Completer<void>();
      final client = _FakeStreamChatClientPort(
        connectGate: connectGate,
        connectStarted: connectStarted,
      );
      final source = _MutableSessionSource(
        identity: const StreamChatIdentity(userId: 'loop-user-42'),
      );
      final authorizer = StreamChatSdkSessionAuthorizer(
        client: client,
        source: source,
      );
      await authorizer.synchronizePrincipal('did:privy:test');

      final authorization = authorizer.authorize();
      await connectStarted.future;
      final clearing = authorizer.clearSession();

      expect(
        await authorization.timeout(const Duration(seconds: 1)),
        StreamSessionAuthorization.unavailable,
      );
      await clearing;
      expect(client.connectedUserId, isNull);
      expect(connectGate.isCompleted, isFalse);
      expect(client.disposeCalls, 1);
      expect(client.disconnectCalls, 1);
      expect(client.flushRequests, <bool>[false]);
    },
  );

  test('dispose invalidates an in-flight authorization exactly once', () async {
    final connectGate = Completer<void>();
    final connectStarted = Completer<void>();
    final client = _FakeStreamChatClientPort(
      connectGate: connectGate,
      connectStarted: connectStarted,
    );
    final source = _MutableSessionSource(
      identity: const StreamChatIdentity(userId: 'loop-user-42'),
    );
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: source,
    );
    await authorizer.synchronizePrincipal('did:privy:test');

    final authorization = authorizer.authorize();
    await connectStarted.future;
    final firstDispose = authorizer.dispose();
    final secondDispose = authorizer.dispose();

    expect(
      await authorization.timeout(const Duration(seconds: 1)),
      StreamSessionAuthorization.unavailable,
    );
    await Future.wait(<Future<void>>[firstDispose, secondDispose]);
    expect(client.disposeCalls, 1);
    expect(client.connectedUserId, isNull);
    expect(connectGate.isCompleted, isFalse);
  });

  test(
    'logout disconnects promptly while backend identity loading is stuck',
    () async {
      final client = _FakeStreamChatClientPort();
      final source = _MutableSessionSource(
        identity: const StreamChatIdentity(userId: 'loop-user-42'),
      );
      final authorizer = StreamChatSdkSessionAuthorizer(
        client: client,
        source: source,
      );
      await authorizer.synchronizePrincipal('did:privy:test');
      expect(
        await authorizer.authorize(),
        StreamSessionAuthorization.authorized,
      );

      final identityGate = Completer<void>();
      final identityStarted = Completer<void>();
      source
        ..identityGate = identityGate
        ..identityStarted = identityStarted;
      final authorization = authorizer.authorize();
      await identityStarted.future;

      await authorizer.clearSession().timeout(const Duration(seconds: 1));

      expect(client.connectedUserId, isNull);
      expect(client.disposeCalls, 1);
      expect(client.disconnectCalls, 0);
      expect(
        await authorization.timeout(const Duration(seconds: 1)),
        StreamSessionAuthorization.unavailable,
      );
      expect(identityGate.isCompleted, isFalse);
      identityGate.complete();
    },
  );

  test(
    'stuck token loading is invalidated without releasing its gate',
    () async {
      final staleGate = Completer<void>();
      final staleStarted = Completer<void>();
      final client = _FakeStreamChatClientPort();
      final source =
          _MutableSessionSource(
              identity: const StreamChatIdentity(userId: 'loop-user-a'),
            )
            ..tokenGate = staleGate
            ..tokenStarted = staleStarted;
      final authorizer = StreamChatSdkSessionAuthorizer(
        client: client,
        source: source,
        initialPrincipalKey: 'did:privy:a',
      );

      final staleAuthorization = authorizer.authorize();
      await staleStarted.future;
      await authorizer.clearSession().timeout(const Duration(seconds: 1));

      expect(
        await staleAuthorization.timeout(const Duration(seconds: 1)),
        StreamSessionAuthorization.unavailable,
      );
      expect(staleGate.isCompleted, isFalse);
      expect(client.connectedUserId, isNull);
    },
  );

  test(
    'principal-bound sessions isolate an abandoned SDK connection',
    () async {
      final staleGate = Completer<void>();
      final staleStarted = Completer<void>();
      final clientA = _FakeStreamChatClientPort(
        connectGate: staleGate,
        connectStarted: staleStarted,
      );
      final authorizerA = StreamChatSdkSessionAuthorizer(
        client: clientA,
        source: _MutableSessionSource(
          identity: const StreamChatIdentity(userId: 'loop-user-a'),
        ),
        initialPrincipalKey: 'did:privy:a',
      );
      final staleAuthorization = authorizerA.authorize();
      await staleStarted.future;

      await authorizerA.dispose().timeout(const Duration(seconds: 1));
      final clientB = _FakeStreamChatClientPort();
      final authorizerB = StreamChatSdkSessionAuthorizer(
        client: clientB,
        source: _MutableSessionSource(
          identity: const StreamChatIdentity(userId: 'loop-user-b'),
        ),
        initialPrincipalKey: 'did:privy:b',
      );

      expect(
        await staleAuthorization.timeout(const Duration(seconds: 1)),
        StreamSessionAuthorization.unavailable,
      );
      expect(
        await authorizerB.authorize().timeout(const Duration(seconds: 1)),
        StreamSessionAuthorization.authorized,
      );
      expect(staleGate.isCompleted, isFalse);
      expect(clientB.connectedUserId, 'loop-user-b');

      // Match Stream's non-cancellable initialization behavior: an abandoned
      // Future may finish late, but its retirement reaper disconnects it again.
      staleGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(clientA.connectedUserId, isNull);
      expect(clientA.disconnectCalls, 2);
      expect(clientB.connectedUserId, 'loop-user-b');
    },
  );

  test(
    'a different principal retires a bound client instead of reusing it',
    () async {
      final client = _FakeStreamChatClientPort();
      final authorizer = StreamChatSdkSessionAuthorizer(
        client: client,
        source: _MutableSessionSource(
          identity: const StreamChatIdentity(userId: 'loop-user-a'),
        ),
        initialPrincipalKey: 'did:privy:a',
      );
      expect(
        await authorizer.authorize(),
        StreamSessionAuthorization.authorized,
      );

      await authorizer.synchronizePrincipal('did:privy:b');

      expect(client.disposeCalls, 1);
      expect(
        await authorizer.authorize(),
        StreamSessionAuthorization.unavailable,
      );
      expect(client.connectCalls, 1);
    },
  );

  test('an already connected user is not connected twice', () async {
    final client = _FakeStreamChatClientPort();
    final source = _MutableSessionSource(
      identity: const StreamChatIdentity(userId: 'loop-user-42'),
    );
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: source,
    );
    await authorizer.synchronizePrincipal('did:privy:test');

    expect(await authorizer.authorize(), StreamSessionAuthorization.authorized);
    expect(await authorizer.authorize(), StreamSessionAuthorization.authorized);

    expect(source.identityCalls, 2);
    expect(client.connectCalls, 1);
    expect(source.tokenUserIds, <String>['loop-user-42']);
  });

  test(
    'a changed backend Stream user fails closed for the bound principal',
    () async {
      final client = _FakeStreamChatClientPort();
      final source = _MutableSessionSource(
        identity: const StreamChatIdentity(userId: 'loop-user-42'),
      );
      final authorizer = StreamChatSdkSessionAuthorizer(
        client: client,
        source: source,
      );
      await authorizer.synchronizePrincipal('did:privy:test');

      expect(
        await authorizer.authorize(),
        StreamSessionAuthorization.authorized,
      );
      source.identity = const StreamChatIdentity(userId: 'loop-user-84');
      expect(
        await authorizer.authorize(),
        StreamSessionAuthorization.unavailable,
      );

      expect(client.connectCalls, 1);
      expect(client.disconnectCalls, 1);
      expect(client.flushRequests, <bool>[false]);
      expect(client.connectedUserId, isNull);
      expect(source.tokenUserIds, <String>['loop-user-42']);
    },
  );

  test('logout identity clears the active SDK user and fails closed', () async {
    final client = _FakeStreamChatClientPort();
    final source = _MutableSessionSource(
      identity: const StreamChatIdentity(userId: 'loop-user-42'),
    );
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: source,
    );
    await authorizer.synchronizePrincipal('did:privy:test');

    expect(await authorizer.authorize(), StreamSessionAuthorization.authorized);
    source.identity = null;

    expect(
      await authorizer.authorize(),
      StreamSessionAuthorization.unavailable,
    );
    expect(client.connectedUserId, isNull);
    expect(client.disconnectCalls, 1);
    expect(client.flushRequests, <bool>[false]);
  });

  test('blank token fails closed and cleans partial SDK state', () async {
    final client = _FakeStreamChatClientPort();
    final source = _MutableSessionSource(
      identity: const StreamChatIdentity(userId: 'loop-user-42'),
      token: '   ',
    );
    final authorizer = StreamChatSdkSessionAuthorizer(
      client: client,
      source: source,
    );
    await authorizer.synchronizePrincipal('did:privy:test');

    expect(
      await authorizer.authorize(),
      StreamSessionAuthorization.unavailable,
    );
    expect(client.connectCalls, 1);
    expect(client.disconnectCalls, 1);
    expect(client.connectedUserId, isNull);
  });

  test(
    'dispose disconnects the client and blocks later authorization',
    () async {
      final client = _FakeStreamChatClientPort();
      final source = _MutableSessionSource(
        identity: const StreamChatIdentity(userId: 'loop-user-42'),
      );
      final authorizer = StreamChatSdkSessionAuthorizer(
        client: client,
        source: source,
      );
      await authorizer.synchronizePrincipal('did:privy:test');

      expect(
        await authorizer.authorize(),
        StreamSessionAuthorization.authorized,
      );
      await authorizer.dispose();

      expect(client.disposeCalls, 1);
      expect(client.connectedUserId, isNull);
      expect(
        await authorizer.authorize(),
        StreamSessionAuthorization.unavailable,
      );
      expect(client.connectCalls, 1);
    },
  );
}

class _MutableSessionSource implements StreamChatSessionSource {
  _MutableSessionSource({this.identity, this.token = 'stream-token'});

  StreamChatIdentity? identity;
  String token;
  int identityCalls = 0;
  final List<String> tokenUserIds = <String>[];
  Completer<void>? identityGate;
  Completer<void>? identityStarted;
  Completer<void>? tokenGate;
  Completer<void>? tokenStarted;

  @override
  Future<StreamChatIdentity?> loadIdentity() async {
    identityCalls += 1;
    final started = identityStarted;
    if (started != null && !started.isCompleted) started.complete();
    await identityGate?.future;
    return identity;
  }

  @override
  Future<String> loadToken(String userId) async {
    tokenUserIds.add(userId);
    final started = tokenStarted;
    if (started != null && !started.isCompleted) started.complete();
    await tokenGate?.future;
    return token;
  }
}

class _FakeStreamChatClientPort implements StreamChatClientPort {
  _FakeStreamChatClientPort({this.connectGate, this.connectStarted});

  Completer<void>? connectGate;
  final Completer<void>? connectStarted;
  final List<StreamChatIdentity> connectedIdentities = <StreamChatIdentity>[];
  final List<String> receivedTokens = <String>[];
  final List<bool> flushRequests = <bool>[];
  int connectCalls = 0;
  int disconnectCalls = 0;
  int disposeCalls = 0;

  @override
  String? connectedUserId;

  @override
  Future<void> connect({
    required StreamChatIdentity identity,
    required Future<String> Function(String userId) tokenProvider,
  }) async {
    connectCalls += 1;
    connectedIdentities.add(identity);
    final token = await tokenProvider(identity.userId);
    receivedTokens.add(token);
    final started = connectStarted;
    if (started != null && !started.isCompleted) started.complete();
    final gate = connectGate;
    await gate?.future;
    connectedUserId = identity.userId;
  }

  @override
  Future<void> disconnect({required bool flushLocalPersistence}) async {
    disconnectCalls += 1;
    flushRequests.add(flushLocalPersistence);
    connectedUserId = null;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    connectedUserId = null;
  }
}
