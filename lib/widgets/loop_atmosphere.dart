import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_remote_avatar.dart';

// ---------------------------------------------------------------------------
// 氛围层 · shared pieces (S264 → S265, decisions 0220 / 0221)
// ---------------------------------------------------------------------------
//
// The wall is black and the only two materials are chrome and spray paint.
// Spray lands on brand pieces only — the title crown, a section index, the
// chosen chip, a default face, a progress bar's drip — and data rows stay
// flat and readable. Yellow is for what asks to be tapped; Purple is the
// brand band and the chosen state.
//
// Nothing here loops: the MEME home's moving pieces (the band, the hand's
// sheen) stay in `launch2_atmosphere.dart`.

/// Decodes [paths] (every atmosphere piece by default) ahead of a page's
/// first frame, so none of them pops in after the page.
void loopPrecacheAtmosphere(
  BuildContext context, [
  Iterable<String> paths = LoopAtmoAssets.all,
]) {
  for (final path in paths) {
    unawaited(
      precacheImage(
        AssetImage(path),
        context,
        onError: (error, stackTrace) {
          debugPrint('LOOP atmosphere: $path did not decode ($error)');
        },
      ),
    );
  }
}

/// The pieces a tab page's wall, crown and chips use.
const List<String> loopAtmosphereTabAssets = <String>[
  LoopAtmoAssets.wall,
  LoopAtmoAssets.sprayPurple,
  LoopAtmoAssets.sprayYellow,
  LoopAtmoAssets.crownWall,
  LoopAtmoAssets.splatYellow,
];

/// Decodes [paths] once, before [child]'s first frame (decision 0221: each
/// tab page with a wall precaches what it draws).
class LoopAtmoPrecache extends StatefulWidget {
  const LoopAtmoPrecache({
    required this.child,
    super.key,
    this.paths = loopAtmosphereTabAssets,
  });

  final Widget child;
  final List<String> paths;

  @override
  State<LoopAtmoPrecache> createState() => _LoopAtmoPrecacheState();
}

class _LoopAtmoPrecacheState extends State<LoopAtmoPrecache> {
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_done) return;
    _done = true;
    loopPrecacheAtmosphere(context, widget.paths);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A decorative asset image: no semantics, no gap while it loads.
Widget loopAtmoArt(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  Key? key,
}) => Image.asset(
  path,
  key: key,
  width: width,
  height: height,
  fit: fit,
  excludeFromSemantics: true,
  gaplessPlayback: true,
  errorBuilder: (context, error, stackTrace) =>
      SizedBox(width: width, height: height),
);

// ---- the wall -------------------------------------------------------------

/// One fog spot on the wall, in the design's 390-wide coordinates.
@immutable
final class LoopFogSpot {
  const LoopFogSpot({
    required this.asset,
    required this.opacity,
    required this.size,
    this.left,
    this.top,
    this.right,
    this.bottom,
  });

  final String asset;
  final double opacity;
  final double size;
  final double? left;
  final double? top;
  final double? right;
  final double? bottom;
}

/// Where the two fogs sit on each tab, so the five walls are not one copy.
enum LoopWallFog {
  /// MEME: Purple top left 15 %, Yellow bottom right 11 % (decision 0220).
  meme(<LoopFogSpot>[
    LoopFogSpot(
      asset: LoopAtmoAssets.sprayPurple,
      opacity: 0.15,
      size: 560,
      left: -190,
      top: -150,
    ),
    LoopFogSpot(
      asset: LoopAtmoAssets.sprayYellow,
      opacity: 0.11,
      size: 540,
      right: -220,
      bottom: 60,
    ),
  ]),

  /// 聊天: Purple top right, Yellow bottom left.
  chat(<LoopFogSpot>[
    LoopFogSpot(
      asset: LoopAtmoAssets.sprayPurple,
      opacity: 0.15,
      size: 560,
      right: -200,
      top: -160,
    ),
    LoopFogSpot(
      asset: LoopAtmoAssets.sprayYellow,
      opacity: 0.10,
      size: 520,
      left: -240,
      bottom: 40,
    ),
  ]),

  /// 广场: Yellow top right, Purple low on the left.
  square(<LoopFogSpot>[
    LoopFogSpot(
      asset: LoopAtmoAssets.sprayYellow,
      opacity: 0.10,
      size: 500,
      right: -210,
      top: -170,
    ),
    LoopFogSpot(
      asset: LoopAtmoAssets.sprayPurple,
      opacity: 0.14,
      size: 540,
      left: -230,
      bottom: 120,
    ),
  ]),

  /// 情报: Yellow top left, Purple bottom right.
  intel(<LoopFogSpot>[
    LoopFogSpot(
      asset: LoopAtmoAssets.sprayYellow,
      opacity: 0.10,
      size: 500,
      left: -200,
      top: -160,
    ),
    LoopFogSpot(
      asset: LoopAtmoAssets.sprayPurple,
      opacity: 0.15,
      size: 560,
      right: -220,
      bottom: 40,
    ),
  ]),

  /// 钱包: Yellow top right behind the chrome plate, Purple low on the left.
  wallet(<LoopFogSpot>[
    LoopFogSpot(
      asset: LoopAtmoAssets.sprayYellow,
      opacity: 0.11,
      size: 520,
      right: -190,
      top: -140,
    ),
    LoopFogSpot(
      asset: LoopAtmoAssets.sprayPurple,
      opacity: 0.14,
      size: 540,
      left: -200,
      bottom: 100,
    ),
  ]);

  const LoopWallFog(this.spots);

  final List<LoopFogSpot> spots;
}

/// The still layer under a tab page: the wall at 85 % over Ink, a darkening
/// wash down the page (Ink 15 % → 70 %) and two fogs placed per tab.
class LoopWallBackdrop extends StatelessWidget {
  const LoopWallBackdrop({
    super.key,
    this.fog = LoopWallFog.meme,
    this.keyPrefix = 'loop-atmo',
  });

  final LoopWallFog fog;

  /// Prefix of the wall layer's key (`<prefix>-wall`).
  final String keyPrefix;

  /// The design's reference width; the fog sizes scale with the screen.
  static const double referenceWidth = 390;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final k = constraints.maxWidth / referenceWidth;
      double? at(double? value) => value == null ? null : value * k;
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              key: ValueKey<String>('$keyPrefix-wall'),
              decoration: const BoxDecoration(
                color: LoopColors.ink,
                image: DecorationImage(
                  image: AssetImage(LoopAtmoAssets.wall),
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  repeat: ImageRepeat.repeatY,
                  opacity: 0.85,
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0x2609090B),
                    Color(0x7309090B),
                    Color(0xB309090B),
                  ],
                  stops: <double>[0, 0.55, 1],
                ),
              ),
            ),
            for (final spot in fog.spots)
              Positioned(
                left: at(spot.left),
                top: at(spot.top),
                right: at(spot.right),
                bottom: at(spot.bottom),
                width: spot.size * k,
                height: spot.size * k,
                child: Opacity(
                  opacity: spot.opacity,
                  child: loopAtmoArt(spot.asset),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Marks a subtree as standing on a page backdrop. Embedded pages inside it
/// leave their own ground clear so the wall shows, and [LoopBackdropSlice]
/// paints the same wall behind a pinned bar.
class LoopBackdropScope extends InheritedWidget {
  const LoopBackdropScope({
    required this.backdrop,
    required super.child,
    super.key,
    this.stageSize = Size.zero,
  });

  /// The still layer under the page (a [LoopWallBackdrop]).
  final Widget backdrop;

  /// The size the backdrop is laid out at under the page.
  final Size stageSize;

  static LoopBackdropScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LoopBackdropScope>();

  /// Whether [context] stands on a backdrop.
  static bool on(BuildContext context) => maybeOf(context) != null;

  @override
  bool updateShouldNotify(LoopBackdropScope oldWidget) =>
      oldWidget.backdrop != backdrop || oldWidget.stageSize != stageSize;
}

/// Lays [backdrop] under [child] (fixed, never scrolling) and publishes it
/// through a [LoopBackdropScope].
class LoopBackdropStage extends StatelessWidget {
  const LoopBackdropStage({
    required this.backdrop,
    required this.child,
    super.key,
  });

  final Widget backdrop;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => LoopBackdropScope(
      backdrop: backdrop,
      stageSize: constraints.biggest,
      child: _LoopBackdropOrigin(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Positioned.fill(child: IgnorePointer(child: backdrop)),
            child,
          ],
        ),
      ),
    ),
  );
}

/// The box the backdrop was laid out in, for [LoopBackdropSlice].
class _LoopBackdropOrigin extends SingleChildRenderObjectWidget {
  const _LoopBackdropOrigin({required super.child});

  @override
  RenderProxyBox createRenderObject(BuildContext context) =>
      _RenderBackdropOrigin();
}

class _RenderBackdropOrigin extends RenderProxyBox {}

/// Paints the scope's backdrop cut to this box, at the place it has on the
/// page: a pinned bar over a scrolling list reads as the page's own ground
/// and rows pass under it unseen. Outside a scope it paints Ink.
class LoopBackdropSlice extends StatelessWidget {
  const LoopBackdropSlice({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = LoopBackdropScope.maybeOf(context);
    if (scope == null) return ColoredBox(color: LoopColors.ink, child: child);
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: _BackdropSlice(
              key: const ValueKey<String>('loop-backdrop-slice'),
              stageSize: scope.stageSize,
              child: scope.backdrop,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropSlice extends SingleChildRenderObjectWidget {
  const _BackdropSlice({
    required this.stageSize,
    required super.child,
    super.key,
  });

  final Size stageSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBackdropSlice(stageSize);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderBackdropSlice renderObject,
  ) {
    renderObject.stageSize = stageSize;
  }
}

class _RenderBackdropSlice extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  _RenderBackdropSlice(this._stageSize);

  Size _stageSize;

  set stageSize(Size value) {
    if (value == _stageSize) return;
    _stageSize = value;
    markNeedsLayout();
  }

  RenderBox? _origin() {
    var node = parent;
    while (node != null) {
      if (node is _RenderBackdropOrigin) return node;
      node = node.parent;
    }
    return null;
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final stage = _stageSize.isEmpty || !_stageSize.isFinite
        ? size
        : _stageSize;
    child?.layout(BoxConstraints.tight(stage));
  }

  @override
  bool get isRepaintBoundary => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final slice = child;
    if (slice == null) return;
    final origin = _origin();
    final shift = origin == null
        ? Offset.zero
        : localToGlobal(Offset.zero, ancestor: origin);
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (context, offset) => context.paintChild(slice, offset - shift),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      false;
}

// ---- the title crown --------------------------------------------------------

/// [child] with the wall crown peeking out behind it (60 %, −8°).
class LoopTitleCrown extends StatelessWidget {
  const LoopTitleCrown({
    required this.child,
    super.key,
    this.crownKey,
    this.left = 52,
    this.top = -14,
    this.width = 84,
  });

  final Widget child;
  final Key? crownKey;
  final double left;
  final double top;
  final double width;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: <Widget>[
      Positioned(
        left: left,
        top: top,
        width: width,
        child: IgnorePointer(
          child: Transform.rotate(
            angle: -8 * math.pi / 180,
            child: Opacity(
              opacity: 0.6,
              child: loopAtmoArt(LoopAtmoAssets.crownWall, key: crownKey),
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

/// A tab title with the wall crown behind it (decision 0220 §3).
class LoopAtmoTitle extends StatelessWidget {
  const LoopAtmoTitle({required this.title, super.key, this.crownKey});

  final String title;
  final Key? crownKey;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: LoopTitleCrown(
      crownKey: crownKey,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
    ),
  );
}

// ---- spray pieces -------------------------------------------------------------

/// The small Yellow splat sticker a chosen chip wears on its top-left corner
/// (−18°, 24 wide).
class LoopSplatSticker extends StatelessWidget {
  const LoopSplatSticker({super.key, this.width = 24, this.angle = -18});

  final double width;
  final double angle;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Transform.rotate(
      angle: angle * math.pi / 180,
      child: loopAtmoArt(LoopAtmoAssets.splatYellow, width: width),
    ),
  );
}

/// A section heading: with an [index] the Anton number in Yellow with a
/// small splat at its top right (only for an order or a ranking), without
/// one the 16 / 700 title with the splat after it. A Yellow 「全部」 when the
/// section has somewhere to go.
class LoopSprayHeading extends StatelessWidget {
  const LoopSprayHeading({
    required this.title,
    super.key,
    this.index,
    this.onMore,
    this.moreKey,
  });

  final int? index;
  final String title;
  final VoidCallback? onMore;
  final Key? moreKey;

  static Widget _splat() => Opacity(
    opacity: 0.75,
    child: Transform.rotate(
      angle: 12 * math.pi / 180,
      child: loopAtmoArt(LoopAtmoAssets.splatYellow),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final more = onMore;
    final number = index;
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: LoopType.sectionTitle,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        24,
        LoopSpacing.page,
        8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (number != null) ...<Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Text(
                  number.toString().padLeft(2, '0'),
                  style: LoopType.sectionIndex.copyWith(
                    color: LoopColors.yellow,
                  ),
                ),
                Positioned(right: -12, top: -8, width: 26, child: _splat()),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: heading,
              ),
            ),
          ] else
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: heading,
                    ),
                    Positioned(
                      right: -4,
                      top: -6,
                      width: 18,
                      child: KeyedSubtree(
                        key: const ValueKey<String>('loop-spray-heading-splat'),
                        child: _splat(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (more != null)
            Semantics(
              button: true,
              label: '$title 全部',
              excludeSemantics: true,
              child: LoopPressable(
                key: moreKey,
                onTap: more,
                scale: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: LoopTouch.minimum,
                    minHeight: LoopTouch.minimum,
                  ),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            '全部',
                            style: LoopTypography.withWeight(
                              LoopType.titleSm,
                              FontWeight.w600,
                            ).copyWith(color: LoopColors.yellow),
                          ),
                          const LoopIcon(
                            'chevron',
                            size: 14,
                            color: LoopColors.yellow,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- boards ----------------------------------------------------------------------

/// One card-ground board, 16 radius, its rows split by 1 px lines (or not,
/// when the rows draw their own).
class LoopAtmoBoard extends StatelessWidget {
  const LoopAtmoBoard({
    required this.children,
    super.key,
    this.dividers = true,
  });

  final List<Widget> children;
  final bool dividers;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
    clipBehavior: Clip.antiAlias,
    decoration: const BoxDecoration(
      color: LoopColors.card,
      borderRadius: LoopRadius.card,
      border: Border(top: BorderSide(color: Color(0x0AFFFFFF))),
    ),
    // A row's ink splash paints on this, above the board's own ground.
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final (index, child) in children.indexed) ...<Widget>[
            if (dividers && index > 0)
              const Divider(height: 1, thickness: 1, color: LoopColors.line),
            child,
          ],
        ],
      ),
    ),
  );
}

/// The greyscale matrix the empty-state crown and the 2nd / 3rd crowns use.
const List<double> loopGreyMatrix = <double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// An empty state on the wall (decision 0220 §9): a board with the grey
/// crown line drawing, one sentence and, when there is one, a Yellow action.
class LoopAtmoEmpty extends StatelessWidget {
  const LoopAtmoEmpty({
    required this.message,
    super.key,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.crownKey,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;
  final Key? crownKey;

  @override
  Widget build(BuildContext context) {
    final action = onAction;
    final label = actionLabel;
    return LoopAtmoBoard(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Opacity(
                opacity: 0.45,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix(loopGreyMatrix),
                  child: loopAtmoArt(
                    LoopAtmoAssets.crownFlat,
                    key: crownKey,
                    width: 64,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: LoopType.bodySm,
              ),
              if (action != null && label != null) ...<Widget>[
                const SizedBox(height: 10),
                LoopYellowButton(
                  key: actionKey,
                  label: label,
                  height: 44,
                  onTap: action,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The atmosphere's solid Yellow button: 12 radius, Ink 14 / 700, a soft
/// Yellow glow under it.
class LoopYellowButton extends StatelessWidget {
  const LoopYellowButton({
    required this.label,
    super.key,
    this.onTap,
    this.height = 40,
    this.maxWidth = 160,
  });

  final String label;
  final VoidCallback? onTap;
  final double height;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      height: height,
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        minWidth: LoopTouch.minimum,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: LoopColors.yellow,
        borderRadius: LoopRadius.button,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x38FFD600),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      // Sized by its words (`inline-flex`), centred in its height.
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LoopType.action.copyWith(color: LoopColors.ink),
        ),
      ),
    );
    final tap = onTap;
    if (tap == null) return box;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: LoopPressable(onTap: tap, child: box),
    );
  }
}

// ---- chrome ----------------------------------------------------------------------

/// The chrome edge: `chrome1 → chrome2 → chrome3 → chrome2`, top left to
/// bottom right.
const LinearGradient loopChromeGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[
    LoopColors.chrome1,
    LoopColors.chrome2,
    LoopColors.chrome3,
    LoopColors.chrome2,
  ],
  stops: <double>[0, 0.35, 0.7, 1],
);

/// The chrome plate (decision 0221): a 1.5 px chrome edge around a card
/// face, with a faint chrome light across the face's top. The face stays the
/// dark card, so the plate does not glare and its figure (Arimo 32 / 700
/// Yellow) reads on the card ground.
class LoopChromePlate extends StatelessWidget {
  const LoopChromePlate({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.margin = const EdgeInsets.symmetric(horizontal: LoopSpacing.page),
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;

  static const double edge = 1.5;

  @override
  Widget build(BuildContext context) => Padding(
    padding: margin,
    child: DecoratedBox(
      key: const ValueKey<String>('loop-chrome-plate-edge'),
      decoration: const BoxDecoration(
        gradient: loopChromeGradient,
        borderRadius: LoopRadius.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(edge),
        child: DecoratedBox(
          key: const ValueKey<String>('loop-chrome-plate-face'),
          decoration: BoxDecoration(
            color: LoopColors.card,
            borderRadius: BorderRadius.circular(LoopRadius.cardValue - edge),
          ),
          child: Stack(
            children: <Widget>[
              // The chrome light: Chalk 7 % fading out a third of the way
              // down, on the face's ground.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: const ValueKey<String>('loop-chrome-plate-light'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        LoopRadius.cardValue - edge,
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment(0.2, 0.2),
                        colors: <Color>[Color(0x12F0F0F3), Color(0x00F0F0F3)],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A round chrome medal with the small crown: the default face of anything
/// that has no picture of its own (decision 0220 §8).
class LoopChromeMedal extends StatelessWidget {
  const LoopChromeMedal({required this.size, super.key, this.artKey});

  final double size;
  final Key? artKey;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: ClipOval(
      child: loopAtmoArt(
        LoopAtmoAssets.avatarChrome,
        key: artKey,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    ),
  );
}

/// A round face: the picture at [logoUrl] when there is one, else the
/// chrome medal (and the medal while the picture fails).
class LoopChromeAvatar extends StatelessWidget {
  const LoopChromeAvatar({
    required this.size,
    super.key,
    this.logoUrl,
    this.medalKey,
    this.logoKey,
  });

  final double size;
  final String? logoUrl;
  final Key? medalKey;
  final Key? logoKey;

  @override
  Widget build(BuildContext context) {
    final medal = LoopChromeMedal(size: size, artKey: medalKey);
    final url = logoUrl;
    if (url == null) return medal;
    return LoopRemoteAvatar(
      key: logoKey,
      url: url,
      fallback: medal,
      size: size,
    );
  }
}

/// The crown a top-three face wears: Yellow for the first, chrome-grey for
/// the second and the third.
class LoopRankCrown extends StatelessWidget {
  const LoopRankCrown({required this.place, super.key, this.width = 24});

  final int place;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (place == 1) {
      return IgnorePointer(
        child: Transform.rotate(
          angle: 14 * math.pi / 180,
          child: loopAtmoArt(LoopAtmoAssets.crownYellow, width: width),
        ),
      );
    }
    return IgnorePointer(
      child: Transform.rotate(
        angle: 14 * math.pi / 180,
        child: Opacity(
          // Second brighter than third: chrome, then a duller grey.
          opacity: place == 2 ? 0.95 : 0.75,
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(loopGreyMatrix),
            child: loopAtmoArt(LoopAtmoAssets.crownFlat, width: width * 0.9),
          ),
        ),
      ),
    );
  }
}

// ---- the drip bar ------------------------------------------------------------------

/// The 6 px Yellow progress bar; past 0 a Yellow drip hangs from its end.
class LoopDripBar extends StatelessWidget {
  const LoopDripBar({
    required this.fraction,
    super.key,
    this.width = 96,
    this.dripKey,
  });

  final double fraction;
  final double width;
  final Key? dripKey;

  @override
  Widget build(BuildContext context) {
    final f = fraction.clamp(0.0, 1.0);
    final fill = width * f;
    return SizedBox(
      width: width,
      height: 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF24232A),
                borderRadius: LoopRadius.pill,
              ),
            ),
          ),
          if (f > 0) ...<Widget>[
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: fill,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: LoopRadius.pill,
                  gradient: LinearGradient(
                    colors: <Color>[Color(0xFFE6BE00), LoopColors.yellow],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: Color(0x73FFD600), blurRadius: 6),
                  ],
                ),
              ),
            ),
            Positioned(
              left: fill - 3,
              top: 2,
              width: 5,
              child: loopAtmoArt(
                LoopAtmoAssets.dripYellow,
                key: dripKey,
                width: 5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
