import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

/// Where one sender stands in a channel's member lookup.
///
/// Every status but [found] draws the neutral 「成员」, but they are different
/// facts and the directory keeps them apart: [unrequested] and [pending] have
/// not been answered yet, [absent] was answered — Stream holds no current
/// membership for that id in this channel — and [unavailable] is a lookup
/// that failed as many times as it may and will not be asked again.
enum LoopGroupMemberLookupStatus {
  unrequested,
  pending,
  found,
  absent,
  unavailable,
}

/// Reads the current [Member] rows of one channel for exactly [userIds].
///
/// The answer is filtered on the Stream user id, never on a name: a LOOP
/// account's `User.name` is its id, and an Alias is not a Stream field.
typedef LoopGroupMemberLookup = Future<List<Member>> Function(
  List<String> userIds,
);

/// The members of one group channel its loaded roster does not carry.
///
/// Stream loads a bounded slice of a channel's members with the channel — the
/// membership query that mounts a conversation asks for 100 at most — and a
/// community channel has hundreds. A sender outside that slice had no member
/// row to read an Alias from, so every one of them read as 「成员」 with 「成」
/// on the avatar (device report 2026-09-29 · S102, decision 0107).
///
/// This directory asks Stream for those rows by id: the ids a visible message
/// needs are collected, deduplicated, debounced and sent in batches of at most
/// [batchSize]. What comes back is a [Member] exactly like the loaded ones and
/// goes through the same fail-closed projection check — the directory stores
/// rows, never names. A failed batch is retried after each of [retryDelays]
/// and then given up on for the life of the directory, so a broken read never
/// becomes a request loop.
final class LoopGroupMemberDirectory extends ChangeNotifier {
  LoopGroupMemberDirectory({
    required this._lookup,
    bool Function()? canLookup,
    this.debounce = const Duration(milliseconds: 200),
    this.retryDelays = const <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 8),
    ],
    this.batchSize = 50,
  }) : assert(batchSize > 0 && batchSize <= 100, 'Stream answers ≤100 rows'),
       _canLookup = canLookup ?? _always;

  static bool _always() => true;

  static final Expando<LoopGroupMemberDirectory> _byChannel =
      Expando<LoopGroupMemberDirectory>('loopGroupMemberDirectory');

  /// The one directory for [channel], created on first use.
  ///
  /// It lives as long as the [Channel] object does — the client keeps one per
  /// CID for the session — so a second visit to the same room re-uses what
  /// the first one learned. It asks only over a connected websocket: a lookup
  /// that cannot reach Stream has not answered anything and is not counted as
  /// a failure.
  static LoopGroupMemberDirectory forChannel(Channel channel) {
    final existing = _byChannel[channel];
    if (existing != null) return existing;
    final directory = LoopGroupMemberDirectory(
      lookup: (userIds) async {
        final response = await channel.queryMembers(
          filter: Filter.in_('id', userIds),
          pagination: PaginationParams(limit: userIds.length),
        );
        return response.members;
      },
      canLookup: () =>
          channel.client.wsConnectionStatus == ConnectionStatus.connected,
    );
    directory._events = channel
        .on(
          EventType.memberAdded,
          EventType.memberUpdated,
          EventType.memberRemoved,
        )
        .listen(directory.observe, onError: (Object _) {});
    _byChannel[channel] = directory;
    return directory;
  }

  /// Installs [directory] for [channel] in place of the Stream-backed one.
  @visibleForTesting
  static void debugInstall(
    Channel channel,
    LoopGroupMemberDirectory directory,
  ) {
    _byChannel[channel] = directory;
  }

  final LoopGroupMemberLookup _lookup;
  final bool Function() _canLookup;

  /// How long ids are collected before one batch leaves.
  final Duration debounce;

  /// The wait before each retry of a failed batch. Its length is the number
  /// of retries; after the last one the ids are [LoopGroupMemberLookupStatus.unavailable].
  final List<Duration> retryDelays;

  /// The most ids one request carries.
  final int batchSize;

  final Map<String, List<Member>> _found = <String, List<Member>>{};
  final Set<String> _absent = <String>{};
  final Set<String> _unavailable = <String>{};
  final Set<String> _queued = <String>{};
  final Set<String> _inFlight = <String>{};
  final Set<String> _retrying = <String>{};
  final Map<String, int> _failures = <String, int>{};
  final Set<Timer> _retryTimers = <Timer>{};
  Timer? _flushTimer;
  StreamSubscription<Event>? _events;
  bool _disposed = false;

  /// Where [userId] stands. See [LoopGroupMemberLookupStatus].
  LoopGroupMemberLookupStatus statusOf(String userId) {
    if (_found.containsKey(userId)) return LoopGroupMemberLookupStatus.found;
    if (_absent.contains(userId)) return LoopGroupMemberLookupStatus.absent;
    if (_unavailable.contains(userId)) {
      return LoopGroupMemberLookupStatus.unavailable;
    }
    if (_queued.contains(userId) ||
        _inFlight.contains(userId) ||
        _retrying.contains(userId)) {
      return LoopGroupMemberLookupStatus.pending;
    }
    return LoopGroupMemberLookupStatus.unrequested;
  }

  /// The roster a group channel names people from.
  ///
  /// [loaded] — the channel's own current member list — always wins. The
  /// reader's own [membership] row joins it when the loaded slice left the
  /// reader out, and then every row this directory found for an id neither
  /// carries. An id appears once per source only, so the resolver's
  /// duplicate rule keeps meaning "Stream answered twice", not "LOOP merged
  /// twice".
  List<Member> roster(Iterable<Member> loaded, {Member? membership}) {
    final result = List<Member>.of(loaded);
    final covered = <String>{for (final member in result) ?_memberId(member)};
    final ownId = membership == null ? null : _memberId(membership);
    if (membership != null && ownId != null && covered.add(ownId)) {
      result.add(membership);
    }
    _found.forEach((userId, members) {
      if (!covered.contains(userId)) result.addAll(members);
    });
    return List<Member>.unmodifiable(result);
  }

  /// Asks for the member rows of [userIds] that nobody has asked for yet.
  ///
  /// Safe to call while building: it only records the ids and arms a timer,
  /// and it never notifies synchronously.
  void request(Iterable<String> userIds) {
    // Offline, nothing is queued and no timer is armed: an id stays
    // unrequested until a build over a live socket asks for it again.
    if (_disposed || !_canLookup()) return;
    var added = false;
    for (final userId in userIds) {
      if (userId.isEmpty || userId != userId.trim()) continue;
      if (statusOf(userId) != LoopGroupMemberLookupStatus.unrequested) {
        continue;
      }
      _queued.add(userId);
      added = true;
    }
    if (added) _scheduleFlush();
  }

  /// Applies a live membership event for this channel.
  ///
  /// A member who leaves stops being named at once; a member who joins or is
  /// updated replaces what the directory held, so a later message is named
  /// from the current row and not a remembered one.
  @visibleForTesting
  void observe(Event event) {
    if (_disposed) return;
    final member = event.member;
    final userId =
        (member == null ? null : _memberId(member)) ?? event.user?.id;
    if (userId == null || userId.isEmpty) return;
    switch (event.type) {
      case EventType.memberRemoved:
        _found.remove(userId);
        _unavailable.remove(userId);
        _absent.add(userId);
      case EventType.memberAdded || EventType.memberUpdated:
        if (member == null) return;
        _found[userId] = <Member>[member];
        _absent.remove(userId);
        _unavailable.remove(userId);
      default:
        return;
    }
    notifyListeners();
  }

  void _scheduleFlush() {
    if (_flushTimer != null || _queued.isEmpty) return;
    _flushTimer = Timer(debounce, _flush);
  }

  void _flush() {
    _flushTimer = null;
    if (_disposed || _queued.isEmpty) return;
    if (!_canLookup()) {
      // The socket went away inside the debounce. Nothing was asked, so
      // nothing failed: the ids go back to unrequested and the next build
      // that needs them asks again.
      _queued.clear();
      return;
    }
    final ids = List<String>.of(_queued);
    _queued.clear();
    for (var start = 0; start < ids.length; start += batchSize) {
      final end = start + batchSize < ids.length
          ? start + batchSize
          : ids.length;
      unawaited(_run(ids.sublist(start, end)));
    }
  }

  Future<void> _run(List<String> batch) async {
    _inFlight.addAll(batch);
    List<Member> answer;
    try {
      answer = await _lookup(List<String>.unmodifiable(batch));
    } on Object {
      _inFlight.removeAll(batch);
      if (_disposed) return;
      _fail(batch);
      notifyListeners();
      return;
    }
    _inFlight.removeAll(batch);
    if (_disposed) return;

    final wanted = batch.toSet();
    final byId = <String, List<Member>>{};
    for (final member in answer) {
      final userId = _memberId(member);
      // A row nobody asked for is not evidence about anybody.
      if (userId == null || !wanted.contains(userId)) continue;
      (byId[userId] ??= <Member>[]).add(member);
    }
    for (final userId in batch) {
      _failures.remove(userId);
      final rows = byId[userId];
      if (rows == null) {
        _absent.add(userId);
      } else {
        _found[userId] = List<Member>.unmodifiable(rows);
      }
    }
    notifyListeners();
  }

  void _fail(List<String> batch) {
    final retry = <String>[];
    var attempt = 0;
    for (final userId in batch) {
      final failures = (_failures[userId] ?? 0) + 1;
      _failures[userId] = failures;
      if (failures > retryDelays.length) {
        _unavailable.add(userId);
      } else {
        retry.add(userId);
        if (failures > attempt) attempt = failures;
      }
    }
    if (retry.isEmpty) return;
    _retrying.addAll(retry);
    late final Timer timer;
    timer = Timer(retryDelays[attempt - 1], () {
      _retryTimers.remove(timer);
      if (_disposed) return;
      _retrying.removeAll(retry);
      _queued.addAll(retry);
      _scheduleFlush();
    });
    _retryTimers.add(timer);
  }

  static String? _memberId(Member member) {
    final id = member.userId ?? member.user?.id;
    return id == null || id.isEmpty ? null : id;
  }

  @override
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    for (final timer in _retryTimers) {
      timer.cancel();
    }
    _retryTimers.clear();
    unawaited(_events?.cancel());
    _events = null;
    super.dispose();
  }
}
