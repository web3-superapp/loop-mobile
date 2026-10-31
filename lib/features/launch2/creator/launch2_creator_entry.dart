import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pressable.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';

/// Whether the MEME v2 project-side entry may be drawn: the build switch is
/// on and the server publishes `launch2` as available (decision 0137).
bool launch2CreatorEntryVisible(WidgetRef ref) {
  if (!ref.watch(loopFeatureSwitchesProvider).launch2Visible) return false;
  final capability = ref.watch(
    loopCapabilityProvider(LoopV2CapabilityId.launch2),
  );
  return capability.decision == LoopCapabilityDecision.available;
}

/// The v2 choice of the MEME tab's 「发起」 (S135, decision 0138).
///
/// The MEME tab draws [Launch2CreatorActions] (decision 0146); this single
/// control stays for pages that want a full-width button. It is drawn nowhere
/// unless [launch2CreatorEntryVisible]; with the switch off it draws nothing.
class Launch2CreatorEntry extends ConsumerWidget {
  const Launch2CreatorEntry({required this.onNavigate, super.key});

  final void Function(String location) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!launch2CreatorEntryVisible(ref)) return const SizedBox.shrink();
    return LoopButton(
      key: const ValueKey<String>('launch2-creator-entry'),
      label: 'v2 发射（NFT 预售 + 官方外盘）',
      icon: 'launch',
      onPressed: () => onNavigate(Launch2CreatorRoute.createPath),
    );
  }
}

/// The owner's way back to 我的项目 from anywhere the entry is drawn.
class Launch2MyProjectsEntry extends ConsumerWidget {
  const Launch2MyProjectsEntry({required this.onNavigate, super.key});

  final void Function(String location) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!launch2CreatorEntryVisible(ref)) return const SizedBox.shrink();
    return LoopButton(
      key: const ValueKey<String>('launch2-my-projects-entry'),
      label: '我的项目',
      onPressed: () => onNavigate(Launch2CreatorRoute.minePath),
    );
  }
}

/// S148 · decision 0146: the MEME tab's project-side entry on the v2 face.
///
/// One top-bar control, drawn only when [launch2CreatorEntryVisible]:
/// 「发射」 opens the decision 0138 §6 chooser — v2 发射 (this module's create page) or 经典发射 (the MEME curve
/// create page, passed in as [classicCreatePath] so this module does not
/// import the MEME feature).
///
/// Decision 0195: with [LoopFeatureSwitchValues.classicMemeLaunchVisible]
/// off there is nothing to choose between, so 「发射」 opens the v2 create
/// page at once instead of a one-row sheet.
///
/// S279 · decision 0237 (需求方 2026-10-22 第 15 条): 「我的项目」 is a 24
/// glyph in a heavier pen, and 「发射」 is no longer a small plus but the
/// Yellow capsule with its words, the page's one call to action.
///
/// S294 · decision 0244 (需求方 2026-10-23 第 06 条): 「我的项目」 left the
/// MEME home's top bar; it is the create page's top-bar trailing icon
/// ([Launch2MyProjectsAction]).
class Launch2CreatorActions extends ConsumerWidget {
  const Launch2CreatorActions({
    required this.onNavigate,
    required this.classicCreatePath,
    super.key,
  });

  final void Function(String location) onNavigate;
  final String classicCreatePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!launch2CreatorEntryVisible(ref)) return const SizedBox.shrink();
    final classic = ref.watch(
      loopFeatureSwitchesProvider.select((s) => s.classicMemeLaunchVisible),
    );
    return Row(
      key: const ValueKey<String>('launch2-creator-actions'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Launch2LaunchCapsule(
          key: const ValueKey<String>('launch2-create-action'),
          onPressed: classic
              ? () => unawaited(_choose(context))
              : () => onNavigate(Launch2CreatorRoute.createPath),
        ),
      ],
    );
  }

  Future<void> _choose(BuildContext context) async {
    final location = await showLoopSheet<String>(
      context,
      builder: (sheetContext) => LoopRecordGroup(
        key: const ValueKey<String>('launch2-create-chooser'),
        rows: <LoopRecordRow>[
          LoopRecordRow(
            key: const ValueKey<String>('launch2-create-chooser-v2'),
            leading: const LoopRowIcon(icon: 'launch'),
            title: 'v2 发射',
            subtitle: 'NFT 预售 + 提前购 + 公开内盘，毕业进官方外盘',
            subtitleMaxLines: 2,
            position: LoopRowPosition.first,
            onTap: () =>
                Navigator.of(sheetContext).pop(Launch2CreatorRoute.createPath),
          ),
          LoopRecordRow(
            key: const ValueKey<String>('launch2-create-chooser-classic'),
            leading: const LoopRowIcon(icon: 'chart'),
            title: '经典发射',
            subtitle: '联合曲线发币，打满自动上 PancakeSwap',
            subtitleMaxLines: 2,
            position: LoopRowPosition.last,
            onTap: () => Navigator.of(sheetContext).pop(classicCreatePath),
          ),
        ],
      ),
    );
    if (location == null || !context.mounted) return;
    onNavigate(location);
  }
}

/// 「我的项目」 on the create page's top bar (S294 · decision 0244): the
/// heavier `user` glyph in a 44 target, drawn only when
/// [launch2CreatorEntryVisible], like the MEME home's 「发射」.
class Launch2MyProjectsAction extends ConsumerWidget {
  const Launch2MyProjectsAction({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!launch2CreatorEntryVisible(ref)) return const SizedBox.shrink();
    return Launch2BoldIconButton(
      key: const ValueKey<String>('launch2-my-projects-action'),
      icon: 'user',
      label: '我的项目',
      onPressed: onPressed,
    );
  }
}

/// A sprite glyph in a heavier pen: the 1.7 sprite stroke drawn five times,
/// a fraction of a pixel apart, so it reads about half again as thick
/// without a second icon set (S279 · decision 0237).
class Launch2BoldIcon extends StatelessWidget {
  const Launch2BoldIcon(this.name, {super.key, this.size = 24, this.color});

  final String name;
  final double size;
  final Color? color;

  /// How far each extra pass sits from the glyph, in logical pixels.
  static const double spread = 0.45;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        for (final offset in const <Offset>[
          Offset(spread, 0),
          Offset(-spread, 0),
          Offset(0, spread),
          Offset(0, -spread),
          Offset.zero,
        ])
          Transform.translate(
            offset: offset,
            child: LoopIcon(name, size: size, color: color),
          ),
      ],
    ),
  );
}

/// A 44 top-bar control with a [Launch2BoldIcon], named like
/// `LoopIconButton`: the label is its accessible name and its tooltip.
class Launch2BoldIconButton extends StatelessWidget {
  const Launch2BoldIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: LoopRadius.tool,
          child: SizedBox.square(
            dimension: LoopTouch.minimum,
            child: Center(
              child: Launch2BoldIcon(icon, color: LoopColors.chalk),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 「发射」: the MEME home's create entry, a Yellow button with the rocket
/// and the word in Ink, 36 high inside a 44 target — square with the button
/// radius and no glow, like every other button (S325 · decision 0255).
class Launch2LaunchCapsule extends StatelessWidget {
  const Launch2LaunchCapsule({required this.onPressed, super.key});

  final VoidCallback onPressed;

  static const String label = '发射';

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: LoopPressable(
      onTap: onPressed,
      child: SizedBox(
        height: LoopTouch.minimum,
        child: Center(
          widthFactor: 1,
          child: Container(
            key: const ValueKey<String>('launch2-create-capsule'),
            height: 36,
            padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
            decoration: const BoxDecoration(
              color: LoopColors.yellow,
              borderRadius: LoopRadius.button,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Launch2BoldIcon(
                  'launch',
                  size: 18,
                  color: LoopColors.ink,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  style: LoopType.button.copyWith(color: LoopColors.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
