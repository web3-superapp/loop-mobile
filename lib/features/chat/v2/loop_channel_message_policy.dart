import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/chat/v2/conversation_social_scope.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// What LOOP lets the reader do to a message in one channel, on top of what
/// Stream's own capabilities allow.
///
/// Stream grants `pin-message` to every member of a LOOP community channel, so
/// Stream's long-press sheet offered 「置顶到会话」 to everyone (device report
/// 2026-09-28 · S99-3). Pinning is a community owner's or admin's act. The
/// client is the first gate — the server narrows the Stream grant too — and it
/// only ever takes actions away: a policy never adds one Stream did not offer.
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

/// Applies the nearest [LoopChannelMessagePolicy] to one message item.
///
/// With no policy in scope the props are returned untouched and Stream's own
/// capabilities decide. Every LOOP conversation sets one: a community group
/// (owner / admin), a friend group (its creator, S99c), a direct
/// conversation (nobody).
StreamMessageItemProps loopApplyChannelMessagePolicy(
  BuildContext context,
  StreamMessageItemProps props,
) {
  final policy = LoopChannelMessagePolicy.maybeOf(context);

  final inner = props.actionsBuilder;
  return props.copyWith(
    actionsBuilder: (context, defaults) {
      final allowed = policy != null && !policy.mayPin
          ? loopWithoutPinActions(defaults)
          : defaults;
      final items = inner != null
          ? inner(context, allowed)
          : StreamContextMenuAction.partitioned(items: allowed);
      final cid = StreamChannel.maybeOf(context)?.channel.cid;
      final router = GoRouter.maybeOf(context);
      final share = ConversationSocialScope.maybeOf(context)?.community;
      final message = props.message;
      if (router == null ||
          cid == null ||
          parseLoopStreamChannelCid(cid) == null ||
          message.isDeleted ||
          (message.text?.trim().isEmpty ?? true)) {
        return items;
      }
      return [
        ...items,
        ListTile(
          key: const ValueKey<String>('message-select-forward'),
          leading: const Icon(Icons.forward_to_inbox_outlined),
          title: const Text('转发 / 多选'),
          onTap: () {
            Navigator.of(context).pop();
            router.push(
              Uri(
                path: '/chat/forward',
                queryParameters: {'cid': cid, 'message': message.id},
              ).toString(),
              extra: share,
            );
          },
        ),
      ];
    },
  );
}
