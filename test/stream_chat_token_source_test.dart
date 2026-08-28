import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token_repository.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_sdk_session.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

const _identity = LoopBootstrapIdentity(
  loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
  streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
);
const _providerToken = 'abcdefghijklmnopqrstuvwxyz123456';

void main() {
  test(
    'uses a current Privy token and enforces the bootstrap identity',
    () async {
      final accessTokens = _AccessTokens(<String>['bootstrap', 'chat']);
      final streamTokens = _StreamTokens((_) async => _issued());
      final fixture = _fixture(
        accessTokens: accessTokens,
        streamTokens: streamTokens,
      );
      addTearDown(fixture.dispose);

      final identity = await fixture.source.loadIdentity();
      expect(identity?.userId, _identity.streamUserId);
      expect(
        await fixture.source.loadToken(_identity.streamUserId),
        _providerToken,
      );

      expect(accessTokens.loaded, <String>['bootstrap', 'chat']);
      expect(streamTokens.accessTokens, <String>['chat']);
    },
  );

  test('a client-selected Stream user never reaches the token route', () async {
    final accessTokens = _AccessTokens(<String>['bootstrap']);
    final streamTokens = _StreamTokens((_) async => _issued());
    final fixture = _fixture(
      accessTokens: accessTokens,
      streamTokens: streamTokens,
    );
    addTearDown(fixture.dispose);
    expect(
      (await fixture.source.loadIdentity())?.userId,
      _identity.streamUserId,
    );

    await expectLater(
      fixture.source.loadToken('loop_11111111111111111111111111111111'),
      throwsA(_failure(LoopBackendFailureKind.authentication)),
    );

    expect(accessTokens.loaded, <String>['bootstrap']);
    expect(streamTokens.accessTokens, isEmpty);
  });

  test(
    'bootstrap invalidation while loading a Privy token prevents issuance',
    () async {
      final accessTokens = _GatedAccessTokens();
      final streamTokens = _StreamTokens((_) async => _issued());
      final fixture = _fixture(
        accessTokens: accessTokens,
        streamTokens: streamTokens,
      );
      addTearDown(fixture.dispose);
      await fixture.source.loadIdentity();

      final loading = fixture.source.loadToken(_identity.streamUserId);
      await accessTokens.chatLoadStarted.future;
      fixture.container
          .read(loopBootstrapSessionProvider)!
          .invalidateAuthorization();
      accessTokens.chatToken.complete('chat-access-token');

      await expectLater(
        loading,
        throwsA(_failure(LoopBackendFailureKind.authentication)),
      );
      expect(streamTokens.accessTokens, isEmpty);
      expect(accessTokens.calls, 2);
    },
  );

  test('source disposal promptly retires a pending Privy token load', () async {
    final accessTokens = _GatedAccessTokens();
    final streamTokens = _StreamTokens((_) async => _issued());
    final fixture = _fixture(
      accessTokens: accessTokens,
      streamTokens: streamTokens,
    );
    addTearDown(fixture.dispose);
    await fixture.source.loadIdentity();

    final loading = fixture.source.loadToken(_identity.streamUserId);
    await accessTokens.chatLoadStarted.future;
    fixture.dispose();

    await expectLater(
      loading,
      throwsA(anything),
    ).timeout(const Duration(seconds: 1));
    expect(accessTokens.chatToken.isCompleted, isFalse);
    expect(streamTokens.accessTokens, isEmpty);
  });

  test('source disposal promptly retires a pending token response', () async {
    final response = Completer<LoopStreamToken>();
    final requestStarted = Completer<void>();
    final streamTokens = _StreamTokens((_) {
      requestStarted.complete();
      return response.future;
    });
    final fixture = _fixture(
      accessTokens: _AccessTokens(<String>['bootstrap', 'chat']),
      streamTokens: streamTokens,
    );
    addTearDown(fixture.dispose);
    await fixture.source.loadIdentity();

    final loading = fixture.source.loadToken(_identity.streamUserId);
    await requestStarted.future;
    fixture.dispose();

    await expectLater(
      loading,
      throwsA(anything),
    ).timeout(const Duration(seconds: 1));
    expect(response.isCompleted, isFalse);
    expect(streamTokens.accessTokens, <String>['chat']);
  });

  test('one 401 reloads the Privy token and retries exactly once', () async {
    final accessTokens = _AccessTokens(<String>[
      'bootstrap',
      'expired-access-token',
      'refreshed-access-token',
    ]);
    var attempt = 0;
    final streamTokens = _StreamTokens((_) async {
      attempt += 1;
      if (attempt == 1) {
        throw const LoopBackendFailure(
          LoopBackendFailureKind.authentication,
          statusCode: 401,
          code: 'invalid_access_token',
        );
      }
      return _issued();
    });
    final fixture = _fixture(
      accessTokens: accessTokens,
      streamTokens: streamTokens,
    );
    addTearDown(fixture.dispose);
    await fixture.source.loadIdentity();

    expect(
      await fixture.source.loadToken(_identity.streamUserId),
      _providerToken,
    );
    expect(streamTokens.accessTokens, <String>[
      'expired-access-token',
      'refreshed-access-token',
    ]);
  });

  test('a second 401 stops without a third token or request', () async {
    final accessTokens = _AccessTokens(<String>[
      'bootstrap',
      'first-access-token',
      'second-access-token',
    ]);
    final streamTokens = _StreamTokens(
      (_) async => throw const LoopBackendFailure(
        LoopBackendFailureKind.authentication,
        statusCode: 401,
        code: 'invalid_access_token',
      ),
    );
    final fixture = _fixture(
      accessTokens: accessTokens,
      streamTokens: streamTokens,
    );
    addTearDown(fixture.dispose);
    await fixture.source.loadIdentity();

    await expectLater(
      fixture.source.loadToken(_identity.streamUserId),
      throwsA(_failure(LoopBackendFailureKind.authentication)),
    );
    expect(streamTokens.accessTokens, <String>[
      'first-access-token',
      'second-access-token',
    ]);
    expect(accessTokens.remaining, 0);
  });

  test('one bootstrap_required re-authorizes and replays once', () async {
    final bootstrap = _BootstrapRepository();
    final accessTokens = _AccessTokens(<String>[
      'initial-bootstrap',
      'first-chat-token',
      'replacement-bootstrap',
      'replayed-chat-token',
    ]);
    var attempt = 0;
    final streamTokens = _StreamTokens((_) async {
      attempt += 1;
      if (attempt == 1) {
        throw const LoopBackendFailure(
          LoopBackendFailureKind.invalidRequest,
          statusCode: 409,
          code: 'bootstrap_required',
        );
      }
      return _issued();
    });
    final fixture = _fixture(
      bootstrap: bootstrap,
      accessTokens: accessTokens,
      streamTokens: streamTokens,
    );
    addTearDown(fixture.dispose);
    await fixture.source.loadIdentity();

    expect(
      await fixture.source.loadToken(_identity.streamUserId),
      _providerToken,
    );
    expect(bootstrap.calls, 2);
    expect(streamTokens.accessTokens, <String>[
      'first-chat-token',
      'replayed-chat-token',
    ]);
  });

  test('a second bootstrap_required stops without another replay', () async {
    final bootstrap = _BootstrapRepository();
    final accessTokens = _AccessTokens(<String>[
      'initial-bootstrap',
      'first-chat-token',
      'replacement-bootstrap',
      'replayed-chat-token',
    ]);
    final streamTokens = _StreamTokens(
      (_) async => throw const LoopBackendFailure(
        LoopBackendFailureKind.invalidRequest,
        statusCode: 409,
        code: 'bootstrap_required',
      ),
    );
    final fixture = _fixture(
      bootstrap: bootstrap,
      accessTokens: accessTokens,
      streamTokens: streamTokens,
    );
    addTearDown(fixture.dispose);
    await fixture.source.loadIdentity();

    await expectLater(
      fixture.source.loadToken(_identity.streamUserId),
      throwsA(_failure(LoopBackendFailureKind.invalidRequest)),
    );
    expect(bootstrap.calls, 2);
    expect(streamTokens.accessTokens, <String>[
      'first-chat-token',
      'replayed-chat-token',
    ]);
    expect(accessTokens.remaining, 0);
    expect(
      fixture.container.read(loopBootstrapSessionProvider)!.identity,
      isNull,
    );
  });

  test('quota and provider failures are never automatically retried', () async {
    for (final failure in <LoopBackendFailure>[
      const LoopBackendFailure(
        LoopBackendFailureKind.unavailable,
        statusCode: 429,
        code: 'rate_limit_exceeded',
      ),
      const LoopBackendFailure(
        LoopBackendFailureKind.unavailable,
        statusCode: 503,
        code: 'stream_unavailable',
      ),
    ]) {
      final accessTokens = _AccessTokens(<String>[
        'bootstrap',
        'single-chat-token',
        'must-remain-unused',
      ]);
      final streamTokens = _StreamTokens((_) async => throw failure);
      final fixture = _fixture(
        accessTokens: accessTokens,
        streamTokens: streamTokens,
      );
      addTearDown(fixture.dispose);
      await fixture.source.loadIdentity();

      await expectLater(
        fixture.source.loadToken(_identity.streamUserId),
        throwsA(_failure(LoopBackendFailureKind.unavailable)),
      );
      expect(streamTokens.accessTokens, <String>['single-chat-token']);
      expect(accessTokens.remaining, 1);
      fixture.dispose();
    }
  });

  test('concurrent requests for one Chat identity are single-flight', () async {
    final gate = Completer<LoopStreamToken>();
    final started = Completer<void>();
    final accessTokens = _AccessTokens(<String>['bootstrap', 'chat']);
    final streamTokens = _StreamTokens((_) {
      if (!started.isCompleted) started.complete();
      return gate.future;
    });
    final fixture = _fixture(
      accessTokens: accessTokens,
      streamTokens: streamTokens,
    );
    addTearDown(fixture.dispose);
    await fixture.source.loadIdentity();

    final first = fixture.source.loadToken(_identity.streamUserId);
    await started.future;
    final second = fixture.source.loadToken(_identity.streamUserId);
    gate.complete(_issued());

    expect(await Future.wait(<Future<String>>[first, second]), <String>[
      _providerToken,
      _providerToken,
    ]);
    expect(streamTokens.accessTokens, <String>['chat']);
  });

  test('a mismatched token response fails closed', () async {
    final fixture = _fixture(
      accessTokens: _AccessTokens(<String>['bootstrap', 'chat']),
      streamTokens: _StreamTokens(
        (_) async => _issued(userId: 'loop_11111111111111111111111111111111'),
      ),
    );
    addTearDown(fixture.dispose);
    await fixture.source.loadIdentity();

    await expectLater(
      fixture.source.loadToken(_identity.streamUserId),
      throwsA(_failure(LoopBackendFailureKind.invalidPayload)),
    );
  });
}

({
  ProviderContainer container,
  StreamChatSessionSource source,
  void Function() dispose,
})
_fixture({
  _BootstrapRepository? bootstrap,
  required LoopBackendAccessTokenSource accessTokens,
  required _StreamTokens streamTokens,
}) {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(_config()),
      loopSessionProvider.overrideWith(_AuthenticatedSession.new),
      loopBootstrapRepositoryProvider.overrideWithValue(
        bootstrap ?? _BootstrapRepository(),
      ),
      loopBackendAccessTokenSourceProvider.overrideWithValue(accessTokens),
      loopStreamChatTokenRepositoryProvider.overrideWithValue(streamTokens),
    ],
  );
  return (
    container: container,
    source: container.read(streamChatSessionSourceProvider),
    dispose: container.dispose,
  );
}

AppConfig _config() => const AppConfig(
  privyAppId: 'privy-app',
  privyAppClientId: 'privy-client',
  streamApiKey: 'public-stream-key',
  backendBaseUrl: 'https://api.example.com',
  firebaseConfigured: false,
);

final class _BootstrapRepository implements LoopBootstrapRepository {
  int calls = 0;

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    calls += 1;
    return _identity;
  }
}

final class _AccessTokens implements LoopBackendAccessTokenSource {
  _AccessTokens(List<String> values) : _values = List<String>.of(values);

  final List<String> _values;
  final List<String> loaded = <String>[];

  int get remaining => _values.length;

  @override
  Future<String> loadAccessToken() async {
    final value = _values.removeAt(0);
    loaded.add(value);
    return value;
  }
}

final class _GatedAccessTokens implements LoopBackendAccessTokenSource {
  final chatLoadStarted = Completer<void>();
  final chatToken = Completer<String>();
  var calls = 0;

  @override
  Future<String> loadAccessToken() {
    calls += 1;
    if (calls == 1) return Future<String>.value('bootstrap-access-token');
    if (calls == 2) {
      chatLoadStarted.complete();
      return chatToken.future;
    }
    throw StateError('Unexpected access-token request.');
  }
}

final class _StreamTokens implements LoopStreamTokenRepository {
  _StreamTokens(this._handler);

  final Future<LoopStreamToken> Function(String accessToken) _handler;
  final List<String> accessTokens = <String>[];

  @override
  Future<LoopStreamToken> issueChatToken({required String accessToken}) {
    accessTokens.add(accessToken);
    return _handler(accessToken);
  }
}

class _AuthenticatedSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:user-a'),
  );
}

LoopStreamToken _issued({String? userId}) {
  return LoopStreamToken(
    apiKey: 'public-stream-key',
    token: _providerToken,
    expiresAt: DateTime.utc(2026, 8, 28, 1),
    userId: userId ?? _identity.streamUserId,
  );
}

TypeMatcher<LoopBackendFailure> _failure(LoopBackendFailureKind kind) {
  return isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    kind,
  );
}
