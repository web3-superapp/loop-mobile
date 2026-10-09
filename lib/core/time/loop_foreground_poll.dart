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
/// * it stops while the page is covered — another page pushed over it, or its
///   tab put behind another tab — and starts its interval again when the page
///   is uncovered (decision 0125: a community page left under a chat or a
///   room kept asking for the room every five seconds, nobody looking);
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
  var _visible = true;

  /// Whether the page that owns this poll is the one the reader sees: its
  /// route is the top one and its subtree is not an offstage tab. Calling
  /// this from `build` makes the page rebuild when either changes, so a page
  /// passes the answer straight to [setVisible].
  static bool pageVisible(BuildContext context) {
    final routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    return routeCurrent && TickerMode.valuesOf(context).enabled;
  }

  /// Whether the interval is held because the page is covered. Visible for
  /// tests.
  bool get isVisible => _visible;

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
    if (_foreground && _visible) _arm();
  }

  /// Tells the poll whether its page can be seen. Covered, the interval is
  /// dropped; uncovered, the interval starts again from that moment.
  ///
  /// Uncovering does not read at once: a sheet or a dialog the page opened
  /// covers it too, and what the page does when that closes — the command the
  /// sheet confirmed, the answer it brought back — is the page's to read, not
  /// a poll's to race. The next read is one interval away, as it was before
  /// the page was covered.
  ///
  /// It may be called from `build`; it only arms or drops a timer.
  void setVisible(bool visible) {
    if (visible == _visible) return;
    _visible = visible;
    if (!_running) return;
    if (!visible) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_foreground && !_reading) _arm();
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
    if (!_active) return;
    unawaited(_tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground =
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (!_running || !_visible) return;
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

  bool get _active => _running && _foreground && _visible;

  Future<void> _tick() async {
    if (!_active) return;
    if (_reading) return;
    _reading = true;
    try {
      await read();
    } catch (_) {
      // The read states its own failure where the reader can see it, or keeps
      // what the page already has. A poll never raises one of its own.
    } finally {
      _reading = false;
      if (_active) _arm();
    }
  }
}
