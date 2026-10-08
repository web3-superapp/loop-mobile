import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/features/intel/intel_rank_board.dart';
import 'package:loop_mobile/features/intel/intel_rank_controller.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

/// `intel` · 情报 (decision 0110, S106 §4; redrawn by decision 0118).
///
/// Two page segments: the mining power boards (社区 / 用户 / 推广) and the
/// market list (自选 / 主流 / MEME / 社区代币) under the promotion strip.
class IntelScreen extends ConsumerWidget {
  const IntelScreen({required this.onNavigate, super.key});

  /// Pushes one location (the market list's rows and tools).
  final ValueChanged<String> onNavigate;

  static const segments = <String>['算力榜', '行情'];

  /// Where a promotion card goes (decision 0100 §13). `/intel` is this page:
  /// it opens the 算力榜 segment. `/square` and `/meme` are tabs and are
  /// switched to, never pushed; a community profile is pushed.
  static void openPromotion(
    BuildContext context,
    WidgetRef ref,
    String location,
    ValueChanged<String> push,
  ) {
    switch (location) {
      case '/intel':
        ref.read(loopTabSegmentMemoryProvider.notifier).select('intel', 0);
      case '/square' || '/meme':
        GoRouter.maybeOf(context)?.go(location);
      default:
        push(location);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LoopSegmentedTabPage(
      key: const ValueKey<String>('intel-screen'),
      tabKey: 'intel',
      title: '情报',
      segments: segments,
      // The segment bodies are embedded pages with no bar of their own, so
      // their 更新中 is drawn on the segment row (S106b).
      updating: (ref, index) => index == 0
          ? ref.watch(
              intelRankBoardControllerProvider.select(
                (state) => state.refreshing,
              ),
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
          ? IntelRankBoard(onNavigate: onNavigate)
          : MarketScreen(
              embedded: true,
              onNavigate: onNavigate,
              onOpenPromotion: (location) =>
                  openPromotion(context, ref, location, onNavigate),
            ),
    );
  }
}
