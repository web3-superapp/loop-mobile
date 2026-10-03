import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_recommendations_controller.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';

class CommunityRecommendationsScreen extends ConsumerStatefulWidget {
  const CommunityRecommendationsScreen({
    super.key,
    this.onDone,
    this.onBack,
    this.onBindInvitation,
  });

  final VoidCallback? onDone;
  final VoidCallback? onBack;

  /// Opens the existing Referral surface. Binding remains its controller's
  /// server-confirmed command; this page never stores an invitation code.
  final VoidCallback? onBindInvitation;

  @override
  ConsumerState<CommunityRecommendationsScreen> createState() =>
      _CommunityRecommendationsScreenState();
}

class _CommunityRecommendationsScreenState
    extends ConsumerState<CommunityRecommendationsScreen> {
  Future<void> _join() async {
    final done = await ref
        .read(communityRecommendationsControllerProvider.notifier)
        .joinSelected();
    if (done && mounted) widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(communityRecommendationsControllerProvider);
    final controller = ref.read(
      communityRecommendationsControllerProvider.notifier,
    );
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final blocked = communityCapabilityBlocks(state.mode, capability);
    if (!blocked && state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final pendingCount = state.pendingIds.length;
    return LoopFocusPage(
      key: const ValueKey<String>('community-recommendations-screen'),
      archetype: LoopPageArchetype.listing,
      title: '选择社区',
      onBack: state.busy ? null : widget.onBack,
      actions: <Widget>[
        if (blocked)
          LoopIconButton(
            key: const ValueKey<String>('recommendations-skip'),
            icon: 'close',
            label: '跳过',
            onPressed: state.busy ? null : widget.onDone,
          ),
      ],
      block: blocked
          ? CommunityCapabilityPageBlock(
              capability: capability,
              title: '社区模块当前不可用',
            )
          : null,
      body: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('加入感兴趣的社区', style: LoopTypography.heading(22)),
              const SizedBox(height: 8),
              Text(
                state.phase == CommunityViewPhase.ready &&
                        state.items.isNotEmpty
                    ? '默认选择最多 5 个，点击可取消。'
                    : '选择感兴趣的社区，也可以稍后再加入。',
                style: LoopTypography.body(14, color: LoopColors.text2),
              ),
            ],
          ),
        ),
        if (state.phase != CommunityViewPhase.ready)
          CommunityStateBlock(
            phase: state.phase,
            failureKind: state.failureKind,
            emptyMessage: '暂无推荐社区',
            emptyReason: '稍后可以从社区页重新选择。',
            onRetry: () => unawaited(controller.load()),
          )
        else if (state.items.isEmpty)
          const LoopEmpty(message: '暂无推荐社区', reason: '稍后可以从社区页重新选择。')
        else
          Column(
            children: [
              for (var index = 0; index < state.items.length; index += 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _row(state, index, controller),
                ),
            ],
          ),
        if (state.failures.isNotEmpty)
          LoopNotice(
            key: const ValueKey<String>('recommendations-partial-failure'),
            icon: 'warn',
            title: '部分社区尚未加入',
            body: '已确认加入 ${state.joined.length} 个。保留的选择可以重试，也可以稍后处理。',
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          ),
        if (widget.onBindInvitation != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LoopButton(
              key: const ValueKey<String>('recommendations-invitation'),
              label: '填写邀请码',
              onPressed: state.busy ? null : widget.onBindInvitation,
            ),
          ),
      ],
      primaryAction: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          LoopButton(
            key: const ValueKey<String>('recommendations-join'),
            label: state.busy
                ? '正在加入…'
                : pendingCount == 0
                ? '继续'
                : state.failures.isEmpty
                ? '加入 $pendingCount 个社区'
                : '重试 $pendingCount 个社区',
            primary: true,
            onPressed:
                blocked || state.busy || state.phase != CommunityViewPhase.ready
                ? null
                : () => unawaited(_join()),
          ),
          const SizedBox(height: 8),
          LoopButton(
            key: const ValueKey<String>('recommendations-skip'),
            label: '稍后再说',
            onPressed: state.busy ? null : widget.onDone,
          ),
        ],
      ),
    );
  }

  LoopRecordRow _row(
    CommunityRecommendationsState state,
    int index,
    CommunityRecommendationsController controller,
  ) {
    final community = state.items[index];
    final id = community.communityId;
    final joined = state.joined.contains(id);
    final selected = state.selected.contains(id);
    final failure = state.failures[id];
    return LoopRecordRow(
      key: ValueKey<String>('recommendations-row-$id'),
      title: community.name,
      leading: CommunityLogo(
        identity: id,
        name: community.name,
        logoRef: community.logoRef,
      ),
      subtitle: failure == null
          ? '${community.memberCount} 名成员 · ${communityVerificationLabel(community.verificationStatus)}'
          : communityOutcomeIsUnresolved(failure)
          ? '加入结果尚未确认，可以重试核对状态。'
          : communityFailureReason(failure),
      subtitleMaxLines: failure == null ? 1 : 2,
      trailingBadge: joined
          ? Text(
              '已加入',
              style: LoopTypography.caption(13, color: LoopColors.text2),
            )
          : Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? LoopColors.lime : LoopColors.text3,
              size: 24,
            ),
      selected: selected && !joined,
      chevron: false,
      position: LoopRowPosition.single,
      semanticLabel:
          '${community.name}，${joined
              ? '已加入'
              : selected
              ? '已选择，点击取消'
              : '未选择，点击选择'}',
      onTap: state.busy || joined ? null : () => controller.toggle(id),
    );
  }
}
