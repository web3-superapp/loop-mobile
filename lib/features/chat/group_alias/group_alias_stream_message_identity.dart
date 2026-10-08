import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/chat/member_buy/loop_member_buy_card.dart';
import 'package:loop_mobile/features/chat/member_buy/member_buy_event.dart';
import 'package:loop_mobile/features/chat/v2/loop_channel_message_policy.dart';
import 'package:loop_mobile/features/chat/v2/loop_message_selection.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';
import 'package:loop_mobile/features/chat/v2/direct_message_identity_scope.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/chat/group_alias/group_member_directory.dart';
import 'package:loop_mobile/features/chat/token_card/chat_token_card.dart';
import 'package:loop_mobile/features/chat/token_card/chat_token_detection.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/integrations/communication/loop_chat_image_policy.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_appearance.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_localizations_zh.dart';
import 'package:loop_mobile/integrations/communication/stream_display_identity.dart';
import 'package:loop_mobile/features/profile/presentation/avatar_media.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';
import 'package:loop_mobile/widgets/loop_unread_badge.dart';
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
  bool realIdentity = false,
  User? senderUser,
}) {
  if (senderUserId.isEmpty || senderUserId != senderUserId.trim()) {
    return loopGroupMemberNeutralLabel;
  }
  if (realIdentity) {
    final real = resolveLoopGroupRealIdentity(
      senderUserId: senderUserId,
      members: members,
      senderUser: senderUser,
    );
    if (real != null) return real.name;
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

/// The account's own name and face in a real-identity channel (S107 §2).
///
/// The member row's user wins over the message's copy of the user — it is
/// the one Stream refreshes when the account renames — and either is read
/// only through [loopStreamRealIdentityOf], so a user Stream knows only by
/// id has no real identity and the caller falls back to the channel-scoped
/// projection.
LoopStreamRealIdentity? resolveLoopGroupRealIdentity({
  required String senderUserId,
  required Iterable<Member> members,
  User? senderUser,
}) {
  for (final member in members) {
    final user = member.user;
    if (user == null || user.id != senderUserId) continue;
    final real = loopStreamRealIdentityOf(user);
    if (real != null) return real;
  }
  if (senderUser != null && senderUser.id == senderUserId) {
    return loopStreamRealIdentityOf(senderUser);
  }
  return null;
}

/// Whether the channel at [cid] draws its members as their real accounts.
///
/// A community channel follows `communityChatRealIdentity`; every other group
/// follows the inverse of `groupAliasVisible` (decision 0112).
bool loopChannelUsesRealIdentity(BuildContext context, String? cid) {
  final switches = loopFeatureSwitchesOf(context);
  return switches.realIdentityFor(
    communityChannel:
        cid != null &&
        loopChatSurfaceForCid(cid) == LoopChatSurface.communityChat,
  );
}

/// Every Stream user id one group message may draw a name or an avatar for.
///
/// The sender, whoever it `@`s, whoever pinned it, the thread's participants,
/// and the same again for the message it quotes — the ids
/// [sanitizeLoopGroupMessageForDisplay] resolves, so a row asks for exactly
/// the member rows it is about to read. Reactions are left out: their detail
/// sheet is suppressed in group channels and they draw no names.
@visibleForTesting
Set<String> loopGroupMessageUserIds(Message message) {
  final ids = <String>{};
  void collect(Message message, int depth) {
    if (message.user case final User user) ids.add(user.id);
    for (final user in message.mentionedUsers) {
      ids.add(user.id);
    }
    if (message.pinnedBy case final User user) ids.add(user.id);
    for (final user in message.threadParticipants ?? const <User>[]) {
      ids.add(user.id);
    }
    final quoted = message.quotedMessage;
    if (quoted != null && depth < 3) collect(quoted, depth + 1);
  }

  collect(message, 0);
  return ids;
}

/// The roster one group surface names people from, asking for what it lacks.
///
/// The channel's loaded members come first and win; the reader's own
/// membership row and whatever [directory] has already found fill the rest
/// (see [LoopGroupMemberDirectory.roster]). Any id in [needs] the result does
/// not carry is handed to [directory], which asks Stream once, batched and
/// debounced, and notifies when the row lands. Until then that id reads as
/// 「成员」 — the same word it read before anyone asked, so nothing flickers
/// through an id or an account name on the way.
List<Member> loopGroupRosterFor({
  required LoopGroupMemberDirectory directory,
  required ChannelState channelState,
  Iterable<String> needs = const <String>{},
}) {
  final roster = directory.roster(
    channelState.members ?? const <Member>[],
    membership: channelState.membership,
  );
  final covered = <String>{
    for (final member in roster) ?(member.userId ?? member.user?.id),
  };
  final missing = needs.where((id) => !covered.contains(id));
  if (missing.isNotEmpty) directory.request(missing);
  return roster;
}

/// Watches one group channel's roster: its loaded members, live, plus the
/// rows its [LoopGroupMemberDirectory] looked up for [needs].
class LoopGroupRosterBuilder extends StatelessWidget {
  const LoopGroupRosterBuilder({
    required this.channel,
    required this.builder,
    this.needs = const <String>{},
    super.key,
  });

  final Channel channel;

  /// The ids this subtree is about to name.
  final Set<String> needs;

  final Widget Function(BuildContext context, List<Member> members) builder;

  @override
  Widget build(BuildContext context) {
    final state = channel.state;
    if (state == null) return builder(context, const <Member>[]);
    final directory = LoopGroupMemberDirectory.forChannel(channel);
    // Only the member rows are watched, as before: a new message or a read
    // receipt changes the channel state but not who anybody is, and every
    // bubble in the room rebuilding on each of them would be wasted work.
    final initial = _LoopRosterSource.of(state.channelState);
    final sources = state.channelStateStream
        .map(_LoopRosterSource.of)
        .distinct();
    return StreamBuilder<_LoopRosterSource>(
      initialData: initial,
      stream: sources,
      builder: (context, snapshot) => ListenableBuilder(
        listenable: directory,
        builder: (context, _) => builder(
          context,
          snapshot.hasError
              ? const <Member>[]
              : loopGroupRosterFor(
                  directory: directory,
                  channelState: (snapshot.data ?? initial).asChannelState(),
                  needs: needs,
                ),
        ),
      ),
    );
  }
}

/// The two parts of a channel state a roster is built from.
@immutable
final class _LoopRosterSource {
  const _LoopRosterSource(this.members, this.membership);

  factory _LoopRosterSource.of(ChannelState channelState) => _LoopRosterSource(
    List<Member>.unmodifiable(channelState.members ?? const <Member>[]),
    channelState.membership,
  );

  final List<Member> members;
  final Member? membership;

  ChannelState asChannelState() =>
      ChannelState(members: members, membership: membership);

  @override
  bool operator ==(Object other) =>
      other is _LoopRosterSource &&
      listEquals(other.members, members) &&
      other.membership == membership;

  @override
  int get hashCode => Object.hash(Object.hashAll(members), membership);
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
///
/// Two LOOP rows sit on top (S108, decision 0114): a member-buy feed message
/// is [LoopMemberBuyCard], not a bubble, and while the conversation is
/// multi-selecting every row carries its check box ([LoopSelectableMessage]).
Widget loopStreamGroupMessageItemBuilder(
  BuildContext context,
  StreamMessageItemProps props,
) {
  final message = props.message;
  final Widget item = loopIsMemberBuyMessage(message) && !message.isDeleted
      ? LoopMemberBuyCard(
          key: ValueKey<String>('loop-member-buy-${message.id}'),
          message: message,
        )
      : _LoopStreamGroupMessageItem(
          props: loopApplyChannelMessagePolicy(context, props),
        );
  return LoopSelectableMessage(message: message, child: item);
}

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
  bool realIdentity = false,
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
      realIdentity: realIdentity,
      senderUser: user,
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

/// Keeps a private `@` linked to the peer it names when the message leaves.
///
/// The same filter that dropped a group Alias drops this one: the member
/// types the peer's alias, and a LOOP account carries no Stream name, so
/// neither token `removeMentionsIfNotIncluded` looks for was in the body and
/// `@Voyager_09` left with `mentioned_users: []` — no unread, no push, no
/// highlight for the one person it was addressed to (device report
/// 2026-09-20 · R15-3).
///
/// So the mentioned user is named locally with the word the page itself shows
/// for the peer, and Stream's own filter then finds it. The body is left
/// alone, and the projection is not sent: `mentioned_users` serializes as ids.
/// The reader is never renamed — a member does not mention themselves, and a
/// stale self-mention is left exactly as Stream had it.
@visibleForTesting
Message prepareLoopDirectMentionsForSend({
  required Message message,
  required String peerLabel,
  required String? currentUserId,
}) {
  final mentioned = message.mentionedUsers;
  if (mentioned.isEmpty) return message;

  var changed = false;
  final named = <User>[];
  for (final user in mentioned) {
    if (user.id == currentUserId || user.name == peerLabel) {
      named.add(user);
      continue;
    }
    changed = true;
    named.add(User(id: user.id, name: peerLabel));
  }
  if (!changed) return message;
  return message.copyWith(mentionedUsers: named);
}

/// The pre-send step a LOOP composer installs for the channel it is in.
///
/// A group channel names its mentions from the live member roster. A direct
/// channel has no roster to read a name from, so the caller passes the peer
/// name its own page published; without one nothing is renamed and the
/// mention stands or falls on Stream's own tokens.
Message loopPrepareChannelMessageForSend({
  required Message message,
  required Channel channel,
  String? directPeerLabel,
  String? currentUserId,
  bool realIdentity = false,
}) {
  if (!loopStreamChannelUsesGroupMessageAlias(channel.cid)) {
    if (directPeerLabel == null) return message;
    return prepareLoopDirectMentionsForSend(
      message: message,
      peerLabel: directPeerLabel,
      currentUserId: currentUserId,
    );
  }
  final channelState = channel.state?.channelState;
  return prepareLoopGroupMentionsForSend(
    message: message,
    realIdentity: realIdentity,
    // The same roster the `@` card offered from, so a member it found by
    // lookup is named on the way out too.
    members: channelState == null
        ? const <Member>[]
        : LoopGroupMemberDirectory.forChannel(channel).roster(
            channelState.members ?? const <Member>[],
            membership: channelState.membership,
          ),
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
/// The right end of an inbox row: the last message's time and, when the
/// conversation has unread messages, LOOP's unread badge after it
/// (decision 0105 · 6).
Widget loopStreamChannelListTrailing(Widget time, int unreadCount) {
  if (loopUnreadBadgeLabel(unreadCount) == null) return time;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      time,
      const SizedBox(width: 6),
      LoopUnreadBadge(
        key: const ValueKey<String>('loop-channel-unread-badge'),
        count: unreadCount,
      ),
    ],
  );
}

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

/// The channel a direct row's preview is formatted against.
///
/// The official formatter branches on the member count: the reader's own
/// message takes the 「你: 」 prefix, a channel of more than two names the
/// author, and anything else is printed bare
/// (`message_preview_formatter.dart:228`). `8b4780f` passed no channel at
/// all, to keep that middle branch — which would print the author's Stream
/// identity — away from a 1:1 row. The cost showed up on the device: a group
/// row read 「你: …」 and a private row did not, so the same list answered
/// "who said this" in two different ways (device report 2026-09-20 · R15-2).
///
/// A direct channel is 1:1 by construction, so the count is pinned at two
/// here: the reader's own message is marked, the peer's is printed bare, and
/// the author branch stays unreachable no matter what the provider's count
/// drifts to.
@visibleForTesting
ChannelModel loopDirectPreviewChannel(ChannelModel? channel) =>
    (channel ?? ChannelModel(id: 'loop_direct', type: 'messaging')).copyWith(
      memberCount: 2,
    );

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
                // `.row-ico`: the resolved name's initials on `--card2`.
                // A `CircleAvatar` here took the Material scheme's primary —
                // Lime — and printed a solid Lime disc per row (audit
                // 2026-09-20 · D-10).
                avatar: _directRowAvatar(context, identity),
                title: Text(identity.title),
                subtitle: lastMessage == null
                    ? Text(context.translations.emptyMessagesText)
                    : StreamMessagePreviewText(
                        message: lastMessage,
                        channel: loopDirectPreviewChannel(channelState.channel),
                      ),
                timestamp: loopStreamChannelListTrailing(
                  loopStreamChannelListTimestamp(channel),
                  unreadSnapshot.data ?? state.unreadCount,
                ),
                // Decision 0105 · 6: the count is LOOP's badge beside the
                // time, not Stream's own.
                unreadCount: 0,
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

/// The peer's uploaded picture (S107 §1), over the initials it replaces.
Widget _directRowAvatar(BuildContext context, LoopDirectRowIdentity identity) {
  final initials = LoopInitialsAvatar(
    key: const ValueKey<String>('loop-direct-channel-avatar'),
    label: identity.initial,
    size: 40,
  );
  final url = loopMediaUrlFor(context, identity.peer?.avatarRef);
  if (url == null) return initials;
  return LoopRemoteAvatar(
    key: const ValueKey<String>('loop-direct-channel-avatar-image'),
    url: url,
    size: 40,
    fallback: initials,
  );
}

class _LoopStreamGroupChannelListItem extends StatelessWidget {
  const _LoopStreamGroupChannelListItem({required this.props});

  final StreamChannelListItemProps props;

  @override
  Widget build(BuildContext context) {
    final channel = props.channel;
    final state = channel.state!;
    final directory = LoopGroupMemberDirectory.forChannel(channel);
    return StreamBuilder<ChannelState>(
      initialData: state.channelState,
      stream: state.channelStateStream,
      builder: (context, snapshot) => ListenableBuilder(
        listenable: directory,
        builder: (context, _) => _buildTile(
          context,
          channelState: snapshot.data ?? state.channelState,
          directory: directory,
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required ChannelState channelState,
    required LoopGroupMemberDirectory directory,
  }) {
    final channel = props.channel;
    final state = channel.state!;
    final messages = channelState.messages ?? const <Message>[];
    final lastMessage = messages.isEmpty ? null : messages.last;
    // The row names the last sender the way the room does, so it asks
    // for the same member row the room would.
    final members = loopGroupRosterFor(
      directory: directory,
      channelState: channelState,
      needs: lastMessage == null
          ? const <String>{}
          : loopGroupMessageUserIds(lastMessage),
    );
    // A member-buy feed message names nobody (S108): the preview formatter
    // recognises it by its sender — LOOP's feed bot — which the member
    // projection below would replace, so it is previewed as it arrived.
    final displayMessage = lastMessage == null
        ? null
        : loopIsMemberBuyMessage(lastMessage)
        ? lastMessage
        : sanitizeLoopGroupMessageForDisplay(
            message: lastMessage,
            members: members,
            realIdentity: loopChannelUsesRealIdentity(context, channel.cid),
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
        builder: (context, pinnedSnapshot) => StreamBuilder<int>(
          initialData: state.unreadCount,
          stream: state.unreadCountStream,
          builder: (context, unreadSnapshot) => StreamChannelListTile(
            avatar: LoopInitialsAvatar(
              key: const ValueKey<String>('loop-group-channel-neutral-avatar'),
              label: label,
              size: 40,
              shape: BoxShape.rectangle,
            ),
            title: Text(label),
            subtitle: displayMessage == null
                ? Text(context.translations.emptyMessagesText)
                : StreamMessagePreviewText(
                    message: displayMessage,
                    channel: channelState.channel,
                  ),
            timestamp: loopStreamChannelListTrailing(
              loopStreamChannelListTimestamp(channel),
              unreadSnapshot.data ?? state.unreadCount,
            ),
            unreadCount: 0,
            isMuted: mutedSnapshot.data ?? channel.isMuted,
            isPinned: pinnedSnapshot.data ?? channel.isPinned,
            onTap: props.onTap,
            onLongPress: props.onLongPress,
            selected: props.selected,
          ),
        ),
      ),
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
  bool realIdentity = false,
}) => _sanitizeMessage(
  message,
  List<Member>.unmodifiable(members),
  depth: 0,
  realIdentity: realIdentity,
);

Message _sanitizeMessage(
  Message message,
  List<Member> members, {
  required int depth,
  required bool realIdentity,
}) {
  User displayUser(User user) =>
      _groupDisplayUser(user, members, realIdentity: realIdentity);

  final originalMentionedUsers = message.mentionedUsers;
  var displayText = message.text;
  for (final user in originalMentionedUsers) {
    final label = resolveLoopGroupMessageSenderLabel(
      senderUserId: user.id,
      members: members,
      realIdentity: realIdentity,
      senderUser: user,
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
      : _sanitizeMessage(
          quotedMessage,
          members,
          depth: depth + 1,
          realIdentity: realIdentity,
        );

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

User _groupDisplayUser(
  User user,
  List<Member> members, {
  required bool realIdentity,
}) {
  if (realIdentity) {
    final real = resolveLoopGroupRealIdentity(
      senderUserId: user.id,
      members: members,
      senderUser: user,
    );
    // The account's own name, face and profile: the bubble names it, the
    // gutter draws its picture and a tap opens the profile it carries.
    if (real != null) {
      return loopStreamRealDisplayUser(id: user.id, identity: real);
    }
  }
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
  List<Member> members, {
  required bool realIdentity,
}) {
  final displayMessage = sanitizeLoopGroupMessageForDisplay(
    message: props.message,
    members: members,
    realIdentity: realIdentity,
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
/// It is written onto [loopStreamDisplayAvatarLabelField] instead, so the
/// avatar beside each of their messages draws their initial rather than the
/// unnamed tile (emulator 2026-10-08). The reader's own projection is left
/// exactly as Stream had it.
@visibleForTesting
Message sanitizeLoopDirectMessageForDisplay({
  required Message message,
  required String? peerLabel,
  required String? currentUserId,
  String? peerProfileId,
}) => _sanitizeDirectMessage(
  message,
  peerLabel ?? loopDirectConversationNeutralInitial,
  currentUserId,
  peerProfileId,
  depth: 0,
);

Message _sanitizeDirectMessage(
  Message message,
  String label,
  String? currentUserId,
  String? peerProfileId, {
  required int depth,
}) {
  User displayUser(User user) {
    if (user.id == currentUserId) return user;
    // S107 §2: the peer's own picture, and the profile their avatar opens —
    // the one the page was opened for, or the one Stream carries.
    final real = loopStreamRealIdentityOf(user);
    final profile = real?.publicProfileId ?? peerProfileId;
    return User(
      id: user.id,
      name: label,
      extraData: <String, Object?>{
        // The avatar column reads this (never User.name); the name line over
        // the bubbles reads only the display label, which stays unset here.
        loopStreamDisplayAvatarLabelField: label,
        loopStreamDisplayImageField: ?real?.imageUrl,
        loopStreamDisplayProfileField: ?profile,
      },
    );
  }

  final quotedMessage = message.quotedMessage;
  return message.copyWith(
    user: message.user == null ? null : displayUser(message.user!),
    quotedMessage: quotedMessage == null || depth >= 3
        ? null
        : _sanitizeDirectMessage(
            quotedMessage,
            label,
            currentUserId,
            peerProfileId,
            depth: depth + 1,
          ),
  );
}

StreamMessageItemProps _directDisplayProps(
  StreamMessageItemProps props, {
  required String? peerLabel,
  required String? currentUserId,
  String? peerProfileId,
}) {
  final displayMessage = sanitizeLoopDirectMessageForDisplay(
    message: props.message,
    peerLabel: peerLabel,
    currentUserId: currentUserId,
    peerProfileId: peerProfileId,
  );
  // Always a fresh props: the reaction detail sheet below is suppressed even
  // when the display copy is the message itself.
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
    // Decision 0117: as in a group, the reaction detail sheet stays shut. Its
    // 「+」 (`StreamEmojiChip.addEmoji`) opens Stream's Emoji catalogue, which
    // LOOP leaves empty, and no component builder replaces it.
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
      final directProps = _directDisplayProps(
        props,
        peerLabel: LoopDirectPeerScope.maybeOf(context),
        currentUserId: StreamChat.of(context).currentUser?.id,
        peerProfileId: LoopDirectPeerScope.profileOf(context),
      );
      return _withTokenCards(
        context,
        directProps.message,
        LoopStreamMessageRow(
          message: directProps.message,
          padding: directProps.padding,
          child: DefaultStreamMessageItem(props: directProps),
        ),
      );
    }

    final state = channel?.state;
    if (channel == null || state == null) {
      return _buildDefault(context, const <Member>[]);
    }

    return LoopGroupRosterBuilder(
      channel: channel,
      needs: loopGroupMessageUserIds(props.message),
      builder: _buildDefault,
    );
  }

  Widget _buildDefault(BuildContext context, List<Member> members) {
    // The Alias-projected copy is the one the avatar reads too, so the
    // initials over the gutter and the name above the bubble stay the same
    // member.
    final channel = StreamChannel.maybeOf(context)?.channel;
    final displayProps = _groupDisplayProps(
      props,
      members,
      realIdentity: loopChannelUsesRealIdentity(context, channel?.cid),
    );
    return _withTokenCards(
      context,
      displayProps.message,
      LoopStreamMessageRow(
        message: displayProps.message,
        padding: displayProps.padding,
        child: DefaultStreamMessageItem(props: displayProps),
      ),
    );
  }
}

/// Puts a Token Card under a bubble whose text names a contract address.
///
/// The bubble is untouched: the address stays in the message exactly as it
/// was written, and the card below it is LOOP reading that address — the
/// message itself carries no facts and is never rewritten.
///
/// The long-press preview renders the same item; it gets no cards, because a
/// preview is a copy of the bubble and a second card there would read the
/// same contract twice for one message.
Widget _withTokenCards(BuildContext context, Message message, Widget row) {
  if (StreamMessageLayout.presentationOf(context) !=
      StreamMessagePresentation.standard) {
    return row;
  }
  if (message.isDeleted) return row;
  final addresses = loopDetectChatTokenAddresses(message.text ?? '');
  if (addresses.isEmpty) return row;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      row,
      for (final address in addresses)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ChatTokenCard(address: address),
        ),
    ],
  );
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
  bool realIdentity = false,
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
      realIdentity: realIdentity,
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

/// The one person a private `@` may complete to, or nobody.
///
/// A direct channel carries no Alias namespace and Stream's own candidate
/// search reads `User.name` — the id — so LOOP resolves the candidate itself:
/// the room's single other member, named with the public profile the page
/// published. Anything that is not exactly that fails closed. A roster that
/// has not loaded, a channel that somehow holds more than one other member,
/// and a page with no published identity all offer nothing, because none of
/// them can prove who would be mentioned.
@visibleForTesting
List<LoopGroupMentionCandidate> resolveLoopDirectMentionCandidates({
  required Iterable<Member> members,
  required String query,
  required String? peerLabel,
  String? currentUserId,
}) {
  if (peerLabel == null || peerLabel.isEmpty) {
    return const <LoopGroupMentionCandidate>[];
  }
  final others = <String>{};
  for (final member in members) {
    final userId = member.userId ?? member.user?.id;
    if (userId == null || userId.isEmpty) continue;
    if (userId == currentUserId) continue;
    others.add(userId);
  }
  if (others.length != 1) return const <LoopGroupMentionCandidate>[];
  if (!peerLabel.toLowerCase().startsWith(query.trim().toLowerCase())) {
    return const <LoopGroupMentionCandidate>[];
  }
  return List<LoopGroupMentionCandidate>.unmodifiable(
    <LoopGroupMentionCandidate>[
      LoopGroupMentionCandidate(userId: others.single, alias: peerLabel),
    ],
  );
}

/// The `@` overlay a group or community channel shows.
///
/// It replaces Stream's [StreamMentionAutocompleteOptions] for those channels
/// (`enableMentionsOverlay: false` plus this trigger), because that widget
/// queries and names candidates by the account identity LOOP may not draw.
/// Everything else about the composer stays Stream's.
///
/// The roster offered is the channel's own loaded member list, watched live,
/// plus the rows the channel's [LoopGroupMemberDirectory] already looked up
/// *by id* for senders on screen. It is not extended by a query on what was
/// typed: Stream's `queryMembers` can only match `name`, which for a LOOP
/// account is the id, so a request made on an Alias prefix would answer with
/// the wrong people or with nobody — and would send the typed Alias to a
/// provider field it does not belong in. A member neither loaded nor looked up
/// is therefore not offered — the same honest limit as a member whose
/// projection has not landed (decision 0107).
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
    return LoopGroupRosterBuilder(
      channel: channel!,
      builder: (context, members) => _LoopMentionCandidateCard(
        candidates: resolveLoopGroupMentionCandidates(
          members: members,
          query: query,
          currentUserId: currentUserId,
          realIdentity: loopChannelUsesRealIdentity(context, channel.cid),
        ),
        messageComposerController: messageComposerController,
      ),
    );
  }
}

/// The `@` overlay a direct conversation shows.
///
/// A direct channel has no Alias namespace, so until now it kept Stream's own
/// overlay, whose row and whose tap both read `User.name` — the id. The one
/// honest name here is the peer's public profile, which the page publishes on
/// [LoopDirectPeerScope]; there is exactly one other person in the room, so
/// there is exactly one candidate, and without a published identity there is
/// none at all.
class LoopDirectMentionAutocompleteOptions extends StatelessWidget {
  const LoopDirectMentionAutocompleteOptions({
    required this.query,
    required this.messageComposerController,
    super.key,
  });

  /// The text typed after `@`, matched against the peer's name as a prefix.
  final String query;

  final StreamMessageComposerController messageComposerController;

  @override
  Widget build(BuildContext context) {
    final channel = StreamChannel.maybeOf(context)?.channel;
    final state = channel?.state;
    if (state == null) return const SizedBox.shrink();

    final peerLabel = LoopDirectPeerScope.maybeOf(context);
    final currentUserId = StreamChat.of(context).currentUser?.id;
    return _LoopMembersBuilder(
      state: state,
      builder: (context, members) => _LoopMentionCandidateCard(
        candidates: resolveLoopDirectMentionCandidates(
          members: members,
          query: query,
          peerLabel: peerLabel,
          currentUserId: currentUserId,
        ),
        messageComposerController: messageComposerController,
      ),
    );
  }
}

/// Watches one channel's loaded member list.
class _LoopMembersBuilder extends StatelessWidget {
  const _LoopMembersBuilder({required this.state, required this.builder});

  final ChannelClientState state;
  final Widget Function(BuildContext context, List<Member> members) builder;

  @override
  Widget build(BuildContext context) {
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
      builder: (context, snapshot) => builder(
        context,
        snapshot.hasError
            ? const <Member>[]
            : snapshot.data ?? const <Member>[],
      ),
    );
  }
}

/// The one card both LOOP `@` overlays draw.
class _LoopMentionCandidateCard extends StatelessWidget {
  const _LoopMentionCandidateCard({
    required this.candidates,
    required this.messageComposerController,
  });

  final List<LoopGroupMentionCandidate> candidates;
  final StreamMessageComposerController messageComposerController;

  @override
  Widget build(BuildContext context) {
    if (candidates.isEmpty) return const SizedBox.shrink();

    final (:elevation, :margin, :shape) = AutocompleteOptionsStyle.fixed
        .resolve(context.streamColorScheme.borderDefault);
    return StreamAutocompleteOptions<LoopGroupMentionCandidate>(
      options: candidates,
      maxHeight: _loopGroupMentionMaxHeight,
      elevation: elevation,
      margin: margin,
      shape: shape,
      // The card's own default is `backgroundElevation1`, which LOOP maps to
      // the 6%-opaque chalk wash every flat panel on a page uses. A panel
      // drawn *over* the conversation cannot be a wash: on the device the
      // messages underneath read straight through the candidates — half a
      // group roster against a lime bubble (report 2026-09-20 · R14-4), and
      // the conversation's own clock through the private one (R15-4). This
      // overlay is a floating surface, so it takes the opaque elevated
      // ground, and both overlays take it from here.
      color: context.streamColorScheme.backgroundElevation3,
      optionBuilder: (context, candidate) => DefaultStreamMentionItem(
        // The official row, handed a display-only projection: its title and
        // its avatar initials both read the name LOOP resolved, and no
        // account field reaches it.
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
  }

  void _accept(BuildContext context, LoopGroupMentionCandidate candidate) {
    // Two separate facts leave with the message. The text is the word the
    // member just read in the row; `mentioned_users` is a list of ids on the
    // payload (`message.g.dart:89`). The resolved name rides along as the
    // mentioned user's local name, because Stream drops a mention whose token
    // it cannot find in the body — see [loopPrepareChannelMessageForSend],
    // which re-reads it on the way out and so also covers an edit.
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
/// Pair it with `enableMentionsOverlay: false` on the same composer.
StreamAutocompleteTrigger loopGroupMentionAutocompleteTrigger() =>
    StreamAutocompleteTrigger(
      trigger: '@',
      optionsViewBuilder: (context, autocompleteQuery, controller) =>
          LoopGroupMentionAutocompleteOptions(
            query: autocompleteQuery.query,
            messageComposerController: controller,
          ),
    );

/// The `@` trigger a direct composer installs instead of Stream's.
StreamAutocompleteTrigger loopDirectMentionAutocompleteTrigger() =>
    StreamAutocompleteTrigger(
      trigger: '@',
      optionsViewBuilder: (context, autocompleteQuery, controller) =>
          LoopDirectMentionAutocompleteOptions(
            query: autocompleteQuery.query,
            messageComposerController: controller,
          ),
    );

/// The triggers one LOOP composer installs for [cid].
///
/// Every LOOP channel now brings its own `@`: a group or community channel
/// completes to the channel Alias, a direct channel to the peer the page
/// published. Stream's own overlay is never mounted, because both its row and
/// its tap read `User.name`, which for a LOOP account is the id.
List<StreamAutocompleteTrigger> loopChannelAutocompleteTriggers(String? cid) {
  if (loopStreamChannelUsesGroupMessageAlias(cid)) {
    return <StreamAutocompleteTrigger>[loopGroupMentionAutocompleteTrigger()];
  }
  // A locator LOOP cannot read names no room, so it installs no `@` of its
  // own; the composer that asked has already refused to mount such a channel.
  if (cid == null || parseLoopStreamChannelCid(cid) == null) {
    return const <StreamAutocompleteTrigger>[];
  }
  return <StreamAutocompleteTrigger>[loopDirectMentionAutocompleteTrigger()];
}
