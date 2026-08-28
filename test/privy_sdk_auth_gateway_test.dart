import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:privy_flutter/privy_flutter.dart';
// ignore: implementation_imports
import 'package:privy_flutter/src/modules/email/login_with_email.dart';

void main() {
  test(
    'a newer unverified stream state wins over a stale authenticated restore',
    () async {
      final privy = _GatedPrivy();
      final gateway = PrivySdkAuthGateway.testing(privy);
      final observed = <PrivySessionSnapshot>[];
      final subscription = gateway.watchSession().listen(observed.add);
      addTearDown(subscription.cancel);
      addTearDown(privy.dispose);

      final restoring = gateway.restoreSession();
      await privy.restoreStarted.future;

      privy.emit(const AuthenticatedUnverified());
      privy.completeRestore(Authenticated(_FakePrivyUser('did:privy:stale')));

      final restored = await restoring;

      expect(observed.last.kind, PrivySessionKind.authenticatedUnverified);
      expect(restored.kind, PrivySessionKind.authenticatedUnverified);
      await expectLater(
        gateway.getCurrentAccessToken(),
        throwsA(isA<PrivyGatewayException>()),
      );
    },
  );

  test(
    'a newer authenticated principal wins over stale restore user',
    () async {
      final privy = _GatedPrivy();
      final gateway = PrivySdkAuthGateway.testing(privy);
      final subscription = gateway.watchSession().listen((_) {});
      addTearDown(subscription.cancel);
      addTearDown(privy.dispose);

      final restoring = gateway.restoreSession();
      await privy.restoreStarted.future;

      privy.emit(
        Authenticated(
          _FakePrivyUser('did:privy:current', token: 'current-access-token'),
        ),
      );
      privy.completeRestore(
        Authenticated(
          _FakePrivyUser('did:privy:stale', token: 'stale-access-token'),
        ),
      );

      final restored = await restoring;

      expect(restored.kind, PrivySessionKind.authenticated);
      expect(restored.account?.privyUserId, 'did:privy:current');
      expect(await gateway.getCurrentAccessToken(), 'current-access-token');
    },
  );

  test(
    'a newer authenticated principal wins over stale signed-out restore',
    () async {
      final privy = _GatedPrivy();
      final gateway = PrivySdkAuthGateway.testing(privy);
      final subscription = gateway.watchSession().listen((_) {});
      addTearDown(subscription.cancel);
      addTearDown(privy.dispose);

      final restoring = gateway.restoreSession();
      await privy.restoreStarted.future;
      privy.emit(
        Authenticated(
          _FakePrivyUser('did:privy:current', token: 'current-access-token'),
        ),
      );
      privy.completeRestore(const Unauthenticated());

      final restored = await restoring;

      expect(restored.kind, PrivySessionKind.authenticated);
      expect(restored.account?.privyUserId, 'did:privy:current');
      expect(await gateway.getCurrentAccessToken(), 'current-access-token');
    },
  );

  test('a streamed NotReady retires a token-capable user', () async {
    final privy = _GatedPrivy();
    final gateway = PrivySdkAuthGateway.testing(privy);
    final subscription = gateway.watchSession().listen((_) {});
    addTearDown(subscription.cancel);
    addTearDown(privy.dispose);

    privy.emit(
      Authenticated(
        _FakePrivyUser('did:privy:current', token: 'current-access-token'),
      ),
    );
    expect(await gateway.getCurrentAccessToken(), 'current-access-token');
    privy.emit(const NotReady());

    await expectLater(
      gateway.getCurrentAccessToken(),
      throwsA(isA<PrivyGatewayException>()),
    );
  });

  test(
    'current SDK state wins before its stream callback is delivered',
    () async {
      final privy = _GatedPrivy();
      final gateway = PrivySdkAuthGateway.testing(privy);
      addTearDown(privy.dispose);

      final restoring = gateway.restoreSession();
      await privy.restoreStarted.future;

      privy.updateCurrent(const AuthenticatedUnverified());
      privy.completeRestore(
        Authenticated(
          _FakePrivyUser('did:privy:stale', token: 'stale-access-token'),
        ),
      );

      final restored = await restoring;

      expect(restored.kind, PrivySessionKind.authenticatedUnverified);
      await expectLater(
        gateway.getCurrentAccessToken(),
        throwsA(isA<PrivyGatewayException>()),
      );
    },
  );

  test(
    'a delayed current NotReady retires a user observed during restore',
    () async {
      final privy = _GatedPrivy();
      final gateway = PrivySdkAuthGateway.testing(privy);
      final subscription = gateway.watchSession().listen((_) {});
      addTearDown(subscription.cancel);
      addTearDown(privy.dispose);

      final restoring = gateway.restoreSession();
      await privy.restoreStarted.future;
      privy.emit(
        Authenticated(
          _FakePrivyUser('did:privy:current', token: 'current-access-token'),
        ),
      );
      expect(await gateway.getCurrentAccessToken(), 'current-access-token');

      privy.updateCurrent(const NotReady());
      privy.completeRestore(
        Authenticated(
          _FakePrivyUser('did:privy:stale', token: 'stale-access-token'),
        ),
      );

      final restored = await restoring;

      expect(restored.kind, PrivySessionKind.notReady);
      await expectLater(
        gateway.getCurrentAccessToken(),
        throwsA(isA<PrivyGatewayException>()),
      );
    },
  );

  test(
    'current NotReady immediately retires a previously authenticated user',
    () async {
      final privy = _GatedPrivy();
      final gateway = PrivySdkAuthGateway.testing(privy);
      final subscription = gateway.watchSession().listen((_) {});
      addTearDown(subscription.cancel);
      addTearDown(privy.dispose);

      privy.emit(
        Authenticated(
          _FakePrivyUser('did:privy:current', token: 'current-access-token'),
        ),
      );
      expect(await gateway.getCurrentAccessToken(), 'current-access-token');

      privy.updateCurrent(const NotReady());
      final restored = await gateway.restoreSession();

      expect(restored.kind, PrivySessionKind.notReady);
      expect(privy.restoreStarted.isCompleted, isFalse);
      await expectLater(
        gateway.getCurrentAccessToken(),
        throwsA(isA<PrivyGatewayException>()),
      );
    },
  );

  test(
    'an explicit email login wins over an older in-flight restore',
    () async {
      final loginUser = _FakePrivyUser(
        'did:privy:login',
        token: 'login-access-token',
      );
      final privy = _GatedPrivy(loginUser: loginUser);
      final gateway = PrivySdkAuthGateway.testing(privy);
      final subscription = gateway.watchSession().listen((_) {});
      addTearDown(subscription.cancel);
      addTearDown(privy.dispose);

      final restoring = gateway.restoreSession();
      await privy.restoreStarted.future;
      privy.emit(const Unauthenticated());

      final account = await gateway.verifyEmailCode(
        email: 'person@example.com',
        code: '123456',
      );
      expect(account.privyUserId, 'did:privy:login');
      expect(privy.currentAuthState, isA<Unauthenticated>());

      privy.completeRestore(
        Authenticated(
          _FakePrivyUser('did:privy:stale', token: 'stale-access-token'),
        ),
      );
      final restored = await restoring;

      expect(restored.kind, PrivySessionKind.authenticated);
      expect(restored.account?.privyUserId, 'did:privy:login');
      expect(await gateway.getCurrentAccessToken(), 'login-access-token');
    },
  );

  test('restore is used when current stays at initial NotReady', () async {
    final privy = _GatedPrivy();
    final gateway = PrivySdkAuthGateway.testing(privy);
    addTearDown(privy.dispose);

    final restoring = gateway.restoreSession();
    await privy.restoreStarted.future;
    privy.completeRestore(
      Authenticated(
        _FakePrivyUser('did:privy:restored', token: 'restored-access-token'),
      ),
    );

    final restored = await restoring;

    expect(restored.kind, PrivySessionKind.authenticated);
    expect(restored.account?.privyUserId, 'did:privy:restored');
    expect(await gateway.getCurrentAccessToken(), 'restored-access-token');
  });
}

final class _GatedPrivy implements Privy {
  _GatedPrivy({PrivyUser? loginUser}) : _email = _FakeLoginWithEmail(loginUser);

  final _states = StreamController<AuthState>.broadcast(sync: true);
  final _restore = Completer<AuthState>();
  final restoreStarted = Completer<void>();
  final LoginWithEmail _email;

  AuthState _current = const NotReady();

  void emit(AuthState state) {
    _current = state;
    _states.add(state);
  }

  void updateCurrent(AuthState state) => _current = state;

  void completeRestore(AuthState state) => _restore.complete(state);

  Future<void> dispose() => _states.close();

  @override
  Stream<AuthState> get authStateStream => _states.stream;

  @override
  AuthState get currentAuthState => _current;

  @override
  LoginWithEmail get email => _email;

  @override
  Future<AuthState> getAuthState() {
    if (!restoreStarted.isCompleted) restoreStarted.complete();
    return _restore.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeLoginWithEmail implements LoginWithEmail {
  _FakeLoginWithEmail(this._loginUser);

  final PrivyUser? _loginUser;

  @override
  Future<Result<PrivyUser>> loginWithCode({
    required String code,
    required String email,
  }) async {
    final user = _loginUser;
    if (user == null) {
      return const Failure<PrivyUser>(PrivyException('Login unavailable'));
    }
    return Success<PrivyUser>(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakePrivyUser implements PrivyUser {
  _FakePrivyUser(this.id, {this.token = 'stale-access-token'});

  @override
  final String id;
  final String token;

  @override
  List<EmbeddedEthereumWallet> get embeddedEthereumWallets =>
      const <EmbeddedEthereumWallet>[];

  @override
  List<LinkedAccounts> get linkedAccounts => const <LinkedAccounts>[];

  @override
  Future<Result<String>> getAccessToken() async => Success<String>(token);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
