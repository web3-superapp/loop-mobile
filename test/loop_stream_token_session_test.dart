import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token_session.dart';

void main() {
  const identity = LoopBootstrapIdentity(
    loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
    streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
  );

  test(
    'bootstraps first and passes a fresh bearer to the token route',
    () async {
      final accessTokens = _TokenSource(<Object>[
        'bootstrap-access-token',
        'stream-access-token',
      ]);
      final bootstrapRepository = _BootstrapRepository((_) async => identity);
      final tokenRepository = _StreamTokenRepository(
        (_) async => _credential(),
      );
      final session = _session(
        accessTokens: accessTokens,
        bootstrapRepository: bootstrapRepository,
        tokenRepository: tokenRepository,
      );

      final token = await session.loadToken(
        product: LoopStreamTokenProduct.chat,
        expectedStreamUserId: identity.streamUserId,
      );

      expect(token, _credential().token);
      expect(bootstrapRepository.tokens, <String>['bootstrap-access-token']);
      expect(tokenRepository.calls.single.product, LoopStreamTokenProduct.chat);
      expect(
        tokenRepository.calls.single.expectedStreamUserId,
        identity.streamUserId,
      );
      expect(tokenRepository.calls.single.accessToken, 'stream-access-token');
      expect(accessTokens.calls, 2);
    },
  );

  test('one 401 refreshes Privy access token exactly once', () async {
    final accessTokens = _TokenSource(<Object>[
      'bootstrap-token',
      'first-stream-token',
      'second-stream-token',
      'must-not-be-read',
    ]);
    final tokenRepository = _StreamTokenRepository((call) async {
      if (call.accessToken == 'first-stream-token') {
        throw const LoopBackendFailure(
          LoopBackendFailureKind.authentication,
          statusCode: 401,
          code: 'invalid_access_token',
        );
      }
      return _credential();
    });
    final session = _session(
      accessTokens: accessTokens,
      bootstrapRepository: _BootstrapRepository((_) async => identity),
      tokenRepository: tokenRepository,
    );

    expect(
      await session.loadToken(
        product: LoopStreamTokenProduct.video,
        expectedStreamUserId: identity.streamUserId,
      ),
      _credential().token,
    );
    expect(tokenRepository.calls.map((call) => call.accessToken), <String>[
      'first-stream-token',
      'second-stream-token',
    ]);
    expect(accessTokens.calls, 3);
  });

  test('a second 401 fails without requesting a third route token', () async {
    final accessTokens = _TokenSource(<Object>[
      'bootstrap-token',
      'first-stream-token',
      'second-stream-token',
      'must-not-be-read',
    ]);
    final tokenRepository = _StreamTokenRepository((_) async {
      throw const LoopBackendFailure(
        LoopBackendFailureKind.authentication,
        statusCode: 401,
        code: 'invalid_access_token',
      );
    });
    final session = _session(
      accessTokens: accessTokens,
      bootstrapRepository: _BootstrapRepository((_) async => identity),
      tokenRepository: tokenRepository,
    );

    await expectLater(
      session.loadToken(
        product: LoopStreamTokenProduct.chat,
        expectedStreamUserId: identity.streamUserId,
      ),
      throwsA(_failure(LoopBackendFailureKind.authentication)),
    );
    expect(tokenRepository.calls.length, 2);
    expect(accessTokens.calls, 3);
  });

  test(
    'one bootstrap_required reauthorizes the same identity and replays',
    () async {
      final accessTokens = _TokenSource(<Object>[
        'first-bootstrap-token',
        'first-stream-token',
        'second-bootstrap-token',
        'second-stream-token',
      ]);
      final bootstrapRepository = _BootstrapRepository((_) async => identity);
      final tokenRepository = _StreamTokenRepository((call) async {
        if (call.accessToken == 'first-stream-token') {
          throw const LoopBackendFailure(
            LoopBackendFailureKind.invalidRequest,
            statusCode: 409,
            code: 'bootstrap_required',
          );
        }
        return _credential();
      });
      final session = _session(
        accessTokens: accessTokens,
        bootstrapRepository: bootstrapRepository,
        tokenRepository: tokenRepository,
      );

      expect(
        await session.loadToken(
          product: LoopStreamTokenProduct.chat,
          expectedStreamUserId: identity.streamUserId,
        ),
        _credential().token,
      );
      expect(bootstrapRepository.tokens, <String>[
        'first-bootstrap-token',
        'second-bootstrap-token',
      ]);
      expect(tokenRepository.calls.map((call) => call.accessToken), <String>[
        'first-stream-token',
        'second-stream-token',
      ]);
    },
  );

  test(
    '401 and bootstrap recovery share bounded independent budgets',
    () async {
      final accessTokens = _TokenSource(<Object>[
        'bootstrap-token',
        'first-stream-token',
        'second-stream-token',
        'repeat-bootstrap-token',
        'third-stream-token',
        'must-not-be-read',
      ]);
      final bootstrapRepository = _BootstrapRepository((_) async => identity);
      final tokenRepository = _StreamTokenRepository((call) async {
        return switch (call.accessToken) {
          'first-stream-token' => throw const LoopBackendFailure(
            LoopBackendFailureKind.authentication,
            statusCode: 401,
            code: 'invalid_access_token',
          ),
          'second-stream-token' => throw const LoopBackendFailure(
            LoopBackendFailureKind.invalidRequest,
            statusCode: 409,
            code: 'bootstrap_required',
          ),
          _ => _credential(),
        };
      });
      final session = _session(
        accessTokens: accessTokens,
        bootstrapRepository: bootstrapRepository,
        tokenRepository: tokenRepository,
      );

      expect(
        await session.loadToken(
          product: LoopStreamTokenProduct.video,
          expectedStreamUserId: identity.streamUserId,
        ),
        _credential().token,
      );
      expect(tokenRepository.calls.length, 3);
      expect(bootstrapRepository.tokens.length, 2);
      expect(accessTokens.calls, 5);
    },
  );

  test('a repeated bootstrap_required invalidates and fails closed', () async {
    final accessTokens = _TokenSource(<Object>[
      'bootstrap-token',
      'first-stream-token',
      'repeat-bootstrap-token',
      'second-stream-token',
    ]);
    final bootstrapRepository = _BootstrapRepository((_) async => identity);
    final bootstrap = LoopBootstrapSession(
      principalKey: 'did:privy:user-a',
      accessTokens: accessTokens,
      repository: bootstrapRepository,
    );
    final tokenRepository = _StreamTokenRepository((_) async {
      throw const LoopBackendFailure(
        LoopBackendFailureKind.invalidRequest,
        statusCode: 409,
        code: 'bootstrap_required',
      );
    });
    final session = LoopStreamTokenSession(
      principalKey: 'did:privy:user-a',
      bootstrapSession: bootstrap,
      accessTokens: accessTokens,
      repository: tokenRepository,
    );

    await expectLater(
      session.loadToken(
        product: LoopStreamTokenProduct.chat,
        expectedStreamUserId: identity.streamUserId,
      ),
      throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
    );
    expect(tokenRepository.calls.length, 2);
    expect(bootstrap.identity, isNull);
  });

  test('wrong SDK user and 429 never enter a retry loop', () async {
    final wrongUserTokens = _TokenSource(<Object>['bootstrap-token']);
    final wrongUserRepository = _StreamTokenRepository(
      (_) async => _credential(),
    );
    final wrongUserSession = _session(
      accessTokens: wrongUserTokens,
      bootstrapRepository: _BootstrapRepository((_) async => identity),
      tokenRepository: wrongUserRepository,
    );

    await expectLater(
      wrongUserSession.loadToken(
        product: LoopStreamTokenProduct.chat,
        expectedStreamUserId: 'loop_11111111111111111111111111111111',
      ),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
    expect(wrongUserRepository.calls, isEmpty);
    expect(wrongUserTokens.calls, 1);

    final rateLimitTokens = _TokenSource(<Object>[
      'bootstrap-token',
      'stream-token',
      'must-not-be-read',
    ]);
    final rateLimitRepository = _StreamTokenRepository((_) async {
      throw const LoopBackendFailure(
        LoopBackendFailureKind.unavailable,
        statusCode: 429,
        code: 'rate_limit_exceeded',
      );
    });
    final rateLimitSession = _session(
      accessTokens: rateLimitTokens,
      bootstrapRepository: _BootstrapRepository((_) async => identity),
      tokenRepository: rateLimitRepository,
    );

    await expectLater(
      rateLimitSession.loadToken(
        product: LoopStreamTokenProduct.video,
        expectedStreamUserId: identity.streamUserId,
      ),
      throwsA(_failure(LoopBackendFailureKind.unavailable)),
    );
    expect(rateLimitRepository.calls.length, 1);
    expect(rateLimitTokens.calls, 2);
  });
}

LoopStreamTokenSession _session({
  required _TokenSource accessTokens,
  required _BootstrapRepository bootstrapRepository,
  required _StreamTokenRepository tokenRepository,
}) {
  return LoopStreamTokenSession(
    principalKey: 'did:privy:user-a',
    bootstrapSession: LoopBootstrapSession(
      principalKey: 'did:privy:user-a',
      accessTokens: accessTokens,
      repository: bootstrapRepository,
    ),
    accessTokens: accessTokens,
    repository: tokenRepository,
  );
}

LoopStreamTokenCredential _credential() {
  return LoopStreamTokenCredential(
    token: List<String>.filled(64, 't').join(),
    expiresAt: DateTime.utc(2026, 8, 29, 13),
  );
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

final class _BootstrapRepository implements LoopBootstrapRepository {
  _BootstrapRepository(this._handler);

  final Future<LoopBootstrapIdentity> Function(String token) _handler;
  final List<String> tokens = <String>[];

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) {
    tokens.add(accessToken);
    return _handler(accessToken);
  }
}

typedef _StreamTokenCall = ({
  LoopStreamTokenProduct product,
  String expectedStreamUserId,
  String accessToken,
});

final class _StreamTokenRepository implements LoopStreamTokenRepository {
  _StreamTokenRepository(this._handler);

  final Future<LoopStreamTokenCredential> Function(_StreamTokenCall call)
  _handler;
  final List<_StreamTokenCall> calls = <_StreamTokenCall>[];

  @override
  Future<LoopStreamTokenCredential> issue({
    required LoopStreamTokenProduct product,
    required String expectedStreamUserId,
    required String accessToken,
  }) {
    final call = (
      product: product,
      expectedStreamUserId: expectedStreamUserId,
      accessToken: accessToken,
    );
    calls.add(call);
    return _handler(call);
  }
}

TypeMatcher<LoopBackendFailure> _failure(LoopBackendFailureKind kind) {
  return isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    kind,
  );
}
