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

/// How long one D0 answer is served without asking again (decision 0098).
///
/// The two documents change on operator action, not per request, and every
/// round trip from a phone costs 0.5–2.3 s through the tunnel. Inside this
/// window a page change reads the answer this process already holds; after it
/// the next trigger re-reads in the background while the old answer stays on
/// screen.
abstract final class LoopV2MetaCachePolicy {
  static const freshFor = Duration(seconds: 60);
}

/// The clock the D0 cache measures [LoopV2MetaCachePolicy.freshFor] against.
final loopV2MetaClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The last D0 answer this process received, and when (decision 0098).
///
/// It holds only successful observations: a failed read stores nothing, so a
/// failure is never served from here and the retry ladder of decision 0064
/// still owns it. It is in memory only; the cold-start snapshot store of
/// decision 0095 does not carry D0 documents.
///
/// Reads are single-flight: a second reader while a read is running joins it.
final class LoopV2MetaCache {
  LoopV2MetaCache(this._repository, {required this._now});

  final LoopV2MetaRepository _repository;
  final DateTime Function() _now;

  LoopV2MetaSnapshot? _value;
  DateTime? _observedAt;
  Future<LoopV2MetaSnapshot>? _inFlight;

  /// The answer on hand, fresh or not.
  LoopV2MetaSnapshot? get value => _value;

  /// When this device received [value].
  DateTime? get observedAt => _observedAt;

  /// Whether a read would be answered without a request.
  bool get isFresh {
    final at = _observedAt;
    return _value != null &&
        at != null &&
        _now().difference(at) < LoopV2MetaCachePolicy.freshFor;
  }

  /// There is an answer, and it is old enough to be asked again.
  bool get isStale => _value != null && !isFresh;

  /// Marks the answer on hand as old, so the next read asks the server.
  ///
  /// The answer itself stays: a page keeps drawing it until a new one lands.
  void expire() => _observedAt = null;

  /// The answer on hand when it is fresh, otherwise both documents re-read
  /// concurrently.
  Future<LoopV2MetaSnapshot> read() {
    final value = _value;
    if (value != null && isFresh) {
      return Future<LoopV2MetaSnapshot>.value(value);
    }
    final active = _inFlight;
    if (active != null) return active;
    late final Future<LoopV2MetaSnapshot> operation;
    operation = _fetch().whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  Future<LoopV2MetaSnapshot> _fetch() async {
    final values = await Future.wait<Object>(<Future<Object>>[
      _repository.getClientPolicy(),
      _repository.getCapabilities(),
    ]);
    final snapshot = LoopV2MetaSnapshot(
      clientPolicy: values[0] as LoopV2ClientPolicy,
      capabilities: values[1] as LoopV2Capabilities,
    );
    _value = snapshot;
    _observedAt = _now();
    return snapshot;
  }
}

/// One cache per backend origin; `null` when no backend is configured.
final loopV2MetaCacheProvider = Provider<LoopV2MetaCache?>((ref) {
  final repository = ref.watch(loopV2MetaRepositoryProvider);
  if (repository == null) return null;
  return LoopV2MetaCache(repository, now: ref.watch(loopV2MetaClockProvider));
});

/// Reads both public D0 resources concurrently as one immutable observation.
///
/// The provider itself still installs no automatic retry, and none of the
/// returned states is mapped onto an application gate here. In particular,
/// unavailable/deferred policy or pending provider evidence stays visible to
/// the owning product boundary. Re-arming a *failed* observation, and
/// re-reading one older than [LoopV2MetaCachePolicy.freshFor], is owned by
/// [LoopV2MetaObserver], which drives this provider from the outside.
///
/// The request pair itself runs in [LoopV2MetaCache]; rebuilding this provider
/// inside the freshness window costs no request (decision 0098).
final loopV2MetaSnapshotProvider =
    FutureProvider.autoDispose<LoopV2MetaSnapshot?>((ref) async {
      final cache = ref.watch(loopV2MetaCacheProvider);
      if (cache == null) return null;
      return cache.read();
    }, retry: (retryCount, error) => null);

/// Whether the last D0 observation failed, i.e. LOOP was not reached.
///
/// It is a status, not the document: it carries no capability, no policy, no
/// reason code and no identity, and it starts no request of its own. It exists
/// so a surface can tell "the client never got an answer" apart from "LOOP
/// answered and closed this capability" — two facts with two different next
/// steps that must never share a sentence.
final loopV2MetaUnreachableProvider = Provider<bool>(
  (ref) => ref.watch(loopV2MetaSnapshotProvider).hasError,
);

/// Why a D0 observation was started. Recorded for tests and diagnostics only;
/// every trigger runs the same single request pair.
enum LoopV2MetaObservationTrigger {
  coldStart,
  backoffRetry,
  connectivityRestored,
  appResumed,
  navigation,

  /// The owner pressed 重试 on a page that could not be read.
  ownerRetry,

  /// A caller about to act on a capability asked for the server's current
  /// answer rather than the one on hand (decision 0098).
  forcedRefresh,
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
/// endpoint is configured" answer — is not re-read while it is younger than
/// [LoopV2MetaCachePolicy.freshFor]. Decision 0098: once it is older, the same
/// triggers re-read it in the background (stale-while-revalidate). The old
/// answer stays observable for the whole read, and a new answer replaces it
/// the moment it lands — including one that closes a capability.
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

  /// One external trigger. Ignored unless the last observation failed, or
  /// succeeded longer than [LoopV2MetaCachePolicy.freshFor] ago, and no read
  /// or scheduled retry is already covering it.
  void observe(LoopV2MetaObservationTrigger trigger) {
    if (_disposed || _inFlight || _retryTimer != null) return;
    final observation = _ref.read(loopV2MetaSnapshotProvider);
    if (observation.hasError) {
      _consecutiveFailures = 0;
      _start(trigger);
      return;
    }
    if (observation.isLoading) return;
    if (_ref.read(loopV2MetaCacheProvider)?.isStale != true) return;
    // Decision 0098: the answer on hand is kept while the new one is read.
    // Triggers may arrive from a router redirect, so the provider is touched
    // after the current frame's synchronous work rather than inside it.
    _inFlight = true;
    _lastTrigger = trigger;
    scheduleMicrotask(() {
      if (_disposed) return;
      _ref.invalidate(loopV2MetaSnapshotProvider);
      _ref.read(loopV2MetaSnapshotProvider);
    });
  }

  /// Reads both documents again now, whatever the age of the answer on hand.
  ///
  /// The entry for a caller about to act on a capability — a signature, a
  /// write — that wants the server's current answer instead of one up to
  /// [LoopV2MetaCachePolicy.freshFor] old. The answer on hand stays
  /// observable until the new one lands. A read already in flight is joined,
  /// not doubled. A failed forced read leaves the old answer in place and
  /// hands the failure to the retry ladder, exactly like any other failure;
  /// the old answer is not marked fresh again by it.
  Future<void> refreshNow() async {
    if (_disposed) return;
    if (!_inFlight) {
      final cache = _ref.read(loopV2MetaCacheProvider);
      if (cache == null) return;
      cache.expire();
      _retryTimer?.cancel();
      _retryTimer = null;
      _consecutiveFailures = 0;
      _start(LoopV2MetaObservationTrigger.forcedRefresh);
    }
    try {
      await _ref.read(loopV2MetaSnapshotProvider.future);
    } on Object {
      // The observation publishes what it answered.
    }
  }

  /// The owner asked for the read again, from a page that never reached LOOP.
  ///
  /// It differs from [observe] in exactly two ways, both of which follow from
  /// a person having pressed a button. It is awaitable, so the page can show
  /// that a read is running instead of looking inert; and it does not stand
  /// down for a scheduled backoff — the owner asked now, so the pending wait
  /// is cancelled and the ladder starts over from the first rung.
  ///
  /// Everything else is unchanged. It stays single-flight, because a read
  /// already in flight is the read that was asked for. It refuses to touch a
  /// *completed* observation, so a gate the server closed can never be retried
  /// into a different answer, and no capability, policy or reason code is
  /// derived here.
  Future<void> retryObservation() async {
    if (_disposed || _inFlight) return;
    if (!_ref.read(loopV2MetaSnapshotProvider).hasError) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    _consecutiveFailures = 0;
    _start(LoopV2MetaObservationTrigger.ownerRetry);
    try {
      await _ref.read(loopV2MetaSnapshotProvider.future);
    } on Object {
      // The observation publishes what it answered. The caller only needs to
      // know that the read finished.
    }
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
