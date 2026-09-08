import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

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
  });

  final String? communityId;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenMembers;

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
      title: community?.name ?? communityMissingFigure,
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
        heading: community?.name ?? communityMissingFigure,
        caption: community == null
            ? '社区档案尚未读取成功，本页不展示任何推测数字。'
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
      sections: <Widget>[
        CommunityPreviewNotice(mode: mode, resource: '社区档案'),
        if (id == null)
          const LoopEmpty(
            key: ValueKey<String>('community-profile-missing-id'),
            icon: 'warn',
            message: '缺少社区标识',
            reason: '请从社区列表或搜索结果进入，本页不会猜测要打开哪个社区。',
          )
        else if (communityCapabilityBlocks(mode, capability))
          LoopEmpty(
            key: const ValueKey<String>(
              'community-profile-capability-unavailable',
            ),
            icon: 'warn',
            message: '社区模块当前不可用',
            reason: capability.reasonCode == null
                ? '尚未读取到能力清单，本页不请求社区档案。'
                : '服务端原因：${capability.reasonCode}。',
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
          const LoopLabel('在线'),
          CommunityUnavailableCard(label: '在线人数', fact: detail.onlineCount),
          const LoopLabel('社区币'),
          if (!detail.community.hasBoundAsset)
            const LoopEmpty(
              key: ValueKey<String>('community-profile-no-asset'),
              message: '未绑定资产',
              reason: '该社区没有绑定合约地址，因此不展示任何代币卡片或市场数字。',
            )
          else
            _BoundAssetCard(assetKey: detail.community.boundAssetKey!),
          const LoopLabel('挖矿'),
          CommunityUnavailableCard(
            label: 'Mining Power',
            fact: detail.miningPower,
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
      body: '短链接与验证状态不能通过本接口修改。是否接受由服务端判定。',
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

  Future<void> _changeMembership(
    CommunityProfileController controller, {
    required bool joined,
  }) async {
    final confirmed = await confirmCommunityAction(
      context,
      title: joined ? '加入这个社区？' : '退出这个社区？',
      body: joined
          ? '加入后你会出现在成员目录里。是否继续由服务端判定。'
          : '退出后你将从成员目录中移除。社区所有者需要先转让所有权才能退出。',
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
                        style: LoopTypography.sora(
                          size: 17,
                          weight: FontWeight.w700,
                        ),
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
                const SizedBox(height: 4),
                Text(
                  community.slug,
                  style: LoopTypography.mono(
                    size: 11.5,
                    color: LoopColors.muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  community.description ?? '这个社区还没有填写简介。',
                  style: LoopTypography.sora(
                    size: 12.5,
                    weight: FontWeight.w500,
                    color: LoopColors.muted,
                    height: 1.6,
                  ),
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
          const LoopNotice(
            key: ValueKey<String>('community-owner-cannot-leave'),
            icon: 'info',
            title: '所有者不能直接退出',
            body: '需要先把所有权转让给另一名成员，服务端才会接受退出请求。',
            margin: EdgeInsets.fromLTRB(16, 0, 16, 14),
          ),
      ],
    );
  }
}

class _BoundAssetCard extends StatelessWidget {
  const _BoundAssetCard({required this.assetKey});

  final String assetKey;

  @override
  Widget build(BuildContext context) {
    return LoopSurfaceCard(
      key: const ValueKey<String>('community-bound-asset'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'BOUND ASSET',
            style: LoopTypography.mono(
              size: 9.5,
              weight: FontWeight.w600,
              color: LoopColors.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(assetKey, style: LoopTypography.mono(size: 12)),
          const SizedBox(height: 10),
          Text(
            '该地址由社区所有者登记，服务端尚未解析。价格、市值、流动性与持有人均无来源，'
            '本页不展示任何市场数字。',
            style: LoopTypography.sora(
              size: 12,
              weight: FontWeight.w500,
              color: LoopColors.muted,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
