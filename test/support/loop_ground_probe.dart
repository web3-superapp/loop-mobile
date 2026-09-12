import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// What a subtree actually paints, and what it painted it on.
///
/// The palette's soft tokens are Chalk at a low alpha, so "invisible" is not a
/// property of a colour — it is a property of a colour *and its ground*. A
/// probe that walks the mounted tree carrying the ground is therefore the only
/// thing that can state the question the way the bug happens: this widget, on
/// this card, disappears.
@immutable
final class LoopPaintedColour {
  const LoopPaintedColour({
    required this.colour,
    required this.ground,
    required this.kind,
    required this.where,
  });

  /// The colour as it was handed to the painter, before compositing.
  final Color colour;

  /// The opaque colour underneath it.
  final Color ground;

  /// `text`, `glyph`, `fill` or `edge`.
  final String kind;

  /// Enough of the widget to find it again.
  final String where;

  /// [colour] composited over [ground].
  Color get composited => loopCompositeOver(colour, ground);

  /// How far the composite moved the ground, on its furthest channel, in the
  /// familiar 0–255 scale. Zero means the paint changed nothing at all.
  double get groundDelta => loopGroundDelta(colour, ground);

  /// WCAG relative-luminance contrast of the composite against the ground.
  double get contrast => loopContrastRatio(colour, ground);

  @override
  String toString() =>
      '$kind ${_hex(colour)} on ${_hex(ground)} '
      '(delta ${groundDelta.toStringAsFixed(1)}, '
      'contrast ${contrast.toStringAsFixed(2)}) · $where';
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}';

/// `src-over`: [source] painted onto the opaque [ground].
Color loopCompositeOver(Color source, Color ground) {
  final a = source.a;
  return Color.from(
    alpha: 1,
    red: source.r * a + ground.r * (1 - a),
    green: source.g * a + ground.g * (1 - a),
    blue: source.b * a + ground.b * (1 - a),
  );
}

/// The furthest channel [source] moves [ground], scaled to 0–255.
double loopGroundDelta(Color source, Color ground) {
  final result = loopCompositeOver(source, ground);
  return math.max(
        (result.r - ground.r).abs(),
        math.max((result.g - ground.g).abs(), (result.b - ground.b).abs()),
      ) *
      255;
}

double _channel(double value) => value <= 0.03928
    ? value / 12.92
    : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _channel(color.r) +
    0.7152 * _channel(color.g) +
    0.0722 * _channel(color.b);

/// WCAG contrast of [source] composited over [ground], against [ground].
double loopContrastRatio(Color source, Color ground) {
  final a = _luminance(loopCompositeOver(source, ground)) + 0.05;
  final b = _luminance(ground) + 0.05;
  return a > b ? a / b : b / a;
}

Color? _decorationFill(Decoration decoration) {
  if (decoration is! BoxDecoration) return null;
  final gradient = decoration.gradient;
  if (gradient is LinearGradient && gradient.colors.isNotEmpty) {
    return gradient.colors.first;
  }
  return decoration.color;
}

/// Every colour the subtree under [root] paints, paired with its ground.
///
/// The walk carries two things down: the nearest opaque ground, recomputed
/// whenever a box paints a fill, and the accumulated [Opacity] factor, because
/// a layer at 66% is exactly as capable of erasing a hairline as a low alpha
/// is. Gradients contribute their first stop; a fully transparent colour is
/// deliberate absence and is not reported.
List<LoopPaintedColour> loopProbeGround(Element root, Color ground) {
  final found = <LoopPaintedColour>[];

  void visit(Element element, Color currentGround, double opacity) {
    var childGround = currentGround;
    var childOpacity = opacity;
    final widget = element.widget;

    Color scaled(Color colour) => childOpacity >= 0.999
        ? colour
        : colour.withValues(alpha: colour.a * childOpacity);

    void record(Color colour, String kind) {
      if (colour.a <= 0) return;
      found.add(
        LoopPaintedColour(
          colour: scaled(colour),
          ground: childGround,
          kind: kind,
          where: widget.toStringShort(),
        ),
      );
    }

    if (widget is Opacity) {
      childOpacity *= widget.opacity;
    } else if (widget is ColoredBox) {
      record(widget.color, 'fill');
      childGround = loopCompositeOver(scaled(widget.color), childGround);
    } else if (widget is Material && widget.color != null) {
      record(widget.color!, 'fill');
      childGround = loopCompositeOver(scaled(widget.color!), childGround);
    } else if (widget is DecoratedBox) {
      final fill = _decorationFill(widget.decoration);
      if (fill != null) {
        record(fill, 'fill');
        childGround = loopCompositeOver(scaled(fill), childGround);
      }
      final decoration = widget.decoration;
      if (decoration is BoxDecoration) {
        final border = decoration.border;
        if (border != null) {
          for (final side in <BorderSide>{
            border.top,
            border.bottom,
            if (border is Border) ...<BorderSide>{border.left, border.right},
          }) {
            if (side.style == BorderStyle.none) continue;
            record(side.color, 'edge');
          }
        }
      }
    } else if (widget is Text) {
      final resolved = DefaultTextStyle.of(element).style
          .merge(widget.style)
          .color;
      if (resolved != null) record(resolved, 'text');
    } else if (widget is LoopIcon) {
      final resolved =
          widget.color ?? IconTheme.of(element).color ?? LoopColors.chalk;
      record(resolved, 'glyph');
    }

    element.visitChildren((child) => visit(child, childGround, childOpacity));
  }

  visit(root, ground, 1);
  return found;
}

/// Assert that nothing the subtree paints vanished into [ground].
///
/// Two floors, because two different things are being asked. Copy and glyphs
/// have to be *read*, so they take a contrast ratio. A fill or a hairline only
/// has to be *seen*, and the palette's own hairline on the Ink page is a
/// 31/255 move, so a floor of three says "this paint did something" without
/// inventing a stricter design than the prototype's.
void loopExpectVisibleOnGround(
  WidgetTester tester, {
  required Finder subtree,
  required Color ground,
  double textContrast = 2.5,
  double markDelta = 3,
  Iterable<String> exempt = const <String>[],
}) {
  final probes = loopProbeGround(tester.element(subtree), ground);
  expect(probes, isNotEmpty, reason: 'the probe found nothing to check');
  final vanished = <LoopPaintedColour>[];
  for (final probe in probes) {
    if (exempt.contains(probe.where)) continue;
    final ok = probe.kind == 'text' || probe.kind == 'glyph'
        ? probe.contrast >= textContrast
        : probe.groundDelta >= markDelta;
    if (!ok) vanished.add(probe);
  }
  expect(
    vanished,
    isEmpty,
    reason:
        'painted on ${_hex(ground)} but not there:\n'
        '${vanished.map((probe) => '  $probe').join('\n')}',
  );
}
