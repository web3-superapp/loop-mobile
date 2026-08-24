import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';

enum EmailAuthStep { enterEmail, enterCode }

@immutable
class EmailAuthState {
  const EmailAuthState({
    this.step = EmailAuthStep.enterEmail,
    this.submittedEmail,
    this.isBusy = false,
    this.errorMessage,
  });

  final EmailAuthStep step;
  final String? submittedEmail;
  final bool isBusy;
  final String? errorMessage;
}

class EmailAuthController extends Notifier<EmailAuthState> {
  @override
  EmailAuthState build() => const EmailAuthState();

  Future<void> sendCode(String input) async {
    if (state.isBusy) return;
    final config = ref.read(appConfigProvider);
    if (!config.canInitializePrivy) {
      state = const EmailAuthState(
        errorMessage: '需要先提供 Privy Mobile App Client ID。',
      );
      return;
    }

    final email = input.trim();
    if (!_isValidEmail(email)) {
      state = const EmailAuthState(errorMessage: '请输入有效的邮箱地址。');
      return;
    }

    state = EmailAuthState(isBusy: true, submittedEmail: email);
    try {
      await ref.read(privyAuthGatewayProvider).sendEmailCode(email);
      state = EmailAuthState(
        step: EmailAuthStep.enterCode,
        submittedEmail: email,
      );
    } on PrivyGatewayException catch (error) {
      state = EmailAuthState(
        submittedEmail: email,
        errorMessage: error.userMessage,
      );
    }
  }

  Future<void> verifyCode(String input) async {
    if (state.isBusy) return;
    final code = input.trim();
    final email = state.submittedEmail;
    if (email == null) {
      state = const EmailAuthState(errorMessage: '请重新发送验证码。');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      state = EmailAuthState(
        step: EmailAuthStep.enterCode,
        submittedEmail: email,
        errorMessage: '请输入 6 位数字验证码。',
      );
      return;
    }

    state = EmailAuthState(
      step: EmailAuthStep.enterCode,
      submittedEmail: email,
      isBusy: true,
    );
    try {
      final account = await ref
          .read(privyAuthGatewayProvider)
          .verifyEmailCode(email: email, code: code);
      ref.read(loopSessionProvider.notifier).acceptAuthenticated(account);
      state = EmailAuthState(submittedEmail: email);
    } on PrivyGatewayException catch (error) {
      state = EmailAuthState(
        step: EmailAuthStep.enterCode,
        submittedEmail: email,
        errorMessage: error.userMessage,
      );
    }
  }

  Future<void> resendCode() async {
    final email = state.submittedEmail;
    if (email == null || state.isBusy) return;
    state = EmailAuthState(
      step: EmailAuthStep.enterCode,
      submittedEmail: email,
      isBusy: true,
    );
    try {
      await ref.read(privyAuthGatewayProvider).sendEmailCode(email);
      state = EmailAuthState(
        step: EmailAuthStep.enterCode,
        submittedEmail: email,
      );
    } on PrivyGatewayException catch (error) {
      state = EmailAuthState(
        step: EmailAuthStep.enterCode,
        submittedEmail: email,
        errorMessage: error.userMessage,
      );
    }
  }

  void changeEmail() {
    if (state.isBusy) return;
    state = const EmailAuthState();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }
}

final emailAuthProvider = NotifierProvider<EmailAuthController, EmailAuthState>(
  EmailAuthController.new,
);
