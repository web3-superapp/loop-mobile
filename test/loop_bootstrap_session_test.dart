import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';

void main() {
  const identity = LoopBootstrapIdentity(
    loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
    streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
  );

  test('authorizes once and exposes only the backend identity', () async {
    final tokens = _TokenSource(<Object>['first-token']);
    final repository = _RecordingRepository((_) async => identity);
    final session = LoopBootstrapSession(
      principalKey: 'did:privy:user-a',
      accessTokens: tokens,
      repository: repository,
    );

    expect(await session.authorize(), LoopBootstrapAuthorization.authorized);
    expect(await session.authorize(), LoopBootstrapAuthorization.authorized);
    expect(session.identity, same(identity));
    expect(tokens.calls, 1);
    expect(repository.tokens, <String>['first-token']);
  });

  test('one 401 obtains a fresh token and retries exactly once', () async {
    final tokens = _TokenSource(<Object>['first-token', 'second-token']);
    final repository = _RecordingRepository((token) async {
      if (token == 'first-token') {
        throw const LoopBackendFailure(
          LoopBackendFailureKind.authentication,
          statusCode: 401,
          code: 'invalid_access_token',
        );
      }
      return identity;
    });
    final session = LoopBootstrapSession(
      principalKey: 'did:privy:user-a',
      accessTokens: tokens,
      repository: repository,
    );

    expect(await session.authorize(), LoopBootstrapAuthorization.authorized);
    expect(tokens.calls, 2);
    expect(repository.tokens, <String>['first-token', 'second-token']);
  });

  test('a second 401 fails closed without requesting a third token', () async {
    final tokens = _TokenSource(<Object>[
      'first-token',
      'second-token',
      'must-not-be-requested',
    ]);
    final repository = _RecordingRepository((_) async {
      throw const LoopBackendFailure(
        LoopBackendFailureKind.authentication,
        statusCode: 401,
      );
    });
    final session = LoopBootstrapSession(
      principalKey: 'did:privy:user-a',
      accessTokens: tokens,
      repository: repository,
    );

    expect(await session.authorize(), LoopBootstrapAuthorization.unavailable);
    expect(session.identity, isNull);
    expect(tokens.calls, 2);
    expect(repository.tokens, <String>['first-token', 'second-token']);
  });

  test('503 and malformed tokens are never retried', () async {
    final unavailableTokens = _TokenSource(<Object>['first-token']);
    final unavailableRepository = _RecordingRepository((_) async {
      throw const LoopBackendFailure(
        LoopBackendFailureKind.unavailable,
        statusCode: 503,
      );
    });
    final unavailableSession = LoopBootstrapSession(
      principalKey: 'did:privy:user-a',
      accessTokens: unavailableTokens,
      repository: unavailableRepository,
    );

    expect(
      await unavailableSession.authorize(),
      LoopBootstrapAuthorization.unavailable,
    );
    expect(unavailableTokens.calls, 1);
    expect(unavailableRepository.tokens, <String>['first-token']);

    final blankTokens = _TokenSource(<Object>['  ']);
    final blankRepository = _RecordingRepository((_) async => identity);
    final blankSession = LoopBootstrapSession(
      principalKey: 'did:privy:user-a',
      accessTokens: blankTokens,
      repository: blankRepository,
    );

    expect(
      await blankSession.authorize(),
      LoopBootstrapAuthorization.unavailable,
    );
    expect(blankRepository.tokens, isEmpty);
  });

  test('concurrent authorization is single-flight', () async {
    final gate = Completer<LoopBootstrapIdentity>();
    final tokens = _TokenSource(<Object>['first-token']);
    final repository = _RecordingRepository((_) => gate.future);
    final session = LoopBootstrapSession(
      principalKey: 'did:privy:user-a',
      accessTokens: tokens,
      repository: repository,
    );

    final first = session.authorize();
    final second = session.authorize();
    await Future<void>.delayed(Duration.zero);
    expect(identical(first, second), isTrue);
    expect(tokens.calls, 1);
    expect(repository.tokens, <String>['first-token']);

    gate.complete(identity);
    expect(await first, LoopBootstrapAuthorization.authorized);
    expect(await second, LoopBootstrapAuthorization.authorized);
  });

  test(
    'invalidating cached authorization requires a fresh bootstrap',
    () async {
      final tokens = _TokenSource(<Object>['first-token', 'second-token']);
      final repository = _RecordingRepository((_) async => identity);
      final session = LoopBootstrapSession(
        principalKey: 'did:privy:user-a',
        accessTokens: tokens,
        repository: repository,
      );

      expect(await session.authorize(), LoopBootstrapAuthorization.authorized);
      session.invalidateAuthorization();
      expect(session.identity, isNull);
      expect(await session.authorize(), LoopBootstrapAuthorization.authorized);

      expect(repository.tokens, <String>['first-token', 'second-token']);
      expect(tokens.calls, 2);
    },
  );

  test(
    'dispose invalidates stuck and late work without publishing identity',
    () async {
      final tokenGate = Completer<String>();
      final tokens = _TokenSource(<Object>[tokenGate.future]);
      final repository = _RecordingRepository((_) async => identity);
      final session = LoopBootstrapSession(
        principalKey: 'did:privy:user-a',
        accessTokens: tokens,
        repository: repository,
      );

      final authorization = session.authorize();
      await Future<void>.delayed(Duration.zero);
      session.dispose();

      expect(await authorization, LoopBootstrapAuthorization.unavailable);
      tokenGate.complete('late-token');
      await Future<void>.delayed(Duration.zero);
      expect(session.identity, isNull);
      expect(repository.tokens, isEmpty);
      expect(await session.authorize(), LoopBootstrapAuthorization.unavailable);
    },
  );

  test('a failed authorization backs off before dispatching again', () async {
    var now = DateTime.utc(2026, 10, 28, 12);
    final tokens = _TokenSource(<Object>[
      'first-token',
      'second-token',
      'third-token',
    ]);
    var fail = true;
    final repository = _RecordingRepository((_) async {
      if (fail) {
        throw const LoopBackendFailure(
          LoopBackendFailureKind.unavailable,
          statusCode: 500,
        );
      }
      return identity;
    });
    final session = LoopBootstrapSession(
      principalKey: 'did:privy:user-a',
      accessTokens: tokens,
      repository: repository,
      clock: () => now,
    );

    expect(await session.authorize(), LoopBootstrapAuthorization.unavailable);
    // Every surface asking again inside the pause gets the same answer
    // without a request.
    expect(await session.authorize(), LoopBootstrapAuthorization.unavailable);
    expect(await session.authorize(), LoopBootstrapAuthorization.unavailable);
    expect(repository.tokens, <String>['first-token']);

    now = now.add(LoopBootstrapSession.initialFailureBackoff);
    expect(await session.authorize(), LoopBootstrapAuthorization.unavailable);
    expect(repository.tokens, <String>['first-token', 'second-token']);

    // The second pause is twice as long.
    now = now.add(LoopBootstrapSession.initialFailureBackoff);
    expect(await session.authorize(), LoopBootstrapAuthorization.unavailable);
    expect(repository.tokens, hasLength(2));

    fail = false;
    now = now.add(LoopBootstrapSession.initialFailureBackoff);
    expect(await session.authorize(), LoopBootstrapAuthorization.authorized);
    expect(repository.tokens, hasLength(3));
  });

  test('the failure pause never exceeds its ceiling', () async {
    var now = DateTime.utc(2026, 10, 28, 12);
    final tokens = _TokenSource(<Object>[for (var i = 0; i < 10; i++) 't$i']);
    final repository = _RecordingRepository((_) async {
      throw const LoopBackendFailure(
        LoopBackendFailureKind.unavailable,
        statusCode: 500,
      );
    });
    final session = LoopBootstrapSession(
      principalKey: 'did:privy:user-a',
      accessTokens: tokens,
      repository: repository,
      clock: () => now,
    );

    for (var attempt = 1; attempt <= 8; attempt += 1) {
      await session.authorize();
      expect(repository.tokens, hasLength(attempt));
      now = now.add(LoopBootstrapSession.maxFailureBackoff);
    }
  });

  test('a request that never reached LOOP is retried at once', () async {
    final now = DateTime.utc(2026, 10, 28, 12);
    var online = false;
    final tokens = _TokenSource(<Object>['first-token', 'second-token']);
    final repository = _RecordingRepository((_) async {
      if (!online) {
        throw const LoopBackendFailure(LoopBackendFailureKind.connection);
      }
      return identity;
    });
    final session = LoopBootstrapSession(
      principalKey: 'did:privy:user-a',
      accessTokens: tokens,
      repository: repository,
      clock: () => now,
    );

    expect(await session.authorize(), LoopBootstrapAuthorization.unavailable);
    online = true;
    expect(await session.authorize(), LoopBootstrapAuthorization.authorized);
    expect(repository.tokens, <String>['first-token', 'second-token']);
  });

  test('invalid principal keys are rejected without echoing their value', () {
    expect(
      () => LoopBootstrapSession(
        principalKey: '  ',
        accessTokens: _TokenSource(<Object>[]),
        repository: _RecordingRepository((_) async => identity),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (error) => error.toString(),
          'sanitized error',
          isNot(contains('did:privy')),
        ),
      ),
    );
  });
}

final class _TokenSource implements LoopBackendAccessTokenSource {
  _TokenSource(this._values);

  final List<Object> _values;
  int calls = 0;

  @override
  Future<String> loadAccessToken() async {
    calls += 1;
    final value = _values.removeAt(0);
    if (value is Future<String>) return value;
    if (value is String) return value;
    throw value;
  }
}

final class _RecordingRepository implements LoopBootstrapRepository {
  _RecordingRepository(this._handler);

  final Future<LoopBootstrapIdentity> Function(String token) _handler;
  final List<String> tokens = <String>[];

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) {
    tokens.add(accessToken);
    return _handler(accessToken);
  }
}
