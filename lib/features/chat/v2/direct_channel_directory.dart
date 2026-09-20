import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';

/// Who each of this account's direct conversations is with, by Stream CID.
///
/// The conversation inbox reads its rows from Stream, and Stream carries no
/// name for a LOOP account: `User.name` is empty and its getter answers
/// `User.id`, so Stream's own 1:1 row drew `loop_7e25…` at the top of the
/// most-read list in the app (device report 2026-09-20 · R14-1). LOOP's
/// `direct_channels` table is the authority instead, read through
/// `GET /v2/chat/direct-channels` (decision 0056), and this is its index.
///
/// Three answers are distinct and must stay distinct:
///
/// * a CID with a peer — the row is named `alias ?? loopId`;
/// * a CID whose peer is `null` — that account has no presentable public
///   profile, so the row reads as a deactivated user;
/// * a CID that is not in the map at all — the read has not landed or the
///   module answered `503`, so LOOP knows nothing and says only that this is
///   a direct conversation.
@immutable
final class LoopDirectChannelDirectory {
  LoopDirectChannelDirectory(Map<String, LoopPublicProfile?> peers)
    : _peers = Map<String, LoopPublicProfile?>.unmodifiable(peers);

  /// The empty index: every CID is unknown, and every row stays neutral.
  factory LoopDirectChannelDirectory.empty() =>
      LoopDirectChannelDirectory(const <String, LoopPublicProfile?>{});

  factory LoopDirectChannelDirectory.fromEntries(
    Iterable<DirectChannelEntry> entries,
  ) => LoopDirectChannelDirectory(<String, LoopPublicProfile?>{
    for (final entry in entries) entry.streamCid: entry.peer,
  });

  final Map<String, LoopPublicProfile?> _peers;

  int get length => _peers.length;

  /// Whether LOOP has an answer for [cid] at all.
  bool knows(String? cid) => cid != null && _peers.containsKey(cid);

  /// The peer of [cid], or `null` both when the account has no public profile
  /// and when the CID is unknown. Pair it with [knows] to tell those apart.
  LoopPublicProfile? peerOf(String? cid) => cid == null ? null : _peers[cid];
}

/// Publishes the index to the Stream widgets that draw the inbox rows.
///
/// The rows are built by official Stream components under a controller LOOP
/// does not own, so the index travels down the tree rather than through the
/// row's props.
class LoopDirectChannelDirectoryScope extends InheritedWidget {
  const LoopDirectChannelDirectoryScope({
    required this.directory,
    required super.child,
    super.key,
  });

  final LoopDirectChannelDirectory directory;

  static LoopDirectChannelDirectory? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<LoopDirectChannelDirectoryScope>()
      ?.directory;

  @override
  bool updateShouldNotify(LoopDirectChannelDirectoryScope oldWidget) =>
      !identical(oldWidget.directory, directory);
}

/// The most pages one inbox load will ask for.
///
/// The server page is at most 50 rows, so this bounds the read at 500 direct
/// conversations. A longer list is not silently truncated in secret: the rows
/// past it simply stay unknown and read as neutral direct conversations,
/// which is the same honest answer as a read that never landed.
@visibleForTesting
const int loopDirectChannelMaxPages = 10;

/// Reads every page of `GET /v2/chat/direct-channels` once.
///
/// A failure is an [AsyncError] here, and the inbox then renders its rows
/// without names rather than with a guessed one. It never falls back to
/// Stream.
final directChannelDirectoryProvider =
    FutureProvider.autoDispose<LoopDirectChannelDirectory>((ref) async {
      final gateway = ref.watch(chatV2GatewayProvider);
      final entries = <DirectChannelEntry>[];
      String? cursor;
      for (var page = 0; page < loopDirectChannelMaxPages; page += 1) {
        final result = await gateway.listDirectChannels(cursor: cursor);
        entries.addAll(result.items);
        cursor = result.nextCursor;
        if (cursor == null) break;
      }
      return LoopDirectChannelDirectory.fromEntries(entries);
    });
