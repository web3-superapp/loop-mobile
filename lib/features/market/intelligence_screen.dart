import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/market/market_widgets.dart';
import 'package:loop_mobile/features/market/scoped_assets_screen.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';

class IntelligenceScreen extends StatefulWidget {
  const IntelligenceScreen({super.key});
  @override
  State<IntelligenceScreen> createState() => _IntelligenceScreenState();
}

class _IntelligenceScreenState extends State<IntelligenceScreen> {
  bool _ranking = false;
  int _scope = 0;
  @override
  Widget build(BuildContext context) {
    final header = MarketTabBar(
      expanded: true,
      key: const ValueKey('intelligence-destinations'),
      keyPrefix: 'intelligence-destination',
      labels: const ['行情', '算力榜'],
      selectedIndex: _ranking ? 1 : 0,
      onSelected: (index) => setState(() => _ranking = index == 1),
    );
    final shortcuts = <Widget>[
      LoopRecordGroup(
        rows: [
          LoopRecordRow(
            title: '我的挖矿',
            leading: const LoopRowIcon(icon: 'mine-tab'),
            onTap: () => context.push('/mining'),
          ),
          LoopRecordRow(
            title: '邀请好友',
            leading: const LoopRowIcon(icon: 'users'),
            onTap: () => context.push('/profile/referral'),
          ),
        ],
      ),
    ];
    if (_ranking) {
      return MiningRankScreen(
        title: '情报',
        sectionsPrefix: [header],
        tabPage: true,
        shortcuts: shortcuts,
      );
    }
    final scopeBar = LoopSegBar(
      labels: const ['全部资产', '平台 MEME', '社区资产'],
      selectedIndex: _scope,
      onSelected: (index) => setState(() => _scope = index),
    );
    if (_scope != 0) {
      return ScopedAssetsScreen(
        scope: _scope == 1
            ? ScopedAssetsScope.platform
            : ScopedAssetsScope.community,
        sectionsPrefix: [header, const SizedBox(height: 12), scopeBar],
      );
    }
    return MarketScreen(
      title: '情报',
      shortcuts: [header, const SizedBox(height: 12)],
      filters: [scopeBar],
    );
  }
}
