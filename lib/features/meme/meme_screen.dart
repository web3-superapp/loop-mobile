import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
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
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
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

  /// S259 · decision 0217: with the IDO switch on, the v2 desk and IDO are
  /// the only two segments; otherwise the MEME Tab has no segment row.
  static const v2SegmentsWithIdo = <String>['发射台', 'IDO'];

  /// The index of the IDO segment while the switch is on.
  static const int idoSegment = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final switches = ref.watch(loopFeatureSwitchesProvider);
    final ido = switches.idoLaunchVisible;
    // S136 · decision 0139: the v2 desk is drawn only with the build switch
    // on and the server's `launch2` capability available.
    // S259 · decision 0217: with the switch on but the capability closed or
    // not read yet, the Tab says so in one line — never the retired classic
    // list.
    final v2 = launch2SurfaceVisible(ref);
    if (v2 || switches.launch2Visible) {
      return _v2(context, ref, ido: ido, available: v2);
    }
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

  // S259 · decision 0217: the v2 desk is the whole Tab — no 「v2 发射 / 历史
  // / 已毕业」 row; the classic curve list has no entry. S279 · decision
  // 0237: the desk's own 「内盘 / 预告 / 已毕业」 tabs choose its one list (tap
  // only, so they nest under the segment row's swipe). IDO comes back as a
  // second segment only while its switch is on.
  Widget _v2(
    BuildContext context,
    WidgetRef ref, {
    required bool ido,
    required bool available,
  }) {
    void open(String location) {
      final navigate = onNavigate;
      if (navigate != null) {
        navigate(location);
        return;
      }
      context.push(location);
    }

    Widget creatorActions() => Launch2CreatorActions(
      onNavigate: open,
      classicCreatePath: MemeRoute.createPath,
    );
    if (!ido && !available) return const _MemeV2Closed();
    if (!ido) {
      return KeyedSubtree(
        key: const ValueKey<String>('meme-screen'),
        child: Launch2ListSegment(
          scope: Launch2ListScope.all,
          onNavigate: open,
          tabTitle: 'MEME',
          actions: <Widget>[creatorActions()],
        ),
      );
    }
    return LoopSegmentedTabPage(
      key: const ValueKey<String>('meme-screen'),
      tabKey: 'meme',
      title: 'MEME',
      segments: v2SegmentsWithIdo,
      actionsBuilder: (context, index) => index == 1
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
          : <Widget>[creatorActions()],
      updating: (ref, index) => switch (index) {
        0 => ref.watch(
          launch2ListControllerProvider(Launch2ListScope.all)
              .select((state) => state.refreshing),
        ),
        _ => ref.watch(
          launchOverviewControllerProvider.select((state) => state.refreshing),
        ),
      },
      builder: (context, index) => switch (index) {
        0 when !available => const _MemeV2Closed(embedded: true),
        0 => Launch2ListSegment(scope: Launch2ListScope.all, onNavigate: open),
        _ => LaunchScreen(
          embedded: true,
          onOpenLaunch: onOpenLaunch,
          onOpenStake: onOpenStake,
          onOpenRules: onOpenRules,
          onOpenEconomy: onOpenEconomy,
          onOpenApply: onOpenApply,
        ),
      },
    );
  }
}

/// The MEME Tab while the build shows MEME v2 but the server's `launch2`
/// capability is closed or not read yet (S259 · decision 0217): the title
/// and one inline line, no desk, no read, no classic list.
class _MemeV2Closed extends ConsumerWidget {
  const _MemeV2Closed({this.embedded = false});

  /// The 发射台 segment beside IDO: the segment page draws the bar.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.launch2),
    );
    return LoopDashboardPage(
      key: ValueKey<String>(embedded ? 'meme-v2-closed' : 'meme-screen'),
      archetype: LoopPageArchetype.state,
      title: 'MEME',
      tabPage: true,
      embedded: embedded,
      sections: <Widget>[
        LoopInlineUnavailable(
          key: const ValueKey<String>('launch2-list-all-unavailable'),
          message: 'MEME v2 暂时不可用 · ${launch2CapabilityText(capability)}',
        ),
      ],
    );
  }
}
