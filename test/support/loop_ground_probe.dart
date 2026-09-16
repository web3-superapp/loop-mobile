import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_ui.dart';

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
    this.widgetName = '',
    this.site = '',
    this.inactive = false,
  });

  /// The colour as it was handed to the painter, before compositing.
  final Color colour;

  /// The opaque colour underneath it.
  final Color ground;

  /// `text`, `glyph`, `fill` or `edge`.
  final String kind;

  /// Enough of the widget to find it again: the nearest named ancestor, the
  /// widget itself and, for copy, the words on screen.
  final String where;

  /// The widget's own type name, with no ancestry and no content.
  final String widgetName;

  /// `owner · widget`: the painting site, stable across the words on screen.
  /// Exemptions are written against this, so an exempt entry names one place
  /// and not every widget of that type in the application.
  final String site;

  /// The application itself says this control is off, through the
  /// `Semantics(enabled: false)` it publishes to the accessibility tree.
  final bool inactive;

  /// [colour] composited over [ground].
  Color get composited => loopCompositeOver(colour, ground);

  /// How far the composite moved the ground, on its furthest channel, in the
  /// familiar 0–255 scale. Zero means the paint changed nothing at all.
  double get groundDelta => loopGroundDelta(colour, ground);

  /// WCAG relative-luminance contrast of the composite against the ground.
  double get contrast => loopContrastRatio(colour, ground);

  /// One defect, named once: the same colour on the same ground under the
  /// same widget is one finding however many rows of a list repeat it.
  String get signature => '$kind|${_hex(colour)}|${_hex(ground)}|$where';

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

/// What a box actually grounds its subtree in.
///
/// Flutter paints a [BoxDecoration]'s gradient *instead of* the colour
/// declared beside it, so a box that declares both grounds nothing but its
/// gradient. The probe has to read it the way the painter does, or a
/// near-transparent glow over an opaque colour reads here as the opaque
/// colour while on the device the page behind shows through.
Color? _decorationFill(Decoration decoration) {
  if (decoration is! BoxDecoration) return null;
  final gradient = decoration.gradient;
  if (gradient != null) {
    return gradient.colors.isEmpty ? decoration.color : gradient.colors.first;
  }
  return decoration.color;
}

/// Every colour the subtree under [root] paints, paired with its ground.
///
/// The walk carries four things down: the nearest opaque ground, recomputed
/// whenever a box paints a fill, the accumulated [Opacity] factor, because
/// a layer at 66% is exactly as capable of erasing a hairline as a low alpha
/// is, the settled colour of any implicit text animation overhead, so
/// that copy and the ground under it are read from the same end of a
/// transition, and an unspent [LoopSeam] claim. Gradients contribute their
/// first stop; a fully transparent colour is deliberate absence and is not
/// reported.
List<LoopPaintedColour> loopProbeGround(Element root, Color ground) {
  final found = <LoopPaintedColour>[];

  void visit(
    Element element,
    Color currentGround,
    double opacity,
    String owner,
    bool inactive,
    Color? settledInk,
    Color? animatedInk,
    bool seam,
  ) {
    var childGround = currentGround;
    var childOpacity = opacity;
    var childInactive = inactive;
    var childSettledInk = settledInk;
    var childSeam = seam;
    // Set for the immediate children of an `AnimatedDefaultTextStyle` only,
    // because the one widget it builds is the one carrying the frame's value.
    Color? childAnimatedInk;
    final widget = element.widget;
    final name = widget.runtimeType.toString();
    final childOwner = _isNamedOwner(name) ? name : owner;

    Color scaled(Color colour) => childOpacity >= 0.999
        ? colour
        : colour.withValues(alpha: colour.a * childOpacity);

    void record(Color colour, String kind, [String? detail]) {
      if (colour.a <= 0) return;
      final short = widget.toStringShort();
      found.add(
        LoopPaintedColour(
          colour: scaled(colour),
          ground: childGround,
          kind: kind,
          widgetName: name,
          site: owner.isEmpty ? short : '$owner · $short',
          inactive: childInactive,
          where: <String>[
            if (owner.isNotEmpty) owner,
            short,
            ?detail,
          ].join(' · '),
        ),
      );
    }

    if (widget is LoopSeam) {
      // The one claim a call site may make: "this mark is meant to match what
      // it lands on". It is carried down until the first bare border spends
      // it, and it is spent once — so it reaches the seam this widget draws
      // and nothing else in the subtree, however deep.
      childSeam = true;
    } else if (widget is Opacity) {
      childOpacity *= widget.opacity;
    } else if (widget is AnimatedDefaultTextStyle) {
      // The state the application declared, as opposed to the frame the
      // transition is currently on. `Material` drives its subtree's copy
      // through one of these while the probe reads its own `color` straight
      // off the widget, so without this a button caught mid-state-change
      // reads as the colour it is leaving on the ground it is arriving at —
      // two halves of two different states, and neither of them a state the
      // page is ever in.
      childAnimatedInk = widget.style.color;
    } else if (widget is DefaultTextStyle) {
      // The `DefaultTextStyle` an `AnimatedDefaultTextStyle` builds is that
      // animation's current frame, and it is the only one that inherits the
      // declared colour above it. Any other one states its colour outright,
      // so the settled colour stops here.
      childSettledInk = animatedInk;
    } else if (widget is Semantics) {
      // The application publishes "this control is off" to the accessibility
      // tree already; the probe reads the same statement rather than guessing
      // from a colour how faded is faded on purpose.
      childInactive = childInactive || widget.properties.enabled == false;
    } else if (widget is ColoredBox) {
      record(widget.color, 'fill');
      childGround = loopCompositeOver(scaled(widget.color), childGround);
    } else if (widget is Material && widget.color != null) {
      record(widget.color!, 'fill');
      childGround = loopCompositeOver(scaled(widget.color!), childGround);
    } else if (widget is Badge) {
      // `Badge` paints its own pill inside its render object rather than
      // through a box the walk can see, so without this its label reads as
      // painted on whatever is behind the badge. Take the colour the widget
      // declares, and fall back to the theme the way the widget itself does.
      final fill =
          widget.backgroundColor ??
          Theme.of(element).badgeTheme.backgroundColor ??
          Theme.of(element).colorScheme.error;
      record(fill, 'fill');
      childGround = loopCompositeOver(scaled(fill), childGround);
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
            // A border in the box's own fill colour is the box having no
            // border. It is not an edge that vanished; there is no edge.
            if (fill != null && side.color.toARGB32() == fill.toARGB32()) {
              continue;
            }
            // A seam, declared by the [LoopSeam] overhead: a border and
            // nothing but a border, whose job is to continue the surface
            // under it so that the shape above reads as separated. The claim
            // is spent here, so a second border deeper in the same subtree —
            // a divider that really did vanish — is judged as usual.
            if (seam && fill == null) {
              childSeam = false;
              continue;
            }
            record(side.color, 'edge');
          }
        }
      }
    } else if (widget is Text) {
      final resolved = DefaultTextStyle.of(element).style
          .merge(widget.style)
          .color;
      // A colour of its own is the widget's own statement and always wins;
      // otherwise a settled colour from overhead beats the frame's value, so
      // that the copy and the ground beside it are read from the same state.
      final colour = widget.style?.color ?? childSettledInk ?? resolved;
      if (colour != null) record(colour, 'text', _quote(widget.data));
    } else if (widget is LoopIcon) {
      final resolved =
          widget.color ?? IconTheme.of(element).color ?? LoopColors.chalk;
      record(resolved, 'glyph', widget.name);
    }

    element.visitChildren(
      (child) => visit(
        child,
        childGround,
        childOpacity,
        childOwner,
        childInactive,
        childSettledInk,
        childAnimatedInk,
        childSeam,
      ),
    );
  }

  visit(root, ground, 1, '', false, null, null, false);
  return found;
}

/// Widgets whose name is worth carrying down as "where this happened".
///
/// A page, a LOOP primitive and the route veil are names a reader can act on;
/// the framework's own boxes are not, and a breadcrumb made of `Padding`
/// locates nothing.
bool _isNamedOwner(String name) =>
    name.endsWith('Screen') ||
    name.endsWith('Sheet') ||
    name == 'ModalBarrier' ||
    (name.startsWith('Loop') && !name.startsWith('LoopColors'));

String? _quote(String? data) {
  if (data == null || data.isEmpty) return null;
  final trimmed = data.length > 24 ? '${data.substring(0, 24)}…' : data;
  return '「$trimmed」';
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
  final vanished = loopVanishedPaint(
    probes,
    textContrast: textContrast,
    markDelta: markDelta,
    exempt: exempt,
  );
  expect(
    vanished,
    isEmpty,
    reason:
        'painted on ${_hex(ground)} but not there:\n'
        '${vanished.map((probe) => '  $probe').join('\n')}',
  );
}

/// The paints that did not survive their ground.
///
/// One place decides what "not there" means, so the catalogue test, the
/// page-wide probe and any future caller all ask the same question. Two
/// floors, because two different things are being asked: copy and glyphs have
/// to be *read*, so they take a contrast ratio; a fill or a hairline only has
/// to be *seen*.
List<LoopPaintedColour> loopVanishedPaint(
  Iterable<LoopPaintedColour> probes, {
  double textContrast = 2.5,
  double markDelta = 3,
  Iterable<String> exempt = const <String>[],
}) {
  final vanished = <LoopPaintedColour>[];
  for (final probe in probes) {
    if (exempt.contains(probe.widgetName) ||
        exempt.contains(probe.site) ||
        exempt.contains(probe.where)) {
      continue;
    }
    if (loopGroundProbeExemptions.containsKey(probe.site)) continue;
    // An opaque fill repainted in the ground's own colour is the ground being
    // restated — the Scaffold under the page's own background, a section that
    // continues the surface it sits on. It hides nothing, because there is
    // nothing behind it but itself, and everything above it is then judged
    // against it. Only a *translucent* mark that moves the ground by nothing
    // is the bug this probe exists for.
    if (probe.kind == 'fill' && probe.colour.a >= 1 && probe.groundDelta == 0) {
      continue;
    }
    final copy = probe.kind == 'text' || probe.kind == 'glyph';
    // An inactive control is meant to recede: the application says so itself,
    // and WCAG 1.4.3 exempts an inactive component from the reading floor for
    // the same reason. It is still held to the mark floor, which is the floor
    // that catches Chalk painted on Chalk — so a control that is off may be
    // quiet, and still may not be absent.
    final ok = copy && !probe.inactive
        ? probe.contrast >= textContrast
        : probe.groundDelta >= markDelta;
    if (!ok) vanished.add(probe);
  }
  return vanished;
}

/// Paint the probe deliberately does not judge, keyed by `owner · widget`,
/// with the reason for each.
///
/// An entry here is a claim that the paint is *meant* to be at or below the
/// floor, not that the floor is too strict. Lowering a floor would silence the
/// next real bug with it; naming one site silences exactly that site.
///
/// All three entries are the same shape: a surface painted in the page's own
/// Ink, which cannot move a page that is already Ink. None of them is a mark
/// that was supposed to be seen.
const loopGroundProbeExemptions = <String, String>{
  'ModalBarrier · ColoredBox':
      'the route veil is `LoopColors.veil`, Ink at 76%, and it fades in from '
      'nothing. Over the Ink page it darkens close to nothing, which is '
      'the point: what separates a sheet from the page is the sheet\'s '
      'own surface, not the veil. The veil is there to catch the tap.',
  'CommunityScreen · ColoredBox':
      'the Community panel scrim, the same `LoopColors.veil` painted by the '
      'screen itself instead of by a route, for the same reason. '
      'Community paints no other bare `ColoredBox`.',
  'LoopActionDock · DecoratedBox':
      'the sticky dock restates the page behind it — Abyss at 96%, the page\'s '
      'own colour — so that content scrolls under it. The line that '
      'separates it is its top hairline, which the probe checks and which '
      'holds.',
};

/// The findings of the test that is running now, keyed so that the same paint
/// in twenty rows of one list is reported once.
Map<String, LoopPaintedColour>? _collecting;
Color _collectingGround = LoopColors.ink;
bool _watching = false;

/// Watch every frame this test paints, and fail if something it painted is
/// not there.
///
/// Called from the page harnesses rather than from the tests, so it covers the
/// pages that exist today and the pages added next year without anybody
/// remembering to opt in. A test file that mounts a page without a harness
/// calls [loopWatchGround] once instead.
///
/// It reads the tree on every frame, not once after the mount, because the
/// state a page is wrong in is often the one a tap reaches: a sheet, an error
/// strip, a Chalk card that only a loaded read builds. `flutter_test` resets
/// the tree before tear-downs run, so the findings are accumulated while the
/// test is still running and reported from the tear-down.
void loopArmGroundProbe(WidgetTester tester, {Color ground = LoopColors.ink}) {
  _arm(tester.binding, ground);
}

/// Arms the probe for every `testWidgets` in one file, from its `main`.
///
/// The harnesses are the automatic path; this is the same watch for the files
/// that mount a page through their own `pumpWidget`, so that "this file
/// renders a page" and "this file is watched" stay the same statement.
void loopWatchGround({Color ground = LoopColors.ink}) {
  setUp(() => _arm(TestWidgetsFlutterBinding.instance, ground));
}

void _arm(TestWidgetsFlutterBinding binding, Color ground) {
  // Already armed for this test: a test may mount more than once, and the
  // watch is one per test, not one per mount.
  if (_collecting != null) return;
  _collecting = <String, LoopPaintedColour>{};
  _collectingGround = ground;
  if (!_watching) {
    _watching = true;
    // A persistent frame callback cannot be removed, so it is registered once
    // for the whole process and does nothing while no test has armed it.
    binding.addPersistentFrameCallback((_) {
      final collecting = _collecting;
      final root = binding.rootElement;
      if (collecting == null || root == null) return;
      final probes = loopProbeGround(root, _collectingGround);
      for (final probe in loopVanishedPaint(probes)) {
        collecting.putIfAbsent(probe.signature, () => probe);
      }
    });
  }
  addTearDown(() {
    final found = _collecting;
    _collecting = null;
    if (found == null || found.isEmpty) return;
    fail(
      'painted but not there (${found.length} distinct):\n'
      '${found.values.map((probe) => '  $probe').join('\n')}\n'
      'Each line is a colour this test painted on that ground, at or below '
      'the floor. Derive it with `LoopGround` from the ground it lands on, '
      'or name it in `loopGroundProbeExemptions` with the reason it is '
      'meant to be invisible.',
    );
  });
}
