import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The four prototype segments. Only the two backed by
/// `GET /v2/communities?sort=` can be selected; the other two are disabled
/// with the reason, because "算力最高" and "讨论最多" have no source yet.
enum CommunityDiscoverSegment {
  members('成员最多', CommunityDirectorySort.members),
  power('算力最高', null),
  discussion('讨论最多', null),
  newest('新社区', CommunityDirectorySort.newest);

  const CommunityDiscoverSegment(this.label, this.sort);

  final String label;
  final CommunityDirectorySort? sort;

  bool get isAvailable => sort != null;

  /// The step that will give the segment a source.
  String get deferredReason => switch (this) {
    CommunityDiscoverSegment.power => '算力排序暂时不能用，挖矿开放后再试。',
    CommunityDiscoverSegment.discussion => '讨论量排序暂时不能用，聊天开放后再试。',
    _ => '',
  };
}

class CommunityDiscoverScreen extends ConsumerStatefulWidget {
  const CommunityDiscoverScreen({
    super.key,
    this.onBack,
    this.onOpenCommunity,
    this.joinedOnly = false,
  });

  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenCommunity;

  /// Entered from the home aggregate's "view all joined" action.
  final bool joinedOnly;

  @override
  ConsumerState<CommunityDiscoverScreen> createState() =>
      _CommunityDiscoverScreenState();
}

class _CommunityDiscoverScreenState
    extends ConsumerState<CommunityDiscoverScreen> {
  CommunityDiscoverSegment _segment = CommunityDiscoverSegment.members;

  /// Collects the application, confirms it, then submits it exactly once.
  /// The five refusal codes each get their own copy; only a 201 navigates.
  Future<void> _apply() async {
    final application = await showCommunityApplySheet(context);
    if (application == null || !mounted) return;
    final confirmed = await confirmCommunityAction(
      context,
      title: '提交社区申请？',
      body: '提交后社区状态为「审核中」，你是所有者。短链接一旦被接受就不能再改。',
      confirmLabel: '提交',
      sheetKey: 'community-apply-confirm-sheet',
    );
    if (!confirmed || !mounted) return;
    final outcome = await ref
        .read(communityApplicationControllerProvider.notifier)
        .submit(application);
    if (!mounted) return;
    final detail = outcome.detail;
    if (detail != null) {
      LoopToast.show(context, message: '社区申请已提交，状态为审核中');
      widget.onOpenCommunity?.call(detail.community.communityId);
      return;
    }
    LoopToast.show(
      context,
      message: communityApplyFailureReason(outcome.failureKind),
      kind: LoopToastKind.err,
    );
  }

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final state = ref.watch(communityDiscoverControllerProvider);
    final controller = ref.read(communityDiscoverControllerProvider.notifier);
    if (!communityCapabilityBlocks(mode, capability) &&
        state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (!mounted) return;
        unawaited(
          widget.joinedOnly ? controller.openJoined() : controller.load(),
        );
      });
    }

    final selectedSegment = _segment;
    return LoopStreamPage(
      key: const ValueKey<String>('community-discover-screen'),
      archetype: LoopPageArchetype.listing,
      title: widget.joinedOnly ? '已加入的社区' : '发现社区',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.listing,
        kicker: 'DISCOVERY DESK',
        heading: state.phase == CommunityViewPhase.ready
            ? '${state.items.length} 个社区'
            : communityMissingFigure,
        caption: '排序只用成员数和创建时间这两项可核对的信息。热门不等于推荐。',
        stamp: state.recommendation == null ? null : 'RULE',
      ),
      filters: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final segment in CommunityDiscoverSegment.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: LoopSeg(
                    key: ValueKey<String>('discover-seg-${segment.name}'),
                    label: segment.label,
                    selected: segment == selectedSegment,
                    onSelected: segment.isAvailable
                        ? () {
                            setState(() => _segment = segment);
                            unawaited(controller.selectSort(segment.sort!));
                          }
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
      block: communityCapabilityBlocks(mode, capability)
          ? CommunityCapabilityPageBlock(
              key: const ValueKey<String>(
                'community-discover-capability-unavailable',
              ),
              capability: capability,
              title: '社区模块当前不可用',
            )
          : null,
      onRefresh: controller.refresh,
      updating: state.refreshing,
      collection: ListView(
        key: const ValueKey<String>('community-discover-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          CommunityPreviewNotice(mode: mode, resource: '社区目录'),
          for (final segment in CommunityDiscoverSegment.values)
            if (!segment.isAvailable)
              LoopEmpty(
                key: ValueKey<String>('discover-seg-${segment.name}-reason'),
                icon: 'warn',
                message: '"${segment.label}" 暂不可用',
                reason: segment.deferredReason,
              ),
          if (state.phase != CommunityViewPhase.ready)
            CommunityStateBlock(
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: '没有符合条件的社区',
              emptyReason: '这个排序下没有社区。',
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (var index = 0; index < state.items.length; index += 1)
                  communityDirectoryRow(
                    community: state.items[index],
                    position: communityRowPosition(index, state.items.length),
                    onTap: () => widget.onOpenCommunity?.call(
                      state.items[index].communityId,
                    ),
                  ),
              ],
            ),
            if (state.nextCursor != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LoopButton(
                  key: const ValueKey<String>('community-discover-load-more'),
                  label: state.loadingMore ? '正在载入…' : '载入更多',
                  block: true,
                  onPressed: state.loadingMore
                      ? null
                      : () => unawaited(controller.loadMore()),
                ),
              ),
          ],
          const LoopNotice(
            key: ValueKey<String>('community-discover-apply-notice'),
            icon: 'community',
            title: '社区怎么入驻',
            body:
                '任何社区都可以提交申请。申请后状态为"审核中"，只有运维核验通过才会显示验证标记；'
                '本页不代表任何 Mining 权重结论。',
            margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
          ),
          // No application route exists in the frozen manifest, so the form
          // opens as a sheet from this block.
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('community-apply-action'),
                label: '申请入驻',
                onPressed: communityCapabilityBlocks(mode, capability)
                    ? null
                    : () => unawaited(_apply()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
