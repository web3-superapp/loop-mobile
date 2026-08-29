import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/integrations/reown/external_wallet_credential_gateway.dart';
import 'package:loop_mobile/integrations/reown/reown_external_wallet_connector.dart';

enum EmailAuthStep { enterEmail, enterCode }

enum IdentityAuthOperation {
  sendEmailCode,
  verifyEmailCode,
  resendEmailCode,
  google,
  apple,
  externalWalletLogin,
  externalWalletLink,
}

final isIosIdentityPlatformProvider = Provider<bool>((ref) {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
});

@immutable
class EmailAuthState {
  const EmailAuthState({
    this.step = EmailAuthStep.enterEmail,
    this.submittedEmail,
    this.activeOperation,
    this.errorMessage,
    this.successMessage,
  });

  final EmailAuthStep step;
  final String? submittedEmail;
  final IdentityAuthOperation? activeOperation;
  final String? errorMessage;
  final String? successMessage;

  bool get isBusy => activeOperation != null;
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

    state = EmailAuthState(
      activeOperation: IdentityAuthOperation.sendEmailCode,
      submittedEmail: email,
    );
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
      activeOperation: IdentityAuthOperation.verifyEmailCode,
    );
    try {
      final account = await ref
          .read(privyAuthGatewayProvider)
          .verifyEmailCode(email: email, code: code);
      _acceptLoginResult(account);
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
      activeOperation: IdentityAuthOperation.resendEmailCode,
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

  Future<void> loginWithGoogle() =>
      _loginWithOAuth(PrivyOAuthLoginProvider.google);

  Future<void> loginWithApple() async {
    if (!ref.read(isIosIdentityPlatformProvider)) {
      state = const EmailAuthState(errorMessage: 'Apple 登录仅支持 iOS。');
      return;
    }
    await _loginWithOAuth(PrivyOAuthLoginProvider.apple);
  }

  Future<void> _loginWithOAuth(PrivyOAuthLoginProvider provider) async {
    if (state.isBusy) return;
    final session = ref.read(loopSessionProvider);
    if (session.mode != LoopSessionMode.signedOut) {
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: '当前会话状态已变化，请重新检查。',
      );
      return;
    }
    final config = ref.read(appConfigProvider);
    if (!config.canInitializePrivy) {
      state = const EmailAuthState(
        errorMessage: '需要先通过 --dart-define 提供 Privy Mobile App Client ID。',
      );
      return;
    }

    final operation = provider == PrivyOAuthLoginProvider.google
        ? IdentityAuthOperation.google
        : IdentityAuthOperation.apple;
    state = EmailAuthState(
      step: state.step,
      submittedEmail: state.submittedEmail,
      activeOperation: operation,
    );
    try {
      final account = await ref
          .read(privyCredentialGatewayProvider)
          .loginWithOAuth(provider);
      if (!ref.mounted) return;
      _acceptLoginResult(account);
      state = const EmailAuthState();
    } on PrivyGatewayException catch (error) {
      if (!ref.mounted) return;
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: error.userMessage,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: '登录未完成，请检查网络和应用回跳后重试。',
      );
    }
  }

  Future<void> connectExternalWallet(BuildContext context) async {
    if (state.isBusy) return;
    final config = ref.read(appConfigProvider);
    if (!config.canConnectExternalWallet) {
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: config.canInitializePrivy
            ? '需要先通过 --dart-define 提供有效的 Reown Project ID。'
            : '需要先通过 --dart-define 提供 Privy Client ID 和 Reown Project ID。',
      );
      return;
    }

    final requestedSession = ref.read(loopSessionProvider);
    final (
      intent,
      expectedPrincipal,
      operation,
    ) = switch (requestedSession.mode) {
      LoopSessionMode.signedOut => (
        ExternalWalletCredentialIntent.login,
        null,
        IdentityAuthOperation.externalWalletLogin,
      ),
      LoopSessionMode.authenticated when requestedSession.account != null => (
        ExternalWalletCredentialIntent.link,
        requestedSession.account!.privyUserId,
        IdentityAuthOperation.externalWalletLink,
      ),
      _ => (null, null, null),
    };
    if (intent == null || operation == null) {
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: '只有退出登录状态或已验证的 Privy 账号可以连接钱包。',
      );
      return;
    }

    state = EmailAuthState(
      step: state.step,
      submittedEmail: state.submittedEmail,
      activeOperation: operation,
    );
    try {
      final account = await ref
          .read(externalWalletCredentialGatewayProvider)
          .authenticate(
            context: context,
            intent: intent,
            expectedPrivyUserId: expectedPrincipal,
          );
      if (!ref.mounted) return;
      if (intent == ExternalWalletCredentialIntent.login) {
        _acceptLoginResult(account);
        state = const EmailAuthState();
        return;
      }

      ref
          .read(loopSessionProvider.notifier)
          .acceptLinkedAccount(
            account,
            expectedPrivyUserId: expectedPrincipal!,
          );
      state = const EmailAuthState(successMessage: '外部钱包已绑定为 Privy 登录凭据。');
    } on ExternalWalletConnectorException catch (error) {
      if (!ref.mounted) return;
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: error.userMessage,
      );
    } on PrivyGatewayException catch (error) {
      if (!ref.mounted) return;
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: error.userMessage,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = EmailAuthState(
        step: state.step,
        submittedEmail: state.submittedEmail,
        errorMessage: '钱包操作未完成，请检查网络和应用回跳后重试。',
      );
    }
  }

  void clearFeedback() {
    if (state.isBusy) return;
    state = EmailAuthState(
      step: state.step,
      submittedEmail: state.submittedEmail,
    );
  }

  void _acceptLoginResult(PrivyAccountSummary account) {
    final current = ref.read(loopSessionProvider);
    final isPreAuthentication =
        current.mode == LoopSessionMode.restoring ||
        current.mode == LoopSessionMode.signedOut;
    final alreadyAcceptedSamePrincipal =
        current.mode == LoopSessionMode.authenticated &&
        current.account?.privyUserId == account.privyUserId;
    if (!isPreAuthentication && !alreadyAcceptedSamePrincipal) {
      throw const PrivyGatewayException('当前会话状态已变化，请重新检查。');
    }
    ref.read(loopSessionProvider.notifier).acceptAuthenticated(account);
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }
}

final emailAuthProvider = NotifierProvider<EmailAuthController, EmailAuthState>(
  EmailAuthController.new,
);
