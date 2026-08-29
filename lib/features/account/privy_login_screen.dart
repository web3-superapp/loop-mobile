import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

/// Production authentication surface backed by Privy credentials.
///
/// Development preview is an explicit offline/read-only mode. Entering it does
/// not create a wallet, connect Stream, bootstrap a backend session, or trade.
class PrivyLoginScreen extends ConsumerStatefulWidget {
  const PrivyLoginScreen({super.key});

  @override
  ConsumerState<PrivyLoginScreen> createState() => _PrivyLoginScreenState();
}

class _PrivyLoginScreenState extends ConsumerState<PrivyLoginScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(loopSessionProvider);
    if (session.mode == LoopSessionMode.restoring) {
      return const PrivySessionRestoreScreen();
    }

    final config = ref.watch(appConfigProvider);
    final previewEnabled = ref.watch(developmentPreviewEnabledProvider);
    final authState = ref.watch(emailAuthProvider);
    final authController = ref.read(emailAuthProvider.notifier);
    final showApple = ref.watch(isIosIdentityPlatformProvider);

    return LoopPage(
      eyebrow: 'PRIVY IDENTITY',
      title: authState.step == EmailAuthStep.enterEmail
          ? 'Welcome to LOOP'
          : 'Check your email',
      subtitle: authState.step == EmailAuthStep.enterEmail
          ? 'Use a one-time email code to enter. Wallet creation remains a separate, explicit action.'
          : 'A 6-digit code was sent to ${authState.submittedEmail}. This address stays fixed until you choose to change it.',
      children: <Widget>[
        if (!config.canInitializePrivy && !previewEnabled) ...<Widget>[
          const LoopStateCard(
            title: 'Login configuration incomplete',
            message: 'The Privy App ID is present, but the Mobile App Client ID is missing. Real OTP calls remain disabled.',
            icon: Icons.key_off_outlined,
            tone: LoopTone.warning,
          ),
          const SizedBox(height: 16),
        ],
        LoopCard(
          accent: true,
          tone: LoopTone.positive,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  authState.step == EmailAuthStep.enterEmail
                      ? 'Continue with email'
                      : authState.submittedEmail ?? 'Email verification',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                if (authState.step == EmailAuthStep.enterEmail)
                  TextField(
                    key: const ValueKey('privy-email-field'),
                    controller: _emailController,
                    enabled: !authState.isBusy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.email],
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email address',
                      hintText: 'name@example.com',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    onSubmitted: authState.isBusy
                        ? null
                        : authController.sendCode,
                  )
                else
                  TextField(
                    key: const ValueKey('privy-otp-field'),
                    controller: _codeController,
                    enabled: !authState.isBusy,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.oneTimeCode],
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Verification code',
                      hintText: '000000',
                      prefixIcon: Icon(Icons.password_rounded),
                    ),
                    onSubmitted: authState.isBusy
                        ? null
                        : authController.verifyCode,
                  ),
                if (authState.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      authState.errorMessage!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: LoopColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey('privy-auth-primary-button'),
                  onPressed: authState.isBusy
                      ? null
                      : () {
                          if (authState.step == EmailAuthStep.enterEmail) {
                            authController.sendCode(_emailController.text);
                          } else {
                            authController.verifyCode(_codeController.text);
                          }
                        },
                  child: authState.isBusy
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          authState.step == EmailAuthStep.enterEmail
                              ? 'Send one-time code'
                              : 'Verify and continue',
                        ),
                ),
                if (authState.step == EmailAuthStep.enterCode) ...<Widget>[
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextButton(
                          onPressed: authState.isBusy
                              ? null
                              : authController.changeEmail,
                          child: const Text('Change email'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: authState.isBusy
                              ? null
                              : authController.resendCode,
                          child: const Text('Resend code'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (previewEnabled) ...<Widget>[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const ValueKey('enter-development-preview-button'),
            onPressed: () =>
                ref.read(loopSessionProvider.notifier).enterPreview(),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Enter development preview'),
          ),
          const SizedBox(height: 12),
          Text(
            '开发预览 · 不会创建钱包、连接 Stream、提交交易或伪造 Provider 状态。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: LoopColors.vapor),
          ),
        ],
        if (authState.step == EmailAuthStep.enterEmail) ...<Widget>[
          const SizedBox(height: 16),
          LoopCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Other sign-in methods',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  key: const ValueKey('privy-google-login-button'),
                  onPressed: authState.isBusy
                      ? null
                      : authController.loginWithGoogle,
                  icon:
                      authState.activeOperation == IdentityAuthOperation.google
                      ? const _IdentityButtonProgress()
                      : const Icon(Icons.g_mobiledata_rounded),
                  label: const Text('Continue with Google'),
                ),
                if (showApple) ...<Widget>[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const ValueKey('privy-apple-login-button'),
                    onPressed: authState.isBusy
                        ? null
                        : authController.loginWithApple,
                    icon:
                        authState.activeOperation == IdentityAuthOperation.apple
                        ? const _IdentityButtonProgress()
                        : const Icon(Icons.apple_rounded),
                    label: const Text('Continue with Apple'),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('privy-wallet-login-button'),
                  onPressed:
                      authState.isBusy || !config.canConnectExternalWallet
                      ? null
                      : () => authController.connectExternalWallet(context),
                  icon:
                      authState.activeOperation ==
                          IdentityAuthOperation.externalWalletLogin
                      ? const _IdentityButtonProgress()
                      : const Icon(Icons.account_balance_wallet_outlined),
                  label: const Text('Connect wallet'),
                ),
                const SizedBox(height: 12),
                Text(
                  'External EVM wallets are Privy sign-in credentials only. They are not LOOP trading wallets and cannot authorize trades.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: LoopColors.vapor),
                ),
                if (!config.hasValidReownProjectId) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Reown Project ID is missing or invalid; wallet connection remains unavailable.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: LoopColors.warning),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _IdentityButtonProgress extends StatelessWidget {
  const _IdentityButtonProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class PrivySessionRestoreScreen extends StatelessWidget {
  const PrivySessionRestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: LoopBackdrop()),
          SafeArea(
            child: Center(
              child: Semantics(
                label: 'LOOP is restoring your Privy session',
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.all_inclusive_rounded,
                      color: LoopColors.mint,
                      size: 72,
                    ),
                    SizedBox(height: 24),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
