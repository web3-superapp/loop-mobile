import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';

const _identity = LoopBootstrapIdentity(
  loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
  streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
);

void main() {
  test('refreshes one proven 401 exactly once', () async {
    final tokens = _TokenSource(<Object>[
      'bootstrap-token',
      'first-request-token',
      'second-request-token',
      'must-not-be-read',
    ]);
    final bootstrapRepository = _BootstrapRepository();
    final bootstrap = _bootstrap(tokens, bootstrapRepository);
    final session = _session(tokens, bootstrap);
    addTearDown(() {
      session.dispose();
      bootstrap.dispose();
    });
    final requestTokens = <String>[];

    final result = await session.execute((accessToken) async {
      requestTokens.add(accessToken);
      if (accessToken == 'first-request-token') {
        throw const LoopBackendFailure(
          LoopBackendFailureKind.authentication,
          statusCode: 401,
          code: 'invalid_access_token',
        );
      }
      return 'authorized-result';
    });

    expect(result, 'authorized-result');
    expect(bootstrapRepository.tokens, <String>['bootstrap-token']);
    expect(requestTokens, <String>[
      'first-request-token',
      'second-request-token',
    ]);
    expect(tokens.calls, 3);
  });

  test(
    '401 refresh and bootstrap recovery have independent one-use budgets',
    () async {
      final tokens = _TokenSource(<Object>[
        'initial-bootstrap-token',
        'first-request-token',
        'second-request-token',
        'rebootstrap-token',
        'third-request-token',
        'must-not-be-read',
      ]);
      final bootstrapRepository = _BootstrapRepository();
      final bootstrap = _bootstrap(tokens, bootstrapRepository);
      final session = _session(tokens, bootstrap);
      addTearDown(() {
        session.dispose();
        bootstrap.dispose();
      });
      final requestTokens = <String>[];

      final result = await session.execute((accessToken) async {
        requestTokens.add(accessToken);
        return switch (accessToken) {
          'first-request-token' => throw const LoopBackendFailure(
            LoopBackendFailureKind.authentication,
            statusCode: 401,
            code: 'invalid_access_token',
          ),
          'second-request-token' => throw const LoopBackendFailure(
            LoopBackendFailureKind.invalidRequest,
            statusCode: 409,
            code: 'bootstrap_required',
          ),
          _ => 'recovered-result',
        };
      });

      expect(result, 'recovered-result');
      expect(bootstrapRepository.tokens, <String>[
        'initial-bootstrap-token',
        'rebootstrap-token',
      ]);
      expect(requestTokens, <String>[
        'first-request-token',
        'second-request-token',
        'third-request-token',
      ]);
      expect(tokens.calls, 5);
    },
  );

  test('a second 401 fails without loading a third request token', () async {
    final tokens = _TokenSource(<Object>[
      'bootstrap-token',
      'first-request-token',
      'second-request-token',
      'must-not-be-read',
    ]);
    final bootstrapRepository = _BootstrapRepository();
    final bootstrap = _bootstrap(tokens, bootstrapRepository);
    final session = _session(tokens, bootstrap);
    addTearDown(() {
      session.dispose();
      bootstrap.dispose();
    });
    var requests = 0;

    await expectLater(
      session.execute<void>((_) async {
        requests += 1;
        throw const LoopBackendFailure(
          LoopBackendFailureKind.authentication,
          statusCode: 401,
          code: 'invalid_access_token',
        );
      }),
      throwsA(_backendFailure(LoopBackendFailureKind.authentication)),
    );

    expect(requests, 2);
    expect(tokens.calls, 3);
  });

  test('a second bootstrap_required is not recovered again', () async {
    final tokens = _TokenSource(<Object>[
      'initial-bootstrap-token',
      'first-request-token',
      'rebootstrap-token',
      'second-request-token',
      'must-not-be-read',
    ]);
    final bootstrapRepository = _BootstrapRepository();
    final bootstrap = _bootstrap(tokens, bootstrapRepository);
    final session = _session(tokens, bootstrap);
    addTearDown(() {
      session.dispose();
      bootstrap.dispose();
    });
    var requests = 0;

    await expectLater(
      session.execute<void>((_) async {
        requests += 1;
        throw const LoopBackendFailure(
          LoopBackendFailureKind.invalidRequest,
          statusCode: 409,
          code: 'bootstrap_required',
        );
      }),
      throwsA(
        _backendFailure(LoopBackendFailureKind.invalidRequest)
            .having((failure) => failure.statusCode, 'statusCode', 409)
            .having((failure) => failure.code, 'code', 'bootstrap_required'),
      ),
    );

    expect(requests, 2);
    expect(bootstrapRepository.tokens, <String>[
      'initial-bootstrap-token',
      'rebootstrap-token',
    ]);
    expect(tokens.calls, 4);
  });

  test('dispose wins a race with an in-flight authenticated request', () async {
    final tokens = _TokenSource(<Object>['bootstrap-token', 'request-token']);
    final bootstrapRepository = _BootstrapRepository();
    final bootstrap = _bootstrap(tokens, bootstrapRepository);
    final session = _session(tokens, bootstrap);
    addTearDown(bootstrap.dispose);
    final requestGate = Completer<String>();
    var requests = 0;

    final pending = session.execute((_) {
      requests += 1;
      return requestGate.future;
    });
    await _waitUntil(() => requests == 1);
    session.dispose();

    await expectLater(pending, throwsA(anything));
    requestGate.complete('late-success');
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    await expectLater(session.execute((_) async => 'wrong'), throwsA(anything));
  });

  test(
    'dispose during bootstrap prevents the owning request from starting',
    () async {
      final bootstrapToken = Completer<String>();
      final tokens = _TokenSource(<Object>[bootstrapToken.future]);
      final bootstrapRepository = _BootstrapRepository();
      final bootstrap = _bootstrap(tokens, bootstrapRepository);
      final session = _session(tokens, bootstrap);
      addTearDown(() {
        session.dispose();
        bootstrap.dispose();
      });
      var requests = 0;

      final pending = session.execute((_) async {
        requests += 1;
        return 'must-not-run';
      });
      await _waitUntil(() => tokens.calls == 1);
      session.dispose();

      await expectLater(pending, throwsA(anything));
      bootstrapToken.complete('late-bootstrap-token');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(requests, 0);
    },
  );
}

LoopBootstrapSession _bootstrap(
  _TokenSource tokens,
  _BootstrapRepository repository,
) => LoopBootstrapSession(
  principalKey: 'did:privy:test-user',
  accessTokens: tokens,
  repository: repository,
);

LoopAuthenticatedSession _session(
  _TokenSource tokens,
  LoopBootstrapSession bootstrap,
) => LoopAuthenticatedSession(
  principalKey: 'did:privy:test-user',
  bootstrapSession: bootstrap,
  accessTokens: tokens,
);

Future<void> _waitUntil(bool Function() predicate) async {
  for (var index = 0; index < 20 && !predicate(); index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(predicate(), isTrue);
}

final class _TokenSource implements LoopBackendAccessTokenSource {
  _TokenSource(this._values);

  final List<Object> _values;
  var calls = 0;

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
  final tokens = <String>[];

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    tokens.add(accessToken);
    return _identity;
  }
}

TypeMatcher<LoopBackendFailure> _backendFailure(LoopBackendFailureKind kind) =>
    isA<LoopBackendFailure>().having((failure) => failure.kind, 'kind', kind);
