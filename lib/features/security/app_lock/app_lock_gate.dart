import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/account/account_screens.dart'
    show LoopLaunchFrame;
import 'package:loop_mobile/features/security/app_lock/app_lock_controller.dart';
import 'package:loop_mobile/features/security/app_lock/app_lock_models.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
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
  LoopDeviceAuthOutcome.succeeded =>
    LoopL10n.current.securityAppLock_gateSucceeded,
  LoopDeviceAuthOutcome.failed => LoopL10n.current.securityAppLock_gateFailed,
  LoopDeviceAuthOutcome.canceled =>
    LoopL10n.current.securityAppLock_gateCanceled,
  LoopDeviceAuthOutcome.lockedOut =>
    LoopL10n.current.securityAppLock_gateLockedOut,
  LoopDeviceAuthOutcome.unavailable =>
    LoopL10n.current.securityAppLock_gateUnavailable,
  LoopDeviceAuthOutcome.error =>
    systemMessage == null || systemMessage.trim().isEmpty
        ? LoopL10n.current.securityAppLock_gateSwitch
        : LoopL10n.current.securityAppLock_gateS(systemMessage.trim()),
};

/// What the device offers, said once, where the owner decides.
String loopAppLockFactorText(LoopDeviceAuthCapability capability) =>
    switch (capability.factor) {
      LoopDeviceAuthFactor.biometric =>
        LoopL10n.current.securityAppLock_gateBiometric,
      LoopDeviceAuthFactor.deviceCredential =>
        LoopL10n.current.securityAppLock_gateDeviceCredential,
      null => switch (capability.unavailableReason) {
        LoopDeviceAuthUnavailableReason.noCredentialSet =>
          LoopL10n.current.securityAppLock_gateNoCredentialSet,
        LoopDeviceAuthUnavailableReason.unsupportedPlatform =>
          LoopL10n.current.securityAppLock_gateUnsupportedPlatform,
        LoopDeviceAuthUnavailableReason.unknown ||
        null => LoopL10n.current.securityAppLock_gateSwitch2,
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
    // UX-001 (decision 0254): the curtain is the launch frame — the mark
    // where the native launch screen and every wait put it — so a locked
    // start does not jump from one mark to another.
    return Material(
      key: const ValueKey<String>('loop-app-lock-curtain'),
      color: LoopColors.ink,
      child: LoopLaunchFrame(
        semanticLabel:
            context.l10n.securityAppLock_gateLoopAppLockUnlockSemanticLabel,
        showRail: false,
        waiting: false,
        status: context.l10n.securityAppLock_gateLoopAppLockUnlockSemanticLabel,
        statusKey: const ValueKey<String>('loop-app-lock-title'),
        statusStyle: LoopType.titleLg,
        detail: outcome != null && outcome != LoopDeviceAuthOutcome.succeeded
            ? loopAppLockAttemptText(outcome, state.systemMessage)
            : null,
        detailKey: const ValueKey<String>('loop-app-lock-attempt'),
        action: LoopButton(
          key: const ValueKey<String>('loop-app-lock-unlock'),
          label: state.busy
              ? context.l10n.securityAppLock_gateLoopAppLockUnlockLabel
              : context.l10n.securityAppLock_gateLoopAppLockUnlockLabel2,
          primary: true,
          block: true,
          onPressed: state.busy
              ? null
              : () =>
                    unawaited(ref.read(loopAppLockProvider.notifier).unlock()),
        ),
      ),
    );
  }
}
