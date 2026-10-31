import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/email_auth_controller.dart';
import 'package:loop_mobile/features/account/identity_step_scaffold.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inputs.dart';

/// `auth-otp`: the second Privy email step on its own manifest route.
///
/// The controller owns every fact shown here — the destination address, the
/// resend cooldown and the remaining attempts are real local state, never a
/// simulated provider quota.
///
/// UX-002 (decision 0254): the step bar at the very top, 验证邮箱, the
/// address with 更换邮箱 beside it, six cells, the countdown that turns into
/// 重新发送 in the same place, and 继续 — closed until all six digits are in.
class PrivyOtpScreen extends ConsumerStatefulWidget {
  const PrivyOtpScreen({super.key, this.onBack, this.onChangeEmail});

  final VoidCallback? onBack;

  /// 更换邮箱: back to the e-mail step, after the pending code is dropped.
  final VoidCallback? onChangeEmail;

  @override
  ConsumerState<PrivyOtpScreen> createState() => _PrivyOtpScreenState();
}

class _PrivyOtpScreenState extends ConsumerState<PrivyOtpScreen> {
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();
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
    _codeFocusNode.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeFocusNode
      ..removeListener(_onFocus)
      ..dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(emailAuthProvider);
    final controller = ref.read(emailAuthProvider.notifier);
    final destination = authState.submittedEmail;
    final now = ref.watch(loopDeviceClockProvider)();
    final cooldown = authState.resendCooldownSeconds(now);
    final canResend = authState.canResend(now);
    final verifying =
        authState.activeOperation == IdentityAuthOperation.verifyEmailCode;
    final resending =
        authState.activeOperation == IdentityAuthOperation.resendEmailCode;
    final complete = _codeController.text.length == _OtpGrid.length;
    final back = widget.onBack ?? controller.changeEmail;
    // 更换邮箱 always drops the pending code; where the page is told how to
    // leave, it also goes back to the e-mail step.
    void changeEmail() {
      controller.changeEmail();
      widget.onChangeEmail?.call();
    }

    return IdentityStepScaffold(
      title: '验证邮箱',
      step: 1,
      total: 5,
      progressLabel: '验证邮箱',
      onBack: back,
      subtitle: destination == null
          ? Text(
              '尚未发送验证码',
              key: const ValueKey<String>('identity-step-copy'),
              style: LoopType.body.copyWith(color: LoopColors.text2),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: Text(
                    '验证码已发送至 ${maskEmailForDisplay(destination)}',
                    key: const ValueKey<String>('identity-step-copy'),
                    style: LoopType.body.copyWith(color: LoopColors.text2),
                  ),
                ),
                const SizedBox(width: 8),
                _TextLink(
                  key: const ValueKey<String>('privy-otp-change-email'),
                  label: '更换邮箱',
                  onPressed: authState.isBusy ? null : changeEmail,
                ),
              ],
            ),
      primaryAction: destination == null
          ? null
          : LoopButton(
              key: const ValueKey<String>('privy-auth-primary-button'),
              label: verifying ? '验证中…' : '继续',
              primary: true,
              block: true,
              onPressed:
                  authState.isBusy || authState.attemptsExhausted || !complete
                  ? null
                  : () =>
                        unawaited(controller.verifyCode(_codeController.text)),
            ),
      body: <Widget>[
        if (destination == null)
          const LoopEmptyState(
            key: ValueKey<String>('privy-otp-no-destination'),
            illustration: LoopIllustration.profile,
            title: '没有待验证的邮箱',
            message: '返回上一步输入邮箱。',
            compact: true,
          )
        else ...<Widget>[
          _OtpGrid(
            controller: _codeController,
            focusNode: _codeFocusNode,
            enabled: !authState.isBusy && !authState.attemptsExhausted,
            onChanged: (_) => setState(() {}),
            onSubmitted:
                authState.isBusy || authState.attemptsExhausted || !complete
                ? null
                : controller.verifyCode,
          ),
          const SizedBox(height: 18),
          // The countdown and the resend share one place: the line counts
          // down, then the same line is the action.
          Center(
            child: cooldown > 0
                ? Semantics(
                    liveRegion: true,
                    child: Text(
                      key: const ValueKey<String>('privy-otp-resend-hint'),
                      '$cooldown 秒后可重新发送',
                      textAlign: TextAlign.center,
                      style: LoopType.caption,
                    ),
                  )
                : _TextLink(
                    key: const ValueKey<String>('privy-otp-resend'),
                    label: resending ? '发送中…' : '重新发送',
                    onPressed: canResend
                        ? () => unawaited(controller.resendCode())
                        : null,
                  ),
          ),
          if (authState.attemptsExhausted)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                6,
                LoopSpacing.page,
                0,
              ),
              child: Text(
                key: const ValueKey<String>('privy-otp-attempts'),
                '尝试次数已用完，请重新发送验证码。',
                textAlign: TextAlign.center,
                style: LoopType.caption.copyWith(color: LoopColors.chalk),
              ),
            ),
          if (authState.deliveryUnconfirmed)
            LoopOfflineState(
              key: const ValueKey<String>('privy-otp-offline'),
              pausedActions: const <String>['重新发送验证码'],
              onRetry: canResend
                  ? () => unawaited(controller.resendCode())
                  : null,
              margin: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                14,
                LoopSpacing.page,
                0,
              ),
            ),
          if (authState.errorMessage != null)
            LoopNotice(
              key: const ValueKey<String>('privy-otp-error'),
              icon: 'close',
              tone: LoopNoticeTone.danger,
              title: '验证未通过',
              body: authState.errorMessage!,
              margin: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                14,
                LoopSpacing.page,
                0,
              ),
            ),
        ],
      ],
    );
  }
}

/// `1026276885@qq.com` → `1026••••85@qq.com`: the address the code went to,
/// recognisable to its owner and not readable over a shoulder.
String maskEmailForDisplay(String email) {
  final at = email.lastIndexOf('@');
  if (at <= 0) return email;
  final local = email.substring(0, at);
  final domain = email.substring(at);
  if (local.length <= 2) return '${local[0]}••••$domain';
  if (local.length <= 6) {
    return '${local.substring(0, 1)}••••${local.substring(local.length - 1)}'
        '$domain';
  }
  return '${local.substring(0, 4)}••••${local.substring(local.length - 2)}'
      '$domain';
}

/// A Yellow text action: 更换邮箱, 重新发送. A full touch target, no fill.
class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: LoopRadius.control,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: LoopTouch.minimum,
            minHeight: LoopTouch.minimum,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: LoopTypography.withWeight(LoopType.body, FontWeight.w700)
                    .copyWith(
                      color: enabled ? LoopColors.yellow : LoopColors.text3,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.otp-grid`: six visible cells over one real field.
///
/// The cells are presentation only. A single hidden [TextField] keeps the
/// exact controller contract, the one-time-code autofill hint and the digit
/// formatters, so nothing here can accept a value the controller would not.
class _OtpGrid extends StatelessWidget {
  const _OtpGrid({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  static const length = 6;

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  /// `.otp-cell{height:56px}`, with room for a larger text scale.
  static const double cellHeight = 56;

  @override
  Widget build(BuildContext context) {
    final digits = controller.text;
    final focused = enabled && focusNode.hasFocus;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
      child: Stack(
        children: <Widget>[
          Row(
            children: <Widget>[
              for (var index = 0; index < length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label: '验证码第 ${index + 1} 位',
                    value: index < digits.length ? digits[index] : '未填写',
                    readOnly: true,
                    child: Container(
                      key: ValueKey<String>('privy-otp-cell-${index + 1}'),
                      height: cellHeight,
                      alignment: Alignment.center,
                      // UX-008 (decision 0254): the cell is a field like any
                      // other — the 12 corner, and the Purple edge on the cell
                      // that takes the next digit while the field has focus.
                      decoration: loopCodeCellDecoration(
                        focused:
                            focused &&
                            (index == digits.length ||
                                (digits.length == length &&
                                    index == length - 1)),
                        filled: index < digits.length,
                      ),
                      child: ExcludeSemantics(
                        child: index < digits.length
                            ? Text(digits[index], style: LoopType.figureLg)
                            : focused && index == digits.length
                            ? Container(
                                key: const ValueKey<String>('privy-otp-caret'),
                                width: 2,
                                height: 22,
                                color: LoopColors.chalk,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          // The one real field: transparent, full-bleed, and the only place
          // that owns the value.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: const ValueKey<String>('privy-otp-field'),
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                autofocus: true,
                showCursor: false,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(length),
                ],
                decoration: const InputDecoration(border: InputBorder.none),
                onChanged: onChanged,
                onSubmitted: onSubmitted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
