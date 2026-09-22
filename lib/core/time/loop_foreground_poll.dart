import 'dart:async';

import 'package:flutter/widgets.dart';

/// Runs one read on a fixed interval, for exactly as long as a page is on
/// screen and LOOP is in front of the reader.
///
/// Most of LOOP reads once and says when it read. A few facts are about what
/// two people are doing at the same moment — a room that has just opened, the
/// people inside it, a hand somebody raised — and a page that read them once
/// stands there saying something that stopped being true while the reader
/// watched. On the review devices that was every one of them: the second phone
/// never saw the room, the host never saw the listener arrive and never saw
/// the hand.
///
/// The rules this holds to:
///
/// * it starts when the page asks and stops on [stop], which a page calls from
///   its own teardown — a poll that outlives the page is a request nobody is
///   waiting for;
/// * it stops while LOOP is not in the foreground, and reads once on the way
///   back, so a phone in a pocket makes no requests and a reader who comes
///   back is not shown the moment they left;
/// * it never runs two reads at once, and a read that takes longer than the
///   interval simply delays the next one.
final class LoopForegroundPoll with WidgetsBindingObserver {
  LoopForegroundPoll({required this.interval, required this.read});

  /// How long after one read finishes the next one starts.
  final Duration interval;

  /// The read itself. It owns its own failure: a poll never reports one,
  /// because the page already shows what it last read successfully.
  final Future<void> Function() read;

  Timer? _timer;
  var _running = false;
  var _reading = false;
  var _foreground = true;

  /// Whether a read is on its way out right now. Visible for tests.
  bool get isReading => _reading;

  /// Whether the interval is armed. Visible for tests.
  bool get isRunning => _running && _timer != null;

  void start() {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground =
        lifecycle == null ||
        lifecycle == AppLifecycleState.resumed ||
        lifecycle == AppLifecycleState.inactive;
    if (_foreground) _arm();
  }

  void stop() {
    if (!_running) return;
    _running = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Reads now, and starts the next interval from this read.
  ///
  /// A page uses it when something told it the answer changed — a provider
  /// event, a command it just sent — so the interval is the floor of how
  /// stale a page can be, never the speed at which it answers.
  void readNow() {
    if (!_running || !_foreground) return;
    unawaited(_tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (!_running) return;
    if (!foreground) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    // Back in front of the reader: the page is showing the moment it left.
    unawaited(_tick());
  }

  void _arm() {
    _timer?.cancel();
    _timer = Timer(interval, () => unawaited(_tick()));
  }

  Future<void> _tick() async {
    if (!_running || !_foreground) return;
    if (_reading) return;
    _reading = true;
    try {
      await read();
    } catch (_) {
      // The read states its own failure where the reader can see it, or keeps
      // what the page already has. A poll never raises one of its own.
    } finally {
      _reading = false;
      if (_running && _foreground) _arm();
    }
  }
}
