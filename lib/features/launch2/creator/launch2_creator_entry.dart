import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/config/loop_feature_switches.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/launch2/creator/launch2_creator_routes.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

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
/// The MEME tab's chooser (v2 发射 / 经典发射) is S136's to draw; until it
/// lands, this one control is the whole entry and is drawn nowhere unless
/// [launch2CreatorEntryVisible]. With the switch off it draws nothing at all.
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
