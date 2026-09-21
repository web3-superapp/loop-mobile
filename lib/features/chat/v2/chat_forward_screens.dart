import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/v2/chat_conversation_label.dart';
import 'package:loop_mobile/features/chat/v2/chat_merge_export.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:loop_mobile/integrations/communication/stream_failure.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The forward and merge caps fixed by the step-4 ruling.
const int chatForwardSelectionLimit = 20;
const int chatMergeSelectionLimit = 50;

/// How many recent conversations the destination list offers. It is one page,
/// not the account's complete channel set, and the page says so.
const int chatForwardTargetPageSize = 30;

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
  const ChatForwardTarget({
    required this.cid,
    required this.label,
    required this.detail,
  });

  final String cid;

  /// The conversation's own name, or the kind when LOOP has no name for it.
  final String label;

  /// The kind, and the membership figure the provider stated.
  final String detail;
}

@immutable
final class ChatForwardState {
  const ChatForwardState({
    this.sourceCid,
    this.sourceLabel,
    this.messages = const <ChatForwardMessage>[],
    this.targets = const <ChatForwardTarget>[],
    this.selected = const <String>{},
    this.loading = false,
    this.failed = false,
    this.offline = false,
    this.busy = false,
  });

  final String? sourceCid;

  /// The name of the conversation these messages came from, or `null` when
  /// LOOP has none. `#scr-chat-forward` prints it as the hero's heading —
  /// `PEPE Official · 3 messages` — so the page says what is being forwarded
  /// and not only how much.
  final String? sourceLabel;
  final List<ChatForwardMessage> messages;
  final List<ChatForwardTarget> targets;
  final Set<String> selected;
  final bool loading;
  final bool failed;

  /// The read never reached Stream. Nothing was forwarded and nothing was
  /// disproved, so the page pauses instead of reporting a failure.
  final bool offline;
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
    String? sourceLabel,
    List<ChatForwardMessage>? messages,
    List<ChatForwardTarget>? targets,
    Set<String>? selected,
    bool? loading,
    bool? failed,
    bool? offline,
    bool? busy,
  }) => ChatForwardState(
    sourceCid: sourceCid ?? this.sourceCid,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    messages: messages ?? this.messages,
    targets: targets ?? this.targets,
    selected: selected ?? this.selected,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    offline: offline ?? this.offline,
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
/// Not `final`: a test seeds an exact selection by overriding [build], which
/// is how the merged card is reached without driving a Stream query.
base class ChatForwardController extends Notifier<ChatForwardState> {
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
      // The source conversation is queried on its own, by exact CID and
      // current membership, so the message list can never come from whichever
      // page of the inbox happened to contain it.
      final sourceChannels = await session.client.queryChannelsOnline(
        filter: Filter.and(<Filter>[
          Filter.equal('cid', sourceCid),
          Filter.in_('members', <Object>[userId]),
        ]),
        state: true,
        messageLimit: chatMergeSelectionLimit,
        paginationParams: const PaginationParams(limit: 1),
      );
      final messages = <ChatForwardMessage>[];
      String? sourceLabel;
      if (sourceChannels.length == 1 &&
          sourceChannels.single.cid == sourceCid &&
          sourceChannels.single.membership?.userId == userId) {
        sourceLabel = loopStoredConversationName(
          sourceChannels.single.extraData,
        );
        for (final message
            in sourceChannels.single.state?.messages ?? const <Message>[]) {
          messages.add(
            ChatForwardMessage(
              messageId: message.id,
              text: message.text ?? '',
              createdAt: message.createdAt,
              forwardable:
                  !message.isDeleted && (message.text ?? '').trim().isNotEmpty,
            ),
          );
        }
      }

      // The destination list is one bounded page of the account's most
      // recently updated conversations; the page says so rather than implying
      // it is the complete set.
      final destinations = await session.client.queryChannelsOnline(
        filter: Filter.in_('members', <Object>[userId]),
        sort: const <SortOption<ChannelState>>[
          SortOption<ChannelState>.desc(ChannelSortKey.lastUpdated),
        ],
        paginationParams: const PaginationParams(
          limit: chatForwardTargetPageSize,
        ),
      );
      // LOOP's own index of its direct channels: the one authority for who a
      // 1:1 conversation is with. A read that has not landed leaves those
      // rows neutral rather than borrowing a name from the provider.
      final directory = ref
          .read(directChannelDirectoryProvider)
          .maybeWhen(data: (value) => value, orElse: () => null);
      final targets = <ChatForwardTarget>[];
      for (final channel in destinations) {
        final cid = channel.cid;
        if (cid == null || cid == sourceCid) continue;
        final surface = loopChatSurfaceForCid(cid);
        if (surface == null) continue;
        // A destination must be a channel the account already belongs to.
        if (channel.membership?.userId != userId) continue;
        // The row is named after the conversation, not after its kind. Nine
        // community channels used to arrive as nine rows reading 社区官方群,
        // with nothing to tell them apart (audit 2026-09-20 · B.6).
        final label = resolveChatConversationLabel(
          surface: surface,
          extraData: channel.extraData,
          cid: cid,
          memberCount: channel.memberCount,
          directory: directory,
        );
        targets.add(
          ChatForwardTarget(
            cid: cid,
            label: label.title,
            detail: label.subtitle,
          ),
        );
      }
      state = ChatForwardState(
        sourceCid: sourceCid,
        sourceLabel: sourceLabel,
        messages: List<ChatForwardMessage>.unmodifiable(messages),
        targets: List<ChatForwardTarget>.unmodifiable(targets),
      );
    } catch (error) {
      // A query that never reached Stream is not "this conversation has no
      // messages" and not "the read failed": it is a pause.
      final offline = loopStreamFailureIsOffline(error);
      state = ChatForwardState(
        sourceCid: sourceCid,
        failed: !offline,
        offline: offline,
      );
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
      orElse: () => const ChatForwardTarget(cid: '', label: '', detail: ''),
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
      // `#scr-chat-forward .topbar` carries `3 SELECTED · CHOOSE DESTINATION`
      // under the title: the count and the next step, in one line, before the
      // reader reaches the hero.
      kicker: null,
      subtitle: '$selectedCount 条已选择 · 选择目标会话',
      onBack: widget.onBack,
      framedTools: true,
      primary: LoopFolioPrimary(
        // `.chalk-card.folio-state.folio-primary` resolves to
        // `background:var(--lime);color:var(--ink)` — the one solid Lime hero
        // in the prototype, and the app had none (audit 2026-09-20 · B.6).
        variant: LoopFolioVariant.lime,
        archetype: LoopFolioArchetype.state,
        kicker: 'SELECTED THREAD',
        heading: switch ((state.sourceLabel, selectedCount)) {
          (final String source?, final int count) => '$source · $count 条',
          (null, final int count) => '$count 条已选择',
        },
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
            message: '找不到原会话',
            reason: '请从会话页进入转发，本页不会猜测要转发哪个会话的消息。',
          )
        else if (state.loading)
          const LoopSkeleton(
            key: ValueKey<String>('chat-forward-loading'),
            type: LoopSkeletonType.list,
            rows: 4,
          )
        else if (state.offline)
          LoopOfflineState(
            key: const ValueKey<String>('chat-forward-state-offline'),
            pausedActions: const <String>['读取消息', '选择目标', '转发'],
            onRetry: () => unawaited(
              ref
                  .read(chatForwardControllerProvider.notifier)
                  .load(widget.sourceCid!),
            ),
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
          // `.label` — the prototype's `发送到`, with the scope of the list in
          // it rather than in a fourth explanation card below it
          // (audit 2026-09-20 · B.6).
          const LoopLabel('发送到 · 最近 $chatForwardTargetPageSize 个会话'),
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
    // A community's official channel is that community, so the row wears the
    // community's own face — the same one its home row, its record and both
    // mining boards draw. The channel carries no `logoRef`, so a preset image
    // cannot be resolved here; the id-derived monogram is the same face that
    // community shows wherever its preset has no local image.
    final communityId = loopCommunityIdForChannelCid(target.cid);
    return LoopRecordRow(
      key: ValueKey<String>('chat-forward-target-${target.cid}'),
      // `.row-ico`: the prototype's destination rows all carry one.
      leading: communityId == null
          ? LoopInitialsAvatar(
              label: target.label,
              size: 44,
              shape: BoxShape.rectangle,
              radius: 15,
            )
          : CommunityLogo(
              identity: communityId,
              name: target.label,
              size: 44,
              radius: 15,
            ),
      title: target.label,
      subtitle: target.detail,
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
      body: '选中的消息会作为新消息发出，并标注来自哪个会话。已删除或没有正文的消息会跳过。',
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
/// so none can be exported either — the exported PNG is a pixel copy of the
/// card the viewer can see, encoded on device and handed straight to the
/// system share sheet.
class ChatMergePreviewScreen extends ConsumerStatefulWidget {
  const ChatMergePreviewScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<ChatMergePreviewScreen> createState() =>
      _ChatMergePreviewScreenState();
}

class _ChatMergePreviewScreenState
    extends ConsumerState<ChatMergePreviewScreen> {
  final GlobalKey _cardKey = GlobalKey(debugLabel: 'chat-merge-card-boundary');
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatForwardControllerProvider);
    final rows = state.mergeRows;
    return LoopDashboardPage(
      key: const ValueKey<String>('chat-merge-preview-screen'),
      archetype: LoopPageArchetype.state,
      title: '合并长图预览',
      // `#scr-chat-merge-preview .topbar`: `Merge Preview` over
      // `ANONYMOUS BY DEFAULT`.
      subtitle: '默认匿名',
      onBack: widget.onBack,
      framedTools: true,
      // `#scr-chat-merge-preview` has no folio of its own: the Chalk card
      // *is* `[data-ll-primary]`, because the page's one primary narrative is
      // the image about to be exported. A deep hero above it turned the
      // preview into an illustration of itself (audit 2026-09-20 · B.7).
      //
      // The exported image is captured from exactly this subtree, so the
      // anonymous rendering inside it is the only thing that can be encoded.
      primary: rows.isEmpty
          ? const LoopFolioPrimary(
              variant: LoopFolioVariant.quiet,
              archetype: LoopFolioArchetype.state,
              kicker: 'ANONYMOUS BY DEFAULT',
              heading: '0 条内容',
              caption:
                  '合并预览只输出「$chatMergeAnonymousLabel」、时间与正文，'
                  '不含昵称、LOOP ID 或钱包地址。',
              stamp: 'ANONYMOUS',
            )
          : RepaintBoundary(
              key: _cardKey,
              child: _MergeCard(
                key: const ValueKey<String>('chat-merge-card'),
                rows: rows,
                sourceLabel: state.sourceLabel,
                selectedCount: state.selectedMessages.length,
              ),
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
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            ),
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('chat-merge-back'),
                label: '返回聊天',
                onPressed: widget.onBack,
              ),
              LoopButton(
                key: const ValueKey<String>('chat-merge-export'),
                label: '生成长图',
                primary: true,
                onPressed: _exporting ? null : () => unawaited(_export()),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  /// Captures the anonymous card, encodes it as PNG on device and hands the
  /// bytes to the system share sheet. Nothing is uploaded and nothing is kept.
  Future<void> _export() async {
    setState(() => _exporting = true);
    final sink = ref.read(chatMergeExportSinkProvider);
    ChatMergeExportOutcome outcome;
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      final bytes = boundary == null ? null : await _encode(boundary);
      outcome = bytes == null
          ? ChatMergeExportOutcome.failed
          : await sink.shareImage(
              pngBytes: bytes,
              fileName: 'loop-merge-preview.png',
            );
    } catch (_) {
      outcome = ChatMergeExportOutcome.failed;
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    LoopToast.show(
      context,
      message: chatMergeExportMessage(outcome),
      kind: outcome == ChatMergeExportOutcome.shared
          ? LoopToastKind.ok
          : LoopToastKind.warn,
    );
  }

  static Future<Uint8List?> _encode(RenderRepaintBoundary boundary) async {
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}

/// The exported image itself, as the reader sees it before it exists.
///
/// `#scr-chat-merge-preview` is one Chalk card holding the whole export: the
/// source over the title, the `3/5 VISIBLE` Ink badge beside them, a rule,
/// then numbered rows with a hairline between each, and the privacy line
/// along the bottom edge. LOOP had split it into a deep hero, a grey card of
/// three bare paragraphs and a separate notice, so the preview no longer
/// looked like the thing being exported (audit 2026-09-20 · B.7).
///
/// The capture boundary is around exactly this widget, so everything drawn
/// here — and nothing else — is what the PNG contains.
class _MergeCard extends StatelessWidget {
  const _MergeCard({
    required this.rows,
    required this.sourceLabel,
    required this.selectedCount,
    super.key,
  });

  final List<ChatForwardMessage> rows;

  /// The conversation the selection came from, when LOOP has its name.
  final String? sourceLabel;

  /// How many messages were picked, including the ones that cannot be shown.
  final int selectedCount;

  @override
  Widget build(BuildContext context) => LoopChalkCard(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    sourceLabel == null ? '已选择的会话' : '$sourceLabel · 已选择的会话',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopTypography.eyebrow(
                      11,
                      color: LoopColors.inkText3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '社区信号摘要',
                    style: LoopTypography.display(26, color: LoopColors.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // `3/5 VISIBLE`: how much of the selection the image can carry.
            // It is a count of rows, not a verdict on the ones left out —
            // those are the deleted and the empty, and the page says which.
            Container(
              key: const ValueKey<String>('chat-merge-visible-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: const BoxDecoration(
                color: LoopColors.ink,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${rows.length}/$selectedCount',
                    style: LoopTypography.display(17, color: LoopColors.chalk),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '将输出',
                    style: LoopTypography.eyebrow(
                      11,
                      color: LoopColors.chalk.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // `.ledger-rule`.
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 14),
          color: LoopColors.ink.withValues(alpha: 0.18),
        ),
        for (var index = 0; index < rows.length; index += 1)
          _MergeRow(
            key: ValueKey<String>('chat-merge-row-${rows[index].messageId}'),
            row: rows[index],
            ordinal: index + 1,
            // `01` is Ink, `02` is Lime, `03` is Ink again: the prototype
            // alternates so a long column of numbers keeps a beat.
            accent: index.isOdd,
            last: index == rows.length - 1,
          ),
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 13),
          color: LoopColors.ink.withValues(alpha: 0.18),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const LoopIcon('shield', size: 13, color: LoopColors.inkText3),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '钱包地址、昵称与内部编号不会出现在长图里，长图也不会上传。',
                style: LoopTypography.caption(11, color: LoopColors.inkText3),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// One numbered row of the export.
class _MergeRow extends StatelessWidget {
  const _MergeRow({
    required this.row,
    required this.ordinal,
    required this.accent,
    required this.last,
    super.key,
  });

  final ChatForwardMessage row;
  final int ordinal;
  final bool accent;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 11),
    decoration: last
        ? null
        : BoxDecoration(
            border: Border(
              bottom: BorderSide(color: LoopColors.ink.withValues(alpha: 0.18)),
            ),
          ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent ? LoopColors.lime : LoopColors.ink,
            borderRadius: const BorderRadius.all(Radius.circular(15)),
          ),
          child: Text(
            ordinal.toString().padLeft(2, '0'),
            style: LoopTypography.figure(
              11,
              color: accent ? LoopColors.ink : LoopColors.chalk,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                chatMergeAnonymousLabel,
                style: LoopTypography.label(14, color: LoopColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                communityObservedAtLabel(row.createdAt),
                style: LoopTypography.figure(11, color: LoopColors.inkText3),
              ),
              const SizedBox(height: 5),
              Text(
                row.text,
                style: LoopTypography.caption(11, color: LoopColors.ink),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
