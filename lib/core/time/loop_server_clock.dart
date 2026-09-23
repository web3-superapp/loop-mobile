/// The clock LOOP reads when a timestamp has to agree with the servers.
///
/// A phone's clock is user-writable. A member who moves it back a day does
/// not expect the app to re-file their own actions a day into the past, and a
/// message they just sent still belongs at the bottom of the conversation
/// (C-31). `DateTime.now()` cannot answer that, so every surface that has to
/// agree with a server about *when* reads this clock instead.
///
/// The clock states no time of its own. It holds one offset — the difference
/// between an instant a server named and the device instant at which that
/// instant was observed — and applies it to the device clock. Until a server
/// has named an instant the offset is zero and the clock is the device clock,
/// which is exactly today's behaviour.
///
/// Sources of a server instant, in the order they arrive in a session:
///
///  * `remote_created_at` on a message arriving in a watched channel
///    (`stream_server_clock_source.dart`);
///  * `remote_created_at` on Stream's answer to LOOP's own send
///    (`loop_stream_channel_surface.dart`), which is the accurate one: the
///    round trip is measured, so the server instant is paired with its middle.
///
/// The HTTP `Date` header on every `/v2` response would be the cheapest and
/// most frequent source of all, but reading it needs a Dio interceptor, and
/// `check_harness.py` holds two rules that together forbid one here:
/// `LoopDioFactory` may import nothing but Dio, and no production interceptor
/// may live outside it. Enabling that source is a governance decision, not a
/// code change.
library;

/// The device clock corrected by the most recent server observation.
class LoopServerClock {
  LoopServerClock({DateTime Function()? deviceNow})
    : _deviceNow = deviceNow ?? DateTime.now;

  /// The clock the application reads.
  ///
  /// It is a single mutable field rather than an injected dependency because
  /// the surfaces that need it — a date separator, a message stamp — are
  /// leaf widgets deep inside the official Stream tree, with no seam to pass
  /// one through. A test replaces it in `setUp` and restores it in
  /// `tearDown`.
  static LoopServerClock instance = LoopServerClock();

  /// A round trip longer than this says nothing useful about the offset: the
  /// server instant could sit anywhere inside it. The observation is dropped
  /// rather than averaged into a worse answer.
  static const maxUsefulRoundTrip = Duration(seconds: 30);

  final DateTime Function() _deviceNow;

  Duration _offset = Duration.zero;
  bool _observed = false;

  /// Server time minus device time, as last observed. Zero until a server has
  /// named an instant.
  Duration get offset => _offset;

  /// Whether any server has named an instant in this session.
  bool get hasServerObservation => _observed;

  /// The device clock, uncorrected. Use it to measure durations, never to
  /// state an instant a server also has an opinion about.
  DateTime deviceNow() => _deviceNow();

  /// Now, in the servers' frame. Returns a UTC value: a corrected instant no
  /// longer belongs to the device's wall clock reading, and every server
  /// timestamp LOOP compares it against is UTC too.
  DateTime nowUtc() => _deviceNow().toUtc().add(_offset);

  /// Records that a server named [serverTime] during the round trip bracketed
  /// by [sentAt] and [receivedAt].
  ///
  /// The newest usable observation wins outright: an offset is not a
  /// measurement to average, it is a fact that changes the moment the member
  /// edits the device clock.
  void observe({
    required DateTime serverTime,
    required DateTime sentAt,
    DateTime? receivedAt,
  }) {
    final received = receivedAt ?? _deviceNow();
    if (received.isBefore(sentAt)) return;
    final roundTrip = received.difference(sentAt);
    if (roundTrip > maxUsefulRoundTrip) return;
    _offset = serverTime.toUtc().difference(sentAt.toUtc().add(roundTrip ~/ 2));
    _observed = true;
  }

  /// Records a server instant whose delivery delay is unknown — a message
  /// pushed over the socket, say, rather than the answer to a request this
  /// device timed.
  ///
  /// A late delivery can only make the server look *earlier* than it really
  /// is, which reads as a smaller offset. So this reading is allowed to raise
  /// the offset and never to lower it: a message replayed after a reconnect
  /// cannot drag the clock backwards. The bracketed [observe] — the answer to
  /// LOOP's own send — remains free to set any offset, including a smaller
  /// one, which is what corrects the clock if the member moves the device
  /// forward mid-session.
  ///
  /// The floor is the offset in force, including the zero this clock starts
  /// at. The first unbracketed reading used to be taken whatever it said, so
  /// one replayed message could set the offset to its own age: on 2026-09-23
  /// a message from two days earlier put "now" two days in the past and the
  /// day separator above it read 「今天」.
  void observeAtLeast({required DateTime serverTime, required DateTime at}) {
    final candidate = serverTime.toUtc().difference(at.toUtc());
    if (candidate <= _offset) return;
    _offset = candidate;
    _observed = true;
  }

  /// Forgets the observation. Used when a session ends and by tests.
  void reset() {
    _offset = Duration.zero;
    _observed = false;
  }
}
