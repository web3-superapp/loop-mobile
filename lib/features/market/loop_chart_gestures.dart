import 'package:flutter/gestures.dart';

// ---------------------------------------------------------------------------
// The chart's gesture arbitration (decision 0135)
// ---------------------------------------------------------------------------
//
// The token chart lives inside a vertically scrolling page (`token`, the MEME
// detail) and alone on `chart-full`. One finger on it can mean two things:
// "move the window" (horizontal) or "scroll the page" (vertical). A plain
// `ScaleGestureRecognizer` only claims a touch after 36 pt of travel in any
// direction, while the page's vertical drag claims it after 18 pt of
// vertical travel — so on a phone, where a sideways swipe always drifts a
// little, the page won nearly every time and the inline chart could not be
// panned (audit 2026-10-09 m6).
//
// [LoopChartScaleGestureRecognizer] decides the direction itself, at the
// touch slop, from where the finger went down:
//
// * horizontal travel past the slop, and more horizontal than vertical: the
//   chart claims the touch (pan, then pinch if a second finger joins);
// * vertical travel past the slop, and at least as vertical as horizontal:
//   the chart withdraws, so the page's own drag takes the touch unopposed;
// * a second finger before either: a pinch, the chart claims it.
//
// A touch that lands while the page is still coasting from a fling never
// reaches the chart: `Scrollable` ignores pointers in its content during a
// ballistic scroll, so that touch only stops the page.

/// A scale recognizer that claims horizontal and two-finger touches and
/// gives vertical ones to the enclosing scrollable.
class LoopChartScaleGestureRecognizer extends ScaleGestureRecognizer {
  LoopChartScaleGestureRecognizer({super.debugOwner});

  final Map<int, Offset> _origins = <int, Offset>{};
  bool _decided = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _origins[event.pointer] = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (!_decided && event is PointerMoveEvent && _origins.length == 1) {
      final origin = _origins[event.pointer];
      if (origin != null) {
        final travel = event.position - origin;
        final slop = computeHitSlop(event.kind, gestureSettings);
        final dx = travel.dx.abs();
        final dy = travel.dy.abs();
        if (dx > slop && dx > dy) {
          _decided = true;
          resolve(GestureDisposition.accepted);
        } else if (dy > slop && dy >= dx) {
          _decided = true;
          // Rejecting stops tracking every pointer; there is nothing left
          // for the scale recognizer to do with this event.
          resolve(GestureDisposition.rejected);
          return;
        }
      }
    }
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _origins.remove(event.pointer);
    }
    if (!_decided && event is PointerDownEvent && _origins.length >= 2) {
      _decided = true;
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _origins.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _origins.clear();
    _decided = false;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  String get debugDescription => 'loop chart scale';
}
