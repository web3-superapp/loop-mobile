import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_tab_segments.dart';

/// `meme` · MEME (decision 0110, S106 §4).
///
/// Two page segments. 发射台 renders the IDO Launch catalogue only while
/// [LoopFeatureSwitches.idoLaunchVisible] is on; otherwise it says the launch
/// pad is coming. 行情 has no source yet: platform MEME assets do not exist,
/// and the segment says so rather than borrowing another list.
class MemeScreen extends ConsumerWidget {
  const MemeScreen({
    super.key,
    this.onOpenLaunch,
    this.onOpenStake,
    this.onOpenRules,
    this.onOpenEconomy,
    this.onOpenApply,
  });

  final void Function(String launchId)? onOpenLaunch;
  final VoidCallback? onOpenStake;
  final VoidCallback? onOpenRules;
  final VoidCallback? onOpenEconomy;
  final VoidCallback? onOpenApply;

  static const segments = <String>['发射台', '行情'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switches = ref.watch(loopFeatureSwitchesProvider);
    return LoopSegmentedTabPage(
      key: const ValueKey<String>('meme-screen'),
      tabKey: 'meme',
      title: 'MEME',
      segments: segments,
      // The 发射台 segment is the Launch page without its bar, so the bar's
      // two tools and its 更新中 move up to the segment row (S106b).
      updating: (ref, index) =>
          index == 0 &&
          switches.idoLaunchVisible &&
          ref.watch(
            launchOverviewControllerProvider.select(
              (state) => state.refreshing,
            ),
          ),
      actionsBuilder: (context, index) =>
          index == 0 && switches.idoLaunchVisible
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
      builder: (context, index) {
        if (index == 0 && switches.idoLaunchVisible) {
          return LaunchScreen(
            embedded: true,
            onOpenLaunch: onOpenLaunch,
            onOpenStake: onOpenStake,
            onOpenRules: onOpenRules,
            onOpenEconomy: onOpenEconomy,
            onOpenApply: onOpenApply,
          );
        }
        return _MemeEmptySegment(
          key: ValueKey<String>(
            index == 0 ? 'meme-launchpad-empty' : 'meme-market-empty',
          ),
          message: index == 0 ? '发射台即将开放' : '平台 MEME 资产上线后在这里显示',
        );
      },
    );
  }
}

class _MemeEmptySegment extends StatelessWidget {
  const _MemeEmptySegment({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return LoopStreamPage(
      archetype: LoopPageArchetype.state,
      title: message,
      embedded: true,
      tabPage: true,
      collection: ListView(
        padding: const EdgeInsets.only(top: 48),
        children: <Widget>[LoopEmpty(message: message)],
      ),
    );
  }
}
