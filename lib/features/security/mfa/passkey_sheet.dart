import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/security/mfa/mfa_controller.dart';
import 'package:loop_mobile/features/security/mfa/mfa_models.dart';
import 'package:loop_mobile/features/security/mfa/mfa_sheet.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
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
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        0,
        LoopSpacing.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Passkey',
            key: const ValueKey<String>('passkey-sheet-title'),
            style: LoopType.heading,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.securityMfa_passkeySheetBuild,
            style: LoopType.bodySm,
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
                LoopMfaFailureKind.passkeyDomainUnconfigured =>
                  context.l10n.securityMfa_sheetMfaSheetPasskeyUnavailableTitle,
                LoopMfaFailureKind.cancelled =>
                  context.l10n.securityMfa_passkeySheetCancelled,
                _ => context.l10n.securityMfa_sheetMfaSheetFailureTitle2,
              },
              body: loopMfaFailureText(failure),
            ),
          ],
          const SizedBox(height: 16),
          ..._body(controller, state),
          const SizedBox(height: 10),
          LoopButton(
            key: const ValueKey<String>('passkey-sheet-close'),
            label: context.l10n.common_close,
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
          title:
              LoopL10n.current.securityMfa_sheetMfaSheetPasskeyUnavailableTitle,
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
          title:
              LoopL10n.current.securityMfa_passkeySheetPasskeySheetUnknownTitle,
          body: failureOrDefault(state.failure),
        ),
      ];
    }
    final confirming = _confirming;
    return <Widget>[
      if (state.passkeys.isEmpty)
        LoopEmptyState(
          key: ValueKey<String>('passkey-sheet-empty'),
          illustration: LoopIllustration.profile,
          title:
              LoopL10n.current.securityMfa_passkeySheetPasskeySheetEmptyTitle,
          message:
              LoopL10n.current.securityMfa_passkeySheetPasskeySheetEmptyMessage,
          compact: true,
        )
      else ...<Widget>[
        LoopLabel(
          LoopL10n.current.securityMfa_passkeySheetLoopLabel,
          tight: true,
        ),
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            for (final (index, passkey) in state.passkeys.indexed)
              LoopRecordRow(
                key: ValueKey<String>('passkey-${passkey.credentialId}'),
                title:
                    passkey.label ??
                    LoopL10n.current.securityMfa_passkeySheetTitle,
                subtitle: passkey.enrolledInMfa
                    ? LoopL10n.current.securityMfa_passkeySheetSubtitle
                    : LoopL10n.current.securityMfa_passkeySheetSubtitle2,
                trailing: LoopL10n.current.securityMfa_passkeySheetTrailing,
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
                semanticLabel: LoopL10n.current
                    .securityMfa_passkeySheetSemanticLabel(
                      passkey.label ?? 'Passkey',
                    ),
              ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      if (confirming != null) ...<Widget>[
        LoopNotice(
          key: ValueKey<String>('passkey-sheet-confirm'),
          icon: 'warn',
          tone: LoopNoticeTone.danger,
          title:
              LoopL10n.current.securityMfa_passkeySheetPasskeySheetConfirmTitle,
          body:
              LoopL10n.current.securityMfa_passkeySheetPasskeySheetConfirmBody,
        ),
        const SizedBox(height: 10),
        LoopButton(
          key: const ValueKey<String>('passkey-sheet-unlink'),
          label: state.passkeyWorking
              ? LoopL10n.current.securityMfa_passkeySheetPasskeySheetUnlinkLabel
              : LoopL10n
                    .current
                    .securityMfa_passkeySheetPasskeySheetUnlinkLabel2,
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
            ? LoopL10n.current.securityMfa_sheetMfaSheetPasskeyLabel
            : state.passkeys.isEmpty
            ? LoopL10n.current.securityMfa_passkeySheetPasskeySheetLinkLabel
            : LoopL10n.current.securityMfa_passkeySheetPasskeySheetLinkLabel2,
        primary: state.passkeys.isEmpty,
        block: true,
        onPressed: state.isBusy
            ? null
            : () => unawaited(controller.linkPasskey()),
      ),
    ];
  }

  /// What to print when a read failed but the failure has no words yet.
  static String failureOrDefault(LoopMfaFailureKind? kind) => kind == null
      ? LoopL10n.current.securityMfa_passkeySheetText
      : loopMfaFailureText(kind);
}
