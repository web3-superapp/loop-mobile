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
  transfer('转让所有者'),
  mute('禁言'),
  unmute('解除禁言'),
  ban('封禁'),
  unban('解除封禁');

  const CommunityGovernanceAction(this.label);

  final String label;

  /// Extra copy the second confirmation shows before the command runs.
  String get confirmationDetail => switch (this) {
    CommunityGovernanceAction.transfer =>
      '转让后你会变成普通成员，不能再编辑资料或执行治理动作。这一步不可撤销，只有新的所有者能把权限交还给你。',
    CommunityGovernanceAction.ban =>
      '被封禁的成员会离开官方频道，并从默认成员目录中移除；你之后可以在「已封禁」分段里解除封禁。封禁不改动个人关注关系。',
    CommunityGovernanceAction.unban =>
      '解除封禁会把该成员恢复为活跃成员，加入时间不变，并重新加回官方频道。对方不需要重新申请加入。',
    _ => '这次操作会记入社区日志。',
  };
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
  // A banned row has exactly one meaningful command: restore it.
  if (entry.status == CommunityMemberStatus.banned) {
    return <CommunityGovernanceAction>[
      if (viewer.canBan) CommunityGovernanceAction.unban,
    ];
  }
  return <CommunityGovernanceAction>[
    if (viewer.canInviteAdmin && entry.role == CommunityRole.member)
      CommunityGovernanceAction.promote,
    if (viewer.canInviteAdmin && entry.role == CommunityRole.admin)
      CommunityGovernanceAction.demote,
    // Only an owner is told it may appoint an admin, so only an owner is
    // offered the transfer.
    if (viewer.canInviteAdmin) CommunityGovernanceAction.transfer,
    if (viewer.canMute && entry.status != CommunityMemberStatus.muted)
      CommunityGovernanceAction.mute,
    if (viewer.canMute && entry.status == CommunityMemberStatus.muted)
      CommunityGovernanceAction.unmute,
    if (viewer.canBan) CommunityGovernanceAction.ban,
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
  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode();

  /// The field is revealed by the topbar control, as in the prototype; the
  /// directory itself is always the whole page.
  bool _searchOpen = false;

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _toggleSearch(CommunityMembersController controller) {
    final open = !_searchOpen;
    setState(() => _searchOpen = open);
    if (open) {
      _queryFocus.requestFocus();
      return;
    }
    _query.clear();
    unawaited(controller.clearSearch());
  }

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
      title: '成员',
      kicker: communityPreviewKicker(mode),
      onBack: widget.onBack,
      actions: <Widget>[
        LoopIconButton(
          key: const ValueKey<String>('community-members-search'),
          icon: _searchOpen ? 'close' : 'search',
          label: _searchOpen ? '关闭搜索' : '搜索成员',
          onPressed: () => _toggleSearch(controller),
        ),
      ],
      folio: LoopFolioPrimary(
        variant: LoopFolioVariant.chalk,
        archetype: LoopFolioArchetype.listing,
        kicker: 'MEMBER DIRECTORY',
        heading: counts == null ? communityMissingFigure : '${counts.all} 名成员',
        caption: 'Owner / Admin / 成员 三级权限。',
        stamp: counts == null ? null : '${counts.all}',
      ),
      filters: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: TextField(
                key: const ValueKey<String>('community-members-search-field'),
                controller: _query,
                focusNode: _queryFocus,
                textInputAction: TextInputAction.search,
                maxLength: memberSearchMaximumRunes,
                onChanged: controller.search,
                decoration: InputDecoration(
                  labelText: '按别名搜索成员',
                  hintText: '输入别名开头即可',
                  counterText: '',
                  suffixIcon: !state.isSearching
                      ? null
                      : IconButton(
                          key: const ValueKey<String>(
                            'community-members-search-clear',
                          ),
                          tooltip: '清除',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _query.clear();
                            unawaited(controller.clearSearch());
                            _queryFocus.requestFocus();
                          },
                        ),
                ),
              ),
            ),
          Padding(
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
                  // The governance view is only opened to a viewer the server
                  // told may ban, and it carries no count: `counts` stays the
                  // non-banned directory's.
                  if (state.viewer?.canBan ?? false)
                    _filterSeg(
                      controller,
                      state,
                      CommunityMemberFilter.banned,
                      '已封禁',
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
        ],
      ),
      block: id != null && communityCapabilityBlocks(mode, capability)
          ? CommunityCapabilityPageBlock(
              key: const ValueKey<String>(
                'community-members-capability-unavailable',
              ),
              capability: capability,
              title: '社区模块当前不可用',
            )
          : null,
      onRefresh: id == null ? null : controller.refresh,
      updating: state.refreshing,
      collection: ListView(
        key: const ValueKey<String>('community-members-list'),
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          CommunityPreviewNotice(mode: mode, resource: '成员目录'),
          if (counts != null)
            CommunityUnavailableCard(label: '在线人数', fact: counts.online),
          if (state.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            CommunityUnavailableCard(
              label: '成员算力',
              fact: state.items.first.miningPower,
            ),
          ],
          if (id == null)
            const LoopEmpty(
              key: ValueKey<String>('community-members-missing-id'),
              icon: 'warn',
              message: '缺少社区标识',
              reason: '请从社区档案进入，本页不会猜测要打开哪个社区。',
            )
          else if (state.phase != CommunityViewPhase.ready)
            CommunityStateBlock(
              phase: state.phase,
              failureKind: state.failureKind,
              emptyMessage: state.isSearching ? '没有匹配的成员' : '这个筛选下没有成员',
              emptyReason: state.isSearching
                  ? '别名要从开头对上才算匹配，换个开头再试。'
                  : '这个角色下没有成员。',
              permissionTitle: '没有权限查看成员目录',
              onRetry: () => unawaited(controller.reload()),
            )
          else ...<Widget>[
            // A search re-read keeps the rows it already read; the mark says a
            // newer answer is on the way instead of a skeleton hiding a page
            // that is still readable. Same widget, key and copy every other
            // community surface uses for this.
            if (state.refreshing)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: LoopUpdatingBadge(
                  key: ValueKey<String>('community-state-updating'),
                ),
              ),
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
                'Owner / Admin / 成员。这里只显示你有权限做的操作；'
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
      CommunityMemberStatus.muted => '已禁言',
      CommunityMemberStatus.banned => '已封禁',
    };
    final identity = entry.profile.publicProfileId ?? entry.profile.loopId;
    return LoopRecordRow(
      key: ValueKey<String>('member-row-$identity'),
      title: entry.isSelf
          ? '我 · ${entry.profile.displayName}'
          : entry.profile.displayName,
      // The role and the status are a state, not a figure, so they ride in the
      // badge and the subtitle keeps only the identity.
      subtitle: entry.profile.loopId,
      trailingBadge: LoopBadge(
        status,
        key: ValueKey<String>('member-badge-$identity'),
        kind: switch (entry.status) {
          CommunityMemberStatus.active =>
            entry.role == CommunityRole.member
                ? LoopBadgeKind.mute
                : LoopBadgeKind.mining,
          CommunityMemberStatus.muted => LoopBadgeKind.mute,
          CommunityMemberStatus.banned => LoopBadgeKind.down,
        },
      ),
      position: position,
      // The viewer's own row is never navigable. Every other row opens the
      // shared public-profile sheet, which carries the governance commands
      // the server has allowed for this viewer.
      onTap: entry.isSelf || state.busy
          ? null
          : () => unawaited(_openMemberSheet(entry, actions, controller)),
      semanticLabel: '${entry.profile.displayName}，${entry.role.label}，$status',
    );
  }

  Future<void> _openMemberSheet(
    CommunityMemberEntry entry,
    List<CommunityGovernanceAction> actions,
    CommunityMembersController controller,
  ) async {
    final chosen = await showPublicProfileSheet<CommunityGovernanceAction>(
      context,
      identity: PublicProfileIdentity.fromProfile(entry.profile),
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
          '${chosen.confirmationDetail}',
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
      CommunityGovernanceAction.transfer => await controller.changeRole(
        publicProfileId: target,
        role: CommunityRole.owner,
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
