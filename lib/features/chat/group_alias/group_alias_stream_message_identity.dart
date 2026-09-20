import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_identity_scope.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_policy.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_display_identity.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Neutral sender label used when the current Stream member projection cannot
/// prove a valid group-scoped Alias.
///
/// Decision 0055 (`frontend-v2-communication-api.md` §4) fixes this word: a
/// member whose projection has not landed reads as 「成员」, and never as an
/// account-level name or a Stream id.
const String loopGroupMemberNeutralLabel = '成员';

/// Neutral group label used when Stream does not carry a reviewed group name.
const String loopGroupConversationNeutralLabel = '群聊';

/// Neutral label for a direct conversation LOOP has no name for.
///
/// The inbox reads its rows from Stream alone, and Stream carries no name for
/// a LOOP account: `User.name` is empty, so `StreamChannelName` derived a 1:1
/// row's title from the peer's Stream id and drew `loop_7e25…` at the top of
/// the most-read list in the app (device report 2026-09-20 · R14-1).
///
/// The peer's honest name — `alias ?? loopId` from their public profile — now
/// has a source: `GET /v2/chat/direct-channels` (decision 0056) indexes this
/// account's own direct channels by CID, and the inbox publishes it through
/// [LoopDirectChannelDirectoryScope]. This label is what remains when that
/// read has not landed, or answered `503`: the row says only what it knows —
/// this is a direct conversation. It never says `loop_`.
const String loopDirectConversationNeutralLabel = '私聊';

/// The one character the neutral direct avatar may draw.
///
/// It comes from [loopDirectConversationNeutralLabel], not from a Stream id:
/// the initial Stream's own avatar drew was `L`, the first letter of
/// `loop_…` (device report 2026-09-20 · R14-5).
const String loopDirectConversationNeutralInitial = '私';

/// What a direct row reads when the peer has no presentable public profile.
///
/// `peer: null` is a contract value, not a missing read: that account is
/// deactivated or was never activated. Saying so is honest, and it is
/// different from saying nothing (decision 0056).
const String loopDirectDeactivatedPeerLabel = '已注销用户';

/// The one character the deactivated-peer avatar may draw.
const String loopDirectDeactivatedPeerInitial = '注';

/// How one direct inbox row names itself.
///
/// [peer] is non-null only when LOOP holds that person's public profile, so
/// it is also the test for whether this row may open a conversation that
/// already knows who it is with.
@immutable
final class LoopDirectRowIdentity {
  const LoopDirectRowIdentity({
    required this.title,
    required this.initial,
    required this.peer,
  });

  /// `alias ?? loopId`, 「已注销用户」 or 「私聊」. Never a Stream value.
  final String title;

  /// The single character the row's avatar draws. Same source as [title].
  final String initial;

  final LoopPublicProfile? peer;
}

/// The first character of a resolved title, for the row's avatar.
///
/// It is taken as a grapheme cluster so an emoji or a combining mark is not
/// split in half, and it is never derived from an id.
@visibleForTesting
String loopDirectRowInitial(String title) {
  final trimmed = title.trim();
  if (trimmed.isEmpty) return loopDirectConversationNeutralInitial;
  return trimmed.characters.first.toUpperCase();
}

/// Names one direct row from LOOP's own index, or not at all.
///
/// Three answers, and they stay distinct: a known peer is named; a known
/// account with no public profile reads as 「已注销用户」; and a CID the index
/// does not carry — the read has not landed, or the module answered `503` —
/// keeps the neutral label. Stream is never consulted for any of them.
LoopDirectRowIdentity resolveLoopDirectRowIdentity({
  required String? cid,
  required LoopDirectChannelDirectory? directory,
}) {
  if (directory == null || !directory.knows(cid)) {
    return const LoopDirectRowIdentity(
      title: loopDirectConversationNeutralLabel,
      initial: loopDirectConversationNeutralInitial,
      peer: null,
    );
  }
  final peer = directory.peerOf(cid);
  if (peer == null) {
    return const LoopDirectRowIdentity(
      title: loopDirectDeactivatedPeerLabel,
      initial: loopDirectDeactivatedPeerInitial,
      peer: null,
    );
  }
  final title = peer.displayName;
  return LoopDirectRowIdentity(
    title: title,
    initial: loopDirectRowInitial(title),
    peer: peer,
  );
}

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
///
/// This is the one place a member is named in a group channel: the bubble, the
/// long-press header, the reply banner and the `@` candidate row all come back
/// here, so a member reads as the same person everywhere in the channel.
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
/// Non-user mentions — channel, here, role, user group — carry no account
/// identity and keep the official implementation untouched. A *user* mention
/// is the one row that has to name a person, and neither name Stream can offer
/// is usable: `User.name` is empty for every LOOP account and `User.id` is the
/// LOOP row key (device report 2026-09-19 · F5).
///
/// * A group or community channel no longer reaches here at all: its composer
///   turns Stream's overlay off and installs
///   [loopGroupMentionAutocompleteTrigger], which resolves, filters and
///   completes candidates by the channel Alias. This branch stays as the
///   closed door behind that decision — Stream's own callback closes over the
///   global [User] and accepts `user.name` into the composer
///   (`stream_message_composer.dart:976`), so any stock overlay that did mount
///   in a group channel would type the id into the message.
/// * In a direct channel the peer does have an honest name — the public
///   profile the page's own header shows — published through
///   [LoopDirectPeerScope]. The row renders it, and the tap accepts *that*
///   text, so what lands in the message is the same word the reader saw.
///   Without a published identity, or for any candidate that is not the peer,
///   the row fails closed the same way a group row does.
Widget loopStreamGroupMentionItemBuilder(
  BuildContext context,
  StreamMentionItemProps props,
) {
  final mention = props.mention;
  if (mention is! StreamUserMention) {
    return DefaultStreamMentionItem(props: props);
  }
  final channel = StreamChannel.maybeOf(context)?.channel;
  if (loopStreamChannelUsesGroupMessageAlias(channel?.cid)) {
    return const SizedBox.shrink();
  }
  final peer = LoopDirectPeerScope.maybeOf(context);
  final currentUserId = StreamChat.of(context).currentUser?.id;
  if (peer == null || mention.user.id == currentUserId) {
    return const SizedBox.shrink();
  }
  // Stream's own tap accepts `user.name` — the id — into the composer, so it
  // is replaced rather than reused. The ancestor is looked up here, while the
  // row is built, because a row LOOP cannot complete is not offered as one
  // that can be: no autocomplete above it means no tap.
  final autocomplete = context
      .findAncestorStateOfType<State<StreamAutocomplete>>();
  return DefaultStreamMentionItem(
    props: StreamMentionItemProps(
      mention: StreamUserMention(
        user: loopStreamDisplayUser(id: mention.user.id, label: peer),
      ),
      onTap: autocomplete == null
          ? null
          : () => StreamAutocomplete.of(context).acceptAutocompleteOption(peer),
    ),
  );
}

/// Keeps a group `@` linked to the member it names when the message leaves.
///
/// `Message.toJson` runs `removeMentionsIfNotIncluded()` before anything is
/// serialized, and that filter keeps a mention only when the body spells
/// `@<user.id>` or `@<user.name>` as a standalone word
/// (`stream_chat-10.3.0/lib/src/core/models/message.dart:905`). LOOP types the
/// channel Alias, and a LOOP account carries no Stream name — the getter
/// answers the id — so neither token matched and the whole mention was
/// dropped on the way out: the device's own `@Harbor-7001` came back from the
/// server with `mentioned_users: []` (device report 2026-09-20 · R14-2). The
/// `@` was text, and text alone raises no unread, no push and no highlight.
///
/// So the mentioned user is named *locally* with the Alias this channel
/// resolved, which is exactly the word the member typed, and Stream's own
/// filter then finds it. The body is left alone: writing the id into the text
/// would have linked the mention too, but that id would then be the stored
/// message — read back by chat search, by forwarding, and by every surface
/// that has no member roster to translate it with.
///
/// Nothing about this projection is sent: `mentioned_users` serializes as a
/// list of ids (`User.toIds`, `message.g.dart:89`), so the Alias stays on the
/// device and the server learns only who was mentioned.
@visibleForTesting
Message prepareLoopGroupMentionsForSend({
  required Message message,
  required Iterable<Member> members,
}) {
  final mentioned = message.mentionedUsers;
  if (mentioned.isEmpty) return message;

  final roster = List<Member>.unmodifiable(members);
  var changed = false;
  final named = <User>[];
  for (final user in mentioned) {
    final alias = resolveLoopGroupMessageSenderLabel(
      senderUserId: user.id,
      members: roster,
    );
    // A member this channel cannot name is left exactly as Stream had them:
    // the mention then stands or falls on Stream's own tokens, and LOOP has
    // invented nothing.
    if (alias == loopGroupMemberNeutralLabel || user.name == alias) {
      named.add(user);
      continue;
    }
    changed = true;
    named.add(User(id: user.id, name: alias));
  }
  if (!changed) return message;
  return message.copyWith(mentionedUsers: named);
}

/// The pre-send step a LOOP composer installs for the channel it is in.
///
/// A direct channel has no Alias namespace and keeps Stream's own behavior.
Message loopPrepareChannelMessageForSend({
  required Message message,
  required Channel channel,
}) {
  if (!loopStreamChannelUsesGroupMessageAlias(channel.cid)) return message;
  return prepareLoopGroupMentionsForSend(
    message: message,
    members: channel.state?.channelState.members ?? const <Member>[],
  );
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

/// The timestamp on one inbox row, in LOOP's Chinese 24-hour ladder.
///
/// `ChannelLastMessageDate` falls back to Stream's `formatDate`, whose today
/// bucket is Jiffy's 12-hour `jm` and whose weekday and numeric date bypass
/// the localizations entirely. Every LOOP row passes this formatter instead.
Widget loopStreamChannelListTimestamp(Channel channel) =>
    ChannelLastMessageDate(
      channel: channel,
      formatter: (context, date) => loopStreamChannelListDateLabel(date),
    );

/// Replaces every cell in an official [StreamChannelListView].
///
/// Both branches keep official tap/long-press, unread, mute, pin and live
/// channel state, and both carry LOOP's timestamp formatter. Neither branch
/// lets a Stream identity projection name the row: a group cell reads the
/// reviewed group name, a direct cell reads LOOP's neutral direct label, and
/// both draw a LOOP avatar instead of Stream's.
Widget loopStreamChannelListIdentityItem(StreamChannelListItem defaultItem) {
  if (!loopStreamChannelUsesGroupMessageAlias(defaultItem.props.channel.cid)) {
    return _LoopStreamDirectChannelListItem(props: defaultItem.props);
  }
  return _LoopStreamGroupChannelListItem(props: defaultItem.props);
}

/// One direct cell in the inbox.
///
/// Stream's own `StreamChannelName` / `StreamChannelAvatar` used to render
/// here. For a 1:1 channel without a stored name both of them derive the row
/// from the *other member's* `User.name`, whose getter answers `User.id` when
/// the account has no name — every LOOP account — so the row's title was the
/// peer's Stream id and its initials were `L` (device report 2026-09-20 ·
/// R14-1 / R14-5). The name this cell draws comes from LOOP's own index of
/// its direct channels instead ([resolveLoopDirectRowIdentity]); a CID that
/// index does not carry keeps the neutral label rather than borrowing one
/// from the provider.
///
/// Everything that is not a name stays Stream's: the live muted/pinned/unread
/// state, the last-message preview widget, tap and long-press.
class _LoopStreamDirectChannelListItem extends StatelessWidget {
  const _LoopStreamDirectChannelListItem({required this.props});

  final StreamChannelListItemProps props;

  @override
  Widget build(BuildContext context) {
    final channel = props.channel;
    final state = channel.state!;
    final identity = resolveLoopDirectRowIdentity(
      cid: channel.cid,
      directory: LoopDirectChannelDirectoryScope.maybeOf(context),
    );
    return StreamBuilder<ChannelState>(
      initialData: state.channelState,
      stream: state.channelStateStream,
      builder: (context, snapshot) {
        final channelState = snapshot.data ?? state.channelState;
        final messages = channelState.messages ?? const <Message>[];
        final lastMessage = messages.isEmpty ? null : messages.last;
        return StreamBuilder<bool>(
          initialData: channel.isMuted,
          stream: channel.isMutedStream,
          builder: (context, mutedSnapshot) => StreamBuilder<bool>(
            initialData: channel.isPinned,
            stream: channel.isPinnedStream,
            builder: (context, pinnedSnapshot) => StreamBuilder<int>(
              initialData: state.unreadCount,
              stream: state.unreadCountStream,
              builder: (context, unreadSnapshot) => StreamChannelListTile(
                avatar: CircleAvatar(
                  key: const ValueKey<String>('loop-direct-channel-avatar'),
                  child: Text(identity.initial),
                ),
                title: Text(identity.title),
                subtitle: lastMessage == null
                    ? Text(context.translations.emptyMessagesText)
                    : StreamMessagePreviewText(message: lastMessage),
                timestamp: loopStreamChannelListTimestamp(channel),
                unreadCount: unreadSnapshot.data ?? state.unreadCount,
                isMuted: mutedSnapshot.data ?? channel.isMuted,
                isPinned: pinnedSnapshot.data ?? channel.isPinned,
                onTap: props.onTap,
                onLongPress: props.onLongPress,
                selected: props.selected,
              ),
            ),
          ),
        );
      },
    );
  }
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
              timestamp: loopStreamChannelListTimestamp(channel),
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
      // The `@` the member typed is an Alias, which Stream's own mention
      // filter would not recognize: this names the mentioned member with it
      // so the link leaves with the message.
      preMessageSending: (message) => loopPrepareChannelMessageForSend(
        message: message,
        channel: StreamChannel.of(context).channel,
      ),
      enableVoiceRecording: false,
      // This page only ever mounts a group channel, so the `@` overlay is
      // always LOOP's Alias one.
      enableMentionsOverlay: false,
      customAutocompleteTriggers: <StreamAutocompleteTrigger>[
        loopGroupMentionAutocompleteTrigger(),
      ],
      allowedAttachmentPickerTypes: loopChatImagePickerTypes,
      attachmentLimit: loopChatImageMaxCount,
      useSystemAttachmentPicker: true,
    );

    return StreamScaffold(
      appBar: header,
      bottom: composer,
      appBarSurfaceStyle: StreamChannelHeader.resolveSurfaceStyle(context),
      bottomSurfaceStyle: StreamMessageComposer.resolveSurfaceStyle(context),
      body: StreamMessageListView(
        builders: loopStreamMessageListViewBuilders(),
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
            preMessageSending: (message) => loopPrepareChannelMessageForSend(
              message: message,
              channel: StreamChannel.of(context).channel,
            ),
            enableVoiceRecording: false,
            enableMentionsOverlay: false,
            customAutocompleteTriggers: <StreamAutocompleteTrigger>[
              loopGroupMentionAutocompleteTrigger(),
            ],
            allowedAttachmentPickerTypes: loopChatImagePickerTypes,
            attachmentLimit: loopChatImageMaxCount,
            useSystemAttachmentPicker: true,
          );
    return StreamScaffold(
      appBar: StreamThreadHeader(parent: widget.parent, subtitle: subtitle),
      bottom: composer,
      appBarSurfaceStyle: StreamThreadHeader.resolveSurfaceStyle(context),
      bottomSurfaceStyle: StreamMessageComposer.resolveSurfaceStyle(context),
      body: StreamMessageListView(
        builders: loopStreamMessageListViewBuilders(),
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
    // Read, never rendered: both spellings Stream may have written into the
    // text are replaced by the channel-scoped label before the text is drawn.
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
  // The label is written where a renderer reads it from, not only onto
  // `User.name`: a LOOP surface that prints a name asks for the label LOOP
  // resolved and draws nothing when there is none (device report
  // 2026-09-19 · F5).
  return loopStreamDisplayUser(id: user.id, label: label);
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

/// The display copy a direct conversation's message widgets read.
///
/// A direct channel has no Alias namespace, so until now its messages went to
/// Stream untouched — and the avatar beside the peer's bubble drew `L`, the
/// first letter of `loop_…`, because `User.name` answers `User.id` for every
/// LOOP account (device report 2026-09-20 · R14-5). The peer's honest name is
/// the one the page header already shows, published on [LoopDirectPeerScope],
/// and the avatar draws its initial. A page with no published identity — a
/// deep link carries none — falls back to 「私」, the same character the inbox
/// row uses, and never to anything derived from an id.
///
/// The label is deliberately *not* written onto
/// [loopStreamDisplayLabelField]: in a direct conversation the person is
/// named once, in the header above it, so no name is drawn over each bubble.
/// The reader's own projection is left exactly as Stream had it.
@visibleForTesting
Message sanitizeLoopDirectMessageForDisplay({
  required Message message,
  required String? peerLabel,
  required String? currentUserId,
}) => _sanitizeDirectMessage(
  message,
  peerLabel ?? loopDirectConversationNeutralInitial,
  currentUserId,
  depth: 0,
);

Message _sanitizeDirectMessage(
  Message message,
  String label,
  String? currentUserId, {
  required int depth,
}) {
  User displayUser(User user) =>
      user.id == currentUserId ? user : User(id: user.id, name: label);

  final quotedMessage = message.quotedMessage;
  return message.copyWith(
    user: message.user == null ? null : displayUser(message.user!),
    quotedMessage: quotedMessage == null || depth >= 3
        ? null
        : _sanitizeDirectMessage(
            quotedMessage,
            label,
            currentUserId,
            depth: depth + 1,
          ),
  );
}

StreamMessageItemProps _directDisplayProps(
  StreamMessageItemProps props, {
  required String? peerLabel,
  required String? currentUserId,
}) {
  final displayMessage = sanitizeLoopDirectMessageForDisplay(
    message: props.message,
    peerLabel: peerLabel,
    currentUserId: currentUserId,
  );
  if (identical(displayMessage, props.message)) return props;
  return StreamMessageItemProps(
    message: displayMessage,
    padding: props.padding,
    spacing: props.spacing,
    backgroundColor: props.backgroundColor,
    maxWidth: props.maxWidth,
    swipeToReply: props.swipeToReply,
    onMessageTap: props.onMessageTap,
    onMessageLongPress: props.onMessageLongPress,
    // The global avatar sheet cannot express the one name this conversation
    // has, so the identity-bearing entry points stay off here too.
    onUserAvatarTap: null,
    onMessageLinkTap: props.onMessageLinkTap,
    onMentionTap: null,
    onThreadTap: props.onThreadTap,
    onViewInChannelTap: props.onViewInChannelTap,
    onReplyTap: props.onReplyTap,
    onReactionTap: props.onReactionTap,
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
      final directProps = _directDisplayProps(
        props,
        peerLabel: LoopDirectPeerScope.maybeOf(context),
        currentUserId: StreamChat.of(context).currentUser?.id,
      );
      return LoopStreamMessageRow(
        message: directProps.message,
        padding: directProps.padding,
        child: DefaultStreamMessageItem(props: directProps),
      );
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
    // The Alias-projected copy is the one the avatar reads too, so the
    // initials over the gutter and the name above the bubble stay the same
    // member.
    final displayProps = _groupDisplayProps(props, members);
    return LoopStreamMessageRow(
      message: displayProps.message,
      padding: displayProps.padding,
      child: DefaultStreamMessageItem(props: displayProps),
    );
  }
}

/// The same card height Stream's own mention overlay uses, so a long roster
/// scrolls inside the card instead of pushing the composer off the screen.
const double _loopGroupMentionMaxHeight = 176;

/// One member a group `@` can complete to.
///
/// The Alias is the word this channel resolved for that member — the same word
/// the bubble above their message carries. There is no second name here: the
/// Stream account name is empty and the Stream id is the LOOP row key, and
/// neither is ever carried on this object.
@immutable
class LoopGroupMentionCandidate {
  const LoopGroupMentionCandidate({required this.userId, required this.alias});

  /// Stream's internal id. Used to link the mention, never drawn.
  final String userId;

  /// The channel-scoped Alias. The one string this row may print.
  final String alias;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoopGroupMentionCandidate &&
          other.userId == userId &&
          other.alias == alias;

  @override
  int get hashCode => Object.hash(userId, alias);
}

/// The members a group `@<query>` may complete to, in a stable order.
///
/// Stream's own candidate search matches `User.name` (empty for every LOOP
/// account, so its getter answers the id) and would therefore both fail to
/// match an Alias prefix and offer the id as the row's text. LOOP resolves
/// candidates from the channel's own member projection instead, through
/// [resolveLoopGroupMessageSenderLabel] — the very function that names the
/// sender above a bubble, so a candidate and the message it later produces
/// read as the same person.
///
/// A member whose projection is missing, malformed, ambiguous, or future has
/// no name in this channel, so there is nothing to offer and no row appears.
/// [currentUserId] is dropped: a member does not mention themselves.
@visibleForTesting
List<LoopGroupMentionCandidate> resolveLoopGroupMentionCandidates({
  required Iterable<Member> members,
  required String query,
  String? currentUserId,
}) {
  final roster = List<Member>.unmodifiable(members);
  final prefix = query.trim().toLowerCase();
  final seen = <String>{};
  final candidates = <LoopGroupMentionCandidate>[];

  for (final member in roster) {
    final userId = member.userId ?? member.user?.id;
    if (userId == null || userId.isEmpty) continue;
    if (currentUserId != null && userId == currentUserId) continue;
    if (!seen.add(userId)) continue;

    final alias = resolveLoopGroupMessageSenderLabel(
      senderUserId: userId,
      members: roster,
    );
    if (alias == loopGroupMemberNeutralLabel) continue;
    if (!alias.toLowerCase().startsWith(prefix)) continue;

    candidates.add(LoopGroupMentionCandidate(userId: userId, alias: alias));
  }

  candidates.sort(
    (a, b) => a.alias.toLowerCase().compareTo(b.alias.toLowerCase()),
  );
  return List<LoopGroupMentionCandidate>.unmodifiable(candidates);
}

/// The `@` overlay a group or community channel shows.
///
/// It replaces Stream's [StreamMentionAutocompleteOptions] for those channels
/// (`enableMentionsOverlay: false` plus this trigger), because that widget
/// queries and names candidates by the account identity LOOP may not draw.
/// Everything else about the composer stays Stream's.
///
/// The roster offered is the channel's own loaded member list, watched live.
/// It is not extended by a server query: Stream's `queryMembers` filters on
/// `name`, which for a LOOP account is the id, so a request made on an Alias
/// prefix would answer with the wrong people or with nobody. A member the
/// channel has not loaded is therefore not offered — the same honest limit as
/// a member whose projection has not landed.
class LoopGroupMentionAutocompleteOptions extends StatelessWidget {
  const LoopGroupMentionAutocompleteOptions({
    required this.query,
    required this.messageComposerController,
    super.key,
  });

  /// The text typed after `@`, matched against the Alias as a prefix.
  final String query;

  /// The composer this overlay completes into.
  final StreamMessageComposerController messageComposerController;

  @override
  Widget build(BuildContext context) {
    final channel = StreamChannel.maybeOf(context)?.channel;
    final state = channel?.state;
    if (state == null) return const SizedBox.shrink();

    final currentUserId = StreamChat.of(context).currentUser?.id;
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
        final candidates = resolveLoopGroupMentionCandidates(
          members: members,
          query: query,
          currentUserId: currentUserId,
        );
        if (candidates.isEmpty) return const SizedBox.shrink();

        final (:elevation, :margin, :shape) = AutocompleteOptionsStyle.fixed
            .resolve(context.streamColorScheme.borderDefault);
        return StreamAutocompleteOptions<LoopGroupMentionCandidate>(
          options: candidates,
          maxHeight: _loopGroupMentionMaxHeight,
          elevation: elevation,
          margin: margin,
          shape: shape,
          // The card's own default is `backgroundElevation1`, which LOOP maps
          // to the 6%-opaque chalk wash every flat panel on a page uses. A
          // panel drawn *over* the conversation cannot be a wash: on the
          // device the messages underneath read straight through the
          // candidates and half the roster was unreadable against a lime
          // bubble (report 2026-09-20 · R14-4). This overlay is a floating
          // surface, so it takes the opaque elevated ground.
          color: context.streamColorScheme.backgroundElevation3,
          optionBuilder: (context, candidate) => DefaultStreamMentionItem(
            // The official row, handed a display-only projection: its title
            // and its avatar initials both read the Alias, and no account
            // field reaches it.
            props: StreamMentionItemProps(
              mention: StreamUserMention(
                user: loopStreamDisplayUser(
                  id: candidate.userId,
                  label: candidate.alias,
                ),
              ),
              onTap: () => _accept(context, candidate),
            ),
          ),
        );
      },
    );
  }

  void _accept(BuildContext context, LoopGroupMentionCandidate candidate) {
    // Two separate facts leave with the message. The text is the word the
    // member just read in the row; `mentioned_users` is a list of ids on the
    // payload (`message.g.dart:89`). The Alias rides along as the mentioned
    // user's local name, because Stream drops a mention whose token it cannot
    // find in the body — see [prepareLoopGroupMentionsForSend], which re-reads
    // it from the live roster on the way out and so also covers an edit.
    final alreadyMentioned = messageComposerController.mentionedUsers.any(
      (user) => user.id == candidate.userId,
    );
    if (!alreadyMentioned) {
      messageComposerController.addMentionedUser(
        User(id: candidate.userId, name: candidate.alias),
      );
    }
    StreamAutocomplete.of(context).acceptAutocompleteOption(candidate.alias);
  }
}

/// The `@` trigger a group or community composer installs instead of Stream's.
///
/// Pair it with `enableMentionsOverlay: false` on the same composer: a direct
/// channel keeps Stream's own overlay, where
/// `loopStreamGroupMentionItemBuilder` names the peer from their profile.
StreamAutocompleteTrigger loopGroupMentionAutocompleteTrigger() =>
    StreamAutocompleteTrigger(
      trigger: '@',
      optionsViewBuilder: (context, autocompleteQuery, controller) =>
          LoopGroupMentionAutocompleteOptions(
            query: autocompleteQuery.query,
            messageComposerController: controller,
          ),
    );

/// The triggers one LOOP composer installs for [cid].
///
/// Group and community channels get the Alias overlay; a direct channel gets
/// none of its own and keeps Stream's.
List<StreamAutocompleteTrigger> loopChannelAutocompleteTriggers(String? cid) =>
    loopStreamChannelUsesGroupMessageAlias(cid)
    ? <StreamAutocompleteTrigger>[loopGroupMentionAutocompleteTrigger()]
    : const <StreamAutocompleteTrigger>[];
