import 'package:flutter/material.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/scoped_assets_screen.dart';

/// Keep the existing Launch flow and source-confirmed platform assets together.
class MemeScreen extends StatefulWidget {
  const MemeScreen({
    super.key,
    this.onOpenLaunch,
    this.onOpenStake,
    this.onOpenRules,
    this.onOpenEconomy,
    this.onOpenApply,
  });
  final void Function(String)? onOpenLaunch;
  final VoidCallback? onOpenStake, onOpenRules, onOpenEconomy, onOpenApply;
  @override
  State<MemeScreen> createState() => _MemeScreenState();
}

class _MemeScreenState extends State<MemeScreen> {
  bool _assets = false;
  @override
  Widget build(BuildContext context) {
    final header = MarketTabBar(
      expanded: true,
      key: const ValueKey('meme-destinations'),
      keyPrefix: 'meme-destination',
      labels: const ['发射台', '平台 MEME'],
      selectedIndex: _assets ? 1 : 0,
      onSelected: (index) => setState(() => _assets = index == 1),
    );
    if (!_assets) {
      return LaunchScreen(
        title: 'MEME',
        sectionsPrefix: [header],
        onOpenLaunch: widget.onOpenLaunch,
        onOpenStake: widget.onOpenStake,
        onOpenRules: widget.onOpenRules,
        onOpenEconomy: widget.onOpenEconomy,
        onOpenApply: widget.onOpenApply,
      );
    }
    return ScopedAssetsScreen(
      scope: ScopedAssetsScope.platform,
      title: 'MEME',
      sectionsPrefix: [header],
    );
  }
}
