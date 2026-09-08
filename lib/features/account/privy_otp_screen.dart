import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

/// `auth-otp`: the second Privy email step on its own manifest route.
///
/// The controller owns every fact shown here — the destination address, the
/// resend cooldown and the remaining attempts are real local state, never a
/// simulated provider quota.
class PrivyOtpScreen extends ConsumerStatefulWidget {
  const PrivyOtpScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<PrivyOtpScreen> createState() => _PrivyOtpScreenState();
}

class _PrivyOtpScreenState extends ConsumerState<PrivyOtpScreen> {
  final _codeController = TextEditingController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // One repaint per second. The instant itself always comes from the
    // controller's own clock, so the countdown and the controller's cooldown
    // gate can never disagree.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(emailAuthProvider);
    final controller = ref.read(emailAuthProvider.notifier);
    final destination = authState.submittedEmail;
    final now = controller.clock();
    final cooldown = authState.resendCooldownSeconds(now);
    final canResend = authState.canResend(now);

    return LoopFocusPage(
      archetype: LoopPageArchetype.intro,
      title: '验证邮箱',
      onBack: widget.onBack ?? () => controller.changeEmail(),
      primaryAction: LoopButton(
        key: const ValueKey<String>('privy-auth-primary-button'),
        label: authState.isBusy ? '验证中…' : '验证',
        primary: true,
        block: true,
        onPressed:
            authState.isBusy ||
                destination == null ||
                authState.attemptsExhausted
            ? null
            : () => unawaited(controller.verifyCode(_codeController.text)),
      ),
      disclosure: const LoopDisclosure(
        summary: '验证失败时会看到什么',
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              LoopNotice(
                icon: 'close',
                tone: LoopNoticeTone.danger,
                title: '验证码错误',
                body: '每次失败都会扣掉一次尝试机会；用完后需要重新发送验证码。',
                margin: EdgeInsets.only(bottom: 10),
              ),
              LoopNotice(
                icon: 'clock',
                tone: LoopNoticeTone.warn,
                title: '验证码已过期',
                body: '倒计时结束后可以重新发送；旧验证码会立即失效。',
                margin: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      body: <Widget>[
        const IdentityProgress(step: 1, total: 5, label: '验证邮箱'),
        IdentityStepCopy(
          destination == null ? '尚未发送验证码，请先回到上一步输入邮箱。' : '已发送至 $destination',
        ),
        if (destination == null)
          const LoopEmpty(
            key: ValueKey<String>('privy-otp-no-destination'),
            message: '没有待验证的邮箱',
            reason: '返回登录页重新输入邮箱后再来这一步。',
          )
        else ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
            child: LoopSurfaceCard(
              child: TextField(
                key: const ValueKey<String>('privy-otp-field'),
                controller: _codeController,
                enabled: !authState.isBusy && !authState.attemptsExhausted,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: LoopTypography.mono(
                  size: 22,
                  weight: FontWeight.w600,
                  letterSpacing: 8,
                  color: LoopColors.chalk,
                ),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: '000000',
                ),
                onSubmitted: authState.isBusy || authState.attemptsExhausted
                    ? null
                    : controller.verifyCode,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                key: const ValueKey<String>('privy-otp-resend-hint'),
                cooldown > 0 ? '$cooldown 秒后可重新发送' : '现在可以重新发送验证码',
                textAlign: TextAlign.center,
                style: LoopTypography.sora(
                  size: 12,
                  weight: FontWeight.w400,
                  color: LoopColors.text3,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              6,
              LoopSpacing.page,
              0,
            ),
            child: Text(
              key: const ValueKey<String>('privy-otp-attempts'),
              authState.attemptsExhausted
                  ? '尝试次数已用完，请重新发送验证码。'
                  : '还可尝试 ${authState.remainingAttempts} 次',
              textAlign: TextAlign.center,
              style: LoopTypography.sora(
                size: 12,
                weight: FontWeight.w400,
                color: authState.attemptsExhausted
                    ? LoopColors.chalk
                    : LoopColors.text3,
              ),
            ),
          ),
          if (authState.errorMessage != null)
            LoopNotice(
              key: const ValueKey<String>('privy-otp-error'),
              icon: 'close',
              tone: LoopNoticeTone.danger,
              title: '验证未通过',
              body: authState.errorMessage!,
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              14,
              LoopSpacing.page,
              0,
            ),
            child: LoopButtonPair(
              padded: false,
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('privy-otp-change-email'),
                  label: '换个邮箱',
                  onPressed: authState.isBusy ? null : controller.changeEmail,
                ),
                LoopButton(
                  key: const ValueKey<String>('privy-otp-resend'),
                  label: '重新发送',
                  onPressed: canResend
                      ? () => unawaited(controller.resendCode())
                      : null,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
