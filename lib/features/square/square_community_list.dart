import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
import 'package:loop_mobile/features/chain/chain_widgets.dart';
import 'package:loop_mobile/features/community/community_contract.dart';
import 'package:loop_mobile/features/community/community_controllers.dart';
import 'package:loop_mobile/features/community/community_discover_screen.dart';
import 'package:loop_mobile/features/community/community_gateway.dart';
import 'package:loop_mobile/features/community/community_logo.dart';
import 'package:loop_mobile/features/community/community_models.dart';
import 'package:loop_mobile/features/community/community_state.dart';
import 'package:loop_mobile/features/community/community_widgets.dart';
import 'package:loop_mobile/integrations/backend/v2/loop_v2_meta.dart';
import 'package:loop_mobile/widgets/loop_assets.dart';
import 'package:loop_mobile/core/assets/loop_assets.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_toast.dart';

/// The one line that replaced the DISCOVERY DESK card (decision 0116).
const String squareCommunityRuleLine = '按成员数 / 算力 / 讨论量 / 新建排序，热门不等于推荐';

/// The 社区 segment of 广场, laid out like a DeBox club list (S111 §2,
/// decision 0116).
///
/// Archetype `index`, layout `stream`. A compact rule line and a read-only
/// search entry scroll away; the two chip groups — 全部 / 我加入的 and the
/// four orders — stay pinned; one row is one community, and a community the
/// reader has not joined is joined from its row.
class SquareCommunityList extends ConsumerStatefulWidget {
  const SquareCommunityList({
    required this.onOpenCommunity,
    super.key,
    this.onOpenSearch,
  });

  final ValueChanged<String> onOpenCommunity;

  /// Opens `/search`. Null pushes the route itself.
  final VoidCallback? onOpenSearch;

  @override
  ConsumerState<SquareCommunityList> createState() =>
      _SquareCommunityListState();
}

class _SquareCommunityListState extends ConsumerState<SquareCommunityList> {
  /// Rows whose join is in the air: their capsule waits, and a second tap
  /// does not send a second join.
  final Set<String> _joining = <String>{};

  void _openSearch() {
    final open = widget.onOpenSearch;
    if (open != null) {
      open();
      return;
    }
    unawaited(context.push<void>('/search'));
  }

  Future<void> _join(CommunitySummary community) async {
    final id = community.communityId;
    if (!_joining.add(id)) return;
    setState(() {});
    final failure = await ref
        .read(communityDiscoverControllerProvider.notifier)
        .joinFromRow(id);
    if (!mounted) return;
    setState(() => _joining.remove(id));
    if (failure == null) {
      LoopToast.show(context, message: '已加入');
      return;
    }
    LoopToast.show(
      context,
      message: communityFailureReason(failure),
      kind: LoopToastKind.err,
    );
  }

  Future<void> _showRules(CommunityRecommendation? recommendation) =>
      showLoopSheet<void>(
        context,
        useRootNavigator: true,
        barrierLabel: '关闭排序规则',
        builder: (sheetContext) => _SquareRulesSheet(
          recommendation: recommendation,
          onApply: () {
            Navigator.of(sheetContext).pop();
            unawaited(
              startCommunityApplication(
                context,
                ref,
                onOpenCommunity: widget.onOpenCommunity,
              ),
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final capability = ref.watch(
      loopCapabilityProvider(LoopV2CapabilityId.community),
    );
    final mode = ref.watch(communityGatewayProvider).mode;
    final blocked = communityCapabilityBlocks(mode, capability);
    final state = ref.watch(communityDiscoverControllerProvider);
    final controller = ref.read(communityDiscoverControllerProvider.notifier);
    if (!blocked &&
        state.phase == CommunityViewPhase.loading &&
        !state.refreshing) {
      scheduleMicrotask(() {
        if (mounted) unawaited(controller.load());
      });
    }
    final orderingReason = state.orderingReasonCode;
    final selectedSegment = CommunityDiscoverSegment.of(state.sort);
    final joinedOnly = state.membership == CommunityMembershipFilter.joined;

    final body = <Widget>[
      CommunityPreviewNotice(mode: mode, resource: '社区目录'),
      LoopFreshnessStrip(
        key: const ValueKey<String>('square-community-freshness'),
        refreshing: state.refreshing,
        refreshFailed: state.refreshFailed,
        onRetry: () => unawaited(controller.refresh()),
      ),
      if (orderingReason != null)
        LoopEmpty(
          key: const ValueKey<String>('square-community-ordering-unavailable'),
          icon: 'warn',
          message: '「${selectedSegment.label}」暂时不可用',
          reason: communityUnavailableReason(orderingReason),
          action: LoopButton(
            key: const ValueKey<String>('square-community-ordering-back'),
            label: '按成员最多排序',
            onPressed: () => unawaited(
              controller.selectSort(CommunityDirectorySort.members),
            ),
          ),
        )
      else if (state.phase == CommunityViewPhase.empty && joinedOnly)
        LoopEmptyState(
          key: const ValueKey<String>('square-community-joined-empty'),
          illustration: LoopIllustration.holders,
          title: '还没有加入社区',
          message: '加入后，社区群聊会出现在聊天里',
          action: LoopButton(
            key: const ValueKey<String>('square-community-joined-empty-all'),
            label: '去看看全部',
            icon: 'compass',
            primary: true,
            onPressed: () => unawaited(
              controller.selectMembership(CommunityMembershipFilter.all),
            ),
          ),
        )
      else if (state.phase != CommunityViewPhase.ready)
        CommunityStateBlock(
          key: const ValueKey<String>('square-community-state'),
          phase: state.phase,
          failureKind: state.failureKind,
          skeleton: LoopSkeletonType.record,
          rows: 5,
          emptyMessage: '没有符合条件的社区',
          emptyReason: '这个排序下没有社区。',
          onRetry: () => unawaited(controller.reload()),
        )
      else ...<Widget>[
        for (final community in state.items)
          SquareCommunityRow(
            key: ValueKey<String>('square-community-${community.communityId}'),
            community: community,
            sort: state.sort,
            joining: _joining.contains(community.communityId),
            onOpen: () => widget.onOpenCommunity(community.communityId),
            onJoin: () => unawaited(_join(community)),
          ),
        if (state.appendFailed && !state.loadingMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LoopButton(
              key: const ValueKey<String>('square-community-retry-more'),
              label: '重试',
              block: true,
              onPressed: () => unawaited(controller.loadMore()),
            ),
          )
        else if (state.nextCursor case final String cursor) ...<Widget>[
          LoopLoadMoreSentinel(
            key: const ValueKey<String>('square-community-load-more'),
            cursor: cursor,
            onLoadMore: () => unawaited(controller.loadMore()),
          ),
          if (state.loadingMore)
            const Padding(
              key: ValueKey<String>('square-community-loading-more'),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LoopSkeleton(type: LoopSkeletonType.record, rows: 2),
            ),
        ] else if (state.items.isNotEmpty)
          const LoopProvenanceFooter(
            key: ValueKey<String>('square-community-end'),
            text: '没有更多社区',
          ),
      ],
    ];

    return LoopStreamPage(
      key: const ValueKey<String>('square-community-list'),
      archetype: LoopPageArchetype.listing,
      title: '社区',
      kicker: communityPreviewKicker(mode),
      embedded: true,
      tabPage: true,
      block: blocked
          ? CommunityCapabilityPageBlock(
              key: const ValueKey<String>(
                'square-community-capability-unavailable',
              ),
              capability: capability,
              title: '社区模块当前不可用',
            )
          : null,
      onRefresh: controller.refresh,
      updating: state.refreshing,
      collection: CustomScrollView(
        key: const ValueKey<String>('square-community-scroll'),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _SquareHeaderLine(
                  onRules: () => unawaited(_showRules(state.recommendation)),
                ),
                _SquareSearchEntry(onTap: _openSearch),
              ],
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedChips(
              child: _SquareChips(
                membership: state.membership,
                sort: selectedSegment,
                onMembership: (filter) =>
                    unawaited(controller.selectMembership(filter)),
                onSort: (segment) =>
                    unawaited(controller.selectSort(segment.sort)),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList(delegate: SliverChildListDelegate(body)),
          ),
        ],
      ),
    );
  }
}

class _SquareHeaderLine extends StatelessWidget {
  const _SquareHeaderLine({required this.onRules});

  final VoidCallback onRules;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('square-community-header'),
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              squareCommunityRuleLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopTypography.caption(12, color: LoopColors.muted),
            ),
          ),
          Semantics(
            button: true,
            label: '排序规则',
            excludeSemantics: true,
            child: InkWell(
              key: const ValueKey<String>('square-community-rules'),
              onTap: onRules,
              borderRadius: BorderRadius.circular(LoopRadius.innerValue),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: LoopTouch.minimum,
                  minHeight: LoopTouch.minimum,
                ),
                child: Center(
                  widthFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '规则',
                      style: LoopTypography.label(12, color: LoopColors.text2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A search field that is not one: it opens `/search`, where typing is.
class _SquareSearchEntry extends StatelessWidget {
  const _SquareSearchEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Semantics(
        button: true,
        label: '搜索社区',
        excludeSemantics: true,
        child: Material(
          color: LoopColors.card,
          borderRadius: LoopRadius.control,
          child: InkWell(
            key: const ValueKey<String>('square-community-search'),
            onTap: onTap,
            borderRadius: LoopRadius.control,
            child: Container(
              constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: LoopRadius.control,
                border: Border.all(color: LoopColors.line),
              ),
              child: Row(
                children: <Widget>[
                  const LoopIcon('search', size: 17, color: LoopColors.text3),
                  const SizedBox(width: 10),
                  Text(
                    '搜索社区',
                    style: LoopTypography.caption(13, color: LoopColors.text3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedChips extends SliverPersistentHeaderDelegate {
  const _PinnedChips({required this.child});

  final Widget child;

  static const double height = 52;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => ColoredBox(color: LoopColors.ink, child: child);

  @override
  bool shouldRebuild(covariant _PinnedChips oldDelegate) =>
      oldDelegate.child != child;
}

/// `全部 · 我加入的` then the four orders, on one scrolling line. Each group
/// has exactly one chip chosen.
class _SquareChips extends StatelessWidget {
  const _SquareChips({
    required this.membership,
    required this.sort,
    required this.onMembership,
    required this.onSort,
  });

  final CommunityMembershipFilter membership;
  final CommunityDiscoverSegment sort;
  final ValueChanged<CommunityMembershipFilter> onMembership;
  final ValueChanged<CommunityDiscoverSegment> onSort;

  static const _membershipLabels = <CommunityMembershipFilter, String>{
    CommunityMembershipFilter.all: '全部',
    CommunityMembershipFilter.joined: '我加入的',
  };

  /// Decision 0122: the two membership chips carry a glyph; the four
  /// orders are two-to-four characters and stay words only.
  static const _membershipIcons = <CommunityMembershipFilter, String>{
    CommunityMembershipFilter.all: 'compass',
    CommunityMembershipFilter.joined: 'check',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey<String>('square-community-chips'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 6, 9, 8),
      child: Row(
        children: <Widget>[
          for (final filter in CommunityMembershipFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: LoopSeg(
                key: ValueKey<String>('square-filter-${filter.wireName}'),
                label: _membershipLabels[filter]!,
                icon: _membershipIcons[filter],
                quiet: true,
                selected: filter == membership,
                onSelected: () => onMembership(filter),
              ),
            ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.only(left: 2, right: 9),
            color: LoopColors.line2,
          ),
          for (final segment in CommunityDiscoverSegment.values)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: LoopSeg(
                key: ValueKey<String>('square-sort-${segment.name}'),
                quiet: true,
                label: segment.label,
                selected: segment == sort,
                onSelected: () => onSort(segment),
              ),
            ),
        ],
      ),
    );
  }
}

/// What the right edge of a row offers, from the row's `viewerMembership`.
enum SquareMembershipAction {
  /// The row did not say: nothing is offered.
  none,
  join,
  joined,
  mine,
  pending,
}

SquareMembershipAction squareMembershipAction(
  CommunityDirectoryViewer? viewer,
) {
  if (viewer == null || viewer.isBanned) return SquareMembershipAction.none;
  return switch (viewer.role) {
    CommunityRole.owner => SquareMembershipAction.mine,
    CommunityRole.admin ||
    CommunityRole.member => SquareMembershipAction.joined,
    null =>
      viewer.pending
          ? SquareMembershipAction.pending
          : SquareMembershipAction.join,
  };
}

/// The line under a row's name: members, then the bound token — or, under an
/// order that ranks by a fact the row carries, that fact.
String squareCommunitySubline(
  CommunitySummary community,
  CommunityDirectorySort sort,
) {
  final members = '${community.memberCount} 成员';
  final ranked = communityDirectoryRowFigure(community, sort: sort);
  if (ranked != null) return '$members · ${ranked.caption} ${ranked.value}';
  final symbol = community.assetSymbol;
  return symbol == null ? members : '$members · \$$symbol';
}

/// One community, DeBox-club style (decision 0116): logo, name and its
/// verification, members and token, and the reader's membership at the
/// right. The whole row opens the community.
class SquareCommunityRow extends StatelessWidget {
  const SquareCommunityRow({
    required this.community,
    required this.sort,
    required this.joining,
    required this.onOpen,
    required this.onJoin,
    super.key,
  });

  final CommunitySummary community;
  final CommunityDirectorySort sort;
  final bool joining;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  static const double height = 76;

  @override
  Widget build(BuildContext context) {
    final id = community.communityId;
    final action = squareMembershipAction(community.viewerMembership);
    final subline = squareCommunitySubline(community, sort);
    final verification = communityVerificationLabel(
      community.verificationStatus,
    );
    final state = switch (action) {
      SquareMembershipAction.none => '',
      SquareMembershipAction.join => '，未加入',
      SquareMembershipAction.joined => '，已加入',
      SquareMembershipAction.mine => '，我的社区',
      SquareMembershipAction.pending => '，审核中',
    };
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            button: true,
            label: '${community.name}，$verification，$subline$state',
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey<String>('square-community-open-$id'),
              onTap: onOpen,
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Row(
                    children: <Widget>[
                      CommunityLogo(
                        identity: id,
                        name: community.name,
                        logoRef: community.logoRef,
                        size: 48,
                        radius: LoopRadius.innerValue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    community.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: LoopTypography.title(15),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                LoopBadge(
                                  verification,
                                  key: ValueKey<String>(
                                    'square-community-verification-$id',
                                  ),
                                  kind: community.isVerified
                                      ? LoopBadgeKind.up
                                      : LoopBadgeKind.mute,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subline,
                              key: ValueKey<String>(
                                'square-community-subline-$id',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LoopTypography.caption(
                                12,
                                color: LoopColors.text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (action != SquareMembershipAction.none)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _MembershipCapsule(
              communityId: id,
              action: action,
              joining: joining,
              onJoin: onJoin,
              onOpen: onOpen,
            ),
          )
        else
          const SizedBox(width: 8),
      ],
    );
  }
}

class _MembershipCapsule extends StatelessWidget {
  const _MembershipCapsule({
    required this.communityId,
    required this.action,
    required this.joining,
    required this.onJoin,
    required this.onOpen,
  });

  final String communityId;
  final SquareMembershipAction action;
  final bool joining;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (
      String key,
      String label,
      bool lime,
      VoidCallback? onTap,
    ) = switch (action) {
      SquareMembershipAction.join => (
        'join',
        '加入',
        true,
        joining ? null : onJoin,
      ),
      SquareMembershipAction.joined => ('joined', '已加入', false, onOpen),
      SquareMembershipAction.mine => ('mine', '我的', false, onOpen),
      SquareMembershipAction.pending => ('pending', '审核中', false, onOpen),
      SquareMembershipAction.none => ('none', '', false, null),
    };
    final foreground = lime ? LoopColors.ink : LoopColors.text2;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: joining ? '正在加入' : label,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey<String>('square-community-$key-$communityId'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: LoopTouch.minimum,
            minHeight: LoopTouch.minimum,
          ),
          child: Center(
            widthFactor: 1,
            child: Container(
              height: 28,
              constraints: const BoxConstraints(minWidth: 60),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: lime ? LoopColors.lime : LoopColors.card2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: joining
                  ? SizedBox(
                      key: ValueKey<String>(
                        'square-community-joining-$communityId',
                      ),
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: foreground,
                      ),
                    )
                  : Text(
                      label,
                      style: LoopTypography.label(12, color: foreground),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareRulesSheet extends StatelessWidget {
  const _SquareRulesSheet({
    required this.recommendation,
    required this.onApply,
  });

  final CommunityRecommendation? recommendation;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final rule = recommendation;
    return Padding(
      key: const ValueKey<String>('square-community-rules-sheet'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '排序规则',
            style: LoopTypography.heading(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '排序只用成员数、创建时间、算力与 7 天讨论量这些可核对的数字。热门不等于推荐。',
            style: LoopTypography.body(13, color: LoopColors.muted),
          ),
          if (rule != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'RULE · ${rule.ruleVersion}',
              key: const ValueKey<String>('square-community-rule-version'),
              style: LoopTypography.figure(11, color: LoopColors.text3),
            ),
          ],
          const SizedBox(height: 18),
          Text('社区怎么入驻', style: LoopTypography.title(15)),
          const SizedBox(height: 6),
          Text(
            '任何社区都可以提交申请。申请后状态为"审核中"，只有运维核验通过才会显示验证标记；'
            '本页不代表任何 Mining 权重结论。',
            style: LoopTypography.body(13, color: LoopColors.muted),
          ),
          const SizedBox(height: 14),
          LoopButtonPair(
            padded: false,
            children: <Widget>[
              LoopButton(
                key: const ValueKey<String>('square-community-apply'),
                label: '申请入驻',
                onPressed: onApply,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
