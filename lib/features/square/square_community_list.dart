import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loop_mobile/core/policy/loop_capability_projection.dart';
import 'package:loop_mobile/core/theme/loop_theme.dart';
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
import 'package:loop_mobile/widgets/loop_atmosphere.dart';
import 'package:loop_mobile/widgets/loop_components.dart';
import 'package:loop_mobile/widgets/loop_empty_state.dart';
import 'package:loop_mobile/widgets/loop_inline_states.dart';
import 'package:loop_mobile/widgets/loop_load_more.dart';
import 'package:loop_mobile/widgets/loop_loading.dart';
import 'package:loop_mobile/widgets/loop_pages.dart';
import 'package:loop_mobile/widgets/loop_person_row.dart';
import 'package:loop_mobile/widgets/loop_sheet.dart';
import 'package:loop_mobile/widgets/loop_sheet_heading.dart';
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

  Future<void> _chooseSort(CommunityDiscoverSegment current) async {
    final chosen = await showLoopSheet<CommunityDiscoverSegment>(
      context,
      useRootNavigator: true,
      barrierLabel: '关闭排序',
      builder: (sheetContext) => _SquareSortSheet(
        current: current,
        onSelected: (segment) => Navigator.of(sheetContext).pop(segment),
      ),
    );
    if (chosen == null || chosen == current || !mounted) return;
    await ref
        .read(communityDiscoverControllerProvider.notifier)
        .selectSort(chosen.sort);
  }

  void _openDirectory() => unawaited(context.push<void>('/community/discover'));

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

    // UX-013 (decision 0257): 热门社区 is the community with the most
    // members among the rows already read — no endpoint of its own. A
    // directory of one or two rows has nothing to single out: the banner
    // would only repeat the row under it.
    final hot =
        joinedOnly ||
            state.phase != CommunityViewPhase.ready ||
            state.items.length < squareHotMinimumRows
        ? null
        : squareHotCommunity(state.items);

    final body = <Widget>[
      CommunityPreviewNotice(mode: mode, resource: '社区目录'),
      if (hot != null) ...<Widget>[
        _SquareSectionHead(
          key: const ValueKey<String>('square-hot-head'),
          title: '热门社区',
          icon: 'star',
          trailing: _SquareTextLink(
            key: const ValueKey<String>('square-hot-more'),
            label: '查看更多',
            onTap: _openDirectory,
          ),
        ),
        SquareHotCommunityCard(
          key: ValueKey<String>('square-hot-${hot.communityId}'),
          community: hot,
          joining: _joining.contains(hot.communityId),
          onOpen: () => widget.onOpenCommunity(hot.communityId),
          onJoin: () => unawaited(_join(hot)),
        ),
      ],
      _SquareSectionHead(
        key: const ValueKey<String>('square-all-head'),
        title: joinedOnly ? '我加入的社区' : '全部社区',
        trailing: _SquareSortButton(
          label: selectedSegment.label,
          onTap: () => unawaited(_chooseSort(selectedSegment)),
        ),
      ),
      LoopFreshnessStrip(
        key: const ValueKey<String>('square-community-freshness'),
        refreshing: state.refreshing,
        refreshFailed: state.refreshFailed,
        onRetry: () => unawaited(controller.refresh()),
      ),
      if (orderingReason != null)
        Column(
          key: const ValueKey<String>('square-community-ordering-unavailable'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LoopInlineUnavailable(
              message: '「${selectedSegment.label}」暂时不可用',
              detail: communityUnavailableReason(orderingReason),
              maxLines: 2,
              detailMaxLines: 4,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                LoopSpacing.page,
                0,
                LoopSpacing.page,
                10,
              ),
              child: LoopButton(
                key: const ValueKey<String>('square-community-ordering-back'),
                label: '按成员最多排序',
                onPressed: () => unawaited(
                  controller.selectSort(CommunityDirectorySort.members),
                ),
              ),
            ),
          ],
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
        // Decision 0221: on the wall the rows sit on one card board; the
        // rows themselves stay flat.
        if (state.items.isNotEmpty) ...<Widget>[
          LoopAtmoBoard(
            key: const ValueKey<String>('square-community-board'),
            children: <Widget>[
              for (final community in state.items)
                SquareCommunityRow(
                  key: ValueKey<String>(
                    'square-community-${community.communityId}',
                  ),
                  community: community,
                  sort: state.sort,
                  joining: _joining.contains(community.communityId),
                  onOpen: () => widget.onOpenCommunity(community.communityId),
                  onJoin: () => unawaited(_join(community)),
                ),
            ],
          ),
        ],
        if (state.appendFailed && !state.loadingMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              LoopSpacing.page,
              12,
              LoopSpacing.page,
              0,
            ),
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
              padding: EdgeInsets.fromLTRB(
                LoopSpacing.page,
                12,
                LoopSpacing.page,
                0,
              ),
              child: LoopSkeleton(type: LoopSkeletonType.record, rows: 2),
            ),
        ] else if (state.items.isNotEmpty)
          // Decision 0123 (S121 §1.1.1 rule 10): a list that really
          // ended draws nothing; only room under the last row.
          const SizedBox(
            key: ValueKey<String>('square-community-end'),
            height: 12,
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
              child: _SquareMainTabs(
                membership: state.membership,
                onMembership: (filter) =>
                    unawaited(controller.selectMembership(filter)),
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

/// 「发现社区」 with 「规则与入驻 ›」 at its right (UX-013, decision 0257).
/// The link opens the same sheet as before: the ordering rules and 申请入驻.
class _SquareHeaderLine extends StatelessWidget {
  const _SquareHeaderLine({required this.onRules});

  final VoidCallback onRules;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('square-community-header'),
      padding: const EdgeInsets.only(left: LoopSpacing.page, right: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                '发现社区',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LoopType.title.copyWith(color: LoopColors.chalk),
              ),
            ),
          ),
          _SquareTextLink(
            key: const ValueKey<String>('square-community-rules'),
            label: '规则与入驻',
            onTap: onRules,
          ),
        ],
      ),
    );
  }
}

/// A quiet word with a chevron that opens something (「规则与入驻 ›」,
/// 「查看更多 ›」), 44 tall.
class _SquareTextLink extends StatelessWidget {
  const _SquareTextLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LoopRadius.innerValue),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: LoopTouch.minimum,
          minHeight: LoopTouch.minimum,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: LoopTypography.withWeight(
                  LoopType.label,
                  FontWeight.w600,
                ).copyWith(color: LoopColors.text2),
              ),
              const SizedBox(width: 2),
              const LoopIcon('chevron', size: 14, color: LoopColors.text2),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A module title on the 社区 segment (「热门社区」, 「全部社区」) with an
/// optional control at its right (UX-013, decision 0257).
class _SquareSectionHead extends StatelessWidget {
  const _SquareSectionHead({
    required this.title,
    super.key,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(LoopSpacing.page, 10, 8, 4),
    child: Row(
      children: <Widget>[
        if (icon case final String glyph) ...<Widget>[
          LoopIcon(glyph, size: 18, color: LoopColors.yellow),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LoopTypography.withWeight(
                LoopType.body1,
                FontWeight.w700,
              ).copyWith(color: LoopColors.chalk),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// 「成员最多 ∨」: the current order, opening the four orders the directory
/// takes (UX-013, decision 0257).
class _SquareSortButton extends StatelessWidget {
  const _SquareSortButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '排序，$label',
    excludeSemantics: true,
    child: InkWell(
      key: const ValueKey<String>('square-community-sort'),
      onTap: onTap,
      borderRadius: LoopRadius.pill,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: LoopTouch.minimum),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const BoxDecoration(
              color: LoopColors.card2,
              borderRadius: LoopRadius.pill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: LoopTypography.withWeight(
                    LoopType.label,
                    FontWeight.w600,
                  ).copyWith(color: LoopColors.chalk),
                ),
                const SizedBox(width: 4),
                const RotatedBox(
                  quarterTurns: 1,
                  child: LoopIcon('chevron', size: 12, color: LoopColors.text2),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The four orders, one row each; the chosen one carries a tick.
class _SquareSortSheet extends StatelessWidget {
  const _SquareSortSheet({required this.current, required this.onSelected});

  final CommunityDiscoverSegment current;
  final ValueChanged<CommunityDiscoverSegment> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey<String>('square-community-sort-sheet'),
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const LoopSheetHeading('排序'),
      for (final segment in CommunityDiscoverSegment.values)
        Semantics(
          button: true,
          selected: segment == current,
          label: segment.label,
          excludeSemantics: true,
          child: InkWell(
            key: ValueKey<String>('square-sort-${segment.name}'),
            onTap: () => onSelected(segment),
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LoopSpacing.page,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        segment.label,
                        style: LoopType.body.copyWith(
                          color: segment == current
                              ? LoopColors.yellow
                              : LoopColors.chalk,
                        ),
                      ),
                    ),
                    if (segment == current)
                      const LoopIcon(
                        'check',
                        size: 18,
                        color: LoopColors.yellow,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 8),
    ],
  );
}

/// How many rows the directory must hold before 热门社区 is drawn.
const int squareHotMinimumRows = 3;

/// The community with the most members among [items], the first one on a
/// tie; `null` for no rows (UX-013, decision 0257).
CommunitySummary? squareHotCommunity(List<CommunitySummary> items) {
  CommunitySummary? best;
  for (final item in items) {
    if (best == null || item.memberCount > best.memberCount) best = item;
  }
  return best;
}

/// 「N 成员，7 天讨论 M」 when the row carries its discussion count, otherwise
/// 「N 成员」.
String squareHotFacts(CommunitySummary community) {
  final members = '${community.memberCount} 成员';
  final activity = community.activity;
  if (activity is CommunityActivityCount) {
    final count = activity.bounded
        ? '≥${activity.messageCount}'
        : '${activity.messageCount}';
    return '$members，7 天讨论 $count';
  }
  return members;
}

/// 热门社区's banner card (UX-013, decision 0257): logo, name and the
/// operator's label, one line of description, the counts, and the row's own
/// membership action at the right.
class SquareHotCommunityCard extends StatelessWidget {
  const SquareHotCommunityCard({
    required this.community,
    required this.joining,
    required this.onOpen,
    required this.onJoin,
    super.key,
  });

  final CommunitySummary community;
  final bool joining;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final id = community.communityId;
    final label = community.label;
    final description = community.description?.trim();
    final action = squareMembershipAction(community.viewerMembership);
    final facts = squareHotFacts(community);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        4,
        LoopSpacing.page,
        LoopSpacing.rowGap,
      ),
      child: Material(
        color: LoopColors.card,
        borderRadius: LoopRadius.card,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(LoopSpacing.card),
            child: Row(
              children: <Widget>[
                CommunityLogo(
                  identity: id,
                  name: community.name,
                  logoRef: community.logoRef,
                  size: 64,
                  radius: LoopRadius.innerValue,
                  chromeFallback: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: <String>[
                      '热门社区',
                      community.name,
                      if (label != null) communityLabelDisplay(label),
                      if (description != null && description.isNotEmpty)
                        description,
                      facts,
                    ].join('，'),
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        LayoutBuilder(
                          builder: (context, constraints) => Row(
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  community.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: LoopTypography.withWeight(
                                    LoopType.body1,
                                    FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (label != null) ...<Widget>[
                                const SizedBox(width: 6),
                                CommunityLabelBadge(
                                  label,
                                  maxWidth: constraints.maxWidth * 0.45,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (description != null &&
                            description.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LoopType.caption.copyWith(
                              color: LoopColors.text2,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          facts,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LoopType.captionSm.copyWith(
                            color: LoopColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (action != SquareMembershipAction.none) ...<Widget>[
                  const SizedBox(width: 8),
                  _MembershipCapsule(
                    communityId: 'hot-$id',
                    action: action,
                    joining: joining,
                    onJoin: onJoin,
                    onOpen: onOpen,
                  ),
                ],
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        4,
        LoopSpacing.page,
        LoopSpacing.rowGap,
      ),
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
              // v3 (decision 0229): the OKX search field, 52 high.
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: LoopSpacing.card),
              decoration: const BoxDecoration(
                color: LoopColors.input,
                borderRadius: LoopRadius.control,
              ),
              child: Row(
                children: <Widget>[
                  const LoopIcon('search', size: 19, color: LoopColors.text3),
                  const SizedBox(width: 10),
                  Text(
                    '搜索社区',
                    // R26 a search placeholder: body2 15 text3 (decision 0229).
                    style: LoopType.body.copyWith(color: LoopColors.text3),
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
    // Decision 0221: over the wall the pinned chips paint the same wall cut
    // to their box, so rows pass under them unseen; off the wall, Ink.
  ) => LoopBackdropSlice(child: child);

  @override
  bool shouldRebuild(covariant _PinnedChips oldDelegate) =>
      oldDelegate.child != child;
}

/// 全部 | 我加入的 as the segment's main tab (UX-013, decision 0257): two
/// equal halves on one track, the chosen half the solid Purple choice. The
/// order is no longer a chip row; it is 「全部社区」's own 「成员最多 ∨」.
class _SquareMainTabs extends StatelessWidget {
  const _SquareMainTabs({required this.membership, required this.onMembership});

  final CommunityMembershipFilter membership;
  final ValueChanged<CommunityMembershipFilter> onMembership;

  static const _membershipLabels = <CommunityMembershipFilter, String>{
    CommunityMembershipFilter.all: '全部',
    CommunityMembershipFilter.joined: '我加入的',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('square-community-chips'),
      padding: const EdgeInsets.fromLTRB(
        LoopSpacing.page,
        4,
        LoopSpacing.page,
        4,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: LoopColors.card,
          borderRadius: LoopRadius.pill,
        ),
        child: Row(
          children: <Widget>[
            for (final filter in CommunityMembershipFilter.values)
              Expanded(
                child: LoopSeg(
                  key: ValueKey<String>('square-filter-${filter.wireName}'),
                  label: _membershipLabels[filter]!,
                  quiet: true,
                  block: true,
                  selected: filter == membership,
                  onSelected: () => onMembership(filter),
                ),
              ),
          ],
        ),
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
  // v3 (decision 0229): no centre-dot chain; a comma joins the two facts.
  if (ranked != null) return '$members，${ranked.caption} ${ranked.value}';
  final symbol = community.assetSymbol;
  return symbol == null ? members : '$members，\$$symbol';
}

/// One community, DeBox-club style (decision 0116): logo, name and the
/// operator's label when it has one (decision 0239), members and token, and
/// the reader's membership at the right. The whole row opens the community.
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

  static const double height = LoopSpacing.rowMinWithSub;

  /// A row that also carries its one line of description (UX-013).
  static const double heightWithDescription = 76;

  @override
  Widget build(BuildContext context) {
    final id = community.communityId;
    final action = squareMembershipAction(community.viewerMembership);
    final subline = squareCommunitySubline(community, sort);
    // Decision 0239: the operator's free-text label, or no mark at all.
    final label = community.label;
    final description = community.description?.trim();
    final described = description != null && description.isNotEmpty;
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
            label:
                '${<String>[community.name, if (label != null) communityLabelDisplay(label), if (described) description].join('，')}'
                '，$subline$state',
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey<String>('square-community-open-$id'),
              onTap: onOpen,
              child: SizedBox(
                height: described ? heightWithDescription : height,
                child: Padding(
                  padding: const EdgeInsets.only(left: LoopSpacing.card),
                  child: Row(
                    children: <Widget>[
                      CommunityLogo(
                        identity: id,
                        name: community.name,
                        logoRef: community.logoRef,
                        size: 48,
                        radius: LoopRadius.innerValue,
                        chromeFallback: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // The label takes at most 45 % of the line, so a
                            // long one ellipsizes before it pushes the name
                            // out (decision 0239).
                            LayoutBuilder(
                              builder: (context, constraints) => Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      community.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: LoopType.body1,
                                    ),
                                  ),
                                  if (label != null) ...<Widget>[
                                    const SizedBox(width: 6),
                                    CommunityLabelBadge(
                                      label,
                                      key: ValueKey<String>(
                                        'square-community-label-$id',
                                      ),
                                      maxWidth: constraints.maxWidth * 0.45,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (described) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                description,
                                key: ValueKey<String>(
                                  'square-community-description-$id',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: LoopType.caption.copyWith(
                                  color: LoopColors.text2,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              subline,
                              key: ValueKey<String>(
                                'square-community-subline-$id',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LoopType.caption,
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
            // The action ends on the board's own inner line (decision 0229).
            padding: const EdgeInsets.only(right: LoopSpacing.card),
            child: _MembershipCapsule(
              communityId: id,
              action: action,
              joining: joining,
              onJoin: onJoin,
              onOpen: onOpen,
            ),
          )
        else
          const SizedBox(width: LoopSpacing.card),
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
    // Decision 0212 (docs/42 附C §6): 「加入」 is the Yellow primary step —
    // the one thing on the row that asks to be tapped; 「已加入」 and the
    // others are the quiet secondary pill.
    return LoopPillAction(
      key: ValueKey<String>('square-community-$key-$communityId'),
      label: joining ? '加入中' : label,
      primary: lime,
      onPressed: onTap,
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
    return Column(
      key: const ValueKey<String>('square-community-rules-sheet'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const LoopSheetHeading('排序规则'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            LoopSpacing.page,
            0,
            LoopSpacing.page,
            8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '排序只用成员数、创建时间、算力与 7 天讨论量这些可核对的数字。热门不等于推荐。',
                style: LoopType.bodySm,
              ),
              if (rule != null) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'RULE · ${rule.ruleVersion}',
                  key: const ValueKey<String>('square-community-rule-version'),
                  style: LoopType.captionSm,
                ),
              ],
              const SizedBox(height: 18),
              Text('社区怎么入驻', style: LoopType.title),
              const SizedBox(height: 6),
              Text(
                '任何社区都可以提交申请。申请后状态为"审核中"，只有运维核验通过才会显示验证标记；'
                '本页不代表任何 Mining 权重结论。',
                style: LoopType.bodySm,
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
        ),
      ],
    );
  }
}
