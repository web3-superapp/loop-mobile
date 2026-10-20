import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// How many of a conversation's newest messages one reconciliation reads.
///
/// It is the window the server is asked to vouch for. A conversation shorter
/// than this is read whole, so every message this device still holds for it
/// and the server no longer has is known to be gone.
const int loopStreamReconcilePageSize = 100;

/// Reads the newest [limit] messages of [channel] from Stream, oldest first.
///
/// The production read is `client.queryChannel` with `watch: false`: it
/// returns the server's own answer and merges nothing into the channel, so
/// the answer can be compared with what this device holds.
typedef LoopStreamServerMessagePage = Future<List<Message>> Function(
  Channel channel,
  int limit,
);

/// The ids among [local] that the server no longer has (S253 · decision 0216).
///
/// [serverPage] is the server's newest page for the conversation, oldest
/// first, read *after* [local] was taken. [reachesChannelStart] is whether
/// that page holds the whole conversation (the server returned fewer messages
/// than it was asked for).
///
/// A message is stale when the server would have had to return it and did
/// not: it is a message the server already accepted (not an outgoing or a
/// failed one, not a local-only error or ephemeral row), it is shown in the
/// channel (not a thread-only reply, which a channel page never carries), and
/// it falls inside the window the page covers — anywhere, when the page
/// reaches the channel's start; strictly after the page's oldest message
/// otherwise. Nothing outside that window is judged.
Set<String> loopStaleLocalMessageIds({
  required Iterable<Message> local,
  required List<Message> serverPage,
  required bool reachesChannelStart,
}) {
  final serverIds = <String>{for (final message in serverPage) message.id};
  DateTime? oldest;
  for (final message in serverPage) {
    final at = message.createdAt;
    if (oldest == null || at.isBefore(oldest)) oldest = at;
  }
  if (!reachesChannelStart && oldest == null) return const <String>{};
  final stale = <String>{};
  for (final message in local) {
    if (serverIds.contains(message.id)) continue;
    if (!_serverAccepted(message)) continue;
    if (message.parentId != null && message.showInChannel != true) continue;
    if (!reachesChannelStart && !message.createdAt.isAfter(oldest!)) continue;
    stale.add(message.id);
  }
  return stale;
}

bool _serverAccepted(Message message) {
  final state = message.state;
  if (state.isOutgoing || state.isFailed) return false;
  return message.type != MessageType.ephemeral &&
      message.type != MessageType.error;
}

/// Removes, from one conversation on this device, the messages the server
/// deleted while this device was not listening (S253 · decision 0216).
///
/// Stream's own catch-up (`client.sync` on reconnect) replays only the events
/// since its last sync mark, and applies a delete only to messages loaded in
/// memory unless the event says `hard_delete`. Messages that were hard-deleted
/// on the server and sat outside the loaded window — or whose events were
/// replayed before the channel was held — stay in the local copy for good: on
/// the 2026-10-19 staging device, 13 of 20 deleted messages in one community
/// room survived every restart and reconnect, and only clearing the App's data
/// removed them.
///
/// This compares the conversation's local copy (memory and the offline store)
/// with the server's newest page and drops what the server no longer has,
/// from memory and from the store. It runs when a conversation opens and when
/// the connection comes back. Concurrent requests for one conversation share
/// one read.
final class LoopStreamDeletedMessageReconciler {
  LoopStreamDeletedMessageReconciler({
    required this.client,
    LoopStreamServerMessagePage? serverPage,
    this.pageSize = loopStreamReconcilePageSize,
  }) : _serverPage = serverPage ?? _defaultServerPage(client),
       _readsOverSocket = serverPage == null;

  final StreamChatClient client;
  final int pageSize;
  final LoopStreamServerMessagePage _serverPage;

  /// The production read goes over the client's own connection, so it is
  /// only attempted while that connection is up; the next recovery asks again.
  final bool _readsOverSocket;
  final Map<String, Future<Set<String>>> _inFlight =
      <String, Future<Set<String>>>{};

  static LoopStreamServerMessagePage _defaultServerPage(
    StreamChatClient client,
  ) => (channel, limit) async {
    final state = await client.queryChannel(
      channel.type,
      channelId: channel.id,
      messagesPagination: PaginationParams(limit: limit),
    );
    return state.messages ?? const <Message>[];
  };

  /// Reconciles [channel] and returns the ids it removed. A failed read
  /// removes nothing and is not an error: the copy stays as it was.
  Future<Set<String>> reconcile(Channel channel) {
    final cid = channel.cid;
    if (cid == null || channel.id == null || channel.state == null) {
      return Future<Set<String>>.value(const <String>{});
    }
    if (_readsOverSocket &&
        client.wsConnectionStatus != ConnectionStatus.connected) {
      return Future<Set<String>>.value(const <String>{});
    }
    final active = _inFlight[cid];
    if (active != null) return active;
    final run = _reconcile(channel, cid).whenComplete(() {
      // A block, not an arrow: the arrow would hand `whenComplete` the removed
      // Future — this one — and it would wait on itself forever.
      _inFlight.remove(cid);
    });
    _inFlight[cid] = run;
    return run;
  }

  Future<Set<String>> _reconcile(Channel channel, String cid) async {
    try {
      // The local copy is taken before the server is asked, so a message
      // that arrives while the read is in flight is never judged by it.
      final local = <String, Message>{
        for (final message in await _persisted(cid)) message.id: message,
        for (final message in channel.state?.messages ?? const <Message>[])
          message.id: message,
      };
      if (local.isEmpty) return const <String>{};
      final page = await _serverPage(channel, pageSize);
      final stale = loopStaleLocalMessageIds(
        local: local.values,
        serverPage: page,
        reachesChannelStart: page.length < pageSize,
      );
      if (stale.isEmpty) return const <String>{};
      final state = channel.state;
      if (state != null) {
        final held = state.messages.where((m) => stale.contains(m.id));
        for (final message in held.toList()) {
          state.removeMessage(message);
        }
      }
      final persistence = client.chatPersistenceClient;
      if (persistence != null && persistence.isConnected) {
        final ids = stale.toList();
        await persistence.deleteMessageByIds(ids);
        await persistence.deletePinnedMessageByIds(ids);
      }
      if (kDebugMode) {
        debugPrint('LOOP reconcile: $cid dropped ${stale.length} deleted');
      }
      return stale;
    } catch (error) {
      if (kDebugMode) debugPrint('LOOP reconcile: $cid skipped · $error');
      return const <String>{};
    }
  }

  Future<List<Message>> _persisted(String cid) async {
    final persistence = client.chatPersistenceClient;
    if (persistence == null || !persistence.isConnected) {
      return const <Message>[];
    }
    try {
      return await persistence.getMessagesByCid(cid);
    } catch (_) {
      return const <Message>[];
    }
  }
}

final Expando<LoopStreamDeletedMessageReconciler> _reconcilers =
    Expando<LoopStreamDeletedMessageReconciler>('loop-stream-reconciler');

/// The one reconciler for [client], so every surface showing a conversation
/// shares its single-flight read.
LoopStreamDeletedMessageReconciler loopStreamDeletedMessageReconcilerFor(
  StreamChatClient client,
) =>
    _reconcilers[client] ??= LoopStreamDeletedMessageReconciler(client: client);
