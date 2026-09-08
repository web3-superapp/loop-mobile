import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/features/account/privy_otp_screen.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

// One injected instant, advanced explicitly to cross the resend cooldown.
final _base = DateTime.utc(2026, 9, 7, 1);
DateTime _now = _base;

void main() {
  setUp(() => _now = _base);

  testWidgets('shows the empty step when no code was requested', (
    tester,
  ) async {
    await _pump(tester, _Gateway());

    expect(
      find.byKey(const ValueKey<String>('privy-otp-no-destination')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('privy-otp-field')), findsNothing);
    expect(_pressed(tester, 'privy-auth-primary-button'), isNull);
  });

  testWidgets('shows the real destination, cooldown and attempt budget', (
    tester,
  ) async {
    final container = await _pump(tester, _Gateway());
    await _sendCode(tester, container);

    expect(find.textContaining('owner@example.com'), findsOneWidget);
    expect(find.byKey(const ValueKey('privy-otp-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('privy-otp-resend-hint')),
      findsOneWidget,
    );
    // The cooldown is real local state, so resending is blocked right after
    // a code was sent.
    expect(_pressed(tester, 'privy-otp-resend'), isNull);
    expect(find.text('还可尝试 3 次'), findsOneWidget);
  });

  testWidgets('a rejected code spends one attempt and shows the remainder', (
    tester,
  ) async {
    final gateway = _Gateway(verifyFailure: '验证码不正确。');
    final container = await _pump(tester, gateway);
    await _sendCode(tester, container);

    await tester.enterText(
      find.byKey(const ValueKey('privy-otp-field')),
      '000000',
    );
    await tester.tap(find.byKey(const ValueKey('privy-auth-primary-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('privy-otp-error')),
      findsOneWidget,
    );
    expect(find.text('还可尝试 2 次'), findsOneWidget);
    expect(container.read(emailAuthProvider).failedAttempts, 1);
  });

  testWidgets('the attempt budget closes the field instead of retrying', (
    tester,
  ) async {
    final gateway = _Gateway(verifyFailure: '验证码不正确。');
    final container = await _pump(tester, gateway);
    await _sendCode(tester, container);

    for (var attempt = 0; attempt < 3; attempt += 1) {
      await tester.enterText(
        find.byKey(const ValueKey('privy-otp-field')),
        '00000$attempt',
      );
      await tester.tap(find.byKey(const ValueKey('privy-auth-primary-button')));
      await tester.pumpAndSettle();
    }

    expect(gateway.verifyCalls, 3);
    expect(find.text('尝试次数已用完，请重新发送验证码。'), findsOneWidget);
    expect(_pressed(tester, 'privy-auth-primary-button'), isNull);
  });

  testWidgets('the cooldown expires and a resend restores the budget', (
    tester,
  ) async {
    final gateway = _Gateway(verifyFailure: '验证码不正确。');
    final container = await _pump(tester, gateway);
    await _sendCode(tester, container);

    await tester.enterText(
      find.byKey(const ValueKey('privy-otp-field')),
      '000000',
    );
    await tester.tap(find.byKey(const ValueKey('privy-auth-primary-button')));
    await tester.pumpAndSettle();
    expect(container.read(emailAuthProvider).failedAttempts, 1);

    // Move the injected clock past the cooldown instead of waiting.
    _now = _base.add(emailAuthResendCooldown);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey<String>('privy-otp-resend')));
    await tester.pumpAndSettle();

    expect(gateway.sendCalls, 2);
    expect(container.read(emailAuthProvider).failedAttempts, 0);
    expect(find.text('还可尝试 3 次'), findsOneWidget);
  });

  testWidgets('six labelled cells mirror the one real field', (tester) async {
    final container = await _pump(tester, _Gateway());
    await _sendCode(tester, container);

    for (var index = 1; index <= 6; index += 1) {
      expect(
        find.byKey(ValueKey<String>('privy-otp-cell-$index')),
        findsOneWidget,
      );
    }
    // Exactly one field owns the value.
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('privy-otp-field')),
      '8420',
    );
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(
      find.byKey(const ValueKey<String>('privy-otp-cell-1')),
    );
    expect(semantics.label, '验证码第 1 位');
    expect(semantics.value, '8');
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey<String>('privy-otp-cell-5')))
          .value,
      '未填写',
    );
    // A letter never reaches the controller.
    await tester.enterText(
      find.byKey(const ValueKey('privy-otp-field')),
      '84a20x',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey<String>('privy-otp-cell-3')))
          .value,
      '2',
    );
  });

  testWidgets('an in-flight verification shows the loading state', (
    tester,
  ) async {
    final gateway = _Gateway(holdVerify: true);
    final container = await _pump(tester, gateway);
    await _sendCode(tester, container);

    await tester.enterText(
      find.byKey(const ValueKey('privy-otp-field')),
      '842000',
    );
    await tester.tap(find.byKey(const ValueKey('privy-auth-primary-button')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('privy-otp-verifying')),
      findsOneWidget,
    );
    gateway.releaseVerify();
    await tester.pumpAndSettle();
  });

  testWidgets('an unconfirmed delivery is shown as offline, not a bad code', (
    tester,
  ) async {
    final gateway = _Gateway(sendFailure: '验证码发送失败，请稍后重试。');
    final container = await _pump(tester, gateway);
    await container
        .read(emailAuthProvider.notifier)
        .sendCode('owner@example.com');
    await tester.pumpAndSettle();

    // The send failed, so the step never advanced and nothing claims a code
    // was delivered.
    expect(container.read(emailAuthProvider).deliveryUnconfirmed, isTrue);
    expect(container.read(emailAuthProvider).failedAttempts, 0);
  });

  testWidgets('a failed resend shows the offline block on the step', (
    tester,
  ) async {
    final gateway = _Gateway();
    final container = await _pump(tester, gateway);
    await _sendCode(tester, container);

    gateway.sendFailure = '验证码发送失败，请稍后重试。';
    _now = _base.add(emailAuthResendCooldown);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey<String>('privy-otp-resend')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('privy-otp-offline')),
      findsOneWidget,
    );
  });

  testWidgets('leaving the step abandons the pending code', (tester) async {
    var backs = 0;
    final container = await _pump(tester, _Gateway(), onBack: () => backs += 1);
    await _sendCode(tester, container);

    await tester.tap(
      find.byKey(const ValueKey<String>('privy-otp-change-email')),
    );
    await tester.pumpAndSettle();

    expect(container.read(emailAuthProvider).step, EmailAuthStep.enterEmail);
    expect(container.read(emailAuthProvider).submittedEmail, isNull);
    expect(backs, 0);
  });
}

VoidCallback? _pressed(WidgetTester tester, String key) {
  return tester.widget<LoopButton>(find.byKey(ValueKey<String>(key))).onPressed;
}

Future<void> _sendCode(WidgetTester tester, ProviderContainer container) async {
  await container
      .read(emailAuthProvider.notifier)
      .sendCode('owner@example.com');
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Gateway gateway, {
  VoidCallback? onBack,
}) async {
  final container = ProviderContainer(
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
      privyAuthGatewayProvider.overrideWithValue(gateway),
      loopDeviceClockProvider.overrideWithValue(() => _now),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: LoopTheme.dark,
        home: PrivyOtpScreen(onBack: onBack),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

class _Gateway implements PrivyAuthGateway {
  _Gateway({this.verifyFailure, this.sendFailure, this.holdVerify = false});

  final String? verifyFailure;
  String? sendFailure;
  final bool holdVerify;
  final Completer<void> _verifyGate = Completer<void>();
  var sendCalls = 0;
  var verifyCalls = 0;

  void releaseVerify() {
    if (!_verifyGate.isCompleted) _verifyGate.complete();
  }

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
  Future<void> sendEmailCode(String email) async {
    sendCalls += 1;
    final failure = sendFailure;
    if (failure != null) throw PrivyGatewayException(failure);
  }

  @override
  Future<PrivyAccountSummary> verifyEmailCode({
    required String email,
    required String code,
  }) async {
    verifyCalls += 1;
    if (holdVerify) await _verifyGate.future;
    final failure = verifyFailure;
    if (failure != null) throw PrivyGatewayException(failure);
    return const PrivyAccountSummary(privyUserId: 'did:privy:owner');
  }

  @override
  Stream<PrivySessionSnapshot> watchSession() => const Stream.empty();
}
