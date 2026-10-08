import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_failure.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// Where a forward goes and how it gets there (S108 §2.2).
///
/// The Stream session is the only implementation in the app; a test answers
/// with its own list and records what was sent.
abstract interface class ChatForwardPort {
  /// The account's recent joined conversations, without [excludeCid].
  Future<List<ChatForwardTarget>> recentTargets({required String excludeCid});

  /// Sends one forwarded copy of [message] into [targetCid].
  Future<void> send({
    required String sourceCid,
    required String targetCid,
    required ChatForwardMessage message,
  });
}

/// Thrown when there is no connected chat session to forward through.
final class ChatForwardSessionMissing implements Exception {
  const ChatForwardSessionMissing();
}

final class StreamChatForwardPort implements ChatForwardPort {
  const StreamChatForwardPort(this._ref);

  final Ref _ref;

  @override
  Future<List<ChatForwardTarget>> recentTargets({
    required String excludeCid,
  }) async {
    final session = _ref.read(streamChatSdkSessionProvider);
    final userId = session?.client.state.currentUser?.id;
    if (session == null || userId == null) {
      throw const ChatForwardSessionMissing();
    }
    return queryChatForwardTargets(
      client: session.client,
      userId: userId,
      excludeCid: excludeCid,
      directory: _ref
          .read(directChannelDirectoryProvider)
          .maybeWhen(data: (value) => value, orElse: () => null),
    );
  }

  @override
  Future<void> send({
    required String sourceCid,
    required String targetCid,
    required ChatForwardMessage message,
  }) {
    final session = _ref.read(streamChatSdkSessionProvider);
    final address = parseLoopStreamChannelCid(targetCid);
    if (session == null || address == null) {
      return Future<void>.error(const ChatForwardSessionMissing());
    }
    return chatForwardSendOne(
      channel: session.client.channel(address.type, id: address.id),
      sourceCid: sourceCid,
      message: message,
    );
  }
}

final chatForwardPortProvider = Provider<ChatForwardPort>(
  StreamChatForwardPort.new,
);

/// Opens [ForwardTargetSheet] for [messages] and reports the outcome.
///
/// Returns `null` when the reader closed the sheet without choosing. The
/// toast is shown here, on [context], once the sheet is gone.
Future<ChatForwardOutcome?> showChatForwardTargetSheet(
  BuildContext context, {
  required String sourceCid,
  required List<ChatForwardMessage> messages,
}) async {
  final outcome = await showLoopSheet<ChatForwardOutcome>(
    context,
    barrierLabel: '关闭转发',
    builder: (_) =>
        ForwardTargetSheet(sourceCid: sourceCid, messages: messages),
  );
  if (outcome == null || !context.mounted) return outcome;
  final missed = outcome.skipped + outcome.failed;
  LoopToast.show(
    context,
    message: switch ((outcome.sent, missed)) {
      (0, _) => '没有转发任何消息',
      (_, 0) when messages.length == 1 => '已转发',
      (final sent, 0) => '已转发 $sent 条',
      (final sent, final missed) => '已转发 $sent 条，跳过 $missed 条',
    },
    kind: outcome.sent > 0 && missed == 0
        ? LoopToastKind.ok
        : LoopToastKind.warn,
  );
  return outcome;
}

/// `ForwardTargetSheet`: pick one recent conversation; the forward is sent
/// the moment it is picked.
///
/// The list is the same bounded page `chat-forward` offers — the account's
/// thirty most recently updated joined conversations — and says so. Messages
/// that cannot travel (deleted, a picture, no text) are counted, not sent.
class ForwardTargetSheet extends ConsumerStatefulWidget {
  const ForwardTargetSheet({
    required this.sourceCid,
    required this.messages,
    super.key,
  });

  final String sourceCid;
  final List<ChatForwardMessage> messages;

  @override
  ConsumerState<ForwardTargetSheet> createState() => _ForwardTargetSheetState();
}

class _ForwardTargetSheetState extends ConsumerState<ForwardTargetSheet> {
  late Future<List<ChatForwardTarget>> _targets = _load();
  String? _sendingTo;

  Future<List<ChatForwardTarget>> _load() {
    final pending = ref
        .read(chatForwardPortProvider)
        .recentTargets(excludeCid: widget.sourceCid);
    pending.ignore();
    return pending;
  }

  Future<void> _send(ChatForwardTarget target) async {
    if (_sendingTo != null) return;
    setState(() => _sendingTo = target.cid);
    final port = ref.read(chatForwardPortProvider);
    var sent = 0;
    var skipped = 0;
    var failed = 0;
    for (final message in widget.messages) {
      if (!message.forwardable) {
        skipped += 1;
        continue;
      }
      try {
        await port.send(
          sourceCid: widget.sourceCid,
          targetCid: target.cid,
          message: message,
        );
        sent += 1;
      } catch (_) {
        failed += 1;
      }
    }
    if (!mounted) return;
    Navigator.of(context)
        .pop(ChatForwardOutcome(sent: sent, skipped: skipped, failed: failed));
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.messages.length;
    return Padding(
      key: const ValueKey<String>('forward-target-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            count == 1 ? '转发到' : '逐条转发 $count 条到',
            style: LoopTypography.heading(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '最近 $chatForwardTargetPageSize 个已加入的会话 · 转发后会标注来源会话',
            style: LoopTypography.caption(12),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: FutureBuilder<List<ChatForwardTarget>>(
              future: _targets,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoopSkeleton(
                    key: ValueKey<String>('forward-target-sheet-loading'),
                    type: LoopSkeletonType.list,
                    rows: 4,
                  );
                }
                if (snapshot.hasError) {
                  void retry() => setState(() => _targets = _load());
                  if (loopStreamFailureIsOffline(snapshot.error)) {
                    return LoopOfflineState(
                      key: const ValueKey<String>(
                        'forward-target-sheet-offline',
                      ),
                      pausedActions: const <String>['读取会话', '转发'],
                      onRetry: retry,
                      margin: EdgeInsets.zero,
                    );
                  }
                  return LoopErrorState(
                    key: const ValueKey<String>('forward-target-sheet-error'),
                    reason: '没有读到可转发的会话，本次没有转发任何内容。',
                    onRetry: retry,
                    margin: EdgeInsets.zero,
                  );
                }
                final targets = snapshot.data ?? const <ChatForwardTarget>[];
                if (targets.isEmpty) {
                  return const LoopEmpty(
                    key: ValueKey<String>('forward-target-sheet-empty'),
                    message: '没有可用的目标会话',
                    reason: '转发目标必须是你已加入的会话。',
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: LoopColors.line),
                  itemBuilder: (context, index) => _TargetRow(
                    target: targets[index],
                    sending: _sendingTo == targets[index].cid,
                    enabled: _sendingTo == null,
                    onTap: () => unawaited(_send(targets[index])),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.target,
    required this.sending,
    required this.enabled,
    required this.onTap,
  });

  final ChatForwardTarget target;
  final bool sending;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final communityId = loopCommunityIdForChannelCid(target.cid);
    return InkWell(
      key: ValueKey<String>('forward-target-${target.cid}'),
      onTap: enabled ? onTap : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: <Widget>[
              if (communityId == null)
                LoopInitialsAvatar(
                  label: target.label,
                  size: 40,
                  shape: BoxShape.rectangle,
                  radius: 13,
                )
              else
                CommunityLogo(
                  identity: communityId,
                  name: target.label,
                  size: 40,
                  radius: 13,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      target.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopTypography.title(15),
                    ),
                    Text(
                      target.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LoopTypography.caption(12),
                    ),
                  ],
                ),
              ),
              if (sending)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: LoopColors.lime,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
