import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_models.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chain/chain_contract.dart';
import 'package:loop_mobile/features/market/loop_sparkline.dart';
import 'package:loop_mobile/features/market/market_controllers.dart';
import 'package:loop_mobile/features/market/market_read_models.dart';
import 'package:loop_mobile/features/market/token_card_chart.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';
import 'package:loop_mobile/widgets/loop_token_card.dart';

/// `community-profile` · one community record.
///
/// The Token Card is rendered only when the server reports a bound asset, and
/// even then it carries no price, market cap or holder fact: `boundAssetKey`
/// is stored but not resolved before D10.
class CommunityProfileScreen extends ConsumerStatefulWidget {
  const CommunityProfileScreen({
    required this.communityId,
    super.key,
    this.onBack,
    this.onOpenMembers,
    this.onOpenChat,
    this.onOpenVoiceRoom,
    this.onOpenMiningPanel,
    this.onOpenToken,
  });

  final String? communityId;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenMembers;
  final ValueChanged<String>? onOpenChat;
  final ValueChanged<String>? onOpenVoiceRoom;

  /// The community's own mining panel. Mining Power has no source here, so
  /// the row is a way to the panel, never a figure.
  final ValueChanged<String>? onOpenMiningPanel;

  /// Opens the market `token` page for the bound asset's canonical id.
  final ValueChanged<String>? onOpenToken;

  @override
  ConsumerState<CommunityProfileScreen> createState() =>
      _CommunityProfileScreenState();
}

class _CommunityProfileScreenState
    extends ConsumerState<CommunityProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final state = ref.watch(communityProfileControllerProvider);
    final controller = ref.read(communityProfileControllerProvider.notifier);
    final id = widget.communityId;
    if (!communityCapabilityBlocks(mode, capability) &&
        id != null &&
        state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(id));
      });
    }

    final detail = state.value;
    final community = detail?.community;
    return LoopDashboardPage(
      key: const ValueKey<String>('community-profile-screen'),
      archetype: LoopPageArchetype.record,
      title: community?.name ?? communityMissingName,
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      actions: <Widget>[
        if (community != null)
          LoopIconButton(
            key: const ValueKey<String>('community-profile-open-members'),
            icon: 'users',
            label: '成员与权限',
            onPressed: () => widget.onOpenMembers?.call(community.communityId),
          ),
      ],
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.record,
        kicker: 'COMMUNITY RECORD',
        heading: community?.name ?? communityMissingName,
        caption: community == null
            ? '社区资料暂时读不到，这里不显示数字。'
            : '${community.memberCount} 名成员 · 创建于 '
                  '${communityObservedAtLabel(community.createdAt)}',
        stamp: community == null
            ? null
            : switch (community.verificationStatus) {
                CommunityVerification.verified => 'VERIFIED',
                CommunityVerification.pending => 'PENDING',
                CommunityVerification.rejected => 'REJECTED',
              },
      ),
      block: id != null && communityCapabilityBlocks(mode, capability)
          ? CommunityCapabilityPageBlock(
              key: const ValueKey<String>(
                'community-profile-capability-unavailable',
              ),
              capability: capability,
              title: '社区模块当前不可用',
            )
          : null,
      onRefresh: id == null ? null : controller.reload,
      updating: state.refreshing,
      sections: <Widget>[
        CommunityPreviewNotice(mode: mode, resource: '社区档案'),
        if (id == null)
          const LoopEmpty(
            key: ValueKey<String>('community-profile-missing-id'),
            icon: 'warn',
            message: '缺少社区标识',
            reason: '请从社区列表或搜索结果进入，本页不会猜测要打开哪个社区。',
          )
        else if (detail == null)
          CommunityStateBlock(
            phase: state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.detail,
            emptyMessage: '找不到这个社区',
            emptyReason: '它可能已被移除，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else ...<Widget>[
          _CommunityIdentityCard(community: detail.community),
          // Owner-only. Visibility comes from the server's viewer projection,
          // never from a client-side re-implementation of the matrix.
          if (detail.viewer.isOwner)
            LoopButtonPair(
              children: <Widget>[
                LoopButton(
                  key: const ValueKey<String>('community-edit-profile-action'),
                  label: '编辑社区资料',
                  onPressed: state.busy
                      ? null
                      : () => unawaited(_editProfile(controller, detail)),
                ),
              ],
            ),
          _MembershipActions(
            detail: detail,
            busy: state.busy,
            onJoin: () => _changeMembership(controller, joined: true),
            onLeave: () => _changeMembership(controller, joined: false),
          ),
          if (state.failureKind != null)
            LoopNotice(
              key: const ValueKey<String>('community-profile-action-failure'),
              icon: 'warn',
              tone: LoopNoticeTone.warn,
              title: '上一次操作没有完成',
              body: communityFailureReason(state.failureKind),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            ),
          const LoopLabel('聊天与语音'),
          _ChannelActions(
            detail: detail,
            opening: ref.watch(voiceRoomOpenControllerProvider),
            onOpenChat: () =>
                widget.onOpenChat?.call(detail.community.communityId),
            onOpenVoiceRoom: () =>
                widget.onOpenVoiceRoom?.call(detail.community.communityId),
            onCreateVoiceRoom: () => unawaited(_createVoiceRoom(detail)),
          ),
          const LoopLabel('在线'),
          CommunityOnlineCountCard(fact: detail.onlineCount),
          const LoopLabel('社区币'),
          if (!detail.community.hasBoundAsset)
            const LoopEmpty(
              key: ValueKey<String>('community-profile-no-asset'),
              message: '未绑定资产',
              reason: '这个社区没有绑定代币，因此不显示代币卡片或行情。',
            )
          else
            _BoundAssetCard(
              assetKey: detail.community.boundAssetKey!,
              onOpenToken: widget.onOpenToken,
            ),
          const LoopLabel('挖矿'),
          CommunityMiningPowerCard(
            label: 'Mining Power',
            fact: detail.miningPower,
          ),
          LoopRecordGroup(
            rows: <LoopRecordRow>[
              LoopRecordRow(
                key: const ValueKey<String>('community-profile-mining-panel'),
                title: '社区挖矿面板',
                subtitle: '权重、社区算力与我的贡献',
                onTap: widget.onOpenMiningPanel == null
                    ? null
                    : () => widget.onOpenMiningPanel!(
                        detail.community.communityId,
                      ),
              ),
            ],
          ),
          const LoopLabel('公告'),
          CommunityUnavailableCard(label: '社区公告', fact: detail.announcements),
          const LoopLabel('官方链接'),
          CommunityUnavailableCard(label: '官方链接', fact: detail.officialLinks),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _editProfile(
    CommunityProfileController controller,
    CommunityDetail detail,
  ) async {
    final edit = await showCommunityProfileEditSheet(
      context,
      community: detail.community,
    );
    if (edit == null || !mounted) return;
    final confirmed = await confirmCommunityAction(
      context,
      title: '提交社区资料修改？',
      body: '短链接与验证状态不能在这里修改。',
      confirmLabel: '提交',
      sheetKey: 'community-edit-confirm-sheet',
    );
    if (!confirmed) return;
    final failure = await controller.editProfile(edit);
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: '社区资料已更新');
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
  }

  /// Opens a room for this community. The button exists only for a viewer the
  /// server reports as owner or admin, but the admission is still the
  /// server's: this states what came back and never claims a room that was
  /// not confirmed.
  Future<void> _createVoiceRoom(CommunityDetail detail) async {
    final confirmed = await confirmCommunityAction(
      context,
      title: '开启语音房？',
      body:
          '房间会立刻对社区成员可见，任何成员都能进来收听。你是主持人，'
          '邀请发言、全体静音和结束房间都由你或其他管理员操作；麦克风默认关闭。',
      confirmLabel: '开启',
      sheetKey: 'community-open-voice-room-sheet',
    );
    if (!confirmed || !mounted) return;
    final failure = await ref
        .read(voiceRoomOpenControllerProvider.notifier)
        .openRoom(detail.community.communityId);
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: '语音房已开启');
      unawaited(ref.read(communityProfileControllerProvider.notifier).reload());
      widget.onOpenVoiceRoom?.call(detail.community.communityId);
      return;
    }
    LoopToast.show(
      context,
      message: failure == CommunityFailureKind.resourceConflict
          // The shared copy for this code is about a taken slug; here the
          // conflict is a room that is already live.
          ? '这个社区已经有进行中的语音房，没有重复创建。请刷新后进入。'
          : communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
    if (failure == CommunityFailureKind.resourceConflict) {
      unawaited(ref.read(communityProfileControllerProvider.notifier).reload());
    }
  }

  Future<void> _changeMembership(
    CommunityProfileController controller, {
    required bool joined,
  }) async {
    final confirmed = await confirmCommunityAction(
      context,
      title: joined ? '加入这个社区？' : '退出这个社区？',
      body: joined ? '加入后你会出现在成员列表里。' : '退出后你将从成员目录中移除。社区所有者需要先转让所有权才能退出。',
      confirmLabel: joined ? '加入' : '退出',
      sheetKey: 'community-membership-sheet',
    );
    if (!confirmed) return;
    final failure = await controller.setMembership(joined: joined);
    if (!mounted) return;
    if (failure == null) {
      LoopToast.show(context, message: joined ? '已加入社区' : '已退出社区');
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
  }
}

class _CommunityIdentityCard extends StatelessWidget {
  const _CommunityIdentityCard({required this.community});

  final CommunitySummary community;

  @override
  Widget build(BuildContext context) {
    return LoopSurfaceCard(
      key: const ValueKey<String>('community-profile-identity'),
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CommunityLogoTile(name: community.name, size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        community.name,
                        style: LoopTypography.title(17),
                      ),
                    ),
                    if (community.isVerified) ...<Widget>[
                      const SizedBox(width: 8),
                      const LoopBadge(
                        '已验证',
                        key: ValueKey<String>('community-verified-stamp'),
                        kind: LoopBadgeKind.up,
                      ),
                    ],
                  ],
                ),
                // The slug was printed under the name as a bare
                // `builders-guild`. It is the server's addressing handle, not
                // a name, and there is nothing a reader does with it here.
                const SizedBox(height: 8),
                Text(
                  community.description ?? '这个社区还没有填写简介。',
                  style: LoopTypography.caption(12, color: LoopColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipActions extends StatelessWidget {
  const _MembershipActions({
    required this.detail,
    required this.busy,
    required this.onJoin,
    required this.onLeave,
  });

  final CommunityDetail detail;
  final bool busy;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final membership = detail.viewer.membership;
    if (membership?.status == CommunityMemberStatus.banned) {
      // A banned membership row stays readable, but nothing on it can act.
      return const LoopNotice(
        key: ValueKey<String>('community-membership-banned'),
        icon: 'shield',
        tone: LoopNoticeTone.danger,
        title: '你已被该社区封禁',
        body:
            '社区聊天与治理动作对你不可用，你也不在默认成员目录里。'
            '只有社区的所有者或管理员可以解除封禁；解除后你会恢复为活跃成员，无需重新加入。',
        margin: EdgeInsets.fromLTRB(16, 0, 16, 14),
      );
    }
    if (membership == null) {
      return LoopButtonPair(
        children: <Widget>[
          LoopButton(
            key: const ValueKey<String>('community-join-action'),
            label: '加入社区',
            primary: true,
            onPressed: busy ? null : onJoin,
          ),
        ],
      );
    }
    final status = switch (membership.status) {
      CommunityMemberStatus.active => membership.role.label,
      CommunityMemberStatus.muted => '已禁言（仅影响聊天）',
      CommunityMemberStatus.banned => '已封禁',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopKeyValue(
          key: const ValueKey<String>('community-membership-status'),
          label: '我的身份',
          value: status,
        ),
        // The owner cannot leave: the server refuses it until ownership is
        // transferred, so the control is not offered.
        if (membership.role != CommunityRole.owner)
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('community-leave-action'),
                label: '退出社区',
                onPressed: busy ? null : onLeave,
              ),
            ],
          )
        else
          // The role the transfer actually leaves behind is Admin, which is
          // what the members page's own confirmation states; this notice used
          // to promise 普通成员 and disagree with the sheet the reader is
          // about to open.
          const LoopNotice(
            key: ValueKey<String>('community-owner-cannot-leave'),
            icon: 'info',
            title: '所有者不能直接退出',
            body:
                '先在「成员」页对某位成员执行「转让所有者」，你会降为 Admin，'
                '之后才能退出。转让之前，所有者不能退出社区。',
            margin: EdgeInsets.fromLTRB(16, 0, 16, 14),
          ),
      ],
    );
  }
}

/// `.tcard.tcard-signature` for the community's bound asset.
///
/// The community module stores the address and never resolves it: it has no
/// price, market cap, liquidity or holder source, and the card says so instead
/// of rendering a figure. The one thing that *is* addressable by the canonical
/// key is the market module's own `1h` candle series, so the card's line is a
/// real read with its own unavailable state — never a decorative shape.
class _BoundAssetCard extends ConsumerStatefulWidget {
  const _BoundAssetCard({required this.assetKey, this.onOpenToken});

  final String assetKey;
  final ValueChanged<String>? onOpenToken;

  @override
  ConsumerState<_BoundAssetCard> createState() => _BoundAssetCardState();
}

class _BoundAssetCardState extends ConsumerState<_BoundAssetCard> {
  @override
  Widget build(BuildContext context) {
    final request = MarketCandleRequest(
      assetId: widget.assetKey,
      interval: LoopCandleInterval.oneHour,
    );
    final state = ref.watch(marketCandlesControllerProvider(request));
    if (state.phase == LoopChainViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) {
          unawaited(
            ref.read(marketCandlesControllerProvider(request).notifier).load(),
          );
        }
      });
    }
    // The chart slot is a fixed 106px box. With no line in it, that box was
    // 200px of black under a sentence that pointed at a line which was not
    // there. A card that cannot draw one carries no slot and says so on the
    // line it already has.
    final absence = tokenCardSparklineAbsence(state);
    return KeyedSubtree(
      key: const ValueKey<String>('community-bound-asset'),
      child: LoopTokenCard(
        // The prototype's community-profile card is the plain signature card
        // with a chart slot. Its honesty comes from the stated reasons below,
        // not from a state enum: 数据缺失 carries no chart slot at all.
        state: LoopTokenCardState.normal,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        model: LoopTokenCardModel(
          symbol: loopTruncatedAssetId(widget.assetKey),
          identifier: widget.assetKey,
          priceReason: '暂无价格',
          communityIcon: 'info',
          communityLine: absence == null
              ? '这个地址由社区所有者登记，还没有解析。价格、市值、流动性与持有人暂时都读不到，'
                    '这张卡片不显示行情数字，下面的走势线来自行情页。'
              : '这个地址由社区所有者登记，还没有解析。价格、市值、流动性与持有人暂时都读不到，'
                    '这张卡片不显示行情数字。暂无走势：${absence.text}',
          chartRangeLabel: absence == null
              ? '1H · 最近 $loopSparklineWindow 根收盘价'
              : null,
          chart: absence == null
              ? TokenCardSparkline(
                  assetId: widget.assetKey,
                  keyPrefix: 'community-bound-asset-chart',
                )
              : null,
        ),
        actions: <LoopTokenCardAction>[
          LoopTokenCardAction(
            '资产事实',
            onTap: widget.onOpenToken == null
                ? null
                : () => widget.onOpenToken!(widget.assetKey),
          ),
        ],
      ),
    );
  }
}

/// The two conversation entries a community record offers.
///
/// The official channel opens only when the server reports it as available;
/// `syncing` still opens the page, which then explains the wait. The voice
/// entry appears only for a room the server reports as live.
class _ChannelActions extends StatelessWidget {
  const _ChannelActions({
    required this.detail,
    required this.opening,
    required this.onOpenChat,
    required this.onOpenVoiceRoom,
    required this.onCreateVoiceRoom,
  });

  final CommunityDetail detail;

  /// An open command is in flight, so the button must not start a second one.
  final bool opening;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenVoiceRoom;
  final VoidCallback onCreateVoiceRoom;

  @override
  Widget build(BuildContext context) {
    final chat = detail.chat;
    final voice = detail.voice;
    final chatOpenable = chat.isAvailable || chat.isSyncing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LoopRecordGroup(
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('community-profile-open-chat'),
              title: '社区官方群',
              subtitle: switch (chat.status) {
                CommunityChatStatus.available => '进入官方群',
                CommunityChatStatus.syncing => '聊天权限同步中',
                CommunityChatStatus.unavailable =>
                  communicationUnavailableReason(chat.reasonCode),
              },
              position: LoopRowPosition.first,
              onTap: chatOpenable ? onOpenChat : null,
            ),
            LoopRecordRow(
              key: const ValueKey<String>('community-profile-open-voice'),
              title: '语音房',
              subtitle: voice.isLive
                  ? '当前有进行中的语音房'
                  : communicationUnavailableReason(voice.reasonCode),
              trailing: voice.isLive ? '进入' : null,
              position: LoopRowPosition.last,
              onTap: voice.isLive ? onOpenVoiceRoom : null,
            ),
          ],
        ),
        // Only an owner or an admin may open a room, and only when none is
        // live. A member never sees the button; the server refuses it anyway.
        if (detail.viewer.mayOpenVoiceRoom && !voice.isLive)
          LoopButtonPair(
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>(
                  'community-profile-create-voice-room',
                ),
                label: '开启语音房',
                onPressed: opening ? null : onCreateVoiceRoom,
              ),
            ],
          ),
      ],
    );
  }
}
