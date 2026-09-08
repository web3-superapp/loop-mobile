import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

void main() {
  late _FakePrivyGateway gateway;
  late ProviderContainer container;

  setUp(() {
    gateway = _FakePrivyGateway();
    container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            privyAppId: 'app-id',
            privyAppClientId: 'client-id',
            streamApiKey: 'stream-key',
            backendBaseUrl: '',
            firebaseConfigured: false,
          ),
        ),
        developmentPreviewEnabledProvider.overrideWithValue(true),
        privyAuthGatewayProvider.overrideWithValue(gateway),
      ],
    );
    addTearDown(container.dispose);
  });

  test('freezes normalized email between send, resend, and verify', () async {
    final controller = container.read(emailAuthProvider.notifier);
    var now = DateTime.utc(2026, 9, 8, 10);
    controller.clock = () => now;

    await controller.sendCode('  person@example.com  ');
    expect(gateway.sentEmails, <String>['person@example.com']);
    expect(container.read(emailAuthProvider).step, EmailAuthStep.enterCode);
    expect(
      container.read(emailAuthProvider).submittedEmail,
      'person@example.com',
    );

    // Sending starts a local resend cooldown on this device.
    final afterSend = container.read(emailAuthProvider);
    expect(afterSend.resendAvailableAt, now.add(emailAuthResendCooldown));
    expect(
      afterSend.resendCooldownSeconds(now),
      emailAuthResendCooldown.inSeconds,
    );
    expect(afterSend.canResend(now), isFalse);
    expect(afterSend.failedAttempts, 0);
    expect(afterSend.remainingAttempts, emailAuthMaximumAttempts);

    // A resend inside the cooldown is a no-op and must not re-send.
    await controller.resendCode();
    expect(gateway.sentEmails, <String>['person@example.com']);
    expect(
      container.read(emailAuthProvider).submittedEmail,
      'person@example.com',
    );

    now = now.add(emailAuthResendCooldown + const Duration(seconds: 1));
    expect(container.read(emailAuthProvider).canResend(now), isTrue);

    await controller.resendCode();
    // The resend restarts the cooldown from the new instant, still on the
    // frozen email.
    final afterResend = container.read(emailAuthProvider);
    expect(afterResend.submittedEmail, 'person@example.com');
    expect(afterResend.resendAvailableAt, now.add(emailAuthResendCooldown));
    expect(afterResend.canResend(now), isFalse);

    await controller.verifyCode('123456');

    expect(gateway.sentEmails, <String>[
      'person@example.com',
      'person@example.com',
    ]);
    expect(gateway.verifiedEmails, <String>['person@example.com']);
    expect(
      container.read(loopSessionProvider).mode,
      LoopSessionMode.authenticated,
    );
  });

  test('counts local verification attempts and a resend clears them', () async {
    final controller = container.read(emailAuthProvider.notifier);
    var now = DateTime.utc(2026, 9, 8, 10);
    controller.clock = () => now;
    gateway.verifyFailure = const PrivyGatewayException('验证码不正确。');

    await controller.sendCode('person@example.com');

    await controller.verifyCode('123456');
    var state = container.read(emailAuthProvider);
    expect(state.failedAttempts, 1);
    expect(state.remainingAttempts, emailAuthMaximumAttempts - 1);
    expect(state.attemptsExhausted, isFalse);
    expect(state.errorMessage, contains('验证码不正确。'));
    expect(
      state.errorMessage,
      contains('还可尝试 ${emailAuthMaximumAttempts - 1} 次'),
    );
    expect(state.submittedEmail, 'person@example.com');

    for (var attempt = 2; attempt <= emailAuthMaximumAttempts; attempt++) {
      await controller.verifyCode('123456');
    }
    state = container.read(emailAuthProvider);
    expect(state.failedAttempts, emailAuthMaximumAttempts);
    expect(state.remainingAttempts, 0);
    expect(state.attemptsExhausted, isTrue);
    expect(state.errorMessage, contains('尝试次数已用完'));
    expect(gateway.verifiedEmails, hasLength(emailAuthMaximumAttempts));

    // Exhausted: the client stops asking the provider at all.
    await controller.verifyCode('123456');
    expect(gateway.verifiedEmails, hasLength(emailAuthMaximumAttempts));

    // A newly delivered code resets the local attempt budget.
    now = now.add(emailAuthResendCooldown + const Duration(seconds: 1));
    await controller.resendCode();
    state = container.read(emailAuthProvider);
    expect(state.failedAttempts, 0);
    expect(state.attemptsExhausted, isFalse);
    expect(state.errorMessage, isNull);
    expect(state.step, EmailAuthStep.enterCode);
    expect(state.submittedEmail, 'person@example.com');

    gateway.verifyFailure = null;
    await controller.verifyCode('123456');
    expect(
      container.read(loopSessionProvider).mode,
      LoopSessionMode.authenticated,
    );
  });

  test('rejects malformed email and non-six-digit OTP', () async {
    final controller = container.read(emailAuthProvider.notifier);

    await controller.sendCode('not-an-email');
    expect(gateway.sentEmails, isEmpty);
    expect(container.read(emailAuthProvider).errorMessage, isNotNull);

    await controller.sendCode('person@example.com');
    await controller.verifyCode('12345');
    expect(gateway.verifiedEmails, isEmpty);
    expect(container.read(emailAuthProvider).errorMessage, contains('6'));
  });

  test(
    'suppresses duplicate submissions while a request is in flight',
    () async {
      final pendingSend = Completer<void>();
      gateway.pendingSend = pendingSend.future;
      final controller = container.read(emailAuthProvider.notifier);

      final first = controller.sendCode('person@example.com');
      final duplicate = controller.sendCode('other@example.com');

      expect(container.read(emailAuthProvider).isBusy, isTrue);
      expect(gateway.sentEmails, <String>['person@example.com']);
      pendingSend.complete();
      await Future.wait(<Future<void>>[first, duplicate]);

      expect(gateway.sentEmails, <String>['person@example.com']);
      expect(
        container.read(emailAuthProvider).submittedEmail,
        'person@example.com',
      );
    },
  );

  test(
    'cached unverified session remains restricted instead of logout',
    () async {
      gateway.restoreSnapshot = const PrivySessionSnapshot(
        PrivySessionKind.authenticatedUnverified,
      );

      expect(
        container.read(loopSessionProvider).mode,
        LoopSessionMode.restoring,
      );
      await Future<void>.delayed(Duration.zero);

      final session = container.read(loopSessionProvider);
      expect(session.mode, LoopSessionMode.authenticatedUnverified);
      expect(session.canEnterProduct, isTrue);
      expect(session.canUseProviderBackedFeatures, isFalse);
      await expectLater(
        container.read(loopSessionProvider.notifier).createWallet(),
        throwsA(isA<PrivyGatewayException>()),
      );
    },
  );

  test('development preview never creates a wallet', () async {
    final controller = container.read(loopSessionProvider.notifier);
    controller.enterPreview();

    await expectLater(
      controller.createWallet(),
      throwsA(isA<PrivyGatewayException>()),
    );
    expect(gateway.walletCreationCalls, 0);
  });
}

class _FakePrivyGateway implements PrivyAuthGateway {
  final sentEmails = <String>[];
  final verifiedEmails = <String>[];
  Future<void>? pendingSend;
  PrivyGatewayException? verifyFailure;
  var walletCreationCalls = 0;
  PrivySessionSnapshot restoreSnapshot = const PrivySessionSnapshot(
    PrivySessionKind.unauthenticated,
  );

  @override
  Future<PrivyWalletCreationResult> createFirstEthereumWallet({
    required String expectedPrivyUserId,
  }) async {
    walletCreationCalls += 1;
    return PrivyWalletCreationResult(
      privyUserId: expectedPrivyUserId,
      wallet: const PrivyWalletSummary(address: '0x123'),
    );
  }

  @override
  Future<String> getCurrentAccessToken() async => 'ephemeral-access-token';

  @override
  Future<void> logout() async {}

  @override
  Future<PrivySessionSnapshot> restoreSession() async => restoreSnapshot;

  @override
  Future<void> sendEmailCode(String email) async {
    sentEmails.add(email);
    final operation = pendingSend;
    if (operation != null) await operation;
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    verifiedEmails.add(email);
    final failure = verifyFailure;
    if (failure != null) throw failure;
    return PrivyAccountSummary(privyUserId: 'did:privy:test', email: email);
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() => const Stream.empty();
}
