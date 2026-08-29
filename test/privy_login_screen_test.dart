import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/features/account/privy_login_screen.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  testWidgets('keeps Email and exposes Google plus external EVM wallet login', (
    tester,
  ) async {
    await _pump(tester, showApple: false);

    expect(find.byKey(const ValueKey('privy-email-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('privy-auth-primary-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('privy-google-login-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('privy-wallet-login-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('privy-apple-login-button')),
      findsNothing,
    );
    expect(find.textContaining('not LOOP trading wallets'), findsOneWidget);
  });

  testWidgets('shows Apple only for the iOS composition', (tester) async {
    await _pump(tester, showApple: true);

    expect(
      find.byKey(const ValueKey('privy-apple-login-button')),
      findsOneWidget,
    );
  });

  testWidgets('disables wallet connection when Reown is not configured', (
    tester,
  ) async {
    await _pump(tester, showApple: false, reownProjectId: '');

    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('privy-wallet-login-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.textContaining('wallet connection remains unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('one OAuth operation disables every authentication action', (
    tester,
  ) async {
    final credential = _CredentialGateway();
    final pending = Completer<PrivyAccountSummary>();
    credential.pending = pending.future;
    await _pump(tester, showApple: true, credential: credential);

    await tester.tap(find.byKey(const ValueKey('privy-google-login-button')));
    await tester.pump();

    expect(credential.calls, 1);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('privy-wallet-login-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('privy-auth-primary-button')),
          )
          .onPressed,
      isNull,
    );

    pending.complete(
      const PrivyAccountSummary(privyUserId: 'did:privy:google'),
    );
    await tester.pump();
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required bool showApple,
  _CredentialGateway? credential,
  String reownProjectId = '26a5cc1adad234fcdf7762b8d2a2b28d',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(
            privyAppId: 'privy-app',
            privyAppClientId: 'privy-client',
            reownProjectId: reownProjectId,
            streamApiKey: '',
            backendBaseUrl: '',
            firebaseConfigured: false,
          ),
        ),
        privyAuthGatewayProvider.overrideWithValue(const _SessionGateway()),
        privyCredentialGatewayProvider.overrideWithValue(
          credential ?? _CredentialGateway(),
        ),
        isIosIdentityPlatformProvider.overrideWithValue(showApple),
      ],
      child: const MaterialApp(home: PrivyLoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _SessionGateway implements PrivyAuthGateway {
  const _SessionGateway();

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) => throw UnimplementedError();

  @override
  Future<String> getCurrentAccessToken() => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Stream<PrivySessionSnapshot> watchSession() => const Stream.empty();
}

class _CredentialGateway implements PrivyCredentialGateway {
  Future<PrivyAccountSummary>? pending;
  var calls = 0;

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
  ) async {
    calls += 1;
    return pending ?? const PrivyAccountSummary(privyUserId: 'did:privy:oauth');
  }

  @override
  Future<PrivyAccountSummary> loginWithSiwe({
    required PrivySiweRequest request,
    required String message,
    required String signature,
  }) => throw UnimplementedError();
}
