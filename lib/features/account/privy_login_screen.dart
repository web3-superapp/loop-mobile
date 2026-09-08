import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `auth`: the identity entry point backed by Privy credentials.
///
/// The second email step lives on its own manifest route (`/auth/otp`); this
/// page only sends the code. Development preview is an explicit offline,
/// read-only mode: entering it creates no wallet, connects no provider and
/// bootstraps no backend session.
class PrivyLoginScreen extends ConsumerStatefulWidget {
  const PrivyLoginScreen({super.key, this.onCodeSent});

  /// Called after a code was accepted for delivery, so the shell can push the
  /// `auth-otp` page.
  final VoidCallback? onCodeSent;

  @override
  ConsumerState<PrivyLoginScreen> createState() => _PrivyLoginScreenState();
}

class _PrivyLoginScreenState extends ConsumerState<PrivyLoginScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(loopSessionProvider);
    if (session.mode == LoopSessionMode.restoring) {
      return const PrivySessionRestoreScreen();
    }
    if (session.mode == LoopSessionMode.signingOut) {
      return const PrivySessionSignOutScreen();
    }

    final config = ref.watch(appConfigProvider);
    final previewEnabled = ref.watch(developmentPreviewEnabledProvider);
    final authState = ref.watch(emailAuthProvider);
    final controller = ref.read(emailAuthProvider.notifier);
    final showApple = ref.watch(isIosIdentityPlatformProvider);

    return LoopFocusPage(
      archetype: LoopPageArchetype.intro,
      title: '欢迎来到 LOOP',
      primaryAction: LoopButton(
        key: const ValueKey<String>('privy-auth-primary-button'),
        label: authState.isBusy ? '发送中…' : '发送验证码',
        primary: true,
        block: true,
        onPressed: authState.isBusy
            ? null
            : () => unawaited(_sendCode(controller)),
      ),
      body: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Center(
            child: LoopBrandMark(
              key: ValueKey<String>('privy-auth-mark'),
              kind: LoopBrandMarkKind.appIcon,
              height: 84,
              semanticLabel: 'LOOP',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            LoopSpacing.group,
          ),
          child: Text(
            '登录后自动创建钱包，持仓即产生算力。',
            textAlign: TextAlign.center,
            style: LoopTypography.sora(
              size: 14,
              weight: FontWeight.w500,
              height: 1.5,
              color: LoopColors.text2,
            ),
          ),
        ),
        if (!config.canInitializePrivy && !previewEnabled)
          const LoopNotice(
            key: ValueKey<String>('privy-auth-configuration-incomplete'),
            icon: 'warn',
            tone: LoopNoticeTone.warn,
            title: '登录配置不完整',
            body: '缺少 Privy Mobile App Client ID，真实的验证码请求保持关闭。',
          ),
        const LoopLabel('用邮箱登录'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
          child: LoopSurfaceCard(
            child: AutofillGroup(
              child: TextField(
                key: const ValueKey<String>('privy-email-field'),
                controller: _emailController,
                enabled: !authState.isBusy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'name@example.com',
                ),
                onSubmitted: authState.isBusy
                    ? null
                    : (_) => unawaited(_sendCode(controller)),
              ),
            ),
          ),
        ),
        if (authState.errorMessage != null)
          LoopNotice(
            key: const ValueKey<String>('privy-auth-error'),
            icon: 'close',
            tone: LoopNoticeTone.danger,
            title: '无法继续',
            body: authState.errorMessage!,
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
        const LoopLabel('或'),
        _AuthMethod(
          identifier: 'privy-google-login-button',
          label: '使用 Google 继续',
          busy: authState.activeOperation == IdentityAuthOperation.google,
          available: config.canInitializePrivy,
          unavailableReason: '缺少 Privy Mobile App Client ID',
          onPressed: authState.isBusy ? null : controller.loginWithGoogle,
        ),
        if (showApple)
          _AuthMethod(
            identifier: 'privy-apple-login-button',
            label: '使用 Apple 继续',
            busy: authState.activeOperation == IdentityAuthOperation.apple,
            available: config.canInitializePrivy,
            unavailableReason: '缺少 Privy Mobile App Client ID',
            onPressed: authState.isBusy ? null : controller.loginWithApple,
          ),
        _AuthMethod(
          identifier: 'privy-wallet-login-button',
          label: '连接已有钱包',
          busy:
              authState.activeOperation ==
              IdentityAuthOperation.externalWalletLogin,
          available: config.canConnectExternalWallet,
          unavailableReason: config.hasValidReownProjectId
              ? '缺少 Privy Mobile App Client ID'
              : '缺少有效的 Reown Project ID',
          onPressed: authState.isBusy
              ? null
              : () => unawaited(controller.connectExternalWallet(context)),
        ),
        const LoopNotice(
          icon: 'info',
          title: '外部钱包只是登录凭证',
          body: '它不是 LOOP 交易钱包，也不能授权任何交易。',
          margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            14,
            LoopSpacing.page,
            0,
          ),
          child: Text(
            '继续即表示同意用户协议与隐私政策',
            textAlign: TextAlign.center,
            style: LoopTypography.sora(
              size: 11,
              weight: FontWeight.w400,
              color: LoopColors.text3,
            ),
          ),
        ),
        if (previewEnabled) ...<Widget>[
          const LoopLabel('开发预览'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
            child: LoopButton(
              key: const ValueKey<String>('enter-development-preview-button'),
              label: '进入开发预览',
              block: true,
              onPressed: () =>
                  ref.read(loopSessionProvider.notifier).enterPreview(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              10,
              LoopSpacing.page,
              0,
            ),
            child: Text(
              '开发预览 · 不会创建钱包、连接 Stream、提交交易或伪造 Provider 状态。',
              textAlign: TextAlign.center,
              style: LoopTypography.sora(
                size: 11,
                weight: FontWeight.w400,
                color: LoopColors.text3,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
      ],
    );
  }

  Future<void> _sendCode(EmailAuthController controller) async {
    await controller.sendCode(_emailController.text);
    if (!mounted) return;
    if (ref.read(emailAuthProvider).step == EmailAuthStep.enterCode) {
      widget.onCodeSent?.call();
    }
  }
}

/// One sign-in method row. An unavailable method states its reason instead of
/// silently disabling itself.
class _AuthMethod extends StatelessWidget {
  const _AuthMethod({
    required this.identifier,
    required this.label,
    required this.busy,
    required this.available,
    required this.unavailableReason,
    required this.onPressed,
  });

  final String identifier;
  final String label;
  final bool busy;
  final bool available;
  final String unavailableReason;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LoopButton(
            key: ValueKey<String>(identifier),
            label: busy ? '$label…' : label,
            block: true,
            onPressed: available ? onPressed : null,
          ),
          if (!available)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '暂不可用 · $unavailableReason',
                style: LoopTypography.sora(
                  size: 11,
                  weight: FontWeight.w400,
                  color: LoopColors.text3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PrivySessionRestoreScreen extends StatelessWidget {
  const PrivySessionRestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('privy-restoring-screen'),
      body: SafeArea(
        child: Center(
          child: Semantics(
            label: 'LOOP 正在恢复登录状态',
            liveRegion: true,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LoopBrandMark(
                  kind: LoopBrandMarkKind.appIcon,
                  height: 72,
                  semanticLabel: 'LOOP',
                ),
                SizedBox(height: 24),
                SizedBox(
                  width: 160,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: LoopColors.line2,
                    valueColor: AlwaysStoppedAnimation<Color>(LoopColors.lime),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PrivySessionSignOutScreen extends StatelessWidget {
  const PrivySessionSignOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('privy-signing-out-screen'),
      body: SafeArea(
        child: Center(
          child: Semantics(
            label: 'LOOP 正在安全退出',
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(
                  width: 160,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: LoopColors.line2,
                    valueColor: AlwaysStoppedAnimation<Color>(LoopColors.lime),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '正在安全退出',
                  style: LoopTypography.sora(
                    size: 13,
                    weight: FontWeight.w500,
                    color: LoopColors.text2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
