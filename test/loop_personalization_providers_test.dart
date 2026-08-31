import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/features/profile/presentation/profile_gateway.dart';
import 'package:loop_mobile/features/profile/privacy/privacy_gateway.dart';
import 'package:loop_mobile/features/profile/social_privacy/social_privacy_gateway.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_authenticated_session.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_session.dart';
import 'package:loop_mobile/integrations/personalization/loop_personalization_providers.dart';

void main() {
  test('missing transport or authenticated owner stays unavailable', () async {
    final owner = await _owner('did:privy:owner-a');
    addTearDown(owner.dispose);
    final dio = Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'));
    addTearDown(() => dio.close(force: true));

    final containers = <ProviderContainer>[
      ProviderContainer(
        overrides: [
          loopBackendDioProvider.overrideWithValue(null),
          loopAuthenticatedSessionProvider.overrideWithValue(owner.session),
        ],
      ),
      ProviderContainer(
        overrides: [
          loopBackendDioProvider.overrideWithValue(dio),
          loopAuthenticatedSessionProvider.overrideWithValue(null),
        ],
      ),
    ];
    for (final container in containers) {
      expect(
        container.read(loopProfileGatewayProvider).mode,
        ProfileMode.unavailable,
      );
      expect(
        container.read(loopPrivacyGatewayProvider).mode,
        PrivacyMode.unavailable,
      );
      expect(
        container.read(loopSocialPrivacyGatewayProvider).mode,
        SocialPrivacyMode.unavailable,
      );
      container.dispose();
    }
    expect(owner.requestTokens.calls, 0);
  });

  test('verified owner and backend produce lazy production gateways', () async {
    final owner = await _owner('did:privy:owner-a');
    addTearDown(owner.dispose);
    final dio = Dio(BaseOptions(baseUrl: 'https://api-dev.quant-dinger.cc/'));
    addTearDown(() => dio.close(force: true));
    final container = ProviderContainer(
      overrides: [
        loopBackendDioProvider.overrideWithValue(dio),
        loopAuthenticatedSessionProvider.overrideWithValue(owner.session),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(loopProfileGatewayProvider).mode,
      ProfileMode.production,
    );
    expect(
      container.read(loopPrivacyGatewayProvider).mode,
      PrivacyMode.production,
    );
    expect(
      container.read(loopSocialPrivacyGatewayProvider).mode,
      SocialPrivacyMode.production,
    );
    expect(owner.requestTokens.calls, 0);
  });

  test(
    'principal and backend-provider rotation replace every gateway',
    () async {
      final ownerA = await _owner('did:privy:owner-a');
      final ownerB = await _owner('did:privy:owner-b');
      addTearDown(ownerA.dispose);
      addTearDown(ownerB.dispose);
      final dioA = Dio(BaseOptions(baseUrl: 'https://api-a.example/'));
      final dioB = Dio(BaseOptions(baseUrl: 'https://api-b.example/'));
      addTearDown(() {
        dioA.close(force: true);
        dioB.close(force: true);
      });
      final container = ProviderContainer(
        overrides: [
          loopBackendDioProvider.overrideWithValue(dioA),
          loopAuthenticatedSessionProvider.overrideWithValue(ownerA.session),
        ],
      );
      addTearDown(container.dispose);

      final firstProfile = container.read(loopProfileGatewayProvider);
      final firstPrivacy = container.read(loopPrivacyGatewayProvider);
      final firstSocialPrivacy = container.read(
        loopSocialPrivacyGatewayProvider,
      );

      container.updateOverrides([
        loopBackendDioProvider.overrideWithValue(dioA),
        loopAuthenticatedSessionProvider.overrideWithValue(ownerB.session),
      ]);
      final secondProfile = container.read(loopProfileGatewayProvider);
      final secondPrivacy = container.read(loopPrivacyGatewayProvider);
      final secondSocialPrivacy = container.read(
        loopSocialPrivacyGatewayProvider,
      );
      expect(secondProfile, isNot(same(firstProfile)));
      expect(secondPrivacy, isNot(same(firstPrivacy)));
      expect(secondSocialPrivacy, isNot(same(firstSocialPrivacy)));

      container.updateOverrides([
        loopBackendDioProvider.overrideWithValue(dioB),
        loopAuthenticatedSessionProvider.overrideWithValue(ownerB.session),
      ]);
      expect(
        container.read(loopProfileGatewayProvider),
        isNot(same(secondProfile)),
      );
      expect(
        container.read(loopPrivacyGatewayProvider),
        isNot(same(secondPrivacy)),
      );
      expect(
        container.read(loopSocialPrivacyGatewayProvider),
        isNot(same(secondSocialPrivacy)),
      );
      expect(ownerA.requestTokens.calls, 0);
      expect(ownerB.requestTokens.calls, 0);
    },
  );
}

Future<_Owner> _owner(String principalKey) async {
  final bootstrap = LoopBootstrapSession(
    principalKey: principalKey,
    accessTokens: _Tokens(),
    repository: const _BootstrapRepository(),
  );
  expect(await bootstrap.authorize(), LoopBootstrapAuthorization.authorized);
  final requestTokens = _Tokens();
  return _Owner(
    bootstrap: bootstrap,
    session: LoopAuthenticatedSession(
      principalKey: principalKey,
      bootstrapSession: bootstrap,
      accessTokens: requestTokens,
    ),
    requestTokens: requestTokens,
  );
}

final class _Owner {
  const _Owner({
    required this.bootstrap,
    required this.session,
    required this.requestTokens,
  });

  final LoopBootstrapSession bootstrap;
  final LoopAuthenticatedSession session;
  final _Tokens requestTokens;

  void dispose() {
    session.dispose();
    bootstrap.dispose();
  }
}

final class _Tokens implements LoopBackendAccessTokenSource {
  var calls = 0;

  @override
  Future<String> loadAccessToken() async {
    calls += 1;
    return 'access-token-$calls';
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
