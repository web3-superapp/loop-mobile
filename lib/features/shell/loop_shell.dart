import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_dock_bar.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// Five-destination shell (chapter 5.4).
///
/// Mobile: a solid Chalk floating bar, only on the five tab routes; the page
/// body extends behind it and receives a `90 + safe-area` bottom padding.
/// Widths from [LoopLayout.railBreakpoint] use a navigation rail instead.
///
/// Decision 0128: the five tabs are the branches of one
/// `StatefulShellRoute.indexedStack`, handed in as [navigationShell]. A tab
/// that is left keeps its page, its scroll offset and its state; selecting
/// it again shows it exactly as it was. Selecting the tab that is already
/// showing scrolls it back to the top. The system back on any tab but MEME
/// returns to MEME instead of leaving the App (decision 0221; it was 聊天).
///
/// Without a [navigationShell] (a detached widget test) the shell selects by
/// [location] and switches with `go`.
class LoopShell extends StatefulWidget {
  const LoopShell({
    required this.child,
    super.key,
    this.location = LoopRouteManifest.defaultPath,
    this.navigationShell,
  });

  final Widget child;
  final String location;
  final StatefulNavigationShell? navigationShell;

  static const _destinations = <_LoopDestination>[
    // v3 (需求方 2026-10-08, decision 0110): 聊天/广场/MEME/情报/钱包.
    // Slugs stay the stable test and analytics identifiers.
    _LoopDestination('聊天', '/chat', 'chat'),
    _LoopDestination('广场', '/square', 'compass'),
    _LoopDestination('MEME', '/meme', 'launch'),
    _LoopDestination('情报', '/intel', 'chart'),
    _LoopDestination('钱包', '/wallet', 'wallet'),
  ];

  /// Labels in shell order, for tests and the desktop rail.
  static List<String> get destinationLabels =>
      _destinations.map((item) => item.label).toList(growable: false);

  static List<String> get destinationPaths =>
      _destinations.map((item) => item.path).toList(growable: false);

  /// The home tab: where the App lands and where the system back on every
  /// other tab returns to — MEME since decision 0221. The tab order does
  /// not change.
  static int get homeIndex =>
      destinationPaths.indexOf(LoopRouteManifest.defaultPath);

  /// Brings every vertical scroll region of [context]'s subtree back to its
  /// start: animated, or in one jump under reduced motion.
  ///
  /// It asks the scroll positions themselves rather than one
  /// `PrimaryScrollController`, because a folio page coordinates its header
  /// and list through a `NestedScrollView` whose inner position is not the
  /// route's primary controller. Offstage subtrees (a segment that is not
  /// showing) are left where they are.
  static void scrollToTop(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final positions = <ScrollPosition>[];
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (element is StatefulElement && element.state is ScrollableState) {
        final position = (element.state as ScrollableState).position;
        if (position.axis == Axis.vertical &&
            position.hasPixels &&
            position.hasContentDimensions &&
            position.pixels > position.minScrollExtent &&
            !positions.contains(position)) {
          positions.add(position);
        }
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    for (final position in positions) {
      if (reduceMotion) {
        position.jumpTo(position.minScrollExtent);
      } else {
        unawaited(
          position.animateTo(
            position.minScrollExtent,
            duration: scrollToTopDuration,
            curve: Curves.easeOutCubic,
          ),
        );
      }
    }
  }

  static const Duration scrollToTopDuration = Duration(milliseconds: 320);

  @override
  State<LoopShell> createState() => _LoopShellState();
}

class _LoopShellState extends State<LoopShell> {
  bool _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // S264: the chosen tab's Yellow spray is decoded before the bar's first
    // frame.
    if (_precached) return;
    _precached = true;
    unawaited(
      precacheImage(
        const AssetImage(LoopAtmoAssets.sprayYellow),
        context,
        onError: (error, stackTrace) {},
      ),
    );
  }

  int get _selectedIndex {
    final shell = widget.navigationShell;
    if (shell != null) return shell.currentIndex;
    final match = LoopShell._destinations.indexWhere(
      (item) => widget.location == item.path,
    );
    return match < 0 ? LoopShell.homeIndex : match;
  }

  void _select(BuildContext context, int index) {
    final current = _selectedIndex;
    if (index == current) {
      // m21: the tab that is already showing goes back to its top.
      final branchContext = widget
          .navigationShell
          ?.route
          .branches[index]
          .navigatorKey
          .currentContext;
      LoopShell.scrollToTop(branchContext ?? context);
    }
    final shell = widget.navigationShell;
    if (shell == null) {
      context.go(LoopShell._destinations[index].path);
      return;
    }
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    assert(
      LoopShell.destinationPaths.join(',') ==
          LoopRouteManifest.tabPaths.join(','),
      'LoopShell destinations must follow the manifest tab order.',
    );
    final selectedIndex = _selectedIndex;
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= LoopLayout.railBreakpoint;
        if (wide) {
          return Scaffold(
            body: Row(
              children: <Widget>[
                _DesktopRail(
                  selectedIndex: selectedIndex,
                  onSelect: (index) => _select(context, index),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: LoopColors.line,
                ),
                Expanded(child: widget.child),
              ],
            ),
          );
        }
        // Decision 0226: the page runs under the floating bar to the very
        // bottom of the screen — the wall included — and the system
        // navigation bar draws no scrim of its own over it.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: loopTabSystemOverlay,
          child: LoopTabBarScope(
            child: Scaffold(
              extendBody: true,
              body: widget.child,
              bottomNavigationBar: LoopTabBar(
                selectedIndex: selectedIndex,
                onSelect: (index) => _select(context, index),
              ),
            ),
          ),
        );
      },
    );
    if (widget.navigationShell == null) return body;
    // B2, decision 0221: back on 聊天, 广场, 情报 or 钱包 goes to MEME first;
    // only MEME lets the system close the App. `PopScope` is what Android's
    // predictive back reads, so the system shows no "leave the App" preview
    // on those tabs.
    return PopScope(
      canPop: selectedIndex == LoopShell.homeIndex,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        widget.navigationShell?.goBranch(LoopShell.homeIndex);
      },
      child: body,
    );
  }
}

/// The system bars over the five tabs (decision 0226): a clear navigation
/// bar with no contrast scrim, so the page — on the wall, the wall — shows
/// under the floating tab bar down to the screen's edge.
const SystemUiOverlayStyle loopTabSystemOverlay = SystemUiOverlayStyle(
  systemNavigationBarColor: Color(0x00000000),
  systemNavigationBarDividerColor: Color(0x00000000),
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
  statusBarColor: Color(0x00000000),
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

/// The tab bar's ground (decision 0226): the card surface at 92 %, so the
/// wall shows faintly through it. No blur.
const Color loopTabBarGround = Color(0xEB111114);

/// The floating Chalk tab bar.
///
/// Outer box height is `90 + safe-area-bottom`; with `Scaffold.extendBody`
/// that is exactly the reserve the body receives as bottom padding. Inside,
/// the 70px bar sits `max(8, safe-area)` from the edges with a 23px radius.
///
/// The Lime ground is one indicator, not five backgrounds: switching tabs
/// slides that single pill from the tab that had it to the tab that takes it
/// (decision 0071), so nothing appears and nothing disappears. Material's
/// ripple and highlight are removed — a grey wash under the finger reads as a
/// second, contradicting selection.
class LoopTabBar extends StatelessWidget {
  const LoopTabBar({
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  /// Indicator travel. Long enough to read as one object moving, short enough
  /// that the destination is already legible when the finger lifts.
  static const Duration slideDuration = Duration(milliseconds: 200);
  static const Curve slideCurve = Curves.easeOutCubic;

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final bottomInset = math.max(LoopLayout.tabBarInset, padding.bottom);
    final leftInset = math.max(LoopLayout.tabBarInset, padding.left);
    final rightInset = math.max(LoopLayout.tabBarInset, padding.right);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final count = LoopShell._destinations.length;
    // -1 at the first cell, +1 at the last: `Alignment` interpolates the
    // remaining cells for us, so the pill lands on cell centres exactly.
    final alignment = Alignment(
      count <= 1 ? 0 : -1 + 2 * (selectedIndex / (count - 1)),
      0,
    );
    final indicator = FractionallySizedBox(
      widthFactor: 1 / count,
      heightFactor: 1,
      // Decision 0212 (docs/42 附C §4): the bar carries no colour block —
      // the chosen cell is told apart by its Yellow glyph and word alone. The
      // keyed slot stays so the cell geometry the dock tracks is unchanged.
      child: const Align(
        alignment: Alignment(0, -0.7),
        child: SizedBox(
          key: ValueKey<String>('loop-tab-indicator'),
          width: 48,
          height: 30,
        ),
      ),
    );
    return SizedBox(
      key: const ValueKey<String>('loop-tab-bar'),
      height: LoopLayout.tabPageBottomReserve + padding.bottom,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(leftInset, 0, rightInset, bottomInset),
          child: Semantics(
            container: true,
            label: 'Primary navigation',
            child: Container(
              height: LoopTouch.tabBarHeight,
              padding: const EdgeInsets.all(LoopLayout.tabBarPadding),
              // Decision 0212: the bar is the card surface with a 20 radius
              // and no selection block. S264 (decision 0220): a 1 px chrome
              // line runs along its top edge.
              foregroundDecoration: const _ChromeEdge(),
              decoration: const BoxDecoration(
                // Decision 0226: card at 92 %; the safe area under the bar
                // is clear.
                color: loopTabBarGround,
                borderRadius: LoopRadius.tabBar,
              ),
              child: LoopDockBar(
                count: count,
                selectedIndex: selectedIndex,
                onSelect: onSelect,
                // The pill follows its cell's glyph sideways while the row
                // makes room under a sliding finger; at rest the shift is 0.
                backgroundBuilder: (context, cells) => Transform.translate(
                  offset: Offset(cells[selectedIndex].shift, 0),
                  // Reduced motion is a jump, not a fast slide: the plain
                  // `Align` reaches the new cell in the same frame.
                  child: reduceMotion
                      ? Align(alignment: alignment, child: indicator)
                      : AnimatedAlign(
                          alignment: alignment,
                          duration: slideDuration,
                          curve: slideCurve,
                          child: indicator,
                        ),
                ),
                cellBuilder: (context, index, cell) => LoopTabItem(
                  label: LoopShell._destinations[index].label,
                  slug: LoopShell._destinations[index].slug,
                  icon: LoopShell._destinations[index].icon,
                  selected: index == selectedIndex,
                  dock: cell,
                  onTap: () => onSelect(index),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tab bar's 1 px chrome top edge (S264): dark steel at both ends, light
/// steel in the middle, 18 in from the bar's sides.
class _ChromeEdge extends Decoration {
  const _ChromeEdge();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      const _ChromeEdgePainter();
}

class _ChromeEdgePainter extends BoxPainter {
  const _ChromeEdgePainter();

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final line = Rect.fromLTWH(offset.dx + 18, offset.dy, size.width - 36, 1);
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0x003A3A42),
          LoopColors.chrome2,
          LoopColors.chrome1,
          LoopColors.chrome2,
          Color(0x003A3A42),
        ],
        stops: <double>[0, 0.2, 0.5, 0.8, 1],
      ).createShader(line);
    canvas.drawRect(line, paint);
  }
}

/// One tab cell (S264, decision 0220): selected, an Ink glyph on a Yellow
/// spray with a Yellow label; otherwise a Text3 glyph and label.
///
/// The cell draws no ground of its own — [LoopTabBar]'s single indicator is
/// the Lime ground, and it slides. The cell only crossfades its own ink over
/// the same interval so the glyph darkens exactly while the pill arrives.
class LoopTabItem extends StatelessWidget {
  const LoopTabItem({
    required this.label,
    required this.slug,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
    this.dock = LoopDockCell.rest,
  });

  final String label;

  /// Stable identifier (`chat`, `square`, ...) for keys and analytics.
  final String slug;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  /// The magnification a sliding finger gives this cell's glyph and label
  /// (decision 0096). It moves and scales what the cell paints, never the
  /// cell: the tap target keeps its size.
  final LoopDockCell dock;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey<String>('loop-tab-$slug'),
          onTap: onTap,
          borderRadius: LoopRadius.control,
          // No ripple, no press wash, no hover tint: the indicator is the one
          // thing that may say which tab is selected.
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: selected ? 1 : 0),
            duration: reduceMotion ? Duration.zero : LoopTabBar.slideDuration,
            curve: LoopTabBar.slideCurve,
            builder: (context, t, _) {
              final color = t <= 0
                  ? LoopColors.text3
                  : t >= 1
                  ? LoopColors.yellow
                  : Color.lerp(LoopColors.text3, LoopColors.yellow, t)!;
              // The Ink glyph stands on a solid Yellow core from the first
              // frame of the selection to the last; only the spray around
              // the core fades, so the glyph never sits on a half ground.
              final glyph = t <= 0 ? LoopColors.text3 : LoopColors.ink;
              return ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: LoopTouch.tabCellMinHeight,
                  minWidth: LoopTouch.minimum,
                ),
                child: _dockTransform(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: <Widget>[
                            if (t > 0)
                              Positioned(
                                left: 12 - 29,
                                top: 12 - 29,
                                width: 58,
                                height: 58,
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: 0.8 * t,
                                    child: Transform.rotate(
                                      angle: -10 * math.pi / 180,
                                      child: Image.asset(
                                        LoopAtmoAssets.sprayYellow,
                                        key: ValueKey<String>(
                                          'loop-tab-spray-$slug',
                                        ),
                                        fit: BoxFit.contain,
                                        excludeFromSemantics: true,
                                        gaplessPlayback: true,
                                        errorBuilder: (context, error, stack) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (t > 0)
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: DecoratedBox(
                                  key: ValueKey<String>('loop-tab-core-$slug'),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: <Color>[
                                        LoopColors.yellow,
                                        LoopColors.yellow,
                                        Color(0x00FFD600),
                                      ],
                                      stops: <double>[0, 0.6, 1],
                                    ),
                                  ),
                                  child: Center(
                                    child: LoopIcon(
                                      icon,
                                      size: 21,
                                      color: glyph,
                                    ),
                                  ),
                                ),
                              )
                            else
                              LoopIcon(icon, size: 21, color: glyph),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      ExcludeSemantics(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopTypography.withWeight(
                            LoopType.label,
                            FontWeight.w700,
                          ).copyWith(color: color),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The glyph and label grow from their bottom edge, so a magnified glyph
  /// rises out of the bar the way a dock's does instead of spilling down.
  Widget _dockTransform(Widget child) {
    if (dock.atRest) return child;
    return Transform(
      key: ValueKey<String>('loop-tab-dock-$slug'),
      alignment: Alignment.bottomCenter,
      transform: Matrix4.translationValues(dock.shift, 0, 0)
        ..scaleByDouble(dock.scale, dock.scale, 1, 1),
      child: child,
    );
  }
}

/// The peer-tab fade (decision 0128 keeps decision 0071's fade).
///
/// The branches of the indexed stack are never rebuilt when one is selected,
/// so there is no page transition to fade; instead the branch container fades
/// in over 180ms each time [index] changes. Reduced motion shows it at once.
class LoopTabSwitchFade extends StatefulWidget {
  const LoopTabSwitchFade({
    required this.index,
    required this.child,
    super.key,
  });

  final int index;
  final Widget child;

  static const Duration duration = Duration(milliseconds: 180);

  @override
  State<LoopTabSwitchFade> createState() => _LoopTabSwitchFadeState();
}

class _LoopTabSwitchFadeState extends State<LoopTabSwitchFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: LoopTabSwitchFade.duration,
    value: 1,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void didUpdateWidget(LoopTabSwitchFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
    } else {
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _opacity, child: widget.child);
}

class _DesktopRail extends StatelessWidget {
  const _DesktopRail({required this.selectedIndex, required this.onSelect});

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: NavigationRail(
        selectedIndex: selectedIndex,
        extended: true,
        minExtendedWidth: 212,
        groupAlignment: -0.72,
        backgroundColor: LoopColors.ink,
        indicatorColor: Colors.transparent,
        onDestinationSelected: onSelect,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const LoopBrandMark(kind: LoopBrandMarkKind.appIcon, height: 32),
              const SizedBox(width: 10),
              Text(
                'LOOP',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(letterSpacing: 2.2),
              ),
            ],
          ),
        ),
        destinations: LoopShell._destinations
            .map((item) {
              return NavigationRailDestination(
                icon: LoopIcon(item.icon, color: LoopColors.text2),
                selectedIcon: LoopIcon(item.icon, color: LoopColors.ink),
                label: Text(item.label),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _LoopDestination {
  const _LoopDestination(this.label, this.path, this.icon);

  final String label;
  final String path;

  String get slug => path.substring(1);

  /// Sprite icon name.
  final String icon;
}
