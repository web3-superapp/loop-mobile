import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/text/loop_human_text.dart';
import 'package:loop_mobile/features/chat/v2/loop_channel_message_policy.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Renaming a small group (decision 0113, S109b §3.5).
///
/// The name is the server's: `PATCH /v2/chat/groups/{id}` writes it, and the
/// server copies it onto the Stream channel afterwards. The client checks the
/// shape the creation form checks (1–40 code points, no control or format
/// characters), shows the confirmed name at once, and leaves the channel
/// list to Stream's own update event.

/// The longest group name, in code points — the creation form's limit.
const int groupNameMaximumRunes = 40;

/// The trimmed name, or null when [raw] is a name the server would refuse.
String? normalizedGroupName(String raw) {
  if (raw.length > 256 || containsLoopForbiddenHumanTextCodePoint(raw)) {
    return null;
  }
  final trimmed = raw.trim();
  final runes = trimmed.runes.length;
  if (runes < 1 || runes > groupNameMaximumRunes) return null;
  return trimmed;
}

/// The group resource the rename answers with.
@immutable
final class GroupRenamed {
  const GroupRenamed({
    required this.groupId,
    required this.name,
    required this.nameVersion,
    required this.updatedAt,
  });

  final String groupId;
  final String name;
  final int nameVersion;
  final DateTime updatedAt;
}

/// Feature-facing port for the group profile write. No transport type and
/// no `/v2/` literal live here.
abstract interface class GroupProfileGateway {
  CommunityGatewayMode get mode;

  /// Renames [groupId]. Creator only; anybody else is refused with
  /// [CommunityFailureKind.permissionDenied]. A server that does not serve
  /// the route yet is [CommunityFailureKind.unavailable], never a success.
  Future<GroupRenamed> rename(String groupId, String name);
}

final class UnavailableGroupProfileGateway implements GroupProfileGateway {
  const UnavailableGroupProfileGateway();

  @override
  CommunityGatewayMode get mode => CommunityGatewayMode.unavailable;

  @override
  Future<GroupRenamed> rename(String groupId, String name) =>
      Future<GroupRenamed>.error(
        const CommunityGatewayException(CommunityFailureKind.unavailable),
      );
}

/// Overridden by `main.dart` with the V2 adapter. The Preview composes none,
/// so renaming there says it is unavailable.
final groupProfileGatewayProvider = Provider<GroupProfileGateway>(
  (ref) => const UnavailableGroupProfileGateway(),
);

/// What `group-info` reads about the group from Stream: its current name
/// and whether the reader created it (the creator is the channel's
/// `created_by`, loop-api 0091 — the same fact pinning uses).
@immutable
final class GroupStreamFacts {
  const GroupStreamFacts({required this.name, required this.viewerIsCreator});

  final String? name;
  final bool viewerIsCreator;
}

typedef GroupStreamFactsReader = Future<GroupStreamFacts?> Function(String cid);

/// Reads [GroupStreamFacts] from the channel Stream already holds, or from
/// one membership-scoped query when it holds none. A channel the account is
/// not a member of, or no Stream session at all, is null: unknown, so the
/// page offers no rename.
final groupStreamFactsReaderProvider = Provider<GroupStreamFactsReader>((ref) {
  final session = ref.watch(streamChatSdkSessionProvider);
  return (cid) async {
    final client = session?.client;
    final userId = client?.state.currentUser?.id;
    if (client == null || userId == null) return null;
    try {
      var channel = client.state.channels[cid];
      if (channel == null || channel.state == null) {
        final channels = await client.queryChannelsOnline(
          filter: Filter.and(<Filter>[
            Filter.equal('cid', cid),
            Filter.in_('members', <Object>[userId]),
          ]),
          state: true,
          watch: false,
          messageLimit: 1,
          paginationParams: const PaginationParams(limit: 1),
        );
        if (channels.length != 1 || channels.single.cid != cid) return null;
        channel = channels.single;
      }
      return GroupStreamFacts(
        name: channel.name,
        viewerIsCreator: loopFriendGroupCreatorMayPin(channel, userId),
      );
    } catch (_) {
      return null;
    }
  };
});
