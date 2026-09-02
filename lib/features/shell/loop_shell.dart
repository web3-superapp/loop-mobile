import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';

class LoopShell extends StatelessWidget {
  const LoopShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  static const _destinations = <_LoopDestination>[
    _LoopDestination(
      'Community',
      '/community',
      Icons.groups_outlined,
      Icons.groups_rounded,
    ),
    _LoopDestination(
      'Mining',
      '/mining',
      Icons.bolt_outlined,
      Icons.bolt_rounded,
    ),
    _LoopDestination(
      'Launch',
      '/launch',
      Icons.rocket_launch_outlined,
      Icons.rocket_launch_rounded,
    ),
    _LoopDestination(
      'Market',
      '/market',
      Icons.query_stats_outlined,
      Icons.query_stats_rounded,
    ),
    _LoopDestination(
      'Wallet',
      '/wallet',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
    ),
  ];

  int get _selectedIndex {
    final match = _destinations.indexWhere((item) => location == item.path);
    return match < 0 ? 0 : match;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
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
          body: child,
          bottomNavigationBar: ColoredBox(
            color: LoopColors.ink,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: ClipRRect(
                borderRadius: LoopRadius.large,
                child: NavigationBar(
                  selectedIndex: _selectedIndex,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: (index) =>
                      context.go(_destinations[index].path),
                  destinations: _destinations
                      .map((item) {
                        return NavigationDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: item.label,
                          tooltip: item.label,
                        );
                      })
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
        onDestinationSelected: onSelect,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: LoopColors.lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.all_inclusive_rounded,
                  color: LoopColors.ink,
                  size: 20,
                ),
              ),
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
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: Text(item.label),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _LoopDestination {
  const _LoopDestination(this.label, this.path, this.icon, this.selectedIcon);

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}
