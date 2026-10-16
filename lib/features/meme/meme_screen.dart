import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/features/launch/launch_controllers.dart';
import 'package:loop_mobile/features/launch/launch_screen.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_entry.dart';
import 'package:loop_mobile/features/launch2/launch2_controllers.dart'; // S136
import 'package:loop_mobile/features/launch2/launch2_list.dart'; // S136
import 'package:loop_mobile/features/launch2/launch2_models.dart'; // S136
import 'package:loop_mobile/features/meme/meme_controllers.dart';
import 'package:loop_mobile/features/meme/meme_launchpad.dart';
import 'package:loop_mobile/features/meme/meme_models.dart';
import 'package:loop_mobile/features/meme/meme_routes.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
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

  /// S136 · decision 0139: the three segments while MEME v2 is shown —
  /// v2 instances, the S117 curve launchpad as 「经典」, graduated v2
  /// instances. The `meme` market category stays on 行情 (`/market`).
  static const v2Segments = <String>['v2 发射', '经典', '已毕业'];

  /// Decision 0195: while classic launches are retired the curve segment
  /// keeps its tokens (they stay readable and tradable) under 「历史」, so a
  /// new reader is not told 经典 is a way to launch.
  static const v2SegmentsClassicRetired = <String>['v2 发射', '历史', '已毕业'];

  /// The index of the IDO segment while the switch is on.
  static const int idoSegment = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switches = ref.watch(loopFeatureSwitchesProvider);
    final ido = switches.idoLaunchVisible;
    // S136 · decision 0139: drawn only with the build switch on and the
    // server's `launch2` capability available; otherwise exactly as before.
    if (launch2SurfaceVisible(ref)) return _v2(context, ref, ido: ido);
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

  // S136 · decision 0139: 「v2 发射 / 经典 / 已毕业」, IDO fourth when its
  // switch is on.
  Widget _v2(BuildContext context, WidgetRef ref, {required bool ido}) {
    void open(String location) {
      final navigate = onNavigate;
      if (navigate != null) {
        navigate(location);
        return;
      }
      context.push(location);
    }

    void select(int index) =>
        ref.read(loopTabSegmentMemoryProvider.notifier).select('meme', index);
    final idoIndex = v2Segments.length;
    final classic = ref
        .watch(loopFeatureSwitchesProvider)
        .classicMemeLaunchVisible;
    return LoopSegmentedTabPage(
      key: const ValueKey<String>('meme-screen'),
      tabKey: 'meme',
      title: 'MEME',
      segments: <String>[
        ...(classic ? v2Segments : v2SegmentsClassicRetired),
        if (ido) 'IDO',
      ],
      actionsBuilder: (context, index) => index == idoIndex && ido
          ? <Widget>[
              Consumer(
                builder: (context, ref, _) {
                  final actions = launchTopbarActions(
                    overview: ref.watch(launchOverviewControllerProvider).value,
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
          // S148 · decision 0146: 「我的项目」 + 「发起」 on the two v2
          // lists; 经典 keeps its own 「创建代币」 line.
          : index == 0 || index == 2
          ? <Widget>[
              Launch2CreatorActions(
                onNavigate: open,
                classicCreatePath: MemeRoute.createPath,
              ),
            ]
          // Decision 0176 (design 35 首页): 经典's search and create sit in
          // the bar, as the design's top bar carries its search.
          : index == 1
          ? <Widget>[
              Consumer(
                builder: (context, ref, _) {
                  final blocked = memeReadsBlocked(ref);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      LoopIconButton(
                        key: const ValueKey<String>('meme-search-entry'),
                        icon: 'search',
                        label: '搜索代币',
                        onPressed: () => open('/search'),
                      ),
                      // Decision 0195: no classic create while retired.
                      if (classic) ...<Widget>[
                        const SizedBox(width: 6),
                        LoopIconButton(
                          key: const ValueKey<String>('meme-create-entry'),
                          icon: 'plus',
                          label: '创建代币',
                          onPressed: blocked
                              ? null
                              : () => open(MemeRoute.createPath),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ]
          : const <Widget>[],
      updating: (ref, index) => switch (index) {
        0 => ref.watch(
          launch2ListControllerProvider(Launch2ListScope.all)
              .select((state) => state.refreshing),
        ),
        1 => ref.watch(
          memeListControllerProvider(MemeListTab.fresh)
              .select((state) => state.refreshing),
        ),
        2 => ref.watch(
          launch2ListControllerProvider(Launch2ListScope.graduated)
              .select((state) => state.refreshing),
        ),
        _ => false,
      },
      builder: (context, index) => switch (index) {
        0 => Launch2ListSegment(
          scope: Launch2ListScope.all,
          onNavigate: open,
          onEmptyAction: () => select(1),
          onOpenGraduated: () => select(2),
        ),
        1 => MemeLaunchpadSegment(
          onNavigate: open,
          onOpenGraduated: () => select(2),
          toolsInTopbar: true,
        ),
        _ when ido && index == idoIndex => LaunchScreen(
          embedded: true,
          onOpenLaunch: onOpenLaunch,
          onOpenStake: onOpenStake,
          onOpenRules: onOpenRules,
          onOpenEconomy: onOpenEconomy,
          onOpenApply: onOpenApply,
        ),
        _ => Launch2ListSegment(
          scope: Launch2ListScope.graduated,
          onNavigate: open,
          onEmptyAction: () => select(0),
        ),
      },
    );
  }
}
