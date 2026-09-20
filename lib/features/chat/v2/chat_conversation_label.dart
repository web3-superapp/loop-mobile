import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/navigation/stream_channel_route.dart';
import 'package:loop_mobile/features/chat/friends/friend_models.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_stream_message_identity.dart';
import 'package:loop_mobile/features/chat/v2/direct_channel_directory.dart';

/// Neutral title for a community's official group LOOP could not name.
const String loopCommunityConversationNeutralLabel = '社区官方群';

/// What one conversation is called, and what it is.
///
/// `#scr-chat-forward` lists its destinations as a name over a line of facts —
/// `PEPE Official / 8,420 online · Official community`, `Alpha Group /
/// 24 members · 8 online`, `NightOwl / Direct message · Online`. LOOP printed
/// the *kind* as the title instead, so nine community rows in a row all read
/// `社区官方群` and the list could not say which community any of them was
/// (audit 2026-09-20 · B.6 / D-10).
@immutable
final class ChatConversationLabel {
  const ChatConversationLabel({required this.title, required this.subtitle});

  /// The name, or the kind when LOOP has no name to use.
  final String title;

  /// The kind, and the membership figure when the provider stated one.
  final String subtitle;
}

/// The name a channel stored about itself, or `null`.
///
/// A conversation's title is a fact the LOOP backend wrote onto the channel
/// when it created it. It is still read defensively: anything that fails the
/// display contract — too long, control characters, empty after trimming — is
/// no name at all, and the caller falls back to the kind. This is the same
/// gate [resolveLoopGroupConversationLabel] applies, minus its fixed neutral,
/// so each surface can name its own.
String? loopStoredConversationName(Map<String, Object?> extraData) {
  final raw = extraData['name'];
  if (raw is! String) return null;
  try {
    return normalizeFriendGroupName(raw) == raw ? raw : null;
  } on InvalidFriendContractException {
    return null;
  }
}

/// Names one conversation for a list row.
///
/// [directory] is LOOP's own index of its direct channels; without it a direct
/// row stays neutral rather than borrowing a name from the provider.
ChatConversationLabel resolveChatConversationLabel({
  required LoopChatSurface surface,
  required Map<String, Object?> extraData,
  String? cid,
  int? memberCount,
  LoopDirectChannelDirectory? directory,
}) {
  final stored = loopStoredConversationName(extraData);
  final members = memberCount == null ? null : '$memberCount 名成员';
  return switch (surface) {
    LoopChatSurface.communityChat => ChatConversationLabel(
      title: stored ?? loopCommunityConversationNeutralLabel,
      subtitle: members == null
          ? loopCommunityConversationNeutralLabel
          : '$loopCommunityConversationNeutralLabel · $members',
    ),
    LoopChatSurface.group => ChatConversationLabel(
      title: stored ?? loopGroupConversationNeutralLabel,
      subtitle: members == null
          ? loopGroupConversationNeutralLabel
          : '$loopGroupConversationNeutralLabel · $members',
    ),
    // A direct row is never named from the channel: LOOP publishes no profile
    // to Stream, so a stored name there could only have come from somewhere
    // this client does not trust.
    LoopChatSurface.direct => ChatConversationLabel(
      title: resolveLoopDirectRowIdentity(cid: cid, directory: directory).title,
      subtitle: '私聊',
    ),
  };
}
