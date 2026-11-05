import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/navigation/market_asset_route.dart';
import 'package:loop_mobile/core/navigation/intel_power_route.dart';
import 'package:loop_mobile/core/navigation/route_manifest.dart';
import 'package:loop_mobile/features/mining/mining_controllers.dart';
import 'package:loop_mobile/features/mining/mining_screen.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_screen.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

/// `intel` · 情报 (decision 0110, S106 §4; redrawn by decisions 0118, 0272).
///
/// Two page segments: 算力 (decision 0272: the network card, 我的总算力 and
/// the NFT / 代币 / 邀请 tabs) and the market list.
///
/// Deep links (decision 0272): `?tab=power|market` picks the segment,
/// `&sub=nft|token|invite` the tab under 我的总算力, `&code=` an invite
/// link's code for 邀请. The request is applied once and the location is
/// then put back to `/intel`, so the same link opened again applies again.
class IntelScreen extends ConsumerStatefulWidget {
  const IntelScreen({
    required this.onNavigate,
    super.key,
    this.tab,
    this.sub,
    this.inviteCode,
  });

  /// Pushes one location (the market list's rows and tools).
  final ValueChanged<String> onNavigate;

  /// The `tab`, `sub` and `code` query values of the location.
  final String? tab;
  final String? sub;
  final String? inviteCode;

  static List<String> get segments => <String>[
    LoopL10n.current.common_power,
    LoopL10n.current.common_market,
  ];

  /// Where a promotion card goes (decision 0100 §13). `/intel` is this page:
  /// it opens the 算力 segment. `/square` and `/meme` are tabs and are
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
      // `/mining/rank` (S368 · decision 0292) and a community profile are
      // pages over the tab: pushed.
      default:
        push(location);
    }
  }

  @override
  ConsumerState<IntelScreen> createState() => _IntelScreenState();
}

class _IntelScreenState extends ConsumerState<IntelScreen> {
  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(IntelScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab ||
        oldWidget.sub != widget.sub ||
        oldWidget.inviteCode != widget.inviteCode) {
      _apply();
    }
  }

  void _apply() {
    final segment = IntelPowerRoute.segmentOf(widget.tab);
    final sub = IntelPowerTab.tryParse(widget.sub);
    final code = widget.inviteCode;
    if (segment == null && sub == null && code == null) return;
    // Riverpod state may not change while the tree builds; the request is
    // applied right after this frame and the query cleared with it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(loopTabSegmentMemoryProvider.notifier)
          .select('intel', segment ?? 0);
      if (sub != null) ref.read(intelPowerTabProvider.notifier).select(sub);
      if (code != null) {
        ref.read(intelPowerTabProvider.notifier).select(IntelPowerTab.invite);
        ref.read(intelPendingInviteCodeProvider.notifier).hold(code);
      }
      GoRouter.maybeOf(context)?.go(IntelPowerRoute.intelPath);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LoopAtmoPrecache(
      paths: const <String>[
        ...loopAtmosphereTabAssets,
        LoopAtmoAssets.crownYellow,
        LoopAtmoAssets.crownFlat,
      ],
      child: _page(context),
    );
  }

  Widget _page(BuildContext context) {
    final onNavigate = widget.onNavigate;
    return LoopSegmentedTabPage(
      key: const ValueKey<String>('intel-screen'),
      tabKey: 'intel',
      title: context.l10n.intel_screenIntelScreenTitle,
      // Decision 0221: the wall under 情报, its own fog placing.
      backdrop: const LoopWallBackdrop(
        key: ValueKey<String>('intel-atmo-backdrop'),
        fog: LoopWallFog.intel,
        keyPrefix: 'intel-atmo',
      ),
      segments: IntelScreen.segments,
      // The segment bodies are embedded pages with no bar of their own, so
      // their 更新中 is drawn on the segment row (S106b).
      updating: (ref, index) => index == 0
          ? ref.watch(
              miningSummaryControllerProvider.select(
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
                icon: 'alarm',
                label: context.l10n.common_priceAlerts,
                framed: true,
                onPressed: () => onNavigate(MarketAssetRoute.alertsPath),
              ),
            ]
          : <Widget>[
              miningInfoAction(
                summary: ref.watch(miningSummaryControllerProvider).value,
                onOpenRules: () =>
                    onNavigate(LoopRouteManifest.pathFor('mining-rules')),
              ),
            ],
      builder: (context, index) => index == 0
          ? MiningScreen(
              key: const ValueKey<String>('intel-power'),
              embedded: true,
              onNavigate: onNavigate,
              onOpenRank: () =>
                  onNavigate(LoopRouteManifest.pathFor('mining-rank')),
              onOpenRewards: () =>
                  onNavigate(LoopRouteManifest.pathFor('mining-rewards')),
              onOpenRules: () =>
                  onNavigate(LoopRouteManifest.pathFor('mining-rules')),
            )
          : MarketScreen(
              embedded: true,
              onNavigate: onNavigate,
              onOpenPromotion: (location) =>
                  IntelScreen.openPromotion(context, ref, location, onNavigate),
            ),
    );
  }
}
