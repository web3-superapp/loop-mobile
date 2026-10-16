import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
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
/// Two top-bar glyphs, both drawn only when [launch2CreatorEntryVisible]:
/// 「我的项目」 opens the owner's list, 「发起」 opens the decision 0138 §6
/// chooser — v2 发射 (this module's create page) or 经典发射 (the MEME curve
/// create page, passed in as [classicCreatePath] so this module does not
/// import the MEME feature).
///
/// Decision 0195: with [LoopFeatureSwitchValues.classicMemeLaunchVisible]
/// off there is nothing to choose between, so 「发起」 opens the v2 create
/// page at once instead of a one-row sheet.
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
        LoopIconButton(
          key: const ValueKey<String>('launch2-my-projects-action'),
          icon: 'user',
          label: '我的项目',
          onPressed: () => onNavigate(Launch2CreatorRoute.minePath),
        ),
        const SizedBox(width: 6),
        LoopIconButton(
          key: const ValueKey<String>('launch2-create-action'),
          icon: 'plus',
          label: '发起',
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
