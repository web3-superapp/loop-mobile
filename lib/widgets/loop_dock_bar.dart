import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:loop_mobile/core/haptics/loop_haptics.dart';
import 'package:loop_mobile/core/theme/loop_motion.dart';

/// How one cell of a [LoopDockBar] is drawn at this moment.
///
/// [scale] multiplies the cell's glyph; [shift] moves the glyph's centre
/// sideways so that magnified neighbours make room for each other. Neither
/// touches the cell's own box: the tap target is the same equal-width cell
/// whatever the finger is doing.
@immutable
class LoopDockCell {
  const LoopDockCell({this.scale = 1, this.shift = 0});

  static const LoopDockCell rest = LoopDockCell();

  final double scale;
  final double shift;

  bool get atRest => scale == 1 && shift == 0;
}

/// A row of equal-width cells that magnify under a sliding finger
/// (decision 0096).
///
/// A tap is the cell's own: nothing grows, the cell's handler runs as before.
/// A press that slides sideways — or a press held until it becomes a long
/// press and then slides — magnifies the glyphs by their distance to the
/// finger ([LoopDockBar.scaleAt]); the glyphs make room for each other by
/// weight, so the row's width never changes; and lifting the finger selects
/// the cell it is over. With motion reduced nothing magnifies, and the slide
/// still selects where it ends.
///
/// The cells are laid out by the row, not by the magnification: [LoopDockCell]
/// only moves and scales what a cell paints, so the hit area of every cell
/// stays its equal share of the width.
class LoopDockBar extends StatefulWidget {
  const LoopDockBar({
    required this.count,
    required this.onSelect,
    required this.cellBuilder,
    super.key,
    this.selectedIndex,
    this.backgroundBuilder,
  });

  final int count;

  /// The cell currently selected; a slide ending on it does not select again.
  final int? selectedIndex;

  /// Called with the cell under the finger when a slide ends.
  final ValueChanged<int> onSelect;

  /// Builds cell [index]; the row gives it an equal share of the width.
  final Widget Function(BuildContext context, int index, LoopDockCell cell)
  cellBuilder;

  /// Painted under the cells, sized to the row, given every cell's state.
  final Widget Function(BuildContext context, List<LoopDockCell> cells)?
  backgroundBuilder;

  /// The glyph scale at [distance] cells from the finger: a Gaussian in
  /// cells, `1 + (peak − 1) · 3^(−d²)`, so the finger's cell is at
  /// [LoopMotion.dockPeakScale], its neighbours at
  /// [LoopMotion.dockNeighbourScale], and anything [LoopMotion.dockReach]
  /// cells away or more at rest.
  static double scaleAt(double distance) {
    final d = distance.abs();
    if (d >= LoopMotion.dockReach) return 1;
    return 1 + (LoopMotion.dockPeakScale - 1) * math.pow(3, -d * d);
  }

  /// Every cell's state for a finger at [fingerX] (in the row's own
  /// coordinates) over a row [width] wide, at [strength] of the full
  /// magnification (0 = rest, 1 = full).
  ///
  /// Each cell's visual width is its scale's share of the row, so a grown
  /// glyph pushes its neighbours aside and the row's edges stay where they
  /// are; [LoopDockCell.shift] is how far that moves the cell's centre from
  /// its laid-out centre.
  static List<LoopDockCell> layout({
    required int count,
    required double width,
    required double? fingerX,
    required double strength,
  }) {
    if (count <= 0) return const <LoopDockCell>[];
    if (fingerX == null || strength <= 0 || width <= 0) {
      return List<LoopDockCell>.filled(count, LoopDockCell.rest);
    }
    final cellWidth = width / count;
    // The finger's position in cells, measured from the first cell's centre.
    final finger = fingerX / cellWidth - 0.5;
    final scales = <double>[
      for (var index = 0; index < count; index += 1)
        1 + (scaleAt(index - finger) - 1) * strength,
    ];
    final total = scales.fold<double>(0, (sum, scale) => sum + scale);
    final cells = <LoopDockCell>[];
    var start = 0.0;
    for (var index = 0; index < count; index += 1) {
      final visual = width * scales[index] / total;
      final centre = start + visual / 2;
      start += visual;
      cells.add(
        LoopDockCell(
          scale: scales[index],
          shift: centre - (index + 0.5) * cellWidth,
        ),
      );
    }
    return cells;
  }

  @override
  State<LoopDockBar> createState() => _LoopDockBarState();
}

class _LoopDockBarState extends State<LoopDockBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _strength = AnimationController(
    vsync: this,
    duration: LoopMotion.dockEngage,
    reverseDuration: LoopMotion.dockRelease,
  )..addListener(_repaint);

  /// The finger, in the row's coordinates, while a slide is under way; kept
  /// through the release so the glyphs settle from where they were.
  double? _fingerX;
  bool _sliding = false;

  /// Where the current pointer went down, for telling a tap from a slide
  /// when it lifts.
  Offset? _downAt;

  @override
  void dispose() {
    _strength.dispose();
    super.dispose();
  }

  void _repaint() => setState(() {});

  void _begin(Offset local) {
    _sliding = true;
    setState(() => _fingerX = local.dx);
    if (LoopMotion.reduced(context)) {
      _strength.value = 0;
    } else {
      _strength.forward();
    }
  }

  void _move(Offset local) {
    if (!_sliding) return;
    setState(() => _fingerX = local.dx);
  }

  void _end(double width) {
    if (!_sliding) return;
    _sliding = false;
    final x = _fingerX;
    if (x != null && width > 0) {
      final index = (x / (width / widget.count)).floor().clamp(
        0,
        widget.count - 1,
      );
      if (index != widget.selectedIndex) {
        LoopHaptics.selection();
        widget.onSelect(index);
      }
    }
    _settle();
  }

  /// Decision 0130: switching tabs is a selection, and a tap switches tabs
  /// as well as a slide does. The tap itself belongs to the cell (the shell
  /// owns what a cell does), so the bar answers it from the pointer: a lift
  /// that did not travel, over a cell that is not the selected one, while no
  /// slide is under way. A slide is answered in [_end] instead, once.
  void _pointerUp(PointerUpEvent event, double width) {
    final down = _downAt;
    _downAt = null;
    if (down == null || _sliding || width <= 0) return;
    if ((event.localPosition - down).distance > kTouchSlop) return;
    final index = (event.localPosition.dx / (width / widget.count))
        .floor()
        .clamp(0, widget.count - 1);
    if (index != widget.selectedIndex) LoopHaptics.selection();
  }

  void _cancel() {
    if (!_sliding) return;
    _sliding = false;
    _settle();
  }

  void _settle() {
    if (LoopMotion.reduced(context)) {
      _strength.value = 0;
      setState(() => _fingerX = null);
      return;
    }
    _strength.reverse().whenCompleteOrCancel(() {
      if (mounted && !_sliding) setState(() => _fingerX = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final strength = LoopMotion.reduced(context)
            ? 0.0
            : LoopMotion.dockCurve.transform(_strength.value);
        final cells = LoopDockBar.layout(
          count: widget.count,
          width: width,
          fingerX: _fingerX,
          strength: strength,
        );
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) => _downAt = event.localPosition,
          onPointerCancel: (_) => _downAt = null,
          onPointerUp: (event) => _pointerUp(event, width),
          child: RawGestureDetector(
            // The slide is a pointer affordance on top of five buttons that
            // each carry their own semantics; announcing the row as scrollable
            // would be a second, wrong description of it.
            excludeFromSemantics: true,
            behavior: HitTestBehavior.translucent,
            gestures: <Type, GestureRecognizerFactory>{
              HorizontalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    HorizontalDragGestureRecognizer
                  >(() => HorizontalDragGestureRecognizer(debugOwner: this), (
                    recognizer,
                  ) {
                    recognizer
                      ..dragStartBehavior = DragStartBehavior.down
                      ..onStart = (details) {
                        _begin(details.localPosition);
                      }
                      ..onUpdate = (details) {
                        _move(details.localPosition);
                      }
                      ..onEnd = (_) {
                        _end(width);
                      }
                      ..onCancel = _cancel;
                  }),
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer
                  >(() => LongPressGestureRecognizer(debugOwner: this), (
                    recognizer,
                  ) {
                    recognizer
                      ..onLongPressStart = (details) {
                        _begin(details.localPosition);
                      }
                      ..onLongPressMoveUpdate = (details) {
                        _move(details.localPosition);
                      }
                      ..onLongPressEnd = (_) {
                        _end(width);
                      }
                      ..onLongPressCancel = _cancel;
                  }),
            },
            child: Stack(
              children: <Widget>[
                if (widget.backgroundBuilder != null)
                  Positioned.fill(
                    child: widget.backgroundBuilder!(context, cells),
                  ),
                Row(
                  children: <Widget>[
                    for (var index = 0; index < widget.count; index += 1)
                      Expanded(
                        child: widget.cellBuilder(context, index, cells[index]),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
