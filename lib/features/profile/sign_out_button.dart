import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// What the confirmation says before this device leaves the account.
///
/// It names only what sign-out actually does (`_signOut` in `app.dart`): the
/// device stops being addressed for this account's notifications and the
/// first-screen answers stored for it are cleared. Nothing on the server is
/// deleted, so signing in again brings everything back.
String get loopSignOutConfirmTitle =>
    LoopL10n.current.profile_signOutButtonLoopSignOutConfirmTitle;
String get loopSignOutConfirmBody =>
    LoopL10n.current.profile_signOutButtonLoopSignOutConfirmBody;

/// Asks before signing out (audit 2026-10-09 M14).
///
/// The same bottom sheet every other leave-or-lose decision uses
/// ([confirmCommunityAction]); never a centred dialog.
Future<bool> confirmLoopSignOut(BuildContext context) => confirmCommunityAction(
  context,
  title: loopSignOutConfirmTitle,
  body: loopSignOutConfirmBody,
  confirmLabel: context.l10n.profile_signOutButtonConfirmLabel,
  sheetKey: 'sign-out-confirm-sheet',
);

/// The one 「退出登录」 control, on 我 and on 设置 alike (audit m15).
///
/// A full-width secondary button at the foot of the page. The tap opens the
/// confirmation; only an explicit 「退出登录」 there runs [onSignOut], and the
/// button stays disabled while it runs so a second tap cannot start a second
/// sign-out.
class LoopSignOutButton extends StatefulWidget {
  const LoopSignOutButton({
    required this.onSignOut,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 0),
  });

  final Future<void> Function() onSignOut;
  final EdgeInsets padding;

  @override
  State<LoopSignOutButton> createState() => _LoopSignOutButtonState();
}

class _LoopSignOutButtonState extends State<LoopSignOutButton> {
  bool _running = false;

  Future<void> _press() async {
    if (_running) return;
    final confirmed = await confirmLoopSignOut(context);
    if (!confirmed || !mounted) return;
    setState(() => _running = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: widget.padding,
    child: LoopButton(
      label: _running
          ? context.l10n.profile_signOutButtonLabel
          : context.l10n.profile_signOutButtonConfirmLabel,
      block: true,
      onPressed: _running ? null : () => unawaited(_press()),
    ),
  );
}
