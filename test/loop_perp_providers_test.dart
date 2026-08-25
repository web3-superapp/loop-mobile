import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/features/perp/private/perp_private_gateway.dart';
import 'package:loop_mobile/features/perp/private/perp_private_models.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/backend/loop_perp_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_perp_repository.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  test(
    'signed-out, unverified, and wallet-less owners create no session',
    () async {
      final bootstrap = await _authorizedBootstrap();
      addTearDown(bootstrap.dispose);
      final repository = _PerpRepository();

      for (final controller in <LoopSessionController Function()>[
        _SignedOutSession.new,
        _UnverifiedSession.new,
        _WalletlessSession.new,
      ]) {
        final tokens = _RecordingTokens();
        final container = ProviderContainer(
          overrides: [
            loopSessionProvider.overrideWith(controller),
            loopBootstrapSessionProvider.overrideWithValue(bootstrap),
            loopPerpRepositoryProvider.overrideWithValue(repository),
            loopBackendAccessTokenSourceProvider.overrideWithValue(tokens),
          ],
        );

        expect(container.read(loopPerpSessionProvider), isNull);
        expect(tokens.calls, 0);
        container.dispose();
      }
      expect(repository.bindingCalls, 0);
    },
  );

  test('missing backend URL creates no private session or token request', () {
    final tokens = _RecordingTokens();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(_config('')),
        loopSessionProvider.overrideWith(_AuthenticatedSession.new),
        loopBackendAccessTokenSourceProvider.overrideWithValue(tokens),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(loopPerpSessionProvider), isNull);
    expect(tokens.calls, 0);
  });

  test('verified owner with HTTPS backend and wallet is lazy', () async {
    final bootstrap = await _authorizedBootstrap();
    addTearDown(bootstrap.dispose);
    final tokens = _RecordingTokens();
    final repository = _PerpRepository();
    final container = ProviderContainer(
      overrides: [
        loopSessionProvider.overrideWith(_AuthenticatedSession.new),
        loopBootstrapSessionProvider.overrideWithValue(bootstrap),
        loopPerpRepositoryProvider.overrideWithValue(repository),
        loopBackendAccessTokenSourceProvider.overrideWithValue(tokens),
      ],
    );
    addTearDown(container.dispose);

    final session = container.read(loopPerpSessionProvider);

    expect(session, isNotNull);
    expect(session!.mode, PerpGatewayMode.production);
    expect(tokens.calls, 0);
    expect(repository.bindingCalls, 0);
  });

  test(
    'wallet and principal rotation replace and invalidate the owner',
    () async {
      final bootstrap = await _authorizedBootstrap();
      addTearDown(bootstrap.dispose);
      final tokens = _RecordingTokens();
      final repository = _PerpRepository(deferred: true);
      final container = ProviderContainer(
        overrides: [
          loopSessionProvider.overrideWith(_MutableSession.new),
          loopBootstrapSessionProvider.overrideWithValue(bootstrap),
          loopPerpRepositoryProvider.overrideWithValue(repository),
          loopBackendAccessTokenSourceProvider.overrideWithValue(tokens),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        loopPerpSessionProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final first = subscription.read()!;
      final pending = first.getWalletBinding();
      final cancellationExpectation = expectLater(
        pending,
        throwsA(
          isA<PerpGatewayException>().having(
            (failure) => failure.kind,
            'kind',
            PerpGatewayFailureKind.cancelled,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final controller =
          container.read(loopSessionProvider.notifier) as _MutableSession;
      controller.replace(_authenticatedState(wallet: '0xwallet-b'));
      await Future<void>.delayed(Duration.zero);

      final second = subscription.read()!;
      expect(second, isNot(same(first)));
      await cancellationExpectation;
      expect(tokens.calls, 1);
      expect(repository.bindingCalls, 1);

      controller.replace(
        _authenticatedState(
          principal: 'did:privy:user-b',
          wallet: '0xwallet-b',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(subscription.read(), isNot(same(second)));

      repository.bindingResult.complete(_unboundBinding);
      await Future<void>.delayed(Duration.zero);
    },
  );
}

AppConfig _config(String backendBaseUrl) => AppConfig(
  privyAppId: 'privy-app',
  privyAppClientId: 'privy-client',
  streamApiKey: 'public-stream-key',
  backendBaseUrl: backendBaseUrl,
  firebaseConfigured: false,
);

LoopSessionState _authenticatedState({
  String principal = 'did:privy:user-a',
  String wallet = '0xwallet-a',
}) => LoopSessionState(
  mode: LoopSessionMode.authenticated,
  account: PrivyAccountSummary(
    privyUserId: principal,
    wallet: PrivyWalletSummary(address: wallet),
  ),
);

final _unboundBinding = PerpWalletBinding(
  state: PerpWalletBindingState.unbound,
  bindingVersion: '0',
  accountKind: null,
  lastVerifiedAt: null,
);

Future<LoopBootstrapSession> _authorizedBootstrap() async {
  final session = LoopBootstrapSession(
    principalKey: 'did:privy:test-user',
    accessTokens: _RecordingTokens(),
    repository: const _BootstrapRepository(),
  );
  expect(await session.authorize(), LoopBootstrapAuthorization.authorized);
  return session;
}

final class _RecordingTokens implements LoopBackendAccessTokenSource {
  var calls = 0;

  @override
  Future<String> loadAccessToken() async {
    calls += 1;
    return 'current-access-token';
  }
}

final class _BootstrapRepository implements LoopBootstrapRepository {
  const _BootstrapRepository();

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    return const LoopBootstrapIdentity(
      loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
      streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
    );
  }
}

final class _PerpRepository implements LoopPerpRepository {
  _PerpRepository({this._deferred = false});

  final bool _deferred;
  final bindingResult = Completer<PerpWalletBinding>();
  var bindingCalls = 0;

  @override
  Future<PerpWalletBinding> getWalletBinding({required String accessToken}) {
    bindingCalls += 1;
    return _deferred
        ? bindingResult.future
        : Future<PerpWalletBinding>.value(_unboundBinding);
  }

  @override
  Future<PerpWalletBinding> bindWallet({
    required String accessToken,
    required String expectedBindingVersion,
  }) => throw UnsupportedError('not used');

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

class _SignedOutSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState.signedOut();
}

class _UnverifiedSession extends LoopSessionController {
  @override
  LoopSessionState build() =>
      const LoopSessionState(mode: LoopSessionMode.authenticatedUnverified);
}

class _WalletlessSession extends LoopSessionController {
  @override
  LoopSessionState build() => const LoopSessionState(
    mode: LoopSessionMode.authenticated,
    account: PrivyAccountSummary(privyUserId: 'did:privy:user-a'),
  );
}

class _AuthenticatedSession extends LoopSessionController {
  @override
  LoopSessionState build() => _authenticatedState();
}

class _MutableSession extends LoopSessionController {
  @override
  LoopSessionState build() => _authenticatedState();

  void replace(LoopSessionState next) => state = next;
}
