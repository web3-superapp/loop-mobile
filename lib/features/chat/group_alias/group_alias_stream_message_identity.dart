import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Neutral sender label used when the current Stream member projection cannot
/// prove a valid group-scoped Alias.
const String loopGroupMemberNeutralLabel = '群成员';

/// Neutral group label used when Stream does not carry a reviewed group name.
const String loopGroupConversationNeutralLabel = '群聊';

const String _aliasIdField = 'loop_group_alias_id';
const String _aliasField = 'loop_group_alias';
const String _aliasVersionField = 'loop_group_alias_version';
const Set<String> _aliasProjectionFields = <String>{
  _aliasIdField,
  _aliasField,
  _aliasVersionField,
};

/// Reads the immutable v1 Alias projection from one Stream [Member].
///
/// Unrelated member custom fields are allowed, but the LOOP group-Alias
/// namespace must contain exactly the reviewed id, Alias, and integer version
/// fields. Malformed or future projections fail closed.
@visibleForTesting
String? parseLoopGroupAliasMemberProjection(Map<String, Object?> extraData) {
  final projectionFields = extraData.keys
      .where((key) => key.startsWith('loop_group_alias'))
      .toSet();
  if (!setEquals(projectionFields, _aliasProjectionFields)) return null;

  final version = extraData[_aliasVersionField];
  final rawId = extraData[_aliasIdField];
  final rawAlias = extraData[_aliasField];
  if (version is! int ||
      version != 1 ||
      rawId is! String ||
      rawAlias is! String) {
    return null;
  }

  try {
    GroupAliasId.fromWire(rawId);
    final normalized = normalizeGroupAlias(rawAlias);
    if (normalized != rawAlias) return null;
    return normalized;
  } on InvalidGroupAliasContractException {
    return null;
  }
}

/// Resolves a message sender label only from the matching current-channel
/// [Member] projection.
///
/// The Stream [User.name] and [User.id] are deliberately not fallbacks. A
/// missing, duplicate, conflicting, malformed, or future projection resolves
/// to [loopGroupMemberNeutralLabel].
@visibleForTesting
String resolveLoopGroupMessageSenderLabel({
  required String senderUserId,
  required Iterable<Member> members,
}) {
  if (senderUserId.isEmpty || senderUserId != senderUserId.trim()) {
    return loopGroupMemberNeutralLabel;
  }

  Member? matchingMember;
  for (final member in members) {
    final matchesTopLevel = member.userId == senderUserId;
    final matchesNested = member.user?.id == senderUserId;
    if (!matchesTopLevel && !matchesNested) continue;
    if (!matchesTopLevel || !matchesNested || matchingMember != null) {
      return loopGroupMemberNeutralLabel;
    }
    matchingMember = member;
  }

  if (matchingMember == null) return loopGroupMemberNeutralLabel;
  return parseLoopGroupAliasMemberProjection(matchingMember.extraData) ??
      loopGroupMemberNeutralLabel;
}

/// Whether a validated messaging CID uses group-scoped message identities.
///
/// Known LOOP direct channels keep Stream's ordinary identity presentation.
/// Other valid messaging channels may carry the backend's group projection,
/// including legacy groups whose ids predate the `loop_group_` prefix.
bool loopStreamChannelUsesGroupMessageAlias(String? cid) {
  if (cid == null) return false;
  final address = parseLoopStreamChannelCid(cid);
  return address != null && !address.id.startsWith('loop_direct_');
}

/// Root Stream component builder for a group message item.
///
/// The official [DefaultStreamMessageItem] continues to own layout, state,
/// actions, replies, and thread behavior. This wrapper only observes the
/// official current-channel member projection and supplies a display-only
/// message copy whose visible user projections use the group Alias boundary.
Widget loopStreamGroupMessageItemBuilder(
  BuildContext context,
  StreamMessageItemProps props,
) => _LoopStreamGroupMessageItem(props: props);

/// Root Stream component builder for mention autocomplete rows.
///
/// Stream's autocomplete callback closes over the global [User], so replacing
/// only the rendered name would still insert that global name into the
/// composer. User mentions therefore fail closed in group channels until an
/// Alias-aware composer contract exists. Non-user mentions and direct-channel
/// mentions retain the official implementation.
Widget loopStreamGroupMentionItemBuilder(
  BuildContext context,
  StreamMentionItemProps props,
) {
  final channel = StreamChannel.maybeOf(context)?.channel;
  final isGroup = loopStreamChannelUsesGroupMessageAlias(channel?.cid);
  if (isGroup && props.mention is StreamUserMention) {
    return const SizedBox.shrink();
  }
  return DefaultStreamMentionItem(props: props);
}

/// Uses a reviewed group name without falling back to Stream member names.
@visibleForTesting
String resolveLoopGroupConversationLabel(Map<String, Object?> extraData) {
  final rawName = extraData['name'];
  if (rawName is! String) return loopGroupConversationNeutralLabel;
  try {
    final normalized = normalizeFriendGroupName(rawName);
    return normalized == rawName
        ? normalized
        : loopGroupConversationNeutralLabel;
  } on InvalidFriendContractException {
    return loopGroupConversationNeutralLabel;
  }
}

/// Replaces only group cells in an official [StreamChannelListView].
///
/// The caller-provided [defaultItem] is returned unchanged for known direct
/// channels. Group cells retain official tap/long-press, unread, mute, pin,
/// timestamp, and live channel state while removing typing/global avatars and
/// sanitizing the last-message preview.
Widget loopStreamChannelListIdentityItem(StreamChannelListItem defaultItem) {
  if (!loopStreamChannelUsesGroupMessageAlias(defaultItem.props.channel.cid)) {
    return defaultItem;
  }
  return _LoopStreamGroupChannelListItem(props: defaultItem.props);
}

class _LoopStreamGroupChannelListItem extends StatelessWidget {
  const _LoopStreamGroupChannelListItem({required this.props});

  final StreamChannelListItemProps props;

  @override
  Widget build(BuildContext context) {
    final channel = props.channel;
    final state = channel.state!;
    return StreamBuilder<ChannelState>(
      initialData: state.channelState,
      stream: state.channelStateStream,
      builder: (context, snapshot) {
        final channelState = snapshot.data ?? state.channelState;
        final members = List<Member>.unmodifiable(
          channelState.members ?? const <Member>[],
        );
        final messages = channelState.messages ?? const <Message>[];
        final lastMessage = messages.isEmpty ? null : messages.last;
        final displayMessage = lastMessage == null
            ? null
            : sanitizeLoopGroupMessageForDisplay(
                message: lastMessage,
                members: members,
              );
        final label = resolveLoopGroupConversationLabel(
          channelState.channel?.extraData ?? channel.extraData,
        );

        return StreamBuilder<bool>(
          initialData: channel.isMuted,
          stream: channel.isMutedStream,
          builder: (context, mutedSnapshot) => StreamBuilder<bool>(
            initialData: channel.isPinned,
            stream: channel.isPinnedStream,
            builder: (context, pinnedSnapshot) => StreamChannelListTile(
              avatar: const CircleAvatar(
                key: ValueKey<String>('loop-group-channel-neutral-avatar'),
                child: Icon(Icons.group_rounded),
              ),
              title: Text(label),
              subtitle: displayMessage == null
                  ? Text(context.translations.emptyMessagesText)
                  : StreamMessagePreviewText(
                      message: displayMessage,
                      channel: channelState.channel,
                    ),
              timestamp: ChannelLastMessageDate(channel: channel),
              unreadCount: state.unreadCount,
              isMuted: mutedSnapshot.data ?? channel.isMuted,
              isPinned: pinnedSnapshot.data ?? channel.isPinned,
              onTap: props.onTap,
              onLongPress: props.onLongPress,
              selected: props.selected,
            ),
          ),
        );
      },
    );
  }
}

/// Official Stream channel surface with group-safe chrome.
///
/// Message list/composer pagination, state, actions, and thread navigation are
/// still owned by Stream. Only the stock name-bearing header/avatar and typing
/// projections are replaced for group channels.
class LoopStreamGroupChannelHeader extends StatelessWidget
    implements PreferredSizeWidget {
  const LoopStreamGroupChannelHeader({this.onChannelAvatarPressed, super.key});

  final void Function(BuildContext context, Channel channel)?
  onChannelAvatarPressed;

  @override
  Size get preferredSize => const Size.fromHeight(kStreamToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final channel = StreamChannel.of(context).channel;
    return StreamChannelHeader(
      title: _LoopGroupChannelTitle(channel: channel),
      subtitle: _LoopGroupChannelSubtitle(channel: channel),
      trailing: IconButton(
        key: const ValueKey<String>('loop-group-channel-neutral-avatar'),
        tooltip: loopGroupConversationNeutralLabel,
        onPressed: onChannelAvatarPressed == null
            ? null
            : () => onChannelAvatarPressed!(context, channel),
        icon: const Icon(Icons.group_rounded),
      ),
    );
  }
}

class LoopStreamGroupChannelPage extends StatefulWidget {
  const LoopStreamGroupChannelPage({this.onChannelAvatarPressed, super.key});

  final void Function(BuildContext context, Channel channel)?
  onChannelAvatarPressed;

  @override
  State<LoopStreamGroupChannelPage> createState() =>
      _LoopStreamGroupChannelPageState();
}

class _LoopStreamGroupChannelPageState
    extends State<LoopStreamGroupChannelPage> {
  late final FocusNode _focusNode = FocusNode();
  late final StreamMessageComposerController _composerController =
      StreamMessageComposerController();

  @override
  void dispose() {
    _focusNode.dispose();
    _composerController.dispose();
    super.dispose();
  }

  void _reply(Message message) {
    _composerController.quotedMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _edit(Message message) {
    _composerController.editMessage(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final header = LoopStreamGroupChannelHeader(
      onChannelAvatarPressed: widget.onChannelAvatarPressed,
    );
    final composer = StreamMessageComposer(
      focusNode: _focusNode,
      messageComposerController: _composerController,
      onQuotedMessageCleared: _composerController.clearQuotedMessage,
      enableVoiceRecording: false,
    );

    return StreamScaffold(
      appBar: header,
      bottom: composer,
      appBarSurfaceStyle: StreamChannelHeader.resolveSurfaceStyle(context),
      bottomSurfaceStyle: StreamMessageComposer.resolveSurfaceStyle(context),
      body: StreamMessageListView(
        onEditMessageTap: _edit,
        onReplyTap: _reply,
        threadBuilder: (_, parentMessage) =>
            _LoopStreamGroupThreadPage(parent: parentMessage!),
        enableSafeArea: true,
      ),
    );
  }
}

class _LoopGroupChannelTitle extends StatelessWidget {
  const _LoopGroupChannelTitle({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) => StreamBuilder<ChannelState>(
    initialData: channel.state!.channelState,
    stream: channel.state!.channelStateStream,
    builder: (context, snapshot) => Text(
      resolveLoopGroupConversationLabel(
        snapshot.data?.channel?.extraData ?? channel.extraData,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _LoopGroupChannelSubtitle extends StatelessWidget {
  const _LoopGroupChannelSubtitle({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) => StreamBuilder<ChannelState>(
    initialData: channel.state!.channelState,
    stream: channel.state!.channelStateStream,
    builder: (context, snapshot) {
      final state = snapshot.data ?? channel.state!.channelState;
      final count = state.channel?.memberCount ?? state.members?.length;
      return Text(count == null ? '群聊' : '$count 位成员');
    },
  );
}

class _LoopStreamGroupThreadPage extends StatefulWidget {
  const _LoopStreamGroupThreadPage({required this.parent});

  final Message parent;

  @override
  State<_LoopStreamGroupThreadPage> createState() =>
      _LoopStreamGroupThreadPageState();
}

class _LoopStreamGroupThreadPageState
    extends State<_LoopStreamGroupThreadPage> {
  late final FocusNode _focusNode = FocusNode();
  late final StreamMessageComposerController _composerController =
      StreamMessageComposerController(
        message: Message(parentId: widget.parent.id),
      );

  @override
  void dispose() {
    _focusNode.dispose();
    _composerController.dispose();
    super.dispose();
  }

  void _reply(Message message) {
    _composerController.quotedMessage = message;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _edit(Message message) {
    _composerController.editMessage(message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final replyCount = widget.parent.replyCount;
    final subtitle = replyCount == null || replyCount == 0
        ? const SizedBox.shrink()
        : Text('$replyCount 条回复');
    final composer = widget.parent.isDeleted
        ? null
        : StreamMessageComposer(
            focusNode: _focusNode,
            messageComposerController: _composerController,
            enableVoiceRecording: false,
          );
    return StreamScaffold(
      appBar: StreamThreadHeader(parent: widget.parent, subtitle: subtitle),
      bottom: composer,
      appBarSurfaceStyle: StreamThreadHeader.resolveSurfaceStyle(context),
      bottomSurfaceStyle: StreamMessageComposer.resolveSurfaceStyle(context),
      body: StreamMessageListView(
        parentMessage: widget.parent,
        onReplyTap: _reply,
        onEditMessageTap: _edit,
        enableSafeArea: true,
      ),
    );
  }
}

/// Produces the immutable display copy consumed by official Stream message UI.
///
/// Every [User] reachable by the default message widgets is replaced with a
/// minimal projection containing only the stable internal id (needed by
/// Stream interactions) and the channel Alias/neutral label. Global names,
/// images, and custom user data never enter the group presentation tree.
@visibleForTesting
Message sanitizeLoopGroupMessageForDisplay({
  required Message message,
  required Iterable<Member> members,
}) => _sanitizeMessage(message, List<Member>.unmodifiable(members), depth: 0);

Message _sanitizeMessage(
  Message message,
  List<Member> members, {
  required int depth,
}) {
  User displayUser(User user) => _groupDisplayUser(user, members);

  final originalMentionedUsers = message.mentionedUsers;
  var displayText = message.text;
  for (final user in originalMentionedUsers) {
    final label = resolveLoopGroupMessageSenderLabel(
      senderUserId: user.id,
      members: members,
    );
    displayText = _replaceMentionLiteral(displayText, user.id, label);
    if (user.name != user.id) {
      displayText = _replaceMentionLiteral(displayText, user.name, label);
    }
  }

  // Inline quote UI renders a single quoted card. Bound malformed recursive
  // payloads and remove a deeper quote rather than allowing an unsanitized
  // user projection into the presentation tree.
  final quotedMessage = message.quotedMessage;
  final displayQuotedMessage = quotedMessage == null || depth >= 3
      ? null
      : _sanitizeMessage(quotedMessage, members, depth: depth + 1);

  return message.copyWith(
    text: displayText,
    user: message.user == null ? null : displayUser(message.user!),
    mentionedUsers: originalMentionedUsers
        .map(displayUser)
        .toList(growable: false),
    latestReactions: message.latestReactions
        ?.map((reaction) => _sanitizeReaction(reaction, displayUser))
        .toList(growable: false),
    ownReactions: message.ownReactions
        ?.map((reaction) => _sanitizeReaction(reaction, displayUser))
        .toList(growable: false),
    quotedMessage: displayQuotedMessage,
    threadParticipants: message.threadParticipants
        ?.map(displayUser)
        .toList(growable: false),
    pinnedBy: message.pinnedBy == null ? null : displayUser(message.pinnedBy!),
  );
}

String? _replaceMentionLiteral(String? text, String literal, String label) {
  if (text == null || text.isEmpty || literal.isEmpty) return text;
  return text.replaceAll('@$literal', '@$label');
}

Reaction _sanitizeReaction(Reaction reaction, User Function(User) displayUser) {
  final user = reaction.user;
  return user == null ? reaction : reaction.copyWith(user: displayUser(user));
}

User _groupDisplayUser(User user, List<Member> members) {
  final label = resolveLoopGroupMessageSenderLabel(
    senderUserId: user.id,
    members: members,
  );
  return User(id: user.id, name: label);
}

StreamMessageItemProps _groupDisplayProps(
  StreamMessageItemProps props,
  List<Member> members,
) {
  final displayMessage = sanitizeLoopGroupMessageForDisplay(
    message: props.message,
    members: members,
  );
  return StreamMessageItemProps(
    message: displayMessage,
    padding: props.padding,
    spacing: props.spacing,
    backgroundColor: props.backgroundColor,
    maxWidth: props.maxWidth,
    swipeToReply: props.swipeToReply,
    onMessageTap: props.onMessageTap,
    onMessageLongPress: props.onMessageLongPress,
    // Global avatar/profile and mention callbacks cannot express a
    // group-scoped identity, so these identity-bearing entry points stay off.
    onUserAvatarTap: null,
    onMessageLinkTap: props.onMessageLinkTap,
    onMentionTap: null,
    onThreadTap: props.onThreadTap,
    onViewInChannelTap: props.onViewInChannelTap,
    onReplyTap: props.onReplyTap,
    // The official reaction detail sheet hydrates global users independently
    // of this display copy. Keep reactions/actions, but suppress that sheet.
    onReactionTap: (_, _) {},
    onQuotedMessageTap: props.onQuotedMessageTap,
    reactionSorting: props.reactionSorting,
    actionsBuilder: props.actionsBuilder,
    onMessageActions: props.onMessageActions,
    onBouncedErrorMessageActions: props.onBouncedErrorMessageActions,
    onEditMessageTap: props.onEditMessageTap,
    attachmentBuilders: props.attachmentBuilders,
  );
}

class _LoopStreamGroupMessageItem extends StatelessWidget {
  const _LoopStreamGroupMessageItem({required this.props});

  final StreamMessageItemProps props;

  @override
  Widget build(BuildContext context) {
    final channel = StreamChannel.maybeOf(context)?.channel;
    if (!loopStreamChannelUsesGroupMessageAlias(channel?.cid)) {
      return DefaultStreamMessageItem(props: props);
    }

    final state = channel?.state;
    if (state == null) {
      return _buildDefault(const <Member>[]);
    }

    final initialMembers = List<Member>.unmodifiable(
      state.channelState.members ?? const <Member>[],
    );
    final membersStream = state.channelStateStream
        .map(
          (channelState) => List<Member>.unmodifiable(
            channelState.members ?? const <Member>[],
          ),
        )
        .distinct(listEquals);

    return StreamBuilder<List<Member>>(
      initialData: initialMembers,
      stream: membersStream,
      builder: (context, snapshot) {
        final members = snapshot.hasError
            ? const <Member>[]
            : snapshot.data ?? const <Member>[];
        return _buildDefault(members);
      },
    );
  }

  Widget _buildDefault(List<Member> members) {
    return DefaultStreamMessageItem(props: _groupDisplayProps(props, members));
  }
}
