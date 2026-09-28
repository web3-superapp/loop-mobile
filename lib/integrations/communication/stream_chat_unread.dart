import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/integrations/communication/stream_chat_providers.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// The reader's total unread message count across every Stream conversation,
/// or null when this client has no source for it (decision 0105 · 6).
///
/// The count is Stream's own `total_unread_count`, kept current by the events
/// the already-connected Chat client receives; nothing here opens a
/// connection or asks the server. Until that client is connected — no
/// session, signed out, reconnecting, a Preview build — there is no count, and
/// null is what every badge draws as nothing: a zero nobody counted is not
/// shown and a stale number is not kept.
final streamChatUnreadTotalProvider = StreamProvider<int?>((ref) {
  final session = ref.watch(streamChatSdkSessionProvider);
  if (session == null) return Stream<int?>.value(null);
  final client = session.client;
  return loopStreamUnreadTotal(
    initialStatus: client.wsConnectionStatus,
    status: client.wsConnectionStatusStream,
    initialTotal: client.state.totalUnreadCount,
    total: client.state.totalUnreadCountStream,
  );
});

/// Combines the socket state and Stream's running total into one reading:
/// the total while the socket is connected, null otherwise.
Stream<int?> loopStreamUnreadTotal({
  required ConnectionStatus initialStatus,
  required Stream<ConnectionStatus> status,
  required int initialTotal,
  required Stream<int> total,
}) {
  late final StreamController<int?> controller;
  StreamSubscription<ConnectionStatus>? statusSubscription;
  StreamSubscription<int>? totalSubscription;
  var connected = initialStatus == ConnectionStatus.connected;
  var latest = initialTotal;
  int? last;
  var emitted = false;

  void emit() {
    final value = connected ? latest : null;
    if (emitted && value == last) return;
    emitted = true;
    last = value;
    controller.add(value);
  }

  controller = StreamController<int?>(
    onListen: () {
      emit();
      statusSubscription = status.listen((next) {
        connected = next == ConnectionStatus.connected;
        emit();
      });
      totalSubscription = total.listen((next) {
        latest = next;
        emit();
      });
    },
    onCancel: () async {
      await statusSubscription?.cancel();
      await totalSubscription?.cancel();
    },
  );
  return controller.stream;
}
