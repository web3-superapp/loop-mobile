import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The forward and merge caps fixed by the step-4 ruling.
const int chatForwardSelectionLimit = 20;
const int chatMergeSelectionLimit = 50;

/// The anonymous author label used by every merged row.
const String chatMergeAnonymousLabel = '匿名成员';

/// One selectable message, reduced to what the two pages may render.
///
/// The sender is deliberately absent: the merged image is anonymous by
/// default, so no alias, LOOP ID, Stream user ID or address can leak into it.
@immutable
final class ChatForwardMessage {
  const ChatForwardMessage({
    required this.messageId,
    required this.text,
    required this.createdAt,
    required this.forwardable,
  });

  final String messageId;
  final String text;
  final DateTime createdAt;

  /// False for a deleted or non-text message: it is listed as skipped rather
  /// than silently dropped.
  final bool forwardable;
}

/// One channel the account is already a member of.
@immutable
final class ChatForwardTarget {
  const ChatForwardTarget({required this.cid, required this.label});

  final String cid;
  final String label;
}

@immutable
final class ChatForwardState {
  const ChatForwardState({
    this.sourceCid,
    this.messages = const <ChatForwardMessage>[],
    this.targets = const <ChatForwardTarget>[],
    this.selected = const <String>{},
    this.loading = false,
    this.failed = false,
    this.busy = false,
  });

  final String? sourceCid;
  final List<ChatForwardMessage> messages;
  final List<ChatForwardTarget> targets;
  final Set<String> selected;
  final bool loading;
  final bool failed;
  final bool busy;

  List<ChatForwardMessage> get selectedMessages => <ChatForwardMessage>[
    for (final message in messages)
      if (selected.contains(message.messageId)) message,
  ];

  /// The rows a merged image would actually render, capped at 50.
  List<ChatForwardMessage> get mergeRows {
    final forwardable = <ChatForwardMessage>[
      for (final message in selectedMessages)
        if (message.forwardable) message,
    ];
    return forwardable.length <= chatMergeSelectionLimit
        ? forwardable
        : forwardable.sublist(0, chatMergeSelectionLimit);
  }

  bool get mergeTruncated =>
      selectedMessages.where((message) => message.forwardable).length >
      chatMergeSelectionLimit;

  ChatForwardState copyWith({
    String? sourceCid,
    List<ChatForwardMessage>? messages,
    List<ChatForwardTarget>? targets,
    Set<String>? selected,
    bool? loading,
    bool? failed,
    bool? busy,
  }) => ChatForwardState(
    sourceCid: sourceCid ?? this.sourceCid,
    messages: messages ?? this.messages,
    targets: targets ?? this.targets,
    selected: selected ?? this.selected,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    busy: busy ?? this.busy,
  );
}

/// The outcome of one forward. `skipped` counts the messages the client
/// refused to send; `failed` counts the ones Stream rejected.
@immutable
final class ChatForwardOutcome {
  const ChatForwardOutcome({
    required this.sent,
    required this.skipped,
    required this.failed,
  });

  final int sent;
  final int skipped;
  final int failed;
}

/// Owns the selection shared by `chat-forward` and `chat-merge-preview`.
///
/// Stream types stay inside this feature: the controller projects messages and
/// channels into the two DTOs above before any page sees them.
final class ChatForwardController extends Notifier<ChatForwardState> {
  @override
  ChatForwardState build() => const ChatForwardState();

  Future<void> load(String sourceCid) async {
    if (state.sourceCid == sourceCid && state.messages.isNotEmpty) return;
    final session = ref.read(streamChatSdkSessionProvider);
    final userId = session?.client.state.currentUser?.id;
    if (session == null || userId == null) {
      state = ChatForwardState(sourceCid: sourceCid, failed: true);
      return;
    }
    state = ChatForwardState(sourceCid: sourceCid, loading: true);
    try {
      final channels = await session.client.queryChannelsOnline(
        filter: Filter.in_('members', <Object>[userId]),
        state: true,
        messageLimit: chatMergeSelectionLimit,
        paginationParams: const PaginationParams(limit: 30),
      );
      final targets = <ChatForwardTarget>[];
      final messages = <ChatForwardMessage>[];
      for (final channel in channels) {
        final cid = channel.cid;
        if (cid == null) continue;
        final surface = loopChatSurfaceForCid(cid);
        if (surface == null) continue;
        // A destination must be a channel the account already belongs to.
        if (channel.membership?.userId != userId) continue;
        if (cid != sourceCid) {
          targets.add(
            ChatForwardTarget(
              cid: cid,
              label: switch (surface) {
                LoopChatSurface.communityChat => '社区官方群',
                LoopChatSurface.group => '群聊',
                LoopChatSurface.direct => '私聊',
              },
            ),
          );
        } else {
          for (final message in channel.state?.messages ?? const <Message>[]) {
            messages.add(
              ChatForwardMessage(
                messageId: message.id,
                text: message.text ?? '',
                createdAt: message.createdAt,
                forwardable:
                    !message.isDeleted &&
                    (message.text ?? '').trim().isNotEmpty,
              ),
            );
          }
        }
      }
      state = ChatForwardState(
        sourceCid: sourceCid,
        messages: List<ChatForwardMessage>.unmodifiable(messages),
        targets: List<ChatForwardTarget>.unmodifiable(targets),
      );
    } catch (_) {
      state = ChatForwardState(sourceCid: sourceCid, failed: true);
    }
  }

  /// Returns false when the 20-message cap refused the selection.
  bool toggle(String messageId) {
    final next = Set<String>.of(state.selected);
    if (!next.remove(messageId)) {
      if (next.length >= chatForwardSelectionLimit) return false;
      next.add(messageId);
    }
    state = state.copyWith(selected: next);
    return true;
  }

  Future<ChatForwardOutcome?> forward(String targetCid) async {
    final session = ref.read(streamChatSdkSessionProvider);
    final source = state.sourceCid;
    if (session == null || source == null || state.busy) return null;
    final target = state.targets.firstWhere(
      (item) => item.cid == targetCid,
      orElse: () => const ChatForwardTarget(cid: '', label: ''),
    );
    // Only an already-joined channel from the loaded list may be a target.
    if (target.cid.isEmpty) return null;

    state = state.copyWith(busy: true);
    var sent = 0;
    var skipped = 0;
    var failed = 0;
    final address = parseLoopStreamChannelCid(targetCid);
    if (address == null) {
      state = state.copyWith(busy: false);
      return null;
    }
    final channel = session.client.channel(address.type, id: address.id);
    for (final message in state.selectedMessages) {
      if (!message.forwardable) {
        skipped += 1;
        continue;
      }
      try {
        await channel.sendMessage(
          Message(
            text: message.text,
            extraData: <String, Object?>{
              'loop_forwarded_from': <String, Object?>{
                'cid': source,
                'messageId': message.messageId,
              },
            },
          ),
        );
        sent += 1;
      } catch (_) {
        failed += 1;
      }
    }
    state = state.copyWith(busy: false);
    return ChatForwardOutcome(sent: sent, skipped: skipped, failed: failed);
  }
}

final chatForwardControllerProvider =
    NotifierProvider<ChatForwardController, ChatForwardState>(
      ChatForwardController.new,
    );

/// `chat-forward` · pick messages, then pick one joined channel.
class ChatForwardScreen extends ConsumerStatefulWidget {
  const ChatForwardScreen({
    required this.sourceCid,
    super.key,
    this.onBack,
    this.onOpenMergePreview,
  });

  final String? sourceCid;
  final VoidCallback? onBack;
  final VoidCallback? onOpenMergePreview;

  @override
  ConsumerState<ChatForwardScreen> createState() => _ChatForwardScreenState();
}

class _ChatForwardScreenState extends ConsumerState<ChatForwardScreen> {
  @override
  void initState() {
    super.initState();
    final cid = widget.sourceCid;
    if (cid != null) {
      scheduleMicrotask(
        () => unawaited(
          ref.read(chatForwardControllerProvider.notifier).load(cid),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatForwardControllerProvider);
    final selectedCount = state.selected.length;
    return LoopDashboardPage(
      key: const ValueKey<String>('chat-forward-screen'),
      archetype: LoopPageArchetype.state,
      title: '转发消息',
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.state,
        kicker: 'SELECTED THREAD',
        heading: '$selectedCount 条已选择',
        caption:
            '一次最多转发 $chatForwardSelectionLimit 条，目标只能是你已加入的会话。'
            '已删除或没有正文的消息会被跳过并计数。',
        stamp: '$selectedCount SELECTED',
      ),
      sections: <Widget>[
        if (widget.sourceCid == null)
          const LoopEmpty(
            key: ValueKey<String>('chat-forward-missing-source'),
            icon: 'warn',
            message: '缺少来源会话',
            reason: '请从会话页进入转发，本页不会猜测要转发哪个会话的消息。',
          )
        else if (state.loading)
          const LoopSkeleton(
            key: ValueKey<String>('chat-forward-loading'),
            type: LoopSkeletonType.list,
            rows: 4,
          )
        else if (state.failed)
          LoopErrorState(
            key: const ValueKey<String>('chat-forward-error'),
            reason: '没有读到这个会话的消息与可用目标，本页没有转发任何内容。',
            onRetry: () => unawaited(
              ref
                  .read(chatForwardControllerProvider.notifier)
                  .load(widget.sourceCid!),
            ),
          )
        else ...<Widget>[
          const LoopLabel('选择消息'),
          if (state.messages.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('chat-forward-no-messages'),
              message: '这个会话还没有可转发的消息',
              reason: '只有已同步到本机的文本消息可以被转发。',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (var index = 0; index < state.messages.length; index += 1)
                  _messageRow(state, index),
              ],
            ),
          const LoopLabel('发送到'),
          if (state.targets.isEmpty)
            const LoopEmpty(
              key: ValueKey<String>('chat-forward-no-targets'),
              message: '没有可用的目标会话',
              reason: '转发目标必须是你已加入的会话。',
            )
          else
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (var index = 0; index < state.targets.length; index += 1)
                  _targetRow(state, index),
              ],
            ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('chat-forward-cancel'),
                label: '取消',
                onPressed: widget.onBack,
              ),
              LoopButton(
                key: const ValueKey<String>('chat-forward-open-merge'),
                label: '预览合并长图',
                primary: true,
                onPressed: selectedCount == 0
                    ? null
                    : widget.onOpenMergePreview,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  LoopRecordRow _messageRow(ChatForwardState state, int index) {
    final message = state.messages[index];
    final selected = state.selected.contains(message.messageId);
    return LoopRecordRow(
      key: ValueKey<String>('chat-forward-message-${message.messageId}'),
      title: message.forwardable ? message.text : '这条消息不能转发',
      subtitle: message.forwardable
          ? communityObservedAtLabel(message.createdAt)
          : '已删除或没有正文，转发时会被跳过。',
      trailingBadge: selected
          ? const LoopBadge('已选', kind: LoopBadgeKind.up)
          : null,
      position: index == 0
          ? LoopRowPosition.first
          : index == state.messages.length - 1
          ? LoopRowPosition.last
          : LoopRowPosition.middle,
      onTap: message.forwardable
          ? () {
              final accepted = ref
                  .read(chatForwardControllerProvider.notifier)
                  .toggle(message.messageId);
              if (!accepted) {
                LoopToast.show(
                  context,
                  message: '一次最多选择 $chatForwardSelectionLimit 条',
                  kind: LoopToastKind.warn,
                );
              }
            }
          : null,
    );
  }

  LoopRecordRow _targetRow(ChatForwardState state, int index) {
    final target = state.targets[index];
    return LoopRecordRow(
      key: ValueKey<String>('chat-forward-target-${target.cid}'),
      title: target.label,
      subtitle: '已加入的会话',
      position: index == 0
          ? LoopRowPosition.first
          : index == state.targets.length - 1
          ? LoopRowPosition.last
          : LoopRowPosition.middle,
      onTap: state.selected.isEmpty || state.busy
          ? null
          : () => unawaited(_forward(target)),
    );
  }

  Future<void> _forward(ChatForwardTarget target) async {
    final confirmed = await confirmCommunityAction(
      context,
      title: '转发到这个会话？',
      body: '已选择的消息会以新消息发出，并标注来源会话。已删除或没有正文的消息会被跳过。',
      confirmLabel: '转发',
      sheetKey: 'chat-forward-confirm-sheet',
    );
    if (!confirmed || !mounted) return;
    final outcome = await ref
        .read(chatForwardControllerProvider.notifier)
        .forward(target.cid);
    if (!mounted) return;
    if (outcome == null) {
      LoopToast.show(context, message: '没有转发任何消息', kind: LoopToastKind.warn);
      return;
    }
    final skipped = outcome.skipped + outcome.failed;
    LoopToast.show(
      context,
      message: skipped == 0
          ? '已转发 ${outcome.sent} 条'
          : '已转发 ${outcome.sent} 条，跳过 $skipped 条',
      kind: skipped == 0 ? LoopToastKind.ok : LoopToastKind.warn,
    );
  }
}

/// `chat-merge-preview` · the anonymous merged transcript.
///
/// Anonymous is the only mode: every row shows `匿名成员`, the timestamp and
/// the text. No alias, LOOP ID, Stream user ID or wallet address is rendered,
/// so none can be exported either.
class ChatMergePreviewScreen extends ConsumerWidget {
  const ChatMergePreviewScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatForwardControllerProvider);
    final rows = state.mergeRows;
    return LoopDashboardPage(
      key: const ValueKey<String>('chat-merge-preview-screen'),
      archetype: LoopPageArchetype.state,
      title: '合并长图预览',
      onBack: onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.state,
        kicker: 'ANONYMOUS BY DEFAULT',
        heading: '${rows.length} 条内容',
        caption:
            '合并预览只输出「$chatMergeAnonymousLabel」、时间与正文，'
            '不含昵称、LOOP ID 或钱包地址。',
        stamp: 'ANONYMOUS',
      ),
      sections: <Widget>[
        if (rows.isEmpty)
          const LoopEmpty(
            key: ValueKey<String>('chat-merge-empty'),
            message: '还没有选择任何消息',
            reason: '回到转发页选择要合并的消息，最多 $chatMergeSelectionLimit 条。',
          )
        else ...<Widget>[
          if (state.mergeTruncated)
            LoopNotice(
              key: const ValueKey<String>('chat-merge-truncated'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '已截断',
              body: '一次最多合并 $chatMergeSelectionLimit 条，多出的部分不会出现在预览里。',
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            ),
          LoopChalkCard(
            key: const ValueKey<String>('chat-merge-card'),
            margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final row in rows)
                  Padding(
                    key: ValueKey<String>('chat-merge-row-${row.messageId}'),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '$chatMergeAnonymousLabel · '
                          '${communityObservedAtLabel(row.createdAt)}',
                          style: LoopTypography.mono(
                            size: 9.5,
                            weight: FontWeight.w600,
                            color: LoopColors.inkText3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          row.text,
                          style: LoopTypography.sora(
                            size: 11,
                            weight: FontWeight.w400,
                            height: 1.55,
                            color: LoopColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const LoopNotice(
            key: ValueKey<String>('chat-merge-privacy-note'),
            icon: 'shield',
            title: '不输出身份',
            body: '钱包地址、昵称与内部 ID 永远不会进入合并长图，合并结果也不会上传到 LOOP 服务端。',
            margin: EdgeInsets.fromLTRB(16, 14, 16, 0),
          ),
          const LoopEmpty(
            key: ValueKey<String>('chat-merge-export-unavailable'),
            icon: 'warn',
            message: '生成长图当前不可用',
            reason: '导出与系统分享还没有经过评审的实现，本页只做本机预览，不会生成或上传任何文件。',
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}
