import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
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

  testWidgets(
    'signing out blocks every login entry until backend cleanup really ends',
    (tester) async {
      final gateway = _SigningOutGateway();
      final container = ProviderContainer(
        overrides: [privyAuthGatewayProvider.overrideWithValue(gateway)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PrivyLoginScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.authenticated,
      );

      final backendGate = Completer<LoopBackendLogoutResult>();
      final exit = container
          .read(loopSessionProvider.notifier)
          .exit(revokeBackend: (_) => backendGate.future);
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('privy-signing-out-screen')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('privy-email-field')), findsNothing);
      expect(
        find.byKey(const ValueKey('privy-google-login-button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('enter-development-preview-button')),
        findsNothing,
      );

      // The removed controller-level timeout used to release this boundary
      // after 20 seconds while the non-cancellable revoke Future kept running.
      await tester.pump(const Duration(seconds: 21));
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signingOut,
      );
      expect(gateway.logoutCalls, 0);

      backendGate.complete(LoopBackendLogoutResult.confirmed);
      await exit;
      await tester.pump();

      expect(gateway.logoutCalls, 1);
      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.signedOut,
      );
    },
  );
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

class _SigningOutGateway implements PrivyAuthGateway {
  var logoutCalls = 0;

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) => throw UnimplementedError();

  @override
  Future<String> getCurrentAccessToken() => throw UnimplementedError();

  @override
  Future<void> logout() async {
    logoutCalls += 1;
  }

  @override
  Future<PrivySessionSnapshot> restoreSession() async {
    return const PrivySessionSnapshot(
      PrivySessionKind.authenticated,
      account: PrivyAccountSummary(privyUserId: 'did:privy:old'),
    );
  }

  @override
  Future<void> sendEmailCode(String email) => throw UnimplementedError();

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
