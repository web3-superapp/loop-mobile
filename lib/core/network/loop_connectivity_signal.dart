import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A narrow "the radio came back" trigger.
///
/// It reports one thing only: the device went from reporting no transport to
/// reporting one. It is never evidence that a service is reachable, that a
/// request will succeed, or that LOOP is offline — the platform radio state
/// cannot prove any of that, and no product surface may derive an outage from
/// it. Its single use is to re-arm reads that already failed.
abstract interface class LoopConnectivitySignal {
  Stream<void> get onRestored;
}

/// The `connectivity_plus` adapter.
///
/// The first platform event is deliberately not filtered out: a cold start on
/// a working network emits one "restored" tick, which every consumer already
/// de-duplicates through its own single-flight guard.
final class ConnectivityPlusSignal implements LoopConnectivitySignal {
  ConnectivityPlusSignal({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool hasTransport(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  @override
  Stream<void> get onRestored {
    late final Stream<List<ConnectivityResult>> events;
    try {
      events = _connectivity.onConnectivityChanged;
    } on Object {
      // A host without the plugin registered simply never restores.
      return const Stream<void>.empty();
    }
    return events
        .map(hasTransport)
        .handleError((Object _) {})
        .distinct()
        .where((connected) => connected)
        .map((_) {});
  }
}

final loopConnectivitySignalProvider = Provider<LoopConnectivitySignal>(
  (ref) => ConnectivityPlusSignal(),
);
