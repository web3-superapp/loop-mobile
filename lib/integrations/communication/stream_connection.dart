import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// A chat read that needed the provider's websocket and never got one.
///
/// The SDK refuses a channel query while it has no live socket
/// (`stream_chat-10.3.0/lib/src/client/client.dart:890`) by throwing a bare
/// `StreamChatError`. That is neither a transport failure nor a server answer,
/// so it used to land in whatever branch the caller had left over. It is its
/// own fact: nothing was asked, and the way to ask is to open the socket
/// first.
class LoopStreamNotConnected implements Exception {
  const LoopStreamNotConnected([this.cause]);

  /// What the attempt to open the socket failed with, when it failed at all.
  /// `null` means the attempt finished without an error and the socket was
  /// still not up.
  final Object? cause;

  @override
  String toString() => 'LoopStreamNotConnected($cause)';
}

/// The two websocket facts a LOOP chat read depends on.
///
/// Narrow on purpose: it is the seam an acceptance test stands in for, and it
/// keeps [loopStreamConnectedRead] free of the SDK's client.
abstract interface class LoopStreamConnection {
  /// Whether the provider's socket is up right now.
  bool get isConnected;

  /// Opens the socket. Completing does not promise [isConnected]; the caller
  /// reads that back.
  Future<void> open();
}

/// [LoopStreamConnection] over the official client.
///
/// `maybeReconnect` is the SDK's own foreground path
/// (`stream_chat_flutter_core-10.3.0/lib/src/stream_chat_core.dart:391`): it
/// drops any pending retry delay and opens a new socket, so a member who has
/// just regained network does not wait out a 25 s backoff.
class LoopStreamClientConnection implements LoopStreamConnection {
  const LoopStreamClientConnection(this.client);

  final StreamChatClient client;

  @override
  bool get isConnected =>
      client.wsConnectionStatus == ConnectionStatus.connected;

  @override
  Future<void> open() => client.maybeReconnect();
}

/// Runs [read] over a live websocket, opening one first when there is none.
///
/// Device report 2026-09-19 · F1: after the OS closed the socket behind a
/// backgrounded app, every retry re-ran the same query against the same dead
/// socket and produced the same error — restoring the network changed nothing,
/// and only backgrounding the app again (which makes the SDK reconnect on
/// resume) let the member in. A retry has to reconnect before it re-reads.
///
/// The connection is read back after the attempt rather than trusted from it:
/// the SDK's own lifecycle observer may be opening the same socket at the same
/// instant, in which case our `openConnection` throws "connection already in
/// progress" while the socket it complains about is the one we wanted.
Future<T> loopStreamConnectedRead<T>(
  LoopStreamConnection connection,
  Future<T> Function() read,
) async {
  if (!connection.isConnected) {
    Object? failure;
    try {
      await connection.open();
    } on Object catch (error) {
      failure = error;
    }
    if (!connection.isConnected) throw LoopStreamNotConnected(failure);
  }
  return read();
}
