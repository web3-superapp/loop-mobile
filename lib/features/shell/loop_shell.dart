import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/beta_feedback/beta_feedback_entry.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_unread_badge.dart';
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
    this.attention = const <String>{},
  });

  final Widget child;
  final String location;
  final StatefulNavigationShell? navigationShell;

  /// The tab slugs that carry a small red dot (S343 · decision 0271: 我的
  /// while a notification is unread or a stranger request waits).
  final Set<String> attention;

  static const _destinations = <_LoopDestination>[
    // v3 (需求方 2026-10-08, decision 0110): 聊天/广场/MEME/情报/钱包.
    // S343 · decision 0271: 钱包 became 我的 with a person glyph; its path
    // and slug stay `/wallet`. Slugs stay the stable test and analytics
    // identifiers.
    _LoopDestination('聊天', chatPath, 'chat'),
    _LoopDestination('广场', '/square', 'compass'),
    _LoopDestination('MEME', '/meme', 'launch'),
    _LoopDestination('情报', '/intel', 'chart'),
    _LoopDestination('我的', '/wallet', 'user'),
  ];

  /// Labels in shell order, for tests and the desktop rail.
  static List<String> get destinationLabels =>
      _destinations.map((item) => item.label).toList(growable: false);

  /// 聊天's root, where the inbox floats its 「发起」 key (decision 0123).
  static const String chatPath = '/chat';

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

  /// S332 · decision 0262: the floating 意见反馈 entry, over the tabs and
  /// under every pushed page, only in a build whose switch is on. The key's
  /// lowest place is [tabBarReserve] + the safe area + 12.
  ///
  /// S337 · decision 0266: on 聊天 the inbox floats its 「发起」 key in the
  /// same corner, [LoopLayout.tabPageBottomReserve] over the page's bottom
  /// inset and [LoopLayout.floatingActionExtent] tall; where the entry's
  /// default place would come within 12 of it, the default is lifted to 12
  /// over that key.
  Widget _withFeedbackEntry(
    BuildContext context,
    Widget page, {
    required double tabBarReserve,
  }) {
    if (!loopFeatureSwitchesOf(context).betaFeedbackVisible) return page;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final lowestBottom =
        tabBarReserve + safeBottom + BetaFeedbackEntry.gapOverTabBar;
    var floorLift = 0.0;
    if (Uri.tryParse(widget.location)?.path == LoopShell.chatPath) {
      // The inbox stands its key [LoopLayout.tabPageBottomReserve] over its
      // own bottom inset, which under the bar is the bar's reserve.
      final createBottom =
          safeBottom + tabBarReserve + LoopLayout.tabPageBottomReserve;
      final createTop = createBottom + LoopLayout.floatingActionExtent;
      final overlaps =
          lowestBottom < createTop + BetaFeedbackEntry.gapOverTabBar &&
          lowestBottom + BetaFeedbackEntry.size >
              createBottom - BetaFeedbackEntry.gapOverTabBar;
      if (overlaps) {
        floorLift = createTop + BetaFeedbackEntry.gapOverTabBar - lowestBottom;
      }
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(child: page),
        Positioned.fill(
          child: BetaFeedbackEntry(
            location: widget.location,
            lowestBottom: lowestBottom,
            floorLift: floorLift,
            onOpen: (origin) => unawaited(
              context.push(
                LoopRouteManifest.pathFor('beta-feedback'),
                extra: origin,
              ),
            ),
          ),
        ),
      ],
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
          final page = Scaffold(
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
          return _withFeedbackEntry(context, page, tabBarReserve: 0);
        }
        // Decision 0226: the page runs under the floating bar to the very
        // bottom of the screen — the wall included — and the system
        // navigation bar draws no scrim of its own over it.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: loopTabSystemOverlay,
          child: LoopTabBarScope(
            child: _withFeedbackEntry(
              context,
              Scaffold(
                extendBody: true,
                body: widget.child,
                bottomNavigationBar: LoopTabBar(
                  selectedIndex: selectedIndex,
                  onSelect: (index) => _select(context, index),
                  attention: widget.attention,
                ),
              ),
              tabBarReserve: LoopLayout.tabPageBottomReserve,
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

/// The tab bar's ground (decision 0226): the card surface, see-through.
/// S326 · decision 0256 (UX-004 ⑦): 72 % over a background blur
/// ([loopTabBarBlur]) — the page under the bar is frosted, not hidden.
const Color loopTabBarGround = Color(0xB8111114);

/// The blur under the tab bar (decision 0256).
const double loopTabBarBlur = 20;

/// The tab bar's light edge on all four sides (decision 0256): it reads as
/// a floating object, not a strip that slipped off the screen's foot.
const Color loopTabBarEdge = Color(0x24FFFFFF);

/// The floating Chalk tab bar.
///
/// Outer box height is `90 + safe-area-bottom`; with `Scaffold.extendBody`
/// that is exactly the reserve the body receives as bottom padding. Inside,
/// the 70px bar sits `max(8, safe-area)` from the edges with a 23px radius.
///
/// S331 · decision 0261 (overturns decision 0212's "no colour block"): the
/// selected cell stands on one visible glass pill. Switching tabs stretches
/// that single pill from the tab that had it across to the tab that takes it
/// — the leading edge runs ahead, the trailing edge follows and settles with
/// a slight spring — so nothing appears and nothing disappears (decision
/// 0071). A press anywhere on the bar swells the whole bar by 2 %. Material's
/// ripple and highlight are removed — a grey wash under the finger reads as a
/// second, contradicting selection.
class LoopTabBar extends StatefulWidget {
  const LoopTabBar({
    required this.selectedIndex,
    required this.onSelect,
    super.key,
    this.attention = const <String>{},
  });

  /// The tab slugs that carry a small red dot.
  final Set<String> attention;

  /// Indicator travel, and the cells' ink crossfade over the same time.
  static const Duration slideDuration = Duration(milliseconds: 280);
  static const Curve slideCurve = Curves.easeOutCubic;

  /// The leading edge's share of [slideDuration]: it runs out first, so the
  /// pill's first frame already spans both cells.
  static const Interval leadInterval = Interval(
    0,
    0.62,
    curve: Curves.easeOutCubic,
  );

  /// The trailing edge's share: it starts late and springs into place.
  static const double trailBegin = 0.22;

  /// The trailing edge's overshoot past its rest, in cells.
  static const double trailOvershoot = 0.06;

  /// Glass pill (decision 0261): white 10 % over the bar's ground, a 1 px
  /// white 8 % edge inside, inset 4 from its cell on every side.
  static const Color indicatorFill = Color(0x1AFFFFFF);
  static const Color indicatorEdge = Color(0x14FFFFFF);
  static const double indicatorInset = 4;

  /// Press feedback on the whole bar (decision 0261).
  static const double pressScale = 1.02;
  static const Duration pressDuration = Duration(milliseconds: 120);

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  State<LoopTabBar> createState() => _LoopTabBarState();
}

class _LoopTabBarState extends State<LoopTabBar> with TickerProviderStateMixin {
  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: LoopTabBar.slideDuration,
    value: 1,
  );
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: LoopTabBar.pressDuration,
  );
  late final Animation<double> _pressScale = Tween<double>(
    begin: 1,
    end: LoopTabBar.pressScale,
  ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));

  // The pill's edges in cell units: cell i spans [i, i + 1].
  late double _fromLeft = widget.selectedIndex.toDouble();
  late double _fromRight = widget.selectedIndex + 1.0;
  late double _toLeft = _fromLeft;
  late double _toRight = _fromRight;
  bool _towardsEnd = true;
  Curve _trailCurve = Curves.easeOutCubic;

  @override
  void didUpdateWidget(LoopTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex == widget.selectedIndex) return;
    final target = widget.selectedIndex.toDouble();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _slide.value = 1;
      _fromLeft = _toLeft = target;
      _fromRight = _toRight = target + 1;
      return;
    }
    // A second tap mid-flight carries on from where the pill is now.
    final (left, right) = _edges();
    _fromLeft = left;
    _fromRight = right;
    _toLeft = target;
    _toRight = target + 1;
    _towardsEnd = (_toLeft + _toRight) >= (left + right);
    final trailTravel = _towardsEnd
        ? (_toLeft - _fromLeft).abs()
        : (_toRight - _fromRight).abs();
    _trailCurve = trailTravel <= 0
        ? Curves.easeOutCubic
        : LoopBoundedBackCurve(
            overshoot: math.min(0.1, LoopTabBar.trailOvershoot / trailTravel),
          );
    unawaited(_slide.forward(from: 0));
  }

  /// The pill's left and right edges, in cell units, at this frame.
  (double, double) _edges() {
    final t = _slide.value;
    if (t >= 1) return (_toLeft, _toRight);
    final lead = LoopTabBar.leadInterval.transform(t);
    final trail = Interval(
      LoopTabBar.trailBegin,
      1,
      curve: _trailCurve,
    ).transform(t);
    double lerp(double a, double b, double f) => a + (b - a) * f;
    return _towardsEnd
        ? (lerp(_fromLeft, _toLeft, trail), lerp(_fromRight, _toRight, lead))
        : (lerp(_fromLeft, _toLeft, lead), lerp(_fromRight, _toRight, trail));
  }

  void _pressDown(bool reduceMotion) {
    if (reduceMotion) return;
    unawaited(_press.forward());
  }

  void _pressUp() {
    if (_press.value == 0 && !_press.isAnimating) return;
    unawaited(_press.reverse());
  }

  @override
  void dispose() {
    _slide.dispose();
    _press.dispose();
    super.dispose();
  }

  Widget _indicator(double shift) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = constraints.maxWidth / LoopShell._destinations.length;
        const inset = LoopTabBar.indicatorInset;
        return AnimatedBuilder(
          animation: _slide,
          builder: (context, _) {
            final reduceMotion = MediaQuery.disableAnimationsOf(context);
            final (leftCells, rightCells) = reduceMotion
                ? (widget.selectedIndex.toDouble(), widget.selectedIndex + 1.0)
                : _edges();
            final left = leftCells * cell + inset + shift;
            final width = math.max(
              0.0,
              (rightCells - leftCells) * cell - 2 * inset,
            );
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: left,
                  top: inset,
                  bottom: inset,
                  width: width,
                  // Decision 0261 overturns decision 0212: the bar carries a
                  // visible glass pill under the selected cell again.
                  child: const DecoratedBox(
                    key: ValueKey<String>('loop-tab-indicator'),
                    decoration: ShapeDecoration(
                      color: LoopTabBar.indicatorFill,
                      shape: StadiumBorder(
                        side: BorderSide(color: LoopTabBar.indicatorEdge),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final bottomInset = math.max(LoopLayout.tabBarInset, padding.bottom);
    final leftInset = math.max(LoopLayout.tabBarInset, padding.left);
    final rightInset = math.max(LoopLayout.tabBarInset, padding.right);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final count = LoopShell._destinations.length;
    final selectedIndex = widget.selectedIndex;
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
            // Decision 0261: the whole bar swells 2 % under a press. The
            // scale sits outside the shadow, the clip and the blur, so the
            // frosted area grows with the bar instead of being cut.
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _pressDown(reduceMotion),
              onPointerUp: (_) => _pressUp(),
              onPointerCancel: (_) => _pressUp(),
              child: ScaleTransition(
                key: const ValueKey<String>('loop-tab-bar-press'),
                scale: reduceMotion
                    ? const AlwaysStoppedAnimation<double>(1)
                    : _pressScale,
                child: DecoratedBox(
                  key: const ValueKey<String>('loop-tab-bar-float'),
                  // S326 · decision 0256: a soft shadow under the bar lifts it
                  // off the page.
                  decoration: const BoxDecoration(
                    borderRadius: LoopRadius.tabBar,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: LoopRadius.tabBar,
                    child: BackdropFilter(
                      key: const ValueKey<String>('loop-tab-bar-blur'),
                      filter: ImageFilter.blur(
                        sigmaX: loopTabBarBlur,
                        sigmaY: loopTabBarBlur,
                      ),
                      // The light edge all round is painted over the bar, so
                      // the cells keep their geometry.
                      child: DecoratedBox(
                        key: const ValueKey<String>('loop-tab-bar-edge'),
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          borderRadius: LoopRadius.tabBar,
                          border: Border.all(color: loopTabBarEdge),
                        ),
                        child: Container(
                          height: LoopTouch.tabBarHeight,
                          padding: const EdgeInsets.all(
                            LoopLayout.tabBarPadding,
                          ),
                          // S264 (decision 0220): a 1 px chrome line runs
                          // along the bar's top edge — S326 · decision 0256:
                          // dimmed, over a light edge all round.
                          foregroundDecoration: const _ChromeEdge(),
                          decoration: BoxDecoration(
                            // Decision 0226: the safe area under the bar is
                            // clear.
                            color: loopTabBarGround,
                            borderRadius: LoopRadius.tabBar,
                          ),
                          child: LoopDockBar(
                            count: count,
                            selectedIndex: selectedIndex,
                            onSelect: widget.onSelect,
                            // The pill follows its cell's glyph sideways while
                            // the row makes room under a sliding finger; at
                            // rest the shift is 0.
                            backgroundBuilder: (context, cells) =>
                                _indicator(cells[selectedIndex].shift),
                            cellBuilder: (context, index, cell) => LoopTabItem(
                              label: LoopShell._destinations[index].label,
                              slug: LoopShell._destinations[index].slug,
                              icon: LoopShell._destinations[index].icon,
                              selected: index == selectedIndex,
                              dot: widget.attention.contains(
                                LoopShell._destinations[index].slug,
                              ),
                              dock: cell,
                              onTap: () => widget.onSelect(index),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `easeOutBack` with its overshoot bounded (decision 0261): the curve
/// `1 + (s + 1)(t − 1)³ + s(t − 1)²` peaks at `4s³ / 27(s + 1)²` past 1, so
/// [overshoot] picks `s`; 0 is `easeOutCubic`, about 0.1 is `easeOutBack`.
class LoopBoundedBackCurve extends Curve {
  LoopBoundedBackCurve({required this.overshoot}) : _s = _solve(overshoot);

  /// The peak past 1, as a fraction of the travel.
  final double overshoot;
  final double _s;

  static double peakFor(double s) => 4 * s * s * s / (27 * (s + 1) * (s + 1));

  static double _solve(double overshoot) {
    if (overshoot <= 0) return 0;
    var lo = 0.0;
    var hi = 20.0;
    for (var i = 0; i < 48; i += 1) {
      final mid = (lo + hi) / 2;
      if (peakFor(mid) < overshoot) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  @override
  double transformInternal(double t) {
    final x = t - 1;
    return 1 + (_s + 1) * x * x * x + _s * x * x;
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
        // S326 · decision 0256 (UX-004 ⑦): the highlight at about a third of
        // its old strength, so the top edge no longer outshines the rest.
        colors: <Color>[
          Color(0x003A3A42),
          Color(0x339A9AA3),
          Color(0x59F0F0F3),
          Color(0x339A9AA3),
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
/// The cell draws no ground of its own — [LoopTabBar]'s single glass pill
/// is the ground, and it stretches across (decision 0261). The cell only
/// crossfades its own ink over the same 280 ms, so on the first frame both
/// the old and the new cell are lit and the old one greys as the pill
/// leaves.
class LoopTabItem extends StatelessWidget {
  const LoopTabItem({
    required this.label,
    required this.slug,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
    this.dock = LoopDockCell.rest,
    this.dot = false,
  });

  final String label;

  /// A small red dot on the glyph's corner (S343 · decision 0271).
  final bool dot;

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
      label: dot ? '$label，有新消息' : label,
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
                      LoopTabGlyphMotion(
                        icon: icon,
                        slug: slug,
                        selected: selected,
                        child: SizedBox(
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
                                          errorBuilder: (
                                            context,
                                            error,
                                            stack,
                                          ) => const SizedBox.shrink(),
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
                                    key: ValueKey<String>(
                                      'loop-tab-core-$slug',
                                    ),
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
                              if (dot)
                                Positioned(
                                  top: -1,
                                  right: -3,
                                  child: IgnorePointer(
                                    child: LoopUnreadBadge(
                                      key: ValueKey<String>(
                                        'loop-tab-dot-$slug',
                                      ),
                                      count: 1,
                                      dot: true,
                                    ),
                                  ),
                                ),
                            ],
                          ),
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

/// One tab glyph's move when its tab becomes selected (S331 · decision
/// 0261): [t] runs 0 → 1 linearly over [duration]; [at] gives the glyph's
/// transform about [alignment] at that point, the identity at both ends.
@immutable
class LoopTabGlyphMove {
  const LoopTabGlyphMove({
    required this.duration,
    required this.at,
    this.alignment = Alignment.center,
  });

  final Duration duration;
  final Matrix4 Function(double t) at;
  final Alignment alignment;
}

/// The selected-moment move of each tab glyph (decision 0261), by icon:
/// the bubble nods, the compass needle turns a full circle, the rocket lifts
/// off and drops back, the bars grow again, the wallet flips on its upright.
class LoopTabGlyphMotion extends StatefulWidget {
  const LoopTabGlyphMotion({
    required this.icon,
    required this.slug,
    required this.selected,
    required this.child,
    super.key,
  });

  final String icon;
  final String slug;
  final bool selected;
  final Widget child;

  static const double _degree = math.pi / 180;

  /// 0 → 1 → 0 over [t]: rising on [rise] up to [peakAt], falling on [fall].
  static double _hump(double t, double peakAt, Curve rise, Curve fall) =>
      t <= peakAt
      ? rise.transform(t / peakAt)
      : 1 - fall.transform((t - peakAt) / (1 - peakAt));

  /// Piecewise keyframes: [values] at [stops], each segment on [curves].
  static double _keys(
    double t,
    List<double> stops,
    List<double> values,
    List<Curve> curves,
  ) {
    for (var i = 1; i < stops.length; i += 1) {
      if (t <= stops[i]) {
        final f = curves[i - 1].transform(
          (t - stops[i - 1]) / (stops[i] - stops[i - 1]),
        );
        return values[i - 1] + (values[i] - values[i - 1]) * f;
      }
    }
    return values.last;
  }

  static final Map<String, LoopTabGlyphMove> moves = <String, LoopTabGlyphMove>{
    // 聊天: scale 1 → 1.18 → 1 while tilting 0 → −8° → 0.
    'chat': LoopTabGlyphMove(
      duration: const Duration(milliseconds: 320),
      at: (t) {
        final p = _hump(t, 0.4, Curves.easeOutBack, Curves.easeOut);
        final scale = 1 + 0.18 * p;
        return Matrix4.rotationZ(-8 * _degree * p)
          ..scaleByDouble(scale, scale, 1, 1);
      },
    ),
    // 广场: the whole compass turns once; the ring is symmetric, so the eye
    // sees the needle sweep round.
    'compass': LoopTabGlyphMove(
      duration: const Duration(milliseconds: 420),
      at: (t) =>
          Matrix4.rotationZ(2 * math.pi * Curves.easeOutCubic.transform(t)),
    ),
    // MEME: the rocket lifts (+2, −3) px tilting −6°, then drops back.
    'launch': LoopTabGlyphMove(
      duration: const Duration(milliseconds: 320),
      at: (t) {
        final p = _hump(t, 0.5, Curves.easeOut, Curves.easeOutBack);
        return Matrix4.translationValues(2 * p, -3 * p, 0)
          ..rotateZ(-6 * _degree * p);
      },
    ),
    // 情报: the bars shrink and grow again from the baseline,
    // scaleY 1 → 0.72 → 1.08 → 1; x is untouched.
    'chart': LoopTabGlyphMove(
      duration: const Duration(milliseconds: 360),
      alignment: Alignment.bottomCenter,
      at: (t) => Matrix4.diagonal3Values(
        1,
        _keys(
          t,
          const <double>[0, 0.25, 0.6, 1],
          const <double>[1, 0.72, 1.08, 1],
          const <Curve>[Curves.easeOut, Curves.easeOut, Curves.easeInOut],
        ),
        1,
      ),
    ),
    // 我的 (S343 · decision 0271): the person nods, scale 1 → 1.14 → 1
    // rising 2 px.
    'user': LoopTabGlyphMove(
      duration: const Duration(milliseconds: 320),
      at: (t) {
        final p = _hump(t, 0.45, Curves.easeOutBack, Curves.easeOut);
        final scale = 1 + 0.14 * p;
        return Matrix4.translationValues(0, -2 * p, 0)
          ..scaleByDouble(scale, scale, 1, 1);
      },
    ),
    // 钱包: a flip on the upright axis, rotateY 0 → −0.45 rad → 0.
    'wallet': LoopTabGlyphMove(
      duration: const Duration(milliseconds: 340),
      at: (t) {
        final p = _hump(t, 0.5, Curves.easeInOut, Curves.easeInOut);
        return Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateY(-0.45 * p);
      },
    ),
  };

  @override
  State<LoopTabGlyphMotion> createState() => _LoopTabGlyphMotionState();
}

class _LoopTabGlyphMotionState extends State<LoopTabGlyphMotion>
    with SingleTickerProviderStateMixin {
  LoopTabGlyphMove? get _move => LoopTabGlyphMotion.moves[widget.icon];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _move?.duration ?? Duration.zero,
    value: 1,
  );

  @override
  void didUpdateWidget(LoopTabGlyphMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the moment a tab becomes selected moves its glyph; deselecting
    // plays nothing backwards — the ink fades out on its own.
    if (oldWidget.selected || !widget.selected || _move == null) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    unawaited(_controller.forward(from: 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final move = _move;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final rest = move == null || reduceMotion || t <= 0 || t >= 1;
        return Transform(
          key: ValueKey<String>('loop-tab-glyph-motion-${widget.slug}'),
          alignment: move?.alignment ?? Alignment.center,
          transform: rest ? Matrix4.identity() : move.at(t),
          child: child,
        );
      },
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
