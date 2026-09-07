import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';

/// Five-destination shell (chapter 5.4).
///
/// Mobile: a solid Chalk floating bar, only on the five tab routes; the page
/// body extends behind it and receives a `90 + safe-area` bottom padding.
/// Widths from [LoopLayout.railBreakpoint] use a navigation rail instead.
class LoopShell extends StatelessWidget {
  const LoopShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  static const _destinations = <_LoopDestination>[
    _LoopDestination('Community', '/community', 'community'),
    _LoopDestination('Mining', '/mining', 'mine-tab'),
    _LoopDestination('Launch', '/launch', 'launch'),
    _LoopDestination('Market', '/market', 'chart'),
    _LoopDestination('Wallet', '/wallet', 'wallet'),
  ];

  /// Labels in shell order, for tests and the desktop rail.
  static List<String> get destinationLabels =>
      _destinations.map((item) => item.label).toList(growable: false);

  static List<String> get destinationPaths =>
      _destinations.map((item) => item.path).toList(growable: false);

  int get _selectedIndex {
    final match = _destinations.indexWhere((item) => location == item.path);
    return match < 0 ? 0 : match;
  }

  @override
  Widget build(BuildContext context) {
    assert(
      destinationPaths.join(',') == LoopRouteManifest.tabPaths.join(','),
      'LoopShell destinations must follow the manifest tab order.',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= LoopLayout.railBreakpoint;
        if (wide) {
          return Scaffold(
            body: Row(
              children: <Widget>[
                _DesktopRail(
                  selectedIndex: _selectedIndex,
                  onSelect: (index) => context.go(_destinations[index].path),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: LoopColors.line,
                ),
                Expanded(child: child),
              ],
            ),
          );
        }
        return Scaffold(
          extendBody: true,
          body: child,
          bottomNavigationBar: LoopTabBar(
            selectedIndex: _selectedIndex,
            onSelect: (index) => context.go(_destinations[index].path),
          ),
        );
      },
    );
  }
}

/// The floating Chalk tab bar.
///
/// Outer box height is `90 + safe-area-bottom`; with `Scaffold.extendBody`
/// that is exactly the reserve the body receives as bottom padding. Inside,
/// the 70px bar sits `max(8, safe-area)` from the edges with a 23px radius.
class LoopTabBar extends StatelessWidget {
  const LoopTabBar({
    required this.selectedIndex,
    required this.onSelect,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final bottomInset = math.max(LoopLayout.tabBarInset, padding.bottom);
    final leftInset = math.max(LoopLayout.tabBarInset, padding.left);
    final rightInset = math.max(LoopLayout.tabBarInset, padding.right);
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
              decoration: BoxDecoration(
                color: LoopColors.chalk,
                borderRadius: LoopRadius.tabBar,
                boxShadow: LoopDepth.tabBar,
                border: const Border(
                  top: BorderSide(color: LoopDepth.tabBarEdge),
                ),
              ),
              child: Row(
                children: <Widget>[
                  for (
                    var index = 0;
                    index < LoopShell._destinations.length;
                    index++
                  )
                    Expanded(
                      child: LoopTabItem(
                        label: LoopShell._destinations[index].label,
                        icon: LoopShell._destinations[index].icon,
                        selected: index == selectedIndex,
                        onTap: () => onSelect(index),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab cell: Lime gradient with Ink glyph when selected, Ink 62% otherwise.
class LoopTabItem extends StatelessWidget {
  const LoopTabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? LoopColors.ink : LoopColors.inkMuted;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: ValueKey<String>('loop-tab-${label.toLowerCase()}'),
          onTap: onTap,
          borderRadius: LoopRadius.control,
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(
              minHeight: LoopTouch.tabCellMinHeight,
              minWidth: LoopTouch.minimum,
            ),
            decoration: BoxDecoration(
              borderRadius: LoopRadius.control,
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        LoopColors.limeHighlight,
                        LoopColors.lime,
                      ],
                      stops: <double>[0, 0.64],
                    )
                  : null,
              boxShadow: selected ? LoopDepth.tabSelected : null,
              border: selected
                  ? const Border(
                      top: BorderSide(color: LoopDepth.tabSelectedEdge),
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                LoopIcon(icon, size: 21, color: color),
                const SizedBox(height: 3),
                ExcludeSemantics(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LoopTypography.sora(
                      size: 11,
                      weight: FontWeight.w700,
                      height: 1.2,
                      letterSpacing: 0.17,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Page wrapper for the five tab routes: peers switch with a fade only.
class LoopTabPage<T> extends CustomTransitionPage<T> {
  LoopTabPage({required super.child, super.key, super.name})
    : super(
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      );
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
        indicatorColor: LoopColors.lime,
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

  /// Sprite icon name.
  final String icon;
}
