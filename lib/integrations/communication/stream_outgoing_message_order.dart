import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:loop_mobile/core/time/loop_server_clock.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Keeps a message the device has just sent at the newest end of its channel,
/// whatever the device clock says.
///
/// C-31 on the device: a member whose phone clock runs slow sends a message
/// and it appears above the history instead of below it, then jumps down a
/// moment later. The list is ordered by `Message.createdAt`, and for a message
/// that has not reached the server yet that is `localCreatedAt`, which
/// `Channel.sendMessage` stamps with the device clock
/// (`stream_chat-10.3.0/lib/src/client/channel.dart:776`) and does not let the
/// caller set. A phone two hours behind therefore files its own new message
/// two hours into the past, which is where the list draws it.
///
/// The fix is in two layers and this is the second one — the invariant:
///
///  * a message this device has sent and the server has not yet confirmed is
///    always stamped after every message the channel already knows about, so
///    it can only be drawn last;
///  * two such messages keep the order they were sent in;
///  * when the server confirms one, its own `remote_created_at` replaces the
///    stamp — the real order is the server's to state, not LOOP's.
///
/// The first layer ([LoopServerClock]) makes the stamp itself close to the
/// server's clock, so that replacement moves nothing on screen and the
/// timestamp printed under the bubble is the time the servers will agree on.
///
/// Only `remoteCreatedAt` is written, and it is not part of the message's JSON
/// (`@JsonKey(includeToJson: false)`), so nothing invented here is ever sent
/// to Stream. A resend still routes on `MessageState`
/// (`Channel.retryMessage`), not on this field.
class LoopOutgoingMessageOrder {
  LoopOutgoingMessageOrder({required Channel channel, LoopServerClock? clock})
    // The fields are private, so an initializing formal would leak the
    // underscore into the constructor's public parameter name.
    // ignore: prefer_initializing_formals
    : _channel = channel,
      _clock = clock ?? LoopServerClock.instance;

  /// The smallest gap the list can order two messages by.
  static const _tick = Duration(milliseconds: 1);

  final Channel _channel;
  final LoopServerClock _clock;

  /// The stamp this keeper has given each unconfirmed message, so a later
  /// pass re-states the same answer instead of walking the message forward
  /// every time the channel changes.
  final Map<String, DateTime> _stamped = <String, DateTime>{};

  /// The order the unconfirmed messages were first seen in, which is the
  /// order they were sent in.
  final Map<String, int> _sequence = <String, int>{};
  int _nextSequence = 0;

  StreamSubscription<List<Message>>? _subscription;
  bool _writing = false;

  /// Starts watching the channel. Safe to call twice.
  ///
  /// Attach before the message list subscribes to the same state, so a
  /// correction lands in the same microtask drain as the change that caused
  /// it and no frame is ever painted with the message in the wrong place.
  void attach() {
    if (_subscription != null) return;
    final state = _channel.state;
    if (state == null) return;
    reconcile(state.messages);
    _subscription = state.messagesStream.listen(reconcile);
  }

  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _stamped.clear();
    _sequence.clear();
  }

  /// Re-states the stamps for [messages] and writes back the ones that moved.
  @visibleForTesting
  void reconcile(List<Message> messages) {
    if (_writing) return;
    final corrections = _corrections(messages);
    if (corrections.isEmpty) return;
    final state = _channel.state;
    if (state == null) return;
    _writing = true;
    try {
      for (final message in corrections) {
        state.updateMessage(message);
      }
    } finally {
      _writing = false;
    }
  }

  List<Message> _corrections(List<Message> messages) {
    final pending = <Message>[];
    DateTime? known;
    for (final message in messages) {
      if (_isUnconfirmedOutgoing(message)) {
        pending.add(message);
        continue;
      }
      final createdAt = message.createdAt.toUtc();
      if (known == null || createdAt.isAfter(known)) known = createdAt;
    }

    _forget(pending.map((message) => message.id).toSet());
    if (pending.isEmpty) return const <Message>[];

    for (final message in pending) {
      _sequence.putIfAbsent(message.id, () => _nextSequence++);
    }
    pending.sort((a, b) => _sequence[a.id]!.compareTo(_sequence[b.id]!));

    final corrections = <Message>[];
    var floor = known;
    for (final message in pending) {
      var stamp = _stamped[message.id];
      // A stamp stays put unless it no longer sits after everything the
      // channel knows — history that arrived late, or the message sent just
      // before this one.
      if (stamp == null || (floor != null && !stamp.isAfter(floor))) {
        stamp = _clock.nowUtc();
        if (floor != null && !stamp.isAfter(floor)) stamp = floor.add(_tick);
      }
      _stamped[message.id] = stamp;
      floor = stamp;
      if (message.createdAt.toUtc() != stamp) {
        corrections.add(message.copyWith(createdAt: stamp));
      }
    }
    return corrections;
  }

  void _forget(Set<String> stillPending) {
    _stamped.keys.toList().forEach((id) {
      if (!stillPending.contains(id)) _stamped.remove(id);
    });
    _sequence.keys.toList().forEach((id) {
      if (!stillPending.contains(id)) _sequence.remove(id);
    });
  }

  /// A message this device is still trying to deliver.
  ///
  /// The state is the whole test. `remoteCreatedAt == null` reads like the
  /// more direct question — has the server stated a time for this? — but this
  /// keeper writes that field itself, so a message it had already stamped
  /// would answer "yes" and stop being watched. `MessageState.sending` and
  /// `sendingFailed` are set by `Channel.sendMessage` and nothing else, and
  /// are replaced by the server's own state on the answer.
  ///
  /// An edit (`updating`) is deliberately not included: re-stating an old
  /// message does not move it to the end of the room.
  static bool _isUnconfirmedOutgoing(Message message) =>
      message.state.isSending || message.state.isSendingFailed;
}
