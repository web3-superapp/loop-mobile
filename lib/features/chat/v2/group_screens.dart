import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_gateway.dart';
import 'package:loop_mobile/features/chat/group_alias/group_alias_models.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_gateway.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The unavailable facts `group-info` renders instead of prototype samples.
const _memberDirectoryDeferred = LoopUnavailableFact(
  'GROUP_MEMBER_DIRECTORY_DEFERRED',
);
const _groupProfileDeferred = LoopUnavailableFact('GROUP_PROFILE_DEFERRED');
const _groupSettingsDeferred = LoopUnavailableFact('GROUP_SETTINGS_DEFERRED');

/// `group` · one small-group conversation.
///
/// The channel address always comes from the server (group creation, the
/// channel list, or a notification deep link). The page adds only the chrome:
/// Stream still owns history, delivery, read state and the composer.
class GroupChatScreen extends ConsumerWidget {
  const GroupChatScreen({
    required this.channelCid,
    super.key,
    this.onBack,
    this.onOpenInfo,
    this.onOpenSearch,
    this.onOpenForward,
  });

  final String? channelCid;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenInfo;

  /// Both take the channel CID, so search and forwarding start from the exact
  /// conversation the user is reading.
  final ValueChanged<String>? onOpenSearch;
  final ValueChanged<String>? onOpenForward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityChat),
    );
    final mode = ref.watch(chatV2GatewayProvider).mode;
    final cid = channelCid;
    final blocked = communityCapabilityBlocks(mode, capability);
    return Scaffold(
      key: const ValueKey<String>('group-screen'),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopTopbar(
              title: '群聊',
              kicker: communityPreviewKicker(mode),
              onBack: onBack,
              minHeight: 72,
              actions: <Widget>[
                if (cid != null) ...<Widget>[
                  LoopIconButton(
                    key: const ValueKey<String>('group-open-search'),
                    icon: 'search',
                    label: '搜索这个会话',
                    onPressed: () => onOpenSearch?.call(cid),
                  ),
                  LoopIconButton(
                    key: const ValueKey<String>('group-open-forward'),
                    icon: 'shuffle',
                    label: '转发消息',
                    onPressed: () => onOpenForward?.call(cid),
                  ),
                  LoopIconButton(
                    key: const ValueKey<String>('group-open-info'),
                    icon: 'info',
                    label: '群信息',
                    onPressed: () => onOpenInfo?.call(cid),
                  ),
                ],
              ],
            ),
            Expanded(
              child: switch ((blocked, cid)) {
                (true, _) => _Block(
                  blockKey: 'group-capability-unavailable',
                  message: '群聊当前不可用',
                  reason: capability.reasonCode == null
                      ? '尚未读取到能力清单，本页不请求任何频道。'
                      : communicationUnavailableReason(capability.reasonCode),
                ),
                (false, null) => const _Block(
                  blockKey: 'group-missing-cid',
                  message: '缺少群聊标识',
                  reason: '请从会话列表或群信息进入，本页不会猜测要打开哪个群。',
                ),
                (false, final String value) => LoopStreamChannelSurface(
                  key: ValueKey<String>('group-$value'),
                  cid: value,
                  composerHint: '发消息',
                  header: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      CommunityPreviewNotice(mode: mode, resource: '群聊'),
                      const LoopNotice(
                        key: ValueKey<String>('group-scope-note'),
                        icon: 'info',
                        title: '普通群与社区的区别',
                        body:
                            '普通群没有社区币、没有 Mining Weight，也没有 Community AI。'
                            '带币社区在「社区」栏。',
                        margin: EdgeInsets.fromLTRB(16, 10, 16, 4),
                      ),
                    ],
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// `group-info` · the group record and its one available action.
///
/// Member management (kick, rename) has no reviewed source in this step and is
/// rendered unavailable. Leaving goes through the LOOP backend, never Stream's
/// own `leave`, so the removal stays server-owned and idempotent.
class GroupInfoScreen extends ConsumerStatefulWidget {
  const GroupInfoScreen({
    required this.channelCid,
    super.key,
    this.onBack,
    this.onLeft,
  });

  final String? channelCid;
  final VoidCallback? onBack;
  final VoidCallback? onLeft;

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  GroupId? _groupId;
  bool _resolving = false;

  /// Why the exit is closed. `null` means the resolve has not failed.
  ///
  /// The kind is kept rather than a boolean so an offline device, a group the
  /// server will not confirm, and a broken response each get their own block
  /// instead of one indistinguishable failure.
  GroupAliasGatewayFailureKind? _resolveFailure;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_resolveGroup);
  }

  Future<void> _resolveGroup() async {
    final cid = widget.channelCid;
    if (cid == null || _resolving) return;
    GroupAliasStreamChannelId channelId;
    try {
      channelId = GroupAliasStreamChannelId.fromCid(cid);
    } on InvalidGroupAliasContractException {
      if (mounted) {
        setState(
          () => _resolveFailure = GroupAliasGatewayFailureKind.invalidData,
        );
      }
      return;
    }
    setState(() {
      _resolving = true;
      _resolveFailure = null;
    });
    try {
      final groupId = await ref
          .read(groupAliasResolverGatewayProvider)
          .resolveGroup(channelId);
      if (!mounted) return;
      setState(() {
        _groupId = groupId;
        _resolving = false;
      });
    } on GroupAliasGatewayException catch (error) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _resolveFailure = error.kind;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _resolveFailure = GroupAliasGatewayFailureKind.unexpected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(chatV2GatewayProvider).mode;
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityChat),
    );
    final busy = ref.watch(groupMembershipControllerProvider);
    final blocked = communityCapabilityBlocks(mode, capability);
    final canLeave = !blocked && _groupId != null && !busy;

    return LoopDashboardPage(
      key: const ValueKey<String>('group-info-screen'),
      archetype: LoopPageArchetype.record,
      title: '群信息',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      primary: const LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'GROUP RECORD',
        heading: '群信息',
        caption: '成员、通知与退出操作按风险从低到高排列。本页只展示服务端确认过的事实。',
        stamp: 'PRIVATE',
      ),
      sections: <Widget>[
        CommunityPreviewNotice(mode: mode, resource: '群信息'),
        if (blocked)
          LoopEmpty(
            key: const ValueKey<String>('group-info-capability-unavailable'),
            icon: 'warn',
            message: '群聊当前不可用',
            reason: capability.reasonCode == null
                ? '尚未读取到能力清单，本页不请求任何群资源。'
                : communicationUnavailableReason(capability.reasonCode),
          )
        else if (widget.channelCid == null)
          const LoopEmpty(
            key: ValueKey<String>('group-info-missing-cid'),
            icon: 'warn',
            message: '缺少群聊标识',
            reason: '请从群聊页进入，本页不会猜测要打开哪个群的信息。',
          )
        else ...<Widget>[
          const LoopLabel('成员'),
          const CommunityUnavailableCard(
            key: ValueKey<String>('group-info-members-unavailable'),
            label: '成员与成员管理',
            fact: _memberDirectoryDeferred,
          ),
          const LoopLabel('群资料'),
          const CommunityUnavailableCard(
            key: ValueKey<String>('group-info-profile-unavailable'),
            label: '群名称与简介',
            fact: _groupProfileDeferred,
          ),
          const LoopLabel('设置'),
          const CommunityUnavailableCard(
            key: ValueKey<String>('group-info-settings-unavailable'),
            label: '消息通知与置顶会话',
            fact: _groupSettingsDeferred,
          ),
          const LoopLabel('退出'),
          if (_resolving)
            const LoopSkeleton(
              key: ValueKey<String>('group-info-state-loading'),
              type: LoopSkeletonType.list,
              rows: 1,
            )
          else if (_resolveFailure == GroupAliasGatewayFailureKind.offline)
            LoopOfflineState(
              key: const ValueKey<String>('group-info-state-offline'),
              onRetry: () => unawaited(_resolveGroup()),
              pausedActions: const <String>['退出群聊'],
            )
          else if (_resolveFailure == GroupAliasGatewayFailureKind.notFound)
            const LoopEmpty(
              key: ValueKey<String>('group-info-state-empty'),
              icon: 'info',
              message: '没有可退出的群成员关系',
              reason: '服务端没有确认这个群，或当前账号已经不是成员。这不代表退出失败。',
            )
          else if (_resolveFailure == GroupAliasGatewayFailureKind.unavailable)
            const LoopEmpty(
              key: ValueKey<String>('group-info-state-unavailable'),
              icon: 'warn',
              message: '退出操作当前不可用',
              reason: '群成员关系服务暂时不可用，本页没有提交任何变更。',
            )
          else if (_resolveFailure != null)
            LoopErrorState(
              key: const ValueKey<String>('group-info-resolve-failed'),
              reason: '没有确认这个群的服务端标识，因此不提供退出操作，也没有提交任何变更。',
              onRetry: () => unawaited(_resolveGroup()),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: LoopButton(
                key: const ValueKey<String>('group-info-leave'),
                label: '退出群聊',
                block: true,
                icon: 'warn',
                onPressed: canLeave ? () => unawaited(_leave()) : null,
              ),
            ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _leave() async {
    final groupId = _groupId;
    if (groupId == null) return;
    final confirmed = await confirmCommunityAction(
      context,
      title: '退出这个群聊？',
      body: '退出后你将不再收到这个群的消息。群创建者不能退出，是否接受由服务端判定。',
      confirmLabel: '退出',
      sheetKey: 'group-leave-confirm-sheet',
    );
    if (!confirmed || !mounted) return;
    final failure = await ref
        .read(groupMembershipControllerProvider.notifier)
        .leave(groupId.wireValue);
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: '已退出群聊');
      widget.onLeft?.call();
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.warn,
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.blockKey,
    required this.message,
    required this.reason,
  });

  final String blockKey;
  final String message;
  final String reason;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: LoopEmpty(
      key: ValueKey<String>(blockKey),
      icon: 'warn',
      message: message,
      reason: reason,
    ),
  );
}
