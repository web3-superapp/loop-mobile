import 'package:loop_mobile/core/cache/loop_snapshot_store.dart';

/// The last few answers of a read that is keyed by subject — one community,
/// one conversation — kept in memory for [LoopSnapshotPolicy.memoryRetention]
/// (decision 0101).
///
/// `loopRetainRead` keeps a whole provider alive, which is right for a read
/// with one answer per account. A page that shows one subject at a time on a
/// shared controller needs the answer per subject instead: going back to a
/// community drew a skeleton and paid a round trip for a record the device
/// had read seconds earlier.
///
/// Memory only. The owner scopes an instance to one account, so an answer is
/// never shown to another one.
final class LoopRecentAnswers<K, V> {
  LoopRecentAnswers({this.capacity = 16}) : assert(capacity > 0);

  final int capacity;

  // Insertion order doubles as recency: a hit is moved to the end.
  final Map<K, ({V value, DateTime readAt})> _entries =
      <K, ({V value, DateTime readAt})>{};

  /// The answer for [key] read at most [LoopSnapshotPolicy.memoryRetention]
  /// before [now], or `null`.
  ({V value, DateTime readAt})? lookup(K key, DateTime now) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    if (now.difference(entry.readAt) > LoopSnapshotPolicy.memoryRetention) {
      return null;
    }
    _entries[key] = entry;
    return entry;
  }

  void remember(K key, V value, DateTime readAt) {
    _entries.remove(key);
    _entries[key] = (value: value, readAt: readAt);
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void forget(K key) => _entries.remove(key);

  int get length => _entries.length;
}
