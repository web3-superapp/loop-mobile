import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/chat/chat_state.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/notifications/notification_inbox.dart';
import 'package:loop_mobile/features/social/social_controllers.dart';
import 'package:loop_mobile/integrations/communication/communication_gateway.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// Whether the stranger requests waiting on this account may be shown.
///
/// The Development Preview reads its requests from memory, so nothing about
/// them is drawn there: a count with no 演示数据 mark beside it would read as
/// real.
bool _requestsShown(WidgetRef ref) =>
    ref.watch(communicationGatewayProvider).mode != CommunicationMode.preview;

/// Starts the stranger-request read once, while it has not answered.
void _loadRequests(WidgetRef ref, MessageRequestsState state, bool mounted) {
  if (state.phase != CommunityViewPhase.loading || state.refreshing) return;
  scheduleMicrotask(() {
    if (mounted) {
      unawaited(ref.read(messageRequestsControllerProvider.notifier).load());
    }
  });
}

/// Whether 我的 needs a look (S343 · decision 0271): a notification is
/// unread, or a stranger request waits. [builder] gets the answer; the shell
/// draws it as a dot on the tab.
///
/// The unread total is read when the shell first appears and again when the
/// App comes back to the foreground (at most once a minute); a notification
/// arriving and a read in the centre force a read of their own. Nothing polls.
class LoopMeAttentionReader extends ConsumerStatefulWidget {
  const LoopMeAttentionReader({required this.builder, super.key});

  final Widget Function(BuildContext context, bool attention) builder;

  @override
  ConsumerState<LoopMeAttentionReader> createState() =>
      _LoopMeAttentionReaderState();
}

class _LoopMeAttentionReaderState extends ConsumerState<LoopMeAttentionReader> {
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
    final unread = ref.watch(notificationUnreadCountProvider) ?? 0;
    var waiting = false;
    if (_requestsShown(ref)) {
      final requests = ref.watch(messageRequestsControllerProvider);
      _loadRequests(ref, requests, mounted);
      waiting =
          requests.phase == CommunityViewPhase.ready &&
          requests.items.isNotEmpty;
    }
    return widget.builder(context, unread > 0 || waiting);
  }
}

/// 我的's entry to the stranger requests waiting on this account (S343 ·
/// decision 0271; it stood above the 聊天 list before).
///
/// Drawn only when the request list was read and is not empty: an entry
/// with nothing behind it would be one more row to read on every visit.
class MeMessageRequestsEntry extends ConsumerWidget {
  const MeMessageRequestsEntry({super.key, this.onOpen});

  /// Opens `dm-requests`; defaults to pushing `/chat/requests`.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_requestsShown(ref)) return const SizedBox.shrink();
    final state = ref.watch(messageRequestsControllerProvider);
    _loadRequests(ref, state, context.mounted);
    if (state.phase != CommunityViewPhase.ready || state.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final count = state.items.length;
    final label = state.nextCursor == null ? '$count' : '$count+';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
      child: LoopRecordGroup(
        rows: <LoopRecordRow>[
          LoopRecordRow(
            key: const ValueKey<String>('stream-chat-message-requests-entry'),
            // Decision 0212: a quiet Text2 glyph, not a Yellow one.
            leading: const LoopRowIcon(icon: 'mail'),
            title: context.l10n.common_messageRequests,
            trailing: context.l10n
                .profile_meAttentionStreamChatMessageRequestsEntryTrailing(
                  label,
                ),
            semanticLabel: context.l10n
                .profile_meAttentionStreamChatMessageRequestsEntrySemanticLabel(
                  label,
                ),
            onTap:
                onOpen ?? () => unawaited(context.push<void>('/chat/requests')),
          ),
        ],
      ),
    );
  }
}
