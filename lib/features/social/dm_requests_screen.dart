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
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `dm-requests` · accept, ignore or report a stranger request.
///
/// The message body and the AI moderation verdict have no source in this
/// step: both render as unavailable and the prototype's sample copy and
/// "AI flagged as fraud" card are deliberately not shown.
class MessageRequestsScreen extends ConsumerStatefulWidget {
  const MessageRequestsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<MessageRequestsScreen> createState() =>
      _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends ConsumerState<MessageRequestsScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(socialGatewayProvider).mode;
    final state = ref.watch(messageRequestsControllerProvider);
    final controller = ref.read(messageRequestsControllerProvider.notifier);
    if (!communityCapabilityBlocks(mode, capability) &&
        state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }

    return LoopStreamPage(
      key: const ValueKey<String>('dm-requests-screen'),
      archetype: LoopPageArchetype.listing,
      title: '陌生人请求',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.listing,
        kicker: 'MESSAGE REQUESTS',
        // A read that came back with nothing counted nothing: zero requests
        // is a figure, and 暂无数值 claimed the page had no figure at all.
        heading: switch (state.phase) {
          CommunityViewPhase.ready => '${state.items.length} 个请求待决定',
          CommunityViewPhase.empty => '0 个待处理',
          _ => communityMissingHeading,
        },
        // The one sentence this page owes a reader before they decide, and
        // the sentences it used to owe them in a fourth card at the bottom:
        // one explanation per page is the ceiling (audit 2026-09-20 · D-5).
        caption: '接受后建立联系；忽略后 24 小时内不再提醒；举报等于拒绝并屏蔽。',
        // `.folio-stamp` is a pill that names what it counts — `1 NEW` — not a
        // bare digit in a circle (audit 2026-09-20 · B.4).
        stamp: switch (state.phase) {
          CommunityViewPhase.ready => '${state.items.length} NEW',
          CommunityViewPhase.empty => '0 NEW',
          _ => null,
        },
        // A Chalk hero has no `::after` ring in the prototype; only
        // `.folio-primary.folio-state` does.
        ring: false,
      ),
      block: communityCapabilityBlocks(mode, capability)
          ? CommunityCapabilityPageBlock(
              key: const ValueKey<String>('dm-requests-capability-unavailable'),
              capability: capability,
              title: '陌生人请求当前不可用',
            )
          : null,
      onRefresh: controller.refresh,
      updating: state.refreshing,
      collection: ListView(
        key: const ValueKey<String>('dm-requests-list'),
        // A short list must still overscroll, or the gesture would exist only
        // while the inbox is full.
        physics: loopRefreshablePhysics(controller.refresh),
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          CommunityPreviewNotice(mode: mode, resource: '陌生人请求'),
          if (state.phase != CommunityViewPhase.ready)
            CommunityStateBlock(
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: '没有待处理的请求',
              emptyReason: '被你屏蔽的账号不会出现在这里。',
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            if (state.failureKind != null)
              LoopNotice(
                key: const ValueKey<String>('dm-requests-action-failure'),
                icon: 'warn',
                tone: LoopNoticeTone.warn,
                title: '上一次决定没有完成',
                body: communityFailureReason(state.failureKind),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              ),
            for (final entry in state.items)
              _RequestCard(
                key: ValueKey<String>('dm-request-${entry.messageRequestId}'),
                entry: entry,
                busy: state.busy,
                onDecide: (decision) =>
                    unawaited(_decide(entry, decision, controller)),
              ),
            if (state.canLoadMore)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LoopButton(
                  key: const ValueKey<String>('dm-requests-load-more'),
                  label: '载入更多',
                  block: true,
                  onPressed: () => unawaited(controller.loadMore()),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _decide(
    MessageRequestEntry entry,
    MessageRequestDecision decision,
    MessageRequestsController controller,
  ) async {
    final label = switch (decision) {
      MessageRequestDecision.accept => '接受',
      MessageRequestDecision.ignore => '忽略',
      MessageRequestDecision.report => '举报并屏蔽',
    };
    final confirmed = await confirmCommunityAction(
      context,
      title: '$label这个请求？',
      body: switch (decision) {
        MessageRequestDecision.accept => '接受后会建立联系。如果任一方屏蔽了对方，则无法建立。',
        MessageRequestDecision.ignore => '忽略后对方在 24 小时内不能再次发起请求。',
        MessageRequestDecision.report => '举报会拒绝请求、屏蔽发起人并写入审计，同时断开双向关注。',
      },
      confirmLabel: label,
      sheetKey: 'dm-request-confirm-sheet',
    );
    if (!confirmed) return;
    final outcome = await controller.decide(
      messageRequestId: entry.messageRequestId,
      decision: decision,
    );
    if (!mounted) return;
    if (outcome == null) {
      LoopToast.show(
        context,
        message: communityFailureReason(
          ref.read(messageRequestsControllerProvider).failureKind,
        ),
        kind: LoopToastKind.err,
      );
      return;
    }
    // `blocked` comes from the response, never from the requested decision.
    LoopToast.show(
      context,
      message: outcome.blocked ? '已举报并屏蔽' : '已$label',
      kind: outcome.blocked ? LoopToastKind.warn : LoopToastKind.ok,
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.entry,
    required this.busy,
    required this.onDecide,
    super.key,
  });

  final MessageRequestEntry entry;
  final bool busy;
  final ValueChanged<MessageRequestDecision> onDecide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: ValueKey<String>('dm-request-row-${entry.messageRequestId}'),
              // `.row-ico`: the prototype's request row opens with the
              // sender's tile, so the name has a face beside it before the
              // three decisions under it.
              leading: LoopInitialsAvatar(
                label: entry.profile.displayName,
                size: 44,
                shape: BoxShape.rectangle,
                radius: 15,
              ),
              title: entry.profile.displayName,
              subtitle: entry.profile.loopId,
              trailing: '待处理',
            ),
          ],
        ),
        CommunityUnavailableCard(label: '消息正文', fact: entry.preview),
        const SizedBox(height: 10),
        CommunityUnavailableCard(label: 'AI 巡查标记', fact: entry.aiModeration),
        LoopButtonPair(
          children: <Widget>[
            LoopButton(
              key: ValueKey<String>(
                'dm-request-accept-${entry.messageRequestId}',
              ),
              label: '接受',
              primary: true,
              onPressed: busy
                  ? null
                  : () => onDecide(MessageRequestDecision.accept),
            ),
            LoopButton(
              key: ValueKey<String>(
                'dm-request-ignore-${entry.messageRequestId}',
              ),
              label: '忽略',
              onPressed: busy
                  ? null
                  : () => onDecide(MessageRequestDecision.ignore),
            ),
            LoopButton(
              key: ValueKey<String>(
                'dm-request-report-${entry.messageRequestId}',
              ),
              label: '举报',
              onPressed: busy
                  ? null
                  : () => onDecide(MessageRequestDecision.report),
            ),
          ],
        ),
      ],
    );
  }
}
