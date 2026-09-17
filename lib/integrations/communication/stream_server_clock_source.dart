import 'dart:async';

import 'package:loop_mobile/core/time/loop_server_clock.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Reads the servers' clock off the messages Stream delivers.
///
/// [LoopServerClock] needs to know how far the device clock has drifted from
/// the servers'. The most accurate reading LOOP has is the answer to its own
/// send — the round trip is measured, so the server instant can be paired with
/// the middle of it — but that only arrives once the member has sent
/// something. Until then, every message arriving in a watched channel carries
/// the instant the servers filed it at, which is a reading of the same clock
/// one network hop old.
///
/// A delivery delay makes this reading *early*, never late — including the
/// large delay of a message replayed after a reconnect — so it goes in
/// through [LoopServerClock.observeAtLeast], which lets it raise the offset
/// and never lower it.
///
/// `Message.remoteCreatedAt` is used rather than `Event.createdAt` because the
/// latter falls back to the device clock when a payload omits the field
/// (`stream_chat-10.3.0/lib/src/core/models/event.dart:53`), which would read
/// as "no drift" and quietly undo a good observation.
StreamSubscription<Event> loopWatchStreamServerClock(
  StreamChatClient client, {
  LoopServerClock? clock,
}) {
  final target = clock ?? LoopServerClock.instance;
  return client
      .on(EventType.messageNew, EventType.notificationMessageNew)
      .listen((event) {
        final serverTime = event.message?.remoteCreatedAt;
        if (serverTime == null) return;
        target.observeAtLeast(serverTime: serverTime, at: target.deviceNow());
      });
}
