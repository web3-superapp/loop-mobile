import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/social_controllers.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `blocklist` · the three prototype segments.
///
/// Only `user` has a backend in this step; the contract and domain segments
/// can be selected but state their own unavailability and list nothing.
class BlocklistScreen extends ConsumerStatefulWidget {
  const BlocklistScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<BlocklistScreen> createState() => _BlocklistScreenState();
}

class _BlocklistScreenState extends ConsumerState<BlocklistScreen> {
  static const Map<BlockKind, String> _segmentLabels = <BlockKind, String>{
    BlockKind.user: '用户',
    BlockKind.contract: '合约',
    BlockKind.domain: '域名',
  };

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(socialGatewayProvider).mode;
    final state = ref.watch(blocklistControllerProvider);
    final controller = ref.read(blocklistControllerProvider.notifier);
    if (!communityCapabilityBlocks(mode, capability) &&
        state.kind.isSupported &&
        state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }

    return LoopStreamPage(
      key: const ValueKey<String>('blocklist-screen'),
      archetype: LoopPageArchetype.record,
      title: '屏蔽名单',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'BLOCKED ENTITIES',
        heading: state.userCount == null
            ? communityMissingFigure
            : '${state.userCount} 个已屏蔽账号',
        caption: '屏蔽优先于关注与私聊。解除屏蔽不会恢复关注关系。',
        stamp: 'PRIVATE',
      ),
      filters: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final kind in BlockKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: LoopSeg(
                    key: ValueKey<String>('blocklist-seg-${kind.wireName}'),
                    label: kind == BlockKind.user && state.userCount != null
                        ? '用户 ${state.userCount}'
                        : _segmentLabels[kind]!,
                    selected: state.kind == kind,
                    onSelected: () => controller.selectKind(kind),
                  ),
                ),
            ],
          ),
        ),
      ),
      collection: ListView(
        key: const ValueKey<String>('blocklist-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          CommunityPreviewNotice(mode: mode, resource: '屏蔽名单'),
          if (communityCapabilityBlocks(mode, capability))
            LoopEmpty(
              key: const ValueKey<String>('blocklist-capability-unavailable'),
              icon: 'warn',
              message: '屏蔽名单当前不可用',
              reason: capability.reasonCode == null
                  ? '尚未读取到能力清单，本页不请求屏蔽名单。'
                  : '服务端原因：${capability.reasonCode}。',
            )
          else if (!state.kind.isSupported)
            LoopEmpty(
              key: ValueKey<String>(
                'blocklist-kind-unavailable-${state.kind.wireName}',
              ),
              icon: 'warn',
              message: '"${_segmentLabels[state.kind]}" 屏蔽暂不可用',
              reason: '合约与域名屏蔽还没有服务端来源，本页不列出任何条目，也不发起请求。',
            )
          else if (state.phase != CommunityViewPhase.ready)
            CommunityStateBlock(
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: '没有屏蔽任何账号',
              emptyReason: '在陌生人请求里选择"举报"会自动屏蔽发起人。',
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            if (state.failureKind != null)
              LoopNotice(
                key: const ValueKey<String>('blocklist-action-failure'),
                icon: 'warn',
                tone: LoopNoticeTone.warn,
                title: '上一次操作没有完成',
                body: communityFailureReason(state.failureKind),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              ),
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (var index = 0; index < state.items.length; index += 1)
                  _blockRow(
                    state.items[index],
                    index,
                    state.items.length,
                    state,
                    controller,
                  ),
              ],
            ),
            if (state.canLoadMore)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LoopButton(
                  key: const ValueKey<String>('blocklist-load-more'),
                  label: '载入更多',
                  block: true,
                  onPressed: () => unawaited(controller.loadMore()),
                ),
              ),
          ],
          const LoopNotice(
            key: ValueKey<String>('blocklist-precedence-notice'),
            icon: 'shield',
            title: '屏蔽的效果',
            body:
                '屏蔽会立即断开双向关注，并让对方从搜索、关注列表和陌生人请求中消失。'
                '解除屏蔽不会自动恢复关注，需要重新关注。',
            margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
          ),
        ],
      ),
    );
  }

  LoopRecordRow _blockRow(
    BlockEntry entry,
    int index,
    int length,
    BlocklistState state,
    BlocklistController controller,
  ) {
    final title = entry.profile?.displayName ?? entry.stableId;
    return LoopRecordRow(
      key: ValueKey<String>('block-row-${entry.stableId}'),
      title: title,
      subtitle: blockReasonText(entry.reasonCode),
      trailing: '解除',
      position: communityRowPosition(index, length),
      onTap: state.busy ? null : () => unawaited(_unblock(entry, controller)),
      semanticLabel: '$title，${blockReasonText(entry.reasonCode)}，可解除屏蔽',
    );
  }

  Future<void> _unblock(
    BlockEntry entry,
    BlocklistController controller,
  ) async {
    final title = entry.profile?.displayName ?? entry.stableId;
    final confirmed = await confirmCommunityAction(
      context,
      title: '解除对 $title 的屏蔽？',
      body: '解除后对方可以重新出现在搜索与陌生人请求里。已经断开的关注关系不会自动恢复。',
      confirmLabel: '解除屏蔽',
      sheetKey: 'blocklist-confirm-sheet',
    );
    if (!confirmed) return;
    final failure = await controller.unblock(entry);
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: '已解除屏蔽');
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
  }
}
