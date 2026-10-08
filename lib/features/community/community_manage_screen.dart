import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_models.dart';
import 'package:loop_mobile/features/chat/v2/chat_v2_controllers.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_voice_room_open.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/qr/loop_qr_card.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_blocks.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The Owner / Admin head count the 成员 row prints, read once per visit
/// from the members directory's own counts (`GET …/members`).
final communityManageCountsProvider = FutureProvider.autoDispose
    .family<CommunityMemberCounts, String>((ref, communityId) async {
      final directory = await ref
          .read(communityGatewayProvider)
          .listMembers(communityId);
      return directory.counts;
    });

/// `community-manage` · action / dashboard (decision 0113, S109b §3.4).
///
/// Everything an owner or an admin does to a community, in one place: its
/// profile (and, for the owner alone, its bound token), its members, its
/// voice room, its announcements, its card and — for the owner — its
/// ownership. The record (`community-profile`) keeps reading; this page is
/// where it is changed. Every write is still the server's to admit: the role
/// only decides what is offered.
///
/// It reads the same record the community page reads (one controller, one
/// answer), so arriving from the record costs no second request.
class CommunityManageScreen extends ConsumerStatefulWidget {
  const CommunityManageScreen({
    required this.communityId,
    super.key,
    this.onBack,
  });

  final String? communityId;
  final VoidCallback? onBack;

  @override
  ConsumerState<CommunityManageScreen> createState() =>
      _CommunityManageScreenState();
}

class _CommunityManageScreenState extends ConsumerState<CommunityManageScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final state = ref.watch(communityProfileControllerProvider);
    final controller = ref.read(communityProfileControllerProvider.notifier);
    // Held so an opening started here outlives the confirm sheet.
    final opening = ref.watch(voiceRoomOpenControllerProvider);
    final id = widget.communityId;
    final blocked = communityCapabilityBlocks(mode, capability);
    final shown = state.value;
    if (!blocked &&
        id != null &&
        (state.phase == CommunityViewPhase.loading ||
            (shown != null && shown.community.communityId != id))) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(id));
      });
    }
    final detail = shown != null && shown.community.communityId == id
        ? shown
        : null;
    final viewer = detail?.viewer;
    final isOwner = viewer?.isOwner ?? false;
    return LoopDashboardPage(
      key: const ValueKey<String>('community-manage-screen'),
      archetype: LoopPageArchetype.action,
      title: '社区管理',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      primary: LoopFolioPrimary(
        variant: LoopFolioVariant.quiet,
        archetype: LoopFolioArchetype.action,
        kicker: 'MANAGE',
        heading: detail?.community.name ?? communityMissingName,
        caption: '资料、成员、语音房、公告、分享与所有权。这里的每一项修改都由服务端确认。',
        stamp: viewer?.membership?.role.label,
      ),
      block: id != null && blocked
          ? CommunityCapabilityPageBlock(
              key: const ValueKey<String>(
                'community-manage-capability-unavailable',
              ),
              capability: capability,
              title: '社区模块当前不可用',
            )
          : null,
      onRefresh: id == null ? null : controller.reload,
      updating: state.refreshing || state.busy || opening,
      sections: <Widget>[
        CommunityPreviewNotice(mode: mode, resource: '社区管理'),
        if (id == null)
          const LoopEmpty(
            key: ValueKey<String>('community-manage-missing-id'),
            icon: 'warn',
            message: '缺少社区标识',
            reason: '请从社区主页右上角的「管理」进入，本页不会猜测要管理哪个社区。',
          )
        else if (detail == null)
          CommunityStateBlock(
            phase: state.phase == CommunityViewPhase.ready
                ? CommunityViewPhase.loading
                : state.phase,
            failureKind: state.failureKind,
            skeleton: LoopSkeletonType.list,
            emptyMessage: '找不到这个社区',
            emptyReason: '它可能已被移除，或对当前账号不可见。',
            onRetry: () => unawaited(controller.reload()),
          )
        else if (!detail.viewer.mayManage)
          const LoopEmpty(
            key: ValueKey<String>('community-manage-permission'),
            icon: 'lock',
            message: '只有社区所有者与管理员可以管理',
            reason: '你在这个社区的身份不包含管理权限；社区主页仍然可以照常查看。',
          )
        else
          ..._groups(context, detail, isOwner: isOwner, busy: state.busy),
      ],
    );
  }

  List<Widget> _groups(
    BuildContext context,
    CommunityDetail detail, {
    required bool isOwner,
    required bool busy,
  }) {
    final community = detail.community;
    final id = community.communityId;
    final counts = ref.watch(communityManageCountsProvider(id));
    return <Widget>[
      // 资料
      const LoopLabel('资料'),
      LoopRecordGroup(
        key: const ValueKey<String>('community-manage-profile-group'),
        rows: <LoopRecordRow>[
          LoopRecordRow(
            key: const ValueKey<String>('community-manage-edit-profile'),
            leading: CommunityLogo(
              identity: id,
              name: community.name,
              logoRef: community.logoRef,
              size: 36,
            ),
            title: '名称与简介',
            subtitle: community.description == null
                ? '${community.name} · 还没有简介'
                : '${community.name} · ${community.description}',
            onTap: busy
                ? null
                : () =>
                      unawaited(_editProfile(detail, includeBoundAsset: false)),
          ),
          if (isOwner)
            LoopRecordRow(
              key: const ValueKey<String>('community-manage-bound-asset'),
              leading: const LoopRowIcon(icon: 'wallet'),
              title: '绑定代币',
              subtitle: _boundAssetLine(community),
              trailingBadge: const LoopBadge('仅所有者'),
              onTap: busy
                  ? null
                  : () => unawaited(
                      _editProfile(detail, includeBoundAsset: true),
                    ),
            ),
        ],
      ),
      if (isOwner &&
          community.boundAsset != null &&
          !community.boundAsset!.hasRegisteredPool)
        const LoopNotice(
          key: ValueKey<String>('community-manage-no-pool'),
          icon: 'warn',
          tone: LoopNoticeTone.warn,
          body: '尚无已注册池子，群友买入动态不会出现。',
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          '社区图标暂不能在这里更换；短链接与验证状态不能修改。',
          key: const ValueKey<String>('community-manage-logo-note'),
          style: LoopTypography.caption(11),
        ),
      ),
      // 成员
      const LoopLabel('成员'),
      LoopRecordGroup(
        key: const ValueKey<String>('community-manage-members-group'),
        rows: <LoopRecordRow>[
          LoopRecordRow(
            key: const ValueKey<String>('community-manage-members'),
            leading: const LoopRowIcon(icon: 'users'),
            title: '成员与权限',
            subtitle: switch (counts) {
              AsyncData(:final value) =>
                'Owner ${value.owner} · Admin ${value.admin} · 共 ${value.all} 人',
              AsyncError() => '${community.memberCount} 位成员 · 角色计数暂时读不到',
              _ => '${community.memberCount} 位成员 · 正在读取角色计数',
            },
            onTap: () => unawaited(
              context.push<void>(
                '/community/members?id=${Uri.encodeQueryComponent(id)}',
              ),
            ),
          ),
        ],
      ),
      // 语音房
      const LoopLabel('语音房'),
      LoopRecordGroup(
        key: const ValueKey<String>('community-manage-voice-group'),
        rows: <LoopRecordRow>[
          if (detail.voice.isLive)
            LoopRecordRow(
              key: const ValueKey<String>('community-manage-voice-enter'),
              leading: const LoopRowIcon(icon: 'voice'),
              title: '进入语音房',
              subtitle: '社区正在开播',
              onTap: () => unawaited(
                context.push<void>(
                  '/chat/voice?id=${Uri.encodeQueryComponent(id)}',
                ),
              ),
            )
          else
            LoopRecordRow(
              key: const ValueKey<String>('community-manage-voice-open'),
              leading: const LoopRowIcon(icon: 'mic'),
              title: '开启语音房',
              subtitle: '你是主持人，麦克风默认关闭',
              onTap: ref.watch(voiceRoomOpenControllerProvider)
                  ? null
                  : () => unawaited(
                      openCommunityVoiceRoom(
                        context,
                        ref,
                        detail,
                        onOpened: (communityId) => unawaited(
                          context.push<void>(
                            '/chat/voice?id='
                            '${Uri.encodeQueryComponent(communityId)}',
                          ),
                        ),
                      ),
                    ),
            ),
        ],
      ),
      // 公告
      const LoopLabel('公告'),
      const LoopNotice(
        key: ValueKey<String>('community-manage-announcements'),
        icon: 'news',
        title: '公告发布',
        body: '公告发布随运营后台开放；在那之前，这里不提供发布入口。',
      ),
      // 分享
      const LoopLabel('分享'),
      LoopRecordGroup(
        key: const ValueKey<String>('community-manage-share-group'),
        rows: <LoopRecordRow>[
          LoopRecordRow(
            key: const ValueKey<String>('community-manage-share'),
            leading: const LoopRowIcon(icon: 'share'),
            title: '社区二维码名片',
            subtitle: '分享海报或复制社区链接',
            onTap: () => unawaited(
              showLoopQrCardSheet(
                context,
                LoopCommunityQrCard(
                  communityId: id,
                  name: community.name,
                  memberCount: community.memberCount,
                  logoRef: community.logoRef,
                  description: community.description,
                ),
              ),
            ),
          ),
        ],
      ),
      // 所有权
      if (isOwner) ...<Widget>[
        const LoopLabel('所有权'),
        LoopRecordGroup(
          key: const ValueKey<String>('community-manage-ownership-group'),
          rows: <LoopRecordRow>[
            LoopRecordRow(
              key: const ValueKey<String>('community-manage-transfer'),
              leading: const LoopRowIcon(icon: 'crown'),
              title: '转让所有者',
              subtitle: '在成员页对某位成员执行「转让所有者」，你会降为 Admin',
              onTap: () => unawaited(
                context.push<void>(
                  '/community/members?id=${Uri.encodeQueryComponent(id)}',
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Text(
            '解散社区不提供。',
            key: const ValueKey<String>('community-manage-no-dissolve'),
            style: LoopTypography.caption(11),
          ),
        ),
      ],
      const SizedBox(height: 24),
    ];
  }

  String _boundAssetLine(CommunitySummary community) {
    final key = community.boundAssetKey;
    if (key == null) return '未绑定';
    final asset = community.boundAsset;
    if (asset == null) {
      // An API that predates the `boundAsset` block: the key is all there is.
      return '${loopTruncatedAddress(key.split(':').last)} · 代币信息暂时读不到';
    }
    final name = asset.name;
    final pool = asset.hasRegisteredPool ? '已有注册池子' : '尚无注册池子';
    return name == null || name == asset.symbol
        ? '${asset.symbol} · $pool'
        : '${asset.symbol} · $name · $pool';
  }

  Future<void> _editProfile(
    CommunityDetail detail, {
    required bool includeBoundAsset,
  }) async {
    final controller = ref.read(communityProfileControllerProvider.notifier);
    final edit = await showCommunityProfileEditSheet(
      context,
      community: detail.community,
      // Decision 0113: the bound token is the owner's field alone.
      includeBoundAsset: includeBoundAsset && detail.viewer.isOwner,
    );
    if (edit == null || !mounted) return;
    if (edit.isEmpty) {
      LoopToast.show(context, message: '没有修改任何内容');
      return;
    }
    final confirmed = await confirmCommunityAction(
      context,
      title: '提交社区资料修改？',
      body: edit.touchesBoundAsset
          ? '绑定代币会立刻影响社区页的代币卡片与群友买入动态。短链接与验证状态不能在这里修改。'
          : '短链接与验证状态不能在这里修改。',
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
      message: switch (failure) {
        CommunityFailureKind.validationFailed when edit.touchesBoundAsset =>
          '这个代币还没有在 LOOP 登记，不能绑定；资料没有修改。',
        CommunityFailureKind.permissionDenied when edit.touchesBoundAsset =>
          '只有社区所有者可以修改绑定代币；资料没有修改。',
        _ => communityFailureReason(failure),
      },
      kind: LoopToastKind.err,
    );
  }
}
