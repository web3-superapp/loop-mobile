import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/l10n/loop_l10n.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_flat.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/features/social/profile_face_link.dart';
import 'package:loop_mobile/features/social/secondary_row_metrics.dart';

/// `connections` · following and followers.
///
/// Following is one-directional and needs no consent. Mining power on a row
/// has no source and is stated as unavailable rather than shown as a figure.
class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key, this.onBack, this.onOpenConversation});

  final VoidCallback? onBack;

  /// Opens the conversation with one row's account.
  ///
  /// The whole public profile travels, not just its id: the `dm` page's header
  /// and the `@` row under it name the peer from the same four fields this row
  /// just drew, and this screen is the only place in the product that holds
  /// them at the moment the conversation is opened (device report
  /// 2026-09-20 · R14-3).
  final ValueChanged<LoopPublicProfile>? onOpenConversation;

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(socialGatewayProvider).mode;
    final state = ref.watch(connectionsControllerProvider);
    final controller = ref.read(connectionsControllerProvider.notifier);
    if (!communityCapabilityBlocks(mode, capability) &&
        state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }

    final counts = state.counts;
    return LoopFlat(
      child: LoopStreamPage(
        key: const ValueKey<String>('connections-screen'),
        archetype: LoopPageArchetype.record,
        title: context.l10n.social_connectionsConnectionsScreenTitle,
        kicker: communityPreviewKicker(mode),
        onBack: widget.onBack,
        filters: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LoopSpacing.page,
            vertical: 10,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: LoopSeg(
                    key: const ValueKey<String>('connections-seg-following'),
                    quiet: true,
                    label: counts == null
                        ? context.l10n.socialPublicProfile_userCountFollowing
                        : context.l10n
                              .social_connectionsConnectionsSegFollowingLabel(
                                counts.following,
                              ),
                    selected: state.direction == ConnectionDirection.following,
                    onSelected: () => unawaited(
                      controller.selectDirection(ConnectionDirection.following),
                    ),
                  ),
                ),
                LoopSeg(
                  key: const ValueKey<String>('connections-seg-followers'),
                  quiet: true,
                  label: counts == null
                      ? context.l10n.common_followers
                      : context.l10n
                            .social_connectionsConnectionsSegFollowersLabel(
                              counts.followers,
                            ),
                  selected: state.direction == ConnectionDirection.followers,
                  onSelected: () => unawaited(
                    controller.selectDirection(ConnectionDirection.followers),
                  ),
                ),
              ],
            ),
          ),
        ),
        block: communityCapabilityBlocks(mode, capability)
            ? CommunityCapabilityPageBlock(
                key: const ValueKey<String>(
                  'connections-capability-unavailable',
                ),
                capability: capability,
                title: context
                    .l10n
                    .social_connectionsConnectionsCapabilityUnavailableTitle,
              )
            : null,
        onRefresh: controller.refresh,
        updating: state.refreshing,
        collection: ListView(
          key: const ValueKey<String>('connections-list'),
          // A short list must still overscroll, or the gesture would exist only
          // on the accounts that happen to follow enough people.
          physics: loopRefreshablePhysics(controller.refresh),
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            CommunityPreviewNotice(
              mode: mode,
              resource: context.l10n.social_connectionsResource,
            ),
            if (state.phase != CommunityViewPhase.ready)
              CommunityStateBlock(
                phase: state.phase,
                failureKind: state.failureKind,
                emptyMessage: state.direction == ConnectionDirection.following
                    ? context
                          .l10n
                          .social_connectionsCommunityStateEmptyEmptyMessage
                    : context
                          .l10n
                          .social_connectionsCommunityStateEmptyEmptyMessage2,
                emptyReason: context
                    .l10n
                    .social_connectionsCommunityStateEmptyEmptyReason,
                empty: LoopEmptyState(
                  showMessage: true,
                  key: const ValueKey<String>('community-state-empty'),
                  illustration: LoopIllustration.friends,
                  title: state.direction == ConnectionDirection.following
                      ? context
                            .l10n
                            .social_connectionsCommunityStateEmptyEmptyMessage
                      : context
                            .l10n
                            .social_connectionsCommunityStateEmptyEmptyMessage2,
                  message: context
                      .l10n
                      .social_connectionsCommunityStateEmptyEmptyReason,
                ),
                onRetry: () => unawaited(controller.reload()),
              )
            else ...<Widget>[
              if (state.failureKind != null)
                LoopNotice(
                  key: const ValueKey<String>('connections-action-failure'),
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
              for (final entry in state.items)
                _connectionRow(entry, state, controller),
              LoopLoadMoreFooter(
                key: const ValueKey<String>('connections-footer'),
                keyPrefix: 'connections',
                cursor: state.nextCursor,
                canLoadMore: state.canLoadMore && !state.refreshing,
                loading: state.loadingMore,
                onLoadMore: controller.loadMore,
              ),
              // One switch, one name: the privacy centre calls it 可被发现.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LoopSpacing.page,
                  20,
                  LoopSpacing.page,
                  0,
                ),
                child: Text(
                  context.l10n.social_connectionsConnectionsDiscoverableNotice,
                  key: const ValueKey<String>(
                    'connections-discoverable-notice',
                  ),
                  style: LoopType.captionSm,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// One OKX row (decision 0127): the face at 40 in a 56 row, the name over
  /// the LOOP ID, and 关注 / 已关注 as the capsule on the right.
  Widget _connectionRow(
    ConnectionEntry entry,
    ConnectionsState state,
    ConnectionsController controller,
  ) {
    final target = entry.profile.publicProfileId;
    final following = entry.viewerFollows;
    return LoopPersonRow(
      key: ValueKey<String>('connection-row-${target ?? entry.profile.loopId}'),
      // S370b · decision 0294: a person row reads as the conversation row
      // (docs/58 §3.2): 67 high, the face 48.
      height: SecondaryRowMetrics.personRow,
      // S371 · decision 0297: ruled, 6 above and below (docs/58 §9.4).
      divider: true,
      padding: SecondaryRowMetrics.rowPadding,
      // S239: the face opens the contact's page; the row keeps its sheet.
      leading: LoopProfileFaceLink(
        key: ValueKey<String>(
          'connection-face-${target ?? entry.profile.loopId}',
        ),
        publicProfileId: target,
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
        key: ValueKey<String>(
          'connection-follow-${target ?? entry.profile.loopId}',
        ),
        label: following
            ? LoopL10n.current.common_following
            : LoopL10n.current.common_follow,
        primary: !following,
        onPressed: state.busy || target == null
            ? null
            : () => unawaited(_toggleFollow(entry, target, controller)),
      ),
      onTap: state.busy || target == null
          ? null
          : () => unawaited(_openRow(entry, target, controller)),
      semanticLabel:
          '${entry.profile.displayName}${LoopL10n.current.common_listSeparator}${following ? LoopL10n.current.common_following : LoopL10n.current.social_publicProfileSheetPublicProfileFollowState}',
    );
  }

  /// The row offers exactly two commands: open the conversation and
  /// follow / unfollow.
  Future<void> _openRow(
    ConnectionEntry entry,
    String target,
    ConnectionsController controller,
  ) async {
    final following = entry.viewerFollows;
    final choice = await showLoopSheet<String>(
      context,
      barrierLabel:
          LoopL10n.current.social_connectionsConnectionActionsSheetBarrierLabel,
      builder: (sheetContext) => Padding(
        key: const ValueKey<String>('connection-actions-sheet'),
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
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LoopButton(
                key: const ValueKey<String>('connection-action-dm'),
                label:
                    LoopL10n.current.social_connectionsConnectionActionDmLabel,
                block: true,
                onPressed: () => Navigator.of(sheetContext).pop('dm'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LoopButton(
                key: const ValueKey<String>('connection-action-follow'),
                label: following
                    ? LoopL10n
                          .current
                          .social_connectionsConnectionActionFollowLabel
                    : LoopL10n.current.common_follow,
                block: true,
                onPressed: () => Navigator.of(sheetContext).pop('follow'),
              ),
            ),
            LoopButton(
              key: const ValueKey<String>('connection-action-cancel'),
              label: LoopL10n.current.common_cancel,
              block: true,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'dm') {
      widget.onOpenConversation?.call(entry.profile);
      return;
    }
    await _toggleFollow(entry, target, controller);
  }

  Future<void> _toggleFollow(
    ConnectionEntry entry,
    String target,
    ConnectionsController controller,
  ) async {
    final following = entry.viewerFollows;
    final confirmed = await confirmCommunityAction(
      context,
      title: following
          ? LoopL10n.current.social_connectionsTitle
          : LoopL10n.current.social_connectionsTitle2,
      body: following
          ? LoopL10n.current.social_connectionsBody
          : LoopL10n.current.social_connectionsBody2,
      confirmLabel: following
          ? LoopL10n.current.social_connectionsConnectionActionFollowLabel
          : LoopL10n.current.common_follow,
      sheetKey: 'connections-follow-sheet',
    );
    if (!confirmed) return;
    final failure = await controller.setFollowing(
      publicProfileId: target,
      following: !following,
    );
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(
        context,
        message: following
            ? LoopL10n.current.social_connectionsMessage
            : LoopL10n.current.common_following,
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
