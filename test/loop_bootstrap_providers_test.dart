import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_failure.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/loop_stream_token_repository.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_video_providers.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  const identity = LoopBootstrapIdentity(
    loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
    streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
  );

  test('missing or insecure backend URL creates no session', () {
    for (final baseUrl in <String>['', 'http://api.example.com']) {
      final tokens = _RecordingTokens();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_config(baseUrl)),
          loopSessionProvider.overrideWith(_AuthenticatedSession.new),
          loopBackendAccessTokenSourceProvider.overrideWithValue(tokens),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(loopBootstrapSessionProvider), isNull);
      expect(tokens.calls, 0);
    }
  });

  test('unverified sessions never create a backend session', () {
    final repository = _Repository(identity);
    final tokens = _RecordingTokens();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_config('https://api.example.com')),
        loopSessionProvider.overrideWith(_UnverifiedSession.new),
        loopBootstrapRepositoryProvider.overrideWithValue(repository),
        loopBackendAccessTokenSourceProvider.overrideWithValue(tokens),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(loopBootstrapSessionProvider), isNull);
    expect(tokens.calls, 0);
    expect(repository.calls, 0);
  });

  test(
    'Chat and Video share identity while only Chat uses its token contract',
    () async {
      final repository = _Repository(identity);
      final streamTokens = _StreamTokenRepository(identity.streamUserId);
      final tokens = _RecordingTokens();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            _config('https://api.example.com'),
          ),
          loopSessionProvider.overrideWith(_AuthenticatedSession.new),
          loopBootstrapRepositoryProvider.overrideWithValue(repository),
          loopBackendAccessTokenSourceProvider.overrideWithValue(tokens),
          loopStreamChatTokenRepositoryProvider.overrideWithValue(streamTokens),
        ],
      );
      addTearDown(container.dispose);

      final bootstrapSession = container.read(loopBootstrapSessionProvider);
      expect(bootstrapSession, isNotNull);
      expect(repository.calls, 0);
      expect(tokens.calls, 0);

      final chatIdentity = await container
          .read(streamChatSessionSourceProvider)
          .loadIdentity();
      final videoIdentity = await container
          .read(streamVideoSessionSourceProvider)
          .loadIdentity();

      expect(chatIdentity?.userId, identity.streamUserId);
      expect(videoIdentity?.userId, identity.streamUserId);
      expect(repository.calls, 1);
      expect(tokens.calls, 1);
      expect(
        await container
            .read(streamChatSessionSourceProvider)
            .loadToken(identity.streamUserId),
        'abcdefghijklmnopqrstuvwxyz123456',
      );
      await expectLater(
        container
            .read(streamVideoSessionSourceProvider)
            .loadToken(identity.streamUserId),
        throwsA(_unavailableTokenFailure()),
      );
      expect(streamTokens.calls, 1);
      expect(tokens.calls, 2);
    },
  );

  test('principal rotation invalidates the old in-flight bootstrap', () async {
    final gate = Completer<LoopBootstrapIdentity>();
    final repository = _Repository.fromHandler((_) => gate.future);
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_config('https://api.example.com')),
        loopSessionProvider.overrideWith(_MutableSession.new),
        loopBootstrapRepositoryProvider.overrideWithValue(repository),
        loopBackendAccessTokenSourceProvider.overrideWithValue(
          _RecordingTokens(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      loopBootstrapSessionProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    final firstSession = subscription.read()!;
    final firstAuthorization = firstSession.authorize();
    await Future<void>.delayed(Duration.zero);
    final controller =
        container.read(loopSessionProvider.notifier) as _MutableSession;
    controller.replace(
      const LoopSessionState(
        mode: LoopSessionMode.authenticated,
        account: PrivyAccountSummary(privyUserId: 'did:privy:user-b'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(subscription.read(), isNot(same(firstSession)));
    expect(await firstAuthorization, LoopBootstrapAuthorization.unavailable);
    gate.complete(identity);
    await Future<void>.delayed(Duration.zero);
    expect(firstSession.identity, isNull);
  });
}

AppConfig _config(String backendBaseUrl) {
  return AppConfig(
    privyAppId: 'privy-app',
    privyAppClientId: 'privy-client',
    streamApiKey: 'public-stream-key',
    backendBaseUrl: backendBaseUrl,
    firebaseConfigured: false,
  );
}

final class _RecordingTokens implements LoopBackendAccessTokenSource {
  int calls = 0;

  @override
  Future<String> loadAccessToken() async {
    calls += 1;
    return 'current-access-token';
  }
}

final class _Repository implements LoopBootstrapRepository {
  _Repository(LoopBootstrapIdentity identity)
    : this.fromHandler((_) async => identity);

  _Repository.fromHandler(this._handler);

  final Future<LoopBootstrapIdentity> Function(String token) _handler;
  int calls = 0;

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) {
    calls += 1;
    return _handler(accessToken);
  }
}

final class _StreamTokenRepository implements LoopStreamTokenRepository {
  _StreamTokenRepository(this.userId);

  final String userId;
  int calls = 0;

  @override
  Future<LoopStreamToken> issueChatToken({required String accessToken}) async {
    calls += 1;
    return LoopStreamToken(
      apiKey: 'public-stream-key',
      token: 'abcdefghijklmnopqrstuvwxyz123456',
      expiresAt: DateTime.utc(2026, 8, 28, 1),
      userId: userId,
    );
  }
}

class _AuthenticatedSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:user-a'),
  );
}

class _UnverifiedSession extends LoopSessionController {
  @override
  LoopSessionState build() =>
      const LoopSessionState(mode: LoopSessionMode.authenticatedUnverified);
}

class _MutableSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:user-a'),
  );

  void replace(LoopSessionState next) => state = next;
}

TypeMatcher<LoopBackendFailure> _unavailableTokenFailure() {
  return isA<LoopBackendFailure>().having(
    (failure) => failure.kind,
    'kind',
    LoopBackendFailureKind.unavailable,
  );
}
