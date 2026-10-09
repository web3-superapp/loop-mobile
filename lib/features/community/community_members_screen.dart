import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/features/profile/profile_v2_screens.dart';
import 'package:loop_mobile/features/social/public_profile_sheet.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The UI copy for one server-published governance command.
///
/// Only the copy lives here. Whether a row offers the command is
/// `CommunityMemberEntry.actions`, which the server computes from its
/// permission matrix; this file states no rule about who may do what.
extension CommunityGovernanceActionCopy on CommunityGovernanceAction {
  String get label => switch (this) {
    CommunityGovernanceAction.promote => '任命为 Admin',
    CommunityGovernanceAction.demote => '撤销 Admin',
    CommunityGovernanceAction.transfer => '转让所有者',
    CommunityGovernanceAction.mute => '禁言',
    CommunityGovernanceAction.unmute => '解除禁言',
    CommunityGovernanceAction.ban => '封禁',
    CommunityGovernanceAction.unban => '解除封禁',
  };

  /// Extra copy the second confirmation shows before the command runs.
  ///
  /// The transfer sentence states the role the server actually leaves the
  /// previous owner in: the write path demotes them to `admin` in the same
  /// transaction, not to a plain member. An Admin keeps mute and ban over
  /// members and loses the owner-only rights — editing the community
  /// profile, assigning or revoking Admin, and transferring again.
  String get confirmationDetail => switch (this) {
    CommunityGovernanceAction.transfer =>
      '转让后你会降为 Admin：编辑社区资料、任免 Admin 和再次转让都归新的所有者，你仍可禁言、封禁普通成员。'
          '这一步不可撤销，只有新的所有者能把权限交还给你。',
    CommunityGovernanceAction.ban =>
      '被封禁的成员会离开官方频道，并从默认成员目录中移除；你之后可以在「已封禁」分段里解除封禁。封禁不改动个人关注关系。',
    CommunityGovernanceAction.unban =>
      '解除封禁会把该成员恢复为活跃成员，加入时间不变，并重新加回官方频道。对方不需要重新申请加入。',
    _ => '这次操作会记入社区日志。',
  };
}

/// `community-members` · grouped directory and governance.
///
/// Every row renders exactly the commands the server published in
/// `items[].actions`. The permission matrix is not re-implemented here, and
/// no row action is derived from the viewer-level flags: those carry no
/// target, so deriving from them offered an admin a mute and a ban against
/// another admin that the server had always refused.
class CommunityMembersScreen extends ConsumerStatefulWidget {
  const CommunityMembersScreen({
    required this.communityId,
    super.key,
    this.onBack,
    this.onOpenDirectMessage,
    this.onOpenProfile,
  });

  final String? communityId;
  final VoidCallback? onBack;

  /// Opens the direct conversation with the member whose card is open.
  ///
  /// `#scr-community-members` makes every member row a `dm` entry. The row
  /// opens the shared public-profile card instead, and the card carries the
  /// control; the route stays with the shell, which owns every destination.
  final PublicProfileDirectMessageHandler? onOpenDirectMessage;

  /// Opens `user-profile` (decision 0112). A row the viewer may govern still
  /// opens the sheet, which carries the commands and a way to the page.
  final ValueChanged<String>? onOpenProfile;

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
    // `counts` is the whole directory's, not this search's: the server counts
    // members by role, never matches for a prefix. While the page is narrowed
    // by a query the totals therefore describe rows that are not on screen —
    // "2 名成员" over "没有匹配的成员" — so the search state states its subject
    // instead of a figure, and the role chips drop the numbers they cannot
    // stand behind. Clearing the field brings both back unchanged.
    final searching = state.isSearching;
    // While the soft keyboard is up the page has roughly a third of its
    // height left, and the pinned folio plus the two standing notices took
    // all of it: the matches were laid out under the keyboard with no room
    // left to scroll them back into view. Typing therefore folds away
    // everything that is not the field, the chips and the matches; dismissing
    // the keyboard brings all of it back unchanged.
    //
    // The fold is a collapse, never a `folio: null`. Dropping the folio
    // changes which layout `LoopStreamPage` builds, and the field — which is
    // below it — is then rebuilt at a new place in the element tree on the
    // very frame the keyboard opens. It lost focus there, the keyboard closed,
    // the page unfolded, and the field came back empty and unfocused: on the
    // device the keyboard never stayed up and not one character could be typed
    // (R3-3).
    final typing = _searchOpen && MediaQuery.viewInsetsOf(context).bottom > 0;
    // The page is titled 成员 and every row on it is a person: without the
    // community's own face nothing here says whose directory this is.
    final community = state.community;
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
                  suffixIcon: !searching
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
                    counts == null || searching ? '全部' : '全部 ${counts.all}',
                  ),
                  _filterSeg(
                    controller,
                    state,
                    CommunityMemberFilter.owner,
                    counts == null || searching
                        ? 'Owner'
                        : 'Owner ${counts.owner}',
                  ),
                  _filterSeg(
                    controller,
                    state,
                    CommunityMemberFilter.admin,
                    counts == null || searching
                        ? 'Admin'
                        : 'Admin ${counts.admin}',
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
                  // A tap answers with that reason instead of nothing.
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: LoopSeg(
                      key: const ValueKey<String>('members-seg-online'),
                      quiet: true,
                      label: '在线',
                      selected: false,
                      onSelected: null,
                      onBlocked: () => LoopToast.show(
                        context,
                        message: memberDirectoryPresenceNote,
                        kind: LoopToastKind.warn,
                      ),
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
          // Decision 0127: whose directory this is — the community's face and
          // name in one row — instead of a hero card with an English eyebrow.
          if (community != null && !typing)
            LoopPersonRow(
              key: const ValueKey<String>('community-members-owner-row'),
              leading: CommunityLogo(
                key: const ValueKey<String>('community-members-logo'),
                identity: community.communityId,
                name: community.name,
                logoRef: community.logoRef,
                size: 40,
                radius: 12,
              ),
              title: community.name,
              subtitle: searching
                  ? '搜索成员'
                  : counts == null
                  ? null
                  : _directoryHeading(state.filter, counts),
            ),
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
              emptyMessage: searching ? '没有匹配的成员' : '这个筛选下没有成员',
              emptyReason: searching
                  ? '别名要从开头对上才算匹配，换个开头再试。'
                  : _emptyFilterReason(state.filter),
              permissionTitle: '没有权限查看成员目录',
              empty: LoopEmptyState(
                key: const ValueKey<String>('community-state-empty'),
                illustration: LoopIllustration.members,
                title: searching ? '没有匹配的成员' : '这个筛选下没有成员',
                message: searching
                    ? '别名要从开头对上才算匹配，换个开头再试。'
                    : _emptyFilterReason(state.filter),
              ),
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
              for (final entry in group.$2)
                _memberRow(entry: entry, state: state, controller: controller),
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
            // The end of the directory draws nothing (decision 0127).
          ],
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
        quiet: true,
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

  /// One OKX row (decision 0127): the face at 36, the name with the role
  /// as a small mark, the LOOP ID under it, and 「管理」 on the right when the
  /// server published a command for this row.
  Widget _memberRow({
    required CommunityMemberEntry entry,
    required CommunityMembersState state,
    required CommunityMembersController controller,
  }) {
    final status = switch (entry.status) {
      CommunityMemberStatus.active => entry.role.label,
      CommunityMemberStatus.muted => '已禁言',
      CommunityMemberStatus.banned => '已封禁',
    };
    final identity = entry.profile.publicProfileId ?? entry.profile.loopId;
    final governs =
        entry.status == CommunityMemberStatus.active &&
        entry.role != CommunityRole.member;
    // The viewer's own row is never navigable. A row the viewer may govern
    // opens the shared public-profile sheet, which carries the commands the
    // server allowed; any other row opens the member's page.
    final VoidCallback? open = entry.isSelf || state.busy
        ? null
        : entry.actions.isEmpty &&
              widget.onOpenProfile != null &&
              entry.profile.publicProfileId != null
        ? () => widget.onOpenProfile!(entry.profile.publicProfileId!)
        : () => unawaited(_openMemberSheet(entry, controller));
    return LoopPersonRow(
      key: ValueKey<String>('member-row-$identity'),
      height: 60,
      leading: LoopProfileAvatar(
        avatarRef: entry.profile.avatarRef,
        alias: entry.profile.displayName,
        size: 36,
      ),
      title: entry.isSelf
          ? '我 · ${entry.profile.displayName}'
          : entry.profile.displayName,
      // A member with no alias already carries the LOOP ID as the title, so
      // the grey line says when the member joined instead of repeating it.
      subtitle: entry.profile.alias == null
          ? '加入于 ${communityObservedAtLabel(entry.joinedAt)}'
          : entry.profile.loopId,
      tag:
          entry.role == CommunityRole.member &&
              entry.status == CommunityMemberStatus.active
          ? null
          : LoopTag(
              status,
              key: ValueKey<String>('member-badge-$identity'),
              lime: governs,
            ),
      trailing: entry.actions.isEmpty || entry.isSelf
          ? null
          : LoopPillAction(
              key: ValueKey<String>('member-manage-$identity'),
              label: '管理',
              primary: false,
              onPressed: open,
            ),
      onTap: open,
      semanticLabel: '${entry.profile.displayName}，${entry.role.label}，$status',
    );
  }

  Future<void> _openMemberSheet(
    CommunityMemberEntry entry,
    CommunityMembersController controller,
  ) async {
    final chosen = await showPublicProfileSheet<CommunityGovernanceAction>(
      context,
      identity: PublicProfileIdentity.fromProfile(
        entry.profile,
        isSelf: entry.isSelf,
      ),
      onOpenDirectMessage: widget.onOpenDirectMessage,
      onOpenProfile: widget.onOpenProfile,
      // Exactly the server's list for this row, in the server's order.
      actions: <PublicProfileSheetAction<CommunityGovernanceAction>>[
        for (final action in entry.actions)
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

/// The hero over the member directory.
///
/// `counts` is the whole directory's: the server counts members by role and
/// never counts the rows this page loaded, nor the governance view at all. So
/// a role filter heads itself with the figure the server counted for that
/// role, and 已封禁 heads itself with no figure — 「311 名成员」 over seven
/// banned rows was the directory's number on a page that was not showing the
/// directory.
String _directoryHeading(
  CommunityMemberFilter filter,
  CommunityMemberCounts? counts,
) => switch (filter) {
  CommunityMemberFilter.all =>
    counts == null ? communityMissingHeading : '${counts.all} 名成员',
  CommunityMemberFilter.owner =>
    counts == null ? 'Owner 权限' : '${counts.owner} 名 Owner',
  CommunityMemberFilter.admin =>
    counts == null ? 'Admin 权限' : '${counts.admin} 名 Admin',
  CommunityMemberFilter.banned => '已封禁的成员',
};

/// Why a filter came back with no rows. 已封禁 is a status the server keeps on
/// a membership, not one of the three roles, and the empty state said 「这个角色
/// 下没有成员」 over it.
String _emptyFilterReason(CommunityMemberFilter filter) => switch (filter) {
  CommunityMemberFilter.all => '这个社区目前没有可显示的成员。',
  CommunityMemberFilter.owner || CommunityMemberFilter.admin => '这个角色下没有成员。',
  CommunityMemberFilter.banned => '这个社区目前没有被封禁的成员。',
};

/// What this page carries instead of an online count.
const String memberDirectoryPresenceNote = '成员目录不观察在线状态，本页不显示在线人数。社区主页会去问一次。';
