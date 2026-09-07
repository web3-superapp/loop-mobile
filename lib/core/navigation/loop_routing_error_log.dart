import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One recorded navigation to a location that is not part of the product map.
@immutable
final class LoopRoutingError {
  const LoopRoutingError({
    required this.location,
    required this.fallback,
    required this.recordedAt,
  });

  /// The requested location, exactly as the router received it.
  final String location;

  /// The safe location the router landed on instead.
  final String fallback;

  final DateTime recordedAt;

  @override
  String toString() =>
      'LoopRoutingError($location -> $fallback @ ${recordedAt.toIso8601String()})';
}

/// In-memory routing error journal.
///
/// The frozen prototype silently ignores unknown hashes. Production must record
/// every illegal route and return to the safe entry (`/community`) instead of
/// leaving a control without feedback. Entries stay in process memory and are
/// mirrored to the debug console; nothing is persisted or transmitted.
final class LoopRoutingErrorLog {
  LoopRoutingErrorLog({DateTime Function()? clock, this.capacity = 64})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Maximum retained entries; the oldest entry is dropped first.
  final int capacity;

  final List<LoopRoutingError> _entries = <LoopRoutingError>[];

  List<LoopRoutingError> get entries =>
      List<LoopRoutingError>.unmodifiable(_entries);

  LoopRoutingError? get last => _entries.isEmpty ? null : _entries.last;

  /// Records [location] and returns [fallback] so the router redirect can
  /// `return log.record(...)` in one expression.
  String record(String location, {String fallback = '/community'}) {
    final error = LoopRoutingError(
      location: location,
      fallback: fallback,
      recordedAt: _clock(),
    );
    _entries.add(error);
    if (_entries.length > capacity) _entries.removeAt(0);
    if (kDebugMode) {
      debugPrint('LOOP routing error: $error');
    }
    return fallback;
  }

  void clear() => _entries.clear();
}

/// Application-wide routing error journal.
final loopRoutingErrorLogProvider = Provider<LoopRoutingErrorLog>(
  (ref) => LoopRoutingErrorLog(),
);
