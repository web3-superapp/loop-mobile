import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/integrations/backend/loop_backend_providers.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta_repository.dart';

final loopV2MetaRepositoryProvider = Provider<LoopV2MetaRepository?>((ref) {
  final endpoint = ref.watch(loopBackendEndpointProvider);
  if (endpoint == null) return null;

  final repository = DioLoopV2MetaRepository(origin: endpoint.uri);
  ref.onDispose(repository.close);
  return repository;
});

/// Reads both public D0 resources concurrently as one immutable observation.
///
/// The provider itself still installs no automatic retry, and none of the
/// returned states is mapped onto an application gate here. In particular,
/// unavailable/deferred policy or pending provider evidence stays visible to
/// the owning product boundary. Re-arming a *failed* observation is owned by
/// [LoopV2MetaObserver], which drives this provider from the outside.
final loopV2MetaSnapshotProvider =
    FutureProvider.autoDispose<LoopV2MetaSnapshot?>((ref) async {
      final repository = ref.watch(loopV2MetaRepositoryProvider);
      if (repository == null) return null;

      final values = await Future.wait<Object>(<Future<Object>>[
        repository.getClientPolicy(),
        repository.getCapabilities(),
      ]);
      return LoopV2MetaSnapshot(
        clientPolicy: values[0] as LoopV2ClientPolicy,
        capabilities: values[1] as LoopV2Capabilities,
      );
    }, retry: (retryCount, error) => null);

/// Why a D0 observation was started. Recorded for tests and diagnostics only;
/// every trigger runs the same single request pair.
enum LoopV2MetaObservationTrigger {
  coldStart,
  backoffRetry,
  connectivityRestored,
  appResumed,
  navigation,
}

/// Keeps the D0 observation alive across a cold start that hit a dead network.
///
/// Decision 0064. The observation stays exactly what decision 0050 and the D0
/// contract made it — non-blocking, unauthenticated, with no Bearer or
/// `X-Loop-*` header, and unable to gate login or routing. The only change is
/// that a *failed* read is retried instead of being frozen until the next cold
/// start:
///
/// * cold start once, exactly as before;
/// * on failure, up to [maxRetries] retries at 1s → 2s → 4s → 8s → 16s;
/// * one attempt when the radio comes back, when the app returns to the
///   foreground, and when the owner navigates while the document is missing.
///
/// Every trigger is single-flight: it is ignored while a read is in flight and
/// while a backoff retry is already scheduled, so no burst of triggers can
/// multiply requests. A *completed* observation — including the "no backend
/// endpoint is configured" answer — is never re-read; only a failed one is.
final class LoopV2MetaObserver {
  LoopV2MetaObserver(this._ref);

  final Ref _ref;

  static const maxRetries = 5;

  static const retryBackoff = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
  ];

  Timer? _retryTimer;
  var _consecutiveFailures = 0;
  var _inFlight = false;
  var _disposed = false;
  LoopV2MetaObservationTrigger? _lastTrigger;

  /// How many consecutive failures the current ladder has recorded.
  int get consecutiveFailures => _consecutiveFailures;

  /// Whether a backoff retry is already waiting.
  bool get isRetryScheduled => _retryTimer != null;

  /// Whether a read is currently in flight.
  bool get isObserving => _inFlight;

  /// The ladder ran out; only an external trigger can start a new one.
  bool get isExhausted =>
      _consecutiveFailures >= maxRetries && _retryTimer == null && !_inFlight;

  LoopV2MetaObservationTrigger? get lastTrigger => _lastTrigger;

  /// Called for every state the observation publishes.
  void onObservation(AsyncValue<LoopV2MetaSnapshot?> observation) {
    if (_disposed) return;
    if (observation.isLoading) {
      _inFlight = true;
      return;
    }
    _inFlight = false;
    if (!observation.hasError) {
      _consecutiveFailures = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    if (_consecutiveFailures >= maxRetries) return;
    final delay = retryBackoff[_consecutiveFailures];
    _consecutiveFailures += 1;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      _start(LoopV2MetaObservationTrigger.backoffRetry);
    });
  }

  /// One external trigger. Ignored unless the last observation failed and no
  /// read or scheduled retry is already covering it.
  void observe(LoopV2MetaObservationTrigger trigger) {
    if (_disposed || _inFlight || _retryTimer != null) return;
    if (!_ref.read(loopV2MetaSnapshotProvider).hasError) return;
    _consecutiveFailures = 0;
    _start(trigger);
  }

  void _start(LoopV2MetaObservationTrigger trigger) {
    if (_disposed) return;
    _inFlight = true;
    _lastTrigger = trigger;
    // Invalidate *and* read back: the observation must run now, not when some
    // later reader happens to arrive.
    _ref.invalidate(loopV2MetaSnapshotProvider);
    _ref.read(loopV2MetaSnapshotProvider);
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
  }
}

/// Owns the D0 observation lifecycle. Reading it starts the cold-start read.
final loopV2MetaObserverProvider = Provider<LoopV2MetaObserver>((ref) {
  final observer = LoopV2MetaObserver(ref);
  ref.onDispose(observer.dispose);
  ref.listen<AsyncValue<LoopV2MetaSnapshot?>>(
    loopV2MetaSnapshotProvider,
    (previous, next) => observer.onObservation(next),
    fireImmediately: true,
  );
  return observer;
});
