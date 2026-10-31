import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/app/app_config.dart';
import 'package:loop_mobile/app/session/loop_session_controller.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart'
    show LoopLaunchFrame, SplashScreen;
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/features/account/identity_step_scaffold.dart';
import 'package:loop_mobile/integrations/privy/privy_auth_gateway.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `auth`: the identity entry point backed by Privy credentials.
///
/// UX-002 (decision 0254, layout one of the three the designer offered): the
/// mark, 欢迎来到 LOOP and one line; three methods of one shape — Apple (the
/// Yellow one, iOS only), Google and 邮箱 — then 已有钱包？连接钱包 as a text
/// link, and the terms line at the foot of the page. 使用邮箱登录 opens its own
/// step (`/auth/email`); this page sends nothing itself. Each method shows
/// its own busy state: only the method that was pressed says it is working.
///
/// Development preview is an explicit offline, read-only mode: entering it
/// creates no wallet, connects no provider and bootstraps no backend session.
class PrivyLoginScreen extends ConsumerWidget {
  const PrivyLoginScreen({super.key, this.onOpenEmail});

  /// Opens the e-mail step (`/auth/email`).
  final VoidCallback? onOpenEmail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(loopSessionProvider);
    // Decision 0064: restoring and "temporarily unreachable" are both
    // undecided. Only an explicit Privy sign-out reaches the form below.
    // Decision 0124: Privy said "unauthenticated" with no network behind it.
    // The frame waits for the network instead of showing the form.
    if (session.isAwaitingNetwork) {
      return PrivySessionAwaitingNetworkScreen(
        onUseAnotherAccount: () =>
            ref.read(loopSessionProvider.notifier).useAnotherAccount(),
      );
    }
    if (session.isRestoring) {
      return PrivySessionRestoreScreen(
        unreachableMessage: session.isRestoreUnavailable
            ? (session.errorMessage ?? loopUndecidedSessionMessage)
            : null,
        onRetry: session.isRestoreUnavailable
            ? () => unawaited(
                ref.read(loopSessionProvider.notifier).retryRestore(),
              )
            : null,
      );
    }
    if (session.mode == LoopSessionMode.signingOut) {
      return const PrivySessionSignOutScreen();
    }
    // S253: a session that may enter the product is never a reason to draw
    // the credential form. The launch frame stays until the router takes the
    // owner away.
    if (session.canEnterProduct) return const PrivySessionHandoverFrame();

    final config = ref.watch(appConfigProvider);
    final previewEnabled = ref.watch(developmentPreviewEnabledProvider);
    final authState = ref.watch(emailAuthProvider);
    final controller = ref.read(emailAuthProvider.notifier);
    final showApple =
        ref.watch(isIosIdentityPlatformProvider) &&
        ref.watch(loopFeatureSwitchesProvider).appleLoginVisible;
    final busy = authState.isBusy;
    final operation = authState.activeOperation;

    return Scaffold(
      key: const ValueKey<String>('privy-auth-screen'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // `.identity-head`: mark, title, one line of copy.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 56, 16, 36),
                      child: Semantics(
                        header: true,
                        container: true,
                        child: Column(
                          children: <Widget>[
                            const LoopBrandMark(
                              key: ValueKey<String>('privy-auth-mark'),
                              kind: LoopBrandMarkKind.officialIcon,
                              height: 104,
                              semanticLabel: 'LOOP',
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '欢迎来到 LOOP',
                              textAlign: TextAlign.center,
                              style: LoopType.stepTitle,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '选择一种方式登录或创建账户',
                              textAlign: TextAlign.center,
                              style: LoopType.body.copyWith(
                                color: LoopColors.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!config.canInitializePrivy && !previewEnabled)
                      const LoopNotice(
                        key: ValueKey<String>(
                          'privy-auth-configuration-incomplete',
                        ),
                        icon: 'warn',
                        tone: LoopNoticeTone.warn,
                        title: '登录配置不完整',
                        body: '缺少 Privy Mobile App Client ID，真实的验证码请求保持关闭。',
                      ),
                    if (showApple)
                      AuthMethodButton(
                        key: const ValueKey<String>('privy-apple-login-button'),
                        label: '使用 Apple 登录',
                        leading: const Icon(
                          Icons.apple,
                          size: 22,
                          color: LoopColors.ink,
                        ),
                        primary: true,
                        busy: operation == IdentityAuthOperation.apple,
                        onPressed: !config.canInitializePrivy || busy
                            ? null
                            : () => unawaited(controller.loginWithApple()),
                      ),
                    AuthMethodButton(
                      key: const ValueKey<String>('privy-google-login-button'),
                      label: '使用 Google 登录',
                      leading: const _GoogleMark(),
                      busy: operation == IdentityAuthOperation.google,
                      onPressed: !config.canInitializePrivy || busy
                          ? null
                          : () => unawaited(controller.loginWithGoogle()),
                    ),
                    AuthMethodButton(
                      key: const ValueKey<String>('privy-email-login-button'),
                      label: '使用邮箱登录',
                      leading: const LoopIcon(
                        'mail',
                        size: 20,
                        color: LoopColors.chalk,
                      ),
                      // Opening the step is not an operation: it never says
                      // it is busy, it only waits while another method is.
                      busy: false,
                      onPressed: busy ? null : onOpenEmail,
                    ),
                    if (authState.errorMessage != null)
                      LoopNotice(
                        key: const ValueKey<String>('privy-auth-error'),
                        icon: 'close',
                        tone: LoopNoticeTone.danger,
                        title: '无法继续',
                        body: authState.errorMessage!,
                        margin: const EdgeInsets.fromLTRB(
                          LoopSpacing.page,
                          4,
                          LoopSpacing.page,
                          0,
                        ),
                      ),
                    const SizedBox(height: 18),
                    _WalletLink(
                      busy:
                          operation ==
                          IdentityAuthOperation.externalWalletLogin,
                      onPressed: !config.canConnectExternalWallet || busy
                          ? null
                          : () => unawaited(
                              controller.connectExternalWallet(context),
                            ),
                    ),
                    if (!config.canConnectExternalWallet)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          config.hasValidReownProjectId
                              ? '暂不可用 · 缺少 Privy Mobile App Client ID'
                              : '暂不可用 · 缺少有效的 Reown Project ID',
                          textAlign: TextAlign.center,
                          style: LoopType.captionSm,
                        ),
                      ),
                    if (previewEnabled) ...<Widget>[
                      const LoopLabel('开发预览'),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: LoopSpacing.page,
                        ),
                        child: LoopButton(
                          key: const ValueKey<String>(
                            'enter-development-preview-button',
                          ),
                          label: '进入开发预览',
                          block: true,
                          onPressed: () => ref
                              .read(loopSessionProvider.notifier)
                              .enterPreview(),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        LoopSpacing.page,
                        24,
                        LoopSpacing.page,
                        loopChildPageBottomInset(context) + 12,
                      ),
                      child: Text.rich(
                        key: const ValueKey<String>('privy-auth-terms'),
                        TextSpan(
                          style: LoopType.captionSm,
                          children: <InlineSpan>[
                            const TextSpan(text: '继续即表示同意 '),
                            TextSpan(
                              text: '用户协议',
                              style: LoopTypography.withWeight(
                                LoopType.captionSm,
                                FontWeight.w700,
                              ).copyWith(color: LoopColors.chalk),
                            ),
                            const TextSpan(text: ' 和 '),
                            TextSpan(
                              text: '隐私政策',
                              style: LoopTypography.withWeight(
                                LoopType.captionSm,
                                FontWeight.w700,
                              ).copyWith(color: LoopColors.chalk),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `auth-email`: the e-mail step 使用邮箱登录 opens (UX-002, decision 0254).
///
/// One field and 获取验证码. Only that button says 发送中… while the code is
/// being sent; the busy state of a Google or Apple attempt never reaches it.
class PrivyEmailScreen extends ConsumerStatefulWidget {
  const PrivyEmailScreen({super.key, this.onBack, this.onCodeSent});

  final VoidCallback? onBack;

  /// Called after a code was accepted for delivery, so the shell can push the
  /// `auth-otp` page.
  final VoidCallback? onCodeSent;

  @override
  ConsumerState<PrivyEmailScreen> createState() => _PrivyEmailScreenState();
}

class _PrivyEmailScreenState extends ConsumerState<PrivyEmailScreen> {
  late final TextEditingController _emailController = TextEditingController(
    text: ref.read(emailAuthProvider).submittedEmail ?? '',
  );

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEdited);
  }

  void _onEdited() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _emailController
      ..removeListener(_onEdited)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(emailAuthProvider);
    final controller = ref.read(emailAuthProvider.notifier);
    final sending =
        authState.activeOperation == IdentityAuthOperation.sendEmailCode;
    final busy = authState.isBusy;
    final empty = _emailController.text.trim().isEmpty;
    return IdentityStepScaffold(
      key: const ValueKey<String>('privy-email-screen'),
      title: '邮箱登录',
      onBack: widget.onBack,
      body: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
          child: AutofillGroup(
            child: TextField(
              key: const ValueKey<String>('privy-email-field'),
              controller: _emailController,
              enabled: !busy,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.email],
              autocorrect: false,
              style: LoopType.bodyLg,
              decoration: loopFormFieldDecoration(hint: 'name@example.com'),
              onSubmitted: busy || empty
                  ? null
                  : (_) => unawaited(_sendCode(controller)),
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
            margin: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
          ),
      ],
      primaryAction: LoopButton(
        key: const ValueKey<String>('privy-auth-primary-button'),
        label: sending ? '发送中…' : '获取验证码',
        primary: true,
        block: true,
        onPressed: busy || empty
            ? null
            : () => unawaited(_sendCode(controller)),
      ),
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

/// One sign-in method: a full-width 52 control with its mark on the left of
/// the label. The Yellow one is the method the page pushes; the others are
/// the Graphite ground with a hairline.
class AuthMethodButton extends StatelessWidget {
  const AuthMethodButton({
    required this.label,
    required this.leading,
    required this.busy,
    required this.onPressed,
    super.key,
    this.primary = false,
  });

  final String label;
  final Widget leading;

  /// This method is the operation in flight. Only this one says so.
  final bool busy;
  final VoidCallback? onPressed;
  final bool primary;

  static const double height = 52;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = primary ? LoopColors.ink : LoopColors.chalk;
    final background = primary ? LoopColors.yellow : LoopColors.card;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        12,
      ),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: busy ? '$label，正在进行' : label,
        excludeSemantics: true,
        child: Opacity(
          opacity: enabled || busy ? 1 : 0.5,
          child: Material(
            color: background,
            shape: RoundedRectangleBorder(
              borderRadius: LoopRadius.button,
              side: primary
                  ? BorderSide.none
                  : const BorderSide(color: LoopColors.line2),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                height: height,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox.square(
                      dimension: 22,
                      child: Center(
                        child: busy
                            ? SizedBox.square(
                                key: const ValueKey<String>('auth-method-busy'),
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: foreground,
                                ),
                              )
                            : leading,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      busy ? '$label…' : label,
                      style: LoopTypography.withWeight(
                        LoopType.bodyLg,
                        FontWeight.w700,
                      ).copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 已有钱包？连接钱包 — the wallet login as one text link.
class _WalletLink extends StatelessWidget {
  const _WalletLink({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Center(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: busy ? '正在连接钱包' : '已有钱包？连接钱包',
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey<String>('privy-wallet-login-button'),
          onTap: onPressed,
          borderRadius: LoopRadius.control,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text.rich(
                  TextSpan(
                    style: LoopType.body.copyWith(color: LoopColors.text2),
                    children: <InlineSpan>[
                      const TextSpan(text: '已有钱包？'),
                      TextSpan(
                        text: busy ? '正在连接…' : '连接钱包',
                        style:
                            LoopTypography.withWeight(
                              LoopType.body,
                              FontWeight.w700,
                            ).copyWith(
                              color: enabled || busy
                                  ? LoopColors.yellow
                                  : LoopColors.text3,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google's four-colour G, drawn from its published path.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  static const String _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
      '<path fill="#FFC107" d="M43.611 20.083H42V20H24v8h11.303c-1.649 4.657-6.08 8-11.303 8-6.627 0-12-5.373-12-12s5.373-12 12-12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 12.955 4 4 12.955 4 24s8.955 20 20 20 20-8.955 20-20c0-1.341-.138-2.65-.389-3.917z"/>'
      '<path fill="#FF3D00" d="M6.306 14.691l6.571 4.819C14.655 15.108 18.961 12 24 12c3.059 0 5.842 1.154 7.961 3.039l5.657-5.657C34.046 6.053 29.268 4 24 4 16.318 4 9.656 8.337 6.306 14.691z"/>'
      '<path fill="#4CAF50" d="M24 44c5.166 0 9.86-1.977 13.409-5.192l-6.19-5.238A11.91 11.91 0 0 1 24 36c-5.202 0-9.619-3.317-11.283-7.946l-6.522 5.025C9.505 39.556 16.227 44 24 44z"/>'
      '<path fill="#1976D2" d="M43.611 20.083H42V20H24v8h11.303a12.04 12.04 0 0 1-4.087 5.571l.003-.002 6.19 5.238C36.971 39.205 44 34 44 24c0-1.341-.138-2.65-.389-3.917z"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) =>
      SvgPicture.string(_svg, width: 20, height: 20);
}

/// The branded launch frame for both undecided session states.
///
/// With [unreachableMessage] null it is the plain "正在恢复登录…" frame. With a
/// message it becomes the third state of decision 0064: the same brand frame
/// carrying the five-state Offline vocabulary (the `offline` icon and the
/// danger notice tone) plus a retry. It is never the credential form.
class PrivySessionRestoreScreen extends StatefulWidget {
  const PrivySessionRestoreScreen({
    super.key,
    this.unreachableMessage,
    this.onRetry,
  });

  /// Why the session could not be confirmed. Null while Privy is still
  /// answering.
  final String? unreachableMessage;

  final VoidCallback? onRetry;

  /// What the frame says about itself from the very first paint: the one
  /// status line of the launch frame (UX-001, decision 0254).
  static const String restoringTitle = '正在恢复登录状态';

  /// The same line once the wait has run long. Only the words change; the
  /// frame stays exactly where it was.
  static const String slowMessage = '网络较慢，仍在恢复登录状态…';

  /// How long the silent wait may last before the frame admits it is slow.
  /// Presentation only: it changes no session state and decides nothing.
  static const Duration slowAfter = Duration(seconds: 3);

  @override
  State<PrivySessionRestoreScreen> createState() =>
      _PrivySessionRestoreScreenState();
}

class _PrivySessionRestoreScreenState extends State<PrivySessionRestoreScreen> {
  Timer? _slowTimer;
  var _slow = false;

  @override
  void initState() {
    super.initState();
    _armSlowTimer();
  }

  @override
  void didUpdateWidget(PrivySessionRestoreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.unreachableMessage == null) !=
        (widget.unreachableMessage == null)) {
      _armSlowTimer();
    }
  }

  /// The hint belongs to the silent wait and to nothing else. Reaching the
  /// undecided state retires it, because that frame carries its own reason
  /// and its own retry.
  void _armSlowTimer() {
    _slowTimer?.cancel();
    _slowTimer = null;
    if (widget.unreachableMessage != null) {
      _slow = false;
      return;
    }
    _slowTimer = Timer(PrivySessionRestoreScreen.slowAfter, () {
      _slowTimer = null;
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _slowTimer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.unreachableMessage;
    if (message == null) {
      return LoopLaunchFrame(
        key: const ValueKey<String>('privy-restoring-screen'),
        semanticLabel: 'LOOP 正在恢复登录状态',
        status: _slow
            ? PrivySessionRestoreScreen.slowMessage
            : PrivySessionRestoreScreen.restoringTitle,
        statusKey: const ValueKey<String>('privy-restoring-title'),
      );
    }
    // The undecided state (decision 0064) on the same frame: the rail gives
    // way to the reason and the one retry. It is never the credential form.
    return LoopLaunchFrame(
      key: const ValueKey<String>('privy-restore-unavailable-screen'),
      semanticLabel: 'LOOP 暂时无法确认登录状态',
      showRail: false,
      waiting: false,
      status: '暂时无法确认登录状态',
      statusKey: const ValueKey<String>('privy-restore-unavailable-notice'),
      detail: message,
      action: LoopButton(
        key: const ValueKey<String>('privy-restore-unavailable-retry'),
        label: '重试',
        primary: true,
        onPressed: widget.onRetry,
      ),
    );
  }
}

/// The frame `/auth` draws for a session that is already signed in (S253).
///
/// It only ever stands for the frame or two before the router moves the
/// owner to the launch page, so it is that page already: the same launch
/// frame saying the same line, so the move changes nothing on screen
/// (UX-001, decision 0254).
class PrivySessionHandoverFrame extends StatelessWidget {
  const PrivySessionHandoverFrame({super.key});

  @override
  Widget build(BuildContext context) {
    // The rail is held still for these frames: the router replaces the page
    // before a sweep could be seen, and a still rail never keeps a frame
    // scheduled behind it.
    return const LoopLaunchFrame(
      key: ValueKey<String>('privy-auth-handover'),
      status: SplashScreen.preparingText,
      waiting: false,
    );
  }
}

/// The cold-start frame for a session waiting on the network (decision 0124).
///
/// Privy answered `Unauthenticated` while the device reported no transport,
/// which Privy could not have checked. The owner keeps the launch frame, is
/// told what LOOP is waiting for, and is not asked to sign in again; when the
/// radio comes back the session asks Privy once more on its own. The secondary
/// entry is for an owner who really does want the credential form.
class PrivySessionAwaitingNetworkScreen extends StatelessWidget {
  const PrivySessionAwaitingNetworkScreen({
    super.key,
    this.onUseAnotherAccount,
  });

  final VoidCallback? onUseAnotherAccount;

  static const String title = '网络不可用，正在等待连接';
  static const String message = '联网后会自动确认这台设备上的登录状态，不需要重新登录。';
  static const String anotherAccountLabel = '换个账号登录';

  @override
  Widget build(BuildContext context) {
    return LoopLaunchFrame(
      key: const ValueKey<String>('privy-awaiting-network-screen'),
      semanticLabel: 'LOOP $title',
      // Indeterminate: the frame is waiting, and a full bar would claim an
      // answer arrived.
      loaderKey: const ValueKey<String>('privy-awaiting-network-progress'),
      status: title,
      statusKey: const ValueKey<String>('privy-awaiting-network-notice'),
      detail: message,
      action: LoopButton(
        key: const ValueKey<String>('privy-awaiting-network-another-account'),
        label: anotherAccountLabel,
        onPressed: onUseAnotherAccount,
      ),
    );
  }
}

class PrivySessionSignOutScreen extends StatelessWidget {
  const PrivySessionSignOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: prefer_const_constructors
    return LoopLaunchFrame(
      key: const ValueKey<String>('privy-signing-out-screen'),
      semanticLabel: 'LOOP 正在安全退出',
      status: '正在安全退出',
    );
  }
}
