import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/meme/meme_controllers.dart';
import 'package:loop_mobile/features/meme/meme_launchpad.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

/// `meme` · MEME (decision 0110; MEME curve launchpad, decision 0120).
///
/// 发射台 is the MEME curve launchpad: four chips, the create entry and one
/// row per token. 行情 is the server's `meme` market category. The retired
/// IDO Launch catalogue is hidden, not deleted: while
/// [LoopFeatureSwitchValues.idoLaunchVisible] is on it comes back as a third
/// segment with its own two tools.
class MemeScreen extends ConsumerWidget {
  const MemeScreen({
    super.key,
    this.onNavigate,
    this.onOpenLaunch,
    this.onOpenStake,
    this.onOpenRules,
    this.onOpenEconomy,
    this.onOpenApply,
  });

  /// Where a launchpad row, the create entry or a market row is opened.
  /// `null` pushes the location on the ambient router.
  final void Function(String location)? onNavigate;
  final void Function(String launchId)? onOpenLaunch;
  final VoidCallback? onOpenStake;
  final VoidCallback? onOpenRules;
  final VoidCallback? onOpenEconomy;
  final VoidCallback? onOpenApply;

  static const segments = <String>['发射台', '行情'];

  /// The index of the IDO segment while the switch is on.
  static const int idoSegment = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switches = ref.watch(loopFeatureSwitchesProvider);
    final ido = switches.idoLaunchVisible;
    void open(String location) {
      final navigate = onNavigate;
      if (navigate != null) {
        navigate(location);
        return;
      }
      context.push(location);
    }

    return LoopSegmentedTabPage(
      key: const ValueKey<String>('meme-screen'),
      tabKey: 'meme',
      title: 'MEME',
      segments: <String>[...segments, if (ido) 'IDO'],
      updating: (ref, index) => switch (index) {
        0 => ref.watch(
          memeListControllerProvider(MemeListTab.fresh)
              .select((state) => state.refreshing),
        ),
        idoSegment when ido => ref.watch(
          launchOverviewControllerProvider.select((state) => state.refreshing),
        ),
        _ => false,
      },
      actionsBuilder: (context, index) => index == idoSegment && ido
          ? <Widget>[
              Consumer(
                builder: (context, ref, _) {
                  final overview = ref
                      .watch(launchOverviewControllerProvider)
                      .value;
                  final actions = launchTopbarActions(
                    overview: overview,
                    onOpenStake: onOpenStake,
                    onOpenRules: onOpenRules,
                  );
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (var i = 0; i < actions.length; i += 1) ...<Widget>[
                        if (i > 0) const SizedBox(width: 6),
                        actions[i],
                      ],
                    ],
                  );
                },
              ),
            ]
          : const <Widget>[],
      builder: (context, index) => switch (index) {
        0 => MemeLaunchpadSegment(onNavigate: open),
        idoSegment when ido => LaunchScreen(
          embedded: true,
          onOpenLaunch: onOpenLaunch,
          onOpenStake: onOpenStake,
          onOpenRules: onOpenRules,
          onOpenEconomy: onOpenEconomy,
          onOpenApply: onOpenApply,
        ),
        _ => MemeMarketSegment(onNavigate: open),
      },
    );
  }
}
