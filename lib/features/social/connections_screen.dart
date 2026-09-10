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
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// `connections` · following and followers.
///
/// Following is one-directional and needs no consent. Mining power on a row
/// has no source and is stated as unavailable rather than shown as a figure.
class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key, this.onBack, this.onOpenConversation});

  final VoidCallback? onBack;

  /// `dm` is still an unavailable placeholder before D7; the row explains that
  /// instead of pretending a conversation exists.
  final ValueChanged<String>? onOpenConversation;

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
      folio: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'SOCIAL CONNECTIONS',
        heading: counts == null
            ? communityMissingFigure
            : '${counts.following} 关注 · ${counts.followers} 粉丝',
        caption: '公开关系可见，钱包地址始终隐藏。关注是单向的，不需要对方同意。',
        stamp: counts == null ? null : 'SOCIAL',
      ),
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
                  label: counts == null ? '关注' : '关注 ${counts.following}',
                  selected: state.direction == ConnectionDirection.following,
                  onSelected: () => unawaited(
                    controller.selectDirection(ConnectionDirection.following),
                  ),
                ),
              ),
              LoopSeg(
                key: const ValueKey<String>('connections-seg-followers'),
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
      collection: ListView(
        key: const ValueKey<String>('connections-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          CommunityPreviewNotice(mode: mode, resource: '关注关系'),
          if (communityCapabilityBlocks(mode, capability))
            LoopEmpty(
              key: const ValueKey<String>('connections-capability-unavailable'),
              icon: 'warn',
              message: '关注关系当前不可用',
              reason: '请稍后再试。',
            )
          else if (state.phase != CommunityViewPhase.ready)
            CommunityStateBlock(
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: state.direction == ConnectionDirection.following
                  ? '还没有关注任何人'
                  : '还没有粉丝',
              emptyReason: '被你屏蔽的账号不会出现在这里。',
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
            LoopRecordGroup(
              rows: <LoopRecordRow>[
                for (var index = 0; index < state.items.length; index += 1)
                  _connectionRow(
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
                  key: const ValueKey<String>('connections-load-more'),
                  label: '载入更多',
                  block: true,
                  onPressed: () => unawaited(controller.loadMore()),
                ),
              ),
            if (state.items.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              // The reason comes from the server's own per-row projection.
              CommunityUnavailableCard(
                label: '行内算力',
                fact: state.items.first.miningPower,
              ),
            ],
            const LoopNotice(
              key: ValueKey<String>('connections-discoverable-notice'),
              icon: 'info',
              title: '想被别人找到？',
              body: '默认不可被发现。需要在"隐私中心 · 可被发现"里打开后，别人才能搜索到你并关注你。',
              margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
            ),
          ],
        ],
      ),
    );
  }

  LoopRecordRow _connectionRow(
    ConnectionEntry entry,
    int index,
    int length,
    ConnectionsState state,
    ConnectionsController controller,
  ) {
    final target = entry.profile.publicProfileId;
    return LoopRecordRow(
      key: ValueKey<String>('connection-row-${target ?? entry.profile.loopId}'),
      title: entry.profile.displayName,
      subtitle: entry.profile.loopId,
      // The relationship is a state, not a figure.
      trailingBadge: LoopBadge(
        entry.viewerFollows ? '已关注' : '未关注',
        kind: entry.viewerFollows ? LoopBadgeKind.up : LoopBadgeKind.mute,
      ),
      position: communityRowPosition(index, length),
      onTap: state.busy || target == null
          ? null
          : () => unawaited(_openRow(entry, target, controller)),
      semanticLabel:
          '${entry.profile.displayName}，${entry.viewerFollows ? '已关注' : '未关注'}',
    );
  }

  /// The row offers exactly two commands: open the conversation (still an
  /// unavailable placeholder before D7) and follow / unfollow.
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
      widget.onOpenConversation?.call(target);
      return;
    }
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
