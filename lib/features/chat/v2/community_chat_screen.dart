import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/chat/v2/loop_stream_channel_surface.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
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
/// online count have no source in this step, so the header strip states
/// neither and takes no room (decision 0071).
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
              title: detail?.community.name ?? communityMissingName,
              // `#scr-community-chat .topbar` puts the room's one presence
              // fact on an 11px line *under* the name. A mono eyebrow above
              // it reads as a section marker, which a conversation header is
              // not; the preview marker still earns that slot, because a
              // reader has to know the room is a preview before they read a
              // word of it.
              kicker: communityPreviewKicker(mode),
              subtitle: communityChatPresenceLine(detail),
              onBack: widget.onBack,
              minHeight: 72,
              // Four tools plus the back control leave the channel name a
              // column about 120pt wide. At the bar's own 24pt heading step
              // that was four characters and an ellipsis — a header that could
              // not say which channel it was. `dense` prints the title at
              // 18pt, where the same column holds a whole short name, and two
              // of those lines still fit the 72pt bar, so every tool stays
              // where it was.
              titleMaxLines: 2,
              dense: true,
              // `.back.tool-btn` and `.seg`: the prototype frames every
              // control in this bar. Over a message list a row of bare glyphs
              // has no edge to be aimed at (audit 2026-09-20 · B.2).
              framedTools: true,
              actions: <Widget>[
                if (detail?.chat.channelCid case final String cid) ...<Widget>[
                  LoopIconButton(
                    key: const ValueKey<String>('community-chat-open-search'),
                    icon: 'search',
                    label: '搜索这个会话',
                    framed: true,
                    onPressed: () => widget.onOpenSearch?.call(cid),
                  ),
                  LoopIconButton(
                    key: const ValueKey<String>('community-chat-open-forward'),
                    icon: 'shuffle',
                    label: '转发消息',
                    framed: true,
                    onPressed: () => widget.onOpenForward?.call(cid),
                  ),
                ],
                if (detail != null) ...<Widget>[
                  LoopIconButton(
                    key: const ValueKey<String>('community-chat-open-voice'),
                    icon: 'voice',
                    label: '进入语音房',
                    framed: true,
                    onPressed: () => widget.onOpenVoiceRoom?.call(
                      detail.community.communityId,
                    ),
                  ),
                  LoopIconButton(
                    key: const ValueKey<String>('community-chat-open-profile'),
                    icon: 'info',
                    label: '社区信息',
                    framed: true,
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
    final aiGate = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.communityAi),
    );
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
      // One half of the prototype's hint is real now: an address pasted into
      // a message opens a Token Card. The other half — "@AI 提问" — stays
      // out, because there is no Community AI to ask.
      composerHint: loopChatComposerHint,
      // Stream answered the membership query with nothing. LOOP's own record
      // of this account's channel membership is the only fact available about
      // why, so its reason code supplies the sentence; without one the
      // surface states only what it observed.
      unresolvedMessage: switch (chat.memberState) {
        CommunityChatMemberState.pending => communicationUnavailableReason(
          'COMMUNITY_CHANNEL_MEMBER_SYNCING',
        ),
        CommunityChatMemberState.capacityPending =>
          communicationUnavailableReason('COMMUNITY_CHANNEL_CAPACITY_PENDING'),
        CommunityChatMemberState.removed ||
        CommunityChatMemberState.synced => null,
        null => null,
      },
      // Presence and the pinned announcement are one line, and only when the
      // server stated them. `onlineCount` and `announcements` are both
      // `{status: unavailable}` projections in this step, so the strip is
      // handed nothing and renders nothing: an absent fact does not earn a
      // card explaining its own absence, and the message list keeps the room.
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CommunityPreviewNotice(mode: state.mode, resource: '社区官方群'),
          LoopChatHeaderStrip(
            key: const ValueKey<String>('community-chat-header-strip'),
            // The one identity fact LOOP may state about the reader in this
            // room: the persona this community issued them (decision 0055).
            // Everybody else's name is read from that member's own channel
            // projection, never from a LOOP record.
            segments: <String>[
              ?communityChatPersonaSegment(chat.viewerPersona),
            ],
            collapsed: loopChatKeyboardIsUp(context),
          ),
          // `.notice` with the pin glyph, directly under the bar — the
          // prototype's `Q3 路线图已发布 · 项目方`. It appears only when this
          // community actually pinned something; an absent announcement earns
          // no strip of its own.
          if (communityChatPinnedAnnouncement(detail.announcements)
              case final CommunityAnnouncement pinned)
            LoopChatHeaderFold(
              collapsed: loopChatKeyboardIsUp(context),
              child: LoopNotice(
                key: const ValueKey<String>('community-chat-pinned'),
                icon: 'pin',
                body: pinned.byline == null
                    ? pinned.title
                    : '${pinned.title} · ${pinned.byline}',
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              ),
            ),
          // The prototype's last message in this room is the community's AI
          // answering. There is none, so the row states that instead.
          if (!aiGate.isUsable)
            LoopChatAiUnavailableBubble(
              key: const ValueKey<String>('community-chat-ai-unavailable'),
              name: '${detail.community.name} AI',
              reason: communicationUnavailableReason(
                aiGate.reasonCode ?? 'COMMUNITY_AI_RUNTIME_DEFERRED',
              ),
              collapsed: loopChatKeyboardIsUp(context),
            ),
        ],
      ),
    );
  }
}

/// The room's presence line, or `null` when the server stated none.
///
/// `#scr-community-chat .topbar` prints `3,241 在线` under the name. It is one
/// observation with one number; a community whose presence LOOP could not read
/// gets no line at all rather than a dash or a zero.
String? communityChatPresenceLine(CommunityDetail? detail) =>
    switch (detail?.onlineCount) {
      CommunityOnlineCountObserved(:final count) => '$count 在线',
      _ => null,
    };

/// The announcement this community pinned, or `null`.
///
/// The prototype's strip carries one line, so this returns the first pinned
/// row in the server's own order. An unavailable feed and a published feed
/// with nothing pinned are the same answer here: no strip.
CommunityAnnouncement? communityChatPinnedAnnouncement(
  CommunityAnnouncementFeed feed,
) {
  if (feed is! CommunityAnnouncementFeedPublished) return null;
  for (final item in feed.items) {
    if (item.pinned) return item;
  }
  return null;
}

/// One line naming the reader inside this community's official group.
///
/// `null` when the server has stated no persona: not issued yet, or this
/// account is not a member. A persona LOOP has issued but the provider has not
/// confirmed is named as what it is — the room still shows this account under
/// the neutral label until the projection lands.
String? communityChatPersonaSegment(CommunityChatPersona? persona) {
  if (persona == null) return null;
  return persona.isPending ? '正在同步你的显示名' : '你在这个社区显示为 ${persona.alias}';
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
