import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/notifications/notification_inbox.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_unread_badge.dart';

/// The bell at the head of 聊天 that opens the notification centre
/// (decision 0241), with the unread total on its corner.
///
/// The total is read when the bell first appears and again when the App comes
/// back to the foreground (at most once a minute); a notification arriving
/// and a read in the centre force a read of their own. Nothing polls. With no
/// answer — no adapter, Preview, a server without the endpoint — the bell is
/// drawn bare.
class NotificationBellButton extends ConsumerStatefulWidget {
  const NotificationBellButton({required this.onPressed, super.key});

  final VoidCallback? onPressed;

  @override
  ConsumerState<NotificationBellButton> createState() =>
      _NotificationBellButtonState();
}

class _NotificationBellButtonState
    extends ConsumerState<NotificationBellButton> {
  late final AppLifecycleListener _lifecycle;

  void _refresh() {
    if (!mounted) return;
    unawaited(ref.read(notificationUnreadCountProvider.notifier).refresh());
  }

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    scheduleMicrotask(_refresh);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(notificationUnreadCountProvider);
    final label = loopUnreadBadgeLabel(unread);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('chat-notification-bell'),
          icon: 'bell',
          label: label == null ? '通知' : '通知，未读 $label 条',
          onPressed: widget.onPressed,
        ),
        if (label != null)
          Positioned(
            top: 4,
            right: 2,
            child: IgnorePointer(
              child: LoopUnreadBadge(
                key: const ValueKey<String>('chat-notification-badge'),
                count: unread,
              ),
            ),
          ),
      ],
    );
  }
}
