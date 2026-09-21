import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/security/mfa/mfa_controller.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';
import 'package:loop_mobile/features/security/mfa/mfa_sheet.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// Binds or unbinds a passkey as a way back into this account.
///
/// This is the recovery side of a passkey, not the second-factor side: what
/// it changes is whether the owner can sign in with the device's own
/// biometrics after losing the email. The second factor is switched
/// separately, in the MFA sheet, because they are different promises.
///
/// Nothing on this sheet is performed by LOOP. The platform creates the
/// credential, the provider stores it, and every line here is read back from
/// what the provider answered.
Future<void> showLoopPasskeySheet(BuildContext context) => showLoopSheet<void>(
  context,
  builder: (context) => const _LoopPasskeySheet(),
);

class _LoopPasskeySheet extends ConsumerStatefulWidget {
  const _LoopPasskeySheet();

  @override
  ConsumerState<_LoopPasskeySheet> createState() => _LoopPasskeySheetState();
}

class _LoopPasskeySheetState extends ConsumerState<_LoopPasskeySheet> {
  /// The credential the owner asked to remove, held until they confirm it.
  ///
  /// An unbind is a way back in being taken away, so it is never one tap:
  /// the row names the credential, the confirmation names the consequence,
  /// and the device is asked before the provider is.
  String? _confirming;

  @override
  void initState() {
    super.initState();
    // The sheet may be the first thing to ask. A page that opened it has
    // already started a read; this one is single-flight and joins it.
    Future<void>.microtask(() => ref.read(loopMfaProvider.notifier).load());
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
            'Passkey',
            key: const ValueKey<String>('passkey-sheet-title'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Passkey 由这台设备的系统保管，登录服务只记下它的公钥。换手机后，用同一个系统账号同步过去的 Passkey 就能再次进入。',
            style: LoopTypography.caption(12, color: LoopColors.text3),
          ),
          if (failure != null) ...<Widget>[
            const SizedBox(height: 12),
            LoopNotice(
              key: const ValueKey<String>('passkey-sheet-failure'),
              icon: 'warn',
              tone:
                  failure == LoopMfaFailureKind.passkeyDomainUnconfigured ||
                      failure == LoopMfaFailureKind.cancelled
                  ? LoopNoticeTone.warn
                  : LoopNoticeTone.danger,
              title: switch (failure) {
                LoopMfaFailureKind.passkeyDomainUnconfigured => 'Passkey 还开不了',
                LoopMfaFailureKind.cancelled => '这次没有完成',
                _ => '这一步没有完成',
              },
              body: loopMfaFailureText(failure),
            ),
          ],
          const SizedBox(height: 16),
          ..._body(controller, state),
          const SizedBox(height: 10),
          LoopButton(
            key: const ValueKey<String>('passkey-sheet-close'),
            label: '关闭',
            block: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  List<Widget> _body(LoopMfaController controller, LoopMfaState state) {
    if (!state.canUsePasskey) {
      return <Widget>[
        LoopNotice(
          key: const ValueKey<String>('passkey-sheet-unavailable'),
          icon: 'info',
          title: 'Passkey 还开不了',
          body: loopMfaFailureText(
            LoopMfaFailureKind.passkeyDomainUnconfigured,
          ),
        ),
      ];
    }
    if (state.phase == LoopMfaPhase.reading) {
      return <Widget>[
        const LoopSkeleton(
          key: ValueKey<String>('passkey-sheet-loading'),
          type: LoopSkeletonType.list,
          rows: 2,
        ),
      ];
    }
    // "We could not ask" is not "you have none". A page that has not heard
    // from the provider offers no binding and says why.
    if (state.phase != LoopMfaPhase.known) {
      return <Widget>[
        LoopNotice(
          key: const ValueKey<String>('passkey-sheet-unknown'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          title: '还没有读到登录服务的回答',
          body: failureOrDefault(state.failure),
        ),
      ];
    }
    final confirming = _confirming;
    return <Widget>[
      if (state.passkeys.isEmpty)
        const LoopEmpty(
          key: ValueKey<String>('passkey-sheet-empty'),
          message: '这个账号还没有 Passkey',
          reason: '绑定后，这台设备的面容或指纹就是一条独立的回来路。',
        )
      else ...<Widget>[
        const LoopLabel('已绑定', tight: true),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            for (final (index, passkey) in state.passkeys.indexed)
              LoopRecordRow(
                key: ValueKey<String>('passkey-${passkey.credentialId}'),
                title: passkey.label ?? '这个账号的 Passkey',
                subtitle: passkey.enrolledInMfa ? '也用作二次验证' : '用于登录与恢复',
                trailing: '已设置',
                position: state.passkeys.length == 1
                    ? LoopRowPosition.single
                    : index == 0
                    ? LoopRowPosition.first
                    : index == state.passkeys.length - 1
                    ? LoopRowPosition.last
                    : LoopRowPosition.middle,
                onTap: state.isBusy
                    ? null
                    : () => setState(
                        () => _confirming = confirming == passkey.credentialId
                            ? null
                            : passkey.credentialId,
                      ),
                semanticLabel: '${passkey.label ?? 'Passkey'}，已设置，点按后可以解绑',
              ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      if (confirming != null) ...<Widget>[
        const LoopNotice(
          key: ValueKey<String>('passkey-sheet-confirm'),
          icon: 'warn',
          tone: LoopNoticeTone.danger,
          title: '解绑后这条路就没有了',
          body: '解绑前设备会先验证一次身份。系统里的那份 Passkey 由系统管理，LOOP 删不掉它，只是登录服务不再认它。',
        ),
        const SizedBox(height: 10),
        LoopButton(
          key: const ValueKey<String>('passkey-sheet-unlink'),
          label: state.passkeyWorking ? '正在解绑…' : '确认解绑',
          block: true,
          onPressed: state.isBusy
              ? null
              : () => unawaited(
                  controller.unlinkPasskey(confirming).then((removed) {
                    if (removed && mounted) setState(() => _confirming = null);
                  }),
                ),
        ),
        const SizedBox(height: 10),
      ],
      LoopButton(
        key: const ValueKey<String>('passkey-sheet-link'),
        label: state.passkeyWorking && confirming == null
            ? '正在等待系统验证…'
            : state.passkeys.isEmpty
            ? '绑定 Passkey'
            : '再绑定一个 Passkey',
        primary: state.passkeys.isEmpty,
        block: true,
        onPressed: state.isBusy
            ? null
            : () => unawaited(controller.linkPasskey()),
      ),
    ];
  }

  /// What to print when a read failed but the failure has no words yet.
  static String failureOrDefault(LoopMfaFailureKind? kind) =>
      kind == null ? '这次运行还没有得到登录服务的回答。' : loopMfaFailureText(kind);
}
