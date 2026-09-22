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
import 'package:loop_mobile/widgets/loop_toast.dart';

/// What a failed second-factor call means, in the owner's words.
///
/// The provider's own sentence never appears here: it goes to the debug log,
/// where it can be read by somebody who can act on it. What the owner is told
/// is what LOOP actually knows.
String loopMfaFailureText(LoopMfaFailureKind kind) => switch (kind) {
  // Not a fault of the owner's, of their device, or of the login service:
  // a passkey belongs to a domain, and LOOP has not finished giving this
  // build one. It says what is missing rather than what failed.
  LoopMfaFailureKind.passkeyDomainUnconfigured => '$loopPasskeyDomainPending。',
  LoopMfaFailureKind.cancelled => '系统的验证没有完成，这次什么都没有改变。',
  LoopMfaFailureKind.deviceUnsupported => '这台设备没有可用的 Passkey，系统没有提供可以创建的地方。',
  LoopMfaFailureKind.notEnabled => '登录服务尚未开启 MFA。这不是这台设备的问题，也不是你账号的问题。',
  LoopMfaFailureKind.notAuthenticated => '登录状态已经失效，重新登录后再试。',
  LoopMfaFailureKind.invalidCode => '验证码不对或者已经过期，重新输入一次。',
  LoopMfaFailureKind.rejected => '这次没有完成。',
  LoopMfaFailureKind.unavailable => '暂时联系不上登录服务。',
  LoopMfaFailureKind.unknown => '没有完成，登录服务没有说明原因。',
};

/// Why a passkey is not offered, said once and read everywhere.
///
/// The login service does support passkeys. What is missing is on LOOP's
/// side: a passkey belongs to a domain, and this build was given no domain
/// credential — no Associated Domains entitlement, no `assetlinks.json`, no
/// relying party at the provider. Calling the platform without one fails on
/// the device every time, so the product says what is actually missing
/// instead of offering a button that cannot work.
const loopPasskeyDomainPending = '还要先给 LOOP 配好 Passkey 用的域名凭据，当前版本还没有';

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
            '二次验证',
            key: const ValueKey<String>('mfa-sheet-title'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '两种方式都由登录服务保管，LOOP 不保存密钥，也不保存 Passkey。',
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
          const LoopLabel('验证器 App', tight: true),
          Text(
            state.hasTotp
                ? '关闭后，登录服务在要求二次验证时不会再问你验证码。'
                : '验证器 App 是手机上生成 6 位验证码的应用，例如 Google Authenticator、'
                      'Microsoft Authenticator、1Password。用它扫码或输入密钥即可。'
                      '密钥由登录服务签发，LOOP 不保存它。',
            style: LoopTypography.caption(12, color: LoopColors.text3),
          ),
          const SizedBox(height: 12),
          if (state.hasTotp)
            ..._removal(controller, state)
          else
            ..._enrolment(controller, state),
          const SizedBox(height: 18),
          const LoopLabel('Passkey', tight: true),
          ..._passkey(controller, state),
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

  /// The secret goes to the clipboard as typed, for the authenticator that
  /// cannot scan; nothing else about it is kept or logged.
  Future<void> _copySecret(String secret) async {
    await Clipboard.setData(ClipboardData(text: secret));
    if (!mounted) return;
    LoopToast.show(context, message: '已复制密钥', kind: LoopToastKind.ok);
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
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: SelectableText(
              secret.secret,
              key: const ValueKey<String>('mfa-sheet-secret'),
              style: LoopTypography.figure(15, color: LoopColors.chalk),
            ),
          ),
          const SizedBox(width: 12),
          LoopButton(
            key: const ValueKey<String>('mfa-sheet-secret-copy'),
            label: '复制',
            onPressed: () => unawaited(_copySecret(secret.secret)),
          ),
        ],
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

  /// The account's passkey, as a second factor.
  ///
  /// A passkey is two things at Privy and they are kept apart here: a way
  /// back into the account, and a method the provider will accept as a
  /// second factor. This block only switches the second one. Turning it off
  /// leaves the passkey as a way in, because taking that away is a different
  /// decision and is made on the recovery page.
  List<Widget> _passkey(LoopMfaController controller, LoopMfaState state) {
    if (!state.canUsePasskey) {
      return <Widget>[
        LoopNotice(
          key: const ValueKey<String>('mfa-sheet-passkey-unavailable'),
          icon: 'info',
          title: 'Passkey 还开不了',
          body: loopMfaFailureText(
            LoopMfaFailureKind.passkeyDomainUnconfigured,
          ),
        ),
      ];
    }
    final enrolled = state.hasPasskeyMfa;
    return <Widget>[
      Text(
        enrolled
            ? '已开启 · Passkey。登录服务要求二次验证时，会让系统弹出 Passkey 验证。'
            : state.hasPasskey
            ? '这个账号已经有 Passkey，可以直接把它也用作二次验证。'
            : '用这台设备创建一个 Passkey，并把它作为二次验证方式。',
        key: const ValueKey<String>('mfa-sheet-passkey-status'),
        style: LoopTypography.caption(12, color: LoopColors.text3),
      ),
      const SizedBox(height: 12),
      LoopButton(
        key: const ValueKey<String>('mfa-sheet-passkey'),
        label: state.passkeyWorking
            ? '正在等待系统验证…'
            : enrolled
            ? '关闭 Passkey 验证'
            : 'Passkey 开启二次验证',
        primary: !enrolled,
        block: true,
        onPressed: state.isBusy
            ? null
            : () => unawaited(
                enrolled
                    ? controller.disablePasskeyMfa()
                    : controller.enablePasskeyMfa(),
              ),
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
