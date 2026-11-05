import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/social_controllers.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/features/social/secondary_row_metrics.dart';

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
  static Map<BlockKind, String> get _segmentLabels => <BlockKind, String>{
    BlockKind.user: LoopL10n.current.common_user,
    BlockKind.contract: LoopL10n.current.common_contract,
    BlockKind.domain: LoopL10n.current.social_blocklistDomain,
  };

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(socialGatewayProvider).mode;
    final state = ref.watch(blocklistControllerProvider);
    final controller = ref.read(blocklistControllerProvider.notifier);
    // The contract and domain segments have no backend, so there is nothing a
    // pull could re-read while one of them is selected.
    final refresh = state.kind.isSupported ? controller.refresh : null;
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
      title: context.l10n.common_blockList,
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: context.l10n.common_blockList,
        heading: state.userCount == null
            ? communityMissingHeading
            : context.l10n.social_blocklistHeading(state.userCount!),
        caption: context.l10n.social_blocklistCaption,
        stamp: context.l10n.social_blocklistStamp,
      ),
      filters: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LoopSpacing.page,
          vertical: 10,
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final kind in BlockKind.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  // The two deferred kinds have no backend at all, so their
                  // segments are disabled rather than selectable-and-empty.
                  child: LoopSeg(
                    key: ValueKey<String>('blocklist-seg-${kind.wireName}'),
                    label: kind == BlockKind.user && state.userCount != null
                        ? context.l10n.social_blocklistLabel(state.userCount)
                        : _segmentLabels[kind]!,
                    selected: state.kind == kind,
                    onSelected: kind.isSupported
                        ? () => controller.selectKind(kind)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
      block: communityCapabilityBlocks(mode, capability)
          ? CommunityCapabilityPageBlock(
              key: const ValueKey<String>('blocklist-capability-unavailable'),
              capability: capability,
              title: context
                  .l10n
                  .social_blocklistBlocklistCapabilityUnavailableTitle,
            )
          : null,
      onRefresh: refresh,
      updating: state.refreshing,
      collection: ListView(
        key: const ValueKey<String>('blocklist-list'),
        // A short list must still overscroll, or the gesture would exist only
        // on an account that has blocked enough people.
        physics: loopRefreshablePhysics(refresh),
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          CommunityPreviewNotice(
            mode: mode,
            resource: context.l10n.common_blockList,
          ),
          if (!state.kind.isSupported)
            LoopInlineUnavailable(
              key: ValueKey<String>(
                'blocklist-kind-unavailable-${state.kind.wireName}',
              ),
              message: context.l10n.social_blocklistMessage(
                _segmentLabels[state.kind],
              ),
              detail: context.l10n.social_blocklistDetail,
              maxLines: 2,
              detailMaxLines: 4,
            )
          else if (state.phase != CommunityViewPhase.ready)
            CommunityStateBlock(
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: context.l10n.social_blocklistEmptyMessage,
              emptyReason: context.l10n.social_blocklistEmptyReason,
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            if (state.failureKind != null)
              LoopNotice(
                key: const ValueKey<String>('blocklist-action-failure'),
                icon: 'warn',
                tone: LoopNoticeTone.warn,
                title: context.l10n.common_lastActionIncomplete,
                body: communityFailureReason(state.failureKind),
                margin: const EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  0,
                  LoopSpacing.page,
                  14,
                ),
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
            LoopLoadMoreFooter(
              key: const ValueKey<String>('blocklist-footer'),
              keyPrefix: 'blocklist',
              cursor: state.nextCursor,
              canLoadMore: state.canLoadMore && !state.refreshing,
              loading: state.loadingMore,
              onLoadMore: controller.loadMore,
            ),
          ],
          // The two deferred kinds are disabled segments, so their reason is
          // stated here instead of only after a selection that cannot happen.
          LoopInlineUnavailable(
            key: ValueKey<String>('blocklist-deferred-kinds'),
            message: context.l10n.social_blocklistBlocklistDeferredKindsMessage,
            detail: context.l10n.social_blocklistBlocklistDeferredKindsDetail,
            maxLines: 2,
            detailMaxLines: 4,
            padding: EdgeInsets.fromLTRB(
              LoopSpacing.page,
              16,
              LoopSpacing.page,
              0,
            ),
          ),
          LoopNotice(
            key: ValueKey<String>('blocklist-precedence-notice'),
            icon: 'shield',
            title: context.l10n.social_blocklistBlocklistPrecedenceNoticeTitle,
            body: context.l10n.social_blocklistBlocklistPrecedenceNoticeBody,
            margin: EdgeInsets.fromLTRB(
              LoopSpacing.page,
              16,
              LoopSpacing.page,
              0,
            ),
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
      // `.row-ico.mono` + `.badge`: the prototype's blocked row is a monogram
      // tile, a reason and a 解除 pill — not two lines of text with a mono
      // value where the pill belongs (audit 2026-09-21 §J.12, §D #7).
      // S371 · decision 0297: a person row borrows the conversation row's
      // 67 and its 48 face.
      kind: LoopRecordRowKind.person,
      leading: LoopRowIcon(
        monogram: loopMonogram(title),
        size: SecondaryRowMetrics.personFace,
      ),
      title: title,
      subtitle: blockReasonText(entry.reasonCode),
      trailingBadge: LoopBadge(LoopL10n.current.social_blocklistLoopBadge),
      position: communityRowPosition(index, length),
      chevron: false,
      onTap: state.busy ? null : () => unawaited(_unblock(entry, controller)),
      semanticLabel: LoopL10n.current.social_blocklistSemanticLabel(
        blockReasonText(entry.reasonCode),
        title,
      ),
    );
  }

  Future<void> _unblock(
    BlockEntry entry,
    BlocklistController controller,
  ) async {
    final title = entry.profile?.displayName ?? entry.stableId;
    final confirmed = await confirmCommunityAction(
      context,
      title: LoopL10n.current.social_blocklistTitle(title),
      body: LoopL10n.current.social_blocklistBody,
      confirmLabel: LoopL10n.current.social_blocklistConfirmLabel,
      sheetKey: 'blocklist-confirm-sheet',
    );
    if (!confirmed) return;
    final failure = await controller.unblock(entry);
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(
        context,
        message: LoopL10n.current.social_blocklistMessage2,
      );
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
  }
}
