import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// What one conversation row in 聊天 can do besides opening (decision 0129,
/// S123 M2): the same four things behind a swipe and behind a long press.
enum ChatInboxRowAction {
  pin('置顶'),
  unpin('取消置顶'),
  mute('静音'),
  unmute('取消静音'),
  markRead('标为已读'),
  delete('删除');

  const ChatInboxRowAction(this.label);

  final String label;

  /// Whether the action is revealed by a swipe towards the start (the
  /// leading side). 标为已读 is the only one; the rest sit at the end.
  bool get leading => this == ChatInboxRowAction.markRead;

  bool get destructive => this == ChatInboxRowAction.delete;
}

/// The facts about one channel that decide which actions are drawn.
///
/// Every flag comes from Stream's own channel state for the reader: an action
/// Stream would refuse is not drawn at all rather than drawn and failing.
@immutable
final class ChatInboxRowFacts {
  const ChatInboxRowFacts({
    required this.pinned,
    required this.canPin,
    required this.muted,
    required this.canMute,
    required this.unread,
    required this.canMarkRead,
    required this.canDelete,
  });

  /// Reads the facts off a Stream channel. A channel whose state has not
  /// been read yet answers no actions.
  factory ChatInboxRowFacts.of(Channel channel) {
    if (channel.state == null) return none;
    final surface = channel.cid == null
        ? null
        : loopChatSurfaceForCid(channel.cid!);
    return ChatInboxRowFacts(
      pinned: channel.isPinned,
      // Pinning is a property of the reader's own membership.
      canPin: channel.membership != null,
      muted: channel.isMuted,
      canMute: channel.canMuteChannel,
      unread: channel.state!.unreadCount,
      canMarkRead: channel.canUseReadReceipts || channel.usesLocalUnreadCount,
      // 删除 hides a conversation from this reader's list. A community's
      // official channel is the community's, and leaves with the community;
      // it is not offered here.
      canDelete:
          surface == LoopChatSurface.direct || surface == LoopChatSurface.group,
    );
  }

  static const ChatInboxRowFacts none = ChatInboxRowFacts(
    pinned: false,
    canPin: false,
    muted: false,
    canMute: false,
    unread: 0,
    canMarkRead: false,
    canDelete: false,
  );

  final bool pinned;
  final bool canPin;
  final bool muted;
  final bool canMute;
  final int unread;
  final bool canMarkRead;
  final bool canDelete;
}

/// The actions one row offers, in the order they are drawn.
List<ChatInboxRowAction> chatInboxRowActions(ChatInboxRowFacts facts) =>
    <ChatInboxRowAction>[
      if (facts.canPin)
        facts.pinned ? ChatInboxRowAction.unpin : ChatInboxRowAction.pin,
      if (facts.canMute)
        facts.muted ? ChatInboxRowAction.unmute : ChatInboxRowAction.mute,
      if (facts.canMarkRead && facts.unread > 0) ChatInboxRowAction.markRead,
      if (facts.canDelete) ChatInboxRowAction.delete,
    ];

/// Runs one action through Stream's own channel API.
///
/// 删除 is Stream's `hide`: the conversation leaves this reader's list until
/// a new message arrives, and its history is kept.
Future<void> runChatInboxRowAction(
  Channel channel,
  ChatInboxRowAction action,
) async {
  switch (action) {
    case ChatInboxRowAction.pin:
      await channel.pin();
    case ChatInboxRowAction.unpin:
      await channel.unpin();
    case ChatInboxRowAction.mute:
      await channel.mute();
    case ChatInboxRowAction.unmute:
      await channel.unmute();
    case ChatInboxRowAction.markRead:
      await channel.markRead();
    case ChatInboxRowAction.delete:
      await channel.hide();
  }
}

/// The long-press menu of one row: the same actions the swipe reveals.
///
/// Returns the chosen action, or null when the sheet was dismissed.
Future<ChatInboxRowAction?> showChatInboxRowActionSheet(
  BuildContext context, {
  required String title,
  required List<ChatInboxRowAction> actions,
}) {
  unawaited(HapticFeedback.mediumImpact());
  return showLoopSheet<ChatInboxRowAction>(
    context,
    barrierLabel: '关闭会话操作',
    // The inbox is a tab root: the sheet goes over the floating tab bar.
    useRootNavigator: true,
    builder: (sheetContext) => Padding(
      key: const ValueKey<String>('chat-inbox-row-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LoopTypography.heading(16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          for (final action in actions) ...<Widget>[
            LoopButton(
              key: ValueKey<String>('chat-inbox-row-sheet-${action.name}'),
              label: action.label,
              block: true,
              onPressed: () => Navigator.of(sheetContext).pop(action),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 2),
          LoopButton(
            key: const ValueKey<String>('chat-inbox-row-sheet-cancel'),
            label: '取消',
            block: true,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}

/// Keeps at most one row of a list swiped open, and closes it when the list
/// scrolls.
class ChatInboxSwipeGroup extends ChangeNotifier {
  Object? _open;

  Object? get open => _open;

  void opened(Object row) {
    if (identical(_open, row)) return;
    _open = row;
    notifyListeners();
  }

  void closed(Object row) {
    if (!identical(_open, row)) return;
    _open = null;
    notifyListeners();
  }

  void closeAll() {
    if (_open == null) return;
    _open = null;
    notifyListeners();
  }
}

/// Supplies a [ChatInboxSwipeGroup] to the rows under it and closes the open
/// row as soon as the list is scrolled.
class ChatInboxSwipeScope extends StatefulWidget {
  const ChatInboxSwipeScope({required this.child, super.key});

  final Widget child;

  static ChatInboxSwipeGroup? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_ChatInboxSwipeInherited>()
      ?.group;

  @override
  State<ChatInboxSwipeScope> createState() => _ChatInboxSwipeScopeState();
}

class _ChatInboxSwipeScopeState extends State<ChatInboxSwipeScope> {
  final ChatInboxSwipeGroup _group = ChatInboxSwipeGroup();

  @override
  void dispose() {
    _group.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollStartNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) _group.closeAll();
        return false;
      },
      child: _ChatInboxSwipeInherited(group: _group, child: widget.child),
    );
  }
}

class _ChatInboxSwipeInherited extends InheritedWidget {
  const _ChatInboxSwipeInherited({required this.group, required super.child});

  final ChatInboxSwipeGroup group;

  @override
  bool updateShouldNotify(_ChatInboxSwipeInherited oldWidget) =>
      !identical(group, oldWidget.group);
}

/// One conversation row that a horizontal swipe slides aside to reveal its
/// actions (S123 M2).
///
/// Swiping towards the start reveals 置顶 / 静音 / 删除 at the end; swiping
/// towards the end reveals 标为已读. A row that is open does not open the
/// conversation when tapped — the tap closes it — so the swipe and the tap
/// never act on the same touch. A vertical drag is the list's: the swipe
/// starts only once the finger has moved sideways.
class ChatInboxSwipeRow extends StatefulWidget {
  const ChatInboxSwipeRow({
    required this.actions,
    required this.onAction,
    required this.child,
    super.key,
  });

  /// Every action the row offers; each is drawn on its own side. Read when a
  /// swipe starts, so the row always offers what the channel allows now.
  final List<ChatInboxRowAction> Function() actions;
  final ValueChanged<ChatInboxRowAction> onAction;
  final Widget child;

  /// The width of one revealed action.
  static const double actionWidth = 76;

  @override
  State<ChatInboxSwipeRow> createState() => _ChatInboxSwipeRowState();
}

class _ChatInboxSwipeRowState extends State<ChatInboxSwipeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  ChatInboxSwipeGroup? _group;
  bool _crossedThreshold = false;
  List<ChatInboxRowAction> _actions = const <ChatInboxRowAction>[];

  List<ChatInboxRowAction> get _leading =>
      _actions.where((action) => action.leading).toList();

  List<ChatInboxRowAction> get _trailing =>
      _actions.where((action) => !action.leading).toList();

  double get _leadingExtent => _leading.length * ChatInboxSwipeRow.actionWidth;

  double get _trailingExtent =>
      _trailing.length * ChatInboxSwipeRow.actionWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final group = ChatInboxSwipeScope.maybeOf(context);
    if (!identical(group, _group)) {
      _group?.removeListener(_onGroup);
      _group = group?..addListener(_onGroup);
    }
  }

  @override
  void dispose() {
    _group?.removeListener(_onGroup);
    _offset.dispose();
    super.dispose();
  }

  void _onGroup() {
    if (!identical(_group?.open, this) && _offset.value != 0) _settle(0);
  }

  void _onDragStart(DragStartDetails details) {
    _offset.stop();
    _crossedThreshold = false;
    if (_offset.value == 0) _actions = widget.actions();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    final next = (_offset.value + delta).clamp(
      -_trailingExtent,
      _leadingExtent,
    );
    _offset.value = next;
    final extent = next < 0 ? _trailingExtent : _leadingExtent;
    final crossed = extent > 0 && next.abs() >= extent / 2;
    if (crossed && !_crossedThreshold) {
      unawaited(HapticFeedback.selectionClick());
    }
    _crossedThreshold = crossed;
  }

  void _onDragEnd(DragEndDetails details) {
    final value = _offset.value;
    final velocity = details.primaryVelocity ?? 0;
    double target = 0;
    if (value < 0 && _trailingExtent > 0) {
      final fling = velocity < -400;
      final far = value.abs() >= _trailingExtent / 2;
      if ((fling || far) && velocity <= 400) target = -_trailingExtent;
    } else if (value > 0 && _leadingExtent > 0) {
      final fling = velocity > 400;
      final far = value >= _leadingExtent / 2;
      if ((fling || far) && velocity >= -400) target = _leadingExtent;
    }
    _settle(target);
  }

  void _settle(double target) {
    if (target == 0) {
      _group?.closed(this);
    } else {
      _group?.opened(this);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _offset.value = target;
      return;
    }
    unawaited(
      _offset.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _run(ChatInboxRowAction action) {
    _settle(0);
    widget.onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final ground = Theme.of(context).scaffoldBackgroundColor;
    return GestureDetector(
      key: const ValueKey<String>('chat-inbox-swipe-row'),
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _offset,
          builder: (context, child) {
            final value = _offset.value;
            return Stack(
              children: <Widget>[
                if (value > 0)
                  Positioned.fill(
                    child: Row(
                      children: <Widget>[
                        for (final action in _leading)
                          _ActionKey(action: action, onPressed: _run),
                        const Spacer(),
                      ],
                    ),
                  ),
                if (value < 0)
                  Positioned.fill(
                    child: Row(
                      children: <Widget>[
                        const Spacer(),
                        for (final action in _trailing)
                          _ActionKey(action: action, onPressed: _run),
                      ],
                    ),
                  ),
                Transform.translate(offset: Offset(value, 0), child: child),
              ],
            );
          },
          // The row's own ground covers the actions underneath; a Material,
          // so the row's press highlight still paints on it.
          child: Material(
            color: ground,
            child: _OpenRowGuard(
              offset: _offset,
              onClose: () => _settle(0),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// While the row is open, a tap on it closes it instead of reaching the row.
class _OpenRowGuard extends StatelessWidget {
  const _OpenRowGuard({
    required this.offset,
    required this.onClose,
    required this.child,
  });

  final Animation<double> offset;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: offset,
      child: child,
      builder: (context, child) {
        final open = offset.value != 0;
        return Stack(
          children: <Widget>[
            AbsorbPointer(absorbing: open, child: child),
            if (open)
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey<String>('chat-inbox-swipe-close'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({required this.action, required this.onPressed});

  final ChatInboxRowAction action;
  final ValueChanged<ChatInboxRowAction> onPressed;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (action) {
      ChatInboxRowAction.pin ||
      ChatInboxRowAction.unpin => (LoopColors.graphite, LoopColors.chalk),
      ChatInboxRowAction.mute ||
      ChatInboxRowAction.unmute => (LoopColors.muted, LoopColors.ink),
      ChatInboxRowAction.markRead => (LoopColors.lime, LoopColors.ink),
      ChatInboxRowAction.delete => (LoopColors.fall, LoopColors.chalk),
    };
    return SizedBox(
      width: ChatInboxSwipeRow.actionWidth,
      child: Semantics(
        button: true,
        label: action.label,
        excludeSemantics: true,
        child: Material(
          color: background,
          child: InkWell(
            key: ValueKey<String>('chat-inbox-swipe-${action.name}'),
            onTap: () => onPressed(action),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: LoopTypography.label(
                    12,
                    weight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
