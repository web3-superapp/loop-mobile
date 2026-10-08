import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/member_buy/member_buy_event.dart';
import 'package:loop_mobile/features/chat/v2/chat_conversation_label.dart';
import 'package:loop_mobile/features/chat/v2/chat_forward_screens.dart';
import 'package:loop_mobile/features/chat/v2/forward_target_sheet.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The most messages one multi-select may hold — the forward cap the step-4
/// ruling fixed, shared with `chat-forward`.
const int loopMessageSelectionLimit = chatForwardSelectionLimit;

/// The location of the merged-image preview (`chat-merge-preview`).
const String loopChatMergePreviewLocation = '/chat/merge-preview';

/// What a tap on a row did to the selection.
enum LoopMessageSelectionChange { added, removed, refusedAtLimit }

/// Whether a message may be ticked at all: a sent message that is still
/// there. A member-buy feed card is LOOP's own row, not a member's message,
/// and is not part of a selection.
bool loopMessageSelectable(Message message) =>
    !message.isDeleted &&
    !message.state.isDeleted &&
    !message.state.isFailed &&
    !message.state.isOutgoing &&
    !loopIsMemberBuyMessage(message);

/// The ticked messages as the conversation holds them now.
@immutable
final class LoopSelectedMessages {
  const LoopSelectedMessages({
    required this.messages,
    required this.unavailable,
  });

  /// Still loaded and not deleted, oldest first — the order a forward sends
  /// them in and the merged image lists them in.
  final List<Message> messages;

  /// Ticked, but deleted since or no longer in the loaded conversation.
  final int unavailable;
}

/// One conversation's multi-select (S108 §2.2).
///
/// Off until 「多选」 starts it on a message; then each row carries a check
/// box, the top bar reads 「已选 N 条」 and the composer gives way to the
/// action bar. At most [loopMessageSelectionLimit] messages.
///
/// Only ids are kept. A message can be edited or deleted while it is ticked,
/// so every action reads the messages back from the channel when it runs
/// ([resolve]) instead of acting on a copy taken when the box was ticked.
class LoopMessageSelectionController extends ChangeNotifier {
  final Set<String> _selected = <String>{};
  bool _active = false;

  bool get active => _active;
  int get count => _selected.length;
  bool isSelected(String messageId) => _selected.contains(messageId);
  Set<String> get selectedIds => Set<String>.unmodifiable(_selected);

  /// Enters selection with [message] already ticked.
  void start(Message message) {
    _active = true;
    _selected.clear();
    if (loopMessageSelectable(message)) _selected.add(message.id);
    notifyListeners();
  }

  LoopMessageSelectionChange toggle(Message message) {
    final LoopMessageSelectionChange change;
    if (_selected.remove(message.id)) {
      change = LoopMessageSelectionChange.removed;
    } else if (_selected.length >= loopMessageSelectionLimit) {
      return LoopMessageSelectionChange.refusedAtLimit;
    } else {
      _selected.add(message.id);
      change = LoopMessageSelectionChange.added;
    }
    notifyListeners();
    return change;
  }

  /// The ticked messages among [loaded] — the channel's current messages.
  LoopSelectedMessages resolve(Iterable<Message> loaded) {
    final byId = <String, Message>{
      for (final message in loaded) message.id: message,
    };
    final messages = <Message>[];
    var unavailable = 0;
    for (final id in _selected) {
      final message = byId[id];
      if (message == null || message.isDeleted || message.state.isDeleted) {
        unavailable += 1;
      } else {
        messages.add(message);
      }
    }
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return LoopSelectedMessages(
      messages: List<Message>.unmodifiable(messages),
      unavailable: unavailable,
    );
  }

  /// Leaves selection and forgets every tick.
  void cancel() {
    if (!_active && _selected.isEmpty) return;
    _active = false;
    _selected.clear();
    notifyListeners();
  }
}

/// Publishes one conversation's [LoopMessageSelectionController] to its top
/// bar, its message rows and its composer slot.
class LoopMessageSelectionScope
    extends InheritedNotifier<LoopMessageSelectionController> {
  const LoopMessageSelectionScope({
    required LoopMessageSelectionController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// The controller, rebuilding [context] whenever the selection changes.
  static LoopMessageSelectionController? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LoopMessageSelectionScope>()
          ?.notifier;

  /// The controller, without subscribing — for a callback, not a build.
  static LoopMessageSelectionController? read(BuildContext context) => context
      .getInheritedWidgetOfExactType<LoopMessageSelectionScope>()
      ?.notifier;
}

/// Owns the selection for one conversation page.
///
/// The system back gesture leaves selection first and the page second.
class LoopMessageSelectionHost extends StatefulWidget {
  const LoopMessageSelectionHost({required this.child, super.key});

  final Widget child;

  @override
  State<LoopMessageSelectionHost> createState() =>
      _LoopMessageSelectionHostState();
}

class _LoopMessageSelectionHostState extends State<LoopMessageSelectionHost> {
  final LoopMessageSelectionController _controller =
      LoopMessageSelectionController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LoopMessageSelectionScope(
    controller: _controller,
    child: ListenableBuilder(
      listenable: _controller,
      builder: (context, child) => PopScope(
        canPop: !_controller.active,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _controller.cancel();
        },
        child: child!,
      ),
      child: widget.child,
    ),
  );
}

/// The page's own top bar, or 「已选 N 条 / 取消」 while selecting.
class LoopSelectionAwareTopbar extends StatelessWidget {
  const LoopSelectionAwareTopbar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final selection = LoopMessageSelectionScope.maybeOf(context);
    if (selection == null || !selection.active) return child;
    return LoopTopbar(
      key: const ValueKey<String>('loop-selection-topbar'),
      title: '已选 ${selection.count} 条',
      subtitle: '最多 $loopMessageSelectionLimit 条',
      minHeight: 72,
      framedTools: true,
      dense: true,
      actions: <Widget>[
        // Decision 0087: a top bar carries glyphs, never words. 「取消」 is the
        // close glyph's own name.
        LoopIconButton(
          key: const ValueKey<String>('loop-selection-cancel'),
          icon: 'close',
          label: '取消',
          framed: true,
          onPressed: selection.cancel,
        ),
      ],
    );
  }
}

/// One message row, with its check box while the conversation is selecting.
///
/// While selecting, the row is one tap target: the bubble's own gestures —
/// long-press, links, the avatar — are suspended so a tap only ever ticks.
/// A row that cannot be ticked keeps the same gutter so the column does not
/// jump, and is drawn as it is.
class LoopSelectableMessage extends StatelessWidget {
  const LoopSelectableMessage({
    required this.message,
    required this.child,
    super.key,
  });

  final Message message;
  final Widget child;

  static const double gutter = 44;

  @override
  Widget build(BuildContext context) {
    final selection = LoopMessageSelectionScope.maybeOf(context);
    if (selection == null || !selection.active) return child;
    if (StreamMessageLayout.presentationOf(context) !=
        StreamMessagePresentation.standard) {
      return child;
    }
    if (!loopMessageSelectable(message)) {
      return Row(
        children: <Widget>[
          const SizedBox(width: gutter),
          Expanded(child: IgnorePointer(child: child)),
        ],
      );
    }
    final selected = selection.isSelected(message.id);
    return Semantics(
      checked: selected,
      button: true,
      label: selected ? '已选择这条消息' : '选择这条消息',
      child: GestureDetector(
        key: ValueKey<String>('loop-selectable-${message.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final change = selection.toggle(message);
          if (change == LoopMessageSelectionChange.refusedAtLimit) {
            LoopToast.show(
              context,
              message: '一次最多选择 $loopMessageSelectionLimit 条',
              kind: LoopToastKind.warn,
            );
          }
        },
        child: Row(
          children: <Widget>[
            SizedBox(
              width: gutter,
              child: Center(child: LoopSelectionCheck(selected: selected)),
            ),
            Expanded(child: IgnorePointer(child: child)),
          ],
        ),
      ),
    );
  }
}

/// The round check box at the start of a selectable row.
class LoopSelectionCheck extends StatelessWidget {
  const LoopSelectionCheck({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey<String>(
      selected ? 'loop-selection-check-on' : 'loop-selection-check-off',
    ),
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: selected ? LoopColors.lime : Colors.transparent,
      border: Border.all(
        color: selected ? LoopColors.lime : LoopColors.line2,
        width: 1.5,
      ),
    ),
    child: selected
        ? const Center(
            child: LoopIcon('check', size: 14, color: LoopColors.ink),
          )
        : null,
  );
}

/// 「转发」 and 「多选」 for one message's long-press sheet.
///
/// Stream's [MessageAction] is a sealed class, so LOOP's two actions carry
/// no value: each is a [StreamContextMenuAction] with an `onTap`. Inside the
/// sheet the action pops the route first (with `null`, which Stream's own
/// dispatcher ignores) and then runs `onTap` on the message row's context,
/// which outlives the sheet.
///
/// 「转发」 is offered only for a message that can travel — sent, text, no
/// picture — and 「多选」 only where a page installed a selection.
List<StreamContextMenuAction<MessageAction>> loopMessageForwardActions(
  BuildContext context,
  Message message,
) {
  if (message.isDeleted ||
      message.state.isDeleted ||
      message.state.isFailed ||
      message.state.isOutgoing ||
      loopIsMemberBuyMessage(message)) {
    return const <StreamContextMenuAction<MessageAction>>[];
  }
  final cid = StreamChannel.maybeOf(context)?.channel.cid;
  final selection = LoopMessageSelectionScope.read(context);
  return <StreamContextMenuAction<MessageAction>>[
    if (cid != null && chatForwardMessageIsForwardable(message))
      StreamContextMenuAction<MessageAction>(
        key: const ValueKey<String>('loop-message-action-forward'),
        label: const Text('转发'),
        leading: const LoopIcon('share', size: 20),
        onTap: () {
          if (!context.mounted) return;
          unawaited(
            showChatForwardTargetSheet(
              context,
              sourceCid: cid,
              messages: <ChatForwardMessage>[
                chatForwardMessageOf(
                  message,
                  realIdentity: chatForwardUsesRealIdentity(
                    loopFeatureSwitchesOf(context),
                    cid,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    if (selection != null)
      StreamContextMenuAction<MessageAction>(
        key: const ValueKey<String>('loop-message-action-select'),
        label: const Text('多选'),
        leading: const LoopIcon('check', size: 20),
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          selection.start(message);
        },
      ),
  ];
}

/// The bar that replaces the composer while a conversation is selecting.
///
/// 「逐条转发」 sends each ticked message on its own; 「合并转发」 opens the
/// merged-image preview with exactly the ticked messages; 「删除」 is offered
/// only when every ticked message is the reader's own and the channel lets
/// them delete their own messages.
class LoopMessageSelectionBar extends ConsumerStatefulWidget {
  const LoopMessageSelectionBar({required this.controller, super.key});

  final LoopMessageSelectionController controller;

  @override
  ConsumerState<LoopMessageSelectionBar> createState() =>
      _LoopMessageSelectionBarState();
}

class _LoopMessageSelectionBarState
    extends ConsumerState<LoopMessageSelectionBar> {
  bool _busy = false;

  LoopSelectedMessages _resolve(Channel channel) =>
      widget.controller.resolve(channel.state?.messages ?? const <Message>[]);

  List<ChatForwardMessage> _projected(Channel channel, List<Message> messages) {
    final realIdentity = chatForwardUsesRealIdentity(
      ref.read(loopFeatureSwitchesProvider),
      channel.cid ?? '',
    );
    return <ChatForwardMessage>[
      for (final message in messages)
        chatForwardMessageOf(message, realIdentity: realIdentity),
    ];
  }

  Future<void> _forwardEach(Channel channel) async {
    final cid = channel.cid;
    if (cid == null) return;
    final selection = _resolve(channel);
    final outcome = await showChatForwardTargetSheet(
      context,
      sourceCid: cid,
      messages: _projected(channel, selection.messages),
      unavailable: selection.unavailable,
    );
    if (outcome != null && outcome.sent > 0 && mounted) {
      widget.controller.cancel();
    }
  }

  void _merge(Channel channel) {
    final cid = channel.cid;
    if (cid == null) return;
    final selection = _resolve(channel);
    ref
        .read(chatForwardControllerProvider.notifier)
        .seedSelection(
          sourceCid: cid,
          sourceLabel: loopStoredConversationName(channel.extraData),
          messages: _projected(channel, selection.messages),
        );
    widget.controller.cancel();
    if (selection.unavailable > 0) {
      LoopToast.show(
        context,
        message: '${selection.unavailable} 条已删除或不在本机，没有放进长图',
        kind: LoopToastKind.warn,
      );
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      unawaited(router.push<void>(loopChatMergePreviewLocation));
      return;
    }
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (routeContext) => ChatMergePreviewScreen(
            onBack: () => Navigator.of(routeContext).maybePop(),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Channel channel) async {
    final count = widget.controller.count;
    final confirmed = await confirmCommunityAction(
      context,
      title: '删除这 $count 条消息？',
      body: '删除后会话里的每个人都会看到「消息已删除」，无法撤回。',
      confirmLabel: '删除',
      sheetKey: 'loop-selection-delete-confirm',
    );
    if (!confirmed || !mounted) return;
    // Read back after the confirmation: a message deleted while the sheet
    // was open is not deleted twice.
    final selection = _resolve(channel);
    setState(() => _busy = true);
    var failed = 0;
    for (final message in selection.messages) {
      try {
        await channel.deleteMessage(message);
      } catch (_) {
        failed += 1;
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    widget.controller.cancel();
    final deleted = selection.messages.length - failed;
    LoopToast.show(
      context,
      message: <String>[
        '已删除 $deleted 条',
        if (failed > 0) '$failed 条没有删除成功',
        if (selection.unavailable > 0) '${selection.unavailable} 条已不在本机，跳过',
      ].join('，'),
      kind: failed == 0 && selection.unavailable == 0
          ? LoopToastKind.ok
          : LoopToastKind.warn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final channel = StreamChannel.of(context).channel;
    final selected = _resolve(channel).messages;
    final userId = StreamChat.maybeOf(context)?.currentUser?.id;
    final anyForwardable = selected.any(chatForwardMessageIsForwardable);
    final allOwn =
        selected.isNotEmpty &&
        userId != null &&
        selected.every((message) => message.user?.id == userId);
    final mayDelete =
        allOwn && (channel.canDeleteOwnMessage || channel.canDeleteAnyMessage);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      key: const ValueKey<String>('loop-selection-bar'),
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
      decoration: const BoxDecoration(
        color: LoopColors.ink,
        border: Border(top: BorderSide(color: LoopColors.line)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: LoopButton(
              key: const ValueKey<String>('loop-selection-forward-each'),
              label: '逐条转发',
              block: true,
              onPressed: _busy || !anyForwardable
                  ? null
                  : () => unawaited(_forwardEach(channel)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LoopButton(
              key: const ValueKey<String>('loop-selection-merge'),
              label: '合并转发',
              primary: true,
              block: true,
              onPressed: _busy || !anyForwardable
                  ? null
                  : () => _merge(channel),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LoopButton(
              key: const ValueKey<String>('loop-selection-delete'),
              label: '删除',
              block: true,
              onPressed: _busy || !mayDelete
                  ? null
                  : () => unawaited(_delete(channel)),
            ),
          ),
        ],
      ),
    );
  }
}
