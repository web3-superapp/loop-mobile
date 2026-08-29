import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/reown/external_wallet_credential_gateway.dart';
import 'package:loop_mobile/integrations/reown/reown_external_wallet_connector.dart';

void main() {
  late _SessionGateway sessionGateway;
  late _CredentialGateway credentialGateway;
  late _ExternalCredentialGateway externalGateway;
  late ProviderContainer container;

  setUp(() async {
    sessionGateway = _SessionGateway();
    credentialGateway = _CredentialGateway();
    externalGateway = _ExternalCredentialGateway();
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            privyAppId: 'privy-app',
            privyAppClientId: 'privy-client',
            reownProjectId: '26a5cc1adad234fcdf7762b8d2a2b28d',
            streamApiKey: '',
            backendBaseUrl: '',
            firebaseConfigured: false,
          ),
        ),
        privyAuthGatewayProvider.overrideWithValue(sessionGateway),
        privyCredentialGatewayProvider.overrideWithValue(credentialGateway),
        externalWalletCredentialGatewayProvider.overrideWithValue(
          externalGateway,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(loopSessionProvider);
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'Google OAuth uses the shared lease and accepts the Privy account',
    () async {
      final controller = container.read(emailAuthProvider.notifier);

      await controller.loginWithGoogle();

      expect(credentialGateway.oauthProviders, <PrivyOAuthLoginProvider>[
        PrivyOAuthLoginProvider.google,
      ]);
      expect(
        container.read(loopSessionProvider).account?.privyUserId,
        'did:privy:google',
      );
      expect(container.read(emailAuthProvider).isBusy, isFalse);
    },
  );

  test('same-principal SDK stream can win the OAuth response race', () async {
    final pending = Completer<PrivyAccountSummary>();
    credentialGateway.pendingOAuth = pending.future;
    final operation = container
        .read(emailAuthProvider.notifier)
        .loginWithGoogle();
    container
        .read(loopSessionProvider.notifier)
        .acceptAuthenticated(
          const PrivyAccountSummary(privyUserId: 'did:privy:google'),
        );
    pending.complete(
      const PrivyAccountSummary(privyUserId: 'did:privy:google'),
    );

    await operation;

    expect(container.read(emailAuthProvider).errorMessage, isNull);
    expect(
      container.read(loopSessionProvider).account?.privyUserId,
      'did:privy:google',
    );
  });

  test(
    'different-principal SDK stream rejects a late OAuth response',
    () async {
      final pending = Completer<PrivyAccountSummary>();
      credentialGateway.pendingOAuth = pending.future;
      final operation = container
          .read(emailAuthProvider.notifier)
          .loginWithGoogle();
      container
          .read(loopSessionProvider.notifier)
          .acceptAuthenticated(
            const PrivyAccountSummary(privyUserId: 'did:privy:other'),
          );
      pending.complete(
        const PrivyAccountSummary(privyUserId: 'did:privy:google'),
      );

      await operation;

      expect(
        container.read(emailAuthProvider).errorMessage,
        contains('会话状态已变化'),
      );
      expect(
        container.read(loopSessionProvider).account?.privyUserId,
        'did:privy:other',
      );
    },
  );

  test('Apple login remains unavailable outside iOS', () async {
    final controller = container.read(emailAuthProvider.notifier);

    await controller.loginWithApple();

    expect(credentialGateway.oauthProviders, isEmpty);
    expect(container.read(emailAuthProvider).errorMessage, 'Apple 登录仅支持 iOS。');
  });

  testWidgets('signed-out wallet connection always selects SIWE login', (
    tester,
  ) async {
    final context = await _context(tester);

    await container
        .read(emailAuthProvider.notifier)
        .connectExternalWallet(context);

    expect(externalGateway.intents, <ExternalWalletCredentialIntent>[
      ExternalWalletCredentialIntent.login,
    ]);
    expect(externalGateway.expectedPrincipals, <String?>[null]);
    expect(
      container.read(loopSessionProvider).account?.privyUserId,
      'did:privy:wallet-login',
    );
  });

  testWidgets('authenticated wallet connection only links current principal', (
    tester,
  ) async {
    const current = PrivyAccountSummary(privyUserId: 'did:privy:current');
    container.read(loopSessionProvider.notifier).acceptAuthenticated(current);
    externalGateway.result = const PrivyAccountSummary(
      privyUserId: 'did:privy:current',
      externalEvmCredentials: <PrivyExternalEvmCredentialSummary>[
        PrivyExternalEvmCredentialSummary(
          address: '0x1111111111111111111111111111111111111111',
          chainId: '1',
        ),
      ],
    );
    final context = await _context(tester);

    await container
        .read(emailAuthProvider.notifier)
        .connectExternalWallet(context);

    expect(externalGateway.intents.single, ExternalWalletCredentialIntent.link);
    expect(externalGateway.expectedPrincipals.single, 'did:privy:current');
    expect(
      container
          .read(loopSessionProvider)
          .account
          ?.externalEvmCredentials
          .single
          .address,
      '0x1111111111111111111111111111111111111111',
    );
    expect(
      container.read(emailAuthProvider).successMessage,
      contains('Privy 登录凭据'),
    );
  });

  testWidgets(
    'a cross-account link result is rejected without rotating session',
    (tester) async {
      container
          .read(loopSessionProvider.notifier)
          .acceptAuthenticated(
            const PrivyAccountSummary(privyUserId: 'did:privy:current'),
          );
      externalGateway.result = const PrivyAccountSummary(
        privyUserId: 'did:privy:other',
      );
      final context = await _context(tester);

      await container
          .read(emailAuthProvider.notifier)
          .connectExternalWallet(context);

      expect(
        container.read(loopSessionProvider).account?.privyUserId,
        'did:privy:current',
      );
      expect(container.read(emailAuthProvider).errorMessage, contains('账号已变化'));
    },
  );

  testWidgets('wallet ownership and cancellation errors stay explicit', (
    tester,
  ) async {
    final context = await _context(tester);
    externalGateway.error = const PrivyGatewayException(
      '该钱包已属于另一个 Privy 账号，LOOP 不会自动转移或删除账号。',
    );

    await container
        .read(emailAuthProvider.notifier)
        .connectExternalWallet(context);
    expect(
      container.read(emailAuthProvider).errorMessage,
      contains('另一个 Privy 账号'),
    );

    externalGateway.error = const ExternalWalletConnectorException(
      ExternalWalletConnectorFailure.cancelled,
      '已取消钱包连接。',
    );
    await container
        .read(emailAuthProvider.notifier)
        .connectExternalWallet(context);
    expect(container.read(emailAuthProvider).errorMessage, '已取消钱包连接。');
  });

  test('OTP in flight suppresses OAuth and wallet operations', () async {
    final send = Completer<void>();
    sessionGateway.pendingSend = send.future;
    final controller = container.read(emailAuthProvider.notifier);

    final first = controller.sendCode('person@example.com');
    await controller.loginWithGoogle();

    expect(credentialGateway.oauthProviders, isEmpty);
    expect(externalGateway.intents, isEmpty);
    send.complete();
    await first;
  });
}

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext value;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          value = context;
          return const SizedBox();
        },
      ),
    ),
  );
  return value;
}

class _SessionGateway implements PrivyAuthGateway {
  Future<void>? pendingSend;

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
  Future<void> sendEmailCode(String email) async {
    final pending = pendingSend;
    if (pending != null) await pending;
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) async => PrivyAccountSummary(privyUserId: 'did:privy:email', email: email);

  @override
  Stream<PrivySessionSnapshot> watchSession() => const Stream.empty();
}

class _CredentialGateway implements PrivyCredentialGateway {
  final oauthProviders = <PrivyOAuthLoginProvider>[];
  Future<PrivyAccountSummary>? pendingOAuth;

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
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PrivyAccountSummary> loginWithOAuth(
    PrivyOAuthLoginProvider provider,
  ) async {
    oauthProviders.add(provider);
    final pending = pendingOAuth;
    if (pending != null) return pending;
    return PrivyAccountSummary(privyUserId: 'did:privy:${provider.name}');
  }

  @override
  Future<PrivyAccountSummary> loginWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
  }) {
    throw UnimplementedError();
  }
}

class _ExternalCredentialGateway implements ExternalWalletCredentialGateway {
  final intents = <ExternalWalletCredentialIntent>[];
  final expectedPrincipals = <String?>[];
  Object? error;
  PrivyAccountSummary result = const PrivyAccountSummary(
    privyUserId: 'did:privy:wallet-login',
  );

  @override
  Future<PrivyAccountSummary> authenticate({
    required BuildContext context,
    required ExternalWalletCredentialIntent intent,
    String? expectedPrivyUserId,
  }) async {
    intents.add(intent);
    expectedPrincipals.add(expectedPrivyUserId);
    final failure = error;
    error = null;
    if (failure != null) throw failure;
    return result;
  }
}
