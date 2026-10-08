import 'package:flutter/widgets.dart';
import 'package:loop_mobile/features/chat/v2/loop_message_selection.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// What LOOP lets the reader do to a message in one channel, on top of what
/// Stream's own capabilities allow.
///
/// Stream grants `pin-message` to every member of a LOOP community channel, so
/// Stream's long-press sheet offered 「置顶到会话」 to everyone (device report
/// 2026-09-28 · S99-3). Pinning is a community owner's or admin's act. The
/// client is the first gate — the server narrows the Stream grant too. The pin
/// rule only ever takes actions away; LOOP's own forward and multi-select are
/// added separately (S108, [loopApplyChannelMessagePolicy]).
class LoopChannelMessagePolicy extends InheritedWidget {
  const LoopChannelMessagePolicy({
    required this.mayPin,
    required super.child,
    super.key,
  });

  /// Whether pin and unpin stay in the message actions.
  final bool mayPin;

  static LoopChannelMessagePolicy? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LoopChannelMessagePolicy>();

  @override
  bool updateShouldNotify(LoopChannelMessagePolicy oldWidget) =>
      mayPin != oldWidget.mayPin;
}

/// Whether [action] pins or unpins a message.
bool loopIsPinAction(MessageAction action) =>
    action is PinMessage || action is UnpinMessage;

/// [actions] without pin and unpin.
List<StreamContextMenuAction<MessageAction>> loopWithoutPinActions(
  List<StreamContextMenuAction<MessageAction>> actions,
) => actions
    .where((action) {
      final value = action.props.value;
      return value == null || !loopIsPinAction(value);
    })
    .toList(growable: false);

/// Whether [action] is one of the moderation actions LOOP removes from every
/// long-press sheet: flag, mute / unmute and block / unblock (S108 §2.2).
///
/// Each has its own LOOP entry — reporting and blocking live on the person's
/// profile, muting on the conversation — so Stream's copies, which call the
/// provider directly and record nothing on LOOP's side, are taken away.
bool loopIsModerationAction(MessageAction action) =>
    action is FlagMessage ||
    action is MuteUser ||
    action is UnmuteUser ||
    action is BlockUser ||
    action is UnblockUser;

/// [actions] without the moderation actions.
List<StreamContextMenuAction<MessageAction>> loopWithoutModerationActions(
  List<StreamContextMenuAction<MessageAction>> actions,
) => actions
    .where((action) {
      final value = action.props.value;
      return value == null || !loopIsModerationAction(value);
    })
    .toList(growable: false);

/// Whether the reader [userId] created the friend group [channel] (S99c).
///
/// Since loop-api 0091 a friend group's creator is its Stream
/// `channel_moderator` and may pin; no other member may. The creator is read
/// from the channel Stream loaded — the server creates the channel as the
/// creator's Stream user, so `created_by` is that user. A channel with no
/// loaded state or no `created_by` is unknown, and unknown pins nothing.
bool loopFriendGroupCreatorMayPin(Channel channel, String userId) {
  if (channel.state == null) return false;
  final creator = channel.createdBy?.id;
  return creator != null && creator.isNotEmpty && creator == userId;
}

/// Applies LOOP's long-press sheet to one message item.
///
/// Stream's own actions stay — reply, copy, edit, delete, mark unread — minus
/// the moderation actions LOOP has its own entries for, and minus pin and
/// unpin when the nearest [LoopChannelMessagePolicy] says this reader may not
/// pin. With no policy in scope Stream's own capabilities decide pinning.
/// Every LOOP conversation sets one: a community group (owner / admin), a
/// friend group (its creator, S99c), a direct conversation (nobody).
///
/// LOOP then adds 「转发」 and 「多选」 (S108 §2.2) — the only actions a
/// policy adds; see [loopMessageForwardActions].
StreamMessageItemProps loopApplyChannelMessagePolicy(
  BuildContext context,
  StreamMessageItemProps props,
) {
  final policy = LoopChannelMessagePolicy.maybeOf(context);
  final mayPin = policy?.mayPin ?? true;
  final inner = props.actionsBuilder;
  final message = props.message;
  return props.copyWith(
    actionsBuilder: (context, defaults) {
      var allowed = loopWithoutModerationActions(defaults);
      if (!mayPin) allowed = loopWithoutPinActions(allowed);
      allowed = <StreamContextMenuAction<MessageAction>>[
        ...allowed,
        // Stream answers nothing for a deleted message, and LOOP adds
        // nothing to a sheet Stream left empty.
        if (defaults.isNotEmpty) ...loopMessageForwardActions(context, message),
      ];
      if (inner != null) return inner(context, allowed);
      return StreamContextMenuAction.partitioned(items: allowed);
    },
  );
}
