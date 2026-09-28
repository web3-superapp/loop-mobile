import 'package:flutter/widgets.dart';
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

/// Applies the nearest [LoopChannelMessagePolicy] to one message item.
///
/// With no policy in scope — a direct conversation, a friend group — the props
/// are returned untouched and Stream's own capabilities decide.
StreamMessageItemProps loopApplyChannelMessagePolicy(
  BuildContext context,
  StreamMessageItemProps props,
) {
  final policy = LoopChannelMessagePolicy.maybeOf(context);
  if (policy == null || policy.mayPin) return props;
  final inner = props.actionsBuilder;
  return props.copyWith(
    actionsBuilder: (context, defaults) {
      final allowed = loopWithoutPinActions(defaults);
      if (inner != null) return inner(context, allowed);
      return StreamContextMenuAction.partitioned(items: allowed);
    },
  );
}
