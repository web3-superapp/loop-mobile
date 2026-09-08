import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/social/public_profile_sheet.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// One governance command offered on a member row.
enum CommunityGovernanceAction {
  promote('任命为 Admin'),
  demote('撤销 Admin'),
  mute('禁言'),
  unmute('解除禁言'),
  ban('封禁'),
  unban('解除封禁');

  const CommunityGovernanceAction(this.label);

  final String label;
}

/// The commands the server has told this viewer it may run against this row.
///
/// This is visibility only: the permission matrix itself lives on the server
/// and decides the outcome. The client adds no rule of its own beyond the
/// facts the response already states.
List<CommunityGovernanceAction> communityGovernanceActions(
  CommunityViewer? viewer,
  CommunityMemberEntry entry,
) {
  if (viewer == null || !entry.isActionable) {
    return const <CommunityGovernanceAction>[];
  }
  // The owner can never be the target of a governance action.
  if (entry.role == CommunityRole.owner) {
    return const <CommunityGovernanceAction>[];
  }
  return <CommunityGovernanceAction>[
    if (viewer.canInviteAdmin && entry.role == CommunityRole.member)
      CommunityGovernanceAction.promote,
    if (viewer.canInviteAdmin && entry.role == CommunityRole.admin)
      CommunityGovernanceAction.demote,
    if (viewer.canMute && entry.status != CommunityMemberStatus.muted)
      CommunityGovernanceAction.mute,
    if (viewer.canMute && entry.status == CommunityMemberStatus.muted)
      CommunityGovernanceAction.unmute,
    if (viewer.canBan && entry.status != CommunityMemberStatus.banned)
      CommunityGovernanceAction.ban,
    if (viewer.canBan && entry.status == CommunityMemberStatus.banned)
      CommunityGovernanceAction.unban,
  ];
}

/// `community-members` · grouped directory and governance.
///
/// Action visibility comes only from the server's `viewer` flags plus the
/// row's own facts (`isSelf`, a present `publicProfileId`, current role and
/// status). The permission matrix itself is never re-implemented here.
class CommunityMembersScreen extends ConsumerStatefulWidget {
  const CommunityMembersScreen({
    required this.communityId,
    super.key,
    this.onBack,
  });

  final String? communityId;
  final VoidCallback? onBack;

  @override
  ConsumerState<CommunityMembersScreen> createState() =>
      _CommunityMembersScreenState();
}

class _CommunityMembersScreenState
    extends ConsumerState<CommunityMembersScreen> {
  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final state = ref.watch(communityMembersControllerProvider);
    final controller = ref.read(communityMembersControllerProvider.notifier);
    final id = widget.communityId;
    if (!communityCapabilityBlocks(mode, capability) &&
        id != null &&
        state.phase == CommunityViewPhase.loading) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.open(id));
      });
    }

    final counts = state.counts;
    return LoopStreamPage(
      key: const ValueKey<String>('community-members-screen'),
      archetype: LoopPageArchetype.listing,
      title: '成员与权限',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      folio: LoopFolioPrimary(
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.listing,
        kicker: 'MEMBER DIRECTORY',
        heading: counts == null ? communityMissingFigure : '${counts.all} 名成员',
        caption: 'Owner / Admin / 成员 三级权限。计数与排序都来自服务端。',
        stamp: counts == null ? null : '${counts.all}',
      ),
      filters: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              _filterSeg(
                controller,
                state,
                CommunityMemberFilter.all,
                counts == null ? '全部' : '全部 ${counts.all}',
              ),
              _filterSeg(
                controller,
                state,
                CommunityMemberFilter.owner,
                counts == null ? 'Owner' : 'Owner ${counts.owner}',
              ),
              _filterSeg(
                controller,
                state,
                CommunityMemberFilter.admin,
                counts == null ? 'Admin' : 'Admin ${counts.admin}',
              ),
              // Presence has no source; the segment stays disabled with its
              // server reason rather than showing a fabricated online count.
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: LoopSeg(
                  key: ValueKey<String>('members-seg-online'),
                  label: '在线',
                  selected: false,
                  onSelected: null,
                ),
              ),
            ],
          ),
        ),
      ),
      collection: ListView(
        key: const ValueKey<String>('community-members-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          CommunityPreviewNotice(mode: mode, resource: '成员目录'),
          if (counts != null)
            CommunityUnavailableCard(label: '在线人数', fact: counts.online),
          if (id == null)
            const LoopEmpty(
              key: ValueKey<String>('community-members-missing-id'),
              icon: 'warn',
              message: '缺少社区标识',
              reason: '请从社区档案进入，本页不会猜测要打开哪个社区。',
            )
          else if (communityCapabilityBlocks(mode, capability))
            LoopEmpty(
              key: const ValueKey<String>(
                'community-members-capability-unavailable',
              ),
              icon: 'warn',
              message: '社区模块当前不可用',
              reason: capability.reasonCode == null
                  ? '尚未读取到能力清单，本页不请求成员目录。'
                  : '服务端原因：${capability.reasonCode}。',
            )
          else if (state.phase != CommunityViewPhase.ready)
            CommunityStateBlock(
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: '这个筛选下没有成员',
              emptyReason: '服务端没有返回符合该角色的成员。',
              permissionTitle: '没有权限查看成员目录',
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            if (state.failureKind != null)
              LoopNotice(
                key: const ValueKey<String>('community-members-action-failure'),
                icon: 'warn',
                tone: LoopNoticeTone.warn,
                title: '上一次操作没有完成',
                body: communityFailureReason(state.failureKind),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              ),
            for (final group in _groups(state.items)) ...<Widget>[
              LoopLabel(group.$1),
              LoopRecordGroup(
                rows: <LoopRecordRow>[
                  for (var index = 0; index < group.$2.length; index += 1)
                    _memberRow(
                      entry: group.$2[index],
                      position: communityRowPosition(index, group.$2.length),
                      state: state,
                      controller: controller,
                    ),
                ],
              ),
            ],
            if (state.nextCursor != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LoopButton(
                  key: const ValueKey<String>('community-members-load-more'),
                  label: state.loadingMore ? '正在载入…' : '载入更多',
                  block: true,
                  onPressed: state.loadingMore
                      ? null
                      : () => unawaited(controller.loadMore()),
                ),
              ),
          ],
          const LoopNotice(
            key: ValueKey<String>('community-members-rules'),
            icon: 'info',
            title: '三级权限',
            body:
                'Owner / Admin / 成员。所有治理动作由服务端判定，本页只按服务端返回的权限显示入口；'
                '禁言只影响聊天，不影响治理权限。',
            margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
          ),
        ],
      ),
    );
  }

  Widget _filterSeg(
    CommunityMembersController controller,
    CommunityMembersState state,
    CommunityMemberFilter filter,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: LoopSeg(
        key: ValueKey<String>('members-seg-${filter.wireName}'),
        label: label,
        selected: state.filter == filter,
        onSelected: () => unawaited(controller.selectFilter(filter)),
      ),
    );
  }

  static List<(String, List<CommunityMemberEntry>)> _groups(
    List<CommunityMemberEntry> items,
  ) {
    final groups = <(String, List<CommunityMemberEntry>)>[];
    for (final role in CommunityRole.values) {
      final rows = <CommunityMemberEntry>[
        for (final entry in items)
          if (entry.role == role) entry,
      ];
      if (rows.isNotEmpty) groups.add((role.label, rows));
    }
    return groups;
  }

  LoopRecordRow _memberRow({
    required CommunityMemberEntry entry,
    required LoopRowPosition position,
    required CommunityMembersState state,
    required CommunityMembersController controller,
  }) {
    final actions = communityGovernanceActions(state.viewer, entry);
    final status = switch (entry.status) {
      CommunityMemberStatus.active => entry.role.label,
      CommunityMemberStatus.muted => '${entry.role.label} · 已禁言',
      CommunityMemberStatus.banned => '${entry.role.label} · 已封禁',
    };
    final identity = entry.profile.publicProfileId ?? entry.profile.loopId;
    return LoopRecordRow(
      key: ValueKey<String>('member-row-$identity'),
      title: entry.isSelf
          ? '我 · ${entry.profile.displayName}'
          : entry.profile.displayName,
      subtitle: '${entry.profile.loopId} · $status',
      trailing: entry.role.label,
      position: position,
      // The viewer's own row is never navigable, and a member without a
      // profile row can never be a command target.
      // The viewer's own row is never navigable. Every other row opens the
      // shared public-profile sheet, which carries the governance commands
      // the server has allowed for this viewer.
      onTap: entry.isSelf || state.busy
          ? null
          : () => unawaited(_openMemberSheet(entry, actions, controller)),
      semanticLabel: '${entry.profile.displayName}，$status',
    );
  }

  Future<void> _openMemberSheet(
    CommunityMemberEntry entry,
    List<CommunityGovernanceAction> actions,
    CommunityMembersController controller,
  ) async {
    final chosen = await showPublicProfileSheet<CommunityGovernanceAction>(
      context,
      profile: entry.profile,
      actions: <PublicProfileSheetAction<CommunityGovernanceAction>>[
        for (final action in actions)
          PublicProfileSheetAction<CommunityGovernanceAction>(
            id: action.name,
            label: action.label,
            value: action,
          ),
      ],
    );
    if (chosen == null || !mounted) return;
    final confirmed = await confirmCommunityAction(
      context,
      title: '${chosen.label}？',
      body:
          '目标：${entry.profile.displayName}（${entry.profile.loopId}）。'
          '结果由服务端判定，本次操作会写入社区审计。',
      confirmLabel: chosen.label,
      sheetKey: 'member-confirm-sheet',
    );
    if (!confirmed) return;
    final target = entry.profile.publicProfileId;
    if (target == null) return;
    final failure = switch (chosen) {
      CommunityGovernanceAction.promote => await controller.changeRole(
        publicProfileId: target,
        role: CommunityRole.admin,
      ),
      CommunityGovernanceAction.demote => await controller.changeRole(
        publicProfileId: target,
        role: CommunityRole.member,
      ),
      CommunityGovernanceAction.mute => await controller.setMuted(
        publicProfileId: target,
        muted: true,
      ),
      CommunityGovernanceAction.unmute => await controller.setMuted(
        publicProfileId: target,
        muted: false,
      ),
      CommunityGovernanceAction.ban => await controller.setBanned(
        publicProfileId: target,
        banned: true,
      ),
      CommunityGovernanceAction.unban => await controller.setBanned(
        publicProfileId: target,
        banned: false,
      ),
    };
    if (!mounted) return;
    if (failure == null) {
      // Only a 2xx reaches this line.
      LoopToast.show(context, message: '${chosen.label}已生效');
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
  }
}
