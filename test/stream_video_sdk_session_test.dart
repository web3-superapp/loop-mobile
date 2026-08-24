import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/communication/stream_video_sdk_session.dart';

void main() {
  const identity = StreamVideoIdentity(
    userId: 'stream-user-42',
    displayName: 'Loop User',
  );

  test('construction performs no identity, token, or client work', () {
    final source = _RecordingSource(identity: identity);
    final factory = _RecordingClientFactory();

    StreamVideoSdkSession(
      apiKey: 'public-key',
      source: source,
      clientFactory: factory,
      initialPrincipalKey: 'privy-principal-a',
    );

    expect(source.identityCalls, 0);
    expect(source.tokenCalls, 0);
    expect(factory.createCalls, 0);
  });

  test(
    'missing principal fails closed before loading backend identity',
    () async {
      final source = _RecordingSource(identity: identity);
      final factory = _RecordingClientFactory();
      final session = StreamVideoSdkSession(
        apiKey: 'public-key',
        source: source,
        clientFactory: factory,
      );
      addTearDown(session.dispose);

      expect(
        await session.authorize(),
        StreamVideoSessionAuthorization.unavailable,
      );
      expect(source.identityCalls, 0);
      expect(factory.createCalls, 0);
    },
  );

  test('missing backend identity never constructs the SDK client', () async {
    final source = _RecordingSource(identity: null);
    final factory = _RecordingClientFactory();
    final session = StreamVideoSdkSession(
      apiKey: 'public-key',
      source: source,
      clientFactory: factory,
      initialPrincipalKey: 'privy-principal-a',
    );
    addTearDown(session.dispose);

    expect(
      await session.authorize(),
      StreamVideoSessionAuthorization.unavailable,
    );
    expect(source.identityCalls, 1);
    expect(source.tokenCalls, 0);
    expect(factory.createCalls, 0);
  });

  test(
    'authorization creates one delayed client and uses backend token',
    () async {
      final source = _RecordingSource(identity: identity, token: 'short-token');
      final factory = _RecordingClientFactory();
      final session = StreamVideoSdkSession(
        apiKey: 'public-key',
        source: source,
        clientFactory: factory,
        initialPrincipalKey: 'privy-principal-a',
      );
      addTearDown(session.dispose);

      expect(
        await session.authorize(),
        StreamVideoSessionAuthorization.authorized,
      );
      expect(factory.createCalls, 1);
      expect(factory.lastApiKey, 'public-key');
      expect(factory.lastIdentity, same(identity));
      expect(factory.lastInitialToken, 'short-token');
      expect(factory.clients.single.connectCalls, 1);
      expect(source.identityCalls, 1);
      expect(source.requestedUserIds, <String>['stream-user-42']);
    },
  );

  test('concurrent authorization is single-flight', () async {
    final identityGate = Completer<StreamVideoIdentity?>();
    final source = _RecordingSource(identityFuture: identityGate.future);
    final factory = _RecordingClientFactory();
    final session = StreamVideoSdkSession(
      apiKey: 'public-key',
      source: source,
      clientFactory: factory,
      initialPrincipalKey: 'privy-principal-a',
    );
    addTearDown(session.dispose);

    final first = session.authorize();
    final second = session.authorize();
    identityGate.complete(identity);

    expect(
      await Future.wait(<Future<StreamVideoSessionAuthorization>>[
        first,
        second,
      ]),
      everyElement(StreamVideoSessionAuthorization.authorized),
    );
    expect(source.identityCalls, 1);
    expect(factory.createCalls, 1);
  });

  test(
    'logout invalidates a stuck identity request without making a client',
    () async {
      final identityGate = Completer<StreamVideoIdentity?>();
      final source = _RecordingSource(identityFuture: identityGate.future);
      final factory = _RecordingClientFactory();
      final session = StreamVideoSdkSession(
        apiKey: 'public-key',
        source: source,
        clientFactory: factory,
        initialPrincipalKey: 'privy-principal-a',
      );
      addTearDown(session.dispose);

      final authorization = session.authorize();
      await _waitUntil(() => source.identityCalls == 1);
      await session.synchronizePrincipal(null);

      expect(
        await authorization.timeout(const Duration(seconds: 1)),
        StreamVideoSessionAuthorization.unavailable,
      );
      expect(factory.createCalls, 0);
    },
  );

  test(
    'logout retires a client even when SDK connect never completes',
    () async {
      final connectGate = Completer<bool>();
      final source = _RecordingSource(identity: identity);
      final factory = _RecordingClientFactory(
        connectFuture: connectGate.future,
      );
      final session = StreamVideoSdkSession(
        apiKey: 'public-key',
        source: source,
        clientFactory: factory,
        initialPrincipalKey: 'privy-principal-a',
      );
      addTearDown(() {
        if (!connectGate.isCompleted) connectGate.complete(false);
        return session.dispose();
      });

      final authorization = session.authorize();
      await _waitUntil(() => factory.clients.isNotEmpty);
      await session.synchronizePrincipal(null);

      expect(
        await authorization.timeout(const Duration(seconds: 1)),
        StreamVideoSessionAuthorization.unavailable,
      );
      connectGate.complete(true);
      await _waitUntil(() => factory.clients.single.disconnectCalls == 2);
      expect(factory.clients.single.connected, isFalse);
      expect(factory.clients.single.disconnectCalls, 2);
      expect(factory.clients.single.disposeCalls, 1);
    },
  );

  test(
    'logout invalidates a stuck initial token before SDK construction',
    () async {
      final tokenGate = Completer<String>();
      final source = _RecordingSource(
        identity: identity,
        tokenFuture: tokenGate.future,
      );
      final factory = _RecordingClientFactory();
      final session = StreamVideoSdkSession(
        apiKey: 'public-key',
        source: source,
        clientFactory: factory,
        initialPrincipalKey: 'privy-principal-a',
      );
      addTearDown(session.dispose);

      final authorization = session.authorize();
      await _waitUntil(() => source.tokenCalls == 1);
      await session.synchronizePrincipal(null);

      expect(
        await authorization.timeout(const Duration(seconds: 1)),
        StreamVideoSessionAuthorization.unavailable,
      );
      expect(factory.createCalls, 0);
    },
  );

  test('token requests for a different Stream user fail closed', () async {
    final source = _RecordingSource(identity: identity);
    final factory = _RecordingClientFactory(
      requestedTokenUserId: 'unexpected-user',
    );
    final session = StreamVideoSdkSession(
      apiKey: 'public-key',
      source: source,
      clientFactory: factory,
      initialPrincipalKey: 'privy-principal-a',
    );
    addTearDown(session.dispose);

    expect(
      await session.authorize(),
      StreamVideoSessionAuthorization.unavailable,
    );
    expect(source.tokenCalls, 1);
    expect(factory.clients.single.disposeCalls, greaterThanOrEqualTo(1));
  });

  test('a different principal retires the bound client', () async {
    final source = _RecordingSource(identity: identity);
    final factory = _RecordingClientFactory();
    final session = StreamVideoSdkSession(
      apiKey: 'public-key',
      source: source,
      clientFactory: factory,
      initialPrincipalKey: 'privy-principal-a',
    );
    addTearDown(session.dispose);

    expect(
      await session.authorize(),
      StreamVideoSessionAuthorization.authorized,
    );
    await session.synchronizePrincipal('privy-principal-b');

    expect(factory.clients.single.disposeCalls, greaterThanOrEqualTo(1));
    expect(
      await session.authorize(),
      StreamVideoSessionAuthorization.unavailable,
    );
  });
}

final class _RecordingSource implements StreamVideoSessionSource {
  _RecordingSource({
    this.identity,
    this.identityFuture,
    this.tokenFuture,
    this.token = 'short-token',
  });

  final StreamVideoIdentity? identity;
  final Future<StreamVideoIdentity?>? identityFuture;
  final Future<String>? tokenFuture;
  final String token;
  int identityCalls = 0;
  int tokenCalls = 0;
  final List<String> requestedUserIds = <String>[];

  @override
  Future<StreamVideoIdentity?> loadIdentity() {
    identityCalls += 1;
    return identityFuture ?? Future<StreamVideoIdentity?>.value(identity);
  }

  @override
  Future<String> loadToken(String userId) async {
    tokenCalls += 1;
    requestedUserIds.add(userId);
    return tokenFuture ?? token;
  }
}

final class _RecordingClientFactory implements StreamVideoClientFactory {
  _RecordingClientFactory({this.connectFuture, this.requestedTokenUserId});

  final Future<bool>? connectFuture;
  final String? requestedTokenUserId;
  int createCalls = 0;
  String? lastApiKey;
  StreamVideoIdentity? lastIdentity;
  String? lastInitialToken;
  final List<_RecordingClient> clients = <_RecordingClient>[];

  @override
  StreamVideoClientPort create({
    required String apiKey,
    required StreamVideoIdentity identity,
    required String initialToken,
    required Future<String> Function(String userId) tokenProvider,
  }) {
    createCalls += 1;
    lastApiKey = apiKey;
    lastIdentity = identity;
    lastInitialToken = initialToken;
    final client = _RecordingClient(
      userId: identity.userId,
      tokenProvider: tokenProvider,
      requestedTokenUserId: requestedTokenUserId,
      connectFuture: connectFuture,
    );
    clients.add(client);
    return client;
  }
}

final class _RecordingClient implements StreamVideoClientPort {
  _RecordingClient({
    required this.userId,
    required this.tokenProvider,
    required this.connectFuture,
    this.requestedTokenUserId,
  });

  @override
  final String userId;
  final Future<String> Function(String userId) tokenProvider;
  final Future<bool>? connectFuture;
  final String? requestedTokenUserId;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int disposeCalls = 0;
  bool connected = false;

  @override
  Future<bool> connect() async {
    connectCalls += 1;
    final refreshUserId = requestedTokenUserId;
    if (refreshUserId != null) await tokenProvider(refreshUserId);
    final result = await (connectFuture ?? Future<bool>.value(true));
    connected = result;
    return result;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    connected = false;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
  }
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}
