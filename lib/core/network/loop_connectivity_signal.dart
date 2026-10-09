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

/// A counter that moves once each time the device may have come back online:
/// the radio reported a transport again, or the App returned to the
/// foreground (decision 0123).
///
/// It is a re-arm signal only. A read that already failed listens to it and
/// asks again; a read that succeeded ignores it. Nothing reads the value as
/// evidence that LOOP is reachable.
class LoopNetworkRecoveryTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final loopNetworkRecoveryTickProvider =
    NotifierProvider<LoopNetworkRecoveryTick, int>(LoopNetworkRecoveryTick.new);

/// Whether the signed-in session is waiting for the network before Privy can
/// confirm it (decision 0123).
///
/// Privy publishes `AuthenticatedUnverified` when it restores a stored
/// session with no network — a cold start, or Android restarting the process
/// while the radio was down. LOOP then holds no access token, so nothing
/// provider-backed can be read, but nothing was refused either: blocks say
/// 离线 and wait, never 不可用. The App shell keeps this flag in step with the
/// session; its default is `false`, so a surface built without the shell
/// behaves exactly as before.
class LoopSessionAwaitingNetwork extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

final loopSessionAwaitingNetworkProvider =
    NotifierProvider<LoopSessionAwaitingNetwork, bool>(
      LoopSessionAwaitingNetwork.new,
    );
