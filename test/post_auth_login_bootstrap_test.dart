import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap.dart';
import 'package:loop_mobile/integrations/backend/loop_bootstrap_providers.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/reown/external_wallet_credential_gateway.dart';

void main() {
  for (final method in _LoginMethod.values) {
    testWidgets(
      '${method.name} login triggers one non-blocking LOOP bootstrap',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        final tokens = _Tokens();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appConfigProvider.overrideWithValue(
                const AppConfig(
                  privyAppId: 'privy-app',
                  privyAppClientId: 'privy-client',
                  reownProjectId: '26a5cc1adad234fcdf7762b8d2a2b28d',
                  streamApiKey: '',
                  backendBaseUrl: 'https://api.example.com',
                  firebaseConfigured: false,
                ),
              ),
              privyAuthGatewayProvider.overrideWithValue(const _AuthGateway()),
              privyCredentialGatewayProvider.overrideWithValue(
                const _CredentialGateway(),
              ),
              externalWalletCredentialGatewayProvider.overrideWithValue(
                const _ExternalGateway(),
              ),
              loopBootstrapRepositoryProvider.overrideWithValue(repository),
              loopBackendAccessTokenSourceProvider.overrideWithValue(tokens),
              isIosIdentityPlatformProvider.overrideWithValue(true),
            ],
            child: const LoopApp(),
          ),
        );
        await tester.pumpAndSettle();

        await _completeLogin(tester, method);
        await tester.pumpAndSettle();

        expect(repository.calls, 1);
        expect(tokens.calls, 1);
        expect(find.text('Home overview'), findsOneWidget);
      },
    );
  }
}

enum _LoginMethod { email, google, apple, wallet }

Future<void> _completeLogin(WidgetTester tester, _LoginMethod method) async {
  switch (method) {
    case _LoginMethod.email:
      await tester.enterText(
        find.byKey(const ValueKey('privy-email-field')),
        'person@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('privy-auth-primary-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('privy-otp-field')),
        '123456',
      );
      await tester.tap(find.byKey(const ValueKey('privy-auth-primary-button')));
    case _LoginMethod.google:
      await tester.tap(find.byKey(const ValueKey('privy-google-login-button')));
    case _LoginMethod.apple:
      await tester.tap(find.byKey(const ValueKey('privy-apple-login-button')));
    case _LoginMethod.wallet:
      await tester.tap(find.byKey(const ValueKey('privy-wallet-login-button')));
  }
}

class _AuthGateway implements PrivyAuthGateway {
  const _AuthGateway();

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) => throw UnimplementedError();

  @override
  Future<String> getCurrentAccessToken() async => 'access-token';

  @override
  Future<void> logout() async {}

  @override
  Future<PrivySessionSnapshot> restoreSession() async =>
      const PrivySessionSnapshot(PrivySessionKind.unauthenticated);

  @override
  Future<void> sendEmailCode(String email) async {}

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) async => const PrivyAccountSummary(privyUserId: 'did:privy:login');

  @override
  Stream<PrivySessionSnapshot> watchSession() => const Stream.empty();
}

class _CredentialGateway implements PrivyCredentialGateway {
  const _CredentialGateway();

  @override
  Future<String> generateSiweMessage(PrivySiweRequest request) {
    throw UnimplementedError();
  }

  @override
  Future<PrivyAccountSummary> linkWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
    required String expectedPrivyUserId,
  }) => throw UnimplementedError();

  @override
  Future<PrivyAccountSummary> loginWithOAuth(
    PrivyOAuthLoginProvider provider,
  ) async => const PrivyAccountSummary(privyUserId: 'did:privy:login');

  @override
  Future<PrivyAccountSummary> loginWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
  }) => throw UnimplementedError();
}

class _ExternalGateway implements ExternalWalletCredentialGateway {
  const _ExternalGateway();

  @override
  Future<PrivyAccountSummary> authenticate({
    required BuildContext context,
    required ExternalWalletCredentialIntent intent,
    String? expectedPrivyUserId,
  }) async => const PrivyAccountSummary(privyUserId: 'did:privy:login');
}

class _Repository implements LoopBootstrapRepository {
  var calls = 0;

  @override
  Future<LoopBootstrapIdentity> bootstrap({required String accessToken}) async {
    calls += 1;
    return const LoopBootstrapIdentity(
      loopUserId: '7a7448be-64e2-4f9f-a9f1-891f1beec7fd',
      streamUserId: 'loop_7a7448be64e24f9fa9f1891f1beec7fd',
    );
  }
}

class _Tokens implements LoopBackendAccessTokenSource {
  var calls = 0;

  @override
  Future<String> loadAccessToken() async {
    calls += 1;
    return 'current-access-token';
  }
}
