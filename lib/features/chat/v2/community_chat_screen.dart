import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';

/// `community-chat` · the official community channel.
///
/// The channel is entered only through the server's own `chat.channelCid`.
/// `syncing` is shown as "聊天权限同步中", never as unavailable, because LOOP has
/// already recorded the membership intent. The pinned announcement and the
/// online count have no source in this step and stay unavailable.
class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({
    required this.communityId,
    super.key,
    this.onBack,
    this.onOpenProfile,
    this.onOpenVoiceRoom,
    this.onOpenSearch,
    this.onOpenForward,
  });

  final String? communityId;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenProfile;
  final ValueChanged<String>? onOpenVoiceRoom;

  /// Both take the channel CID, so search and forwarding start from the exact
  /// conversation the user is reading.
  final ValueChanged<String>? onOpenSearch;
  final ValueChanged<String>? onOpenForward;

  @override
  ConsumerState<CommunityChatScreen> createState() =>
      _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityChat),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final state = ref.watch(communityChatControllerProvider);
    final controller = ref.read(communityChatControllerProvider.notifier);
    final id = widget.communityId;
    final blocked = communityCapabilityBlocks(mode, capability);
    if (!blocked && id != null && state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(id));
      });
    }

    final detail = state.value;
    return Scaffold(
      key: const ValueKey<String>('community-chat-screen'),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LoopTopbar(
              title: detail?.community.name ?? communityMissingFigure,
              kicker: communityPreviewKicker(mode),
              onBack: widget.onBack,
              minHeight: 72,
              actions: <Widget>[
                if (detail?.chat.channelCid case final String cid) ...<Widget>[
                  LoopIconButton(
                    key: const ValueKey<String>('community-chat-open-search'),
                    icon: 'search',
                    label: '搜索这个会话',
                    onPressed: () => widget.onOpenSearch?.call(cid),
                  ),
                  LoopIconButton(
                    key: const ValueKey<String>('community-chat-open-forward'),
                    icon: 'shuffle',
                    label: '转发消息',
                    onPressed: () => widget.onOpenForward?.call(cid),
                  ),
                ],
                if (detail != null) ...<Widget>[
                  LoopIconButton(
                    key: const ValueKey<String>('community-chat-open-voice'),
                    icon: 'voice',
                    label: '进入语音房',
                    onPressed: () => widget.onOpenVoiceRoom?.call(
                      detail.community.communityId,
                    ),
                  ),
                  LoopIconButton(
                    key: const ValueKey<String>('community-chat-open-profile'),
                    icon: 'info',
                    label: '社区信息',
                    onPressed: () => widget.onOpenProfile?.call(
                      detail.community.communityId,
                    ),
                  ),
                ],
              ],
            ),
            Expanded(
              child: _body(id: id, blocked: blocked, state: state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body({
    required String? id,
    required bool blocked,
    required CommunityResourceState<CommunityDetail> state,
  }) {
    final controller = ref.read(communityChatControllerProvider.notifier);
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityChat),
    );
    if (id == null) {
      return const _ChatBlock(
        blockKey: 'community-chat-missing-id',
        message: '缺少社区标识',
        reason: '请从社区列表或社区主页进入，本页不会猜测要打开哪个社区的官方群。',
      );
    }
    if (blocked) {
      return _ChatBlock(
        blockKey: 'community-chat-capability-unavailable',
        message: '社区聊天当前不可用',
        reason: capability.reasonCode == null
            ? '尚未读取到能力清单，本页不请求任何频道。'
            : communicationUnavailableReason(capability.reasonCode),
      );
    }
    final detail = state.value;
    if (detail == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: CommunityStateBlock(
          phase: state.phase,
          failureKind: state.failureKind,
          skeleton: LoopSkeletonType.list,
          emptyMessage: '找不到这个社区',
          emptyReason: '它可能已被移除，或对当前账号不可见。',
          onRetry: () => unawaited(controller.reload()),
        ),
      );
    }

    final chat = detail.chat;
    if (chat.isSyncing) {
      return _SyncingBlock(
        reasonCode: chat.reasonCode,
        onRetry: () => unawaited(controller.reload()),
      );
    }
    if (!chat.isAvailable) {
      return _ChatBlock(
        blockKey: 'community-chat-unavailable',
        message: '官方群当前不可用',
        reason: communicationUnavailableReason(chat.reasonCode),
        onRetry: () => unawaited(controller.reload()),
      );
    }

    return LoopStreamChannelSurface(
      key: ValueKey<String>('community-chat-${chat.channelCid}'),
      cid: chat.channelCid!,
      keyPrefix: 'community-chat-channel',
      // The prototype's "@AI 提问 · 贴 CA 自动识别" hint is not reproduced: neither
      // capability exists yet, so the composer promises only a message.
      composerHint: '发消息',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CommunityPreviewNotice(mode: state.mode, resource: '社区官方群'),
          CommunityUnavailableCard(
            key: const ValueKey<String>('community-chat-online-unavailable'),
            label: '在线人数',
            fact: detail.onlineCount,
          ),
          CommunityUnavailableCard(
            key: const ValueKey<String>(
              'community-chat-announcement-unavailable',
            ),
            label: '置顶公告',
            fact: detail.announcements,
          ),
        ],
      ),
    );
  }
}

class _SyncingBlock extends StatelessWidget {
  const _SyncingBlock({required this.reasonCode, required this.onRetry});

  final String? reasonCode;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopNotice(
          key: const ValueKey<String>('community-chat-syncing'),
          icon: 'clock',
          title: '聊天权限同步中',
          body:
              '${communicationUnavailableReason(reasonCode)}'
              'LOOP 已经记录了你的成员身份，服务商侧还没跟上。稍后重试即可，不需要重新加入社区。',
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: LoopButton(
            key: const ValueKey<String>('community-chat-syncing-retry'),
            label: '重新检查',
            block: true,
            onPressed: onRetry,
          ),
        ),
      ],
    ),
  );
}

class _ChatBlock extends StatelessWidget {
  const _ChatBlock({
    required this.blockKey,
    required this.message,
    required this.reason,
    this.onRetry,
  });

  final String blockKey;
  final String message;
  final String reason;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopEmpty(
          key: ValueKey<String>(blockKey),
          icon: 'warn',
          message: message,
          reason: reason,
        ),
        if (onRetry != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: LoopButton(
              key: ValueKey<String>('$blockKey-retry'),
              label: '重试',
              block: true,
              onPressed: onRetry,
            ),
          ),
      ],
    ),
  );
}
