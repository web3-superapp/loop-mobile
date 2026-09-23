import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
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

/// The four prototype segments, each backed by a `GET /v2/communities?sort=`
/// value (decision 0061).
///
/// 「算力最高」 ranks by the settled community power every mining read
/// resolves to, 「讨论最多」 by the messages the official channel was seen
/// carrying over the last week. Whether either can be applied is the server's
/// answer on that page, not a client-side switch: a segment whose order comes
/// back unavailable states the reason and offers the member order instead.
/// There is no 「增长最快」 segment, because nothing measures growth.
enum CommunityDiscoverSegment {
  members('成员最多', CommunityDirectorySort.members),
  power('算力最高', CommunityDirectorySort.miningPower),
  discussion('讨论最多', CommunityDirectorySort.activity),
  newest('新社区', CommunityDirectorySort.newest);

  const CommunityDiscoverSegment(this.label, this.sort);

  final String label;
  final CommunityDirectorySort sort;

  static CommunityDiscoverSegment of(CommunityDirectorySort sort) {
    for (final segment in values) {
      if (segment.sort == sort) return segment;
    }
    return CommunityDiscoverSegment.members;
  }
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
      // The answer arrives on 我的 → 我的社区 → 我创建的, and the applicant is
      // told so here rather than left to find it.
      await showCommunityApplicationSubmittedSheet(
        context,
        communityName: detail.community.name,
      );
      if (!mounted) return;
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

    final orderingReason = state.orderingReasonCode;
    // The chip that reads as chosen is the order the controller is on, so a
    // segment can never look selected while the list beside it was ranked by
    // something else.
    final selectedSegment = CommunityDiscoverSegment.of(state.sort);
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
        // The directory answers one cursor page at a time and carries no
        // total, so a heading may only count what is loaded — and it says
        // that it is what it is counting until the last page is in.
        heading:
            state.phase != CommunityViewPhase.ready || orderingReason != null
            ? communityMissingHeading
            : state.nextCursor == null
            ? '${state.items.length} 个社区'
            : '已载入 ${state.items.length} 个社区',
        caption: '排序只用成员数、创建时间、算力与 7 天讨论量这些可核对的数字。热门不等于推荐。',
        stamp: state.recommendation == null ? null : 'RULE',
      ),
      // `.refined-page .folio-body>.segs{padding:0 16px 16px;gap:7px}` — the
      // chips carry the prototype's own separation from the first row. LOOP
      // had 10 under them and 8 between them (decision 0086).
      filters: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final segment in CommunityDiscoverSegment.values)
                Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: LoopSeg(
                    key: ValueKey<String>('discover-seg-${segment.name}'),
                    label: segment.label,
                    selected: segment == selectedSegment,
                    onSelected: () =>
                        unawaited(controller.selectSort(segment.sort)),
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
          if (orderingReason != null)
            // The page answered and the order did not: an empty list here
            // would say 「没有社区」, which is not what was measured.
            LoopEmpty(
              key: const ValueKey<String>(
                'community-discover-ordering-unavailable',
              ),
              icon: 'warn',
              message: '「${selectedSegment.label}」暂时不可用',
              reason: communityUnavailableReason(orderingReason),
              action: LoopButton(
                key: const ValueKey<String>('community-discover-ordering-back'),
                label: '按成员最多排序',
                onPressed: () => unawaited(
                  controller.selectSort(CommunityDirectorySort.members),
                ),
              ),
            )
          else if (state.phase != CommunityViewPhase.ready)
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
                    sort: state.sort,
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
              )
            // The last page's control simply disappeared, and a list that
            // ends in silence reads as one that stopped loading.
            else if (state.items.isNotEmpty)
              const LoopProvenanceFooter(
                key: ValueKey<String>('community-discover-end'),
                text: '没有更多社区',
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
