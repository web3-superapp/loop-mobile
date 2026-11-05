import 'dart:async';

import 'package:flutter/material.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/social_controllers.dart';
import 'package:loop_mobile/features/social/social_gateway.dart';
import 'package:loop_mobile/features/social/social_models.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/features/social/profile_face_link.dart';
import 'package:loop_mobile/features/social/secondary_row_metrics.dart';

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

    return LoopFlat(
      child: LoopStreamPage(
        key: const ValueKey<String>('dm-requests-screen'),
        archetype: LoopPageArchetype.listing,
        title: context.l10n.common_messageRequests,
        kicker: communityPreviewKicker(mode),
        onBack: widget.onBack,
        // Decision 0127: the count in the bar's grey line; the hero card and
        // its English eyebrow are gone.
        subtitle: switch (state.phase) {
          CommunityViewPhase.ready => context.l10n.social_dmRequestsReady(
            state.items.length,
          ),
          CommunityViewPhase.empty => context.l10n.social_dmRequestsEmpty,
          _ => null,
        },
        block: communityCapabilityBlocks(mode, capability)
            ? CommunityCapabilityPageBlock(
                key: const ValueKey<String>(
                  'dm-requests-capability-unavailable',
                ),
                capability: capability,
                title: context
                    .l10n
                    .social_dmRequestsDmRequestsCapabilityUnavailableTitle,
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
            CommunityPreviewNotice(
              mode: mode,
              resource: context.l10n.common_messageRequests,
            ),
            if (state.phase != CommunityViewPhase.ready)
              CommunityStateBlock(
                phase: state.phase,
                failureKind: state.failureKind,
                emptyMessage: context
                    .l10n
                    .social_dmRequestsCommunityStateEmptyEmptyMessage,
                emptyReason: context
                    .l10n
                    .social_connectionsCommunityStateEmptyEmptyReason,
                empty: LoopEmptyState(
                  key: ValueKey<String>('community-state-empty'),
                  illustration: LoopIllustration.friends,
                  title: context
                      .l10n
                      .social_dmRequestsCommunityStateEmptyEmptyMessage,
                  message: context
                      .l10n
                      .social_connectionsCommunityStateEmptyEmptyReason,
                ),
                onRetry: () => unawaited(controller.reload()),
              )
            else ...<Widget>[
              if (state.failureKind != null)
                LoopNotice(
                  key: const ValueKey<String>('dm-requests-action-failure'),
                  icon: 'warn',
                  tone: LoopNoticeTone.warn,
                  title: context
                      .l10n
                      .social_dmRequestsDmRequestsActionFailureTitle,
                  body: communityFailureReason(state.failureKind),
                  margin: const EdgeInsets.fromLTRB(
                    LoopSpacing.page,
                    0,
                    LoopSpacing.page,
                    14,
                  ),
                ),
              for (final entry in state.items)
                _RequestRow(
                  key: ValueKey<String>('dm-request-${entry.messageRequestId}'),
                  entry: entry,
                  busy: state.busy,
                  onDecide: (decision) =>
                      unawaited(_decide(entry, decision, controller)),
                ),
              LoopLoadMoreFooter(
                key: const ValueKey<String>('dm-requests-footer'),
                keyPrefix: 'dm-requests',
                cursor: state.nextCursor,
                canLoadMore: state.canLoadMore && !state.refreshing,
                loading: state.loadingMore,
                onLoadMore: controller.loadMore,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _decide(
    MessageRequestEntry entry,
    MessageRequestDecision decision,
    MessageRequestsController controller,
  ) async {
    final label = switch (decision) {
      MessageRequestDecision.accept => LoopL10n.current.social_dmRequestsAccept,
      MessageRequestDecision.ignore => LoopL10n.current.social_dmRequestsIgnore,
      MessageRequestDecision.report => LoopL10n.current.social_dmRequestsReport,
    };
    final confirmed = await confirmCommunityAction(
      context,
      title: switch (decision) {
        MessageRequestDecision.accept =>
          LoopL10n.current.social_dmRequestsAcceptTitle,
        MessageRequestDecision.ignore =>
          LoopL10n.current.social_dmRequestsIgnoreTitle,
        MessageRequestDecision.report =>
          LoopL10n.current.social_dmRequestsReportTitle,
      },
      body: switch (decision) {
        MessageRequestDecision.accept =>
          LoopL10n.current.social_dmRequestsAccept2,
        MessageRequestDecision.ignore =>
          LoopL10n.current.social_dmRequestsIgnore2,
        MessageRequestDecision.report =>
          LoopL10n.current.social_dmRequestsReport2,
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
      message: outcome.blocked
          ? LoopL10n.current.social_dmRequestsMessage
          : switch (decision) {
              MessageRequestDecision.accept =>
                LoopL10n.current.social_dmRequestsAccepted,
              MessageRequestDecision.ignore =>
                LoopL10n.current.social_dmRequestsIgnored,
              MessageRequestDecision.report =>
                LoopL10n.current.social_dmRequestsMessage,
            },
      kind: outcome.blocked ? LoopToastKind.warn : LoopToastKind.ok,
    );
  }
}

/// One request (decision 0127): the sender's face at 40, the name over the
/// LOOP ID, and 「接受」 as the Lime capsule on the right. 忽略 and 举报 are in
/// the sheet the row opens.
class _RequestRow extends StatelessWidget {
  const _RequestRow({
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
    final id = entry.messageRequestId;
    return LoopPersonRow(
      key: ValueKey<String>('dm-request-row-$id'),
      // S370b · decision 0294: the conversation row, 67 / 48.
      height: SecondaryRowMetrics.personRow,
      // S371 · decision 0297: ruled, 6 above and below (docs/58 §9.4).
      divider: true,
      padding: SecondaryRowMetrics.rowPadding,
      // S239: the face opens the requester's page; the row keeps its sheet.
      leading: LoopProfileFaceLink(
        key: ValueKey<String>('dm-request-face-$id'),
        publicProfileId: entry.profile.publicProfileId,
        name: entry.profile.displayName,
        child: LoopProfileAvatar(
          avatarRef: entry.profile.avatarRef,
          alias: entry.profile.displayName,
          size: SecondaryRowMetrics.personFace,
        ),
      ),
      title: entry.profile.displayName,
      subtitle: entry.profile.loopId,
      trailing: LoopPillAction(
        key: ValueKey<String>('dm-request-accept-$id'),
        label: context.l10n.social_dmRequestsAccept,
        onPressed: busy ? null : () => onDecide(MessageRequestDecision.accept),
      ),
      onTap: busy ? null : () => unawaited(_openMore(context)),
    );
  }

  Future<void> _openMore(BuildContext context) async {
    final choice = await showLoopSheet<MessageRequestDecision>(
      context,
      barrierLabel: context.l10n.social_dmRequestsBarrierLabel,
      builder: (sheetContext) => Padding(
        key: ValueKey<String>(
          'dm-request-actions-sheet-${entry.messageRequestId}',
        ),
        padding: const EdgeInsets.fromLTRB(
          LoopSpacing.page,
          4,
          LoopSpacing.page,
          8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopLabel(entry.profile.displayName),
            LoopButton(
              key: ValueKey<String>(
                'dm-request-ignore-${entry.messageRequestId}',
              ),
              label: context.l10n.social_dmRequestsIgnore,
              block: true,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(MessageRequestDecision.ignore),
            ),
            const SizedBox(height: 8),
            LoopButton(
              key: ValueKey<String>(
                'dm-request-report-${entry.messageRequestId}',
              ),
              label: context.l10n.social_dmRequestsReport,
              block: true,
              onPressed: () =>
                  Navigator.of(sheetContext).pop(MessageRequestDecision.report),
            ),
            const SizedBox(height: 8),
            LoopButton(
              label: context.l10n.common_cancel,
              block: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
    if (choice != null) onDecide(choice);
  }
}
