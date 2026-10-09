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
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

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
    return LoopStreamPage(
      key: const ValueKey<String>('connections-screen'),
      archetype: LoopPageArchetype.record,
      title: '关注与粉丝',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      filters: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: LoopSeg(
                  key: const ValueKey<String>('connections-seg-following'),
                  quiet: true,
                  label: counts == null ? '关注' : '关注 ${counts.following}',
                  selected: state.direction == ConnectionDirection.following,
                  onSelected: () => unawaited(
                    controller.selectDirection(ConnectionDirection.following),
                  ),
                ),
              ),
              LoopSeg(
                key: const ValueKey<String>('connections-seg-followers'),
                quiet: true,
                label: counts == null ? '粉丝' : '粉丝 ${counts.followers}',
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
              key: const ValueKey<String>('connections-capability-unavailable'),
              capability: capability,
              title: '关注关系当前不可用',
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
          CommunityPreviewNotice(mode: mode, resource: '关注关系'),
          if (state.phase != CommunityViewPhase.ready)
            CommunityStateBlock(
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: state.direction == ConnectionDirection.following
                  ? '还没有关注任何人'
                  : '还没有粉丝',
              emptyReason: '被你屏蔽的账号不会出现在这里。',
              empty: LoopEmptyState(
                key: const ValueKey<String>('community-state-empty'),
                illustration: LoopIllustration.friends,
                title: state.direction == ConnectionDirection.following
                    ? '还没有关注任何人'
                    : '还没有粉丝',
                message: '被你屏蔽的账号不会出现在这里。',
              ),
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            if (state.failureKind != null)
              LoopNotice(
                key: const ValueKey<String>('connections-action-failure'),
                icon: 'warn',
                tone: LoopNoticeTone.warn,
                title: '上一次操作没有完成',
                body: communityFailureReason(state.failureKind),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(
                '在「隐私中心 · 可被发现」打开后，别人才能按昵称搜到你；LOOP ID 始终可被精确搜索。',
                key: const ValueKey<String>('connections-discoverable-notice'),
                style: LoopTypography.caption(11, color: LoopColors.text3),
              ),
            ),
          ],
        ],
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
      height: 56,
      leading: LoopProfileAvatar(
        avatarRef: entry.profile.avatarRef,
        alias: entry.profile.displayName,
        size: 40,
      ),
      title: entry.profile.displayName,
      subtitle: entry.profile.loopId,
      trailing: LoopPillAction(
        key: ValueKey<String>(
          'connection-follow-${target ?? entry.profile.loopId}',
        ),
        label: following ? '已关注' : '关注',
        primary: !following,
        onPressed: state.busy || target == null
            ? null
            : () => unawaited(_toggleFollow(entry, target, controller)),
      ),
      onTap: state.busy || target == null
          ? null
          : () => unawaited(_openRow(entry, target, controller)),
      semanticLabel:
          '${entry.profile.displayName}，${following ? '已关注' : '未关注'}',
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
      barrierLabel: '关闭联系人操作',
      builder: (sheetContext) => Padding(
        key: const ValueKey<String>('connection-actions-sheet'),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopLabel(entry.profile.displayName),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LoopButton(
                key: const ValueKey<String>('connection-action-dm'),
                label: '打开私聊',
                block: true,
                onPressed: () => Navigator.of(sheetContext).pop('dm'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LoopButton(
                key: const ValueKey<String>('connection-action-follow'),
                label: following ? '取消关注' : '关注',
                block: true,
                onPressed: () => Navigator.of(sheetContext).pop('follow'),
              ),
            ),
            LoopButton(
              key: const ValueKey<String>('connection-action-cancel'),
              label: '取消',
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
      title: following ? '取消关注？' : '关注这个账号？',
      body: following
          ? '取消关注后，你不会再看到对方的公开动态。'
          : '关注是单向的，不需要对方同意。对方需要开启"可被发现"才能被关注。',
      confirmLabel: following ? '取消关注' : '关注',
      sheetKey: 'connections-follow-sheet',
    );
    if (!confirmed) return;
    final failure = await controller.setFollowing(
      publicProfileId: target,
      following: !following,
    );
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: following ? '已取消关注' : '已关注');
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
  }
}
