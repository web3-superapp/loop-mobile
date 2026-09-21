import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// What the last attempt means, in the owner's words.
///
/// The system's own sentence is shown as the system's, never rewritten into a
/// LOOP promise; where the platform said nothing, LOOP says only what it can
/// stand behind.
String loopAppLockAttemptText(
  LoopDeviceAuthOutcome outcome,
  String? systemMessage,
) => switch (outcome) {
  LoopDeviceAuthOutcome.succeeded => '验证通过。',
  LoopDeviceAuthOutcome.failed => '没有通过验证，可以再试一次。',
  LoopDeviceAuthOutcome.canceled => '你取消了这次验证。',
  LoopDeviceAuthOutcome.lockedOut => '系统暂时停用了验证，等一会儿再试，或改用设备密码。',
  LoopDeviceAuthOutcome.unavailable => '这台设备现在没有可用的锁屏验证。',
  LoopDeviceAuthOutcome.error =>
    systemMessage == null || systemMessage.trim().isEmpty
        ? '验证没有完成。'
        : '验证没有完成 · 系统提示：${systemMessage.trim()}',
};

/// What the device offers, said once, where the owner decides.
String loopAppLockFactorText(LoopDeviceAuthCapability capability) =>
    switch (capability.factor) {
      LoopDeviceAuthFactor.biometric => '用这台设备的生物识别解锁；识别不了时会退回设备密码',
      LoopDeviceAuthFactor.deviceCredential => '用这台设备的锁屏密码解锁',
      null => switch (capability.unavailableReason) {
        LoopDeviceAuthUnavailableReason.noCredentialSet =>
          '这台设备还没有设置锁屏密码或生物识别，先在系统设置里加上',
        LoopDeviceAuthUnavailableReason.unsupportedPlatform => '这台设备不支持锁屏验证',
        LoopDeviceAuthUnavailableReason.unknown || null => '还没有读到这台设备的锁屏能力',
      },
    };

/// Holds the curtain over LOOP while the lock is closed.
///
/// The App stays in the tree behind it: a lock is about what can be read, not
/// about throwing away where the owner was. The curtain is opaque and takes
/// every pointer, so nothing under it can be read or touched.
class LoopAppLockGate extends ConsumerStatefulWidget {
  const LoopAppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LoopAppLockGate> createState() => _LoopAppLockGateState();
}

class _LoopAppLockGateState extends ConsumerState<LoopAppLockGate> {
  /// One automatic prompt per closing. Asking again by itself would fight an
  /// owner who cancelled on purpose.
  bool _asked = false;

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(
      loopAppLockProvider.select((state) => state.locked),
    );
    if (!locked) {
      _asked = false;
      return widget.child;
    }
    if (!_asked) {
      _asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(ref.read(loopAppLockProvider.notifier).unlock());
      });
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[widget.child, const _LoopAppLockCurtain()],
    );
  }
}

class _LoopAppLockCurtain extends ConsumerWidget {
  const _LoopAppLockCurtain();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loopAppLockProvider);
    final outcome = state.lastOutcome;
    return Material(
      key: const ValueKey<String>('loop-app-lock-curtain'),
      color: LoopColors.ink,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const LoopBrandMark(
                  kind: LoopBrandMarkKind.wordmark,
                  height: 72,
                  semanticLabel: 'LOOP',
                ),
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'LOOP 已锁定',
                    key: const ValueKey<String>('loop-app-lock-title'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '这台设备的锁屏验证通过后才会显示内容。',
                  textAlign: TextAlign.center,
                  style: LoopTypography.caption(12, color: LoopColors.text3),
                ),
                if (outcome != null &&
                    outcome != LoopDeviceAuthOutcome.succeeded) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    loopAppLockAttemptText(outcome, state.systemMessage),
                    key: const ValueKey<String>('loop-app-lock-attempt'),
                    textAlign: TextAlign.center,
                    style: LoopTypography.caption(12, color: LoopColors.text2),
                  ),
                ],
                const SizedBox(height: 22),
                LoopButton(
                  key: const ValueKey<String>('loop-app-lock-unlock'),
                  label: state.busy ? '正在验证…' : '验证身份',
                  primary: true,
                  block: true,
                  onPressed: state.busy
                      ? null
                      : () => unawaited(
                          ref.read(loopAppLockProvider.notifier).unlock(),
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
