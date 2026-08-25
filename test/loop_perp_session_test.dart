import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/loop_perp_repository.dart';
import 'package:loop_mobile/integrations/backend/loop_perp_session.dart';

void main() {
  test('authorizes bootstrap before loading a private request token', () async {
    final events = <String>[];
    final bootstrap = LoopBootstrapSession(
      principalKey: 'did:privy:test-user',
      accessTokens: _Tokens(<String>['bootstrap-token'], events: events),
      repository: _BootstrapRepository(events: events),
    );
    addTearDown(bootstrap.dispose);
    final privateTokens = _Tokens(<String>['private-token'], events: events);
    final repository = _PerpRepository(
      onBinding: (token) async {
        events.add('perp:$token');
        return _unboundBinding;
      },
    );
    final session = LoopPerpSession(
      principalKey: 'did:privy:test-user',
      bootstrapSession: bootstrap,
      accessTokens: privateTokens,
      repository: repository,
    );
    addTearDown(session.dispose);

    expect(await session.getWalletBinding(), same(_unboundBinding));
    expect(events, <String>[
      'token:bootstrap-token',
      'bootstrap:bootstrap-token',
      'token:private-token',
      'perp:private-token',
    ]);
  });

  test('one 401 loads one new token and retries exactly once', () async {
    final bootstrap = await _authorizedBootstrap();
    addTearDown(bootstrap.dispose);
    final tokens = _Tokens(<String>['expired-token', 'fresh-token']);
    final seenTokens = <String>[];
    final repository = _PerpRepository(
      onBinding: (token) async {
        seenTokens.add(token);
        if (seenTokens.length == 1) {
          throw const LoopBackendFailure(
            LoopBackendFailureKind.authentication,
            statusCode: 401,
            code: 'invalid_access_token',
          );
        }
        return _unboundBinding;
      },
    );
    final session = LoopPerpSession(
      principalKey: 'did:privy:test-user',
      bootstrapSession: bootstrap,
      accessTokens: tokens,
      repository: repository,
    );
    addTearDown(session.dispose);

    expect(await session.getWalletBinding(), same(_unboundBinding));
    expect(seenTokens, <String>['expired-token', 'fresh-token']);
    expect(tokens.calls, 2);
  });

  test('a second 401 is returned without a third attempt', () async {
    final bootstrap = await _authorizedBootstrap();
    addTearDown(bootstrap.dispose);
    final tokens = _Tokens(<String>['expired-token', 'still-expired']);
    final repository = _PerpRepository(
      onBinding: (_) async => throw const LoopBackendFailure(
        LoopBackendFailureKind.authentication,
        statusCode: 401,
        code: 'invalid_access_token',
      ),
    );
    final session = LoopPerpSession(
      principalKey: 'did:privy:test-user',
      bootstrapSession: bootstrap,
      accessTokens: tokens,
      repository: repository,
    );
    addTearDown(session.dispose);

    await expectLater(
      session.getWalletBinding(),
      throwsA(
        isA<PerpGatewayException>().having(
          (failure) => failure.kind,
          'kind',
          PerpGatewayFailureKind.authentication,
        ),
      ),
    );
    expect(repository.bindingCalls, 2);
    expect(tokens.calls, 2);
  });

  test(
    'maps stable mutation conflicts and preserves only the request ID',
    () async {
      final bootstrap = await _authorizedBootstrap();
      addTearDown(bootstrap.dispose);
      const requestId = 'a4f8eb85-93fb-4fa2-8621-c410e4a46950';
      final repository = _PerpRepository(
        onBinding: (_) async => _unboundBinding,
        onBind: (_, _) async => throw const LoopBackendFailure(
          LoopBackendFailureKind.invalidRequest,
          statusCode: 409,
          code: 'version_conflict',
          requestId: requestId,
        ),
      );
      final session = LoopPerpSession(
        principalKey: 'did:privy:test-user',
        bootstrapSession: bootstrap,
        accessTokens: _Tokens(<String>['current-token']),
        repository: repository,
      );
      addTearDown(session.dispose);

      await expectLater(
        session.bindWallet(expectedBindingVersion: '0'),
        throwsA(
          isA<PerpGatewayException>()
              .having(
                (failure) => failure.kind,
                'kind',
                PerpGatewayFailureKind.versionConflict,
              )
              .having((failure) => failure.requestId, 'requestId', requestId),
        ),
      );
    },
  );

  test(
    'bootstrap_required expires the cache for the next explicit read',
    () async {
      final events = <String>[];
      final bootstrap = LoopBootstrapSession(
        principalKey: 'did:privy:test-user',
        accessTokens: _Tokens(<String>[
          'bootstrap-token-1',
          'bootstrap-token-2',
        ], events: events),
        repository: _BootstrapRepository(events: events),
      );
      addTearDown(bootstrap.dispose);
      expect(
        await bootstrap.authorize(),
        LoopBootstrapAuthorization.authorized,
      );

      var reads = 0;
      final repository = _PerpRepository(
        onBinding: (token) async {
          reads += 1;
          events.add('perp:$token');
          if (reads == 1) {
            throw const LoopBackendFailure(
              LoopBackendFailureKind.invalidRequest,
              statusCode: 409,
              code: 'bootstrap_required',
            );
          }
          return _unboundBinding;
        },
      );
      final session = LoopPerpSession(
        principalKey: 'did:privy:test-user',
        bootstrapSession: bootstrap,
        accessTokens: _Tokens(<String>[
          'private-token-1',
          'private-token-2',
        ], events: events),
        repository: repository,
      );
      addTearDown(session.dispose);

      await expectLater(
        session.getWalletBinding(),
        throwsA(
          isA<PerpGatewayException>().having(
            (failure) => failure.kind,
            'kind',
            PerpGatewayFailureKind.bootstrapRequired,
          ),
        ),
      );
      expect(bootstrap.identity, isNull);
      expect(repository.bindingCalls, 1);

      expect(await session.getWalletBinding(), same(_unboundBinding));
      expect(repository.bindingCalls, 2);
      expect(events.where((event) => event.startsWith('bootstrap:')).length, 2);
    },
  );

  test('dispose cancels an in-flight private result', () async {
    final bootstrap = await _authorizedBootstrap();
    addTearDown(bootstrap.dispose);
    final result = Completer<PerpWalletBinding>();
    final repository = _PerpRepository(onBinding: (_) => result.future);
    final session = LoopPerpSession(
      principalKey: 'did:privy:test-user',
      bootstrapSession: bootstrap,
      accessTokens: _Tokens(<String>['current-token']),
      repository: repository,
    );

    final pending = session.getWalletBinding();
    await Future<void>.delayed(Duration.zero);
    session.dispose();

    await expectLater(
      pending,
      throwsA(
        isA<PerpGatewayException>().having(
          (failure) => failure.kind,
          'kind',
          PerpGatewayFailureKind.cancelled,
        ),
      ),
    );
    result.complete(_unboundBinding);
    await Future<void>.delayed(Duration.zero);
  });

  test('an unavailable bootstrap prevents the private request', () async {
    final bootstrap = LoopBootstrapSession(
      principalKey: 'did:privy:test-user',
      accessTokens: _Tokens(<String>['bootstrap-token']),
      repository: _BootstrapRepository(fails: true),
    );
    addTearDown(bootstrap.dispose);
    final repository = _PerpRepository(onBinding: (_) async => _unboundBinding);
    final session = LoopPerpSession(
      principalKey: 'did:privy:test-user',
      bootstrapSession: bootstrap,
      accessTokens: _Tokens(<String>['private-token']),
      repository: repository,
    );
    addTearDown(session.dispose);

    await expectLater(
      session.getWalletBinding(),
      throwsA(
        isA<PerpGatewayException>().having(
          (failure) => failure.kind,
          'kind',
          PerpGatewayFailureKind.unavailable,
        ),
      ),
    );
    expect(repository.bindingCalls, 0);
  });
}

final _unboundBinding = PerpWalletBinding(
  state: PerpWalletBindingState.unbound,
  bindingVersion: '0',
  accountKind: null,
  lastVerifiedAt: null,
);

Future<LoopBootstrapSession> _authorizedBootstrap() async {
  final session = LoopBootstrapSession(
    principalKey: 'did:privy:test-user',
    accessTokens: _Tokens(<String>['bootstrap-token']),
    repository: _BootstrapRepository(),
  );
  expect(await session.authorize(), LoopBootstrapAuthorization.authorized);
  return session;
}

final class _Tokens implements LoopBackendAccessTokenSource {
  _Tokens(this._tokens, {this.events});

  final List<String> _tokens;
  final List<String>? events;
  var calls = 0;

  @override
  Future<String> loadAccessToken() async {
    final token = _tokens[calls];
    calls += 1;
    events?.add('token:$token');
    return token;
  }
}

final class _BootstrapRepository implements LoopBootstrapRepository {
  _BootstrapRepository({this.events, this.fails = false});

  final List<String>? events;
  final bool fails;

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    events?.add('bootstrap:$accessToken');
    if (fails) {
      throw const LoopBackendFailure(LoopBackendFailureKind.unavailable);
    }
    return const LoopBootstrapIdentity(
      loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
      streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
    );
  }
}

final class _PerpRepository implements LoopPerpRepository {
  _PerpRepository({required this.onBinding, this.onBind});

  final Future<PerpWalletBinding> Function(String accessToken) onBinding;
  final Future<PerpWalletBinding> Function(
    String accessToken,
    String expectedBindingVersion,
  )?
  onBind;
  var bindingCalls = 0;

  @override
  Future<PerpWalletBinding> getWalletBinding({required String accessToken}) {
    bindingCalls += 1;
    return onBinding(accessToken);
  }

  @override
  Future<PerpWalletBinding> bindWallet({
    required String accessToken,
    required String expectedBindingVersion,
  }) {
    final callback = onBind;
    if (callback == null) throw UnsupportedError('not used');
    return callback(accessToken, expectedBindingVersion);
  }

  @override
  Future<PerpWalletBinding> unbindWallet({
    required String accessToken,
    required String expectedBindingVersion,
  }) => throw UnsupportedError('not used');

  @override
  Future<PerpAccount> getAccount({required String accessToken}) =>
      throw UnsupportedError('not used');

  @override
  Future<PerpConfig> getConfig({required String accessToken}) =>
      throw UnsupportedError('not used');

  @override
  Future<PerpPage<PerpFill>> listFills({
    required String accessToken,
    int? limit,
    String? cursor,
  }) => throw UnsupportedError('not used');

  @override
  Future<PerpPage<PerpFundingEntry>> listFunding({
    required String accessToken,
    int? limit,
    String? cursor,
  }) => throw UnsupportedError('not used');

  @override
  Future<PerpPage<PerpOrder>> listOrders({
    required String accessToken,
    int? limit,
    String? cursor,
  }) => throw UnsupportedError('not used');

  @override
  Future<PerpPage<PerpPosition>> listPositions({
    required String accessToken,
    int? limit,
    String? cursor,
  }) => throw UnsupportedError('not used');
}
