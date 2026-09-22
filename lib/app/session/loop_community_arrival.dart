import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this account has arrived in Community in this run.
///
/// Decision 0076: the notification permission is asked for on that arrival —
/// after the five-step opening, or straight away on a restored session —
/// rather than the instant the backend accepts the account, which lands the
/// system dialog on top of 创建钱包.
///
/// An arrival is two facts, and neither is enough on its own:
///
/// * the account **belongs** in Community, which is the landing
///   `GET /v2/profile` published. Not a route location: a deep link into a
///   conversation is an arrival too, and a location string would miss it.
/// * a product frame has been **drawn**. The landing is published before the
///   navigation it causes — the opening publishes it and then goes, a
///   restored session publishes it and lets the launch gate refresh the
///   router — so acting on it alone raises the dialog over the page the
///   owner is still looking at.
///
/// Either can happen first. The arrival is the moment the second one does.
final class LoopCommunityArrivalController extends Notifier<bool> {
  var _landing = false;
  var _drawn = false;

  @override
  bool build() => false;

  /// The profile read says this account belongs in Community.
  bool landed() => _mark(landing: true);

  /// A product frame is on screen. Reported by the shell every page under it
  /// is drawn in, so it is true for the tab and for anything deep inside it.
  bool productDrawn() => _mark(drawn: true);

  /// Answers whether this call is the one that completed the arrival, so the
  /// one action bound to it — asking the device about notifications — happens
  /// once and not again on every return to the tab.
  bool _mark({bool landing = false, bool drawn = false}) {
    if (state) return false;
    _landing = _landing || landing;
    _drawn = _drawn || drawn;
    if (!_landing || !_drawn) return false;
    state = true;
    return true;
  }

  /// Leaving the account takes the arrival with it: the next account on this
  /// device has not been anywhere yet.
  void leave() {
    _landing = false;
    _drawn = false;
    if (state) state = false;
  }
}

final loopCommunityArrivalProvider =
    NotifierProvider<LoopCommunityArrivalController, bool>(
      LoopCommunityArrivalController.new,
    );

/// Reports the frame a product page was actually drawn in.
///
/// It wraps the one shell every tab and every page under it is built in, and
/// says so once, after the first frame that contains it. Nothing else in LOOP
/// may claim that a page is on screen: a router location changes a whole
/// frame earlier, inside the listener that caused it.
class LoopProductFrameReporter extends StatefulWidget {
  const LoopProductFrameReporter({
    required this.onDrawn,
    required this.child,
    super.key,
  });

  final VoidCallback onDrawn;
  final Widget child;

  @override
  State<LoopProductFrameReporter> createState() =>
      _LoopProductFrameReporterState();
}

class _LoopProductFrameReporterState extends State<LoopProductFrameReporter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDrawn();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
