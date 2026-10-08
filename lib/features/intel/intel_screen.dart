import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_secondary_screens.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

/// `intel` · 情报 (decision 0110, S106 §4).
///
/// Two page segments: the mining power boards (社区 / 用户 / 推广) and the
/// market list without 新币 and 聪明钱, whose pages stay mounted at their own
/// locations.
class IntelScreen extends StatelessWidget {
  const IntelScreen({required this.onNavigate, super.key});

  /// Pushes one location (the market list's rows and tools).
  final ValueChanged<String> onNavigate;

  static const segments = <String>['算力榜', '行情'];

  @override
  Widget build(BuildContext context) {
    return LoopSegmentedTabPage(
      key: const ValueKey<String>('intel-screen'),
      tabKey: 'intel',
      title: '情报',
      segments: segments,
      // The segment bodies are embedded pages with no bar of their own, so
      // their 更新中 is drawn on the segment row (S106b).
      updating: (ref, index) => index == 0
          ? ref.watch(
              miningRankControllerProvider.select((state) => state.refreshing),
            )
          : ref.watch(
              marketOverviewControllerProvider.select(
                (state) => state.refreshing,
              ),
            ),
      actionsBuilder: (context, index) => index == 1
          ? <Widget>[
              LoopIconButton(
                key: const ValueKey<String>('intel-alerts-action'),
                icon: 'bell',
                label: '价格提醒',
                framed: true,
                onPressed: () => onNavigate(MarketAssetRoute.alertsPath),
              ),
            ]
          : const <Widget>[],
      builder: (context, index) => index == 0
          ? const MiningRankScreen(embedded: true, includeReferralScope: true)
          : MarketScreen(
              embedded: true,
              hideOutboundLists: true,
              onNavigate: onNavigate,
            ),
    );
  }
}
