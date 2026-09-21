import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/qr/loop_qr_code.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/security/mfa/mfa_controller.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// What a failed second-factor call means, in the owner's words.
///
/// The provider's own sentence never appears here: it goes to the debug log,
/// where it can be read by somebody who can act on it. What the owner is told
/// is what LOOP actually knows.
String loopMfaFailureText(LoopMfaFailureKind kind) => switch (kind) {
  LoopMfaFailureKind.notEnabled => '登录服务尚未开启 MFA。这不是这台设备的问题，也不是你账号的问题。',
  LoopMfaFailureKind.notAuthenticated => '登录状态已经失效，重新登录后再试。',
  LoopMfaFailureKind.invalidCode => '验证码不对或者已经过期，重新输入一次。',
  LoopMfaFailureKind.rejected => '这次没有完成。',
  LoopMfaFailureKind.unavailable => '暂时联系不上登录服务。',
  LoopMfaFailureKind.unknown => '没有完成，登录服务没有说明原因。',
};

/// Opens the second-factor sheet for this account.
///
/// One sheet does both directions: an account with no method walks the
/// enrolment, an account with one is offered its removal. Both are the
/// provider's operations — this sheet starts them and reports what came back.
Future<void> showLoopMfaSheet(BuildContext context) =>
    showLoopSheet<void>(context, builder: (context) => const _LoopMfaSheet());

class _LoopMfaSheet extends ConsumerStatefulWidget {
  const _LoopMfaSheet();

  @override
  ConsumerState<_LoopMfaSheet> createState() => _LoopMfaSheetState();
}

class _LoopMfaSheetState extends ConsumerState<_LoopMfaSheet> {
  final TextEditingController _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loopMfaProvider);
    final controller = ref.read(loopMfaProvider.notifier);
    final failure = state.failure;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            state.hasTotp ? '关闭 MFA' : '开启 MFA',
            key: const ValueKey<String>('mfa-sheet-title'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            state.hasTotp
                ? '关闭后，登录服务在要求二次验证时不会再问你验证码。'
                : '用验证器 App 生成 6 位验证码。密钥由登录服务签发，LOOP 不保存它。',
            style: LoopTypography.caption(12, color: LoopColors.text3),
          ),
          if (failure != null) ...<Widget>[
            const SizedBox(height: 12),
            LoopNotice(
              key: const ValueKey<String>('mfa-sheet-failure'),
              icon: 'warn',
              tone: failure == LoopMfaFailureKind.notEnabled
                  ? LoopNoticeTone.warn
                  : LoopNoticeTone.danger,
              title: failure == LoopMfaFailureKind.notEnabled
                  ? '登录服务尚未开启 MFA'
                  : '这一步没有完成',
              body: loopMfaFailureText(failure),
            ),
          ],
          const SizedBox(height: 16),
          if (state.hasTotp)
            ..._removal(controller, state)
          else
            ..._enrolment(controller, state),
          const SizedBox(height: 10),
          LoopButton(
            key: const ValueKey<String>('mfa-sheet-close'),
            label: '关闭',
            block: true,
            onPressed: () {
              controller.cancelTotp();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _enrolment(LoopMfaController controller, LoopMfaState state) {
    final secret = state.secret;
    if (state.step == LoopMfaEnrollmentStep.starting) {
      return <Widget>[
        const LoopSkeleton(
          key: ValueKey<String>('mfa-sheet-starting'),
          type: LoopSkeletonType.list,
          rows: 2,
        ),
      ];
    }
    if (secret == null) {
      return <Widget>[
        LoopButton(
          key: const ValueKey<String>('mfa-sheet-begin'),
          label: '获取密钥',
          primary: true,
          block: true,
          onPressed: state.isBusy
              ? null
              : () => unawaited(controller.beginTotp()),
        ),
      ];
    }
    return <Widget>[
      _LoopTotpSquare(data: secret.authUrl),
      const SizedBox(height: 12),
      const LoopLabel('手动输入的密钥', tight: true),
      SelectableText(
        secret.secret,
        key: const ValueKey<String>('mfa-sheet-secret'),
        style: LoopTypography.figure(15, color: LoopColors.chalk),
      ),
      const SizedBox(height: 14),
      const LoopLabel('验证器给出的 6 位码', tight: true),
      TextField(
        key: const ValueKey<String>('mfa-sheet-code'),
        controller: _code,
        enabled: !state.isBusy,
        keyboardType: TextInputType.number,
        style: LoopTypography.figure(20, color: LoopColors.chalk),
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 14),
      LoopButton(
        key: const ValueKey<String>('mfa-sheet-submit'),
        label: state.step == LoopMfaEnrollmentStep.submitting
            ? '正在验证…'
            : '验证并开启',
        primary: true,
        block: true,
        onPressed: _code.text.length == 6 && !state.isBusy
            ? () => unawaited(controller.submitTotp(_code.text))
            : null,
      ),
    ];
  }

  List<Widget> _removal(LoopMfaController controller, LoopMfaState state) {
    return <Widget>[
      LoopButton(
        key: const ValueKey<String>('mfa-sheet-remove'),
        label: state.removing ? '正在关闭…' : '关闭 MFA',
        block: true,
        onPressed: state.isBusy
            ? null
            : () => unawaited(controller.removeTotp()),
      ),
    ];
  }
}

/// The `otpauth://` square an authenticator app scans.
///
/// A payload the encoder cannot carry prints nothing rather than a broken
/// square: the key beneath it is the way in either way.
class _LoopTotpSquare extends StatelessWidget {
  const _LoopTotpSquare({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final code = LoopQrCode.encode(data);
    if (code == null) return const SizedBox.shrink();
    return Center(
      child: Container(
        key: const ValueKey<String>('mfa-sheet-qr'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: LoopColors.chalk,
          borderRadius: BorderRadius.circular(LoopRadius.innerValue),
        ),
        child: SizedBox(
          width: 180,
          height: 180,
          child: CustomPaint(painter: _LoopTotpSquarePainter(code: code)),
        ),
      ),
    );
  }
}

class _LoopTotpSquarePainter extends CustomPainter {
  const _LoopTotpSquarePainter({required this.code});

  final LoopQrCode code;

  @override
  void paint(Canvas canvas, Size size) {
    final module = size.width / code.size;
    final paint = Paint()..color = LoopColors.ink;
    for (var y = 0; y < code.size; y++) {
      for (var x = 0; x < code.size; x++) {
        if (!code.isDark(x, y)) continue;
        canvas.drawRect(
          Rect.fromLTWH(x * module, y * module, module, module),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LoopTotpSquarePainter oldDelegate) =>
      oldDelegate.code != code;
}
